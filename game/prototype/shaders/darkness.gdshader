// darkness - the 2D lighting model (canon §12.28). ONE multiplicative quad over
// the whole view: the world sits in a dark blue-violet ambient and LIGHT HOLES
// (fire fields, glowshrooms, the hero's lantern pool, legendary presence) punch
// through to full brightness. This is the Children-of-Morta / Phantom Tower
// foundation: effects can only read as light sources when the world is dark.
// gl_compatibility-safe: blend_mul, no screen reads, uniform-bounded loop.
shader_type canvas_item;
render_mode blend_mul, unshaded;

uniform vec4 ambient : source_color = vec4(0.40, 0.44, 0.62, 1.0);
uniform int light_count = 0;
uniform vec4 lights[16];          // xy = world px, z = radius px, w = strength
uniform vec2 origin = vec2(0.0);  // world-space rect of this quad (set per frame)
uniform vec2 size = vec2(640.0, 360.0);

float hash12(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 world = origin + UV * size;
	float lit = 0.0;
	for (int i = 0; i < light_count; i++) {
		vec2 d = world - lights[i].xy;
		d.y *= 1.55;                       // elliptical falloff — floor projection
		float r = max(lights[i].z, 1.0);
		lit += lights[i].w * exp(-dot(d, d) / (r * r));
	}
	lit = clamp(lit, 0.0, 1.0);
	// smoothstep gives the pools a soft shoulder instead of a linear ramp
	lit = lit * lit * (3.0 - 2.0 * lit);
	vec3 m = mix(ambient.rgb, vec3(1.0), lit);
	// tiny dither kills banding on the wide gradients (multiply pass = LDR)
	m += (hash12(world) - 0.5) * (1.5 / 255.0);
	COLOR = vec4(m, 1.0);
}
