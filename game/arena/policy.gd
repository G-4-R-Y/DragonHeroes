# ARENA — policy base class: the mind interface + the fairness layer
# (docs/design/23). Implementations:
#   native    — inert base instance; the body runs its own built-in AI.
#   scripted  — scripted_policy.gd (ArenaScriptedPolicy): utility heuristics.
#   neural    — neural_policy.gd (ArenaNeuralPolicy): MLP from a weights JSON
#               exported by ml/training (per-species + global net, one runtime).
#
# OBSERVATION SCHEMA "arena.obs.v1" (OBS_DIM = 31) — fixed layout, versioned;
# ml/training/policy_net.py MUST match. Entity-set encodings and learned
# content embeddings (canon §9 §5) arrive with dh-env; the embedding-row slot
# (EMB_DIM) already exists so nets are content-keyed from day one.
#   [0]  self hp_frac
#   [1..2]  self pos rel arena center / 512
#   [3..4]  self velocity / 100
#   [5]  self attack cooldown fraction
#   [6]  self special (E) cooldown fraction
#   [7..10] self skill-slot 1-4 cooldown fractions
#   [11] self charge fraction (Combo/Attunement)
#   [12] self dodge charges fraction
#   [13] self slowed flag
#   [14] self damage-over-time flag
#   [15] enemy hp_frac
#   [16..17] enemy rel pos / 512
#   [18] enemy distance / 512
#   [19..20] bearing to enemy (sin, cos)
#   [21] enemy body_radius / 16
#   [22] enemy winding-up flag
#   [23..30] two nearest hostile projectiles: rel x,y / 512 + vel x,y / 256
#
# FAIRNESS (canon §9 §6 — baked into TRAINING, not patched at inference):
# every policy observes through a sampled 150-250 ms delay buffer, aims through
# gaussian noise, and commits actions under a burst-binding rate cap.
class_name ArenaPolicy
extends RefCounted

const OBS_DIM := 31
const EMB_DIM := 16
const ACTION_LOGITS := 7        # noop, attack, special, skill1..4
const OBS_SCHEMA := "arena.obs.v1"
const POLICY_SCHEMA := "arena.policy.v1"

const ACTION_BUDGET := 6        # commits per second (burst cap, AlphaStar lesson)
const BUDGET_WINDOW := 1.0
const AIM_NOISE_RAD := 0.06     # ~3.4 deg — human dispersion stand-in

var fighter: ArenaFighter = null
var enemy: ArenaFighter = null
var rng := RandomNumberGenerator.new()

var _delay_s := 0.2             # sampled per episode in [0.15, 0.25]
var _obs_log: Array = []        # [{t, obs}] ring buffer for delayed obs
var _clock := 0.0
var _commits: Array = []        # timestamps of recent committed actions

func setup(f: ArenaFighter, e: ArenaFighter, seed: int) -> void:
	fighter = f
	enemy = e
	rng.seed = seed
	_delay_s = rng.randf_range(0.15, 0.25)
	_obs_log.clear()
	_commits.clear()
	_clock = 0.0

func policy_id() -> String:
	return "native"

func tick(delta: float) -> void:
	_clock += delta
	_obs_log.append({"t": _clock, "obs": fighter.obs_vector(enemy)})
	while _obs_log.size() > 24:
		_obs_log.pop_front()
	while not _commits.is_empty() and _clock - float(_commits[0]) > BUDGET_WINDOW:
		_commits.pop_front()
	_act(delta)

# The observation the policy is ALLOWED to see (client-equivalent, delayed).
func delayed_obs() -> PackedFloat32Array:
	var target := _clock - _delay_s
	var best: PackedFloat32Array = _obs_log[0].obs
	for entry in _obs_log:
		if float(entry.t) <= target:
			best = entry.obs
		else:
			break
	return best

# Burst-binding action budget: a commit is an attack/skill/dodge decision.
func can_commit() -> bool:
	return _commits.size() < ACTION_BUDGET

func note_commit() -> void:
	_commits.append(_clock)

func noisy_aim(at: Vector2) -> Vector2:
	var d := at - fighter.body.global_position
	return fighter.body.global_position + d.rotated(rng.randfn(0.0, AIM_NOISE_RAD))

func _act(_delta: float) -> void:
	pass   # native: the body's own AI runs
