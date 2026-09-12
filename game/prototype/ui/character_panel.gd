# PROTOTYPE HARNESS — character panel (C/Tab): equipment, the inventory grid
# (REAL item instances from items.gd, rarity-bordered icons), REAL attribute
# allocation, the VISUAL class skill tree (branch lanes + drawn prerequisite
# connectors + a fixed detail card; canon §12.21), rune sockets (canon §4), and
# the 3-slot pet roster. Everything binds to the Session autoload so the panel
# works mid-hunt AND in the Haven; the shipping panel binds to replicated
# dh-sim character state instead (docs/tech/22). Pauses nothing.
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

const SKILL_SOCKETS := ["cleave", "rend", "dodge"]

const RARITY_ORDER := {"common": 0, "uncommon": 1, "rare": 2, "epic": 3, "legendary": 4}

# skill-tree visual language: element accents + status colors (effects registry)
const ELEM_COLORS := {"ember": Color("ff9a3c"), "frost": Color("7fe7ff"),
		"arcane": Color("cf9dff"), "steel": Color("cdd6dd")}
const STATUS_COLORS := {"bleed": Color("ff6b6b"), "ignite": Color("ff9a3c"),
		"chill": Color("7fe7ff"), "expose": Color("cf9dff"), "stagger": Color("ffd166")}
const VS_TO_STATUS := {"bleeding": "bleed", "ignited": "ignite", "chilled": "chill",
		"exposed": "expose", "staggered": "stagger"}
const TREE_W := 264.0     # tree canvas width inside the tab scroll (scrollbar-safe)

var _boxes := {}          # tab name -> VBoxContainer
var _sel_uid := -1        # selected bag item uid
var _sel_slot := ""       # selected equipment slot
var _bag_filter := "all"  # all | gear | rune | material
var _socket_for := ""     # skill whose rune chooser is open
var _sel_node := ""       # selected skill-tree node (detail card)
var _sk_points: Label
var _sk_class: Label
var _sk_charge: Label
var _sk_loadout: HBoxContainer
var _sk_detail: PanelContainer
var _sk_detail_box: VBoxContainer

func _ready() -> void:
	layer = 14   # spec §2.0: above post(5)/damage(6)/HUD(10)/minimap(12)
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
	title.text = ProtoLang.t("cp_title")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", ProtoTheme.SIZE_BODY)
	title.add_theme_color_override("font_color", EMBER)
	bar.add_child(title)
	var hint := Label.new()
	hint.text = ProtoLang.t("cp_close_hint")
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
		if tab_name == "Skills":   # the tree tab owns its layout (fixed header/card)
			tabs.add_child(_build_skills_tab())
			continue
		var scroll := ScrollContainer.new()
		scroll.name = tab_name
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		tabs.add_child(scroll)
		var vb := VBoxContainer.new()
		vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vb.add_theme_constant_override("separation", 4)
		scroll.add_child(vb)
		_boxes[tab_name] = vb
	# tab titles localize; node names stay EN (stable lookups for tests/tools)
	for i in tabs.get_tab_count():
		tabs.set_tab_title(i, ProtoLang.t(
				"tab_" + str(tabs.get_tab_control(i).name).to_lower()))

# Skills tab shell: points header + loadout row pinned on top, the tree in a
# ScrollContainer, and a FIXED detail card pinned at the bottom (not a tooltip).
func _build_skills_tab() -> Control:
	var root := VBoxContainer.new()
	root.name = "Skills"
	root.add_theme_constant_override("separation", 3)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	root.add_child(head)
	_sk_points = Label.new()
	_sk_points.add_theme_font_size_override("font_size", ProtoTheme.SIZE_BODY)
	_sk_points.add_theme_color_override("font_color", GOLD)
	head.add_child(_sk_points)
	_sk_class = Label.new()
	_sk_class.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sk_class.add_theme_font_size_override("font_size", 8)
	_sk_class.add_theme_color_override("font_color", DIM)
	_sk_class.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	head.add_child(_sk_class)
	_sk_charge = Label.new()
	_sk_charge.add_theme_font_size_override("font_size", ProtoTheme.SIZE_BODY)
	_sk_charge.add_theme_color_override("font_color", VIOLET)
	_sk_charge.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_sk_charge.mouse_filter = Control.MOUSE_FILTER_STOP   # hover shows the mechanic
	head.add_child(_sk_charge)
	_sk_loadout = HBoxContainer.new()
	_sk_loadout.add_theme_constant_override("separation", 3)
	root.add_child(_sk_loadout)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 4)
	scroll.add_child(vb)
	_boxes["Skills"] = vb
	_sk_detail = PanelContainer.new()
	_sk_detail.custom_minimum_size = Vector2(0, 110)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.06, 0.085, 0.98)
	sb.border_color = ProtoTheme.EMBER_DIM
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 6.0
	sb.content_margin_right = 6.0
	sb.content_margin_top = 4.0
	sb.content_margin_bottom = 4.0
	_sk_detail.add_theme_stylebox_override("panel", sb)
	# the card scrolls: long skill text is never CAPPED (Ricardo: "text is
	# very cluttered and frequently capped") — 110 px viewport, full content
	var detail_scroll := ScrollContainer.new()
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_sk_detail.add_child(detail_scroll)
	_sk_detail_box = VBoxContainer.new()
	_sk_detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sk_detail_box.add_theme_constant_override("separation", 2)
	detail_scroll.add_child(_sk_detail_box)
	root.add_child(_sk_detail)
	return root

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

