## Outcomes for interrupted loads, unload reversal, far/negative travel and
## a failed helper request. Uses the real C++ generator and real apply queue.
extends Node2D

var world: ProtoWorld
var hunter: Node2D
var peak_chunks := 0
var checked_fence := false
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _process(_dt: float) -> void:
	if world == null: return
	peak_chunks = maxi(peak_chunks, world.chunks.size())
	if world._apply_active and world._apply_mode == "load" and not checked_fence:
		var tiles: PackedByteArray = world.chunks[world._apply_key]
		for i in tiles.size():
			if tiles[i] != 1 and tiles[i] != 2: continue
			@warning_ignore("integer_division")
			var p := Vector2(world._apply_key * 64 + Vector2i(i % 64, i / 64)) * 16 + Vector2(8, 8)
			check(not world.is_walkable(p), "unfinished terrain opened the movement fence")
			checked_fence = true
			break

func travel(key: Vector2i) -> void:
	hunter.position = Vector2(key * 64 + Vector2i(32, 32)) * 16

func settle(key: Vector2i) -> bool:
	var until := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame
		if world._player_chunk != key or world._req_inflight or world._apply_active or not world._jobs.is_empty(): continue
		var ready := true
		for y in range(-2, 3):
			for x in range(-2, 3):
				ready = ready and world.chunks.has(key + Vector2i(x, y))
		if ready: return true
	check(false, "stream did not recover at %s" % key)
	return false

func _ready() -> void:
	hunter = Node2D.new()
	hunter.add_to_group("player")
	add_child(hunter)
	world = ProtoWorld.new()
	world.forced_seed = 41487
	add_child(world)
	check(world.can_stream(), "real helper missing")
	if not world.can_stream():
		get_tree().quit(1)
		return
	print("[recovery] interrupting far loads")
	var origin: PackedByteArray = world.chunks[Vector2i.ZERO].duplicate()
	# Move again before either the worker or its apply jobs can settle.
	for key in [Vector2i(14, -11), Vector2i(400, -370), Vector2i(-1530, 980)]:
		travel(key)
		for i in 3: await get_tree().process_frame
	await settle(Vector2i(-1530, 980))
	print("[recovery] far travel settled")
	check(world._staged.is_empty(), "obsolete staging leaked after far travel")
	travel(Vector2i(12, 0))
	await settle(Vector2i(12, 0))
	travel(Vector2i(24, 0))
	var until := Time.get_ticks_msec() + 30000
	var reversed := false
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame
		if world._apply_active and world._apply_mode == "unload":
			var back := world._apply_key
			travel(back)
			await settle(back)
			reversed = true
			break
	check(reversed, "did not exercise reversal during an active unload")
	print("[recovery] unload reversed")
	# Simulate a temporary helper failure, then restore it without moving.
	if OS.has_feature("linux"):
		var helper := world._bin_path
		world._bin_path = "/usr/bin/false"
		travel(Vector2i(-70, -60))
		until = Time.get_ticks_msec() + 3000
		while world._stream_failures == 0 and Time.get_ticks_msec() < until:
			await get_tree().process_frame
		check(world._stream_failures > 0, "failed request was not recorded")
		world._bin_path = helper
		await settle(Vector2i(-70, -60))
		check(world._stream_failures == 0, "retry did not recover")
	travel(Vector2i.ZERO)
	await settle(Vector2i.ZERO)
	check(world.chunks.get(Vector2i.ZERO) == origin, "revisited origin changed its terrain")
	check(checked_fence, "did not inspect an unfinished walkable chunk")
	check(peak_chunks <= 49, "active tile capacity exceeded 49: %d" % peak_chunks)
	check(world._pending_unload.is_empty() and world._staged.is_empty(), "pending state leaked")
	check(not FileAccess.file_exists("user://stream_%d.json" % world.get_instance_id()), "scratch dump was retained")
	for f in failures: print("STREAM RECOVERY FAIL: ", f)
	print("STREAM RECOVERY ", "OK" if failures.is_empty() else "FAILED", " peak_chunks=", peak_chunks,
		" worst_apply_ms=", world._worst_apply_ms)
	get_tree().quit(0 if failures.is_empty() else 1)
