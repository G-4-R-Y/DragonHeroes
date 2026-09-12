## Shared presentation for stables, mounts and bonded companions. Portraits
## come from the same cached frame library as the actor; nicknames never
## replace species identity, rolled attributes, skills or save UIDs.
class_name ProtoCompanionCard
extends RefCounted

static func frames(data: Dictionary) -> SpriteFrames:
	var actor := str(data.get("bundle", str(data.get("species", "")).get_slice(".", 2)))
	if actor.is_empty() and data.has("kind"):
		actor = "ember_drake" if str(data.kind) == "fly" else "fen_boar"
	if not actor.is_empty() and FileAccess.file_exists("res://prototype/art/%s/atlas.json" % actor):
		var sf := ProtoBundleArt.frames_for(actor)
		if sf != null:
			return sf
	return ProtoSprites.stalker_frames()

static func create(data: Dictionary, status := "", action_text := "", action := Callable(), unavailable := false) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "Companion_%d" % int(data.get("uid", 0))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	card.add_child(row)
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(48, 48)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var sf := frames(data)
	var clip := "idle" if sf.has_animation("idle") else sf.get_animation_names()[0]
	portrait.texture = sf.get_frame_texture(clip, 0)
	portrait.tooltip_text = str(data.get("species", data.get("name", "")))
	row.add_child(portrait)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var heading := Label.new()
	heading.text = Session.companion_name(data)
	heading.add_theme_color_override("font_color", ProtoTheme.GOLD)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(heading)
	var identity := Label.new()
	identity.text = str(data.get("name", "")) + ("  ·  " + status if not status.is_empty() else "") if not str(data.get("nickname", "")).is_empty() else status
	identity.visible = not identity.text.is_empty()
	identity.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(identity)
	var facts := Label.new()
	if data.has("kind"):
		facts.text = "%s   ·   +%d%% %s" % [ProtoLang.t("cp_flying") if str(data.kind) == "fly" else ProtoLang.t("cp_walking"), roundi((float(data.get("speed_mult", 1.0)) - 1.0) * 100.0), ProtoLang.t("mount_speed")]
	else:
		facts.text = "%d%% %s   ·   %d %s" % [int(data.get("roll_pct", 100)), ProtoLang.t("companion_potential"), data.get("skills", []).size(), ProtoLang.t("companion_skills")]
	facts.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	facts.add_theme_color_override("font_color", ProtoTheme.LUMEN)
	info.add_child(facts)
	if not data.get("skills", []).is_empty():
		var skills := Label.new()
		var names := PackedStringArray()
		for id in data.skills:
			names.append(str(id).get_slice(".", str(id).get_slice_count(".") - 1).replace("_", " ").capitalize())
		skills.text = " · ".join(names)
		skills.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(skills)
	var edit_row := HBoxContainer.new()
	info.add_child(edit_row)
	var edit := LineEdit.new()
	edit.name = "Nickname"
	edit.max_length = 24
	edit.placeholder_text = ProtoLang.t("companion_nickname")
	edit.text = str(data.get("nickname", ""))
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.custom_minimum_size.x = 90
	edit_row.add_child(edit)
	var save := Button.new()
	save.text = ProtoLang.t("companion_rename")
	var commit := func() -> void:
		if Session.rename_companion(int(data.get("uid", -1)), edit.text):
			heading.text = Session.companion_name(data)
			edit.text = str(data.get("nickname", ""))
	save.pressed.connect(commit)
	edit.text_submitted.connect(func(_value: String) -> void: commit.call())
	edit_row.add_child(save)
	if action.is_valid():
		var button := Button.new()
		button.text = action_text
		button.disabled = unavailable
		button.pressed.connect(action)
		info.add_child(button)
	return card
