# PROTOTYPE HARNESS — title screen with an offline login. The name lands in the
# Session autoload; real authentication arrives with Nakama (docs/tech/26).
# UI is code-built like the rest of the slice — real screens come with the
# presentation layer proper once dh-godot exists.
extends Control

const EMBER := Color("ff9a3c")
const PALE := Color("d9d4c7")
const DIM := Color(0.55, 0.54, 0.5)

var _name_edit: LineEdit
var _class_pick := "core.class.reaver"
var _class_btns := {}
var _class_kit: Label
var _class_desc: Label

# class-lite roster (proposal): shared kit, distinct casts. Full kits: design/10.
# kit = what LMB and E actually cast; accent = the class's signature color.
# Class names are proper nouns (never localized); kit/desc carry _pt twins
# rendered through ProtoLang.pick.
const CLASSES := {
	"core.class.reaver": {"name": "Reaver", "kit": "Cleave · Whirlwind",
			"kit_pt": "Cutilada · Redemoinho",
			"accent": Color("ff8a7a"),
			"desc": "the balanced blade — umbral Shadow Rend, no tradeoffs",
			"desc_pt": "a lâmina equilibrada — Rasgo Sombrio umbral, sem contrapartidas"},
	"core.class.emberkin": {"name": "Emberkin", "kit": "Cleave · Whirlwind",
			"kit_pt": "Cutilada · Redemoinho",
			"accent": Color("ff9a3c"),
			"desc": "+12% fire on every hit, 20% chance to Ignite — but -10% HP",
			"desc_pt": "+12% de fogo em cada golpe, 20% de chance de Incendiar — mas -10% de HP"},
	"core.class.frostbinder": {"name": "Frostbinder", "kit": "Cleave · Whirlwind",
			"kit_pt": "Cutilada · Redemoinho",
			"accent": Color("7fe7ff"),
			"desc": "+15% HP and every hit Chills the enemy — but -8% damage",
			"desc_pt": "+15% de HP e cada golpe Gela o inimigo — mas -8% de dano"},
	"core.class.mage": {"name": "Gloam Mage", "kit": "Arcane Bolt · Frost Nova",
			"kit_pt": "Seta Arcana · Nova de Gelo",
			"accent": Color("cf9dff"),
			"desc": "ranged Arcane Bolts + Frost Nova (E) · +15% skill damage — but -20% HP",
			"desc_pt": "Setas Arcanas à distância + Nova de Gelo (E) · +15% de dano de habilidade — mas -20% de HP"},
	"core.class.rogue": {"name": "Veilblade", "kit": "Swift Stab · Fan of Knives",
			"kit_pt": "Estocada · Leque de Lâminas",
			"accent": Color("cdd6dd"),
			"desc": "blinding-fast stabs + Fan of Knives (E) · +10% crit and move — but -15% HP",
			"desc_pt": "estocadas velozes como um piscar + Leque de Lâminas (E) · +10% de crítico e movimento — mas -15% de HP"},
}

func _ready() -> void:
	_build()

