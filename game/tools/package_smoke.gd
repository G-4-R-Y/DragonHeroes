# Explicit outcome probe for exported Codex review packages. Release templates
# disable external --script overrides; this runs only with -- --codex-smoke.
extends Node

func _ready() -> void:
	if "--codex-smoke" in OS.get_cmdline_user_args():
		call_deferred("_run")

func _verdict(ok: bool, detail: String) -> bool:
	var file := FileAccess.open("user://package-smoke.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"passed": ok, "detail": detail}))
		file.close()
	print(("PACKAGE SMOKE OK: " if ok else "PACKAGE SMOKE FAIL: ") + detail)
	get_tree().quit(0 if ok else 1)
	return ok

func _run() -> void:
	var tree := get_tree()
	for frame in range(20):
		await tree.process_frame
	if OS.get_user_data_dir().get_file() != "Dragon Heroes Codex":
		_verdict(false, "save isolation")
		return
	var icon: Texture2D = load("res://branding/dragon-heroes.png")
	if icon == null or icon.get_width() != 512 or not FileAccess.file_exists("res://branding/dragon-heroes.ico"):
		_verdict(false, "packaged application icons")
		return
	var menu: Node = tree.current_scene
	var texts := ""
	for button in menu.find_children("*", "Button", true, false):
		texts += " " + str(button.text).to_upper()
	if not ("ENTER" in texts and "CO-OP" in texts and "OPTIONS" in texts):
		_verdict(false, "menu did not finish building")
		return
	if tree.change_scene_to_file("res://prototype/main.tscn") != OK:
		_verdict(false, "Hunt scene unavailable")
		return
	await tree.create_timer(8.0).timeout
	var player: Node = tree.get_first_node_in_group("player")
	var world: Node = tree.get_first_node_in_group("world")
	var creatures := tree.get_nodes_in_group("creatures")
	if player == null or world == null or creatures.size() < 20:
		_verdict(false, "Hunt did not populate")
		return
	if not bool(world.get("_streaming")):
		_verdict(false, "packaged C++ helper did not generate streaming world")
		return
	# Assert the sustain beat in the release PCK too, through a real death.
	# This explicit smoke mode runs in the packager's isolated user directory.
	var hunt: Node = tree.current_scene
	hunt.process_mode = Node.PROCESS_MODE_DISABLED
	player.respawn(player.global_position)
	player.hp = player.max_hp * 0.25
	player.dodge_charges = 0
	player.flask_charges = 0
	Session.level = 1
	hunt.kills = hunt._kills_for_level(1) - 1
	var prey := ProtoCreature.new()
	hunt.add_child(prey)
	prey.take_damage(prey.max_hp + 1.0, Vector2.ZERO)
	if Session.level != 2 or not is_equal_approx(player.hp, player.max_hp) \
			or player.dodge_charges != ProtoPlayer.DODGE_CHARGES_MAX or player.flask_charges != ProtoPlayer.FLASK_MAX:
		_verdict(false, "exported Hunt level-up did not refill HP/dodges/flasks")
		return
	# Exercise input from the real exported PCK, not a direct drink() call.
	# The scene has to PROCESS again first: R reaches the flask through
	# main.gd::_unhandled_input, and a PROCESS_MODE_DISABLED node receives no
	# input callbacks at all, so the press above would land nowhere and this
	# gate would fail a working flask. (Measured headless: INHERIT delivers
	# _unhandled_input, DISABLED does not.) The world still holds still --
	# physics is switched off per node on the next three lines, which is what
	# the blanket disable was really for.
	hunt.process_mode = Node.PROCESS_MODE_INHERIT
	player.set_physics_process(false)
	hunt.set_physics_process(false)
	for creature in tree.get_nodes_in_group("creatures"): creature.set_physics_process(false)
	player.hp = player.max_hp * 0.4
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_R
		event.physical_keycode = KEY_R
		event.pressed = pressed
		Input.parse_input_event(event)
	for frame in 3: await tree.process_frame
	if player.flask_charges != 1 or not is_equal_approx(player.hp, player.max_hp * 0.6):
		_verdict(false, "exported R press did not heal immediately")
		return
	player._process_flask(5.0)
	if not is_equal_approx(player.hp, player.max_hp * 0.8):
		_verdict(false, "exported Flask exceeded its total healing budget")
		return
	for i in 6: player.note_kill()
	if player.flask_charges != 2 or not is_equal_approx(player.hp, player.max_hp * 0.8):
		_verdict(false, "exported recharge changed HP or lost its charge")
		return
	_verdict(true, "exported menu/icons/isolated saves, streaming Hunt, level-up refill, real R immediate heal, exact Flask total and recharge; creatures=%d" % creatures.size())
