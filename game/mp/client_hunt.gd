# MP — the co-op CLIENT view (docs/tech/33). Renders the host's hunt: builds
# the SAME world locally from the lobby seed (dh-procgen determinism — the
# terrain never crosses the wire), renders 20 Hz entity snapshots as smoothed
# puppets, and sends this peer's inputs upstream at 30 Hz. Zero gameplay rules
# here — the host simulates everything; this scene is a view + input device.
extends Node2D

const SEND_HZ := 30.0
const BOLT_POOL := 40
const FIELD_COLORS := {
	"fire": Color(1.0, 0.55, 0.2, 0.35), "earth": Color(0.75, 0.6, 0.35, 0.3),
	"mire": Color(0.35, 0.8, 0.5, 0.35), "lava": Color(1.0, 0.3, 0.1, 0.45),
}
const BOLT_COLORS := [Color("ff7a33"), Color("9a6cff"), Color("7fd8ff"),
	Color("b48cff"), Color("cdd6dd"), Color("a8845a")]

var _world: ProtoWorld
var _cam: Camera2D
var _my_id := 0
var _puppets := {}            # id -> MpPuppet (player ids are peer ids)
var _manifest := {}           # creature id -> spawn manifest row
var _stale := {}              # creature id -> true (missing from last snapshot)
var _bolts: Array = []
var _fields_layer: Node2D
var _fields: Array = []
var _send_t := 0.0
var _edges := {}
var _hp_fill: ColorRect
var _pips: Array = []
var _party: Label
var _toast: Label
var _toast_t := 0.0
var _my_hp := 1.0
var _my_dc := 3

func _ready() -> void:
	ProtoTheme.apply_doctrine()
	y_sort_enabled = true
	_my_id = multiplayer.get_unique_id()
	var payload: Dictionary = MpNet.game_payload
	_world = ProtoWorld.new()
	_world.add_to_group("world")
	_world.forced_seed = int(payload.get("seed", 0))
	add_child(_world)
	for peer_id in payload.get("players", {}):
		_ensure_player(int(peer_id), payload.players[peer_id])
	_cam = Camera2D.new()
	_cam.position_smoothing_enabled = true
	_cam.position_smoothing_speed = 8.0
	add_child(_cam)
	_cam.make_current()
	_fields_layer = Node2D.new()
	_fields_layer.z_index = -5
	_fields_layer.draw.connect(_on_fields_draw)
	add_child(_fields_layer)
	for i in BOLT_POOL:   # pooled bolt dots — no per-snapshot allocation
		var b := Node2D.new()
		b.set_script(preload("res://mp/bolt.gd"))
		b.visible = false
		add_child(b)
		_bolts.append(b)
	_build_hud()
	MpNet.snapshot_received.connect(_on_snapshot)
	MpNet.event_received.connect(_on_event)
	MpNet.server_closed.connect(_on_server_closed)

func _ensure_player(id: int, info: Dictionary) -> MpPuppet:
	if _puppets.has(id):
		return _puppets[id]
	var p := MpPuppet.make_player(str(info.get("name", "Hunter")),
			str(info.get("class_id", "core.class.reaver")))
	add_child(p)
	_puppets[id] = p
	if id == _my_id:
		p.add_to_group("player")   # ProtoWorld streams around this focus
	return p

# ---- snapshots ------------------------------------------------------------------

func _on_snapshot(snap: Dictionary) -> void:
	for id in snap.get("sp", {}):
		_manifest[int(id)] = snap.sp[id]
	for row in snap.get("pl", []):
		var id := int(row[0])
		var p: MpPuppet = _puppets.get(id)
		if p == null:
			p = _ensure_player(id, MpNet.players.get(id, {}))
		p.apply_row(Vector2(row[1], row[2]), float(row[3]) / maxf(float(row[4]), 1.0),
				str(row[6]))
		p.sprite.flip_h = bool(row[7])
		if id == _my_id:
			_my_hp = float(row[3]) / maxf(float(row[4]), 1.0)
			_my_dc = int(row[5])
	var seen := {}
	for row in snap.get("cr", []):
		var id := int(row[0])
		seen[id] = true
		var p: MpPuppet = _puppets.get(id)
		if p == null:
			p = MpPuppet.make_creature(_manifest.get(id, {}))
			add_child(p)
			_puppets[id] = p
		p.apply_row(Vector2(row[1], row[2]), float(row[3]), str(row[4]))
	for id in _puppets.keys():
		if id > 100 and not seen.has(id):   # creature ids are instance ids (big)
			_stale[id] = true
	# bolts: refill the pool from the snapshot
	var bi := 0
	for row in snap.get("pj", []):
		if bi >= _bolts.size():
			break
		_bolts[bi].visible = true
		_bolts[bi].global_position = Vector2(row[0], row[1])
		_bolts[bi].col = BOLT_COLORS[clampi(int(row[2]), 0, BOLT_COLORS.size() - 1)]
		_bolts[bi].queue_redraw()
		bi += 1
	for i in range(bi, _bolts.size()):
		_bolts[i].visible = false
	_fields = snap.get("fd", [])
	_fields_layer.queue_redraw()
	_refresh_hud()