func _line(vb: Container, text: String, color := PALE, font_size := ProtoTheme.SIZE_BODY) -> Label:
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
	b.add_theme_font_size_override("font_size", ProtoTheme.SIZE_BODY)
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
	_line(vb, ProtoLang.t("cp_gear_header") % [Session.player_name,
			Session.class_display(), Session.level], EMBER)
	var s := ProtoStats.compute(Session)
	for sl in ProtoStats.summary_lines(s):
		_line(vb, sl, DIM)
	for slot in ProtoItems.GEAR_SLOTS:
		var it: Dictionary = Session.equipment[slot]
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", ProtoTheme.SIZE_BODY)
		if it.is_empty():
			b.text = ProtoLang.t("cp_slot_empty") % ProtoLang.term("slot", str(slot))
			b.add_theme_color_override("font_color", DIM)
		else:
			b.icon = _icon(it)
			b.text = ProtoLang.t("cp_slot_row") % [ProtoLang.term("slot", str(slot)),
					_iname(it), ProtoItems.power(it)]
			b.add_theme_color_override("font_color", _rcolor(it))
			b.tooltip_text = "\n".join(PackedStringArray(ProtoItems.describe(it)))
		b.pressed.connect(_select_slot.bind(str(slot)))
		vb.add_child(b)
	if _sel_slot != "":
		var it: Dictionary = Session.equipment.get(_sel_slot, {})
		if not it.is_empty():
			_line(vb, "— %s —" % _iname(it), _rcolor(it))
			_line(vb, ProtoLang.t("cp_item_meta") % [
					ProtoLang.term("rarity", str(it.get("rarity", "?"))),
					ProtoLang.term("slot", str(it.get("slot", "?"))).to_lower(),
					ProtoItems.sell_price(it)], DIM)
			for d in ProtoItems.describe(it):
				_line(vb, str(d), PALE)
			var hb := HBoxContainer.new()
			hb.add_theme_constant_override("separation", 6)
			vb.add_child(hb)
			_btn(hb, ProtoLang.t("cp_unequip"), _do_unequip.bind(_sel_slot), GOLD)
			if Session.inventory.size() >= ProtoItems.INVENTORY_CAP:
				_line(vb, ProtoLang.t("cp_bag_full"), RED)

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
	_line(vb, ProtoLang.t("cp_bag_header") % [Session.inventory.size(),
			ProtoItems.INVENTORY_CAP, _gold()], EMBER)
	if Session.inventory.is_empty():
		_line(vb, ProtoLang.t("cp_bag_empty"), DIM)
		return
	# toolbar: filter chips + one-click sorts (bag organization — Ricardo)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 4)
	vb.add_child(bar)
	for f in [["all", "flt_all"], ["gear", "flt_gear"], ["rune", "flt_runes"],
			["material", "flt_mats"]]:
		var fb := Button.new()
		fb.text = ProtoLang.t(str(f[1]))
		fb.focus_mode = Control.FOCUS_NONE
		fb.add_theme_font_size_override("font_size", ProtoTheme.SIZE_BODY)
		if _bag_filter == str(f[0]):
			fb.add_theme_color_override("font_color", GOLD)
		fb.pressed.connect(_set_bag_filter.bind(str(f[0])))
		bar.add_child(fb)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(gap)
	for srt in [["rarity", "srt_rarity"], ["power", "srt_power"], ["slot", "srt_slot"]]:
		var sb2 := Button.new()
		sb2.text = ProtoLang.t(str(srt[1]))
		sb2.focus_mode = Control.FOCUS_NONE
		sb2.tooltip_text = ProtoLang.t("cp_sort_tip") % ProtoLang.t(str(srt[1]))
		sb2.add_theme_font_size_override("font_size", ProtoTheme.SIZE_BODY)
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
	_line(vb, "— %s —" % _iname(item), _rcolor(item))
	_line(vb, "%s %s" % [ProtoLang.term("rarity", str(item.get("rarity", "?"))),
			ProtoLang.term("slot", str(item.get("slot", "?"))).to_lower()], DIM)
	var slot := str(item.get("slot", ""))
	var equipped: Dictionary = Session.equipment.get(slot, {}) \
			if ProtoItems.GEAR_SLOTS.has(slot) else {}
	if equipped.is_empty() or int(equipped.get("uid", -1)) == int(item.get("uid", -2)):
		for d in ProtoItems.describe(item):
			_line(vb, str(d), PALE)
	else:
		# side-by-side comparison: the pick vs what you're wearing
		var cols := HBoxContainer.new()
		cols.add_theme_constant_override("separation", 10)
		vb.add_child(cols)
		for pair in [[item, ProtoLang.t("cp_selected")], [equipped, ProtoLang.t("cp_equipped")]]:
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
			nm.text = ProtoLang.t("cp_pw") % [_iname(it2), ProtoItems.power(it2)]
			nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			nm.add_theme_font_size_override("font_size", ProtoTheme.SIZE_BODY)
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
		var rows := [["cmp_max_hp", "max_hp", 1.0], ["cmp_melee", "melee_damage", 1.0],
				["cmp_rend", "rend_damage", 1.0], ["cmp_crit", "crit_chance", 100.0],
				["cmp_move", "move_speed_mult", 100.0], ["cmp_armor", "armor", 1.0],
				["cmp_resist", "resist_pct", 100.0]]
		var any := false
		for r in rows:
			var d: float = (float(alt[r[1]]) - float(cur[r[1]])) * float(r[2])
			if absf(d) < 0.05:
				continue
			any = true
			_line(vb, ProtoLang.t("cp_vs_diff") % [ProtoLang.t(str(r[0])), d],
					GREEN if d > 0.0 else RED)
		if not any:
			_line(vb, ProtoLang.t("cp_no_change"), DIM)
	elif slot == "rune":
		_line(vb, ProtoLang.t("cp_rune_hint"), VIOLET)
	elif slot == "material":
		_line(vb, ProtoLang.t("cp_mat_hint"), CYAN)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	vb.add_child(hb)
	if ProtoItems.GEAR_SLOTS.has(slot):
		_btn(hb, ProtoLang.t("cp_equip"), _do_equip.bind(int(item.get("uid", -1))), GOLD)
	_btn(hb, ProtoLang.t("cp_sell") % (ProtoItems.sell_price(item) * int(item.get("qty", 1))),
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
	_line(vb, ProtoLang.t("cp_attr_header") % Session.attribute_points, EMBER)
	_line(vb, ProtoLang.t("cp_attr_note") % [Session.BASE_ATTRIBUTE], DIM)
	for attr in Session.ATTRIBUTES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		vb.add_child(row)
		var nl := Label.new()
		nl.text = "%s  (%s)" % [ProtoLang.t("attr_" + str(attr)),
				ProtoLang.t("fxs_" + str(attr))]
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nl.add_theme_font_size_override("font_size", ProtoTheme.SIZE_BODY)
		nl.add_theme_color_override("font_color", PALE)
		row.add_child(nl)
		var vl := Label.new()
		vl.text = str(Session.attributes[attr])
		vl.add_theme_font_size_override("font_size", ProtoTheme.SIZE_BODY)
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

# ---- Skills tab: visual class tree + fixed detail card + base kit ---------------

func _refresh_skills() -> void:
	var s := ProtoStats.compute(Session)
	_sk_points.text = ProtoLang.t("cp_skill_points") % Session.skill_points
	_sk_points.tooltip_text = ProtoLang.t("cp_pts_tip")
	_sk_class.text = ProtoLang.t("cp_class_tree") % Session.class_display()
	var charge := Session.class_charge()
	_sk_charge.visible = not charge.is_empty()
	if not charge.is_empty():
		_sk_charge.text = "◈ %s" % ProtoLang.pick(charge, "name")
		_sk_charge.tooltip_text = ProtoLang.pick(charge, "desc")
	_refresh_loadout()
	var vb: VBoxContainer = _boxes["Skills"]
	_clear(vb)
	_build_tree(vb, s)
	_line(vb, ProtoLang.t("cp_tree_legend"), DIM)
	_build_base_kit(vb, s)
	_refresh_detail(s)

# Hotbar chips: what 1-4 cast right now (click a filled chip to clear it).
func _refresh_loadout() -> void:
	_clear(_sk_loadout)
	for i in 4:
		var d := Session.skill_def(str(Session.skill_loadout[i]))
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 8)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		if d.is_empty():
			b.text = "%d ·  —" % (i + 1)
			b.add_theme_color_override("font_color", DIM)
			b.tooltip_text = ProtoLang.t("cp_slot_empty_tip") % (i + 1)
		else:
			# first word only — full names clipped the chips into clutter
			b.text = "%d · %s" % [i + 1,
					ProtoLang.pick(d, "name", "?").get_slice(" ", 0)]
			b.add_theme_color_override("font_color", GOLD)
			b.tooltip_text = "%s\n%s" % [ProtoLang.pick(d, "name", "?"),
					ProtoLang.t("cp_slot_cast_tip") % (i + 1)]
			b.pressed.connect(_do_assign.bind(i, ""))
			var sb := ProtoTheme.chip_box(GOLD, 0.10)
			b.add_theme_stylebox_override("normal", sb)
			b.add_theme_stylebox_override("hover", ProtoTheme.chip_box(GOLD, 0.2))
			b.add_theme_stylebox_override("pressed", sb)
		_sk_loadout.add_child(b)

