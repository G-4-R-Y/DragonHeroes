# Body Aura (cosmetic) — lab notes

Preview for `game/prototype/shaders/aura_body.gdshader`, driven at runtime by
`game/arena/cosmetics.gd` (ProtoCosmetics). Re-render:

    cd genforge/vfx_lab/auras && python3 render.py   # -> contact_sheet.png

Sheet layout: column per canon damage element (fire, frost, storm, venom,
umbral, blood — `content/core/registries/damage_types.json`), row per TIME
phase (0.0 / 0.9 / 1.8 / 2.7 s). The aura is PERSISTENT — there is no life
envelope; rows exist to judge the advection, not a birth/death curve.

## Anatomy (shared by render.py and the shader — same constants)

1. **Silhouette band**: asymmetric ellipse around the hero (rx 30 px, ry 52 px,
   `TOP_STRETCH 1.30` — reaches higher above the head, media licks upward).
   Hollow core so the hero reads through.
2. **Filaments**: domain-warped fBm (3 octaves — mobile budget) with low
   y-frequency (tall vertical streaks), advected by TIME at `rise_speed`
   (blood is NEGATIVE: slow downward, liquid). Low-freq sway leans the shroud.
3. **Erosion**: density threshold at `erosion`, wanders with the warp field;
   the band shell is noise-modulated (`0.50 + 0.70*smoothstep(n)`) so the
   medium breaks the ellipse into wisps — never a clean ring. Patchy rim at
   the threshold crossing (`color_edge`), gated by the same noise so it can
   never form a full outline (the hard-shape sin, canon §12.27).
4. **Storm**: sparse jagged branching bolt polylines, re-struck every ~0.34 s
   (25 % of cells strike nothing), drawn THROUGH the band, not clipped by it.
5. **Blood**: heavy falloff + 4 slow drip streaks falling below the band.

## Blend contract (matches the shader, `render_mode blend_mix`)

- `occlude` elements (umbral 0.85, blood 0.60, venom 0.55 max alpha): MIX
  composite — `scene*(1-a) + smoke*a`, glow adds on top (umbra.gdshader
  pattern). Additive darkness is physically impossible.
- glow elements (fire, frost, storm): translucent colored light, HDR cores
  (×1.7) fake the additive pop under the darkness layer.

## Tunables (top of render.py / shader uniforms)

`RX, RY, TOP_STRETCH, BAND_IN, BAND_OUT, OCTAVES` · per element in `EL` /
ProtoCosmetics.ELEMENTS: `core, edge, smoke, rise_speed, erosion, arc,
occlude, max_alpha`. Deterministic seeds: `SEED_BASE + column * 13.7`.

Runtime gates USAGE only via `strength` (ProtoFx.intensity), never allocation.
