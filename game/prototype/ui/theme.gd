# PROTOTYPE HARNESS — one code-built Theme for every menu surface (main menu,
# Haven, character panel, confirm/keybind cards). Dark slate panels, ember
# accents, hover/pressed states — set it on a root Control/PanelContainer and it
# propagates. The shipping UI theme is an art-directed resource (docs/design/17).
class_name ProtoTheme
extends RefCounted

const PANEL_BG := Color(0.055, 0.078, 0.106, 0.97)
const PANEL_BORDER := Color(0.16, 0.23, 0.30)
const BTN_BG := Color(0.075, 0.105, 0.14)
const BTN_BG_HOVER := Color(0.11, 0.155, 0.21)
const BTN_BG_PRESSED := Color(0.05, 0.07, 0.095)
const EMBER := Color("ff9a3c")
const EMBER_DIM := Color(1.0, 0.6, 0.24, 0.6)
const PALE := Color("d9d4c7")
const DIM := Color(0.5, 0.49, 0.45)

static var _theme: Theme = null

static func _box(bg: Color, border: Color, radius := 3, margin := 6.0,
		border_w := 1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = margin
	sb.content_margin_right = margin
	sb.content_margin_top = margin * 0.6
	sb.content_margin_bottom = margin * 0.6
	return sb

static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.set_stylebox("panel", "PanelContainer", _box(PANEL_BG, PANEL_BORDER, 4, 8.0))
	t.set_stylebox("normal", "Button", _box(BTN_BG, PANEL_BORDER))
	t.set_stylebox("hover", "Button", _box(BTN_BG_HOVER, EMBER_DIM))
	t.set_stylebox("pressed", "Button", _box(BTN_BG_PRESSED, EMBER))
	t.set_stylebox("disabled", "Button", _box(Color(0.06, 0.08, 0.1, 0.6),
			Color(0.12, 0.16, 0.2)))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", PALE)
	t.set_color("font_hover_color", "Button", Color(1.0, 0.98, 0.92))
	t.set_color("font_pressed_color", "Button", EMBER)
	t.set_color("font_disabled_color", "Button", DIM)
	t.set_font_size("font_size", "Button", 11)
	t.set_stylebox("panel", "TabContainer", _box(PANEL_BG, PANEL_BORDER, 4, 6.0))
	var sel := _box(BTN_BG_HOVER, EMBER_DIM, 3, 7.0)
	sel.border_width_bottom = 0
	var unsel := _box(Color(0, 0, 0, 0.25), Color(0.1, 0.14, 0.18), 3, 7.0)
	unsel.border_width_bottom = 0
	t.set_stylebox("tab_selected", "TabContainer", sel)
	t.set_stylebox("tab_unselected", "TabContainer", unsel)
	t.set_color("font_selected_color", "TabContainer", EMBER)
	t.set_color("font_unselected_color", "TabContainer", DIM)
	t.set_font_size("font_size", "TabContainer", 10)
	t.set_stylebox("normal", "LineEdit", _box(Color(0.05, 0.07, 0.095), PANEL_BORDER, 3, 6.0))
	t.set_stylebox("focus", "LineEdit", _box(Color(0.05, 0.07, 0.095), EMBER_DIM, 3, 6.0))
	t.set_color("font_color", "LineEdit", PALE)
	t.set_color("caret_color", "LineEdit", EMBER)
	t.set_stylebox("panel", "TooltipPanel", _box(Color(0.04, 0.06, 0.08, 0.97), EMBER_DIM))
	t.set_color("font_color", "TooltipLabel", PALE)
	t.set_font_size("font_size", "TooltipLabel", 9)
	_theme = t
	return t
