# REBIRTH / Godot 3D — scripted hunter for the headless selftest and captures.
# Plays the fight the way the design says it should be played: keep mid range,
# dodge on the commit window, punish recoveries with the full combo, spend the
# skill on punish, howl when ready. Produces the same Intent a player would.
class_name RbAutopilot
extends RefCounted

var slice: Node
var hunter: RbHunter
var dragon: RbDragon
var pet: RbPet
var cam: RbCameraRig
var ticks := 0
var _side := 1.0
var _wait := 0.0
const DODGE_AT := 0.22   # s before the strike (i-frames last 0.28)

func _init(s: Node) -> void:
	slice = s
	hunter = s.get("hunter")
	dragon = s.get("dragon")
	pet = s.get("pet")
	cam = s.get("cam")

func _local(dir: Vector3) -> Vector2:
	if dir.length_squared() < 0.0001:
		return Vector2.ZERO
	var d := dir.normalized()
	return Vector2(d.dot(cam.right_flat()), d.dot(cam.forward_flat()))

func tick(delta: float) -> RbInput.Intent:
	ticks += 1
	var i := RbInput.Intent.new()
	if ticks == 2:
		i.lock = true
	var st: String = slice.get("state")
	if st != "fight":
		_wait += delta
		if _wait > 2.0:
			i.rematch = true
			_wait = 0.0
		return i
	_wait = 0.0
	if hunter.state == "dead" or dragon.state == "dead":
		return i
	var to := dragon.position - hunter.position
	to.y = 0.0
	var d := maxf(to.length() - dragon.HIT_RADIUS, 0.0)
	var dir := to.normalized()
	var side := dir.cross(Vector3.UP) * _side
	if ticks % 600 == 0:
		_side = -_side
	# threat: commit window -> dodge sideways
	if dragon.state == "tele" and dragon.telegraph_left <= DODGE_AT and hunter.state == "idle":
		i.dodge = true
		if dragon.skill == "tail":
			i.move = _local(-dir + side * 0.4)
		elif dragon.skill == "gust":
			i.move = _local(-dir)
		else:
			i.move = _local(side)
		return i
	if dragon.state == "act" and dragon.skill == "breath" and d < 6.0:
		i.move = _local(side)
		return i
	var punish := dragon.punishable or dragon.state == "stagger"
	if punish:
		if d > 2.2:
			i.move = _local(dir)
		else:
			if hunter.skill_cd <= 0.0 and hunter.state == "idle":
				i.skill = true
			else:
				i.attack = true
	elif dragon.state == "tele":
		# hold mid range, keep moving (meteors aim at where we WERE)
		if dragon.skill == "meteors":
			i.move = _local(side)
		elif d < 4.5:
			i.move = _local(-dir)
		elif d > 6.0:
			i.move = _local(dir)
		else:
			i.move = _local(side * 0.6)
	else:
		# idle/approach/recover(not punishable)/act: close to melee range and poke
		if d > 2.6:
			i.move = _local(dir)
		elif dragon.state != "act":
			i.attack = true
	if pet != null and pet.howl_cd <= 0.0 and d < 12.0:
		i.pet = true
	return i
