# REPOP PROBE — continuous spawn pressure as a gate (roadmap 2; Ricardo:
# "hordes don't keep spawning"). Boots the hunt, wipes the field, calls the
# repopulation pass, and asserts fresh mixed packs prowl in (with wisp support
# possible).   godot --headless --path game res://prototype/tests/repop_probe.tscn
extends Node

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var hunt := preload("res://prototype/main.tscn").instantiate()
	add_child(hunt)
	var waited := 0.0
	while waited < 60.0 and hunt.player == null:
		await get_tree().create_timer(0.5).timeout
		waited += 0.5
	if hunt.player == null:
		_verdict(false, "hunt never booted")
		return
	# wipe the field (as if the hunter cleared it)
	for m in get_tree().get_nodes_in_group("creatures"):
		if is_instance_valid(m):
			m.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	var before := get_tree().get_nodes_in_group("creatures").size()
	# the cadence would fire in 18 s; call the pass directly (it's the same path)
	for i in 3:
		hunt._repopulate()
	await get_tree().process_frame
	var after := get_tree().get_nodes_in_group("creatures").size()
	# pack mixing: at least 2 distinct bundles/species among the newcomers when
	# the roster allows it (variety gate — "always the same mobs")
	var species := {}
	for m in get_tree().get_nodes_in_group("creatures"):
		if is_instance_valid(m):
			species[str(m.get("bundle") if m.get("bundle") != null else m.get("archetype"))] = true
	if after <= before:
		_verdict(false, "repopulation spawned nothing (before=%d after=%d)" % [before, after])
	elif hunt._ground_species.size() >= 2 and species.size() < 2:
		_verdict(false, "repop spawned %d but all one species (variety)" % after)
	else:
		_verdict(true, "field restocked %d -> %d creatures across %d species" % [
				before, after, species.size()])

func _verdict(ok: bool, msg: String) -> void:
	if ok:
		print("REPOP OK — ", msg)
	else:
		push_error("REPOP FAIL — " + msg)
	get_tree().quit(0 if ok else 1)
