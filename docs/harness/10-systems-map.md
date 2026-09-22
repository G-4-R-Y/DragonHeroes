# Urgent playtest recovery — 2026-09-13

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

# Recovery status — 2026-09-13

All prompts (including latest recovery reminders) preserved verbatim in
requests/2026-09-12-recovery.md; R01–R26 in 20-roadmap.md is the single ledger.
Canon §12.47; design/27, tech/36 and business/33 record continuity/community plans.
3f52b35 and b622aa6 pushed. Current clean b622aa6 Codex packages pass exported
Linux gameplay and Windows PE-icon/hash checks (native Windows play untested).

Completed prototype slices: Haven→title save/isolation, companion sprites and
nicknames, wrapped character tabs, visibility setting, visible Flask/HP/dodge,
finite locally baked action clips and resilient bounded terrain streaming.
R03/R04/R07/R15 done; broad UI/art/animation refinement still pending. Actual
Linux executable icon association verified after fixing Snap IDE GIO/XDG issues;
corrected installer still needs the next package.

R08 residency now implemented and fully gated, uncommitted: bounded active nodes,
primitive per-Hunt disk records, stable identity/HP/stats/statuses, paired bosses,
no dead revival/reward duplication, every hunter considered, flying water wakes,
120 active cap including summons, no unbounded visited RAM. Tech/29; files
encounter_residency.gd/main.gd/world_gen.gd/hag.gd; residency_probe + real streamed
GL return capture. All 20 Godot outcomes, 116 Python tests, CTest 4/4 and content
validator pass. GL return 60 FPS; process median 4.573 / p95 9.167 ms, adapter 0.707 ms,
stream 1.253 ms worst. Short desktop samples, not a mobile/slow-storage guarantee.

Modern hunter source candidate saved with prompt/provenance; needs component/
pivot ingest and a clipped-frame repair. Opaque checkerboard cleanup rejected.
Haven courtyard source saved but not integrated. Next after residency commit/
package: real hero/ALL-creature Orun art, native 5-biome terrain, Haven/crafting,
weekly enchantments and cosmetic XP. Rebirth local CPU / 6 GB GPU follows 2D; UE is
uncompiled. Old Codex branch has no unique commits; missing temp worktree and
superseded stash are preserved without reapplying. See HANDOFF for exact paths.

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

## Capture & pets
**LANDED (R57, 2026-09-22).** Law: design/13 §7.1. `creature.gd::capture_profile()`
is the single export seam — species id, archetype, element, tint, scale, the
level-free base hp/damage (it divides out the `1 + rate*(level-1)` that
`_apply_entry` baked in) and, for a legendary, the authored `kit`.
`main.gd::_roll_pet` rolls from a three-tier signature pool (legendary kit ▸
hand-written species row in `abyssal.json` ▸ `element_signatures` +
`archetype_signatures`), `pet.gd` dresses itself from that chassis and
re-derives hp/damage at the hunter's current level every tick, keeping its wound
fraction. **Every tier is capturable**: elites/legendaries bond as mini-pets
(HP gate 0.15/0.10, chance ×0.35/×0.15, keeps 25%/20% hp and 50%/45% dmg, drawn
at 0.5–0.6); a capture pays no loot, no rune, no kill credit, and the duo
survivor enrages. Pre-R57 saves carry no chassis and stay the founding 120/14
stalker. Gate: `tests/capture_probe.tscn` (`CAPTURE OK`), mutation-verified.
Known: `blood` and `frost` have no dedicated skill in `content/core/skills/` and
degrade to the neighbouring element's pair; rolled pet skills still never cast
(R65's remaining half).

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
x 5 tabs), TRAINER STOP (`bash tools/trainer_stop_test.sh`), COSMETICS,
pytest ml (98). Rule: LOCAL GPUs only
(§12.38). **R56 (2026-09-21):** the console launches the trainer under `setsid`
and STOP kills the whole PROCESS GROUP. The old `pkill -KILL -P <pid>` reached
one generation only, so anything spawned a level deeper survived Stop holding
the card; the group kill is safe only because setsid gives the trainer a session
of its own — Godot's own children inherit GODOT'S group, and `console.gd`
requires `pgid == pid` before it ever signals `-PGID`. A crashed trainer's
orphans are swept on the next poll too, not just on Stop. Issues: scripted baseline beats native AI — L1 data-driven AI profiles
is the unlock; fen_boar candidates take 0 wins vs native every match (fitness
moves on hp margin only) — opponent curriculum/shaping next (design/25 §5).
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

