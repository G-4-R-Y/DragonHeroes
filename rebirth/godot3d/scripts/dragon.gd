# REBIRTH / Godot 3D — the legendary dragon. FIVE signature skills composing one
# learnable strategy (canon §4): BREATH cone (front, mid range, leaves a burning
# field), METEOR volley (far — rings mark the landings), TAIL sweep (punishes
# standing behind), WING GUST (punishes hugging the front — long recovery = the
# punish window), POUNCE (closes distance; the enraged opener). ENRAGE at 40%:
# faster, shorter telegraphs, meteors 3→5, red aura light, and the RETREAT LEAP
# (wing-beat back 14 m → meteors → pounce back in: the enraged pattern; repeats
# every ~18 s of melee). Telegraph → commit
# (aim locks 0.35 s before the strike: THE dodge window) → act → recover
# (punishable). A state machine, not a stat wall.
class_name RbDragon
extends Node3D

signal slain
signal skill_used(id: String)
signal enraged_now

const HP_MAX := 600.0
const HIT_RADIUS := 2.4
const SPEED := 4.2
const TURN := 2.0                 # rad/s while approaching
const TELE_TURN := 1.2            # rad/s while telegraphing (slow = readable)
const ENRAGE_AT := 0.40
const COMMIT_S := 0.35            # aim lock before the strike
const SKILLS := {
	"breath":  {"tele": 1.10, "act": 1.20, "recover": 1.60, "min": 3.0, "max": 15.0, "dmg": 30.0, "cd": 5.0},
	"meteors": {"tele": 1.40, "act": 0.50, "recover": 1.00, "min": 9.0, "max": 60.0, "dmg": 24.0, "cd": 9.0},
	"tail":    {"tele": 0.80, "act": 0.30, "recover": 1.20, "min": 0.0, "max": 7.0,  "dmg": 22.0, "cd": 4.0},
	"gust":    {"tele": 0.90, "act": 0.30, "recover": 1.90, "min": 0.0, "max": 7.5,  "dmg": 12.0, "cd": 6.0},
	"pounce":  {"tele": 1.00, "act": 0.55, "recover": 1.30, "min": 3.0, "max": 30.0, "dmg": 34.0, "cd": 8.0},
}
const BREATH_RANGE := 14.0
const BREATH_HALF_DEG := 35.0
const METEOR_R := 3.2
const TAIL_REACH := 7.0
const GUST_R := 7.5
const POUNCE_R := 3.6

var hp := HP_MAX
var state := "idle"      # idle | approach | tele | act | recover | stagger | dead
var skill := ""
var t := 0.0
var enraged := false
var punishable := false
var telegraph_left := 0.0
var cds := {}
var used := {}
var stats := {"skills": 0, "hits_landed": 0, "dmg_dealt": 0.0}
var hunter: RbHunter
var valley: RbValley
var fx: RbFx
var _think := 0.0
var _act_done := false
var _aim_locked := false
var _tele_handles: Array[int] = []
var _meteors: Array[Dictionary] = []   # {handle, pos, applied}
var _pounce_from := Vector3.ZERO
var _pounce_to := Vector3.ZERO
var _field_tick := 0.0
var _spawn := Vector3.ZERO
var _flash := 0.0
var body: Node3D
var wings: Array[Node3D] = []
var aura: OmniLight3D
var _mats: Array[StandardMaterial3D] = []
var force_next := ""      # test hook: next decision uses this skill if legal-ish
var _retreat_pending := false
var _retreat_timer := 0.0
var rng := RandomNumberGenerator.new()
const RETREAT_S := 0.6
const RETREAT_M := 14.0
const RETREAT_EVERY := 18.0

func setup(h: RbHunter, v: RbValley, f: RbFx, spawn: Vector3) -> void:
	hunter = h
	valley = v
	fx = f
	_spawn = spawn
	_build_body()
	reset()

