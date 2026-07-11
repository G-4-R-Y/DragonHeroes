# PROTOTYPE HARNESS — character panel (C/Tab): equipment, the inventory grid
# (REAL item instances from items.gd, rarity-bordered icons), REAL attribute
# allocation, skills with rune sockets (canon §4), and the 3-slot pet roster.
# Everything binds to the Session autoload so the panel works mid-hunt AND in
# the Haven; the shipping panel binds to replicated dh-sim character state
# instead (docs/tech/22). Pauses nothing — the hunt keeps running.
class_name ProtoCharacterPanel
extends CanvasLayer

const EMBER := Color("ff9a3c")
const GOLD := Color("ffd166")
const PALE := Color("d9d4c7")
const DIM := Color(0.62, 0.6, 0.55)
const VIOLET := Color("cf9dff")
const CYAN := Color("7fe7ff")
const GREEN := Color("58c470")
const RED := Color("ff8a7a")

# attribute effects per allocated point (stats.gd proposals)
const ATTR_FX := {
	"might": "+2% melee dmg", "agility": "+1% move, +2% dodge rchg",
	"intellect": "+2% skill dmg", "vitality": "+6 max HP",
	"willpower": "+1% resist, +2% status res",
}
const SKILL_SOCKETS := ["cleave", "rend", "dodge"]

const RARITY_ORDER := {"common": 0, "uncommon": 1, "rare": 2, "epic": 3, "legendary": 4}

var _boxes := {}          # tab name -> VBoxContainer
var _sel_uid := -1        # selected bag item uid
var _sel_slot := ""       # selected equipment slot
var _bag_filter := "all"  # all | gear | rune | material
var _socket_for := ""     # skill whose rune chooser is open

func _ready() -> void:
	layer = 4
	visible = false
	var panel := PanelContainer.new()
	panel.theme = ProtoTheme.get_theme()
	panel.position = Vector2(8, 8)
	panel.size = Vector2(312, 344)   # left half of the 640x360 viewport
	add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 4)
	panel.add_child(root)
	# title bar: the panel closes from ANY scene — ×, Esc, C or Tab (Haven bug fix)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	root.add_child(bar)
	var title := Label.new()
	title.text = "CHARACTER"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", EMBER)
	bar.add_child(title)
	var hint := Label.new()
	hint.text = "Esc / C close"
	hint.add_theme_font_size_override("font_size", 8)
	hint.add_theme_color_override("font_color", DIM)
	bar.add_child(hint)
	var x := Button.new()
	x.text = "×"
	x.focus_mode = Control.FOCUS_NONE
	x.custom_minimum_size = Vector2(22, 20)
	x.pressed.connect(func() -> void: visible = false)
	bar.add_child(x)
	var tabs := TabContainer.new()
	tabs.focus_mode = Control.FOCUS_NONE
	tabs.get_tab_bar().focus_mode = Control.FOCUS_NONE
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(tabs)
	for tab_name in ["Gear", "Bag", "Attributes", "Skills", "Pets", "Mounts"]:
		var scroll := ScrollContainer.new()
		scroll.name = tab_name
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		tabs.add_child(scroll)
		var vb := VBoxContainer.new()
		vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vb.add_theme_constant_override("separation", 4)
		scroll.add_child(vb)
		_boxes[tab_name] = vb

func toggle() -> void:
	visible = not visible
	if visible:
		refresh()

# The panel owns its close/toggle keys so it works at the Haven too — the v4 bug
# was main.gd owning them, and main only exists during hunts.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_character"):
		toggle()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("ui_cancel"):
		visible = false
		get_viewport().set_input_as_handled()

func refresh() -> void:
	_refresh_gear()
	_refresh_bag()
	_refresh_attributes()
	_refresh_skills()
	_refresh_pets()
	_refresh_mounts()

# ---- small UI kit ----------------------------------------------------------------

func _clear(vb: Container) -> void:
	for c in vb.get_children():
		vb.remove_child(c)
		c.queue_free()

func _line(vb: Container, text: String, color := PALE, font_size := 10) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	vb.add_child(l)
	return l

func _btn(parent: Container, text: String, cb: Callable, color := PALE) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 10)
	b.add_theme_color_override("font_color", color)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

func _iname(item: Dictionary) -> String:
	var t := int(item.get("upgrade_tier", 0))
	return str(item.get("name", "?")) + (" +%d" % t if t > 0 else "")

func _rcolor(item: Dictionary) -> Color:
	return ProtoItems.rarity_color(str(item.get("rarity", "common")))

