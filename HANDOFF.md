# Handoff — 2026-09-22: the build merge closes the cleanup arc

**Read this first, then `docs/harness/README.md` → `10-systems-map.md` →
`20-roadmap.md` (the one demand ledger) → `21-work-journal.md` (the evidence).**

> **Everything dated before 2026-09-22 in this file is history, kept verbatim.**
> In particular, any older section that tells you to run `tools/package_codex.py`,
> `tools/smoke_codex.py`, `tools/profile_codex.py` or to look in `builds/codex/`
> is **superseded by R77** — those paths no longer exist. The current commands
> are in `docs/USAGE.md` §8.

## Where the tree is

`master` at **25f32f8**, working tree clean except two untracked notes of
Ricardo's own (`prompts queue.txt`, `sprites prompt.md`). **54 commits are
unpushed** — `origin/master` is still at `b622aa6` (2026-09-12). R17 (push
everything, remote equality) is still open.

Commits this session, newest first:

| commit | what |
|---|---|
| `25f32f8` | **R77** — one packager, one build, the zips finally ship the real client |
| `3fd8ed3` | **R75** — the repo stops committing its own build trees |
| `871bcc6` | R60 — the console captures committed with the fix |
| `53bbd1c` | **R76** — the banner loses its hallucinated dragon head |
| `3ff7de7` | **R44/R61/R74** — bosses roam the open map, and up to three may share it |
| `246a6a5` | the parallel session's living-world + residency tree lands |

## What R77 changed that you will trip over

1. **There is exactly one packager: `python3 tools/package_build.py all`**
   (`linux | windows | all`). It was `package_codex.py`. It won because it passes
   an explicit path to `--export-release`, which overrides the preset — the very
   drift that had `builds/dragon-heroes-*.zip` shipping a **2026-09-12 client for
   ten days**.
2. `tools/package_game.sh` is a thin wrapper now; the old body is commented out,
   not deleted. Its only remaining live job is
   `DH_FETCH_TEMPLATES=1 tools/package_game.sh all` on a fresh machine (~1 GB of
   export templates).
3. Renames: `smoke_codex.py` → `smoke_package.py`, `profile_codex.py` →
   `profile_client.py`, `--codex-smoke` → `--package-smoke`, `--codex-profile` →
   `--client-profile`.
4. **The save directory moved** from `Dragon Heroes Codex` to `Dragon Heroes`.
   `game/tools/user_dir_migration.gd` is the FIRST autoload and copies the old
   directory across additively — it never clobbers a file and never deletes the
   old one. Verified against Ricardo's real saves (88 files copied, old dir
   intact). If you add an autoload, it stays first.
5. Binaries are `dragon-heroes.x86_64` / `dragon-heroes.exe`. `builds/codex/` and
   `sim/build-codex-windows/` are gone (~365 MB). The **in-game CODEX** (the
   effects/affix registry, canon §12.12) is untouched — same word, unrelated.
6. The Windows helper resolver is `helper_candidates()`: a fresh cross-build
   always outranks `builds/prebuilt/windows/dh-server.exe`. Never reverse that
   order or the cache ships stale code.

Last verified package run: EXIT=0, every gate OK, client dated 2026-09-22
05:00/05:01, `lair journey fps=60.0 frame_cpu_ms=0.325`. Log:
`genforge/candidates/packaging/r77-merge-build.log`.

## Two findings logged, neither a regression, neither fixed

- **Windows ships no GDExtension.** `game/addons/dh_godot/dh_godot.gdextension`
  declares only `linux.debug.x86_64` / `linux.release.x86_64`, so Godot has
  nothing to put in the Windows zip; `game/arena/neural_policy.gd` falls back to
  GDScript, so Windows plays. Pre-existing platform gap, older than R77.
- **The mingw tree emits a misnamed artifact**:
  `sim/build-windows/libs/dh-godot/libdhgodot.linux.template_debug.x86_64.dll`
  — says linux, says debug, is a `.dll`. Nothing consumes it today.
- Also unexplained: the Windows export prints
  `Project export for preset "Windows Desktop" completed with warnings. at:
  _fs_changed (editor/editor_node.cpp:1353)`. Not investigated.

## Where to pick up

The ledger order in `20-roadmap.md` §2 NOW, unchanged:

1. **R55 residual / R59** — port `creature.gd::_separate(delta)` into `sim/`
   (the arena separates overlapping bodies, the sim does not — that is why
   dh-env fights run ~1.8× longer at identical per-channel damage, and why
   creatures stand on top of Ricardo where he cannot hit them). Then re-run the
   parity matrix at **64 episodes** and retrain:
   `STEPS=60000000 PLATEAU_UPDATES=80 PLATEAU_DELTA=0.02 PLATEAU_MIN_STEPS=20000000
   CLONE=heuristic tools/train_all.sh --ppo`.
2. **R57** — captured-species variety, then boss mini-pets that level with the
   player (unblocks R65).
3. **R62 → R71** — potion enchanting, skill design + cooldown cues, pet
   levels/skills, item scaling, kill-streak sky chest, multi-boss events,
   DRAGON COUNCIL, bot mercenaries, questline themes. Largest last.
4. **R72(b)** — the boss fight as the Meshy→Blender→Unreal concept test; the
   judgement is already written in `rebirth/docs/02-status.md` §3.1 (the real
   gap is Blender, not Meshy or Unreal).
5. **R58** (reproduce the potion HoT complaint in a real hunt before touching
   it), **R51**, **R47**, **R48**, **R49**, **R46**.

**Owed to Ricardo, still:** the `builds.json` kit-range unit mix (cinder_drake
`bolt_volley range 10.0` and `field_cast 9.0` against bog_golem's `112.0` =
`7.0 * TILE`; the 7–10 values were almost certainly meant as tiles) — that is a
balance decision plus a full retrain, so it is his call, not the harness's.

**Blocked, do not guess:** 13b, the local image-gen repo, which comes from
Ricardo *after* the rest of the roadmap and is to be adapted behind the
`ImageBackend` seam.

## Standing rules that bit this session

- Never `git add -A` across the tree; stage explicit paths and check
  `git show --stat` after every commit.
- Comment out superseded code with a provenance note; never delete it.
- Kill Godot with `pkill -x godot`, never `pkill -f`. Never launch a Vulkan
  window; headless, or windowed `opengl3` on `DISPLAY=:1`.
- Docs update in the same change as the work. Canon first.
- Another session may share this tree: check timestamps and
  `git status --porcelain` before deleting anything you did not create. That
  check is what made deleting `builds/codex/` safe.

# Urgent playtest recovery — 2026-09-13

## 2026-09-19 (later) — R52 hifi sprite generator BUILT; R50 converged run DONE (2/7); R55 found

- **R52 built, offline, no API called.** `genforge/hifi/` — verbatim prompt
  contract pinned to `sprites prompt.md`; `process` = alpha → grid → palette
  → emissive → dedither → Ink-Hold outline → normal (emissive packed in
  B<128); `scorecard` gate grades ANY image (9 hard / 4 advisory checks);
  `write_bundle` on the `bundle_art.gd` contract + provenance; `generate`
  best-of-n behind `ImageBackend` (model knob `GENFORGE_HIFI_IMAGE_MODEL`);
  CLI `prompt process generate score bench selftest creatures`.
  `sprite_lit.gdshader` lights packed-emissive pixels flat + HDR push
  (headless parse OK). Gates: `python3 -m pytest genforge/tests/test_hifi.py`
  (23) and `python3 -m genforge.hifi selftest` → delivered FAIL 53.6 → shipped
  PASS 100, silhouette IoU 0.9999 vs the original. Doc: tech/40.
- **Ricardo mid-turn (verbatim in roadmap R52):** "we aren't generating
  through any api, are we? if so, use gpt luna instead of any other / as it's
  cheap". Answer: nothing called an API. GPT-5.6 Luna is OpenAI's cheap TEXT
  model (no image output) → cannot be the sprite model; it is the standing
  default for any future TEXT call. Image model id = his decision (knob ready).
- **R50 converged run finished** (31 min, 7 creatures, all plateau-stopped
  25–38 M): gate PASS grave_shade + gloam_wisp (deployed), FAIL 5. Finding →
  **R55**: greedy 0.94 in dh-env vs 0.25 in the 4-episode arena gate for
  cinder_drake (p≈0.004 if it were noise) — a dh-env→arena OUTCOME gap on the
  same decode; measure per creature with ≥32 episodes before changing the
  trainer; raise gate episodes. Best-greedy checkpoint export still queued.
  Ledger row + context bullet in tech/39.
- **R55 MEASURED** (`ml.eval.env_parity`, 32 eps, greedy, same seeds): on the
  run's nets the win rate collapses dh-env → arena (cinder_drake vs native
  0.875 → 0.03, mire_serpent 1.00 → 0.28, bog_golem vs scripted 0.91 → 0.375)
  and the one common term is **damage TAKEN per second 1.7–2.3× higher in the
  arena** while damage dealt/s mostly agrees. dh-env under-models what the
  opponent does to the policy. Net-free baselines (scripted vs native, every
  build) were launched to localize which bodies/kits diverge; results land in
  tech/39 §2. Fix belongs in `sim/libs/dh-sim/src/arena.cpp` (effects the
  Godot fighter applies that the sim does not), then retrain.
- **R44/R45 diagnosed, not edited** (the other session owns `main.gd`,
  `world_gen.gd`, `encounter_residency.gd`): roadmap rows carry the diagnosis.
- **Next:** R55 localize + fix + retrain; then best-greedy export + second run;
  R52 real generation once the image model is confirmed; bench vs astra when
  astra's files arrive; R44/R45/R49/R51/R46 remain.

## 2026-09-19 — R50 BUILT (mask · greedy probes · reversible curriculum · reservoir · anneal · plateau); converged run launched

Commit `545c78a` (+ the `--all/--ppo` guard fix that followed). The PPO trainer
sampled πθ while every runtime argmaxed it (fen_boar v7.0: sampled 0.96 vs
greedy 0.04 win rate vs native). Built in Ricardo's order: `arena.mask.v1` in
all five runtimes pinned by one fixture (`ml/tests/test_action_mask.py`,
`godot --headless --path game res://arena/tests/mask_parity_test.tscn`,
`sim-tests`); `ppo.py` greedy probes (`--eval-envs 64`, `greedy=` in the log,
excluded from the update), promotion on greedy and reversible
(`--demote-wr 0.45`), scripts never dropped, `--reservoir 8` snapshots,
β 0.01→0.001 / std 0.3→0.1 anneal, plateau stop. Knobs in
`tools/train_run.sh` → `config.json`. Docs: root `TRAINING_HYPERPARAMETERS.md`
(R53), `docs/tech/39-experiment-ledger.md` + `tools/experiment_ledger.py`
(R54, standing), canon §9 + §12.52, tech/25 §5.1.5, tech/37, design/23.

**RUNNING NOW (local GPU, do not kill):**
`ml/runs/2026-09-19_1015__all-creatures__steps60000000_envs512_mlp_sp4_ev64_pl80/`
— `STEPS=60000000 PLATEAU_UPDATES=80 PLATEAU_DELTA=0.02 PLATEAU_MIN_STEPS=20000000
CLONE=heuristic tools/train_all.sh --ppo`, every creature as a mirror, ~179 k
steps/s ≈ 5–6 min per creature at the full ceiling. Isolated registry; nothing
in `ml/serving/` changes until `tools/train_run.sh --promote <run>`. When it
finishes: `python3 tools/experiment_ledger.py --write`, read `summary.txt`,
then the post-hoc sampled-vs-greedy measurement on the converged nets decides
whether Option B (sample at serving) is ever built. Then R52 — the hi-fi
dark-fantasy sprite generator; the brief is `sprites prompt.md` at the root
(also recorded verbatim in roadmap R52).

Latest request and quota follow-up are saved in full; roadmap R01–R40 is the
single ledger. R34 performance and R35 Flask are Ricardo's current priority,
followed by skills/runes, Arena navigation/Train All and boss/dungeon/art work.
The approval service's credits rejection cleared on the read-only retry after
reset; account balance and the original cause cannot be verified here.

