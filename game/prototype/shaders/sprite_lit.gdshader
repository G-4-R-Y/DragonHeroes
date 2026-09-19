// sprite_lit - per-pixel N·L sprite lighting from the global light registry
// (canon §12.30 — the Dead Cells stack). Actors' frames are CanvasTextures
// (bundle_art.gd) whose normal maps arrive in NORMAL; the registry lights
// (dh_light_tex — the same records driving the darkness holes and light
// pools) sculpt volume across the sprite instead of tinting cardboard. The
// response is CEL-QUANTIZED into bands so lit pixels keep reading as pixel
// art (raw N·L = greasy plastic). Sprites without maps get flat normals and
// only the attenuation tint. Modulate (hit flash / fades) is preserved:
// lighting multiplies COLOR, never recomputes it. gl_compatibility-safe.
shader_type canvas_item;
render_mode blend_mix;

uniform float bands = 3.0;             // cel steps on the N·L response
uniform float light_gain = 1.15;
uniform float ambient_floor = 0.74;    // unlit sprite brightness (the darkness
                                       // quad above still grades the scene)
// Emissive Channel Mask (genforge.hifi, sprites prompt.md pillar 2): hifi
// bundles pack the emissive mask into the normal map's BLUE channel low range
// — B < 0.5 never occurs in a valid tangent normal (nz > 0 -> B >= 0.5; the
// flat default is 1.0), so every existing sheet_n.png reads as "no emission".
// Emissive pixels are lit flat ("sharp unshaded glow") and pushed above 1.0 so
// the Vulkan WorldEnvironment glow blooms them; under gl_compatibility the
// push just clamps and ProtoGlow's additive sprites carry the halo as before.
uniform float emissive_gain = 1.5;
global uniform sampler2D dh_light_tex;
global uniform int dh_light_count;

varying vec2 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 base = COLOR;                 // albedo * modulate — keep both
	float nb = texture(NORMAL_TEXTURE, UV).b;
	float emis = nb < 0.5 ? (1.0 - nb * 2.0) : 0.0;   // packed intensity 0..1
	vec3 n = emis > 0.0 ? vec3(0.0, 0.0, 1.0) : normalize(NORMAL);
	vec3 acc = vec3(0.0);
	int cnt = min(dh_light_count, 16);
	for (int i = 0; i < cnt; i++) {
		vec4 L = texelFetch(dh_light_tex, ivec2(i, 0), 0);   // x,y,radius,strength
		vec2 d = L.xy - wpos;
		float r = max(L.z, 1.0);
		float att = L.w * exp(-dot(d, d) / (r * r * 1.4));
		if (att < 0.004) {
			continue;
		}
		vec4 M = texelFetch(dh_light_tex, ivec2(i, 1), 0);   // r,g,b,casts
		// light sits slightly above the ground plane; screen y points down
		float ndl = max(dot(n, normalize(vec3(d.x, d.y, 52.0))), 0.0);
		ndl = floor(ndl * bands + 0.5) / bands;              // cel quantize
		acc += M.rgb * (att * ndl);
	}
	vec3 lit = base.rgb * (ambient_floor + acc * light_gain);
	// previous (pre-hifi) output, kept for reference:
	// COLOR = vec4(base.rgb * (ambient_floor + acc * light_gain), base.a);
	COLOR = vec4(mix(lit, base.rgb * (1.0 + emis * emissive_gain), emis), base.a);
}
