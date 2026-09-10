# MP — the P2P lobby (docs/tech/33). HOST: pick name/class, share your LAN IP,
# friends JOIN with it, everyone readies, the host STARTS the hunt. Internet
# play needs port-forward or an overlay (Tailscale etc.) — Nakama matchmaking
# replaces discovery later (design/21); this is the friends-and-LAN path.
extends Node2D

const CLASSES := {
	"core.class.reaver": "Reaver", "core.class.emberkin": "Emberkin",
	"core.class.frostbinder": "Frostbinder", "core.class.mage": "Gloam Mage",
	"core.class.rogue": "Veilblade",
}

var _name: LineEdit
var _class: OptionButton
var _ip: LineEdit
var _port: LineEdit
var _list: Label
var _status: Label
var _start_btn: Button
var _ready_btn: Button

func _ready() -> void:
	ProtoTheme.apply_doctrine()
	_build_ui()
	MpNet.lobby_changed.connect(_refresh)
	MpNet.game_started.connect(_on_start)
	MpNet.connection_failed.connect(func(r: String) -> void: _status.text = r)
	_name.text = str(Session.player_name) if Session.player_name != "" else "Hunter"

func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.position = Vector2(200, 60)
	root.custom_minimum_size = Vector2(240, 0)
	root.add_theme_constant_override("separation", 6)
	add_child(root)
	var title := Label.new()
	title.text = "CO-OP HUNT (P2P)"
	root.add_child(title)
	root.add_child(_row("Name", _name_edit()))
	root.add_child(_row("Class", _class_picker()))
	root.add_child(_row("Host IP", _ip_edit()))
	root.add_child(_row("Port", _port_edit()))
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 6)
	root.add_child(btns)
	var host_btn := Button.new()
	host_btn.text = "HOST"
	host_btn.pressed.connect(_on_host)
	btns.add_child(host_btn)
	var join_btn := Button.new()
	join_btn.text = "JOIN"
	join_btn.pressed.connect(_on_join)
	btns.add_child(join_btn)
	_ready_btn = Button.new()
	_ready_btn.text = "READY"
	_ready_btn.disabled = true
	_ready_btn.pressed.connect(func() -> void: MpNet.set_ready(true))
	btns.add_child(_ready_btn)
	_start_btn = Button.new()
	_start_btn.text = "START HUNT"
	_start_btn.disabled = true
	_start_btn.pressed.connect(func() -> void: MpNet.start_game())
	root.add_child(_start_btn)
	_list = Label.new()
	root.add_child(_list)
	_status = Label.new()
	_status.modulate = Color("ffd166")
	root.add_child(_status)
	var back := Button.new()
	back.text = "< MENU"
	back.pressed.connect(func() -> void:
		MpNet.leave()
		get_tree().change_scene_to_file("res://prototype/ui/main_menu.tscn"))
	root.add_child(back)

func _row(label_text: String, field: Control) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var l := Label.new()
	l.text = label_text
	l.custom_minimum_size = Vector2(56, 0)
	h.add_child(l)
	h.add_child(field)
	return h

func _name_edit() -> LineEdit:
	_name = LineEdit.new()
	_name.custom_minimum_size = Vector2(140, 0)
	_name.max_length = 16
	_name.text_changed.connect(func(t: String) -> void: MpNet.local_info.name = t)
	return _name

func _class_picker() -> OptionButton:
	_class = OptionButton.new()
	for cid in CLASSES:
		_class.add_item(CLASSES[cid])
	_class.item_selected.connect(func(i: int) -> void:
		MpNet.local_info.class_id = CLASSES.keys()[i])
	return _class

func _ip_edit() -> LineEdit:
	_ip = LineEdit.new()
	_ip.custom_minimum_size = Vector2(140, 0)
	_ip.placeholder_text = "192.168.x.x (host leaves blank)"
	return _ip

func _port_edit() -> LineEdit:
	_port = LineEdit.new()
	_port.custom_minimum_size = Vector2(70, 0)
	_port.text = str(MpNet.DEFAULT_PORT)
	return _port

func _on_host() -> void:
	if MpNet.host_game(int(_port.text)):
		_status.text = "Hosting — friends join your LAN IP below:"
		_status.text += "\n" + "\n".join(_local_ips())
		_ready_btn.disabled = false
		_start_btn.disabled = false
	else:
		_status.text = "Could not host on port " + _port.text

func _on_join() -> void:
	if _ip.text.is_empty():
		_status.text = "Enter the host's IP first."
		return
	if MpNet.join_game(_ip.text.strip_edges(), int(_port.text)):
		_status.text = "Connecting…"
		_ready_btn.disabled = false
	else:
		_status.text = "Could not start client."

func _local_ips() -> Array:
	var out: Array = []
	for addr in IP.get_local_addresses():
		if addr.count(".") == 3 and not addr.begins_with("127."):
			out.append(addr)
	return out

func _refresh() -> void:
	var lines: Array = []
	for id in MpNet.players:
		var p: Dictionary = MpNet.players[id]
		lines.append("%s  %-12s  %s%s" % [
				"HOST" if id == 1 else "ally",
				str(p.get("name", "?")),
				CLASSES.get(str(p.get("class_id", "")), "?"),
				"  ✓" if bool(p.get("ready", false)) else ""])
	_list.text = "\n".join(lines)

func _on_start(_payload: Dictionary) -> void:
	if MpNet.is_host:
		get_tree().change_scene_to_file("res://prototype/main.tscn")
	else:
		get_tree().change_scene_to_file("res://mp/client_hunt.tscn")
