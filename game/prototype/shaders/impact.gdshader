// Dragon Heroes VFX -- IMPACT SPARK / HIT
// Procedural, no textures. Ports the numpy render.py math 1:1.
// gl_compatibility-safe: standard frag ops, inlined value noise, one 10-iter
// loop for embers. No compute, no screen read, mobile-cheap.
shader_type canvas_item;
render_mode blend_add, unshaded;

// ------------------------------------------------------------ uniforms
uniform float progress   : hint_range(0.0, 1.0) = 0.0;  // life 0..1 (peak at 0)
uniform vec4  color       : source_color = vec4(1.0, 0.86, 0.55, 1.0); // hot tint
uniform vec2  dir         = vec2(1.0, 0.0);   // burst orientation (star axes)
uniform float seed        = 7.0;
uniform float intensity   = 1.0;   // global multiplier (crit = push higher)
uniform float ca_amount   = 0.013; // chromatic split (radial)


// ------------------------------------------------------------ noise
float hash2(float x, float y) {
    float n = sin(x * 127.1 + y * 311.7 + seed * 13.13) * 43758.5453;
    return fract(n);
}
float value_noise(float x, float y) {
    float xi = floor(x); float yi = floor(y);
    float xf = x - xi;   float yf = y - yi;
    float u = xf * xf * (3.0 - 2.0 * xf);
    float v = yf * yf * (3.0 - 2.0 * yf);
    float a = hash2(xi,       yi);
    float b = hash2(xi + 1.0, yi);
    float c = hash2(xi,       yi + 1.0);
    float d = hash2(xi + 1.0, yi + 1.0);
    return mix(mix(a, b, u), mix(c, d, u), v);
}
float sstep(float a, float b, float x) { return smoothstep(a, b, x); }

// one bidirectional lens streak: soft gaussian + razor-thin hot filament
float streak(float along, float perp, float ln, float th) {
    float soft = exp(-(perp / th) * (perp / th)) * exp(-(along / ln) * (along / ln));
    float line = exp(-(perp / (th * 0.30)) * (perp / (th * 0.30)))
               * exp(-(along / ln) * (along / ln));
    float flick = 0.65 + 0.5 * value_noise(along * 14.0, 2.0);
    return soft * flick + 1.3 * line;
}

// ------------------------------------------------------------ the effect
// single-channel HDR intensity at centered coord c (~[-1,1]), life p.
float field(vec2 c, float p) {
    float r   = length(c) + 1e-6;
    float ang = atan(c.y, c.x);
    float u = c.x; float v = c.y;

    // front-loaded envelopes: peak at p=0, ~all action in first third
    float core_env   = pow(clamp(1.0 - p / 0.30, 0.0, 1.0), 1.8);
    float star_env   = pow(clamp(1.0 - p / 0.40, 0.0, 1.0), 1.5);
    float ring_env   = pow(clamp(1.0 - p / 0.80, 0.0, 1.0), 1.1);
    float streak_env = pow(clamp(1.0 - p / 0.35, 0.0, 1.0), 1.7);
    float ember_env  = pow(clamp(1.0 - p / 0.95, 0.0, 1.0), 1.4);

    // 0. faint light-pop flash-disc
    float flash_env = pow(clamp(1.0 - p / 0.16, 0.0, 1.0), 2.0);
    float flash = flash_env * 0.42 * exp(-(r / 0.5) * (r / 0.5));

    // 1. hot core: tight gaussian point + faint halo (HDR >> 1)
    float core = core_env * (2.9 * exp(-(r / 0.048) * (r / 0.048))
                           + 0.8 * exp(-(r / 0.12) * (r / 0.12)));

    // 2. star / cross: 4 axis-aligned + 2 diagonal streaks, irregular tips
    float tipn = 0.80 + 0.40 * value_noise(ang * 3.0, 5.0);
    float L  = 0.60 * tipn;
    float tk = 0.028;
    float du = (u + v) * 0.70710678;
    float dv = (u - v) * 0.70710678;
    float star = star_env * (
          streak(u,  v,  L,        tk)
        + streak(v,  u,  L,        tk)
        + 0.55 * (streak(du, dv, L * 0.62, tk * 0.8)
                + streak(dv, du, L * 0.62, tk * 0.8))
    ) * 1.5;

    // 3. noisy radial sunburst filaments
    float rays = value_noise(ang * 9.0 + 17.0, 3.0);
    float spikes = pow(clamp(rays, 0.0, 1.0), 5.0);
    float spike_len = 0.55 * (0.8 + 0.4 * value_noise(ang * 9.0, 8.0));
    float radial_prof = exp(-((r - spike_len * 0.35) / (spike_len * 0.55))
                          * ((r - spike_len * 0.35) / (spike_len * 0.55)));
    float streaks = streak_env * spikes * radial_prof * 2.2;

    // 4. expanding SDF shockwave ring: sharp leading edge, soft trail
    float ring_r = 0.10 + 0.78 * (1.0 - pow(1.0 - p, 2.2));
    ring_r *= 1.0 + 0.035 * (value_noise(ang * 5.0, 9.0) - 0.5);
    float thick = 0.055 + 0.05 * p;
    float aa = 0.018;
    float outer = 1.0 - sstep(ring_r, ring_r + aa, r);
    float trail = sstep(ring_r - thick, ring_r, r);
    float rim   = exp(-((r - ring_r) / (aa * 1.6)) * ((r - ring_r) / (aa * 1.6)));
    float ring_noise = 0.45 + 0.95 * value_noise(ang * 7.0, 4.0);
    float ring = ring_env * (outer * trail * ring_noise + 0.55 * rim) * 1.5;

    // 5. flying ember sparks: travel out + fade = trailing life
    float embers = 0.0;
    float travel = 0.85 * (1.0 - pow(1.0 - p, 1.8));
    for (int i = 0; i < 10; i++) {
        float fi = float(i);
        float a  = (fi + 0.5) / 10.0 * TAU + hash2(fi * 3.1, 1.0) * 2.0;
        float sp = 0.55 + 0.5 * hash2(fi * 1.7, 2.0);
        float rr = travel * sp;
        vec2  pc = vec2(rr * cos(a), rr * sin(a));
        float caA = cos(a); float saA = sin(a);
        vec2  d  = c - pc;
        float along = d.x * caA + d.y * saA;
        float perp  = -d.x * saA + d.y * caA;
        embers += exp(-(along / 0.060) * (along / 0.060))
                * exp(-(perp / 0.013) * (perp / 0.013));
    }
    embers *= ember_env * 1.6;

    return flash + core + star + streaks + ring + embers;
}

void fragment() {
    // center the quad to [-1,1] and orient star axes to `dir`
    vec2 c = (UV - 0.5) * 2.0;
    float rot = atan(dir.y, dir.x);
    float cr = cos(rot); float sr = sin(rot);
    c = mat2(vec2(cr, sr), vec2(-sr, cr)) * c;

    // chromatic aberration: radial split (scale warps coord like the numpy ref)
    float ir = field(c * (1.0 - ca_amount), progress);
    float ig = field(c,                     progress);
    float ib = field(c * (1.0 + ca_amount), progress);

    vec3 rgb = vec3(ir, ig, ib) * color.rgb * intensity;

    // blend_add adds rgb*a; keep a=1 so additive HDR matches the numpy comp.
    // Values > 1 clip to white on LDR canvas (reads hot); a 2D glow/bloom
    // post-pass turns the >1 core + rim into real bloom.
    COLOR = vec4(rgb, 1.0);
}
