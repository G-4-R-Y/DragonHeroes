# GENFORGE PROBE — does the assets cockpit fit the canvas it is rendered into?
#
# Ricardo, 2026-09-14: "assets generation console not working properly: console
# design is bloated and overflowing". It was. The arena cockpit had a layout gate
# (arena/tests/console_layout_probe.tscn) and this one had none, which is exactly
# why nobody noticed: it was a flat two-column Control with no window fitting, no
# scrolling and no tabs, laid out at whatever canvas the project default gave it.
#
#   godot --headless --path game res://genforge/tests/console_layout_probe.tscn --quit-after 300
#
# BOTH AXES, and text as well as boxes: a Label that does not wrap reports its
# whole sentence as a minimum width, and that minimum propagates up to the root.
#
# The root here is a Control anchored FULL_RECT and that matters — a Control
# parented to a Node2D has no rect to anchor against, so the console would lay
# out at its content minimum and every number below would be a fiction.
extends Control

var CANVASES: Array = DhConsoleFit.every_canvas()

func _ready() -> void:
	var bad: Array = []
	var walked := 0
	var measured := 0
	for canvas in CANVASES:
		var w := get_window()
		w.content_scale_size = canvas
		w.size = canvas
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var console: Control = load("res://genforge/console.gd").new()
		console.set("_selftest", true)         # no window fitting, no BACK button
		add_child(console)
		console.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for _i in 4:
			await get_tree().process_frame
		_load_it_up(console)
		for _i in 4:
			await get_tree().process_frame
		# A TabContainer does not lay out the tabs you are not looking at, so a
		# tab can only be measured while it is the visible one.
		var tabs: TabContainer = _find_tabs(console)
		var names: Array = []
		var over: Array = []
		for ti in (tabs.get_tab_count() if tabs != null else 1):
			if tabs != null:
				tabs.current_tab = ti
				names.append(tabs.get_tab_title(ti))
				for _j in 3:
					await get_tree().process_frame
			var rows := _walk(console, canvas)
			measured += rows.size()
			over += rows.filter(func(r: Dictionary) -> bool: return r.over > 0.5)
		walked += 1
		print("canvas %dx%d — %d control(s) overflow across %s" % [
				canvas.x, canvas.y, over.size(), str(names)])
		for r in over:
			print("    [%s] %-40s %.0f > %.0f  (over by %.0f)" % [
					r.axis, r.path, r.edge, r.limit, r.over])
		if not over.is_empty():
			bad.append(canvas)
		console.queue_free()
		await get_tree().process_frame
	# A gate that passes having measured NOTHING is worse than no gate.
	if walked < 4 or measured < 100:
		push_error("GENFORGE LAYOUT FAILED — the probe measured almost nothing "
				+ "(%d canvas(es), %d control(s)); it did not run, it broke" % [walked, measured])
		get_tree().quit(1)
		return
	if bad.is_empty():
		print("GENFORGE LAYOUT OK — %d canvases x %d controls, nothing leaves the canvas "
				% [walked, measured] + "on EITHER axis")
		get_tree().quit(0)
	else:
		push_error("GENFORGE LAYOUT FAILED — overflows at %s" % str(bad))
		get_tree().quit(1)

# Two things are not overflow and must not be reported as it: a hidden tab, and
# anything inside a ScrollContainer — growing past the viewport is the entire
# point of one. What is left is pixels drawn off Ricardo's screen.
func _walk(node: Node, canvas: Vector2i, path := "") -> Array:
	var out: Array = []
	for child in node.get_children():
		if not (child is Control):
			continue
		var c: Control = child
		if not c.is_visible_in_tree():
			continue
		var label: String = path + "/" + (String(c.name) if String(c.name) != "" else c.get_class())
		var short: String = label.substr(maxi(0, label.length() - 40))
		out.append({"path": short, "axis": "y", "edge": c.global_position.y + c.size.y,
				"limit": float(canvas.y),
				"over": (c.global_position.y + c.size.y) - float(canvas.y)})
		out.append({"path": short, "axis": "x", "edge": c.global_position.x + c.size.x,
				"limit": float(canvas.x),
				"over": (c.global_position.x + c.size.x) - float(canvas.x)})
		var text_w := _text_width(c)
		if text_w > 0.0:
			out.append({"path": short, "axis": "t", "edge": c.global_position.x + text_w,
					"limit": float(canvas.x),
					"over": (c.global_position.x + text_w) - float(canvas.x)})
		if not (c is ScrollContainer):
			out += _walk(c, canvas, label)
	return out

# How wide the text actually draws. Only for controls that neither wrap nor
# scroll: an autowrapping Label reflows and an ItemList may hold more than it shows.
func _text_width(c: Control) -> float:
	var font := ThemeDB.fallback_font
	var size := ProtoTheme.SIZE_BODY
	if c is Label:
		var l: Label = c
		if l.autowrap_mode != TextServer.AUTOWRAP_OFF or l.text == "":
			return 0.0
		if l.has_theme_font_size_override("font_size"):
			size = l.get_theme_font_size("font_size")
		return font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	if c is Button:
		var b: Button = c
		if b.text == "":
			return 0.0
		if b.has_theme_font_size_override("font_size"):
			size = b.get_theme_font_size("font_size")
		return font.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 12.0
	return 0.0

func _find_tabs(node: Node) -> TabContainer:
	for child in node.get_children():
		if child is TabContainer:
			return child
		var found := _find_tabs(child)
		if found != null:
			return found
	return null

# An EMPTY cockpit fits anything — that is not the console Ricardo is looking at.
# This loads the REAL catalog (the console's own _refresh shells out to
# tools/genforge.py) and then the longest strings it actually produces.
func _load_it_up(console: Control) -> void:
	if console.has_method("_refresh"):
		console.call("_refresh")
	if console.has_method("_check"):
		console.call("_check")
	if console.has_method("_review"):
		console.call("_review")
	var status: Label = console.get("_status")
	if status != null:
		status.text = ("fen_bells   NOT READY — 1 failure(s), 5 open item(s)\n"
				+ "genforge/candidates/living/fen_bells-edc214fa2d7bc032\n"
				+ "build fen_bells running · pid 484213 · ml/data/logs/genforge_console.log")
	var detail: Label = console.get("_detail")
	if detail != null:
		detail.text = ("approval: none — APPROVE records the human half, pinned to this "
				+ "bundle's content hash\n5 blocker(s) the build refused to clear")
	if console.has_method("_refresh_ui"):
		console.call("_refresh_ui")
