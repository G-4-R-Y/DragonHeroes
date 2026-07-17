// ENERGY VORTEX / ORBITAL  --  Dragon Heroes VFX lab
// Curl/flow-noise spiral arms orbiting a hollow eye. Seamless periodic angular
// noise (no atan2 branch-cut seam), log-spiral arms, differential swirl, thin
// hot filament cores, frayed wispy trailing edges, chromatic dispersion.
// progress drives spin-up -> peak -> spin-down + expansion + front-loaded fade.
//
// gl_compatibility-safe: fragment-only, inlined value-noise/fBm, constant loop
// bounds, no screen read, no derivatives, no compute.
shader_type canvas_item;
render_mode blend_add, unshaded;

// ---- uniforms -------------------------------------------------------------
uniform float progress : hint_range(0.0, 1.0) = 0.5;  // life 0..1
uniform vec4  color : source_color = vec4(0.42, 0.12, 0.95, 1.0); // body energy hue
uniform vec2  dir = vec2(1.0, 0.0);   // orientation of the arms (cast direction)
uniform float seed = 7.0;             // per-cast variation
uniform float gain : hint_range(0.0, 6.0) = 3.1;   // HDR brightness (>1 -> bloom)
uniform float chroma : hint_range(0.0, 1.0) = 1.0; // 0 = cheap 1-eval path

// ---- constants (match render.py) ------------------------------------------
// (TAU and PI are Godot shader built-in constants -- do not redefine.)
const float ARMS       = 5.0;    // integer -> sin() arms wrap seamlessly
const float XPERIOD    = 12.0;   // angular noise period (cells around circle)
const float SWIRL      = 0.55;   // differential rotation strength (1/r)
const float LOG_SPIRAL = 2.2;    // log-spiral tightness
const float TOTAL_TURNS= 2.4;    // rotation across life
const float INNER_R    = 0.10;   // hollow eye radius
const float OUTER_R0   = 0.30;   // outer radius at spin-up
const float OUTER_R1   = 0.46;   // outer radius at peak
const float EDGE_SOFT  = 0.10;
const int   OCT        = 3;       // fBm octaves

// ---- noise ----------------------------------------------------------------
float hash2(vec2 p, float s) {
    float n = sin(p.x * 127.1 + p.y * 311.7 + s * 13.13) * 43758.5453;
    return fract(n);
}

// Value noise; if xperiod > 0 the X lattice wraps -> seamless around circle.
float vnoise(vec2 p, float s, float xperiod) {
    vec2 i = floor(p);
    vec2 f = p - i;
    vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0); // quintic
    float xa = i.x;
    float xb = i.x + 1.0;
    if (xperiod > 0.0) {
        xa = mod(xa, xperiod);
        xb = mod(xb, xperiod);
    }
    float a = hash2(vec2(xa, i.y),       s);
    float b = hash2(vec2(xb, i.y),       s);
    float c = hash2(vec2(xa, i.y + 1.0), s);
    float d = hash2(vec2(xb, i.y + 1.0), s);
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p, float s, float xperiod) {
    float total = 0.0;
    float amp = 0.5;
    float freq = 1.0;
    float norm = 0.0;
    for (int o = 0; o < OCT; o++) {
        float xp = (xperiod > 0.0) ? xperiod * freq : 0.0;
        total += amp * vnoise(p * freq, s, xp);
        norm  += amp;
        amp  *= 0.5;
        freq *= 2.0;
    }
    return total / norm;
}

// Seamless filament streak (single tangential tap = cheapest motion blur).
float streak_noise(float phase, float reff, float s, float flow,
                   float rfreq, float smear) {
    // smear kept as a coordinate bias; single tap for mobile cost.
    vec2 c = vec2(phase + smear * 0.0, reff * rfreq - flow);
    return fbm(c, s, XPERIOD);
}

