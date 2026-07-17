// PROTOTYPE HARNESS — full-frame screen post pass (spec §2.3). First .gdshader in
// the repo. One fragment pass, ~5 taps over 230k px (+2-4 tiny LUT taps when a
// baked grade is bound): radial chromatic aberration + vignette + over-bright +
// color grade. NO gaussian bloom — "bloom" is faked by the additive ribbon/glow
// layer (no multi-pass blur on the gl_compatibility fill budget).
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
// Heat-haze sources (fire fields, cinder bursts) — registered world-side by
// post.gd, converted to screen space per frame. Riding THIS pass costs zero
// extra backbuffer copies. xy = screen uv, z = radius (height units),
// w = strength (texels). Off below the fake-bloom floor like everything else.
uniform int haze_count = 0;
uniform vec4 haze_src[6];
// 3D-LUT color grade baked to a 2D strip (genforge/pipeline/lut_gen.py):
// 256x256 = 16x16 grid of 16x16 tiles; R -> x in tile, G -> y in tile,
// B -> tile index. Per-biome grades are pure data (Hades color scripting).
// lut_amount == 0 keeps the analytic split-tone path in fragment() alive,
// so a missing texture can never regress the frame. lut_blend crossfades
// toward lut_tex2 (biome hand-offs, driven by post.gd::set_lut). GLES3-safe:
// no sampler3D anywhere, just two 2D fetches mixed by the B fraction.
uniform sampler2D lut_tex : filter_linear, repeat_disable;
uniform sampler2D lut_tex2 : filter_linear, repeat_disable;
uniform float lut_amount : hint_range(0.0, 1.0) = 0.0;
uniform float lut_blend : hint_range(0.0, 1.0) = 0.0;

// Strip sampler for a CLAMPED [0,1] color: bilinear R/G inside one tile — the
// half-texel inset keeps the linear filter from bleeding across tile seams —
// plus two whole-tile fetches mixed by the B fraction (the third LUT axis).
vec3 lut_grade(sampler2D lut, vec3 c) {
	float slice = c.b * 255.0;
	float s0 = floor(slice);
	float s1 = min(s0 + 1.0, 255.0);
	vec2 inner = (c.rg * 15.0 + 0.5) / 256.0;
	vec2 uv0 = vec2(mod(s0, 16.0), floor(s0 / 16.0)) / 16.0 + inner;
	vec2 uv1 = vec2(mod(s1, 16.0), floor(s1 / 16.0)) / 16.0 + inner;
	return mix(texture(lut, uv0).rgb, texture(lut, uv1).rgb, slice - s0);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 col;
	// Safety branch: below the fake-bloom floor, pass the frame straight through
	// (post.gd also hides the ColorRect + skips the backbuffer copy at this level).
	// canvas_item shaders forbid `return` in fragment(), so this is a plain branch.
	if (intensity < 0.15) {
		col = texture(screen_tex, uv).rgb;
	} else {
		// Heat haze: gaussian-falloff shimmer around each source. Distances are
		// height-normalized (dd.x * aspect) so pools stay round on 16:9.
		float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
		for (int i = 0; i < haze_count; i++) {
			vec2 dd = uv - haze_src[i].xy;
			dd.x *= aspect;
			float fall = exp(-dot(dd, dd) / max(haze_src[i].z * haze_src[i].z, 1e-6));
			float w1 = sin(uv.y * 140.0 + TIME * 9.0 + float(i) * 2.7)
					+ 0.55 * sin(uv.y * 291.0 - TIME * 14.0 + float(i));
			float w2 = sin(uv.x * 120.0 + TIME * 6.5 + float(i) * 1.3);
			uv += vec2(w1, 0.45 * w2) * fall * haze_src[i].w * SCREEN_PIXEL_SIZE;
		}
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
		// Color grade (the CoM / Phantom Tower palette unifier), AFTER the
		// over-bright term. Two paths on a uniform branch (no divergence):
		if (lut_amount > 0.0) {
			// Baked LUT strip(s): per-biome grades as pure data. The LUT eats
			// [0,1]; the over-bright excess (col > 1 from bright_boost) is
			// re-added on top so vignetted edges keep the analytic path's pop.
			vec3 base = clamp(col, vec3(0.0), vec3(1.0));
			vec3 graded = lut_grade(lut_tex, base);
			if (lut_blend > 0.0) {
				graded = mix(graded, lut_grade(lut_tex2, base), lut_blend);
			}
			col = mix(col, graded + (col - base), lut_amount);
		} else {
			// Analytic fallback (the exact grade veilands_default.png bakes):
			// shadows pull cool blue-violet, highlights stay warm — plus a
			// mild S-curve. Runs under the darkness model, so "shadows" is
			// most of the frame and the tint reads as atmosphere, not a filter.
			float lum = dot(col, vec3(0.299, 0.587, 0.114));
			vec3 tint = mix(vec3(0.80, 0.85, 1.14), vec3(1.06, 1.01, 0.93),
					smoothstep(0.0, 0.55, lum));
			col *= tint;
			col = mix(col, col * col * (3.0 - 2.0 * col), 0.18);
		}
		// Vignette — folds in and replaces ambient.gd's old static vignette.
		float vig = 1.0 - smoothstep(vig_inner, vig_outer, dist);
		col *= vig;
	}
	COLOR = vec4(col, 1.0);
}
