// fog - drifting ground mist over the dark world (canon §12.29). Mix-blend,
// world-space domain-warped fBm scrolled by TIME; density THINS near the same
// light holes the darkness model uses (fire burns the fog off, glowshrooms
// clear little pockets) — that coupling is what makes it read as one
// atmosphere instead of a screen overlay. gl_compatibility-safe.
shader_type canvas_item;
render_mode blend_mix, unshaded;

uniform vec4 tint : source_color = vec4(0.52, 0.58, 0.80, 1.0);
uniform float density : hint_range(0.0, 1.0) = 0.22;
uniform vec2 origin = vec2(0.0);
uniform vec2 size = vec2(640.0, 360.0);

// the shared light registry (packed by darkness.gd — canon §12.30)
global uniform sampler2D dh_light_tex;
global uniform int dh_light_count;

float hash12(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}
float fbm3(vec2 p) {
	float t = 0.0, amp = 0.5, fr = 1.0;
	for (int i = 0; i < 3; i++) { t += amp * vnoise(p * fr); fr *= 2.0; amp *= 0.5; }
	return t;
}

void fragment() {
	vec2 world = origin + UV * size;
	vec2 p = world * 0.011;
	float t = TIME * 0.05;
	// two-layer domain warp: slow rolling banks with finer curls inside
	float q = fbm3(p + vec2(t * 0.7, -t * 0.3));
	float f = fbm3(p * 1.9 + (q - 0.5) * 1.4 + vec2(-t, t * 0.4));
	float d = smoothstep(0.35, 0.78, f * 0.75 + q * 0.25) * density;
	// light burns fog off (same registry holes the darkness pass lifts)
	float lit = 0.0;
	int n = min(dh_light_count, 16);
	for (int i = 0; i < n; i++) {
		vec4 L = texelFetch(dh_light_tex, ivec2(i, 0), 0);
		vec2 dd = world - L.xy;
		dd.y *= 1.55;
		float r = max(L.z * 1.25, 1.0);
		lit += L.w * exp(-dot(dd, dd) / (r * r));
	}
	d *= 1.0 - clamp(lit, 0.0, 1.0) * 0.75;
	COLOR = vec4(tint.rgb, d);
}
