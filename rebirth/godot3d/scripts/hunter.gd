# REBIRTH / Godot 3D — the hunter. Third-person locomotion, lock-on, dodge with
# i-frames + input buffering (the 2D game's own feel rules: 3 dodge charges,
# 0.15 s buffer — game/prototype/player.gd), a 3-hit melee combo and one skill.
# All hit tests are pure math (arc + reach against the dragon's hit capsule):
# no physics areas, so the same rules would port to dh-sim unchanged.
class_name RbHunter
extends Node3D

signal died

const HP_MAX := 100.0
const SPEED := 6.2
const TURN := 14.0                  # rad/s facing lerp
const DODGE_CHARGES_MAX := 3
const DODGE_RECHARGE := 1.8
const DODGE_DUR := 0.42
const DODGE_DIST := 6.0
const DODGE_IFRAMES := 0.28
const INPUT_BUFFER_S := 0.15
const COMBO_LINK_S := 0.45
const HITSTUN := 0.30
const SKILL_CD := 6.0
const COMBO := [
	{"startup": 0.12, "active": 0.10, "recover": 0.22, "dmg": 10.0, "reach": 2.6, "arc": 70.0},
	{"startup": 0.10, "active": 0.10, "recover": 0.22, "dmg": 10.0, "reach": 2.6, "arc": 70.0},
	{"startup": 0.16, "active": 0.12, "recover": 0.34, "dmg": 18.0, "reach": 2.9, "arc": 90.0},
]
const SKILL := {"startup": 0.18, "active": 0.16, "recover": 0.36, "dmg": 45.0, "reach": 3.4, "arc": 100.0, "lunge": 4.0}

var hp := HP_MAX
var state := "idle"     # idle | dodge | attack | skill | hitstun | dead
var t := 0.0
var combo_step := 0
var combo_link := 0.0
var combo_hits := 0
var dodge_charges := DODGE_CHARGES_MAX
var dodge_recharge := 0.0
var dodge_dir := Vector3.ZERO
var iframes := 0.0
var skill_cd := 0.0
var lock_target: Node3D = null
var knock := Vector3.ZERO
var valley: RbValley
var fx: RbFx
var dragon: Node3D
var stats := {"iframe_avoids": 0, "max_combo": 0, "hits": 0, "dmg_taken": 0.0, "dodges": 0, "distance": 0.0, "skills": 0}
var _buf := {"dodge": 0.0, "attack": 0.0, "skill": 0.0}
var _hit_done := false
var _spawn := Vector3.ZERO
var body: Node3D
var sword: Node3D
var lantern: OmniLight3D
var _flash := 0.0
var _mats: Array[StandardMaterial3D] = []

func setup(v: RbValley, f: RbFx, d: Node3D, spawn: Vector3) -> void:
	valley = v
	fx = f
	dragon = d
	_spawn = spawn
	_build_body()
	reset()

func reset() -> void:
	hp = HP_MAX
	state = "idle"
	t = 0.0
	combo_step = 0
	combo_link = 0.0
	combo_hits = 0
	dodge_charges = DODGE_CHARGES_MAX
	dodge_recharge = 0.0
	iframes = 0.0
	skill_cd = 0.0
	knock = Vector3.ZERO
	position = _spawn
	position.y = valley.height_at(position.x, position.z)
	rotation.y = atan2(-(dragon.position.x - position.x), -(dragon.position.z - position.z))
	visible = true

func forward() -> Vector3:
	return -global_transform.basis.z

