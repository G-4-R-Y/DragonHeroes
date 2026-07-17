// Rim-glow outline for actor sprites (Phantom Tower / Hades elite silhouettes,
// canon §12.26): a colored 1-2 texel glow hugging the sprite's alpha edge, so
// elites/bosses read instantly against the dark world. Pure texture-alpha
// neighborhood sampling — gl_compatibility-safe, shared material per color
// (ProtoGlow.rim_material cache), zero per-frame cost beyond the 8 taps.
shader_type canvas_item;

uniform vec4  rim_color : source_color = vec4(1.0, 0.3, 0.9, 1.0);
uniform float rim_strength : hint_range(0.0, 3.0) = 1.15;
uniform float texel : hint_range(0.5, 3.0) = 1.5;   // outline reach, in texels

void fragment() {
	vec4 base = COLOR;                       // pre-set: texture * modulate
	vec2 px = TEXTURE_PIXEL_SIZE * texel;
	float a = texture(TEXTURE, UV).a;
	float n = 0.0;
	n = max(n, texture(TEXTURE, UV + vec2(px.x, 0.0)).a);
	n = max(n, texture(TEXTURE, UV - vec2(px.x, 0.0)).a);
	n = max(n, texture(TEXTURE, UV + vec2(0.0, px.y)).a);
	n = max(n, texture(TEXTURE, UV - vec2(0.0, px.y)).a);
	n = max(n, texture(TEXTURE, UV + px * 0.7071).a);
	n = max(n, texture(TEXTURE, UV - px * 0.7071).a);
	n = max(n, texture(TEXTURE, UV + vec2(px.x, -px.y) * 0.7071).a);
	n = max(n, texture(TEXTURE, UV + vec2(-px.x, px.y) * 0.7071).a);
	// outside-the-body halo where a neighbor is solid, plus a soft inner rim
	float halo = clamp(n - a, 0.0, 1.0);
	float inner = a * (1.0 - a) * 2.0;
	float rim = (halo + inner * 0.35) * rim_strength;
	COLOR = vec4(base.rgb + rim_color.rgb * rim, max(base.a, halo * rim_color.a * rim_strength));
}
