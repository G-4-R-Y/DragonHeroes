# PROTOTYPE HARNESS — pooled danger telegraphs + aura (spec §2.4). Retires the
# per-cast telegraph.gd (ProtoTelegraph.new()); every windup/aura now claims a slot
# from ONE 24-descriptor pool. Two sibling draw nodes iterate that same pool so the
# whole system costs exactly TWO draw calls: _base (normal blend — dark readable
# danger fills) and _glow (shared ADD material — bright edges, converging beams,
# aura rings). Zero per-cast allocation.
#
# Telegraphs are GAMEPLAY INFORMATION — never intensity-scaled (a danger ring always
# renders at full clarity); only the additive _glow embellishment is "spectacle".
# On the default canvas at z=-2: above terrain/fields, under actors, lightly graded
# by the post pass.
class_name ProtoTelegraphs
extends Node2D

enum Kind { RING, LINE, BEAMS, AURA }

const CAP := 24                  # descriptor slots (slot 0 reserved for player aura)
const AMBER := Color(1.0, 0.55, 0.15, 1.0)
const RED := Color(1.0, 0.2, 0.15, 1.0)

class Desc:
	var active := false
	var kind := 0
	var pos := Vector2.ZERO
	var owner: Node2D = null
	var radius := 0.0
	var length := 0.0
	var width := 0.0
	var dir := Vector2.RIGHT
	var t := 0.0
	var duration := 1.0
	var color := Color(1, 0.55, 0.15, 1)
	# BEAMS params
	var count := 6
	var spread := TAU
	var converge := 180.0

var _base: Node2D
var _glow: Node2D
var _pool: Array = []
var _gen := PackedInt32Array()   # per-slot generation, for safe clear(id)
var _peak := 0

func _ready() -> void:
	z_index = -2
	_base = Node2D.new()
	_base.z_index = 0
	add_child(_base)
	_base.draw.connect(_draw_base)
	_glow = Node2D.new()
	_glow.z_index = 1
	_glow.material = ProtoGlow.add_material()
	add_child(_glow)
	_glow.draw.connect(_draw_glow)
	_gen.resize(CAP)
	for i in CAP:
		_pool.append(Desc.new())
		_gen[i] = 0
	set_process(true)

# ---- id packing (slot + generation, so a stale clear() can't nuke a reused slot) -

func _mk_id(slot: int) -> int:
	return (slot << 16) | (_gen[slot] & 0xFFFF)

# ---- claim ----------------------------------------------------------------------

func _activate(s: int) -> int:
	var d: Desc = _pool[s]
	d.active = true
	d.t = 0.0
	_gen[s] = (_gen[s] + 1) & 0xFFFF
	if OS.is_debug_build():
		var used := 0
		for i in CAP:
			if _pool[i].active:
				used += 1
		_peak = maxi(_peak, used)
		assert(used <= CAP)
	return s

# General claim scans [1,CAP) (slot 0 is reserved for the player aura); on a full
# pool it steals the closest-to-expiry non-AURA slot so danger tells never leak.
func _claim_general() -> int:
	for s in range(1, CAP):
		if not _pool[s].active:
			return _activate(s)
	var best := -1
	var best_frac := -1.0
	for s in range(1, CAP):
		var d: Desc = _pool[s]
		if d.kind == Kind.AURA:
			continue
		var frac := d.t / maxf(d.duration, 0.001)
		if frac > best_frac:
			best_frac = frac
			best = s
	if best < 0:
		return -1
	return _activate(best)

# ---- API (spec §2.4) ------------------------------------------------------------

func ring(pos: Vector2, radius: float, dur: float, color := AMBER) -> int:
	var s := _claim_general()
	if s < 0:
		return -1
	var d: Desc = _pool[s]
	d.kind = Kind.RING
	d.pos = pos
	d.radius = radius
	d.duration = maxf(dur, 0.01)
	d.color = color
	d.owner = null
	return _mk_id(s)

func line(p0: Vector2, dir: Vector2, length: float, width: float, dur: float,
		color := AMBER) -> int:
	var s := _claim_general()
	if s < 0:
		return -1
	var d: Desc = _pool[s]
	d.kind = Kind.LINE
	d.pos = p0
	d.dir = dir.normalized()
	d.length = length
	d.width = width
	d.duration = maxf(dur, 0.01)
	d.color = color
	d.owner = null
	return _mk_id(s)

# Red converging warning: `count` tapered wedges advancing inward as t->1. cfg:
# count, spread (radians; >=TAU = full radial enrage burst), converge_dist, dur, color.
func beams(pos: Vector2, dir: Vector2, cfg: Dictionary = {}) -> int:
	var s := _claim_general()
	if s < 0:
		return -1
	var d: Desc = _pool[s]
	d.kind = Kind.BEAMS
	d.pos = pos
	d.dir = dir.normalized() if dir.length() > 0.001 else Vector2.RIGHT
	d.count = maxi(1, int(cfg.get("count", 6)))
	d.spread = float(cfg.get("spread", TAU))
	d.converge = float(cfg.get("converge_dist", 180.0))
	d.duration = maxf(float(cfg.get("dur", 0.8)), 0.01)
	d.color = cfg.get("color", RED)
	d.owner = null
	return _mk_id(s)

