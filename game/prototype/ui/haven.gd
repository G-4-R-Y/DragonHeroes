# PROTOTYPE HARNESS — the Haven: between-hunt game menu. The meta systems are
# REAL now: the character panel (gear/bag/attributes/rune sockets), the FORGE
# (tiered upgrades with fail risk), the ENCHANTER (Spirit Essences with destroy
# risk at high tiers — docs/design/14 mirror) and the VENDOR (gold sink stub;
# the real player marketplace is web-only, docs/design/15) all mutate the
# Session autoload — the stand-in for server-authoritative state (canon hard
# rule). Dies the day the real meta screens land.
extends Control

const EMBER := Color("ff9a3c")
const GOLD := Color("ffd166")
const PALE := Color("d9d4c7")
const DIM := Color(0.6, 0.59, 0.55)
const VIOLET := Color("cf9dff")
const CYAN := Color("7fe7ff")
const RED := Color("ff8a7a")

const CharacterPanelScene := preload("res://prototype/ui/character_panel.gd")

var _panel_title: Label
var _panel_body: VBoxContainer
var _stats_label: Label
var _points_label: Label
var _attr_labels := {}
var _char_panel: ProtoCharacterPanel
var _forge_uid := -1
var _forge_msg := ""
var _ench_uid := -1
var _ench_msg := ""
var _vendor_msg := ""

func _ready() -> void:
	_build()

# Code-built end to end, so the language toggle (welcome panel) rebuilds the
# whole screen in place — same trick as the main menu.
func _build() -> void:
	theme = ProtoTheme.get_theme()
	# display text (screen + panel titles) rides the 16 px pixel font; body stays 8
	var big := ProtoTheme.font_big()
	Session.request_save()   # entering the Haven checkpoints the character
	var bg := ColorRect.new()
	bg.color = Color("0e1319")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 14)
	add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	margin.add_child(vb)

	var title := Label.new()
	title.text = ProtoLang.t("hv_welcome_title") % Session.player_name
	if big != null:
		title.add_theme_font_override("font", big)
	title.add_theme_font_size_override("font_size", ProtoTheme.SIZE_TITLE)
	title.add_theme_color_override("font_color", EMBER)
	vb.add_child(title)

	_stats_label = Label.new()
	_stats_label.add_theme_font_size_override("font_size", ProtoTheme.SIZE_BODY)
	_stats_label.add_theme_color_override("font_color", PALE)
	_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_stats_label)
	_refresh_stats()

	var hb := HBoxContainer.new()
	hb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hb.add_theme_constant_override("separation", 12)
	vb.add_child(hb)

	var buttons := VBoxContainer.new()
	buttons.custom_minimum_size = Vector2(190, 0)
	buttons.add_theme_constant_override("separation", 4)
	hb.add_child(buttons)

	var hunt := _btn(buttons, ProtoLang.t("hv_go_hunting"), _go_hunting)
	hunt.add_theme_color_override("font_color", EMBER)
	hunt.add_theme_font_size_override("font_size", ProtoTheme.SIZE_BODY)
	hunt.custom_minimum_size = Vector2(0, 24)
	# 2-wide grid: eleven stacked buttons overflowed the 360 px viewport and
	# cropped QUIT half off-screen (Ricardo 2026-07-12). Nav labels sit on the
	# pixel body grid (8) in every language — the widest PT-BR label
	# ("ENCANTADOR") still holds in the 93 px cells and QUIT/SAIR stays inside
	# the viewport (click test guard).
	var nav_font := ProtoTheme.SIZE_BODY
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(grid)
	for pair: Array in [["hv_character", _toggle_character], ["hv_skills", _show_skills],
			["hv_pets", _show_pets], ["hv_attributes", _show_attributes],
			["hv_forge", _show_forge], ["hv_enchanter", _show_enchant],
			["hv_vendor", _show_vendor], ["hv_chest", _show_chest],
			["hv_codex", _show_codex]]:
		var nb := _btn(grid, ProtoLang.t(str(pair[0])), pair[1])
		nb.add_theme_font_size_override("font_size", nav_font)
		nb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	buttons.add_child(gap)
	var quit := _btn(buttons, ProtoLang.t("hv_quit"), func() -> void: get_tree().quit())
	quit.add_theme_font_size_override("font_size", nav_font)

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hb.add_child(panel)

	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 4)
	panel.add_child(pv)

	_panel_title = Label.new()
	if big != null:
		_panel_title.add_theme_font_override("font", big)
	_panel_title.add_theme_font_size_override("font_size", ProtoTheme.SIZE_TITLE)
	# localized kiosk titles (esp. PT-BR) can run long at the 16 px display width;
	# wrap inside the bounded panel rather than spill past the border
	_panel_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel_title.add_theme_color_override("font_color", EMBER)
	pv.add_child(_panel_title)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pv.add_child(scroll)

	_panel_body = VBoxContainer.new()
	_panel_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel_body.add_theme_constant_override("separation", 3)
	scroll.add_child(_panel_body)

	# The same character panel used in the hunt — gear/bag/attributes/runes/pets.
	_char_panel = CharacterPanelScene.new()
	add_child(_char_panel)

	_show_welcome()

