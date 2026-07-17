# NOVA / EXPLOSION — procedural VFX

Pure-math radial blast: an expanding SDF ring shockwave + radial energy shards +
turbulent fBm core flash, all additive/translucent so the hero survives visually.
Frost-nova palette by default; retint via uniforms for boss ultimates / big kills.

![contact sheet](contact_sheet.png)

## Technique (all fragment-space, no textures)

- **Coords.** Centre UV to `[-1,1]`, take `r = length(uv)`, `ang = atan(y,x)`.
- **Front-loaded envelopes.** `R = 1.35*(1-(1-p)^2.3)` (ease-out: ring races out fast,
  eases at the end). `life = (1-p)^1.5` (fast fade + trailing tail). Everything is a
  function of these two, so the whole life snaps in and decays with one `progress`.
- **Ring shockwave.** SDF ring `1 - smoothstep(0, th, |r-R|)`; thickness `th` thins as
  it expands. Circumference gets *internal life* from two octaves of angular value
  noise + a subtle sinusoidal flicker (`stri`), so it reads as filaments, not a clean
  line. A separate, much thinner squared band (`edge`) is the hot near-white **leading
  edge**.
- **Chromatic dispersion.** The R/G/B ring radii are split by `disp` (grows with p):
  R samples slightly *outside*, B slightly *inside* → a tasteful warm-gold outer /
  cyan inner fringe on the bright edge (fire-meets-frost), never a separate halo.
- **Radial shards.** `pow(0.5+0.5*sin(ang*13), 9)` makes sharp angular spikes;
  per-shard length/brightness randomised by angular noise. Confined to a short band
  *behind* the ring front (`smoothstep(reach, reach-0.34, r)`) so they read as a
  shockwave, and they fade faster than the ring (`life^1.5`) so the ring stays the
  signature element late in the life. Hot white **tips** where a shard meets the front.
- **Debris flecks.** Thresholded value noise on a `(cos,sin)*40 + r*30` field, gated to
  a thin band at the front → sparse bright specks flung outward for punch/detail.
- **Turbulent core flash.** Domain-warped fBm (`warp` feeds `turb`) inside a core whose
  radius **blooms then collapses** (`sin(p*pi)`), lit by a hard Gaussian `flash` peaking
  near p=0 plus a tighter pure-white heart. HDR: pre-tonemap values exceed 1.0 for bloom.
- **Output.** Soft-clip `1 - exp(-rgb*exposure)` (hue-preserving), emitted through
  `blend_add`. The dark scene stays dark; the project's WorldEnvironment glow supplies
  the final HDR punch.

## Uniforms

| uniform | type | default | range / notes |
|---|---|---|---|
| `progress` | float | 0.0 | 0..1 — drive 0→1 over the blast; radius out, alpha down |
| `color` | vec4 (source_color) | (0.35,0.72,1.0) | icy base tint; retint for fire/void/holy |
| `core_color` | vec4 (source_color) | (0.80,0.93,1.0) | hot near-white core/edge tint |
| `dir` | vec2 | (1,0) | optional: rotates the angular (shard/striation) pattern; magnitude ignored, (0,0) safe |
| `seed` | float | 7.0 | per-cast variation of striations/shards/flecks |
| `intensity` | float | 1.0 | master brightness multiplier |
| `exposure` | float | 1.7 | soft-clip bloom knee |

### Suggested timing / param ranges
- **Frost nova (fast):** `progress` 0→1 over ~0.35 s (front-loaded curve does the snap).
- **Boss ultimate (bigger/slower):** scale the quad larger, `intensity` 1.2–1.6, ~0.6 s.
- **Big-kill pop (tiny):** small quad, ~0.25 s, default color.
- Retints: fire = (1.0,0.45,0.15)/(1.0,0.85,0.6); void = (0.6,0.3,1.0)/(0.9,0.8,1.0);
  holy = (1.0,0.9,0.55)/(1.0,1.0,0.95).

## In-game hook
One `pack.type.name` VFX entry (`vfx.nova.frost`, retint clones for others) fired by the
combat presentation layer on: frost-nova cast, boss ultimate telegraph-release, and
large-kill deaths. Drawn on a **square** quad centred on the caster/impact, sized to the
blast radius. `progress` driven by the client's interpolated effect timer; server stays
authoritative over the gameplay event, client owns the purely-cosmetic playback.

## Cost estimate (mobile budget)
- No textures, no screen read, no compute, no dynamic loops (fBm unrolled) — GLES3 /
  gl_compatibility safe.
- Per fragment (outer/ring region, the vast majority): ~4 value-noise evals
  (striation ×2, shard-var ×1, fleck ×1) ≈ 16 `sin`-hash taps + a handful of
  smoothsteps/pows. The expensive core fBm (`fbm3`+`fbm4` ≈ 28 taps) is **branch-gated**
  by `core_body`, so only the small central disc pays for it.
- On a modest blast quad (say ≤ 40k px on a mid-range phone) this is well inside a
  60 FPS frame with plenty of headroom; a full-screen blast still fits given the core
  gate. If a target is `sin`-hash-bound, swap `hash2` for a `dot`/`fract` hash
  (cheaper, cosmetically near-identical) — noted as the one optional deviation.

## render.py ↔ shader parity
`render.py` is the reference; `effect.gdshader` is a line-for-line port. A numpy
re-implementation of the shader body matches `nova()` to float32 precision
(max abs diff ~5e-7, i.e. rounding only). The single intentional difference: the
preview also applies a display gamma over the composited scene for the PNG; the shader
omits it and relies on `blend_add` + project glow instead.
