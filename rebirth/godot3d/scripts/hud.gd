# REBIRTH / Godot 3D — HUD, one Control drawing everything (no per-widget
# nodes): hunter/dragon bars, dodge charges, skill/howl cooldowns, combo, the
# drop toast, prompts, and the frame-time budget readout (60 FPS directive).
class_name RbHud
extends CanvasLayer

var hunter: RbHunter
var dragon: RbDragon
var pet: RbPet
var slice: Node
var toast := ""
var toast_t := 0.0
var last_toast := ""
var toasts := 0
var prompt := ""
var _c: Control
var _font: Font

func _ready() -> void:
	_c = Control.new()
	_c.set_anchors_preset(Control.PRESET_FULL_RECT)
	_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_c)
	_font = ThemeDB.fallback_font
	_c.draw.connect(_draw_hud)

func show_toast(text: String, dur: float = 3.5) -> void:
	toast = text
	last_toast = text
	toasts += 1
	toast_t = dur

func _process(delta: float) -> void:
	toast_t = maxf(toast_t - delta, 0.0)
	if toast_t <= 0.0:
		toast = ""
	_c.queue_redraw()

func _bar(pos: Vector2, size: Vector2, frac: float, fill: Color, label: String) -> void:
	_c.draw_rect(Rect2(pos, size), Color(0.05, 0.05, 0.07, 0.85))
	_c.draw_rect(Rect2(pos + Vector2(2, 2), Vector2((size.x - 4.0) * clampf(frac, 0.0, 1.0), size.y - 4.0)), fill)
	_c.draw_rect(Rect2(pos, size), Color(0.75, 0.7, 0.6, 0.9), false, 1.0)
	_c.draw_string(_font, pos + Vector2(6, -6), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.95, 0.92, 0.85))

func _draw_hud() -> void:
	if hunter == null:
		return
	var sz := _c.size
	# hunter
	_bar(Vector2(28, 40), Vector2(300, 18), hunter.hp / hunter.HP_MAX, Color(0.75, 0.15, 0.1), "HUNTER  %d / %d" % [int(hunter.hp), int(hunter.HP_MAX)])
	for i in hunter.DODGE_CHARGES_MAX:
		var on := i < hunter.dodge_charges
		_c.draw_rect(Rect2(Vector2(28 + i * 22, 64), Vector2(18, 8)), Color(0.45, 0.8, 1.0) if on else Color(0.2, 0.25, 0.3))
	var sk := "SKILL READY (K)" if hunter.skill_cd <= 0.0 else "skill %.1fs" % hunter.skill_cd
	_c.draw_string(_font, Vector2(28, 92), sk, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.7, 0.35) if hunter.skill_cd <= 0.0 else Color(0.6, 0.6, 0.6))
	if pet != null:
		var hw := "HOWL READY (E)" if pet.howl_cd <= 0.0 else "howl %.1fs" % pet.howl_cd
		_c.draw_string(_font, Vector2(28, 110), hw, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.4, 1.0, 0.9) if pet.howl_cd <= 0.0 else Color(0.6, 0.6, 0.6))
	if hunter.combo_hits > 0:
		_c.draw_string(_font, Vector2(28, 134), "COMBO x%d" % hunter.combo_hits, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 0.9, 0.5))
	# dragon
	if dragon != null:
		var title := "CINDER WYRM, THE VALLEY'S END" + ("  — ENRAGED" if dragon.enraged else "")
		_bar(Vector2(sz.x * 0.5 - 260, 40), Vector2(520, 16), dragon.hp / dragon.HP_MAX, Color(0.85, 0.35, 0.1) if dragon.enraged else Color(0.7, 0.55, 0.15), title)
		var st := dragon.state
		if st == "tele":
			_c.draw_string(_font, Vector2(sz.x * 0.5 - 60, 82), "!! %s !!" % dragon.skill.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 0.5, 0.2))
		elif dragon.punishable:
			_c.draw_string(_font, Vector2(sz.x * 0.5 - 40, 82), "PUNISH", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.5, 1.0, 0.6))
	# frame budget (60 FPS directive: show the number, always)
	var ms := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var pms := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var fps := Engine.get_frames_per_second()
	var col := Color(0.6, 1.0, 0.6) if ms + pms < 16.0 else Color(1.0, 0.5, 0.4)
	_c.draw_string(_font, Vector2(sz.x - 250, 28), "%d fps  proc %.1f ms  phys %.1f ms" % [fps, ms, pms], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col)
	_c.draw_string(_font, Vector2(sz.x - 250, 46), "nodes %d  fx %d" % [Performance.get_monitor(Performance.OBJECT_NODE_COUNT), slice.get("fx").active_count() if slice != null else 0], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.7, 0.7, 0.75))
	# toast + prompt
	if toast != "":
		var a := clampf(toast_t / 0.6, 0.0, 1.0)
		_c.draw_rect(Rect2(Vector2(sz.x * 0.5 - 300, sz.y * 0.5 - 60), Vector2(600, 64)), Color(0.05, 0.03, 0.02, 0.8 * a))
		_c.draw_string(_font, Vector2(sz.x * 0.5 - 280, sz.y * 0.5 - 18), toast, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1.0, 0.85, 0.4, a))
	if prompt != "":
		_c.draw_string(_font, Vector2(sz.x * 0.5 - 120, sz.y - 40), prompt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.95, 0.92, 0.85))
	_c.draw_string(_font, Vector2(28, sz.y - 22), "WASD move · Space dodge · J attack · K skill · E howl · Tab lock-on · mouse orbit · R rematch · Esc mouse", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.6, 0.6, 0.65))
