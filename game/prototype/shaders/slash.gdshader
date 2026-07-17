// SLASH / CRESCENT — arcane/melee cleave VFX
// Godot 4.6 canvas_item, gl_compatibility-safe (no compute, no screen read).
// Pure procedural: polar SDF band + swept leading edge + fbm filaments + chromatic fringe.
// Ports render.py exactly. Additive; HDR core (>1) feeds a bloom/glow pass.
//
// Place on a ColorRect / quad centered on the effect origin (hero), sized ~2*arc_radius.
// UV is [0,1] over the quad; origin maps to UV (0.5,0.5).
shader_type canvas_item;
render_mode blend_add, unshaded;

uniform float progress    : hint_range(0.0, 1.0) = 0.0; // life 0..1 (drives sweep + fade)
uniform vec4  color       : source_color = vec4(0.62, 0.30, 1.00, 1.0); // element tint
uniform vec2  dir         = vec2(0.927, -0.375); // slash facing (unit); default ~-22deg
uniform float seed        = 7.0;    // noise offset for per-cast variation
uniform float arc_radius  = 0.66;   // mean radius of the band, in half-quad units [0..1]
uniform float arc_thick   = 0.24;   // max half-thickness at arc centre
uniform float arc_span    = 2.0944; // total swept angle (rad). 2.0944 = 120deg

// ---- hash / value-noise / fbm (match render.py) ------------------------------
float hash2(vec2 p) {
    return fract(sin(p.x * 127.1 + p.y * 311.7) * 43758.5453);
}
float value_noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = p - i;
    vec2 u = f * f * (3.0 - 2.0 * f);
    float a = hash2(i);
    float b = hash2(i + vec2(1.0, 0.0));
    float c = hash2(i + vec2(0.0, 1.0));
    float d = hash2(i + vec2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}
float fbm(vec2 p) {
    float v = 0.0;
    float amp = 0.5;
    float freq = 1.0;
    for (int i = 0; i < 4; i++) {          // 4 octaves — mobile-cheap
        v += amp * value_noise(p * freq);
        freq *= 2.0;
        amp *= 0.5;
    }
    return v;
}
float ease_out(float x) { return 1.0 - (1.0 - x) * (1.0 - x); }

void fragment() {
    float half_span = arc_span * 0.5;

    // centred coords, y up (matches numpy previz)
    vec2 uv = (UV - 0.5) * 2.0;
    uv.y = -uv.y;

    float r = length(uv) + 1e-6;
    float a = atan(uv.y, uv.x);
    float dir_ang = atan(dir.y, dir.x);
    float arel = atan(sin(a - dir_ang), cos(a - dir_ang)); // wrapped [-pi,pi]
    float t = arel / half_span;                            // along-arc [-1,1]

    // sweep: leading edge crosses +1 -> -1, front-loaded, completes ~progress 0.45
    float sweep  = ease_out(clamp(progress / 0.45, 0.0, 1.0));
    float lead_t = 1.0 - 2.0 * sweep;

    // life envelope: hard snap-in, brief hold, quick decay -> wisps
    float env   = smoothstep(0.0, 0.10, progress) * (1.0 - smoothstep(0.45, 1.0, progress));
    float decay = smoothstep(0.42, 1.0, progress);

    // expansion: band drifts outward and puffs as it dissipates
    float R_eff = arc_radius + 0.14 * decay;
    float thick = arc_thick * (1.0 + 0.9 * decay);

    // blade thickness taper (fat middle, pointy tips)
    float half_thick = max(thick * sqrt(clamp(1.0 - t * t, 0.0, 1.0)), 0.010);
    float ncross = (r - R_eff) / half_thick;          // normalized across-band coord

    // soft angular taper so tips fade instead of hard-cutting
    float tip_fade = smoothstep(1.02, 0.80, abs(t));

    // arc-space turbulence for filaments
    float nz = fbm(vec2(t * 6.0 + 3.1 + seed, ncross * 2.2 + 7.0));

    // across-band profiles: crisp centreline core + soft outer glow
    float across_core = exp(-(ncross * ncross) / (2.0 * 0.34 * 0.34));
    float across_glow = exp(-(ncross * ncross) / (2.0 * 0.72 * 0.72));

    // angular: covered region is t >= lead_t (already passed)
    float behind = clamp(t - lead_t, 0.0, 2.0);
    float drawn  = 1.0 / (1.0 + exp((lead_t - t) * 34.0));
    float trail  = exp(-behind / 0.62) * drawn;

    // leading edge: thin bright band-confined arc segment (crescent front, NOT a spoke)
    float edge = exp(-pow(t - lead_t, 2.0) / (2.0 * 0.045 * 0.045)) * drawn;

    // filaments: tangential striations along the arc (additive detail)
    float fil = pow(0.5 + 0.5 * sin(ncross * 8.5 + nz * 6.5 + t * 2.5), 3.0);

    // erosion: as it decays keep only high-noise strands -> trailing wisps
    float erosion = smoothstep(decay - 0.10, decay + 0.45, nz);
    float keep = (1.0 - decay) + decay * erosion;

    // body: solid bright smear, gently turbulent, filaments added on top
    float smear   = trail * (0.75 * across_core + 0.40 * across_glow);
    float turb    = 0.80 + 0.40 * nz;
    float fil_add = trail * across_core * fil * 0.55;
    float body = (smear * turb + fil_add) * tip_fade * env * keep;

    // leading edge (hot, band-confined)
    float edge_core = edge * across_core * tip_fade * env;
    float edge_halo = edge * across_glow * tip_fade * env;

    // chromatic fringe: thin prismatic rim — R just ahead of edge, B just behind
    float d_chroma = 0.045;
    float edge_R = exp(-pow(t - (lead_t - d_chroma), 2.0) / (2.0 * 0.040 * 0.040)) * across_core * tip_fade * env;
    float edge_B = exp(-pow(t - (lead_t + d_chroma), 2.0) / (2.0 * 0.040 * 0.040)) * drawn * across_core * tip_fade * env;

    // ---- compose HDR color (additive) ----
    vec3 col = vec3(0.0);
    col += body      * color.rgb * 2.9;   // violet body
    col += edge_halo * color.rgb * 1.8;   // violet halo around edge
    col += vec3(edge_core * 4.6);         // hot near-white core (HDR>1 -> bloom)
    col.r += edge_R * 1.3;                // chromatic red fringe (lead)
    col.b += edge_B * 1.5;                // chromatic blue fringe (trail)

    // blend_add adds col * alpha; alpha=1 -> pure additive, empty areas add 0.
    COLOR = vec4(col, 1.0);
}
