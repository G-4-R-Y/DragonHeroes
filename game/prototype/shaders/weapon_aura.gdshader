// weapon_aura - blade/weapon enchant flare (shadow-aura weapons!)
// Godot 4.6 canvas_item, gl_compatibility-safe. Elongated tilted energy
// overlay: sharp core band along the blade axis + fBm lick (3 octaves) +
// erosion at the edges, element-tinted. `pulse` 1->0 drives a quick flare
// envelope (ProtoCosmetics.pulse() on each attack); `flip` mirrors the quad
// with the wielder's facing. Additive energy on a small quad — light source,
// not a medium, so blend_add is correct here.
shader_type canvas_item;
render_mode blend_add, unshaded;

uniform vec4  color_core : source_color = vec4(1.0, 0.6, 0.2, 1.0);
uniform vec4  color_edge : source_color = vec4(1.0, 0.85, 0.5, 1.0);
uniform float pulse : hint_range(0.0, 1.0) = 0.0;  // flare envelope 1->0
uniform float flip = 0.0;                          // 1 mirrors with facing
uniform float tilt = -0.45;                        // blade slant (radians)
uniform float seed = 3.0;

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
	vec2 uv = UV - 0.5;
	if (flip > 0.5) { uv.x = -uv.x; }
	float c = cos(tilt), s = sin(tilt);
	vec2 p = vec2(uv.x * c - uv.y * s, uv.x * s + uv.y * c) * 2.0;

	// blade frame: `along` runs hilt->tip, `across` the thin edge axis
	float along = p.y;
	float across = p.x * 2.6;
	float body = exp(-across * across * 1.4)
			* smooth01(along, -1.05, -0.80) * (1.0 - smooth01(along, 0.70, 1.02));

	// fBm lick crawling along the blade (TIME-advected, persistent texture)
	float adv = mod(TIME * 3.0, 240.0) + seed * 7.0;
	float n = fbm3(vec2(p.x * 5.0 + seed, p.y * 2.2 - adv));
	float raw = n * 0.85 + body * 0.30;
	float thr = 0.40;
	float lick = smooth01(raw, thr, thr + 0.28) * body;
	float edge = smooth01(raw, thr - 0.05, thr) * (1.0 - smooth01(raw, thr, thr + 0.07)) * body;
	float coreband = exp(-across * across * 3.5) * body;   // sharp spine of light

	// flare envelope: punchy attack, quick decay (pulse driven 1 -> 0)
	float env = pulse * pulse;
	vec3 rgb = (color_core.rgb * (lick * 1.4 + coreband * 1.3)
			+ color_edge.rgb * edge * 1.6) * env;
	COLOR = vec4(rgb * color_core.a, 1.0);  // blend_add: alpha folded into rgb
}
