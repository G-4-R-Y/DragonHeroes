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
var _class_desc: Label

# class-lite roster (proposal): shared kit, distinct casts. Full kits: design/10.
const CLASSES := {
	"core.class.reaver": {"name": "Reaver",
			"desc": "the balanced blade — umbral Shadow Rend, no tradeoffs"},
	"core.class.emberkin": {"name": "Emberkin",
			"desc": "+12% fire on every hit, 20% chance to Ignite — but -10% HP"},
	"core.class.frostbinder": {"name": "Frostbinder",
			"desc": "+15% HP and every hit Chills the enemy — but -8% damage"},
	"core.class.mage": {"name": "Gloam Mage",
			"desc": "ranged Arcane Bolts + Frost Nova (E) · +15% skill damage — but -20% HP"},
	"core.class.rogue": {"name": "Veilblade",
			"desc": "blinding-fast stabs + Fan of Knives (E) · +10% crit and move — but -15% HP"},
}

func _ready() -> void:
	theme = ProtoTheme.get_theme()
	var bg := ColorRect.new()
	bg.color = Color("0c1116")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# soft ember halo behind the title (glow.gd fake-bloom)
	var halo := ProtoGlow.make(Color(1.0, 0.55, 0.2), 120.0, 0.16, 1.6, 0.25)
	halo.position = Vector2(320, 148)
	add_child(halo)

	_add_embers()

	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 8)
	add_child(vb)

	var title := Label.new()
	title.text = "DRAGON HEROES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", EMBER)
	vb.add_child(title)

	var sub := Label.new()
	sub.text = "pre-alpha prototype"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", DIM)
	vb.add_child(sub)

	vb.add_child(_spacer(10.0))

	_name_edit = _edit(vb, "hunter name", false)
	_edit(vb, "password", true)

	vb.add_child(_spacer(4.0))

	# class selection (new characters; existing saves keep their class)
	var class_row := HBoxContainer.new()
	class_row.alignment = BoxContainer.ALIGNMENT_CENTER
	class_row.add_theme_constant_override("separation", 6)
	vb.add_child(class_row)
	for cid in CLASSES:
		var cb := Button.new()
		cb.text = str(CLASSES[cid]["name"])
		cb.toggle_mode = true
		cb.focus_mode = Control.FOCUS_NONE
		cb.custom_minimum_size = Vector2(72, 0)
		cb.pressed.connect(_pick_class.bind(str(cid)))
		class_row.add_child(cb)
		_class_btns[cid] = cb
	_class_desc = Label.new()
	_class_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_class_desc.add_theme_font_size_override("font_size", 9)
	_class_desc.add_theme_color_override("font_color", DIM)
	vb.add_child(_class_desc)
	_update_class_ui()

	vb.add_child(_spacer(4.0))

	var btn := Button.new()
	btn.text = "Enter the World"
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
		cont.text = "saved hunters: %s — enter a name to continue" % " · ".join(names)
		cont.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cont.add_theme_font_size_override("font_size", 9)
		cont.add_theme_color_override("font_color", Color("7fe7ff"))
		vb.add_child(cont)

	var foot := Label.new()
	foot.text = "offline prototype login — real auth arrives with Nakama (docs/tech/26)"
	foot.position = Vector2(0, 344)
	foot.size = Vector2(640, 14)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.add_theme_font_size_override("font_size", 10)
	foot.add_theme_color_override("font_color", DIM)
	add_child(foot)

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
		_class_btns[cid].button_pressed = cid == _class_pick
	_class_desc.text = str(CLASSES[_class_pick]["desc"])

func _enter() -> void:
	var pname := _name_edit.text.strip_edges()
	Session.class_id = _class_pick
	# login loads the saved character if the name exists (keeps its class),
	# else claims the slot with the picked class
	Session.login(pname if pname != "" else "Hunter")
	get_tree().change_scene_to_file("res://prototype/ui/haven.tscn")