# The tree proper: one root chip on top, then a column ("lane") per branch with
# prerequisite connectors drawn top-to-bottom by the TreeCanvas underneath.
func _build_tree(vb: Container, s: Dictionary) -> void:
	var branches: Array = []
	var root_node := {}
	for br in Session.class_branches():
		var nodes: Array = br.get("nodes", [])
		if nodes.size() == 1 and int(nodes[0].get("cost", 1)) <= 0:
			root_node = nodes[0]
			continue
		branches.append(br)
	if branches.is_empty():
		_line(vb, ProtoLang.t("cp_no_tree"), DIM)
		return
	var cols := branches.size()
	var col_w := floorf(TREE_W / cols)
	var chip_w := col_w - 5.0
	var chip_h := 40.0
	var row_h := chip_h + 14.0
	var y0 := 44.0
	var max_rows := 0
	for br in branches:
		max_rows = maxi(max_rows, (br.get("nodes", []) as Array).size())
	var canvas := TreeCanvas.new()
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.custom_minimum_size = Vector2(TREE_W, y0 + max_rows * row_h)
	vb.add_child(canvas)
	var root_w := 110.0
	var root_pos := Vector2((TREE_W - root_w) * 0.5, 0.0)
	if not root_node.is_empty():
		_tree_chip(canvas, root_node, s, Rect2(root_pos, Vector2(root_w, 24.0)), true)
	for ci in cols:
		var br: Dictionary = branches[ci]
		var cx := ci * col_w
		var hl := Label.new()
		hl.text = ProtoLang.pick(br, "name", "?").to_upper()
		hl.position = Vector2(cx, 31.0)
		hl.size = Vector2(col_w - 2.0, 10.0)
		hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hl.clip_text = true
		hl.add_theme_font_size_override("font_size", ProtoTheme.SIZE_BODY)
		hl.add_theme_color_override("font_color", EMBER)
		hl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		canvas.add_child(hl)
		var nodes: Array = br.get("nodes", [])
		for ni in nodes.size():
			var node: Dictionary = nodes[ni]
			var rect := Rect2(Vector2(cx + (col_w - chip_w) * 0.5, y0 + ni * row_h),
					Vector2(chip_w, chip_h))
			var st := _tree_chip(canvas, node, s, rect, false)
			var from := Vector2(root_pos.x + root_w * 0.5, 24.0) if ni == 0 \
					else Vector2(rect.position.x + chip_w * 0.5,
							y0 + (ni - 1) * row_h + chip_h)
			canvas.add_edge(from,
					Vector2(rect.position.x + chip_w * 0.5, rect.position.y), st)

