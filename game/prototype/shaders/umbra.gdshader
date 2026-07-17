// umbra - darkness smoke (Shadow Rend, umbral deaths, hag auras)
// Godot 4.6 canvas_item, gl_compatibility-safe (GLES3 / WebGL2).
// THE first MIX-BLEND lab effect: additive darkness is physically impossible,
// so this medium OCCLUDES the scene (near-black violet smoke, alpha <= 0.90)
// and only its rims glow. Ports genforge/vfx_lab/umbra/render.py 1:1.
//
// Anatomy: domain-warped fBm advected slowly upward (darkness LOOMS, fire
// licks) -> radial blob whose boundary is eaten by noise -> erosion dissolve
// (threshold RISES over life; the cloud burns off in patches, never fades) ->
// narrow violet rim band at the threshold crossing + drifting motes.
shader_type canvas_item;
render_mode blend_mix, unshaded;

uniform float progress : hint_range(0.0, 1.0) = 0.0;  // effect life 0..1
uniform vec4  color : source_color = vec4(0.60, 0.26, 1.0, 1.0); // RIM tint
uniform float seed = 11.0;                             // per-cast variation

const vec3 SMOKE_DEEP = vec3(0.016, 0.008, 0.045);     // near-black violet core
const vec3 SMOKE_MID  = vec3(0.10, 0.05, 0.19);        // lit smoke folds

// ---- hash / value noise / fbm (lab parity) -------------------------------
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
float fbm3(vec2 p) {
    float t = 0.0, amp = 0.5, fr = 1.0;
    for (int i = 0; i < 3; i++) { t += amp * vnoise(p * fr); fr *= 2.0; amp *= 0.5; }
    return t;
}
float fbm4(vec2 p) {
    float t = 0.0, amp = 0.5, fr = 1.0;
    for (int i = 0; i < 4; i++) { t += amp * vnoise(p * fr); fr *= 2.0; amp *= 0.5; }
    return t;
}
float smooth01(float v, float a, float b) {
    float t = clamp((v - a) / (b - a), 0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
}

void fragment() {
    vec2 uv = UV * 2.0 - 1.0;
    float x = uv.x;
    float y = uv.y;
    float r = length(uv);
    float p = progress;

    // --- envelope: fast swell in, long organic dissolve out ---
    float swell = smooth01(p, 0.0, 0.14);
    float R = 0.62 + 0.30 * smooth01(p, 0.0, 0.55);

    // --- advection: TIME-based slow curl (auras re-fire; speed never syrups) ---
    float adv = mod(TIME * 0.85, 240.0) + seed * 0.13;
    float q  = fbm3(vec2(x * 1.7 + seed, y * 1.7 - adv * 0.55));
    float dn = fbm4(vec2(x * 2.6 + (q - 0.5) * 2.1, y * 2.6 - adv + (q - 0.5) * 1.5) + 5.0);

    // --- density: radial blob eaten by noise (noise-dominant -> patchy wisps) ---
    float fall = smooth01(r, R, R * 0.28);
    float raw = dn * 0.85 + fall * 0.30;
    // erosion dissolve: threshold RISES over life
    float thr = 0.36 + 0.40 * smooth01(p, 0.35, 1.0);
    float density = smooth01(raw, thr, thr + 0.22) * fall * swell;
    float end_fade = 1.0 - smooth01(p, 0.88, 1.0);     // guaranteed clean exit
    density *= end_fade;
    float alpha = clamp(density * 1.25, 0.0, 0.90);    // REAL occluding darkness

    // --- smoke color: near-black core, faint violet in the folds ---
    float folds = smooth01(dn, 0.35, 0.9);
    vec3 smoke_rgb = mix(SMOKE_DEEP, SMOKE_MID, folds);

    // --- violet rim: NARROW band at the erosion threshold, never gain-boosted
    // wide/late (a fat bright rim over a dissolving cloud reads as a flat
    // lavender blob — the hard-shape sin this effect exists to kill) ---
    float band = smooth01(raw, thr - 0.07, thr) * (1.0 - smooth01(raw, thr, thr + 0.09));
    float rim = band * fall * swell * end_fade;
    float rim_gain = 0.9 + 0.45 * smooth01(p, 0.45, 0.8);
    vec3 rim_rgb = rim * color.rgb * rim_gain;

    // --- drifting motes: sparse hash-grid specks rising inside the cloud ---
    float N = 7.0;
    vec2 g = vec2(x * N * 0.5 + 3.0, y * N * 0.5 - adv * 1.6 + 7.0);
    vec2 cell = floor(g);
    vec2 j = vec2(hash2(cell + 41.0), hash2(cell + 73.0)) - 0.5;
    vec2 mp = g - cell - 0.5 - j * 0.7;
    float md = length(mp);
    float keep = smooth01(hash2(cell + 113.0), 0.55, 0.9);
    float mote = smooth01(md, 0.10, 0.02) * keep;
    float flick = 0.5 + 0.5 * sin(TIME * 16.0 + hash2(cell + 151.0) * 6.28);
    float mote_i = mote * fall * swell * (1.0 - smooth01(p, 0.7, 1.0)) * flick * end_fade;
    rim_rgb += mote_i * color.rgb * 1.6;

    // --- composite for MIX blend: the rim lives where smoke alpha is LOW, so
    // plain vec4(smoke+rim, alpha) would multiply the rim away. Treat rim as a
    // second layer OVER the smoke: hue-preserving normalize (uniform division
    // by its own luminance — per-channel would white-fringe), intensity in a.
    float rim_lum = clamp(max(rim_rgb.r, max(rim_rgb.g, rim_rgb.b)), 0.0, 1.0);
    vec3 rim_hue = rim_rgb / max(rim_lum, 0.001);
    float a_out = clamp(alpha + rim_lum * (1.0 - alpha), 0.0, 0.95) * color.a;
    vec3 rgb_out = (smoke_rgb * alpha * (1.0 - rim_lum) + rim_hue * rim_lum)
            / max(a_out, 0.001);
    COLOR = vec4(clamp(rgb_out, vec3(0.0), vec3(1.0)), a_out);
}
