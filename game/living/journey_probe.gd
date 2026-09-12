# Dormant exported outcome gate. Exercises real input and native victories.
extends Node
var captures := false
var deadline := 0

func _ready() -> void:
	if "--lairs-selftest" in OS.get_cmdline_user_args():
		captures = "--lairs-capture" in OS.get_cmdline_user_args()
		_run.call_deferred()

func frames(count: int) -> void:
	for i in range(count): await get_tree().process_frame

func check(condition: bool, message: String) -> bool:
	if not condition:
		push_error("LAIR PLAYTEST FAIL: " + message)
		get_tree().quit(1)
	return condition

func capture(name: String) -> void:
	if not captures: return
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://lair-"+name+".png")

func victory(trial: Node) -> bool:
	deadline = Time.get_ticks_msec()+55000
	while Time.get_ticks_msec()<deadline:
		await get_tree().process_frame
		if trial._connected and trial._state[3] > 0:
			return check(trial._state[3] == 1 and trial._state[445] == 0, "guardian victory must save its reward")
	return check(false, "encounter timed out")

func _run() -> void:
	LairJourney.explore()
	await frames(15)
	var world := get_tree().current_scene
	if not check(world.get("world") != null, "exploration scene did not open"): return
	var portals: Node = null
	for child in world.get_children():
		if child.get_script() == load("res://living/world_lairs.gd"): portals = child
	if not check(portals != null and not portals.entries.is_empty(), "native world must contain a doorway"): return
	var position: Vector2 = world.player.global_position
	var seed: int = world.world._hunt_seed
	await capture("entrance")
	var event := InputEventKey.new()
	event.physical_keycode = KEY_G
	event.pressed = true
	portals._unhandled_key_input(event)
	await frames(15)
	if not check(is_instance_valid(LairJourney.overlay), "G at the doorway must enter its lair"): return
	var trial: Node = LairJourney.overlay.get_child(0)
	if not check(world.process_mode == Node.PROCESS_MODE_DISABLED, "Hunt must pause inside a lair"): return
	print("LAIR PLAYTEST: discovered entrance, playing guardian with earned equipment")
	if not await victory(trial): return
	if not check(trial._state[450] == 1 and trial._state[446] == 1 and trial._state[444] == 1, "first kill must grant an item and unlock guardian"): return
	await capture("victory")
	trial._menu()
	await frames(10)
	if not check(get_tree().current_scene == world and world.player.global_position.distance_to(position) < 2 and world.world._hunt_seed == seed, "return must preserve the exact Hunt"): return
	var draw_us: int = portals.max_draw_us
	get_tree().change_scene_to_file("res://living/lair_menu.tscn")
	await frames(10)
	var saved := LairJourney.collection()
	if not check(saved.get("items", [0])[0] == 1, "collection must survive helper restart"): return
	await capture("collection")
	LairJourney.rush(str(LairJourney.data().playable.lairs[0].id))
	await frames(15)
	trial = get_tree().current_scene
	print("LAIR PLAYTEST: returned to same Hunt; collection persisted; playing unlocked boss rush")
	if not await victory(trial): return
	if not check(trial._state[451] == 1 and trial._state[447] == 1, "rush must earn the next artifact"): return
	await capture("rush")
	trial._next_button.pressed.emit()
	deadline = Time.get_ticks_msec()+3000
	while trial._state[441] < 2 and Time.get_ticks_msec() < deadline: await get_tree().process_frame
	if not check(trial._state[441] == 2 and trial._state[3] == 0, "continue must start a fresh scaled rush round"): return
	var report := {"passed": true, "seed": seed, "entrances": portals.entries.size() if is_instance_valid(portals) else 1,
		"lair_unlocks": 1, "earned_artifacts": 2, "rush_round": trial._state[441], "world_return_preserved": true,
		"entrance_draw_us": draw_us, "fps": Engine.get_frames_per_second(),
		"frame_cpu_ms": Performance.get_monitor(Performance.TIME_PROCESS)*1000.0,
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}
	var file := FileAccess.open("user://lair-smoke.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report))
	file.close()
	print("LAIR PLAYTEST OK ", report)
	get_tree().quit()