# ---- panel plumbing ----------------------------------------------------------

func _btn(parent: Container, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

func _open(title: String) -> void:
	_panel_title.text = title
	for c in _panel_body.get_children():
		_panel_body.remove_child(c)
		c.queue_free()

func _line(text: String, color := PALE, font_size := ProtoTheme.SIZE_BODY) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	_panel_body.add_child(l)
	return l

func _header(text: String) -> Label:
	return _line(text, EMBER)

# Quiet section break + small ember section header — every flow reads the same.
func _section(text: String) -> void:
	_panel_body.add_child(HSeparator.new())
	_line(text.to_upper(), EMBER)

# "core.skill.abyssal_maw" -> "Abyssal Maw"
func _pretty_id(content_id: String) -> String:
	return content_id.get_slice(".", 2).capitalize()

func _iname(item: Dictionary) -> String:
	var t := int(item.get("upgrade_tier", 0))
	return str(item.get("name", "?")) + (" +%d" % t if t > 0 else "")

func _refresh_stats() -> void:
	Session.request_save()   # forge/enchant/vendor/attribute changes all pass here
	var weapon: Dictionary = Session.equipment["weapon"]
	var wtxt := ProtoLang.t("hv_unarmed") if weapon.is_empty() else _iname(weapon)
	_stats_label.text = ProtoLang.t("hv_stats") % [
			Session.level, Session.gold, Session.kills, Session.attribute_points,
			Session.stones, Session.snares, Session.pets.size(), Session.MAX_PETS,
			Session.inventory.size(), ProtoItems.INVENTORY_CAP, wtxt]

# Every gear item (equipped + bagged) as [item, where] pairs — forge/enchanter lists.
func _gear_list() -> Array:
	var out: Array = []
	for slot in ProtoItems.GEAR_SLOTS:
		var it: Dictionary = Session.equipment[slot]
		if not it.is_empty():
			out.append([it, "equipped"])
	for it in Session.inventory:
		if ProtoItems.GEAR_SLOTS.has(str(it.get("slot", ""))):
			out.append([it, "bag"])
	return out

func _find_gear(uid: int) -> Dictionary:
	for entry in _gear_list():
		if int((entry[0] as Dictionary).get("uid", -1)) == uid:
			return entry[0]
	return {}

# ---- panels -------------------------------------------------------------------

func _show_welcome() -> void:
	_open(ProtoLang.t("hv_title"))
	_line(ProtoLang.t("hv_welcome_line"), PALE)
	_line(ProtoLang.t("hv_welcome_body"), DIM)
	# language toggle mirrored from the main menu — switches live and persists
	var lb := Button.new()
	lb.text = ProtoLang.t("lang_toggle")
	lb.focus_mode = Control.FOCUS_NONE
	lb.add_theme_font_size_override("font_size", 8)
	lb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	lb.pressed.connect(_toggle_lang)
	_panel_body.add_child(lb)

func _toggle_lang() -> void:
	ProtoLang.set_lang("pt" if ProtoLang.lang == "en" else "en")
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_build()

func _toggle_character() -> void:
	_char_panel.toggle()

func _go_hunting() -> void:
	# Always a fresh hunt (fresh packs); character state persists via Session.
	get_tree().change_scene_to_file("res://prototype/main.tscn")

func _show_skills() -> void:
	_open(ProtoLang.t("hv_skills_title") % Session.class_display())
	# class-tree summary (skill_trees.json): the real learn/assign UI lives in
	# CHARACTER → Skills; this kiosk is the overview.
	var actives := 0
	var passives := 0
	var learned := 0
	for n in Session.class_tree():
		if str(n.get("type", "")) == "active":
			actives += 1
		elif int(n.get("cost", 1)) > 0:
			passives += 1
		if int(n.get("cost", 1)) > 0 and Session.def_learned(n):
			learned += 1
	_line(ProtoLang.t("hv_skills_summary")
			% [Session.class_display(), actives, passives, learned]
			+ ProtoLang.t("hv_skills_banked") % Session.skill_points, PALE)
	var charge: Dictionary = Session.class_charge()
	if not charge.is_empty():
		_line("◈ %s — %s" % [ProtoLang.pick(charge, "name"),
				ProtoLang.pick(charge, "desc")], VIOLET)
	for br in Session.class_branches():
		var names: Array[String] = []
		for n in br.get("nodes", []):
			if int(n.get("cost", 1)) > 0:
				names.append(ProtoLang.pick(n, "name", "?"))
		if not names.is_empty():
			_line("- %s: %s" % [ProtoLang.pick(br, "name", "?"), ", ".join(names)], DIM)
	_line(ProtoLang.t("hv_skills_open_tree"), PALE)
	var cleave := Session.load_content("cleave")
	var n: Dictionary = cleave.get("numbers", {})
	_header(ProtoLang.t("hv_cleave_header") % str(cleave.get("id", "core.skill.cleave")))
	_line(ProtoLang.t("hv_cleave_stats") % [
			float(n.get("damage_coeff", 0.0)), float(n.get("reach_m", 0.0)),
			int(n.get("arc_deg", 0)), int(n.get("cooldown_s", 0)),
			ProtoLang.term("dt", str(cleave.get("damage_type", "physical")))], PALE)
	_header(ProtoLang.t("hv_runes_header"))
	for def in ProtoItems.rune_defs():
		_line("- %s — %s" % [str(def.get("name", "?")), str(def.get("desc", ""))],
				VIOLET)
	_line(ProtoLang.t("hv_runes_drop"), DIM)

func _show_pets() -> void:
	_open(ProtoLang.t("hv_pets_title") % [Session.pets.size(), Session.MAX_PETS])
	if Session.pets.is_empty():
		_line(ProtoLang.t("hv_pets_none"), DIM)
	for pet in Session.pets:
		_header(str(pet.get("name", "?")))
		_line(ProtoLang.t("hv_pets_roll") % [int(pet.get("roll_pct", 100)),
				str(pet.get("species", ""))], PALE)
		for s in pet.get("skills", []):
			_line("- %s  (%s)" % [_pretty_id(str(s)), str(s)], GOLD)
	if not Session.stables.is_empty():
		_header(ProtoLang.t("hv_stables_header") % Session.stables.size())
		for pet in Session.stables:
			_line(ProtoLang.t("hv_stables_row") % [str(pet.get("name", "?")),
					int(pet.get("roll_pct", 100)),
					(pet.get("skills", []) as Array).size()], PALE)
		_line(ProtoLang.t("hv_stables_manage"), DIM)
	_line(ProtoLang.t("hv_pets_rules"), DIM)
	var fam := Session.load_content("abyssal")
	_line(str(fam.get("lore", "")), DIM)
	_header(ProtoLang.t("hv_family_skills"))
	for s in fam.get("family_shared_skills", []):
		_line("- %s  (%s)" % [_pretty_id(str(s)), str(s)], PALE)
	_header(ProtoLang.t("hv_species"))
	for sp in fam.get("species", []):
		var sigs: Array[String] = []
		for s in sp.get("signature_skills", []):
			sigs.append(_pretty_id(str(s)))
		_line(ProtoLang.t("hv_species_row") % [
				_pretty_id(str(sp.get("creature", "?"))), ", ".join(sigs)], PALE)
	var rules: Dictionary = fam.get("roll_rules", {})
	var roll_range: Dictionary = rules.get("attribute_roll_range", {})
	_line(ProtoLang.t("hv_roll_rules") % [
			int(rules.get("skill_slots", 0)),
			int(float(rules.get("family_skill_chance", 0.0)) * 100.0),
			int(roll_range.get("min_pct", 0)), int(roll_range.get("max_pct", 0))], DIM)

func _show_attributes() -> void:
	_open(ProtoLang.t("hv_attr_title"))
	_attr_labels.clear()
	_points_label = _line(ProtoLang.t("unspent_points") % Session.attribute_points, GOLD)
	for attr in Session.ATTRIBUTES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_panel_body.add_child(row)
		var nl := Label.new()
		nl.text = "%s  (%s)" % [ProtoLang.t("attr_" + str(attr)),
				ProtoLang.t("fx_" + str(attr))]
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nl.add_theme_font_size_override("font_size", ProtoTheme.SIZE_BODY)
		nl.add_theme_color_override("font_color", PALE)
		row.add_child(nl)
		var vl := Label.new()
		vl.text = str(Session.attributes[attr])
		vl.add_theme_font_size_override("font_size", ProtoTheme.SIZE_BODY)
		vl.add_theme_color_override("font_color", GOLD)
		row.add_child(vl)
		_attr_labels[attr] = vl
		var minus := Button.new()
		minus.text = "-"
		minus.custom_minimum_size = Vector2(22, 0)
		minus.pressed.connect(_adjust_attribute.bind(str(attr), -1))
		row.add_child(minus)
		var plus := Button.new()
		plus.text = "+"
		plus.custom_minimum_size = Vector2(22, 0)
		plus.pressed.connect(_adjust_attribute.bind(str(attr), 1))
		row.add_child(plus)
	_line(ProtoLang.t("hv_attr_note"), DIM)

# REALLY spends Session points (refunds allowed down to base — prototype QoL).
func _adjust_attribute(attr: String, delta: int) -> void:
	if delta > 0 and Session.attribute_points <= 0:
		return
	if delta < 0 and int(Session.attributes[attr]) <= Session.BASE_ATTRIBUTE:
		return
	Session.attributes[attr] = int(Session.attributes[attr]) + delta
	Session.attribute_points -= delta
	_attr_labels[attr].text = str(Session.attributes[attr])
	_points_label.text = ProtoLang.t("unspent_points") % Session.attribute_points
	_refresh_stats()

# ---- FORGE: REAL tiered upgrades (docs/design/14 soft mirror; proposals) ----------

# Preview + UPGRADE render FIRST (above the fold at 640x360); the pick list
# and the rules explainer sit below them.
func _show_forge() -> void:
	_open(ProtoLang.t("hv_forge_title"))
	_line(ProtoLang.t("gold_line") % Session.gold, GOLD)
	if _forge_msg != "":
		_line(_forge_msg, EMBER)
	var gear := _gear_list()
	if gear.is_empty():
		_line(ProtoLang.t("hv_forge_none"), DIM)
		return
	var item := _find_gear(_forge_uid)
	if item.is_empty():
		_line(ProtoLang.t("hv_forge_pick_hint"), DIM)
	else:
		var tier := int(item.get("upgrade_tier", 0))
		_header(ProtoLang.t("hv_forge_before_after") % _iname(item))
		if tier >= ProtoItems.FORGE_MAX_TIER:
			_line(ProtoLang.t("hv_forge_max") % ProtoItems.FORGE_MAX_TIER, DIM)
		else:
			for a in item.get("affixes", []):
				var cur := float(a.get("value", 0)) * (1.0 + 0.1 * tier)
				var nxt := float(a.get("value", 0)) * (1.0 + 0.1 * (tier + 1))
				_line("%s: +%.0f → +%.0f" % [
						ProtoItems.stat_name(str(a.get("stat", "?"))), cur, nxt],
						PALE)
			var en: Variant = item.get("enchant")
			if en is Dictionary and not (en as Dictionary).is_empty():
				_line(ProtoLang.t("hv_forge_enchant_note") % [
						float(en.get("value", 0)),
						ProtoItems.stat_name(str(en.get("stat", "?")))], DIM)
			var cost := ProtoItems.upgrade_cost(item)
			var fail := ProtoItems.upgrade_fail_chance(item)
			var risk_txt := "" if fail <= 0.0 \
					else ProtoLang.t("hv_fail_risk") % int(round(fail * 100.0))
			var b2 := _btn(_panel_body, ProtoLang.t("hv_forge_upgrade_btn") % [tier + 1,
					cost, risk_txt], _forge_do)
			b2.add_theme_color_override("font_color", EMBER)
			b2.disabled = Session.gold < cost
			if Session.gold < cost:
				_line(ProtoLang.t("hv_no_gold"), RED)
	_section(ProtoLang.t("hv_forge_pick_section"))
	_line(ProtoLang.t("hv_forge_rules"), DIM)
	for entry in gear:
		var it: Dictionary = entry[0]
		var picked := int(it.get("uid", -1)) == _forge_uid
		var b := _btn(_panel_body, ProtoLang.t("hv_gear_row") % [
				"▸ " if picked else "", _iname(it), ProtoItems.power(it),
				int(it.get("upgrade_tier", 0)), ProtoLang.t("where_" + str(entry[1]))],
				_forge_pick.bind(int(it.get("uid", -1))))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", ProtoTheme.SIZE_BODY)
		b.add_theme_color_override("font_color",
				ProtoItems.rarity_color(str(it.get("rarity", "common"))))

func _forge_pick(uid: int) -> void:
	_forge_uid = uid
	_forge_msg = ""
	_show_forge()

func _forge_do() -> void:
	var item := _find_gear(_forge_uid)
	if item.is_empty() or int(item.get("upgrade_tier", 0)) >= ProtoItems.FORGE_MAX_TIER:
		return
	var cost := ProtoItems.upgrade_cost(item)
	if Session.gold < cost:
		return
	Session.gold -= cost   # gold is consumed either way (design/14 risk taste)
	if ProtoItems.try_upgrade(item):
		_forge_msg = ProtoLang.t("hv_forged_msg") % _iname(item)
	else:
		_forge_msg = ProtoLang.t("hv_forge_failed") % cost
	_refresh_stats()
	_show_forge()

# ---- ENCHANTER: Spirit Essences (docs/design/14 §9.1; destroy risk mirror) ---------

# Same shape as the forge: current pick + APPLY on top, list + explainer below.
func _show_enchant() -> void:
	_open(ProtoLang.t("hv_ench_title"))
	var ess_count := 0
	for it in Session.inventory:
		if str(it.get("slot", "")) == "material":
			ess_count += int(it.get("qty", 1))
	_line(ProtoLang.t("hv_ench_count") % ess_count, CYAN)
	if _ench_msg != "":
		_line(_ench_msg, EMBER)
	if ess_count == 0:
		_line(ProtoLang.t("hv_ench_none"), DIM)
		return
	var item := _find_gear(_ench_uid)
	if item.is_empty() or not ProtoItems.can_enchant(item):
		_line(ProtoLang.t("hv_ench_pick_hint"), DIM)
	else:
		_header(_iname(item))
		var en: Variant = item.get("enchant")
		if en is Dictionary and not (en as Dictionary).is_empty():
			_line(ProtoLang.t("hv_ench_current") % [
					float(en.get("value", 0)),
					ProtoItems.stat_name(str(en.get("stat", "?")))], PALE)
		else:
			_line(ProtoLang.t("hv_ench_none_yet"), PALE)
		var b2 := _btn(_panel_body, ProtoLang.t("hv_ench_apply"), _ench_do)
		b2.add_theme_color_override("font_color", CYAN)
	_section(ProtoLang.t("hv_ench_pick_section"))
	_line(ProtoLang.t("hv_ench_rules"), DIM)
	var any := false
	for entry in _gear_list():
		var it: Dictionary = entry[0]
		if not ProtoItems.can_enchant(it):
			continue
		any = true
		var picked := int(it.get("uid", -1)) == _ench_uid
		var b := _btn(_panel_body, ProtoLang.t("hv_ench_row") % ["▸ " if picked else "",
				_iname(it), int(it.get("upgrade_tier", 0)),
				ProtoLang.t("where_" + str(entry[1]))],
				_ench_pick.bind(int(it.get("uid", -1))))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", ProtoTheme.SIZE_BODY)
		b.add_theme_color_override("font_color",
				ProtoItems.rarity_color(str(it.get("rarity", "common"))))
	if not any:
		_line(ProtoLang.t("hv_ench_no_gear"), DIM)

func _ench_pick(uid: int) -> void:
	_ench_uid = uid
	_ench_msg = ""
	_show_enchant()

func _ench_do() -> void:
	var item := _find_gear(_ench_uid)
	if item.is_empty() or not ProtoItems.can_enchant(item):
		return
	var essence := {}
	for it in Session.inventory:
		if str(it.get("slot", "")) == "material":
			essence = it
			break
	if essence.is_empty():
		return
	_consume_essence(essence)   # the only cost — gear is never destroyed (Ricardo)
	var en := ProtoItems.roll_enchant()
	item.enchant = en
	item.power = ProtoItems.power(item)
	_ench_msg = ProtoLang.t("hv_ench_done") % [_iname(item), int(en.value),
			ProtoItems.stat_name(str(en.stat))]
	_refresh_stats()
	_show_enchant()

# Materials stack (qty); consuming takes one off the stack.
func _consume_essence(essence: Dictionary) -> void:
	if int(essence.get("qty", 1)) > 1:
		essence.qty = int(essence.qty) - 1
		Session.request_save()
	else:
		Session.remove_item(int(essence.get("uid", -1)))

# ---- VENDOR: sell for gold (stub sink — the real marketplace is docs/design/15) ----

# Selling (the primary action) renders first; the stable-master sits below.
func _show_vendor() -> void:
	_open(ProtoLang.t("hv_vendor_title"))
	_line(ProtoLang.t("gold_line") % Session.gold, GOLD)
	# message line ALWAYS renders so rows never shift under the cursor mid-spree
	_line(_vendor_msg if _vendor_msg != "" else " ", EMBER)
	if Session.inventory.is_empty():
		_line(ProtoLang.t("hv_bag_empty"), DIM)
	else:
		# one-click clears per rarity — non-equipped bag gear only (Ricardo)
		var chips := HBoxContainer.new()
		chips.add_theme_constant_override("separation", 6)
		_panel_body.add_child(chips)
		for rar in ["common", "uncommon", "rare", "epic"]:
			var uids: Array = []
			var total := 0
			for it in Session.inventory:
				if str(it.get("rarity", "")) == rar \
						and ProtoItems.GEAR_SLOTS.has(str(it.get("slot", ""))):
					uids.append(int(it.get("uid", -1)))
					total += ProtoItems.sell_price(it)
			if uids.is_empty():
				continue
			var sa := _btn(chips, ProtoLang.t("hv_sell_all_chip") % [
					ProtoLang.term("rarity", rar), uids.size(), total],
					_sell_all.bind(uids))
			sa.add_theme_font_size_override("font_size", ProtoTheme.SIZE_BODY)
			sa.add_theme_color_override("font_color", ProtoItems.rarity_color(rar))
		for it in Session.inventory:
			var qty := int(it.get("qty", 1))
			var b := _btn(_panel_body, ProtoLang.t("hv_sell_row") % [_iname(it),
					" x%d" % qty if qty > 1 else "", ProtoItems.sell_price(it) * qty],
					_vendor_sell.bind(int(it.get("uid", -1))))
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.icon = ProtoSprites.item_icon(str(it.get("sprite_key", "sword")),
					str(it.get("rarity", "common")))
			b.add_theme_font_size_override("font_size", ProtoTheme.SIZE_BODY)
			b.add_theme_color_override("font_color",
					ProtoItems.rarity_color(str(it.get("rarity", "common"))))
	_section(ProtoLang.t("hv_stable_master"))
	if Session.owns_mount("gloam_strider"):
		_line(ProtoLang.t("hv_strider_owned"), DIM)
	else:
		var mb := _btn(_panel_body, ProtoLang.t("hv_buy_strider"), _buy_strider)
		mb.add_theme_color_override("font_color", CYAN)
		mb.disabled = Session.gold < 400
	if not Session.owns_mount("emberwing_drakeling"):
		_line(ProtoLang.t("hv_no_fly_sale"), DIM)
	_line(ProtoLang.t("hv_market_note"), DIM)

func _buy_strider() -> void:
	if Session.gold < 400 or Session.owns_mount("gloam_strider"):
		return
	Session.gold -= 400
	Session.grant_mount({"uid": ProtoItems.next_uid(), "key": "gloam_strider",
			"name": "Gloam Strider", "kind": "walk", "speed_mult": 1.6,
			"rarity": "rare", "tint": "9ecbe8"})
	_vendor_msg = ProtoLang.t("hv_strider_bought")
	_refresh_stats()
	_show_vendor()

# ---- CHEST: the Haven stash (Ricardo) — bag <-> chest, big capacity ---------------

func _show_chest() -> void:
	_open(ProtoLang.t("hv_chest_title") % [Session.stash.size(),
			Session.STASH_CAP, Session.inventory.size(), ProtoItems.INVENTORY_CAP])
	_line(ProtoLang.t("hv_chest_note"), DIM)
	_section(ProtoLang.t("hv_chest_store_sec") % Session.inventory.size())
	if Session.inventory.is_empty():
		_line(ProtoLang.t("hv_bag_empty"), DIM)
	for it in Session.inventory:
		_chest_row(it, ProtoLang.t("hv_chest_store_row"), _chest_store)
	_section(ProtoLang.t("hv_chest_take_sec") % Session.stash.size())
	if Session.stash.is_empty():
		_line(ProtoLang.t("hv_chest_empty"), DIM)
	for it in Session.stash:
		_chest_row(it, ProtoLang.t("hv_chest_take_row"), _chest_take)

func _chest_row(it: Dictionary, fmt: String, cb: Callable) -> void:
	var qty := int(it.get("qty", 1))
	var b := _btn(_panel_body, fmt % [_iname(it), " x%d" % qty if qty > 1 else ""],
			cb.bind(int(it.get("uid", -1))))
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.icon = ProtoSprites.item_icon(str(it.get("sprite_key", "sword")),
			str(it.get("rarity", "common")))
	b.add_theme_font_size_override("font_size", ProtoTheme.SIZE_BODY)
	b.add_theme_color_override("font_color",
			ProtoItems.rarity_color(str(it.get("rarity", "common"))))

func _chest_store(uid: int) -> void:
	if Session.stash_item(uid):
		_refresh_stats()
	_show_chest()

func _chest_take(uid: int) -> void:
	if Session.unstash_item(uid):
		_refresh_stats()
	_show_chest()

# CODEX — the living registry of every effect/mechanic (effects.json, synced
# from content/core/registries/). Expandable data, never engine work (canon).
func _show_codex() -> void:
	_open(ProtoLang.t("hv_codex_title"))
	var data: Dictionary = Session.load_content("effects")
	_line(ProtoLang.t("hv_codex_note"), DIM)
	# entry names/descs come straight from effects.json (out of scope for this
	# pass — proposal: give the registry the same name_pt/desc_pt treatment).
	for group in data.get("groups", []):
		var entries: Array = group.get("entries", [])
		_section("%s (%d)" % [ProtoLang.pick(group, "name", "?"), entries.size()])
		for e in group.get("entries", []):
			var live := str(e.get("status", "live")) == "live"
			_line("- %s — %s%s" % [ProtoLang.pick(e, "name", "?"),
					ProtoLang.pick(e, "desc"),
					"" if live else ProtoLang.t("hv_codex_planned")],
					PALE if live else DIM)

func _sell_all(uids: Array) -> void:
	var got := 0
	var n := 0
	for uid in uids:
		var it := Session.find_item(int(uid))
		if it.is_empty():
			continue
		got += ProtoItems.sell_price(it)
		n += 1
		Session.remove_item(int(uid))
	Session.gold += got
	_vendor_msg = ProtoLang.t("hv_sold_n") % [n, got]
	_refresh_stats()
	_show_vendor()

func _vendor_sell(uid: int) -> void:
	var it := Session.find_item(uid)
	if it.is_empty():
		return
	Session.remove_item(uid)
	var price := ProtoItems.sell_price(it) * int(it.get("qty", 1))
	Session.gold += price
	_vendor_msg = ProtoLang.t("hv_sold_one") % [_iname(it), price]
	_refresh_stats()
	_show_vendor()
