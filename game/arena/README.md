# The Arena — how to use it

Watch creatures and geared builds fight, train neural policies against them, and
log every episode for behavioral cloning. Full design rationale:
[docs/design/23](../../docs/design/23-arena-and-self-play.md) · canon §9/§12.35.

---

## 1. Watch a fight (30 seconds)

```bash
godot --path game res://arena/arena.tscn
```

A window opens on the arena: two fighters from the roster rotation walk in and
fight to the death (or the 90 s clock — higher HP% wins). When a match set ends,
the next matchup from the rotation loads automatically.

| Key | Action |
|---|---|
| `N` | skip to the next matchup |
| `R` | restart the current matchup |
| `1` / `2` / `3` | 1× / 2× / 4× speed |
| `Q` | quit |

The top bar shows each fighter's **name · policy** and HP. Policies you will see:
`native` (the creature's built-in AI), `scripted` (the utility baseline),
`neural:<file>` (a trained net — once you train one, §4).

> Vulkan users: run via `tools/run_vulkan.sh` if you want real HDR bloom;
> default gl_compatibility already shows the full layered look.

---

## 2. Run a headless match set (what training runs)

```bash
godot --headless --path game res://arena/arena.tscn -- \
    --a core.arena.dusk_revenant --b core.arena.fen_boar_alpha \
    --policy-a scripted --policy-b native \
    --episodes 4 --seed 7 --fast \
    --record-dir "$PWD/ml/data/episodes" \
    --out /tmp/result.json
```

Training's fastest form — CPU-bound and deterministic (results bit-identical to
the wall-locked modes; measured 2026-09-11: a 2-episode set in 0.9 s vs 22 s):

```bash
godot --headless --fixed-fps 60 --path game res://arena/arena.tscn -- \
    --a core.arena.fen_boar_alpha --b core.arena.fen_boar_alpha \
    --policy-a scripted --policy-b native --episodes 4 --fast --speed max --out /tmp/r.json
```

| Flag | Default | Meaning |
|---|---|---|
| `--a`, `--b` | — | build IDs from the roster (§3) |
| `--policy-a/-b` | build's own default | `native`, `scripted`, or a path to a weights JSON (§4) |
| `--episodes` | 4 | episodes in the set (spawn sides alternate) |
| `--seed` | 2026 | match RNG (gear rolls, policies, spawn jitter) |
| `--level` | 20 | `Session.level` for creature power scaling + item ilvl |
| `--time-limit` | 90 | seconds per episode; timeout → higher HP% wins |
| `--fast` | off | faster than real time (the headless training mode); the rate is `--speed` |
| `--speed` | 4 | with `--fast`: `N` = WALL-LOCKED N× (60·N Hz ticks × time_scale N, same 1/60 s tick — never faster than N× however idle the CPU); `max` = CPU-bound, one tick per frame — needs the ENGINE flag `--fixed-fps 60` before `--` (league.py passes it; without it the arena warns and runs 4×) |
| `--record-dir` | off | write obs+action JSONL per episode here |
| `--out` | off | write the match-set summary JSON here |
| `--selftest` | — | run the built-in CI gate instead (§6) |

Output: one `ARENA RESULT a=… b=… wins_a=N wins_b=N draws=N` line per set, plus
`--out` JSON with per-episode `winner / duration_s / hp_a / hp_b / dmg_taken_*`.

Recorded episodes (`--record-dir`) are JSONL: a `meta` line, one `step` line per
fighter per 30 Hz sample (`obs` = the exact 31-float `arena.obs.v1` vector the
policy saw + the action it emitted), and a `result` line. This is the R0
behavioral-cloning dataset (canon §9).

---

## 3. The roster: builds, bounty hunters, cosmetics

Roster data: canonical `content/core/arena/builds.json` (CI-validated by
`tools/validate_content.py`), runtime snapshot `game/arena/data/builds.json` —
**edit the content copy and re-sync**: `cp content/core/arena/builds.json game/arena/data/`.

List what's available:

```bash
python3 -m ml.training.league roster
```

Three kinds of builds:

- **player** — a full bounty-hunter loadout: `class_id`, `attributes`,
  `equipment` (slot/base/rarity/quality — rolled fresh per match by seed),
  `runes`, `learned` + `loadout` (skill-tree node IDs from
  `game/prototype/data/skill_trees.json`), optional `pet`, and `cosmetics`.
- **creature** — a bestiary species by `bundle` (see
  `game/prototype/data/bestiary_normal.json`) + optional elite `affix`
  (Brutal/Swift/Fiery/Bulwark).
