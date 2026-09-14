# ARENA — one combatant (docs/design/23): a body (creature, boss, or geared
# player build), its ArenaProxy (the uniform target surface), its policy, its
# pet, and its cosmetic loadout (ProtoCosmetics — auras/necklaces/weapon glows
# are VISUAL ONLY here; canon: cosmetics never touch combat math).
class_name ArenaFighter
extends Node2D

const TILE := 16.0
const CreatureScene := preload("res://prototype/creature.gd")
const BossScene := preload("res://prototype/boss.gd")
const HagScene := preload("res://prototype/hag.gd")
const PyreScene := preload("res://prototype/pyre_sovereign.gd")
const ColossusScene := preload("res://prototype/terravore_colossus.gd")
const PlayerScene := preload("res://prototype/player.gd")
const PetScene := preload("res://prototype/pet.gd")
const ProjectileScene := preload("res://prototype/projectile.gd")
const MainScript := preload("res://prototype/main.gd")

var build_id := ""
var build_name := ""
var policy_key := ""            # embedding-row key: species id / build id
var body: Node2D = null         # primary body (duo: first member)
var body2: Node2D = null        # duo second member (null otherwise)
var proxy: ArenaProxy = null
var proxy2: ArenaProxy = null   # duo second member's proxy
var build: ProtoBuild = null    # player builds only
var policy: ArenaPolicy = null
var pet: ProtoPet = null
var enemy: ArenaFighter = null  # wired by the arena at match start

# Creature skill kits (data from builds.json "skills"): per-species actives so
# same-chassis species fight DIFFERENTLY — and per-species nets have something
# to specialize in. Native AI fires them off cooldown (boss-kit style); bot
# policies reach them through cmd_skill(i) just like player builds.
var _kits: Array = []           # [{id, cd, kind?, element?, range?, _cd}]
var _kit_fire_t := 0.0
var _pending: Array = []        # [{t, cb: Callable}] scheduled kit resolutions

var damage_taken := 0.0
# Last emitted action (recorder): move vector + committed act code
# (0 none, 1 attack, 2 special, 3..6 skill slots, 7 dodge).
var last_action := {"move": Vector2.ZERO, "act": 0}
var _last_pos := Vector2.ZERO
var _vel := Vector2.ZERO
var _move_dir := Vector2.ZERO

func is_dead() -> bool:
	if is_instance_valid(body) and not body.dead:
		return false
	return body2 == null or not is_instance_valid(body2) or body2.dead

func owns_body(b: Node2D) -> bool:
	return b == body or (body2 != null and b == body2)

# Duo-aware HP: average fraction across members (obs + results).
func hp_frac() -> float:
	var fracs: Array = []
	for b in [body, body2]:
		if b != null and is_instance_valid(b):
			fracs.append(clampf(b.hp / maxf(b.max_hp, 1.0), 0.0, 1.0))
	if fracs.is_empty():
		return 0.0
	var s := 0.0
	for f in fracs:
		s += f
	return s / fracs.size()

# Duo-aware health BAR: the pool damage_taken is measured against. Reported per
# episode so ml/eval/env_parity.py can put the two runtimes' raw damage on one
# scale — dh-env's specs come from ml/env/specs.json and the arena's from the
# live content, so absolute hit points are not comparable but bars dealt are.
func max_hp_total() -> float:
	var total := 0.0
	for b in [body, body2]:
		if b != null and is_instance_valid(b):
			total += maxf(float(b.max_hp), 1.0)
	return maxf(total, 1.0)

# Enemies aim at the NEAREST living member's proxy (duo targeting).
func nearest_proxy_to(pos: Vector2) -> ArenaProxy:
	var ok1 := is_instance_valid(proxy) and not proxy.dead
	var ok2 := proxy2 != null and is_instance_valid(proxy2) and not proxy2.dead
	if ok1 and ok2 and proxy.global_position.distance_to(pos) \
			> proxy2.global_position.distance_to(pos):
		return proxy2
	if ok2 and not ok1:
		return proxy2
	return proxy

