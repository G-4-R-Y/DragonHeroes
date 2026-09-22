# Asset audit — 2026-09-22 (R81)

**Recommendation:** finish one excellent, repeatable animated creature family
and one coherent gameplay scene before expanding asset generation. The largest
opportunity is the connection from authored form and motion to the shipping
frame. More prompt adjectives, a larger catalog, or another lighting system
alone will not close that gap.

This is an evidence-backed review and a proposed sequence, **not a new approved
art canon or a claim of shipped improvements**. Baseline: `master` at `3c006ac`,
with concurrent Arena UI edits preserved. The supplied brief is archived
[verbatim](../harness/requests/2026-09-22-asset-pillars.md). Governing contracts:
[canon](../00-canon.md), [living pixel world](../design/26-living-pixel-world.md),
[hi-fi generator](../tech/40-hifi-sprite-generator.md). Earlier work and proposals
in [the visual catalog](../design/19-visual-om-catalog.md) remain relevant; shared
lighting, approximate normals, fog, water, LUTs and pools already exist.

## What actually exists

| Surface | Inspection result | Consequence |
|---|---|---|
| Hunt actors | 10 `game/prototype/art/*/atlas.json` bundles; zero identify as hifi | The new generator has not replaced the shipping actor library |
| Creature catalog | 1,000 normal entries reference 7 bundle keys; 100 legendary entries use 40 explicit bundle references and 60 empty/fallback references | Creature count substantially exceeds distinct body art; recolors cannot supply 1,100 distinct silhouettes |
| Hero | 52×52 source cells, 26×26 logical size; 7 clips with 2–8 frames | The core actor is still the small earlier rig, despite richer concept art elsewhere |
| Existing motion | Each declared clip has byte-distinct frames; no identical whole clips in the 10 atlases | Repetition is not simply duplicate PNGs: pose range, timing and reuse of body families need visual review |
| Orun | Legacy RGBA 1774×887 source remains active, with idle only; v2 is RGB 1024×1536, 4×6 cells | V2 is still a rejected candidate, not an animated production boss |
| Orun renderer | `game/living/trial.gd::_draw_actor` selects `_atlas.clips[0]` | Adding clip names to JSON alone cannot make the fight animate its actions |
| Hifi export | `write_bundle` puts every input in a single looping `idle` row; logical size defaults to half the grid | It is currently a static/idle authoring path, not a complete action compiler |
| Environments | One record in `content/core/biomes/`; fresh Hunt capture still dominated by repeating grass marks | Environment composition is a high-payoff parallel art task |
| Reproducibility | Prompt-verification code depends on untracked `sprites prompt.md` | Tests can pass locally while a clean clone lacks their input; preserve Ricardo's private note and move the approved contract into a tracked canonical asset |

Catalog counts describe data references, not unique runtime bosses or an assertion
that all encounters look identical. The original 10 atlases' diffuse + normal
decoded RGBA footprint totals **4.514 MiB**, excluding strips, imports, other
textures and runtime allocations. By comparison, **24 frames × 256² × RGBA ×
two channels = 12 MiB for one uncompressed actor**. More pixels need an explicit
resident texture budget.

The fresh [Hunt frame](../art/asset-audit-2026-09-22/hunt-baseline.png) shows the
practical visual bottleneck: the hero and target occupy a small central area,
grass has high-frequency marks almost everywhere, and a large share of the
frame has little compositional or biome distinction. Larger, quieter ground
shapes and meaningful landmarks should improve readability and atmosphere
before adding more surface detail. This is visual judgment, not an automated
score.

## The gates are useful, but insufficient

`python3 -m pytest genforge/tests/test_hifi.py -q`: **23 passed**.
`python3 -m genforge.hifi selftest --out genforge/candidates/r81/selftest`:
**PASS, 100/100 after processing**. That validates the synthetic fixture and
the current contract; it does not validate Orun or measure artistic quality.

I ran the existing local processor on exact 256×256 cells **0, 4, 8, 12, 16,
23** from Orun v2, one representative from each intended clip. No provider
call, staging, approval or source replacement occurred. Results are preserved
in [diagnosis.json](../art/asset-audit-2026-09-22/diagnosis.json), with the
[diagnostic output](../art/asset-audit-2026-09-22/orun-diagnostic.png).

1. **Six of six samples fail.** Five fail minimum silhouette fill and all six
   report zero emissive-core pixels after processing. A dim/dead core should
   eventually be a clip-specific expectation; its absence in the standing
   samples is the important failure. The per-creature rule cannot express
   that distinction today.
2. **Background removal is not solved for real art.** The border flood removes
   the outer checkerboard but the inspected result retains pale patches inside
   enclosed shapes. Re-inking their boundaries can make those defects harder
   to remove. Semantic masks/manual repair are necessary before approval.
