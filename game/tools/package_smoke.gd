# Explicit outcome probe for exported Codex review packages. Release templates
# disable external --script overrides; this runs only with -- --codex-smoke.
extends Node

func _ready() -> void:
	if "--codex-smoke" in OS.get_cmdline_user_args():
		call_deferred("_run")

func _verdict(ok: bool, detail: String) -> bool:
	var file := FileAccess.open("user://package-smoke.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"passed": ok, "detail": detail}))
		file.close()
	print(("PACKAGE SMOKE OK: " if ok else "PACKAGE SMOKE FAIL: ") + detail)
	get_tree().quit(0 if ok else 1)
	return ok

func _run() -> void:
	var tree := get_tree()
	for frame in range(20):
		await tree.process_frame
	if OS.get_user_data_dir().get_file() != "Dragon Heroes Codex":
		_verdict(false, "save isolation")
		return
	var icon: Texture2D = load("res://branding/dragon-heroes.png")
	if icon == null or icon.get_width() != 512 or not FileAccess.file_exists("res://branding/dragon-heroes.ico"):
		_verdict(false, "packaged application icons")
		return
	var menu: Node = tree.current_scene
	var texts := ""
	for button in menu.find_children("*", "Button", true, false):
		texts += " " + str(button.text).to_upper()
	if not ("ENTER" in texts and "CO-OP" in texts and "OPTIONS" in texts):
		_verdict(false, "menu did not finish building")
		return
	if tree.change_scene_to_file("res://prototype/main.tscn") != OK:
		_verdict(false, "Hunt scene unavailable")
		return
	await tree.create_timer(8.0).timeout
	var player: Node = tree.get_first_node_in_group("player")
	var world: Node = tree.get_first_node_in_group("world")
	var creatures := tree.get_nodes_in_group("creatures")
	if player == null or world == null or creatures.size() < 20:
		_verdict(false, "Hunt did not populate")
		return
	if not bool(world.get("_streaming")):
		_verdict(false, "packaged C++ helper did not generate streaming world")
		return
	_verdict(true, "exported menu, icons, isolated saves, streaming Hunt; creatures=%d" % creatures.size())