Current integrated HEAD is 4eb811f, preserving the other session's checkpoint/
resume work. The old all-creatures sweep predates checkpoints: DO NOT kill it.
All functional recovery gates passed, Python 127 passed, native CTest 4/4 passed;
the streaming hard 4 ms gate STILL FAILS while the existing 20-job training sweep
runs. Transition-row caching preserves terrain, but spikes moved to base painting;
profile contention before claiming 60 FPS. A bounded, reversible CPU reservation
for measurement is planned; no training affinity has been changed yet.

Completed residency/loot/projectile/story/quit-cleanup/icon changes remain
uncommitted; builds/codex still contains b622aa6. Finish the urgent fixes and shared
gates, then commit/push the integrated work and regenerate clean Codex packages.
All-creature/player art, native five-biome exploration and the larger roadmap are
still pending; do not confuse source candidates or written plans with shipped work.

## 2026-09-13 (latest+1) — THE BOX REBOOTED; the sweep is gone. Resident workers landed.

**!! THE 12-HOUR SWEEP IS LOST !!** The machine restarted around 18:58 (uptime
was 1d05:00, then 28 min). `ml/runs/2026-09-13_0640__all-creatures__.../` reached
**g582 of 1000 on key 1 of 7**, registered NOTHING (train_es only registers after
the full loop), and has **no checkpoint** — that run predates the checkpointing
landed earlier the same day by hours. Nothing is recoverable. A relaunch today
would be checkpointed AND ~1.8x faster; Ricardo has not been asked yet.

Bright side for measurement: every number taken before the reboot was on a box
saturated by that sweep, so absolutes were inflated ~4-5x. Everything below is
from the idle box.

**LANDED — resident arena workers** (`061487c`). `--serve` boots the arena once
and takes matchups as JSON lines on stdin; `league.py` pools them, one per job,
booted once per RUN instead of once per match. Steady state, pop 10 / 13
episodes / 2 opponents / jobs 10, identical scores in all four rows:

| configuration | s/gen | speedup |
|---|---|---|
| editor binary, engine per match (old) | 13.0 | 1.00x |
| editor + resident | 9.3 | 1.39x |
| release export, engine per match | 9.5 | 1.36x |
| release export + resident | **7.1** | **1.83x** |

1000-generation key: 3.6 h -> 2.0 h. `DH_ARENA_POOL=0` disables.

**Three bugs worth remembering, all found by RUNNING it:**
- `OS.read_string_from_stdin()` is line-oriented and strips the newline — code
  waiting for a `"\n"` hangs on the first request.
- Godot flushes stdout per print in debug but NOT release, so a release
  trainer's `ARENA SERVE READY` sat in the C buffer and every worker timed out.
  `run/flush_stdout_on_print=true`. The build check missed it by reading stdout
  from a FILE after exit — it now probes through the real pool over a live pipe.
- `close()` killed a wedged worker without reaping it, leaving a zombie.

**CORRECTION to what I wrote earlier today:** I read load average 23-24 on 10
physical cores as oversubscription and claimed more concurrency would hurt.
Measured idle, `--jobs` does not plateau until 16: 4 -> 9.6 s/gen, 8 -> 7.4,
10 -> 7.1, 12 -> 7.0, 16 -> 6.4, 20 -> 6.4. **`JOBS=$(nproc)` was right.**
Parallel keys still buy nothing, but because one key at jobs=20 already
saturates the box at ~3.1 matches/s — throughput, not contention. NOTE: the
other session's `TRAIN_PROFILE=desktop` (half the CPUs) trades ~11-16% training
throughput for desktop responsiveness. That is a real trade, not a bug fix.

**DECIDED: 60 Hz stays.** Ricardo, "as to be fully capable". Recorded in
`game/arena/README.md` so it is not reopened as an optimisation.

**GPU physics: no.** Godot 2D physics is CPU-only (no CUDA backend), physics is
~7% of the tick vs the forward pass's ~93%, and one match is a latency problem,
not the throughput problem a GPU wins. The GPU-shaped version is `libdh-env` +
PPO, already batched on the GPU.

**Still the biggest win:** the forward pass in C++. Even flat it is ~3,100
us/tick. Blocked on `sim/libs/dh-godot` being only a README.

## 2026-09-13 (latest) — the arena tick, profiled: 93% GDScript, and no determinism

Committed as `a193e5d`. Ricardo asked three throughput questions; two were
already solved and the profile found a bug nobody was hunting.

**THE ARENA WAS NEVER REPRODUCIBLE.** Godot randomises the GLOBAL random stream
at startup; `arena.gd` seeded `_rng` and never that one, while gameplay draws
from it (`creature.gd` wander, `hag.gd` retreat, `projectile.gd` desync). Same
`--seed`, different fights. Winners stayed stable — that is why every win-rate
check missed it — but fitness carries an hp term. Fitness sd over 4 identical
runs: **0.0037 -> 0.0000**, vs a within-generation candidate sd of 0.0350, so
~11% of ES's ranking signal was noise. Fixed by seeding the global stream per
episode in `_start_episode`.

**The neural forward pass was 93% of the tick** (~2,200 us per neural side, for
7,744 MACs) because `_forward` used an `Array` of `Array` and `float(row[j]) *
float(out[j])` — every element through a Variant. Flat `PackedFloat64Array`:
**1.74x, bit-identical fights**.

**!! BOTH ARE LIVE FOR THE RUNNING SWEEP !!** It spawns a fresh Godot per match
and reads the `.gd` from disk, so generations from ~g536 use the new code. The
MLP change is bit-identical (pure speedup). The seed fix DOES change the RNG
stream, so the fitness landscape shifted slightly mid-run at g~526. Strictly an
improvement (less noise), but it is a discontinuity in that experiment.

**Measuring cost Ricardo throughput** while it ran: median s/generation went
73.9 -> 93.2 during the benchmark window. Stopped; it should recover, and then
beat the old baseline because of the 1.74x.

**Not done, deliberately:** the arena runs physics at 60 Hz while canon
specifies a 30 Hz sim. Matching canon halves the work but moves dodge windows
and would invalidate every trained net and gate band. **Ricardo's call.**

**Biggest remaining win:** move the forward pass to C++. Even flat it is
~3,100 us/tick, ~1000x off C. Blocked on `sim/libs/dh-godot` being only a
README — the GDExtension is not built or wired into `game/`.

**COLLISION TO FLAG:** the other session is now editing `tools/train_run.sh`
(adding `TRAIN_PROFILE=desktop` to stop `JOBS` taking every CPU — the same
oversubscription I measured from the other end) and `game/arena/console.gd`.
Both were mine. I staged only my own hunks of `docs/USAGE.md` and
`game/project.godot` and left theirs dirty; `tools/train_run.sh` and
`console.gd` I did not touch at all.

## 2026-09-13 (later) — interruptible ES runs, and why a Godot episode costs what it does

**Checkpoint + resume.** `train_es` registered its net only after the FULL
generation loop, so the 1000-generation sweep running since 06:40 would have
lost every hour if killed. Now `--checkpoint-every` (default 25 — protects even
runs started without the flag) writes ONE `_ckpt_<key>.npz` into the run's
own weights dir: theta, the next generation, and the RNG bit-generator state,
temp-then-renamed so a kill cannot leave half a file. `--resume` restores all
three, and the resumed run is bit-for-bit the run that would have happened —
`ml/tests/test_league.py::test_resume_reproduces_the_uninterrupted_run` asserts
that against a simulated mid-generation kill. `tools/train_run.sh --resume
ml/runs/<run>` needs no other flags, because config.json now records the
key/build pairs and the knobs — and the resume READS THEM BACK rather than
trusting the environment, since knobs that disagree with the killed run would
make the checkpoint inapplicable (a resume launched with deliberately wrong
`GENERATIONS=999 POP=99 EPISODES=99` ignored all three).

**Verified end to end 17:31**, not just in unit tests: a real 6-generation run,
process group killed after the g4 checkpoint, then `--resume` ran g4 and g5
ONLY, emitted `resumed g=4`, registered `fen_boar_alpha@v2`, and cleared its
checkpoint. `ml/serving/` untouched. Committed as `4eb811f`.

**The checkpoint is one file on purpose.** The first cut wrote theta and the
metadata separately. Each rename was atomic, but the PAIR was not — a kill
between them would leave weights from generation N beside metadata claiming
N-k, and the resume would silently replay work it had already done. That is the
kind of bug that never crashes and just quietly wastes hours, so both now ride
in a single `.npz` and one rename commits the whole thing
(`test_checkpoint_commits_in_a_single_rename` holds the line). The suspicion
came from an earlier test that showed `resumed g=2` against a `checkpoint g4` —
that particular reading turned out to be contamination from two interleaved
test invocations sharing a run folder, but the race it pointed at was real.

Two bugs the tests caught, worth remembering:
- `np.savez_compressed` appends `.npz` unless the name already ends in it, so
  the temp-then-rename had nothing to rename. Temp names must keep the suffix.
- A `.replace()` on the shell script silently did nothing after an earlier
  indentation change moved the anchor, so the new flags never reached the
  trainer. Assert on every scripted edit; a no-op replace looks like success.

**THE SWEEP IN FLIGHT HAS NO CHECKPOINT** — it predates this. Killing it still
loses its hours.

**Why an episode is slow** (Ricardo asked; measured, not guessed). Not
rendering — `--headless` draws nothing. An episode simulates ~28.5 in-game
seconds at 60 physics ticks/s (~1,700 frames of GDScript across every arena
node) in a freshly booted engine. One at a time on a loaded box: 1 episode
4.07 s, 4 episodes 7.74 s, 13 episodes 16.58 s — a straight line of ~3.0 s
fixed engine startup per match plus ~1.04 s per episode. The sweep sees ~86 s
per match because `--jobs 20` runs 20 engines on 20 cores. Same box, same
moment: Godot arena 27.5x real time, `libdh-env` 6,076x — ~220x apart. The
consequence worth acting on: the GATE must stay in Godot (it is the deployment
environment), the SEARCH need not — moving ES onto dh-env the way PPO already
is would be the next order-of-magnitude lever.

# Recovery continuation — 2026-09-13 (loot, shots and connected stories)

Latest full user prompt preserved verbatim; R27–R32 added before work, canon §12.48
and design/28 added. Existing R01–R26 remain, 2D before Rebirth. Other session's
0d075a8/ab14e32 are already on local master; origin/master was b622aa6 at fetch,
no divergent upstream commits. Preserve the other session's benchmark receipt.

Current uncommitted slice extends R08 to original ground-loot records and exactly-once
collection (even full bag/creature cap). Projectiles continue finite flight offscreen,
including after caster removal; live reachable targets stay awake. R27 ground_state
probe passes. R32 water leak diagnosed as pending OFF-TREE water MMIs at quit; explicit
cleanup passes forced-staging test plus 12/12 verbose real Hunt exits. Script/file
notes in docs/reference/files; commands in USAGE. All earlier residency receipts
below remain valid; updated integrated Godot/Python/native suite is running now.

R28 authoring seam implemented: mandatory narrative schema with named visual
archetypes, connected threads, factions, prospective event branches and meaningful
cross-release links; original Fen Bells enriched. New drafts pin prior release
SHA-256 and retain a marked continuation link. Local briefs include real prior
stories; build hashes include pinned transitive sources. 35 narrative/living tests
pass. Limit: dependency depth eight / 32 visits; reviewed history-anchor compaction
still pending for long release chains. No world-event gameplay or official authority
claimed. stage_living_preview already refreshed chapter.json/generated C++ stamp;
native helpers rebuilt. Full suite still needed before commit/publication.

Next: finish suite, commit/push ALL completed recovery work together with retained
training commits/benchmark receipt, build clean-source Codex clients, verify final
Linux executable icon after export. Then continue native five-biome exploration,
modern player/ALL-creature local art, Haven and weekly enchanting/cosmetic XP;
Rebirth remains after 2D. Do not stop at this documentation/persistence milestone.

## 2026-09-13 — the ML cockpit, a themed terminal, and the PPO batch (Claude, session B)

Four of Ricardo's demands, all logged in `docs/harness/20-roadmap.md` and closed there.

