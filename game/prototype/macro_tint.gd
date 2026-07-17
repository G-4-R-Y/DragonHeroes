# PROTOTYPE HARNESS — macro ground-tint quad ("procgen stops looking procgen").
# ONE camera-glued multiplicative quad UNDER the water overlay (z=-8, water sits
# at -6): a static 2-octave world-space value noise drifts floor brightness
# +-6% and cools dark patches toward moonlit blue, so the 16-tile atlas
# repetition dissolves into large organic regions. Mounted by world_gen (it
# owns terrain dressing). Pure dressing: nothing reads it back, zero allocation
# after _ready, one draw call. Same camera glue as darkness.gd — the quad
# tracks the view while the shader gets the world rect, so the noise stays
# anchored to the GROUND, never to the screen.
class_name ProtoMacroTint
extends Node2D

const TEX_SIZE := 2.0

var _quad: Sprite2D
var _mat: ShaderMaterial

func _ready() -> void:
	z_as_relative = false
	z_index = -8
	var img := Image.create(int(TEX_SIZE), int(TEX_SIZE), false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	_quad = Sprite2D.new()
	_quad.texture = ImageTexture.create_from_image(img)
	_quad.centered = true
	_quad.texture_filter = TEXTURE_FILTER_LINEAR
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://prototype/shaders/macro_tint.gdshader")
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