# Tear down every owned node (episode reset). The proxy is a child of the body
# and dies with it; the cosmetics rig likewise.
func free_body() -> void:
	if is_instance_valid(pet):
		pet.queue_free()
	if is_instance_valid(body):
		body.queue_free()
	if is_instance_valid(body2):
		body2.queue_free()
	queue_free()

# The live representative body: body while it lives, else the duo partner.
# A fallen duo member's body is FREED — every consumer must go through this.
func alive_body() -> Node2D:
	if is_instance_valid(body) and not body.dead:
		return body
	if body2 != null and is_instance_valid(body2) and not body2.dead:
		return body2
	return body   # both gone: callers guard via is_dead() first

# Living member proxies (1 for normal fighters, up to 2 for a duo).
func living_proxies() -> Array:
	var out: Array = []
	if is_instance_valid(proxy) and not proxy.dead:
		out.append(proxy)
	if proxy2 != null and is_instance_valid(proxy2) and not proxy2.dead:
		out.append(proxy2)
	return out

func alive_radius() -> float:
	var b := alive_body()
	return b.body_radius if is_instance_valid(b) else 8.0

func is_player() -> bool:
	return is_instance_valid(body) and body is ProtoPlayer

func note_damage_taken(dmg: float) -> void:
	damage_taken += dmg

func is_ranged() -> bool:
	var b := alive_body()
	if not is_instance_valid(b):
		return false
	if b is ProtoPlayer:
		return str(b._kit) == "mage"
	return b is ProtoWisp

func preferred_range() -> Vector2:
	var b := alive_body()
	if is_ranged():
		return Vector2(4.0 * TILE, 7.0 * TILE)
	return Vector2(0.5 * b.attack_reach, b.attack_reach)

func is_winding_up() -> bool:
	var b := alive_body()
	return not is_dead() and is_instance_valid(b) \
			and ("_state" in b) and b._state == "windup"

# ---- construction --------------------------------------------------------------------