- **boss** — a prototype `chassis`: `boss` (Matriarch), `hag`, `pyre`,
  `colossus`.

Cosmetics (presentation only): `"cosmetics": {"aura": …, "necklace": …,
"weapon": …}` with elements `fire frost storm venom umbral blood`. The necklace
is the Grand-Chase-style 3-bead orbit; the weapon glow pulses on every attack.

Default policy per build: `"policy": "native" | "scripted"`. Players have no
native mind — they fall back to `scripted`.

---

## 4. Train policies (per-species nets + the global net)

Requires: `python3` with numpy, `godot` on PATH. Everything runs real matches
through the headless arena at `--speed max` (default since 2026-09-11): a
4-episode match set takes ~1–3 s boot included, where the old wall-locked mode
took 45 s. Nothing here uses the GPU — workers are Godot physics + GDScript and
the trainer is numpy on a tiny MLP — so throughput = cores × per-core speed.

**Training console** (the GUI for everything below — roster, jobs/speed, live
progress, fitness chart, per-match score strip, gate, watch; docs/design/25):

```bash
godot --path game res://arena/console.tscn
```

```bash
# create + register a fresh net for a species/build key
python3 -m ml.training.league init --key fen_boar

# train it (ES: perturb candidates, fight them, keep what wins)
python3 -m ml.training.league train --key fen_boar \
    --build core.arena.fen_boar_alpha --generations 3 --pop 6 --episodes 4
# scale: --jobs N runs N matches at once, but a generation is only pop × opponents
# matches (12 here) — raise --pop to use more cores; --speed max|N (default max)
python3 -m ml.training.league train --key fen_boar --build core.arena.fen_boar_alpha \
    --generations 10 --pop 10 --episodes 4 --jobs 20

# the eval gate: scripted suite + native suite + past-policy ladder.
# PASS → deployed. FAIL → fleet stays on the previous pin (by design).
python3 -m ml.training.league gate --key fen_boar \
    --build core.arena.fen_boar_alpha --episodes 4
```

- **Per-species nets** (`--key fen_boar`): one net per creature type — the
  fine-tuned "species brain".
- **The global net** (`train-global`): one weight set with an embedding row per
  content ID, evaluated across many builds so *every* episode updates the same
  network:

  ```bash
  python3 -m ml.training.league train-global \
      --builds core.arena.fen_boar_alpha,core.arena.dusk_revenant,core.arena.cinder_drake \
      --generations 3 --pop 6 --episodes 2
  ```

- Custom opponents: `--opponents "native@core.arena.gloamfen_stalker,scripted@core.arena.dusk_revenant"`.
- Artifacts: weights + registry in `ml/serving/` (`registry.json` holds versions,
  lineage, eval reports), episodes in `ml/data/episodes/` (both gitignored).

**Fight with a trained net** (headless or spectator-observable):

```bash
godot --headless --path game res://arena/arena.tscn -- \
    --a core.arena.fen_boar_alpha --b core.arena.fenwitch_hag \
    --policy-a "$PWD/ml/serving/weights/fen_boar_v2.json" --policy-b native \
    --episodes 4 --fast --out /tmp/r.json
```

(Headless because policies load from absolute paths; to *watch* a net, copy its
JSON into `game/arena/data/` and pass `--policy-a res://arena/data/fen_boar_v2.json`.)

Fairness is baked in (canon §9 §6): every policy plays with 150–250 ms
observation delay, aim noise, and a 6-commits/s burst cap — what you watch is
what training optimized.

---

## 5. How matches actually work (reading what you see)

- The ring is a bounded disc — the pale rim is the wall. Fields (fire/earth/
  mire) tick inside it; **fire + earth fields fuse into LAVA** (the Duologue).
- Creature windups show amber danger rings; dodge through them. Scripted and
  neural policies dodge with reaction delay, not telepathy.
- Builds fight with their real kits: runes proc, class charges build and spend,
  pets assist, statuses (Bleed/Ignite/Chill/Expose/Stagger) all apply.
- Balance is uncalibrated — some matchups are stomps. That's signal for the
  league, not a bug; fitness includes HP-margin shaping.

---

## 6. CI gates

```bash
godot --headless --path game res://arena/arena.tscn -- --selftest        # ARENA SELFTEST OK
godot --headless --path game res://arena/console.tscn -- --selftest      # CONSOLE SELFTEST OK
godot --headless --path game res://arena/tests/cosmetics_test.tscn --quit-after 140  # COSMETICS OK
python3 -m pytest ml/tests/ -q                                          # 18 passed
python3 tools/validate_content.py                                       # content OK
```

