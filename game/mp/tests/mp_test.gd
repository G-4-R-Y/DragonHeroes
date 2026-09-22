# MP — the co-op gate (docs/tech/33): TWO processes on loopback.
#   terminal A: godot --headless --path game res://mp/tests/mp_test.tscn -- --host
#   terminal B: godot --headless --path game res://mp/tests/mp_test.tscn -- --join
# (or tools/mp_test.sh, which runs both). Host asserts: client registered,
# hunt started on the lobby seed, the remote hunter SPAWNED and MOVED from
# client inputs. Client asserts: start payload arrived with the seed and
# snapshots flow. Each side prints MP HOST OK / MP CLIENT OK and quits 0.
extends Node2D

const TEST_PORT := 7391
const TEST_SEED := 1234
const TIMEOUT_S := 90.0

var _mode := ""
var _t := 0.0
var _done := false
var _hunt: Node2D = null
var _snaps := 0
var _send_t := 0.0
var _spawn_pos := {}
var _host_ok_t := 0.0
var _flask_sent := false
var _flask_seen := false

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a in ["--host", "--join"]:
			_mode = a
	if _mode == "":
		push_error("mp_test: pass -- --host or -- --join")
		get_tree().quit(1)
		return
	MpNet.local_info.name = "TestAlly"
	MpNet.local_info.class_id = "core.class.rogue"
	if _mode == "--host":
		MpNet.lobby_changed.connect(_on_lobby)
		MpNet.game_started.connect(_on_started)
		if not MpNet.host_game(TEST_PORT):
			push_error("mp_test: host_game failed")
			get_tree().quit(1)
	else:
		MpNet.game_started.connect(_on_client_started)
		MpNet.snapshot_received.connect(func(s: Dictionary) -> void:
			_snaps += 1
			for row in s.get("pl", []):
				if int(row[0]) == multiplayer.get_unique_id() and row.size() > 8:
					if int(row[8]) == 1 and float(row[3]) >= float(row[4]) * 0.59:
						_flask_seen = true)
		if not MpNet.join_game("127.0.0.1", TEST_PORT):
			push_error("mp_test: join_game failed")
			get_tree().quit(1)

func _on_lobby() -> void:
	if MpNet.players.size() >= 2:
		MpNet.pending_seed = TEST_SEED
		MpNet.start_game()

func _on_started(payload: Dictionary) -> void:
	if int(payload.get("seed", 0)) != TEST_SEED:
		_fail("host: wrong seed in payload")
		return
	_hunt = preload("res://prototype/main.tscn").instantiate()
	add_child(_hunt)   # main.gd reads MpNet.pending_seed + attaches host_driver
	for creature in get_tree().get_nodes_in_group("creatures"):
		creature.set_physics_process(false)   # isolate transport/healing from attacks

func _on_client_started(payload: Dictionary) -> void:
	if int(payload.get("seed", 0)) != TEST_SEED:
		_fail("client: wrong seed in payload")
		return
	print("MP CLIENT: payload ok (seed %d, %d players)" % [
			TEST_SEED, (payload.get("players", {}) as Dictionary).size()])

func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	if _t > TIMEOUT_S:
		_fail("timeout")
		return
	if _mode == "--join" and int(_t) % 5 == 0 and int(_t) != int(_t - delta):
		print("MP CLIENT: t=%d in_game=%s snaps=%d players=%d" % [
				int(_t), MpNet.in_game, _snaps, MpNet.players.size()])
	if _mode == "--join" and MpNet.in_game:
		_send_t += delta
		if _send_t >= 1.0 / 30.0:
			_send_t = 0.0
			MpNet.send_input({"m": [1.0, 0.0], "aim": [200.0, 0.0], "atk": false})
		if _snaps >= 3 and not _flask_sent:
			_flask_sent = true
			MpNet.request_flask()
		if _snaps >= 30 and _flask_seen:
			_done = true
			print("MP CLIENT OK — %d snapshots; host-owned Flask HP and charge received" % _snaps)
			get_tree().quit(0)
		return
	if _mode == "--host" and _hunt != null:
		var drv := get_tree().get_first_node_in_group("mp_host")
		if drv == null:
			return
		if _host_ok_t != 0.0:   # asserted — grace period so the client finishes
			if _t - _host_ok_t >= 3.0:
				_done = true
				get_tree().quit(0)
			return
		for peer_id in drv._remotes:
			var body: Node2D = drv._remotes[peer_id].body
			if not is_instance_valid(body):
				continue
			if not _spawn_pos.has(peer_id):
				_spawn_pos[peer_id] = body.global_position
				body.hp = body.max_hp * 0.4
			# the remote must MOVE from its spawn point — driven by client inputs
			if body.global_position.distance_to(_spawn_pos[peer_id]) > 30.0 \
					and body.flask_charges == 1 and body.hp >= body.max_hp * 0.59:
				_host_ok_t = _t
				print("MP HOST OK — remote hunter moved %s -> %s on client inputs" \
						% [str(_spawn_pos[peer_id].round()), str(body.global_position.round())])
				return

func _fail(why: String) -> void:
	_done = true
	push_error("MP TEST FAIL (%s): %s" % [_mode, why])
	get_tree().quit(1)
