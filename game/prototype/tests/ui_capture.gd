# PROTOTYPE HARNESS — UI screen capture (the capture loop, canon §12.28, for
# menus). Instantiates one UI scene, waits for layout + a few paint frames,
# saves a PNG to tests/captures/, quits. Windowed GL only (no xvfb here).
#   UI_SCENE=res://prototype/ui/main_menu.tscn  (default)
#   UI_TAG=menu                                  (capture filename)
#   UI_WAIT=40                                   (frames before the shot)
#   UI_TAB=VERSUS                                (select a tab before shooting)
#   UI_TAG=cue...                                (R64: stage the cooldown cues)
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
	if tag.begins_with("cue"):
		_seed_cue()
	var screen := ps.instantiate()
	add_child(screen)
	if OS.get_environment("UI_OPTIONS") == "1" and screen.has_method("_open_options"):
		screen._open_options()
	var wait := 40
	if OS.get_environment("UI_WAIT") != "":
		wait = int(OS.get_environment("UI_WAIT"))
	# UI_TAB picks a tab by its title before the shot. Added for R60: the arena
	# console keeps five tabs and only the front one was ever captured, so a
	# caption that collapsed on RUNS or VERSUS could never show up in a
	# screenshot. Any tabbed screen gets this for free.
	if OS.get_environment("UI_TAB") != "":
		_select_tab(screen, OS.get_environment("UI_TAB"))
	_run(tag, wait)

# R64 capture: a throwaway hunter carrying four DIFFERENT skill kinds, so one
# frame shows four tints on the feet fan and on the HUD chips at once. Never
# "Hunter": learn_node/assign_skill write a save, and a capture must not edit a
# player's character.
const CUE_KIT := ["rv_gash", "rv_hurled_cleaver", "rv_artery_storm", "rv_earthsplitter"]

func _seed_cue() -> void:
	Session.login("cue_capture")
	Session.class_id = "core.class.reaver"
	Session.skill_points = maxi(Session.skill_points, CUE_KIT.size())
	for i in CUE_KIT.size():
		Session.learn_node(str(CUE_KIT[i]), 1)
		Session.assign_skill(i, str(CUE_KIT[i]))

# Depth-first for the first TabContainer holding a tab with this title.
func _select_tab(root: Node, title: String) -> bool:
	if root is TabContainer:
		var tc: TabContainer = root
		for i in tc.get_tab_count():
			if tc.get_tab_title(i) == title:
				tc.current_tab = i
				return true
	for child in root.get_children():
		if _select_tab(child, title):
			return true
	return false

func _run(tag: String, wait: int) -> void:
	var cue_player: Node2D = null
	for i in wait:
		await get_tree().process_frame
	if tag.begins_with("cue"):
		cue_player = await _stage_cue()
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
	if cue_player != null:
		# 640x360 of canvas is too small to read a 13 px fan or a 26 px chip, so
		# the shot also lands as two nearest-neighbour insets at 4x the LOGICAL
		# pixel: the cue at the hero's feet, and the hotbar it must agree with.
		# Canvas coordinates are in viewport space; the saved frame is the
		# window, so every rect crosses by the integer stretch factor first.
		var k := float(img.get_width()) / get_viewport().get_visible_rect().size.x
		var feet: Rect2 = Rect2(cue_player.get_global_transform_with_canvas().origin
				- Vector2(40, 34), Vector2(80, 68))
		_inset(img, feet, dir + "/ui_" + tag + "_feet.png", k)
		var chips: Array = []
		_chips(self, chips)
		if not chips.is_empty():
			var box: Rect2 = (chips[0] as Control).get_global_rect()
			for c in chips:
				box = box.merge((c as Control).get_global_rect())
			_inset(img, box.grow(6.0), dir + "/ui_" + tag + "_hotbar.png", k)
	# Short desktop sample, not a sustained frame-budget assertion. Useful for
	# comparing art passes at identical viewport/renderer/settings.
	var metrics := {"fps": Engine.get_frames_per_second(),
		"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"viewport": [img.get_width(), img.get_height()], "scene": OS.get_environment("UI_SCENE")}
	if cue_player != null:
		metrics["cue_arcs"] = cue_player.cue_arcs   # R64 budget: at most 12
	var report := FileAccess.open(path.trim_suffix(".png") + ".json", FileAccess.WRITE)
	if report != null:
		report.store_string(JSON.stringify(metrics, "  ") + "\n")
	print("UI_CAPTURE METRICS ", JSON.stringify(metrics))
	await get_tree().process_frame
	get_tree().quit(0)

# Four slots, four states, one frame: slot 1 deep in cooldown, slot 2 nearly
# back AND freshly denied, slot 3 caught inside its 0.35 s ready bloom, slot 4
# calm and ready. Every state is driven through the SHIPPING path - real seconds
# on the player's cooldowns and a real press on slot 2 - so the capture shows
# the game's own arcs, never a posed drawing.
func _stage_cue() -> Node2D:
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p == null:
		push_error("UI_CAPTURE: the cue tag found no player")
		return null
	p.skill_cds[CUE_KIT[0]] = 3.1     # melee_arc: most of the segment still dark
	p.skill_cds[CUE_KIT[1]] = 1.2     # projectile: nearly whole again
	p.skill_cds[CUE_KIT[2]] = 0.05    # nova: expires within a tick -> a REAL edge
	p.skill_cds[CUE_KIT[3]] = 0.0     # field: the calm, motionless ready arc
	var guard := 0
	while p.skill_ready_flash(2) <= 0.0 and guard < 240:
		guard += 1
		await get_tree().process_frame
	Input.action_press("slot2")       # a press the 0.15 s buffer cannot save
	await get_tree().physics_frame
	Input.action_release("slot2")
	for i in 3:                       # bloom (0.35 s) and deny (0.25 s) both alive
		await get_tree().process_frame
	print("UI_CAPTURE CUE flash=", p.skill_ready_flash(2), " deny=",
			p.skill_deny_flash(1), " arcs=", p.cue_arcs)
	return p

# A crop of the saved frame at 4x the logical pixel - pixel art must be
# magnified by WHOLE pixels or the capture lies about what the renderer drew.
# box is in canvas coordinates; k is the window's integer stretch factor.
func _inset(img: Image, box: Rect2, out_path: String, k := 1.0) -> void:
	var scaled := Rect2(box.position * k, box.size * k)
	var clip := Rect2i(scaled).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	if clip.size.x <= 0 or clip.size.y <= 0:
		return
	var zoom := maxi(1, int(round(4.0 / k)))
	var cut := img.get_region(clip)
	cut.resize(clip.size.x * zoom, clip.size.y * zoom, Image.INTERPOLATE_NEAREST)
	cut.save_png(out_path)
	print("UI_CAPTURE SAVED ", out_path, " ", cut.get_size())

func _chips(n: Node, acc: Array) -> void:
	if n is HudSkillChip:
		acc.append(n)
	for c in n.get_children():
		_chips(c, acc)

func _labels(n: Node, acc: Array) -> void:
	if n is Label:
		acc.append(n)
	for c in n.get_children():
		_labels(c, acc)
