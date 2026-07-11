# PROTOTYPE HARNESS — pooled elemental VFX. A fixed pool of CPUParticles2D
# one-shot emitters (14 additive "emissive" + 8 normal "debris") plus 4 pooled
# lightning Line2Ds — nothing is allocated mid-fight, and the worst case stays
# under ~400 concurrent particles (22 emitters x <=24 amount + ambient/trails).
# The shipping path is GPU-driven particles with explicit budgets (docs/design/17);
# this pool is its gl_compatibility stand-in and dies when dh-godot lands.
class_name ProtoFx
extends Node2D

const ADD_POOL := 20         # 100x pass (Ricardo): richer bursts, still pooled
const NORM_POOL := 12
const BOLT_POOL := 4
const RING_POOL := 6         # expanding shockwave rings (Line2D circles)
const MAX_AMOUNT := 40

var _add: Array = []
var _norm: Array = []
var _bolts: Array = []
var _rings: Array = []
var _ai := 0
var _ni := 0
var _bi := 0
var _ri := 0

func _ready() -> void:
	z_index = 18
	for i in ADD_POOL:
		_add.append(_mk(true))
	for i in NORM_POOL:
		_norm.append(_mk(false))
	for i in BOLT_POOL:
		var l := Line2D.new()
		l.width = 2.0
		l.material = ProtoGlow.add_material()
		l.visible = false
		l.z_index = 30
		add_child(l)
		_bolts.append(l)
	for i in RING_POOL:
		var r := Line2D.new()
		r.width = 2.5
		r.material = ProtoGlow.add_material()
		r.closed = true
		r.visible = false
		r.z_index = 24
		add_child(r)
		_rings.append(r)

func _mk(add_blend: bool) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.emitting = false
	p.local_coords = false
	p.texture = ProtoSprites.spore_tex()
	if add_blend:
		p.material = ProtoGlow.add_material()
	add_child(p)
	return p

# Generic pooled one-shot burst. cfg keys (all optional): add, amount, lifetime,
# direction, spread, v_min, v_max, gravity, s_min, s_max, color, ramp (Gradient),
# texture, tangential, emission_radius.
func burst(at: Vector2, cfg: Dictionary = {}) -> void:
	var add_blend: bool = cfg.get("add", true)
	var p: CPUParticles2D
	if add_blend:
		p = _add[_ai]
		_ai = (_ai + 1) % ADD_POOL
	else:
		p = _norm[_ni]
		_ni = (_ni + 1) % NORM_POOL
	p.global_position = at
	p.amount = mini(int(cfg.get("amount", 12)), MAX_AMOUNT)
	p.lifetime = float(cfg.get("lifetime", 0.4))
	p.direction = cfg.get("direction", Vector2.UP)
	p.spread = float(cfg.get("spread", 180.0))
	p.initial_velocity_min = float(cfg.get("v_min", 40.0))
	p.initial_velocity_max = float(cfg.get("v_max", 120.0))
	p.gravity = cfg.get("gravity", Vector2(0, 160))
	p.scale_amount_min = float(cfg.get("s_min", 0.8))
	p.scale_amount_max = float(cfg.get("s_max", 2.0))
	p.tangential_accel_min = float(cfg.get("tangential", 0.0))
	p.tangential_accel_max = float(cfg.get("tangential", 0.0))
	p.texture = cfg.get("texture", ProtoSprites.spore_tex())
	if cfg.has("ramp"):
		p.color_ramp = cfg.get("ramp")
		p.color = Color(1, 1, 1)
	else:
		p.color_ramp = null
		p.color = cfg.get("color", Color(1, 1, 1))
	if cfg.has("emission_radius"):
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE_SURFACE
		p.emission_sphere_radius = float(cfg.get("emission_radius"))
	else:
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINT
	p.restart()
	p.emitting = true

# ---- presets --------------------------------------------------------------------

func explosion(at: Vector2, color: Color, big := false) -> void:
	burst(at, {"amount": 20 if big else 12, "lifetime": 0.5, "v_min": 60.0,
			"v_max": 220.0 if big else 150.0, "gravity": Vector2(0, 60),
			"s_min": 1.2, "s_max": 3.2 if big else 2.4, "color": color})
	burst(at, {"amount": 8, "lifetime": 0.3, "v_min": 90.0, "v_max": 260.0,
			"s_min": 0.7, "s_max": 1.4, "color": Color(1, 1, 1, 0.95)})

func debris(at: Vector2, color := Color(0.42, 0.36, 0.28)) -> void:
	burst(at, {"add": false, "amount": 14, "lifetime": 0.6, "v_min": 60.0,
			"v_max": 190.0, "gravity": Vector2(0, 420), "s_min": 1.0, "s_max": 2.6,
			"color": color})

