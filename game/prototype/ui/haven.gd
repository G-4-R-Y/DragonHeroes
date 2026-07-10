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
	theme = ProtoTheme.get_theme()
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
	title.text = "Haven — welcome, %s" % Session.player_name
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", EMBER)
	vb.add_child(title)

	_stats_label = Label.new()
	_stats_label.add_theme_font_size_override("font_size", 10)
	_stats_label.add_theme_color_override("font_color", PALE)
	_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_stats_label)
	_refresh_stats()

	var hb := HBoxContainer.new()
	hb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hb.add_theme_constant_override("separation", 12)
	vb.add_child(hb)

	var buttons := VBoxContainer.new()
	buttons.custom_minimum_size = Vector2(150, 0)
	buttons.add_theme_constant_override("separation", 4)
	hb.add_child(buttons)

	var hunt := _btn(buttons, "GO HUNTING", _go_hunting)
	hunt.add_theme_color_override("font_color", EMBER)
	_btn(buttons, "CHARACTER", _toggle_character)
	_btn(buttons, "SKILLS", _show_skills)
	_btn(buttons, "PETS", _show_pets)
	_btn(buttons, "ATTRIBUTES", _show_attributes)
	_btn(buttons, "FORGE", _show_forge)
	_btn(buttons, "ENCHANTER", _show_enchant)
	_btn(buttons, "VENDOR", _show_vendor)
	_btn(buttons, "CHEST", _show_chest)
	_btn(buttons, "CODEX", _show_codex)
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	buttons.add_child(gap)
	_btn(buttons, "QUIT", func() -> void: get_tree().quit())

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hb.add_child(panel)

	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 4)
	panel.add_child(pv)

	_panel_title = Label.new()
	_panel_title.add_theme_font_size_override("font_size", 14)
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

func _line(text: String, color := PALE, font_size := 10) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	_panel_body.add_child(l)
	return l

func _header(text: String) -> Label:
	return _line(text, EMBER, 12)

# "core.skill.abyssal_maw" -> "Abyssal Maw"
func _pretty_id(content_id: String) -> String:
	return content_id.get_slice(".", 2).capitalize()

func _iname(item: Dictionary) -> String:
	var t := int(item.get("upgrade_tier", 0))
	return str(item.get("name", "?")) + (" +%d" % t if t > 0 else "")