func reset() -> void:
	hp = HP_MAX
	state = "idle"
	skill = ""
	t = 0.0
	enraged = false
	punishable = false
	telegraph_left = 0.0
	cds = {}
	for id: String in SKILLS.keys():
		cds[id] = 0.0
	cds["meteors"] = 4.0
	cds["pounce"] = 3.0
	_think = 0.6
	_retreat_pending = false
	_retreat_timer = 0.0
	rng.seed = 11
	_meteors.clear()
	_tele_handles.clear()
	position = _spawn
	position.y = valley.height_at(position.x, position.z)
	if hunter != null:
		rotation.y = atan2(-(hunter.position.x - position.x), -(hunter.position.z - position.z))
	if aura != null:
		aura.visible = false
	visible = true
	scale = Vector3.ONE

func forward() -> Vector3:
	return -global_transform.basis.z

func _build_body() -> void:
	body = RbGlb.load_scene("dragon")
	if body == null:
		body = Node3D.new()
		var hide := _mat(Color(0.20, 0.09, 0.08))
		var belly := _mat(Color(0.42, 0.24, 0.12))
		var horn := _mat(Color(0.12, 0.10, 0.10))
		var torso := MeshInstance3D.new()
		var cap := CapsuleMesh.new()
		cap.radius = 1.3
		cap.height = 6.0
		torso.mesh = cap
		torso.material_override = hide
		torso.rotation.x = PI / 2.0
		torso.position.y = 1.8
		body.add_child(torso)
		var chest := MeshInstance3D.new()
		var cs := SphereMesh.new()
		cs.radius = 1.05
		cs.height = 2.1
		chest.mesh = cs
		chest.material_override = belly
		chest.position = Vector3(0.0, 1.2, -1.0)
		chest.scale = Vector3(1.0, 0.8, 1.6)
		body.add_child(chest)
		var neck := MeshInstance3D.new()
		var nc := CapsuleMesh.new()
		nc.radius = 0.55
		nc.height = 3.4
		neck.mesh = nc
		neck.material_override = hide
		neck.position = Vector3(0.0, 3.2, -3.4)
		neck.rotation.x = 0.9
		body.add_child(neck)
		var head := MeshInstance3D.new()
		var hb := BoxMesh.new()
		hb.size = Vector3(1.1, 0.9, 2.2)
		head.mesh = hb
		head.material_override = hide
		head.position = Vector3(0.0, 4.3, -5.0)
		body.add_child(head)
		for side in [-1.0, 1.0]:
			var eye := MeshInstance3D.new()
			var es := SphereMesh.new()
			es.radius = 0.12
			es.height = 0.24
			eye.mesh = es
			var glow := StandardMaterial3D.new()
			glow.emission_enabled = true
			glow.emission = Color(1.0, 0.55, 0.1)
			glow.emission_energy_multiplier = 4.0
			glow.albedo_color = Color(1.0, 0.6, 0.2)
			eye.material_override = glow
			eye.position = Vector3(side * 0.45, 4.5, -5.7)
			body.add_child(eye)
			var h := MeshInstance3D.new()
			var hm := CylinderMesh.new()
			hm.top_radius = 0.02
			hm.bottom_radius = 0.16
			hm.height = 1.1
			h.mesh = hm
			h.material_override = horn
			h.position = Vector3(side * 0.45, 5.1, -4.6)
			h.rotation = Vector3(-0.8, 0.0, side * 0.3)
			body.add_child(h)
			var wing := Node3D.new()
			wing.position = Vector3(side * 1.1, 2.6, -0.4)
			body.add_child(wing)
			wings.append(wing)
			var membrane := MeshInstance3D.new()
			var wm := BoxMesh.new()
			wm.size = Vector3(6.5, 0.08, 3.6)
			membrane.mesh = wm
			var wmat := _mat(Color(0.30, 0.10, 0.10))
			wmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			wmat.albedo_color.a = 0.88
			wmat.cull_mode = BaseMaterial3D.CULL_DISABLED
			membrane.material_override = wmat
			membrane.position = Vector3(side * 3.25, 0.0, 0.0)
			wing.add_child(membrane)
		var prev := Vector3(0.0, 1.6, 3.2)
		for i in 5:
			var seg := MeshInstance3D.new()
			var sm := CapsuleMesh.new()
			sm.radius = 0.55 - i * 0.09
			sm.height = 1.9
			seg.mesh = sm
			seg.material_override = hide
			seg.position = prev + Vector3(0.0, -0.05, 0.9)
			seg.rotation.x = PI / 2.0
			body.add_child(seg)
			prev = seg.position
	add_child(body)
	# the wyrm's own ember light: the fire-breather reads in the dark (canon §12.27)
	var maw := OmniLight3D.new()
	maw.light_color = Color(1.0, 0.5, 0.15)
	maw.omni_range = 7.0
	maw.light_energy = 1.4
	maw.position = Vector3(0.0, 4.2, -5.6)
	maw.shadow_enabled = false
	add_child(maw)
	aura = OmniLight3D.new()
	aura.light_color = Color(1.0, 0.15, 0.05)
	aura.omni_range = 11.0
	aura.light_energy = 2.4
	aura.position.y = 2.5
	aura.visible = false
	aura.shadow_enabled = false
	add_child(aura)

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.75
	_mats.append(m)
	return m

