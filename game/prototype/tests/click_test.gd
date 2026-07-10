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
	await _click(up.get_global_rect().get_center())
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

	# ---- skill tree: learn a node through injected clicks ------------------------
	Session.skill_points = 1
	tabs.current_tab = 3   # Skills
	cp.refresh()
	await get_tree().process_frame
	var learn := _btn_containing(cp, "Learn (1 pt)")
	if learn == null:
		_fail("no learnable node button on the Skills tab")
	else:
		await _click(learn.get_global_rect().get_center())
		if Session.node_learned("brutal_edge"):
			print("CLICKTEST OK: skill node learned via click (brutal_edge)")
		else:
			_fail("Learn click had no effect")

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
	Session.login("clicktest")   # reload from disk
	if Session.gold == 777 and Session.stables.size() == 1 \
			and Session.mounts.size() == 1 and Session.owns_mount("gloam_strider") \
			and str(Session.equipment["weapon"].get("name", "")) == weapon_name:
		print("CLICKTEST OK: save round-trip (gold, stables, mounts, equipment)")
	else:
		_fail("save round-trip mismatch: gold %d, stables %d, weapon '%s' vs '%s'" % [
				Session.gold, Session.stables.size(),
				str(Session.equipment["weapon"].get("name", "")), weapon_name])
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