func setup(def: Dictionary, arena: Node, at: Vector2, policy_spec: String,
		seed: int) -> void:
	build_id = str(def.get("id", "?"))
	build_name = str(def.get("name", build_id))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	match str(def.get("kind", "creature")):
		"player":
			build = ProtoBuild.make_player_build(def, rng)
			body = PlayerScene.new()
			body.build_source = build
			policy_key = build_id
		"boss":
			body = _make_boss(str(def.get("chassis", "boss")), def)
			policy_key = str(def.get("chassis", "boss"))
		"duo":   # a Legendary duo as ONE fighter: two partnered bodies, shared fate
			var members: Array = def.get("members", ["pyre", "colossus"])
			body = _make_boss(str(members[0]), def)
			body2 = _make_boss(str(members[1]) if members.size() > 1 else "colossus", def)
			if body is ProtoDuoBoss and body2 is ProtoDuoBoss:
				body.partner = body2
				body2.partner = body
			policy_key = build_id
		_:   # "creature" — a bestiary species entry on its archetype chassis
			body = CreatureScene.new()
			var entry := _find_entry(str(def.get("species", "")), def)
			if not entry.is_empty():
				body.setup_from_entry(entry, str(def.get("affix", "")))
				policy_key = str(entry.get("id", build_id))
			else:
				body.setup_archetype(str(def.get("archetype", "stalker")),
						str(def.get("affix", "")))
				policy_key = build_id
	var hp_scale := float(def.get("hp_scale", 1.0))
	var dmg_scale := float(def.get("dmg_scale", 1.0))
	# Player bots have no "native" mind — the scripted baseline drives them.
	var spec := policy_spec
	if body is ProtoPlayer and spec == "native":
		spec = "scripted"
	if spec != "native":
		body.bot_drive = true
	# Every creature body in the arena is a duellist, not a dungeon inhabitant:
	# it was placed here to fight the other one. Without this it spawns OUTSIDE
	# its own aggro_range (300 px apart, every species aggros at 112-208 px) and
	# stays idle until the opponent closes — so a policy that keeps its distance
	# was scored against a creature that never woke up. See creature.gd's
	# `arena_duel` for the measurement. Harmless on bot_drive bodies, which skip
	# the idle/chase machine entirely; set on all of them so the meaning is
	# "this body is in a duel", not "this body needs a workaround".
	if not (body is ProtoPlayer):
		body.arena_duel = true
	body.global_position = at
	arena.add_child(body)
	if body is ProtoPlayer:
		body.apply_stats()   # recompute with level-scaled arena gear in place
	else:
		body.max_hp *= hp_scale
		body.hp = body.max_hp
		body.damage *= dmg_scale
	# Creature bodies leave the "creatures" group: the proxy is the fighter's
	# ONLY representative there (no double-hits). Done post-_ready.
	if body.is_in_group("creatures"):
		body.remove_from_group("creatures")
	proxy = ArenaProxy.new()
	proxy.setup(body, self)
	body.add_child(proxy)
	if body2 != null:   # duo second member: its own body, proxy, and group exit
		if spec != "native":
			body2.bot_drive = true
		if not (body2 is ProtoPlayer):
			body2.arena_duel = true
		body2.global_position = at + Vector2(36, 24)
		arena.add_child(body2)
		body2.max_hp *= hp_scale
		body2.hp = body2.max_hp
		body2.damage *= dmg_scale
		if body2.is_in_group("creatures"):
			body2.remove_from_group("creatures")
		proxy2 = ArenaProxy.new()
		proxy2.setup(body2, self)
		body2.add_child(proxy2)
	# creature skill kits: this species' actives (data), each with its cooldown
	for k in def.get("skills", []):
		_kits.append({"id": str(k.get("id", "")), "cd": float(k.get("cd", 6.0)),
				"kind": str(k.get("kind", "fire")), "element": str(k.get("element", "")),
				"range": float(k.get("range", 7.0 * TILE)), "_cd": 0.0})
	# Cosmetics: pure presentation (aura / Grand-Chase necklace / weapon glow).
	var cos: Dictionary = def.get("cosmetics", {})
	if not cos.is_empty():
		ProtoCosmetics.attach(body, cos)
	# Pet companion (bounty hunters bring their bonded roll).
	var pet_def: Dictionary = def.get("pet", {})
	if not pet_def.is_empty():
		pet = PetScene.new()
		pet.setup({"uid": 1, "name": pet_def.get("name", "Gloam Stalker"),
				"roll_pct": int(pet_def.get("roll_pct", 100)),
				"species": pet_def.get("species", "")})
		pet.owner_override = body
		pet.global_position = at + Vector2(24, 0)
		arena.add_child(pet)
	# Policy. "default" defers to game/arena/data/ai_defaults.json — the game's
	# default AI per build, which the training console's NETS tab writes and the
	# deployed registry pin feeds (ai_defaults.gd).
	if spec == "default":
		policy = ArenaAIDefaults.policy_for(build_id)
	elif spec == "native":
		policy = ArenaPolicy.new()   # inert: the body's own AI runs
	elif spec == "scripted" or spec == "":
		policy = ArenaScriptedPolicy.new()
	else:
		policy = ArenaNeuralPolicy.from_file(spec)

func _make_boss(chassis: String, def: Dictionary) -> Node2D:
	var b: Node2D
	match chassis:
		"hag":
			b = HagScene.new()
		"pyre":
			b = PyreScene.new()
		"colossus":
			b = ColossusScene.new()
		_:
			b = BossScene.new()
	var leg := _find_entry(str(def.get("legendary", "")), def, "legendary")
	if not leg.is_empty():
		b.setup_legendary(leg)
		b.display_name = str(leg.get("name", build_name))
		b.bar_color = Color(str(leg.get("tint", "#c95bff")))
	return b

