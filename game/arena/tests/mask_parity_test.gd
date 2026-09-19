# ARENA TEST — arena.mask.v1 decodes the SAME way here as in Python.
#
# The action mask (neural_policy.gd::action_mask / decode) is one rule in five
# runtimes. Python pins its own runtimes in ml/tests/test_action_mask.py and
# writes the cases to fixtures/action_mask_v1.json; this reads them back and
# runs the GDScript twin over every one. A mismatch means the arena would spend
# a deployed net differently from the trainer that produced it.
#
#   godot --headless --path game res://arena/tests/mask_parity_test.tscn --quit-after 20
#
# Prints MASK PARITY OK + quit(0); push_error + quit(1) on any mismatch.
extends Node2D

const FIXTURE := "res://arena/tests/fixtures/action_mask_v1.json"

func _fail(msg: String) -> void:
	push_error("MASK PARITY FAILED — " + msg)
	get_tree().quit(1)

func _ready() -> void:
	var raw := FileAccess.get_file_as_string(FIXTURE)
	var data: Variant = JSON.parse_string(raw) if not raw.is_empty() else null
	if not (data is Dictionary) or str(data.get("schema", "")) != "arena.mask.v1":
		_fail("fixture missing or wrong schema: " + FIXTURE)
		return
	if int(data.get("action_logits", 0)) != ArenaPolicy.ACTION_LOGITS \
			or int(data.get("obs_dim", 0)) != ArenaPolicy.OBS_DIM:
		_fail("fixture shape %s/%s vs runtime %d/%d" % [data.get("action_logits"),
				data.get("obs_dim"), ArenaPolicy.ACTION_LOGITS, ArenaPolicy.OBS_DIM])
		return
	var n := 0
	for c in data["cases"]:
		var obs := PackedFloat32Array()
		for v in c["obs"]:
			obs.append(float(v))
		var y := PackedFloat64Array()
		for v in c["y"]:
			y.append(float(v))
		var kit_count := int(c["kit_count"])
		var is_player := bool(c["is_player"])
		var allowed := ArenaNeuralPolicy.action_mask(obs, kit_count, is_player)
		for i in allowed.size():
			if allowed[i] != bool(c["allowed"][i]):
				_fail("'%s': allowed[%d] %s vs Python %s" % [c["label"], i, allowed[i], c["allowed"][i]])
				return
		var dec := ArenaNeuralPolicy.decode(y, obs, kit_count, is_player)
		if int(dec[0]) != int(c["pick"]) or bool(dec[1]) != bool(c["dodge"]):
			_fail("'%s': pick %d dodge %s vs Python pick %d dodge %s"
					% [c["label"], int(dec[0]), bool(dec[1]), int(c["pick"]), bool(c["dodge"])])
			return
		if ArenaNeuralPolicy.dodge_allowed(obs) != (float(obs[12]) > 0.0):
			_fail("'%s': dodge_allowed drifted" % c["label"])
			return
		n += 1
	print("MASK PARITY OK — %d cases decode exactly as ml/tests/test_action_mask.py" % n)
	get_tree().quit(0)
