extends Control

func _ready() -> void:
	theme = ProtoTheme.get_theme()
	add_child(preload("res://prototype/ui/world_frame.gd").new())
	var box := VBoxContainer.new()
	box.position = Vector2(46, 18)
	box.size = Vector2(548, 320)
	box.add_theme_constant_override("separation", 5)
	add_child(box)
	label(box, "LAIRS & LEGENDS", 16, Color("d8b875"))
	label(box, "Find a doorway. Defeat its guardian. Remember the hunt.", 8)
	ProtoTheme.accent_button(button(box, "EXPLORE SHRINE ENTRANCES", LairJourney.explore), ProtoTheme.LUMEN)
	button(box, "PRACTICE THE BELL SHRINE — ALL ARTIFACTS", LairJourney.practice)
	label(box, "BOSS RUSH  ·  Defeat guardians in their lairs to unlock them", 8, Color("7ed4ba"))
	var saved := LairJourney.collection()
	if saved.has("error"):
		label(box, str(saved.error), 8, Color("ec867e"))
	else:
		var scroller := ScrollContainer.new()
		scroller.custom_minimum_size.y = 60
		scroller.follow_focus = true
		scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
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
		var cards := HBoxContainer.new()
		cards.add_theme_constant_override("separation", 6)
		box.add_child(cards)
		var rarities := ["legendary", "relic", "mythic", "divine"]
		var colors := [Color("e2b96f"), Color("79d4b7"), Color("c5a1ea"), Color("eee1ab")]
		var chapter := LairJourney.data()
		for i in range(rarities.size()):
			for artifact in chapter.release.artifacts:
				if artifact.rarity != rarities[i]: continue
				var card := preload("res://living/artifact_card.gd").new()
				card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				card.add_theme_stylebox_override("panel", ProtoTheme.chip_box(colors[i], 0.1))
				card.tooltip_text = str(artifact.name) + "\n" + str(artifact.signature).left(220)
				for lore in chapter.release.lore:
					if lore.id == artifact.lore:
						card.tooltip_text += "\n\n" + str(lore.story).left(220) + ("…" if str(lore.story).length() > 220 else "")
				cards.add_child(card)
				var content := VBoxContainer.new()
				content.add_theme_constant_override("separation", 3)
				content.mouse_filter = Control.MOUSE_FILTER_IGNORE
				card.add_child(content)
				label(content, str(rarities[i]).to_upper(), 8, colors[i])
				label(content, "%d earned" % int(saved.items[i]), 8)
				var name_label := Label.new()
				name_label.text = str(artifact.name)
				name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				name_label.max_lines_visible = 2
				name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
				name_label.add_theme_color_override("font_color", ProtoTheme.DIM)
				name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
				content.add_child(name_label)
		label(box, "Each victory earns an artifact. New facets unlock as your collection grows.", 8)
	label(box, "Codex collection · local profile · separate from your regular equipment", 8, Color("acb8b4"))
	button(box, "BACK TO MAIN MENU", func() -> void: get_tree().change_scene_to_file("res://prototype/ui/main_menu.tscn"))

func label(parent: Node, text: String, size: int, color := Color("d9d4c7")) -> void:
	var item := Label.new()
	item.text = text
	item.add_theme_font_size_override("font_size", size)
	if size == 16: item.add_theme_font_override("font", ProtoTheme.font_big())
	item.add_theme_color_override("font_color", color)
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(item)

func button(parent: Node, text: String, action: Callable) -> Button:
	var item := Button.new()
	item.text = text
	item.custom_minimum_size.y = 23
	item.pressed.connect(action)
	parent.add_child(item)
	return item