func _find_entry(species: String, def: Dictionary, kind := "normal") -> Dictionary:
	if species != "":
		for e in MainScript.bestiary(kind):
			if str(e.get("id", "")) == species:
				return e
	var bundle := str(def.get("bundle", ""))
	if bundle != "":
		for e in MainScript.bestiary(kind):
			if str(e.get("bundle", "")) == bundle:
				return e
	return {}

# ---- per-frame wiring (arena calls before bodies process) ------------------------------

func pre_tick(delta: float, enemy: ArenaFighter) -> void:
	if is_dead():
		return
	var me := alive_body()
	_vel = (me.global_position - _last_pos) / maxf(delta, 0.0001)
	_last_pos = me.global_position
	# kit cooldowns + scheduled resolutions
	for k in _kits:
		k._cd = maxf(float(k._cd) - delta, 0.0)
	if not _pending.is_empty():
		var keep: Array = []
		for p in _pending:
			p.t = float(p.t) - delta
			if float(p.t) <= 0.0:
				(p.cb as Callable).call()
			else:
				keep.append(p)
		_pending = keep
	# target wiring: creatures hunt the ENEMY's NEAREST living proxy (duo-aware);
	# players are aimed by their policy via bot_aim.
	if not (me is ProtoPlayer):
		var foe_proxy: ArenaProxy = enemy.nearest_proxy_to(me.global_position)
		me.target_override = foe_proxy
		if body2 != null and is_instance_valid(body2) and me != body2:
			body2.target_override = foe_proxy
	if policy != null:
		policy.tick(delta)
	# apply the policy's movement command through the body's own path
	if me is ProtoPlayer:
		if me.bot_drive:
			var spd: float = me.move_speed * (0.65 if me._slow_t > 0.0 else 1.0)
			me._bot_step = _move_dir.limit_length(1.0) * spd * delta
	elif me.bot_drive:
		if _move_dir.length() > 0.05:
			me._move(_move_dir.normalized() * me._speed() * delta)
	# native AI fires its species kit off cooldown, boss-kit style — this is what
	# makes same-chassis species fight differently (bot policies use cmd_skill)
	if not _kits.is_empty() and policy != null and policy.policy_id() == "native" \
			and enemy != null and not enemy.is_dead():
		_kit_fire_t -= delta
		if _kit_fire_t <= 0.0:
			for i in _kits.size():
				var k: Dictionary = _kits[i]
				if float(k._cd) > 0.0:
					continue
				var d: float = enemy.nearest_proxy_to(me.global_position) \
						.global_position.distance_to(me.global_position)
				if d <= float(k.range) and _kit_exec(i):
					_kit_fire_t = 0.4
					break

func post_tick() -> void:
	if is_instance_valid(body) and body is ProtoPlayer:
		body._bot_step = Vector2.ZERO   # commands are per-frame intents

# ---- policy command API ---------------------------------------------------------------

func cmd_move(dir: Vector2) -> void:
	_move_dir = dir
	last_action.move = dir

func cmd_aim(pos: Vector2) -> void:
	if body is ProtoPlayer:
		body.bot_aim = pos

func cmd_attack() -> bool:
	if is_dead():
		return false
	if body is ProtoPlayer:
		if body._attack_cd > 0.0:
			return false
		body._attack()
		ProtoCosmetics.pulse(body.get_node_or_null("Cosmetics"))
		last_action.act = 1
		return true
	var ok: bool = body.bot_attack(proxy_of_enemy_dir())
	if ok:
		last_action.act = 1
	return ok

func cmd_special() -> bool:
	if is_dead():
		return false
	if is_player():
		if body._whirl_cd > 0.0:
			return false
		match str(body._kit):
			"mage": body._frost_nova()
			"rogue": body._fan_of_knives()
			_: body._whirlwind()
		ProtoCosmetics.pulse(body.get_node_or_null("Cosmetics"))
		last_action.act = 2
		return true
	var ok: bool = alive_body().bot_attack(proxy_of_enemy_dir())
	if ok:
		last_action.act = 2
	return ok

