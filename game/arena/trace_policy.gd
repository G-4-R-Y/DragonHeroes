# ARENA — the REPLAY mind (R51, docs/design/23 §replay). It thinks nothing: it
# hands this body the commands a dh-env fighter issued on the same tick of a
# recorded match (`arena.trace.v1`, written by ml/eval/trace_match.py).
#
# WHY A POLICY AND NOT A PUPPETEER. Teleporting the bodies along the recorded
# positions would be a video, and a video cannot be wrong — it would show the
# dh-env match perfectly while proving nothing about this runtime. Feeding the
# same COMMANDS into real ArenaFighter bodies makes the arena re-derive the
# motion with its own physics, cooldowns and hit registration. The recorded
# positions are then drawn as ghosts (trace_ghosts.gd), and the gap between
# ghost and body is a direct, per-tick, per-body reading of where dh-env and the
# arena disagree — which is exactly what ml/eval/env_parity.py cannot give,
# because a win rate or a surviving hp_frac can only say THAT they diverged.
#
# The action budget is NOT re-applied here (`can_commit()` is never consulted).
# The recorded command already passed dh-env's own budget, so gating it again
# would drop actions for a reason the traced run never had. The recorded
# `commit` column carries dh-env's verdict instead, and comparing it with what
# this runtime accepts is itself a parity reading, not something to suppress.
class_name ArenaTracePolicy
extends ArenaPolicy

var frames: Array = []          # rows of `stride` floats, as written by the sim
var side := 0                   # 0 = side A columns, 1 = side B columns
var tick_hz := 60.0
var side_fields := 11

var _t := 0.0                   # sim seconds since the episode began
var _cursor := -1               # last recorded tick whose ACTION was issued
var _last_act := 0
var _last_commit := -1.0

# Column order, frame layout `arena.trace.v1` (sim/libs/dh-env/include/dh_env.h).
const F_X := 0
const F_Y := 1
const F_AIM_X := 2
const F_AIM_Y := 3
const F_HP := 4
const F_WINDUP := 5
const F_DODGE_T := 6
const F_COMMIT := 7
const F_MOVE_X := 8
const F_MOVE_Y := 9
const F_ACT := 10
const ACT_DODGE := 8            # DH_ENV_ACT_DODGE — a FLAG, not an action id

func load_trace(doc: Dictionary, which: int) -> void:
	frames = doc.get("frames", [])
	side = which & 1
	tick_hz = float(doc.get("tick_hz", 60.0))
	side_fields = int(doc.get("side_fields", 11))
	_t = 0.0
	_cursor = -1

func policy_id() -> String:
	return "trace:%s" % ("a" if side == 0 else "b")

func frame_count() -> int:
	return frames.size()

# Recorded value for a column, at a recorded tick index (clamped: after the last
# frame the trace simply holds its final state rather than snapping to zero).
func at(idx: int, field: int) -> float:
	if frames.is_empty():
		return 0.0
	var row: Array = frames[clampi(idx, 0, frames.size() - 1)]
	return float(row[1 + side * side_fields + field])

func pos_at(idx: int) -> Vector2:
	return Vector2(at(idx, F_X), at(idx, F_Y))

func cursor() -> int:
	return int(_t * tick_hz)

# True once the recording has been acted out to its end — the arena stops the
# episode there instead of letting the bodies fight on unrecorded.
func finished() -> bool:
	return not frames.is_empty() and cursor() >= frames.size()

func last_action() -> int:
	return _last_act

func last_commit() -> float:
	return _last_commit

func _act(delta: float) -> void:
	# The clock advances FIRST and unconditionally: it is the replay's only
	# time source (trace_ghosts.gd reads cursor() off this policy), so a frame
	# where the body is momentarily unavailable must not stall the ghosts.
	_t += delta
	if frames.is_empty() or not is_instance_valid(fighter.alive_body()):
		return
	var idx := mini(cursor(), frames.size() - 1)
	# MOVE and AIM are per-frame intents (fighter.gd resets them each tick), so
	# they are re-issued every frame from the current row — not once per tick.
	fighter.cmd_move(Vector2(at(idx, F_MOVE_X), at(idx, F_MOVE_Y)))
	# The trace stores aim as the sim's aim DIRECTION; the command API takes a
	# world point. Same origin and same units (px, arena centre), so a point one
	# body-length along that direction aims at exactly what dh-env aimed at.
	var here: Vector2 = fighter.alive_body().global_position
	var aim := Vector2(at(idx, F_AIM_X), at(idx, F_AIM_Y))
	if aim.length() > 0.001:
		fighter.cmd_aim(here + aim.normalized() * 64.0)
	# DISCRETE actions fire once per recorded tick. The loop exists for the case
	# where one frame covers several sim ticks (--speed max, a hitch): every
	# recorded action is still offered, in order, instead of silently skipped.
	while _cursor < idx:
		_cursor += 1
		_issue(int(at(_cursor, F_ACT)), _cursor)

func _issue(act: int, idx: int) -> void:
	_last_act = act
	_last_commit = at(idx, F_COMMIT)
	var pick := act & 0x7
	var ok := false
	match pick:
		1: ok = fighter.cmd_attack()
		2: ok = fighter.cmd_special()
		3, 4, 5, 6: ok = fighter.cmd_skill(pick - 3)
	# dodge is attempted only when the pick was refused — the same order
	# game/arena/neural_policy.gd uses, and the same one dh-env recorded.
	if (act & ACT_DODGE) != 0 and not ok:
		ok = fighter.cmd_dodge(Vector2(at(idx, F_MOVE_X), at(idx, F_MOVE_Y)))
	if ok:
		note_commit()   # bookkeeping only: nothing here reads the budget back
