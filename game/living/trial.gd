# Presentation/input only. The adjacent dh-server owns the 30 Hz trial simulation.
extends Node2D

const EXPECTED_FLOATS := 452
const GOLD := Color("d8b875")
const TEAL := Color("7ed4ba")
const RARITIES := ["LEGENDARY", "RELIC", "MYTHIC", "DIVINE"]
const COLORS := [Color("efcf95"), Color("7ed4ba"), Color("c4a4ef"), Color("f4e8c1")]
const EFFECT_KIND_ACTION := {1: "echo", 2: "chain", 3: "resource", 4: "ward"}
var _peer := PacketPeerUDP.new()
var _pid := -1
var _port := 0
var _token := 0
var _sequence := 0
var _last_snapshot := 0
var _state := PackedFloat32Array()
var _previous := PackedFloat32Array()
var _age := 0.0
var _send_time := 0.0
var _elapsed := 0.0
var _last_received := 0.0
var _artifact := 3
var _extra_buttons := 0
var _pending_buttons := 0
var _pending_sequence := 0
var _lore_open := false
var _paused_focus := false
var _chapter: Dictionary
var _artifacts: Array = []
var _atlas: Dictionary
var _albedo: Texture2D
var _emissive: Texture2D
var _hero: Texture2D
var _wisp: Texture2D
var _shrine: Texture2D
var _wisp_data: Dictionary
var _small: Font
var _big: Font
var _status: Label
var _feedback: Label
var _lore_panel: PanelContainer
var _lore_text: RichTextLabel
var _artifact_buttons: Array[Button] = []
var _cast_buttons: Array[Button] = []
var _connected := false
var _test_frames := 0
var _test_mode := false
var _captures := false
var _seen := 0
var _max_draw_us := 0
var _effect_colors := {}
var _skills := {}
var _creature: Dictionary
var _lair_index := -1
var _next_button: Button
var _exit_button: Button

func _ready() -> void:
	_small = load(ProtoTheme.FONT_SMALL_PATH)
	_big = load(ProtoTheme.FONT_BIG_PATH)
	_chapter = JSON.parse_string(FileAccess.get_file_as_string("res://living/generated/chapter.json"))
	for effect in _chapter.release.effects:
		_effect_colors[effect.action] = Color(effect.vfx.color)
	for skill in _chapter.release.skills:
		_skills[skill.id] = skill
	for creature in _chapter.release.creatures:
		if creature.id == _chapter.playable.lairs[0].creature: _creature = creature
	_atlas = JSON.parse_string(FileAccess.get_file_as_string("res://living/generated/atlas.json"))
	_albedo = load("res://living/generated/albedo.png")
	_emissive = load("res://living/generated/emissive.png")
	_hero = load("res://prototype/art/hero/sheet.png")
	_wisp = load("res://prototype/art/gloamfen_wisp/sheet.png")
	_shrine = load("res://living/shrine.png")
	_wisp_data = JSON.parse_string(FileAccess.get_file_as_string("res://prototype/art/gloamfen_wisp/atlas.json"))
	for rarity in ["legendary", "relic", "mythic", "divine"]:
		for artifact in _chapter.release.artifacts:
			if artifact.rarity == rarity:
				_artifacts.append(artifact)
	_test_mode = "--living-selftest" in OS.get_cmdline_user_args()
	_captures = "--living-capture" in OS.get_cmdline_user_args()
	_build_ui()
	_start_host()

func _start_host() -> void:
	if _peer.bind(0, "127.0.0.1") != OK:
		_status.text = "Could not open the local trial connection. ESC returns to menu."
		return
	_token = int(randi() & 0x7fffffff) + 1
	var helper := ProjectSettings.globalize_path("res://../sim/build/libs/dh-server/dh-server")
	if not OS.has_feature("editor"):
		helper = OS.get_executable_path().get_base_dir().path_join("dh-server.exe" if OS.has_feature("windows") else "dh-server")
	if not FileAccess.file_exists(helper):
		_status.text = "Trial helper missing. Keep dh-server beside the game. ESC: menu."
		return
	if LairJourney.lair_id.is_empty():
		LairJourney.lair_id = str(_chapter.playable.lairs[0].id)
	var args := ["--living-preview", "--client-port", str(_peer.get_local_port()), "--token", str(_token),
		"--mode", LairJourney.mode_name, "--lair", LairJourney.lair_id, "--profile", LairJourney.profile(),
		"--seed", str(LairJourney.seed), "--entrance-chunk", LairJourney.entrance_chunk]
	_pid = OS.create_process(helper, args)
	if _pid < 0:
		_status.text = "Trial could not start. Check executable permissions. ESC: menu."

