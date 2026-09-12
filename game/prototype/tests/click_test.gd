# PROTOTYPE HARNESS — headless UI regression: injects REAL mouse events and
# asserts the interactive flows respond (Haven forge picks/upgrades, character
# panel bag select + equip). Run:
#   godot --headless --path game res://prototype/tests/click_test.tscn
# Prints CLICKTEST OK/FAIL lines; exits nonzero on failure.
extends Node2D

var _failed := false

func _ready() -> void:
	_run()

func _run() -> void:
	# the suite asserts English strings — a stray user://settings.json from a
	# local PT-BR session must never break CI
	ProtoLang.set_lang("en")
	Session.gold = 1000
	var sword: Dictionary = ProtoItems.roll_item("emberfang_blade", "rare")
	Session.add_item(sword)
	Session.add_item(ProtoItems.make_essence())

	# ---- Haven: FORGE flow entirely through injected clicks -------------------
	var haven: Control = (load("res://prototype/ui/haven.tscn") as PackedScene).instantiate()
	add_child(haven)
	await get_tree().process_frame
	await get_tree().process_frame
	print("haven root rect: ", haven.get_global_rect())
	# QUIT must sit FULLY on-screen — the 2-wide nav grid regression guard
	var quit_btn := _btn_with_text(haven, "QUIT")
	var vp_rect := Rect2(Vector2.ZERO, Vector2(640, 360))
	if quit_btn == null:
		_fail("no QUIT button at the Haven")
	elif not vp_rect.encloses(quit_btn.get_global_rect()):
		_fail("QUIT button rect %s pokes outside the 640x360 viewport"
				% quit_btn.get_global_rect())
	else:
		print("CLICKTEST OK: Haven QUIT button fully inside the 640x360 viewport")
	var forge_btn := _btn_with_text(haven, "FORGE")
	if forge_btn == null:
		_fail("no FORGE button found")
		return _done()
	print("FORGE button rect: ", forge_btn.get_global_rect())
	await _click(forge_btn.get_global_rect().get_center())
	if _label_starting(haven, "+10% to ALL affix values") == null:
		_fail("FORGE click did not open the forge panel")
	else:
		print("CLICKTEST OK: forge panel opened via mouse click")
	var pick := _btn_containing(haven, "Emberfang")
	if pick == null:
		_fail("forge list shows no gear button")
		return _done()
	await _click(pick.get_global_rect().get_center())
	var up := _btn_containing(haven, "UPGRADE to +1")
	if up == null:
		_fail("gear click did not open the upgrade preview")
		return _done()
	await _scroll_to(up)   # the wider nav column wraps the explainer; UPGRADE
	await _click(up.get_global_rect().get_center())   # can sit below the fold
	if int(sword.get("upgrade_tier", 0)) == 1:
		print("CLICKTEST OK: forge upgrade applied via clicks (tier +1, gold %d)" % Session.gold)
	else:
		_fail("UPGRADE click had no effect (tier still %d)" % int(sword.get("upgrade_tier", 0)))

	# ---- Character panel: bag select + Equip through injected clicks ----------
	var cp := ProtoCharacterPanel.new()
	add_child(cp)
	cp.toggle()
	await get_tree().process_frame
	var tabs: TabContainer = cp.find_children("*", "TabContainer", true, false)[0]
	tabs.current_tab = 1   # Bag (tab-bar switching is engine behavior, not ours)
	cp.refresh()
	await get_tree().process_frame
	await get_tree().process_frame
	var item_btn := _btn_with_tooltip(cp, "Emberfang")
	if item_btn == null:
		_fail("no bag item button rendered")
		return _done()
	print("bag item rect: ", item_btn.get_global_rect())
	await _click(item_btn.get_global_rect().get_center())
	var eq := _btn_with_text(cp, "Equip")
	if eq == null:
		_fail("bag item click did not open the detail (no Equip button)")
		return _done()
	await _click(eq.get_global_rect().get_center())
	if not (Session.equipment["weapon"] as Dictionary).is_empty():
		print("CLICKTEST OK: item equipped via clicks — %s" %
				str(Session.equipment["weapon"].get("name", "?")))
	else:
		_fail("Equip click had no effect")

	# ---- skill tree: node chips open the fixed detail card; Learn + the 1-4
	# assign chips live on the card (visual tree redesign) --------------------------
	Session.level = 20   # min_level gates open (brutal_edge needs level 2)
	Session.skill_points = 3
	tabs.current_tab = 3   # Skills
	cp.refresh()
	await get_tree().process_frame
	if _btn_with_tooltip(cp, "learn brutal_edge") != null:
		_fail("Learn button rendered before any node was selected")
	var chip := _btn_with_tooltip(cp, "(node brutal_edge)")
	if chip == null:
		_fail("no tree chip for brutal_edge on the Skills tab")
	else:
		await _scroll_to(chip)   # chips live inside the tab's ScrollContainer
		await _click(chip.get_global_rect().get_center())
		var learn := _btn_with_tooltip(cp, "learn brutal_edge")
		if learn == null:
			_fail("chip click did not open the detail card (no Learn for brutal_edge)")
		else:
			print("CLICKTEST OK: node detail card opened via chip click (brutal_edge)")
			await _scroll_to(learn)   # the upstream detail card is scrollable
			await _click(learn.get_global_rect().get_center())
			if Session.node_learned("brutal_edge"):
				print("CLICKTEST OK: passive learned via the detail card (brutal_edge)")
			else:
				_fail("detail-card Learn click had no effect (brutal_edge)")
	var chip_act := _btn_with_tooltip(cp, "(node rv_gash)")
	if chip_act == null:
		_fail("no tree chip for the rv_gash active")
	else:
		await _scroll_to(chip_act)
		await _click(chip_act.get_global_rect().get_center())
		var learn_act := _btn_with_tooltip(cp, "learn rv_gash")
		if learn_act == null:
			_fail("rv_gash chip click did not open its detail card")
		else:
			await _scroll_to(learn_act)   # the upstream detail card is scrollable
			await _click(learn_act.get_global_rect().get_center())
			if Session.node_learned("rv_gash"):
				print("CLICKTEST OK: active skill learned via the detail card (rv_gash)")
			else:
				_fail("detail-card Learn click had no effect (rv_gash)")
	var assign := _btn_with_tooltip(cp, "assign Gash to slot 1")
	if assign == null:
		_fail("learned active shows no assign chip for slot 1 on the detail card")
	else:
		await _scroll_to(assign)   # the upstream detail card is scrollable
		await _click(assign.get_global_rect().get_center())
		if str(Session.skill_loadout[0]) == "rv_gash":
			print("CLICKTEST OK: active assigned to skill-bar slot 1 via click")
		else:
			_fail("assign chip click had no effect (slot 1 = '%s')"
					% str(Session.skill_loadout[0]))

	# ---- executor: a REAL cast against a REAL creature (headless, no main) ------
	var pl := ProtoPlayer.new()
	add_child(pl)
	var cr := ProtoCreature.new()
	cr.global_position = pl.global_position + Vector2(24, 0)   # inside Gash reach
	add_child(cr)
	await get_tree().process_frame
	# use_skill aims at the mouse — park it to the player's RIGHT so the arc
	# covers the creature (UI clicks above left the cursor pointing elsewhere)
	await _mouse_move(pl.global_position + Vector2(300, 0))
	var hp0: float = cr.hp
	if pl.use_skill(Session.skill_def("rv_gash")) and cr.hp < hp0 \
			and cr.has_status("bleeding") and pl.skill_cd_left("rv_gash") > 0.0:
		print("CLICKTEST OK: generic executor — Gash dealt damage, applied Bleed, set cooldown")
	else:
		_fail("use_skill(rv_gash) failed (hp %.1f -> %.1f, bleeding %s, cd %.2f)" % [
				hp0, cr.hp, str(cr.has_status("bleeding")), pl.skill_cd_left("rv_gash")])
	# keys 1-4 path: learn a buff active, assign it to slot 2, cast it with KEY_2
	var chip_buff := _btn_with_tooltip(cp, "(node rv_blood_howl)")
	if chip_buff == null:
		_fail("no tree chip for rv_blood_howl")
	else:
		await _scroll_to(chip_buff)
		await _click(chip_buff.get_global_rect().get_center())
		var learn_buff := _btn_with_tooltip(cp, "learn rv_blood_howl")
		if learn_buff == null:
			_fail("rv_blood_howl chip click did not open its detail card")
		else:
			await _scroll_to(learn_buff)   # the upstream detail card is scrollable
			await _click(learn_buff.get_global_rect().get_center())
		var assign2 := _btn_with_tooltip(cp, "assign Blood Howl to slot 2")
		if assign2 == null:
			_fail("no assign chip for Blood Howl slot 2")
		else:
			await _scroll_to(assign2)   # the upstream detail card is scrollable
			await _click(assign2.get_global_rect().get_center())
			# slot path (KEY_2 in play): headless physics ticks don't align with
			# injected-event flush frames, so drive the same code directly.
			pl._cast_slot(1)
			if pl.skill_cd_left("rv_blood_howl") > 0.0:
				print("CLICKTEST OK: skill bar — slot 2 cast the assigned Blood Howl")
			else:
				_fail("slot 2 did not cast the assigned skill")

	# class charge mechanic: the Gloam Mage builds Attunement and spends it
	Session.class_id = "core.class.mage"
	pl.apply_stats()
	pl.use_skill(Session.skill_def("gm_gloambolt"))     # builder: +1 stack
	var stacks_after_build: int = pl.charge_stacks
	pl.use_skill(Session.skill_def("gm_gloomburst"))    # spender: consumes all
	if pl.charge_name == "Attunement" and stacks_after_build == 1 \
			and pl.charge_stacks == 0:
		print("CLICKTEST OK: class charge — Attunement built by Gloambolt, spent by Gloomburst")
	else:
		_fail("charge mechanic broken (name '%s', built %d, after spend %d)" % [
				pl.charge_name, stacks_after_build, pl.charge_stacks])
	Session.class_id = "core.class.reaver"
	pl.apply_stats()

	# ---- panel close: × click, C toggle, Esc — the Haven-close bug regression ---
	if not cp.visible:
		_fail("panel should be visible after the equip flow")
	var xbtn := _btn_with_text(cp, "×")
	if xbtn == null:
		_fail("no × close button on the panel")
	else:
		await _click(xbtn.get_global_rect().get_center())
		if cp.visible:
			_fail("× click did not close the panel")
		else:
			print("CLICKTEST OK: panel closed via × button")
	await _key(KEY_C)
	if not cp.visible:
		_fail("C key did not reopen the panel")
	await _key(KEY_ESCAPE)
	if cp.visible:
		_fail("Esc did not close the panel")
	else:
		print("CLICKTEST OK: panel toggles via C and closes via Esc")

	# ---- PT-BR: toggle to pt — SAIR stays inside the viewport (the longest
	# nav label regression) and the detail card speaks Portuguese ---------------
	ProtoLang.set_lang("pt")
	var haven_pt: Control = (load("res://prototype/ui/haven.tscn") as PackedScene).instantiate()
	add_child(haven_pt)
	await get_tree().process_frame
	await get_tree().process_frame
	var sair := _btn_with_text(haven_pt, "SAIR")
	if sair == null:
		_fail("PT: no SAIR button at the Haven")
	elif not vp_rect.encloses(sair.get_global_rect()):
		_fail("PT: SAIR button rect %s pokes outside the 640x360 viewport"
				% sair.get_global_rect())
	else:
		print("CLICKTEST OK: PT-BR — SAIR button fully inside the 640x360 viewport")
	cp._sel_node = "rv_gash"
	cp.refresh()
	await get_tree().process_frame
	var pt_name := str(Session.skill_def("rv_gash").get("name_pt", ""))
	if pt_name == "":
		_fail("PT: rv_gash carries no name_pt in skill_trees.json")
	elif _label_with_text(cp, pt_name) == null:
		_fail("PT: detail card does not show rv_gash's name_pt ('%s')" % pt_name)
	else:
		print("CLICKTEST OK: PT-BR — detail card titles rv_gash as '%s'" % pt_name)
	ProtoLang.set_lang("en")
	haven_pt.queue_free()
	await get_tree().process_frame

	# ---- persistence: save → mutate → login reloads (stables included) ----------
	Session.login("clicktest")
	Session.stables.append({"uid": ProtoItems.next_uid(), "name": "Stabled 88%",
			"species": "core.creature.gloamfen_stalker", "roll_pct": 88,
			"skills": ["core.skill.shadow_rend"]})
	Session.gold = 777
	Session.grant_mount({"uid": ProtoItems.next_uid(), "key": "gloam_strider",
			"name": "Gloam Strider", "kind": "walk", "speed_mult": 1.6,
			"rarity": "rare", "tint": "9ecbe8"})
	Session.save()
	var weapon_name := str(Session.equipment["weapon"].get("name", ""))
	Session.gold = 0
	Session.stables = []
	Session.mounts = []
	Session.equipment["weapon"] = {}
	Session.skill_loadout = ["", "", "", ""]
	Session.learned_nodes = ["root_cleave"]
	Session.login("clicktest")   # reload from disk
	if Session.gold == 777 and Session.stables.size() == 1 \
			and Session.mounts.size() == 1 and Session.owns_mount("gloam_strider") \
			and str(Session.equipment["weapon"].get("name", "")) == weapon_name \
			and str(Session.skill_loadout[0]) == "rv_gash" \
			and Session.node_learned("rv_gash"):
		print("CLICKTEST OK: save round-trip (gold, stables, mounts, equipment, skill loadout)")
	else:
		_fail("save round-trip mismatch: gold %d, stables %d, weapon '%s' vs '%s', slot1 '%s'" % [
				Session.gold, Session.stables.size(),
				str(Session.equipment["weapon"].get("name", "")), weapon_name,
				str(Session.skill_loadout[0])])
	DirAccess.remove_absolute(
			ProjectSettings.globalize_path("user://saves/clicktest.json"))
	_done()

