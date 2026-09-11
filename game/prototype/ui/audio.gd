# Audio settings (Ricardo, 2026-09-11: "a settings option to control audio —
# mute songs and effects"). Two buses, "Music" and "SFX", created in code the
# first time anything asks (the project has no bus-layout resource: every sound
# is synthesized, sfx.gd), each with a persisted ON/OFF + linear volume in
# user://settings.json under "audio" — the same file as display + language.
# Applied at every boot (menu AND direct scene boots), idempotent. There is no
# music in the slice yet; the Music bus is where it will play, so the switch
# exists on day one and nothing has to be retrofitted.
class_name ProtoAudio

const PATH := "user://settings.json"
const BUSES := ["Music", "SFX"]
const KINDS := {"music": "Music", "sfx": "SFX"}
const DEFAULTS := {"music": true, "sfx": true, "music_vol": 1.0, "sfx_vol": 1.0}

# Buses by name, so AudioStreamPlayer.bus = "SFX" resolves before the first play
# (an unknown bus name silently falls back to Master).
static func ensure_buses() -> void:
	for bus_name in BUSES:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus_name)
			AudioServer.set_bus_send(i, "Master")

static func apply_saved() -> void:
	ensure_buses()
	var a := current()
	for kind in KINDS:
		_apply_bus(str(KINDS[kind]), bool(a[kind]), float(a[kind + "_vol"]))

static func _apply_bus(bus_name: String, on: bool, vol: float) -> void:
	var i := AudioServer.get_bus_index(bus_name)
	if i < 0:
		return
	AudioServer.set_bus_mute(i, not on)
	AudioServer.set_bus_volume_db(i, linear_to_db(clampf(vol, 0.0001, 1.0)))

# Saved values over defaults — always a complete dictionary.
static func current() -> Dictionary:
	var a := DEFAULTS.duplicate()
	a.merge(_load(), true)
	return a

static func is_on(kind: String) -> bool:
	return bool(current().get(kind, true))

static func set_on(kind: String, on: bool) -> void:
	if not KINDS.has(kind):
		return
	var a := current()
	a[kind] = on
	_save(a)
	apply_saved()

# Flip music|sfx; returns the new state (what the button shows).
static func toggle(kind: String) -> bool:
	var on := not is_on(kind)
	set_on(kind, on)
	return on

static func set_volume(kind: String, vol: float) -> void:
	if not KINDS.has(kind):
		return
	var a := current()
	a[kind + "_vol"] = clampf(vol, 0.0, 1.0)
	_save(a)
	apply_saved()

static func _load() -> Dictionary:
	if FileAccess.file_exists(PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary and (parsed as Dictionary).get("audio") is Dictionary:
			return (parsed as Dictionary)["audio"]
	return {}

# Rewrites only the "audio" key; display + language keys survive.
static func _save(audio: Dictionary) -> void:
	var root := {}
	if FileAccess.file_exists(PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary:
			root = parsed
	root["audio"] = audio
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(root, "  "))
		f.close()