func _exit_tree() -> void:
	if _port > 0:
		_send(256)
	_peer.close()
	if _pid > 0 and OS.is_process_running(_pid):
		OS.kill(_pid)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_paused_focus = true
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_paused_focus = false

func _build_ui() -> void:
	var ui := CanvasLayer.new()
	ui.layer = 101
	add_child(ui)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = ProtoTheme.get_theme()
	ui.add_child(root)
	_status = Label.new()
	_status.position = Vector2(16, 33)
	_status.add_theme_font_size_override("font_size", ProtoTheme.SIZE_BODY)
	_status.text = "Opening the bell shrine..."
	root.add_child(_status)
	_button(root, "LORE [L]", Vector2(452, 9), Vector2(74, 20), _toggle_lore)
	_exit_button = _button(root, "RETURN [ESC]", Vector2(534, 9), Vector2(96, 20), _menu)
	_next_button = _button(root, "CONTINUE [ENTER]", Vector2(225, 202), Vector2(190, 23), func() -> void: _extra_buttons |= 512)
	_next_button.hide()
	for i in range(4):
		var pick := i
		var button := _button(root, "%d  %s" % [i + 1, RARITIES[i]], Vector2(10+i*157, 286), Vector2(150, 21), func() -> void:
			_artifact = pick
			_refresh_lore())
		button.tooltip_text = _artifacts[i].name + "\n" + _artifacts[i].signature
		_artifact_buttons.append(button)
	_feedback = Label.new()
	_feedback.position = Vector2(12, 309)
	_feedback.add_theme_font_size_override("font_size", ProtoTheme.SIZE_BODY)
	root.add_child(_feedback)
	var labels := ["LMB / SPACE  CUT", "SHIFT  REED STEP", "Q  MIRE CHIME", "E  STORM TOLL", "R  COMPANION"]
	var bits := [1, 2, 4, 8, 16]
	for i in range(5):
		var bit: int = bits[i]
		var cast := _button(root, labels[i], Vector2(8+i*126, 332), Vector2(122, 20), func() -> void: _extra_buttons |= bit)
		_cast_buttons.append(cast)
	_lore_panel = PanelContainer.new()
	_lore_panel.position = Vector2(52, 48)
	_lore_panel.size = Vector2(536, 225)
	root.add_child(_lore_panel)
	_lore_text = RichTextLabel.new()
	_lore_text.custom_minimum_size = Vector2(510, 205)
	_lore_text.bbcode_enabled = false
	_lore_text.add_theme_font_size_override("normal_font_size", ProtoTheme.SIZE_BODY)
	_lore_panel.add_child(_lore_text)
	_lore_panel.hide()
	_refresh_lore()

