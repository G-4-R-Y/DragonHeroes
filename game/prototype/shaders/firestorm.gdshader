// firestorm - fire / ember plume (emberkin hits, boss breath, ignite)
// Godot 4.6 canvas_item, gl_compatibility-safe (GLES3 / WebGL2).
// Pure procedural: fBm value noise + domain warp + upward flow + temp ramp
// + advected ember specks + ignition flash + chromatic edge dispersion.
// Ports the exact fragment math prototyped in render.py.
shader_type canvas_item;
render_mode blend_add, unshaded;

uniform float progress : hint_range(0.0, 1.0) = 0.0;  // effect life 0..1
uniform vec4  color : source_color = vec4(1.0, 1.0, 1.0, 1.0); // tint * master opacity
uniform vec2  dir = vec2(0.0, -1.0);                  // plume travel dir (screen up)
uniform float seed = 3.0;                             // per-cast variation
// Medium params (lab parity). Advection is TIME-based, NOT progress-based, so a
// 10 s ground-fire field burns at the same speed as a 0.6 s burst instead of
// playing in syrup slow-mo. hold = progress where decay starts (fields ~0.88);
// flash_amt lets persistent field quads skip the ignition pop.
uniform float hold : hint_range(0.05, 0.95) = 0.25;
uniform float flow = 4.5;                             // advection speed (units/s)
uniform float flash_amt : hint_range(0.0, 1.0) = 1.0;

// ---- hash / value noise / fbm (inlined, mobile-cheap) --------------------
float hash2(vec2 p) {
    float v = sin((p.x * 127.1 + p.y * 311.7) + seed * 13.0) * 43758.5453;
    return fract(v);
}
float vnoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    float a = hash2(i);
    float b = hash2(i + vec2(1.0, 0.0));
    float c = hash2(i + vec2(0.0, 1.0));
    float d = hash2(i + vec2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}
// warp field: 2 octaves (cheap)
float fbm_warp(vec2 p) {
    float t = 0.0, amp = 0.5, fr = 1.0;
    for (int i = 0; i < 2; i++) { t += amp * vnoise(p * fr); fr *= 2.0; amp *= 0.5; }
    return t;
}
// flame body: 4 octaves
float fbm_flame(vec2 p) {
    float t = 0.0, amp = 0.5, fr = 1.0;
    for (int i = 0; i < 4; i++) { t += amp * vnoise(p * fr); fr *= 2.0; amp *= 0.5; }
    return t;
}
float hash1(float n) { return fract(sin(n * 17.23 + seed) * 43758.5453); }

