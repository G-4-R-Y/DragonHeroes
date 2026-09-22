# CUE PROBE — R64/R43 as a gate. R43's complaint was that cooldowns "require too
# much attention in fast combat"; R64 answers it with a PERIPHERAL cue (the fan
# at the hero's feet, player.gd::_draw_skill_cues) driven by the same edge that
# flashes the central HUD chip (ui/hud_chip.gd), so the eye never has to leave
# the fight — and never gets spammed for looking.
#
# Every assertion has teeth: reverting the matching R64 line makes exactly one
# of these fail.
#   (a) a hunt that STARTS ready does not bloom — spawning, learning or
#       assigning a ready skill is not a cooldown->ready transition,
#   (b) an unassigned slot carries no cue at all (no kind, no ready state, no
#       bloom) — four empty slots must not read as four ready ones,
#   (c) a real cast raises the burning cue to full and files the seconds the
#       fan and the chip both count down,
#   (d) the return fires EXACTLY one bloom, at value 1, decaying monotonically
#       to 0 within CUE_BLOOM_S and never rising again while the slot stays
#       ready — this is the "no false-ready/cue spam" criterion,
#   (e) a slot emptied mid-cooldown goes quiet instead of blooming,
#   (f) a press that the 150 ms input buffer cannot save answers with one deny
#       tick; a press INSIDE the buffer window does not (it will be honoured),
#   (g) the draw work is real and bounded: the fan lays down arcs while a cue
#       is live, and never more than 12,
#   (h) the grave clears every cue — nobody respawns to a bloom for a cast
#       they lost.
#   godot --headless --path game res://prototype/tests/cue_probe.tscn
extends Node

const SKILL := "rv_gash"          # Reaver, melee_arc, cd 4.0 — cd_scale is 1.0
const SLOT := 0
const OTHER := 1                  # deliberately left empty

var failures: Array[String] = []
var _hunt: Node
var _player: ProtoPlayer

func check(ok: bool, why: String) -> void:
	if not ok: failures.append(why)

# The cues live in player.gd::_physics_process, and headless PROCESS frames can
# contain zero physics ticks (the capture_probe flake) — everything is waited on
# the clock that actually does the work.
func physics_frames(n: int = 1) -> void:
	for i in n: await get_tree().physics_frame

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	ProtoLang.set_lang("en")
	Session.login("cue_probe")
	Session.class_id = "core.class.reaver"
	Session.skill_points = maxi(Session.skill_points, 2)
	Session.learn_node(SKILL, 1)
	Session.assign_skill(SLOT, SKILL)
	Session.skill_loadout[OTHER] = ""
	_hunt = preload("res://prototype/main.tscn").instantiate()
	add_child(_hunt)
	_hunt.world._streaming = false
	_hunt.world.set_process(false)
	_hunt._residency.set_process(false)
	var waited := 0.0
	while waited < 30.0 and _hunt.player == null:
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
	if _hunt.player == null:
		push_error("CUE FAIL: the hunt never produced a player")
		get_tree().quit(1)
		return
	_player = _hunt.player
	await physics_frames(4)

	_check_quiet_start()
	await _check_cast_and_return()
	await _check_emptied_slot()
	await _check_denied_press()
	await _check_grave()

	if failures.is_empty():
		print("CUE OK — one bloom per cooldown, silent on spawn/empty/grave, "
				+ "deny tick honours the %.2f s buffer, draw work <= 12 arcs"
				% ProtoPlayer.INPUT_BUFFER_S)
	else:
		for f in failures: push_error("CUE FAIL: " + f)
	get_tree().quit(0 if failures.is_empty() else 1)

# ---- helpers ----------------------------------------------------------------

func _def() -> Dictionary:
	return Session.skill_def(SKILL)

func _kind(i: int) -> String:
	return str(_player._cue_kind[i])

# ---- (a) a hunt that starts ready does not bloom -----------------------------
# ---- (b) an unassigned slot carries no cue at all ----------------------------

func _check_quiet_start() -> void:
	check(_player.skill_cd_left(SKILL) <= 0.0,
			"the hunt started with %s already burning" % SKILL)
	check(_player.skill_ready_flash(SLOT) <= 0.0,
			"a skill that was ready from the first frame bloomed anyway")
	check(_kind(SLOT) == str(_def().get("kind", "")),
			"the assigned slot carries kind '%s', not the skill's" % _kind(SLOT))
	check(_kind(OTHER) == "",
			"an unassigned slot carries kind '%s' — it would draw a cue" % _kind(OTHER))
	check(_player.skill_ready_flash(OTHER) <= 0.0,
			"an unassigned slot bloomed")
	check(not bool(_player._cue_ready[OTHER]),
			"an unassigned slot reads as READY — four empty slots would read as four")

# ---- (c) a cast raises the burning cue ---------------------------------------
# ---- (d) the return fires exactly one bloom ----------------------------------
# ---- (g) the draw work is real and bounded -----------------------------------

