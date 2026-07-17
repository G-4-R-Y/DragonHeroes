# PROTOTYPE HARNESS — pooled elemental VFX. A fixed pool of CPUParticles2D
# one-shot emitters (14 additive "emissive" + 8 normal "debris") plus 4 pooled
# lightning Line2Ds — nothing is allocated mid-fight, and the worst case stays
# under ~400 concurrent particles (22 emitters x <=24 amount + ambient/trails).
# Juice pass adds two pooled primitives: afterimage GHOSTS (8 Sprite2Ds — dodge
# trails, snapshot a frame texture and fade) and a DUST puff preset over burst().
# The shipping path is GPU-driven particles with explicit budgets (docs/design/17);
# this pool is its gl_compatibility stand-in and dies when dh-godot lands.
class_name ProtoFx
extends Node2D

const ADD_POOL := 20         # 100x pass (Ricardo): richer bursts, still pooled
const NORM_POOL := 12
const BOLT_POOL := 4
const RING_POOL := 12        # expanding shockwave rings (was 8) — a 3-ring
                             # fx.shockwave() can't starve the nova/impact rings
const GHOST_POOL := 8        # afterimage sprites (dodge/dash trails)
const MAX_AMOUNT := 40

# Master spectacle / quality knob (spec §4). LOW/MED/HIGH = 0.15 / 0.5 / 1.0;
# mobile default MED. Read by ribbons, post, damage numbers, and the particle
# amount scale below. Governing invariant: pools are sized for the HIGH ceiling
# at load; intensity gates per-frame USAGE only, never allocation.
static var intensity: float = 0.5

var _add: Array = []
var _norm: Array = []
var _bolts: Array = []
var _rings: Array = []
var _ghosts: Array = []
var _bolt_tw: Array = []     # per-slot running tween — killed on slot reuse so a
var _ring_tw: Array = []     # recycled node is never fought over by a stale fade
var _ghost_tw: Array = []
var _ai := 0
var _ni := 0
var _bi := 0
var _ri := 0
var _gi := 0

var _ribbons: ProtoRibbons          # orbital / sweeping-trail MultiMesh (ribbons.gd)
var _shader_fx: ProtoShaderFx       # pooled procedural-shader quads (shader_fx.gd)
var _lights: ProtoLights            # ground light pools (lights.gd) — under entities
var _aura_seq := 0
var _auras: Dictionary = {}         # handle -> {tele:int, ribbons:Array[int]}

func _ready() -> void:
	z_index = 18
	_ribbons = ProtoRibbons.new()   # ONE MultiMesh, one draw call; sized for HIGH
	add_child(_ribbons)
	_shader_fx = ProtoShaderFx.new()  # vfx_lab shader effects, pooled quads
	add_child(_shader_fx)
	_lights = ProtoLights.new()       # ground light pools, ONE MultiMesh draw
	add_child(_lights)
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
		_bolt_tw.append(null)
	for i in RING_POOL:
		var r := Line2D.new()
		r.width = 2.5
		r.material = ProtoGlow.add_material()
		r.closed = true
		r.visible = false
		r.z_index = 24
		add_child(r)
		_rings.append(r)
		_ring_tw.append(null)
	for i in GHOST_POOL:
		var g := Sprite2D.new()
		g.visible = false
		g.z_index = -8   # under the sparks/rings — trails read as behind the actor
		add_child(g)
		_ghosts.append(g)
		_ghost_tw.append(null)

# Kill the recycled slot's running tween before reprogramming the node.
func _reuse(tweens: Array, idx: int) -> void:
	var tw: Tween = tweens[idx]
	if tw != null and tw.is_valid():
		tw.kill()
	tweens[idx] = null

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
	# intensity scales EMITTED amount only (pool node counts stay fixed); floor 1.
	var amt_scale := lerpf(0.4, 1.0, intensity)
	p.amount = clampi(int(round(int(cfg.get("amount", 12)) * amt_scale)), 1, MAX_AMOUNT)
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
# `width` defaults to the pool's baseline 2.5; fx.shockwave() passes fatter rings.
func ring(at: Vector2, color: Color, radius: float, duration := 0.35, width := 2.5) -> void:
	var r: Line2D = _rings[_ri]
	_reuse(_ring_tw, _ri)
	var slot := _ri
	_ri = (_ri + 1) % RING_POOL
	r.width = width
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
	_ring_tw[slot] = tw