float smooth01(float v, float a, float b) {
    float t = clamp((v - a) / (b - a), 0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
}

// ---- temperature -> HDR RGB (white core -> yellow -> orange -> red -> smoke)
vec3 temp_ramp(float t) {
    t = clamp(t, 0.0, 1.3);
    vec3 c;
    if      (t < 0.22) c = mix(vec3(0.05,0.04,0.06), vec3(0.55,0.10,0.02), t / 0.22);
    else if (t < 0.45) c = mix(vec3(0.55,0.10,0.02), vec3(1.15,0.32,0.05), (t-0.22)/0.23);
    else if (t < 0.70) c = mix(vec3(1.15,0.32,0.05), vec3(1.55,0.78,0.18), (t-0.45)/0.25);
    else if (t < 0.92) c = mix(vec3(1.55,0.78,0.18), vec3(1.85,1.55,1.05), (t-0.70)/0.22);
    else               c = mix(vec3(1.85,1.55,1.05), vec3(2.20,2.05,1.80), (t-0.92)/0.38);
    return c;
}

// ---- turbulent flame density field 0..1 --------------------------------
// luv.x = perpendicular offset, luv.y = height above origin (+up along dir)
float flame_field(vec2 luv, float reach, float scroll, float warp_amt,
                  float chroma, out float hnorm, out float n) {
    float x = luv.x + chroma;
    float yup = luv.y;
    hnorm = clamp(yup / reach, 0.0, 1.0);
    // whole-plume low-freq sway so the column leans / waves (not a clean cone)
    float sway = fbm_warp(vec2(yup * 1.6 - scroll * 0.5 + 3.0, 7.0)) - 0.5;
    float xs = x - sway * 0.10 * hnorm;
    // domain warp: strong horizontal sway, tall vertical streaks (low y-freq)
    float wx = fbm_warp(vec2(xs * 3.0 + 19.0, yup * 2.0 - scroll * 0.9)) - 0.5;
    float wy = fbm_warp(vec2(xs * 3.0 - 5.0,  yup * 2.0 - scroll * 0.6)) - 0.5;
    vec2 s = vec2(xs * 7.0 + wx * warp_amt * 2.6,
                  yup * 2.4 - scroll + wy * warp_amt * 1.3);
    n = fbm_flame(s);
    float halfw = 0.155 * (1.0 - 0.5 * hnorm) + 0.02;
    float hz = xs / halfw;
    float horiz = exp(-hz * hz * 1.25);
    float below = clamp(1.0 + yup / 0.06, 0.0, 1.0);   // hard cut below origin
    float grad = clamp(1.0 - hnorm, 0.0, 1.0);
    return (n * (0.55 + 0.85 * grad) + grad * 0.35) * horiz * below;
}

void fragment() {
    // local frame: origin at center-lower, plume points along dir
    vec2 origin = vec2(0.5, 0.74);
    vec2 rel = UV - origin;
    vec2 d = normalize(dir);
    float yup = dot(rel, d);                 // height above origin (+ along travel)
    float x   = dot(rel, vec2(-d.y, d.x));   // perpendicular offset
    vec2 luv = vec2(x, yup);

    // --- life envelope: hard snap-in, sustain to `hold`, front-loaded decay ---
    float rise = clamp(progress / 0.10, 0.0, 1.0);
    rise = rise * rise * (3.0 - 2.0 * rise);
    float fall = 1.0 - clamp((progress - hold) / max(1.0 - hold, 0.001), 0.0, 1.0);
    fall = fall * fall;
    float env = rise * fall;
    float fall_s = sqrt(fall);
    float reach = 0.28 + 0.54 * rise * (0.5 + 0.5 * fall_s);   // shoot up, burn down
    // TIME-based advection; mod keeps sin() hash args in float32-precise range
    float scroll = mod(TIME * flow, 240.0) + seed * 13.0;
    float warp_amt = 0.55 + 0.45 * env;

    // --- flame field (base + chromatic-offset R/B) ---
    float chroma = 0.011 * (0.4 + 0.6 * env);
    float hnorm, n, dRh, dRn, dBh, dBn;
    float field   = flame_field(luv, reach, scroll, warp_amt,  0.0,     hnorm, n);
    float field_r = flame_field(luv, reach, scroll, warp_amt, -chroma,  dRh, dRn);
    float field_b = flame_field(luv, reach, scroll, warp_amt,  chroma,  dBh, dBn);

    float core   = smooth01(field,   0.40, 0.66);   // sharp bright tongues
    float glow   = smooth01(field,   0.16, 0.52);   // soft translucent halo
    float core_r = smooth01(field_r, 0.40, 0.66);
    float core_b = smooth01(field_b, 0.40, 0.66);

    // temperature: hot & white at base/core, cooling upward and at edges
    float heat = env * (1.05 - 0.45 * hnorm);
    float temp = (core * (1.25 - 0.5 * hnorm) + glow * 0.45) * heat;
    temp *= (0.72 + 0.5 * n);
    // white-hot base bloom, carved by turbulence, softened at exact center
    float bx = x / 0.10;
    float base_hot = exp(-bx * bx) * clamp(1.0 - yup / 0.14, 0.0, 1.0);
    base_hot = clamp(base_hot, 0.0, 1.0) * env * (0.45 + 0.7 * n);
    float cc = (x * x + (yup - 0.015) * (yup - 0.015)) / (0.030 * 0.030);
    base_hot *= (1.0 - 0.35 * exp(-cc));
    temp += base_hot * 0.85;

    float vis = clamp(env * 1.25, 0.0, 1.0);
    vec3 rgb = temp_ramp(temp);
    float intensity = pow(clamp(core + glow * 0.55, 0.0, 1.0), 0.8) * vis;
    rgb *= intensity;

    // chromatic dispersion at hot edges (R/B split)
    float edge = clamp(core_r - core_b, -1.0, 1.0) * env;
    rgb.r += clamp(edge, 0.0, 1.0)  * 0.85 * intensity;
    rgb.b += clamp(-edge, 0.0, 1.0) * 0.85 * intensity;

    // --- trailing smoke wisps: dark, translucent, rise & outlive the flame ---
    float s0 = max(hold, 0.32);
    float smk_env = clamp(progress / 0.22, 0.0, 1.0)
                  * pow(1.0 - clamp((progress - s0) / max(1.0 - s0, 0.001), 0.0, 1.0), 1.3);
    float ss = scroll * 0.55 + 11.0;   // coherent with the flame flow
    float sn = fbm_flame(vec2(x * 4.0 + 31.0, yup * 2.6 - ss));
    float s_reach = 0.30 + 0.55 * clamp(progress / 0.5, 0.0, 1.0);
    float sh = clamp(yup / s_reach, 0.0, 1.0);
    float s_halfw = 0.10 + 0.16 * sh;
    float shz = x / s_halfw;
    float s_horiz = exp(-shz * shz * 1.1);
    float s_below = clamp(yup / 0.05, 0.0, 1.0);       // smoke lives ABOVE the fire
    float smoke = smooth01(sn * (0.6 + 0.4 * sh) * s_horiz * s_below, 0.30, 0.7);
    smoke *= smk_env * (0.5 + 0.5 * sh);
    rgb += smoke * vec3(0.16, 0.15, 0.17);

    // --- ignition flash: radial white pop, very front-loaded ---
    float fl = clamp(1.0 - abs(progress - 0.06) / 0.10, 0.0, 1.0);
    fl *= fl * flash_amt;
    float fd = x * x + (yup - 0.02) * (yup - 0.02);
    float flash = exp(-fd / (0.09 * 0.09)) * fl;
    rgb += flash * vec3(2.0, 1.7, 1.2);

    // --- rising ember specks (advected by the flow, motion-streaked) ---
    for (int i = 0; i < 20; i++) {
        float fi = float(i);
        float ex0   = (hash1(fi + 1.0) - 0.5) * 0.34;
        float speed = 0.55 + hash1(fi + 9.0) * 0.9;
        float loff  = hash1(fi + 3.0);
        float phase = fract((TIME * 0.85 + loff * 7.0) * speed);   // TIME-based rise
        float ey = phase * 0.62;
        float ex = ex0 + 0.05 * sin((phase * 6.0 + fi) * 3.14159) * phase;
        float sz = 0.006 + hash1(fi + 5.0) * 0.010;
        float stre = 2.0 + 1.5 * speed;               // vertical motion streak
        vec2 dd = vec2(x - ex, (yup - ey) / stre);
        float spark = exp(-dot(dd, dd) / (sz * sz));
        float flick = 0.5 + 0.5 * sin(TIME * 26.0 + fi * 2.3);
        float bright = env * (1.0 - phase) * (0.6 + 0.4 * flick);
        float eheat = 1.0 - 0.7 * phase;
        rgb += spark * bright * vec3(1.9, 0.9 + 0.7 * eheat, 0.25 + 0.55 * eheat);
    }

    // additive output: tint * master opacity folded into rgb, alpha = 1
    // (blend_add multiplies rgb by alpha, so keep alpha at 1.0)
    rgb *= color.rgb * color.a;
    COLOR = vec4(rgb, 1.0);
}