func _fail(msg: String) -> void:
	_failed = true
	print("CLICKTEST FAIL: " + msg)

func _done() -> void:
	print("CLICKTEST DONE — %s" % ("FAILED" if _failed else "ALL PASS"))
	get_tree().quit(1 if _failed else 0)

# ---- helpers -------------------------------------------------------------------

func _click(pos: Vector2) -> void:
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = pos
		ev.global_position = pos
		Input.parse_input_event(ev)
	await get_tree().process_frame
	await get_tree().process_frame

func _mouse_move(pos: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	Input.parse_input_event(ev)
	await get_tree().process_frame
	await get_tree().process_frame

# Injected clicks miss controls scrolled out of view — bring them on screen first.
func _scroll_to(ctl: Control) -> void:
	var p: Node = ctl.get_parent()
	while p != null and not (p is ScrollContainer):
		p = p.get_parent()
	if p is ScrollContainer:
		(p as ScrollContainer).ensure_control_visible(ctl)
		await get_tree().process_frame
		await get_tree().process_frame

func _key(code: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.pressed = pressed
		Input.parse_input_event(ev)
	await get_tree().process_frame
	await get_tree().process_frame

func _btn_with_text(root: Node, text: String) -> Button:
	for b in root.find_children("*", "Button", true, false):
		if b.text == text:
			return b
	return null

func _btn_containing(root: Node, part: String) -> Button:
	for b in root.find_children("*", "Button", true, false):
		if part in b.text:
			return b
	return null

func _btn_with_tooltip(root: Node, part: String) -> Button:
	for b in root.find_children("*", "Button", true, false):
		if part in b.tooltip_text:
			return b
	return null

func _label_starting(root: Node, part: String) -> Label:
	for l in root.find_children("*", "Label", true, false):
		if str(l.text).begins_with(part):
			return l
	return null

func _label_with_text(root: Node, text: String) -> Label:
	for l in root.find_children("*", "Label", true, false):
		if str(l.text) == text:
			return l
	return null
