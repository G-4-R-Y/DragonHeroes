# PROTOTYPE HARNESS — drifting ground mist (canon §12.29). One camera-glued
# mix-blend quad at z=12: above the darkness (10) and the light-pool tints (11),
# below the fireflies (13) and all fx (18+), so flames and skills cut through
# the mist. Reuses the darkness model's per-frame hole upload (ProtoDarkness
# .last_packed) — fog thins where light lives, which binds the two passes into
# one atmosphere. Density eases with ProtoFx.intensity (LOW keeps a wisp).
class_name ProtoFog
extends Node2D

const TEX_SIZE := 2.0

var density := 0.22

var _quad: Sprite2D
var _mat: ShaderMaterial

func _ready() -> void:
	z_as_relative = false
	z_index = 12
	var img := Image.create(int(TEX_SIZE), int(TEX_SIZE), false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	_quad = Sprite2D.new()
	_quad.texture = ImageTexture.create_from_image(img)
	_quad.centered = true
	_quad.texture_filter = TEXTURE_FILTER_LINEAR
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://prototype/shaders/fog.gdshader")
	_quad.material = _mat
	add_child(_quad)
	set_process(true)

func _process(_dt: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		_quad.visible = false
		return
	_quad.visible = true
	var center := cam.get_screen_center_position()
	var vs := get_viewport_rect().size / cam.zoom
	global_position = center
	_quad.scale = (vs * 1.04) / TEX_SIZE
	_mat.set_shader_parameter("origin", center - vs * 0.52)
	_mat.set_shader_parameter("size", vs * 1.04)
	_mat.set_shader_parameter("density", density * lerpf(0.5, 1.0, ProtoFx.intensity))
	# lights come from the GLOBAL registry texture darkness.gd publishes —
	# nothing to copy here (canon §12.30: one gather, many consumers)

func _pool_debug() -> Dictionary:
	return {"size": 1, "peak_in_use": 1}