# --- helpers --------------------------------------------------------------------

func _to_hunter() -> Vector3:
	var to := hunter.position - position
	to.y = 0.0
	return to

func _surface_dist() -> float:
	return maxf(_to_hunter().length() - HIT_RADIUS, 0.0)

## Signed angle (deg) between our forward and the hunter direction; |a| > 100 = behind.
func _rel_angle_deg() -> float:
	var to := _to_hunter().normalized()
	return rad_to_deg(forward().signed_angle_to(to, Vector3.UP))

func _tele_time(id: String) -> float:
	var base: float = SKILLS[id]["tele"]
	return base * (0.8 if enraged else 1.0)

func _speed() -> float:
	return SPEED * (1.3 if enraged else 1.0)

# --- the tick -------------------------------------------------------------------

func tick(delta: float) -> void:
	if state == "dead":
		return
	t += delta
	_flash = maxf(_flash - delta, 0.0)
	for id: String in cds.keys():
		cds[id] = maxf(cds[id] - delta, 0.0)
	_tick_meteors()
	_tick_fields(delta)
	if not enraged and hp <= HP_MAX * ENRAGE_AT:
		_enrage()
	if enraged and state in ["idle", "approach", "recover"] and _surface_dist() < 6.0:
		_retreat_timer += delta
		if _retreat_timer >= RETREAT_EVERY:
			_retreat_timer = 0.0
			_retreat_pending = true
	var hunter_alive := hunter.state != "dead"
	match state:
		"idle":
			punishable = false
			if hunter_alive:
				_think -= delta
				if _think <= 0.0:
					_think = 0.35
					if _retreat_pending:
						_retreat_pending = false
						_retreat_timer = 0.0
						_enter("retreat")
					else:
						_decide()
		"retreat":
			var k: float = clampf(t / RETREAT_S, 0.0, 1.0)
			var back := -forward()
			position += back * (RETREAT_M / RETREAT_S) * delta
			var flat := Vector2(position.x, position.z)
			if flat.length() > valley.BOWL_R - 2.0:
				flat = flat.normalized() * (valley.BOWL_R - 2.0)
				position.x = flat.x
				position.z = flat.y
			body.position.y = sin(k * PI) * 3.0
			if t >= RETREAT_S:
				body.position.y = 0.0
				cds["meteors"] = 0.0
				cds["pounce"] = minf(cds["pounce"], 2.5)
				_think = 0.05
				_enter("idle")
		"approach":
			_face_hunter(delta, TURN * (1.3 if enraged else 1.0))
			if _surface_dist() > 3.6:
				position += forward() * _speed() * delta
			_think -= delta
			if _think <= 0.0:
				_think = 0.35
				_decide()
		"tele":
			telegraph_left = maxf(_tele_time(skill) - t, 0.0)
			if telegraph_left > COMMIT_S and skill in ["breath", "gust", "pounce"]:
				_face_hunter(delta, TELE_TURN)
				_update_telegraph()
			elif not _aim_locked:
				_aim_locked = true
				_update_telegraph()
			if telegraph_left <= 0.0:
				_begin_act()
		"act":
			_tick_act(delta)
		"recover":
			punishable = true
			if t >= SKILLS[skill]["recover"]:
				punishable = false
				_enter("idle")
		"stagger":
			punishable = true
			if t >= 1.1:
				punishable = false
				_enter("idle")
	position.y = valley.height_at(position.x, position.z)
	_animate(delta)

