# PROTOTYPE HARNESS — fireflies / drifting ember motes (canon §12.29). ONE
# MultiMesh of tiny additive glints wandering around the camera at z=13 (above
# fog, below fx): the "the dark is alive" layer that Hades-likes scatter over
# every dark scene. Pure transform math per frame, zero allocation; the pool
# respawns motes that drift off-view at a fresh edge point. ProtoFx.intensity
# gates the VISIBLE count only.
class_name ProtoMotes
extends MultiMeshInstance2D

const POOL := 40
const TEX := 16

class Rec:
	var base := Vector2.ZERO
	var phase := 0.0
	var speed := 1.0
	var size := 2.0
	var col := Color(1.0, 0.8, 0.45)
	var drift := Vector2.ZERO

var _mm: MultiMesh
var _recs: Array = []
var _t := 0.0
var _zero := Transform2D(Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)

func _ready() -> void:
	z_as_relative = false
	z_index = 13
	texture_filter = TEXTURE_FILTER_LINEAR
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_2D
	_mm.use_colors = true
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	_mm.mesh = q
	_mm.instance_count = POOL
	multimesh = _mm
	material = ProtoGlow.add_material()
	texture = _dot_tex()
	for i in POOL:
		var r := Rec.new()
		_seed_rec(r)
		# 70% warm ember, 30% cold spirit — the Veilands' two lights
		r.col = Color(1.0, 0.78, 0.42) if randf() < 0.7 else Color(0.5, 0.9, 1.0)
		_recs.append(r)
	set_process(true)

static var _tex_cache: ImageTexture = null
static func _dot_tex() -> ImageTexture:
	if _tex_cache != null:
		return _tex_cache
	var img := Image.create(TEX, TEX, false, Image.FORMAT_RGBA8)
	var c := (TEX - 1) * 0.5
	for y in TEX:
		for x in TEX:
			var r := Vector2(float(x) - c, float(y) - c).length() / c
			var a := pow(clampf(1.0 - r, 0.0, 1.0), 1.8)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	_tex_cache = ImageTexture.create_from_image(img)
	return _tex_cache

func _seed_rec(r: Rec) -> void:
	r.phase = randf() * TAU
	r.speed = 0.5 + randf() * 1.1
	r.size = 1.4 + randf() * 2.2
	r.drift = Vector2(randf_range(-4.0, 4.0), randf_range(-3.0, 1.0))

func _process(dt: float) -> void:
	_t += dt
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		visible = false
		return
	visible = true
	var center := cam.get_screen_center_position()
	var vs := get_viewport_rect().size / cam.zoom
	var half := vs * 0.55
	var shown := clampi(int(round(lerpf(12.0, float(POOL), ProtoFx.intensity))), 0, POOL)
	for i in POOL:
		var r: Rec = _recs[i]
		if i >= shown:
			_mm.set_instance_transform_2d(i, _zero)
			continue
		if r.base == Vector2.ZERO or absf(r.base.x - center.x) > half.x \
				or absf(r.base.y - center.y) > half.y:
			r.base = center + Vector2(randf_range(-half.x, half.x),
					randf_range(-half.y, half.y))
			_seed_rec(r)
		r.base += r.drift * dt
		var pos := r.base + Vector2(sin(_t * r.speed + r.phase) * 9.0,
				cos(_t * r.speed * 0.7 + r.phase * 1.7) * 6.0)
		var a := 0.25 + 0.55 * (0.5 + 0.5 * sin(_t * (r.speed * 2.1) + r.phase * 3.0))
		_mm.set_instance_transform_2d(i,
				Transform2D(Vector2(r.size, 0), Vector2(0, r.size), pos))
		var col := r.col
		col.a = a
		_mm.set_instance_color(i, col)

func _pool_debug() -> Dictionary:
	return {"size": POOL, "peak_in_use": POOL}