func _icon(item: Dictionary) -> Texture2D:
	return ProtoSprites.item_icon(str(item.get("sprite_key", "sword")),
			str(item.get("rarity", "common")))

func _pretty_id(content_id: String) -> String:
	return content_id.get_slice(".", 2).capitalize()

func _main() -> Node:
	return get_tree().get_first_node_in_group("main")

# Gold lives in main during a hunt (synced to Session), in Session at the Haven.
func _gold() -> int:
	var m := _main()
	return m.gold if m else Session.gold

func _add_gold(amount: int) -> void:
	var m := _main()
	if m:
		m.add_gold(amount)
	else:
		Session.gold += amount

# Equip/allocate/socket changes re-apply the live StatBlock mid-hunt.
func _apply_live() -> void:
	var p := get_tree().get_first_node_in_group("player")
	if p:
		p.apply_stats()
	var m := _main()
	if m:
		m.refresh_hud()

# ---- Gear tab ----------------------------------------------------------------------

func _refresh_gear() -> void:
	var vb: VBoxContainer = _boxes["Gear"]
	_clear(vb)
	_line(vb, "%s — %s, level %d" % [Session.player_name, Session.class_display(),
			Session.level], EMBER, 12)
	var s := ProtoStats.compute(Session)
	for sl in ProtoStats.summary_lines(s):
		_line(vb, sl, DIM, 9)
	for slot in ProtoItems.GEAR_SLOTS:
		var it: Dictionary = Session.equipment[slot]
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 10)
		if it.is_empty():
			b.text = "%s — empty" % str(slot).capitalize()
			b.add_theme_color_override("font_color", DIM)
		else:
			b.icon = _icon(it)
			b.text = "%s — %s · pw %d" % [str(slot).capitalize(), _iname(it),
					ProtoItems.power(it)]
			b.add_theme_color_override("font_color", _rcolor(it))
			b.tooltip_text = "\n".join(PackedStringArray(ProtoItems.describe(it)))
		b.pressed.connect(_select_slot.bind(str(slot)))
		vb.add_child(b)
	if _sel_slot != "":
		var it: Dictionary = Session.equipment.get(_sel_slot, {})
		if not it.is_empty():
			_line(vb, "— %s —" % _iname(it), _rcolor(it), 11)
			_line(vb, "%s %s · sells %d gold" % [str(it.get("rarity", "?")),
					str(it.get("slot", "?")), ProtoItems.sell_price(it)], DIM, 9)
			for d in ProtoItems.describe(it):
				_line(vb, str(d), PALE, 10)
			var hb := HBoxContainer.new()
			hb.add_theme_constant_override("separation", 6)
			vb.add_child(hb)
			_btn(hb, "Unequip", _do_unequip.bind(_sel_slot), GOLD)
			if Session.inventory.size() >= ProtoItems.INVENTORY_CAP:
				_line(vb, "bag full — sell something first", RED, 9)

func _select_slot(slot: String) -> void:
	_sel_slot = "" if _sel_slot == slot else slot
	_refresh_gear()

func _do_unequip(slot: String) -> void:
	if Session.unequip(slot):
		_sel_slot = ""
		_apply_live()
	refresh()

# ---- Bag tab (inventory grid) --------------------------------------------------------

