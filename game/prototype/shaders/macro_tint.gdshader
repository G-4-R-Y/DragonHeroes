// macro_tint - macro ground variation ("procgen stops looking procgen").
// ONE camera-glued multiplicative quad UNDER the water overlay (z=-8): a
// static 2-octave world-space value noise drifts floor brightness +-6% and
// cools the dark patches toward moonlit blue, so the 16-tile atlas repetition
// dissolves into big organic regions. No TIME term — the ground itself varies;
// mood and light stay owned by the darkness pass above. gl_compatibility-safe.
shader_type canvas_item;
render_mode blend_mul, unshaded;

uniform vec2 origin = vec2(0.0);  // world-space rect of this quad (set per frame)
uniform vec2 size = vec2(640.0, 360.0);
uniform float strength = 1.0;     // 0 = flat white (off) .. 1 = full drift

float hash12(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x),
			mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	vec2 world = origin + UV * size;
	// 2 octaves: ~50-tile then ~20-tile features (16 px tiles); widen the
	// mid-heavy value-noise histogram so full-light/full-dark patches exist
	float n = vnoise(world * 0.00125) * 0.65 + vnoise(world * 0.0031) * 0.35;
	n = clamp((n - 0.5) * 1.7 + 0.5, 0.0, 1.0);
	float bright = 1.0 + (n - 0.5) * 0.12;                 // +-6% brightness drift
	vec3 hue = mix(vec3(0.95, 1.0, 1.08), vec3(1.0),
			clamp(n * 1.6, 0.0, 1.0));                     // cool the dark patches
	COLOR = vec4(mix(vec3(1.0), hue * bright, strength), 1.0);
}