func _build_body() -> void:
	body = RbGlb.load_scene("hunter")
	if body == null:
		body = Node3D.new()
		var leather := _mat(Color(0.16, 0.13, 0.12))
		var skin := _mat(Color(0.62, 0.48, 0.38))
		var steel := _mat(Color(0.75, 0.78, 0.85))
		steel.metallic = 0.9
		steel.roughness = 0.25
		var torso := MeshInstance3D.new()
		var cap := CapsuleMesh.new()
		cap.radius = 0.32
		cap.height = 1.25
		torso.mesh = cap
		torso.material_override = leather
		torso.position.y = 1.0
		body.add_child(torso)
		var head := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = 0.19
		sph.height = 0.38
		head.mesh = sph
		head.material_override = skin
		head.position.y = 1.78
		body.add_child(head)
		var hood := MeshInstance3D.new()
		var hs := SphereMesh.new()
		hs.radius = 0.23
		hs.height = 0.3
		hood.mesh = hs
		hood.material_override = leather
		hood.position.y = 1.86
		body.add_child(hood)
		sword = Node3D.new()
		sword.position = Vector3(0.42, 1.05, 0.0)
		body.add_child(sword)
		var blade := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.07, 1.15, 0.02)
		blade.mesh = bm
		blade.material_override = steel
		blade.position.y = 0.55
		sword.add_child(blade)
		var guard := MeshInstance3D.new()
		var gm := BoxMesh.new()
		gm.size = Vector3(0.28, 0.05, 0.06)
		guard.mesh = gm
		guard.material_override = steel
		sword.add_child(guard)
	add_child(body)
	lantern = OmniLight3D.new()
	lantern.light_color = Color(1.0, 0.72, 0.4)
	lantern.omni_range = 9.0
	lantern.light_energy = 1.6
	lantern.position = Vector3(-0.5, 1.3, 0.0)
	lantern.shadow_enabled = false
	add_child(lantern)
	var lamp := MeshInstance3D.new()
	var ls := SphereMesh.new()
	ls.radius = 0.09
	ls.height = 0.18
	lamp.mesh = ls
	var lm := _mat(Color(1.0, 0.8, 0.4))
	lm.emission_enabled = true
	lm.emission = Color(1.0, 0.7, 0.3)
	lm.emission_energy_multiplier = 3.0
	lamp.material_override = lm
	lamp.position = Vector3(-0.5, 1.3, 0.0)
	add_child(lamp)

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.8
	_mats.append(m)
	return m

# --- the tick -------------------------------------------------------------------

func tick(intent: RbInput.Intent, delta: float, cam_yaw: float) -> void:
	if state == "dead":
		return
	t += delta
	iframes = maxf(iframes - delta, 0.0)
	skill_cd = maxf(skill_cd - delta, 0.0)
	combo_link = maxf(combo_link - delta, 0.0)
	if combo_link == 0.0 and state != "attack":
		combo_step = 0
		combo_hits = 0
	if dodge_charges < DODGE_CHARGES_MAX:
		dodge_recharge += delta
		if dodge_recharge >= DODGE_RECHARGE:
			dodge_recharge = 0.0
			dodge_charges += 1
	for k: String in _buf.keys():
		_buf[k] = maxf(_buf[k] - delta, 0.0)
	if intent.dodge:
		_buf["dodge"] = INPUT_BUFFER_S
	if intent.attack:
		_buf["attack"] = INPUT_BUFFER_S
	if intent.skill:
		_buf["skill"] = INPUT_BUFFER_S
	# camera-relative move vector in world space
	var cf := Vector3(-sin(cam_yaw), 0.0, -cos(cam_yaw))
	var cr := Vector3(cos(cam_yaw), 0.0, -sin(cam_yaw))
	var move := (cr * intent.move.x + cf * intent.move.y)
	if move.length() > 1.0:
		move = move.normalized()
	var before := position
	match state:
		"idle":
			_tick_idle(move, delta)
		"dodge":
			_tick_dodge(delta)
		"attack":
			_tick_attack(delta)
		"skill":
			_tick_skill(delta)
		"hitstun":
			position += knock * delta
			knock = knock.lerp(Vector3.ZERO, 1.0 - exp(-delta * 8.0))
			if t >= HITSTUN:
				_enter("idle")
	# ground + arena bounds
	var flat := Vector2(position.x, position.z)
	if flat.length() > valley.BOWL_R + 8.0:
		flat = flat.normalized() * (valley.BOWL_R + 8.0)
		position.x = flat.x
		position.z = flat.y
	position.y = valley.height_at(position.x, position.z)
	stats["distance"] += Vector2(position.x - before.x, position.z - before.z).length()
	_animate(delta)

