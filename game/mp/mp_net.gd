# MP — P2P co-op transport + lobby state (docs/tech/33). PROTOTYPE-GRADE by
# design: one friend hosts, up to 3 more join by IP (ENet, party cap 1-4 per
# canon §4). The HOST is authoritative — it runs the one real hunt; clients
# send inputs and render snapshots. The shipping path (Nakama matchmaking +
# zone servers, design/21) replaces discovery and authority; this layer stays
# the LAN/friends fallback. No NAT traversal: same-LAN, port-forward, or a
# VPN-style overlay (Tailscale etc.) for internet play with friends.
extends Node

signal lobby_changed
signal game_started(payload: Dictionary)
signal connection_failed(reason: String)
signal server_closed
# in-game transport (host_driver / client_hunt consume these)
signal input_received(peer_id: int, pkt: Dictionary)
signal snapshot_received(snap: Dictionary)
signal event_received(ev: Dictionary)

const DEFAULT_PORT := 7377
const MAX_CLIENTS := 3            # host + 3 = party of 4 (canon §4)

var is_host := false
var in_game := false
var pending_seed := 0             # lobby-chosen hunt seed (world_gen forced_seed)
var game_payload := {}            # last _rpc_start payload (clients read at boot)
var players := {}                 # peer_id -> {name, class_id, ready}
var local_info := {"name": "Hunter", "class_id": "core.class.reaver"}

# ---- lobby --------------------------------------------------------------------

func host_game(port := DEFAULT_PORT) -> bool:
	leave()
	var peer := ENetMultiplayerPeer.new()
	if peer.create_server(port, MAX_CLIENTS) != OK:
		return false
	multiplayer.multiplayer_peer = peer
	is_host = true
	players[1] = local_info.duplicate()
	players[1].ready = true
	multiplayer.peer_connected.connect(_on_peer_changed)
	multiplayer.peer_disconnected.connect(_on_peer_changed)
	return true

func join_game(ip: String, port := DEFAULT_PORT) -> bool:
	leave()
	var peer := ENetMultiplayerPeer.new()
	if peer.create_client(ip, port) != OK:
		return false
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(
			func() -> void: connection_failed.emit("could not reach host"))
	multiplayer.server_disconnected.connect(
			func() -> void: server_closed.emit())
	return true

func leave() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	is_host = false
	in_game = false
	pending_seed = 0
	game_payload = {}
	players.clear()

func set_ready(r: bool) -> void:
	if is_host:
		players[1].ready = r
		_lobby_sync()
	else:
		rpc_id(1, "_rpc_ready", r)

# Host: pick the seed, tell everyone, load the hunt (lobby listens to the signal).
func start_game() -> void:
	if not is_host:
		return
	if pending_seed == 0:   # a caller may pre-seed (tests, rematches)
		pending_seed = randi()
	var payload := {"seed": pending_seed, "players": players.duplicate(true)}
	rpc("_rpc_start", payload)   # call_local delivers on the host too

func _on_connected() -> void:
	rpc_id(1, "_rpc_register", local_info)

func _on_peer_changed(_id: int) -> void:
	if is_host:
		_lobby_sync()

func _lobby_sync() -> void:
	rpc("_rpc_lobby", players)   # call_local delivers on the host too

@rpc("any_peer", "reliable")
func _rpc_register(info: Dictionary) -> void:
	if not is_host:
		return
	var sender := multiplayer.get_remote_sender_id()
	players[sender] = info
	players[sender].ready = false
	_lobby_sync()

@rpc("any_peer", "reliable")
func _rpc_ready(r: bool) -> void:
	if not is_host:
		return
	players[multiplayer.get_remote_sender_id()].ready = r
	_lobby_sync()

@rpc("authority", "reliable", "call_local")
func _rpc_lobby(synced: Dictionary) -> void:
	players = synced.duplicate(true)
	lobby_changed.emit()

@rpc("authority", "reliable", "call_local")
func _rpc_start(payload: Dictionary) -> void:
	in_game = true
	pending_seed = int(payload.get("seed", 0))
	game_payload = payload
	game_started.emit(payload)

# ---- in-game transport ------------------------------------------------------------

func _connected() -> bool:
	return multiplayer.multiplayer_peer != null and \
			multiplayer.multiplayer_peer.get_connection_status() == \
			MultiplayerPeer.CONNECTION_CONNECTED

func send_input(pkt: Dictionary) -> void:
	if not is_host and in_game and _connected():
		rpc_id(1, "_rpc_input", pkt)

func send_snapshot(snap: Dictionary) -> void:
	if is_host and in_game and _connected():
		rpc("_rpc_snapshot", snap)

func send_event(ev: Dictionary) -> void:
	if is_host and in_game and _connected():
		rpc("_rpc_event", ev)

@rpc("any_peer", "unreliable")
func _rpc_input(pkt: Dictionary) -> void:
	if is_host:
		input_received.emit(multiplayer.get_remote_sender_id(), pkt)

@rpc("authority", "unreliable")
func _rpc_snapshot(snap: Dictionary) -> void:
	if not is_host:
		snapshot_received.emit(snap)

@rpc("authority", "reliable")
func _rpc_event(ev: Dictionary) -> void:
	if not is_host:
		event_received.emit(ev)
