# ARENA — the game's DEFAULT AI: which mind drives a build when nothing names one
# (Ricardo, 2026-09-13: "make sure to add an option to the arena console/training
# interface to set new game default ais!").
#
# Until now "which AI runs" was decided per match, on the command line. The
# training console could move the DEPLOYED pin in ml/serving/registry.json, but
# nothing read that pin as "the default" — every arena match still had to be told
# `--policy-a native|scripted|<path>` explicitly. This is the missing seam:
#
#     --policy-a default        ->  whatever this file says for that build
#
# CONFIG: game/arena/data/ai_defaults.json, schema "arena.ai_defaults.v1"
#     {"mode": "deployed" | "scripted" | "native",
#      "per_build": {"core.arena.cinder_drake": "scripted"},   # overrides mode
#      "fallback": "native"}                                   # if no net is pinned
# The training console writes it (NETS tab -> DEFAULT AI). A missing file means
# DEFAULT_MODE below, so a fresh checkout behaves.
#
# WHERE THE NET COMES FROM, in order:
#   1. res://arena/data/nets/<key>.json   — packaged with an exported game
#   2. <repo>/ml/serving/registry.json    — the deployed pin, for a dev tree
# An exported build has no ml/ next to it, so 1 is what ships and 2 is what a
# developer and the training console see. Both resolve to the same schema
# ("arena.policy.v1"); neural_policy.gd does not care which produced it.
class_name ArenaAIDefaults
extends RefCounted

const CONFIG_PATH := "res://arena/data/ai_defaults.json"
const PACKAGED_NETS := "res://arena/data/nets/"
const REGISTRY_REL := "ml/serving/registry.json"
const SCHEMA := "arena.ai_defaults.v1"
const DEFAULT_MODE := "deployed"
const DEFAULT_FALLBACK := "native"
const MODES := ["deployed", "scripted", "native"]

static func load_config() -> Dictionary:
	var cfg := {"schema": SCHEMA, "mode": DEFAULT_MODE, "per_build": {},
			"fallback": DEFAULT_FALLBACK}
	if not FileAccess.file_exists(CONFIG_PATH):
		return cfg
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	if parsed is Dictionary:
		for k in ["mode", "per_build", "fallback"]:
			if (parsed as Dictionary).has(k):
				cfg[k] = (parsed as Dictionary)[k]
	return cfg

# The mode that applies to one build: its per-build override, else the global one.
static func mode_for(build_id: String, cfg: Dictionary = {}) -> String:
	var c := cfg if not cfg.is_empty() else load_config()
	var per: Dictionary = c.get("per_build", {})
	var m := str(per.get(build_id, c.get("mode", DEFAULT_MODE)))
	return m if m in MODES else DEFAULT_MODE

# build id ("core.arena.fen_boar_alpha") -> the registry key the trainers use
# ("fen_boar_alpha"): the last dotted segment, the tools/train_all.sh convention.
static func key_for(build_id: String) -> String:
	var parts := build_id.split(".")
	return parts[parts.size() - 1] if parts.size() > 0 else build_id

# The policy spec a fighter would be given: "native", "scripted", or an absolute
# path to a weights JSON. Never returns "" — a missing net degrades to `fallback`,
# because a dungeon that refuses to spawn is worse than one running the built-in AI.
static func policy_spec_for(build_id: String, cfg: Dictionary = {}) -> String:
	var c := cfg if not cfg.is_empty() else load_config()
	var mode := mode_for(build_id, c)
	if mode != "deployed":
		return mode
	var key := key_for(build_id)
	var packaged := PACKAGED_NETS + key + ".json"
	if FileAccess.file_exists(packaged):
		return ProjectSettings.globalize_path(packaged)
	var net := _deployed_net(key)
	return net if net != "" else str(c.get("fallback", DEFAULT_FALLBACK))

static func policy_for(build_id: String, cfg: Dictionary = {}) -> ArenaPolicy:
	var spec := policy_spec_for(build_id, cfg)
	if spec == "native":
		return ArenaPolicy.new()          # inert: the body's own AI runs
	if spec == "scripted":
		return ArenaScriptedPolicy.new()
	return ArenaNeuralPolicy.from_file(spec)

# The deployed pin for a key, read straight from the registry the trainers write.
# One deployed entry per key is the invariant (ml/eval/gate.py); if a stale
# registry carries several, the highest version wins — the same rule
# ml/training/league.py's resolve_policy("<key>@deployed") uses.
static func _deployed_net(key: String) -> String:
	var repo := ProjectSettings.globalize_path("res://..").simplify_path()
	var path := repo.path_join(REGISTRY_REL)
	if not FileAccess.file_exists(path):
		return ""
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		return ""
	var best := -1
	var pick := ""
	for p in (parsed as Dictionary).get("policies", []):
		if not (p is Dictionary):
			continue
		var d: Dictionary = p
		if str(d.get("key", "")) != key or not bool(d.get("deployed", false)):
			continue
		var game_json := str(d.get("game_json", ""))
		if game_json == "" or int(d.get("version", 0)) <= best:
			continue
		best = int(d.get("version", 0))
		pick = game_json if game_json.begins_with("/") else repo.path_join(game_json)
	return pick if pick != "" and FileAccess.file_exists(pick) else ""