func _refresh_bag() -> void:
	var vb: VBoxContainer = _boxes["Bag"]
	_clear(vb)
	_line(vb, "Bag %d/%d — gold %d" % [Session.inventory.size(),
			ProtoItems.INVENTORY_CAP, _gold()], EMBER, 12)
	if Session.inventory.is_empty():
		_line(vb, "empty — creatures drop gear, essences and (from Elites) runes.", DIM)
		return
	# toolbar: filter chips + one-click sorts (bag organization — Ricardo)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 4)
	vb.add_child(bar)
	for f in [["all", "All"], ["gear", "Gear"], ["rune", "Runes"], ["material", "Mats"]]:
		var fb := Button.new()
		fb.text = str(f[1])
		fb.focus_mode = Control.FOCUS_NONE
		fb.add_theme_font_size_override("font_size", 9)
		if _bag_filter == str(f[0]):
			fb.add_theme_color_override("font_color", GOLD)
		fb.pressed.connect(_set_bag_filter.bind(str(f[0])))
		bar.add_child(fb)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(gap)
	for srt in [["rarity", "rarity"], ["power", "power"], ["slot", "slot"]]:
		var sb2 := Button.new()
		sb2.text = str(srt[1])
		sb2.focus_mode = Control.FOCUS_NONE
		sb2.tooltip_text = "sort the bag by %s" % str(srt[0])
		sb2.add_theme_font_size_override("font_size", 9)
		sb2.add_theme_color_override("font_color", DIM)
		sb2.pressed.connect(_sort_bag.bind(str(srt[0])))
		bar.add_child(sb2)
	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	vb.add_child(grid)
	for it in Session.inventory:
		if not _bag_match(it):
			continue
		var uid := int(it.get("uid", -1))
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(30, 30)
		b.icon = _icon(it)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var qty := int(it.get("qty", 1))
		if qty > 1:   # stacked materials show their count on the tile
			b.text = "x%d" % qty
			b.add_theme_font_size_override("font_size", 8)
		b.tooltip_text = _iname(it) + ("" if qty <= 1 else " x%d" % qty) + "\n" \
				+ "\n".join(PackedStringArray(ProtoItems.describe(it)))
		var selected := uid == _sel_uid
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.16, 0.2, 0.25) if selected else Color(0.09, 0.12, 0.15)
		sb.set_border_width_all(2 if selected else 1)
		sb.border_color = _rcolor(it)   # rarity border (grey/green/blue/purple/orange)
		for st in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, sb)
		b.pressed.connect(_select_bag.bind(uid))
		grid.add_child(b)
	var item := Session.find_item(_sel_uid)
	if not item.is_empty():
		_bag_detail(vb, item)

func _select_bag(uid: int) -> void:
	_sel_uid = -1 if _sel_uid == uid else uid
	_refresh_bag()

func _set_bag_filter(f: String) -> void:
	_bag_filter = f
	_refresh_bag()

func _bag_match(it: Dictionary) -> bool:
	match _bag_filter:
		"gear":
			return ProtoItems.GEAR_SLOTS.has(str(it.get("slot", "")))
		"rune", "material":
			return str(it.get("slot", "")) == _bag_filter
	return true

# In-place sort of the real inventory (persists): rarity/power desc, slot alpha.
func _sort_bag(key: String) -> void:
	Session.inventory.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		match key:
			"rarity":
				return int(RARITY_ORDER.get(str(a.get("rarity", "common")), 0)) \
						> int(RARITY_ORDER.get(str(b.get("rarity", "common")), 0))
			"power":
				return ProtoItems.power(a) > ProtoItems.power(b)
		return str(a.get("slot", "")) < str(b.get("slot", "")))
	Session.request_save()
	_refresh_bag()

# Inspect popup: affixes, enchant, vs-equipped stat diff, equip/sell actions.
func _bag_detail(vb: VBoxContainer, item: Dictionary) -> void:
	_line(vb, "— %s —" % _iname(item), _rcolor(item), 11)
	_line(vb, "%s %s" % [str(item.get("rarity", "?")), str(item.get("slot", "?"))], DIM, 9)
	var slot := str(item.get("slot", ""))
	var equipped: Dictionary = Session.equipment.get(slot, {}) \
			if ProtoItems.GEAR_SLOTS.has(slot) else {}
	if equipped.is_empty() or int(equipped.get("uid", -1)) == int(item.get("uid", -2)):
		for d in ProtoItems.describe(item):
			_line(vb, str(d), PALE, 10)
	else:
		# side-by-side comparison: the pick vs what you're wearing
		var cols := HBoxContainer.new()
		cols.add_theme_constant_override("separation", 10)
		vb.add_child(cols)
		for pair in [[item, "SELECTED"], [equipped, "EQUIPPED"]]:
			var it2: Dictionary = pair[0]
			var col := VBoxContainer.new()
			col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			col.add_theme_constant_override("separation", 1)
			cols.add_child(col)
			var head := Label.new()
			head.text = str(pair[1])
			head.add_theme_font_size_override("font_size", 8)
			head.add_theme_color_override("font_color", DIM)
			col.add_child(head)
			var nm := Label.new()
			nm.text = "%s · pw %d" % [_iname(it2), ProtoItems.power(it2)]
			nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			nm.add_theme_font_size_override("font_size", 9)
			nm.add_theme_color_override("font_color", _rcolor(it2))
			col.add_child(nm)
			for d in ProtoItems.describe(it2):
				var dl := Label.new()
				dl.text = str(d)
				dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				dl.add_theme_font_size_override("font_size", 8)
				dl.add_theme_color_override("font_color", PALE)
				col.add_child(dl)
	if ProtoItems.GEAR_SLOTS.has(slot):
		# vs-equipped diff: stats.gd on a hypothetical loadout with this item in
		var hypo: Dictionary = Session.equipment.duplicate()
		hypo[slot] = item
		var cur := ProtoStats.compute(Session)
		var alt := ProtoStats.compute(Session, hypo)
		var rows := [["max HP", "max_hp", 1.0], ["melee dmg", "melee_damage", 1.0],
				["rend dmg", "rend_damage", 1.0], ["crit %", "crit_chance", 100.0],
				["move %", "move_speed_mult", 100.0], ["armor", "armor", 1.0],
				["resist %", "resist_pct", 100.0]]
		var any := false
		for r in rows:
			var d: float = (float(alt[r[1]]) - float(cur[r[1]])) * float(r[2])
			if absf(d) < 0.05:
				continue
			any = true
			_line(vb, "  %s %+.1f vs equipped" % [r[0], d], GREEN if d > 0.0 else RED, 9)
		if not any:
			_line(vb, "  no stat change vs equipped", DIM, 9)
	elif slot == "rune":
		_line(vb, "socket it on a skill — Skills tab", VIOLET, 9)
	elif slot == "material":
		_line(vb, "spend it at the Haven ENCHANTER", CYAN, 9)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	vb.add_child(hb)
	if ProtoItems.GEAR_SLOTS.has(slot):
		_btn(hb, "Equip", _do_equip.bind(int(item.get("uid", -1))), GOLD)
	_btn(hb, "Sell %d g" % (ProtoItems.sell_price(item) * int(item.get("qty", 1))),
			_do_sell.bind(int(item.get("uid", -1))))