func _enter(s: String) -> void:
	state = s
	t = 0.0
	_hit_done = false

func _face(dir: Vector3, delta: float, rate: float = TURN) -> void:
	if dir.length_squared() < 0.0001:
		return
	var want := atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, want, 1.0 - exp(-delta * rate))

func _try_actions(move: Vector3) -> bool:
	if _buf["dodge"] > 0.0 and dodge_charges > 0:
		_buf["dodge"] = 0.0
		dodge_charges -= 1
		stats["dodges"] += 1
		if move.length_squared() > 0.01:
			dodge_dir = move.normalized()
		elif lock_target != null:
			dodge_dir = -(lock_target.position - position).normalized()
			dodge_dir.y = 0.0
		else:
			dodge_dir = forward()
		iframes = DODGE_IFRAMES
		_enter("dodge")
		return true
	if _buf["skill"] > 0.0 and skill_cd <= 0.0:
		_buf["skill"] = 0.0
		skill_cd = SKILL_CD
		stats["skills"] += 1
		if lock_target != null:
			var to := lock_target.position - position
			to.y = 0.0
			rotation.y = atan2(-to.x, -to.z)
		_enter("skill")
		return true
	if _buf["attack"] > 0.0:
		_buf["attack"] = 0.0
		if combo_link <= 0.0:
			combo_step = 0
			combo_hits = 0
		if lock_target != null:
			var to := lock_target.position - position
			to.y = 0.0
			rotation.y = atan2(-to.x, -to.z)
		_enter("attack")
		return true
	return false

func _tick_idle(move: Vector3, delta: float) -> void:
	if _try_actions(move):
		return
	if move.length_squared() > 0.0001:
		position += move * SPEED * delta
	if lock_target != null:
		var to := lock_target.position - position
		to.y = 0.0
		_face(to, delta, 10.0)
	else:
		_face(move, delta)

func _tick_dodge(delta: float) -> void:
	var k := t / DODGE_DUR
	var speed := (DODGE_DIST / DODGE_DUR) * (1.6 - 1.2 * k)   # ease-out
	position += dodge_dir * speed * delta
	if lock_target == null:
		_face(dodge_dir, delta)
	if t >= DODGE_DUR:
		_enter("idle")

func _tick_attack(delta: float) -> void:
	var step: Dictionary = COMBO[combo_step]
	var startup: float = step["startup"]
	var active: float = step["active"]
	var total: float = startup + active + step["recover"]
	if t >= startup and not _hit_done:
		_hit_done = true
		fx.slash(position, rotation.y, step["reach"], Color(0.9, 0.95, 1.0, 0.6))
		if _arc_hit(step["reach"], step["arc"], step["dmg"]):
			combo_hits += 1
			stats["max_combo"] = maxi(stats["max_combo"], combo_hits)
	# dodge-cancel out of recovery (responsiveness, the 2D feel bar)
	if t >= startup + active and _buf["dodge"] > 0.0 and dodge_charges > 0:
		combo_link = COMBO_LINK_S
		_try_actions(Vector3.ZERO)
		return
	if t >= total:
		combo_step = (combo_step + 1) % COMBO.size()
		combo_link = COMBO_LINK_S
		_enter("idle")
		# a buffered press chains immediately
		_try_actions(Vector3.ZERO)

