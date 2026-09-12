# Dragon Heroes — Usage Manual (play, co-op, arena, training, dev)

> Everything you can run today, in one place. Deeper references:
> [game/arena/README.md](../game/arena/README.md) (arena),
> [tech/33](tech/33-p2p-coop.md) (co-op), [tech/32](tech/32-scaling-rl-training.md)
> (training at scale), [00-canon](00-canon.md) (decisions).

## Requirements

- **Godot 4.6+** on PATH (`godot --version` → 4.6.stable).
- **Python 3** with numpy + pytest (ML/content tooling).
- The sim server binary for world generation: `cmake -S sim -B sim/build && cmake --build sim/build -j` → `sim/build/libs/dh-server/dh-server`.
- Default renderer: gl_compatibility (safe everywhere). Vulkan HDR bloom is an
  opt-in: `tools/run_vulkan.sh` — **only on Ricardo's hardware** (a Vulkan
  window once crashed the dev's X; never auto-flip).

## Playing the game

```bash
godot --path game                # boots the main menu (640×360 pixel-perfect)
```

Menu → name your hunter → pick a class (Reaver / Emberkin / Frostbinder /
Gloam Mage / Veilblade) → **ENTER THE HUNT**. Saved hunters load automatically
(saves in `user://saves/`). **CO-OP (P2P)** opens the multiplayer lobby (below).
EN/PT-BR toggle in the menu and the Haven.

### Controls (keyboard + mouse)

| Input | Action |
|---|---|
| `WASD` / arrows | move |
| `LMB` / `Space` | attack (hold to keep swinging) |
| `Shift` / `RMB` | dodge dash (3 charges; brief i-frames + displacement) |
| `E` | class special (Whirlwind / Frost Nova / Fan of Knives) |
| `Q` | Shadow Rend (bestial slot — needs a skill stone) |
| `1–4` | class-tree skills (assign in CHARACTER → Skills) |
| `F` | Soul Snare — capture a creature below ~35% HP (fails enrage it) |
| `Z` | mount / dismount (combat dismounts you) |
| `C` / `Tab` | character panel (attributes, skills, pets, bag) |
| `K` | keybind card |

Attacks and skills **buffer** for 150 ms — presses just before a cooldown ends
still fire. Leveling heals to full. Death costs 25% of carried gold.

### Settings (title screen, bottom corners)

Bottom-left: **Language** (EN / PT-BR). Bottom-right, stacked: **MUSIC: ON/OFF**,
**SFX: ON/OFF**, **FIT** (integer pixels / fractional fill), **MODE** (windowed /
fullscreen). Everything persists in `user://settings.json` and applies at every
boot, including direct scene boots. Audio runs on two buses, `Music` and `SFX`
(created in code — there is no music track yet; the slice's sound is
synthesized effects, so MUSIC controls the bus future music will play on).
Volumes are also persisted (`audio.music_vol` / `audio.sfx_vol`, 0..1) for
anyone who wants quieter rather than silent.

### The hunt

Infinite seeded world (new map every hunt): 14 packs, three boss hunts —
Fenwitch Hag (pack 8), the Pyre Sovereign + Terravore Colossus legendary DUO
(pack 11 — fire + earth fields fuse into LAVA), and the Emberwing Matriarch
(pack 13). One hunt legendary per map (magenta minimap diamond). Loot: gear
with affixes, runes (skill modifiers), skill stones (unlock Q), Spirit
Essences (enchants), pets (snare them). The Haven between hunts: vendor,
forge, enchanter, chest, stables.

## Co-op (P2P, friends & LAN)

Menu → **CO-OP (P2P)** → one friend **HOST**s (share the LAN IP shown), up to
3 friends **JOIN** with that IP (port 7377 UDP) → **READY** → host **START
HUNT**. Everyone gets the same world; the host simulates; clients play as full
hunters. Internet: port-forward UDP 7377 or use Tailscale-style overlay.
Details + v1 simplifications: [tech/33](tech/33-p2p-coop.md).

## The arena (watch & train creature AI)

