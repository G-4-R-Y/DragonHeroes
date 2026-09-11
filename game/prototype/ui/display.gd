# Display settings (canon §12.38): windowed vs borderless fullscreen, and
# integer (crisp pixels, possible letterbox) vs FRACTIONAL fit (fills any
# screen, pixels go slightly non-uniform at non-integer scales). Persisted in
# user://settings.json next to the language; applied at every boot (idempotent,
# so direct scene boots and the menu see the same frame).
class_name ProtoDisplay

const PATH := "user://settings.json"
const MODES := ["windowed", "fullscreen"]
const SCALES := ["integer", "fit"]

static func apply_saved() -> void:
	var d := _load()
	apply(str(d.get("mode", "windowed")), str(d.get("scale", "integer")))

static func apply(mode: String, scale: String) -> void:
	var w := (Engine.get_main_loop() as SceneTree).root.get_window()
	w.mode = Window.MODE_FULLSCREEN if mode == "fullscreen" else Window.MODE_WINDOWED
	w.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_INTEGER \
			if scale == "integer" else Window.CONTENT_SCALE_STRETCH_FRACTIONAL
	if DisplayServer.get_name() != "headless":
		fit_windowed(w)

# Windowed fit (canon §12.38): the largest INTEGER scale of the 640x360 base
# that fits the usable screen rect (minus chrome), centered. The default
# 1280x720 override overflowed smaller screens — UI ended up outside the glass.
static func fit_windowed(w: Window) -> void:
	if w.mode != Window.MODE_WINDOWED:
		return
	var usable := DisplayServer.screen_get_usable_rect(w.current_screen)
	var s := maxi(1, mini((usable.size.x - 16) / 640, (usable.size.y - 96) / 360))
	w.size = Vector2i(640, 360) * s
	w.position = usable.position + (usable.size - w.size) / 2

static func current() -> Dictionary:
	return _load()

static func cycle_mode() -> String:
	var d := _load()
	var next := str(MODES[(MODES.find(str(d.get("mode", "windowed"))) + 1) % MODES.size()])
	d["mode"] = next
	_save(d)
	apply_saved()
	return next

static func cycle_scale() -> String:
	var d := _load()
	var next := str(SCALES[(SCALES.find(str(d.get("scale", "integer"))) + 1) % SCALES.size()])
	d["scale"] = next
	_save(d)
	apply_saved()
	return next

static func _load() -> Dictionary:
	if FileAccess.file_exists(PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary:
			return parsed.get("display", {})
	return {}

static func _save(display: Dictionary) -> void:
	var root := {}
	if FileAccess.file_exists(PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary:
			root = parsed
	root["display"] = display
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(root, "  "))
		f.close()
