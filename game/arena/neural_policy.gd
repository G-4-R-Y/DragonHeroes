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
var _layers: Array = []         # [{w: PackedFloat64Array flat [out*in], b: ..., n_in, n_out, act}]
# The same forward pass in C++ (sim/libs/dh-godot), when the GDExtension is
# built. Even flattened, GDScript spends ~400 ns per multiply-add; this is the
# rest of that gap. It is OPTIONAL on purpose — a checkout without the extension
# runs the GDScript path below and gets identical numbers, just slower.
var _cnet: Object = null

# Activation codes, shared with ml/training/arch.py and sim/libs/dh-godot
# (DhPolicyNet::Activation). Ricardo, 2026-09-13: "net hyperparams should be
# configurable, as to test new architectures" — a layer used to be tanh-or-not.
# The set stays tiny because BOTH forward passes below have to produce the same
# bits: max(0, x) and a hard-coded slope do, erf/exp curves would need a proof.
# 1 == the old `true` and 0 == the old `false`, so nothing on disk changes meaning.
const ACT_CODES := {"linear": 0, "tanh": 1, "relu": 2, "leaky_relu": 3,
		# "logits" is what the PPO exporter called its folded head before this
		# was an enum, and four nets in ml/serving/weights carry it TODAY. It has
		# always meant linear; refusing it would retire them.
		"logits": 0}
const LEAKY_SLOPE := 0.01

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
		# Default tanh: nets exported before activations were configurable carry
		# "act": "tanh" already, and anything older had no key and WAS tanh.
		var act_name := str(l.get("act", "tanh"))
		if not ACT_CODES.has(act_name):
			push_error("NeuralPolicy: unknown activation '%s' in %s" % [act_name, p])
			pol._layers.clear()
			return pol
		pol._layers.append({"w": flat, "b": bias, "n_in": n_in, "n_out": n_out,
				"act": int(ACT_CODES[act_name])})
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
		if not bool(n.call("add_layer", l.w, l.b, l.n_in, l.n_out, l.act)):
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
		var act: int = l.act
		var lim: int = mini(n_in, out.size())
		var nxt := PackedFloat64Array()
		nxt.resize(n_out)
		for o in n_out:
			var base: int = o * n_in
			var s: float = b[o]
			for j in lim:
				s += w[base + j] * out[j]
			# Branch on the code, not through a helper call: this is the hot
			# loop, and it must read as the same arithmetic as activate() in
			# sim/libs/dh-godot/src/dh_policy_net.cpp.
			match act:
				1: nxt[o] = tanh(s)
				2: nxt[o] = s if s > 0.0 else 0.0
				3: nxt[o] = s if s > 0.0 else LEAKY_SLOPE * s
				_: nxt[o] = s
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
	# arena.mask.v1 (R50, 2026-09-19): the pick is the argmax over the actions
	# the body can actually take right now, decided from the same delayed obs
	# the net just read — see decode(). The unmasked argmax it replaces is kept
	# below for the record: with it, a net whose top logit was a kit on an 8 s
	# cooldown stood there re-picking a refused action for 480 ticks.
	# var pick := 0
	# var best := -INF
	# for i in ACTION_LOGITS:
	# 	if float(y[2 + i]) > best:
	# 		best = float(y[2 + i])
	# 		pick = i
	# if rng.randf() < explore:
	# 	pick = rng.randi_range(0, ACTION_LOGITS - 1)
	var kit_n := fighter.kit_count()
	var is_pl := fighter.is_player()
	var dec := decode(y, obs, kit_n, is_pl)
	var pick: int = dec[0]
	if rng.randf() < explore:
		pick = explore_pick(obs, kit_n, is_pl)
	if not can_commit():
		return
	var ok := false
	match pick:
		1: ok = fighter.cmd_attack()
		2: ok = fighter.cmd_special()
		3, 4, 5, 6: ok = fighter.cmd_skill(pick - 3)
	# if float(y[2 + ACTION_LOGITS]) > 0.0 and not ok:   (pre-mask: no charge check)
	if bool(dec[1]) and not ok:
		ok = fighter.cmd_dodge(Vector2(float(y[0]), float(y[1])))
	if ok:
		note_commit()

# ---- arena.mask.v1 -------------------------------------------------------------------
# ONE rule in five runtimes: this file, ml/training/policy_net.py::decode, the torch
# trainer (ml/training/torch_policy.py::mask_heads), dh::sim::Arena::action_mask
# (the frozen self-play opponent) and ml/eval/env_parity.py. It reads only the obs
# the policy SEES plus two body constants, so every runtime computes the same bits.
#   0 noop        always
#   1 attack      o[5] <= 0            (attack cooldown fraction; EXACTLY 0.0 when ready)
#   2 special     player: o[6] <= 0    creature: o[5] <= 0 (its "special" is a swing)
#   3+k kit k     k < kit_count and o[7+k] <= 0
#   dodge flag    y[9] > 0 and o[12] > 0  (a charge must be visible)
# Ties: the FIRST max among the available logits — every runtime's loop is strict >.
# Pinned by game/arena/tests/mask_parity_test.gd against the fixture Python writes.
static func action_mask(obs: PackedFloat32Array, kit_count: int, is_player: bool) -> Array[bool]:
	var m: Array[bool] = []
	m.resize(ACTION_LOGITS)
	var attack_ready := obs[5] <= 0.0
	m[0] = true
	m[1] = attack_ready
	m[2] = (obs[6] <= 0.0) if is_player else attack_ready
	for k in 4:
		m[3 + k] = k < kit_count and obs[7 + k] <= 0.0
	return m

static func dodge_allowed(obs: PackedFloat32Array) -> bool:
	return obs[12] > 0.0

# -> [pick: int, dodge: bool]; the head y is [move2, logits7, dodge1]
static func decode(y: PackedFloat64Array, obs: PackedFloat32Array, kit_count: int,
		is_player: bool) -> Array:
	var allowed := action_mask(obs, kit_count, is_player)
	var pick := -1
	for i in ACTION_LOGITS:
		if allowed[i] and (pick < 0 or float(y[2 + i]) > float(y[2 + pick])):
			pick = i
	return [pick, float(y[2 + ACTION_LOGITS]) > 0.0 and dodge_allowed(obs)]

# epsilon-exploration draws from the AVAILABLE actions, not from all seven
func explore_pick(obs: PackedFloat32Array, kit_count: int, is_player: bool) -> int:
	var allowed := action_mask(obs, kit_count, is_player)
	var pool: Array[int] = []
	for i in ACTION_LOGITS:
		if allowed[i]:
			pool.append(i)
	return pool[rng.randi_range(0, pool.size() - 1)]
