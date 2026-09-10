# ARENA — the neural policy runtime (docs/design/23). ONE loader serves both
# per-species fine-tuned nets and the global net: a weights JSON exported by
# ml/training/policy_net.py (schema "arena.policy.v1"). The input is the
# arena.obs.v1 vector PLUS the fighter's embedding row (policy_key) — species
# nets carry a single "*" row, the global net carries one row per content id
# (canon §9 §5: new content = new embedding rows, never new tensor shapes).
class_name ArenaNeuralPolicy
extends ArenaPolicy

var path := ""
var explore := 0.05             # epsilon on the action logits (eval: ~0)
var _emb := {}
var _layers: Array = []         # [{w: [[out x in]], b: [out], act: "tanh"|"logits"}]

func policy_id() -> String:
	return "neural:" + path.get_file()

static func from_file(p: String) -> ArenaNeuralPolicy:
	var pol := ArenaNeuralPolicy.new()
	pol.path = p
	var raw := FileAccess.get_file_as_string(p)
	if raw.is_empty():
		push_error("NeuralPolicy: missing weights " + p)
		return pol
	var data: Variant = JSON.parse_string(raw)
	if not (data is Dictionary) or str(data.get("schema", "")) != POLICY_SCHEMA:
		push_error("NeuralPolicy: bad policy file " + p)
		return pol
	if int(data.get("obs_dim", 0)) != OBS_DIM:
		push_error("NeuralPolicy: obs_dim mismatch in " + p)
		return pol
	pol._emb = data.get("embeddings", {})
	for l in data.get("layers", []):
		pol._layers.append({"w": l.get("w", []), "b": l.get("b", []),
				"act": str(l.get("act", "tanh"))})
	pol.explore = float(data.get("explore", 0.05))
	return pol

func _forward(x: PackedFloat32Array) -> Array:
	var out: Array = []
	out.resize(x.size())
	for i in x.size():
		out[i] = x[i]
	for l in _layers:
		var w: Array = l.w
		var b: Array = l.b
		var nxt: Array = []
		nxt.resize(w.size())
		for o in w.size():
			var row: Array = w[o]
			var s := float(b[o])
			for j in mini(row.size(), out.size()):
				s += float(row[j]) * float(out[j])
			nxt[o] = tanh(s) if str(l.act) == "tanh" else s
		out = nxt
	return out

func _act(_delta: float) -> void:
	if _layers.is_empty() or not is_instance_valid(fighter.body):
		return
	var obs := delayed_obs()
	if obs.is_empty():
		return
	var row: Array = _emb.get(fighter.policy_key, _emb.get("*", []))
	if row.is_empty():
		return
	var x := PackedFloat32Array()
	x.resize(OBS_DIM + EMB_DIM)
	for i in OBS_DIM:
		x[i] = obs[i]
	for i in mini(EMB_DIM, row.size()):
		x[OBS_DIM + i] = float(row[i])
	var y := _forward(x)
	if y.size() < 2 + ACTION_LOGITS + 1:
		return
	fighter.cmd_move(Vector2(float(y[0]), float(y[1])))
	# aim tracks the enemy through the fairness noise, like every policy
	var foe_pos: Vector2 = enemy.body.global_position \
			if enemy != null and not enemy.is_dead() \
			else fighter.body.global_position + Vector2.RIGHT
	fighter.cmd_aim(noisy_aim(foe_pos))
	var pick := 0
	var best := -INF
	for i in ACTION_LOGITS:
		if float(y[2 + i]) > best:
			best = float(y[2 + i])
			pick = i
	if rng.randf() < explore:
		pick = rng.randi_range(0, ACTION_LOGITS - 1)
	if not can_commit():
		return
	var ok := false
	match pick:
		1: ok = fighter.cmd_attack()
		2: ok = fighter.cmd_special()
		3, 4, 5, 6: ok = fighter.cmd_skill(pick - 3)
	if float(y[2 + ACTION_LOGITS]) > 0.0 and not ok:
		ok = fighter.cmd_dodge(Vector2(float(y[0]), float(y[1])))
	if ok:
		note_commit()