func _button(parent: Node, text: String, pos: Vector2, bounds: Vector2, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = pos
	button.size = bounds
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", ProtoTheme.SIZE_BODY)
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _refresh_lore() -> void:
	if _artifacts.is_empty():
		return
	var item: Dictionary = _artifacts[_artifact]
	var story := ""
	for lore in _chapter.release.lore:
		if lore.id == item.lore:
			story = lore.story + "\n\nDISCOVERY\n" + lore.discovery
	var boss_story := ""
	for lore in _chapter.release.lore:
		if lore.id == _creature.lore: boss_story = lore.story
	_lore_text.text = "%s — %s\n\n%s\n\n%s\n\n%s\n\nCLASS CONNECTIONS: %s\n\n%s\n%s\n\nTrial controls: WASD move, aim with mouse, LMB/Space cut, Shift/RMB dodge, Q Wet field, E Storm, R companion. Q then E spends Wet for chains on Mythic/Divine; R grants the Divine ward. ENTER restarts; F bonds the guardian after victory.\n\nThe new sprite currently has an idle loop. Footwork and attacks use motion and telegraphs while action animation awaits review. Scroll to read; L closes and resumes." % [
		item.name, RARITIES[_artifact], item.signature, item.tradeoff, story, ", ".join(item.class_hooks), str(_creature.name).to_upper(), boss_story]

func _toggle_lore() -> void:
	_lore_open = not _lore_open
	_lore_panel.visible = _lore_open
	_refresh_lore()

func _menu() -> void:
	LairJourney.leave()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: int = event.physical_keycode
	if key == KEY_ESCAPE:
		_menu()
	elif key == KEY_L:
		_toggle_lore()
	elif key >= KEY_1 and key <= KEY_4:
		_artifact = key - KEY_1
		_refresh_lore()
	elif key == KEY_ENTER:
		_extra_buttons |= 512 if _connected and _state[3] == 1 else 32
	elif key == KEY_F:
		_extra_buttons |= 128

func _send(button_override := -1) -> void:
	if _port == 0:
		return
	var movement := Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
	var aim := get_global_mouse_position().clamp(Vector2.ZERO, Vector2(640, 360))
	if (_extra_buttons & (32 | 128 | 512)) != 0:
		_pending_buttons |= _extra_buttons & (32 | 128 | 512)
		_pending_sequence = 0
	var buttons := _extra_buttons | _pending_buttons
	_extra_buttons = 0
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_physical_key_pressed(KEY_SPACE): buttons |= 1
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or Input.is_physical_key_pressed(KEY_SHIFT): buttons |= 2
	if Input.is_physical_key_pressed(KEY_Q): buttons |= 4
	if Input.is_physical_key_pressed(KEY_E): buttons |= 8
	if Input.is_physical_key_pressed(KEY_R): buttons |= 16
	if aim.y > 280 or aim.y < 48: buttons &= ~1
	if _lore_open or _paused_focus: buttons = 64
	if button_override >= 0: buttons = button_override
	if (_test_mode or _captures) and button_override < 0:
		# Headless exported outcome probe drives actual commands through the host.
		aim = _position_at(35) if _connected else Vector2(435, 187)
		buttons = 4 | 8 | 16
		movement = Vector2(1, 0) if not _connected or _state[10] < 260 else Vector2.ZERO
	if "--lairs-selftest" in OS.get_cmdline_user_args() and _connected and button_override < 0:
		aim = Vector2(_state[35], _state[36])
		var direction := aim - Vector2(_state[10], _state[11])
		movement = direction.normalized() if direction.length() > 42 else Vector2.ZERO
		buttons = 1 | 4 | 8 | 16 | _pending_buttons
	_sequence += 1
	if _pending_buttons != 0 and _pending_sequence == 0 and (buttons & _pending_buttons) == _pending_buttons:
		_pending_sequence = _sequence
	var bytes := PackedByteArray()
	bytes.resize(36)
	bytes.encode_u32(0, 0x31494c44)
	bytes.encode_u32(4, _token)
	bytes.encode_u32(8, _sequence)
	bytes.encode_float(12, movement.x)
	bytes.encode_float(16, movement.y)
	bytes.encode_float(20, aim.x)
	bytes.encode_float(24, aim.y)
	bytes.encode_u32(28, buttons)
	bytes.encode_u32(32, _artifact)
	_peer.put_packet(bytes)

func _process(delta: float) -> void:
	_elapsed += delta
	_age += delta
	_send_time += delta
	var drained := 0
	while _peer.get_available_packet_count() > 0 and drained < 64:
		drained += 1
		var bytes := _peer.get_packet()
		if bytes.size() != 20+EXPECTED_FLOATS*4 or bytes.decode_u32(0) != 0x32534c44 or bytes.decode_u32(4) != _token:
			continue
		if bytes.decode_u32(16) != int(_chapter.simulation_stamp):
			_status.text = "Trial data and helper versions differ. Re-extract the full package."
			continue
		if _peer.get_packet_ip() != "127.0.0.1":
			continue
		var seq := bytes.decode_u32(8)
		if seq <= _last_snapshot or bytes.decode_u32(12) != EXPECTED_FLOATS:
			continue
		if _port == 0:
			_port = _peer.get_packet_port()
			_peer.set_dest_address("127.0.0.1", _port)
		elif _peer.get_packet_port() != _port:
			continue
		_last_snapshot = seq
		_previous = _state
		_state = bytes.slice(20).to_float32_array()
		if _pending_sequence > 0 and int(_state[0]) >= _pending_sequence:
			_pending_buttons = 0
			_pending_sequence = 0
		if _previous.is_empty(): _previous = _state
		_connected = true
		_last_received = _elapsed
		_age = 0
		_select_lair(int(_state[439]))
		_refresh_status()
	if _send_time >= 1.0/30.0:
		_send_time = 0
		_send()
	if _elapsed - _last_received > 3.0:
		_status.text = "Trial connection interrupted. ESC returns to menu."
	queue_redraw()
	if _test_mode:
		_test_frames += 1
		if _connected and _state[1] >= 180:
			var ok := _state[5] >= 1 and _state[24+1] > 0 and _state[24+4] > 0 and _state[29] > 0
			var report := {"passed": ok, "ticks": _state[1], "damage": _state[29], "chain_procs": _state[25], "ward_procs": _state[28], "atlas_frames": _atlas.clips[0].frames.size(), "max_draw_us": _max_draw_us}
			var file := FileAccess.open("user://living-smoke.json", FileAccess.WRITE)
			file.store_string(JSON.stringify(report))
			file.close()
			print("LIVING PLAYTEST ", "OK " if ok else "FAIL ", report)
			get_tree().quit(0 if ok else 1)
		elif _elapsed > 20:
			push_error("LIVING PLAYTEST TIMEOUT")
			get_tree().quit(1)
	if _captures and _connected and _elapsed > 8.0 and _seen == 0:
		_seen = 1
		_capture.call_deferred()

func _capture() -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://living-trial.png")
	var file := FileAccess.open("user://living-render.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"fps": Engine.get_frames_per_second(), "frame_cpu_ms": Performance.get_monitor(Performance.TIME_PROCESS)*1000.0, "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "max_draw_us": _max_draw_us}))
	file.close()
	print("LIVING CAPTURE: ", OS.get_user_data_dir().path_join("living-trial.png"))
	get_tree().quit()

