## Ember Flask outcome gate: actual R and mouse input, exact healing and recharge.
extends Node

var failures: Array[String] = []
var hunt: Node
var p: ProtoPlayer

func check(ok: bool, why: String) -> void:
	if not ok: failures.append(why)

func frames(n: int = 2) -> void:
	for i in n: await get_tree().process_frame

func key(pressed: bool, echo := false) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_R
	event.physical_keycode = KEY_R
	event.pressed = pressed
	event.echo = echo
	Input.parse_input_event(event)

func click(button: Button) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = button.get_global_rect().get_center()
		event.global_position = event.position
		Input.parse_input_event(event)
	await frames()

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	ProtoLang.set_lang("en")
	Session.login("flask_probe")
	hunt = preload("res://prototype/main.tscn").instantiate()
	add_child(hunt)
	hunt.set_physics_process(false)
	hunt.world._streaming = false
	hunt.world.set_process(false)
	hunt._residency.set_process(false)
	p = hunt.player
	p.set_physics_process(false)
	for creature in get_tree().get_nodes_in_group("creatures"): creature.queue_free()
	await frames(3)
	p.refill_flask()
	p.hp = p.max_hp * 0.4
	key(true)
	key(false)
	await frames()
	check(p.flask_charges == 1, "R did not consume exactly one charge")
	check(is_equal_approx(p.hp, p.max_hp * 0.6), "R did not heal 20% immediately")
	key(true, true)
	key(false)
	await frames()
	check(p.flask_charges == 1, "key repeat consumed another charge")
	p._process_flask(0.75)
	check(is_equal_approx(p.hp, p.max_hp * 0.675), "incorrect healing rate")
	p._process_flask(50.0)
	check(is_equal_approx(p.hp, p.max_hp * 0.8), "large final tick exceeded 40% total")
	p._process_flask(50.0)
	check(is_equal_approx(p.hp, p.max_hp * 0.8), "completed flask healed again")

	p.refill_flask()
	p.hp = p.max_hp * 0.1
	var button: Button = hunt._hud.flask_button
	await click(button)
	check(p.flask_charges == 1 and is_equal_approx(p.hp, p.max_hp * 0.3),
		"visible bottle did not deliver its immediate heal")
	check(hunt._hud.hp_text.text == "%d / %d HP" % [ceili(p.hp), ceili(p.max_hp)],
		"HP display did not refresh with the bottle click")
	await click(button)
	check(p.flask_charges == 1, "second click spent a charge during healing")
	check(hunt._hud.hint.text == ProtoLang.t("msg_flask_healing"), "missing already-healing feedback")
	p._process_flask(-0.5)
	check(is_equal_approx(p.hp, p.max_hp * 0.3), "negative time changed HP")
	hunt.refresh_hud()
	hunt._update_gauges(0.0)
	if DisplayServer.get_name() != "headless":
		await frames(4)
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://prototype/tests/captures/flask")
		get_viewport().get_texture().get_image().save_png("res://prototype/tests/captures/flask/healing.png")
	p._process_flask(2.0)
	var hp := p.hp
	for i in ProtoPlayer.FLASK_KILLS_PER_CHARGE: p.note_kill()
	check(p.flask_charges == 2 and is_equal_approx(p.hp, hp), "recharge healed HP or failed to restore a charge")
	for i in 100: p.note_kill()
	check(p.flask_kills == 0, "full bottle banked an unbounded kill counter")

	p.flask_charges = 0
	await click(button)
	check(is_equal_approx(p.hp, hp) and hunt._hud.hint.text == ProtoLang.t("msg_flask_empty"),
		"empty bottle healed or gave no feedback")
	p.refill_flask()
	p.hp = p.max_hp
	await click(button)
	check(p.flask_charges == 2 and hunt._hud.hint.text == ProtoLang.t("msg_flask_full"),
		"full HP spent a charge or gave no feedback")
	p.hp = p.max_hp * 0.1
	p.dead = true
	await click(button)
	p._process_flask(2.0)
	check(p.flask_charges == 2 and is_equal_approx(p.hp, p.max_hp * 0.1), "Flask revived a dead hunter")
	for why in failures: push_error("FLASK FAIL: " + why)
	if failures.is_empty(): print("FLASK OK — real R/click, 20% now + 20% over 2s, exact budget, recharge never heals, full/empty/dead feedback")
	hunt.queue_free()
	await frames(3)
	get_tree().quit(0 if failures.is_empty() else 1)
