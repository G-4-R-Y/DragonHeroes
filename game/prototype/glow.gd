# PROTOTYPE HARNESS — additive glow sprite: the gl_compatibility stand-in for
# HDR bloom (canon §4 fidelity raise: "gl_compatibility fallback fakes glow with
# additive sprites"). One cached radial texture + a shared ADD-blend material;
# each instance is a single sprite with an optional cheap sine pulse. Under the
# Vulkan renderers the same emissive pixels ALSO feed the real WorldEnvironment
# glow (main.gd opt-in), so this layer stays correct in both paths.
class_name ProtoGlow
extends Sprite2D

static var _add_mat: CanvasItemMaterial = null

var pulse_speed := 3.0
var base_alpha := 0.5
var pulse_amp := 0.18
var base_scale := 1.0
var _t := 0.0

static func add_material() -> CanvasItemMaterial:
	if _add_mat == null:
		_add_mat = CanvasItemMaterial.new()
		_add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _add_mat

# Rim-glow outline material (shaders/rim_glow.gdshader): the Phantom-Tower elite
# silhouette. Cached PER COLOR — same-tier actors share one material, so a pack
# of Brutal elites costs one compile and zero per-spawn allocation.
const _RIM_SHADER := preload("res://prototype/shaders/rim_glow.gdshader")
static var _rim_cache := {}

static func rim_material(color: Color, strength := 1.15) -> ShaderMaterial:
	var key := color.to_html() + str(snappedf(strength, 0.05))
	if not _rim_cache.has(key):
		var m := ShaderMaterial.new()
		m.shader = _RIM_SHADER
		m.set_shader_parameter("rim_color", color)
		m.set_shader_parameter("rim_strength", strength)
		_rim_cache[key] = m
	return _rim_cache[key]

# radius_px = world-space glow radius. amp <= 0 disables the pulse (static glow).
static func make(color: Color, radius_px: float, alpha := 0.5, speed := 3.0,
		amp := 0.18) -> ProtoGlow:
	var g := ProtoGlow.new()
	g.texture = ProtoSprites.glow_tex()
	g.material = add_material()
	g.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	g.base_alpha = alpha
	g.pulse_speed = speed
	g.pulse_amp = amp
	g._t = randf() * TAU
	g.base_scale = radius_px * 2.0 / float(ProtoSprites.GLOW_TEX_SIZE)
	g.scale = Vector2.ONE * g.base_scale
	g.modulate = Color(color.r, color.g, color.b, alpha)
	g.z_index = 1
	return g

func _process(delta: float) -> void:
	if pulse_amp <= 0.0:
		set_process(false)
		return
	_t += delta * pulse_speed
	var k := 1.0 + sin(_t) * pulse_amp
	modulate.a = base_alpha * k
	scale = Vector2.ONE * (base_scale * (0.94 + 0.06 * k))
