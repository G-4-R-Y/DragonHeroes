# ARENA — the scripted utility baseline (docs/design/23). Drives ANY body
# (player build or bot-driven creature) through the shared command API: hold a
# preferred range band, strafe, cast the skill bar off cooldown, dodge close
# windups, disengage at low HP. This is the R1 eval-suite opponent and the
# fallback mind for every build that has no trained net yet.
class_name ArenaScriptedPolicy
extends ArenaPolicy

var _strafe_dir := 1.0
var _strafe_t := 0.0
var _retreat_t := 0.0

func policy_id() -> String:
	return "scripted"

func _act(delta: float) -> void:
	var obs := delayed_obs()
	if obs.is_empty() or not is_instance_valid(fighter.alive_body()):
		return
	var my_pos := Vector2(obs[1], obs[2]) * 512.0
	var foe_pos := my_pos + Vector2(obs[16], obs[17]) * 512.0
	var dist := float(obs[18]) * 512.0
	var to_foe: Vector2 = (foe_pos - fighter.alive_body().global_position).normalized()
	var foe_windup: bool = obs[22] > 0.5
	var my_hp := float(obs[0])
	_strafe_t -= delta
	if _strafe_t <= 0.0:
		_strafe_t = rng.randf_range(0.8, 1.6)
		_strafe_dir = 1.0 if rng.randf() < 0.5 else -1.0
	# low-HP disengage (a couple of seconds), then re-engage
	if my_hp < 0.25 and _retreat_t <= 0.0:
		_retreat_t = 2.5
	_retreat_t = maxf(_retreat_t - delta, 0.0)
	# dodge a close windup (reaction gated by the obs delay + budget)
	if foe_windup and dist < 3.0 * 16.0 and can_commit() \
			and fighter.cmd_dodge(-to_foe):
		note_commit()
		return
	var ranged: bool = fighter.is_ranged()
	var band := fighter.preferred_range()
	var move := Vector2.ZERO
	if _retreat_t > 0.0:
		move = -to_foe
	elif dist > band.y:
		move = to_foe
	elif dist < band.x:
		move = -to_foe
	else:
		move = to_foe.rotated(PI * 0.5) * _strafe_dir * 0.7
	fighter.cmd_move(move)
	fighter.cmd_aim(noisy_aim(foe_pos))
	if not can_commit():
		return
	# skills off cooldown, in range order: bar slots, then special, then LMB
	for i in 4:
		if dist < 6.0 * 16.0 and fighter.cmd_skill(i):
			note_commit()
			return
	if dist < (band.y + 16.0) and fighter.cmd_special():
		note_commit()
		return
	if dist < (band.y + 8.0) and fighter.cmd_attack():
		note_commit()
	elif ranged and dist < 9.0 * 16.0 and fighter.cmd_attack():
		note_commit()
