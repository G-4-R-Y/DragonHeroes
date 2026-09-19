# Recovery work in flight — 2026-09-12

All quota-outage requests and new continuity/community directions are tracked
as R01–R26 in 20-roadmap.md. Full recovered prompts: requests/2026-09-12-recovery.md.
Canon §12.47; design/27, tech/36 and business/33 distinguish decisions,
proposals and official-server gates. Original publication e036a7c succeeded.

In-flight 2D slice: authored hero cast/heavy/spin/dodge clips + 8-frame walk,
finite fallback actions, slash orientation and recycled shader parameters;
shared companion portraits/nicknames, save isolation on character switches,
Haven main-menu return, wrapped six-tab navigation, visible Flask and saved
world-visibility slider. R03/R04/R07 are gated complete; broader UI/art remains.
115 Python tests pass; renewal_probe and click/flask/level-up pass. GL captures
in prototype/tests/captures/renewal show remaining floor/hero/HUD art work;
performance sample must be warmed/settled before claiming 60 FPS. Linux
launcher installer now also associates the executable PNG using GIO, creates
an in-folder .desktop shortcut and handles relocation; native desktop proof and
rebuilt packages remain pending. Rebirth still waits for 2D; "plebs" means
local CPU/6 GB GPU 3D generation. No public backend/economy deployment implied.

Stream recovery: obsolete loads discarded, nearby ground prioritized, unfinished
movement fence closed, failed helper retries, unload reversal reconciliation,
49-chunk peak and bounded 7×7 worker SDF. stream_recovery passes far negative
travel, stationary retry and deterministic revisit (worst apply 1.07 ms; ordinary
stream 1.10 ms). Actual biomes and encounter hibernation still pending R08/R09.

Warmed actual GL receipt: 300 gameplay frames at reported 60 FPS; frame median
16.668 ms / p95 16.911 ms, CPU process median 3.813 ms / p95 4.218 ms. PNG readback stalls
are excluded. Full captures and reproduction: docs/art/ui-renewal/README.md.
This is a short desktop sample, not a sustained/mobile guarantee. First playable
recovery milestone is being committed/pushed and packaged; all remaining R-items
stay scheduled/in progress.

Publication checkpoint 2026-09-13: recovery milestone 3f52b35 pushed to GitHub.
Both initial Codex exports pass ZIP/hash/icon checks; Linux passes real menu,
Hunt/resource refill, practice effects and saved lair→Hunt→rush journey. Windows
has verified PE icons but no native Windows gameplay test. Staging changed only
chapter.json's decoded texture count 7573376→8049280 for the larger hero sheet;
initial manifests correctly flag dirty source. Commit this generated metadata
and rebuild with new --require-clean so both final manifests identify one clean
revision. Linux GIO/file-manager association still to verify, then resume R08/R09
and the larger 2D backlog. New "resume work" prompt archived verbatim.

---

# Systems Map — current state per system (2026-09-10, HEAD = v0.3.0 era)

Format: **status** · law doc(s) · key files · gate · known issues. Pointers,
not prose — open the law doc before touching a system.

## World & procgen
**LANDED, infinite (v0.2.0).** tech/24 (generator), tech/29 (streaming),
canon §12.32. C++: `sim/libs/dh-procgen` (stateless coordinate hashing),
`sim/libs/dh-server/src/main.cpp` (`--dump-chunks R`, `--dump-window
cx0,cy0,cx1,cy1`). Godot: `game/prototype/world_gen.gd` (ProtoWorld — 5×5
window, load r=2/unload r=3, worker-thread dump+JSON+SDF, row-budgeted
apply, signals `chunk_loaded/unloaded`, `can_stream/loaded_bounds/
chunk_map_image`; `forced_seed` for co-op parity; `_find_dh_server()` also
looks next to the executable). Gates: STREAMTEST (worst apply ≤2 ms),
SPAWNTEST. Issues: cold 25-chunk teleports take ~700 frames to fill (normal
walking never sees it). Codex adds versioned lair metadata via `dh-procgen/lairs.hpp`,
clear-pad placement and streaming-lifetime assertions; richer TRELLIS-style
features remain pending.

