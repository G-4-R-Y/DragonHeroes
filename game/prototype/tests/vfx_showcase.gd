# PROTOTYPE HARNESS — VFX showcase capture. Boots the REAL hunt, fires the
# signature moments (burning field, Shadow Rend darkness, nova, cinder pop),
# and saves viewport PNGs to tests/captures/ so the COMPOSITED look (world +
# lighting + rims + shaders + post, all together) can be reviewed frame by
# frame against the reference games — lab contact sheets validate effects in
# isolation; this validates the frame the player actually sees.
# Run WINDOWED on GL (never Vulkan):
#   godot --path game res://prototype/tests/vfx_showcase.tscn
# Self-quits. NOT part of headless CI (needs a real backbuffer to read).
extends Node

const DIR := "res://prototype/tests/captures"

func _ready() -> void:
	await _run()

func _wait(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame

func _snap(shot: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [DIR, shot])
	print("SHOWCASE snap ", shot)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	await _wait(40)                       # world settled, packs roaming
	var main := get_tree().get_first_node_in_group("main")
	var player := get_tree().get_first_node_in_group("player")
	if main == null or player == null:
		print("SHOWCASE FAIL: no main/player")
		get_tree().quit(1)
		return
	# relocate away from whatever aggroed at spawn (a legendary camping the
	# start point photobombs every skill shot with its own giant telegraphs)
	player.global_position += Vector2(520, 300)
	if main.get("camera") != null:
		main.camera.reset_smoothing()
	await _wait(20)
	var p: Vector2 = player.global_position
	await _snap("01_world")
	# burning ground: must read as FIRE + ground light + heat shimmer
	main.spawn_field(p + Vector2(70, 10), 40.0, 9.0, 8.0, "fire")
	await _wait(30)
	await _snap("02_firefield")
	await _wait(45)
	await _snap("03_firefield_burning")
	# the darkness aura
	if OS.get_environment("SHOWCASE_NULL") != "1" and player.has_method("_shadow_rend"):
		player._shadow_rend(main)
	await _wait(10)
	await _snap("04_shadow_rend")
	await _wait(18)
	await _snap("05_shadow_rend_late")
	# frost nova + cinder pop (composite skill reads)
	if OS.get_environment("SHOWCASE_NULL") != "1":
		main.fx.shader_burst("nova", p + Vector2(-60, 0), {"size": 200.0})
		main.fx.shockwave(p + Vector2(-60, 0), Color(0.5, 0.8, 1.0), 60.0)
	await _wait(8)
	await _snap("06_nova")
	main.fx.shader_burst("firestorm", p + Vector2(40, -30), {"size": 110.0})
	main.fx.shader_burst("impact", p + Vector2(40, -30),
			{"size": 44.0, "color": Color(1.0, 0.75, 0.4)})
	main.post.haze(p + Vector2(40, -30), 50.0, 2.6, 0.7)
	await _wait(9)
	await _snap("07_cinder")
	await _wait(30)
	await _snap("08_settle")
	print("SHOWCASE DONE")
	get_tree().quit(0)
