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
}
# sensible default life (s) per kind — a blink, not a lingering cloud
const LIVES := {"slash": 0.28, "nova": 0.5, "vortex": 0.55,
		"firestorm": 0.6, "impact": 0.3}

var _sprites: Array[Sprite2D] = []
var _mats := {}                  # kind -> Array[ShaderMaterial] (one per slot):
								 # ALL materials built + shaders compiled at load —
								 # a spawn only re-points sprite.material, never
								 # swaps a shader mid-fight (frame-time spike)
var _cur: Array[ShaderMaterial] = []
var _age: Array[float] = []
var _life: Array[float] = []
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

# One pooled shader effect. cfg (all optional): size (world px, quad side),
# color, dir (Vector2), life, seed, plus raw uniform passthroughs under
# cfg.uniforms (e.g. {"intensity": 2.0, "core_color": Color(...)}).
func burst(kind: String, at: Vector2, cfg: Dictionary = {}) -> void:
	if not SHADERS.has(kind):
		push_warning("shader_fx: unknown kind '%s'" % kind)
		return
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
	s.visible = true

func _claim() -> int:
	# round-robin; the oldest slot is simply recycled (effects are sub-second)
	var i := _idx
	_idx = (_idx + 1) % POOL
	if not _sprites[i].visible:
		_active += 1
		_peak = maxi(_peak, mini(_active, POOL))
	return i

func _process(dt: float) -> void:
	var live := 0
	for i in POOL:
		if not _sprites[i].visible:
			continue
		_age[i] += dt
		if _age[i] >= _life[i]:
			_sprites[i].visible = false
			continue
		live += 1
		if _cur[i] != null:
			_cur[i].set_shader_parameter("progress", _age[i] / _life[i])
	_active = live

func _pool_debug() -> Dictionary:
	return {"size": POOL, "peak_in_use": _peak}
