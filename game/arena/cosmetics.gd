# ARENA — cosmetic VFX attachments (canon §12.27 media doctrine; Grand Chase
# auras + necklaces, modernized). THREE shader-driven cosmetics, all pure data
# per element: a persistent body-hugging aura medium (aura_body.gdshader),
# the 3-bead elemental necklace (necklace_bead.gdshader, orbit driven here),
# and a weapon enchant flare (weapon_aura.gdshader, pulse() on each attack).
#
# 60 FPS contract (ProtoFx pooling invariant): EVERYTHING is created once in
# attach(); _process only moves/toggles pre-created nodes and writes uniforms —
# zero per-frame allocation. ProtoFx.intensity gates USAGE (bead count, aura
# strength), never allocation.
#
# Z contract: the rig is a child of the wearer at z_index +1 (relative), so
# cosmetics live in the z ~1-2 band — above the body sprite (z 0), BELOW
# ProtoDarkness (z=10) so the darkness multiplicative layer still grades them
# (they read as in-world light, not UI). Beads flip z -2/+1 around the body at
# the orbit's back/front crossover; FX layers (18+) stay above everything.
#
# spec keys (any may be missing/""):
#   aura:     "fire"|"frost"|"storm"|"venom"|"umbral"|"blood"
#   necklace: same elements — 3 orbiting beads (Grand Chase style)
#   weapon:   same elements — flare shown by pulse()
class_name ProtoCosmetics
extends RefCounted

const AURA_SHADER := preload("res://prototype/shaders/aura_body.gdshader")
const BEAD_SHADER := preload("res://prototype/shaders/necklace_bead.gdshader")
const WEAPON_SHADER := preload("res://prototype/shaders/weapon_aura.gdshader")

const AURA_SIZE := Vector2(48.0, 76.0)   # ellipse band: rx 24 / ry 38 world px
const AURA_POS := Vector2(0.0, -10.0)    # hugging the body (sprite at y=-12)
const ORBIT_CENTER := Vector2(0.0, -10.0)
const ORBIT_RX := 14.0
const ORBIT_RY := 7.0
const ORBIT_PERIOD := 3.2                # seconds per turn
const BEAD_SIZE := 10.0                  # world px per bead sprite
const WEAPON_SIZE := Vector2(26.0, 40.0)
const WEAPON_POS := Vector2(10.0, -10.0) # mirrored with the wielder's facing
const PULSE_TIME := 0.25

# Element table: colors + shader params per canon damage type (Physical is
# elementless — no cosmetic). blend behavior is fixed blend_mix for the aura
# (see aura_body.gdshader header): occlude=1 elements (umbral/blood/venom)
# render as occluding smoke capped at `alpha`; occlude=0 elements
# (fire/frost/storm) render as translucent light with HDR cores.
const ELEMENTS := {
	"fire":   {"core": Color(1.00, 0.60, 0.16), "edge": Color(1.00, 0.86, 0.52),
		"smoke": Color(0.05, 0.02, 0.01), "rise": 1.5,  "erosion": 0.36,
		"arc": 0.0, "occlude": 0.0, "alpha": 0.55},
	"frost":  {"core": Color(0.50, 0.85, 1.00), "edge": Color(0.90, 0.98, 1.00),
		"smoke": Color(0.06, 0.10, 0.14), "rise": 0.9,  "erosion": 0.38,
		"arc": 0.0, "occlude": 0.0, "alpha": 0.55},
	"storm":  {"core": Color(0.62, 0.52, 1.00), "edge": Color(0.95, 0.92, 1.00),
		"smoke": Color(0.06, 0.05, 0.12), "rise": 1.2,  "erosion": 0.38,
		"arc": 1.0, "occlude": 0.0, "alpha": 0.55},
	"venom":  {"core": Color(0.55, 0.88, 0.24), "edge": Color(0.85, 1.00, 0.55),
		"smoke": Color(0.04, 0.09, 0.02), "rise": 0.8,  "erosion": 0.37,
		"arc": 0.0, "occlude": 1.0, "alpha": 0.55},
	"umbral": {"core": Color(0.42, 0.18, 0.85), "edge": Color(0.66, 0.32, 1.00),
		"smoke": Color(0.02, 0.01, 0.06), "rise": 0.5,  "erosion": 0.36,
		"arc": 0.0, "occlude": 1.0, "alpha": 0.85},
	"blood":  {"core": Color(0.78, 0.10, 0.14), "edge": Color(1.00, 0.42, 0.42),
		"smoke": Color(0.10, 0.01, 0.03), "rise": -0.35, "erosion": 0.38,
		"arc": 0.0, "occlude": 1.0, "alpha": 0.60},
}

