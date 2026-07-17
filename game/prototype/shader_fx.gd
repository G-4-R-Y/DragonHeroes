# PROTOTYPE HARNESS — pooled procedural-shader FX quads (the vfx_lab shaders,
# canon §12.23/§12.25). Each effect is PURE MATH in a canvas_item fragment shader
# (SDF + fBm + chromatic dispersion), authored in numpy previews (genforge/
# vfx_lab/) and ported 1:1. Because the project uses canvas_items stretch, these
# fragments evaluate at the WINDOW resolution — smooth hi-res effects composited
# over the chunky pixel world (the Children-of-Morta layering) with zero extra
# viewport machinery.
#
# Pooling contract (60 FPS hard rule): POOL quads + POOL ShaderMaterials are
# created ONCE in _ready; a spawn claims a slot round-robin (stealing the oldest
# when full), swaps the cached Shader, sets uniforms, and shows the sprite.
# progress is driven by one shared _process — no per-effect nodes, tweens, or
# allocation, ever. gl_compatibility-safe: no screen reads, no compute.
class_name ProtoShaderFx
extends Node2D

const POOL := 12
const TEX_SIZE := 2.0            # tiny white quad texture; scale = size / TEX_SIZE

# kind -> preloaded Shader (compiled once at load)
const SHADERS := {
	"slash": preload("res://prototype/shaders/slash.gdshader"),
	"nova": preload("res://prototype/shaders/nova.gdshader"),
	"vortex": preload("res://prototype/shaders/vortex.gdshader"),
	"firestorm": preload("res://prototype/shaders/firestorm.gdshader"),
	"impact": preload("res://prototype/shaders/impact.gdshader"),
	"umbra": preload("res://prototype/shaders/umbra.gdshader"),
}
# sensible default life (s) per kind — a blink, not a lingering cloud
const LIVES := {"slash": 0.28, "nova": 0.5, "vortex": 0.55,
		"firestorm": 0.6, "impact": 0.3, "umbra": 0.8}

var _sprites: Array[Sprite2D] = []
var _mats := {}                  # kind -> Array[ShaderMaterial] (one per slot):
								 # ALL materials built + shaders compiled at load —
								 # a spawn only re-points sprite.material, never
								 # swaps a shader mid-fight (frame-time spike)
var _cur: Array[ShaderMaterial] = []
var _age: Array[float] = []
var _life: Array[float] = []
var _persist: Array[bool] = []   # long-lived quads (field flames): stolen LAST
var _gen: Array[int] = []        # per-slot generation — burst() ids for kill()
var _idx := 0
var _peak := 0
var _active := 0

func _ready() -> void:
	z_as_relative = false
	z_index = 21                  # above ribbons (20), below bolt/ring accents
	var img := Image.create(int(TEX_SIZE), int(TEX_SIZE), false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var tex := ImageTexture.create_from_image(img)
	for kind in SHADERS:
		var arr: Array[ShaderMaterial] = []
		for i in POOL:
			var m := ShaderMaterial.new()
			m.shader = SHADERS[kind]
			arr.append(m)
		_mats[kind] = arr
	for i in POOL:
		var s := Sprite2D.new()
		s.texture = tex
		s.centered = true
		s.visible = false
		s.texture_filter = TEXTURE_FILTER_LINEAR   # global filter is NEAREST
		add_child(s)
		_sprites.append(s)
		_cur.append(null)
		_age.append(0.0)
		_life.append(1.0)
		_persist.append(false)
		_gen.append(0)

# One pooled shader effect. cfg (all optional): size (world px, quad side),
# color, dir (Vector2), life, seed, persist (steal-last, for field flames),
# plus raw uniform passthroughs under cfg.uniforms (e.g. {"intensity": 2.0}).
# Returns a stable id for kill() (-1 on unknown kind).
func burst(kind: String, at: Vector2, cfg: Dictionary = {}) -> int:
	if not SHADERS.has(kind):
		push_warning("shader_fx: unknown kind '%s'" % kind)
		return -1
	var i := _claim()
	var s := _sprites[i]
	var m: ShaderMaterial = _mats[kind][i]
	s.material = m
	_cur[i] = m
	s.global_position = at
	var size := float(cfg.get("size", 64.0))
	s.scale = Vector2.ONE * (size / TEX_SIZE)
	m.set_shader_parameter("progress", 0.0)
	m.set_shader_parameter("seed", float(cfg.get("seed", randf() * 97.0)))
	if cfg.has("color"):
		m.set_shader_parameter("color", cfg.get("color"))
	if cfg.has("dir"):
		var d: Vector2 = cfg.get("dir")
		m.set_shader_parameter("dir", d.normalized() if d.length() > 0.0 else Vector2.RIGHT)
	for u in (cfg.get("uniforms", {}) as Dictionary):
		m.set_shader_parameter(u, cfg.uniforms[u])
	_age[i] = 0.0
	_life[i] = maxf(float(cfg.get("life", LIVES.get(kind, 0.4))), 0.05)
	_persist[i] = bool(cfg.get("persist", false))
	_gen[i] += 1
	s.visible = true
	return _gen[i] * POOL + i

# Early fade-out for a long-lived burst (field consumed by a lava fusion).
# The slot fades over ~0.45 s: with a high `hold` the progress jump stays in
# the sustain plateau, so there is no visible pop — just the decay tail.
func kill(id: int) -> void:
	if id < 0:
		return
	var i := id % POOL
	if _gen[i] * POOL + i != id or not _sprites[i].visible:
		return   # slot was recycled since — nothing to kill
	_persist[i] = false
	if _life[i] - _age[i] > 0.45:
		_life[i] = _age[i] + 0.45

func _claim() -> int:
	# 1) any invisible slot (scan from _idx so rotation stays fair)
	for k in POOL:
		var i := (_idx + k) % POOL
		if not _sprites[i].visible:
			_idx = (i + 1) % POOL
			_active += 1
			_peak = maxi(_peak, mini(_active, POOL))
			return i
	# 2) all live: steal the quad closest to death — non-persist first, so a
	# 10 s field flame is never eaten by the 13th sub-second burst
	var best := -1
	var best_p := -1
	var rem_best := INF
	var rem_best_p := INF
	for i in POOL:
		var rem := _life[i] - _age[i]
		if _persist[i]:
			if rem < rem_best_p:
				rem_best_p = rem
				best_p = i
		elif rem < rem_best:
			rem_best = rem
			best = i
	var pick := best if best >= 0 else best_p
	_idx = (pick + 1) % POOL
	return pick

func _process(dt: float) -> void:
	var live := 0
	for i in POOL:
		if not _sprites[i].visible:
			continue
		_age[i] += dt
		if _age[i] >= _life[i]:
			_sprites[i].visible = false
			_persist[i] = false
			continue
		live += 1
		if _cur[i] != null:
			_cur[i].set_shader_parameter("progress", _age[i] / _life[i])
	_active = live

func _pool_debug() -> Dictionary:
	return {"size": POOL, "peak_in_use": _peak}
