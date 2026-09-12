# REBIRTH / Godot 3D — input contract. A controller (keyboard+mouse or the
# autopilot) produces an Intent per tick; the hunter consumes it. Inputs are
# DATA, never engine callbacks — the same shape dh-sim expects from a client.
class_name RbInput
extends RefCounted

class Intent:
	var move := Vector2.ZERO   # camera-relative: x = strafe right, y = forward
	var dodge := false
	var attack := false
	var skill := false
	var pet := false
	var lock := false
	var rematch := false

const ACTIONS := {
	"rb_forward": [KEY_W, KEY_UP],
	"rb_back": [KEY_S, KEY_DOWN],
	"rb_left": [KEY_A, KEY_LEFT],
	"rb_right": [KEY_D, KEY_RIGHT],
	"rb_dodge": [KEY_SPACE, KEY_SHIFT],
	"rb_attack": [KEY_J],
	"rb_skill": [KEY_K],
	"rb_pet": [KEY_E],
	"rb_lock": [KEY_TAB, KEY_Q],
	"rb_rematch": [KEY_R],
}
const MOUSE := {"rb_attack": MOUSE_BUTTON_LEFT, "rb_skill": MOUSE_BUTTON_RIGHT, "rb_lock": MOUSE_BUTTON_MIDDLE}

static func setup() -> void:
	for a: String in ACTIONS.keys():
		if not InputMap.has_action(a):
			InputMap.add_action(a)
		for k: int in ACTIONS[a]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k as Key
			InputMap.action_add_event(a, ev)
	for a: String in MOUSE.keys():
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE[a] as MouseButton
		InputMap.action_add_event(a, mb)

static func poll() -> Intent:
	var i := Intent.new()
	i.move = Input.get_vector("rb_left", "rb_right", "rb_back", "rb_forward")
	i.dodge = Input.is_action_just_pressed("rb_dodge")
	i.attack = Input.is_action_just_pressed("rb_attack")
	i.skill = Input.is_action_just_pressed("rb_skill")
	i.pet = Input.is_action_just_pressed("rb_pet")
	i.lock = Input.is_action_just_pressed("rb_lock")
	i.rematch = Input.is_action_just_pressed("rb_rematch")
	return i