func _do_equip(uid: int) -> void:
	if Session.equip(uid):
		_sel_uid = -1
		_apply_live()
	refresh()

func _do_sell(uid: int) -> void:
	var item := Session.find_item(uid)
	if item.is_empty():
		return
	Session.remove_item(uid)
	_add_gold(ProtoItems.sell_price(item) * int(item.get("qty", 1)))
	_sel_uid = -1
	var m := _main()
	if m:
		m.play_ui("pickup", -12.0)
	refresh()

# ---- Attributes tab (REAL allocation) --------------------------------------------------

func _refresh_attributes() -> void:
	var vb: VBoxContainer = _boxes["Attributes"]
	_clear(vb)
	_line(vb, "Attributes — unspent points: %d" % Session.attribute_points, EMBER, 12)
	_line(vb, ("Allocation is REAL (stats.gd): +5 points per level, 1 level per " +
			"20 kills (proposal). Prototype allows refunds down to base %d.") % [
			Session.BASE_ATTRIBUTE], DIM, 9)
	for attr in Session.ATTRIBUTES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		vb.add_child(row)
		var nl := Label.new()
		nl.text = "%s  (%s)" % [str(attr).capitalize(), ATTR_FX[attr]]
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nl.add_theme_font_size_override("font_size", 9)
		nl.add_theme_color_override("font_color", PALE)
		row.add_child(nl)
		var vl := Label.new()
		vl.text = str(Session.attributes[attr])
		vl.add_theme_font_size_override("font_size", 11)
		vl.add_theme_color_override("font_color", GOLD)
		row.add_child(vl)
		var minus := Button.new()
		minus.text = "-"
		minus.focus_mode = Control.FOCUS_NONE
		minus.custom_minimum_size = Vector2(22, 0)
		minus.pressed.connect(_adjust_attribute.bind(str(attr), -1))
		row.add_child(minus)
		var plus := Button.new()
		plus.text = "+"
		plus.focus_mode = Control.FOCUS_NONE
		plus.custom_minimum_size = Vector2(22, 0)
		plus.pressed.connect(_adjust_attribute.bind(str(attr), 1))
		row.add_child(plus)

# REALLY spends Session points; the live StatBlock re-applies immediately.
func _adjust_attribute(attr: String, delta: int) -> void:
	if delta > 0 and Session.attribute_points <= 0:
		return
	if delta < 0 and int(Session.attributes[attr]) <= Session.BASE_ATTRIBUTE:
		return
	Session.attributes[attr] = int(Session.attributes[attr]) + delta
	Session.attribute_points -= delta
	_apply_live()
	_refresh_attributes()
	_refresh_gear()
	_refresh_skills()

# ---- Skills tab (numbers + rune sockets) -------------------------------------------------

