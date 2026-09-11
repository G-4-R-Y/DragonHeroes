# 32 — Scaling RL training: from one match to thousands of parallel episodes

> **Status:** v1 (2026-09-02). Tier 1 (parallel Godot workers) is LANDED and
> measured; Tier 2 (dh-env) is the canon path (§9, [tech/25](25-creature-ai-and-rl.md));
> Tier 3 is the runbook for when we outgrow one box. Companion docs:
> [design/23](../design/23-arena-and-self-play.md) (the arena),
> [game/arena/README.md](../../game/arena/README.md) (commands).

## The question

"How do I train on thousands of parallel episodes?" — three answers, in the
order you should adopt them:

| Tier | What | Throughput (measured / canon) | When |
|---|---|---|---|
| **1. Parallel Godot workers** | `league --jobs N`: N headless arena processes in one pool | since 2026-09-11 (`--speed max`): 1 worker ≈ **110× real time**; 16 workers ≈ **870× aggregate** ≈ 600 two-episode match sets/min ≈ **70k episodes/hour** on the 20-core dev box (flat past 16). Before: wall-locked 4× → 3.8k/hour | TODAY, one dev box |
| **2. dh-env (C++ vectorized sim)** | thousands of arena instances *per process*, PufferLib PPO | canon §9/tech/25: **300k–1.2M env-steps/s** on one GPU box — this is the real "thousands of parallel episodes" | when `dh-sim` combat lands |
| **3. Worker fleets** | the Tier-1 runner replicated across machines (spot CPU workers, one artifact) | linear in machines | big league nights before Tier 2 exists |

## Tier 1 — parallel Godot workers (landed)

`ml/training/league.py` evaluates every (ES-perturbation × opponent) pair in a
`ThreadPoolExecutor` of headless Godot subprocesses (`--jobs N`). Each worker is
a full arena boot running `--fast --speed max`: under the engine flag
`--fixed-fps 60` every frame advances exactly one 1/60 s tick, so the match is
CPU-bound and deterministic (results bit-identical to the wall-locked modes).

**Until 2026-09-11 fast mode was WALL-LOCKED at 4×** (240 Hz ticks × time_scale
4): a 4-episode match took ≥ 45 s however idle the CPU was, and a generation is
only pop × opponents matches (12 by default) — so `--jobs 32` ran 12 processes
and "more jobs" changed nothing. Ricardo's question ("is it using my GPU? more
jobs doesn't accelerate much") led to the `--speed` lever (arena.gd
`_apply_speed`, canon §12.39, design/25 §5). `--speed N` still gives the
wall-locked N× for watching. **No GPU is involved in this tier** — numpy MLP +
Godot physics/GDScript workers; GPUs arrive with Tier 2.

**Measured on the dev box (2026-09-02, wall-locked 4×):** one ES generation
(pop 2 × 2 opponents × 1 episode) — serial 52.6 s → `--jobs 4` 13.8 s (**3.8×**,
near-linear; workers are ~1-core processes).

**Measured 2026-09-11 (`--speed max`, 20 logical cores):** the same seeded
2-episode set 22.1 s (4×) → 5.65 s (16×) → **0.91 s (max)**, bit-identical
results. Concurrent max-speed workers: 1 → 109× real time, 4 → 384×, 8 → 543×,
12 → 711×, 16 → 873×, 20 → 863× (saturated: e-cores and the ~0.4 s boot per
match). A default generation (12 four-episode matches) is ~3 s with `--jobs 12`.

### Runbook

```bash
# 0. One-time: import so N concurrent instances never race the .godot cache
godot --headless --path game --import

# 1. A real training run (species net): pop 16, 4 episodes vs the default
#    ladder (native + scripted + past self), 16 workers ~= a 4-episode match set
#    every ~2-3 s per worker at --speed max (the default)
python3 -m ml.training.league train --key fen_boar \
    --build core.arena.fen_boar_alpha \
    --generations 20 --pop 16 --episodes 4 --jobs "$(nproc)"

# 2. The global net learns from every build at once (mirror matches per build)
python3 -m ml.training.league train-global \
    --builds core.arena.fen_boar_alpha,core.arena.gloamfen_stalker,core.arena.cinder_drake,core.arena.dusk_revenant \
    --generations 20 --pop 16 --episodes 2 --jobs "$(nproc)"

# 3. Gate before anything deploys (unchanged, still serial by default)
python3 -m ml.training.league gate --key fen_boar --build core.arena.fen_boar_alpha
```

### Sizing and rules of thumb

- **Workers ≈ physical cores.** Each headless Godot is ~1 core / ~150–300 MB.
  `--jobs $(nproc)` is the sane default; halve it on a shared box.
