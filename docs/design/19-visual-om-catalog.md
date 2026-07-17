# Visual Order-of-Magnitude Catalog (2026-07-17)

Deep-research output (6 investigators + adversarial synthesis, ~350k tokens)
answering Ricardo's question: *"what would improve the visuals by orders of
magnitude — not incrementally — and what are the industry NAMES for it?"*
Everything below is verified against gl_compatibility (GLES3/WebGL2) + the
mid-mobile 60 FPS hard rule. Context: the darkness-quad lighting model,
atmosphere stack (fog/motes/water/sway) and capture loop shipped v0.1.13–14.

## The research's top 5 "do these next"

1. **Raymarched SDF 2D Lighting** (jump-flood distance field + cone-marched
   soft shadows — the "Noita-like" family). Occlusion is the single biggest
   cue our model lacks: today light passes through walls and creatures; this
   adds contact shadows with distance-softened penumbras. Fragment-only
   GLES3 proven (samuelbigos Godot GLES3, Yaazarai GameMaker). 2 days–2
   weeks. Every line of JFA/SDF work is reused if Radiance Cascades comes
   later — nothing is thrown away.
2. **Normal-Mapped Pixel-Art Sprites** + **automated normal generation**
   (Laigter CLI / distance-transform bevel + Sobel, arXiv 2212.09692) +
   **cel/palette-quantized `light()`** (the Dead Cells stack). Sprites stop
   being flat cutouts: the SAME ProtoLights records sculpt per-pixel volume
   and Hades-style rim. The toon-banded light response is the quality gate
   that keeps it reading as pixel art (raw normals = "greasy plastic").
   Keep the darkness quad as luminance authority; lights become the
   surface-detail authority. Automation is what makes it weekly-content
   compatible — one initiative, not two.
3. **Atmosphere stack** — light-modulated fog + **painted god-ray shaft
   cards** + ambient motes (Eastward/Hollow Knight/CoM). Fog + motes SHIPPED
   v0.1.14; remaining: procgen-placed painted light-shaft cards at clearings
   and cave mouths (screen-space radial-blur god rays REJECTED — wrong
   geometry for top-down, not mobile-viable).
4. **Dual-Grid Autotiling** (Oskar Stålberg / Townscaper corners; jess::codes
   2023-24) + domain-warped biome edges, optional 47-tile blob hybrid with a
   precomputed 256→47 bitmask LUT. Kills the #1 procgen tell (grid-staircase
   biome boundaries) in days of generation-time CPU; transition tiles emitted
   procedurally by the existing atlas painter.
5. **Per-Biome 3D LUT Color Grading** (Hades color-scripting doctrine, baked
   16³/32³ color cubes, crossfaded). Replaces the hand-coded split-tone with
   an authored data artifact that drives grade, darkness ambient, light
   colors, fog tint and VFX accents as ONE color identity per biome — AAA
   coherence as pack data. 2–4 days of shader work.

## Full catalog — STRUCTURAL-OVERHAUL tier

- **Master-Palette Discipline + palette-snap enforcement** (OKLAB
  asset-time quantization, Lospec-style ramps — Mark Ferrari doctrine).
  THE cohesion lever for art from three uncoordinated generators; CI-gated
  at import time, free at runtime. Prerequisite for LUT recolors + dither
  ramps + the 3D-to-sprite pipeline. 1–2 weeks.
- **Pixel-Perfect UI + Bitmap-Font doctrine** ("separate worlds" quarantine —
  saint11/Celeste; Diablo IV damage-number conventions folded in). Mixed-res
  vector HUD is the most-cited "amateur" tell and it's on every screenshot.
  ~1 week. Check PT-BR diacritics (ã ç õ é) in the chosen font.
- **VFX Anatomy Doctrine**: anticipation → climax → dissipation with a
  value/saturation readability hierarchy (League of Legends VFX style guide;
  Hades boon construction). A data-driven 3-phase composer over the existing
  pools; every weekly skill inherits the template. Days–2 weeks.
- **Living Top-Down Water v2**: CPU-baked shore-distance field per chunk
  (avoid `texture_sdf` — unverified on compat) + light-array specular.
  v1 (neighbor-mask foam) shipped v0.1.14; the distance-field bake
  generalizes to wet rock/ice/lava as data-only biomes. 1–2 weeks.