# Persistent bright ring following an owner. cfg: radius, dur (<=0 = persistent
# until clear() / owner invalid), pulse. green = protective, red/orange = enrage.
func aura(owner: Node2D, color: Color, cfg: Dictionary = {}) -> int:
	var s := -1
	if not _pool[0].active:
		s = _activate(0)
	else:
		s = _claim_general()
	if s < 0:
		return -1
	var d: Desc = _pool[s]
	d.kind = Kind.AURA
	d.owner = owner
	d.color = color
	d.radius = float(cfg.get("radius", 22.0))
	d.duration = float(cfg.get("dur", 2.0))
	d.pos = owner.global_position if is_instance_valid(owner) else Vector2.ZERO
	return _mk_id(s)

func clear(id: int) -> void:
	if id < 0:
		return
	var slot := id >> 16
	var gen := id & 0xFFFF
	if slot < 0 or slot >= CAP:
		return
	if _pool[slot].active and _gen[slot] == gen:
		_pool[slot].active = false
		_pool[slot].owner = null

# ---- per-frame -------------------------------------------------------------------

func _process(dt: float) -> void:
	for s in CAP:
		var d: Desc = _pool[s]
		if not d.active:
			continue
		d.t += dt
		if d.kind == Kind.AURA:
			if not is_instance_valid(d.owner):
				d.active = false
				continue
			d.pos = d.owner.global_position
			if d.duration > 0.0 and d.t >= d.duration:
				d.active = false
		elif d.t >= d.duration:
			d.active = false
	_base.queue_redraw()
	_glow.queue_redraw()

# ---- drawing (two nodes, one shared pool, two draw calls) -----------------------

func _draw_base() -> void:
	for s in CAP:
		var d: Desc = _pool[s]
		if not d.active:
			continue
		var c := d.color
		var f := clampf(d.t / d.duration, 0.0, 1.0) if d.duration > 0.0 else 1.0
		match d.kind:
			Kind.RING:
				# alphas rebalanced for the dark world (canon §12.28): over the
				# multiplied ambient the old bright-ground values read as a
				# solid neon wall; danger info needs far less paint now
				_base.draw_circle(d.pos, d.radius, Color(c.r, c.g, c.b, 0.11))
				_base.draw_circle(d.pos, d.radius * f, Color(c.r, c.g, c.b, 0.22))
			Kind.LINE:
				var dd := d.dir
				var nn := dd.orthogonal() * d.width * 0.5
				var tip := d.pos + dd * d.length
				_base.draw_colored_polygon(
						PackedVector2Array([d.pos - nn, tip - nn, tip + nn, d.pos + nn]),
						Color(c.r, c.g, c.b, 0.11))
				var ftip := d.pos + dd * d.length * f
				_base.draw_colored_polygon(
						PackedVector2Array([d.pos - nn, ftip - nn, ftip + nn, d.pos + nn]),
						Color(c.r, c.g, c.b, 0.2))

func _draw_glow() -> void:
	for s in CAP:
		var d: Desc = _pool[s]
		if not d.active:
			continue
		var c := d.color
		var f := clampf(d.t / d.duration, 0.0, 1.0) if d.duration > 0.0 else 1.0
		match d.kind:
			Kind.RING:
				_glow.draw_arc(d.pos, d.radius, 0, TAU, 48, Color(c.r, c.g, c.b, 0.55), 2.0)
			Kind.LINE:
				var dd := d.dir
				var nn := dd.orthogonal() * d.width * 0.5
				var tip := d.pos + dd * d.length
				var edge := Color(c.r, c.g, c.b, 0.55)
				_glow.draw_line(d.pos - nn, tip - nn, edge, 2.0)
				_glow.draw_line(d.pos + nn, tip + nn, edge, 2.0)
			Kind.BEAMS:
				_draw_beams(d, f, c)
			Kind.AURA:
				var op := d.owner.global_position if is_instance_valid(d.owner) else d.pos
				var pr := d.radius + sin(d.t * 6.0) * 2.0
				_glow.draw_arc(op, pr, 0, TAU, 40, Color(c.r, c.g, c.b, 0.55), 2.5)
				_glow.draw_arc(op, pr * 0.68, 0, TAU, 28, Color(c.r, c.g, c.b, 0.28), 1.5)

func _draw_beams(d: Desc, f: float, c: Color) -> void:
	var full := d.spread >= TAU - 0.001
	var base_ang := d.dir.angle()
	var far_d := d.converge + 40.0
	var near_d := lerpf(d.converge, 12.0, f)   # near ends advance inward as t->1
	var wide := 11.0
	# per-wedge alpha normalized by count: a 24-beam converging cast must carry
	# roughly the same total light as a 6-beam one, or the additive overlap at
	# the apex white-walls the whole zone (seen on legendary casts in captures)
	var a := clampf(0.2 + 0.35 * f, 0.0, 1.0) \
			* clampf(6.0 / float(maxi(d.count, 1)), 0.3, 1.0)
	var col := Color(c.r, c.g, c.b, a)
	for kk in d.count:
		var ba: float
		if full:
			ba = TAU * float(kk) / float(d.count)
		else:
			ba = base_ang + d.spread * (float(kk) / float(maxi(d.count - 1, 1)) - 0.5)
		var da := Vector2.from_angle(ba)
		var perp := da.orthogonal()
		var apex := d.pos + da * near_d
		var b1 := d.pos + da * far_d + perp * wide
		var b2 := d.pos + da * far_d - perp * wide
		_glow.draw_colored_polygon(PackedVector2Array([apex, b1, b2]), col)

func _pool_debug() -> Dictionary:
	return {"size": CAP, "peak_in_use": _peak}