# Tiny pooled ring pop — projectile impact "squash flash" (short + small so the
# knife-fan worst case can't starve the nova rings for long).
func impact_pop(at: Vector2, color: Color) -> void:
	ring(at, Color(color.r, color.g, color.b, 0.85), 9.0, 0.16)

# Grounded dust puff (brute slams, pounce landings, boss dives) — normal-blend
# so it reads as dirt, not light. Rides the same pooled burst path.
func dust(at: Vector2, strength := 1.0) -> void:
	burst(at, {"add": false, "amount": int(10.0 * strength), "lifetime": 0.45,
			"direction": Vector2.UP, "spread": 70.0, "v_min": 20.0,
			"v_max": 70.0 * strength, "gravity": Vector2(0, -30),
			"s_min": 1.2, "s_max": 2.4 * strength,
			"color": Color(0.62, 0.56, 0.45, 0.5)})

# Pooled afterimage ghost: snapshot of an actor frame left behind by a dash.
# Fades out fast; slot reuse kills the previous fade first (no fighting tweens).
func afterimage(tex: Texture2D, at: Vector2, flip: bool, spr_scale: Vector2,
		tint := Color(0.55, 0.9, 1.0, 0.45), life := 0.25) -> void:
	if tex == null:
		return
	var g: Sprite2D = _ghosts[_gi]
	_reuse(_ghost_tw, _gi)
	var slot := _gi
	_gi = (_gi + 1) % GHOST_POOL
	g.texture = tex
	g.global_position = at
	g.flip_h = flip
	g.global_scale = spr_scale
	g.modulate = tint
	g.visible = true
	var tw := g.create_tween()
	tw.tween_property(g, "modulate:a", 0.0, life) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: g.visible = false)
	_ghost_tw[slot] = tw

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
	_reuse(_bolt_tw, _bi)
	var slot := _bi
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
	_bolt_tw[slot] = tw

# Jagged white-blue strike from the sky — thunder SFX is the caller's business.
func lightning(at: Vector2) -> void:
	var l: Line2D = _bolts[_bi]
	_reuse(_bolt_tw, _bi)
	var slot := _bi
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
	_bolt_tw[slot] = tw
	burst(at, {"amount": 10, "lifetime": 0.25, "v_min": 70.0, "v_max": 200.0,
			"s_min": 0.7, "s_max": 1.6, "color": Color(0.8, 0.92, 1.0, 0.95)})

# ---- ribbon forwarders (ribbons.gd — orbital / sweeping-trail MultiMesh) --------
# Thin pass-throughs so callers keep the main.fx.<preset>() contract. cfg keys
# (all optional, sane defaults): count, radius(r0), r1, radius_jitter, turns,
# ang_vel, span, dir, life, width, color, owner, cw.

func orbital(center: Vector2, cfg: Dictionary = {}) -> void:
	_ribbons.spawn_orbit(center, cfg)

func ribbon_arc(at: Vector2, dir: Vector2, cfg: Dictionary = {}) -> void:
	_ribbons.spawn_crescent(at, dir, cfg)

func ribbon_streak(from: Vector2, to: Vector2, cfg: Dictionary = {}) -> void:
	_ribbons.spawn_streak(from, to, cfg)

func ribbon_radial(center: Vector2, cfg: Dictionary = {}) -> void:
	_ribbons.spawn_radial(center, cfg)

# STREAK_FOLLOW trail pinned to a node; returns an id. cfg.life is the orphan
# fallback so a bolt that frees without trail_detach still self-releases.
func trail_attach(node: Node2D, cfg: Dictionary = {}) -> int:
	return _ribbons.attach(node, cfg)

func trail_detach(id: int) -> void:
	_ribbons.detach(id)

# ---- procedural-shader effects (vfx_lab): slash / nova / vortex / firestorm /
# impact — hi-res fragment math on pooled quads; see shader_fx.gd -------------
func shader_burst(kind: String, at: Vector2, cfg: Dictionary = {}) -> int:
	return _shader_fx.burst(kind, at, cfg)

