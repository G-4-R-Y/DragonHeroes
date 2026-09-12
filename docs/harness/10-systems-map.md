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
walking never sees it); TRELLIS-style POI/feature layers not yet generated.

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
`--jobs N`, progress writer), `ml/eval/gate.py`, `ml/serving/` (registry +
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
--selftest`, headless), COSMETICS, pytest ml (18). Rule: LOCAL GPUs only
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
not fetched; no touch controls; no mobile perf pass (60 FPS directive).

## Sim workspace (C++20)
**M0 benchmark harness.** tech/20-22, canon §10. `sim/libs/{dh-math,dh-sim,
dh-procgen,dh-server,dh-net,dh-env,dh-godot,dh-content}`; `cmake --build
sim/build`. Only dh-procgen/dh-server are exercised by the game today (world
dumps). L5 (authority + RL throughput port) is the strategic next step.

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
