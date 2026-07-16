# PROTOTYPE HARNESS — orbital / sweeping-trail ribbon system (spec §2.1).
# ONE MultiMesh, ONE draw call, 640 instances (MAX_RIBBONS 40 x SEG 16) allocated
# once in _ready(); nothing allocates mid-fight. Each ribbon owns a contiguous
# instance range [s*SEG, s*SEG+SEG); active ribbons are kept compacted in the
# prefix [0, _active_count) (swap-remove on death) so visible_instance_count is
# always a clean prefix. The global ProtoFx.intensity knob gates USAGE per frame
# (active_cap / seg_used), never allocation — lowering never frees, raising never
# allocates, so there is no mid-session hitch either direction.
#
# The gl_compatibility fake-bloom path: the shared ADD-blend CanvasItemMaterial
# (ProtoGlow.add_material) + the soft ribbon_tex strip make swept quads read as
# glowing additive light. Under Vulkan the same emissive pixels also feed the real
# WorldEnvironment glow (main.gd opt-in) — this layer stays correct in both paths.
class_name ProtoRibbons
extends MultiMeshInstance2D

enum Mode { ORBIT, CRESCENT, STREAK, STREAK_FOLLOW, RADIAL }

const MAX_RIBBONS := 40
const SEG := 16                       # segments per ribbon (== instances per ribbon)

# Per-ribbon state. Pre-allocated MAX_RIBBONS times in _ready(); reused forever.
# The spine is a ring buffer of SEG+1 world points (the swept trail history);
# head_idx points at the newest sample. Never re-sized after construction.
class Ribbon:
	var active := false
	var mode := 0
	var age := 0.0
	var life := 1.0
	var color := Color.WHITE
	var width := 6.0
	var taper := 0.2                  # tail width fraction (fat head -> thin tail)
	var owner: Node2D = null
	var pinned := false               # STREAK_FOLLOW / aura orbit — never stolen
	var id := -1                      # stable handle for detach(); -1 = one-shot
	var spine := PackedVector2Array()
	var head_idx := 0
	# mode params
	var center := Vector2.ZERO
	var r0 := 0.0
	var angle := 0.0
	var ang_vel := 0.0
	var dir := Vector2.RIGHT
	var from := Vector2.ZERO
	var to := Vector2.ZERO
	var span := 0.0

var _mm: MultiMesh
var _pool: Array = []                 # MAX_RIBBONS Ribbon objects (never resized)
var _active_count := 0                # active ribbons live in _pool[0.._active_count)
var _next_id := 1
var _peak := 0
# Collapsed transform for unused segments (zero basis -> zero-area quad = invisible).
var _zero_xf := Transform2D(Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)

func _ready() -> void:
	z_as_relative = false
	z_index = 20                      # above fx particles (18), below bolt/ring accents
	texture_filter = TEXTURE_FILTER_LINEAR   # global filter is NEAREST — override locally
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_2D
	_mm.use_colors = true
	var q := QuadMesh.new()
	q.size = Vector2.ONE              # unit 1x1 centered quad; scaled per segment
	_mm.mesh = q
	_mm.instance_count = MAX_RIBBONS * SEG
	_mm.visible_instance_count = 0
	multimesh = _mm
	material = ProtoGlow.add_material()
	texture = ProtoSprites.ribbon_tex()
	for i in MAX_RIBBONS:
		var rb := Ribbon.new()
		rb.spine.resize(SEG + 1)
		_pool.append(rb)
	set_process(true)

# ---- intensity gates (usage only — never allocation) ----------------------------

func _active_cap() -> int:
	return maxi(6, int(round(lerpf(6.0, 40.0, ProtoFx.intensity))))

func _seg_used() -> int:
	return clampi(int(round(lerpf(8.0, 16.0, ProtoFx.intensity))), 1, SEG)

# ---- claim / release ------------------------------------------------------------

# Returns an index into _pool to write a ribbon into, or -1 if none available.
# Grows the active prefix while under the cap; otherwise steals the oldest
# non-pinned one-shot slot (STREAK_FOLLOW / aura orbits are protected).
func _claim() -> int:
	var cap := _active_cap()
	if _active_count < cap and _active_count < MAX_RIBBONS:
		var idx := _active_count
		_active_count += 1
		if OS.is_debug_build():
			assert(_active_count <= MAX_RIBBONS)
		_peak = maxi(_peak, _active_count)
		return idx
	var best := -1
	var best_frac := -1.0
	for i in _active_count:
		var rb: Ribbon = _pool[i]
		if rb.pinned:
			continue
		var frac := rb.age / maxf(rb.life, 0.001)
		if frac > best_frac:
			best_frac = frac
			best = i
	return best

