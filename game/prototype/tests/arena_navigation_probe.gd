## Real Back/Train All clicks, with only child process creation substituted.
extends Node

class ConsoleHarness extends "res://arena/console.gd":
	var dispatched: Array[String] = []
	func _launch_training(command: String) -> int:
		dispatched.append(command)
		return -1   # never run real training from a regression test

var failures: Array[String] = []
func check(ok: bool, why: String) -> void:
	if not ok: failures.append(why)
func frames(n := 3) -> void:
	for i in n: await get_tree().process_frame
func click(button: Button) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = button.get_global_rect().get_center()
		event.global_position = event.position
		Input.parse_input_event(event)
	await frames()
func _ready() -> void:
	call_deferred("run")
func run() -> void:
	ProtoLang.set_lang("en")
	var original := get_window().content_scale_size
	var console := ConsoleHarness.new()
	get_tree().root.add_child(console)
	get_tree().current_scene = console
	get_window().content_scale_size = Vector2i(640, 360)
	await frames(5)
	var back := console.find_child("ArenaBack", true, false) as Button
	var all_button: Button = console._train_all_btn
	var view := Rect2(Vector2.ZERO, Vector2(640, 360))
	check(back != null and view.encloses(back.get_global_rect()), "Back is missing or outside the canvas")
	check(view.encloses(all_button.get_global_rect()), "Train All is outside the canvas")
	console._repo = ProjectSettings.globalize_path("user://arena_navigation_fixture")
	console._runs_root = console._repo.path_join("ml/runs")
	console._gpu.button_pressed = true
	await click(all_button)
	check(console.dispatched.size() == 1, "Train All click did not dispatch once")
	if not console.dispatched.is_empty():
		var command := console.dispatched[0]
		check("--all --run-dir" in command and "tools/train_run.sh" in command,
			"Train All did not use an isolated full-roster run")
		check("--ppo" not in command and "--key" not in command,
			"Train All used the single selected creature/GPU path")
		check("JOBS=4" in command or OS.get_processor_count() < 8, "desktop default consumes every CPU")
	var progress := console._sweep_progress.path_join("fen_boar_alpha.jsonl")
	DirAccess.make_dir_recursive_absolute(progress.get_base_dir())
	var file := FileAccess.open(progress, FileAccess.WRITE)
	file.store_line(JSON.stringify({"event": "start", "key": "fen_boar_alpha"}))
	file.close()
	console._follow_sweep()
	check(console._tail_path == progress, "sweep did not follow its species progress file")
	if DisplayServer.get_name() != "headless":
		await frames(4)
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://prototype/tests/captures/arena")
		get_viewport().get_texture().get_image().save_png("res://prototype/tests/captures/arena/navigation.png")
	await click(back)
	check(get_tree().current_scene.scene_file_path == "res://prototype/ui/main_menu.tscn", "real Back click did not return to title")
	check(get_window().content_scale_size == original, "Arena canvas size leaked into the game")
	for why in failures: push_error("ARENA NAVIGATION FAIL: " + why)
	if failures.is_empty(): print("ARENA NAVIGATION OK — real Back/Train All clicks, isolated sweep, visible actions and canvas restore")
	get_tree().quit(0 if failures.is_empty() else 1)
