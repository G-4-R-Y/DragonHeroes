# PROTOTYPE HARNESS — minimal VFX isolation: fx + darkness + camera on a grey
# floor, fire ONE effect, capture frames. Bisects "which system paints X" when
# the full-game showcase is ambiguous. Windowed GL only.
#   godot --path game res://prototype/tests/vfx_iso.tscn
extends Node2D

var fx: ProtoFx
var darkness: ProtoDarkness
var post: ProtoPost

func _ready() -> void:
	add_to_group("main")
	ProtoFx.intensity = 1.0
	var floor_rect := ColorRect.new()
	floor_rect.color = Color(0.32, 0.34, 0.30)
	floor_rect.position = Vector2(-800, -600)
	floor_rect.size = Vector2(1600, 1200)
	floor_rect.z_index = -10
	add_child(floor_rect)
	fx = ProtoFx.new()
	add_child(fx)
	darkness = ProtoDarkness.new()
	add_child(darkness)
	post = ProtoPost.new()
	add_child(post)
	var cam := Camera2D.new()
	add_child(cam)
	cam.make_current()
	await _run()

func _wait(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame

func _snap(shot: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://prototype/tests/captures/%s.png" % shot)
	print("ISO snap ", shot)

func _run() -> void:
	await _wait(20)
	await _snap("iso_00_empty")
	fx.shader_burst("nova", Vector2.ZERO, {"size": 200.0})
	await _wait(8)
	await _snap("iso_01_nova")
	await _wait(40)
	fx.shockwave(Vector2.ZERO, Color(0.5, 0.8, 1.0), 60.0)
	await _wait(6)
	await _snap("iso_02_shockwave")
	print("ISO DONE")
	get_tree().quit(0)