3. **Scale changes by pose.** The five sampled upright poses reduce by 2;
   the collapsed pose reduces by 1. In a controlled array test, widening a
   240×100 opaque rectangle to 241×100 makes `fit_canvas` output 120×50.
   Independent fitting cannot provide stable animation. All frames need one
   scale, camera and authored root/contact anchors.
4. **Palette identity is not shared across a sequence.** The six samples create
   six different palettes; `palette.json` exports only the first. Individual
   albedos are still rendered, but shared palette/LUT meaning and temporal color
   consistency are unproven. Fit a family/material palette once, then quantize
   every clip against it.
5. **Duplicate-frame animation passes.** Bundling the same processed synthetic
   frame twice returns PASS. `write_bundle` aggregates frame checks; it does not
   validate motion, action coverage, event timing or loop continuity. Runtime
   `ensure_animations` aliases missing actions from walk/fly/idle: useful for
   keeping a prototype running, never an art approval.
6. **Pixel dimensions are treated as proof of pixel craft.** `evaluate` accepts
   the native-grid check immediately for a 256×256 input, and `grid.estimate`
   reports conformity 1 for these 256×256 painted cells. This is a format
   check, not proof of well-designed clusters or a faithful original lattice.

Do not tune the failing thresholds until these images pass. Preserve the
rejection, fix sequence processing, and judge the resulting animation in-game.

## Which parts of the new brief to keep or refine

Keep **material clusters, distinct silhouettes, isolated albedo/emission,
readable anticipation/contact/recovery, and discrete poses with smooth VFX**.
These reinforce the existing direction. Preserve the supplied master prompt
as a versioned brief; evolve a separate production specification deliberately.

Several technical assertions should not become unconditional rules:

