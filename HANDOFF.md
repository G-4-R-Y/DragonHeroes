# Handoff — running state (updated 2026-07-17, v0.1.14)

Read `CLAUDE.md` + `docs/00-canon.md` first (decisions log §12 is current through
item 29). This file is the delta: exactly where work stopped and what's next.

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

STRUCTURAL-OVERHAUL QUEUE (the "like the lighting fix" list, ROI-ranked):
1. Terrain art system: dual-grid/blob autotiling + biome edge blending +
   macro variation — the square tile grid is the last "prototype" tell.
2. Sprite lighting integration: normal-mapped pixel sprites (auto-generate
   normals in the GenForge bake) + directional shading from our own light
   holes — makes bodies feel 3D-lit like Dead Cells.
3. Animation authoring: smear/anticipation frames via the GenForge skeletal
   template pipeline (the "their animation is WAY better" gap).
4. UI/typography: pixel-perfect bitmap-font HUD pass (giant desktop fonts in
   captures read amateur next to the new world).
5. Vulkan flip on Ricardo's hardware: real HDR bloom over every emissive
   pixel (ProtoPost.set_hdr_mode seam is ready; only he can test).

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
