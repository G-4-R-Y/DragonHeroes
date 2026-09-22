# Navigation/presentation only. The native helper owns collection and unlocks.
extends Node
var mode_name := "practice"
var lair_id := ""
var entrance_chunk := ""
var seed := 42
var tour := false
var world: Node
var overlay: CanvasLayer
var old_process_mode := Node.PROCESS_MODE_INHERIT
var chapter: Dictionary = {}

func data() -> Dictionary:
	if chapter.is_empty():
		chapter = JSON.parse_string(FileAccess.get_file_as_string("res://living/generated/chapter.json"))
	return chapter

func helper() -> String:
	if OS.has_feature("editor"):
		return ProjectSettings.globalize_path("res://../sim/build/libs/dh-server/dh-server")
	return OS.get_executable_path().get_base_dir().path_join("dh-server.exe" if OS.has_feature("windows") else "dh-server")

func profile() -> String:
	return ProjectSettings.globalize_path("user://lair-collection-v1.txt")

func collection() -> Dictionary:
	var output: Array = []
	if not FileAccess.file_exists(helper()):
		return {"error": ProtoLang.t("lm_no_helper")}
	var code := OS.execute(helper(), ["--lair-profile", profile()], output)
	var result = JSON.parse_string("".join(output))
	if result is Dictionary:
		return result
	return {"error": ProtoLang.t("lm_unreadable") % code}

func practice() -> void:
	mode_name = "practice"
	lair_id = str(data().playable.lairs[0].id)
	get_tree().change_scene_to_file("res://living/trial.tscn")

func rush(id: String) -> void:
	mode_name = "rush"
	lair_id = id
	get_tree().change_scene_to_file("res://living/trial.tscn")

func explore() -> void:
	tour = true
	Session.login("Lair Explorer")
	get_tree().change_scene_to_file("res://prototype/main.tscn")

func enter(source: Node, entrance: Dictionary) -> void:
	if is_instance_valid(overlay) or MpNet.in_game:
		return
	mode_name = "lair"
	lair_id = str(entrance.id)
	entrance_chunk = "%d,%d" % [entrance.chunk.x, entrance.chunk.y]
	seed = source.world._hunt_seed
	world = source
	old_process_mode = world.process_mode
	world.process_mode = Node.PROCESS_MODE_DISABLED
	# Keep the exact Hunt alive and paused. A separate canvas covers it, preserving
	# player position, packs, terrain and streaming state on the return journey.
	# load() can return null — a damaged install, or (Ricardo, 2026-09-14) the
	# build directory being replaced under a RUNNING game, which unlinks the
	# process's cwd and takes Godot's whole DirAccess layer with it. Calling
	# .instantiate() on that null took the game down at the doorway. Fail the
	# entry instead: the Hunt is restored and the player keeps playing.
	var packed: PackedScene = load("res://living/trial.tscn") as PackedScene
	var trial: Node = packed.instantiate() if packed != null else null
	if trial == null:
		push_error("LAIR: res://living/trial.tscn could not be loaded — the "
				+ "lair cannot open. If the game was updated while running, "
				+ "restart it.")
		world.process_mode = old_process_mode
		world = null
		return
	overlay = CanvasLayer.new()
	overlay.layer = 100
	get_tree().root.add_child(overlay)
	overlay.add_child(trial)

func leave() -> void:
	if is_instance_valid(world) and is_instance_valid(overlay):
		world.process_mode = old_process_mode
		overlay.queue_free()
		overlay = null
		world = null
	else:
		get_tree().change_scene_to_file("res://living/lair_menu.tscn")