# One node = one chip: kind icon (element-tinted), name, state microline.
# learned = lit ember · learnable-now = pulsing gold border · locked = dim + lock.
func _tree_chip(canvas: TreeCanvas, node: Dictionary, s: Dictionary, rect: Rect2,
		is_root: bool) -> Dictionary:
	var id := str(node.get("id", ""))
	var st := _node_state(node)
	var accent := _node_accent(node)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.position = rect.position
	b.size = rect.size
	b.tooltip_text = "(node %s)\n%s" % [id, _node_tooltip(node, s)]
	b.pressed.connect(_select_node.bind(id))
	var sel := _sel_node == id
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(3)
	sb.set_border_width_all(2 if sel else 1)
	var base_border: Color
	if st.learned:
		sb.bg_color = Color(0.16, 0.11, 0.05, 0.95)
		base_border = EMBER
	elif st.learnable:
		sb.bg_color = Color(0.10, 0.14, 0.17)
		base_border = GOLD
	elif st.open:   # gates met, no points banked
		sb.bg_color = Color(0.075, 0.105, 0.14)
		base_border = Color(0.45, 0.4, 0.25)
	else:
		sb.bg_color = Color(0.05, 0.07, 0.095)
		base_border = Color(0.13, 0.17, 0.21)
	sb.border_color = Color(0.92, 0.88, 0.78) if sel else base_border
	var hover := sb.duplicate() as StyleBoxFlat
	hover.bg_color = sb.bg_color.lightened(0.07)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if st.learnable and not sel:   # the "you can learn this NOW" pulse
		canvas.pulse_boxes.append({"sb": sb, "a": base_border, "b": Color(1.0, 0.93, 0.62)})
		canvas.pulse_boxes.append({"sb": hover, "a": base_border, "b": Color(1.0, 0.93, 0.62)})
	canvas.add_child(b)
	var locked: bool = not (st.learned or st.learnable or st.open)
	if is_root:
		var rl := Label.new()
		rl.text = ProtoLang.t("cp_free_root") % ProtoLang.pick(node, "name", "?")
		rl.position = Vector2(0, 0)
		rl.size = rect.size
		rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		rl.clip_text = true
		rl.add_theme_font_size_override("font_size", 8)
		rl.add_theme_color_override("font_color", GOLD)
		rl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(rl)
		return st
	var icon := TextureRect.new()
	icon.texture = _kind_icon(_node_kind_key(node), accent)
	icon.position = Vector2((rect.size.x - 16.0) * 0.5, 2.0)
	icon.size = Vector2(16, 16)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if locked:
		icon.modulate = Color(1, 1, 1, 0.4)
	b.add_child(icon)
	if locked:
		var lock := TextureRect.new()
		lock.texture = _lock_tex()
		lock.position = icon.position + Vector2(11.0, 9.0)
		lock.size = Vector2(8, 8)
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(lock)
	var nl := Label.new()
	nl.text = ProtoLang.pick(node, "name", "?")
	nl.position = Vector2(1.0, 19.0)
	nl.size = Vector2(rect.size.x - 2.0, 9.0)
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nl.clip_text = true
	nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nl.add_theme_font_size_override("font_size", ProtoTheme.SIZE_BODY)
	nl.add_theme_color_override("font_color",
			GOLD if st.learned else (Color(0.93, 0.91, 0.84) if st.learnable
			else (PALE if st.open else DIM)))
	nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(nl)
	var micro := Label.new()
	if st.learned:
		micro.text = ProtoLang.t("cp_learned")
		micro.add_theme_color_override("font_color", ProtoTheme.EMBER_DIM)
	elif st.learnable:
		micro.text = ProtoLang.t("cp_learn_pt") % st.cost
		micro.add_theme_color_override("font_color", GOLD)
	elif st.open:
		micro.text = ProtoLang.t("cp_pt") % st.cost
		micro.add_theme_color_override("font_color", DIM)
	elif not st.lvl_ok:
		micro.text = ProtoLang.t("cp_level_req") % int(node.get("min_level", 1))
		micro.add_theme_color_override("font_color", Color(0.8, 0.45, 0.4))
	else:
		micro.text = ProtoLang.t("cp_needs") % ", ".join(st.req_names)
		micro.add_theme_color_override("font_color", DIM)
	micro.position = Vector2(1.0, 29.0)
	micro.size = Vector2(rect.size.x - 2.0, 9.0)
	micro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	micro.clip_text = true
	micro.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	micro.add_theme_font_size_override("font_size", ProtoTheme.SIZE_BODY)
	micro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(micro)
	return st

# Learn/level/point gates for one node — single source for chips, edges and card.
func _node_state(node: Dictionary) -> Dictionary:
	var learned := Session.def_learned(node)
	var req_names: Array[String] = []
	var reqs_met := true
	for r in node.get("requires", []):
		var rdef := Session.skill_def(str(r))
		if not (Session.node_learned(str(r)) \
				or (not rdef.is_empty() and Session.def_learned(rdef))):
			reqs_met = false
			req_names.append(ProtoLang.pick(rdef, "name", str(r)))
	var lvl_ok := Session.level >= int(node.get("min_level", 1))
	var cost := int(node.get("cost", 1))
	var afford := Session.skill_points >= cost
	return {"learned": learned, "reqs_met": reqs_met, "lvl_ok": lvl_ok,
			"afford": afford, "req_names": req_names, "cost": cost,
			"learnable": not learned and reqs_met and lvl_ok and afford and cost > 0,
			"open": not learned and reqs_met and lvl_ok and not afford and cost > 0}

# Element accent for a node: explicit element > first applied status > neutral.
func _node_accent(node: Dictionary) -> Color:
	var p: Dictionary = node.get("params", {})
	var elem := str(p.get("element", ""))
	if ELEM_COLORS.has(elem):
		return ELEM_COLORS[elem]
	var applies: Array = node.get("applies", [])
	if not applies.is_empty() and STATUS_COLORS.has(str(applies[0])):
		return STATUS_COLORS[str(applies[0])]
	if _node_kind_key(node) == "keystone":
		return GOLD
	return PALE

# Icon key: actives use their executor kind; passives split plain vs keystone
# (the tradeoff passive — any negative stat mod marks it).
func _node_kind_key(node: Dictionary) -> String:
	if str(node.get("type", "")) == "active":
		return str(node.get("kind", "melee_arc"))
	for m in node.get("stat_mods", []):
		if float(m.get("value", 0)) < 0.0:
			return "keystone"
	return "passive"

func _select_node(id: String) -> void:
	_sel_node = "" if _sel_node == id else id
	_refresh_skills()

