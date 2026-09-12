# REBIRTH / Godot 3D — third-person camera. Free orbit (mouse) or lock-on
# framing (camera settles behind the hunter, looks at a point between hunter
# and dragon, backs off as the dragon gets far). Smooth, never inside terrain.
class_name RbCameraRig
extends Node3D

var cam: Camera3D
var yaw := 0.0
var pitch := -0.30
var dist := 7.5
var target: Node3D
var lock: Node3D
var valley: RbValley
var _pos := Vector3.ZERO
var _focus := Vector3.ZERO
var _started := false

func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = 62.0
	cam.near = 0.1
	cam.far = 400.0
	cam.current = true
	add_child(cam)

func orbit(dx: float, dy: float) -> void:
	yaw -= dx * 0.0035
	pitch = clampf(pitch - dy * 0.0035, -1.15, 0.30)

func update(delta: float) -> void:
	if target == null:
		return
	var focus := target.position + Vector3(0.0, 1.6, 0.0)
	var d := dist
	var p := pitch
	if lock != null:
		var to := lock.position - target.position
		to.y = 0.0
		var back := -to.normalized()
		var want := atan2(back.x, back.z)
		yaw = lerp_angle(yaw, want, 1.0 - exp(-delta * 4.0))
		focus = target.position + to * 0.22 + Vector3(0.0, 1.8, 0.0)
		d = 7.5 + clampf(to.length() * 0.12, 0.0, 4.0)
		p = -0.30
	var back_dir := Vector3(sin(yaw), 0.0, cos(yaw))
	var want_pos := focus + back_dir * d * cos(p) + Vector3.UP * (-sin(p)) * d
	var ground := valley.height_at(want_pos.x, want_pos.z) + 0.7 if valley != null else -1000.0
	want_pos.y = maxf(want_pos.y, ground)
	if not _started:
		_pos = want_pos
		_focus = focus
		_started = true
	_pos = _pos.lerp(want_pos, 1.0 - exp(-delta * 9.0))
	_focus = _focus.lerp(focus, 1.0 - exp(-delta * 12.0))
	cam.position = _pos
	cam.look_at(_focus, Vector3.UP)

func forward_flat() -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))

func right_flat() -> Vector3:
	return Vector3(cos(yaw), 0.0, -sin(yaw))