func _release(i: int) -> void:
	var rb: Ribbon = _pool[i]
	rb.active = false
	rb.owner = null
	rb.pinned = false
	rb.id = -1
	var last := _active_count - 1
	if i != last:
		var tmp: Ribbon = _pool[i]
		_pool[i] = _pool[last]
		_pool[last] = tmp
	_active_count -= 1

func _init_common(rb: Ribbon, mode: int, center: Vector2, color: Color, width: float,
		life: float, owner: Node2D, pinned: bool) -> void:
	rb.active = true
	rb.mode = mode
	rb.age = 0.0
	rb.life = maxf(life, 0.02)
	rb.color = color
	rb.width = width
	rb.taper = 0.2
	rb.owner = owner
	rb.pinned = pinned
	rb.id = -1
	rb.center = center
	rb.head_idx = 0

func _prime_spine(rb: Ribbon, head: Vector2) -> void:
	for k in SEG + 1:
		rb.spine[k] = head

# ---- spawn entry points (called by the ProtoFx forwarders) ----------------------

func spawn_orbit(center: Vector2, cfg: Dictionary) -> void:
	var count := maxi(1, int(cfg.get("count", 6)))
	var r0 := float(cfg.get("radius", 24.0))
	var jitter := float(cfg.get("radius_jitter", 0.0))
	var turns := float(cfg.get("turns", 2.0))
	var life := float(cfg.get("life", 0.5))
	var width := float(cfg.get("width", 5.0))
	var color: Color = cfg.get("color", Color(0.7, 0.9, 1.0))
	var owner: Node2D = cfg.get("owner", null)
	var cw: bool = cfg.get("cw", false)
	var ang_vel := float(cfg.get("ang_vel", turns * TAU / maxf(life, 0.05)))
	if cw:
		ang_vel = -ang_vel
	for n in count:
		var idx := _claim()
		if idx < 0:
			return
		var rb: Ribbon = _pool[idx]
		var rad := r0 + (randf() * jitter if jitter > 0.0 else 0.0)
		var a0 := TAU * float(n) / float(count)
		_init_common(rb, Mode.ORBIT, center, color, width, life, owner, false)
		rb.r0 = rad
		rb.angle = a0
		rb.ang_vel = ang_vel
		_prime_spine(rb, center + Vector2.from_angle(a0) * rad)

func spawn_crescent(at: Vector2, dir: Vector2, cfg: Dictionary) -> void:
	var span := float(cfg.get("span", 2.1))
	var radius := float(cfg.get("radius", 22.0))
	var life := float(cfg.get("life", 0.22))
	var width := float(cfg.get("width", 6.0))
	var color: Color = cfg.get("color", Color(1, 1, 1))
	var idx := _claim()
	if idx < 0:
		return
	var rb: Ribbon = _pool[idx]
	var base_ang := dir.angle() - span * 0.5
	_init_common(rb, Mode.CRESCENT, at, color, width, life, cfg.get("owner", null), false)
	rb.r0 = radius
	rb.angle = base_ang
	rb.span = span
	_prime_spine(rb, at + Vector2.from_angle(base_ang) * radius)

func spawn_streak(from: Vector2, to: Vector2, cfg: Dictionary) -> void:
	var life := float(cfg.get("life", 0.25))
	var width := float(cfg.get("width", 6.0))
	var color: Color = cfg.get("color", Color(0.55, 0.9, 1.0))
	var idx := _claim()
	if idx < 0:
		return
	var rb: Ribbon = _pool[idx]
	_init_common(rb, Mode.STREAK, from, color, width, life, cfg.get("owner", null), false)
	rb.from = from
	rb.to = to
	_prime_spine(rb, from)

func spawn_radial(center: Vector2, cfg: Dictionary) -> void:
	var count := maxi(1, int(cfg.get("count", 12)))
	var radius := float(cfg.get("radius", 40.0))
	var life := float(cfg.get("life", 0.4))
	var width := float(cfg.get("width", 5.0))
	var color: Color = cfg.get("color", Color(0.7, 0.9, 1.0))
	for n in count:
		var idx := _claim()
		if idx < 0:
			return
		var rb: Ribbon = _pool[idx]
		var dir := Vector2.from_angle(TAU * float(n) / float(count))
		_init_common(rb, Mode.RADIAL, center, color, width, life, null, false)
		rb.dir = dir
		rb.r0 = radius
		_prime_spine(rb, center)

# STREAK_FOLLOW pinned trail. `cfg.life` is the orphan fallback so a bolt that frees
# without trail_detach still self-releases (no leak). Returns a stable id.
func attach(node: Node2D, cfg: Dictionary) -> int:
	if node == null:
		return -1
	var idx := _claim()
	if idx < 0:
		return -1
	var rb: Ribbon = _pool[idx]
	var life := float(cfg.get("life", 1.5))
	var width := float(cfg.get("width", 3.0))
	var color: Color = cfg.get("color", Color(0.8, 0.9, 1.0))
	_init_common(rb, Mode.STREAK_FOLLOW, node.global_position, color, width, life, node, true)
	rb.taper = float(cfg.get("taper", 0.2))
	rb.id = _next_id
	_next_id += 1
	_prime_spine(rb, node.global_position)
	return rb.id

