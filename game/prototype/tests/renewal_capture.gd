## Actual GL frames of the renewal slice; never run this with Vulkan.
extends Node

const DIR := "res://prototype/tests/captures/renewal"

func wait_frames(n: int) -> void:
	for i in n: await get_tree().process_frame

func snap(tag: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(DIR + "/" + tag + ".png")
	print("RENEWAL CAPTURE ", tag, " fps=", Engine.get_frames_per_second(),
		" process_ms=", snappedf(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, 0.001),
		" draws=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))

func measure(hunt: Node) -> void:
	var samples: Array[float] = []
	var cpu: Array[float] = []
	var previous := Time.get_ticks_usec()
	for i in 300:
		if i % 30 == 0: hunt.player._attack()
		if i % 90 == 0:
			hunt.player.skill_cds.clear()
			hunt.player.use_skill(Session.skill_def("rv_gash"))
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		samples.append((now - previous) / 1000.0)
		cpu.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		previous = now
	samples.sort()
	cpu.sort()
	print("RENEWAL STEADY frames=300 fps=", Engine.get_frames_per_second(),
		" frame_median_ms=", samples[150], " frame_p95_ms=", samples[285],
		" process_median_ms=", cpu[150], " process_p95_ms=", cpu[285])

func _ready() -> void:
	Engine.max_fps = 60
	DirAccess.make_dir_recursive_absolute(DIR)
	ProtoLang.set_lang("en")
	Session.player_name = "Ari"
	Session.stables = [{"uid": 601, "name": "Gloam Stalker", "nickname": "Moonfang", "species": "core.creature.gloamfen_stalker", "roll_pct": 104, "skills": ["core.skill.shadow_rend", "core.skill.abyssal_howl"]}]
	Session.mounts = [{"uid": 602, "name": "Emberwing Drakeling", "kind": "fly", "speed_mult": 1.9, "rarity": "legendary"}]
	Session.active_mount = 602
	var haven := preload("res://prototype/ui/haven.tscn").instantiate()
	add_child(haven)
	haven._show_pets()
	await wait_frames(90)
	await snap("stables")
	haven._char_panel.visible = true
	haven._char_panel._refresh_mounts()
	var tabs: TabContainer = haven._char_panel.find_children("*", "TabContainer", true, false)[0]
	tabs.current_tab = 5
	await wait_frames(12)
	await snap("mounts")
	haven.queue_free()
	await wait_frames(2)
	var menu := preload("res://prototype/ui/main_menu.tscn").instantiate()
	add_child(menu)
	menu._open_options()
	await wait_frames(12)
	await snap("options")
	menu.queue_free()
	await wait_frames(2)
	var hunt := preload("res://prototype/main.tscn").instantiate()
	add_child(hunt)
	await wait_frames(120)
	for c in get_tree().get_nodes_in_group("creatures"):
		c.set_physics_process(false)
		if c.global_position.distance_to(hunt.player.global_position) < 300:
			c.global_position += Vector2(420, 0)
	hunt.player.hp = hunt.player.max_hp * 0.65
	hunt.refresh_hud()
	await wait_frames(10)
	await snap("hunt_luminous")
	ProtoDisplay.set_visibility(0.0)
	await wait_frames(10)
	await snap("hunt_moody")
	ProtoDisplay.set_visibility(0.6)
	hunt.player.bot_drive = true
	hunt.player.bot_aim = hunt.player.global_position + Vector2(100, -50)
	# Warm the material variants before taking action frames. Readback and first
	# shader compilation are not steady-state frame-budget measurements.
	hunt.player._attack()
	hunt.player.use_skill(Session.skill_def("rv_gash"))
	hunt.player._cast_bolt()
	await wait_frames(90)
	await measure(hunt)
	hunt.player._attack()
	await wait_frames(2)
	await snap("attack")
	await wait_frames(60)
	hunt.player.skill_cds.clear()
	hunt.player.use_skill(Session.skill_def("rv_gash"))
	await wait_frames(2)
	await snap("heavy")
	await wait_frames(60)
	hunt.player._cast_bolt()
	await wait_frames(2)
	await snap("cast")
	hunt.queue_free()
	await wait_frames(3)
	print("RENEWAL CAPTURES OK")
	get_tree().quit()
