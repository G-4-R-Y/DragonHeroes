# HUD skill chip (roadmap 4b — Ricardo: "skills don't even got icons, no clear
# cooldown countdown"). A 26x26 framed tile with a PROCEDURAL glyph per skill
# kind (pixel doctrine: crisp 1 px strokes, no art-pipeline dependency), a
# top-down cooldown sweep, a numeric countdown under 10 s, and an ember edge
# glow when ready. Drawn in _draw() — zero per-frame allocation, bounded calls.
class_name HudSkillChip
extends Control

const SIZE := 26.0
const FRAME := Color(0.35, 0.42, 0.55, 0.9)
const FRAME_READY := Color("ffb45c")
const BG := Color(0.04, 0.05, 0.08, 0.85)
const SWEEP := Color(0.0, 0.0, 0.0, 0.72)
const KIND_TINT := {
	"melee_arc": Color("c9d4e8"), "projectile": Color("7fd8ff"),
	"cone": Color("ff9a3c"), "chain": Color("b78cff"),
	"nova": Color("ffd166"), "field": Color("7ce7a2"),
}

var kind := ""
var key_text := ""
var cd_frac := 0.0        # 0 = ready, 1 = just cast
var cd_left := 0.0        # seconds (numeric countdown under 10)
var pulse := 0.0
var empty := true

var _cd_label: Label

func _init() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	_cd_label = Label.new()
	_cd_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cd_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cd_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cd_label.add_theme_font_size_override("font_size", 10)
	_cd_label.add_theme_color_override("font_color", Color.WHITE)
	_cd_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cd_label)

func set_state(p_kind: String, p_cd_frac: float, p_left: float,
		p_empty: bool, p_pulse: float) -> void:
	if p_kind == kind and is_equal_approx(p_cd_frac, cd_frac) \
			and p_empty == empty and is_equal_approx(p_left, cd_left):
		pulse = p_pulse   # cheap early-out: redraws only on change
		return
	kind = p_kind
	cd_frac = clampf(p_cd_frac, 0.0, 1.0)
	cd_left = p_left
	empty = p_empty
	pulse = p_pulse
	_cd_label.text = "" if cd_left < 0.05 or cd_left > 10.0 else "%.0f" % ceil(cd_left)
	queue_redraw()

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, Vector2(SIZE, SIZE))
	draw_rect(r, BG, true)
	if empty:
		draw_rect(r, FRAME.darkened(0.55), false, 1.0)
		return
	var tint: Color = KIND_TINT.get(kind, Color("d9d4c7"))
	_glyph(kind, tint)
	# cooldown sweep: darkness drains top-down as the cooldown burns
	if cd_frac > 0.0:
		draw_rect(Rect2(Vector2.ZERO, Vector2(SIZE, SIZE * cd_frac)), SWEEP, true)
	# frame: ember breathing when ready
	var f := FRAME
	if cd_frac <= 0.0:
		f = FRAME_READY.lerp(Color.WHITE, 0.35 * pulse)
	draw_rect(r, f, false, 1.0)
	# keybind corner digit
	if key_text != "":
		draw_string(ProtoTheme.font_small(), Vector2(SIZE - 9, SIZE - 3), key_text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 1, 1, 0.7))

# 1 px-stroke procedural glyphs, one per skill kind (skill_trees.json "kind").
func _glyph(g: String, tint: Color) -> void:
	var c := Vector2(SIZE, SIZE) * 0.5
	match g:
		"melee_arc":   # blade slash: arc + tip
			draw_arc(c, 7.5, -2.4, 0.9, 10, tint, 1.6)
			draw_line(c + Vector2(6.5, 3.5), c + Vector2(9, 5.5), tint, 1.6)
		"projectile":  # bolt: shaft + head + trail
			draw_line(c + Vector2(-7, 6), c + Vector2(3, -4), tint, 1.6)
			draw_line(c + Vector2(3, -4), c + Vector2(7, -8), tint, 2.2)
			draw_line(c + Vector2(-6, 2), c + Vector2(-2, -2), tint.darkened(0.4), 1.0)
		"cone":        # flame cone: fan of three tongues
			for i in 3:
				var a := -1.9 + i * 0.55
				draw_line(c + Vector2(-5, 6), c + Vector2(-5, 6) + Vector2(cos(a), sin(a)) * 11.0,
						tint.lerp(Color.WHITE, i * 0.15), 1.4)
		"chain":       # two interlocked links
			draw_rect(Rect2(c + Vector2(-8, -3), Vector2(7, 6)), tint, false, 1.3)
			draw_rect(Rect2(c + Vector2(1, -3), Vector2(7, 6)), tint, false, 1.3)
		"nova":        # ring + core
			draw_arc(c, 7.0, 0, TAU, 14, tint, 1.4)
			draw_circle(c, 2.0, tint)
		"field":       # ground circle + rune dot
			draw_arc(c + Vector2(0, 3), 6.5, 0, TAU, 12, tint, 1.2)
			draw_circle(c + Vector2(0, -4), 1.6, tint)
		_:             # default diamond
			var d := 6.0
			draw_colored_polygon(PackedVector2Array([
					c + Vector2(0, -d), c + Vector2(d, 0),
					c + Vector2(0, d), c + Vector2(-d, 0)]), tint)