## Lighting stack (the "physical" cues)
**LANDED (v0.1.13→v0.1.17).** canon §12.28-12.30, design/18, design/19.
`darkness.gd` (multiplicative quad z=10, ambient, 16 holes, statics with
handles, LIGHT REGISTRY → `dh_light_tex`/`dh_light_count` globals;
`set_sdf`), `shaders/darkness.gdshader` (sphere-traced SDF shadows, 4×4
Bayer bands), `lights.gd` (32-pool ground ellipses z=11), `fog.gd`,
`motes.gd`, `shaders/sprite_lit.gdshader` + `bundle_art.gd` (CanvasTexture
diffuse+normal, cel N·L, ONE shared material via `ProtoGlow.lit_material()`),
`genforge/pipeline/normal_gen.py` (bevel+Sobel `_n.png`). Gate: FXSTRESS +
captures. Issues: SDF shadow direction near rock ridges never visually
confirmed; normals are approximations until the 3D-to-sprite pipeline.

## Atmosphere, FX & post
**LANDED.** design/18, canon §12.29. `fx.gd` (pools, ring() width fix,
burst halos, light forwarders), `shader_fx.gd` (72 precompiled materials,
umbra/firestorm/nova), `shaders/*.gdshader` (firestorm TIME advection, umbra
hue-preserving rim, water shore foam, prop_sway, macro_tint), `post.gd` +
`post.gdshader` (haze, split-tone, 2D-strip LUT `set_lut()`, LUTs in
`art/luts/` from `genforge/pipeline/lut_gen.py`), cosmetics shaders
(aura_body/weapon_aura/necklace_bead). Labs: `genforge/vfx_lab/*`. Gate:
FXSTRESS (frame_ms < 16.6; ~4-5 ms today). Rule: over the dark world FEWER
additive layers read as MORE.

## Terrain dressing
**LANDED (v0.1.16).** `world_gen.gd` dual-grid transitions (forest/grass,
rock/grass; water keeps hard edges), `_pick_variant` macro patches,
`macro_tint.gd`. Issue: lakes read near-black at night with hard edges —
a water/shore transition pair is the open item.

## UI & typography
**LANDED (v0.1.18).** canon §12.31. `ui/theme.gd` (ProtoTheme doctrine:
Pixel Operator 8/16, AA off, `SIZE_BODY/SIZE_TITLE/snap()`, fallback AND
default-theme restamp), `ui/main_menu.gd` (name-chip class cards, CO-OP
button), `ui/haven.gd`, `ui/character_panel.gd`, `ui/lang.gd` (EN/PT-BR),
`ui/display.gd`, `damage_numbers.gd`. Gate: CLICKTEST (16 checks). Issue:
skill-bar labels clip at fixed widths ("Lumenpie").
**2026-09-12 identity pass:** `ui/theme.gd`, `ui/world_frame.gd`,
`ui/slider_rune.svg`, `living/lair_menu.gd` + `artifact_card.gd` share bronze,
ivory and Lumen styling, cached shrine framing, visible focus and bounded lore
previews on data-driven rarity cards. Menu/Haven/options keep their existing
flows. Actual GL frames + metrics: `docs/art/ui-identity/`; capture tool accepts
`UI_LANG` and `UI_OPTIONS`. Law: design/26, canon §12.45. Production HUD,
class sigils, bestiary and full gear-card migration remain scheduled.
Approved Codex source is now on `master` (70e8b4f); fresh verified Linux/Windows
Codex archives live in the original workspace under `builds/codex/`.

## Hunt progression sustain
**Level-up refresh (2026-09-12).** Law: canon §12.46, design/24.
`player.gd::refresh_on_level_up`, `main.gd::_grant_level_ups`,
`mp/host_driver.gd`: recompute stats, replenish HP/dodges/flasks, clear obsolete
refill timers, refresh HUD before feedback; host applies party parity. Preserve
builds, cooldowns, class stacks and death state. Normal apply_stats never heals.
Gate: `tests/level_up_probe.tscn` (`LEVEL UP OK`, real creature deaths).
**Scaling audit:** hunter level cap 100; monsters read level at spawn; item
rolls use +4%/ilvl (normal progression reaches 100); forge +5. Frontier scales
elite-affix odds, not extra levels. Rush HP caps at 1.5×. No endless progression
system exists. Sources, formulas and proposal/runtime drift: design/24 audit.

## Combat, classes, skills (prototype rules — presentation-side for now)
**PLAYABLE; overhaul SCHEDULED.** design/10-11 (kits), design/21 M-C (the
overhaul), design/24 §1 (polish pack landed: input buffering, dodge
i-frames, point-blank hits…). `player.gd`, `creature.gd`, `boss.gd`,
`hag.gd`, `pyre_sovereign.gd`, `terravore_colossus.gd`, `wisp.gd`, `pet.gd`,
`projectile.gd`, `stats.gd`, `telegraphs.gd`. Known: hitboxes are
sprite-scale hacks (Ricardo: "too sketchy"), pets' rolled skills never cast
(L4), bolts fly through walls. The real fix is L5: authority into `dh-sim`.

