# ARENA PROBE — does the cockpit actually FIT the canvas it is rendered into?
#
# Ricardo, 2026-09-14: "graph overflows from the rendered screen." _fit_window
# picks 1600x900 on a 1080p desktop and then halves the canvas to 800x450 for
# legible pixel typography, so the console's real budget is 450 logical pixels
# tall — not 900. This walks the PROGRESS column at every canvas _fit_window can
# choose and reports any child whose rect leaves its parent.
#
#   godot --headless --path game res://arena/tests/console_layout_probe.tscn --quit-after 300
#
# The root is a Control anchored FULL_RECT, and that matters: a Control parented
# to a Node2D has no rect to anchor against, so the console lays out at its
# CONTENT minimum and every measurement below is a fiction. The first version of
# this probe did exactly that and reported a chart stuck at 120 px on an 810 px
# canvas — the harness was the bug, not the console.
extends Control

# every (cand / k) _fit_window can land on, smallest first
# 640x360 is FIRST because it is the one nobody chose: it is the project default
# (project.godot window/size/viewport_*), and _fit_window's candidate loop can
# fall through without setting anything — every candidate needs usable height
# >= 636 — leaving the console on a canvas 90 logical px shorter than its own
# content. The rest are what _fit_window can actually pick.
const CANVASES := [Vector2i(640, 360), Vector2i(800, 450), Vector2i(960, 540),
		Vector2i(1024, 576), Vector2i(1152, 648), Vector2i(1280, 720), Vector2i(1440, 810)]

var _last_canvas_h := 0
var _last_chart_h := 0.0

func _ready() -> void:
	var bad: Array = []
	for canvas in CANVASES:
		var w := get_window()
		w.content_scale_size = canvas
		w.size = canvas
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var console: Control = load("res://arena/console.gd").new()
		console.set("_selftest", true)          # no window fitting, no BACK button
		add_child(console)
		console.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for _i in 4:
			await get_tree().process_frame     # containers settle over a frame or two
		_load_it_up(console)
		for _i in 4:
			await get_tree().process_frame
		# EVERY tab, not just the one that happens to be open: a TabContainer does
		# not lay out the tabs you are not looking at, so a tab can only be
		# measured while it is the visible one.
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
			over += rows.filter(func(r: Dictionary) -> bool: return r.over > 0.5)
		print("canvas %dx%d — %d control(s) overflow across %s" % [
				canvas.x, canvas.y, over.size(), str(names)])
		for r in over:
			print("    %-40s bottom %.0f > %.0f  (over by %.0f)" % [
					r.path, r.bottom, r.limit, r.over])
		if not over.is_empty():
			bad.append(canvas)
		if tabs != null:
			tabs.current_tab = 0
			for _j in 3:
				await get_tree().process_frame
		if not _check_progress(console, canvas):
			bad.append(canvas)
		console.queue_free()
		await get_tree().process_frame
	if bad.is_empty():
		print("CONSOLE LAYOUT OK — the cockpit fits every canvas _fit_window can pick")
		get_tree().quit(0)
	else:
		push_error("CONSOLE LAYOUT FAILED — overflows at %s" % str(bad))
		get_tree().quit(1)

# Every VISIBLE Control that ends below the canvas. Two things are not overflow
# and must not be reported as it: a hidden tab (TabContainer never lays out the
# tabs you are not looking at, so their rects are meaningless), and anything
# inside a ScrollContainer (growing past the viewport is the entire point of one).
# What is left is real: pixels drawn off the bottom of Ricardo's screen.
func _walk(node: Node, canvas: Vector2i, path := "") -> Array:
	var out: Array = []
	for child in node.get_children():
		if not (child is Control):
			continue
		var c: Control = child
		if not c.is_visible_in_tree():
			continue
		var label: String = path + "/" + (String(c.name) if String(c.name) != "" else c.get_class())
		var bottom := c.global_position.y + c.size.y
		out.append({"path": label.substr(maxi(0, label.length() - 40)),
				"bottom": bottom, "limit": float(canvas.y),
				"over": bottom - float(canvas.y)})
		if not (c is ScrollContainer):
			out += _walk(c, canvas, label)
	return out


