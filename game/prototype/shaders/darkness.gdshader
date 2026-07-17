// darkness - the 2D lighting model (canon §12.28/§12.30). ONE multiplicative
// quad over the view: dark ambient + light holes read from the GLOBAL light
// registry texture (dh_light_tex, packed by darkness.gd — same registry the
// fog/water/sprite shaders consume). v0.1.15 adds:
//  - SDF SHADOWS: caster-flagged lights cone-march the world distance field
//    baked by world_gen, so light stops passing through walls (soft penumbras
//    widen with distance — the "Noita-family" raymarched SDF lighting).
//  - ORDERED DITHER: the gaussian falloff is quantized into bands through a
//    4x4 Bayer matrix anchored to WORLD pixels (Obra Dinn read) — the smooth
//    24-bit gradient becomes authored-looking pixel art and never swims.
// gl_compatibility-safe: fragment-only, texelFetch, no compute.
shader_type canvas_item;
render_mode blend_mul, unshaded;

uniform vec4 ambient : source_color = vec4(0.40, 0.44, 0.62, 1.0);
uniform vec2 origin = vec2(0.0);  // world-space rect of this quad (set per frame)
uniform vec2 size = vec2(640.0, 360.0);
uniform int shadow_casters = 6;   // intensity-gated: 0 LOW / 4 MED / 6 HIGH
uniform float dither_steps = 7.0;
// world occlusion SDF (world_gen bake; px distances / SDF_MAX). size 0 = none.
uniform sampler2D sdf_tex : filter_linear;
uniform vec2 sdf_origin = vec2(0.0);
uniform vec2 sdf_size = vec2(0.0);

global uniform sampler2D dh_light_tex;
global uniform int dh_light_count;

const float SDF_MAX = 500.0;

float sdf_d(vec2 wp) {
	vec2 uv = (wp - sdf_origin) / sdf_size;
	if (uv.x <= 0.0 || uv.y <= 0.0 || uv.x >= 1.0 || uv.y >= 1.0) {
		return SDF_MAX;
	}
	return texture(sdf_tex, uv).r * SDF_MAX;
}

// branchless 4x4 Bayer: b2 = [[0,2],[3,1]] via 2x+3y-4xy, recursed once
float b2(vec2 p) {
	p = floor(mod(p, 2.0));
	return 2.0 * p.x + 3.0 * p.y - 4.0 * p.x * p.y;
}
float bayer4(vec2 p) {
	return (4.0 * b2(floor(p * 0.5)) + b2(p)) / 16.0;
}

// sphere-traced soft shadow toward the light; k controls penumbra width
float shadow_march(vec2 from, vec2 to, float dith) {
	vec2 dir = to - from;
	float len = length(dir);
	if (len < 14.0) {
		return 1.0;
	}
	dir /= len;
	float res = 1.0;
	float t = 5.0 + dith * 6.0;   // dithered start hides step banding
	for (int s = 0; s < 12; s++) {
		if (t >= len - 6.0 || res < 0.04) {
			break;
		}
		float d = sdf_d(from + dir * t);
		res = min(res, 9.0 * d / t);
		t += max(d, 5.0);
	}
	return clamp(res, 0.0, 1.0);
}

void fragment() {
	vec2 world = origin + UV * size;
	float dith = bayer4(floor(world));
	float lit = 0.0;
	int n = min(dh_light_count, 16);
	int cast_left = shadow_casters;
	bool has_sdf = sdf_size.x > 1.0;
	for (int i = 0; i < n; i++) {
		vec4 L = texelFetch(dh_light_tex, ivec2(i, 0), 0);   // x,y,radius,strength
		vec4 M = texelFetch(dh_light_tex, ivec2(i, 1), 0);   // r,g,b,casts
		vec2 d = world - L.xy;
		d.y *= 1.55;                       // elliptical falloff — floor projection
		float r = max(L.z, 1.0);
		float c = L.w * exp(-dot(d, d) / (r * r));
		if (M.a > 0.5 && has_sdf && cast_left > 0 && c > 0.012) {
			cast_left--;
			c *= shadow_march(world, L.xy, dith);
		}
		lit += c;
	}
	lit = clamp(lit, 0.0, 1.0);
	lit = lit * lit * (3.0 - 2.0 * lit);   // soft shoulder
	// ordered dither: falloff becomes authored pixel-art bands, world-anchored
	lit = clamp(floor(lit * dither_steps + dith) / dither_steps, 0.0, 1.0);
	vec3 m = mix(ambient.rgb, vec3(1.0), lit);
	COLOR = vec4(m, 1.0);
}
