# ARENA — the FighterProxy. Every combatant (creature body OR player-build body)
# gets ONE of these as a child at (0,0). It is the fighter's ONLY member of the
# "creatures" group (creature bodies are de-grouped by Fighter), which makes it
# the single, uniform target surface for every attack in the prototype combat
# code — melee arcs, novas, chains, dashes, projectiles, pet strikes, boss kits.
#
# Why it exists: creature strikes call player-style signatures
# (take_damage(dmg, dir, "fire")) while players take creature-style ones
# (take_damage(dmg, dir, color, crit)) — the proxy adapts both directions, so
# creature-vs-creature, build-vs-creature and build-vs-build all work through
# ONE code path. `owner_fighter` is the body; the ARENA HOOK skip-guards in
# player.gd/projectile.gd/pet.gd use it so a fighter never hits its own proxy.
class_name ArenaProxy
extends Node2D

var owner_fighter: Node2D = null     # the wrapped combat body (skip-guard key)
var fighter: Node = null             # the ArenaFighter (stats/AI wiring)

var _threat := false                 # players have no `threat`; pets read ours
var _dots: Array = []                # fallback DoTs for bodies without statuses

var dead: bool:
	get: return not is_instance_valid(owner_fighter) or bool(owner_fighter.dead)
var hp: float:
	get: return 0.0 if not is_instance_valid(owner_fighter) else float(owner_fighter.hp)
var max_hp: float:
	get: return 1.0 if not is_instance_valid(owner_fighter) else float(owner_fighter.max_hp)
var body_radius: float:
	get: return 9.0 if not is_instance_valid(owner_fighter) else float(owner_fighter.body_radius)
var threat: bool:
	get: return _threat or (is_instance_valid(owner_fighter) \
			and ("threat" in owner_fighter) and bool(owner_fighter.threat))

func _ready() -> void:
	# The proxy is the fighter's ONLY member of "creatures" (the body was
	# de-grouped) — every melee arc, nova, chain, projectile and pet finds it.
	add_to_group("creatures")

func setup(body: Node2D, owner: Node) -> void:
	owner_fighter = body
	fighter = owner

func _physics_process(delta: float) -> void:
	# Proxy-side DoTs: only used when the body lacks the status machinery
	# (player bodies can't bleed/burn on their own). Ticked as "status" damage.
	if _dots.is_empty() or dead:
		return
	var keep: Array = []
	for d in _dots:
		var dmg := float(d.dps) * delta
		if is_instance_valid(owner_fighter):
			owner_fighter.take_damage(dmg, Vector2.ZERO, "status")
		if fighter != null:
			fighter.note_damage_taken(dmg)
		d.until -= delta
		if float(d.until) > 0.0:
			keep.append(d)
	_dots = keep

# The universal hit entry point. arg3 arrives as a Color (creature-style hits)
# or a damage-type String (player-style fiery packets); route by body type.
func take_damage(dmg: float, from_dir: Vector2, arg3: Variant = Color("cfd6ff"),
		crit := false) -> void:
	if dead:
		return
	_threat = true
	if owner_fighter is ProtoPlayer:
		var dmg_type := str(arg3) if arg3 is String else "physical"
		owner_fighter.take_damage(dmg, from_dir, dmg_type)
	elif arg3 is String:   # element packet on a creature body: raw damage
		owner_fighter.take_damage(dmg, from_dir)
	else:
		owner_fighter.take_damage(dmg, from_dir, arg3, crit)
	if fighter != null:
		# a String arg3 is an element packet = a projectile (or a player-style
		# swing, which no creature-league build throws); a Color is contact
		fighter.note_damage_taken(dmg, "bolt" if arg3 is String else "contact")

func dot_damage(dmg: float, num_color := Color("ff9a3c")) -> void:
	if dead:
		return
	if owner_fighter.has_method("dot_damage"):
		owner_fighter.dot_damage(dmg, num_color)
	else:
		owner_fighter.take_damage(dmg, Vector2.ZERO, "status")
	if fighter != null:
		fighter.note_damage_taken(dmg, "field")

func knockback(vec: Vector2) -> void:
	if not dead:
		if owner_fighter.has_method("knockback"):
			owner_fighter.knockback(vec)
		elif owner_fighter.has_method("shove"):
			owner_fighter.shove(vec.normalized(), vec.length())

func shove(dir: Vector2, dist: float) -> void:
	knockback(dir.normalized() * dist)

func apply_slow(duration: float) -> void:
	if not dead and owner_fighter.has_method("apply_slow"):
		owner_fighter.apply_slow(duration)

func apply_status(key: String, power: float, duration: float) -> void:
	if dead:
		return
	if owner_fighter.has_method("apply_status"):
		owner_fighter.apply_status(key, power, duration)
	elif key == "chill":
		apply_slow(duration)
	elif key == "ignite" or key == "bleed":
		_dots.append({"key": key, "dps": power, "until": duration})

func has_status(key: String) -> bool:
	if dead:
		return false
	if owner_fighter.has_method("has_status"):
		return owner_fighter.has_status(key)
	for d in _dots:
		if str(d.key) == key:
			return true
	return false

func clear_status(key: String) -> void:
	if not is_instance_valid(owner_fighter):
		return
	if owner_fighter.has_method("clear_status"):
		owner_fighter.clear_status(key)
	_dots = _dots.filter(func(d: Dictionary) -> bool: return str(d.key) != key)

func ignite(dps: float, duration: float) -> void:
	apply_status("ignite", dps, duration)

func spread_ignite(radius: float) -> void:
	if not dead and owner_fighter.has_method("spread_ignite"):
		owner_fighter.spread_ignite(radius)

func detonate_ignite() -> float:
	if not dead and owner_fighter.has_method("detonate_ignite"):
		return owner_fighter.detonate_ignite()
	# Fallback bodies (players) pop their proxy-side burn as one packet.
	var total := 0.0
	var keep: Array = []
	for d in _dots:
		if str(d.key) == "ignite":
			total += float(d.dps) * float(d.until)
		else:
			keep.append(d)
	_dots = keep
	if total > 0.0 and not dead:
		owner_fighter.take_damage(total, Vector2.ZERO, "status")
		if fighter != null:
			fighter.note_damage_taken(total)
	return total

func enrage(duration: float) -> void:
	if not dead and owner_fighter.has_method("enrage"):
		owner_fighter.enrage(duration)