func _refresh_skills() -> void:
	var vb: VBoxContainer = _boxes["Skills"]
	_clear(vb)
	var s := ProtoStats.compute(Session)
	var m := _main()
	var owns_rend: bool = Session.stones >= 1 or (m != null and m.stones >= 1)
	_line(vb, "Skills — %s" % Session.class_display(), EMBER, 12)
	match str(s.get("class_kit", "melee")):   # each class wears its own kit
		"mage":
			_skill_card(vb, "cleave", "Arcane Bolt  (LMB)", Color("b48cff"),
					"%d dmg · %.2f s cd · ranged umbral bolt · crit %d%%" % [
					int(round(s.melee_damage * 0.9)), 0.55 / s.attack_speed_mult,
					int(s.crit_chance * 100.0)])
			_skill_card(vb, "", "Frost Nova  (E)", Color("9fd4ff"),
					"%d dmg · 5 s cd · 2.8 m radial · hard Chill" % [
					int(round(s.melee_damage * 0.7 * s.skill_damage_mult))])
		"rogue":
			_skill_card(vb, "cleave", "Swift Stab  (LMB)", PALE,
					"%d dmg · %.2f s cd · 60 deg · 1.8 m · crit %d%%" % [
					int(round(s.melee_damage * 0.8)), 0.25 / s.attack_speed_mult,
					int(s.crit_chance * 100.0)])
			_skill_card(vb, "", "Fan of Knives  (E)", Color("cdd6dd"),
					"5 x %d dmg · 4.5 s cd · piercing steel fan" % [
					int(round(s.melee_damage * 0.5))])
		_:
			_skill_card(vb, "cleave", "Cleave  (LMB)", PALE,
					"%d dmg · %.2f s cd · 110 deg · 2.2 m · crit %d%%" % [
					int(round(s.melee_damage)), 0.4 / s.attack_speed_mult,
					int(s.crit_chance * 100.0)])
			_skill_card(vb, "", "Whirlwind  (E)", Color("9fd4ff"),
					"%d dmg · 4 s cd · full circle · 2.6 m + shove" % [
					int(round(s.melee_damage * 0.8))])
	_skill_card(vb, "rend", "Shadow Rend  (Q)", VIOLET,
			"%d dmg · 5 s cd · 130 deg · 2.2 m — umbral" % int(round(s.rend_damage)),
			not owns_rend)
	_skill_card(vb, "dodge", "Dodge  (Shift)", CYAN,
			"4 m dash · 3 charges · %.2f s recharge — no i-frames" % s.dodge_recharge_s)
	if not owns_rend:
		_line(vb, "Shadow Rend awakens with a Bestial Skill stone (the first pack drops one).",
				DIM, 9)
	if _socket_for != "":
		_socket_chooser(vb)
	# ---- the class skill tree (skill_trees.json): learn + assign to keys 1-4 -----
	_line(vb, "%s tree — skill points: %d (1 per level)" % [Session.class_display(),
			Session.skill_points], EMBER, 11)
	# hotbar chips: what 1-4 cast right now (click a filled chip to clear it)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 4)
	vb.add_child(bar)
	for i in 4:
		var d := Session.skill_def(str(Session.skill_loadout[i]))
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 9)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if d.is_empty():
			b.text = "%d · —" % (i + 1)
			b.add_theme_color_override("font_color", DIM)
			b.tooltip_text = "empty — learn an active below, then tap its %d chip" % (i + 1)
		else:
			b.text = "%d · %s" % [i + 1, str(d.get("name", "?"))]
			b.add_theme_color_override("font_color", GOLD)
			b.tooltip_text = "casts on key %d — click to clear the slot" % (i + 1)
			b.pressed.connect(_do_assign.bind(i, ""))
		bar.add_child(b)
	var charge := Session.class_charge()
	if not charge.is_empty():
		_line(vb, "◈ %s — %s" % [str(charge.get("name", "")),
				str(charge.get("desc", ""))], VIOLET, 8)
	for br in Session.class_branches():
		var nodes: Array = br.get("nodes", [])
		if nodes.size() == 1 and int(nodes[0].get("cost", 1)) <= 0:
			continue   # the free root branch needs no rows
		_line(vb, "— %s —" % str(br.get("name", "?")), EMBER, 10)
		for node in nodes:
			_tree_node_row(vb, node, s)
	_line(vb, "◆ active (assign to 1-4) · ○ passive · ⟡ synergy — hover any node " +
			"for numbers. Runes drop from Elites — click a socket chip to slot one.",
			DIM, 8)

