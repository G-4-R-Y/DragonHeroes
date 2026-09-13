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
# Layers are FLAT, not nested. Measured 2026-09-13: with `w` as an Array of
# Arrays and `float(row[j]) * float(out[j])` in the inner loop, this forward pass
# was ~2.2 ms per fighter per tick — 93% of the whole arena tick, dwarfing
# physics, projectiles and the rest of the engine combined. Every element access
# went through a Variant. A flat PackedFloat64Array indexed by o * n_in + j
# keeps the identical numbers (the exported weights are float32-exact, and the
# accumulator was always a GDScript float) with none of the boxing.
var _layers: Array = []         # [{w: PackedFloat64Array flat [out*in], b: ..., n_in, n_out, tanh}]
# The same forward pass in C++ (sim/libs/dh-godot), when the GDExtension is
# built. Even flattened, GDScript spends ~400 ns per multiply-add; this is the
# rest of that gap. It is OPTIONAL on purpose — a checkout without the extension
# runs the GDScript path below and gets identical numbers, just slower.
var _cnet: Object = null

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
		var rows: Array = l.get("w", [])
		var n_out := rows.size()
		var n_in: int = (rows[0] as Array).size() if n_out > 0 else 0
		var flat := PackedFloat64Array()
		flat.resize(n_out * n_in)
		for o in n_out:
			var row: Array = rows[o]
			var base := o * n_in
			for j in mini(n_in, row.size()):
				flat[base + j] = float(row[j])
		var bias := PackedFloat64Array()
		bias.resize(n_out)
		var b_src: Array = l.get("b", [])
		for o in mini(n_out, b_src.size()):
			bias[o] = float(b_src[o])
		pol._layers.append({"w": flat, "b": bias, "n_in": n_in, "n_out": n_out,
				"tanh": str(l.get("act", "tanh")) == "tanh"})
	pol.explore = float(data.get("explore", 0.05))
	pol._build_native()
	return pol


func _build_native() -> void:
	if not ClassDB.class_exists("DhPolicyNet"):
		return
	var n: Object = ClassDB.instantiate("DhPolicyNet")
	if n == null:
		return
	for l in _layers:
		# add_layer refuses a flattening that does not match n_in * n_out. If it
		# ever does, stay on the GDScript path rather than run a net we cannot
		# vouch for.
		if not bool(n.call("add_layer", l.w, l.b, l.n_in, l.n_out, l.tanh)):
			push_warning("DhPolicyNet rejected a layer — using the GDScript forward pass")
			return
	_cnet = n


func uses_native() -> bool:
	return _cnet != null

func _forward(x: PackedFloat64Array) -> PackedFloat64Array:
	if _cnet != null:
		return _cnet.call("forward", x)
	var out := PackedFloat64Array()
	out.resize(x.size())
	for i in x.size():
		out[i] = x[i]
	for l in _layers:
		var w: PackedFloat64Array = l.w
		var b: PackedFloat64Array = l.b
		var n_in: int = l.n_in
		var n_out: int = l.n_out
		var use_tanh: bool = l.tanh
		var lim: int = mini(n_in, out.size())
		var nxt := PackedFloat64Array()
		nxt.resize(n_out)
		for o in n_out:
			var base: int = o * n_in
			var s: float = b[o]
			for j in lim:
				s += w[base + j] * out[j]
			nxt[o] = tanh(s) if use_tanh else s
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
	# f64 container, f32 contents: the obs vector is already a PackedFloat32Array
	# and the embeddings are exported float32, so nothing is rounded differently
	# here — it just avoids converting the vector again for the C++ call.
	var x := PackedFloat64Array()
	x.resize(OBS_DIM + EMB_DIM)
	for i in OBS_DIM:
		x[i] = obs[i]
	for i in mini(EMB_DIM, row.size()):
		x[OBS_DIM + i] = float(row[i])
	var y: PackedFloat64Array = _forward(x)
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
