## Explicit GL benchmark for the actual client; dormant during normal play.
## Assisted combat keeps the hunter alive, with ordinary AI, attacks and VFX.
extends Node

func _ready() -> void:
	if "--codex-profile" in OS.get_cmdline_user_args(): call_deferred("run")

func percentile(values: Array[float], fraction: float) -> float:
	var ordered := values.duplicate()
	ordered.sort()
	return ordered[clampi(ceili(ordered.size() * fraction) - 1, 0, ordered.size() - 1)]

func drive(hunt: Node, delta: float) -> void:
	var p: ProtoPlayer = hunt.player
	p.hp = p.max_hp
	p.bot_drive = true
	var target: Node2D
	var nearest := INF
	for creature in get_tree().get_nodes_in_group("creatures"):
		if creature.dead: continue
		var distance: float = p.global_position.distance_squared_to(creature.global_position)
		if distance < nearest:
			nearest = distance
			target = creature
	if target != null:
		p.bot_aim = target.global_position
		p._bot_step = (target.global_position - p.global_position).normalized() * p.move_speed * delta if nearest > 500.0 else Vector2.ZERO
		if p._attack_cd <= 0.0: p._attack()
		if p._whirl_cd <= 0.0: p._whirlwind()

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("CLIENT PROFILE needs a real GL window")
		get_tree().quit(1)
		return
	var seconds := 12
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--profile-seconds="): seconds = clampi(arg.get_slice("=", 1).to_int(), 5, 60)
	Engine.max_fps = 60
	seed(42)
	Session.login("performance_%d" % Time.get_ticks_usec())
	MpNet.pending_seed = 42
	get_tree().change_scene_to_file("res://prototype/main.tscn")
	# Scene changes finish deferred; one process_frame may precede the swap.
	for frame in 300:
		await get_tree().process_frame
		if get_tree().current_scene != null and get_tree().current_scene.scene_file_path == "res://prototype/main.tscn": break
	var hunt: Node = get_tree().current_scene
	if hunt == null or hunt.get("player") == null:
		push_error("CLIENT PROFILE Hunt failed to initialize")
		get_tree().quit(1)
		return
	for i in 180:
		drive(hunt, 1.0 / 60.0)
		await get_tree().process_frame
	var intervals: Array[float] = []
	var process: Array[float] = []
	var physics: Array[float] = []
	var peak_draws := 0
	var peak_creatures := 0
	var start := Time.get_ticks_usec()
	var previous := start
	while Time.get_ticks_usec() - start < seconds * 1000000:
		drive(hunt, 1.0 / 60.0)
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		intervals.append((now - previous) / 1000.0)
		previous = now
		process.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		peak_draws = maxi(peak_draws, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		peak_creatures = maxi(peak_creatures, get_tree().get_nodes_in_group("creatures").size())
	var result := {"schema": "client.profile.v1", "scenario": "assisted Hunt combat, seed 42", "fps_cap": Engine.max_fps,
		"frames": intervals.size(), "wall_seconds": (previous - start) / 1000000.0,
		"average_fps": intervals.size() * 1000000.0 / (previous - start),
		"interval_median_ms": percentile(intervals, 0.5), "interval_p95_ms": percentile(intervals, 0.95),
		"interval_p99_ms": percentile(intervals, 0.99), "interval_max_ms": intervals.max(),
		"process_p95_ms": percentile(process, 0.95), "physics_p95_ms": percentile(physics, 0.95),
		"peak_draw_calls": peak_draws, "peak_creatures": peak_creatures,
		"stream_worst_ms": hunt.world._worst_apply_ms, "renderer": RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(), "engine": Engine.get_version_info().string}
	var file := FileAccess.open("user://client-profile.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	print("CLIENT PROFILE ", JSON.stringify(result))
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://client-profile.png")
	get_tree().quit()
