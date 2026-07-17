# firestorm — fire / ember plume

Procedural (no textures, no swept quad) fire plume for **emberkin hits, boss
breath, and ignite** DoT ticks. Living turbulence from fBm + domain warp;
`progress` drives a hard snap-in burst and a front-loaded burn-down with
trailing embers and smoke.

## Technique (fragment math, identical in render.py and effect.gdshader)

1. **Local frame.** Origin at `(0.5, 0.74)` of the quad. `dir` rotates the
   plume: `yup = dot(rel, dir)` (height along travel), `x = dot(rel, perp)`
   (perpendicular offset). Default `dir = (0,-1)` = screen-up.
2. **Value noise + fBm.** GLSL-style `sin`-hash lattice, smoothstep-faded
   bilinear value noise. `fbm_warp` = 2 octaves, `fbm_flame` = 4 octaves.
3. **Domain warp → tongues.** Coords are warped by two low-frequency fBm
   fields (strong horizontal displacement) and sampled with a **low vertical
   frequency (2.4x) vs high horizontal (7x)**, which stretches the noise into
   tall vertical flame tongues. A whole-column low-freq `sway` term makes the
   plume lean/wave instead of forming a clean cone.
4. **Height field / carve.** `field = (n*(0.55+0.85*grad) + grad*0.35) *
   horiz * below`, where `grad = 1-hnorm` lifts the base, `horiz` is a
   height-narrowing gaussian confinement, `below` hard-cuts under the origin.
5. **Two-layer edge.** `core = smoothstep(0.40,0.66,field)` gives the sharp
   bright leading tongues; `glow = smoothstep(0.16,0.52,field)` the soft
   translucent halo. This is the crisp-edge / soft-trail contrast.
6. **Temperature ramp.** `temp` (hot at base/core, cooling up and at edges,
   modulated by `n`) drives a 6-stop HDR ramp: smoke → deep red → orange →
   yellow → near-white → **white core > 2.0** (bloom-ready; preview clamps).
   A turbulence-carved white-hot base bloom is added and softened at the exact
   center so the hero marker peeks through at peak.
7. **Chromatic dispersion.** The field is evaluated at `x ± chroma`; the
   difference of the two core masks biases R vs B at the hot edges.
8. **Trailing smoke.** A separate late-peaking envelope drives a dark,
   translucent fBm plume that lives *above* the fire and outlives it.
9. **Ignition flash.** Radial white pop centered on the origin, spiked around
   `progress ≈ 0.06` for the hard snap-in.
10. **Ember specks.** 20 hash-seeded sparks advected upward (`phase =
    fract(progress*speed + loff)`), swaying horizontally, with a vertical
    motion-streak (anisotropic gaussian), flicker, and a white→orange cooling
    ramp as they rise.

All flame/ember/flash contributions are **additive** and gated by the life
envelope `env = rise*fall` (rise over 0..0.10, decay 0.25..1.0), so there is
zero ghost at `progress = 0` or `1`.

## Uniforms

| uniform    | type   | default        | range / meaning |
|------------|--------|----------------|-----------------|
| `progress` | float  | 0.0            | 0..1 effect life. Snap-in ~0-0.10, peak ~0.12, decay to 0 by 1.0. Drive from the sim clock over the ability's VFX duration (see cost note for suggested wall-clock). |
| `color`    | vec4   | (1,1,1,1)      | Multiplicative tint × master opacity (`.a`). Keep white for canon fire; cool-shift for arcane/soulfire variants. Full palette swaps = edit `temp_ramp`. |
| `dir`      | vec2   | (0,-1)         | Plume travel direction (normalized in-shader). Up for ignite/plume; aim along a cone for boss breath. |
| `seed`     | float  | 3.0            | Per-cast RNG variation (hash offset). Randomize per instance so repeats don't twin. |

Suggested wall-clock: **~0.45–0.7 s** for a hit/ignite tick; longer sustain
for boss breath by holding `progress` in the 0.15–0.30 plateau.

## In-game hooks

- **emberkin melee/ranged hits** — short burst, `dir` = up, small quad.
- **boss fire breath** — orient `dir` along the breath cone, scale the quad
  long, hold mid-progress for sustain.
- **ignite DoT** — low-opacity (`color.a` ~0.4) looping burst re-seeded each tick.

## Cost estimate (mobile budget)

- Noise evals / pixel: base flame field = `2(sway) + 2 + 2 (warp) + 4 (flame)`
  → ~10; **×3 for chroma R/B** ≈ 30, plus 1 smoke fbm (4). Each value-noise =
  4 hashes (1 `sin` each). Ember loop = 20 × (~3 `hash` + `exp` + `sin`).
- This is a **hero effect on a small quad** (effect covers a few thousand px),
  so the per-frame cost is bounded by the quad footprint, not full-screen.
  Comfortably inside a 60 FPS frame for a handful of concurrent casts.
- **Low-end scaling levers:** (1) drop the two chroma field evals → single
  eval cuts noise cost ~3×, losing only the edge R/B shimmer; (2) `fbm_flame`
  4→3 octaves; (3) ember loop 20→10. All are uniform/const-time toggles, no
  structural change.
- No compute, no screen texture, no derivatives — `gl_compatibility`-safe
  (GLES3 / WebGL2). `blend_add, unshaded`. Loops are constant-bound so the
  Godot compiler unrolls them.

## Preview

`contact_sheet.png` — 6 frames at `progress = 0.0, 0.2, 0.4, 0.6, 0.8, 1.0`
over a dark stone backdrop with a bright hero marker at the origin.
Render with `python3 render.py`.
