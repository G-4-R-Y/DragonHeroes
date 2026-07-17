# IMPACT SPARK / HIT — VFX lab notes

Pure-math procedural hit flash. No textures. The Godot `effect.gdshader` is a 1:1
port of `render.py`'s `intensity_field`. It is the high-frequency "weight" feedback
that fires on every hit-connect (crit = push `intensity` + swap `color`).

## Technique (5 layered components, all additive HDR)

0. **Light-pop flash-disc** — a soft wide gaussian bloom that only exists in the
   first ~16% of life. Sells the burst of emitted light at the instant of contact.
1. **Hot core** — tight gaussian point (peak ~2.9, HDR) + a faint wide halo. The
   >1 center clips to white = white-hot spark; feeds a 2D glow post-pass as bloom.
2. **Star / cross** — 4 axis-aligned + 2 diagonal *bidirectional* lens streaks.
   Each streak = soft gaussian (cross-thickness + along-length) **plus** a razor-thin
   hot filament line down its axis (crisp AA leading read) and an along-length
   value-noise flicker (internal striations). Per-axis tip length is noise-jittered
   so the star is irregular, not a stock symmetric flare.
3. **Radial sunburst filaments** — `pow(value_noise(angle),5)` spikes gated by a
   radial gaussian shell. Fine flickering rays between the main star arms = turbulence.
4. **SDF shockwave ring** — ease-out expanding radius with a **sharp outer (leading)
   edge** via `1 - smoothstep(r0, r0+aa, r)` and a **soft inner trail** via
   `smoothstep(r0-thick, r0, r)`, plus a hot gaussian rim on the front. Angular
   value-noise breaks the brightness and a 3.5% radius wobble kills the perfect circle.
5. **Flying embers** — 10 sparks on jittered angles, ease-out radial flight, each a
   radially-elongated gaussian (motion-streak). They out-live everything → trailing
   life in the p=0.6–0.8 frames instead of a dead tail.

**Chromatic aberration**: the whole field is evaluated 3× at radially-scaled coords
(`c*(1±ca)` for R/B, `c` for G). Because the scale is radial, tips/rim fringe
cyan-orange while the calm center stays clean. `ca_amount = 0.013` is the sweet spot
(higher reads as a prism rainbow).

**Timing** is deliberately front-loaded — peak at `progress = 0`, decay curves tuned
so ~90% of the energy is spent by the first third:
core gone by 0.30, star 0.40, sunburst 0.35, ring lingers to 0.80, embers to 0.95.
In-game the whole life is ~0.12–0.18 s; it appears in a single client frame (snap-in).

## Uniforms

| uniform | type | default | range | meaning |
|---|---|---|---|---|
| `progress` | float | 0.0 | 0..1 | life; drive 0→1 over ~0.12–0.18 s, peak is at 0 |
| `color` | vec4 (source_color) | (1.0, 0.86, 0.55, 1) | any | hot tint. Gold=physical, white-blue=crit/holy, red=fire |
| `dir` | vec2 | (1,0) | unit-ish | rotates the star axes to the hit direction; (1,0)=identity (matches numpy ref) |
| `seed` | float | 7.0 | any | reshuffles noise (star tips, embers, ring breakup) per hit so repeats don't twin |
| `intensity` | float | 1.0 | 0.5..3 | global multiplier; crits push to ~2.0–2.5 |
| `ca_amount` | float | 0.013 | 0..0.03 | chromatic split; 0 disables (cheap path) |

## In-game hook

- Combat resolves server-side (canon hard rule); on a confirmed hit the client
  spawns one short-lived quad (a MultiMesh instance or a pooled `Sprite2D`/quad with
  this material) at the contact point, sets `color`/`intensity` from hit type
  (normal / crit / element) and a fresh `seed`, animates `progress` 0→1 via a tween
  or a per-instance shader time, then recycles. Omnidirectional, so a single square
  quad ~64–128 px works; set `dir` from the attack vector for a subtle orientation.
- One material, per-instance uniforms → all hits share the shader; no per-hit
  compilation. Pairs with the hit-stop / knockback the sim already emits.

## Cost estimate (60 FPS / mobile budget)

- Per fragment: `field()` × 3 (CA). Each `field` ≈ 6 `value_noise` (4 sin-hash + mixes
  each) + 4 `streak` (1 noise + 4 exp each) + a fixed 10-iter ember loop
  (2 sin/cos + 2 hash + 2 exp per iter). All ALU/transcendental, no texture fetch,
  no dependent branches.
- The quad is *tiny* on screen (a hit spark, not a fullscreen effect): a 96×96 px
  quad ≈ 9k fragments. Even at dozens/frame the overlapping coverage is small and
  additive quads with `blend_add` are cheap on the ROP side. Well inside the 16.6 ms
  frame budget on mid-range mobile.
- **Low-end / swarm path**: set `ca_amount = 0` to collapse to a single `field()` eval
  (~3× cheaper) — the CA is a luxury, the shape survives without it. Optionally drop
  the ember loop to 6. Cap concurrent sparks via the client VFX pool.
- Needs a **2D glow/bloom** WorldEnvironment for the HDR core/rim to bloom; on plain
  LDR `gl_compatibility` the >1 values simply clip to white (still reads hot).

## Iteration log

- **v1**: reciprocal-falloff core = big soft fuzzy ball at p=0, crisp star only at
  p=0.2 (timing backwards), dead tail after p=0.6, no internal life. Rejected.
- **v2**: re-timed to peak at p=0 (irregular multi-spike star + hot tight core +
  newborn ring at once); added noisy sunburst, flicker striations, razor filament
  lines, and 10 flying embers for a live tail. Big jump — cleared most of the bar.
- **v3**: tightened core (marker hints through), added first-instant flash-disc,
  ring radius wobble + hot leading rim, pushed CA to fringe the spike tips.
- **v4 (final)**: pulled CA back 0.016→0.013 and rim 0.8→0.55 so the ring reads as a
  hot white shock-rim with a fringe rather than a rainbow prism.

## Honest self-assessment

Clears the bar. p=0 is a genuine punch (irregular hot starburst, white-hot core,
crisp filaments), the SDF ring has the required sharp-leading/soft-trailing profile,
CA fringes the tips and rim, and embers give a real trailing decay instead of a dead
tail. Next iteration would (a) add 2–3 frames of true anisotropy driven by `dir` so
directional hits smear along the blow, (b) add a brief sub-pixel screen-space "crack"
of ultra-thin white shards for extra crunch on crits, and (c) A/B the crit palette
(white-blue) which this preview does not yet show.