func _enter(s: String) -> void:
	state = s
	t = 0.0
	_act_done = false
	_aim_locked = false

func _face_hunter(delta: float, rate: float) -> void:
	var to := _to_hunter()
	if to.length_squared() < 0.001:
		return
	var want := atan2(-to.x, -to.z)
	var diff := angle_difference(rotation.y, want)
	rotation.y += clampf(diff, -rate * delta, rate * delta)

func _legal(id: String) -> bool:
	if cds[id] > 0.0:
		return false
	var d := _surface_dist()
	var s: Dictionary = SKILLS[id]
	if d < s["min"] or d > s["max"]:
		return false
	var rel := absf(_rel_angle_deg())
	match id:
		"breath", "gust":
			return rel < 70.0
		"tail":
			return rel > 95.0 or (enraged and d < 3.0)
		"pounce":
			return enraged or d > 14.0
	return true

func _decide() -> void:
	var d := _surface_dist()
	var rel := absf(_rel_angle_deg())
	var pick := ""
	if force_next != "" and _legal(force_next):
		pick = force_next
		force_next = ""
	elif _legal("tail"):
		pick = "tail"
	elif d > 9.0 and _legal("meteors"):
		pick = "meteors"
	elif d > 3.0 and _legal("pounce"):
		pick = "pounce"
	elif _legal("gust") and d < 4.0 and (enraged or rng.randf() < 0.35):
		pick = "gust"
	elif _legal("breath") and d >= 3.0:
		pick = "breath"
	elif _legal("gust"):
		pick = "gust"
	if pick == "":
		# no legal skill: turn to face / close distance (the exploitable part)
		if rel > 70.0 or d > 3.6:
			_enter("approach")
		else:
			_enter("idle")
		return
	_start_skill(pick)

func _start_skill(id: String) -> void:
	skill = id
	cds[id] = SKILLS[id]["cd"]
	used[id] = int(used.get(id, 0)) + 1
	stats["skills"] += 1
	_enter("tele")
	telegraph_left = _tele_time(id)
	_show_telegraph()
	skill_used.emit(id)

func _show_telegraph() -> void:
	_tele_handles.clear()
	var dur: float = _tele_time(skill) + SKILLS[skill]["act"]
	match skill:
		"breath":
			_tele_handles.append(fx.cone(position, rotation.y, BREATH_RANGE, Color(1.0, 0.35, 0.1, 0.35), dur))
		"meteors":
			var n := 5 if enraged else 3
			_meteors.clear()
			for i in n:
				var off := Vector3.ZERO
				if i > 0:
					var a := (i / float(n)) * TAU
					off = Vector3(cos(a), 0.0, sin(a)) * (3.2 + i * 0.6)
				var p := hunter.position + off
				p.y = valley.height_at(p.x, p.z)
				_meteors.append({"handle": -1, "pos": p, "applied": false, "ring": fx.ring(p, METEOR_R, Color(1.0, 0.4, 0.1, 0.8), dur + 1.0)})
		"tail":
			_tele_handles.append(fx.cone(position, rotation.y + PI, TAIL_REACH + HIT_RADIUS, Color(1.0, 0.5, 0.15, 0.35), dur))
			var h2 := fx.cone(position, rotation.y + PI + deg_to_rad(60.0), TAIL_REACH + HIT_RADIUS, Color(1.0, 0.5, 0.15, 0.35), dur)
			var h3 := fx.cone(position, rotation.y + PI - deg_to_rad(60.0), TAIL_REACH + HIT_RADIUS, Color(1.0, 0.5, 0.15, 0.35), dur)
			_tele_handles.append(h2)
			_tele_handles.append(h3)
		"gust":
			_tele_handles.append(fx.ring(position, GUST_R + HIT_RADIUS, Color(0.6, 0.75, 1.0, 0.45), dur))
		"pounce":
			_pounce_to = hunter.position
			_tele_handles.append(fx.ring(_pounce_to, POUNCE_R, Color(1.0, 0.25, 0.1, 0.9), dur))

