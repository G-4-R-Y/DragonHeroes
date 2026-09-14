# ARENA — the HEURISTIC control (docs/tech/25 §5.2.2). Five rules: walk at the
# foe, spend each kit the moment it is off cooldown, slam when it is up, attack
# in reach. No strafing, no range band, no retreat — everything the scripted
# baseline does is deliberately left out, so this is a YARDSTICK and not a
# second baseline.
#
# It exists because it beat every net this project has trained. Measured
# 2026-09-14, mirror matchups, 12 episodes each: 12/12 wins against native for
# both cinder_drake and fen_boar, where the deployed fen_boar v6.0 net won 0/12
# and the drake's best net won 4/12. The gate REPORTS the candidate's win rate
# against it rather than requiring it: a net that cannot yet beat five rules is
# not necessarily unshippable, but it should never be invisible.
class_name ArenaHeuristicPolicy
extends ArenaPolicy

func policy_id() -> String:
	return "heuristic"

func _act(_delta: float) -> void:
	var obs := delayed_obs()
	if obs.is_empty() or not is_instance_valid(fighter.alive_body()):
		return
	var my_pos := Vector2(obs[1], obs[2]) * 512.0
	var foe_pos := my_pos + Vector2(obs[16], obs[17]) * 512.0
	var dist := float(obs[18]) * 512.0
	var to_foe: Vector2 = (foe_pos - fighter.alive_body().global_position).normalized()
	# 1. always close. This one line is the whole margin over the trained nets,
	#    whose move head never learned to leave zero (std 0.006 on a +-1 scale).
	fighter.cmd_move(to_foe)
	fighter.cmd_aim(noisy_aim(foe_pos))
	if not can_commit():
		return
	# 2. kits off cooldown, 3. slam, 4. attack — in that order, all range-gated.
	for i in 4:
		if dist < 6.0 * 16.0 and fighter.cmd_skill(i):
			note_commit()
			return
	if dist < fighter.preferred_range().y + 16.0 and fighter.cmd_special():
		note_commit()
		return
	if dist < fighter.preferred_range().y + 8.0 and fighter.cmd_attack():
		note_commit()
