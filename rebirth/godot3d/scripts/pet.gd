# REBIRTH / Godot 3D — the companion beast (the pet canon in miniature):
# follows the hunter, nips the dragon when close (cooldown), and one skill on
# the hunter's E — HOWL: staggers the dragon (punish window) and heals 10.
class_name RbPet
extends Node3D

const SPEED := 8.0
const NIP_CD := 4.0
const NIP_DMG := 6.0
const NIP_RANGE := 4.5
const HOWL_CD := 12.0
const HOWL_RANGE := 14.0
const HOWL_HEAL := 10.0

var hunter: RbHunter
var dragon: Node3D
var valley: RbValley
var fx: RbFx
var nip_cd := 0.0
var howl_cd := 0.0
var stats := {"nips": 0, "howls": 0}
var _mats: Array[StandardMaterial3D] = []
var body: Node3D

func setup(h: RbHunter, d: Node3D, v: RbValley, f: RbFx) -> void:
	hunter = h
	dragon = d
	valley = v
	fx = f
	_build_body()
	reset()

func reset() -> void:
	nip_cd = 1.0
	howl_cd = 2.0
	position = hunter.position + Vector3(-1.6, 0.0, 1.4)
	position.y = valley.height_at(position.x, position.z)

func _build_body() -> void:
	body = RbGlb.load_scene("pet")
	if body == null:
		body = Node3D.new()
		var fur := StandardMaterial3D.new()
		fur.albedo_color = Color(0.32, 0.30, 0.36)
		fur.roughness = 0.9
		_mats.append(fur)
		var torso := MeshInstance3D.new()
		var cap := CapsuleMesh.new()
		cap.radius = 0.28
		cap.height = 1.1
		torso.mesh = cap
		torso.material_override = fur
		torso.rotation.x = PI / 2.0
		torso.position.y = 0.5
		body.add_child(torso)
		var head := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = 0.22
		sph.height = 0.44
		head.mesh = sph
		head.material_override = fur
		head.position = Vector3(0.0, 0.72, -0.62)
		body.add_child(head)
		for side in [-1.0, 1.0]:
			var ear := MeshInstance3D.new()
			var em := BoxMesh.new()
			em.size = Vector3(0.08, 0.22, 0.06)
			ear.mesh = em
			ear.material_override = fur
			ear.position = Vector3(side * 0.13, 0.98, -0.62)
			body.add_child(ear)
			var eye := MeshInstance3D.new()
			var es := SphereMesh.new()
			es.radius = 0.035
			es.height = 0.07
			eye.mesh = es
			var glow := StandardMaterial3D.new()
			glow.emission_enabled = true
			glow.emission = Color(0.4, 1.0, 0.9)
			glow.emission_energy_multiplier = 3.0
			glow.albedo_color = Color(0.4, 1.0, 0.9)
			eye.material_override = glow
			eye.position = Vector3(side * 0.09, 0.76, -0.82)
			body.add_child(eye)
	add_child(body)

func tick(intent: RbInput.Intent, delta: float) -> void:
	nip_cd = maxf(nip_cd - delta, 0.0)
	howl_cd = maxf(howl_cd - delta, 0.0)
	if hunter.state == "dead":
		return
	# follow: heel position behind-left of the hunter
	var heel := hunter.position - hunter.forward() * 1.6 + hunter.global_transform.basis.x * -1.4
	var to_dragon := dragon.position - position
	to_dragon.y = 0.0
	var hit_r: float = dragon.get("HIT_RADIUS")
	var want := heel
	if nip_cd <= 0.0 and to_dragon.length() - hit_r < NIP_RANGE + 3.0 and dragon.get("state") != "dead":
		want = dragon.position - to_dragon.normalized() * (hit_r + 1.2)
	var d := want - position
	d.y = 0.0
	if d.length() > 0.3:
		position += d.normalized() * minf(SPEED * delta, d.length())
		rotation.y = lerp_angle(rotation.y, atan2(-d.x, -d.z), 1.0 - exp(-delta * 10.0))
	position.y = valley.height_at(position.x, position.z)
	if nip_cd <= 0.0 and to_dragon.length() - hit_r <= NIP_RANGE and dragon.get("state") != "dead":
		nip_cd = NIP_CD
		stats["nips"] += 1
		dragon.call("take_damage", NIP_DMG, position)
		fx.spark(position + to_dragon.normalized() * 1.2 + Vector3(0, 1.0, 0), Color(0.5, 1.0, 0.9))
	if intent.pet and howl_cd <= 0.0:
		howl_cd = HOWL_CD
		stats["howls"] += 1
		fx.ring(position, 3.0, Color(0.3, 1.0, 0.9, 0.7), 0.6)
		hunter.heal(HOWL_HEAL)
		if to_dragon.length() <= HOWL_RANGE and dragon.has_method("stagger"):
			dragon.call("stagger", 1.1)
	if body != null:
		body.position.y = absf(sin(Time.get_ticks_msec() * 0.012)) * 0.05
