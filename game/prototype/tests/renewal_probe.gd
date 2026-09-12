## Real actor actions, recycled effects, companion edits, persistence and navigation.
extends Node

var failed := false

func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error("RENEWAL FAIL: " + message)

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	ProtoLang.set_lang("en")
	var hunter := "renewal_%d" % Time.get_ticks_usec()
	Session.login(hunter)
	var pet := {"uid": ProtoItems.next_uid(), "name": "Gloam Stalker", "species": "core.creature.gloamfen_stalker", "roll_pct": 104, "skills": ["core.skill.shadow_rend"]}
	Session.stables = [pet]
	var card := ProtoCompanionCard.create(pet)
	card.theme = ProtoTheme.get_theme()
	add_child(card)
	var edit := card.find_child("Nickname", true, false) as LineEdit
	check(edit != null, "nickname field absent")
	edit.text = "  Moonfang  "
	edit.text_submitted.emit(edit.text)
	check(Session.companion_name(pet) == "Moonfang" and pet.name == "Gloam Stalker", "rename lost species identity")
	Session.gold = 931
	Session.save()
	Session.leave_character()
	Session.login(hunter + "_fresh")
	check(Session.stables.is_empty() and Session.gold == 0 and Session.level == 1, "new hunter inherited the previous save")
	Session.leave_character()
	Session.login(hunter)
	check(Session.stables.size() == 1 and Session.companion_name(Session.stables[0]) == "Moonfang" and Session.gold == 931, "nickname/progress did not round-trip")
	card.queue_free()
	ProtoDisplay.set_visibility(0.85)
	ProtoDisplay.visibility = 0.0
	ProtoDisplay.apply_saved()
	check(is_equal_approx(ProtoDisplay.visibility, 0.85), "visibility did not persist")
	ProtoDisplay.set_visibility(0.6)
	var player := ProtoPlayer.new()
	player.bot_drive = true
	add_child(player)
	for action in ["attack", "cast", "heavy", "spin", "dodge"]:
		check(player.sprite.sprite_frames.has_animation(action), "missing authored action " + action)
		player._play_action(action, 0.15)
		check(player.sprite.animation == action, "action not selected " + action)
		await get_tree().create_timer(0.22).timeout
		check(player.sprite.animation == "idle", "action did not release to locomotion " + action)
	player._bot_step = Vector2(1.0, 0.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(player.sprite.animation == "walk", "movement did not select walk")
	player._bot_step = Vector2.ZERO
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(player.sprite.animation == "idle", "stopping did not select idle")
	# Missing-action compatibility cannot introduce an infinite action loop.
	var fallback := SpriteFrames.new()
	fallback.add_animation("walk")
	fallback.add_frame("walk", player.sprite.sprite_frames.get_frame_texture("idle", 0))
	ProtoBundleArt.ensure_animations(fallback, ["attack"])
	check(not fallback.get_animation_loop("attack"), "fallback attack loops")
	player.queue_free()
	var fx := ProtoShaderFx.new()
	add_child(fx)
	var first := fx.burst("slash", Vector2.ZERO, {"uniforms": {"arc_span": 5.0}})
	for i in ProtoShaderFx.POOL:
		fx.burst("slash", Vector2.ZERO)
	var mat: ShaderMaterial = fx._mats.slash[first % ProtoShaderFx.POOL]
	var restored: Variant = mat.get_shader_parameter("arc_span")
	# The headless renderer represents shader defaults as null.
	check(restored == null or is_equal_approx(float(restored), 2.0944), "recycled effect leaked old skill arc")
	fx.queue_free()
	var haven := preload("res://prototype/ui/haven.tscn").instantiate()
	get_tree().root.add_child(haven)
	get_tree().current_scene = haven
	await get_tree().process_frame
	var buttons := haven.find_children("*", "Button", true, false)
	var menu_button: Button
	for b in buttons:
		if b.text == "MAIN MENU": menu_button = b
	check(menu_button != null, "Haven main-menu navigation absent")
	if menu_button != null:
		Session.gold = 932
		Session.request_save()
		menu_button.pressed.emit()
		for i in 5: await get_tree().process_frame
		check(get_tree().current_scene.scene_file_path == "res://prototype/ui/main_menu.tscn", "Haven return did not open title")
		Session.login(hunter)
		check(Session.gold == 932, "Haven return lost pending save")
	Session.leave_character()
	for name in [hunter, hunter + "_fresh"]:
		DirAccess.remove_absolute("user://saves/%s.json" % name)
	if not failed: print("RENEWAL OK — action release, movement, VFX recycling, portrait/nickname save, fresh hunter isolation, visibility and actual Haven return")
	get_tree().quit(1 if failed else 0)
