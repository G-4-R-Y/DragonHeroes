# 40 — The hi-fi sprite generator (`genforge.hifi`)

**Status:** built 2026-09-19 (roadmap R52). Provider-independent up to the
`ImageBackend` seam; no image API has been called by this pipeline yet.
**Brief:** `sprites prompt.md` at the repo root (Ricardo's; verbatim). The
roadmap's R52 block is its index. **Benchmark opponent:** "astra".

## 1. What it is

Ricardo's brief names five rendering pillars of the Dead Cells / Phantom Tower
register, a MASTER PROMPT and a MANDATORY NEGATIVE PROMPT. An image model can be
*asked* for the pillars; it cannot be *trusted* with them. The generator
therefore has three parts, and the middle one is the product:

1. **Prompt assembly** (`spec.py`, `creatures.py`) — the master prompt's fixed
   tail and the negative prompt are constants pinned to `sprites prompt.md`
   by a test (`verify_against_source`). A creature description fills the first
   slot; the stance and grid words can be swapped (pose-by-pose key frames,
   128 px ordinaries). Backends with no negative-prompt slot get the negative
   folded in as a hard-constraint clause; native ones get both fields.
2. **Enforcement** (`pipeline.process`) — six stages, in a fixed order, each
   reporting what it changed:

   | stage | pillar in the brief | what it does |
   |---|---|---|
   | `alpha` | isolated asset, clean transparent background | detects a painted checkerboard / solid backdrop, floods it from the border, eats the anti-aliased matte fringe (bounded, sub-logical-pixel), hardens alpha to binary (design/26 rule 3: no bloom in alpha), drops specks |
   | `grid` | crisp native 1:1 pixel grid, zero mixels | estimates the lattice the image actually follows (difference-mass concentration; divisors resolved by recursion; the requested grid as a prior), samples ONE logical pixel per cell (per-channel median), places the sprite on the 256 canvas with a margin. Integer block reduction only, never a resample filter |
   | `palette` | deep 8-shade ramps, directional hue-shifting | clusters the sprite's hues into material families, rebuilds each as exactly 8 shades spanning its lightness range, rotates hue cool in the shadows and warm in the highlights, adds one shared dark ink; nearest-in-OKLab quantisation (same maths as `living/atlas.py`) |
   | `emissive` | dedicated emissive core, engine HDR bloom | separates saturated bright pixels of the creature's declared glow hue into their own channel with a per-pixel intensity |
   | `dedither` | no noisy dithering, no point noise | isolated pixels (no 4-neighbour shares their index) join the majority neighbour; the emissive core is protected |
   | `outline` | Ink-Hold Perimeter, 1–2 px, unbreakable | measures the share of the silhouette boundary that is dark ink, paints the gaps in the palette's ink (1 px default, 2 px option), never over the core |
   | `normal` | normal-map-ready planar depth | `normal_gen`'s bevel + Sobel, plus the quantised ramps' lightness as relief (`height_bias`), so painted planes become real slopes; the emissive mask is packed into the normal map's blue channel low range (§3) |

3. **The gate** (`scorecard.py`) — every pillar measured on ANY RGBA image, so
   the same card grades a raw model output, our shipped sprite, or a
   competitor's file. Hard checks decide PASS/FAIL; advisory checks
   (pillow-shading correlation, light-direction agreement, hue-shift depth,
   ramp richness) are scored but cannot fail an asset. `score` is 0–100 for
   ranking. What the scorecard cannot grade: composition, anatomy, taste. A
   named artist's review stays the last gate (design/17 §5: no raw AI output
   ever ships).

Every run records the scorecard **before** (what the model delivered) and
**after** (what ships). The honest measure of a *generator* is the first; of
the *pipeline*, the second; `bench` prints both for every candidate of every
labelled generator, which is how the comparison against astra stays fair.

## 2. Commands (system `python3`; PIL + numpy; scipy optional)

```
python3 -m genforge.hifi prompt   --creature orun [--stance "..."] [--folded]
python3 -m genforge.hifi process  IN.png... --creature orun --out DIR      # any image, no API
python3 -m genforge.hifi generate --creature orun --out DIR [--n 2] [--model ID] [--backend NAME]
python3 -m genforge.hifi score    PATH... [--creature orun] [--json]
python3 -m genforge.hifi bench    --label ours DIR --label astra DIR --creature orun
python3 -m genforge.hifi selftest [--out DIR]                            # synthetic candidate, offline
python3 -m genforge.hifi creatures
```