func _select_lair(index: int) -> void:
	if index == _lair_index: return
	_lair_index = index
	var lair: Dictionary = _chapter.playable.lairs[index]
	for creature in _chapter.release.creatures:
		if creature.id == lair.creature: _creature = creature
	var folder := "res://living/generated/" if index == 0 else "res://living/generated/lair_%d/" % index
	_atlas = JSON.parse_string(FileAccess.get_file_as_string(folder + "atlas.json"))
	_albedo = load(folder + "albedo.png")
	_emissive = load(folder + "emissive.png")
	_refresh_lore()

func _refresh_status() -> void:
	var skill: Dictionary = _skills[_chapter.playable.lairs[_lair_index].phases[int(_state[5])].skill]
	_status.text = "%s  ·  %s  ·  WASD move / mouse aim" % ["PAUSED" if _lore_open else "BELL SHRINE", skill.name]
	_feedback.text = "%s  |  Echo %d  Chain %d  Resolve %d  Ward %d" % [_artifacts[_artifact].name, int(_state[24]), int(_state[25]), int(_state[27]), int(_state[28])]
	if _state[440] == 2:
		_status.text = "BOSS RUSH  ·  ROUND %d  ·  %s" % [int(_state[441]), skill.name]
	elif _state[440] == 0:
		_status.text = "PRACTICE  ·  %s  ·  All artifacts available" % skill.name
	if _state[442] > 0:
		_status.text = "Defeat this guardian in its world lair to unlock boss rush. ESC: return."
	if _state[442] == 2:
		_status.text = "This doorway is not present in this world. ESC: return."
	if _state[445] > 0:
		_status.text = "Collection could not be saved. Keep this fight open to retry."
	if _state[442] == 3:
		_status.text = "Collection is busy or unreadable; its save is preserved. ESC: return."
	if _state[440] != 0 and _artifact > 0 and _state[446+_artifact] == 0:
		_artifact = int(_state[2])
	_next_button.visible = _state[3] == 1 and _state[4] == 0
	_next_button.disabled = _state[445] > 0
	for i in range(4):
		_artifact_buttons[i].disabled = _state[440] != 0 and i != 0 and _state[446+i] == 0
		_artifact_buttons[i].text = "%d  %s%s" % [i+1, RARITIES[i], " ×%d" % int(_state[446+i]) if _state[440] != 0 else ""]
		_artifact_buttons[i].modulate = COLORS[i] if i == int(_state[2]) else Color(0.65, 0.65, 0.65)
	for i in range(5):
		_cast_buttons[i].modulate = TEAL if _state[19+i] == 0 else Color(0.55, 0.6, 0.65)

