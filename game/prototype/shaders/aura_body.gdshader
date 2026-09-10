// aura_body - persistent cosmetic body aura (Grand Chase elemental auras)
// Godot 4.6 canvas_item, gl_compatibility-safe (GLES3 / WebGL2).
// ONE parametrized body-hugging medium: domain-warped fBm filaments (3 octaves,
// mobile budget) advected by TIME inside an elongated silhouette band, erosion
// at the edges, element-tinted via uniforms. Ports genforge/vfx_lab/auras.
//
// BLEND USAGE: render_mode is FIXED to blend_mix (no runtime switch). For
// glow elements (fire/frost/storm) set occlude=0: output is translucent
// colored light with HDR-ish cores. For smoke elements (umbral/blood/venom)
// set occlude=1: the medium OCCLUDES the scene (near-black smoke_color body,
// alpha capped by max_alpha) with color_edge rims on top — the umbra.gdshader
// pattern, because additive darkness is physically impossible (canon §12.27).
// The quad is pre-stretched non-uniformly by the Sprite2D scale, so the band
// is CIRCULAR in UV space and elliptical in world space.
shader_type canvas_item;
render_mode blend_mix, unshaded;

uniform vec4  color_core : source_color = vec4(1.0, 0.6, 0.2, 1.0);  // hot filament cores
uniform vec4  color_edge : source_color = vec4(1.0, 0.85, 0.5, 1.0); // erosion rim / arcs
uniform vec4  smoke_color : source_color = vec4(0.02, 0.01, 0.05, 1.0); // occlude body
uniform float rise_speed = 1.2;        // filament advection (negative = downward, blood)
uniform float erosion : hint_range(0.0, 1.0) = 0.40;   // edge dissolve threshold
uniform float arc_amount : hint_range(0.0, 1.0) = 0.0; // storm vein filaments
uniform float occlude : hint_range(0.0, 1.0) = 0.0;    // 1 -> umbral-style smoke
uniform float max_alpha : hint_range(0.0, 1.0) = 0.55; // alpha cap (occlude path)
uniform float strength : hint_range(0.0, 1.0) = 1.0;   // intensity gate (alpha only)
uniform float seed = 5.0;

// ---- hash / value noise / fbm (lab parity, <= 3 octaves) -------------------
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
float smooth01(float v, float a, float b) {
	float t = clamp((v - a) / (b - a), 0.0, 1.0);
	return t * t * (3.0 - 2.0 * t);
}

void fragment() {
	// pos in [-1,1]; the sprite's non-uniform scale makes the world-space band
	// elliptical, so a CIRCLE here is the silhouette band (top-stretched by the
	// caller's scale choice: taller quad = upward lick)
	vec2 pos = (UV - 0.5) * 2.0;
	float e = length(pos);
	float band = smooth01(e, 0.40, 0.62) * (1.0 - smooth01(e, 0.82, 1.18));

	// TIME-based advection (persistent: speed never syrups), mod keeps the
	// sin() hash args in float32-precise range
	float flow = mod(TIME * rise_speed, 240.0) + seed * 7.0;
	// low-freq sway so the shroud leans/waves (not a clean shell)
	float sway = fbm3(vec2(pos.y * 1.3 - flow * 0.4 + 3.0, seed)) - 0.5;
	float xs = pos.x + sway * 0.30;
	// warp + tall filaments (low y frequency -> vertical streaks)
	float q = fbm3(vec2(xs * 2.0 + seed, pos.y * 1.0 - flow * 0.55));
	float n = fbm3(vec2(xs * 4.2 + (q - 0.5) * 2.2, pos.y * 1.5 - flow + (q - 0.5) * 1.4));

	// NOISE-DOMINANT density: the medium breaks the shell into wisps
	float raw = n * 1.05 + band * 0.22;
	float thr = erosion + 0.08 * (q - 0.5);
	float shell = band * (0.50 + 0.70 * smooth01(n, 0.30, 0.75));
	float density = smooth01(raw, thr, thr + 0.24) * shell;
	// patchy rim at the threshold crossing, never a full outline
	float rim = smooth01(raw, thr - 0.06, thr) * (1.0 - smooth01(raw, thr, thr + 0.08))
			* shell * smooth01(n, 0.38, 0.72);
	float core = smooth01(raw, thr + 0.20, thr + 0.48) * shell;

	// storm arcs: ridge veins re-struck ~7x/s (quantized TIME cell in the seed)
	float arc = 0.0;
	if (arc_amount > 0.001) {
		float tt = floor(TIME * 7.0) + seed * 31.0;
		float gate = step(0.35, fract(sin(tt * 91.7) * 43758.5453));
		float vn = vnoise(vec2(xs * 3.0 + tt * 17.0, pos.y * 2.0 - flow * 0.3));
		float ridge = 1.0 - abs(vn * 2.0 - 1.0);
		arc = pow(ridge, 18.0) * gate * arc_amount * (0.35 + 0.65 * band);
	}

	// ---- glow layer (both paths share it) ----
	vec3 glow_rgb = color_core.rgb * core * 1.7 + color_edge.rgb * (rim * 0.8 + arc * 1.6);
	float glow_lum = clamp(max(glow_rgb.r, max(glow_rgb.g, glow_rgb.b)), 0.0, 1.0);
	vec3 glow_hue = glow_rgb / max(glow_lum, 0.001);
	float a_glow = clamp(density * 0.55 + glow_lum, 0.0, 1.0);
	vec3 rgb_glow = (color_core.rgb * density * 0.35 * (1.0 - glow_lum) + glow_hue * glow_lum)
			/ max(a_glow, 0.001);

	// ---- occlude layer (umbral smoke; umbra.gdshader composite) ----
	float folds = smooth01(n, 0.35, 0.9);
	vec3 smoke_rgb = smoke_color.rgb * (0.6 + 0.8 * folds);
	float a_smoke = clamp(density * 1.3, 0.0, max_alpha);
	float a_occl = clamp(a_smoke + glow_lum * (1.0 - a_smoke), 0.0, 0.95);
	vec3 rgb_occl = (smoke_rgb * a_smoke * (1.0 - glow_lum) + glow_hue * glow_lum)
			/ max(a_occl, 0.001);

	float a_out = mix(a_glow, a_occl, occlude) * strength * color_core.a;
	vec3 rgb_out = mix(rgb_glow, rgb_occl, occlude);
	COLOR = vec4(clamp(rgb_out, vec3(0.0), vec3(1.0)), clamp(a_out, 0.0, 1.0));
}