func _tick_skill(delta: float) -> void:
	var startup: float = SKILL["startup"]
	var active: float = SKILL["active"]
	var total: float = startup + active + SKILL["recover"]
	if t < startup + 0.06:
		position += forward() * (SKILL["lunge"] / (startup + 0.06)) * delta
	if t >= startup and not _hit_done:
		_hit_done = true
		fx.slash(position, rotation.y, SKILL["reach"], Color(1.0, 0.55, 0.2, 0.9))
		fx.field(position + forward() * 1.8, 1.4, 2.5)
		_arc_hit(SKILL["reach"], SKILL["arc"], SKILL["dmg"])
	if t >= total:
		_enter("idle")

func _arc_hit(reach: float, arc_deg: float, dmg: float) -> bool:
	if dragon == null or not dragon.has_method("take_damage"):
		return false
	var to := dragon.position - position
	to.y = 0.0
	var hit_r: float = dragon.get("HIT_RADIUS")
	var dist := maxf(to.length() - hit_r, 0.0)
	if dist > reach:
		return false
	var ang := rad_to_deg(forward().angle_to(to.normalized()))
	if to.length() > hit_r and ang > arc_deg * 0.5:
		return false
	var point := position + forward() * minf(to.length() - hit_r * 0.5, reach) + Vector3(0, 1.4, 0)
	dragon.call("take_damage", dmg, position)
	fx.spark(point, Color(1.0, 0.85, 0.5))
	stats["hits"] += 1
	return true

## Damage from the dragon. Returns true if it landed (false = i-frames ate it).
func take_damage(amount: float, from: Vector3, knockback: float = 3.0) -> bool:
	if state == "dead":
		return false
	if iframes > 0.0:
		stats["iframe_avoids"] += 1
		fx.spark(position + Vector3(0, 1.2, 0), Color(0.6, 0.8, 1.0))
		return false
	hp = maxf(hp - amount, 0.0)
	stats["dmg_taken"] += amount
	_flash = 0.25
	var away := position - from
	away.y = 0.0
	knock = away.normalized() * knockback * 3.0
	fx.spark(position + Vector3(0, 1.2, 0), Color(1.0, 0.3, 0.2))
	if hp <= 0.0:
		state = "dead"
		died.emit()
		return true
	_enter("hitstun")
	return true

func heal(amount: float) -> void:
	if state != "dead":
		hp = minf(hp + amount, HP_MAX)

func _animate(delta: float) -> void:
	_flash = maxf(_flash - delta, 0.0)
	for m in _mats:
		m.emission_enabled = _flash > 0.0
		if _flash > 0.0:
			m.emission = Color(1.0, 0.2, 0.1)
			m.emission_energy_multiplier = 2.0
	if body == null:
		return
	match state:
		"dodge":
			body.rotation.x = -sin(t / DODGE_DUR * PI) * 0.9
			body.rotation.z = 0.0
		"attack":
			var step: Dictionary = COMBO[combo_step]
			var k: float = clampf(t / (step["startup"] + step["active"]), 0.0, 1.0)
			body.rotation.x = 0.0
			body.rotation.z = 0.0
			if sword != null:
				sword.rotation.z = lerpf(1.8, -1.4, k) * (1.0 if combo_step != 1 else -1.0)
				sword.rotation.x = -0.6 + 0.6 * k
		"skill":
			body.rotation.x = -0.3
			if sword != null:
				sword.rotation.z = lerpf(2.2, -2.0, clampf(t / 0.34, 0.0, 1.0))
				sword.rotation.x = -0.8
		_:
			body.rotation.x = lerpf(body.rotation.x, 0.0, 1.0 - exp(-delta * 12.0))
			body.rotation.z = 0.0
			if sword != null:
				sword.rotation.z = lerpf(sword.rotation.z, 0.35, 1.0 - exp(-delta * 10.0))
				sword.rotation.x = lerpf(sword.rotation.x, 0.0, 1.0 - exp(-delta * 10.0))
	lantern.light_energy = 1.6 + sin(Time.get_ticks_msec() * 0.011) * 0.15