func _on_event(ev: Dictionary) -> void:
	if str(ev.get("k", "")) == "toast":
		_toast.text = str(ev.get("text", ""))
		_toast_t = 3.0
		_toast.modulate.a = 1.0

func _on_server_closed() -> void:
	_toast.text = "Host closed the hunt"
	_toast_t = 3.0
	_toast.modulate.a = 1.0
	await get_tree().create_timer(2.0).timeout
	MpNet.leave()
	get_tree().change_scene_to_file("res://mp/lobby.tscn")

# ---- inputs ------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.is_action_pressed("dodge"):
			_edges["d"] = true
		elif event.is_action_pressed("skill2"):
			_edges["e"] = true
		elif event.is_action_pressed("bestial"):
			_edges["q"] = true
		else:
			for i in 4:
				if event.is_action_pressed("slot%d" % (i + 1)):
					_edges["s%d" % i] = true

func _physics_process(delta: float) -> void:
	_send_t += delta
	if _send_t >= 1.0 / SEND_HZ:
		_send_t = 0.0
		var m := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		var aim := get_global_mouse_position()
		var pkt := {"m": [snappedf(m.x, 0.01), snappedf(m.y, 0.01)],
				"aim": [snappedf(aim.x, 0.1), snappedf(aim.y, 0.1)],
				"atk": Input.is_action_pressed("attack")}
		for k in _edges:
			pkt[k] = true
		_edges.clear()
		MpNet.send_input(pkt)
	# camera + stale puppets
	var me: MpPuppet = _puppets.get(_my_id)
	if me != null:
		_cam.global_position = me.global_position
	for id in _stale.keys():
		var p: MpPuppet = _puppets.get(id)
		if p == null or p.mark_stale(delta):
			if p != null:
				p.queue_free()
			_puppets.erase(id)
			_stale.erase(id)
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t <= 0.0:
			_toast.modulate.a = 0.0

# ---- HUD ----------------------------------------------------------------------------

func _build_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 10
	add_child(canvas)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.55)
	bg.position = Vector2(8, 8)
	bg.size = Vector2(184, 14)
	canvas.add_child(bg)
	_hp_fill = ColorRect.new()
	_hp_fill.color = Color("58c470")
	_hp_fill.position = Vector2(2, 2)
	_hp_fill.size = Vector2(180, 10)
	bg.add_child(_hp_fill)
	for i in 3:
		var pip := ColorRect.new()
		pip.color = Color("6fd3ff")
		pip.position = Vector2(10 + i * 14, 26)
		pip.size = Vector2(10, 5)
		canvas.add_child(pip)
		_pips.append(pip)
	_party = Label.new()
	_party.position = Vector2(8, 36)
	_party.add_theme_font_size_override("font_size", 8)
	canvas.add_child(_party)
	_toast = Label.new()
	_toast.position = Vector2(180, 8)
	_toast.add_theme_font_size_override("font_size", 8)
	_toast.modulate = Color("ffd166")
	canvas.add_child(_toast)
	var hint := Label.new()
	hint.text = "co-op view — WASD move · LMB/Space attack · Shift dodge · E Q 1-4 skills"
	hint.position = Vector2(8, 344)
	hint.add_theme_font_size_override("font_size", 8)
	hint.modulate = Color(1, 1, 1, 0.45)
	canvas.add_child(hint)

func _refresh_hud() -> void:
	_hp_fill.size.x = 180.0 * clampf(_my_hp, 0, 1)
	_hp_fill.color = Color("58c470") if _my_hp > 0.3 else Color("d84f4f")
	for i in 3:
		_pips[i].color = Color("6fd3ff") if i < _my_dc else Color(1, 1, 1, 0.2)
	var lines: Array = []
	for id in _puppets:
		var p: MpPuppet = _puppets[id]
		if p.is_player_puppet:
			lines.append("%s  %d%%" % [p._label.text, int(p.hp_frac * 100.0)])
	_party.text = "\n".join(lines)

func _on_fields_draw() -> void:
	for row in _fields:
		var col: Color = FIELD_COLORS.get(str(row[3]), FIELD_COLORS["fire"])
		_fields_layer.draw_circle(Vector2(row[0], row[1]), float(row[2]), col)
		_fields_layer.draw_arc(Vector2(row[0], row[1]), float(row[2]), 0, TAU, 32,
				col.lightened(0.4), 1.5)
