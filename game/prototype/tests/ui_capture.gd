# PROTOTYPE HARNESS — UI screen capture (the capture loop, canon §12.28, for
# menus). Instantiates one UI scene, waits for layout + a few paint frames,
# saves a PNG to tests/captures/, quits. Windowed GL only (no xvfb here).
#   UI_SCENE=res://prototype/ui/main_menu.tscn  (default)
#   UI_TAG=menu                                  (capture filename)
#   UI_WAIT=40                                   (frames before the shot)
# Reusable for any Control-rooted screen; scenes needing session state can be
# pre-seeded here per-tag as they come up.
extends Node

func _ready() -> void:
	if OS.get_environment("UI_LANG") in ["en", "pt"]:
		ProtoLang.set_lang(OS.get_environment("UI_LANG"))
	var scene_path := OS.get_environment("UI_SCENE")
	if scene_path == "":
		scene_path = "res://prototype/ui/main_menu.tscn"
	var tag := OS.get_environment("UI_TAG")
	if tag == "":
		tag = "menu"
	var ps: PackedScene = load(scene_path)
	if ps == null:
		push_error("UI_CAPTURE: cannot load " + scene_path)
		get_tree().quit(1)
		return
	# session-backed screens need a logged-in character (read-only: login loads
	# or claims the slot; nothing here calls save)
	if tag.begins_with("haven") or tag.begins_with("panel") or tag.begins_with("hunt"):
		Session.login("Hunter")
	var screen := ps.instantiate()
	add_child(screen)
	if OS.get_environment("UI_OPTIONS") == "1" and screen.has_method("_open_options"):
		screen._open_options()
	var wait := 40
	if OS.get_environment("UI_WAIT") != "":
		wait = int(OS.get_environment("UI_WAIT"))
	_run(tag, wait)

func _run(tag: String, wait: int) -> void:
	for i in wait:
		await get_tree().process_frame
	# hunt_far: jump the hero N chunks east and let the streamer fill the frame
	# (the v0.2.0 infinite-world verification shot — virgin terrain + minimap)
	if tag.begins_with("hunt_far"):
		var p := get_tree().get_first_node_in_group("player") as Node2D
		if p != null:
			p.global_position += Vector2(6.0 * 64.0 * 16.0, 0.0)
		# a cold 25-chunk teleport needs ~700 frames at the apply budget; normal
		# walking streams the apron incrementally and never sees this
		for i in 800:
			await get_tree().process_frame
	if OS.get_environment("UI_DEBUG_FONTS") == "1":
		print("DBG fallback_font=", ThemeDB.fallback_font,
				" size=", ThemeDB.fallback_font_size)
		var acc: Array = []
		_labels(self, acc)
		for l in acc.slice(0, 6):
			print("DBG label '", (l as Label).text.left(18), "' font=",
					(l as Label).get_theme_font("font"))
	var img := get_viewport().get_texture().get_image()
	var dir := "res://prototype/tests/captures"
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir + "/ui_" + tag + ".png"
	img.save_png(path)
	print("UI_CAPTURE SAVED ", path, " ", img.get_size())
	# Short desktop sample, not a sustained frame-budget assertion. Useful for
	# comparing art passes at identical viewport/renderer/settings.
	var metrics := {"fps": Engine.get_frames_per_second(),
		"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"viewport": [img.get_width(), img.get_height()], "scene": OS.get_environment("UI_SCENE")}
	var report := FileAccess.open(path.trim_suffix(".png") + ".json", FileAccess.WRITE)
	if report != null:
		report.store_string(JSON.stringify(metrics, "  ") + "\n")
	print("UI_CAPTURE METRICS ", JSON.stringify(metrics))
	await get_tree().process_frame
	get_tree().quit(0)

func _labels(n: Node, acc: Array) -> void:
	if n is Label:
		acc.append(n)
	for c in n.get_children():
		_labels(c, acc)