## 6b. Cost and determinism (measured 2026-09-13)

Two facts anyone touching this code needs, so nobody has to go to
`docs/tech/37-ml-parameter-reference.md` to learn them the hard way.

**The neural forward pass is ~93% of the arena tick.** Measured by two-point
slope (same matchup at two `--time-limit` values, so startup cancels):

| Matchup | µs per tick |
|---|---|
| native vs native | ~250–380 |
| scripted vs scripted | ~340–630 |
| neural vs native | ~2,540 |
| neural vs neural | ~4,740–4,950 |

One neural side costs ~2,200 µs/tick for 7,744 multiply-adds. `_forward` in
`neural_policy.gd` is therefore written flat — weights in one
`PackedFloat64Array` indexed `o * n_in + j`, not an `Array` of `Array`. The
nested version cost 1.74× more because every element went through a Variant.
**Do not "tidy" it back into nested arrays.** Physics, projectiles and fields
together are the other 7%; optimising them buys almost nothing.

**The global random stream must stay seeded.** Godot randomises it at startup,
and gameplay draws from it (`creature.gd` wander, `hag.gd` retreat,
`projectile.gd` volley desync). `_start_episode()` seeds it from the match seed,
rotation index and episode index. Without that line the same `--seed` produces
different damage and durations every run — winners stay stable, so win-rate
checks do not catch it, but ES fitness includes an hp term and was carrying
~11% noise. **If you add randomness to arena gameplay, draw it from a seeded
source or it will silently poison training.**

For faster matches, `tools/build_arena.sh` exports a release build that boots
straight into the arena (startup 4.01 s → 2.53 s, bit-identical results); point
training at it with `DH_ARENA_BIN`.

## 6c. `--serve`: one engine, many matchups

Booting the engine costs more than most fights do, so training does not start a
Godot per match. `--serve` boots once and then takes matchups as JSON lines on
stdin:

```bash
printf '%s\n%s\n' \
  '{"a":"core.arena.dusk_revenant","b":"core.arena.gloam_wisp","policy_a":"scripted","policy_b":"scripted","episodes":2,"time_limit":45,"seed":77,"speed":"max","out":"/tmp/r.json"}' \
  '{"quit":true}' \
| godot --headless --fixed-fps 60 --path game res://arena/arena.tscn -- --serve --fast --speed max
```

It answers `ARENA SERVE READY` once booted and `ARENA SERVE DONE <path>` after
each matchup; the result still goes to the file named in the request, so nothing
downstream changed. `ml/training/league.py` keeps a pool of these, one per job.

**Every per-match field is re-read on each request** (`_serve_accept`). A worker
that kept a stale episode count or time limit would produce results that
silently disagree with a one-shot run — which is the whole risk of reusing an
engine, and why `ml/tests/test_arena_pool.py` sends the same matchup first and
last in a batch and demands the one-shot result for both.

Two things that will bite you here:

- `OS.read_string_from_stdin()` is **line oriented and strips the newline**.
  Code that waits for a `"\n"` hangs on the first request.
- Godot flushes stdout per print in debug builds but **not in release**, so a
  release export's `ARENA SERVE READY` sits in the C buffer forever. That is
  what `run/flush_stdout_on_print=true` in `project.godot` is for — do not
  remove it.

**The arena runs physics at 60 Hz and stays there.** Canon's sim target is
30 Hz and halving the tick rate would halve the cost, but Ricardo decided
2026-09-13 to keep 60 "as to be fully capable". It is a deliberate choice, not
an oversight — do not "optimise" it.

## 7. Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `arena: unknown build(s)` | typo in the build ID — `league roster` lists valid ones; or the snapshot is stale (`cp content/core/arena/builds.json game/arena/data/`) |
| `NeuralPolicy: obs_dim mismatch` | weights JSON from an old schema — re-export from `ml/training/policy_net.py` |
| Matches take forever | you forgot `--fast` (headless runs real-time without it); or `--speed max` without the engine flag `--fixed-fps 60` — the arena warns and runs the wall-locked 4× |
| `--jobs` does not speed training up | a generation is pop × opponents matches — that is the most workers ever busy (the console's hint line states it); raise `--pop`, and make sure `--speed max` is in effect (league.py default) |
| A trained net behaves like the built-in AI | the weights path did not load — the arena resolves relative paths against `res://`, so pass an ABSOLUTE path, and check stderr for `NeuralPolicy:` |
| `godot: command not found` | install Godot 4.6+ or add it to PATH |
| New global class not found after editing arena scripts | run `godot --headless --path game --import` once |