- **Decor Scatter Density Doctrine**: noise-modulated density fields +
  Poisson-disc/jittered clustering + MultiMesh litter (5–10x density for
  free). White-noise scatter is the third procgen tell. <1 week.
- **Herringbone Wang Tiles + authored chunk stamps / "pixel scenes"** (the
  Noita approach; stb reference is public-domain C for the sim). Landmark
  moments as pure pack content — shrine clearings, standing stones. Minimal
  version <1 week; full authoring loop weeks.
- **Radiance Cascades** (Alexander Sannikov / Path of Exile 2 — the 2023-26
  SOTA for 2D GI). Unlimited soft-shadow lights, every emissive VFX pixel
  becomes an area light. Fragment-only implementations exist (fad Shadertoy,
  jason.today, Yaazarai); run the light field at 320×180. NO published
  mid-Android benchmark — profile on target before committing. 3–5 weeks.
  Do SDF lighting first; RC marches the same field.
- **Faux-Verticality**: procgen height field + marching-squares cliff
  extraction, layered wall faces (CrossCode height maps / CoM walls). The
  single biggest environment gap vs the reference bar. Weeks–2 months.
  ⚠ CANON FLAG: the flat-vs-height decision must be made BEFORE the C++
  procgen port hardens the flat-plane assumption. Cheap probe first:
  reinterpret impassable T_ROCK as height-1 plateaus.
- **Pre-Rendered 3D-to-Sprite Animation Pipeline** (Dead Cells' "3D pipeline
  for 2D animation"; Hades pre-rendered characters). 10x frame counts with
  baked smears + per-frame normal maps feeding the sprite-lighting stack.
  2–3 months to stand up, then each creature costs days. Schedule after the
  master palette exists.

## INCREMENTAL tier (high value, small)

- **Bayer/ordered dithering on lighting gradients at the VIRTUAL pixel grid**
  (Return of the Obra Dinn). Turns smooth gaussian falloffs into authored
  pixel-art banding, ~10 ALU ops. Anchor the cell to 640×360 pixels and
  world-quantized coords so it doesn't swim. 1–2 days. Do with any lighting
  work.
- **Trauma-based screenshake + tiered hitstop envelopes** (Eiserloh "Juicing
  Your Cameras"; Vlambeer; Sakurai hitlag scaling): trauma², Perlin offsets,
  rotational shake, damage-scaled hitstop (30–50ms light / 80–120ms heavy)
  as an effects.json weight table. 2–3 days. Highest-priority incremental
  for an ARPG.
- **Graveyard Keeper-style projected sprite shadows** (skewed dark copies,
  ~3/object, MultiMesh off ProtoLights records) — entity grounding; the
  fallback/complement tier of SDF shadows. ~1 week.
- **Screen-space refraction/distortion impact layer** (one region-limited
  BackBufferCopy, pooled, intensity-gated) — as the climax-phase ingredient
  of the VFX doctrine. 2–4 days.
- **Macro variation layer**: low-freq Perlin variant selection + one
  multiplicative macro-tint quad (texture-bombing doctrine). 1–2 days,
  breaks the 16px repetition period map-wide.
- **Cel/palette-quantized light() response** — meaningless alone; ships WITH
  the normal-map milestone as its quality gate.
- **Flood-fill/propagation-grid lighting** (Terraria BFS / LPV-style) —
  fallback tier only; blobby and directionless. Keep in the back pocket for
  LOW-tier devices.
- **CRT/posterize RESTRAINT** (negative decision, now doctrine): sharp
  integer-scaled pixels; no CRT emulation; palette discipline over filter
  nostalgia. CRT masks are also the one researched effect that plausibly
  breaks mid-mobile fill budgets.

## Suggested sequencing (research's synthesis + session state)

Now → SDF lighting (occlusion) with Bayer dither; then normal-mapped sprites
+ automated normals + quantized light(); then dual-grid autotiling + macro
variation + scatter doctrine (one "procgen stops looking procgen" sprint);
then LUT grading + master palette + bitmap-font UI (one "cohesion" sprint);
VFX anatomy doctrine + shake/hitstop envelopes alongside. Radiance Cascades
and faux-verticality are the two big bets to schedule deliberately; the
3D-to-sprite pipeline is a strategic initiative after the palette lands.
