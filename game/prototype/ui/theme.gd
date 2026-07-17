# PROTOTYPE HARNESS — one code-built Theme for every menu surface (main menu,
# Haven, character panel, confirm/keybind cards). Dark slate panels, ember
# accents, hover/pressed states — set it on a root Control/PanelContainer and it
# propagates. The shipping UI theme is an art-directed resource (docs/design/17).
#
# Pixel typography doctrine (visual overhaul): mixed-resolution text was the #1
# amateur tell in captures — vector fonts rasterize at window resolution while
# the art lives on the 640x360 grid. Every surface now routes through Pixel
# Operator (CC0, ui/fonts/ — 8 px native for UI text, 16 px native for display)
# with antialiasing OFF, hinting NONE, subpixel positioning OFF and per-font
# oversampling pinned to 1x, so font pixels == art pixels under the integer
# canvas_items stretch. Font sizes must stay integer multiples of the native
# grid — use the SIZE_* constants or snap(). If the TTFs are absent the theme
# degrades to doctrine-only mode on the engine font (kept sizes, no font swap).
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

# Native pixel grids of the two shipped fonts (ui/fonts/README.md).
const GRID_SMALL := 8                  # PixelOperator8.ttf
const GRID_BIG := 16                   # PixelOperator.ttf
# Doctrine sizes — the ONLY legal small/display sizes on the pixel grid. HUD
# stat/hint lines and body text sit one step below the old 10-11 px vector text
# so the type stops dominating captures.
const SIZE_BODY := GRID_SMALL          # buttons, chips, tooltips, HUD lines
const SIZE_TITLE := GRID_BIG           # panel/menu titles
const SIZE_DAMAGE := GRID_BIG          # damage numbers (crits ride pop-scale)

const FONT_SMALL_PATH := "res://prototype/ui/fonts/PixelOperator8.ttf"
const FONT_BIG_PATH := "res://prototype/ui/fonts/PixelOperator.ttf"

static var _theme: Theme = null
static var _doctrine_done := false
static var _font_small: FontFile = null
static var _font_big: FontFile = null

# Quantize a legacy font size onto the pixel grid (never below one grid step).
# Migration seam for consumers still carrying arbitrary vector-era sizes.
static func snap(size: int, grid := GRID_SMALL) -> int:
	return maxi(grid, roundi(float(size) / float(grid)) * grid)

# Loads + doctrine-configures one pixel font. `fallback` chains the engine font
# so glyphs Pixel Operator lacks (◆ ◇ → § …) keep rendering instead of tofu.
# Returns null when the asset is missing (doctrine-only mode).
static func _pixel_font(path: String, fallback: Font) -> FontFile:
	if not ResourceLoader.exists(path):
		return null
	var f := load(path) as FontFile
	if f == null:
		return null
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.hinting = TextServer.HINTING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	# pin rasterization to the 640x360 grid: the 2x integer canvas_items stretch
	# nearest-scales losslessly, and glyphs never land on half-canvas pixels
	f.oversampling = 1.0
	f.generate_mipmaps = false
	f.force_autohinter = false
	if fallback != null:
		f.fallbacks = [fallback]
	return f

# Idempotent global routing. Beyond the Theme below, this re-points the ThemeDB
# fallback so UNTHEMED text (the in-run HUD labels live on a bare CanvasLayer)
# inherits the pixel font too. Local font_size overrides keep their values —
# callers migrate by quantizing with snap()/SIZE_* as they are touched.
static func apply_doctrine() -> void:
	if _doctrine_done:
		return
	_doctrine_done = true
	var engine_font := ThemeDB.fallback_font   # captured BEFORE the override
	_font_small = _pixel_font(FONT_SMALL_PATH, engine_font)
	_font_big = _pixel_font(FONT_BIG_PATH, engine_font)
	if _font_small != null:
		ThemeDB.fallback_font = _font_small
		ThemeDB.fallback_font_size = SIZE_BODY