**Training console = the cockpit** (`game/arena/console.gd`). The right pane is
now a TabContainer: PROGRESS (as before, and it paints a best-of-N too), RUNS
(every `ml/runs/` folder with its config + gate verdicts; OPEN tails that run's
own feed, PROMOTE shells `train_run.sh --promote`), NETS (the registry — which
version is the DEPLOYED pin, DEPLOY/RETIRE, SET A / SET B), VERSUS (best-of-N,
verdicts accumulate in `ml/data/benchmarks/`). Two roster switches: **isolated
run** routes TRAIN through `tools/train_run.sh --run-dir` (new flag — the
console names the folder so it knows where to tail), **GPU (PPO)** runs the
CUDA tier. `CONSOLE SELFTEST OK` now covers all of it against `user://`
fixtures — the gate never touches the real registry, runs or benchmarks.

**`league versus`** — the new best-of-N seam. Either side is `native`,
`scripted`, a policy JSON, or `<key>[@v3|@deployed|@candidate]`. Schema
`arena.versus.v1`. Caveat found while testing: a neural side makes rounds
differ, two baselines do not (scripted vs native is bit-identical on every
seed), so that pairing is a reference point, not a distribution.

**The terminal.** `tools/dh_term.sh` (palette/banner/rules/bars, colour off for
non-TTY), `tools/art/make_dragon.py` → `tools/art/dragon.txt` (the sigil is
rasterised from Bezier outlines into half-blocks, not hand-pasted),
`tools/dh_trainfmt.py` (live bar + sparkline + s/gen + ETA), and
`tools/train_watch.py` (a read-only dashboard over any run). The actual cause
of the old silence was `python3` without `-u` piped into `tail -2`; both are gone.

**PPO batching.** `dh_env_step_many` / `dh_env_reset_many` in the dh-env C API
(+ optional worker pool), `VecDhEnv` in Python, rollout rewritten. Under load
20: 32 envs 56.6k → 352.6k env-steps/s, 128 envs 55.0k → 638.8k, bit-identical
trajectories. That exposed the per-tick GPU launch as the real cost, so
`--envs` is now 512 (5,834 → 56,288 steps/s end to end, flat past 512).

**Watch out:** a `--all` sweep at `GENERATIONS=1000 POP=10 EPISODES=13` projects
~155 h on this box — `tools/train_watch.py <run>` shows the sweep-wide ETA.

# Active recovery — 2026-09-13

Ricardo authorizes executing ALL recovered work, 2D first then Rebirth,
committing/pushing master and rebuilding Codex binaries. Work INLINE per CLAUDE;
no subagents. Single demand ledger: docs/harness/20-roadmap.md, R01–R26. Every
prompt, including both September 13 reminders, is preserved verbatim in
 docs/harness/requests/2026-09-12-recovery.md. Canon §12.47 + design/27 + tech/36 +
business/33 record permanent characters/power ceiling, weekly behavioral item
enchantments, endless cosmetic XP and community/mod/trust/guild/rating directions.
Financial allocations and official-server systems are specifications/proposals,
not deployed services. Do not stop after documenting or this small milestone.

Published: 3f52b35 recovery UI/actions/stream repair and b622aa6 generated-budget
record, both pushed to origin/master. Current Linux/Windows packages under
builds/codex both identify clean b622aa6 and pass hash/ZIP/PE icons. Linux actual
export passes menu/Hunt, level-up refill, practice and complete saved lair→same
Hunt→rush journey. Windows gameplay remains untested natively. Current package
does NOT include the newer residency/Snap correction described below.

READY TO COMMIT (uncommitted): R08 encounter residency + Snap-aware Linux icon
installer, latest prompt/plan archive and modern hunter source candidate. R03
Haven return, R04 companion sprite/nickname cards, R07 saved world visibility and
R15 actual host icon association are gated complete. Broader UI/art remains open.

R08: game/prototype/encounter_residency.gd stores primitive snapshots in owned
per-Hunt per-chunk files; dormant scene nodes are freed. Stable IDs, HP/maxHP,
spawn-time stats/status/cooldowns, species/element and paired-boss linkage survive
return. Sleep 1152px / wake 960px from EVERY hunter, one file/body per frame, paired
wake reserves 2 slots; read only fully drawn terrain (flying creatures over water
work). File claim before activation prevents repeated restores after death.
Pets and short-lived summons remain their own lifecycle. Frontiers roll on
approach with cap headroom; persistent chunk markers replace unbounded visited
RAM. Spawners/hag summons respect the 120 cap. Positional RNG now uses the Hunt seed.
F3 shows awake/sleeping counts. This is the existing LOCAL prototype harness,
not official authoritative storage. Normal exit removes only owned scratch files;
a crash may leave an orphan directory, uniquely named so new Hunts never load it.

All 20 Godot outcomes now pass, including new residency_probe and the existing
co-op/arena/stream/level-up gates. 116 Python tests pass. CTest 4/4 and validator
46 defs/11 types / 5 registries + 1 candidate pass; whitespace gate passed. Actual GL
residency_capture traveled 6 chunks away: 81 original actors dormant, 7 new frontier
actors active; returned target kept exact HP. Final 66 active/22 dormant. 300 warmed
frames report 60 FPS, process median 4.573 ms / p95 9.167 ms; residency worst 0.707 ms,
stream worst 1.253 ms. PNGs in prototype/tests/captures/residency were viewed.
These are short desktop samples, not sustained/mobile/slow-storage guarantees.
Logs under genforge/candidates (residency-capture.log, residency-pytest.log and
 game-gates/results.json). Full test runner helper remains ignored in candidates;
all official individual gate commands are in docs/USAGE and harness/README.

Linux icon: actual GIO metadata now points the raw ELF at
/home/ricz/.local/share/icons/hicolor/512x512/apps/dragon-heroes-codex.png;
host .desktop validates. VS Code Snap polluted GIO_MODULE_DIR and redirected
XDG_DATA_HOME; installer sanitizes Snap library/module overrides for system
subprocesses and uses the host application directory. All 3 renewal Python tests
pass. Next Codex package must include this corrected install-launcher.py.

Art sources: generated Haven courtyard remains under
 genforge/art_sources/haven-renewal/ with exact prompt/provenance; not yet used.
New modern hunter source-v1.png (1774×887 RGBA, 8×4 idle/run/cleave/cast) under
 genforge/art_sources/hunter-renewal/, prompt/provenance saved. 32 separate major
alpha-connected components; several weapon poses cross grid boundaries, and
run frame 15 clips its sword at the right image edge. Needs component/pivot-aware
local ingest and separate repair of the clipped pose before runtime use. A
cleanup image was REJECTED for baked opaque checkerboard (alpha 255 everywhere);
cleanup-prompt/rejection record saved, bad image retained only in imagegen default
output. No runtime hero replacement from this candidate yet. Imagegen skill
was read/announced; use built-in tool for source images, preserve originals.

Recovery audit: old codex/modern-pixel-content-engine branch at d1dbc91 has zero
commits missing from master. Its /tmp checkout directory is absent but history
is safe. Stash 73d6dfa is earlier packaging work superseded by main equivalents;
do not reapply/drop. Candidates/provenance/Rebirth work remains intact.

NEXT: inspect final diff/receipts, commit and push this verified residency slice,
then rebuild/install Codex packages (--require-clean; stage metadata before commit
if needed). Continue real hero/ALL-creature Orun-standard local ingest and native
five-biome generation/terrain art; then Haven NPC/stations/salvage/craft, weekly
item enchantments/classes/skill synergies and cosmetic XP progression. Rebirth
GPU-poor local 3D follows the 2D gates. C++ procgen still only 4 terrain types/no
biomes. Rebirth UE remains uncompiled (no engine); local 6 GB GPU / CPU path intended.

---

# Handoff — GitHub publication authorized (2026-09-12)

Ricardo explicitly requested committing and pushing all completed changes,
resolving merge issues. Latest fetch reports origin/master at 08f92d6, with
zero upstream commits missing and ten completed local commits ready to publish.
Both worktrees were clean before recording this demand; there are no merge
conflicts. Gameplay still matches the tested e570acc source exactly: 17 Godot
outcomes, 113 Python tests, four native suites, and the actual exported Linux
level-up/practice/lair/rush checks passed. Existing clean-source Codex packages
remain in builds/codex; generated archives stay ignored per repository policy.

Publication is in progress on `master` with a normal fast-forward push. After
GitHub confirms it, update this entry and the roadmap, then publish that record
and verify remote HEAD equality. No force push, other branches or stashes need
changing. The prior statements that a push was not requested are historical.

---

## 2026-09-13 (later) — training-run isolation + the ML reference (commit 0d075a8)
- PyTorch tier MEASURED on this box: PPO end to end 32,343 steps/s at --envs 32
  (VRAM-capped rollout 65,536, horizon 2048, device cuda); the C++ env alone
  527,665 steps/s single-threaded. So ~16x is still on the table — the Python
  per-env ctypes step loop is the bottleneck, not the GPU. Next optimisation:
  a batched dh_env_step_many (or worker processes). ES side: a 4-episode Godot
  match is 0.72 s, 16 concurrent 1.4 s, 20 concurrent 1.7 s, a gate 3.1 s —
  tools/train_all.sh defaults are now ~4 MINUTES for all 7 keys, not 7 hours.
- NEW: DH_SERVING_DIR (ml/serving_paths.py) + tools/train_run.sh — per-run
  folders ml/runs/<date>__<keys>__<config>/ with config.json, their own
  registry seeded from the deployed one (cumulative), weights/progress/logs/
  summary.txt; --list, --promote (gate-passing nets only). ml/serving is only
  touched by promote. Verified byte-identical registry after a smoke run.
- NEW: docs/tech/37-ml-parameter-reference.md — every parameter and
  hyperparameter, obs schemas, artifacts + consumers, gate bands, measured
  numbers. ml/README.md and USAGE point at it; docs/README.md indexes it.