func _position_at(index: int) -> Vector2:
	var weight := clampf(_age*30.0, 0, 1)
	return Vector2(lerpf(_previous[index], _state[index], weight), lerpf(_previous[index+1], _state[index+1], weight))

func _text(at: Vector2, text: String, tint := Color("d9d4c7"), large := false) -> void:
	draw_string(_big if large else _small, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16 if large else 8, tint)

func _bar(at: Vector2, width: float, amount: float, maximum: float, tint: Color) -> void:
	draw_rect(Rect2(at, Vector2(width, 4)), Color("101820"))
	draw_rect(Rect2(at, Vector2(width*clampf(amount/maximum, 0, 1), 4)), tint)

func _draw() -> void:
	var started := Time.get_ticks_usec()
	draw_rect(Rect2(0, 0, 640, 360), Color("08121c"))
	# One bounded CanvasItem draws the shrine plate, telegraphs and actors.
	draw_texture_rect(_shrine, Rect2(0,48,640,224), false)
	for i in range(32):
		var x := float((i*71+15)%640)
		var y := 56.0+float((i*37)%220)
		var alpha := 0.15+0.12*sin(_elapsed*1.3+i)
		draw_circle(Vector2(x,y), 1.0, Color(0.45, 0.95, 0.8, alpha))
	_text(Vector2(12,21), "BELL SHRINE" if _lair_index < 0 else str(_chapter.playable.lairs[_lair_index].name).to_upper(), GOLD, true)
	if not _connected:
		return
	for n in range(12):
		var h := 67+n*7
		if _state[h+4] <= 0: continue
		var center := Vector2(_state[h], _state[h+1])
		var radius := _state[h+2]
		var waiting := _state[h+3] > 0
		var color := Color("efb080") if waiting else Color("71c1c2")
		draw_circle(center, radius, Color(color, 0.10 if waiting else 0.22))
		draw_arc(center, radius, 0, TAU, 40, Color(color, 0.85), 1)
		if waiting:
			draw_arc(center, radius-4, -PI/2, -PI/2+TAU*(1.0-_state[h+3]/45.0), 32, Color(color, 0.45), 2)
	for n in range(32):
		var v := 151+n*9
		if _state[v+6] <= 0: continue
		var a := Vector2(_state[v+1],_state[v+2])
		var b := Vector2(_state[v+3],_state[v+4])
		var life := _state[v+6]/maxf(1,_state[v+7])
		var kind := int(_state[v])
		var color := Color(TEAL if kind > 1 else GOLD, life)
		if EFFECT_KIND_ACTION.has(kind) and _effect_colors.has(EFFECT_KIND_ACTION[kind]):
			color = Color(_effect_colors[EFFECT_KIND_ACTION[kind]], life)
		if _state[v+8] > 0: color = Color(1, 0.55, 0.4, life)
		if kind == 2:
			var delta := b-a
			var points := PackedVector2Array([a, a+delta*0.27+Vector2(0,-7), a+delta*0.52+Vector2(0,6), a+delta*0.78+Vector2(0,-4), b])
			draw_polyline(points, Color(color, life*0.18), 5)
			draw_polyline(points, color, 1)
		elif kind <= 1:
			var angle := (b-a).angle()
			draw_arc(a, _state[v+5]*(1.2-life*0.2), angle-1.0, angle+1.0, 18, color, 3 if kind == 0 else 2)
		else:
			draw_arc(a, maxf(8,_state[v+5])*(1.2-life*0.2), 0, TAU, 32, color, 1)
			if kind == 6: draw_line(a,b,color,1)
	var actors: Array = []
	actors.append({"kind": -1, "pos": _position_at(10)})
	actors.append({"kind": -2, "pos": _position_at(17)})
	for i in range(4):
		if _state[35+i*8+2] > 0 or (i == 0 and _state[4] > 0):
			actors.append({"kind": i, "pos": _position_at(35+i*8)})
	actors.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.pos.y < b.pos.y)
	for actor in actors:
		_draw_actor(actor.kind, actor.pos)
	var hp := _state[37]
	_bar(Vector2(208,51), 224, hp, _state[38], GOLD)
	_text(Vector2(220,65), "BONDED COMPANION" if _state[4] > 0 else str(_creature.name).to_upper(), GOLD)
	_bar(Vector2(12,273), 130, _state[12], _state[13], Color("ec867e"))
	_bar(Vector2(149,273), 110, _state[9], 100, TEAL)
	_text(Vector2(268,278), "HP %d  LUMEN %d  WARD %d%s" % [int(_state[12]),int(_state[9]),int(_state[14]),"  WET" if _state[16] > 0 else ""])
	if _state[3] > 0 and _state[4] == 0:
		draw_rect(Rect2(82,109,476,122), Color(0.025,0.05,0.07,0.95))
		_text(Vector2(154,140), "THE BELL REMEMBERS" if _state[3] == 1 else "THE FEN CLAIMS YOU", GOLD, true)
		if _state[3] == 1:
			var earned := int(_state[443])
			_text(Vector2(110,163), "EARNED: " + str(_artifacts[earned].name) if earned < 4 else "Practice complete. Find this guardian in the world.", TEAL)
			_text(Vector2(110,182), "Boss rush unlocked  ·  F: bond guardian  ·  ESC: return" if _state[440] == 1 else "ENTER: next encounter  ·  ESC: collection", GOLD)
		else:
			_text(Vector2(157,162), "ENTER: retry   1-4: change artifact")
	elif _state[4] > 0:
		_text(Vector2(193,92), "Your guardian follows. ENTER: continue", TEAL)
	_max_draw_us = maxi(_max_draw_us, Time.get_ticks_usec()-started)