static var _tex: ImageTexture = null     # one shared 4x4 white quad texture

static func _white_tex() -> ImageTexture:
	if _tex == null:
		var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_tex = ImageTexture.create_from_image(img)
	return _tex

static func _quad(size: Vector2, pos: Vector2, z: int) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = _white_tex()
	s.centered = true
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR  # global is NEAREST
	s.scale = size / 4.0
	s.position = pos
	s.z_index = z
	return s

static func attach(node: Node2D, spec: Dictionary) -> Node2D:
	if node == null:
		push_warning("cosmetics: attach() on null node")
		return null
	var old := node.get_node_or_null("Cosmetics")
	if old != null:
		old.queue_free()                   # re-attach replaces, never stacks
	var rig := _Rig.new()
	rig.name = "Cosmetics"
	rig.z_index = 1                      # ~z 1-2 band: above body, below darkness
	node.add_child(rig)
	rig.host = node

	var aura_el: Dictionary = ELEMENTS.get(str(spec.get("aura", "")), {})
	if not aura_el.is_empty():
		var m := ShaderMaterial.new()
		m.shader = AURA_SHADER
		m.set_shader_parameter("color_core", aura_el.core)
		m.set_shader_parameter("color_edge", aura_el.edge)
		m.set_shader_parameter("smoke_color", aura_el.smoke)
		m.set_shader_parameter("rise_speed", aura_el.rise)
		m.set_shader_parameter("erosion", aura_el.erosion)
		m.set_shader_parameter("arc_amount", aura_el.arc)
		m.set_shader_parameter("occlude", aura_el.occlude)
		m.set_shader_parameter("max_alpha", aura_el.alpha)
		m.set_shader_parameter("seed", randf() * 97.0)
		var q := _quad(AURA_SIZE, AURA_POS, 1)
		q.material = m
		rig.add_child(q)
		rig.aura_mat = m

	var neck_el: Dictionary = ELEMENTS.get(str(spec.get("necklace", "")), {})
	if not neck_el.is_empty():
		for i in 3:                        # all 3 pre-created; intensity only HIDES
			var m := ShaderMaterial.new()
			m.shader = BEAD_SHADER
			m.set_shader_parameter("color", neck_el.core)
			m.set_shader_parameter("seed", float(i) * 13.7)
			var b := _quad(Vector2.ONE * BEAD_SIZE, ORBIT_CENTER, 1)
			b.material = m
			rig.add_child(b)
			rig.beads.append(b)
		# faint full orbit ring (Grand Chase orbit trail), pre-built once
		var ring := Line2D.new()
		var pts := PackedVector2Array()
		for k in 25:
			var a := TAU * float(k) / 24.0
			pts.append(ORBIT_CENTER + Vector2(cos(a) * ORBIT_RX, sin(a) * ORBIT_RY))
		ring.points = pts
		ring.width = 1.0
		ring.default_color = Color(neck_el.core, 0.10)
		ring.z_index = 0
		rig.add_child(ring)
		rig.ring = ring

	var weap_el: Dictionary = ELEMENTS.get(str(spec.get("weapon", "")), {})
	if not weap_el.is_empty():
		var m := ShaderMaterial.new()
		m.shader = WEAPON_SHADER
		m.set_shader_parameter("color_core", weap_el.core)
		m.set_shader_parameter("color_edge", weap_el.edge)
		m.set_shader_parameter("seed", randf() * 97.0)
		var q := _quad(WEAPON_SIZE, WEAPON_POS, 1)
		q.material = m
		q.visible = false                  # shown by pulse() only
		rig.add_child(q)
		rig.weapon = q
		rig.weapon_mat = m
	return rig