func _update_telegraph() -> void:
	match skill:
		"breath":
			for h in _tele_handles:
				fx.cone_end(h)
			_tele_handles.clear()
			_tele_handles.append(fx.cone(position, rotation.y, BREATH_RANGE, Color(1.0, 0.35, 0.1, 0.35), telegraph_left + SKILLS[skill]["act"]))
		"pounce":
			if not _aim_locked:
				_pounce_to = hunter.position
				for h in _tele_handles:
					fx.ring_update(h, _pounce_to, POUNCE_R)

func _begin_act() -> void:
	_enter("act")
	match skill:
		"meteors":
			for m in _meteors:
				m["handle"] = fx.meteor(m["pos"], 0.9)
		"pounce":
			_pounce_from = position
			var to := _pounce_to - position
			to.y = 0.0
			if to.length() > 0.01:
				rotation.y = atan2(-to.x, -to.z)

func _tick_act(delta: float) -> void:
	var s: Dictionary = SKILLS[skill]
	match skill:
		"breath":
			# continuous cone; damage once per hunter (first contact), field at the end
			if not _act_done and _in_cone(hunter.position, BREATH_RANGE, BREATH_HALF_DEG):
				_act_done = true
				_deal(s["dmg"], 4.0)
			if t >= s["act"] - 0.02 and not _tele_handles.is_empty():
				for h in _tele_handles:
					fx.cone_end(h)
				_tele_handles.clear()
				var center := position + forward() * (HIT_RADIUS + 4.5)
				center.y = valley.height_at(center.x, center.z)
				fx.field(center, 3.2 if enraged else 2.6, 7.0)
		"tail":
			if not _act_done and t >= 0.05:
				_act_done = true
				var rel := absf(_rel_angle_deg())
				if rel > 80.0 and _surface_dist() <= TAIL_REACH:
					_deal(s["dmg"], 6.0)
				_end_telegraphs()
		"gust":
			if not _act_done and t >= 0.05:
				_act_done = true
				var rel := absf(_rel_angle_deg())
				if rel < 100.0 and _surface_dist() <= GUST_R:
					_deal(s["dmg"], 9.0)
				fx.ring(position, GUST_R + HIT_RADIUS, Color(0.7, 0.85, 1.0, 0.9), 0.35)
				_end_telegraphs()
		"pounce":
			var k: float = clampf(t / s["act"], 0.0, 1.0)
			var p := _pounce_from.lerp(_pounce_to, k)
			position.x = p.x
			position.z = p.z
			body.position.y = sin(k * PI) * 5.0
			if k >= 1.0 and not _act_done:
				_act_done = true
				body.position.y = 0.0
				if _surface_dist() <= POUNCE_R + 0.5 or Vector2(hunter.position.x - _pounce_to.x, hunter.position.z - _pounce_to.z).length() <= POUNCE_R:
					_deal(s["dmg"], 7.0)
				fx.ring(position, POUNCE_R + HIT_RADIUS, Color(1.0, 0.4, 0.1, 0.9), 0.3)
				fx.spark(position + Vector3(0, 0.5, 0), Color(0.8, 0.6, 0.4))
				_end_telegraphs()
		"meteors":
			pass
	if t >= s["act"]:
		_enter("recover")
		punishable = true