# One tree node = one compact row: state glyph + name (tooltip carries desc,
# synergy and live numbers — no text walls), then Learn or the 1-4 assign chips.
func _tree_node_row(vb: Container, node: Dictionary, s: Dictionary) -> void:
	var id := str(node.get("id", ""))
	var cost := int(node.get("cost", 1))
	if cost <= 0:
		return   # free roots aren't rows
	var learned := Session.def_learned(node)
	var reqs_met := true
	var req_names: Array[String] = []
	for r in node.get("requires", []):
		var rdef := Session.skill_def(str(r))
		if not (Session.node_learned(str(r)) \
				or (not rdef.is_empty() and Session.def_learned(rdef))):
			reqs_met = false
			req_names.append(str(rdef.get("name", r)))
	var lvl_ok := Session.level >= int(node.get("min_level", 1))
	var active := str(node.get("type", "")) == "active"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	vb.add_child(row)
	var name_l := Label.new()
	name_l.text = "%s %s%s" % ["◆" if active else "○", str(node.get("name", "?")),
			"  ⟡" if node.has("synergy") else ""]
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.add_theme_font_size_override("font_size", 10)
	name_l.mouse_filter = Control.MOUSE_FILTER_STOP   # labels need this for tooltips
	name_l.tooltip_text = _node_tooltip(node, s)
	if learned:
		name_l.add_theme_color_override("font_color", GOLD)
	elif reqs_met and lvl_ok:
		name_l.add_theme_color_override("font_color", PALE)
	else:
		name_l.add_theme_color_override("font_color", DIM)
	row.add_child(name_l)
	if learned and active:   # assign chips: 1-4, gold = currently in that slot
		for i in 4:
			var here := str(Session.skill_loadout[i]) == id
			var ab := Button.new()
			ab.text = str(i + 1)
			ab.focus_mode = Control.FOCUS_NONE
			ab.custom_minimum_size = Vector2(20, 0)
			ab.add_theme_font_size_override("font_size", 8)
			ab.add_theme_color_override("font_color", GOLD if here else DIM)
			ab.tooltip_text = "assign %s to slot %d" % [str(node.get("name", "?")), i + 1]
			ab.pressed.connect(_do_assign.bind(i, "" if here else id))
			row.add_child(ab)
	elif not learned:
		if reqs_met and lvl_ok and Session.skill_points >= cost:
			var lb := _btn(row, "Learn (%d pt)" % cost, _do_learn.bind(id, cost), GOLD)
			lb.tooltip_text = "learn " + id
		else:
			var why := "%d pt" % cost
			if not reqs_met:
				why = "needs " + ", ".join(req_names)
			elif not lvl_ok:
				why = "level %d" % int(node.get("min_level", 1))
			var lk := Label.new()
			lk.text = why
			lk.add_theme_font_size_override("font_size", 8)
			lk.add_theme_color_override("font_color", DIM)
			row.add_child(lk)

# Tooltip: desc + synergy line + LIVE numbers (dmg from the current StatBlock).
func _node_tooltip(node: Dictionary, s: Dictionary) -> String:
	var lines: Array[String] = [str(node.get("desc", ""))]
	if node.has("synergy"):
		lines.append("⟡ " + str(node.get("synergy")))
	var p: Dictionary = node.get("params", {})
	var kind := str(node.get("kind", ""))
	if str(node.get("type", "")) == "active":
		var dmg: float = s.melee_damage * float(p.get("mult", 1.0))
		if not kind in ["melee_arc", "dash_strike"]:
			dmg *= s.skill_damage_mult
		var bits: Array[String] = [kind.replace("_", " ")]
		if not kind in ["buff", "field"]:
			bits.append("~%d dmg" % int(round(dmg)))
		if p.has("count"):
			bits.append("x%d" % int(p.get("count")))
		if p.has("jumps"):
			bits.append("%d jumps" % int(p.get("jumps")))
		if p.has("radius"):
			bits.append("%.1f m" % float(p.get("radius")))
		if p.has("reach"):
			bits.append("%.1f m" % float(p.get("reach")))
		if p.has("duration"):
			bits.append("%.0f s" % float(p.get("duration")))
		bits.append("%.1f s cd" % (float(p.get("cd", 6.0))
				* float(s.get("cdr_mult", 1.0))))
		lines.append(" · ".join(bits))
	else:
		var mods: Array[String] = []
		for m in node.get("stat_mods", []):
			mods.append("%s %+d" % [str(m.get("stat", "?")).replace("_", " "),
					int(m.get("value", 0))])
		if not mods.is_empty():
			lines.append(" · ".join(mods))
	lines.append("min level %d · cost %d pt" % [int(node.get("min_level", 1)),
			int(node.get("cost", 1))])
	return "\n".join(lines)