# Early fade for a persistent shader burst (lava fusion consumes a field).
func shader_kill(id: int) -> void:
	_shader_fx.kill(id)

# ---- ground light pools (lights.gd): soft additive ellipses UNDER entities —
# the "effects light the world" layer. cfg: radius, color, alpha, life
# (<0 = until detach), flicker, rate, offset (attach only) ---------------------
func light_at(at: Vector2, cfg: Dictionary = {}) -> int:
	return _lights.place(at, cfg)

func light_attach(node: Node2D, cfg: Dictionary = {}) -> int:
	return _lights.attach(node, cfg)

func light_detach(id: int) -> void:
	_lights.detach(id)

# ---- shockwave: fat multi-ring impact / nova / death nova -----------------------
# cfg: rings (default 3, staggered radii + phase), width (thicker than ring's 2.5),
# life. Rides the pooled RING_POOL (bumped to 12 so a 3-ring wave can't starve it).
func shockwave(at: Vector2, color: Color, radius: float, cfg: Dictionary = {}) -> void:
	var rings := maxi(1, int(cfg.get("rings", 3)))
	var w := float(cfg.get("width", 5.0))
	var life := float(cfg.get("life", 0.45))
	for n in rings:
		var t := float(n) / float(rings)
		var r := radius * (0.6 + 0.4 * t)                # staggered radii
		var dur := life * (0.85 + 0.35 * t)              # staggered decay = phase feel
		var a := clampf(0.85 - 0.18 * float(n), 0.25, 1.0)
		ring(at, Color(color.r, color.g, color.b, a), r, dur, w * (1.0 - 0.2 * t))

# ---- aura: persistent glowing ring + orbiting ribbons following an owner --------
# Green = player buff protection; red/orange = boss enrage. Delegates the ring to
# ProtoTelegraphs (AURA descriptor) and pins cfg.orbit_ribbons ORBIT ribbons tinted
# to the owner. Returns an opaque handle for aura_detach(). cfg: radius, dur, pulse,
# orbit_ribbons.
func aura(owner: Node2D, color: Color, cfg: Dictionary = {}) -> int:
	var radius := float(cfg.get("radius", 22.0))
	var dur := float(cfg.get("dur", 2.0))
	var orbits := maxi(0, int(cfg.get("orbit_ribbons", 3)))
	var handle := _aura_seq
	_aura_seq += 1
	var tele := -1
	var m := get_tree().get_first_node_in_group("main")
	if m != null and m.get("telegraphs") != null:
		tele = m.telegraphs.aura(owner, color, {"radius": radius, "dur": dur,
				"pulse": cfg.get("pulse", true)})
	var ids: Array = []
	for n in orbits:
		var id: int = _ribbons.pin_orbit(owner, {"radius": radius + 6.0, "life": dur,
				"width": 4.0, "color": color, "turns": maxf(dur, 0.5),
				"phase": TAU * float(n) / float(maxi(orbits, 1))})
		if id >= 0:
			ids.append(id)
	_auras[handle] = {"tele": tele, "ribbons": ids}
	return handle

func aura_detach(handle: int) -> void:
	if not _auras.has(handle):
		return
	var rec: Dictionary = _auras[handle]
	var m := get_tree().get_first_node_in_group("main")
	if int(rec.tele) >= 0 and m != null and m.get("telegraphs") != null:
		m.telegraphs.clear(int(rec.tele))
	for id in rec.ribbons:
		_ribbons.detach(int(id))
	_auras.erase(handle)

# Aggregate pool health for the budget harness (fx.gd's own pools are fixed-size
# round-robin; the ribbon sub-pool reports its live peak).
func _pool_debug() -> Dictionary:
	var rb: Dictionary = _ribbons._pool_debug() if _ribbons != null else {"size": 0, "peak_in_use": 0}
	var lt: Dictionary = _lights._pool_debug() if _lights != null else {"size": 0, "peak_in_use": 0}
	return {"ribbons": rb, "lights": lt, "add_pool": ADD_POOL, "ring_pool": RING_POOL}