**2026-09-21 (R55-b — four divergences, and one clock):** damage is now booked
**by source** in every runtime — contact / bolt / field — through
`Arena::damage_by_source`, `dh_env_damage_by_source`,
`fighter.gd::note_damage_taken(dmg, source)` and the arena's
`dmg_{contact,bolt,field}_{a,b}` episode columns, and `ml/eval/env_parity.py`
reports `src_dealt`/`src_taken` beside the totals. Read over the FIRST 10 s only
(so the retreat endgame cannot dominate the mean) that pair localized four
things at once: the **Fiery elite affix** was absent from the sim (a second
packet of half the swing, booked as bolt — `specs.json` gained `fiery`, crossing
to dh-env by its own optional symbol `dh_env_set_body_affix`, never by resizing
`DhFighterSpec`); the **native kit driver** competed with the swing for the one
`act` slot instead of running on its own channel as `fighter.gd::pre_tick` does;
the kit bolt fan carried **aim noise** `cmd_aim` never applies to a creature;
**storm bolts were 3.0 px** where `projectile.gd` says 4.0. `env_parity` also ran
the two runtimes on **different clocks** (arena 45 s, dh-env 68.3 s) — one
`--time-limit` now drives both. Matrix worst ratio **3.17 → 1.93**, the
ranged-kit natives closed (cinder_drake damage-taken/s 2.31 → **1.01**). Gates:
`ctest -R sim-tests`, `ml/.venv/bin/python -m pytest ml/tests` (147 passed).
Residual: vs a scripted opponent the totals agree and the CLOCK does not —
`creature.gd::_separate(delta)` body separation exists in the arena and not in
the sim, and is the next port (also roadmap **R59**, where the same gap is a
gameplay bug: creatures stand on top of the player). Docs: tech/25 §5.3.1,
tech/39 §2.

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
pending confirm). `game/export_presets.cfg`, `tools/package_build.py`
(binary + dh-server + offline review + LEIA-ME), `builds/`. Issues: export
templates (~1 GB) installed locally for the desktop exports; no touch controls;
no mobile perf pass (60 FPS directive).

**One packager (R77, 2026-09-22 — the build merge):** `tools/package_build.py`
(the promoted `package_codex.py`) rebuilds both clients and helpers, bundles the
offline review, records source/file hashes and verifies archives. It exports to an
explicit staged path instead of trusting the preset's `export_path` — the drift
between those two is what made `builds/dragon-heroes-*.zip` ship a ten-day-old
client — and it refuses to write a ZIP that fails a gate. `tools/package_game.sh`
is a wrapper over it, keeping only `DH_FETCH_TEMPLATES=1`. Windows uses the single
`sim/build-windows` tree, falling back to the committed
`builds/prebuilt/windows/dh-server.exe` cache when llvm-mingw is absent.
`tools/build_app_icon.py` derives PNG + six-size ICO from a curated
original; `tools/verify_package.py` checks actual Windows PE icon bytes and
Linux executable formats. Actual release-PCK smoke verifies a streaming Hunt;
fixed the exported helper capability check that silently selected an island. Source: `genforge/art_sources/app_icon/`; outputs:
`builds/{linux,windows}` + the two ZIPs (all ignored). Optional Linux launcher
ships with the package. Law/runbook: tech/34 packaging section. Product name and
save directory are both "Dragon Heroes"; `game/tools/user_dir_migration.gd` (first
autoload) carries pre-merge "Dragon Heroes Codex" saves across on first launch.

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