## Bestiary & content
**LANDED.** design/13-14, tech/23. `content/` packs + `content/schemas/`
(incl. `arena_build.schema.json`), `tools/validate_content.py` (46 defs / 11
types / 5 registries). 1000 normals + 100 legendaries from
`genforge/pipeline/bestiary_gen.py`; actor art bundles in
`game/prototype/art/<actor>/` (sheet.png + sheet_n.png + atlas.json).

## GenForge (art & asset pipeline)
**Playable Codex lairs + boss rush:** main menu → `game/living/lair_menu.tscn`.
`dh-procgen/lairs.hpp` emits seeded entrance metadata; `world_lairs.gd` renders
it and `journey.gd` retains the paused Hunt across a lair visit. `LivingTrial`
owns combat; `LairCampaign` owns earned unlocks, artifact grants/equipment,
rush rotation and bounded recovery/difficulty. `lair_profile.cpp` owns stable-ID
local saves, exclusive writers, atomic replacement and invalid-data preservation.
`tools/stage_living_preview.py` compiles v2 lair/phase/reward/placement data;
new guardians within the five-verb interpreter use authored atlases and kits.
`tools/check_lair_journey.py` exercises real world entry, native victory, saved
loot, exact-world return, helper restart, rush victory and round advancement.
The packager requires that exported journey plus the practice and Hunt gates.
Law: tech/35. Pilot: Orun, four artifact rarities, one local collection. P2P
lair entry, public authority, full action animation, ordinary gear/class/pet
migration and production loot balancing remain follow-ups.

**README key art:** `docs/art/readme-banner/dragon-heroes-banner.png`
(2172×724, 3:1), exact prompt + SHA-256 provenance beside it; relative embed
and descriptive alt text in root README. Law: design/26 + design/17. Gate:
visual title/composition review, PNG decode/dimensions/hash and link validation.

**Review-branch addition (2026-09-12):** modern pixel-art weekly chapter
pipeline in `genforge/living/`; strict `content/schemas/expansion.schema.json`;
sample `genforge/releases/bell_beneath_fen.json`; generated source art in
`genforge/art_sources/` and `docs/art/modern-pixel/`. Run
`python3 tools/review_living.py` for the offline review + C++ command probe.
Law: design/26, tech/34, canon §12.45. Gates: content validator, 24 living
tests (included in full 93-test Python run), CTest and `dh-effect-lab`.
This does not install candidates into the Hunt. Complete motion/attack
animation, gameplay application, rarity migration, mobile capture and pack
promotion remain explicit follow-ups on the roadmap.

**LIVE; mesh stage scaffolded.** tech/28, tech/31, canon §12.34/12.38.
`pipeline/{stub_provider,model_provider,providers}.py` (parts protocol),
`actor_art/bestiary_art/bake_game_art/assemble/manifest`, `normal_gen.py`,
`lut_gen.py`, `mesh_gen.py` (MeshProvider protocol; local adapters triposr /
hunyuan3d-mini / trellis / hunyuan3d via `DH_*_DIR` venvs; VRAM preflight;
`DH_MESH_OFFLOAD=1`; Cloud Run provider PARKED/commented), `service/app.py`
(v0 parts API), `service/mesh_cloudrun/` (PARKED, guarded). Gate: pytest
genforge (52). Issue: TripoSR local install blocked on `torchmcubes` vs CUDA
12.8 — see roadmap "NOW".

