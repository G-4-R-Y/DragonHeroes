# ARENA — the STATUE control (docs/tech/25 §5.2.2). Attacks whenever it can and
# NEVER moves. Deliberately the worst policy that still does something.
#
# It exists because a win rate alone cannot tell "the learner is bad" from "the
# matchup is hard" from "the gate is wrong". This is the floor: any net that
# does not beat a body standing still is broken, whatever its win rate says.
#
# It is not hypothetical. Measured 2026-09-14, mirror matchups, 12 episodes:
# the DEPLOYED fen_boar v6.0 took LESS health off its opponent than this policy
# did (0.421 vs 0.537 vs scripted, 0.652 vs 0.844 vs native) and scored below it
# on the reward model in both. Creature AI that ships must clear this bar.
class_name ArenaStatuePolicy
extends ArenaPolicy

func policy_id() -> String:
	return "statue"

func _act(_delta: float) -> void:
	var obs := delayed_obs()
	if obs.is_empty() or not is_instance_valid(fighter.alive_body()):
		return
	# It still AIMS and ATTACKS — a control that did nothing at all would be a
	# weaker floor than it needs to be, and the point is to isolate MOVEMENT.
	var my_pos := Vector2(obs[1], obs[2]) * 512.0
	var foe_pos := my_pos + Vector2(obs[16], obs[17]) * 512.0
	fighter.cmd_aim(noisy_aim(foe_pos))
	if can_commit() and fighter.cmd_attack():
		note_commit()