func _do_assign(slot: int, id: String) -> void:
	Session.assign_skill(slot, id)
	_refresh_skills()

# One skill = one card: name + live numbers + the rune-socket chip on the right.
func _skill_card(vb: Container, skill_key: String, title: String, color: Color,
		numbers: String, locked := false) -> void:
	var card := PanelContainer.new()
	vb.add_child(card)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	card.add_child(hb)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 1)
	hb.add_child(left)
	var t := Label.new()
	t.text = title + ("   [locked]" if locked else "")
	t.add_theme_font_size_override("font_size", 11)
	t.add_theme_color_override("font_color", DIM if locked else color)
	left.add_child(t)
	var nums := Label.new()
	nums.text = numbers
	nums.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nums.add_theme_font_size_override("font_size", 9)
	nums.add_theme_color_override("font_color", DIM)
	left.add_child(nums)
	if skill_key != "" and not locked:
		var r: Dictionary = Session.skill_runes.get(skill_key, {})
		var sb := Button.new()
		sb.focus_mode = Control.FOCUS_NONE
		sb.add_theme_font_size_override("font_size", 9)
		sb.custom_minimum_size = Vector2(96, 0)
		if r.is_empty():
			sb.text = "◇ socket rune"
			sb.add_theme_color_override("font_color", DIM)
		else:
			sb.text = "◆ %s" % str(r.get("name", "?")).replace("Rune of ", "").replace("the ", "")
			sb.add_theme_color_override("font_color", VIOLET)
			sb.tooltip_text = str(ProtoItems.rune_def(
					str(r.get("rune_key", ""))).get("desc", ""))
		sb.pressed.connect(_open_socket_chooser.bind(skill_key))
		hb.add_child(sb)

# Chooser: opened from a card's socket chip; lists bag runes + remove option.
func _socket_chooser(vb: VBoxContainer) -> void:
	var r: Dictionary = Session.skill_runes.get(_socket_for, {})
	_line(vb, "— socket on %s —" % _socket_for.capitalize(), VIOLET, 10)
	if not r.is_empty():
		_btn(vb, "remove ◆ %s" % str(r.get("name", "?")), _do_unsocket_pick, RED)
	var any := false
	for it in Session.inventory:
		if str(it.get("slot", "")) != "rune":
			continue
		any = true
		_btn(vb, "◆ %s — %s" % [str(it.get("name", "?")), str(ProtoItems.rune_def(
				str(it.get("rune_key", ""))).get("desc", ""))],
				_do_socket_pick.bind(int(it.get("uid", -1))), VIOLET)
	if not any and r.is_empty():
		_line(vb, "no runes in the bag — Elites drop them.", DIM, 9)

func _open_socket_chooser(skill: String) -> void:
	_socket_for = "" if _socket_for == skill else skill
	_refresh_skills()

func _do_socket_pick(uid: int) -> void:
	if Session.socket_rune(_socket_for, uid):
		_apply_live()
	_socket_for = ""
	refresh()

func _do_unsocket_pick() -> void:
	if Session.unsocket_rune(_socket_for):
		_apply_live()
	_socket_for = ""
	refresh()

func _do_learn(node: String, cost := 1) -> void:
	if Session.learn_node(node, cost):   # spends the points + saves; effects are live
		_apply_live()
	refresh()

func _do_socket(skill: String, uid: int) -> void:
	if Session.socket_rune(skill, uid):
		_apply_live()
	refresh()

func _do_unsocket(skill: String) -> void:
	if Session.unsocket_rune(skill):
		_apply_live()
	refresh()

# ---- Pets tab (3 slots, canon §3) ----------------------------------------------------------

