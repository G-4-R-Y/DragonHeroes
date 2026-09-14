# ARENA TEST — the two forward passes must agree BIT FOR BIT.
#
# Nets in ml/serving were trained against one of these two runtimes, so if
# DhPolicyNet (C++, sim/libs/dh-godot) and ArenaNeuralPolicy._forward (GDScript)
# ever disagree, every deployed policy silently becomes a different policy. That
# was already true for tanh; with configurable activations (Ricardo, 2026-09-13:
# "net hyperparams should be configurable, as to test new architectures") it is
# true four times over, which is why this is a gate and not a one-off probe.
#
#   godot --headless --path game res://arena/tests/policy_parity_test.tscn --quit-after 20
#
# Prints POLICY PARITY OK + quit(0); push_error + quit(1) on any mismatch. With
# no GDExtension built it prints SKIPPED and still exits 0 — the GDScript path
# is the reference, and a checkout without the extension is a supported setup.
extends Node2D

const ACTS := ["linear", "tanh", "relu", "leaky_relu"]
const SAMPLES := 64

# Deterministic weights without an RNG object: the same numbers on every machine,
# spread over a range where tanh saturates and relu clips, so a wrong activation
# cannot hide behind a near-linear region.
func _w(i: int) -> float:
	return sin(float(i) * 1.7182818) * 2.5

func _make_json(act: String) -> String:
	var layers: Array = []
	var sizes := [ArenaPolicy.OBS_DIM + ArenaPolicy.EMB_DIM, 13, 11,
			2 + ArenaPolicy.ACTION_LOGITS + 1]
	var seed_i := 0
	for li in range(sizes.size() - 1):
		var n_in: int = sizes[li]
		var n_out: int = sizes[li + 1]
		var rows: Array = []
		for o in n_out:
			var row: Array = []
			for j in n_in:
				seed_i += 1
				row.append(_w(seed_i))
			rows.append(row)
		var b: Array = []
		for o in n_out:
			seed_i += 1
			b.append(_w(seed_i) * 0.25)
		# Hidden layers carry the activation under test; the head is linear, as
		# every exporter writes it.
		layers.append({"w": rows, "b": b,
				"act": act if li < sizes.size() - 2 else "linear"})
	var emb: Array = []
	for i in ArenaPolicy.EMB_DIM:
		emb.append(_w(9000 + i))
	return JSON.stringify({
		"schema": ArenaPolicy.POLICY_SCHEMA,
		"obs_dim": ArenaPolicy.OBS_DIM,
		"emb_dim": ArenaPolicy.EMB_DIM,
		"explore": 0.0,
		"embeddings": {"*": emb},
		"layers": layers,
	})

func _ready() -> void:
	var dir := "user://policy_parity"
	DirAccess.make_dir_recursive_absolute(dir)
	var checked := 0
	var native_seen := false
	for act in ACTS:
		var path: String = dir.path_join("%s.json" % act)
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string(_make_json(act))
		f.close()

		var a := ArenaNeuralPolicy.from_file(path)
		var b := ArenaNeuralPolicy.from_file(path)
		if a._layers.is_empty():
			push_error("POLICY PARITY FAILED — '%s' did not load" % act)
			get_tree().quit(1)
			return
		if not a.uses_native():
			continue
		native_seen = true
		b._cnet = null                      # force the GDScript reference path

		for s in SAMPLES:
			var x := PackedFloat64Array()
			x.resize(ArenaPolicy.OBS_DIM + ArenaPolicy.EMB_DIM)
			for i in x.size():
				x[i] = _w(s * 131 + i * 7) * (1.0 + float(s) * 0.05)
			var yc: PackedFloat64Array = a._forward(x)
			var yg: PackedFloat64Array = b._forward(x)
			if yc.size() != yg.size():
				push_error("POLICY PARITY FAILED — '%s' size %d vs %d" % [act, yc.size(), yg.size()])
				get_tree().quit(1)
				return
			for i in yc.size():
				# Not is_equal_approx: bit-for-bit is the actual contract.
				if yc[i] != yg[i]:
					push_error("POLICY PARITY FAILED — '%s' sample %d out %d: C++ %.17g != GDScript %.17g"
							% [act, s, i, yc[i], yg[i]])
					get_tree().quit(1)
					return
			checked += 1

	# A net whose activation neither runtime knows must be REFUSED, not run as
	# something else. from_file clears its layers; _act then returns immediately.
	var bad: String = dir.path_join("bogus.json")
	var bf := FileAccess.open(bad, FileAccess.WRITE)
	bf.store_string(_make_json("tanh").replace('"act":"tanh"', '"act":"gelu"'))
	bf.close()
	if not ArenaNeuralPolicy.from_file(bad)._layers.is_empty():
		push_error("POLICY PARITY FAILED — an unknown activation loaded anyway")
		get_tree().quit(1)
		return

	if not native_seen:
		print("POLICY PARITY SKIPPED — no DhPolicyNet (GDScript path is the reference)")
	else:
		print("POLICY PARITY OK — %d forward passes matched bit-for-bit across %s"
				% [checked, ", ".join(ACTS)])
	get_tree().quit(0)