# The fixed detail card at the bottom of the tab: identity, live numbers,
# synergy, status chips, then Learn / assign-to-slot actions.
func _refresh_detail(s: Dictionary) -> void:
	_clear(_sk_detail_box)
	var node := Session.skill_def(_sel_node)
	if node.is_empty():
		var hint := Label.new()
		hint.text = ProtoLang.t("cp_detail_hint")
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.add_theme_font_size_override("font_size", 8)
		hint.add_theme_color_override("font_color", DIM)
		_sk_detail_box.add_child(hint)
		return
	var st := _node_state(node)
	var accent := _node_accent(node)
	var active := str(node.get("type", "")) == "active"
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 5)
	_sk_detail_box.add_child(head)
	var icon := TextureRect.new()
	icon.texture = _kind_icon(_node_kind_key(node), accent)
	icon.custom_minimum_size = Vector2(16, 16)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	head.add_child(icon)
	var nm := Label.new()
	nm.text = ProtoLang.pick(node, "name", "?")
	nm.add_theme_font_size_override("font_size", ProtoTheme.SIZE_BODY)
	nm.add_theme_color_override("font_color", accent)
	head.add_child(nm)
	var kind_l := Label.new()
	kind_l.text = "· %s" % ProtoLang.term("kind",
			_node_kind_key(node) if not active else str(node.get("kind", "?"))).replace("_", " ")
	kind_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kind_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	kind_l.add_theme_font_size_override("font_size", 8)
	kind_l.add_theme_color_override("font_color", DIM)
	head.add_child(kind_l)
	var elem := str((node.get("params", {}) as Dictionary).get("element", ""))
	if ELEM_COLORS.has(elem):
		_status_chip(head, ProtoLang.term("elem", elem), ELEM_COLORS[elem],
				ProtoLang.t("elem_damage") % ProtoLang.term("elem", elem))
	# live numbers (this character's StatBlock) or passive stat mods
	if active:
		var bits := _active_bits(node, s)
		_detail_line(" · ".join(bits), PALE, ProtoTheme.SIZE_BODY)
	else:
		var mods: Array[String] = []
		for m in node.get("stat_mods", []):
			mods.append("%s %+d" % [str(m.get("stat", "?")).replace("_", " "),
					int(m.get("value", 0))])
		if not mods.is_empty():
			_detail_line(" · ".join(mods), PALE, ProtoTheme.SIZE_BODY)
	var d := _detail_line(ProtoLang.pick(node, "desc"), DIM, 8)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	d.max_lines_visible = 2
	if node.has("synergy"):
		_detail_line("⟡ %s" % ProtoLang.pick(node, "synergy"), GOLD, 8)
	# status/mechanic chips: applies / consumes / bonus_vs / charge build+spend
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 3)
	var statuses: Dictionary = Session.load_content("skill_trees").get("statuses", {})
	for ap in node.get("applies", []):
		var key := str(ap)
		var sdef: Dictionary = statuses.get(key, {})
		_status_chip(chips, ProtoLang.t("cp_applies") % ProtoLang.pick(sdef, "name", key),
				STATUS_COLORS.get(key, PALE), ProtoLang.pick(sdef, "desc"))
	for vs in node.get("bonus_vs", {}):
		var key2: String = VS_TO_STATUS.get(str(vs), str(vs))
		_status_chip(chips, ProtoLang.t("cp_x_vs") % [
				String.num(float(node.bonus_vs[vs]), 2), ProtoLang.term("vs", str(vs))],
				STATUS_COLORS.get(key2, PALE),
				ProtoLang.t("cp_bonus_tip") % ProtoLang.term("vs", str(vs)))
	for cs in node.get("consumes", []):
		var key3 := str(cs)
		_status_chip(chips, ProtoLang.t("cp_consumes") % ProtoLang.pick(
				statuses.get(key3, {}) as Dictionary, "name", key3),
				STATUS_COLORS.get(key3, PALE), ProtoLang.t("cp_consumes_tip"))
	var charge := Session.class_charge()
	if not charge.is_empty():
		if int(node.get("charge_gain", 0)) > 0:
			_status_chip(chips, "◈ +%d %s" % [int(node.charge_gain),
					ProtoLang.pick(charge, "name")], VIOLET, ProtoLang.pick(charge, "desc"))
		if bool(node.get("charge_spend", false)):
			_status_chip(chips, ProtoLang.t("cp_charge_spend") % ProtoLang.pick(charge, "name"),
					VIOLET, ProtoLang.pick(charge, "desc"))
	if chips.get_child_count() > 0:
		_sk_detail_box.add_child(chips)
	# action row: Learn (with reason when gated) or the 1-4 assign chips
	var act := HBoxContainer.new()
	act.add_theme_constant_override("separation", 4)
	_sk_detail_box.add_child(act)
	var id := str(node.get("id", ""))
	if int(node.get("cost", 1)) <= 0:
		_action_note(act, ProtoLang.t("cp_free_root_note"), ProtoTheme.EMBER_DIM)
	elif not st.learned:
		var lb := Button.new()
		lb.text = ProtoLang.t("cp_learn_btn") % st.cost
		lb.tooltip_text = "learn " + id   # stable hook (click test) — stays EN
		lb.focus_mode = Control.FOCUS_NONE
		lb.add_theme_font_size_override("font_size", ProtoTheme.SIZE_BODY)
		lb.add_theme_color_override("font_color", GOLD)
		lb.disabled = not st.learnable
		lb.pressed.connect(_do_learn.bind(id, st.cost))
		act.add_child(lb)
		if not st.reqs_met:
			_action_note(act, ProtoLang.t("cp_needs") % ", ".join(st.req_names), RED)
		elif not st.lvl_ok:
			_action_note(act, ProtoLang.t("cp_unlock_note") % [
					int(node.get("min_level", 1)), Session.level], RED)
		elif not st.afford:
			_action_note(act, ProtoLang.t("cp_no_points"), RED)
	elif active:
		_action_note(act, ProtoLang.t("cp_slot_label"), DIM)
		for i in 4:
			var here := str(Session.skill_loadout[i]) == id
			var ab := Button.new()
			ab.text = str(i + 1)
			ab.focus_mode = Control.FOCUS_NONE
			ab.custom_minimum_size = Vector2(22, 0)
			ab.add_theme_font_size_override("font_size", ProtoTheme.SIZE_BODY)
			ab.add_theme_color_override("font_color", GOLD if here else DIM)
			if here:
				ab.add_theme_stylebox_override("normal", ProtoTheme.chip_box(GOLD, 0.16))
			ab.tooltip_text = ProtoLang.t("cp_assign_tip") % [ProtoLang.pick(node, "name", "?"), i + 1] \
					if not here else ProtoLang.t("cp_on_key_tip") % (i + 1)
			ab.pressed.connect(_do_assign.bind(i, "" if here else id))
			act.add_child(ab)
		_action_note(act, ProtoLang.t("cp_learned_active"), ProtoTheme.EMBER_DIM)
	else:
		_action_note(act, ProtoLang.t("cp_learned_passive"), ProtoTheme.EMBER_DIM)