func _end_telegraphs() -> void:
	for h in _tele_handles:
		fx.ring_end(h)
		fx.cone_end(h)
	_tele_handles.clear()

func _in_cone(p: Vector3, range_m: float, half_deg: float) -> bool:
	var to := p - position
	to.y = 0.0
	if to.length() > range_m + HIT_RADIUS:
		return false
	if to.length() <= HIT_RADIUS:
		return true
	return rad_to_deg(forward().angle_to(to.normalized())) <= half_deg

func _deal(dmg: float, knockback: float) -> void:
	if hunter.take_damage(dmg, position, knockback):
		stats["hits_landed"] += 1
		stats["dmg_dealt"] += dmg

func _tick_meteors() -> void:
	for m in _meteors:
		if m["handle"] >= 0 and not m["applied"] and fx.meteor_landed(m["handle"]):
			m["applied"] = true
			fx.ring_end(m["ring"])
			var p: Vector3 = m["pos"]
			if Vector2(hunter.position.x - p.x, hunter.position.z - p.z).length() <= METEOR_R:
				_deal(SKILLS["meteors"]["dmg"], 5.0)

func _tick_fields(delta: float) -> void:
	_field_tick -= delta
	if _field_tick <= 0.0:
		_field_tick = 0.5
		if hunter.state != "dead" and fx.fields_hit(hunter.position):
			if hunter.take_damage(4.0, hunter.position + hunter.forward(), 0.5):
				stats["dmg_dealt"] += 4.0

func _enrage() -> void:
	enraged = true
	aura.visible = true
	for m in _mats:
		m.emission_enabled = true
		m.emission = Color(0.6, 0.05, 0.02)
		m.emission_energy_multiplier = 0.9
	fx.ring(position, HIT_RADIUS + 6.0, Color(1.0, 0.1, 0.05, 1.0), 0.8)
	fx.spark(position + Vector3(0, 3.0, 0), Color(1.0, 0.2, 0.1))
	cds["pounce"] = 0.0
	_retreat_pending = true
	enraged_now.emit()

func stagger(dur: float) -> void:
	if state == "dead":
		return
	_end_telegraphs()
	for m in _meteors:
		if m["handle"] < 0:
			fx.ring_end(m["ring"])
	var keep: Array[Dictionary] = []
	for m in _meteors:
		if m["handle"] >= 0:
			keep.append(m)
	_meteors = keep
	_enter("stagger")
	t = 1.1 - dur
	punishable = true
	fx.spark(position + Vector3(0, 4.0, 0), Color(0.5, 1.0, 0.9))

func take_damage(dmg: float, _from: Vector3) -> void:
	if state == "dead":
		return
	hp = maxf(hp - dmg, 0.0)
	_flash = 0.12
	if hp <= 0.0:
		state = "dead"
		punishable = false
		_end_telegraphs()
		for m in _meteors:
			fx.ring_end(m["ring"])
		_meteors.clear()
		aura.visible = false
		slain.emit()

func _animate(delta: float) -> void:
	var now := Time.get_ticks_msec() * 0.001
	var flap := 0.55 if (skill == "pounce" and state == "act") else 0.25
	for i in wings.size():
		var side := -1.0 if i == 0 else 1.0
		wings[i].rotation.z = side * (sin(now * (3.0 if enraged else 2.0)) * flap + 0.15)
	if body != null and skill != "pounce":
		body.position.y = lerpf(body.position.y, 0.0, 1.0 - exp(-delta * 8.0))
	var flash_on := _flash > 0.0
	for m in _mats:
		if enraged:
			m.emission_energy_multiplier = 1.8 if flash_on else 0.9
		else:
			m.emission_enabled = flash_on
			if flash_on:
				m.emission = Color(1.0, 0.9, 0.8)
				m.emission_energy_multiplier = 1.2
	if aura.visible:
		aura.light_energy = 2.4 + sin(now * 11.0) * 0.5
	if state == "dead":
		scale = scale.lerp(Vector3(1.0, 0.25, 1.0), 1.0 - exp(-delta * 3.0))
