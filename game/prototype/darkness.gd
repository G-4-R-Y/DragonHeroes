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
	set_process(true)

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
		cand.append([pos, s[1], clampf(stg, 0.0, 1.0)])
	if cand.size() > MAX_HOLES:
		cand.sort_custom(func(a, b) -> bool:
			return a[0].distance_squared_to(center) < b[0].distance_squared_to(center))
		cand.resize(MAX_HOLES)
	var packed := PackedColorArray()
	for c in cand:
		packed.append(Color(c[0].x, c[0].y, c[1], c[2]))
	_mat.set_shader_parameter("light_count", packed.size())
	if packed.size() > 0:
		while packed.size() < MAX_HOLES:
			packed.append(Color(0, 0, 0, 0))
		_mat.set_shader_parameter("lights", packed)

func _pool_debug() -> Dictionary:
	return {"size": MAX_HOLES, "peak_in_use": mini(_static.size(), MAX_HOLES)}