func _refresh_stats() -> void:
	Session.request_save()   # forge/enchant/vendor/attribute changes all pass here
	var weapon: Dictionary = Session.equipment["weapon"]
	var wtxt := "unarmed" if weapon.is_empty() else _iname(weapon)
	_stats_label.text = ("Level %d · Gold %d · Kills %d · Points %d · Stones %d · " +
			"Snares %d · Pets %d/%d · Bag %d/%d · Weapon: %s") % [
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
	_open("Haven")
	_line("The hunt waits beyond the gloam.", PALE, 11)
	_line("Gear up (CHARACTER: equip loot, spend attribute points, socket runes), " +
			"then improve your kit at the FORGE and the ENCHANTER, sell scraps at " +
			"the VENDOR — and GO HUNTING. The Emberwing Matriarch nests in the far woods.",
			DIM)

func _toggle_character() -> void:
	_char_panel.toggle()

func _go_hunting() -> void:
	# Always a fresh hunt (fresh packs); character state persists via Session.
	get_tree().change_scene_to_file("res://prototype/main.tscn")

func _show_skills() -> void:
	_open("Skills — Reaver tree")
	var cls := Session.load_content("reaver")
	var res: Dictionary = cls.get("resource", {})
	_line("Class: %s (%s)  ·  resource: %s, max %d, %+d/s" % [
			str(cls.get("name", "Reaver")), str(cls.get("role", "")),
			str(res.get("name", "Fury")), int(res.get("max", 0)),
			int(res.get("regen_per_s", 0))], DIM)
	for node in cls.get("skill_tree", []):
		var txt := "%s  [%s]" % [str(node.get("node", "?")), str(node.get("kind", "?"))]
		if str(node.get("grants_skill", "")) != "":
			txt += " — grants %s" % _pretty_id(str(node.get("grants_skill")))
		var mods: Array[String] = []
		for m in node.get("stat_mods", []):
			mods.append("%s %+d" % [str(m.get("stat", "?")), int(m.get("value", 0))])
		if not mods.is_empty():
			txt += " — " + ", ".join(mods)
		if str(node.get("node", "")) == "root_cleave":
			_line("* " + txt + "   — LEARNED", GOLD, 11)
		else:
			_line("- " + txt, PALE, 11)
	var cleave := Session.load_content("cleave")
	var n: Dictionary = cleave.get("numbers", {})
	_header("Cleave (%s)" % str(cleave.get("id", "core.skill.cleave")))
	_line("coeff x%.1f  ·  reach %.1f m  ·  arc %d deg  ·  cooldown %d s  ·  %s damage" % [
			float(n.get("damage_coeff", 0.0)), float(n.get("reach_m", 0.0)),
			int(n.get("arc_deg", 0)), int(n.get("cooldown_s", 0)),
			str(cleave.get("damage_type", "physical"))], PALE, 11)
	_header("Runes (canon §4 — socket one per skill)")
	for def in ProtoItems.rune_defs():
		_line("- %s — %s" % [str(def.get("name", "?")), str(def.get("desc", ""))],
				VIOLET, 11)
	_line("Runes drop from Elites (the first Elite kill guarantees one). Socket " +
			"them in CHARACTER → Skills; the effects are LIVE in combat.", DIM)

func _show_pets() -> void:
	_open("Pets — Abyssal family (%d/%d bonded)" % [Session.pets.size(), Session.MAX_PETS])
	if Session.pets.is_empty():
		_line("No pet bonded yet — on the hunt, wound a Gloamfen Stalker below 35% HP " +
				"and press F with a Soul Snare (stalkers drop them).", DIM)
	for pet in Session.pets:
		_header(str(pet.get("name", "?")))
		_line("attribute roll %d%%  ·  %s" % [int(pet.get("roll_pct", 100)),
				str(pet.get("species", ""))], PALE, 11)
		for s in pet.get("skills", []):
			_line("- %s  (%s)" % [_pretty_id(str(s)), str(s)], GOLD, 11)
	if not Session.stables.is_empty():
		_header("Stables (%d) — pets are never abandoned" % Session.stables.size())
		for pet in Session.stables:
			_line("- %s  ·  roll %d%%  ·  %d skills" % [str(pet.get("name", "?")),
					int(pet.get("roll_pct", 100)),
					(pet.get("skills", []) as Array).size()], PALE, 11)
		_line("Swap active/stabled pets in CHARACTER → Pets.", DIM)
	_line("All bonded pets join every hunt and fight together (3 active slots, " +
			"proposal). Capturing with full slots asks for an F-again confirm and " +
			"STABLES the oldest bond. Pets rest 15 s when their HP empties and reset " +
			"with you on death — they never die.", DIM)
	var fam := Session.load_content("abyssal")
	_line(str(fam.get("lore", "")), DIM)
	_header("Family-shared skills")
	for s in fam.get("family_shared_skills", []):
		_line("- %s  (%s)" % [_pretty_id(str(s)), str(s)], PALE, 11)
	_header("Species")
	for sp in fam.get("species", []):
		var sigs: Array[String] = []
		for s in sp.get("signature_skills", []):
			sigs.append(_pretty_id(str(s)))
		_line("- %s — signature: %s" % [
				_pretty_id(str(sp.get("creature", "?"))), ", ".join(sigs)], PALE, 11)
	var rules: Dictionary = fam.get("roll_rules", {})
	var roll_range: Dictionary = rules.get("attribute_roll_range", {})
	_line("Roll rules: %d skill slots  ·  %d%% family-skill chance  ·  attribute rolls %d-%d%%" % [
			int(rules.get("skill_slots", 0)),
			int(float(rules.get("family_skill_chance", 0.0)) * 100.0),
			int(roll_range.get("min_pct", 0)), int(roll_range.get("max_pct", 0))], DIM)

func _show_attributes() -> void:
	_open("Attributes — allocation is REAL")
	_attr_labels.clear()
	_points_label = _line("Unspent points: %d" % Session.attribute_points, GOLD, 11)
	var fx := {"might": "+2% melee damage/pt", "agility": "+1% move · +2% dodge recharge/pt",
			"intellect": "+2% skill damage/pt", "vitality": "+6 max HP/pt",
			"willpower": "+1% resist · +2% status resist/pt"}
	for attr in Session.ATTRIBUTES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_panel_body.add_child(row)
		var nl := Label.new()
		nl.text = "%s  (%s)" % [str(attr).capitalize(), str(fx[attr])]
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nl.add_theme_font_size_override("font_size", 10)
		nl.add_theme_color_override("font_color", PALE)
		row.add_child(nl)
		var vl := Label.new()
		vl.text = str(Session.attributes[attr])
		vl.add_theme_font_size_override("font_size", 11)
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
	_line("Effects (stats.gd, proposals) apply at hunt start and re-apply live " +
			"mid-hunt from the character panel. +5 points per level — every 20 kills.",
			DIM)

# REALLY spends Session points (refunds allowed down to base — prototype QoL).
func _adjust_attribute(attr: String, delta: int) -> void:
	if delta > 0 and Session.attribute_points <= 0:
		return
	if delta < 0 and int(Session.attributes[attr]) <= Session.BASE_ATTRIBUTE:
		return
	Session.attributes[attr] = int(Session.attributes[attr]) + delta
	Session.attribute_points -= delta
	_attr_labels[attr].text = str(Session.attributes[attr])
	_points_label.text = "Unspent points: %d" % Session.attribute_points
	_refresh_stats()

# ---- FORGE: REAL tiered upgrades (docs/design/14 soft mirror; proposals) ----------

func _show_forge() -> void:
	_open("Forge — upgrade gear")
	_line("+10% to ALL affix values per tier, max +5. Cost 50 x 2^tier gold. " +
			"Attempts into +4/+5 FAIL 25%/40% — the gold burns, the item survives.", DIM)
	_line("Gold: %d" % Session.gold, GOLD, 11)
	if _forge_msg != "":
		_line(_forge_msg, EMBER, 11)
	var gear := _gear_list()
	if gear.is_empty():
		_line("no gear yet — hunt for drops.", DIM)
		return
	for entry in gear:
		var it: Dictionary = entry[0]
		var b := _btn(_panel_body, "%s · pw %d · tier +%d (%s)" % [_iname(it),
				ProtoItems.power(it), int(it.get("upgrade_tier", 0)), str(entry[1])],
				_forge_pick.bind(int(it.get("uid", -1))))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 10)
		b.add_theme_color_override("font_color",
				ProtoItems.rarity_color(str(it.get("rarity", "common"))))
	var item := _find_gear(_forge_uid)
	if item.is_empty():
		return
	var tier := int(item.get("upgrade_tier", 0))
	_header("%s — before → after" % _iname(item))
	if tier >= ProtoItems.FORGE_MAX_TIER:
		_line("already at max tier (+%d)." % ProtoItems.FORGE_MAX_TIER, DIM)
		return
	for a in item.get("affixes", []):
		var cur := float(a.get("value", 0)) * (1.0 + 0.1 * tier)
		var nxt := float(a.get("value", 0)) * (1.0 + 0.1 * (tier + 1))
		_line("%s: +%.0f → +%.0f" % [ProtoItems.stat_name(str(a.get("stat", "?"))),
				cur, nxt], PALE, 11)
	var en: Variant = item.get("enchant")
	if en is Dictionary and not (en as Dictionary).is_empty():
		_line("enchant +%.0f %s (does not scale with tiers)" % [float(en.get("value", 0)),
				ProtoItems.stat_name(str(en.get("stat", "?")))], DIM)
	var cost := ProtoItems.upgrade_cost(item)
	var fail := ProtoItems.upgrade_fail_chance(item)
	var risk_txt := "" if fail <= 0.0 else "  ·  FAIL RISK %d%%" % int(round(fail * 100.0))
	var b2 := _btn(_panel_body, "UPGRADE to +%d — %d gold%s" % [tier + 1, cost, risk_txt],
			_forge_do)
	b2.add_theme_color_override("font_color", EMBER)
	b2.disabled = Session.gold < cost
	if Session.gold < cost:
		_line("not enough gold.", RED, 10)

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
		_forge_msg = "forged: %s — affixes +10%%." % _iname(item)
	else:
		_forge_msg = "the forge FAILED — %d gold burned; the item survives." % cost
	_refresh_stats()
	_show_forge()

