# Dragon Heroes — Usage Manual (every command, verified)

> **Every command below was re-run on 2026-09-13** against this tree, except
> the ones marked *(not run here)* — long training runs, packaging that needs
> the ~1 GB export templates, Nakama's containers, and the Vulkan path that is
> Ricardo-only. Pass lines quoted in the gate table are the real output from
> that pass. Deeper references: [game/arena/README.md](../game/arena/README.md)
> (arena), [tech/33](tech/33-p2p-coop.md) (co-op),
> [tech/32](tech/32-scaling-rl-training.md) (training at scale),
> [00-canon](00-canon.md) (decisions).

## 0. Requirements and first-time setup

```bash
godot --version                      # 4.6.stable.official.89cea1439 here — 4.6+ required, on PATH
cmake -S sim -B sim/build -DCMAKE_BUILD_TYPE=Release && cmake --build sim/build -j
                                     # builds dh-server (worldgen), dh-effect-lab, libdh-env.so, the test binaries
godot --headless --path game --import   # run ONCE after adding/renaming a class_name script
```

- **Python 3** with numpy + pytest for content/ML tooling (system `python3` is enough).
- **PyTorch tier** (GPU PPO only) lives in its own venv: `ml/.venv/bin/python`
  (torch 2.6.0+cu124, CUDA available on the RTX 4050). The system `python3` has
  no torch — `python3 -m ml.training.ppo` fails with `ModuleNotFoundError`, by design.
- Default renderer is **gl_compatibility** (safe everywhere). Vulkan HDR bloom is
  opt-in via `tools/run_vulkan.sh` — **only on Ricardo's hardware**; a Vulkan
  window once crashed the dev X server, so nothing auto-flips to it.