# The whole menu is code-built, so the language toggle just rebuilds it in
# place (keeping whatever name was typed).
func _build() -> void:
	theme = ProtoTheme.get_theme()
	var bg := ColorRect.new()
	bg.color = Color("0c1116")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# soft ember halo behind the title (glow.gd fake-bloom); positioned onto the
	# title after the container's first layout pass (end of _build)
	var halo := ProtoGlow.make(Color(1.0, 0.55, 0.2), 120.0, 0.16, 1.6, 0.25)
	halo.position = Vector2(320, 110)
	add_child(halo)

	_add_embers()

	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# side gutters so autowrapping labels (class desc, saved-hunters) never
	# touch the window edges
	vb.offset_left = 24.0
	vb.offset_right = -24.0
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 8)
	add_child(vb)

	# Pixel-grid typography (ProtoTheme doctrine): display text rides the 16 px
	# font at integer multiples; body text stays on the themed 8 px grid.
	var big := ProtoTheme.font_big()
	var title := Label.new()
	title.text = "DRAGON HEROES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if big != null:
		title.add_theme_font_override("font", big)
	title.add_theme_font_size_override("font_size", ProtoTheme.SIZE_TITLE * 2)
	title.add_theme_color_override("font_color", EMBER)
	vb.add_child(title)

	var sub := Label.new()
	sub.text = ProtoLang.t("menu_subtitle")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", ProtoTheme.SIZE_BODY)
	sub.add_theme_color_override("font_color", DIM)
	vb.add_child(sub)

	vb.add_child(_spacer(10.0))

	_name_edit = _edit(vb, ProtoLang.t("menu_hunter_name"), false)
	_edit(vb, ProtoLang.t("menu_password"), true)

	vb.add_child(_spacer(4.0))

	# class selection (new characters; existing saves keep their class) — name
	# chips in the class accent; the selected class's LMB/E kit + tradeoff line
	# render once under the row (five per-card kit labels can't fit the 640 grid
	# at pixel-font widths — that was the title-screen overflow).
	var class_row := HBoxContainer.new()
	class_row.alignment = BoxContainer.ALIGNMENT_CENTER
	class_row.add_theme_constant_override("separation", 6)
	vb.add_child(class_row)
	for cid in CLASSES:
		var card: Dictionary = CLASSES[cid]
		var cb := Button.new()
		cb.toggle_mode = true
		cb.focus_mode = Control.FOCUS_NONE
		cb.text = str(card["name"])
		if big != null:
			cb.add_theme_font_override("font", big)
		cb.add_theme_font_size_override("font_size", ProtoTheme.SIZE_TITLE)
		cb.add_theme_color_override("font_color", card["accent"])
		cb.add_theme_color_override("font_hover_color", card["accent"])
		cb.add_theme_color_override("font_pressed_color", card["accent"])
		cb.pressed.connect(_pick_class.bind(str(cid)))
		class_row.add_child(cb)
		_class_btns[cid] = cb
	_class_kit = Label.new()
	_class_kit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_class_kit.add_theme_font_size_override("font_size", ProtoTheme.SIZE_BODY)
	vb.add_child(_class_kit)
	_class_desc = Label.new()
	_class_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_class_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_class_desc.add_theme_font_size_override("font_size", ProtoTheme.SIZE_BODY)
	_class_desc.add_theme_color_override("font_color", DIM)
	vb.add_child(_class_desc)
	_update_class_ui()

	vb.add_child(_spacer(4.0))

	var btn := Button.new()
	btn.text = ProtoLang.t("menu_enter")
	btn.custom_minimum_size = Vector2(190, 0)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(_enter)
	vb.add_child(btn)

	# saved hunters (user://saves) — entering a listed name continues that character
	var saves: Array = Session.list_saves()
	if not saves.is_empty():
		var names: Array[String] = []
		for s in saves:
			names.append("%s (lv %d)" % [str(s.name), int(s.level)])
		var cont := Label.new()
		cont.text = ProtoLang.t("menu_saved") % " · ".join(names)
		cont.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cont.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cont.add_theme_font_size_override("font_size", ProtoTheme.SIZE_BODY)
		cont.add_theme_color_override("font_color", Color("7fe7ff"))
		vb.add_child(cont)

	var foot := Label.new()
	foot.text = ProtoLang.t("menu_foot")
	foot.position = Vector2(0, 344)
	foot.size = Vector2(640, 14)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.add_theme_font_size_override("font_size", ProtoTheme.SIZE_BODY)
	foot.add_theme_color_override("font_color", DIM)
	add_child(foot)

	# EN / PT-BR toggle (Ricardo) — bottom-left, switches live and persists
	# (user://settings.json via ProtoLang).
	var lang_btn := Button.new()
	lang_btn.text = ProtoLang.t("lang_toggle")
	lang_btn.focus_mode = Control.FOCUS_NONE
	lang_btn.add_theme_font_size_override("font_size", ProtoTheme.SIZE_BODY)
	lang_btn.position = Vector2(8, 330)
	lang_btn.pressed.connect(_toggle_lang)
	add_child(lang_btn)

	# glue the halo to wherever the centered VBox actually lands the title
	# (content height shifts with the saves list / language). Guards cover the
	# rebuild-on-language-toggle freeing these nodes mid-await.
	await get_tree().process_frame
	if is_instance_valid(halo) and is_instance_valid(title):
		halo.position = title.get_global_rect().get_center()

func _toggle_lang() -> void:
	ProtoLang.set_lang("pt" if ProtoLang.lang == "en" else "en")
	var keep := _name_edit.text
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_build()
	_name_edit.text = keep

func _edit(parent: Container, placeholder: String, is_secret: bool) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.secret = is_secret
	e.alignment = HORIZONTAL_ALIGNMENT_CENTER
	e.custom_minimum_size = Vector2(190, 0)
	e.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	e.text_submitted.connect(func(_t: String) -> void: _enter())
	parent.add_child(e)
	return e

func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c

# Slow ember drift rising from below the title — CPUParticles2D because the
# prototype renders with gl_compatibility (same constraint as ambient.gd).
func _add_embers() -> void:
	var p := CPUParticles2D.new()
	p.amount = 22
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.position = Vector2(320, 376)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(330, 30)
	p.direction = Vector2(0, -1)
	p.spread = 14.0
	p.gravity = Vector2(0, -6)
	p.initial_velocity_min = 12.0
	p.initial_velocity_max = 32.0
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.7
	p.texture = ProtoSprites.spore_tex()
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.15, 0.75, 1.0])
	ramp.colors = PackedColorArray([
		Color(1.0, 0.65, 0.25, 0.0),
		Color(1.0, 0.62, 0.22, 0.55),
		Color(0.95, 0.35, 0.1, 0.3),
		Color(0.6, 0.15, 0.05, 0.0),
	])
	p.color_ramp = ramp
	add_child(p)
	p.emitting = true

func _pick_class(cid: String) -> void:
	_class_pick = cid
	_update_class_ui()

func _update_class_ui() -> void:
	for cid in _class_btns:
		var on: bool = cid == _class_pick
		_class_btns[cid].button_pressed = on
		_class_btns[cid].modulate = Color(1, 1, 1, 1.0 if on else 0.62)
	var card: Dictionary = CLASSES[_class_pick]
	_class_kit.text = ProtoLang.pick(card, "kit")
	_class_kit.add_theme_color_override("font_color", card["accent"])
	_class_desc.text = ProtoLang.pick(card, "desc")

func _enter() -> void:
	var pname := _name_edit.text.strip_edges()
	Session.class_id = _class_pick
	# login loads the saved character if the name exists (keeps its class),
	# else claims the slot with the picked class
	Session.login(pname if pname != "" else "Hunter")
	get_tree().change_scene_to_file("res://prototype/ui/haven.tscn")