# ---- ENCHANTER: Spirit Essences (docs/design/14 §9.1; destroy risk mirror) ---------

func _show_enchant() -> void:
	_open("Enchanter — Spirit Essences")
	var essences: Array = []
	for it in Session.inventory:
		if str(it.get("slot", "")) == "material":
			essences.append(it)
	_line("Apply an Abyssal Remnant to a weapon or amulet: adds or REPLACES its " +
			"enchant with +4-10% umbral damage (rolled). The essence is the only " +
			"cost — enchanting never destroys gear.", DIM)
	var ess_count := 0
	for e in essences:
		ess_count += int(e.get("qty", 1))
	_line("Essences in bag: %d  (Abyssal Remnants drop from abyssal kills — 8%%)" %
			ess_count, CYAN, 11)
	if _ench_msg != "":
		_line(_ench_msg, EMBER, 11)
	if essences.is_empty():
		_line("no essences — hunt Gloamfen Stalkers.", DIM)
		return
	var any := false
	for entry in _gear_list():
		var it: Dictionary = entry[0]
		if not ProtoItems.can_enchant(it):
			continue
		any = true
		var b := _btn(_panel_body, "%s · tier +%d (%s)" % [_iname(it),
				int(it.get("upgrade_tier", 0)), str(entry[1])],
				_ench_pick.bind(int(it.get("uid", -1))))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 10)
		b.add_theme_color_override("font_color",
				ProtoItems.rarity_color(str(it.get("rarity", "common"))))
	if not any:
		_line("no enchantable gear (weapon/amulet) owned.", DIM)
		return
	var item := _find_gear(_ench_uid)
	if item.is_empty() or not ProtoItems.can_enchant(item):
		return
	_header(_iname(item))
	var en: Variant = item.get("enchant")
	if en is Dictionary and not (en as Dictionary).is_empty():
		_line("current enchant: +%.0f %s — a new essence REPLACES it" % [
				float(en.get("value", 0)),
				ProtoItems.stat_name(str(en.get("stat", "?")))], PALE, 11)
	else:
		_line("no enchant yet.", PALE, 11)
	var b2 := _btn(_panel_body, "APPLY ESSENCE (+4-10% umbral)", _ench_do)
	b2.add_theme_color_override("font_color", CYAN)

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
	_ench_msg = "enchanted %s: +%d %s." % [_iname(item), int(en.value),
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

func _show_vendor() -> void:
	_open("Vendor — sell loot")
	_line("Prices scale with rarity and forge tier (proposal). Player-to-player " +
			"trade is the WEB-ONLY marketplace later (docs/design/15) — never in " +
			"the mobile apps.", DIM)
	_line("Gold: %d" % Session.gold, GOLD, 11)
	# message line ALWAYS renders so rows never shift under the cursor mid-spree
	_line(_vendor_msg if _vendor_msg != "" else " ", EMBER, 11)
	_header("Stable-master — mounts (proposal)")
	if Session.owns_mount("gloam_strider"):
		_line("Gloam Strider owned — manage mounts in CHARACTER → Mounts; ride with M.",
				DIM)
	else:
		var mb := _btn(_panel_body,
				"buy GLOAM STRIDER — walking mount, x1.6 speed — 400 gold", _buy_strider)
		mb.add_theme_color_override("font_color", CYAN)
		mb.disabled = Session.gold < 400
	if not Session.owns_mount("emberwing_drakeling"):
		_line("a FLYING mount is not for sale — the Matriarch's brood bonds only " +
				"with whoever fells her.", DIM, 9)
	_header("Buyback — sell loot")
	if Session.inventory.is_empty():
		_line("the bag is empty.", DIM)
		return
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
		var sa := _btn(chips, "all %s (%d) — %dg" % [rar, uids.size(), total],
				_sell_all.bind(uids))
		sa.add_theme_font_size_override("font_size", 9)
		sa.add_theme_color_override("font_color", ProtoItems.rarity_color(rar))
	for it in Session.inventory:
		var qty := int(it.get("qty", 1))
		var b := _btn(_panel_body, "sell %s%s — %d gold" % [_iname(it),
				" x%d" % qty if qty > 1 else "", ProtoItems.sell_price(it) * qty],
				_vendor_sell.bind(int(it.get("uid", -1))))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.icon = ProtoSprites.item_icon(str(it.get("sprite_key", "sword")),
				str(it.get("rarity", "common")))
		b.add_theme_font_size_override("font_size", 10)
		b.add_theme_color_override("font_color",
				ProtoItems.rarity_color(str(it.get("rarity", "common"))))

func _buy_strider() -> void:
	if Session.gold < 400 or Session.owns_mount("gloam_strider"):
		return
	Session.gold -= 400
	Session.grant_mount({"uid": ProtoItems.next_uid(), "key": "gloam_strider",
			"name": "Gloam Strider", "kind": "walk", "speed_mult": 1.6,
			"rarity": "rare", "tint": "9ecbe8"})
	_vendor_msg = "the Gloam Strider is yours — press M on the hunt to ride."
	_refresh_stats()
	_show_vendor()

# ---- CHEST: the Haven stash (Ricardo) — bag <-> chest, big capacity ---------------

func _show_chest() -> void:
	_open("Chest — %d/%d stored  ·  bag %d/%d" % [Session.stash.size(),
			Session.STASH_CAP, Session.inventory.size(), ProtoItems.INVENTORY_CAP])
	_line("Store loot between hunts — enchants, tiers and stacks travel whole. " +
			"The chest lives at the Haven (proposal).", DIM)
	_header("Bag → store")
	if Session.inventory.is_empty():
		_line("the bag is empty.", DIM)
	for it in Session.inventory:
		_chest_row(it, "store %s%s", _chest_store)
	_header("Chest → take")
	if Session.stash.is_empty():
		_line("the chest is empty.", DIM)
	for it in Session.stash:
		_chest_row(it, "take %s%s", _chest_take)

func _chest_row(it: Dictionary, fmt: String, cb: Callable) -> void:
	var qty := int(it.get("qty", 1))
	var b := _btn(_panel_body, fmt % [_iname(it), " x%d" % qty if qty > 1 else ""],
			cb.bind(int(it.get("uid", -1))))
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.icon = ProtoSprites.item_icon(str(it.get("sprite_key", "sword")),
			str(it.get("rarity", "common")))
	b.add_theme_font_size_override("font_size", 10)
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
	_open("Codex — every effect in the game")
	var data: Dictionary = Session.load_content("effects")
	_line("Statuses, conditions, mechanics, enchantments, affixes and fields — " +
			"one expandable registry (prototype/data/effects.json ← " +
			"content/core/registries/effects.json). [planned] = designed, not yet " +
			"in the slice.", DIM)
	for group in data.get("groups", []):
		_header(str(group.get("name", "?")))
		for e in group.get("entries", []):
			var live := str(e.get("status", "live")) == "live"
			_line("- %s — %s%s" % [str(e.get("name", "?")), str(e.get("desc", "")),
					"" if live else "  [planned]"], PALE if live else DIM, 10)

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
	_vendor_msg = "sold %d items for %d gold." % [n, got]
	_refresh_stats()
	_show_vendor()

func _vendor_sell(uid: int) -> void:
	var it := Session.find_item(uid)
	if it.is_empty():
		return
	Session.remove_item(uid)
	var price := ProtoItems.sell_price(it) * int(it.get("qty", 1))
	Session.gold += price
	_vendor_msg = "sold %s for %d gold." % [_iname(it), price]
	_refresh_stats()
	_show_vendor()
