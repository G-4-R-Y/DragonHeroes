# One window-fitting rule for every cockpit (arena, genforge).
#
# A console is a dense text UI in a game whose project canvas is 640x360
# (project.godot window/size/viewport_*) with integer stretch. Left alone it
# renders at that canvas, which is ~90 logical px shorter than a console's own
# content — the panels at the bottom run off the screen. Ricardo, 2026-09-14:
# "console design is bloated and overflowing".
#
# So a console picks its own canvas from the usable screen rect. On a 1080p
# desktop that is 1600x900 halved to an 800x450 canvas: the pixel typography
# reads at menu size instead of 1:1 dots, and the console still gets 450 logical
# px of height to lay out in.
#
# The fallback matters more than the table. The arena console's first version
# walked the candidate list and simply ENDED when nothing fit, leaving the
# project default in place — the one canvas that overflows. A small or
# oddly-reported screen must still land on a real canvas derived from the rect
# it was given.
class_name DhConsoleFit

const CANDIDATES := [Vector2i(1600, 900), Vector2i(1440, 810), Vector2i(1280, 720),
		Vector2i(1152, 648), Vector2i(1024, 576), Vector2i(960, 540)]
const MIN_CANVAS := Vector2i(640, 360)
# below this the roster column cannot hold its rows, so do not halve the canvas
const HALVE_ABOVE := 420

static func apply(w: Window) -> void:
	if w == null or DisplayServer.get_name() == "headless":
		return
	var usable := DisplayServer.screen_get_usable_rect(w.current_screen)
	for cand in CANDIDATES:
		if cand.x <= usable.size.x - 24 and cand.y <= usable.size.y - 96:
			var k := 2 if cand.y / 2 >= HALVE_ABOVE else 1
			w.content_scale_size = cand / k
			w.size = cand
			w.position = usable.position + (usable.size - cand) / 2
			return
	var fit := Vector2i(maxi(usable.size.x - 24, MIN_CANVAS.x),
			maxi(usable.size.y - 96, MIN_CANVAS.y))
	w.content_scale_size = fit
	w.size = Vector2i(mini(fit.x, usable.size.x), mini(fit.y, usable.size.y))
	w.position = usable.position + (usable.size - w.size) / 2

# Every canvas apply() can land on, smallest first — what a layout probe must
# walk. MIN_CANVAS is in the list because it is the fallback nobody chooses.
static func every_canvas() -> Array:
	var out: Array = [MIN_CANVAS]
	for entry in CANDIDATES:
		var cand: Vector2i = entry
		var k := 2 if cand.y / 2 >= HALVE_ABOVE else 1
		var canvas := cand / k
		if not out.has(canvas):
			out.append(canvas)
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y)
	return out
