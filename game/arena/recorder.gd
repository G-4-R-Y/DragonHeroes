# ARENA — the episode recorder: R0-style observation+action logging (canon §9,
# docs/tech/25 §4.1). Every episode is one JSONL file: a meta line, one line per
# fighter per 30 Hz sample with the SAME obs vector the policy consumed (schema
# arena.obs.v1) and the action it emitted, and a result line. These logs are the
# behavioral-cloning dataset and the global net's cross-species training feed.
class_name ArenaRecorder
extends RefCounted

var _file: FileAccess = null
var _path := ""

func is_open() -> bool:
	return _file != null

func open_episode(dir: String, match_id: String, episode: int, meta: Dictionary) -> void:
	close()
	DirAccess.make_dir_recursive_absolute(dir)
	_path = "%s/%s_ep%03d.jsonl" % [dir, match_id, episode]
	_file = FileAccess.open(_path, FileAccess.WRITE)
	if _file == null:
		push_warning("ArenaRecorder: cannot write " + _path)
		return
	var m := meta.duplicate()
	m["type"] = "meta"
	m["obs_schema"] = ArenaPolicy.OBS_SCHEMA
	_write(m)

func log_step(t: float, fighter: ArenaFighter, enemy: ArenaFighter) -> void:
	if _file == null:
		return
	_write({"type": "step", "t": snappedf(t, 0.001),
			"fighter": fighter.build_id, "policy": fighter.policy.policy_id(),
			"policy_key": fighter.policy_key,
			"obs": Array(fighter.obs_vector(enemy)),
			"action": {"move": [snappedf(fighter.last_action.move.x, 0.001),
					snappedf(fighter.last_action.move.y, 0.001)],
					"act": int(fighter.last_action.act)}})

func log_result(result: Dictionary) -> void:
	if _file == null:
		return
	var r := result.duplicate()
	r["type"] = "result"
	_write(r)

func path() -> String:
	return _path

func close() -> void:
	if _file != null:
		_file.close()
		_file = null

func _write(d: Dictionary) -> void:
	_file.store_line(JSON.stringify(d))
