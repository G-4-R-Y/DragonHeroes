# PROTOTYPE HARNESS — UI screen capture (the capture loop, canon §12.28, for
# menus). Instantiates one UI scene, waits for layout + a few paint frames,
# saves a PNG to tests/captures/, quits. Windowed GL only (no xvfb here).
#   UI_SCENE=res://prototype/ui/main_menu.tscn  (default)
#   UI_TAG=menu                                  (capture filename)
# Reusable for any Control-rooted screen; scenes needing session state can be
# pre-seeded here per-tag as they come up.
extends Node

func _ready() -> void:
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
	if tag.begins_with("haven") or tag.begins_with("panel"):
		Session.login("Hunter")
	add_child(ps.instantiate())
	_run(tag)

func _run(tag: String) -> void:
	for i in 40:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	var dir := "res://prototype/tests/captures"
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir + "/ui_" + tag + ".png"
	img.save_png(path)
	print("UI_CAPTURE SAVED ", path, " ", img.get_size())
	await get_tree().process_frame
	get_tree().quit(0)