func _detail_line(text: String, color: Color, font_size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	_sk_detail_box.add_child(l)
	return l

func _action_note(parent: Container, text: String, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)

# Small accent-tinted chip ("applies Ignite", "x1.5 vs Chilled", "◈ +1 Combo").
func _status_chip(parent: Container, text: String, color: Color, tip := "") -> void:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", ProtoTheme.chip_box(color))
	if tip != "":
		pc.tooltip_text = tip
		pc.mouse_filter = Control.MOUSE_FILTER_STOP
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", ProtoTheme.SIZE_BODY)
	l.add_theme_color_override("font_color", color.lerp(Color.WHITE, 0.35))
	pc.add_child(l)
	parent.add_child(pc)

# The always-owned kit (LMB/E/Q/Shift) with its rune sockets, below the tree.
func _build_base_kit(vb: Container, s: Dictionary) -> void:
	var m := _main()
	var owns_rend: bool = Session.stones >= 1 or (m != null and m.stones >= 1)
	_line(vb, ProtoLang.t("cp_base_kit"), EMBER)
	match str(s.get("class_kit", "melee")):   # each class wears its own kit
		"mage":
			_skill_card(vb, "cleave", ProtoLang.t("kit_arcane_bolt"), Color("b48cff"),
					ProtoLang.t("cp_kit_bolt_nums") % [
					int(round(s.melee_damage * 0.9)), 0.55 / s.attack_speed_mult,
					int(s.crit_chance * 100.0)])
			_skill_card(vb, "", ProtoLang.t("kit_frost_nova"), Color("9fd4ff"),
					ProtoLang.t("cp_kit_nova_nums") % [
					int(round(s.melee_damage * 0.7 * s.skill_damage_mult))])
		"rogue":
			_skill_card(vb, "cleave", ProtoLang.t("kit_swift_stab"), PALE,
					ProtoLang.t("cp_kit_stab_nums") % [
					int(round(s.melee_damage * 0.8)), 0.25 / s.attack_speed_mult,
					int(s.crit_chance * 100.0)])
			_skill_card(vb, "", ProtoLang.t("kit_fan_knives"), Color("cdd6dd"),
					ProtoLang.t("cp_kit_fan_nums") % [
					int(round(s.melee_damage * 0.5))])
		_:
			_skill_card(vb, "cleave", ProtoLang.t("kit_cleave"), PALE,
					ProtoLang.t("cp_kit_cleave_nums") % [
					int(round(s.melee_damage)), 0.4 / s.attack_speed_mult,
					int(s.crit_chance * 100.0)])
			_skill_card(vb, "", ProtoLang.t("kit_whirlwind"), Color("9fd4ff"),
					ProtoLang.t("cp_kit_whirl_nums") % [
					int(round(s.melee_damage * 0.8))])
	_skill_card(vb, "rend", ProtoLang.t("kit_shadow_rend"), VIOLET,
			ProtoLang.t("cp_kit_rend_nums") % int(round(s.rend_damage)),
			not owns_rend)
	_skill_card(vb, "dodge", ProtoLang.t("kit_dodge"), CYAN,
			ProtoLang.t("cp_kit_dodge_nums") % s.dodge_recharge_s)
	if not owns_rend:
		_line(vb, ProtoLang.t("cp_rend_stone_note"), DIM, 8)
	if _socket_for != "":
		_socket_chooser(vb)
	_line(vb, ProtoLang.t("cp_runes_drop_note"), DIM)

# Live numbers for an active: damage from the CURRENT StatBlock, then geometry.
func _active_bits(node: Dictionary, s: Dictionary) -> Array[String]:
	var p: Dictionary = node.get("params", {})
	var kind := str(node.get("kind", ""))
	var dmg: float = s.melee_damage * float(p.get("mult", 1.0))
	if not kind in ["melee_arc", "dash_strike"]:
		dmg *= s.skill_damage_mult
	var bits: Array[String] = []
	if not kind in ["buff", "field"]:
		bits.append(ProtoLang.t("cp_dmg") % int(round(dmg)))
	if p.has("count"):
		bits.append("x%d" % int(p.get("count")))
	if p.has("jumps"):
		bits.append(ProtoLang.t("cp_jumps") % int(p.get("jumps")))
	if p.has("radius"):
		bits.append("%.1f m" % float(p.get("radius")))
	if p.has("reach"):
		bits.append("%.1f m" % float(p.get("reach")))
	if p.has("arc_deg"):
		bits.append(ProtoLang.t("cp_deg") % int(p.get("arc_deg")))
	if p.has("duration"):
		bits.append("%.0f s" % float(p.get("duration")))
	bits.append(ProtoLang.t("cp_cd") % (float(p.get("cd", 6.0)) * float(s.get("cdr_mult", 1.0))))
	return bits

# Tooltip: desc + synergy line + LIVE numbers (dmg from the current StatBlock).
func _node_tooltip(node: Dictionary, s: Dictionary) -> String:
	var lines: Array[String] = [ProtoLang.pick(node, "desc")]
	if node.has("synergy"):
		lines.append("⟡ " + ProtoLang.pick(node, "synergy"))
	if str(node.get("type", "")) == "active":
		var bits: Array[String] = [
			ProtoLang.term("kind", str(node.get("kind", ""))).replace("_", " ")]
		bits.append_array(_active_bits(node, s))
		lines.append(" · ".join(bits))
	else:
		var mods: Array[String] = []
		for m in node.get("stat_mods", []):
			mods.append("%s %+d" % [str(m.get("stat", "?")).replace("_", " "),
					int(m.get("value", 0))])
		if not mods.is_empty():
			lines.append(" · ".join(mods))
	lines.append(ProtoLang.t("cp_min_level") % [int(node.get("min_level", 1)),
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
	t.text = title + (ProtoLang.t("cp_locked") if locked else "")
	t.add_theme_font_size_override("font_size", ProtoTheme.SIZE_BODY)
	t.add_theme_color_override("font_color", DIM if locked else color)
	left.add_child(t)
	var nums := Label.new()
	nums.text = numbers
	nums.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nums.add_theme_font_size_override("font_size", ProtoTheme.SIZE_BODY)
	nums.add_theme_color_override("font_color", DIM)
	left.add_child(nums)
	if skill_key != "" and not locked:
		var r: Dictionary = Session.skill_runes.get(skill_key, {})
		var sb := Button.new()
		sb.focus_mode = Control.FOCUS_NONE
		sb.add_theme_font_size_override("font_size", ProtoTheme.SIZE_BODY)
		sb.custom_minimum_size = Vector2(96, 0)
		if r.is_empty():
			sb.text = ProtoLang.t("cp_socket_rune_chip")
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
	_line(vb, ProtoLang.t("cp_socket_on") % ProtoLang.term("sock", _socket_for), VIOLET)
	if not r.is_empty():
		_btn(vb, ProtoLang.t("cp_remove_rune") % str(r.get("name", "?")),
				_do_unsocket_pick, RED)
	var any := false
	for it in Session.inventory:
		if str(it.get("slot", "")) != "rune":
			continue
		any = true
		_btn(vb, "◆ %s — %s" % [str(it.get("name", "?")), str(ProtoItems.rune_def(
				str(it.get("rune_key", ""))).get("desc", ""))],
				_do_socket_pick.bind(int(it.get("uid", -1))), VIOLET)
	if not any and r.is_empty():
		_line(vb, ProtoLang.t("cp_no_runes"), DIM)

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

# ---- Pets tab (3 slots, canon §3) ----------------------------------------------------------

func _refresh_pets() -> void:
	var vb: VBoxContainer = _boxes["Pets"]
	_clear(vb)
	_line(vb, ProtoLang.t("cp_pets_header") % [Session.pets.size(), Session.MAX_PETS],
			EMBER)
	if Session.pets.is_empty():
		_line(vb, ProtoLang.t("cp_pets_none"), DIM)
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
				ProtoLang.t("cp_resting") if resting else ProtoLang.t("cp_on_hunt")]
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nl.add_theme_font_size_override("font_size", ProtoTheme.SIZE_BODY)
		nl.add_theme_color_override("font_color",
				Color("ff8a7a") if resting else CYAN)
		hb.add_child(nl)
		_btn(hb, ProtoLang.t("cp_to_stables"), _do_stable.bind(int(pet.get("uid", 0))))
		var skills: Array[String] = []
		for sk in pet.get("skills", []):
			skills.append(_pretty_id(str(sk)))
		var det := Label.new()
		det.text = ProtoLang.t("cp_pet_roll") % [int(pet.get("roll_pct", 100)),
				" · ".join(skills)]
		det.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		det.add_theme_font_size_override("font_size", ProtoTheme.SIZE_BODY)
		det.add_theme_color_override("font_color", PALE)
		cv.add_child(det)
	# The stables (Ricardo: pets are NEVER abandoned) — overflow captures land here.
	if not Session.stables.is_empty():
		_line(vb, ProtoLang.t("cp_stables_header") % Session.stables.size(), EMBER)
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
			nl.text = ProtoLang.t("cp_stable_row") % [str(pet.get("name", "?")),
					int(pet.get("roll_pct", 100)), " · ".join(skills)]
			nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			nl.add_theme_font_size_override("font_size", ProtoTheme.SIZE_BODY)
			nl.add_theme_color_override("font_color", PALE)
			hb.add_child(nl)
			var b := _btn(hb, ProtoLang.t("cp_make_active"),
					_do_activate.bind(int(pet.get("uid", 0))), CYAN)
			b.disabled = not room
			if not room:
				b.tooltip_text = ProtoLang.t("cp_pack_full_tip")
	_line(vb, ProtoLang.t("cp_stables_note"), DIM)

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
	_line(vb, ProtoLang.t("cp_mounts_header"), EMBER)
	if Session.mounts.is_empty():
		_line(vb, ProtoLang.t("cp_mounts_none"), DIM)
		return
	for m in Session.mounts:
		var active := int(m.get("uid", -1)) == Session.active_mount
		var flying := str(m.get("kind", "")) == "fly"
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 6)
		vb.add_child(hb)
		var nl := Label.new()
		nl.text = ProtoLang.t("cp_mount_row") % [str(m.get("name", "?")),
				ProtoLang.t("cp_flying") if flying else ProtoLang.t("cp_walking"),
				float(m.get("speed_mult", 1.0)),
				ProtoLang.t("cp_active_tag") if active else ""]
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nl.add_theme_font_size_override("font_size", ProtoTheme.SIZE_BODY)
		nl.add_theme_color_override("font_color",
				ProtoItems.rarity_color(str(m.get("rarity", "common"))))
		hb.add_child(nl)
		if not active:
			_btn(hb, ProtoLang.t("cp_select"), _do_select_mount.bind(int(m.get("uid", -1))), CYAN)
	_line(vb, ProtoLang.t("cp_mounts_note"), DIM)

func _do_select_mount(uid: int) -> void:
	Session.active_mount = uid
	Session.request_save()
	_refresh_mounts()

# Mid-hunt swaps respawn the live pet nodes; at the Haven this is a no-op.
func _sync_hunt_pets() -> void:
	var m := _main()
	if m and m.has_method("sync_pet_nodes"):
		m.sync_pet_nodes()

# ---- kind icons: tiny code-drawn glyphs, one per executor kind (ProtoSprites
# style — no external assets). Cached per kind+accent. ----------------------------

static var _kicon_cache := {}
static var _lock_cache: ImageTexture = null

static func _ipx(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)

static func _iline(img: Image, a: Vector2i, b: Vector2i, c: Color) -> void:
	var steps := maxi(absi(b.x - a.x), absi(b.y - a.y))
	if steps == 0:
		_ipx(img, a.x, a.y, c)
		return
	for i in steps + 1:
		var t := float(i) / steps
		_ipx(img, roundi(lerpf(a.x, b.x, t)), roundi(lerpf(a.y, b.y, t)), c)

static func _iarc(img: Image, cx: float, cy: float, rx: float, ry: float, c: Color,
		a0 := 0.0, a1 := TAU) -> void:
	var n := int(maxf(10.0, maxf(rx, ry) * 8.0))
	for i in n + 1:
		var ang := a0 + (a1 - a0) * float(i) / n
		_ipx(img, roundi(cx + cos(ang) * rx), roundi(cy + sin(ang) * ry), c)

static func _idot(img: Image, cx: int, cy: int, r: int, c: Color) -> void:
	for y in range(cy - r, cy + r + 1):
		for x in range(cx - r, cx + r + 1):
			if Vector2(x - cx, y - cy).length() <= r + 0.2:
				_ipx(img, x, y, c)

static func _kind_icon(kind: String, accent: Color) -> ImageTexture:
	var key := kind + accent.to_html()
	if _kicon_cache.has(key):
		return _kicon_cache[key]
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var core := accent.lerp(Color.WHITE, 0.55)
	var faint := Color(accent.r, accent.g, accent.b, 0.45)
	match kind:
		"projectile":   # bolt streaking right
			_iline(img, Vector2i(2, 8), Vector2i(7, 8), accent)
			_iline(img, Vector2i(3, 6), Vector2i(6, 6), faint)
			_iline(img, Vector2i(3, 10), Vector2i(6, 10), faint)
			_idot(img, 11, 8, 2, accent)
			_ipx(img, 11, 8, core)
			_ipx(img, 12, 7, core)
		"nova":         # ring bursting outward
			_iarc(img, 8, 8, 4.6, 4.6, accent)
			_idot(img, 8, 8, 1, core)
			_iline(img, Vector2i(8, 1), Vector2i(8, 2), core)
			_iline(img, Vector2i(8, 13), Vector2i(8, 14), core)
			_iline(img, Vector2i(1, 8), Vector2i(2, 8), core)
			_iline(img, Vector2i(13, 8), Vector2i(14, 8), core)
			for p in [Vector2i(3, 3), Vector2i(12, 3), Vector2i(3, 12), Vector2i(12, 12)]:
				_ipx(img, p.x, p.y, faint)
		"cone":         # fan opening from the apex
			_iline(img, Vector2i(2, 8), Vector2i(13, 3), accent)
			_iline(img, Vector2i(2, 8), Vector2i(13, 13), accent)
			_iline(img, Vector2i(2, 8), Vector2i(12, 8), faint)
			_iarc(img, 2, 8, 11.0, 11.0, core, -0.4, 0.4)
		"melee_arc":    # slash crescent
			_iarc(img, 5, 8, 6.2, 6.2, accent, -0.95, 0.95)
			_iarc(img, 5, 8, 5.0, 5.0, faint, -0.8, 0.8)
			_iline(img, Vector2i(12, 8), Vector2i(13, 8), core)
		"dash_strike":  # arrow with speed lines
			_iline(img, Vector2i(2, 8), Vector2i(11, 8), accent)
			_iline(img, Vector2i(12, 8), Vector2i(9, 5), accent)
			_iline(img, Vector2i(12, 8), Vector2i(9, 11), accent)
			_ipx(img, 13, 8, core)
			_iline(img, Vector2i(2, 5), Vector2i(5, 5), faint)
			_iline(img, Vector2i(2, 11), Vector2i(5, 11), faint)
		"buff":         # rising chevrons
			_iline(img, Vector2i(3, 9), Vector2i(8, 4), accent)
			_iline(img, Vector2i(8, 4), Vector2i(13, 9), accent)
			_iline(img, Vector2i(3, 13), Vector2i(8, 8), faint)
			_iline(img, Vector2i(8, 8), Vector2i(13, 13), faint)
			_ipx(img, 8, 2, core)
		"field":        # ground ellipse with motes rising
			_iarc(img, 8, 11, 5.5, 2.6, accent)
			_iarc(img, 8, 11, 3.2, 1.4, faint)
			_idot(img, 6, 6, 1, core)
			_ipx(img, 9, 4, core)
			_ipx(img, 11, 7, faint)
		"chain":        # jolt jumping between marks
			_iline(img, Vector2i(2, 11), Vector2i(6, 6), accent)
			_iline(img, Vector2i(6, 6), Vector2i(9, 10), accent)
			_iline(img, Vector2i(9, 10), Vector2i(13, 4), accent)
			for p in [Vector2i(2, 11), Vector2i(6, 6), Vector2i(9, 10), Vector2i(13, 4)]:
				_idot(img, p.x, p.y, 1, core)
		"keystone":     # the tradeoff diamond
			_iline(img, Vector2i(8, 2), Vector2i(14, 8), accent)
			_iline(img, Vector2i(14, 8), Vector2i(8, 14), accent)
			_iline(img, Vector2i(8, 14), Vector2i(2, 8), accent)
			_iline(img, Vector2i(2, 8), Vector2i(8, 2), accent)
			_iline(img, Vector2i(8, 5), Vector2i(11, 8), faint)
			_iline(img, Vector2i(11, 8), Vector2i(8, 11), faint)
			_iline(img, Vector2i(8, 11), Vector2i(5, 8), faint)
			_iline(img, Vector2i(5, 8), Vector2i(8, 5), faint)
			_ipx(img, 8, 8, core)
		_:              # passive: quiet ring
			_iarc(img, 8, 8, 3.4, 3.4, accent)
			_ipx(img, 8, 8, faint)
	var tex := ImageTexture.create_from_image(img)
	_kicon_cache[key] = tex
	return tex

# 8x8 padlock for gated nodes.
static func _lock_tex() -> ImageTexture:
	if _lock_cache != null:
		return _lock_cache
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var body := Color(0.82, 0.78, 0.68)
	var dark := Color(0.45, 0.42, 0.36)
	for y in range(4, 8):
		for x in range(2, 7):
			_ipx(img, x, y, body)
	_ipx(img, 4, 5, dark)   # keyhole
	_iline(img, Vector2i(3, 1), Vector2i(5, 1), body)   # shackle
	_ipx(img, 2, 2, body)
	_ipx(img, 2, 3, body)
	_ipx(img, 6, 2, body)
	_ipx(img, 6, 3, body)
	_lock_cache = ImageTexture.create_from_image(img)
	return _lock_cache

# One Control draws every prerequisite connector and drives the learnable-now
# pulse. Chips are its Button children (absolute positions), so ScrollContainer's
# ensure_control_visible still reaches every node.
class TreeCanvas:
	extends Control

	var edges: Array = []        # {pts, color, pulse}
	var pulse_boxes: Array = []  # {sb: StyleBoxFlat, a: Color, b: Color}
	var _t := 0.0
	var _any_pulse_edge := false

	func add_edge(from: Vector2, to: Vector2, st: Dictionary) -> void:
		var pts: PackedVector2Array
		if absf(from.x - to.x) < 0.5:
			pts = PackedVector2Array([from, to])
		else:   # root fan-out: vertical → horizontal → vertical elbow
			var my := (from.y + to.y) * 0.5
			pts = PackedVector2Array([from, Vector2(from.x, my), Vector2(to.x, my), to])
		var color := Color(0.2, 0.25, 0.3)
		var pulse := false
		if bool(st.get("learned", false)):
			color = Color(1.0, 0.6, 0.24, 0.85)
		elif bool(st.get("learnable", false)):
			color = Color(1.0, 0.82, 0.4, 0.8)
			pulse = true
			_any_pulse_edge = true
		elif bool(st.get("open", false)):
			color = Color(0.5, 0.45, 0.3, 0.7)
		edges.append({"pts": pts, "color": color, "pulse": pulse})

	func _process(delta: float) -> void:
		if not is_visible_in_tree() or (pulse_boxes.is_empty() and not _any_pulse_edge):
			return
		_t += delta
		var k := 0.5 + 0.5 * sin(_t * 5.0)
		for pb in pulse_boxes:
			(pb.sb as StyleBoxFlat).border_color = (pb.a as Color).lerp(pb.b as Color, k)
		if _any_pulse_edge:
			queue_redraw()

	func _draw() -> void:
		var k := 0.5 + 0.5 * sin(_t * 5.0)
		for e in edges:
			var c: Color = e.color
			if e.pulse:
				c = c.lerp(Color(1.0, 0.95, 0.7), 0.45 * k)
			draw_polyline(e.pts, c, 1.0)