`generate` is the only command that reaches a provider, and only when the
provider's key is exported (`OPENAI_API_KEY` for the OpenAI seam). The model
is a knob: `--model` / `GENFORGE_HIFI_IMAGE_MODEL`, else the seam's
`GENFORGE_OPENAI_MODEL` (default `gpt-image-1`). Ricardo asked for the cheap
tier (2026-09-19, "use gpt luna … as it's cheap"): GPT-5.6 Luna is OpenAI's
cheap TEXT model and does not generate images, so the cheap *image* tier is
what goes in this knob once he confirms it; Luna is the standing default for
any future TEXT call in GenForge. His local image-gen repo (roadmap 13b) plugs
in as another `ImageBackend` with `supports_negative = True`.

`--describe "..." --emissive-hue DEG` makes an ad-hoc creature; the registry
(`creatures.py`) covers Orun and the arena roster with each creature's glow
hue, which the emissive stage needs and no prompt can guarantee.

## 3. The bundle (what Godot loads)

`write_bundle` produces the `bundle_art.gd` contract plus channels:

```
<out>/sheet.png        albedo, one 256x256 cell per frame (row 0)
<out>/sheet_n.png      tangent normals; emissive packed in B < 128
<out>/sheet_e.png      emissive channel (review, other engines)
<out>/atlas.json       frame_size, anchor, animations{idle}, logical_size, channels
<out>/palette.json     dragon-heroes.hifi-palette.v1 (ink + ramps; `colors` fits style.palette)
<out>/scorecard.json   before/after per frame + every stage's report
<out>/provenance.json  dragon-heroes.art-source.v1 (+ pipeline config, prompt shas, output shas)
<out>/prompt.txt, negative.txt, review.html
```

**Emissive packing.** A valid tangent normal always has nz > 0, so its blue
byte is ≥ 128, and the flat default normal is 255. Hifi normal maps put
`B = 127·(1 − intensity)` on emissive pixels. `sprite_lit.gdshader` reads
`B < 0.5` as "emissive, intensity 1 − 2B", lights the pixel flat (the core is
"sharp unshaded glow" by spec) and multiplies it by `1 + intensity·emissive_gain`
so the Vulkan WorldEnvironment glow blooms it; under gl_compatibility the push
clamps and ProtoGlow's additive sprites carry the halo as before. Every
existing `sheet_n.png` decodes as "no emission". Cost: zero extra textures,
materials or nodes — pillar 2 reaches the engine inside the CanvasTexture the
frames already are. Parse-checked headless (`get_shader_uniform_list` lists
`emissive_gain`); a lit capture is owed when a hifi bundle first ships.

## 4. Gates and tests

`genforge/tests/test_hifi.py` (23 tests, offline): prompt constants pinned to
`sprites prompt.md`; each stage on a synthetic model-like candidate
(`fixture.py`: a correct 256-grid sprite damaged with a painted checkerboard,
4× bilinear mixels, a baked halo, an outline gap and a dithered patch);
delivered FAIL → shipped PASS with the original silhouette recovered
(IoU > 0.99); the clean sprite PASSes raw; integer upscales of 3/4/5 by
nearest/bilinear/bicubic detected with phase; a painted image reports low
conformity; the bundle/provenance contract; `generate` through a fake backend
(negative folded, provider recorded); the CLI. `python3 -m genforge.hifi
selftest` is the same story as one command.

## 5. What it does not do (yet)

- Animation: `KEY_POSES` (16 poses over the six required clips, pillar 4) is
  the plan for pose-by-pose generation; `write_bundle` packs N processed
  frames in a row, but temporal consistency between separate generations is
  a model problem the pipeline can only measure (silhouette area variation,
  as `living/atlas.py` does). The 3D→2D bake of pillar 3 is a different
  production path (design/17 §4), not this tool.
- Taste. See §1.
- A local backend (13b) — Ricardo's repo, when it lands.

## 6. Provenance of the design

`ImageBackend` seam and env-driven config: `genforge/pipeline/image_backend.py`
(tech/28). OKLab quantisation + emissive convention: `genforge/living/atlas.py`
(tech/34). Normal maps: `genforge/pipeline/normal_gen.py`. Art rules:
design/17 §3.3–3.4, §5; design/26 "Art direction". Canon §7 (gen-AI
first-class, curated).