- **Normals are not geometry, specularity or shadow casters.** The current
  bevel/luminance-relief stage estimates surface shape from painted brightness;
  a dark painted stripe can become a fictitious groove. Its output is useful
  but approximate, as design/26 already says. Prefer authored material/height
  masks or normals rendered from approved geometry. Cast shadows still require
  occlusion information; Godot documents that separate setup in
  [2D lights and shadows](https://docs.godotengine.org/en/4.6/tutorials/2d/2d_lights_and_shadows.html).
- **Emissive pixels do not automatically illuminate the floor.** The hifi shader
  decodes a mask and brightens the actor. Ground light still comes from our
  separate registry/pools. Declare emission masks and bounded light sockets
  together, including animation intensity curves. Hue selection is a fallback,
  not a reliable way to distinguish turquoise cloth from a turquoise lamp.
- **“Glow requires Vulkan” is stale for this engine version.** Installed Godot
  is 4.6. Its documentation describes a simpler Compatibility glow path, while
  HDR 2D remains a Forward+/Mobile feature. Our Hunt currently only creates
  WorldEnvironment glow in the non-Compatibility branch. A controlled GL-only
  comparison is reasonable; enabling HDR or changing renderers is not required
  for this audit and was not done. See
  [Godot 4.6 glow](https://docs.godotengine.org/en/4.6/tutorials/3d/environment_and_post_processing.html#glow).
- **3D→2D is a credible production path, not free animation.** Motion Twin
  confirms that much of Dead Cells' art originated in 3D
  ([developer FAQ](https://motiontwin.com/faq)). That does not establish every
  claim in the supplied brief about cloth simulation, exact frame rates or
  Phantom Tower's implementation. Retopology, rigging, contact poses and art
  direction remain work. No Blender bake stage currently exists in GenForge.
- **Screen scale and perspective must be explicit.** The brief's side-profile
  stance is not our canon angled top-down camera. A universal 256px cell or
  eight shades per material does not guarantee a better 26px hero. Separate
  source resolution, logical footprint and screen pixel density; select detail
  by role. Retain the outline contract pending review, but test its actual
  contrast on dark terrain: dark ink alone cannot guarantee legibility.
- **A silhouette is not the combat hitbox.** Antlers, wings and trailing cloth
  need not be damageable. Author contact/readability against the authoritative
  shapes instead of deriving gameplay geometry from decorative pixels.

The inspected primary sources do not verify Phantom Tower's precise normal,
HDR, outline or particle implementation. It remains a visual reference here.

## Proposed sequence, ranked by payoff

| Order | Deliverable | Why it can multiply results | Acceptance evidence | Existing ledger |
|---|---|---|---|---|
| 1 | One animation compiler shared by rig bake, hifi imports and living chapters | Every subsequent creature inherits stable scale, palette, clips, anchors, emission and review | Orun's six real actions reach the fight; no aliases count as authored coverage; contact/recovery track native state; repeatable clean-clone build | R01/R06/R36/R42/R52 |
| 2 | Hero + Orun + one ordinary creature as the reference scene | Tests the art at actual play scale and exposes inconsistency before catalog multiplication | Matched-scale idle/move/attack/death capture, bright/dark scenes, overlapping enemies and VFX, agreed visual review | R26/R30/R52 |
| 3 | A Gloamfen environment kit and one contrasting biome | The floor, props and composition occupy most of every frame | Quiet traversal ground, authored clearings/ruins, clustered props, shoreline transitions, recognizable biome without a label; deterministic placement and streaming budgets | R09/R29/R45 |
| 4 | Reusable family rigs with a Blender→sprite pilot | Reuses poses, true geometry normals and attachment points for skins, equipment and pets; most plausible order-of-magnitude throughput gain | One quadruped in both existing 2D-rig and offline 3D-bake paths; compare accepted clips per artist-hour, repair time, local RAM/VRAM and atlas bytes | R06/R14/R52/R72 |
| 5 | Semantic VFX/material recipes on existing pools | Each weekly skill/item gains recognizable tells and payoffs without new engine code | Tell→contact→aftereffect, muzzle/weapon/core sockets, distinct friendly/hostile cues, high-rarity effects that do not hide danger; crowded capture and bounded allocations | R12/R13/R18/R43 |

**First practical slice:** finish Orun's authored action sheet (including its
remaining cleanup/identity issues), route it through shared sequence processing,
drive its clips from fight state, and capture it beside the current hunter in
the shrine. Then upgrade the hunter and one ordinary enemy to that tested
scale/material contract. This creates a standard worth applying to the catalog.

The compiler should preserve stable asset/content IDs while making camera,
logical size, root/feet anchors, clip timing, normal convention, material IDs,
emissive masks and effect sockets explicit. Bind visual events to authoritative
combat ticks; do not let a faster animation change the damage window. A single
resolved manifest should drive Hunt, pets, the lair and review tools. Store
approval separately from technical validity; hash the manifest, metadata,
palette and dependencies as well as PNGs. Hifi currently hashes only its three
output sheets in `outputs`.

Use the existing local parts/pose rigs for initial throughput. The offline
Blender pilot is a measured comparison, not an engine migration or a commitment
to regenerate every enemy in 3D. GenForge cleanup/baking works locally now;
the hifi provider adapter currently exposes OpenAI, and the requested local
image backend is still pending. No paid generation was needed for this audit.

## Measuring “order of magnitude” honestly

Visual quality has no defensible “100×” unit. Measure **accepted animated
creatures per authoring hour**, rejection/repair minutes, number of distinctive
family silhouettes, and total weekly accepted content. Record generation/bake
time and cost separately. A reusable rig might deliver a 10× throughput gain;
this is a hypothesis until compared against a real baseline batch.

Separate hard technical gates (alpha, bounds, valid channels, required clips,
stable anchors, runtime references, decoded memory, provenance) from artistic
review (anatomy, material identity, motion weight, composition) and gameplay
review (tell recognition, contact clarity, hostile/friendly discrimination).
Use a fixed held-out set of real assets, including bone/white cloth, disconnected
antlers, translucent effects, a dimming death pose and equipment variations.
The generator should not rank itself solely by the properties its cleanup
stage has just forced into the image.

Current fresh baseline: `python3 tools/profile_client.py --label r81-audit
--seconds 5`, **GL Compatibility**, Intel RPL-S, assisted Hunt seed 42:
301 frames in 5.017s, **60.002 average FPS**, frame interval p95 **17.424ms**,
p99 **17.786ms**, max **18.307ms**, physics p95 **5.829ms**, process p95
**6.151ms**, peak 57 creatures / 130 draw calls, worst stream apply **1.179ms**.
[Full receipt](../art/asset-audit-2026-09-22/hunt-baseline.json).
This is a short source-build sample, not GPU timing, a no-training comparison,
a sustained lock guarantee, an RTX 4080 measurement or a mobile certification.
Future art comparisons must use matched load/settings and longer frame-time
sampling, including target mobile hardware. Keep the 60 FPS budget; do not
trade it away to increase candidate score.

## Evidence files and reproduction

- `docs/art/asset-audit-2026-09-22/hunt-baseline.{png,json}`: fresh gameplay
  frame and measured profile; image is gameplay, not a generated concept.
- `diagnose.py`: offline audit driver. From the repository root run
  `python3 docs/art/asset-audit-2026-09-22/diagnose.py`; outputs go only to
  ignored `genforge/candidates/r81/`. Depends on the current hifi code and
  preserved Orun v2 source; performs no staging or provider call.
- `diagnosis.json`: six sampled real-frame scorecards, shared-scale threshold
  reproducer and duplicate-frame PASS evidence from that driver.
- `orun-diagnostic.png`: failed processing output, preserved to make the defects
  reviewable. **Not approved replacement art.**

No gameplay/shader/generator changes, external publishing or binary rebuild
were performed by R81. The current default packager is already
`python3 tools/package_build.py all --require-clean` (R77); the older
`package_codex.py` command is obsolete.
