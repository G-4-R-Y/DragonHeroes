## Actual GL distant-travel/return capture with bounded streaming and residency.
extends Node

const DIR := "res://prototype/tests/captures/residency"
var hunt: Node

func frames(n: int) -> void:
	for i in n: await get_tree().process_frame

func settle(center: Vector2i) -> bool:
	for i in 3600:
		await get_tree().process_frame
		var w: ProtoWorld = hunt.world
		if w._player_chunk == center and not w._req_inflight and not w._apply_active and w._jobs.is_empty():
			return true
	return false

func snap(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(DIR.path_join(label + ".png"))
	print("RESIDENCY CAPTURE ", label, " active=", hunt._residency.active_count(),
		" dormant=", hunt._residency.asleep_count)

func _ready() -> void:
	Engine.max_fps = 60
	DirAccess.make_dir_recursive_absolute(DIR)
	Session.login("residency_visual")
	MpNet.pending_seed = 42
	hunt = preload("res://prototype/main.tscn").instantiate()
	add_child(hunt)
	hunt._repop_t = 10000.0
	hunt.player.set_physics_process(false)
	hunt.camera.position_smoothing_enabled = false
	for c in get_tree().get_nodes_in_group("creatures"): c.set_physics_process(false)
	hunt.child_entered_tree.connect(func(c: Node):
		if c is ProtoCreature: c.call_deferred("set_physics_process", false))
	var target: ProtoCreature = get_tree().get_nodes_in_group("creatures")[0]
	var id: int = hunt._residency.identity(target)
	target.hp *= 0.61
	var hp := target.hp
	var return_position := target.global_position + Vector2(0, 40)
	hunt.player.position = return_position
	hunt._build_debug()
	hunt._debug_label.visible = true
	await frames(90)
	await snap("before")
	var far: Vector2i = hunt._chunk_of(return_position) + Vector2i(6, -3)
	hunt.player.position = Vector2(far * 1024 + Vector2i(512, 512))
	if not await settle(far):
		push_error("RESIDENCY CAPTURE stalled on outward journey")
		get_tree().quit(1)
		return
	await frames(150)
	await snap("away")
	var slept: bool = hunt._residency._live(id) == null
	hunt.player.position = return_position
	if not await settle(hunt._chunk_of(return_position)):
		push_error("RESIDENCY CAPTURE stalled on return")
		get_tree().quit(1)
		return
	await frames(180)
	var restored: ProtoCreature = hunt._residency._live(id)
	var good: bool = slept and is_instance_valid(restored) and is_equal_approx(restored.hp, hp)
	await snap("returned")
	await frames(90)  # exclude screenshot readback from the warm sample
	var samples: Array[float] = []
	for i in 300:
		await get_tree().process_frame
		samples.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	samples.sort()
	print("RESIDENCY GL ", "OK" if good else "FAILED", " fps=", Engine.get_frames_per_second(),
		" process_median_ms=", samples[150], " process_p95_ms=", samples[285],
		" adapter_worst_ms=", hunt._residency.worst_step_ms,
		" stream_worst_ms=", hunt.world._worst_apply_ms)
	get_tree().quit(0 if good else 1)
