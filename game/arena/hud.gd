# ARENA — spectator HUD: both fighters' name/policy/HP, episode + score + timer,
# and the controls hint. CanvasLayer holds Labels + one drawing Control; the
# pixel doctrine is applied by the arena before this is built. Headless training
# runs skip the HUD entirely.
class_name ArenaHud
extends CanvasLayer

var _bars: Array = []          # [{name, policy, frac, tint, side}]
var _label: Label
var _hint_label: Label
var _drawer: Control

func _ready() -> void:
	layer = 10
	_label = Label.new()
	_label.position = Vector2(8, 4)
	add_child(_label)
	_hint_label = Label.new()
	_hint_label.position = Vector2(8, 348)
	_hint_label.modulate = Color(1, 1, 1, 0.55)
	_hint_label.text = "[1/2/3] speed   [N] next matchup   [R] rematch   [Q] quit"
	add_child(_hint_label)
	_drawer = Control.new()
	_drawer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_drawer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drawer.draw.connect(_on_draw)
	add_child(_drawer)

func set_center(text: String) -> void:
	if is_instance_valid(_label):
		_label.text = text

func set_bars(bars: Array) -> void:
	_bars = bars
	if is_instance_valid(_drawer):
		_drawer.queue_redraw()

func _on_draw() -> void:
	var w := 220.0
	for i in _bars.size():
		var b: Dictionary = _bars[i]
		var right := int(b.get("side", 0)) == 1
		var x := 640.0 - 8.0 - w if right else 8.0
		var y := 26.0
		var tint: Color = b.get("tint", Color.WHITE)
		_drawer.draw_string(ThemeDB.fallback_font, Vector2(x, y - 6),
				"%s  ·  %s" % [b.get("name", "?"), b.get("policy", "")],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 8, tint)
		_drawer.draw_rect(Rect2(x, y, w, 8), Color(0, 0, 0, 0.65))
		var frac := clampf(float(b.get("frac", 0.0)), 0.0, 1.0)
		var fill := w * frac
		_drawer.draw_rect(Rect2(x + (w - fill) if right else x, y, fill, 8),
				tint.lerp(Color.BLACK, 0.25))
		_drawer.draw_rect(Rect2(x, y, w, 8), Color(1, 1, 1, 0.35), false, 1.0)
