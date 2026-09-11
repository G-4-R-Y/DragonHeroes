# MENU BOOT GATE: instantiates the real main scene (prototype/ui/main_menu.tscn)
# and asserts it BUILT — its script compiled (a dependency parse error takes
# main_menu.gd down with "Failed to compile depended scripts" and the game boots
# to an empty window with the menu's methods missing) and the class/enter/co-op/
# display buttons exist. 2026-09-11: display.gd's two `var next := ARRAY[i]`
# inferences were a fatal parse error for 9 days and no gate saw it — the click
# test never loads the menu. Run:
#   godot --headless --path game res://prototype/tests/menu_probe.tscn
# Ends MENU OK or MENU FAIL (+ detail), exit 0/1.
extends Node

var _frames := 0
var _menu: Node = null

func _ready() -> void:
	var ps: PackedScene = load("res://prototype/ui/main_menu.tscn")
	if ps == null:
		_verdict(false, "main_menu.tscn failed to load")
		return
	_menu = ps.instantiate()
	add_child(_menu)

func _process(_delta: float) -> void:
	_frames += 1
	if _frames < 20 or _menu == null:
		return
	set_process(false)
	# the compile-failure signature: the script is attached but has no methods
	if not _menu.has_method("_build"):
		_verdict(false, "main_menu.gd did not compile (no _build) — check its dependencies")
		return
	var buttons := _menu.find_children("*", "Button", true, false)
	var edits := _menu.find_children("*", "LineEdit", true, false)
	# _build ends with the display controls (MODE / FIT); a dependency that fails
	# to compile aborts _build mid-way with a runtime "Nonexistent function" —
	# the menu LOOKS fine minus its last controls, so assert they are all there
	var texts := " ".join(buttons.map(func(b: Variant) -> String: return str((b as Button).text).to_upper()))
	var missing: PackedStringArray = []
	for want in ["MODE", "FIT", "ENTER", "CO-OP", "LANGUAGE"]:
		if texts.find(want) < 0:
			missing.append(want)
	if not missing.is_empty():
		_verdict(false, "menu built %d buttons but is missing %s — _build aborted (dependency script error?)" % [
				buttons.size(), ", ".join(missing)])
		return
	if edits.size() < 2:
		_verdict(false, "menu has %d text fields (want name + password)" % edits.size())
		return
	_verdict(true, "%d buttons incl. MODE/FIT/ENTER/CO-OP/LANGUAGE, %d fields, script compiled" % [
			buttons.size(), edits.size()])

func _verdict(ok: bool, detail: String) -> void:
	print(("MENU OK — " if ok else "MENU FAIL — ") + detail)
	get_tree().quit(0 if ok else 1)
