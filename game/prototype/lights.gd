# PROTOTYPE HARNESS — pooled ground light pools ("effects light the world",
# canon §12.27). ONE MultiMesh of soft radial-gradient ellipses, ADD-blend,
# drawn UNDER entities: z=-3 sits above the field decals (-5) and below the
# telegraph rings (-2) so danger UI is never buried. Fire fields, projectiles,
# the hero and hunt legendaries stop floating "on top of" the scene the moment
# the ground under them glows — this is the single cheapest "sits IN the world"
# read we have. gl_compatibility stand-in for real 2D lights (shipping path:
# RenderingServer-driven, never node-per-entity).
#
# Pooling contract: POOL fixed slots allocated once in _ready; place()/attach()
# claim invisible-first, then steal the one-shot light closest to death
# (indefinite/attached lights are stolen last). ProtoFx.intensity gates the
# per-frame USAGE cap only — never allocation.
class_name ProtoLights
extends MultiMeshInstance2D

const POOL := 32
const SQUASH := 0.45              # ellipse y/x — pseudo floor projection
const FADE_IN := 0.12
const FADE_OUT := 0.35

class Rec:
	var active := false
	var id := -1
	var target: Node2D = null     # follow while valid (projectiles, hero)
	var offset := Vector2.ZERO
	var pos := Vector2.ZERO
	var radius := 40.0            # world px (ellipse x half-extent)
	var color := Color(1.0, 0.78, 0.45)
	var alpha := 0.5              # peak center alpha (pre-flicker)
	var flicker := 0.0            # 0..1 amplitude (torch/fire wobble)
	var rate := 11.0              # flicker rate (rad/s-ish)
	var phase := 0.0
	var life := -1.0              # <0 = until detach / target freed
	var age := 0.0

static var _tex_cache: ImageTexture = null

var _mm: MultiMesh
var _recs: Array = []
var _next_id := 1
var _peak := 0
var _zero := Transform2D(Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)

func _ready() -> void:
	z_as_relative = false
	z_index = -3
	texture_filter = TEXTURE_FILTER_LINEAR   # global filter is NEAREST
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_2D
	_mm.use_colors = true
	var q := QuadMesh.new()
	q.size = Vector2.ONE              # unit quad; per-instance scale = diameter
	_mm.mesh = q
	_mm.instance_count = POOL
	_mm.visible_instance_count = POOL # visibility via zero-basis transforms
	multimesh = _mm
	material = ProtoGlow.add_material()
	texture = _pool_tex()
	for i in POOL:
		_recs.append(Rec.new())
		_mm.set_instance_transform_2d(i, _zero)
		_mm.set_instance_color(i, Color(0, 0, 0, 0))
	set_process(true)

# Soft radial falloff — (1-r)^2.4 keeps the pool edge invisible (no disc rim).
static func _pool_tex() -> ImageTexture:
	if _tex_cache != null:
		return _tex_cache
	var n := 96
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := (n - 1) * 0.5
	for y in n:
		for x in n:
			var r := Vector2(float(x) - c, float(y) - c).length() / c
			var a := pow(clampf(1.0 - r, 0.0, 1.0), 2.4)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	_tex_cache = ImageTexture.create_from_image(img)
	return _tex_cache

# ---- claim / API -----------------------------------------------------------------

# One-shot / timed pool at a world position. cfg: radius, color, alpha, life
# (<0 = until light_detach), flicker, rate. Returns an id for detach.
func place(at: Vector2, cfg: Dictionary = {}) -> int:
	return _spawn(null, at, cfg)

# Follows a node until it frees (orphans self-fade) or detach. cfg adds: offset.
func attach(node: Node2D, cfg: Dictionary = {}) -> int:
	if node == null or not is_instance_valid(node):
		return -1
	return _spawn(node, node.global_position, cfg)