func _draw_actor(kind: int, pos: Vector2) -> void:
	draw_set_transform(pos,0,Vector2(1,0.35))
	draw_circle(Vector2.ZERO, 10 if kind != 0 else 24, Color(0,0,0,0.28))
	draw_set_transform(Vector2.ZERO)
	if kind == 0:
		var frames: Array = _atlas.clips[0].rects
		var rect: Array = frames[int(_state[1]/3) % frames.size()]
		var area := Rect2(float(rect[0]),float(rect[1]),float(rect[2]),float(rect[3]))
		var target := Rect2(pos-Vector2(_atlas.anchor[0],_atlas.anchor[1]), Vector2(_atlas.frame_px,_atlas.frame_px))
		draw_texture_rect_region(_albedo,target,area,Color(1.3,1.2,1.05) if _state[41] > 0 else Color.WHITE)
		draw_texture_rect_region(_emissive,target,area,Color(1,1,1,0.35+0.15*sin(_elapsed*3)))
		if _state[39] > 0: draw_arc(pos-Vector2(0,45),48,0,TAU,40,Color(GOLD,0.6),1)
	elif kind == -1:
		var moving := _previous[10] != _state[10] or _previous[11] != _state[11]
		var frame := int(_elapsed*(8 if moving else 3)) % (4 if moving else 2)
		draw_texture_rect_region(_hero,Rect2(pos-Vector2(17,32),Vector2(34,34)),Rect2(frame*52,52 if moving else 0,52,52),Color(TEAL,0.6) if _state[15] > 0 else Color.WHITE)
		if _state[14] > 0: draw_arc(pos-Vector2(0,12),22,0,TAU,32,Color(GOLD,0.8),1)
	else:
		var size: Array = _wisp_data.frame_size
		var anchor: Array = _wisp_data.anchor
		var animation: Dictionary = _wisp_data.animations.idle
		var frame := int(_elapsed*float(animation.fps)) % int(animation.frames)
		var scale := 0.48 if kind == -2 else 0.65
		var tint := TEAL if kind == -2 else Color("c1b8d8")
		draw_texture_rect_region(_wisp,Rect2(pos-Vector2(anchor[0],anchor[1])*scale,Vector2(size[0],size[1])*scale),Rect2(frame*int(size[0]),int(animation.row)*int(size[1]),size[0],size[1]),tint)
	if kind >= 0:
		var index := 35+kind*8
		if kind > 0: _bar(pos+Vector2(-16,5),32,_state[index+2],_state[index+3],Color("a8b4c8"))
		if _state[index+5] > 0:
			draw_arc(pos, 18, 0, TAU, 20, TEAL, 1)
			_text(pos+Vector2(-10,18), "WET", TEAL)