- Kill a stuck run with `pkill -x godot` — never `pkill -f` (it kills the other
  session's training workers too).

## 1. Play the game

```bash
godot --path game                                   # main menu (640x360 pixel-perfect)
godot --path game res://prototype/main.tscn         # skip the menu, straight into a hunt
godot --path game res://prototype/ui/haven.tscn     # straight into the Haven
tools/run_vulkan.sh                                 # Ricardo only: same game, Vulkan + real HDR bloom (not run here)
```

Menu → name your hunter → pick a class (Reaver / Emberkin / Frostbinder / Gloam
Mage / Veilblade) → **ENTER THE HUNT**. Saved hunters load automatically (saves
in `user://saves/`, i.e. `~/.local/share/Dragon Heroes Codex/`). The menu also
offers **PLAY NEW CONTENT: LAIRS & LEGENDS** (§6), **CO-OP (P2P)** (§2),
**ARENA** (opens the training console, §4), a **LANGUAGE** toggle (EN / PT-BR)
and **OPTIONS** — a modal with MUSIC and SFX switches plus two volume sliders,
and the display MODE (windowed / fullscreen) and FIT (integer pixels /
fractional fill) controls. Everything persists in `user://settings.json` and is
applied at every boot, including direct scene boots.

### Controls

| Input | Action |
|---|---|
| `WASD` / arrows | move |
| `LMB` / `Space` | attack (hold to keep swinging) |
| `Shift` / `RMB` | dodge dash (3 charges, brief i-frames + displacement) |
| `E` | class special (Whirlwind / Frost Nova / Fan of Knives) |
| `Q` | Shadow Rend (bestial slot — needs a skill stone) |
| `1`–`4` | class-tree skills (assign in CHARACTER → Skills) |
| `F` | Soul Snare — capture a creature below ~35% HP (a failed snare enrages it) |
| `Z` | mount / dismount (combat dismounts you) |
| `C` / `Tab` | character panel (attributes, skills, pets, bag) |
| `K` | keybind card |
| `Esc` | back to the Haven |

Attacks and skills **buffer** for 150 ms. Leveling heals to full and refills
flasks. Death costs 25% of carried gold.

### The hunt

Infinite seeded world (new map every hunt): 14 packs, three boss hunts — the
Fenwitch Hag (pack 8), the Pyre Sovereign + Terravore Colossus legendary DUO
(pack 11, where fire and earth fields fuse into LAVA) and the Emberwing
Matriarch (pack 13). One hunt legendary per map (magenta minimap diamond).

## 2. Co-op (P2P, friends and LAN)

```bash
godot --path game                                   # menu -> CO-OP (P2P)
godot --path game res://mp/lobby.tscn               # straight to the lobby
bash tools/mp_test.sh                               # the gate: host + client on loopback
```

One friend **HOST**s and shares the LAN IP shown, up to 3 friends **JOIN** with
that IP (UDP 7377) → **READY** → host **START HUNT**. Everyone gets the same
world; the host simulates, clients play as full hunters. Over the internet:
port-forward UDP 7377 or use a Tailscale-style overlay. Details and v1
simplifications: [tech/33](tech/33-p2p-coop.md).

```bash
tools/nakama.sh up | status | logs | down | wipe    # self-hosted Nakama (docker; not run here)
```

## 3. The arena — watch fights

```bash
godot --path game res://arena/arena.tscn            # spectator (N next matchup, R rerun, 1-3 speed, Q quit)
```

A headless match set, exactly what training runs:

```bash
godot --headless --path game res://arena/arena.tscn -- \
    --a core.arena.dusk_revenant --b core.arena.fen_boar_alpha \
    --policy-a scripted --policy-b native \
    --episodes 4 --seed 7 --fast \
    --record-dir "$PWD/ml/data/episodes" --out /tmp/result.json
```

The fastest, deterministic form (results bit-identical to wall-locked speeds):

```bash
godot --headless --fixed-fps 60 --path game res://arena/arena.tscn -- \
    --a core.arena.fen_boar_alpha --b core.arena.cinder_drake \
    --policy-a scripted --policy-b native --episodes 4 --fast --speed max --out /tmp/r.json
```

Flags: `--a` / `--b` (build IDs), `--policy-a` / `--policy-b`
(`native` | `scripted` | absolute path to a weights JSON), `--episodes` (4),
`--seed` (2026), `--fast`, `--speed max|N`, `--spectate`, `--record-dir`,
`--out`, `--selftest`. Watch a trained net by copying its JSON into
`game/arena/data/` and passing `--policy-a res://arena/data/<file>.json`.

```bash
python3 -m ml.training.league roster                # the 17 build IDs (5 player, 7 creature, 4 boss, 1 duo)
godot --headless --path game -s res://arena/tools/dump_specs.gd -- --out "$PWD/ml/env/specs.json"
                                                    # re-export real combat stats to the C++ arena
```

## 4. Train creature AI

### The training console (the GUI for all of it)

```bash
godot --path game res://arena/console.tscn          # or the menu's ARENA button
```

The console is the cockpit for everything below — training, the registry and
the bench — so you rarely need the CLI unless you are scripting.

Left panel: trainee, opponents, generations, pop, episodes, jobs, speed (with a
parallelism hint) · **isolated run** (on by default — TRAIN goes through
`tools/train_run.sh`, so the experiment gets its own registry and cannot
overwrite what the game serves) · **GPU (PPO)** (trains on CUDA through
`ml/training/ppo.py` instead of the ES league; needs `ml/.venv`) · Train / Stop
/ Gate / Watch.

Right pane, four tabs:

| Tab | What you do there |
| --- | --- |
| PROGRESS | live fitness chart, per-match score strip, gate verdict, ETA — and it paints a best-of-N the same way |
| RUNS | every folder under `ml/runs/`, newest first, with its config, gate verdicts and wall time. OPEN PROGRESS tails that run's own feed; PROMOTE copies its gate-PASSING nets into `ml/serving` |
| NETS | the registry: every key's versions, which is the DEPLOYED pin, its gate checks. DEPLOY moves the pin, RETIRE clears it, SET A / SET B arm the bench |
| VERSUS | best-of-N between any two sides (a net, a weights file, or the native/scripted baselines). Verdicts accumulate in `ml/data/benchmarks/` |

> **Every knob, artifact and benchmark is documented in
> [tech/37](tech/37-ml-parameter-reference.md).** To experiment without
> touching the deployed registry, run through `tools/train_run.sh` (§4.4).

### ES league (CPU, numpy — the default trainer)

```bash
python3 -m ml.training.league roster
python3 -m ml.training.league init --key fen_boar
python3 -m ml.training.league train --key fen_boar --build core.arena.fen_boar_alpha \
    --generations 20 --pop 16 --episodes 4 --jobs "$(nproc)"
python3 -m ml.training.league gate --key fen_boar --build core.arena.fen_boar_alpha --episodes 4
python3 -m ml.training.league train-global \
    --builds core.arena.fen_boar_alpha,core.arena.dusk_revenant,core.arena.cinder_drake \
    --generations 3 --pop 6 --episodes 2
python3 -m ml.training.league round-robin --episodes 2
tools/train_all.sh                                  # every roster build, then gate each (not run here)
GENERATIONS=2 POP=4 EPISODES=2 tools/train_all.sh   # quick smoke of the same
```

Extra flags: `--sigma` (0.02), `--lr` (0.02), `--seed` (2026),
`--opponents "native@core.arena.gloamfen_stalker,scripted@core.arena.dusk_revenant"`,
`--progress-file`, `--speed max|N` (default `max`).

**Scaling.** A generation is `pop × opponents` independent matches — that is the
most workers that can ever be busy, so `--jobs` past it idles. Raise `--pop` to
use more cores. Measured on the 20-core box: 1 worker ≈ 110× real time, 16
workers ≈ 870× aggregate (≈ 70k episodes/hour, flat past 16). No GPU is involved
in this tier.

### PPO tier (GPU, PyTorch — needs `ml/.venv`)

```bash
ml/.venv/bin/python -m ml.training.ppo --key fen_boar \
    --build core.arena.fen_boar_alpha --opp-build core.arena.cinder_drake \
    --steps 2000000 --envs 32 --selfplay-every 4 --arch mlp --seed 0
ml/.venv/bin/python -m ml.training.ppo --key fen_boar --build core.arena.fen_boar_alpha \
    --opp-build core.arena.cinder_drake --arch gru --steps 500000
ml/.venv/bin/python -m ml.training.ppo --key duo --build core.arena.fen_boar_alpha \
    --opp-build core.arena.cinder_drake \
    --squad-a-buddy core.arena.gloam_wisp --squad-b-buddy core.arena.bog_golem
ml/.venv/bin/python -m ml.training.evolve --key fen_boar --build core.arena.fen_boar_alpha \
    --opp-build core.arena.cinder_drake --pop 4 --generations 3 --steps 500000
```

`--warm-start <registry JSON/npz>` initialises from an existing net,
`--exploit <build>` targets a specific opponent. VRAM is capped before the first
CUDA allocation by `ml/training/gpu_guard.py` (half the 6 GB card by default;
override with `DH_VRAM_FRACTION`). Training stays **local** on the 4050 — no
cloud GPU (canon §12.38).

### Isolated, cumulative runs (recommended for experiments)

```bash
tools/train_run.sh --all                                   # every creature build, isolated
tools/train_run.sh --key fen_boar --build core.arena.fen_boar_alpha --label sweep
GENERATIONS=200 POP=10 EPISODES=6 tools/train_run.sh --all  # the real budget
tools/train_run.sh --ppo --key cinder_drake --build core.arena.cinder_drake \
    --opp-build core.arena.fen_boar_alpha                   # GPU PPO in the same shape
tools/train_run.sh --resume ml/runs/<run>                   # continue a killed run
tools/train_run.sh --list                                   # every run, oldest first
tools/train_run.sh --promote ml/runs/<run>                  # copy PASSING nets into ml/serving
```

Each run gets `ml/runs/<date>__<keys>__<config>/` holding `config.json`,
its own `registry.json` (seeded from the deployed one, so runs are cumulative;
`--fresh` starts empty), `weights/`, `progress/`, `logs/` and `summary.txt`.
`ml/serving/` — what the game and console read — is untouched until you promote.
Under the hood it is `DH_SERVING_DIR`, honoured by league, ppo and evolve.

**Faster matches: the release trainer build.** Training runs matches through the
Godot *editor* binary, which is a debug build. `tools/build_arena.sh` exports a
release build that boots straight into the arena, verified bit-identical:

```bash
tools/build_arena.sh                                   # -> builds/trainer/dh-arena.x86_64
export DH_ARENA_BIN=$PWD/builds/trainer/dh-arena.x86_64
tools/train_run.sh --all                               # every match now uses it
```

It buys engine startup (4.01 s → 2.53 s per match, and a generation is 20
matches); per tick it changes almost nothing while the GDScript forward pass
dominates. Unset `DH_ARENA_BIN` to fall back to the editor binary. Rebuild it
after editing anything under `game/` — the export is a snapshot, so a stale
binary will train against stale rules.

**A long run is interruptible.** The ES trainer registers its net only when the
whole generation loop finishes, so it checkpoints the search (theta plus the RNG
stream) every `CHECKPOINT_EVERY` generations — 25 by default. Kill the run and
continue it with `tools/train_run.sh --resume ml/runs/<run>`: the folder records
its own keys, builds and knobs, so no other flags are needed, and it reuses the
same registry, weights and progress feed. Resuming is exact rather than
approximate — match seeds come from the generation index and the perturbation
RNG is restored — so the resumed run is the run that would have happened.

The run prints every generation as it closes — a bar, the fitness sparkline,
seconds per generation and an ETA — and a second window can watch the same run
without touching it:

```bash
tools/train_watch.py                        # the newest run under ml/runs/
tools/train_watch.py ml/runs/<run>          # a specific one
tools/train_watch.py --deployed             # a plain run against ml/serving
tools/train_watch.py <run> --once           # one frame, for a log or a gate
```

It shows per-key progress bars, the fitness trace, match throughput, gate
verdicts and an ETA for the **whole sweep** (a `--all` run trains every creature
key one after another, so the ETA counts the ones still queued). Ctrl-C closes
the window; the trainer keeps going. The theme lives in `tools/dh_term.sh` and
the dragon in `tools/art/dragon.txt`, regenerated by
`python3 tools/art/make_dragon.py`.

### Head-to-head: best-of-N (`league versus`)

```bash
python3 -m ml.training.league versus --best-of 9 --episodes 3 --jobs 9 \
    --a fen_boar --b native --a-build core.arena.fen_boar_alpha
python3 -m ml.training.league versus --best-of 5 \
    --a fen_boar@v6 --b fen_boar@deployed --a-build core.arena.fen_boar_alpha
```

Either side is `native`, `scripted`, a path to an `arena.policy.v1` JSON, or a
registry reference — `<key>` (its deployed pin, else the newest), `<key>@v3`,
`<key>@deployed`, `<key>@candidate`. Every round is a real arena match set, so a
verdict here means what a gate verdict means. All N rounds are played even after
the outcome is decided (a 5-4 and a 5-0 are different facts); `clinched_round`
gives the best-of reading. The verdict lands in `ml/data/benchmarks/` as schema
`arena.versus.v1`.

> A **neural** side makes rounds differ — aim noise and the observation delay
> consume the per-episode seed. Two **baseline** sides do not: scripted vs
> native returns the same result for every seed, so that pairing is a reference
> point, not a distribution.

### The C++ environment (dh-env)

```bash
python3 -c "import ml.env.dh_env as e; print(e.DhEnv, e.make_spec)"   # ctypes over sim/build/libs/dh-env/libdh-env.so
ml/.venv/bin/python -m ml.env.bench --seconds 5 --opp scripted        # throughput bench
```

`VecDhEnv` steps every arena in ONE call (`dh_env_step_many`), which is what the
PPO rollout uses. Measured on the dev box while a 20-job ES sweep had it at load
20: 32 envs 56.6k → 352.6k env-steps/s, 128 envs 55.0k → 638.8k, trajectories
bit-identical to the per-env path. With the envs cheap the rollout became bound
by one small GPU forward per tick, so `--envs` is now the throughput knob:
end-to-end PPO goes 5,834 → 56,288 steps/s from 32 to 512 envs, and is flat past
512 (hence the new `--envs 512` default). Each iteration line prints the
`roll=`/`upd=` split so you can see which half costs.

## 5. The world server (dh-server) directly

```bash
sim/build/libs/dh-server/dh-server --seed 42 --entities 500 --ticks 3000
sim/build/libs/dh-server/dh-server --seed 42 --dump-chunks 3 --out /tmp/chunks.json
sim/build/libs/dh-server/dh-server --seed 42 --dump-window "x,y,w,h" --out /tmp/window.json
sim/build/libs/dh-server/dh-server --lair-profile <profile>
sim/build/libs/dh-server/dh-server --living-preview --client-port <port> --token <n> \
    --profile <p> --mode <m> --lair <id> --seed 42 --entrance-chunk <chunk>
sim/build/libs/dh-server/dh-effect-lab <program.dhe>      # offline effect-program probe
```

The game shells out to this binary for worldgen; it must sit next to the
exported executable or worlds and co-op parity break.

## 6. New content — Lairs & Legends trial

```bash
godot --path game                                   # menu -> PLAY NEW CONTENT: LAIRS & LEGENDS
python3 tools/check_lair_journey.py                 # real world -> lair -> saved loot -> boss rush
python3 tools/check_lair_journey.py --capture       # same, with GL captures
python3 tools/check_living_preview.py               # the playable trial with isolated saves
python3 tools/check_living_preview.py --capture
python3 tools/review_living.py                      # build the weekly candidate + C++ effect probe, print an index.html
python3 tools/stage_living_preview.py               # compile authoring data -> C++ tables + Godot display pack
```

In the trial: Shrine Entrances start beside the bell doorway, `G` enters,
defeating Orun unlocks Boss Rush and earns saved artifacts, `L` opens lore,
`Q`→`E` tests Wet/Storm chains, `R` tests companion synergies. Scope and
verification: [tech/35](tech/35-playable-living-trial.md), pipeline:
[tech/34](tech/34-living-content-pipeline.md).

## 7. Content, art and data workflows

```bash
python3 tools/validate_content.py                       # CI gate for every content pack
python3 -m genforge.pipeline.bestiary_gen --seed 2026    # regenerate bestiary data
python3 genforge/vfx_lab/auras/render.py                # re-render VFX previews
python3 -m genforge.pipeline.mesh_gen --actor fen_boar --image <concept.png> --provider triposr
python3 -m pytest ml/tests/ genforge/tests/ -q          # python suites
```

Gameplay content is data (`content/`), validated in CI; IDs are
`pack.type.name` and are never deleted, only deprecated. The arena roster lives
in `content/core/arena/builds.json` and syncs to `game/arena/data/builds.json`.

## 8. Package and distribute (no Godot on their end)

```bash
tools/package_game.sh linux                     # or: windows | all   (not run here)
DH_FETCH_TEMPLATES=1 tools/package_game.sh all  # first time: fetch ~1 GB export templates
python3 tools/package_codex.py all              # Codex review packages (linux | windows | all)
python3 tools/package_codex.py all --require-clean
python3 tools/verify_package.py <package.zip>   # verifies contents incl. embedded Windows icons
python3 tools/smoke_codex.py <package.zip>      # exercise the exported PCK + native helper
python3 tools/build_app_icon.py                 # regenerate PNG + Windows ICO sizes
python3 tools/install_linux_launcher.py         # desktop launcher + icon association
```

Output: `builds/dragon-heroes-<platform>.zip` (mainline) or
`builds/codex/dragon-heroes-codex-<platform>.zip` — the game binary, `dh-server`
and a LEIA-ME quickstart. Code is MIT, art CC BY-NC (business/32): sharing
builds is explicitly fine.

## 9. The 3D experiments

```bash
godot --path game res://prototype3d/hunt3d.tscn              # 2D world/art/data in perspective 3D (design/22)

# rebirth/ — separate engine spikes, own git repo (rebirth/docs/02-status.md)
REBIRTH_SELFTEST=1 godot --headless --fixed-fps 60 --path rebirth/godot3d        # REBIRTH3D OK
godot --path rebirth/godot3d                                                     # play the 3D slice
cmake -S rebirth/native -B rebirth/native/build -DCMAKE_BUILD_TYPE=Release && cmake --build rebirth/native/build -j
rebirth/native/build/rebirth-native --sim-only --verify                           # REBIRTH-NATIVE OK
ctest --test-dir rebirth/native/build
python3 rebirth/assets/tools/gen_assets.py --all-placeholders --stage godot3d native unreal
```

The 2D view remains canon; Unreal is code-complete but uncompiled (no engine on
this box — `rebirth/unreal/INSTALL.md`).

## 10. Dev gates — run ALL before shipping anything

Every row below was run on 2026-09-13 and printed exactly this.

| Gate | Command | Verified pass line |
|---|---|---|
| Menu boot | `godot --headless --path game res://prototype/tests/menu_probe.tscn` | `MENU OK — 12 buttons + OPTIONS screen (2 volume sliders, MUSIC/SFX/MODE/FIT/BACK), 2 fields, SFX bus mutes + restores, settings survive a language save, script compiled` |
| Hunt boot ×3 | `godot --headless --path game res://prototype/main.tscn --quit-after 150` | boots and quits 0. **Known flake:** roughly one run in four ends with 5 `RID allocations … were leaked at exit` lines (a MultiMesh + Mesh + Material + Shader, plus `1 resources still in use`). Exit-time only, no gameplay effect; logged in the roadmap polish backlog. No other scene shows it |
| World spawn | `godot --headless --path game res://prototype/tests/spawn_probe.tscn` | `SPAWNTEST OK — creatures=82 nearest=191 px streaming=true` |
| Distant encounters | `godot --headless --path game res://prototype/tests/residency_probe.tscn` | `RESIDENCY OK` (worst_step_ms=0.514) |
| Stream recovery | `godot --headless --path game res://prototype/tests/stream_recovery.tscn` | `STREAM RECOVERY OK peak_chunks=49 worst_apply_ms=0.858` |
| UI / character renewal | `godot --headless --path game res://prototype/tests/renewal_probe.tscn` | `RENEWAL OK — action release, movement, VFX recycling, portrait/nickname save, fresh hunter isolation, visibility and actual Haven return` |
| World stream | `godot --headless --path game res://prototype/tests/stream_test.tscn` | `STREAMTEST OK worst_apply=0.92ms (budget 2ms / hard 4ms) window=30 chunks` |
| Click test | `godot --headless --path game res://prototype/tests/click_test.tscn` | `CLICKTEST DONE — ALL PASS` |
| Hunt level-up | `godot --headless --path game res://prototype/tests/level_up_probe.tscn` | `LEVEL UP OK — real kills refresh stats/HP/HUD/dodges/flasks; party parity; no gear heal, duplicate refill, build reroll or revival` |
| FX budget | `godot --headless --path game res://prototype/tests/fx_stress.tscn --quit-after 260` | `FXSTRESS OK ribbons_peak<=40(40) lights_peak<=32(32) telegraphs_peak<=24(20) labels_peak<=48(48) nodes_created_after_warmup=0 draws<120(0) frame_ms<16.6(2.19)` |
| Escape to Haven | `godot --headless --path game res://prototype/tests/esc_probe.tscn` | `ESC OK — returned to haven.tscn (static mem 99 -> 46 MB)` |
| Flasks | `godot --headless --path game res://prototype/tests/flask_probe.tscn` | `FLASK OK — drink heals 40% over 2s, charge spent, 6 kills rekindle, empty refuses, haven refills` |
| Repopulation | `godot --headless --path game res://prototype/tests/repop_probe.tscn` | `REPOP OK — field restocked 0 -> 10 creatures across 3 species` |
| Arena | `godot --headless --path game res://arena/arena.tscn -- --selftest` | `ARENA SELFTEST OK — 4 matchups, damage flowed, no orphan proxies, HUD 4134 frames` |
| Training console | `godot --headless --path game res://arena/console.tscn -- --selftest` | `CONSOLE SELFTEST OK — 2 generations, 8/12 matches, ETA 1:20, chart draws 2, hint '12 matches/gen (pop 6 × 2 opp) · jobs 20 · 20 cores — 8 workers idle: pop 10 fills them'` |
| Cosmetics | `godot --headless --path game res://arena/tests/cosmetics_test.tscn --quit-after 140` | `COSMETICS OK` |
| Lair journey | `python3 tools/check_lair_journey.py` | `LAIR JOURNEY OK: earned_artifacts=2, entrances=1, fps=60.0, lair_unlocks=1, rush_round=2.0, world_return_preserved=True` |
| Co-op | `bash tools/mp_test.sh` | `MP HOST OK` + `MP CLIENT OK — 10 snapshots received` + `MP TEST OK` |
| Content | `python3 tools/validate_content.py` | `content OK: 46 definitions across 11 types, 5 registries, 0 problems` |
| Python | `python3 -m pytest ml/tests/ genforge/tests/ -q` | `116 passed in 5.44s` |
| Sim (C++) | `ctest --test-dir sim/build --output-on-failure` | `100% tests passed, 0 tests failed out of 4` (sim, living, lair, lair-profile) |

Longer soaks and capture scenes, run when the area changes:

```bash
godot --headless --path game res://prototype/tests/mem_soak.tscn --quit-after 3000   # MEMSOAK lines: mem must plateau
godot --path game res://prototype/tests/vfx_showcase.tscn        # windowed VFX catalog
godot --path game res://prototype/tests/vfx_iso.tscn             # one effect in isolation
godot --path game res://prototype/tests/ui_capture.tscn          # UI reference frames
godot --path game res://prototype/tests/residency_capture.tscn   # distant-encounter captures
godot --path game res://prototype/tests/renewal_capture.tscn     # renewal captures
```

Notes: `grep -c` exits 1 on zero matches — never chain gates with `&&`, use `;`.
Headless for gates, windowed only for captures.

## 11. Troubleshooting

| Symptom | Fix |
|---|---|
| Black or empty hunt window | build `sim/build` — worldgen shells out to `dh-server` |
| `Script class X not found` | `godot --headless --path game --import` once |
| `ModuleNotFoundError: torch` | use `ml/.venv/bin/python` for the PPO tier; the ES league needs only system numpy |
| Co-op cannot connect | same LAN? UDP 7377 free? host firewall? use an overlay for internet play |
| Arena match crawls | add `--fast` (and `--speed max`) to headless runs |
| `godot: command not found` | install Godot 4.6+ or put it on PATH |
| X crash on Vulkan | expected on this box — stay on gl_compatibility; `tools/run_vulkan.sh` is Ricardo-only |
| Something hangs | `pkill -x godot` only, never `pkill -f` (it would kill training workers) |
