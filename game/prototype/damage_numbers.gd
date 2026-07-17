# PROTOTYPE HARNESS — pooled punchy damage numbers (spec §2.5). A dedicated
# CanvasLayer (layer 6) ABOVE the post pass so the pixel text stays crisp (no
# chromatic fringing). 48 Labels are pre-created + hidden with ONE shared
# LabelSettings (no per-label theme); spawns are round-robin, driven by ONE shared
# _process over parallel state arrays — there is NO per-number Tween and ZERO
# per-hit allocation.
#
# main.damage_number(...) delegates here (M wires that one line); the ~34 call sites
# keep their exact signature. Screen position anchors to the world hit-point via
# get_viewport().get_canvas_transform() so numbers ride the camera correctly.
class_name ProtoDamage
extends CanvasLayer

const POOL := 48

var _labels: Array[Label] = []
var _settings: LabelSettings

# Parallel state arrays (index-aligned with _labels). No per-slot object.
var _active := PackedByteArray()
var _world := PackedVector2Array()
var _scatter := PackedFloat32Array()   # horizontal drift px
var _age := PackedFloat32Array()
var _life := PackedFloat32Array()
var _peakscale := PackedFloat32Array()
var _stagger := PackedFloat32Array()   # vertical stack offset (anti-overprint)
var _color := PackedColorArray()
var _crit := PackedByteArray()

var _idx := 0
var _peak := 0
var _stack := 0                        # recent-spawn counter for vertical stacking
var _since_spawn := 1.0

func _ready() -> void:
	layer = 6
	_settings = LabelSettings.new()
	# typography doctrine (ui/theme.gd): the 16 px-native pixel font at its
	# native grid — normal hits settle small/crisp; crits settle ~1.6x via the
	# pop-scale below. A null font (doctrine-only mode) = engine default.
	_settings.font = ProtoTheme.font_big()
	_settings.font_size = ProtoTheme.SIZE_DAMAGE
	_settings.outline_size = 2
	_settings.outline_color = Color(0.02, 0.02, 0.03, 0.95)
	_settings.shadow_size = 2
	_settings.shadow_color = Color(0, 0, 0, 0.55)
	_settings.font_color = Color(1, 1, 1)      # per-number hue rides label.modulate
	_active.resize(POOL)
	_world.resize(POOL)
	_scatter.resize(POOL)
	_age.resize(POOL)
	_life.resize(POOL)
	_peakscale.resize(POOL)
	_stagger.resize(POOL)
	_color.resize(POOL)
	_crit.resize(POOL)
	for i in POOL:
		var l := Label.new()
		l.label_settings = _settings
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.visible = false
		add_child(l)
		_labels.append(l)
		_active[i] = 0
	set_process(true)

func _cap() -> int:
	return clampi(int(round(lerpf(16.0, 48.0, ProtoFx.intensity))), 1, POOL)

# The pooled entry M delegates main.damage_number(...) to. Same grammar: white
# normal / bigger-pop crit / caller-supplied element hue / green heal.
func number(at: Vector2, amount: float, color: Color, text := "", crit := false) -> void:
	var cap := _cap()
	var slot := _idx
	_idx = (_idx + 1) % cap                    # round-robin within the intensity cap
	# vertical stacking: burst-local counter, reset once spawns pause briefly
	if _since_spawn > 0.18:
		_stack = 0
	_stagger[slot] = float(_stack) * 9.0
	_stack = (_stack + 1) % 6
	_since_spawn = 0.0

	_active[slot] = 1
	_world[slot] = at
	_scatter[slot] = randf_range(-12.0, 12.0)
	_age[slot] = 0.0
	_life[slot] = 1.05 if crit else 0.85
	_peakscale[slot] = 2.2 if crit else 1.6
	_color[slot] = color
	_crit[slot] = 1 if crit else 0

	var l := _labels[slot]
	l.text = text if text != "" else _abbr(int(round(amount)))
	l.reset_size()
	l.pivot_offset = l.size * 0.5
	l.modulate = color
	l.visible = true

	if crit:
		var m := get_tree().get_first_node_in_group("main")
		if m != null and m.get("post") != null:
			m.post.pulse(0.25)

# Thousands abbreviate so late-game hits stay readable: 12437 -> "12.4k",
# 2000 -> "2k" (trailing .0 dropped). Below 1k numbers print verbatim.
static func _abbr(v: int) -> String:
	if v < 1000:
		return str(v)
	var tenths := roundi(v / 100.0)        # 12437 -> 124 tenths-of-k
	if tenths % 10 == 0:
		return "%dk" % (tenths / 10)
	return "%d.%dk" % [tenths / 10, tenths % 10]

func _process(dt: float) -> void:
	_since_spawn += dt
	var xform := get_viewport().get_canvas_transform()
	var used := 0
	for s in POOL:
		if _active[s] == 0:
			continue
		_age[s] += dt
		var f := _age[s] / _life[s]
		if f >= 1.0:
			_active[s] = 0
			_labels[s].visible = false
			continue
		used += 1
		var l := _labels[s]
		var base := xform * _world[s]
		var eased := 1.0 - (1.0 - f) * (1.0 - f)
		var off := Vector2(_scatter[s] * f, -26.0 * eased - _stagger[s])
		var pos := base + off
		# scale pop: 0.2 -> peak -> settle. Normal hits settle at 1.0 (native
		# pixel grid = crisp); crits KEEP ~1.6x — the size hierarchy rides this
		# existing pop-scale path, no extra state.
		var settle := 1.6 if _crit[s] == 1 else 1.0
		var sc: float
		if f < 0.18:
			sc = lerpf(0.2, _peakscale[s], f / 0.18)
		else:
			sc = lerpf(_peakscale[s], settle, clampf((f - 0.18) / 0.30, 0.0, 1.0))
		var a := 1.0
		if f > 0.7:
			a = clampf(1.0 - (f - 0.7) / 0.3, 0.0, 1.0)
		l.scale = Vector2.ONE * sc
		# floor to whole canvas pixels — settled text sits ON the art grid
		l.position = (pos - l.size * 0.5).floor()
		var c := _color[s]
		l.modulate = Color(c.r, c.g, c.b, a)
	_peak = maxi(_peak, used)

func _pool_debug() -> Dictionary:
	return {"size": POOL, "peak_in_use": _peak}
