## Actual leave/return loot, full-cap/full-bag collection and offscreen shots.
extends Node

var failures: Array[String] = []

func check(ok: bool, why: String) -> void:
	if not ok: failures.append(why)

func frames(count: int) -> void:
	for i in count: await get_tree().process_frame

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	Session.login("ground_state_probe")
	var hunt := preload("res://prototype/main.tscn").instantiate()
	add_child(hunt)
	hunt.set_physics_process(false)
	hunt.world.set_process(false)
	hunt.world._streaming = false
	hunt.player.set_physics_process(false)
	for c in get_tree().get_nodes_in_group("creatures"): c.queue_free()
	await frames(3)
	hunt._bosses.clear()
	hunt.boss = null
	hunt.legendary_boss = null
	hunt._ground_species.clear()
	hunt.child_entered_tree.connect(func(node: Node):
		if node is ProtoCreature or node is ProtoPickup or node is ProtoProjectile:
			node.set_physics_process(false)
			node.call_deferred("set_physics_process", false))
	var residency: ProtoEncounterResidency = hunt._residency
	var here: Vector2 = hunt.world.spawn_point()
	hunt.player.position = here + Vector2(1900, 0)
	var original := ProtoItems.roll_item("emberfang_blade", "legendary", 7, 0.5)
	var ids: Array[int] = []
	var bodies: Array[WeakRef] = []
	for kind in ["gold", "item"]:
		var loot := ProtoPickup.new()
		loot.kind = kind
		loot.amount = 37
		loot.item = original.duplicate(true) if kind == "item" else {}
		loot.position = here
		hunt.add_child(loot)
		loot.set_physics_process(false)
		ids.append(residency.identity(loot))
		bodies.append(weakref(loot))
	residency.sweep()
	await frames(30)
	check(residency.asleep_loot == 2 and bodies[0].get_ref() == null and bodies[1].get_ref() == null,
		"distant loot was lost or retained live nodes")
	# Even a saturated creature cap must not keep loot hidden on return.
	for i in hunt.REPOP_CAP:
		var c := ProtoCreature.new()
		c.position = here + Vector2(300, 0)
		hunt.add_child(c)
		c.set_physics_process(false)
	Session.level = 70
	hunt.player.position = here + Vector2(100, 0)
	residency.sweep()
	await frames(100)
	var gold := residency._live(ids[0]) as ProtoPickup
	var gear := residency._live(ids[1]) as ProtoPickup
	check(is_instance_valid(gold) and is_instance_valid(gear) and residency.asleep_loot == 0,
		"loot failed to return with a full creature cap")
	if is_instance_valid(gold) and is_instance_valid(gear):
		check(gear.item == original and gold.amount == 37 and gear._base_y == here.y,
			"loot identity/rolls/amount/position changed after travel and level-up")
		Session.inventory.clear()
		for i in ProtoItems.INVENTORY_CAP: Session.inventory.append({"uid": "filler-%d" % i})
		hunt.player.position = gear.position
		gear._physics_process(0.0)
		check(not gear._collected and gear.item == original, "full bag destroyed or rerolled ground gear")
		Session.inventory.clear()
		Session.equipment["weapon"] = ProtoItems.roll_item("emberfang_blade", "common", 1)
		gear._physics_process(0.0)
		gear._physics_process(0.0)
		check(Session.inventory.size() == 1 and Session.inventory[0] == original,
			"item collection was missing, duplicated or changed")
		var before: int = hunt.gold
		hunt.player.position = gold.position
		gold._physics_process(0.0)
		gold._physics_process(0.0)
		check(hunt.gold == before + 37, "gold collection did not commit exactly once")
	await frames(4)
	hunt.player.position = here + Vector2(1900, 0)
	residency.sweep()
	await frames(3)
	hunt.player.position = here
	residency.sweep()
	await frames(100)
	check(residency._live(ids[0]) == null and residency._live(ids[1]) == null,
		"collected loot reappeared on another visit")
	# Separate projectile fixture: camera/hunter leaves, original caster vanishes.
	residency.set_process(false)
	for c in get_tree().get_nodes_in_group("creatures"): c.queue_free()
	await frames(3)
	var target := ProtoCreature.new()
	target.position = here + Vector2(100, 0)
	hunt.add_child(target)
	target.set_physics_process(false)
	var bolt := ProtoProjectile.new()
	bolt.friendly = true
	bolt.damage = 7.0
	bolt.lifetime = 3.0
	bolt.velocity = Vector2(100, 0)
	bolt.position = here
	var caster := Node2D.new()
	hunt.add_child(caster)
	bolt.shooter = caster
	hunt.add_child(bolt)
	bolt.set_physics_process(false)
	caster.free()
	hunt.player.position = here + Vector2(1900, 0)
	check(not residency._can_sleep(target), "travel unloaded a target while a live shot could still hit it")
	bolt._physics_process(0.25)
	check(not bolt._finished and bolt.position == here + Vector2(25, 0) and is_equal_approx(bolt.lifetime, 2.75),
		"offscreen projectile disappeared, froze or reset its lifetime")
	var hp := target.hp
	bolt._physics_process(0.75)
	var after := target.hp
	bolt._physics_process(0.1)
	check(after < hp and target.hp == after and bolt._finished, "offscreen impact was lost or repeated")
	var expired := ProtoProjectile.new()
	expired.position = here + Vector2(500, 0)
	expired.lifetime = 0.25
	hunt.add_child(expired)
	expired.set_physics_process(false)
	expired._physics_process(0.3)
	check(expired._finished and expired._trail_id == -1 and expired._light_id == -1,
		"natural projectile expiry leaked its visuals")
	# Deterministically quit with one water MultiMesh still staged off-tree.
	var pending: MultiMeshInstance2D = hunt.world._make_water_mmi(Vector2i(999, 999), 1024)
	var pending_ref: WeakRef = weakref(pending)
	hunt.world._water[Vector2i(999, 999)] = pending
	var storage := residency.root
	hunt.queue_free()
	await frames(5)
	check(pending_ref.get_ref() == null, "Hunt teardown leaked an off-tree water MultiMesh")
	check(not DirAccess.dir_exists_absolute(storage), "Hunt retained its ground-state scratch records")
	for why in failures: print("GROUND STATE FAIL: ", why)
	print("GROUND STATE ", "OK" if failures.is_empty() else "FAILED")
	get_tree().quit(0 if failures.is_empty() else 1)