# Doctrine-configured pixel fonts for direct consumers (damage numbers, world
# text). May return null in doctrine-only mode — Label/LabelSettings treat a
# null font as "engine default", so assignment stays unconditional-safe.
static func font_small() -> FontFile:
	apply_doctrine()
	return _font_small

static func font_big() -> FontFile:
	apply_doctrine()
	return _font_big

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

# Accent-tinted chip box — status chips, loadout slots, section chips. One place
# so every surface's chips look like siblings (panel, Haven, menu).
static func chip_box(accent: Color, bg_alpha := 0.14, border_w := 1) -> StyleBoxFlat:
	var sb := _box(Color(accent.r, accent.g, accent.b, bg_alpha),
			Color(accent.r, accent.g, accent.b, 0.55), 3, 5.0, border_w)
	sb.content_margin_top = 2.0
	sb.content_margin_bottom = 2.0
	return sb

static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	apply_doctrine()
	var t := Theme.new()
	# typography: every themed control shares ONE pixel font at ONE grid size —
	# uniform resolution is the whole point. Doctrine-only mode keeps the old
	# integer sizes on the engine font instead.
	var body := SIZE_BODY
	if _font_small != null:
		t.default_font = _font_small
		t.default_font_size = body
	else:
		body = 10
	t.set_stylebox("panel", "PanelContainer", _box(PANEL_BG, PANEL_BORDER, 4, 8.0))
	t.set_stylebox("normal", "Button", _box(BTN_BG, PANEL_BORDER))
	t.set_stylebox("hover", "Button", _box(BTN_BG_HOVER, EMBER_DIM))
	# pressed nudges its content down 1 px — cheap tactile feedback
	var pressed := _box(BTN_BG_PRESSED, EMBER)
	pressed.content_margin_top += 1.0
	pressed.content_margin_bottom -= 1.0
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("hover_pressed", "Button", _box(BTN_BG_HOVER, EMBER))
	t.set_stylebox("disabled", "Button", _box(Color(0.06, 0.08, 0.1, 0.6),
			Color(0.12, 0.16, 0.2)))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", PALE)
	t.set_color("font_hover_color", "Button", Color(1.0, 0.98, 0.92))
	t.set_color("font_pressed_color", "Button", EMBER)
	t.set_color("font_disabled_color", "Button", DIM)
	t.set_font_size("font_size", "Button", body)
	t.set_stylebox("panel", "TabContainer", _box(PANEL_BG, PANEL_BORDER, 4, 6.0))
	var sel := _box(BTN_BG_HOVER, EMBER_DIM, 3, 7.0)
	sel.border_width_bottom = 0
	var unsel := _box(Color(0, 0, 0, 0.25), Color(0.1, 0.14, 0.18), 3, 7.0)
	unsel.border_width_bottom = 0
	t.set_stylebox("tab_selected", "TabContainer", sel)
	t.set_stylebox("tab_unselected", "TabContainer", unsel)
	t.set_color("font_selected_color", "TabContainer", EMBER)
	t.set_color("font_unselected_color", "TabContainer", DIM)
	t.set_font_size("font_size", "TabContainer", body)
	t.set_stylebox("normal", "LineEdit", _box(Color(0.05, 0.07, 0.095), PANEL_BORDER, 3, 6.0))
	t.set_stylebox("focus", "LineEdit", _box(Color(0.05, 0.07, 0.095), EMBER_DIM, 3, 6.0))
	t.set_color("font_color", "LineEdit", PALE)
	t.set_color("caret_color", "LineEdit", EMBER)
	t.set_stylebox("panel", "TooltipPanel", _box(Color(0.04, 0.06, 0.08, 0.97), EMBER_DIM))
	t.set_color("font_color", "TooltipLabel", PALE)
	t.set_font_size("font_size", "TooltipLabel", body if _font_small != null else 9)
	# separators: a quiet 1 px rule (Haven/panel section breaks)
	var sep := StyleBoxLine.new()
	sep.color = PANEL_BORDER
	sep.thickness = 1
	t.set_stylebox("separator", "HSeparator", sep)
	t.set_constant("separation", "HSeparator", 5)
	_theme = t
	return t
