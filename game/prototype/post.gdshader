// PROTOTYPE HARNESS — full-frame screen post pass (spec §2.3). First .gdshader in
// the repo. One fragment pass, ~5 taps over 230k px: radial chromatic aberration +
// vignette + over-bright grade. NO gaussian bloom — "bloom" is faked by the additive
// ribbon/glow layer (no multi-pass blur on the gl_compatibility fill budget).
//
// All aberration offsets are expressed in SCREEN_PIXEL_SIZE texel units (= (1/640,
// 1/360)); the integer 2x upscale is a post-render blit the shader never sees.
// The Vulkan opt-in dials bright_boost toward 0 (real HDR glow takes over on top).
shader_type canvas_item;
render_mode blend_mix, unshaded;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float aberration = 1.0;      // texels (base <= 1.5); pulse() kicks this
uniform float vig_inner = 0.5;       // dist where vignette begins
uniform float vig_outer = 1.25;      // dist where vignette bottoms out
uniform float bright_boost = 0.28;   // over-bright gain (0 under Vulkan HDR)
uniform vec2 kick_center = vec2(0.5, 0.5);
uniform float intensity = 0.5;       // <0.15 = safety passthrough (rect also hidden)

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 col;
	// Safety branch: below the fake-bloom floor, pass the frame straight through
	// (post.gd also hides the ColorRect + skips the backbuffer copy at this level).
	// canvas_item shaders forbid `return` in fragment(), so this is a plain branch.
	if (intensity < 0.15) {
		col = texture(screen_tex, uv).rgb;
	} else {
		vec2 d = uv - kick_center;
		float dist = length(d);
		// Radial chromatic aberration — offsets in texel units, growing toward the rim.
		vec2 off = normalize(d + vec2(1e-6)) * SCREEN_PIXEL_SIZE * aberration * dist * 2.0;
		float r = texture(screen_tex, uv + off).r;
		vec4 g = texture(screen_tex, uv);
		float b = texture(screen_tex, uv - off).b;
		col = vec3(r, g.g, b);
		// Over-bright grade: the "additive over a dark scene" pop (mild gain).
		col += col * bright_boost;
		// Vignette — folds in and replaces ambient.gd's old static vignette.
		float vig = 1.0 - smoothstep(vig_inner, vig_outer, dist);
		col *= vig;
	}
	COLOR = vec4(col, 1.0);
}
