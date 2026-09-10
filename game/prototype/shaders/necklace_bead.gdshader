// necklace_bead - one orbiting necklace bead (Grand Chase cosmetics)
// Godot 4.6 canvas_item, gl_compatibility-safe. Small radial sprite:
// bright gaussian core (pushes to white) + element-hue halo + two-sine
// flicker. The ORBIT MOTION is GDScript (ProtoCosmetics), not shader work —
// this is only the bead's look. Additive is safe here: the falloff is a pure
// gaussian (no hard shapes), the bead is a light source. Lab parity:
// genforge/vfx_lab/necklace_orbit/render.py.
shader_type canvas_item;
render_mode blend_add, unshaded;

uniform vec4  color : source_color = vec4(1.0, 0.6, 0.16, 1.0); // element tint
uniform float flicker : hint_range(0.0, 0.5) = 0.15;
uniform float seed = 0.0;                  // per-bead phase offset

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float d2 = dot(p, p);
	float fl = 1.0 + flicker * sin(TIME * 11.0 + seed * 37.0)
			+ flicker * 0.5 * sin(TIME * 23.0 + seed * 11.0);
	float core = exp(-d2 * 9.0) * 2.6;     // sigma ~1.6px on a 10px sprite
	float halo = exp(-d2 * 1.6) * 0.55;
	float hot = clamp((core + halo) * fl, 0.0, 2.4);
	vec3 rgb = mix(color.rgb, vec3(1.0), clamp(hot * 0.45, 0.0, 0.85)) * hot;
	COLOR = vec4(rgb * color.a, 1.0);      // blend_add: alpha folded into rgb
}
