# FLASK PROBE — the Ember Flask as a gate (roadmap 1; design/11 "dodge, heal,
# or reverse"). Boots the hunt, wounds the hunter, drinks (R path), asserts the
# HoT heals and a charge is spent, then feeds 6 kills and asserts a charge
# rekindles.   godot --headless --path game res://prototype/tests/flask_probe.tscn
extends Node

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var hunt := preload("res://prototype/main.tscn").instantiate()
	add_child(hunt)
	var waited := 0.0
	while waited < 60.0 and hunt.player == null:
		await get_tree().create_timer(0.5).timeout
		waited += 0.5
	if hunt.player == null:
		_verdict(false, "hunt never booted")
		return
	var p = hunt.player
	# wound, then drink: heal-over-time must tick HP up and spend a charge
	p.hp = p.max_hp * 0.4
	if not p.drink_flask():
		_verdict(false, "drink_flask refused with charges and a wounded hunter")
		return
	if p.flask_charges != ProtoPlayer.FLASK_MAX - 1:
		_verdict(false, "charge not spent (charges=%d)" % p.flask_charges)
		return
	var hp0: float = p.hp
	for i in 150:   # ~2.5 s of physics at 60 Hz
		await get_tree().physics_frame
	if p.hp <= hp0 + p.max_hp * 0.2:
		_verdict(false, "flask HoT did not heal (%.0f -> %.0f)" % [hp0, p.hp])
		return
	# kill-feed: 6 kills rekindle one charge
	var rekindled := false
	for i in ProtoPlayer.FLASK_KILLS_PER_CHARGE:
		rekindled = p.note_kill() or rekindled
	if not rekindled or p.flask_charges != ProtoPlayer.FLASK_MAX:
		_verdict(false, "kill-feed did not rekindle (charges=%d)" % p.flask_charges)
		return
	# empty flask refuses; haven refill restores
	p.hp = p.max_hp * 0.5
	p.flask_charges = 0
	if p.drink_flask():
		_verdict(false, "empty flask still poured")
		return
	p.refill_flask()
	if p.flask_charges != ProtoPlayer.FLASK_MAX:
		_verdict(false, "refill did not restore charges")
		return
	_verdict(true, "drink heals 40%% over 2s, charge spent, 6 kills rekindle, empty refuses, haven refills")

func _verdict(ok: bool, msg: String) -> void:
	if ok:
		print("FLASK OK — ", msg)
	else:
		push_error("FLASK FAIL — " + msg)
	get_tree().quit(0 if ok else 1)