```bash
godot --path game res://arena/arena.tscn           # spectator (N/R/1-3/Q)
godot --headless --path game res://arena/arena.tscn -- --selftest   # CI gate
godot --path game res://arena/console.tscn         # training console (below)
```

**In-game:** the title menu's **ARENA** button opens the training console
directly (BACK returns to the menu) — no command line needed. Training runs
need the local Python stack (`ml/.venv` or system python3 + numpy); if it is
missing the console says so instead of failing silently.

Creatures, bosses and geared bounty-hunter builds fight 1v1; scripted baselines
or trained neural policies drive them. Full manual (all flags, roster,
cosmetics, training): **[game/arena/README.md](../game/arena/README.md)**.

### Training console

A windowed front-end for the ES trainer ([design/25](design/25-arena-training-console.md)).
It drives `python3 -m ml.training.league` for you and tails the trainer's
progress file `ml/data/progress/<key>.jsonl` (one JSON event per line).

| Control | What it does |
|---|---|
| **Roster** | pick the trainee (species key + build), tick opponents, set generations / pop / episodes / **jobs** (default = your core count) / **speed** (default `max`); a hint line states the parallelism ceiling (pop × opponents matches per generation), idle workers, and the pop that fills your cores |
| **Train / Stop** | spawns `league train …` as a child process; Stop kills it; the UI never blocks |
| **Progress** | current generation / candidate / match, matches done of total, ETA from observed match durations, a fitness chart (best + mean per generation, per-candidate dots), a per-match **score strip** coloured by opponent (`native@fen_boar_alpha 0.00` in its legend = no learning signal yet), the last gate result |
| **Gate** | runs `league gate` for the trainee → PASS / FAIL + the numbers |
| **Watch** | opens a windowed arena for ONE episode with the trainee's latest net (candidate version, else deployed) against a chosen opponent |

ES has no loss curve: **fitness** (candidate match score vs opponents, 0..1,
higher is better) is the metric, plus the gate's win-rates. Progress arrives
per match, so the chart moves long before a generation completes.

## Training policies (ML)

```bash
python3 -m ml.training.league roster                # list builds
python3 -m ml.training.league train --key fen_boar --build core.arena.fen_boar_alpha \
    --generations 20 --pop 16 --episodes 4 --jobs "$(nproc)"   # parallel workers
python3 -m ml.training.league gate --key fen_boar --build core.arena.fen_boar_alpha
```

**What to expect.** Every match runs at `--speed max` (default since
2026-09-11: CPU-bound, one core per worker, results bit-identical to the old
wall-locked 4× mode), so a 4-episode match set takes ~1–3 s instead of 45 s.
With the defaults (3 generations × 6 candidates × 2 opponents × 4 episodes,
`--jobs 1`) the CLI prints `[train:KEY] fresh net`, then within ~30 s per
generation the `[train:KEY] g0 candN fitness=..` lines and `g0 best=.. mean=..`,
ending `registered vN (candidate — run the gate)`. **Scaling rules:** a
generation is pop × opponents independent matches (12 by default) — that is the
most workers ever busy, so `--jobs` past it idles; raise `--pop` to use more
cores (a better ES gradient too) and set `--jobs` ≈ cores. Measured on the
20-core dev box: 1 worker ≈ 110× real time, 16 workers ≈ 870× aggregate
(≈ 70k episodes/hour; flat past 16). The GPU is not used anywhere in this loop
(numpy MLP + Godot physics/GDScript workers — tech/32); GPUs arrive with the
C++ `dh-env` tier. For live per-match progress use the console (above) — it
reads the same `ml/data/progress/<key>.jsonl` the trainer appends to.

Thousands of parallel episodes, the dh-env endgame, fleet runs:
**[tech/32](tech/32-scaling-rl-training.md)**.

## Distributing to friends (no Godot needed on their end)

```bash
tools/package_game.sh linux      # or: windows | all
# DH_FETCH_TEMPLATES=1 tools/package_game.sh all   # first time: fetch ~1 GB templates
```

