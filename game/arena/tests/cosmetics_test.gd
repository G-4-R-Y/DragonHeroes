# ARENA TEST — ProtoCosmetics smoke gate. Attaches all three cosmetic types
# (aura + necklace + weapon) to a dummy Node2D WITH a `sprite` AnimatedSprite2D
# child and to a sprite-less node (attach must not crash without it), pulses
# the weapon 3x, runs ~90 frames, then asserts the node count never changed
# after warmup (the zero-per-frame-allocation contract) and detach() frees
# cleanly. Bare-root pattern:
#   godot --headless --path game res://arena/tests/cosmetics_test.tscn --quit-after 140
# Prints COSMETICS OK + quit(0); push_error + quit(1) on any breach.
extends Node2D

var _frame := 0
var _baseline := -1
var _h1: Node2D
var _h2: Node2D
var _done := false

func _ready() -> void:
	ProtoFx.intensity = 1.0               # HIGH ceiling: all 3 beads live
	var host1 := Node2D.new()
	host1.name = "Host1"
	add_child(host1)
	var spr := AnimatedSprite2D.new()     # the wearer pattern: `sprite` child
	spr.name = "sprite"
	spr.flip_h = true                     # exercise the weapon flip path
	host1.add_child(spr)
	_h1 = ProtoCosmetics.attach(host1,
			{"aura": "umbral", "necklace": "umbral", "weapon": "umbral"})
	var host2 := Node2D.new()             # sprite-less: must not crash
	host2.name = "Host2"
	add_child(host2)
	_h2 = ProtoCosmetics.attach(host2,
			{"aura": "blood", "necklace": "storm", "weapon": "fire"})
	if _h1 == null or _h2 == null:
		_fail("attach returned null")

func _process(_dt: float) -> void:
	if _done:
		return
	_frame += 1
	match _frame:
		10:
			_baseline = _count(get_tree().root)
		30, 50, 70:                       # pulse 3x while the count is watched
			ProtoCosmetics.pulse(_h1)
			ProtoCosmetics.pulse(_h2)
		85:
			if _count(get_tree().root) != _baseline:
				_fail("node count drifted: %d -> %d (per-frame allocation?)"
						% [_baseline, _count(get_tree().root)])
			ProtoCosmetics.detach(_h2)
		95:
			if is_instance_valid(_h2):
				_fail("detach did not free the rig")
			if not is_instance_valid(_h1) or _h1.get_parent() == null:
				_fail("live rig lost its parent")
			if _h1.get_node_or_null(".") == null:
				_fail("rig corrupt")
			_done = true
			print("COSMETICS OK")
			get_tree().quit(0)

func _count(n: Node) -> int:
	var c := 1
	for ch in n.get_children():
		c += _count(ch)
	return c

func _fail(msg: String) -> void:
	_done = true
	push_error("COSMETICS FAIL: " + msg)
	get_tree().quit(1)