# What the PROGRESS column actually got, and what the chart's own draw routine
# would touch. draw_string is NOT clipped to a Control's rect unless
# clip_contents is on, so a chart that draws past its own height bleeds over its
# neighbours and, at the bottom of the column, off the screen.
func _check_progress(console: Control, canvas: Vector2i) -> bool:
	var chart: Control = console.get("_chart")
	var strip: Control = console.get("_strip")
	if chart == null or strip == null:
		push_error("CONSOLE LAYOUT: no chart/strip to measure")
		return false
	var ok := true
	var font := ThemeDB.fallback_font
	var line_h := font.get_ascent(ProtoTheme.SIZE_BODY) + font.get_descent(ProtoTheme.SIZE_BODY)
	var sz := chart.size

	# 1. the chart is the column's only expanding child, so it must absorb every
	#    pixel the canvas grows by. If it ever stops tracking, something below it
	#    started expanding too and the chart is being starved.
	if _last_canvas_h > 0 and canvas.y > _last_canvas_h:
		var grew := sz.y - _last_chart_h
		var expected := float(canvas.y - _last_canvas_h)
		if grew < expected - 1.0:
			ok = false
			push_error("CONSOLE LAYOUT: canvas grew %.0f px but the chart only grew %.0f" % [
					expected, grew])
	_last_canvas_h = canvas.y
	_last_chart_h = sz.y

	# 2. the x-tick row must land inside the chart — baseline plus descent.
	var b := sz.y - line_h - 3.0
	var text_bottom := b + font.get_ascent(ProtoTheme.SIZE_BODY) + 2.0 \
			+ font.get_descent(ProtoTheme.SIZE_BODY)
	if text_bottom > sz.y:
		ok = false
		push_error("CONSOLE LAYOUT: x-tick text ends %.1f px past the chart (h %.1f)" % [
				text_bottom - sz.y, sz.y])

	# 3. and clipping is the backstop for every label this probe does not model.
	if not chart.clip_contents or not strip.clip_contents:
		ok = false
		push_error("CONSOLE LAYOUT: clip_contents chart=%s strip=%s — draw_string escapes" % [
				chart.clip_contents, strip.clip_contents])
	var col: Control = chart.get_parent()
	var tabs: Control = col.get_parent()
	print("    PROGRESS col h=%.0f (flags v=%d)  tabs h=%.0f  hb h=%.0f" % [
			col.size.y, col.size_flags_vertical, tabs.size.y, tabs.get_parent().size.y])
	print("    chart h=%.0f (floor %.0f)  strip y=%.0f  ticks inside by %.1f px" % [
			sz.y, chart.custom_minimum_size.y, strip.global_position.y,
			sz.y - text_bottom])
	return ok


func _find_tabs(node: Node) -> TabContainer:
	for child in node.get_children():
		if child is TabContainer:
			return child
		var found := _find_tabs(child)
		if found != null:
			return found
	return null


# An EMPTY cockpit fits anything — that is not the console Ricardo is looking at.
# Every panel here is an autowrapping Label with a custom_minimum_size: the
# minimum is a FLOOR, not a ceiling, so real text grows them and the column with
# them. This puts the longest strings the console actually produces into each one
# and a full run's worth of points into the chart.
func _load_it_up(console: Control) -> void:
	var run := {"start": {"key": "gloamfen_stalker", "build": "core.arena.gloamfen_stalker",
			"generations": 200, "pop": 10, "episodes": 6, "jobs": 16, "speed": "max",
			"opponents": [["core.arena.fen_boar_alpha", "native"],
					["core.arena.dusk_revenant", "scripted"]], "warm_start": 4},
		"gens": [], "cands": [], "scores": [], "matches": 0, "dur_sum": 0.0, "dur_n": 0,
		"cur_g": 199, "cur_cand": 9, "last_match": {}, "registered": {}, "gate": {},
		"error": "", "last_t": 0.0, "unknown": 0, "versus": {}, "versus_done": {}}
	for g in 200:
		# fitness shaping runs well outside 0..1; that is what widens the y axis
		run.gens.append({"g": g, "best": 0.9 - float(g) * 0.004, "mean": -2.6 + float(g) * 0.01})
	for k in 10:
		run.cands.append({"g": 199, "cand": k, "fitness": -3.1 + float(k) * 0.4})
	console.set("_run", run)
	var status: Label = console.get("_status")
	var note: Label = console.get("_note")
	var gate: Label = console.get("_gate_label")
	if status != null:
		status.text = ("gloamfen_stalker · core.arena.gloamfen_stalker · g199/200 · "
				+ "cand 9/10 · 3,980/4,000 matches · 16 jobs · speed max · "
				+ "warm-started from v4 · ETA 0:41")
	if note != null:
		note.text = ("train started · pid 484213 · ml/runs/2026-09-14_0133__gloamfen_stalker"
				+ "-console__g200_p10_e6_j16_s2026 — DH_SERVING_DIR is the run folder, "
				+ "ml/serving is untouched until you PROMOTE")
	if gate != null:
		gate.text = ("GATE v12: native 0.58 (PASS, 4 eps) · scripted 0.71 (PASS, 4 eps) · "
				+ "deployed v11 0.49 (FAIL, needs > 0.55) — candidate held, "
				+ "run `league gate --key gloamfen_stalker` to retry")
	if console.has_method("_refresh_ui"):
		console.call("_refresh_ui")