Produces `builds/dragon-heroes-<platform>.zip`: the standalone game binary +
`dh-server` (worldgen — must sit next to the executable or worlds/co-op parity
break) + a LEIA-ME quickstart. Friends unzip and run. Windows packaging needs a
Windows `dh-server.exe` (mingw cross-build or CI). The game is open source
(code MIT / art CC BY-NC, business/32) — sharing builds is explicitly fine.

## The 3D view (experiment)

```bash
godot --path game res://prototype3d/hunt3d.tscn
```

Same world/art/data in perspective 3D ([design/22](design/22-3d-alternative-view.md));
the 2D view remains canon.

## Content & data workflows

Modern pixel-art/weekly-chapter review (isolated experimental branch):

```bash
python3 tools/review_living.py
```

Open the printed `index.html` locally to inspect the animation, emission,
artifact rarities, linked lore and VFX anatomy. This builds the candidate and
runs the C++ effect probe; it does not install the content into a Hunt.
Authoring/generation commands and remaining integration gates:
[tech/34](tech/34-living-content-pipeline.md). Direction and skill proposal:
[design/26](design/26-living-pixel-world.md).

```bash
python3 tools/validate_content.py      # the CI gauntlet for content packs
python3 -m genforge.pipeline.bestiary_gen --seed 2026   # regenerate bestiary data
python3 genforge/vfx_lab/auras/render.py                # re-render VFX previews
python3 -m pytest genforge/tests/ ml/tests/ -q          # python test suites
```

Rules: gameplay content is data (`content/`), validated in CI; IDs are
`pack.type.name` and never deleted, only deprecated. Arena roster:
`content/core/arena/builds.json` → sync to `game/arena/data/builds.json`.

## Dev gates (run before shipping anything)

| Gate | Command | Pass line |
|---|---|---|
| Menu boot | `godot --headless --path game res://prototype/tests/menu_probe.tscn` | MENU OK (asserts the main scene BUILT: MODE/FIT/ENTER/CO-OP/LANGUAGE buttons present) |
| Hunt boot ×3 | `godot --headless --path game res://prototype/main.tscn --quit-after 150` | no errors |
| World spawn | `godot --headless --path game res://prototype/tests/spawn_probe.tscn` | SPAWNTEST OK |
| World stream | `godot --headless --path game res://prototype/tests/stream_test.tscn` | STREAMTEST OK |
| Click test | `godot --headless --path game res://prototype/tests/click_test.tscn` | CLICKTEST OK ×16 |
| FX budget | `godot --headless --path game res://prototype/tests/fx_stress.tscn --quit-after 260` | FXSTRESS OK |
| Arena | `godot --headless --path game res://arena/arena.tscn -- --selftest` | ARENA SELFTEST OK |
| Console | `godot --headless --path game res://arena/console.tscn -- --selftest` | CONSOLE SELFTEST OK |
| Cosmetics | `godot --headless --path game res://arena/tests/cosmetics_test.tscn --quit-after 140` | COSMETICS OK |
| Co-op | `bash tools/mp_test.sh` | MP TEST OK |
| Content | `python3 tools/validate_content.py` | 0 problems |
| Python | `python3 -m pytest ml/tests/ genforge/tests/ -q` | all pass |
| Sim | `ctest --test-dir sim/build --output-on-failure` | all pass |

Notes: kill the game with `pkill -x godot` (never `pkill -f`); after adding a
`class_name` script run `godot --headless --path game --import` once;
`grep -c` exits 1 on zero matches — never chain gates with `&&`.

## Troubleshooting

| Symptom | Fix |
|---|---|
| Black/empty hunt window | build `sim/build` (dh-server) — worldgen shells out to it |
| Co-op can't connect | same LAN? UDP 7377 free? host firewall? use overlay for internet |
| `Script class X not found` | run `godot --headless --path game --import` once |
| Arena match crawls | add `--fast` to headless runs |
| ML: `godot not on PATH` | install/link Godot 4.6+ |
| X crash on Vulkan | expected on the dev box — stay on gl_compatibility (default) |
