# PROTOTYPE HARNESS — infinite-world streaming gate (docs/tech/29 §5). Boots the
# real streamer with a fixed seed, then teleports a player proxy EAST 8 chunks one
# step at a time, fully settling each step (dump worker done, apply queue drained),
# and asserts the §2/§4 contract:
#   (a) the 5x5 apron around the player loads,
#   (b) chunks that fell out of range unload — the window stays bounded,
#   (c) darkness statics never leak (every static maps to a live chunk handle),
#   (d) per-chunk prop/water nodes are freed with their chunk,
#   (e) the walkability fence holds beyond the loaded window,
#   (f) no single main-thread apply step exceeds 4 ms (budget target 2).
# Ends "STREAMTEST OK" (+ worst apply-step ms) or "STREAMTEST FAIL: ...". Joins
# boot x2 / click_test / fx_stress as a standing headless gate. Run:
#   godot --headless --path game res://prototype/tests/stream_test.tscn
extends Node2D

const CHUNK := 64
const TILE := 16
const STEPS := 8
const SETTLE_TIMEOUT_MS := 30000   # failsafe per step (headless streams fast; this is slack)

var world                          # ProtoWorld — the system under test
var darkness                       # world._darkness() resolves this off our "main" node

var _player: Node2D
var _phase := "init"               # init -> boot -> step -> verify -> done
var _step := 0
var _phase_start_ms := 0
var _baseline_statics := 0

func _ready() -> void:
	add_to_group("main")            # world (_darkness) + darkness (fx lookup) key off this
	ProtoFx.intensity = 1.0         # darkness reads it for shadow_casters; keep it defined
	seed(0xD8A9)                    # fixed hunt world -> reproducible gate
	_player = Node2D.new()
	_player.add_to_group("player")
	add_child(_player)
	var cam := Camera2D.new()       # darkness needs a live camera or it early-returns
	_player.add_child(cam)
	cam.make_current()
	world = load("res://prototype/world_gen.gd").new()
	world.add_to_group("world")
	add_child(world)                # runs the synchronous radius-2 boot inside _ready
	_player.global_position = world.spawn_point()
	darkness = load("res://prototype/darkness.gd").new()
	add_child(darkness)             # assembled AFTER world, exactly like main.gd
	if not world.can_stream():
		_fail("dh-server binary missing — the streaming gate cannot run")
		return
	_enter("boot")

func _process(_dt: float) -> void:
	if _phase == "done" or _phase == "init":
		return
	var elapsed := Time.get_ticks_msec() - _phase_start_ms
	match _phase:
		"boot":
			# let the boot 5x5 + deferred shroom/SDF work settle before baselining
			if elapsed > 500 and _settled():
				_baseline_statics = darkness._statics.size()
				print("[stream_test] boot: chunks=%d statics=%d bounds=%s" % [
						world.chunks.size(), _baseline_statics, str(world.loaded_bounds())])
				_step = 1
				_teleport(_step)
				_enter("step")
		"step":
			if _settled() and world.chunks.has(Vector2i(_step, 0)):
				if _step >= STEPS:
					_enter("verify")
				else:
					_step += 1
					_teleport(_step)
					_phase_start_ms = Time.get_ticks_msec()
			elif elapsed > SETTLE_TIMEOUT_MS:
				_fail("step %d stalled (chunks=%d inflight=%s jobs=%d applying=%s)" % [
						_step, world.chunks.size(), str(world._req_inflight),
						world._jobs.size(), str(world._apply_active)])
		"verify":
			if elapsed > 150:   # a couple frames so queue_free reaps unloaded nodes
				_run_asserts()

# Fully quiescent: no dump in flight, apply queue drained, no chunk mid-apply.
func _settled() -> bool:
	return not world._req_inflight and world._jobs.is_empty() and not world._apply_active

func _teleport(step: int) -> void:
	_player.global_position = Vector2((step * CHUNK + CHUNK / 2) * TILE, (CHUNK / 2) * TILE)
	_phase_start_ms = Time.get_ticks_msec()

