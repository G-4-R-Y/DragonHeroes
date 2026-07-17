// NOVA / EXPLOSION — Godot 4.6 canvas_item shader (gl_compatibility-safe).
// 1:1 port of vfx_lab/nova/render.py fragment math.
// Draw on a SQUARE quad centred on the blast origin, sized to the blast radius.
// Additive/translucent by design: the hero underneath stays visible.
//
// Pipeline note: preview render.py applies a soft-clip bloom + display gamma.
// Here we output the soft-clipped bloom colour and let blend_add + the project's
// WorldEnvironment glow supply the HDR punch. No screen read, no compute.

shader_type canvas_item;
render_mode blend_add, unshaded;

uniform float progress : hint_range(0.0, 1.0) = 0.0; // 0 = snap-in, 1 = gone
uniform vec4  color : source_color = vec4(0.35, 0.72, 1.0, 1.0);      // icy base
uniform vec4  core_color : source_color = vec4(0.80, 0.93, 1.0, 1.0); // hot core
uniform vec2  dir = vec2(1.0, 0.0);   // orientation of the angular pattern (optional)
uniform float seed = 7.0;             // per-cast variation
uniform float intensity = 1.0;        // master brightness multiplier
uniform float exposure = 1.7;         // soft-clip bloom knee


// ---- smoothstep matching render.py (supports a > b) ----
float smstep(float a, float b, float x) {
    float t = clamp((x - a) / (b - a), 0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
}

// ---- value noise (sin-hash, matches render.py exactly) ----
float hash2(vec2 i, float s) {
    float n = sin((i.x * 127.1 + i.y * 311.7) + s * 13.0) * 43758.5453;
    return fract(n);
}
float vnoise(vec2 p, float s) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    float a = hash2(i,                 s);
    float b = hash2(i + vec2(1.0, 0.0), s);
    float c = hash2(i + vec2(0.0, 1.0), s);
    float d = hash2(i + vec2(1.0, 1.0), s);
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}
// unrolled fBm (constant loop bounds = GLES/gl_compatibility safe)
float fbm3(vec2 p, float s) {
    float v = 0.0, amp = 0.5, freq = 1.0;
    v += amp * vnoise(p * freq, s); freq *= 2.0; amp *= 0.5;
    v += amp * vnoise(p * freq, s); freq *= 2.0; amp *= 0.5;
    v += amp * vnoise(p * freq, s);
    return v;
}
float fbm4(vec2 p, float s) {
    float v = 0.0, amp = 0.5, freq = 1.0;
    v += amp * vnoise(p * freq, s); freq *= 2.0; amp *= 0.5;
    v += amp * vnoise(p * freq, s); freq *= 2.0; amp *= 0.5;
    v += amp * vnoise(p * freq, s); freq *= 2.0; amp *= 0.5;
    v += amp * vnoise(p * freq, s);
    return v;
}
// angular noise sampled on a circle (wraps cleanly)
float anoise(float ang, float radius, float s, float scale) {
    return vnoise(vec2(cos(ang) * scale + 3.0, sin(ang) * scale + 3.0 + radius), s);
}