func cmd_skill(i: int) -> bool:
	if is_dead():
		return false
	if is_player():
		if build == null or i < 0 or i >= build.skill_loadout.size():
			return false
		var id := str(build.skill_loadout[i])
		if id == "" or body.skill_cd_left(id) > 0.0:
			return false
		var def := build.skill_def(id)
		if def.is_empty():
			return false
		var ok: bool = body.use_skill(def)
		if ok:
			last_action.act = 3 + i
		return ok
	# creatures: fire species-kit slot i (bot policies learn WHEN to use them)
	var ok := _kit_exec(i)
	if ok:
		last_action.act = 3 + i
	return ok

# ---- creature skill kits -----------------------------------------------------------
# damage is already build-scaled in setup (body.damage *= dmg_scale) — kits use it raw.

func _kit_exec(i: int) -> bool:
	if i < 0 or i >= _kits.size() or is_dead() or enemy == null or enemy.is_dead():
		return false
	var k: Dictionary = _kits[i]
	if float(k._cd) > 0.0:
		return false
	var arena := get_parent()
	var me := alive_body()
	var foe_proxy: ArenaProxy = enemy.nearest_proxy_to(me.global_position)
	var foe_pos: Vector2 = foe_proxy.global_position
	var from: Vector2 = me.global_position
	var element := str(k.element) if str(k.element) != "" else str(k.kind)
	match str(k.id):
		"bolt_volley":
			for j in 3:
				var p := ProjectileScene.new()
				p.shooter = me
				p.dmg_type = element   # storm bolts detonate mire fields (§12.41)
				match element:
					"frost": p.set_frost()
					"umbral", "venom", "blood": p.set_violet()
					"storm": p.set_arcane()
				p.global_position = from
				p.velocity = (foe_pos - from).normalized().rotated(
						deg_to_rad(-12.0 + 12.0 * j)) * 13.0 * TILE
				p.damage = me.damage * 0.8
				arena.add_child(p)
		"radial_slam":
			arena.telegraphs.ring(from, 2.2 * TILE, 0.45)
			_pending.append({"t": 0.45, "cb": func() -> void:
				if is_dead() or enemy == null or enemy.is_dead():
					return
				var src := alive_body()
				var pr: ArenaProxy = enemy.nearest_proxy_to(src.global_position)
				if pr.global_position.distance_to(src.global_position) \
						<= 2.2 * TILE + pr.body_radius:
					pr.take_damage(src.damage * 1.5,
							(pr.global_position - src.global_position).normalized())
				arena.fx.shockwave(src.global_position, Color("ffb347"), 2.2 * TILE)
				arena.fx.shader_burst("impact", src.global_position,
						{"size": 64.0, "color": Color(0.9, 0.7, 0.45)})})
		"pounce":
			var dir := (foe_pos - from).normalized()
			for _i in 6:
				me._move(dir * 3.0 * TILE / 6.0)
			if foe_pos.distance_to(me.global_position) <= me.attack_reach \
					+ foe_proxy.body_radius:
				foe_proxy.take_damage(me.damage, dir)
		"field_cast":
			arena.spawn_field(foe_pos, 2.5 * TILE, 6.0,
					me.damage * 0.3, str(k.kind), false, self)
		"enrage":
			if me.has_method("enrage"):
				me.enrage(4.0)
		_:
			return false
	k._cd = float(k.cd)
	return true

func cmd_dodge(dir: Vector2) -> bool:
	if is_dead() or not is_player():
		return false
	var ok: bool = body.bot_dodge(dir)
	if ok:
		last_action.act = 7
	return ok

func proxy_of_enemy_dir() -> Vector2:
	if enemy != null and not enemy.is_dead():
		return (enemy.alive_body().global_position \
				- alive_body().global_position).normalized()
	return Vector2.RIGHT

