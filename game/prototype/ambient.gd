# PROTOTYPE HARNESS — ambient life: drifting bioluminescent spores that follow
# the camera, plus a soft vignette. The shipping path is GPU-driven particles with
# explicit budgets (docs/design/17); CPUParticles2D here because the prototype
# renders with gl_compatibility.
class_name ProtoAmbient
extends Node2D

var _spores: CPUParticles2D

func _ready() -> void:
	z_index = 15  # spores drift above the world
	_spores = CPUParticles2D.new()
	_spores.amount = 14
	_spores.lifetime = 6.0
	_spores.preprocess = 6.0
	_spores.local_coords = false
	_spores.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_spores.emission_rect_extents = Vector2(500.0, 300.0)  # ~1.5 screens
	_spores.direction = Vector2(0.2, -1.0)
	_spores.spread = 180.0
	_spores.gravity = Vector2.ZERO
	_spores.initial_velocity_min = 3.0
	_spores.initial_velocity_max = 9.0
	_spores.scale_amount_min = 0.7
	_spores.scale_amount_max = 1.4
	_spores.texture = ProtoSprites.spore_tex()
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.2, 0.8, 1.0])
	ramp.colors = PackedColorArray([
		Color(0.6, 1.0, 0.85, 0.0),
		Color(0.62, 1.0, 0.85, 0.5),
		Color(0.55, 0.95, 1.0, 0.35),
		Color(0.6, 1.0, 0.9, 0.0),
	])
	_spores.color_ramp = ramp
	add_child(_spores)
	_spores.emitting = true

	# vignette — dark corners framing the luminous world
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var v := TextureRect.new()
	v.texture = ProtoSprites.vignette_tex()
	v.stretch_mode = TextureRect.STRETCH_SCALE
	v.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	v.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(v)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(_delta: float) -> void:
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p:
		global_position = p.global_position
