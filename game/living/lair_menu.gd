extends Control

func _ready() -> void:
	theme = ProtoTheme.get_theme()
	var bg := TextureRect.new()
	bg.texture = load("res://living/shrine.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.modulate = Color(0.25, 0.32, 0.37)
	add_child(bg)
	var box := VBoxContainer.new()
	box.position = Vector2(46, 20)
	box.size = Vector2(548, 320)
	box.add_theme_constant_override("separation", 7)
	add_child(box)
	label(box, "LAIRS & LEGENDS", 16, Color("d8b875"))
	label(box, "Find a doorway. Defeat its guardian. Remember the hunt.", 8)
	button(box, "EXPLORE SHRINE ENTRANCES", LairJourney.explore)
	button(box, "PRACTICE THE BELL SHRINE — ALL ARTIFACTS", LairJourney.practice)
	label(box, "BOSS RUSH  ·  Defeat guardians in their lairs to unlock them", 8, Color("7ed4ba"))
	var saved := LairJourney.collection()
	if saved.has("error"):
		label(box, str(saved.error), 8, Color("ec867e"))
	else:
		var scroller := ScrollContainer.new()
		scroller.custom_minimum_size.y = 72
		box.add_child(scroller)
		var list := VBoxContainer.new()
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroller.add_child(list)
		for lair in LairJourney.data().playable.lairs:
			var clears := 0
			var rushes := 0
			for record in saved.lairs:
				if record.id == lair.id:
					clears = int(record.clears)
					rushes = int(record.rush_clears)
			var id: String = lair.id
			var entry := button(list, ("START RUSH: " if clears > 0 else "LOCKED: ") + str(lair.name), func() -> void: LairJourney.rush(id))
			entry.disabled = clears == 0
			label(list, "Lair victories %d  ·  Rush victories %d" % [clears, rushes], 8)
		label(box, "EARNED COLLECTION  ·  equip these artifacts in lairs and rush", 8, Color("d8b875"))
		var names := ["Legendary", "Relic", "Mythic", "Divine"]
		var counts: Array[String] = []
		for i in range(4): counts.append("%s ×%d" % [names[i], int(saved.items[i])])
		label(box, "     ".join(counts), 8)
		label(box, "Each victory earns an artifact. New facets unlock as your collection grows.", 8)
	label(box, "Codex collection · local profile · separate from your regular equipment", 8, Color("acb8b4"))
	button(box, "BACK TO MAIN MENU", func() -> void: get_tree().change_scene_to_file("res://prototype/ui/main_menu.tscn"))

func label(parent: Node, text: String, size: int, color := Color("d9d4c7")) -> void:
	var item := Label.new()
	item.text = text
	item.add_theme_font_size_override("font_size", size)
	if size == 16: item.add_theme_font_override("font", ProtoTheme.font_big())
	item.add_theme_color_override("font_color", color)
	parent.add_child(item)

func button(parent: Node, text: String, action: Callable) -> Button:
	var item := Button.new()
	item.text = text
	item.custom_minimum_size.y = 23
	item.pressed.connect(action)
	parent.add_child(item)
	return item
