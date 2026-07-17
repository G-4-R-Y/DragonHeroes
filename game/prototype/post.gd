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
# Default biome grade — a 3D-LUT strip baked by genforge/pipeline/lut_gen.py that
# reproduces the shader's analytic split-tone exactly. Post OWNS grading: biome
# code never touches uniforms, it just hands set_lut() a texture.
const DEFAULT_LUT := "res://prototype/art/luts/veilands_default.png"

const BASE_ABERRATION := 1.0     # texels (spec: base <= 1.5)
const BASE_BRIGHT := 0.28
const PULSE_DECAY := 0.25         # seconds
const FLASH_DUR := 0.35
const HAZE_MAX := 6               # shader uniform array size (post.gdshader)

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
var _haze: Array = []             # heat-haze sources, WORLD coords (converted to
                                  # screen uv per frame so camera pans track)
var _has_lut := false             # a grade LUT is bound (lut_amount 1 in-shader)
var _lut_next: Texture2D = null   # incoming grade during a set_lut crossfade
var _lut_fade := 0.0              # seconds left in the crossfade (0 = idle)
var _lut_fade_dur := 1.0

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

	# Biome color grade: the baked LUT strip replaces the shader's analytic
	# split-tone when present. Missing file -> lut_amount stays 0 and the
	# analytic fallback keeps the exact old look (nothing regresses).
	if ResourceLoader.exists(DEFAULT_LUT, "Texture2D"):
		_set_lut_now(load(DEFAULT_LUT))

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

# Crossfade the color grade to a new baked LUT strip (per-biome grades are pure
# data: callers hand over a texture, post owns every grading detail). A fade
# already in flight is committed first so blends never stack; crossfade_s <= 0
# (or no LUT on screen yet) snaps instantly. Costs two float uniforms per frame
# while fading — zero allocation.
func set_lut(tex: Texture2D, crossfade_s := 1.0) -> void:
	if tex == null:
		return
	if _lut_fade > 0.0:
		_commit_lut()
	if not _has_lut or crossfade_s <= 0.0:
		_set_lut_now(tex)
		return
	_lut_next = tex
	_lut_fade_dur = crossfade_s
	_lut_fade = crossfade_s
	_mat.set_shader_parameter("lut_tex2", tex)
	_mat.set_shader_parameter("lut_blend", 0.0)

# Heat-haze shimmer around a WORLD position (fire fields, cinder bursts, lava).
# Rides the existing post pass — zero extra backbuffer copies. Sources ease
# in/out and self-expire; at HAZE_MAX the one closest to expiry is evicted.
func haze(world_pos: Vector2, radius_px := 46.0, strength := 2.2, life := 0.6) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if _haze.size() >= HAZE_MAX:
		var bi := 0
		var brem := INF
		for k in _haze.size():
			var rem: float = _haze[k].until - now
			if rem < brem:
				brem = rem
				bi = k
		_haze.remove_at(bi)
	_haze.append({"pos": world_pos, "radius_px": radius_px, "strength": strength,
			"t0": now, "until": now + maxf(life, 0.1)})

# ---- internals ------------------------------------------------------------------

func _process(dt: float) -> void:
	if _pulse > 0.0:
		_pulse = maxf(0.0, _pulse - dt / PULSE_DECAY)
		_apply_uniforms()
	if _flash_t > 0.0:
		_flash_t = maxf(0.0, _flash_t - dt)
		_flash_rect.color.a = (_flash_t / FLASH_DUR) * _flash_strength
	if _lut_fade > 0.0:
		_lut_fade = maxf(0.0, _lut_fade - dt)
		if _lut_fade == 0.0:
			_commit_lut()
		else:
			_mat.set_shader_parameter("lut_blend", 1.0 - _lut_fade / _lut_fade_dur)
	_update_haze()

# World -> screen-uv conversion every frame (sources track camera pans); the
# uniform array is tiny, so re-uploading it per frame is noise.
func _update_haze() -> void:
	if _haze.is_empty() and _mat.get_shader_parameter("haze_count") == 0:
		return
	var now := Time.get_ticks_msec() / 1000.0
	var vp := get_viewport()
	if vp == null:
		return
	var ct := vp.get_canvas_transform()
	var vps := vp.get_visible_rect().size
	var packed := PackedColorArray()
	var k := 0
	while k < _haze.size():
		var h: Dictionary = _haze[k]
		if now >= float(h.until):
			_haze.remove_at(k)
			continue
		var ease_in: float = clampf((now - float(h.t0)) / 0.25, 0.0, 1.0)
		var ease_out: float = clampf((float(h.until) - now) / 0.3, 0.0, 1.0)
		var s: float = float(h.strength) * ease_in * ease_out * lerpf(0.4, 1.0, _intensity)
		var sp: Vector2 = ct * (h.pos as Vector2)
		var uv := sp / vps
		# radius in HEIGHT units (shader normalizes x by aspect)
		packed.append(Color(uv.x, uv.y, float(h.radius_px) / vps.y, s))
		k += 1
	_mat.set_shader_parameter("haze_count", packed.size())
	if packed.size() > 0:
		while packed.size() < HAZE_MAX:   # fixed-size upload for the array uniform
			packed.append(Color(0, 0, 0, 0))
		_mat.set_shader_parameter("haze_src", packed)

# Snap the primary grade sampler (no crossfade) and enable the LUT path. The
# shader's lut_amount flips 0 -> 1 exactly once, here.
func _set_lut_now(tex: Texture2D) -> void:
	_has_lut = true
	_lut_next = null
	_lut_fade = 0.0
	_mat.set_shader_parameter("lut_tex", tex)
	_mat.set_shader_parameter("lut_blend", 0.0)
	_mat.set_shader_parameter("lut_amount", 1.0)

# Crossfade done (or pre-empted by a new set_lut): promote the incoming LUT to
# the primary sampler and zero the blend — visually a no-op at blend = 1.
func _commit_lut() -> void:
	if _lut_next != null:
		_mat.set_shader_parameter("lut_tex", _lut_next)
		_lut_next = null
	_lut_fade = 0.0
	_mat.set_shader_parameter("lut_blend", 0.0)

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
