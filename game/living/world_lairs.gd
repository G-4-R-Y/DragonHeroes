# Renders the C++ generator's versioned POI metadata. No placement or loot rules.
extends Node2D
var main: Node
var entries: Array[Dictionary] = []
var nearest: Dictionary = {}
var hint: Label
var clock := 0.0
var font: Font
var max_draw_us := 0

func _ready() -> void:
	main = get_parent()
	z_index = 3
	font = load(ProtoTheme.FONT_SMALL_PATH)
	main.world.chunk_loaded.connect(_changed)
	main.world.chunk_unloaded.connect(_changed)
	_refresh()
	var ui := CanvasLayer.new()
	ui.layer = 9
	add_child(ui)
	hint = Label.new()
	hint.theme = ProtoTheme.get_theme()
	hint.add_theme_font_size_override("font_size", ProtoTheme.SIZE_BODY)
	hint.position = Vector2(145, 38)
	hint.size = Vector2(355, 30)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color("b5e6d0"))
	ui.add_child(hint)
	if LairJourney.tour:
		LairJourney.tour = false
		if not entries.is_empty():
			main.player.global_position = entries[0].position + Vector2(0, 24)
			main.camera.reset_smoothing()

func _changed(_key: Vector2i) -> void:
	_refresh()

func _refresh() -> void:
	entries.clear()
	for key in main.world.entrances:
		for record in main.world.entrances[key]:
			var entry: Dictionary = record.duplicate()
			entry.title = "Ancient lair"
			for lair in LairJourney.data().playable.lairs:
				if lair.id == entry.id: entry.title = lair.name
			entry.chunk = key
			entry.position = (Vector2(key * ProtoWorld.CHUNK) + Vector2(float(record.x)+0.5, float(record.y)+0.5)) * ProtoWorld.TILE
			entries.append(entry)

func _process(delta: float) -> void:
	clock += delta
	nearest = {}
	var distance := INF
	for entry in entries:
		var d: float = main.player.global_position.distance_to(entry.position)
		if d < distance:
			distance = d
			nearest = entry
	if nearest.is_empty():
		hint.text = ""
	elif distance < 48:
		hint.text = "G  ENTER: " + str(nearest.title).to_upper() + "\nDefeat its guardian to unlock boss rush"
		if MpNet.in_game: hint.text = "Shrine lairs are available in solo Hunt"
	else:
		var direction: Vector2 = nearest.position - main.player.global_position
		var bearing := ("S" if direction.y > 0 else "N") if absf(direction.y) > absf(direction.x)*0.5 else ""
		if absf(direction.x) > absf(direction.y)*0.5: bearing += "E" if direction.x > 0 else "W"
		hint.text = "A distant bell calls %s  ·  SHRINE %dm" % [bearing, int(distance/ProtoWorld.TILE)]
	queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_G:
		if not nearest.is_empty() and main.player.global_position.distance_to(nearest.position) < 48 and not main.player.dead:
			get_viewport().set_input_as_handled()
			LairJourney.enter(main, nearest)

func _draw() -> void:
	var started := Time.get_ticks_usec()
	for entry in entries:
		var pos: Vector2 = entry.position
		if main.player.global_position.distance_to(pos) > 540: continue
		draw_set_transform(pos)
		# A bounded pixel-built arch, sunken stair, gilded bell and spectral doorway.
		_portal_shadow(Vector2(0, 7), Vector2(43, 13), Color(0.02, 0.08, 0.08, 0.7))
		for i in range(4):
			draw_rect(Rect2(-31+i*3, 3-i*5, 62-i*6, 5), Color("334549") if i%2 else Color("465956"))
		draw_rect(Rect2(-17, -49, 34, 49), Color("091c28"))
		for i in range(8):
			var glow := 0.12 + 0.06*sin(clock*2+i)
			draw_rect(Rect2(-16+i*2, -48+i*3, 32-i*4, 45-i*3), Color(0.18, 0.9, 0.76, glow))
		for side in [-1, 1]:
			for row in range(6):
				var x := float(side*23-6)
				draw_rect(Rect2(x, -row*9-11, 12, 9), Color("405255") if row%2 else Color("51635e"))
				draw_line(Vector2(x, -row*9-11), Vector2(x+10, -row*9-11), Color("8d9572"))
				draw_rect(Rect2(side*23-1, -row*9-9, 2, 3), Color("91d4b6"))
			draw_rect(Rect2(side*28-3, -3, 6, 8), Color("d8b875"))
			draw_circle(Vector2(side*28, -5), 2, Color("a9f6cf"))
		draw_colored_polygon(PackedVector2Array([Vector2(-31,-55),Vector2(-18,-65),Vector2(0,-71),Vector2(18,-65),Vector2(31,-55)]),Color("566764"))
		draw_line(Vector2(-28,-55), Vector2(28,-55), Color("b5a770"), 2)
		draw_rect(Rect2(-5,-62,10,9), Color("c2ab72"))
		draw_rect(Rect2(-7,-55,14,3), Color("e8d497"))
		draw_rect(Rect2(-1,-52,2,3), Color("d8b875"))
		for i in range(12):
			var p := Vector2(sin(i*12.4+clock*0.4)*25, -fmod(clock*8+i*9,66))
			draw_rect(Rect2(p.round(), Vector2.ONE), Color("9debc4"))
		draw_string(font, Vector2(-90,23), str(entry.title).left(32).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 180, 8, Color("d8b875"))
	draw_set_transform(Vector2.ZERO)
	max_draw_us = maxi(max_draw_us, Time.get_ticks_usec()-started)

func _portal_shadow(center: Vector2, size: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(24): points.append(center + Vector2(cos(i*TAU/24)*size.x, sin(i*TAU/24)*size.y))
	draw_colored_polygon(points, color)