# ---- observation (schema "arena.obs.v1" — see policy.gd header) ------------------------

func obs_vector(enemy: ArenaFighter) -> PackedFloat32Array:
	var o := PackedFloat32Array()
	o.resize(ArenaPolicy.OBS_DIM)
	if is_dead():
		return o
	var me := alive_body()
	var foe_ok := enemy != null and not enemy.is_dead()
	var foe_pos: Vector2 = enemy.alive_body().global_position if foe_ok \
			else me.global_position
	o[0] = hp_frac()
	o[1] = clampf(me.global_position.x / 512.0, -1.0, 1.0)
	o[2] = clampf(me.global_position.y / 512.0, -1.0, 1.0)
	o[3] = clampf(_vel.x / 100.0, -2.0, 2.0)
	o[4] = clampf(_vel.y / 100.0, -2.0, 2.0)
	if me is ProtoPlayer:
		o[5] = clampf(me._attack_cd / maxf(me.attack_cd_s, 0.01), 0.0, 1.0)
		o[6] = clampf(me._whirl_cd / maxf(me.whirl_cd_s, 0.01), 0.0, 1.0)
		if build != null:
			for i in 4:
				var id := str(build.skill_loadout[i])
				if id != "":
					var def := build.skill_def(id)
					var cd := float((def.get("params", {}) as Dictionary).get("cd", 6.0))
					o[7 + i] = clampf(me.skill_cd_left(id) / maxf(cd, 0.01), 0.0, 1.0)
		o[11] = float(me.charge_stacks) / maxf(float(me.charge_max), 1.0)
		o[12] = float(me.dodge_charges) / float(ProtoPlayer.DODGE_CHARGES_MAX)
		o[13] = 1.0 if me._slow_t > 0.0 else 0.0
	else:
		o[5] = clampf(me._cd / maxf(me.attack_cd, 0.01), 0.0, 1.0)
		for i in mini(_kits.size(), 4):   # kit cooldowns: nets learn WHEN to cast
			o[7 + i] = clampf(float(_kits[i]._cd) / maxf(float(_kits[i].cd), 0.01), 0.0, 1.0)
		o[13] = 1.0 if me._slow_t > 0.0 else 0.0
		o[14] = 1.0 if me._burn_t > 0.0 or me._bleed_t > 0.0 else 0.0
	if foe_ok:
		var rel: Vector2 = foe_pos - me.global_position
		var dist := rel.length()
		o[15] = enemy.hp_frac()
		o[16] = clampf(rel.x / 512.0, -1.0, 1.0)
		o[17] = clampf(rel.y / 512.0, -1.0, 1.0)
		o[18] = clampf(dist / 512.0, 0.0, 1.0)
		if dist > 0.01:
			var ang := rel.angle()
			o[19] = sin(ang)
			o[20] = cos(ang)
		o[21] = clampf(enemy.alive_radius() / 16.0, 0.0, 2.0)
		o[22] = 1.0 if enemy.is_winding_up() else 0.0
	# two nearest hostile projectiles
	var hostile_friendly := not is_player()
	var found: Array = []
	for n in get_tree().get_nodes_in_group("arena_projectiles"):
		found.append(n)
	found.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return a.global_position.distance_squared_to(me.global_position) \
				< b.global_position.distance_squared_to(me.global_position))
	var slot := 0
	for p in found:
		if slot >= 2:
			break
		if bool(p.friendly) != hostile_friendly:
			continue
		var rel: Vector2 = p.global_position - me.global_position
		o[23 + slot * 4] = clampf(rel.x / 512.0, -1.0, 1.0)
		o[24 + slot * 4] = clampf(rel.y / 512.0, -1.0, 1.0)
		o[25 + slot * 4] = clampf(p.velocity.x / 256.0, -2.0, 2.0)
		o[26 + slot * 4] = clampf(p.velocity.y / 256.0, -2.0, 2.0)
		slot += 1
	return o