func _check_cast_and_return() -> void:
	var cd := float((_def().get("params", {}) as Dictionary).get("cd", 6.0)) * _player.cdr_mult
	check(_player.use_skill(_def()), "the probe could not cast %s" % SKILL)
	await physics_frames(1)
	check(float(_player._cue_frac[SLOT]) > 0.9,
			"a fresh cast left the cue at %.2f, not full" % float(_player._cue_frac[SLOT]))
	check(absf(float(_player._cue_left[SLOT]) - cd) < 0.2,
			"the cue counts %.2f s, the cooldown is %.2f s"
					% [float(_player._cue_left[SLOT]), cd])
	check(_player.skill_ready_flash(SLOT) <= 0.0, "the cue bloomed on the CAST")
	check(_player.cue_arcs > 0,
			"the fan drew nothing while a cooldown was burning")
	check(_player.cue_arcs <= 12,
			"the fan laid down %d arcs — the budget is 12" % _player.cue_arcs)
	# run the rest of the cooldown out in a handful of ticks, then watch the edge
	_player.skill_cds[SKILL] = 0.05
	var rises := 0
	var peak := 0.0
	var prev := _player.skill_ready_flash(SLOT)
	for i in 40:                       # 40 ticks > CUE_BLOOM_S at 60 Hz
		await physics_frames(1)
		var f: float = _player.skill_ready_flash(SLOT)
		if f > prev:                   # the bloom only ever rises ON the edge
			rises += 1
		peak = maxf(peak, f)
		prev = f
		check(_player.cue_arcs <= 12,
				"the fan laid down %d arcs on tick %d" % [_player.cue_arcs, i])
	check(rises == 1, "the cooldown->ready edge fired %d blooms, not 1" % rises)
	check(is_equal_approx(peak, 1.0), "the bloom peaked at %.2f, not 1" % peak)
	check(prev <= 0.0, "the bloom never ended — a ready slot keeps animating")
	check(bool(_player._cue_ready[SLOT]), "the slot never registered as ready")
	# and it stays quiet
	await physics_frames(10)
	check(_player.skill_ready_flash(SLOT) <= 0.0,
			"a slot that has been ready for 10 ticks bloomed again")

# ---- (e) a slot emptied mid-cooldown goes quiet ------------------------------

func _check_emptied_slot() -> void:
	_player.use_skill(_def())
	await physics_frames(2)
	Session.skill_loadout[SLOT] = ""
	await physics_frames(3)
	check(_kind(SLOT) == "", "an emptied slot kept its cue kind")
	check(_player.skill_ready_flash(SLOT) <= 0.0, "an emptied slot bloomed")
	check(not bool(_player._cue_ready[SLOT]), "an emptied slot reads as ready")
	Session.skill_loadout[SLOT] = SKILL
	_player.skill_cds[SKILL] = 0.0
	await physics_frames(3)
	check(_player.skill_ready_flash(SLOT) <= 0.0,
			"re-assigning a ready skill bloomed — that is not a transition")

# ---- (f) the deny tick honours the input buffer ------------------------------

func _check_denied_press() -> void:
	_player.use_skill(_def())
	await physics_frames(2)
	check(_player.skill_deny_flash(SLOT) <= 0.0, "a cast denied itself")
	await _press(SLOT)
	check(_player.skill_deny_flash(SLOT) > 0.0,
			"a press with seconds of cooldown left was swallowed in silence")
	var ticks := 0
	for i in 30:
		await physics_frames(1)
		if _player.skill_deny_flash(SLOT) <= 0.0:
			break
		ticks += 1
	check(ticks > 0 and ticks < 30, "the deny tick never faded (%d ticks)" % ticks)
	# inside the buffer window the press WILL be honoured — no red for a hit
	_player.skill_cds[SKILL] = ProtoPlayer.INPUT_BUFFER_S * 0.5
	await _press(SLOT)
	check(_player.skill_deny_flash(SLOT) <= 0.0,
			"a press the input buffer will honour was marked denied")

func _press(i: int) -> void:
	Input.action_press("slot%d" % (i + 1))
	await physics_frames(2)
	Input.action_release("slot%d" % (i + 1))
	await physics_frames(1)

# ---- (h) the grave clears every cue ------------------------------------------

func _check_grave() -> void:
	_player.skill_cds[SKILL] = 4.0
	await physics_frames(2)
	check(float(_player._cue_frac[SLOT]) > 0.0, "the probe failed to re-arm the cue")
	_player.respawn(_player.global_position)
	await physics_frames(2)
	check(float(_player._cue_frac[SLOT]) <= 0.0, "a cue survived the grave")
	check(_player.skill_ready_flash(SLOT) <= 0.0, "a bloom was waiting at the grave")
	check(_player.skill_deny_flash(SLOT) <= 0.0, "a deny tick was waiting at the grave")
