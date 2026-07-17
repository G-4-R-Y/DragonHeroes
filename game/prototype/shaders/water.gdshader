// water - animated dark water overlay (canon §12.29). One MultiMesh quad per
// water tile (built by world_gen, ONE draw call); INSTANCE_CUSTOM carries the
// shore mask (land to N/E/S/W) so foam hugs real coastlines. Two scrolling
// noise layers + thresholded specular glints; sits under the darkness pass so
// lakes fall into the same night as the land. gl_compatibility-safe.
shader_type canvas_item;
render_mode blend_mix, unshaded;

uniform vec4 deep_color : source_color = vec4(0.030, 0.055, 0.105, 1.0);
uniform vec4 base_color : source_color = vec4(0.065, 0.105, 0.170, 1.0);
uniform vec4 foam_color : source_color = vec4(0.42, 0.52, 0.62, 1.0);

varying vec2 wpos;
varying vec4 shore;   // r=N g=E b=S a=W: 1.0 where land borders this tile

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

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	shore = INSTANCE_CUSTOM;
}

void fragment() {
	// rolling body: slow large swell + finer counter-scrolled ripple
	float swell = fbm3(wpos * 0.055 + vec2(TIME * 0.045, TIME * 0.02));
	float rip = fbm3(wpos * 0.16 + vec2(-TIME * 0.07, TIME * 0.05));
	vec3 col = mix(deep_color.rgb, base_color.rgb, swell * 0.8 + rip * 0.2);
	// specular glints: thresholded ripple peaks, twinkling
	float g = rip * 0.6 + swell * 0.4
			+ 0.06 * sin(TIME * 2.2 + wpos.x * 0.31 + wpos.y * 0.17);
	float glint = smoothstep(0.74, 0.88, g);
	col += glint * vec3(0.20, 0.30, 0.42);
	// shore foam: hugs the mask edges, eaten by noise, breathing slowly
	float band = 0.0;
	band = max(band, shore.r * smoothstep(0.34, 0.02, UV.y));
	band = max(band, shore.b * smoothstep(0.66, 0.98, UV.y));
	band = max(band, shore.g * smoothstep(0.66, 0.98, UV.x));
	band = max(band, shore.a * smoothstep(0.34, 0.02, UV.x));
	float lap = fbm3(wpos * 0.25 + vec2(TIME * 0.10, -TIME * 0.06));
	float foam = band * smoothstep(0.38, 0.72, lap)
			* (0.55 + 0.45 * sin(TIME * 1.4 + wpos.x * 0.2 + wpos.y * 0.13));
	col = mix(col, foam_color.rgb, clamp(foam, 0.0, 0.8));
	COLOR = vec4(col, 1.0);
}
