# PROTOTYPE HARNESS — screen post-process host (spec §2.3). A dedicated CanvasLayer
# (layer 5) sitting above world+fx+ribbons+telegraphs (canvas 0) and below the HUD
# (>=10). Two children in order: a BackBufferCopy in COPY_MODE_VIEWPORT (NEVER Rect
# mode — bug #111096 fails to update hint_screen_texture) and a full-rect ColorRect
# carrying the post shader. A SEPARATE additive flash ColorRect lives on its own
# top layer (>15) so the finisher white-out is NOT itself graded.
#
# Renderer split (spec §1): the full look ships on gl_compatibility via the shader's
# over-bright term (fake bloom). set_hdr_mode(true) — called ONLY inside main.gd's
# existing renderer branch — dials that term toward 0 so real Vulkan HDR glow and
# faked bloom never stack into a blown frame.
class_name ProtoPost
extends CanvasLayer

const SHADER_PATH := "res://prototype/post.gdshader"

const BASE_ABERRATION := 1.0     # texels (spec: base <= 1.5)
const BASE_BRIGHT := 0.28
const PULSE_DECAY := 0.25         # seconds
const FLASH_DUR := 0.35

var _bbc: BackBufferCopy
var _rect: ColorRect
var _mat: ShaderMaterial
var _static_vig: TextureRect      # intensity<0.15 fallback (spec §2.7)
var _flash_layer: CanvasLayer
var _flash_rect: ColorRect

var _intensity := 0.5
var _pulse := 0.0                 # transient aberration+bright kick, decays in _process
var _flash_t := 0.0
var _flash_strength := 0.0
var _hdr := false

func _ready() -> void:
	layer = 5
	_bbc = BackBufferCopy.new()
	_bbc.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(_bbc)

	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = load(SHADER_PATH)
	_rect.material = _mat
	add_child(_rect)

	# Static vignette fallback (re-enabled below the fake-bloom floor). Uses the same
	# ProtoSprites.vignette_tex() ambient.gd used to own; hidden while the shader runs.
	_static_vig = TextureRect.new()
	_static_vig.texture = ProtoSprites.vignette_tex()
	_static_vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	_static_vig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_static_vig.stretch_mode = TextureRect.STRETCH_SCALE
	_static_vig.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_static_vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_static_vig.visible = false
	add_child(_static_vig)

	# Finisher white-out: additive, on its OWN layer above everything (>15) so it is
	# not re-graded by this pass and reads as a true screen flash.
	_flash_layer = CanvasLayer.new()
	_flash_layer.layer = 16
	add_child(_flash_layer)
	_flash_rect = ColorRect.new()
	_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_rect.color = Color(1, 1, 1, 0)
	_flash_rect.material = ProtoGlow.add_material()
	_flash_layer.add_child(_flash_rect)

	_apply_uniforms()
	set_process(true)

# ---- API (spec §2.3) ------------------------------------------------------------

# i<0.15 -> hide the graded rect, skip the copy+pass (0 cost), re-enable the static
# vignette fallback. Otherwise aberration/bright_boost scale with i.
func set_intensity(i: float) -> void:
	_intensity = clampf(i, 0.0, 1.0)
	var on := _intensity >= 0.15
	_rect.visible = on
	_bbc.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT if on else BackBufferCopy.COPY_MODE_DISABLED
	_static_vig.visible = not on
	_apply_uniforms()

# Transient aberration+bright kick for signature hits; decays ~0.25s in _process.
# Uses raw delta so it freezes correctly during hitstop (Engine.time_scale scales it).
func pulse(strength: float) -> void:
	_pulse = maxf(_pulse, clampf(strength, 0.0, 1.5))
	_apply_uniforms()

# Finisher white-out via the SEPARATE top-layer additive rect (NOT the graded rect).
func flash(color: Color, strength := 1.0) -> void:
	_flash_strength = clampf(strength, 0.0, 1.0)
	_flash_t = FLASH_DUR
	_flash_rect.color = Color(color.r, color.g, color.b, _flash_strength)

# Vulkan seam (spec §1): on true, dial the faked over-bright term toward 0 so the
# real HDR WorldEnvironment glow (main.gd branch) takes over without stacking.
func set_hdr_mode(on: bool) -> void:
	_hdr = on
	_apply_uniforms()

# ---- internals ------------------------------------------------------------------

func _process(dt: float) -> void:
	if _pulse > 0.0:
		_pulse = maxf(0.0, _pulse - dt / PULSE_DECAY)
		_apply_uniforms()
	if _flash_t > 0.0:
		_flash_t = maxf(0.0, _flash_t - dt)
		_flash_rect.color.a = (_flash_t / FLASH_DUR) * _flash_strength

func _apply_uniforms() -> void:
	var iscale := lerpf(0.4, 1.0, _intensity)
	var ab := BASE_ABERRATION * iscale + _pulse * 2.5
	var br := BASE_BRIGHT * lerpf(0.3, 1.0, _intensity) + _pulse * 0.4
	if _hdr:
		br = _pulse * 0.4          # Vulkan: kill the faked over-bright, keep the kick
	_mat.set_shader_parameter("aberration", ab)
	_mat.set_shader_parameter("bright_boost", br)
	_mat.set_shader_parameter("vig_inner", 0.5)
	_mat.set_shader_parameter("vig_outer", 1.25)
	_mat.set_shader_parameter("kick_center", Vector2(0.5, 0.5))
	_mat.set_shader_parameter("intensity", _intensity)

# Post owns no claim pool; reported for harness symmetry with the pooled systems.
func _pool_debug() -> Dictionary:
	return {"size": 0, "peak_in_use": 0}