func _run_asserts() -> void:
	var pc := Vector2i(STEPS, 0)
	var fails: Array[String] = []

	# (a) the 5x5 apron around the player's chunk is loaded
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var k := pc + Vector2i(dx, dy)
			if not world.chunks.has(k):
				fails.append("missing apron chunk %s" % str(k))

	# (b) chunks fell out of range; the window is bounded (no unbounded growth)
	if world.chunks.has(Vector2i(0, 0)):
		fails.append("origin chunk (0,0) still loaded after an 8-chunk sprint")
	if world.chunks.size() > 49:
		fails.append("window unbounded: %d chunks loaded (max 7x7=49)" % world.chunks.size())

	# (c) darkness statics: no leak — every static maps to a live chunk's handle
	var live_handles := 0
	for k in world._shroom_handles:
		if not world.chunks.has(k):
			fails.append("orphan shroom-handle record %s" % str(k))
		live_handles += (world._shroom_handles[k] as Array).size()
	if darkness._statics.size() != live_handles:
		fails.append("static leak: %d statics vs %d live handles" % [
				darkness._statics.size(), live_handles])

	# (d) per-chunk prop/water nodes freed with their chunk
	for k in world._props:
		if not world.chunks.has(k):
			fails.append("orphan props container %s" % str(k))
	for k in world._water:
		if not world.chunks.has(k):
			fails.append("orphan water MMI %s" % str(k))
	if world.get_node_or_null(NodePath("Props_0_0")) != null:
		fails.append("Props_0_0 not freed on unload")
	if world.get_node_or_null(NodePath("Water_0_0")) != null:
		fails.append("Water_0_0 not freed on unload")

	# Lair annotations have exactly the loaded tile-data lifetime, including
	# empty lists; unloading terrain must not retain orphan doorway metadata.
	if world.entrances.size() != world.chunks.size():
		fails.append("lair metadata count differs from loaded chunks")
	for key in world.entrances:
		if not world.chunks.has(key): fails.append("orphan lair metadata %s" % str(key))

	# (e) walkability fence holds beyond the loaded window, opens inside it
	var far := Vector2((20 * CHUNK + CHUNK / 2) * TILE, (CHUNK / 2) * TILE)
	if world.is_walkable(far):
		fails.append("fence breach: unloaded space at chunk (20,0) is walkable")
	if not _loaded_has_walkable(pc):
		fails.append("no walkable tile in the loaded window (fence stuck closed)")

	# (f) main-thread apply-step budget (worst over the whole sprint)
	var worst: float = world._worst_apply_ms
	if worst > 4.0:
		fails.append("apply step %.2f ms exceeds the 4 ms hard budget" % worst)

	print("[stream_test] final: chunks=%d statics=%d props=%d water=%d worst_apply=%.2fms" % [
			world.chunks.size(), darkness._statics.size(), world._props.size(),
			world._water.size(), worst])
	if fails.is_empty():
		print("STREAMTEST OK  worst_apply=%.2fms (budget 2ms / hard 4ms)  window=%d chunks" % [
				worst, world.chunks.size()])
		_quit_clean(0)
	else:
		for f in fails:
			print("STREAMTEST FAIL: ", f)
		_quit_clean(1)

func _loaded_has_walkable(pc: Vector2i) -> bool:
	for i in CHUNK * CHUNK:
		@warning_ignore("integer_division")
		var p := Vector2((pc.x * CHUNK + (i % CHUNK) + 0.5) * TILE,
				(pc.y * CHUNK + (i / CHUNK) + 0.5) * TILE)
		if world.is_walkable(p):
			return true
	return false

func _enter(p: String) -> void:
	_phase = p
	_phase_start_ms = Time.get_ticks_msec()

func _fail(msg: String) -> void:
	print("STREAMTEST FAIL: ", msg)
	_quit_clean(1)

func _quit_clean(code: int) -> void:
	_phase = "done"
	get_tree().quit(code)   # world._exit_tree joins its worker threads — no leaks