- **Parallelism ceiling = pop × opponents.** A generation is that many
  independent matches and nothing else runs concurrently, so `--jobs` beyond it
  idles. Raise `--pop` to use more cores — it also sharpens the ES gradient. The
  console's hint line states the ceiling and the pop that fills your cores.
- **Throughput estimate (`--speed max`):** ~110× real time per worker; a
  2-episode set ≈ 0.8 s alone, ≈ 1.6 s at 16 concurrent. 16 workers ≈ 600
  match sets/min ≈ **70k episodes/hour**; a 20-generation pop-16 run ≈ 20×16×2
  opponents×4 episodes ≈ 2.5k episodes ≈ **1–2 minutes**. (Old wall-locked mode:
  4 episodes/min/worker, 3.8k/hour, 40 minutes.)
- **Episodes are cheap, boots are not.** Amortize: prefer more episodes per
  match (`--episodes 4-8`) over more matches.
- **Determinism:** every match is seeded (`--seed`, per-candidate seeds derive
  from it) — reruns are reproducible; parallel order does not affect results.
- **Disk:** `--record-dir` writes ~1 MB/episode JSONL. A 10k-episode night ≈
  10 GB in `ml/data/episodes/` (gitignored). Record gate matches and BC
  datasets, not every ES perturbation.
- **Fairness travels with scale** (canon §9 §6): obs delay, aim noise, and the
  burst cap live inside the arena — 1 or 10,000 episodes, same constraints.
- Don't run two trainings against the same `--key` concurrently (the registry
  is a single JSON; candidates use per-index weight files so matches never race).

### The league shape (what to run at scale)

AlphaStar recipe, per tech/25 §4.2 — as volume grows, extend `--opponents`:

1. **Bootstrap:** native + scripted (default ladder).
2. **+ Past self:** the deployed pin of the same key (self-play) —
   `--opponents "native@<build>,ml/serving/weights/<key>_vD.json@<build>"`.
3. **+ Exploiters:** a second key trained *to beat the main key* (fitness =
   main's loss); rotate both into each other's opponent pools.
4. **Curriculum:** scripted → native → ladder-of-past-selves; shape rewards
   (hp-margin term) anneal toward pure win/loss as the league matures.

## Tier 2 — dh-env: the real "thousands of parallel episodes"

Godot-in-the-loop is ~100× too slow for PPO at scale (tech/25 §4.2) — that's
why Tier 1 trains with ES, which tolerates low episode counts. The canon path
removes the wall entirely: the same C++ `dh-sim` that runs the authoritative
server exposed as `dh-env` (C API + nanobind, vectorized — **thousands of
headless arena instances per process**), trained by PufferLib 3.x at
300k–1.2M env-steps/s on one GPU box. At that throughput "thousands of parallel
episodes" is the *default*, and a full league run is 1–5 days, not weeks.

What ports unchanged (designed for this from day one):

- **Observation schema** `arena.obs.v1` (31 floats + 16-dim content embeddings;
  entity-set encodings are the dh-env upgrade, not a rewrite).
- **The policy registry** (`ml/serving/registry.json`: versions, lineage, eval
  reports) and **the eval gate** (scripted suite + past-policy ladder +
  degeneracy checks; FAIL = stay on pin).
- **The recorded datasets** — every episode logged today is BC fuel for
  warm-starting PPO policies later.
- **Fairness constraints**, reimplemented inside the training loop as canon
  requires (they already live in the arena policies).

Milestone path: vendor godot-cpp → dh-sim combat parity (the HANDOFF "next
architectural step") → `dh-env` benchmark gate (tech/21 §9: steps/s
measurement is the explicit early milestone) → PufferLib configs in
`ml/training/` → the same gate guards every redeploy.

## Tier 3 — Fleets (if you need more before dh-env)

The Tier-1 runner is a pure function of (repo, seed, CLI) → episode JSONLs, so
it replicates trivially:

- **Container:** one image with Godot headless + the repo + numpy; the arena
  needs no GPU, no display, no audio.
- **Orchestration:** N spot CPU workers each running
  `league train --jobs $(nproc)` with a disjoint `--seed` range and a shared
  registry volume (or: shard by `--key` — species nets are independent by
  construction; merge registries afterwards).
- **Cost sanity:** CPU-only workers; a 32-core spot box ≈ 120k episodes/day.
- Keep the eval gate on ONE machine — deployment stays a single-writer decision.

## Anti-goals (don't)

- Don't parallelize by forking Godot *inside* one process — the engine isn't
  built for it; subprocesses are the isolation unit.
- Don't record every ES perturbation's episodes to disk — petabytes beckon;
  record gates, BC sets, and interesting failures.
- Don't chase episode count over opponent diversity: 10k episodes vs one
  scripted bot teaches a wall-hugger. League first, volume second.
