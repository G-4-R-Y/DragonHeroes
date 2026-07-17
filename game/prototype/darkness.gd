# PROTOTYPE HARNESS — the 2D lighting model host (canon §12.28). A single
# camera-glued multiplicative quad at z=10: everything BELOW it (floor, decals,
# telegraphs, creatures) falls into a dark blue ambient; LIGHT HOLES punch
# through to full brightness. Everything ABOVE it (light pools z=11, fx 18+,
# ribbons 20, shader quads 21) composites over the darkened scene and thus
# reads as LIGHT. This is the Children-of-Morta / Phantom Tower foundation.
#
# Holes come from two registries, re-gathered every frame:
#  - dynamic: ProtoLights records (fire fields, hero lantern, bolt glows,
#    legendary presence) — position/flicker already animated there;
#  - static:  environment sources registered once by world_gen (glowshrooms),
#    flickered here with a cheap two-sine wobble.
# The shader takes the nearest MAX_HOLES to the camera — registration is
# unbounded, per-frame cost is not.
class_name ProtoDarkness
extends Node2D

const MAX_HOLES := 16
const TEX_SIZE := 2.0

var ambient := Color(0.40, 0.44, 0.62)  # multiply floor — tune via captures
var enabled := true

var _quad: Sprite2D
var _mat: ShaderMaterial
var _static: Array = []                 # env holes: [pos, radius, strength, phase, rate]
var _t := 0.0

# THE LIGHT REGISTRY (canon §12.30): the gathered holes are packed into a
# 16x2 RGBAF data texture published as the `dh_light_tex`/`dh_light_count`
# shader GLOBALS — darkness, fog, water and the sprite N·L shaders all read
# the same registry with zero coupling to this node. Row 0: x, y, radius,
# strength. Row 1: r, g, b, casts_shadows.
var _light_img: Image
var _light_tex: ImageTexture

# Static world SDF (baked by world_gen from impassable tiles): shadow-caster
# lights cone-march it so light stops passing through walls.
var _sdf_tex: ImageTexture = null
var _sdf_origin := Vector2.ZERO
var _sdf_px := Vector2.ZERO

func _ready() -> void:
	z_as_relative = false
	z_index = 10
	var img := Image.create(int(TEX_SIZE), int(TEX_SIZE), false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	_quad = Sprite2D.new()
	_quad.texture = ImageTexture.create_from_image(img)
	_quad.centered = true
	_quad.texture_filter = TEXTURE_FILTER_LINEAR
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://prototype/shaders/darkness.gdshader")
	_quad.material = _mat
	add_child(_quad)
	_light_img = Image.create(MAX_HOLES, 2, false, Image.FORMAT_RGBAF)
	_light_tex = ImageTexture.create_from_image(_light_img)
	RenderingServer.global_shader_parameter_set("dh_light_tex", _light_tex)
	set_process(true)

# World occlusion field for shadow marching. origin/size in world px.
func set_sdf(tex: ImageTexture, origin_px: Vector2, size_px: Vector2) -> void:
	_sdf_tex = tex
	_sdf_origin = origin_px
	_sdf_px = size_px
	_mat.set_shader_parameter("sdf_tex", tex)
	_mat.set_shader_parameter("sdf_origin", origin_px)
	_mat.set_shader_parameter("sdf_size", size_px)

# Environment light source (glowshrooms, future torches/braziers). Unbounded —
# the per-frame shader upload picks the nearest MAX_HOLES.
func add_static(pos: Vector2, radius := 30.0, strength := 0.8,
		flicker := 0.3, rate := 2.4) -> void:
	_static.append([pos, radius, strength, randf() * TAU, rate * (0.8 + randf() * 0.4),
			flicker])

func set_ambient(c: Color) -> void:
	ambient = c

func _process(dt: float) -> void:
	_t += dt
	var cam := get_viewport().get_camera_2d()
	if cam == null or not enabled:
		_quad.visible = false
		return
	_quad.visible = true
	var center := cam.get_screen_center_position()
	var vs := get_viewport_rect().size / cam.zoom
	global_position = center
	_quad.scale = (vs * 1.04) / TEX_SIZE
	_mat.set_shader_parameter("origin", center - vs * 0.52)
	_mat.set_shader_parameter("size", vs * 1.04)
	_mat.set_shader_parameter("ambient", ambient)

	# gather candidate holes: dynamic light pools + static environment sources
	# — entries are [pos, radius, strength, color, casts_shadows]
	var cand: Array = []
	var m := get_tree().get_first_node_in_group("main")
	if m != null and m.get("fx") != null:
		cand.append_array(m.fx.light_holes())
	var half := vs * 0.62
	for s in _static:
		var pos: Vector2 = s[0]
		if absf(pos.x - center.x) > half.x or absf(pos.y - center.y) > half.y:
			continue                        # cheap cull before the sort
		var w1: float = sin(_t * s[4] + s[3]) * 0.6 + sin(_t * s[4] * 2.3 + s[3] * 1.7) * 0.4
		var stg: float = s[2] * (1.0 + float(s[5]) * 0.3 * w1)
		cand.append([pos, s[1], clampf(stg, 0.0, 1.0), Color(0.45, 0.95, 1.0), false])
	if cand.size() > MAX_HOLES:
		cand.sort_custom(func(a, b) -> bool:
			return a[0].distance_squared_to(center) < b[0].distance_squared_to(center))
		cand.resize(MAX_HOLES)
	# publish the registry: pack into the global data texture (one gather,
	# many consumer shaders — darkness/fog/water/sprites stay decoupled)
	for i in MAX_HOLES:
		if i < cand.size():
			var c: Array = cand[i]
			_light_img.set_pixel(i, 0, Color(c[0].x, c[0].y, c[1], c[2]))
			var col: Color = c[3]
			_light_img.set_pixel(i, 1, Color(col.r, col.g, col.b, 1.0 if c[4] else 0.0))
		else:
			_light_img.set_pixel(i, 0, Color(0, 0, 0, 0))
			_light_img.set_pixel(i, 1, Color(0, 0, 0, 0))
	_light_tex.update(_light_img)
	RenderingServer.global_shader_parameter_set("dh_light_count", cand.size())
	# shadow quality follows the master intensity knob (usage, not allocation)
	_mat.set_shader_parameter("shadow_casters",
			0 if ProtoFx.intensity < 0.2 else (4 if ProtoFx.intensity < 0.75 else 6))

func _pool_debug() -> Dictionary:
	return {"size": MAX_HOLES, "peak_in_use": mini(_static.size(), MAX_HOLES)}