void fragment() {
    // centred UV in [-1, 1]; assumes a square quad
    vec2 uv = (UV - vec2(0.5)) * 2.0;
    float x = uv.x;
    float y = uv.y;
    float r = length(uv);
    float ang = atan(y, x);
    // optional orientation of the angular pattern
    float rot = (dot(dir, dir) > 1e-6) ? atan(dir.y, dir.x) : 0.0;
    float angp = ang - rot;

    float p = clamp(progress, 0.0, 1.0);

    // --- envelopes (front-loaded) ---
    float R = 1.35 * (1.0 - pow(1.0 - p, 2.3));   // ring races out, eases at end
    float life = pow(max(1.0 - p, 0.0), 1.5);     // fast fade + trailing tail

    vec3 rgb = vec3(0.0);
    vec3 COL  = color.rgb;
    vec3 CORE = core_color.rgb;

    // ---------- 1. ring shockwave ----------
    float th = 0.085 * (1.0 - 0.68 * p) + 0.006;
    float stri = 0.5 + 0.6 * anoise(angp, R * 2.0, seed + 1.0, 5.0);
    stri += 0.2 * anoise(angp, R * 3.0, seed + 8.0, 9.0);
    stri *= 0.88 + 0.12 * sin(angp * 20.0 + seed * 3.0);
    stri = clamp(stri, 0.45, 1.35);

    float disp = 0.016 * (0.4 + 0.6 * p);         // chromatic fringe: warm out / cool in
    float ring_r = smstep(th, 0.0, abs(r - (R + disp)));
    float ring_g = smstep(th, 0.0, abs(r - R));
    float ring_b = smstep(th, 0.0, abs(r - (R - disp)));
    vec3 ring_i = vec3(ring_r, ring_g, ring_b) * stri;
    rgb += ring_i * COL * (2.5 * life);
    float edge = smstep(th * 0.35, 0.0, abs(r - R));
    edge *= edge;                                 // sharp hot leading edge
    rgb += (edge * stri) * CORE * (3.4 * life);

    // ---------- 2. radial energy shards (band behind the ring front) ----------
    float shards_life = pow(life, 1.5);           // fade faster than the ring
    float nshards = 13.0;
    float shard_phase = 0.5 + 0.5 * sin(angp * nshards + seed * 2.0);
    float shard = pow(shard_phase, 9.0);
    float svar = anoise(angp, 0.0, seed + 5.0, nshards / 3.0);
    shard *= 0.35 + 0.9 * svar;
    float reach = R * 1.0 + 0.04;
    float shard_body = smstep(reach, reach - 0.34, r) * smstep(0.02, 0.18, r);
    rgb += (shard * shard_body * 1.9 * shards_life) * COL * vec3(0.8, 1.0, 1.25);
    float tip = shard * smstep(reach - 0.16, reach, r) * smstep(reach + 0.05, reach - 0.02, r);
    rgb += (tip * 2.3 * shards_life) * CORE;

    // ---------- 2b. debris flecks near the front ----------
    float fleck_field = vnoise(vec2(cos(angp) * 40.0 + 5.0, sin(angp) * 40.0 + r * 30.0), seed + 9.0);
    float flecks = smstep(0.86, 0.995, fleck_field);
    float fleck_band = smstep(reach + 0.12, reach - 0.02, r) * smstep(reach - 0.3, reach - 0.05, r);
    rgb += (flecks * fleck_band * 2.0 * shards_life) * (0.6 * COL + 0.4 * CORE);

    // ---------- 3. turbulent fBm core flash (bloom -> collapse) ----------
    float core_scale = max(0.5 * (0.35 + 0.65 * sin(p * PI)), 0.06);
    float core_body = smstep(core_scale, 0.0, r);
    if (core_body > 0.001) {                       // gate the fBm: cheap for outer pixels
        float ft = (p - 0.04) / 0.12;
        float flash = exp(-ft * ft);              // (pow() is undefined for negative base)
        float warp = fbm3(vec2(x * 3.0 + p, y * 3.0 - p), seed + 2.0);
        float turb = fbm4(vec2(x * 5.0 + warp * 1.5 + p * 1.5, y * 5.0 + warp * 1.5), seed + 3.0);
        turb = pow(turb, 1.4);
        float core_i = core_body * (0.35 + 1.1 * turb) * (0.7 * life + 1.9 * flash);
        rgb += core_i * CORE;
        float heart = smstep(core_scale * 0.45, 0.0, r) * (0.5 * life + 2.4 * flash);
        rgb += heart * vec3(1.0);
    }

    // soft-clip bloom (hue-preserving); blend_add + project glow add the HDR punch
    vec3 outc = (vec3(1.0) - exp(-rgb * exposure)) * intensity;
    COLOR = vec4(outc, 1.0);
}
