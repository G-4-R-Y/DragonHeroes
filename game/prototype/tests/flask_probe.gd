## Ember Flask outcome gate: actual R and mouse input, exact healing and recharge.
extends Node

var failures: Array[String] = []
var hunt: Node
var p: ProtoPlayer

func check(ok: bool, why: String) -> void:
	if not ok: failures.append(why)

func frames(n: int = 2) -> void:
	for i in n: await get_tree().process_frame

# R57's trap: headless process frames outrun the fixed 60 Hz physics clock, so
# anything asserted on a `_physics_process` effect (the flask burn, the HUD
# gauge pass) must wait on `physics_frame` or it is a coin flip.
func physics_frames(n: int = 2) -> void:
	for i in n: await get_tree().physics_frame

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
	# ---- R58: the drip must be VISIBLE, not merely correct ------------------
	# Everything above drives `_process_flask()` by hand with physics disabled,
	# which is exactly why this gate stayed green while Ricardo watched an
	# "instant top-up": `refresh_hud()` is event-driven, so during the 2 s burn
	# the bar sat frozen and the text lied (measured: hp 50 -> 70, bar stuck at
	# 90.00 px, text stuck on "50 / 100 HP" for the whole burn AND after it).
	# So this section runs the real clock and watches the HUD, not the model.
	p.dead = false
	p.refill_flask()
	p.hp = p.max_hp * 0.3
	hunt.refresh_hud()
	hunt.set_physics_process(true)
	p.set_physics_process(true)
	for creature in get_tree().get_nodes_in_group("creatures"): creature.queue_free()
	hunt._use_flask()
	await physics_frames(2)
	var mid_bar: float = hunt._hud.hp_bar.size.x
	var mid_hp: float = p.hp
	var mid_text: String = hunt._hud.hp_text.text
	check(p._flask_hot > 0.0, "the burn ended before the live sample")
	await physics_frames(30)   # ~0.5 s of real 60 Hz ticks, mid-burn
	check(p.hp > mid_hp, "the heal-over-time did not tick on the real clock")
	check(hunt._hud.hp_bar.size.x > mid_bar,
		"the HP bar did not move while the flask was healing")
	# Movement, not equality: the player's `_physics_process` (which burns the
	# flask) and main's (which draws the gauge) are one node apart, so the text
	# trails the model by at most a single 16 ms tick. Exactness is asserted
	# below, once the burn has ended and HP has stopped moving.
	check(hunt._hud.hp_text.text != mid_text,
		"the HP text went stale during the heal-over-time")
	var drips := 0
	while p._flask_hot > 0.0 and drips < 240:
		await physics_frames(1)
		drips += 1
	await physics_frames(2)
	check(is_equal_approx(hunt._hud.hp_bar.size.x, 180.0 * p.hp / p.max_hp),
		"the HP bar did not settle on the healed total")
	check(hunt._hud.hp_text.text == "%d / %d HP" % [ceili(p.hp), ceili(p.max_hp)],
		"the HP text did not settle on the healed total")
	check(is_equal_approx(p.hp, p.max_hp * 0.7), "the live burn did not deliver 20% + 20%")
	hunt.set_physics_process(false)
	p.set_physics_process(false)

	for why in failures: push_error("FLASK FAIL: " + why)
	if failures.is_empty(): print("FLASK OK — real R/click, 20% now + 20% over 2s on the real clock, the bar and text follow the drip, exact budget, recharge never heals, full/empty/dead feedback")
	hunt.queue_free()
	await frames(3)
	get_tree().quit(0 if failures.is_empty() else 1)