# Pinned ORBIT ribbon that follows an owner — used by fx.aura. Returns a stable id.
func pin_orbit(owner: Node2D, cfg: Dictionary) -> int:
	if owner == null:
		return -1
	var idx := _claim()
	if idx < 0:
		return -1
	var rb: Ribbon = _pool[idx]
	var radius := float(cfg.get("radius", 26.0))
	var life := float(cfg.get("life", 2.0))
	var width := float(cfg.get("width", 4.0))
	var color: Color = cfg.get("color", Color(0.6, 1.0, 0.7))
	var turns := float(cfg.get("turns", 1.0))
	var phase := float(cfg.get("phase", 0.0))
	_init_common(rb, Mode.ORBIT, owner.global_position, color, width, life, owner, true)
	rb.r0 = radius
	rb.angle = phase
	rb.ang_vel = turns * TAU / maxf(life, 0.5)
	rb.id = _next_id
	_next_id += 1
	_prime_spine(rb, owner.global_position + Vector2.from_angle(phase) * radius)
	return rb.id

func detach(id: int) -> void:
	if id < 0:
		return
	for i in _active_count:
		if _pool[i].id == id:
			_release(i)
			return

# ---- per-frame -------------------------------------------------------------------

func _process(dt: float) -> void:
	var seg_used := _seg_used()
	var i := 0
	while i < _active_count:
		var rb: Ribbon = _pool[i]
		rb.age += dt
		# any owner-bound ribbon whose owner is gone releases (no stale follow / leak)
		if rb.owner != null and not is_instance_valid(rb.owner):
			_release(i)
			continue
		if rb.age >= rb.life:
			_release(i)
			continue
		var head := _head_pos(rb, dt)
		rb.head_idx = (rb.head_idx + 1) % (SEG + 1)
		rb.spine[rb.head_idx] = head
		var alpha := _fade(rb.age / rb.life)
		var base := i * SEG
		for j in SEG:
			var inst := base + j
			if j >= seg_used:
				_mm.set_instance_transform_2d(inst, _zero_xf)
				_mm.set_instance_color(inst, Color(0, 0, 0, 0))
				continue
			var ia := (rb.head_idx - j + (SEG + 1)) % (SEG + 1)
			var ib := (rb.head_idx - j - 1 + (SEG + 1)) % (SEG + 1)
			var p0: Vector2 = rb.spine[ia]
			var p1: Vector2 = rb.spine[ib]
			var mid := (p0 + p1) * 0.5
			var d := p0 - p1
			var seg_len := maxf(d.length(), 1.0)
			var ang := d.angle()
			var k := lerpf(1.0, rb.taper, float(j) / float(SEG))   # fat head, thin tail
			var xf := Transform2D()
			var xdir := Vector2.from_angle(ang)
			xf.x = xdir * seg_len
			xf.y = xdir.orthogonal() * (rb.width * k)
			xf.origin = mid
			_mm.set_instance_transform_2d(inst, xf)
			_mm.set_instance_color(inst, Color(rb.color.r, rb.color.g, rb.color.b, alpha * k))
		i += 1
	_mm.visible_instance_count = _active_count * SEG

func _head_pos(rb: Ribbon, dt: float) -> Vector2:
	var f := rb.age / rb.life
	match rb.mode:
		Mode.ORBIT:
			if rb.owner != null and is_instance_valid(rb.owner):
				rb.center = rb.owner.global_position
			rb.angle += rb.ang_vel * dt
			return rb.center + Vector2.from_angle(rb.angle) * rb.r0
		Mode.CRESCENT:
			return rb.center + Vector2.from_angle(rb.angle + rb.span * f) * rb.r0
		Mode.STREAK:
			return rb.from.lerp(rb.to, clampf(f, 0.0, 1.0))
		Mode.STREAK_FOLLOW:
			if rb.owner != null and is_instance_valid(rb.owner):
				return rb.owner.global_position
			return rb.spine[rb.head_idx]
		Mode.RADIAL:
			return rb.center + rb.dir * (rb.r0 * _ease_out(f))
	return rb.center

func _ease_out(x: float) -> float:
	var c := clampf(x, 0.0, 1.0)
	return 1.0 - (1.0 - c) * (1.0 - c)

# Fast fade-in over the first ~15% of life, gentle fade-out across the rest.
func _fade(f: float) -> float:
	if f < 0.15:
		return clampf(f / 0.15, 0.0, 1.0)
	return clampf(1.0 - (f - 0.15) / 0.85, 0.0, 1.0)

func _pool_debug() -> Dictionary:
	return {"size": MAX_RIBBONS, "peak_in_use": _peak}
