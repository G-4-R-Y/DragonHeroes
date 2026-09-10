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

| Flag | Default | Meaning |
|---|---|---|
| `--a`, `--b` | — | build IDs from the roster (§3) |
| `--policy-a/-b` | build's own default | `native`, `scripted`, or a path to a weights JSON (§4) |
| `--episodes` | 4 | episodes in the set (spawn sides alternate) |
| `--seed` | 2026 | match RNG (gear rolls, policies, spawn jitter) |
| `--level` | 20 | `Session.level` for creature power scaling + item ilvl |
| `--time-limit` | 90 | seconds per episode; timeout → higher HP% wins |
| `--fast` | off | 240 Hz ticks × time_scale 4 (same 1/60 s resolution, 4× wall speed) |
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
through the headless arena — expect ~10–20 s per match set.

```bash
# create + register a fresh net for a species/build key
python3 -m ml.training.league init --key fen_boar

# train it (ES: perturb candidates, fight them, keep what wins)
python3 -m ml.training.league train --key fen_boar \
    --build core.arena.fen_boar_alpha --generations 3 --pop 6 --episodes 4

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
godot --headless --path game res://arena/tests/cosmetics_test.tscn --quit-after 140  # COSMETICS OK
python3 -m pytest ml/tests/ -q                                          # 10 passed
python3 tools/validate_content.py                                       # content OK
```

## 7. Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `arena: unknown build(s)` | typo in the build ID — `league roster` lists valid ones; or the snapshot is stale (`cp content/core/arena/builds.json game/arena/data/`) |
| `NeuralPolicy: obs_dim mismatch` | weights JSON from an old schema — re-export from `ml/training/policy_net.py` |
| Matches take forever | you forgot `--fast` (headless runs real-time without it) |
| `godot: command not found` | install Godot 4.6+ or add it to PATH |
| New global class not found after editing arena scripts | run `godot --headless --path game --import` once |
