# ARENA — the GHOST overlay for a trace replay (R51, docs/design/23 §replay).
#
# Draws where dh-env's fighters WERE on the tick the arena is currently acting
# out, on top of where this runtime's bodies actually are. Both are driven by
# the same recorded commands (trace_policy.gd), so a ghost and its body should
# sit on top of one another. Where they come apart is a divergence between the
# two runtimes, localised to a body and a tick — which is the whole point: hp
# totals and win rates (ml/eval/env_parity.py) can only say THAT they disagree.
#
# The clock lives in the policy, not here. ArenaTracePolicy advances its own
# `_t` from ArenaPolicy.tick(), which arena.gd only calls while the match is in
# the "fight" state; reading cursor() off it means the ghosts cannot drift from
# the replay by a frame of intro, pause or end-of-episode hold.
class_name ArenaTraceGhosts
extends Node2D

const R := 13.0                # ghost ring radius, ~a fighter's body radius
const DRIFT_VISIBLE := 2.0     # px: below this the tether is noise, not signal

var fighters: Array = []       # the two ArenaFighters being replayed
var tints := [Color("7fd8ff"), Color("ff9a3c")]
var drift := [0.0, 0.0]        # px, current
var drift_peak := [0.0, 0.0]   # px, worst seen this episode
var drift_sum := [0.0, 0.0]    # for the mean
var samples := 0
# The first tick each body crossed BREAK px away from its ghost: "where did the
# two runtimes part company" as a NUMBER, which is the whole R51 promise. -1 =
# never. Reading it off the policy's cursor keeps it in recorded-tick units, so
# it indexes straight back into the trace's frames for whoever digs in.
var first_break := [-1, -1]
const BREAK := 20.0            # px: further than a body is wide — not jitter
# Mean distance BETWEEN the two bodies, recorded vs replayed. Drift says the
# pair moved differently; this says whether they were even fighting the same
# fight — a melee that never closes deals no damage no matter how it steps.
var gap_rec := 0.0
var gap_now := 0.0
var gap_samples := 0

func _ready() -> void:
	z_index = 60               # above bodies and fields, below the HUD

func reset() -> void:
	drift = [0.0, 0.0]
	drift_peak = [0.0, 0.0]
	drift_sum = [0.0, 0.0]
	samples = 0
	first_break = [-1, -1]
	gap_rec = 0.0
	gap_now = 0.0
	gap_samples = 0

func mean_drift(i: int) -> float:
	return drift_sum[i] / float(maxi(samples, 1))

# One line for the HUD: what a watcher needs to know without reading a log.
func summary() -> String:
	return "drift a %.1f/%.1f b %.1f/%.1f px (now/peak)" % [
			drift[0], drift_peak[0], drift[1], drift_peak[1]]

func _process(_delta: float) -> void:
	_measure()
	queue_redraw()

func _measure() -> void:
	var counted := false
	for i in mini(fighters.size(), 2):
		var f = fighters[i]
		if not is_instance_valid(f) or not (f.policy is ArenaTracePolicy):
			continue
		var body: Node2D = f.alive_body()
		if not is_instance_valid(body):
			continue
		var d: float = body.global_position.distance_to(
				f.policy.pos_at(f.policy.cursor()))
		drift[i] = d
		drift_peak[i] = maxf(drift_peak[i], d)
		drift_sum[i] += d
		if d >= BREAK and first_break[i] < 0:
			first_break[i] = f.policy.cursor()
		counted = true
	if counted:
		samples += 1
	_measure_gap()

# Both bodies must be live for a gap to mean anything; a dead body stops moving
# and would drag the mean toward whatever it died at.
func _measure_gap() -> void:
	if fighters.size() < 2:
		return
	var fa = fighters[0]
	var fb = fighters[1]
	if not is_instance_valid(fa) or not is_instance_valid(fb):
		return
	if not (fa.policy is ArenaTracePolicy) or not (fb.policy is ArenaTracePolicy):
		return
	var ba: Node2D = fa.alive_body()
	var bb: Node2D = fb.alive_body()
	if not is_instance_valid(ba) or not is_instance_valid(bb):
		return
	gap_now += ba.global_position.distance_to(bb.global_position)
	gap_rec += fa.policy.pos_at(fa.policy.cursor()).distance_to(
			fb.policy.pos_at(fb.policy.cursor()))
	gap_samples += 1

func mean_gap_rec() -> float:
	return gap_rec / float(maxi(gap_samples, 1))

func mean_gap_now() -> float:
	return gap_now / float(maxi(gap_samples, 1))

func _draw() -> void:
	for i in mini(fighters.size(), 2):
		var f = fighters[i]
		if not is_instance_valid(f) or not (f.policy is ArenaTracePolicy):
			continue
		var p: ArenaTracePolicy = f.policy
		if p.frame_count() == 0:
			continue
		var idx := p.cursor()
		var g: Vector2 = p.pos_at(idx)
		var tint: Color = tints[i & 1]
		var done := idx >= p.frame_count()
		var a := 0.25 if done else 0.8     # past the recording: fade, don't lie
		# the ring is the recorded body; it goes hollow-thin while the recording
		# says that fighter was mid-dodge (i-frames read as "not really there")
		var dodging: bool = p.at(idx, ArenaTracePolicy.F_DODGE_T) > 0.0
		draw_arc(g, R, 0.0, TAU, 28, Color(tint, a * (0.45 if dodging else 1.0)),
				1.0 if dodging else 2.0, true)
		# recorded hp as an arc on the same ring — a silent desync in hp shows
		# here even when the positions agree (different damage, same motion)
		var hp: float = clampf(p.at(idx, ArenaTracePolicy.F_HP), 0.0, 1.0)
		if hp > 0.0:
			draw_arc(g, R + 3.0, -PI * 0.5, -PI * 0.5 + TAU * hp, 32,
					Color(tint, a * 0.7), 2.0, true)
		# recorded aim, and the windup the recording was in the middle of
		var aim := Vector2(p.at(idx, ArenaTracePolicy.F_AIM_X),
				p.at(idx, ArenaTracePolicy.F_AIM_Y))
		if aim.length() > 0.001:
			draw_line(g, g + aim.normalized() * (R + 7.0), Color(tint, a * 0.8), 1.5)
		if p.at(idx, ArenaTracePolicy.F_WINDUP) > 0.0:
			draw_circle(g, 3.0, Color(1.0, 0.95, 0.6, a))
		# the tether: ghost to body, the divergence made visible
		var body: Node2D = f.alive_body()
		if is_instance_valid(body) and drift[i] > DRIFT_VISIBLE:
			var far: bool = drift[i] > 24.0   # a body-and-a-half apart: shout
			draw_line(g, body.global_position,
					Color(1.0, 0.35, 0.35, 0.85) if far else Color(tint, 0.45),
					2.0 if far else 1.0)
