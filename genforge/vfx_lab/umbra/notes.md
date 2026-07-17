# umbra — darkness smoke (mix-blend medium)

The first NON-additive lab effect. Additive darkness is physically impossible —
a darkness aura must OCCLUDE the scene. `umbra.gdshader` runs `blend_mix`;
the preview composites `scene*(1-a) + smoke*a` and only the rims add.

## Anatomy
1. **Occluding smoke density** — domain-warped fBm (warp field `q` feeds the
   detail field `dn`) advected slowly upward (`adv = p*0.85`; darkness LOOMS,
   fire licks). Radial falloff blob, noise-dominant mix (`dn*0.85 + fall*0.30`)
   so break-up is patchy wisps, never one clump. Alpha caps at 0.90.
2. **Erosion dissolve** — the density threshold RISES over life
   (`thr = 0.36 + 0.40*smoothstep(0.35, 1.0, p)`): the cloud burns off in
   patches instead of alpha-fading. `end_fade` (0.88→1.0) guarantees exit.
3. **Violet rim** — narrow band where density crosses the threshold
   (band 0.07/0.09) = "edge of the void". NEVER gain-boosted wide/late — a
   fat bright rim over a dissolving cloud reads as a flat lavender blob
   (the hard-shape sin this effect exists to kill). Gain 0.9→1.35 max.
4. **Motes** — sparse hash-grid specks drifting up inside the cloud,
   flickering, gone by p=1.

## Iteration log
- v1: rim flare `0.85+1.5*late` + band 0.10/0.14 → p=0.75 was a flat lavender
  blob. Narrowed band, capped gain at 1.35.
- v1: `raw = dn*0.72 + fall*0.42` collapsed to a single clump late. Now
  noise-dominant 0.85/0.30.
- v2: thr ramp to 0.88 killed the cloud entirely by p=0.75 (pop). Final ramp
  0.36→0.76 over 0.35..1.0 leaves a scattered wisp field at 0.75.

## In-game (shader_fx kind "umbra")
Shadow Rend bursts (life ~0.8), umbral creature death puffs (life ~0.7),
legendary hag aura pulses. `color` uniform tints the RIM (default violet);
smoke stays near-black. Quad z=21 (above creatures) — the loom is the point.