func _refresh_pets() -> void:
	var vb: VBoxContainer = _boxes["Pets"]
	_clear(vb)
	_line(vb, "Pets — %d/%d bonded" % [Session.pets.size(), Session.MAX_PETS], EMBER, 12)
	if Session.pets.is_empty():
		_line(vb, "none bonded — weaken a Gloamfen Stalker below 35% HP and press F " +
				"with a Soul Snare (stalkers drop them)", DIM)
	for pet in Session.pets:
		var resting := false
		for n in get_tree().get_nodes_in_group("pet"):
			if n.uid == int(pet.get("uid", 0)):
				resting = n.resting()
		var card := PanelContainer.new()
		vb.add_child(card)
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 1)
		card.add_child(cv)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 6)
		cv.add_child(hb)
		var nl := Label.new()
		nl.text = "%s   %s" % [str(pet.get("name", "?")),
				"· resting" if resting else "· on the hunt"]
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nl.add_theme_font_size_override("font_size", 11)
		nl.add_theme_color_override("font_color",
				Color("ff8a7a") if resting else CYAN)
		hb.add_child(nl)
		_btn(hb, "→ stables", _do_stable.bind(int(pet.get("uid", 0))))
		var skills: Array[String] = []
		for sk in pet.get("skills", []):
			skills.append(_pretty_id(str(sk)))
		var det := Label.new()
		det.text = "roll %d%%  ·  %s" % [int(pet.get("roll_pct", 100)),
				" · ".join(skills)]
		det.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		det.add_theme_font_size_override("font_size", 9)
		det.add_theme_color_override("font_color", PALE)
		cv.add_child(det)
	# The stables (Ricardo: pets are NEVER abandoned) — overflow captures land here.
	if not Session.stables.is_empty():
		_line(vb, "STABLES — %d resting" % Session.stables.size(), EMBER, 11)
		var room := Session.pets.size() < Session.MAX_PETS
		for pet in Session.stables:
			var card := PanelContainer.new()
			vb.add_child(card)
			var hb := HBoxContainer.new()
			hb.add_theme_constant_override("separation", 6)
			card.add_child(hb)
			var skills: Array[String] = []
			for sk in pet.get("skills", []):
				skills.append(_pretty_id(str(sk)))
			var nl := Label.new()
			nl.text = "%s\nroll %d%%  ·  %s" % [str(pet.get("name", "?")),
					int(pet.get("roll_pct", 100)), " · ".join(skills)]
			nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			nl.add_theme_font_size_override("font_size", 9)
			nl.add_theme_color_override("font_color", PALE)
			hb.add_child(nl)
			var b := _btn(hb, "make active", _do_activate.bind(int(pet.get("uid", 0))), CYAN)
			b.disabled = not room
			if not room:
				b.tooltip_text = "active pack is full — stable one first"
	_line(vb, "Overflow captures STABLE the oldest bond — pets are never abandoned " +
			"and never die (they rest 15 s, and respawn with you).", DIM, 9)

func _do_stable(uid: int) -> void:
	for pet in Session.pets:
		if int(pet.get("uid", 0)) == uid:
			Session.pets.erase(pet)
			Session.stables.append(pet)
			break
	Session.request_save()
	_sync_hunt_pets()
	_refresh_pets()

func _do_activate(uid: int) -> void:
	if Session.pets.size() >= Session.MAX_PETS:
		return
	for pet in Session.stables:
		if int(pet.get("uid", 0)) == uid:
			Session.stables.erase(pet)
			Session.pets.append(pet)
			break
	Session.request_save()
	_sync_hunt_pets()
	_refresh_pets()

# ---- Mounts tab (walking + flying — Ricardo, proposals) ----------------------------

func _refresh_mounts() -> void:
	var vb: VBoxContainer = _boxes["Mounts"]
	_clear(vb)
	_line(vb, "Mounts — press M on the hunt to ride", EMBER, 12)
	if Session.mounts.is_empty():
		_line(vb, "none owned — the Haven VENDOR sells the Gloam Strider (walking); " +
				"a FLYING drakeling is said to nest with the Emberwing Matriarch.", DIM)
		return
	for m in Session.mounts:
		var active := int(m.get("uid", -1)) == Session.active_mount
		var flying := str(m.get("kind", "")) == "fly"
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 6)
		vb.add_child(hb)
		var nl := Label.new()
		nl.text = "%s — %s · x%.1f speed%s" % [str(m.get("name", "?")),
				"FLYING" if flying else "walking", float(m.get("speed_mult", 1.0)),
				"   ← active" if active else ""]
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nl.add_theme_font_size_override("font_size", 10)
		nl.add_theme_color_override("font_color",
				ProtoItems.rarity_color(str(m.get("rarity", "common"))))
		hb.add_child(nl)
		if not active:
			_btn(hb, "select", _do_select_mount.bind(int(m.get("uid", -1))), CYAN)
	_line(vb, "Walking mounts respect terrain; FLYING mounts cross water and rock " +
			"(land on solid ground). Attacking or taking damage dismounts you.", DIM, 9)

func _do_select_mount(uid: int) -> void:
	Session.active_mount = uid
	Session.request_save()
	_refresh_mounts()

# Mid-hunt swaps respawn the live pet nodes; at the Haven this is a no-op.
func _sync_hunt_pets() -> void:
	var m := _main()
	if m and m.has_method("sync_pet_nodes"):
		m.sync_pet_nodes()
