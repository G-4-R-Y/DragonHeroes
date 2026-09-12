# Outcome gate: real creature deaths cross the Hunt progression threshold.
# Keep hostile physics paused so damage/regen cannot mask the instant refill.
extends Node

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	Session.level = 1
	Session.kills = 0
	var hunt := preload("res://prototype/main.tscn").instantiate()
	add_child(hunt)
	for i in 300:
		if hunt.player != null and hunt._hud.has("stats"): break
		await get_tree().process_frame
	if hunt.player == null or not hunt._hud.has("stats"):
		_fail("Hunt did not finish booting")
		return
	hunt.process_mode = Node.PROCESS_MODE_DISABLED
	var p: ProtoPlayer = hunt.player
	var old_max := p.max_hp
	_spend(p)
	p.apply_stats()
	if not is_equal_approx(p.hp, 25.0) or p.dodge_charges != 0 or p.flask_charges != 0:
		_fail("ordinary stat application refilled resources")
		return
	var points := Session.attribute_points
	var skills := Session.skill_points
	# A changed stat source must be read before filling to the new maximum.
	Session.attributes.vitality += 3
	var host := preload("res://mp/host_driver.gd").new()
	hunt.add_child(host)
	host._spawn_remote(2, {"name": "LevelAlly", "class_id": "core.class.rogue"})
	host._spawn_remote(3, {"name": "DownedAlly", "class_id": "core.class.reaver"})
	var ally: ProtoPlayer = host._remotes[2].body
	var downed: ProtoPlayer = host._remotes[3].body
	_spend(ally)
	_spend(downed)
	downed.hp = 0.0
	downed.dead = true
	var equipment: Dictionary = ally._src().equipment.duplicate(true)
	hunt.kills = hunt._kills_for_level(1) - 2
	_kill(hunt)
	if Session.level != 1 or not is_equal_approx(p.hp, 25.0) or p.dodge_charges != 0:
		_fail("a non-level kill refilled the hunter")
		return
	_kill(hunt)
	host._physics_process(0.0)   # party refill is applied by the host, before snapshots
	if Session.level != 2 or Session.attribute_points != points + 5 or Session.skill_points != skills + 1:
		_fail("kill threshold or progression rewards changed")
		return
	if p.max_hp <= old_max or not is_equal_approx(p.max_hp, float(ProtoStats.compute(Session).max_hp)) or not _full(p):
		_fail("level-up did not recompute stats and fill HP/dodges/flasks")
		return
	if not is_equal_approx(hunt._hud.hp_bar.size.x, 180.0) or hunt._low_hp:
		_fail("HP HUD did not refresh immediately")
		return
	if not _full(ally) or ally._src().level != 2 or ally._src().equipment != equipment:
		_fail("party level-up did not refill the ally while preserving their build")
		return
	if not downed.dead or downed.hp != 0.0 or downed.flask_charges != 0:
		_fail("party level-up resurrected or refilled a downed ally")
		return
	_spend(p)
	hunt._grant_level_ups()
	if not is_equal_approx(p.hp, 25.0) or p.flask_charges != 0:
		_fail("rechecking an already-earned level gave another refill")
		return
	# One progression update may cross several thresholds; award all points once.
	hunt.kills = hunt._kills_for_level(1) + hunt._kills_for_level(2) + hunt._kills_for_level(3) - 1
	_kill(hunt)
	if Session.level != 4 or Session.attribute_points != points + 15 or Session.skill_points != skills + 3 or not _full(p):
		_fail("multi-level update lost rewards or resource refresh")
		return
	# A delayed kill after death can award a level without cancelling death.
	_spend(p)
	p.dead = true
	p.hp = 0.0
	hunt.kills += hunt._kills_for_level(4) - 1
	_kill(hunt)
	if Session.level != 5 or not p.dead or p.hp != 0.0 or p.dodge_charges != 0 or p.flask_charges != 0:
		_fail("level-up healed or revived a dead hunter")
		return
	print("LEVEL UP OK — real kills refresh stats/HP/HUD/dodges/flasks; party parity; no gear heal, duplicate refill, build reroll or revival; multi-level rewards preserved")
	hunt.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(0)

func _spend(p: ProtoPlayer) -> void:
	p.hp = 25.0
	p.dodge_charges = 0
	p._dodge_recharge = 0.8
	p.flask_charges = 0
	p.flask_kills = 0
	p._flask_hot = 1.0
	p._flask_rate = 20.0
	p._attack_cd = 0.3
	p.skill_cds = {"rv_gash": 2.0}
	p.charge_stacks = 2

func _full(p: ProtoPlayer) -> bool:
	return is_equal_approx(p.hp, p.max_hp) and p.dodge_charges == ProtoPlayer.DODGE_CHARGES_MAX \
		and p._dodge_recharge == 0.0 and p.flask_charges == ProtoPlayer.FLASK_MAX \
		and p.flask_kills == 0 and p._flask_hot == 0.0 and p._flask_rate == 0.0 \
		and is_equal_approx(p._attack_cd, 0.3) and p.skill_cds.get("rv_gash") == 2.0 and p.charge_stacks == 2

func _kill(hunt: Node) -> void:
	var creature := ProtoCreature.new()
	creature.stone_chance = 0.0
	creature.snare_chance = 0.0
	creature.item_chance = 0.0
	hunt.add_child(creature)
	creature.take_damage(creature.max_hp + 1.0, Vector2.ZERO)

func _fail(detail: String) -> void:
	push_error("LEVEL UP FAIL — " + detail)
	get_tree().quit(1)