# Begin the fade-out for a placed/attached light (idempotent; unknown id = no-op).
func detach(id: int) -> void:
	for i in POOL:
		var rec: Rec = _recs[i]
		if rec.active and rec.id == id:
			rec.target = null
			if rec.life < 0.0 or rec.life - rec.age > FADE_OUT:
				rec.life = rec.age + FADE_OUT
			return

func _spawn(target: Node2D, at: Vector2, cfg: Dictionary) -> int:
	var i := _claim()
	var rec: Rec = _recs[i]
	rec.active = true
	rec.id = _next_id
	_next_id += 1
	rec.target = target
	rec.offset = cfg.get("offset", Vector2.ZERO)
	rec.pos = at + rec.offset
	rec.radius = float(cfg.get("radius", 40.0))
	rec.color = cfg.get("color", Color(1.0, 0.78, 0.45))
	rec.alpha = float(cfg.get("alpha", 0.5))
	rec.flicker = float(cfg.get("flicker", 0.0))
	rec.rate = float(cfg.get("rate", 11.0))
	rec.phase = randf() * TAU
	rec.life = float(cfg.get("life", -1.0))
	rec.age = 0.0
	return rec.id

func _claim() -> int:
	for i in POOL:
		if not _recs[i].active:
			return i
	# all live: steal the ONE-SHOT light closest to death; indefinite/attached
	# lights (life<0: field glows mid-burn, hero/projectile follows) go last
	var best := -1
	var best_p := -1
	var rem_best := INF
	var age_best_p := -1.0
	for i in POOL:
		var rec: Rec = _recs[i]
		if rec.life >= 0.0:
			var rem: float = rec.life - rec.age
			if rem < rem_best:
				rem_best = rem
				best = i
		elif rec.age > age_best_p:
			age_best_p = rec.age
			best_p = i
	var pick := best if best >= 0 else best_p
	_off(pick)
	return pick

func _off(i: int) -> void:
	var rec: Rec = _recs[i]
	rec.active = false
	rec.target = null
	_mm.set_instance_transform_2d(i, _zero)
	_mm.set_instance_color(i, Color(0, 0, 0, 0))

# ---- per-frame drive --------------------------------------------------------------

func _cap() -> int:
	return maxi(8, int(round(lerpf(8.0, float(POOL), ProtoFx.intensity))))

func _process(dt: float) -> void:
	var used := 0
	var cap := _cap()
	for i in POOL:
		var rec: Rec = _recs[i]
		if not rec.active:
			continue
		rec.age += dt
		if rec.target != null:
			if not is_instance_valid(rec.target):
				rec.target = null            # orphaned: begin self-fade
				if rec.life < 0.0:
					rec.life = rec.age + FADE_OUT
			else:
				rec.pos = rec.target.global_position + rec.offset
		if rec.life >= 0.0 and rec.age >= rec.life:
			_off(i)
			continue
		used += 1
		if used > cap:                        # intensity gate: usage, not allocation
			_mm.set_instance_transform_2d(i, _zero)
			continue
		var a := rec.alpha * clampf(rec.age / FADE_IN, 0.0, 1.0)
		if rec.life >= 0.0:
			a *= clampf((rec.life - rec.age) / FADE_OUT, 0.0, 1.0)
		if rec.flicker > 0.0:
			var f := sin(rec.age * rec.rate + rec.phase) * 0.6 \
					+ sin(rec.age * rec.rate * 2.7 + rec.phase * 1.7) * 0.4
			a *= 1.0 + rec.flicker * 0.35 * f
		var s := rec.radius * 2.0
		_mm.set_instance_transform_2d(i,
				Transform2D(Vector2(s, 0), Vector2(0, s * SQUASH), rec.pos))
		var col := rec.color
		col.a = clampf(a, 0.0, 1.0)
		_mm.set_instance_color(i, col)
	_peak = maxi(_peak, used)

func _pool_debug() -> Dictionary:
	return {"size": POOL, "peak_in_use": _peak}