- Roadmap demands logged (in 20-roadmap.md, UNCOMMITTED because that file
  carries the other session's R08/R15 text): command ledger (done), run
  isolation (done), ML documentation (done), plus the hunt exit-time RID leak
  in the polish backlog.

## 2026-09-13 — docs/USAGE.md is now the VERIFIED command reference
- Ricardo: "document all commands: from arena starting to game starting — all
  give them to me… there were several changes to the game." USAGE.md rewritten
  end to end; every command re-run that day, gate table quotes the REAL pass
  lines. Marked *not run here*: long training, packaging (~1 GB templates),
  Nakama containers, tools/run_vulkan.sh (Ricardo-only).
- All 20 gates GREEN on this tree, including the other session's new
  residency_probe (RESIDENCY OK, worst_step_ms 0.514) and lair journey
  (LAIR JOURNEY OK). ctest 4/4, pytest 116, content 0 problems, MP TEST OK.
- New in the doc since the last version: the OPTIONS modal (menu_probe asserts
  12 buttons + 2 volume sliders), the PPO/GPU tier (ml/.venv/bin/python — system
  python3 has no torch), evolve.py, gpu_guard (DH_VRAM_FRACTION), dh-env +
  ml.env.bench, dh-server --living-preview/--lair-profile/--dump-chunks/
  --dump-window, dh-effect-lab, the Lairs & Legends tools, Codex packaging,
  arena dump_specs, league round-robin, and the rebirth slices.
- FOUND, not fixed (logged in the roadmap polish backlog): the hunt boot gate
  leaks 5 RIDs at exit (MultiMesh+Mesh+Material+Shader) on ~1 run in 4; no
  other scene does it. Exit-time only.
- NOT COMMITTED in the parent repo: the tree is dirty with the other session's
  in-flight R08 residency + R15 icon work (game/prototype/*, harness docs,
  requests/). My changes sit in the working tree: docs/USAGE.md, the roadmap's
  command-ledger entry (closed) + the leak item, and this block.

## Prior delivery (preserved)

### Progression scaling audit (2026-09-12)

Ricardo asked whether hunters, monsters and items scale indefinitely. They do
not: the playable hunter cap is 100; ordinary items roll with the hunter's level,
monsters scale at spawn, forge caps at +5, and the separate boss rush stops HP
growth at 1.5×. Frontier distance raises capped elite-affix odds, not actual
monster levels. The current model is documented with exact formulas and source
pointers in design/24, Progression scaling audit; tech/29's implementation
claim was corrected while preserving the intended level-bias proposal.

This question prompted a source audit only. Infinite permanent gear power would
change the documented power-ceiling direction; an endless PvE depth/mastery
track could preserve it. No progression redesign, save migration, cap increase
or runtime change was made. Existing e570acc Codex packages still contain the
current game code; the 17-game/113-Python/4-native verification remains relevant.
Roadmap is updated, and this documentation pass is checked with git diff --check.

---

## Prior delivery (preserved)

### Hunt level-up resource refresh (2026-09-12)

Ricardo requested immediate stat/resource refresh when leveling during a Hunt.
`ProtoPlayer.refresh_on_level_up()` recomputes the stat block before filling
HP to its new maximum, three dodge charges and both Ember Flasks; obsolete
recharge/HoT timers clear. Hunt updates HP HUD before the existing flourish.
The P2P host applies the same refresh to living remote hunters, preserving
their builds. Skill cooldowns, class stacks, effects and death state remain.
Ordinary equipment/stat changes grant no refill. The normal Hunt has no mana;
the separate living-trial resource model is unaffected. Law: canon §12.46,
design/24; roadmap is complete for the implementation and outcome gates.

Validation: all **17 Godot checks**, including real-death level-up regression,
co-op, ESC, flask and repopulation; **113 Python tests**, CTest **4/4** and the
content validator pass. Stream 1.39ms; FX stress 5.53ms/no pool growth. The new
regression covers no-level/duplicate/multi-level transitions, new max HP,
instant HUD updates, party parity, unchanged gear/cooldowns and dead hunters.
Gate command is in docs/USAGE and the harness suite. The exported Codex smoke
now also crosses a real kill threshold and asserts the HP/dodge/flask refill.

Fresh Linux/Windows Codex archives are rebuilt in `builds/codex/`. Both record
clean `master` source **e570acc**. Actual exported Linux gameplay passes the
new level-up refill gate (94-creature Hunt), practice and full saved lair/rush
journey. Icons, file hashes and ZIP checks pass, including both six-size Windows
executable icons. The final package-record commit changes only documentation;
these binaries contain the current gameplay code. Windows gameplay still
requires native testing. Commits stay local on `master`; no push was requested.

---

## Previous delivery history (preserved)

### UI identity and approved mainline integration (2026-09-12)

Ricardo approved committing all Codex work to the existing main branch `master`
and requested a stronger UI identity. The first pass adds reusable bronze,
ivory and Lumen styling, clipped metal panels, visible keyboard focus, a rune
volume grip, shared shrine framing for menu/Haven/collection, and data-driven
artifact cards with bounded lore previews. Main-menu copy is localized; the
existing trial remains English. Production HUD/class sigils/bestiary/ordinary
gear cards remain scheduled in the roadmap. Law: design/26, canon §12.45.

Integration complete: the original workspace is now on `master`, fast-forwarded
through **70e8b4f** with every reviewed Codex commit. Latest fetch of origin still
reports 08f92d6; no upstream commits are missing, no conflicts, and rebirth plus
upstream's tracked Windows artifacts are unchanged. The Codex review branch and
the older unrelated stash remain. No remote push was requested or performed.

Fresh archives are in the original workspace's `builds/codex/`:
`dragon-heroes-codex-linux.zip` and `dragon-heroes-codex-windows.zip`. Both record
clean main-branch source **70e8b4f**. The landing-record commit is documentation
only; these packages contain the current game/tools/native source. File hashes,
ZIP CRCs and both Windows six-size executable icons pass. Exported Linux normal
Hunt (86 creatures), practice (chain + ward, eight atlas frames), and the full
lair/reward/world-return/saved-unlock/rush/second-item/round-two journey all pass.
Codex saves, package names and executable icons remain. Play with PLAY NEW
CONTENT → EXPLORE SHRINE ENTRANCES → G; defeating Orun unlocks his boss rush.

Verification for this pass: 113 Python tests, CTest 4/4, content validator and
all 16 Godot outcome gates passed; the console's deliberate malformed-JSON
fixture is qualified as before. Stream worst apply 1.48ms; FX stress 4.85ms,
no pool growth. Five actual GL UI captures + metrics: docs/art/ui-identity/.
All report 60 FPS at 1280×720; these are short desktop samples. Combat capture was also inspected (`docs/art/ui-identity/practice.png`):
60 FPS, 1.942ms process CPU, 85 draws; prior sample 60 FPS, 1.52ms, 85 draws. Windows still
requires native gameplay testing.

---

## Previous delivery history (preserved; current instructions are above)

### Modern pixel-art review branch (2026-09-12)

Latest delivery: GitHub sync + world lairs / earned boss rush (2026-09-12).
Branch `codex/modern-pixel-content-engine` contains `origin/master` **08f92d6**;
final fetch confirms no upstream commits missing. Kept upstream quick play,
ARENA, HUD/hordes, Nakama launchers and rebirth. The one menu overlap is resolved;
compact rows + scrolling preserve all actions at 640×360. Original workspace
and upstream's tracked Windows build artifacts remain untouched. Our Windows
build tree is now `sim/build-codex-windows`.

PLAY NEW CONTENT → LAIRS & LEGENDS → EXPLORE SHRINE ENTRANCES starts beside a
seeded bell arch. G enters Orun's lair. Native victory earns an artifact and
unlocks him in BOSS RUSH; each rush clear earns another item. ENTER continues;
ESC restores the exact paused Hunt or collection menu. The native campaign owns
unlocks/equipment/rewards/rounds; exclusive, flushed atomic stable-ID saves live
in `user://lair-collection-v1.txt`, separate from regular gear and the economy.
Practice exposes all four presets and grants nothing. V2 authoring supports
up to eight lairs with existing phase verbs and distinct creature atlases.
Runbook: tech/35; actual frames: `docs/art/lair-journey/`.

Validation: **113 Python tests**, content validator, **CTest 4/4**, all **16**
integrated Godot outcome checks (with intentional console JSON-error fixture).
Upstream's skill-card scroll required updating the real-click probe; all
learning/assignment/persistence assertions now pass. Stream 1.12ms isolated,
2.25ms in the full run (target 2ms / hard 4ms). Windows helper cross-build, client export
and both six-size PE icons verified. Exported Linux normal Hunt, practice and
full lair→saved reward→same-Hunt return→rush→second reward→round 2 all pass.
Discrete impulses survive acknowledgement, packet batching, pause and save
retry; Unicode native profile paths have an outcome test. Actual GL journey:
60 FPS, 2.033ms process CPU, 89 draws, doorway draw 277µs peak. Practice final:
60 FPS, 1.52ms, 85 draws. These are short desktop samples. Windows gameplay remains
untested natively. Public/P2P lairs, ordinary gear/class/pet migration and full
action animations remain production follow-ups.

Both Codex packages were verified before commit. Run the packager again after
committing so BUILD-INFO records clean source; it requires the full exported
journey. The named interruption stash 06cffd7 can then be dropped; older stashes
belonging to prior work must remain untouched.

README banner follow-up (2026-09-12): original 3:1 Dragon Heroes key art is
embedded at the top of README. Asset, exact prompt and hash provenance:
`docs/art/readme-banner/`. Gold title, luminous ruins, three adventurers,
spectral companion and ivory dragon; aligned with design/26 and the app icon.
PNG and relative links validated; artwork visually inspected. Documentation
only; existing binaries still record tested source commit `60764dc`.

Worktree: `/tmp/dragon-heroes-codex-content-engine`; branch:
`codex/modern-pixel-content-engine`; rebased base: `08f92d6` (originally `b3d41e9`). The original workspace's
uncommitted code, training runs, logs and builds remain untouched.

Delivered: `genforge/living/` (draft, grounded explicit provider generation,
OKLab animation/emissive ingest, strict validation, immutable hash manifests,
offline interactive review); expansion schema and authored `fen_bells`
chapter; generated Gloamfen keyframe and eight-frame Bellwether idle source;
bounded C++ effect commands/probe; CI integration. `tools/review_living.py`
builds everything and prints the review HTML path. Law/specs: canon §12.45,
design/26 and tech/34. The skill/class/run-system work is a documented
proposal; existing Hunt behavior is unchanged.

Verification so far: full GenForge + ML Python suite **93 passed**; content
validator (46 legacy definitions + one candidate) green; CTest green; four
compiled effects pass cooldown/recursion/bounded-output fixtures. Sample
atlases use 1,115,136 decoded bytes (1.064 MiB). Microbench varies with host
load (~3–10 ns/evaluation); it proves no rendered-frame or full-sim budget.
Headless game outcomes passed (import/menu/Hunt×3/spawn/stream/click/FX/arena/
console/cosmetics/co-op). Logs: `genforge/candidates/game-gates/`. Console's
intentional malformed-JSON fixture logs an error despite passing its outcome
assertions; stream measured 2.22ms initially and 2.16ms on isolated rerun
(2ms target, 4ms hard cap). This offline change adds no live streamer work.

The candidate is deliberately non-publishable. Remaining work is listed in
the roadmap: full directional/action animation + manual cleanup; authoritative
effect application/pet events/resources; live rarity/save/UI/loot migration;
crowded Hunt and mid-mobile profiling; signed pack promotion/rollback.
The keyframe is a concept, not a screenshot. Firefox Snap could not use the
isolated `/tmp` profile for a review-page screenshot; no browser visual gate
is claimed. Raw generated art and the quantized atlas were inspected directly.

Codex desktop packaging follow-up: original transparent dragon/Lumen icon at
`genforge/art_sources/app_icon/`; PNG + six-size ICO at `game/branding/`.
`tools/package_codex.py all` rebuilds Linux/Windows clients and their adjacent
world helpers into `builds/codex/`, includes the offline content review, hashes
files, verifies embedded PE icon bytes and ZIP CRCs. Separate Codex title/saves.
Optional Linux app-menu installer ships inside its package; it was tested only
against an isolated XDG directory. Windows native gameplay remains untested.

The actual release-PCK smoke gate found a pre-existing packaging defect:
`world_gen.gd::can_stream()` ignored the resolved adjacent helper and checked
only the dev tree. Fixed alongside exported-build detection. The new explicit
`-- --codex-smoke` probe confirms the release menu, both icon resources, save
isolation and a populated streaming Hunt (95 creatures on the first passing
run). It is dormant on normal boots. Godot 4.6 release templates disable
external `--script`, so that earlier probe attempt timed out and was replaced
by this included outcome probe. Run `python3 tools/smoke_codex.py
builds/codex/linux`; evidence: `genforge/candidates/packaging/`.

Rebase retained upstream arena tests and Codex effects tests. Python: 93 pass;
CTest + content validation pass. Headless full outcome suite after rebase
passes with the documented console malformed-JSON fixture qualification;
stream measured 1.51ms on final suite (inside the 2ms target). That final suite
hit the documented spawn flake once (streaming=true, nearest 0px); isolated
rerun passes with 91 creatures / nearest 135px. Both logs are retained; final
checks and source reference are in roadmap / package BUILD-INFO.json.

---

## Prior session context (preserved)

### Handoff — running state (updated 2026-09-11; HEAD = v0.3.0 + mesh/harness + arena console/speed)

DURABLE MEMORY IS NOW docs/harness/ (README = start here, 10-systems-map,
20-roadmap). This file is only the volatile delta. Canon §12 current through 39.

## 2026-09-12 (night, second context) — REBIRTH ENGINE EXPERIMENTS EXECUTED
- Ricardo: "Unreal engine, godot 3d and the rest… execute what is documented
  in the rebirth folder; one folder per engine inside rebirth; assets/pipelines
  outside." Done INLINE (no agents), never a Vulkan window. Status of record:
  rebirth/docs/02-status.md; canon §12.44; systems map + roadmap updated.
- rebirth/godot3d — RUNS + GATED: `REBIRTH_SELFTEST=1 godot --headless
  --fixed-fps 60 --path rebirth/godot3d` → REBIRTH3D OK (5 skills, enrage,
  i-frame avoids, combo 9, kill, toast, rematch, fx overflow 0, nodes 210);
  captures rebirth_{breath,fight,enrage}.png. gl_compatibility (agent shell);
  Forward+ flip = Ricardo (auto-enables vol fog/SDFGI/SSAO).
- rebirth/native — C++20 + GL 3.3, own 30 Hz deterministic sim: -Werror
  clean, REBIRTH-NATIVE OK + determinism hash + ctest 2/2; 9.5–10 ms/frame
  on Intel Mesa; captures native_{breath,fight}.png.
- rebirth/unreal — UE 5.4 C++ slice, 20 files, COMPLETE BUT UNCOMPILED (no UE
  here; needs Epic account, ~45 GB): INSTALL.md has the runbook + where
  compile errors would surface. rebirth/unity-hdrp — parked by decision (README).
- rebirth/assets/tools — engine-neutral staging (placeholder GLB writer,
  glb_to_dhm, gen_assets → GenForge mesh_gen); proven with placeholders in
  all three engines; real mesh blocked on concept renders (same as §12.38).
- COLLISION (needs Ricardo): the OTHER session committed a UE scaffold at
  rebirth/ ROOT (69a5cd3: Rebirth.uproject, Config/, Source/ stub,
  tools/gen_assets.py) + siblings ../rebirth-native (links dh-sim, arena
  headless) and ../rebirth-unity. I followed the per-engine-folder
  instruction; touched none of theirs (their Source/ was briefly deleted as
  an empty stub and restored from their commit). Pick: delete the root trio
  in favour of rebirth/unreal/, move siblings inside as native-dhsim/ +
  unity/ — or the reverse. Their root Config sets GameEngine= to the
  GameMode class (won't boot as-is).
- Committed in the rebirth repo: my folders only (godot3d/, native/, unreal/,
  unity-hdrp/, assets/tools, docs/02-status, README index, .gitignore). In the
  parent: harness docs only; this file + canon are dirty with the other
  session's work — commit them from that session.

## 2026-09-11 (afternoon, main context) — verification pass on the other session's tree
- FOUND + FIXED: prototype/ui/display.gd `var next := MODES[...]` (x2) was a
  FATAL GDScript parse error since v0.3.0 — main_menu.gd logged "Failed to
  compile depended scripts" at every boot and `_build` aborted at the display
  controls (menu rendered WITHOUT the MODE/FIT buttons; everything else looked
  fine, so nobody noticed). Typed the two vars. NEW GATE
  prototype/tests/menu_probe.tscn → MENU OK asserts the menu BUILT (buttons
  MODE/FIT/ENTER/CO-OP/LANGUAGE + 2 fields); proven to FAIL on the old file.
  USAGE gates row + harness README chain updated.
- Console fit VERIFIED by capture (tests/captures/ui_console_fit2.png,
  1600x900 on the 1080p screen): no overflow, all buttons in view; added a 2x
  integer step to _fit_window (800x450 logical when the canvas allows) so the
  pixel type reads at menu size instead of 1:1 dots. Menu capture
  (ui_menu_fit.png) = 1280x720 integer 2x, centered. Smaller screens (1366x768
  ladder rungs) untested here — no Xvfb on the box.
- Gated the other session's PPO net cinder_drake v4 (10M steps, mixed
  opponents): FAIL — suite_scripted win_rate 0.0 (fitness -0.09), suite_native
  0.5 (pass). Up from 0-4 vs native, scripted baseline still unbeaten.
- Status checks: NO engine experiments exist on disk (Unreal/"Rebirth"/
  siblings = queued twice in the late/night blocks, never started; Godot
  settled §12.27). 3D pipeline: TripoSR installed + runner fixed, ZERO meshes
  generated yet — blocked on valid concept renders (52 px sprites are not
  conditioning); Ricardo's local image repo is the unblock (plug in as an
  ImageBackend, GENFORGE_IMAGE_BACKEND=local).
- AUDIO SETTINGS (Ricardo: "mute songs and effects", canon §12.42): NEW
  prototype/ui/audio.gd (ProtoAudio) — Music + SFX buses created in code,
  ON/OFF + volume persisted in user://settings.json "audio", applied at every
  boot (main_menu._build + main._build_audio); all SFX players bind to "SFX";
  title screen MUSIC/SFX buttons above FIT/MODE. No music exists yet — the
  bus is the seam. menu_probe now also asserts the switch mutes the bus.
- Committed ONLY display.gd, console.gd, the probe, captures, gate docs. The
  rest of the late/night work (kits, duo, dh-env, ppo.py, Windows build) is
  still uncommitted in this tree — commit it from that session (sim/build-windows
  must be gitignored first).

## 2026-09-11 session (main context; everything INLINE — no agents)
- Two background workflows (a freed-instance sweep, the console build) HIT THE
  SESSION QUOTA and died mid-flight. Ricardo: "Don't instantiate background
  agents, execute everything yourself." → CLAUDE.md hygiene line + harness
  README changed; standing rule, canon §12.39.
- ARENA TRAINING CONSOLE LANDED (design/25): game/arena/console.{gd,tscn} —
  roster (trainee / opponents / gens / pop / eps / jobs / speed + a parallelism
  hint), Train/Stop (detached pid), progress tail of ml/data/progress/<key>
  .jsonl, fitness chart, match-score strip by opponent, Gate, Watch. Gate:
  CONSOLE SELFTEST OK. league.py: Progress writer (start / match / candidate /
  generation / registered / gate / error), --progress-file, train_global
  extracted, WEIGHTS_DIR mkdir fix; ml/tests/test_progress.py → 18 ml tests.
- SPEED LEVER (canon §12.39, design/25 §5): arena `--speed max|N`
  (_apply_speed); league.py `--speed` default max (passes the engine flag
  --fixed-fps 60). Same seeded 2-episode set: 22.1 s (4×) / 5.65 s (16×) /
  0.91 s (max), BIT-IDENTICAL results. 1→16 workers: 109× → 873× real time
  aggregate; flat at 20. Projectile group tagging moved _process →
  _physics_process (tick-exact at any speed). Camera/HUD: training workers
  never build them (only --selftest does, on purpose).
- OBSERVED, NOT FIXED: fen_boar candidates take 0 wins vs native in every match
  (Ricardo's v4/v5 runs and the verification run) — fitness moves on hp margin
  only. Next: opponent curriculum / shaping, now ~3 s per generation.
- WATCH: `--import` logs a pre-existing parse error in prototype/ui/display.gd
  (`var next :=` on an untyped Array element, lines 27/35); runtime is fine
  (CLICKTEST ALL PASS). Type the two vars when next in that file.
- Freed-instance sweep: 17 UNVERIFIED candidate sites (fighter.gd 48/73/240/
  257/258/424, arena.gd 167/212/480/536/544, neural_policy.gd 78,
  host_driver.gd 100/156/206, client_hunt.gd 105, mp_test.gd 85) — verifiers
  died on quota; hand-check if the freed-body crash class recurs.
- Git has NO remote: `git remote add origin <url> && git push -u origin master`.

## 2026-09-10 session (main context)
- COMMITTED the eight days of uncommitted parallel-session work as v0.3.0
  (arena, P2P co-op, open source, polish pack, spawn_probe gate, packaging,
  cosmetics, USAGE manual) after re-running EVERY gate on the merged tree.
- Cloud GPU tier PARKED for budget (canon §12.38 — history logged; code kept
  commented-out + guarded, NOT deleted; re-enable when budget returns).
  mesh_gen registry is local-only; DH_MESH_OFFLOAD=1 is the max-quality path
  on the 4050 for now.
- TripoSR draft tier: venv ready (torch cu124 OK); torchmcubes blocked by the
  CUDA 12.8 `lerp` header clash — fix recipe in docs/harness/20-roadmap.md NOW.
- WATCH: spawn_probe flaked ONCE right after `--import` (packs at 0 px),
  passed twice on rerun. If it recurs, suspect the boot dump timing.
- No Unreal Engine anything exists (Ricardo asked for "unreal engine tests" —
  the engine is Godot, settled §12.27; the test commands are docs/USAGE.md).

# Handoff — running state (updated 2026-09-02 pm2, spawn-collapse INCIDENT fixed)

## INCIDENT (2026-09-02 pm2): world silently not booting → all packs spawned
## ON the player ("everything glitched", Ricardo). Root cause: the export
## packaging's _find_dh_server() was inserted as a func INSIDE world_gen._ready
## — GDScript ended _ready at the func keyword, so the entire boot block was
## unreachable. Zero script errors → main.tscn boot gates passed blind. Fixed
## (function moved out of _ready); NEW STANDING GATE
## game/prototype/tests/spawn_probe.tscn asserts packs spawn on rings
## (SPAWNTEST OK — nearest > 100 px) so a silent world-boot failure can never
## pass again. LESSON (permanent): a hunt gate that only greps for errors is
## blind to dead code paths; gates must assert OUTCOMES.
## All gates re-verified after the fix: STREAMTEST OK, SPAWNTEST OK, CLICKTEST
## 16, FXSTRESS OK, ARENA SELFTEST OK, MP TEST OK, pytest 63, validate 0.

## P2P CO-OP (canon §12.36, docs/tech/33 — Ricardo: LAN + lobby P2P, keep it
## simple, just me and friends) + PARALLEL TRAINING (tech/32) + USAGE MANUAL

## P2P CO-OP (canon §12.36, docs/tech/33 — Ricardo: LAN + lobby P2P, keep it
## simple, just me and friends) + PARALLEL TRAINING (tech/32) + USAGE MANUAL

- game/mp/ LANDED: MpNet autoload (ENet lobby + RPC transport), lobby scene
  (menu → CO-OP (P2P)), host_driver (remote hunters as bot_drive ProtoPlayers
  w/ auto-rolled ProtoBuilds; 20 Hz snapshots incl. per-id spawn manifests),
  client_hunt (same world from lobby seed via world forced_seed + smoothed
  puppets + 30 Hz inputs + HUD), MpPuppet. Party loot/XP shared via host
  Session (v1, documented).
- MP HOOK patches (additive): creature/projectile NEAREST-player targeting;
  player death passes self → main routes remote deaths to the driver (3 s
  respawn, no party gold loss); world_gen forced_seed; main.gd reads
  MpNet.pending_seed + attaches host driver; project.godot MpNet autoload;
  menu CO-OP button. Solo behavior unchanged (16/16 CLICKTEST).
- Gate: tools/mp_test.sh — 2 headless procs on loopback: registration, lobby
  sync, seed payload, identical world, remote spawn + INPUT-DRIVEN movement,
  snapshots → MP TEST OK. (Gotcha hit: @rpc call_local still needs rpc() to
  reach peers; result-file/stdout races taught the test to assert DISPLACEMENT
  and to grace-quit.)
- TRAINING AT SCALE (tech/32): league.py --jobs N (ThreadPoolExecutor over
  headless godot workers; measured 3.8x on 4 workers, ~3.8k episodes/hour at
  16 workers). evaluate_candidates() parallelizes ALL (perturbation x
  opponent) pairs; mirror mode for the global net. ml pytest 11/11.
- DOCS: docs/USAGE.md (THE all-usage manual: play/co-op/arena/training/
  content/gates/troubleshooting); tech/32 (scaling); tech/33 (co-op).
- OPEN SOURCE decision (canon §12.37, business/32): no client crypto/DRM —
  value is server-resident by design; code MIT / art CC BY-NC (pending
  Ricardo's confirm); mods = schema-validated data packs (no scripts), solo
  anything-goes / co-op hash-match / ranked+economy official-only.
- PACKAGING: game/export_presets.cfg (Windows+Linux, embedded PCK, tests
  excluded) + tools/package_game.sh → builds/dragon-heroes-<plat>.zip (game
  binary + dh-server + LEIA-ME). world_gen now locates dh-server NEXT TO the
  executable in exported builds. PENDING: templates download (~1 GB, needs
  Ricardo's OK) + friends' platform list (Windows needs mingw dh-server.exe).
- NEXT (Ricardo's picks pending): play co-op with real eyes (client feel,
  puppet interp, world parity on two machines); L1 data-driven AI profiles
  (OM doc §2); L4 pet skills; dh-sim port (authority + dh-env throughput).



## POLISH PACK + GUIDE (2026-09-02 pm, docs/design/24 §1 landed; §2 = the OM
## levers awaiting Ricardo's call; §3 = next polish backlog)

- GUIDE: game/arena/README.md — spectator keys, every headless flag, roster/
  build/cosmetics authoring, train/gate/watch-a-net workflows, JSONL format,
  CI gates, troubleshooting.
- LANDED (full-repo gameplay review → curated fixes, all gates green):
  input buffering (dodge/E/Q/slots, 150 ms) + empty-charge feedback; dodge
  i-frames honesty (comments == behavior); point-blank strikes no longer whiff;
  Ignite max-dps; hostile bolts + fields hit pets; phys_reduction clamped
  (blood_price heal singularity); hitstop last-writer-wins; respawn clears
  transient state; chain whiff = half-CD + always-sfx; Talon Dive wall-gated;
  low-HP breathing red bar + post pulse; camera lookahead to cursor; level-up
  heals to full (sustain floor).
- THE OM LEVERS (docs/design/24 §2, Ricardo's pick): L1 data-driven AI profiles
  for the 1000-species bestiary (fun × species value; the arena bot_drive seam
  is the executor socket); L2 run structure (in-run boon picks, night-fall
  escalation); L3 bosses as system-play (generalize field-combos into the
  boss-design primitive); L4 pets as second build axis (rolled skills never
  cast today — UI advertises them); L5 dh-sim C++ port (authority + 100x RL);
  L6 Radiance Cascades (queued Phase 3); L7 reactive audio layer.
- Gates after the pack: CLICKTEST 16/16, FXSTRESS OK 4.75 ms, ARENA SELFTEST
  OK, hunt boot clean, validate 0, pytest ml 10 + genforge 52.



Read `CLAUDE.md` + `docs/00-canon.md` first (decisions log §12 is current through
item 35). This file is the delta: exactly where work stopped and what's next.

## THE ARENA (canon §12.35, docs/design/23 — Ricardo: observable self-play,
## per-species + global nets, player builds, cosmetics)

- game/arena/ LANDED: creature/creature, build/creature, build/build matches on
  the prototype combat code. Windowed spectator (roster rotation, N/R/1-3/Q),
  headless CLI for training (--a/--b/--policy-*/--episodes/--seed/--fast/
  --record-dir/--out), gate: `... arena.tscn -- --selftest` → ARENA SELFTEST OK.
- TWO ARENA HOOK patch sets in prototype files (additive, marked in-code):
  target_override on creature/projectile(+shooter at 5 spawn sites)/pet;
  bot_drive + bot_aim + bot_dodge + build_source on player; ProtoStats.compute
  now takes Object. Hunt behavior unchanged (click_test + fx_stress + hunt
  boot gates green).
- ArenaProxy is the uniform target surface (only "creatures" member per
  fighter). policy.gd = obs schema arena.obs.v1 (31 floats) + fairness layer
  (150-250 ms obs delay, aim noise, 6 commits/s burst cap). scripted_policy.gd
  baseline; neural_policy.gd loads ml/-exported weights (species nets + global
  net, one runtime; embedding rows per content id, mean-init for new content).
- recorder.gd = R0 obs+action JSONL (30 Hz) → ml/data/episodes (gitignored).
- ml/ LIVE: policy_net.py (numpy twin), league.py (ES trainer + registry),
  eval/gate.py (scripted suite + ladder + sanity; FAIL = stay on pin). Smoke
  verified: fen_boar train g0 registered v1; gate correctly FAILED it (0% vs
  native) — the boring failure mode works. ml pytest 10/10.
- BOUNTY HUNTERS: content/core/arena/builds.json (+ arena_build.schema.json,
  validator wired — `arena` type) = 5 geared player builds (class/attrs/rolled
  gear/runes/loadouts/pets) + 7 creature/boss builds + spectate rotation.
  Snapshot: game/arena/data/builds.json (hand-sync like prototype/data).
- COSMETICS PACK (Ricardo: shadow auras, elemental effects, Grand Chase
  necklaces): genforge/vfx_lab/{auras,necklace_orbit} labs + shaders
  aura_body/necklace_bead/weapon_aura.gdshader + game/arena/cosmetics.gd
  (ProtoCosmetics; 3-bead orbiting necklaces, media auras, weapon pulse).
  Gate: arena/tests/cosmetics_test.tscn → COSMETICS OK. z-band −1..2 (under
  darkness, graded as light). Worn by arena builds via "cosmetics" spec keys.
- NEXT: spectate-mode eyes (Ricardo — the windowed watch loop + cosmetics
  read); neural-vs-native boss kits not policy-addressable yet (boss RL stays
  R3); bounty hunters as hunt-world NPC spawns; fields don't hit summons;
  PufferLib/dh-env port carries registry/gate/schema/datasets unchanged.



## v0.2.0 — INFINITE WORLD (canon §12.32, Ricardo: "work on this for the next
## patch"; design law: docs/tech/29-infinite-world-streaming.md)

- dh-server `--dump-window` LANDED + rebuilt, determinism byte-verified.
- world_gen.gd carries the streaming CONTRACT (signals chunk_loaded/unloaded,
  can_stream, loaded_bounds, chunk_map_image) — internals being rewritten to
  the §2 pipeline by the world-core agent (also: darkness statics get handles
  + remove_static; NEW gate tests/stream_test.tscn must end STREAMTEST OK).
- minimap window-following + main.gd frontier repopulation/distance despawn:
  game-systems agent (§3).
- docs agent: design/20 (v1→v2 retrospective, montage at docs/media/
  v1-vs-v2.png), design/21 (multiplayer roadmap: co-op on infinite world →
  PVP → skill-system overhaul per Ricardo's direction), tech/30 (Android
  export + LAN honesty), README index.
- Fixed en route: ThemeDB default-theme font trap (canon §12.31) — bare HUD/
  nameplate Labels now pixel; main.gd self-applies the doctrine on direct
  boots; reusable tests/ui_capture.tscn harness (UI_SCENE/UI_TAG/UI_WAIT).
- Ricardo's asks still open after this patch: Android on-device profiling
  (60 FPS directive) + touch controls decision; multiplayer M-A scoping.

## THE FIVE-OVERHAUL PROGRAM (canon §12.30 — Ricardo: "do all of those, and
## also radiance cascades"; code must stay reusable/decoupled)

Phase 1 LANDED (v0.1.15, e1419ec): light registry as shader globals
(dh_light_tex 16x2 RGBAF + dh_light_count, packed by darkness.gd — one gather,
N consumer shaders), SDF shadows (world_gen chamfer bake over T_ROCK,
sphere-traced soft penumbras, caster flags on lantern/fields/legendaries,
intensity-gated 0/4/6), world-anchored 4x4 Bayer banding on all falloffs.
VERIFY IN-GAME: shadow direction near rock ridges (no rock was adjacent to
fire in the captures — if shadows look wrong, suspect sdf_origin or the y*1.55
ellipse interacting with the march).

Phase 2 LANDED (v0.1.16 303774a + v0.1.17): all four agents delivered with
green gates; integration done (HUD sizes -> 8px grid; bundle frames are now
CanvasTextures carrying _n.png normals; sprite_lit.gdshader cel-quantized N·L
from the registry on hero+commons — rim material still wins on elites/bosses).
Original partition plans (for reference):
- normals-pipeline: genforge/pipeline/normal_gen.py (bevel+Sobel) + batch
  *_n.png over game/prototype/art/. INTEGRATION AFTER: sprite N·L shader
  reading dh_light_tex + cel-quantized response, wired into ProtoBundleArt.
- terrain: macro variation (variant-bias noise + macro-tint quad z=-8) then
  dual-grid autotiling (16 procedural corner-mask tiles, display layer).
- cohesion-lut: 2D-strip LUT infra in post (analytic path kept as fallback),
  genforge lut_gen.py, veilands_default + ember_hollows biome LUTs.
- pixel-ui: pixel font w/ PT-BR diacritic verification (click test guards
  SAIR/Talho) or AA-off doctrine fallback; damage-number typography.
Integration owner (main context): sprite N·L shader, captures, gates, commit.
Typography migration COMPLETE (v0.1.18, Ricardo: "fonts overflowing… page
decentralized"): main_menu/haven/character_panel/main.gd all on the grid via
ProtoTheme.SIZE_BODY/SIZE_TITLE + guarded font_big(); menu class cards became
name-chips (five per-card kit labels can't fit 640 at pixel widths — kit line
now renders once under the row); tests/ui_capture.tscn is the reusable menu
capture harness (UI_SCENE/UI_TAG env; haven/panel tags pre-seed Session).

Phase 3 SCHEDULED: Radiance Cascades — fragment-only port (fad Shadertoy /
jason.today / Yaazarai refs), light field at 320x180, marches the SAME baked
SDF; MUST profile mid-Android before commitment (no published benchmark).
Master-palette discipline (OKLAB quantize in CI) follows the LUT landing;
3D-to-sprite pipeline after palette; faux-verticality decision before the
C++ procgen port (canon flag).

## v0.1.14 delta (2026-07-17) — atmosphere layers (canon §12.29)

Ricardo ("really liking where this is going... further polish lighting,
perhaps add shaders?"): four capture-verified systems riding the darkness
model — ground mist (ProtoFog z=12, thins near light holes, rises at night),
fireflies (ProtoMotes z=13, 40 glints, ONE MultiMesh), animated water
(per-water-tile MultiMesh overlay, shore foam from INSTANCE_CUSTOM neighbor
mask, ONE draw call), foliage sway (vertex shader: wind + hero walk-through
push on trees/shrooms). Night cycle now drives darkness ambient + fog
density. Gates: FXSTRESS 7.66 ms, boots x2 clean, CLICKTEST ALL PASS,
validate 0. A visual-OM research workflow ran the same session — its
technique catalog (radiance cascades, normal-mapped sprites, dual-grid
autotiling etc.) is summarized in the session log + memory; structural
candidates queued below.

STRUCTURAL-OVERHAUL QUEUE — now research-ranked; full catalog with names,
feasibility and effort: docs/design/19-visual-om-catalog.md:
1. Raymarched SDF 2D lighting (occlusion/soft shadows — light currently
   passes through walls; JFA work is reused by Radiance Cascades later),
   with Bayer dithering on the falloffs in the same pass.
2. Normal-mapped sprites + AUTOMATED normal gen (Laigter/bevel+Sobel in
   genforge) + cel-quantized light() — the Dead Cells stack, one milestone.
3. "Procgen stops looking procgen" sprint: dual-grid autotiling + macro
   variation tint + Poisson scatter doctrine (+ chunk stamps later).
4. Cohesion sprint: per-biome 3D LUT grading + master-palette discipline
   (OKLAB quantize in CI) + pixel-perfect bitmap-font UI (PT-BR diacritics!).
5. VFX anatomy doctrine (anticipation/climax/dissipate composer as data) +
   trauma-shake/tiered-hitstop envelopes (2-3 days, do anytime).
BIG BETS to schedule deliberately: Radiance Cascades (profile mid-Android
first); faux-verticality height fields (CANON FLAG: decide flat-vs-height
BEFORE the C++ procgen port hardens); 3D-to-sprite animation pipeline
(after master palette). Vulkan flip remains Ricardo-only.

## v0.1.13 delta (2026-07-17) — 2D lighting model + the capture loop

Ricardo: "still far from the examples — push to the limits or full overhaul";
after this pass, live: "NOW we are talking. Things are actually beautiful."
- CAPTURE LOOP (the new standing method — canon §12.28 lesson): vfx_showcase
  .tscn boots the REAL hunt, fires signature moments, saves PNGs to
  tests/captures/ (windowed GL, never headless, never Vulkan); vfx_iso.tscn =
  minimal isolation; SHOWCASE_NULL=1 = bisect env vs player paint. Review the
  COMPOSITE after every visual change — lab sheets are not frames.
- ProtoDarkness (z=10 multiply quad, camera-glued): dark ambient + 16 nearest
  light holes from ProtoLights records + world_gen glowshroom statics. Pools
  moved to z=11 (tint OVER darkness). Hero lantern (46px, 0.30). Split-tone
  grade in post. Field edges = soft breathing arcs. Burst auto-halos with
  tight `hole` scale. Telegraph alphas ~x0.55 + beam alpha /count.
- THE RING BUG (since v0.1.5, masked by the bright world): fx.ring() scaled a
  Line2D; width is LOCAL-space -> every shockwave was a ~300px annulus (the
  "blinding triangles disc"). Fixed: width / final scale. Nova shards now
  bead-eroded radially (clock face gone).
- Gates: FXSTRESS OK 7.96ms (darkness + 20 statics in scene), hunt boot x2
  clean, CLICKTEST ALL PASS, validate 0 problems, pytest 31.
- NEXT AESTHETIC ITEMS (in rough ROI order): ambient/night-cycle coupling
  (darkness.set_ambient from _cycle); water tiles flat under darkness; damage
  number typography; HUD hint-bar size; nova at boss-finisher scale re-check
  via showcase; creature visibility floor in deep dark (pack-leader ember
  lights?); Vulkan flip = real bloom on all of this (Ricardo's hardware only).

## v0.1.12 delta (2026-07-17) — media-grade VFX: fire/darkness as MEDIA

Ricardo: v0.1.11 effects still "hard shapes on top of the rest instead of
actual fire and darkness aura"; asked about an engine swap. RE-ANSWERED: no
overhaul (canon §12.27) — the read was authorship (flat-tint SDFs, additive-
only blending, no scene lighting), not engine. Built instead:
- firestorm = persistent medium: TIME-based advection + `hold`/`flash_amt`
  uniforms; fire/lava fields BURN their whole duration (persist quads, stolen
  last, shader_fx.kill() on lava fusion). Lab has burst + field contact sheets.
- NEW umbra.gdshader (lab: genforge/vfx_lab/umbra): first MIX-BLEND medium —
  occluding violet-black smoke, erosion dissolve, narrow violet rim + motes.
  Wired: Shadow Rend, umbral creature deaths, legendary deaths (rim-tinted).
- NEW lights.gd (ProtoLights): 32 pooled additive ground ellipses, ONE
  MultiMesh, z=-3. Fields flicker light, energy bolts glow, hero/legendaries/
  bosses stand in their own light; level-up gold bloom; Cinderburst pop.
- Heat haze INSIDE the existing post pass (vec4[6] world-tracked sources,
  zero extra copies): fire fields + Cinderburst shimmer the air.
- Gates: FXSTRESS OK (lights 32/32 clamped, umbra over-fire, 2 persistent
  flames, haze eviction; 13.78 ms worst, 0 nodes after warmup), hunt boot x2
  clean, CLICKTEST ALL PASS, content validate 0 problems.
- NEXT EYES-ON (Ricardo): do fields read as burning? Does Shadow Rend read as
  darkness? Then: umbral wisp bolts could trail umbra puffs; mire/earth field
  pools; torch/glowshroom PROPS (decor system still doesn't exist); moodier
  global grade; Vulkan flip (real bloom) remains the biggest pound-for-pound.

## v0.1.11 delta (2026-07-16) — Phantom Tower reference pass

Phantom Tower (Steam 3988410) = THE reference (it IS Ricardo's original
screenshots; Hades = ceiling). Decoded from store shots and applied:
- Slash SHARPENED (thin band 0.15, crisp core, halo halved) — knife-light,
  verified on the re-rendered in-repo contact sheet.
- Nova de-symmetrized (seeded angular warp on the 13 shards).
- NEW rim_glow.gdshader: colored silhouette outlines — elites (affix color),
  boss chassis (bar_color), legendaries (magenta); ProtoGlow.rim_material
  per-color cache. The single biggest "modern engine" read at zero cost.
- Still open from the PT language: prop light halos (torches/shrooms as local
  light sources), void-dot orbital bullets, darker/moodier global grade.

## v0.1.10 delta (2026-07-16) — shader-art VFX in-game

- vfx_lab (5 pure-math effects: slash/nova/vortex/firestorm/impact) is IN-REPO:
  genforge/vfx_lab/<effect>/{render.py, notes.md, contact_sheet.png} previews +
  game/prototype/shaders/*.gdshader (compile-verified; nova/impact had PI/TAU
  built-in redefinitions — fixed). shader_fx.gd = pooled 12-quad system, ALL
  5x12 materials pre-compiled at load (mid-fight shader swap = 21.7ms spike,
  caught by fx_stress; now 13.4ms). canvas_items stretch = fragments at WINDOW
  res -> hi-res effects over pixel world (Children-of-Morta layering, free).
- Wired: melee/exec slashes, frost+skill novas, Whirlwind/Shadow Rend vortex,
  Cinderburst + fire-field firestorm, crit/brute-slam/finisher/level-up impact.
- Review: vortex/firestorm/impact clear the reference bar; nova good (slightly
  clock-like spokes); SLASH flagged blobby -> sharpen pass is next iteration.
- OpenAI image provider wired earlier same arc (GENFORGE_PROVIDER=model).
- LESSON: lab/agent outputs go IN-REPO, never /tmp (originals were wiped;
  recovered by replaying Write/Edit ops from agent transcripts).

## v0.1.9 delta (2026-07-15) — spectacle VFX overhaul

Reference: three commercial-ARPG spectacle screenshots. Full spec:
docs/design/18-spectacle-vfx-spec.md. Engine decision (deep-research, verified):
STAY ON GODOT (genre + our Godot+C++-sim+MultiMesh arch are proven; bloom wall was
a renderer setting). Renderer = "Layered now + Vulkan-ready" (Ricardo): full look on
gl_compatibility default w/ faked additive bloom; Vulkan opt-in adds real HDR glow via
ProtoPost.set_hdr_mode() inside the EXISTING main.gd renderer branch (gate condition
UNCHANGED — dev tests the Vulkan flip on real hardware; never auto-flip).

- New engine (game/prototype/): ribbons.gd (ProtoRibbons MultiMesh, 640 inst/1 draw,
  orbit/crescent/streak/streak_follow/radial), post.gd + post.gdshader (ProtoPost
  CanvasLayer 5: chromatic aberration + vignette + over-bright; pulse/flash/set_intensity/
  set_hdr_mode), telegraphs.gd (ProtoTelegraphs z=-2: ring/line/beams/aura, 24-pool,
  2 draw calls), damage_numbers.gd (ProtoDamage layer 6: 48-label pool, crit grammar).
- fx.gd gained 6 ribbon forwarders + shockwave + aura + static intensity; RING_POOL 12.
- CanvasLayer renumber (M): HUD 10 / minimap 12 / kb+panel 14 / confirm 15 / post 5 /
  dmg 6 (post grades world+ribbons+telegraphs, not UI; escapes the day/night tint).
- 4 per-event allocators pooled away (hit_spark, damage_number, telegraph.gd nodes,
  per-bolt projectile trail) — net node count DROPS.
- Budget gate: tests/fx_stress.gd (FXSTRESS OK; ribbons 40/40, labels 48/48,
  telegraphs 20/24, 0 nodes after warmup, 5.9ms). ONE knob ProtoFx.intensity (MED
  mobile default) gates usage not allocation; telegraphs exempt.
- STILL HEADLESS-ONLY VERIFIED. The look itself + additive fill-rate on mid-mobile
  need Ricardo's eyes + a manual --print-fps run (canon "profile before/after").

## v0.1.8 delta (2026-07-12) — UI/feel/PT-BR

- **Visual skill tree** (character_panel.gd): drawn prerequisite connectors,
  kind-icon chips w/ element accents, pulsing learnable states, pinned detail
  card (live stat numbers, synergy highlight, Learn/assign 1-4). Fresh
  hunters start w/ 3 points + two level-1 actives per class.
- **Haven nav**: 2-wide grid — QUIT was cropped off-screen; now test-guarded.
  Forge/enchanter action buttons above the fold; vendor leads with selling.
- **Animation juice** (player/creature/bosses/projectiles): swing leans, cast
  wind-ups, dodge afterimages (pooled ghosts), hit squash, death collapses,
  boss anticipation tells; ~50-60 concurrent tweens worst case, 60 FPS holds.
- **PT-BR** (ui/lang.gd ProtoLang): 330-key EN/PT chrome table + _pt data
  twins; skill trees 145/145 nodes bilingual; toggle in menu + Haven,
  persisted in user://settings.json; EN default (CI-safe). CODEX registry
  PT twins = planned (registry "content_pt_twins").

## v0.1.7 delta (2026-07-11) — skill trees + flow tuning

- **Class skill trees** (canon §12.21): registries/skill_trees.json — per class
  20 actives + 8 passives + root (145 nodes), ONE generic executor in player.gd
  (projectile/nova/cone/melee_arc/dash_strike/buff/field/chain), data-expressed
  synergies (bonus_vs/consumes, Ignite spread/detonate, Shatter, Attunement and
  Combo charges), new statuses Bleed/Expose/Stagger on creatures, skill bar on
  1-4 + learn/assign in CHARACTER -> Skills, loadout saved.
- **Flow tuning** (canon §12.20, v0.1.6): hitboxes follow sprite scale;
  legendary HP normalized (x1.4-3.0 of 900 budget — no 13.8k walls); items
  roll at hunter level (+4%/level, ilvl stamped), boss/legendary drops
  quality-floored (0.35/0.5).

## v0.1.5 delta (2026-07-11) — mass content

- **Bestiary as data** (canon §12.19): `content/generated/bestiary_normal.json`
  (1000 creatures: 12 world-bible families × 7 elements × archetype/tint/scale/
  stat rolls) + `bestiary_legendary.json` (100 named legendaries over
  dragon/colossus/hag chassis, 5-10-skill kits, all ids resolve to
  `content/core/skills/`). Deterministic generator:
  `python3 -m genforge.pipeline.bestiary_gen --seed 2026` (byte-reproducible,
  pytest-gated — 23 tests). Snapshots in `game/prototype/data/`.
- **Catalog-driven spawning** (main.gd/creature.gd): each hunt samples a 6-10
  species roster; packs read as one species w/ 25% strays; ONE legendary boss
  per hunt (pack 13, chassis by base, guaranteed rare+ drop, magenta minimap
  diamond). **Power scaling read at spawn**: normals HP +2%/dmg +1% per player
  level; ALL bosses +6%/+3% (scales scripted skill packets too via dmg_scale).
- **Five new baked bodies**: serpent, shade, golem, fen_boar, marsh_drake
  (`game/prototype/art/`, bestiary_art.py + skeleton/pose JSONs).
- **Five classes**: Gloam Mage (LMB Arcane Bolt projectile, E Frost Nova) and
  Veilblade rogue (LMB Swift Stab 0.25 s cadence, E Fan of Knives ×5) join
  Reaver/Emberkin/Frostbinder. Class KITS reshape LMB/E (player.gd `_kit`),
  not just stats. Friendly projectiles (projectile.gd) hit creatures.
- **VFX pass**: pooled shockwave rings + directional slash trails (fx.gd);
  pools 20/12/6, MAX_AMOUNT 40 — still zero mid-fight allocation.
- Effects registry gained "Bestiary & spawn rules" group (synced to CODEX).

## Top backlog (Ricardo's asks not yet landed)

1. **Measure Godot Vulkan mid-mobile 60 FPS** (unproven per research) + confirm the
   dev's X-crash is gone on current 4.6 before defaulting to the Vulkan renderer.
2. **Gen-AI image provider: SEAM WIRED (2026-07-15)** — provider-agnostic
   image_backend.py + OpenAI (gpt-image-1) + ModelPartsProvider behind the
   PartsProvider seam; `GENFORGE_PROVIDER=model` + OPENAI_API_KEY to enable
   (default stub). REMAINING: template-layout or segmentation so generated
   figures become SKELETAL animated bundles (not just static concept sprites);
   VFX-frame + tile/texture generation reuse the same backend.
3. **Paper-doll**: equipped gear visible on the hero sprite (+ per-slot particles).
4. **Sixth class** (design/10 names six at launch; five are live) + per-class
   resources beyond Attunement/Combo charges.
5. Skill-tree balance pass after play (100 actives are fresh); message log;
   R bestial slot; 7-element bolt flavors (storm/venom/blood wisps currently
   fall back to umbral — see registry `wisp_element_flavor`).

## Next architectural step (bigger than the backlog)

Vendor godot-cpp, build `dh-godot` GDExtension, move authority from
`game/prototype/*.gd` (marked PROTOTYPE HARNESS) into `dh-sim`. That is the moment
`game/` stops containing gameplay rules (hard rule, canon §10).

## Operational notes

- Kill the game with `pkill -x godot` — never `pkill -f` (it matches your own shell).
- NEVER launch Vulkan windows (crashed Ricardo's X once); gl_compatibility is the
  default, `tools/run_vulkan.sh` is the opt-in.
- Headless gates: `godot --headless --path game --quit-after 150` (menu),
  `... res://prototype/main.tscn --quit-after 150` ×3 (hunt), click_test.tscn
  (must end `CLICKTEST DONE — ALL PASS`), `pytest genforge/tests/`,
  `python3 tools/validate_content.py`. After adding a `class_name` script, run
  `--import` once. `grep -c` exits 1 on zero matches — never chain gates with `&&`.
- Git: v0.1 tag → v0.1.5 mass content → 2133327 v0.1.6 tuning → a8f37a4 v0.1.7
  skill trees. Rollback points exist at every step.

## v0.2.1 — 3D view experiment (canon §12.33)
prototype3d/hunt3d.tscn: same world dump/art/bundles as perspective 3D
(billboards + extruded rock + real lights). 2D untouched and canon. Verdict
+ reuse scorecard: docs/design/22. Capture: tests/captures/ui_3d.png.

## Image-to-3D stage (canon §12.34, docs/tech/31)
mesh_gen.py landed (stub CI green). NEXT ACTION (Ricardo-gated): sudo install
cuda-toolkit-12-4, then the TripoSR draft-tier runbook (tech/31 §4), then the
two-creature spike (§5). DH_*_DIR env vars locate adapter checkouts.

## 2026-09-11 (late) — kits+duo, console fit, dh-env tier 2 + GPU PPO (canon §12.40)
- Arena: creature KITS live (7 species, skills[] in builds.json: bolt_volley /
  radial_slam / pounce / field_cast / enrage; native fires boss-style, bots via
  cmd_skill, cds in obs[7..10]); DUO kind + core.arena.the_duologue (pyre+
  colossus, one fighter two bodies); roster 17 builds / 14 rotation pairs;
  schema extended (skills, members, kind duo). Freed-member crash class fixed
  via alive_body()/living_proxies()/nearest_proxy_to; SELFTEST_MATCHES now
  includes the duo (gate sees member-death mid-fight). ARENA SELFTEST OK (4
  matchups), content validate OK.
- Console/game fit: console gets a screen-fitting tool canvas ladder; game
  windowed mode = largest integer scale inside usable rect (ProtoDisplay.
  fit_windowed). CONSOLE SELFTEST OK.
- dh-env: dh-sim arena.cpp (C++ twin, deterministic), dh-env C API (ctypes),
  dump_specs.tscn GENERATES ml/env/specs.json from real bodies (16 builds);
  bench: 216k native / 256k scripted steps/s/core (gate 100k). sim-tests +3.
- PyTorch: ml/.venv (torch 2.6+cu124, CUDA on the 4050; python3-venv missing —
  sudo apt install python3.10-venv pending on Ricardo, get-pip workaround used).
  gpu_guard caps VRAM at 50%. torch_policy = GPU twin + arena.policy.v1 export
  (loads in Godot verbatim — proven). ppo.py: GAE + clip + self-play (frozen
  snapshot opponent in-env), registry-integrated. 250k-step smoke lost 0-4 at
  the Godot gate (expected); a 5M-step cinder_drake run trains in background
  (ml/data/logs/cinder_drake_ppo.log — buffered; use python -u next time).
- NEXT: gate the 5M-step net (league gate), then ES league-shape (past-self +
  exploiters in league.py opponent lists), graphics OM (VFX lab pack + RC
  lab), Rebirth UE scaffold + sibling engine repos, Windows dh-server.exe via
  portable mingw (no sudo).

## 2026-09-11 (night) — league shape, combos, conduct rule, Windows exe (canon §12.41)
- ppo.py: MIXED opponent thirds (native/scripted/past-self) — self-play-only
  was inflating win rates (1.00 fake vs 0.05 honest). --exploit <weights> =
  dedicated exploiter vs a fixed main. Combo rewards: R_KIT/R_CHAIN (90-tick
  window). 5M-step cinder_drake v2 gated: 0W/1L/3D vs native (up from 0/3/1),
  0-4 vs scripted — learning, not passing. 10M-step league-shaped run
  warm-started from v2 in background (ml/data/logs/cinder_drake_ppo2.log,
  python -u unbuffered now).
- CONDUCT combat rule (both sims + test): storm bolt × mire field = 2x burst,
  field consumed (arena.cpp + arena.gd parity, sim-tests +1: 10 total green).
- Windows: portable llvm-mingw (no sudo) → sim/build-windows/dh-server.exe.
  NEXT: tools/package_game.sh windows zip; gate the 10M net; GRU arch variant
  + ES-over-checkpoints outer selection (design: docs/tech/32); 2v2 group
  dynamics (ally obs slots, horde-vs-player) — design pending; graphics OM
  (VFX lab + RC) still queued; engine repos (rebirth + siblings).

## 2026-09-11 (night 2) — strategies + engine POCs (canon §12.42-43)
- Fair training: balance_specs (geometric-mean EHPxDPS normalization) is the
  DhEnv default; gate stays unbalanced. gloam_wisp gained mire field (every
  mob now chains; wisp can SELF-conduct). specs.json re-dumped.
- GRU arch (--arch gru): recurrent PPO, truncated BPTT T=256, .pt export,
  verified. ~40x slower/step than MLP (sequential update) — batch later.
- evolve.py: ES outer loop over PPO configs {arch, lr, entropy, selfplay_every}
  — subprocess PPO + Godot-gate fitness, top-half + mutation. Smoke green.
- 2v2 SQUADS (§12.43): dh-sim buddy bodies, obs v2 (36), C API + ctypes +
  PPO flags, 11 sim-tests green incl. squad termination + ally block.
- Engine POCs: rebirth/ UE5 scaffold committed (uprotject+Source+gen_assets);
  rebirth-unity/ + rebirth-native/ repos created+committed; native M0 PROVEN
  (dh-sim episode headless). Parent .gitignore covers all three.
- Windows: dh-server.exe via portable llvm-mingw (sim/cmake/mingw-w64-x86_64.cmake).
- 10M-step balanced cinder run in background (cinder_drake_ppo3.log).
- NEXT: gate the balanced run; package windows zip; horde mode; graphics OM.

## 2026-09-12 (day 2) — UX/HUD pass, hordes, flask, Nakama self-host, probes
- HUD OM (4b): HudSkillChip (ui/hud_chip.gd) — 26px tiles w/ procedural
  kind-glyphs, top-down cooldown sweep, numeric countdown, ember ready-glow;
  framed HP bar + white ghost-damage trail; dodge/flask pips are breathing
  diamonds. SPAWNTEST/CLICKTEST/FLASK green (run --import for class_name).
- Skills screen: detail card SCROLLS (was fixed 92-110px capper), loadout
  chips show first word + full name in tooltip.
- Menu: QUICK START (last hunter, zero typing — offline never registers),
  ARENA button -> console in-process (console got BACK). USAGE.md documents
  the console (was already there — discoverability was the gap).
- Hordes: REPOP pressure every 18s (floor 10 within 45 tiles, cap 120) +
  hordes.json 5 curated synergy presets (60/40 curated/wild) + wisp support
  + mixing 0.45. REPOP OK.
- Ember Flask (R): gated FLASK OK. First level at 6 kills (opening hook).
- ESC->haven: probe GREEN in source (esc_probe.tscn); RAM bounded ~110-125MB
  (mem_soak.tscn); F3 readout (fps/RAM/VRAM/nodes) for live checks.
- PERF SUSPECT: docker container imagesvc-imagesvc-1 (python run.py, ollama,
  23h+) holds ~3 GB of the 6 GB VRAM — `docker stop imagesvc-imagesvc-1`
  frees it (Ricardo's call, not ours).
- Nakama SELF-HOST LIVE: tools/nakama.sh up (postgres:16 + heroiclabs/nakama,
  compose at tools/nakama/) — console :7351 (admin login on first visit),
  api :7350, game :7349, dev key dh_local_dev_key. tech/26 §9. Roadmap 6b
  (game client auth/leaderboards) is next; 6c Pix design; 6d blockchain PICK;
  6e three play modes canon-locked; 6g leaderboard->cosmetics (auras/wings/
  legendary mounts) queued.
- Packages rebuilt (all of the above inside).

## 2026-09-14 (latest+10) — the training console: graph, bracket sweep, benchmark browser, global rank

Ricardo: *"to the trianing onsole: graph overflows from the rendered screen. Add
tournament mode for the train all method, as well. Also, a better benchmark
interface, filtered by creature"* + *"and a global rank for the all vs all,
where every model net compete for the top in a balance fight"*. All four DONE —
`3c44285`, `8b2ae3e`, `6844eb2`, `d2d194b`. Roadmap has the full write-ups.

- **Graph overflow** was ONE canvas: 640x360, the project default. `_fit_window`
  walked candidates that all needed `usable.size.y >= 636`; when none fit the
  loop just ended and `content_scale_size` stayed at the project default, 90
  logical px shorter than the console's content. New permanent gate:
  `game/arena/tests/console_layout_probe.tscn` — 7 canvases x every tab.
- **TRAIN ALL bracket:** `tools/train_run.sh --tournament` + a `bracket`
  checkbox. Ticked, TRAIN ALL reads "TRAIN ALL ⚔" and each creature's methods
  compete for its pin. `--resume` is refused on a tournament run (no
  per-generation checkpoint exists for a bracket).
- **Benchmark browser:** `ml/data/benchmarks/` holds THREE schemas now and the
  history rendered them all through the versus fields — every bracket read
  "? vs ?  0-0  ?". Each schema has its own row and detail; filtered by creature
  and by kind, and they compose.
- **Global rank (NEW `ml/training/ladder.py`, `league ladder`, RANK tab):** both
  sides on the SAME build, both orientations, every entrant vs every other, so
  the policy is the only variable. `league round-robin` was a stub AND asked the
  wrong question (different builds = ranks the creature). Points 3/1/0, episode
  win rate, HP margin, Bradley-Terry rating on the Elo scale.

**!! game/arena/console.gd HAD NOT PARSED AT HEAD SINCE `aa35f2b` !!** Two call
sites were committed without their definitions — hunk-level staging across the
two concurrent sessions split a refactor from its users:

    Parse Error: Identifier "left_frame" not declared            (console.gd:363,364)
    Parse Error: Too many arguments for "_spawn_train_run()" call
                 Expected at most 2 but received 3.              (console.gd:857)

Every commit from `aa35f2b` to `3c44285` shipped a console that could not boot.
The selftest never caught it because it runs the WORKING TREE file, not the
committed one. `8b2ae3e` carries the missing halves in. **Lesson for both
sessions: after partial-hunk staging, parse-check the COMMITTED blob, not the
working tree** — `git show HEAD:<path>` into a scratch copy and run the gate.

**FIRST REAL LADDER (bog_golem body, 4 entrants, 12 matches, 7.2 s):**

     1  scripted                 9 pts  6-0-0  100%  hp +0.381  rating  287.0
     2  grave_shade v1           4 pts  3-0-3   50%  hp +0.107  rating    0.0
     3  gloam_wisp v1            4 pts  3-0-3   50%  hp +0.103  rating    0.0
     4  native                   0 pts  0-0-6    0%  hp -0.591  rating -287.0

The scripted baseline beats both trained nets in a body neither was trained for.
Worth a look before the next sweep — it says how little these policies transfer.

Gates: CONSOLE SELFTEST OK, CONSOLE LAYOUT OK (5 tabs), pytest ml 98 passed.