func flame_cone(at: Vector2, dir: Vector2) -> void:
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	ramp.colors = PackedColorArray([Color(1.0, 0.92, 0.55, 0.95),
			Color(1.0, 0.5, 0.12, 0.75), Color(0.55, 0.12, 0.03, 0.0)])
	burst(at, {"amount": 22, "lifetime": 0.55, "direction": dir, "spread": 24.0,
			"v_min": 150.0, "v_max": 260.0, "gravity": Vector2(0, -30),
			"s_min": 1.6, "s_max": 3.4, "ramp": ramp})

func tornado(at: Vector2) -> void:
	burst(at, {"amount": 22, "lifetime": 0.7, "direction": Vector2.UP,
			"spread": 40.0, "v_min": 30.0, "v_max": 80.0, "gravity": Vector2(0, -200),
			"tangential": 420.0, "emission_radius": 12.0, "s_min": 0.8, "s_max": 1.8,
			"color": Color(0.8, 0.97, 1.0, 0.55)})

# Expanding shockwave ring — the punctuation mark under novas/impacts/slams.
func ring(at: Vector2, color: Color, radius: float, duration := 0.35) -> void:
	var r: Line2D = _rings[_ri]
	_ri = (_ri + 1) % RING_POOL
	var pts := PackedVector2Array()
	for i in 26:
		pts.append(Vector2.from_angle(TAU * i / 26.0))
	r.points = pts
	r.position = at
	r.scale = Vector2.ONE * (radius * 0.25)
	r.default_color = color
	r.visible = true
	r.modulate = Color(1, 1, 1, 1)
	var tw := r.create_tween()
	tw.set_parallel(true)
	tw.tween_property(r, "scale", Vector2.ONE * radius, duration) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(r, "modulate:a", 0.0, duration)
	tw.chain().tween_callback(func() -> void: r.visible = false)

# Directional melee slash trail — a tight fan of sparks along the swing edge.
func arc_slash(at: Vector2, dir: Vector2, color: Color) -> void:
	burst(at, {"amount": 14, "lifetime": 0.22, "direction": dir, "spread": 34.0,
			"v_min": 120.0, "v_max": 240.0, "gravity": Vector2.ZERO,
			"s_min": 0.7, "s_max": 1.6, "color": color})
	burst(at, {"amount": 6, "lifetime": 0.14, "direction": dir, "spread": 12.0,
			"v_min": 200.0, "v_max": 320.0, "s_min": 0.5, "s_max": 1.0,
			"color": Color(1, 1, 1, 0.9)})

# Jagged link between two points — chain skills (Cold Snap, Umbral Coil) hop
# creature to creature on these. Same pooled Line2Ds as the sky bolts.
func arc_link(from: Vector2, to: Vector2, color: Color) -> void:
	var l: Line2D = _bolts[_bi]
	_bi = (_bi + 1) % BOLT_POOL
	var pts := PackedVector2Array()
	var n := 5
	for i in n + 1:
		var p := from.lerp(to, float(i) / float(n))
		if i > 0 and i < n:
			p += Vector2(randf_range(-6.0, 6.0), randf_range(-6.0, 6.0))
		pts.append(p)
	l.points = pts
	l.default_color = color
	l.visible = true
	l.modulate = Color(1, 1, 1, 1)
	var tw := l.create_tween()
	tw.tween_property(l, "modulate:a", 0.0, 0.18)
	tw.tween_callback(func() -> void: l.visible = false)

# Jagged white-blue strike from the sky — thunder SFX is the caller's business.
func lightning(at: Vector2) -> void:
	var l: Line2D = _bolts[_bi]
	_bi = (_bi + 1) % BOLT_POOL
	var pts := PackedVector2Array()
	var from := at + Vector2(randf_range(-26.0, 26.0), -150.0)
	var n := 6
	for i in n + 1:
		var k := float(i) / float(n)
		var p := from.lerp(at, k)
		if i > 0 and i < n:
			p.x += randf_range(-9.0, 9.0)
		pts.append(p)
	l.points = pts
	l.default_color = Color(0.85, 0.95, 1.0, 1.0)
	l.visible = true
	l.modulate = Color(1, 1, 1, 1)
	var tw := l.create_tween()
	tw.tween_property(l, "modulate:a", 0.0, 0.22)
	tw.tween_callback(func() -> void: l.visible = false)
	burst(at, {"amount": 10, "lifetime": 0.25, "v_min": 70.0, "v_max": 200.0,
			"s_min": 0.7, "s_max": 1.6, "color": Color(0.8, 0.92, 1.0, 0.95)})
