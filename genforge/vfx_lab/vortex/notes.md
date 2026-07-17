# Energy Vortex / Orbital — VFX lab notes

Procedural swirling-energy vortex ("the ribbon done RIGHT"): curl/flow-noise
spiral arms orbiting a **hollow eye**, thin hot filament cores, frayed wispy
trailing edges, chromatic dispersion, additive/HDR. Pure math — no textures,
no flipbooks, no swept quad. Validated to compile clean in **Godot 4.6 stable,
`gl_compatibility`**.

## Technique

Everything is evaluated in polar space around the quad center (0.5, 0.5):

1. **Differential swirl** — `ang = theta + spin + SWIRL/r`. The `1/r` term makes
   the arms wind tighter toward the eye (real vortex shear), not a rigid rotation.
2. **Log-spiral arms** — `arm = ang*ARMS - LOG_SPIRAL*log(r)`; big structure is
   `smoothstep(0.35,1, 0.5+0.5*sin(arm))`. Because `ARMS` is an **integer** and
   `sin` is TAU-periodic, the arms are seamless across the `atan2` branch cut.
3. **Seamless periodic filament noise** — the killer detail. Value-noise/fBm
   whose **X lattice wraps modulo a period** (`XPERIOD` cells around the circle).
   This removes the hard radial seam that a naive `atan2`-fed noise produces on
   the −X axis. Two layers: broad filaments (`streak`) + fine striations (`stri`)
   that *carve* the arms so they read as turbulent energy, not clean ribbons.
4. **Frayed trailing edge** — the inner (trailing) side of each arm is broken
   into wisps toward the eye via a radius-weighted power of the detail.
5. **Radial ring mask** — soft inner edge (keeps the **eye hollow so the hero
   stays visible**) + crisp bright outer leading edge; a thin `rim` arc + faint
   volumetric `haze` give body without filling the center.
6. **Hot cores** — a high-threshold, high-power term (`core`) drives near-white
   HDR filament cores; the palette pushes body → magenta → white by `hotness`.
7. **Chromatic dispersion** — the field is evaluated at a tiny ±angular offset
   for the R and B channels (correlated, so it's clean edge fringing, not
   rainbow speckle). Toggleable for low-end (`chroma`).
8. **Front-loaded timing** — `progress` drives: `rot` (ease-out spin, ~2.4
   turns), `outer_r` expansion (0.30→0.46), a spin-up→peak→spin-down envelope,
   and a life curve that snaps in by p≈0.22 and decays to wisps after p≈0.62.

The numpy renderer (`render.py`) evaluates the **identical** math per pixel and
composites 6 life samples (p = 0, .2, .4, .6, .8, 1) over a dark stone backdrop
(#20242c) with a bright hero marker in the eye → `contact_sheet.png`. The preview
is rendered at the **same reduced cost as the shader** (3 fBm octaves, single
smear tap) so the sheet faithfully represents what ships.

## Uniforms

| uniform    | type  | default                   | range     | meaning |
|------------|-------|---------------------------|-----------|---------|
| `progress` | float | 0.5                       | 0..1      | effect life; drives spin/expand/fade |
| `color`    | vec4  | (0.42,0.12,0.95,1) source_color | any     | body energy hue (violet→magenta→white derived) |
| `dir`      | vec2  | (1,0)                     | any       | arm orientation = `atan2(dir.y,dir.x)`; align to cast dir |
| `seed`     | float | 7.0                       | any       | per-cast filament variation |
| `gain`     | float | 3.1                       | 0..6      | HDR brightness; >1 feeds WorldEnvironment glow/bloom |
| `chroma`   | float | 1.0                       | 0..1      | 1 = chromatic split (3 field evals); 0 = cheap 1-eval |

Tunable `const`s (baked to match the preview; promote to uniforms if content
needs them per-skill): `ARMS=5`, `XPERIOD=12`, `SWIRL=0.55`, `LOG_SPIRAL=2.2`,
`TOTAL_TURNS=2.4`, `INNER_R=0.10` (eye size), `OUTER_R0/1=0.30/0.46`, `OCT=3`.

## In-game hook

Serves the **Energy Vortex / Orbital family**: whirlwind, shadow rend, the
purple swirl — any channelled/burst "swirling energy around the caster" active.
Recolor per class via `color` (violet arcane, crimson blood-rend, teal storm).
Drive `progress` from the ability's normalized cast/impact time; set `dir` to
the aim vector; randomize `seed` per cast. The hollow eye is sized so the hero
sprite reads through the center for the whole life.

Usage: put it on a `ColorRect`/quad (or MultiMesh instance for many casters)
parented to the caster, sized to ~2× the desired outer diameter. `render_mode
blend_add` + a WorldEnvironment glow layer gives the bloom on the >1 cores.

## Cost estimate

- Noise taps/pixel: `chroma=1` → 3 field evals × (streak+stri) × 3 fBm octaves
  = **18 value-noise evals**; `chroma=0` → **6**. Each value-noise is 4 hashes +
  quintic lerps; one `sin` per hash.
- No screen read, no derivatives, no branching in the hot loop (fixed octave
  count), no compute → GLES3/`gl_compatibility` and mobile friendly.
- Coverage is a small quad around the caster, and additive early-outs are cheap
  where `intensity≈0`. Budget: comfortably sub-millisecond at the quad's screen
  footprint on desktop; on mid mobile keep `chroma=0` and/or drop `OCT` to 2 for
  the tightest frame-time. Fits the 60 FPS / measured-budget directive.
- Zero VRAM for assets (fully procedural).

## Iteration history (what the eye drove)

1. v1: log-spiral arms + hero visible, but muddy/navy, weak core.
2. v2: added hot filament cores + tangential motion-blur streaks → but a hard
   radial **seam** appeared (atan2 branch cut) and chroma read as rainbow speckle.
3. v3: **periodic wrapping noise** + seamless `sin` arms → seam gone, correlated
   chroma → clean; but arms went a bit ribbon-clean.
4. v4: carved fine striations + frayed trailing edges → real internal life, but
   dimmer.
5. v5 (final): restored punch (gain, hotter cores, rim arc, volumetric haze),
   then re-validated at mobile cost (3 oct / 1 tap) — punch + filament life both
   survive; hero stays visible in the eye through the peak.
