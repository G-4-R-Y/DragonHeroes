// prop_sway - wind + walk-through displacement for foliage props (canon
// §12.29). Vertex-only: tops sway on a world-phase wind (each tree at its own
// phase), bases stay pinned, and anything the player brushes past bends away
// — the cheapest "the world is alive and touchable" read there is.
// Shared ShaderMaterial: world_gen updates player_pos once per frame.
shader_type canvas_item;
render_mode blend_mix;

uniform vec2 player_pos = vec2(0.0);
uniform float strength : hint_range(0.0, 2.0) = 1.0;

void vertex() {
	vec2 world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	float pin = clamp(1.0 - UV.y, 0.0, 1.0);   // top moves, rooted base doesn't
	float sway = sin(TIME * 1.7 + world.x * 0.051 + world.y * 0.033) * 1.25
			+ sin(TIME * 3.1 + world.x * 0.013) * 0.45;
	vec2 away = world - player_pos;
	float push = exp(-dot(away, away) / (24.0 * 24.0)) * 5.5
			* (away.x >= 0.0 ? 1.0 : -1.0);
	VERTEX.x += (sway + push) * pin * pin * strength;
}