// ---- one channel of the vortex field -> vec2(intensity, hotness) ----------
vec2 vortex_field(vec2 uv, float p, float ang_off, float base) {
    vec2 d = uv - vec2(0.5);
    float r = length(d);
    float theta = atan(d.y, d.x);

    // timing envelopes
    float su = clamp(p / 0.6, 0.0, 1.0);
    float spin_env = (su * su * (3.0 - 2.0 * su))
                     - 0.4 * smoothstep(0.7, 1.0, p);
    float eo = 1.0 - (1.0 - p) * (1.0 - p);        // ease-out
    float rot = TOTAL_TURNS * TAU * eo;
    float outer_r = OUTER_R0 + (OUTER_R1 - OUTER_R0) * eo;

    float reff = max(r, 1e-3);
    float ang = theta + base + rot + SWIRL / reff + ang_off;
    float logr = log(reff);

    // big spiral arms (seamless: ARMS integer, sin is TAU-periodic)
    float arm = ang * ARMS - LOG_SPIRAL * logr;
    float bands = smoothstep(0.35, 1.0, 0.5 + 0.5 * sin(arm));

    // seamless periodic filament detail
    float phase = (ang / TAU) * XPERIOD - (LOG_SPIRAL / TAU) * XPERIOD * logr;
    float flow = rot * 0.6;
    float streak = streak_noise(phase, reff, seed, flow, 20.0, 0.12);
    float stri   = streak_noise(phase * 2.7 + 7.0, reff, seed + 11.0,
                                flow * 1.5, 46.0, 0.05);

    float detail = smoothstep(0.4, 0.85, streak);
    float carve  = 0.45 + 0.55 * smoothstep(0.32, 0.85, stri);
    float body   = bands * (0.15 + 0.85 * detail) * carve;

    // frayed trailing/inner edge -> wisps toward the eye
    float fray = smoothstep(INNER_R, outer_r, r) * 0.5 + 0.5;
    body *= pow(0.55 + 0.45 * detail, 1.0 - fray + 0.3);

    float core = pow(bands * smoothstep(0.66, 0.96, streak) * carve, 1.7);
    float fil  = pow(body, 1.25);

    // radial ring mask: soft inner (hollow eye), crisp bright outer edge
    float inner = smoothstep(INNER_R, INNER_R + EDGE_SOFT, r);
    float outer = 1.0 - smoothstep(outer_r - EDGE_SOFT * 0.5, outer_r, r);
    float ring  = inner * outer;

    float rim  = smoothstep(outer_r - 0.05, outer_r - 0.012, r) * outer
                 * (0.3 + 0.7 * bands);
    float haze = ring * (0.10 + 0.10 * bands);

    float intensity = fil * ring * 1.15 + rim * 1.35 + core * ring * 1.9 + haze;

    // front-loaded life fade
    float life = (1.0 - (1.0 - clamp(p / 0.22, 0.0, 1.0)) * (1.0 - clamp(p / 0.22, 0.0, 1.0)))
                 * (1.0 - smoothstep(0.62, 1.0, p));
    intensity *= (0.6 + 0.4 * spin_env) * (life + 0.04);

    float hotness = (core * ring * 1.9 + rim * 1.0) * (life + 0.04);
    return vec2(intensity, hotness);
}

void fragment() {
    float base = (length(dir) > 0.0001) ? atan(dir.y, dir.x) : 0.0;

    // green (center) channel drives colour grading
    vec2 fG = vortex_field(UV, progress, 0.0, base);
    float iG = fG.x;
    float hG = fG.y;

    // chromatic dispersion: tiny angular offset for R/B (perf-toggleable)
    float iR = iG;
    float iB = iG;
    if (chroma > 0.5) {
        iR = vortex_field(UV, progress, +0.018, base).x;
        iB = vortex_field(UV, progress, -0.018, base).x;
    }

    // palette: violet body -> magenta mid -> near-white hot core
    vec3 violet  = color.rgb;
    vec3 magenta = clamp(color.rgb * 1.6 + vec3(0.14, 0.06, 0.05), 0.0, 1.0);
    vec3 hot     = vec3(1.0, 0.92, 1.0);

    float t = clamp(iG, 0.0, 1.0);
    float h = clamp(hG * 2.2, 0.0, 1.0);
    vec3 body_col = mix(violet, magenta, t);
    vec3 col = mix(body_col, hot, h);

    vec3 glow = vec3(iR, iG, iB);
    vec3 rgb = col * glow * gain;   // HDR: core exceeds 1 -> WorldEnvironment glow

    // blend_add multiplies src by src.a then adds; a=1 -> pure additive,
    // matching the numpy preview (dst + rgb). rgb already carries the fade.
    COLOR = vec4(rgb, 1.0);
}
