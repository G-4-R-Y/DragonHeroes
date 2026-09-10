# Necklace Orbit (cosmetic) — lab notes

The Grand Chase necklace, modernized: 3 elemental beads orbiting the hero on a
tilted ellipse (3/4 top-down: BEHIND at the top of the orbit, IN FRONT at the
bottom). Bead sprite math ports to `game/prototype/shaders/
necklace_bead.gdshader`; the orbit motion itself is GDScript
(`game/arena/cosmetics.gd` — ProtoCosmetics), not shader work. Re-render:

    cd genforge/vfx_lab/necklace_orbit && python3 render.py   # -> contact_sheet.png

Sheet: column per element (fire, frost, storm, venom, umbral, blood), row per
orbit phase (0.0 / 0.30 / 0.60 / 0.90 turns).

## Anatomy

- **Orbit**: ellipse rx 40 / ry 17 px around the hero center; 3 beads 120°
  apart, period ~3.2 s. Depth layer = sign of sin(theta): back half draws
  under the hero marker, front half over it. Beads scale 0.80 (back) → 1.15
  (front) for perspective, plus a ±10 % per-bead pulse.
- **Bead**: gaussian core (sigma 1.6 px, ×2.6 — pushes to white) + halo
  (sigma 4.6 px, ×0.55, keeps the element hue) + two-sine flicker (±15 %).
  Same construction as necklace_bead.gdshader.
- **Trail**: 8 samples × 0.008 turns behind the bead, fade 0.60^k — SHORT;
  longer reads as a comet tail / dotted ring (see git history of this sheet).
- **Orbit ring**: 160-point sampled gaussian stroke, sigma 0.8 px, alpha 0.03
  (back) / 0.065 (front) — faint; it exists to read the full circle, never to
  compete with the beads.

## Runtime mapping (ProtoCosmetics)

Beads/ring pre-created at attach; `ProtoFx.intensity` gates USAGE: <0.3 →
1 bead, <0.8 → 2, else 3 (hidden, never freed). Bead z_index flips -2/+2
around the body sprite at the orbit's front/back crossover.