# Weapon flare — call on each attack. Safe on any handle (no-op without weapon).
static func pulse(handle: Node2D) -> void:
	if handle != null and is_instance_valid(handle) and handle.has_method(&"pulse_weapon"):
		handle.call(&"pulse_weapon")

static func detach(handle: Node2D) -> void:
	if handle != null and is_instance_valid(handle):
		handle.queue_free()

# ---------------------------------------------------------------- runtime rig
class _Rig:
	extends Node2D
	var host: Node2D
	var aura_mat: ShaderMaterial
	var beads: Array[Sprite2D] = []
	var ring: Line2D
	var weapon: Sprite2D
	var weapon_mat: ShaderMaterial
	var _t := 0.0
	var _tween: Tween                   # one reused pulse tween (kill+restart)

	func _process(dt: float) -> void:
		_t += dt
		var inten: float = ProtoFx.intensity
		# aura: usage gate = alpha only (the medium thins, never vanishes)
		if aura_mat != null:
			aura_mat.set_shader_parameter("strength", lerpf(0.45, 1.0, inten))
		# necklace: elliptical orbit, z-flip at the back/front crossover
		var want := 3
		if inten < 0.3:
			want = 1
		elif inten < 0.8:
			want = 2
		for i in beads.size():
			var b := beads[i]
			if i >= want:
				b.visible = false
				continue
			b.visible = true
			var a := TAU * (_t / ProtoCosmetics.ORBIT_PERIOD + float(i) / 3.0)
			var sn := sin(a)
			b.position = ProtoCosmetics.ORBIT_CENTER + Vector2(cos(a) * ProtoCosmetics.ORBIT_RX, sn * ProtoCosmetics.ORBIT_RY)
			b.z_index = 1 if sn >= 0.0 else -2   # front above body, back below
			var depth := (sn + 1.0) * 0.5
			var s := (0.80 + 0.35 * depth) * (1.0 + 0.10 * sin(_t * 4.0 + i * 2.1))
			b.scale = Vector2.ONE * (ProtoCosmetics.BEAD_SIZE / 4.0) * s
		if ring != null:
			ring.visible = want > 1        # no ring for a lone bead
		# weapon: mirror with the wielder's facing (read per-frame; the host
		# may or may not have a `sprite` AnimatedSprite2D child)
		if weapon != null and host != null:
			var spr := host.get_node_or_null("sprite")
			if spr is AnimatedSprite2D:
				var f: bool = spr.flip_h
				weapon.position.x = -ProtoCosmetics.WEAPON_POS.x if f else ProtoCosmetics.WEAPON_POS.x
				weapon_mat.set_shader_parameter("flip", 1.0 if f else 0.0)

	func pulse_weapon() -> void:
		if weapon == null:
			return
		weapon.visible = true
		weapon_mat.set_shader_parameter("pulse", 1.0)
		if _tween != null and _tween.is_valid():
			_tween.kill()
		_tween = create_tween()
		_tween.tween_method(_set_pulse, 1.0, 0.0, ProtoCosmetics.PULSE_TIME)
		_tween.tween_callback(_hide_weapon)

	func _set_pulse(v: float) -> void:
		if weapon_mat != null:
			weapon_mat.set_shader_parameter("pulse", v)

	func _hide_weapon() -> void:
		if weapon != null:
			weapon.visible = false