## Arena & ML (self-play creature AI)
**LANDED (v0.3.0); training console + `--speed` lever LANDED 2026-09-11
(design/25, canon §12.39).** design/23,
design/25, tech/25, tech/32, canon §12.35. `game/arena/` (arena.tscn
spectator/headless, ArenaProxy, policy.gd obs `arena.obs.v1`, scripted/neural
policies, recorder JSONL, builds/cosmetics; `console.gd`/`console.tscn` —
roster, Train/Stop child process, progress tail + fitness chart, Gate, Watch
one episode), `ml/training/{policy_net,league}.py` (numpy twin + ES league,
`--jobs N`, progress writer), `ml/training/tournament.py` (the method bracket
per creature; `tools/train_run.sh --tournament` runs it across the roster),
`ml/training/ladder.py` (the GLOBAL RANK: every net vs every other with both
sides on the SAME build and both orientations, so the policy is the only
variable — `league round-robin` ranks the creature, this ranks the net;
`arena.ladder.v1` verdicts, RANK tab), `ml/eval/gate.py`, `ml/serving/` (registry +
weights), content `core/arena/builds.json`. THE SEAM: league.py appends one
JSON event per line to `ml/data/progress/<key>.jsonl` (`--progress-file`
overrides; events start / match / candidate / generation / registered / gate /
error — design/25 §2); the console tails it every 0.5 s and tolerates partial
trailing lines and unknown events. SPEED: `arena --speed max` (+ engine flag
`--fixed-fps 60`, league.py's default) runs one 1/60 s tick per frame CPU-bound
— same seeded 2-episode set 0.91 s vs 22.1 s under the old wall-locked 4×,
bit-identical results; 16 workers ≈ 870× real time aggregate on the 20-core box
(flat past 16); parallelism ceiling = pop × opponents; NO GPU anywhere in this
tier. Training workers never build camera/HUD (only `--selftest` does, to gate
that path). Gates: ARENA SELFTEST, CONSOLE SELFTEST (`console.tscn --
--selftest`, headless), CONSOLE LAYOUT (`console_layout_probe.tscn` — 7 canvases
x 5 tabs), COSMETICS, pytest ml (98). Rule: LOCAL GPUs only
(§12.38). Issues: scripted baseline beats native AI — L1 data-driven AI profiles
is the unlock; fen_boar candidates take 0 wins vs native every match (fitness
moves on hp margin only) — opponent curriculum/shaping next (design/25 §5).

## Multiplayer
**P2P co-op v1 LANDED (v0.3.0); server-authoritative path = roadmap.**
tech/33 (P2P), tech/22/26 (Nakama/dh-net), design/21 (M-A/M-B/M-C), canon
§12.36. `game/mp/` (MpNet autoload ENet lobby+RPC, lobby.tscn, host_driver
20 Hz snapshots, client_hunt on shared seed, puppet.gd, bolt.gd). Gate:
`tools/mp_test.sh` (MP TEST OK — asserts input-driven displacement). Honest
scope: friends/LAN; ranked/economy stays official-server-only.

## 3D view (experiment)
**LANDED (v0.2.1), parked as experiment.** design/22, canon §12.33.
`game/prototype3d/{hunt3d.gd,hunt3d.tscn,world_data.gd}` — same chunks/art/
bundles as billboards + extruded rock + real lights. Feeds from mesh_gen
later. 2D stays canon.

## Engine experiments — Rebirth (`rebirth/`, own git repo, parent-ignored)
**Godot 3D + native C++ slices RUN and are GATED; UE 5.4 scaffold complete,
UNCOMPILED (no engine on the box); Unity parked by decision.** Plan
`rebirth/docs/01-plan.md`, execution log + open picks `rebirth/docs/02-status.md`,
canon §12.44. One combat table (five-skill dragon, enrage → retreat leap →
meteors → pounce, hunter i-frames/buffer/combo, pet howl) implemented in
`rebirth/godot3d/scripts/`, `rebirth/native/src/sim.cpp`,
`rebirth/unreal/Source/Rebirth/Combat/RebirthCombat.h`. Shared asset staging
`rebirth/assets/tools/gen_assets.py` (GenForge mesh_gen → GLB/.dhm/UE manifest).
Gates: `REBIRTH_SELFTEST=1 godot --headless --fixed-fps 60 --path rebirth/godot3d`
→ `REBIRTH3D OK`; `rebirth/native/build/rebirth-native --sim-only --verify` →
`REBIRTH-NATIVE OK` (+ ctest determinism). Captures: `rebirth/{godot3d,native}/captures/`.
OPEN (Ricardo): layout collision with the parallel session's root-level UE
scaffold + `rebirth-native/`/`rebirth-unity/` siblings; Godot Forward+ flip;
UE install (Epic account, ~45 GB).

## Packaging & platforms
**Desktop packaging LANDED; Android documented, not exported.** docs/USAGE.md,
tech/30 (Android/LAN), business/32 (open source: MIT code, CC BY-NC art
pending confirm). `game/export_presets.cfg`, `tools/package_game.sh`
(binary + dh-server + LEIA-ME), `builds/`. Issues: export templates (~1 GB)
installed locally for the Codex desktop exports; no touch controls; no mobile perf pass (60 FPS directive).

**Codex review packaging:** `tools/package_codex.py` rebuilds both clients and
helpers, bundles the offline review, records source/file hashes and verifies
archives. Windows uses `sim/build-codex-windows` to avoid upstream's tracked
build cache. `tools/build_app_icon.py` derives PNG + six-size ICO from a curated
**2026-09-19 (R52 built — the hi-fi sprite generator):** `genforge/hifi/`
turns `sprites prompt.md` into a generator with a gate: verbatim prompt
assembly (pinned to the file), six enforcement stages (transparent background
+ fringe, native 1:1 grid snap, 8-shade hue-shifted ramps, emissive channel,
dedither, Ink-Hold perimeter, ramp-relief normal map with the emissive packed
in B<128), a 13-check scorecard that grades ANY image the same way (the
astra benchmark harness: `bench`), Godot bundles on the `bundle_art.gd`
contract, provenance `dragon-heroes.art-source.v1`. `sprite_lit.gdshader`
lights packed-emissive pixels flat and pushes them into HDR. Gate: `python3 -m
pytest genforge/tests/test_hifi.py` + `python3 -m genforge.hifi selftest`
(offline). No API called; model id is a knob awaiting Ricardo. Doc: tech/40.
The R50 converged run finished the same day (tech/39 bullet): 2/7 deployed,
and a dh-env→arena OUTCOME gap on the greedy decode is now roadmap R55.

**2026-09-19 (R50 built):** `arena.mask.v1` action mask in all five runtimes
(`ml/env/dh_env.py` rule; `torch_policy.mask_heads`, `policy_net.decode`,
`neural_policy.gd::decode`, `Arena::action_mask`/`mlp_act`, `env_parity.act_from`)
pinned by `game/arena/tests/fixtures/action_mask_v1.json` — gates:
`ml/tests/test_action_mask.py`, `godot --headless --path game
res://arena/tests/mask_parity_test.tscn` (MASK PARITY OK), `sim-tests`. PPO:
greedy probes (`--eval-envs`), promotion on `greedy=` and reversible
(`--demote-wr`), snapshot reservoir, β/std annealing, plateau stop; knobs
plumbed through `tools/train_run.sh` and recorded in each run's `config.json`.
Ledger: `docs/tech/39-experiment-ledger.md` via `tools/experiment_ledger.py`.
Status: smoke-verified (fen_boar mirror: env_parity OK, greedy wins 1.00 vs
native in both runtimes); converged 60 M run is the next gate.
**2026-09-19 (R50 built):** `arena.mask.v1` action mask in all five runtimes
(`ml/env/dh_env.py` rule; `torch_policy.mask_heads`, `policy_net.decode`,
`neural_policy.gd::decode`, `Arena::action_mask`/`mlp_act`, `env_parity.act_from`)
pinned by `game/arena/tests/fixtures/action_mask_v1.json` — gates:
`ml/tests/test_action_mask.py`, `godot --headless --path game
res://arena/tests/mask_parity_test.tscn` (MASK PARITY OK), `sim-tests`. PPO:
greedy probes (`--eval-envs`), promotion on `greedy=` and reversible
(`--demote-wr`), snapshot reservoir, β/std annealing, plateau stop; knobs
plumbed through `tools/train_run.sh` and recorded in each run's `config.json`.
Ledger: `docs/tech/39-experiment-ledger.md` via `tools/experiment_ledger.py`.
Status: smoke-verified (fen_boar mirror: env_parity OK, greedy wins 1.00 vs
native in both runtimes); converged 60 M run is the next gate.
original; `tools/verify_package.py` checks actual Windows PE icon bytes and
Linux executable formats. Actual release-PCK smoke verifies a streaming Hunt;
fixed the exported helper capability check that silently selected an island. Source: `genforge/art_sources/app_icon/`; outputs:
`builds/codex/` (ignored). Optional Linux launcher ships with the package.
Law/runbook: tech/34 packaging section. Window title and saves are Codex-specific.

## Sim workspace (C++20)
**M0 benchmark harness.** tech/20-22, canon §10. `sim/libs/{dh-math,dh-sim,
dh-procgen,dh-server,dh-net,dh-env,dh-godot,dh-content}`; `cmake --build
sim/build`. The 2D Hunt exercises dh-procgen/dh-server world dumps; Codex lairs additionally
exercise the native trial/campaign host. L5 (full Hunt authority + RL throughput
port) remains the strategic production step.

## Tests & captures
`game/prototype/tests/` — vfx_showcase, vfx_iso, ui_capture, stream_test,
spawn_probe, click_test, fx_stress (+ captures/), `game/arena/tests/`,
`game/mp/tests/`, `genforge/tests/`, `ml/tests/`, `tools/mp_test.sh`.
Reference frames: `docs/media/v1-vs-v2.png`, `captures/03_firefield_burning.png`,
`captures/ui_hunt_far.png`, `captures/ui_3d.png`.

## Docs system
`docs/00-canon.md` (truth + §12 log) · `docs/README.md` (index) · `HANDOFF.md`
(volatile) · `docs/harness/` (durable, this) · `docs/USAGE.md` (commands) ·
design/ tech/ business/ research/ · `docs/media/`.
