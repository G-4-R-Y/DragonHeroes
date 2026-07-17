# SLASH / CRESCENT — VFX lab notes

Arcane/melee cleave. Replaces the flat swept-quad ribbon with an origin-anchored,
"drawn-with-light" crescent: a hot near-white leading edge sweeps ~120deg across a
radial band, dragging a soft violet trail full of tangential filaments, with a thin
prismatic (R/B) fringe on the bright edge. `progress` drives sweep + dissipation.

## Technique (pure math — no textures)
- **Polar field** around the origin (hero). `r = length(uv)`, `arel = wrap(atan(uv) - dir)`.
- **Along-arc coord** `t = arel / half_span` in [-1,1]; band lives at mean radius `arc_radius`.
- **Blade taper**: `half_thick = arc_thick * sqrt(1 - t^2)` -> fat middle, pointy tips.
  `ncross = (r - R_eff)/half_thick` is the normalized across-band SDF coordinate.
- **Swept leading edge**: `lead_t = 1 - 2*ease_out(progress/0.45)` sweeps +1 -> -1,
  front-loaded (fast in). `drawn` is a sigmoid step at `lead_t` (crisp AA leading edge);
  `trail = exp(-(t-lead_t)/0.62)*drawn` is the soft decaying smear behind it.
- **Across-band profile**: two Gaussians of `ncross` — a crisp `across_core` (sigma .34)
  for the hot centreline and a soft `across_glow` (sigma .72) for the halo.
- **Filaments**: `pow(0.5+0.5*sin(ncross*8.5 + fbm*6.5 + t*2.5), 3)` — thin tangential
  striations, added on top of a solid smear (not used as a gate, so the body stays dense).
- **Turbulence**: 4-octave value-noise fbm in arc-space modulates the body and drives
  the decay erosion.
- **Decay -> wisps**: `decay = smoothstep(0.42,1,progress)` expands the band outward
  (`R_eff += .14*decay`), puffs thickness (`*1+.9*decay`), and erodes the body with a
  noise threshold (`keep`) so only high-noise strands survive late = trailing wisps.
- **Life envelope**: `env = smoothstep(0,.10,p) * (1 - smoothstep(.45,1,p))` — hard
  snap-in, brief hold, quick fade.
- **Chromatic fringe**: leading edge sampled at +/- `d_chroma` in `t` for R (ahead) and
  B (behind) — a thin prismatic rim on the hot edge, not a coloured plume.
- **HDR core**: near-white edge core scaled to ~4.6 (previz peaks ~3.9 pre-clip, ~1% of
  pixels >1) so a bloom/glow pass blooms the leading edge. Additive blend.

## Uniforms
| uniform      | type  | default                 | range / notes |
|--------------|-------|-------------------------|---------------|
| `progress`   | float | 0.0                     | 0..1 life; animate over the cast (see timing) |
| `color`      | vec4  | (0.62,0.30,1.0,1) violet| element tint; body+halo use it, core stays white |
| `dir`        | vec2  | (0.927,-0.375) ~-22deg  | unit facing dir of the slash |
| `seed`       | float | 7.0                     | per-cast noise offset for variety |
| `arc_radius` | float | 0.66                    | 0.4..0.85 (half-quad units) mean band radius |
| `arc_thick`  | float | 0.24                    | 0.12..0.35 blade half-thickness at centre |
| `arc_span`   | float | 2.0944 (120deg)         | 1.4..2.6 rad total swept angle |

## In-game hook
- **Warrior / rogue melee cleave** and **mage arcane cut** (canon: melee cleave, mage
  arcane cut). One shader, element-tinted via `color`; `dir` from the attack vector,
  `arc_span`/`arc_radius` scale with weapon reach. Drive `progress` 0->1 over the
  swing (fast: ~0.13-0.18s feels right at 60fps — snap-in by frame 2, gone by ~frame 10).
- Place a `ColorRect`/quad centred on the origin, sized ~`2 * world_arc_radius`.
- Server-authoritative gameplay is untouched — this is presentation only; the client
  spawns/animates the quad on the confirmed swing event.

## Cost estimate
- Per fragment: 1 fbm (4 octaves value-noise = 4 sin-hash lookups w/ 4 taps each ~16
  `sin`), a handful of `exp`/`pow`/`smoothstep`. No branches, no loops except the fixed
  4-octave fbm, no texture fetches, no screen read. Mobile-cheap.
- Bound the quad tightly (2*radius) so overdraw is small; the effect is short-lived and
  typically 1-3 on screen. Well within the 60fps budget; profile alongside other adds.
- To go cheaper on low-end: drop fbm to 3 octaves (halves the noise cost; previz barely
  changes) and/or fold `arc_radius/thick/span` to consts.

## Previz parity
`render.py` evaluates this exact math in numpy; `effect.gdshader` is a line-for-line
port (same hash/value-noise/fbm, same constants). Validated in Godot 4.6
(gl_compatibility, headless) — compiles with zero shader errors; a deliberately broken
control variant did surface a `SHADER ERROR`, confirming the parser actually ran.
