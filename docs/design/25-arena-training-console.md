# 25 — Arena Training Console (design + build plan, 2026-09-11)

**Ricardo:** "Arena can get a simple interface for selecting who I'm training
and keeping up with training progress? some loss, performance metrics,
optional watch a single episode from the simulated ones."
**Status:** LANDED 2026-09-11 — console, progress seam, and the `--speed`
training lever (§5). The agent partition (§3) halted on the session quota;
the rest was built and gated inline (Ricardo: no background agents).
**Relation:** design/23 (arena), tech/32 (training at scale), canon §12.35/38
(local GPUs only), docs/USAGE.md (commands).

## 1. What it is

A code-built Godot scene, `game/arena/console.tscn`, that drives the existing
ES trainer (`ml/training/league.py`) and shows its progress live:

- **Roster panel** — pick the trainee (species key + build from
  `ProtoBuild.catalog()`), pick opponents (multi-select), set generations /
  pop / episodes / **jobs** (default = this machine's cores) / **speed**
  (`max` default — CPU-bound; or a wall-locked multiplier for watching). A
  hint line states the parallelism ceiling (pop × opponents matches per
  generation), how many workers or cores idle, and the pop that fills them.
  Gens / pop / episodes mirror league.py's defaults.
- **Train / Stop** — spawns `python3 -m ml.training.league train …` as a
  child process (`OS.create_process` via `bash -lc "cd <repo> && …"`), stores
  the pid, Stop kills it. Never blocks the UI.
- **Progress panel** — tails the trainer's progress JSONL (contract §2) every
  0.5 s: current generation/candidate/match, matches done of total, ETA from
  observed match durations, a **fitness chart** (best + mean per generation,
  per-candidate dots) drawn with `_draw`, a **match-score strip** (one dot
  per match at its win rate, coloured by opponent tag such as
  `native@fen_boar_alpha`, legend with per-opponent means — a flat 0.00 row IS
  the "no learning signal" diagnosis), and the last gate result. ES has no
  loss; **fitness** (candidate match score vs opponents, 0..1, higher is
  better) IS the metric, plus gate win-rates.
- **Gate** — runs `league gate` for the trainee, shows PASS/FAIL + numbers.
- **Watch an episode** — spawns a WINDOWED arena for ONE episode with the
  trainee's latest net: `godot --path game res://arena/arena.tscn -- --a
  <build> --b <opponent> --policy-a <neural spec> --episodes 1 --spectate`.
  The builder reads `game/arena/policy.gd` + `neural_policy.gd` to use the
  exact policy-spec syntax and to point at the CANDIDATE (latest registered)
  version, falling back to the deployed one.
- Pixel typography via `ProtoTheme.get_theme()`; the 640×360 grid; no new
  autoloads.

## 2. Progress contract (league.py → console) — THE SEAM

league.py always appends JSON lines to `ml/data/progress/<key>.jsonl`
(directory created; path also settable with `--progress-file`). One object
per line, `t` = unix seconds, `ev` = event:

```
{"t":..,"ev":"start","key":"fen_boar","build":"core.arena.fen_boar_alpha",
 "generations":3,"pop":6,"episodes":4,"jobs":1,"speed":"max",
 "opponents":[["core.arena.x","scripted"],...],"warm_start":null|1}
{"t":..,"ev":"match","g":0,"cand":2,"opp":"core.arena.x","policy":"scripted",
 "wins_a":3,"wins_b":1,"draws":0,"score":0.75,"duration_s":41.2}
{"t":..,"ev":"candidate","g":0,"cand":2,"fitness":0.41}
{"t":..,"ev":"generation","g":0,"best":0.52,"mean":0.38}
{"t":..,"ev":"registered","version":1,"npz":"ml/serving/weights/fen_boar_v1.npz"}
{"t":..,"ev":"gate","version":1,"pass":false,"metrics":{...}}     # from `league gate`
{"t":..,"ev":"checkpoint","g":25,"path":".../weights/_ckpt_fen_boar.npz"}
{"t":..,"ev":"resumed","g":25,"generations":1000,"saved":"2026-09-13T17:20:04"}
{"t":..,"ev":"error","message":"..."}
```
The head-to-head bench (`league versus`) rides the same feed under the key
`versus`, so the PROGRESS tab paints a best-of-N exactly like a training run:
```
{"t":..,"ev":"versus_start","a":"fen_boar v2 (candidate)","b":"native",
 "a_build":"core.arena.fen_boar_alpha","b_build":"...","best_of":9,"episodes":3}
{"t":..,"ev":"versus_round","i":0,"seed":2026,"wins_a":2,"wins_b":1,"draws":0,
 "hp_a":0.41,"hp_b":0.0,"score_a":0.6667,"duration_s":11.3}
{"t":..,"ev":"versus_done","winner":"a","rounds_a":5,"rounds_b":4,"draws":0,
 "out":"ml/data/benchmarks/2026-09-13_0709__fen_boar-v2_vs_native.json"}
```
Rules: append-only, one line per event, flush after each write; the console
tolerates partial trailing lines and unknown events. `match` events come
from inside `evaluate_candidates` (per arena run — a run IS one match of N
episodes), so progress is visible long before a generation completes (today
the CLI is silent for a whole generation).

## 3. Partition (three builders, disjoint files, one verifier)

- **A — trainer events**: `ml/training/league.py` (a small `Progress` writer;
  events at the points above; `--progress-file`; `gate` writes `gate`
  events), `ml/tests/test_progress.py` (events written + parseable; existing
  11 tests stay green). Keep stdout prints unchanged (scripts grep them).
- **B — console scene**: `game/arena/console.gd` + `console.tscn`; `--selftest`
  flag: builds the UI headless, feeds a fixture progress file, asserts the
  chart parsed ≥2 generations and the ETA/status text updated, prints
  `CONSOLE SELFTEST OK`, exits 0. Adds a "TRAINING CONSOLE" line to
  `game/arena/README.md`. Must not touch arena.gd.
- **C — docs**: `docs/USAGE.md` (console command under "The arena" + gate
  row), `docs/harness/10-systems-map.md` (Arena & ML entry), `docs/harness/
  20-roadmap.md` (NOW item), `docs/README.md` index row for this doc.
- **Verifier**: runs `python3 -m pytest ml/tests -q`, `godot --headless --path
  game res://arena/tests/../console.tscn -- --selftest`, `arena.tscn --
  --selftest`, reports outputs verbatim; no edits.

**Outcome (2026-09-11):** A landed complete; B landed but unverified; C landed;
the verifier and a parallel freed-instance sweep died when the two workflows
exhausted the session quota. Verification, the jobs/speed/hint/strip controls,
the `--speed` lever (§5) and these docs were done inline. Standing rule since:
no background agents unless Ricardo asks (canon §12.39, CLAUDE.md).

## 3b. The cockpit tabs (v2, 2026-09-13)

Ricardo: *"Is the train_run included in arena console? can we run it there
instead? as well as manage active and deployed nets, and even put one against
the other for benchmarking (best of N)"* — and *"can we run this gpu training
in the console, as well?"*. The answer to all of it is yes; the right-hand pane
became a `TabContainer`.

| Tab | What it does | What it shells out to |
| --- | --- | --- |
| PROGRESS | the original fitness chart, match strip, gate verdict — now also paints a best-of-N | — (tails the feed) |
| RUNS | every folder under `ml/runs/`, newest first, with its `config.json`, gate verdicts and wall time. OPEN PROGRESS tails **that run's** feed; PROMOTE copies its gate-PASSING nets into `ml/serving` | `tools/train_run.sh --promote` |
| NETS | the registry: every key's versions, which one is the DEPLOYED pin, its gate checks. DEPLOY moves the pin (clearing the old one — one pin per key), RETIRE clears it, SET A / SET B arm the bench | writes `ml/serving/registry.json` directly |
| VERSUS | best-of-N between any two sides — a registry net, a weights file, or the native/scripted baselines — plus the BENCHMARK BROWSER over `ml/data/benchmarks/`, filtered by creature and by kind | `league versus` |
| RANK | the GLOBAL RANK: every net against every other, both sides on the same build. The table of the newest ladder verdict, and the button that writes a new one | `league ladder` |

Three switches in the roster panel decide what TRAIN and TRAIN ALL do:

- **isolated run** (on by default) routes TRAIN through `tools/train_run.sh
  --run-dir ml/runs/<date>__<key>-console__<knobs>`. The run gets its own
  registry seeded from the deployed one, its own weights and its own progress
  feed, so an experiment started from the console can never overwrite what the
  game serves. The console names the folder itself (hence `--run-dir`) so it
  knows where to tail from instead of guessing a timestamp.
- **GPU (PPO)** swaps the ES league for `ml/training/ppo.py` on CUDA
  (`tools/train_run.sh --ppo`), which needs `ml/.venv`. The first selected
  opponent becomes `--opp-build`.
- **bracket** (TRAIN ALL only) is the sweep's second gear
  (`tools/train_run.sh --tournament --all`). Unticked, the sweep trains every
  creature one way and assumes that was the right one; ticked, every method
  trains each creature and the candidates fight best-of-5 for that creature's
  pin — the TOURNAMENT button's bracket applied across the whole roster. The
  button reads `TRAIN ALL ⚔` while it is armed. PPO is one of the entrants, so
  the GPU tick does not apply. A single-creature TRAIN never brackets: that is
  the TOURNAMENT button, and it needs a chosen matchup.

### RANK — the global rank

VERSUS answers *is this net better than that one*. RANK answers *which net is
best, full stop* — Ricardo, 2026-09-14: *"a global rank for the all vs all,
where every model net compete for the top in a balance fight"*.

The word that carries the weight is **balance**. `league round-robin` fights
deployed nets across DIFFERENT builds, so its table ranks the creature — its
stats, its reach, its cooldowns — with the policy as a rounding error. A ranking
of NETS has to remove the body from the comparison, so `ml/training/ladder.py`:

1. puts **both sides on the same arena build**, making the policy the only
   variable — a bog_golem net driving a fen_boar is the point, not a mistake;
2. plays **both orientations** of every pairing with different seeds, because
   spawn position and the aim-noise stream are not symmetric between sides;
3. runs **every entrant against every other** in every arena — no seeding, no
   byes, no strength of schedule to correct for.

Entrants are every registry net with exported weights (every key, every version)
plus `native` and `scripted`, which are the floor the table is read against.
`pins only` narrows it to the deployed pin of each key; `every arena` replays
the whole ladder in every creature build — fairer, and far longer.

Scoring: 3 points to whoever wins more episodes in a pairing, 1 each if tied;
episode win rate; mean HP margin (how it won); and a Bradley-Terry strength
fitted over the whole episode matrix and printed on the Elo scale, which is
order-independent and stays meaningful when a pair never met. Every entrant gets
half a win and half a loss against a phantom of average strength, or an unbeaten
net would have no finite maximum-likelihood rating and the column would blow up.

### The benchmark browser

`ml/data/benchmarks/` accumulates for the life of the project and holds **two
schemas** that answer different questions:

| schema | written by | what it is |
|---|---|---|
| `arena.versus.v1` | `league versus`, and the bracket's own fights | one net against one other, best-of-N |
| `arena.tournament.v1` | `ml/training/tournament.py` | a whole bracket for ONE creature: entrants, table, champion, whether the pin moved |
| `arena.ladder.v1` | `ml/training/ladder.py` | the global rank: every net against every other, one row per entrant |

The history used to render both through the versus fields, so every bracket read
`? vs ?  0-0  ?`. Each schema now has its own row and its own detail panel, and
the list is filtered two ways (Ricardo, 2026-09-14: *"a better benchmark
interface, filtered by creature"*):

- **creature** — built from the folder, not from the roster, so a key nothing was
  ever benchmarked against is never offered as a filter that shows nothing. Each
  entry carries its count. A verdict's creatures are its bracket `key`, plus
  either side's registry spec (`bog_golem@v2`) and the arena `build` it played —
  which is what makes a `native`/`scripted` row filterable at all. A verdict with
  no creature at all (an older or hand-made file) still appears under *all
  creatures* rather than silently vanishing.
- **kind** — everything / head to head / brackets / global ranks.

Selecting a row puts that verdict in the panel above the list. Parsing is
incremental (name + mtime), so a filter click re-reads nothing.

`--selftest` covers all of it against fixtures under `user://console_selftest/`:
the gate never reads or writes the real registry, run folders or benchmarks.
It asserts the registry ordering, that DEPLOY moves the single pin and RETIRE
clears it, that a run folder's own feed is tailable, that PROMOTE is refused
while a run has no `summary.txt`, that both versus sides arm and a verdict
reads back, that the isolated/GPU run-folder names come out right, that
TRAIN ALL's two gears dispatch correctly — unticked the sweep's command line is
byte-for-byte what it was before the bracket existed, ticked it carries
`--tournament` plus the bracket knobs, and a single-creature run never brackets
— that the benchmark browser renders all three schemas (no row may ever read
`? vs ?` again), filters by creature and by kind, composes the two filters, and
keeps a creature-less verdict in the list, and that RANK shows the newest ladder
verdict in rank order and dispatches `--all-arenas` / `--deployed-only` only
when they are asked for.

## 4. Out of scope (v1)

In-process embedded arena view (SubViewport) — spawn a window instead;
replaying recorded JSONL episodes (needs a replayer — later); global-net
training UI (same contract, add later); loss curves for BC training when
`ml/training` grows a supervised path.

## 5. Speed & scaling — the diagnosis and the lever (2026-09-11)

**Ricardo:** "arena background doesn't need to load camera/hud headlessly, does
it? won't it slow things down? … is the arena training script using my gpu? as
i increase the number of jobs, it doesn't seem to accelerate much. it should be
able to become faster with more compute!"

Findings, from the code and his `fen_boar` progress file (v4/v5 runs):

1. **Camera/HUD:** training workers (`--fast --a …`) never build the Camera2D,
   HUD or darkness stack — `_spectate` is false for them. Only `--selftest`
   runs the spectator stack, deliberately, to gate the freed-body crash path.
2. **GPU:** nothing in the loop touches it. The trainer is numpy on a tiny MLP;
   every worker is Godot physics + GDScript (`nvidia-smi` shows no trainer
   process). The workload is CPU-bound by construction.
3. **The wall-clock cap:** fast mode was `physics_ticks_per_second = 240,
   time_scale = 4` — WALL-LOCKED at 4×. Every 4-episode match took ≥ 45 s
   (his file: every `duration_s` ≈ 45.6) no matter how idle the CPU was.
4. **The parallelism ceiling:** a generation is pop × opponents independent
   matches — 12 by default — so `--jobs 32` ran 12 processes and the other 20
   slots never existed. Hence "more jobs doesn't accelerate much".

The lever — `arena.gd --speed` (`_apply_speed`), threaded through league.py
(`--speed`, default `max`) and the console's speed picker:

| `--speed` | Mechanism | Same seeded 2-episode set | Result parity |
|---|---|---|---|
| `4` (old fast mode) | 240 Hz ticks × time_scale 4, wall-locked | 22.1 s | reference |
| `16` | 960 Hz ticks × time_scale 16 (+ `max_physics_steps_per_frame`) | 5.65 s | bit-identical |
| `max` | engine `--fixed-fps 60`: one 1/60 s tick per frame, no frame sleep, CPU-bound | **0.91 s** | bit-identical |

Concurrent `max` workers on the 20-core dev box (2-episode sets, ~88 s sim each):

| workers | wall | aggregate sim speed | match sets / min |
|---|---|---|---|
| 1 | 0.81 s | 109× | 74 |
| 4 | 0.92 s | 384× | 260 |
| 8 | 1.30 s | 543× | 369 |
| 12 | 1.49 s | 711× | 484 |
| 16 | 1.61 s | 873× | 595 |
| 20 | 2.04 s | 863× | 588 |

So one worker is ~24× the old fast mode and the box saturates near 16 workers
(≈ 70k episodes/hour vs the 3.8k/hour tech/32 quoted). Boot cost (~0.4 s) is
now a visible share of a match — prefer more episodes per match. Also moved the
projectile group tagging from `_process` to `_physics_process` so the
observation vector is tick-exact at every speed. `--speed max` without the
engine flag warns and falls back to 4× (there is no in-script fixed-fps API).

**Observed, not fixed:** in his runs and in the verification run the candidates
take 0 wins vs native fen_boar in every match — fitness moves only on the hp
margin (≈ −0.01). The strip makes this visible from generation 0. Next: an
opponent curriculum (scripted → past self → native) and/or stronger shaping
(tech/25 §4.2), now cheap to iterate at ~3 s per generation.
