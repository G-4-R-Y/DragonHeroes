# SPAWN GATE: boots the real hunt, then asserts the world actually streamed and
# packs spawned on their rings — catches "world silently didn't boot" (a broken
# _ready yields an empty world and every pack collapses onto the player with
# ZERO script errors; main.tscn boot gates can't see it). Run:
#   godot --headless --path game res://prototype/tests/spawn_probe.tscn
# Ends SPAWNTEST OK or SPAWNTEST FAIL (+ detail), exit 0/1.
extends Node2D

var _t := 0.0

func _ready() -> void:
	var hunt := preload("res://prototype/main.tscn").instantiate()
	add_child(hunt)
	# This gate measures placement. Letting enemies chase for eight seconds
	# made a legitimate approach to the hunter look like a collapsed world.
	for creature in get_tree().get_nodes_in_group("creatures"):
		creature.set_physics_process(false)

func _process(delta: float) -> void:
	_t += delta
	if _t < 8.0:
		return
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		_verdict(false, "no player node")
		return
	var dists: Array = []
	for c in get_tree().get_nodes_in_group("creatures"):
		dists.append(c.global_position.distance_to(player.global_position))
	dists.sort()
	var world := get_tree().get_first_node_in_group("world")
	var streaming: bool = world != null and bool(world.get("_streaming"))
	if dists.size() < 20:
		_verdict(false, "only %d creatures — packs did not spawn" % dists.size())
	elif dists[0] < 100.0:
		_verdict(false, "nearest creature at %d px — world failed to load, packs collapsed onto the player (streaming=%s)" \
				% [int(dists[0]), streaming])
	else:
		_verdict(true, "creatures=%d nearest=%d px streaming=%s" % [
				dists.size(), int(dists[0]), streaming])

func _verdict(ok: bool, detail: String) -> void:
	if ok:
		print("SPAWNTEST OK — " + detail)
	else:
		push_error("SPAWNTEST FAIL: " + detail)
	get_tree().quit(0 if ok else 1)
