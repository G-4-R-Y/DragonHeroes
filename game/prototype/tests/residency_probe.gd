## Real Hunt entity lifetime, wounds, paired bosses, death and cap outcomes.
extends Node

var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func frames(count: int) -> void:
	for i in count: await get_tree().process_frame

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	Session.login("residency_probe")
	# R80: this gate needs a water tile near the spawn point, and an unpinned hunt
	# does not always have one -- `main.gd` calls `randomize()` and `world_gen.gd`
	# rolls `_hunt_seed = randi()`, so the fixture existed only on lucky seeds
	# (measured over 28 seeds: 3 had NO water within +/-35 tiles and several more
	# sat at ring 28-35, which is why this probe was red on master). Seed 41487 is
	# the one `stream_recovery.gd` already pins: origin walkable, so `spawn_point()`
	# is exactly (0,0), with water at ring 2. Pinned the way the co-op lobby does it,
	# then released so nothing else in the run inherits a forced world.
	MpNet.pending_seed = 41487
	var hunt := preload("res://prototype/main.tscn").instantiate()
	add_child(hunt)
	MpNet.pending_seed = 0
	hunt.set_physics_process(false)
	hunt.world.set_process(false)
	hunt.world._streaming = false  # this probe isolates entity lifetime from chunk jobs
	hunt.player.set_physics_process(false)
	for c in get_tree().get_nodes_in_group("creatures"): c.queue_free()
	await frames(3)
	hunt._bosses.clear()
	hunt.boss = null
	hunt.legendary_boss = null
	hunt._ground_species.clear()
	hunt.child_entered_tree.connect(func(c: Node):
		if c is ProtoCreature:
			c.set_physics_process(false)
			c.call_deferred("set_physics_process", false))
	var residence: ProtoEncounterResidency = hunt._residency
	var here: Vector2 = hunt.world.spawn_point()
	# R80: the NEAREST water tile, not "the first scanned row that holds water".
	# The old scan walked y from -35 up and took the first hit in that row, so the
	# fixture could land 560 px from spawn -- past residency's 512 px
	# `wake_distance()`, and the flyer then correctly refused to wake. That is
	# exactly how this gate produced "flying creature over drawn water did not
	# return". Ring outwards instead, and never further out than the wake radius.
	var water_position := here
	var max_ring := int(residence.wake_distance() / ProtoWorld.TILE) - 4
	for ring in range(1, max_ring + 1):
		for y in range(-ring, ring + 1):
			for x in range(-ring, ring + 1):
				if maxi(absi(x), absi(y)) != ring: continue   # ring shell only
				var point := here + Vector2(x * ProtoWorld.TILE, y * ProtoWorld.TILE)
				if hunt.world.tile_at(point) == ProtoWorld.T_WATER:
					water_position = point
					break
			if water_position != here: break
		if water_position != here: break
	check(water_position != here, "water fixture missing")
	var wisp := ProtoWisp.new()
	wisp.element = "frost"
	wisp.position = water_position
	wisp.pack_anchor = water_position
	hunt.add_child(wisp)
	wisp.set_physics_process(false)
	var wisp_id := residence.identity(wisp)
	var ordinary := ProtoCreature.new()
	ordinary.setup_from_entry({"id": "core.creature.residency_fixture", "name": "Wounded boar",
		"bundle": "fen_boar", "archetype": "brute", "hp_mult": 1.2}, "Brutal")
	ordinary.position = here
	ordinary.pack_anchor = here
	hunt.add_child(ordinary)
	ordinary.set_physics_process(false)
	ordinary.hp = ordinary.max_hp * 0.37
	ordinary._burn_t = 2.3
	ordinary._burn_dps = 4.0
	var before := {"hp": ordinary.hp, "max_hp": ordinary.max_hp, "damage": ordinary.damage}
	var id := residence.identity(ordinary)
	var body: WeakRef = weakref(ordinary)
	var pyre := ProtoPyreSovereign.new()
	var earth := ProtoTerravoreColossus.new()
	pyre.partner = earth
	earth.partner = pyre
	for c in [pyre, earth]:
		c.position = here
		c.pack_anchor = here
		hunt.add_child(c)
		c.set_physics_process(false)
		hunt._bosses.append(c)
	pyre.hp *= 0.41
	pyre._skill_cd["meteor"] = 2.7
	var pyre_hp := pyre.hp
	var pyre_id := residence.identity(pyre)
	var earth_id := residence.identity(earth)
	var gold_before: int = hunt.gold
	hunt.player.position = here + Vector2(1900, 0)
	var ally := Node2D.new()
	ally.position = here
	ally.add_to_group("player")
	hunt.add_child(ally)
	hunt._despawn_far_creatures()
	await frames(5)
	check(residence.asleep_count == 0, "creatures vanished beside a second hunter")
	ally.queue_free()
	await frames(2)
	hunt._despawn_far_creatures()
	await frames(30)
	check(body.get_ref() == null, "dormant ordinary body was retained in memory")
	check(residence.active_count() == 0 and residence.asleep_count == 4, "sleep did not release active cap slots")
	check(hunt._bosses.is_empty(), "dormant boss nodes were retained")
	Session.level = 30  # returning must not heal or rescale previously spawned foes
	hunt.player.position = here
	hunt._despawn_far_creatures()
	await frames(120)
	var returned_wisp := residence._live(wisp_id)
	check(is_instance_valid(returned_wisp), "flying creature over drawn water did not return")
	if is_instance_valid(returned_wisp):
		check(returned_wisp.global_position == water_position and returned_wisp.get("element") == "frost", "flying identity/position changed")
		returned_wisp.queue_free()
	var restored := residence._live(id)
	check(is_instance_valid(restored), "ordinary encounter was not restored")
	if is_instance_valid(restored):
		restored.set_physics_process(false)
		check(is_equal_approx(restored.hp, before.hp) and is_equal_approx(restored.max_hp, before.max_hp), "wounds or spawn HP changed: %.3f/%.3f vs %.3f/%.3f" % [restored.hp, restored.max_hp, before.hp, before.max_hp])
		check(is_equal_approx(restored._burn_t, 2.3) and restored._burn_dps == 4.0, "status state changed")
		check(is_equal_approx(restored.damage, before.damage), "level-up rerolled dormant damage")
		check(restored.species_name == "Wounded boar", "species identity changed")
	var restored_pyre := residence._live(pyre_id) as ProtoDuoBoss
	var restored_earth := residence._live(earth_id) as ProtoDuoBoss
	check(is_instance_valid(restored_pyre) and is_instance_valid(restored_earth), "duo did not return")
	if is_instance_valid(restored_pyre) and is_instance_valid(restored_earth):
		check(restored_pyre.partner == restored_earth and restored_earth.partner == restored_pyre, "duo linkage was lost")
		check(is_equal_approx(restored_pyre.hp, pyre_hp), "boss healed on return")
	check(hunt.gold == gold_before, "hibernation granted rewards")
	# A real kill after waking cannot become a restorable file again.
	if is_instance_valid(restored): restored.dot_damage(restored.max_hp * 5.0)
	var kills_after: int = hunt.kills
	hunt.player.position = here + Vector2(1900, 0)
	hunt._despawn_far_creatures()
	await frames(30)
	# Hold the cap one short of a duo wake; they must wait together.
	var cap_hag: ProtoHag
	for i in 119:
		var c: ProtoCreature = ProtoHag.new() if i == 118 else ProtoCreature.new()
		if c is ProtoHag: cap_hag = c
		c.position = here
		hunt.add_child(c)
		c.set_physics_process(false)
	hunt.player.position = here
	hunt._despawn_far_creatures()
	await frames(60)
	check(residence._live(pyre_id) == null and residence._live(earth_id) == null, "paired wake overshot available cap")
	var filler: Node = get_tree().get_nodes_in_group("creatures")[0]
	filler.queue_free()
	await frames(60)
	check(residence.active_count() == 120, "paired wake did not fill exactly the two free slots")
	cap_hag._summon(hunt)
	check(residence.active_count() == 120, "boss summons exceeded the active cap")
	check(residence._live(pyre_id) != null and residence._live(earth_id) != null, "pair failed to wake after slots opened")
	check(residence._live(id) == null and hunt.kills == kills_after, "dead encounter reappeared or duplicated rewards")
	var storage := residence.root
	print("RESIDENCY METRICS worst_step_ms=", residence.worst_step_ms)
	hunt.queue_free()
	await frames(5)
	check(not DirAccess.dir_exists_absolute(storage), "completed Hunt retained its scratch records")
	for f in failures: print("RESIDENCY FAIL: ", f)
	print("RESIDENCY ", "OK" if failures.is_empty() else "FAILED")
	get_tree().quit(0 if failures.is_empty() else 1)
