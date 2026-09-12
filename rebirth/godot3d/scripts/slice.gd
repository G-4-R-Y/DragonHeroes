# REBIRTH / Godot 3D — vertical slice root (rebirth/docs/01-plan.md §4):
# one hunter, one legendary dragon, one valley, one pet; kill → legendary drop
# toast → rematch. Everything is code-built here; no editor scenes to diff.
#
# Modes (env):
#   (none)                    play: keyboard+mouse
#   REBIRTH_SELFTEST=1        headless gate with the autopilot (see selftest.gd)
#   REBIRTH_CAPTURE=<tag>     windowed: autopilot plays, saves captures/rebirth_<tag>.png, quits
#   REBIRTH_CAPTURE_FRAMES=N  frame to shoot at (default 240)
#   REBIRTH_FORCE_SKILL=id    dragon opens with this skill (capture composition)
#   REBIRTH_CAPTURE_EVENT=enrage|slain|tele:<skill>  shoot 0.5 s after the event (tele: as the aim locks) instead of at frame N
#   REBIRTH_CAPTURE_DELAY=s  seconds after the event to shoot (default 0.5; 0 for tele:)
extends Node3D

const DROPS := ["Cinderscale Fang", "Ember-Heart Core", "Wyrmking's Talon", "Ashen Wing Membrane"]
const HUNTER_SPAWN := Vector3(0.0, 0.0, 16.0)
const DRAGON_SPAWN := Vector3(0.0, 0.0, -8.0)

var mode := "play"
var state := "fight"     # fight | drop | dead
var kills := 0
var valley: RbValley
var fx: RbFx
var hunter: RbHunter
var dragon: RbDragon
var pet: RbPet
var cam: RbCameraRig
var hud: RbHud
var autopilot: RbAutopilot
var _state_t := 0.0
var _drop_light: OmniLight3D
var _frames := 0
var _time := 0.0
var _capture_at := 240
var _capture_event := ""
var _capture_event_t := -1.0
var _capture_delay := -1.0
var _phys_ms_acc := 0.0
var _phys_ticks := 0

func _ready() -> void:
	RbInput.setup()
	if OS.get_environment("REBIRTH_SELFTEST") != "":
		mode = "selftest"
	elif OS.get_environment("REBIRTH_CAPTURE") != "":
		mode = "capture"
		if OS.get_environment("REBIRTH_CAPTURE_FRAMES") != "":
			_capture_at = int(OS.get_environment("REBIRTH_CAPTURE_FRAMES"))
		_capture_event = OS.get_environment("REBIRTH_CAPTURE_EVENT")
		if OS.get_environment("REBIRTH_CAPTURE_DELAY") != "":
			_capture_delay = float(OS.get_environment("REBIRTH_CAPTURE_DELAY"))
		# Deterministic capture size regardless of the window manager (an enrage shot once came out 1858x1016).
		DisplayServer.window_set_size(Vector2i(1280, 720))
	print("rebirth3d: renderer=%s mode=%s" % [RenderingServer.get_current_rendering_method(), mode])
	_build_environment()
	valley = RbValley.new()
	valley.name = "Valley"
	add_child(valley)
	valley.build()
	fx = RbFx.new()
	fx.name = "Fx"
	fx.valley = valley
	add_child(fx)
	dragon = RbDragon.new()
	dragon.name = "Dragon"
	add_child(dragon)
	hunter = RbHunter.new()
	hunter.name = "Hunter"
	add_child(hunter)
	pet = RbPet.new()
	pet.name = "Pet"
	add_child(pet)
	dragon.setup(hunter, valley, fx, DRAGON_SPAWN)
	hunter.setup(valley, fx, dragon, HUNTER_SPAWN)
	pet.setup(hunter, dragon, valley, fx)
	dragon.slain.connect(_on_dragon_slain)
	hunter.died.connect(_on_hunter_died)
	cam = RbCameraRig.new()
	cam.name = "CameraRig"
	cam.target = hunter
	cam.valley = valley
	add_child(cam)
	cam.yaw = atan2(HUNTER_SPAWN.x - DRAGON_SPAWN.x, HUNTER_SPAWN.z - DRAGON_SPAWN.z)
	hud = RbHud.new()
	hud.name = "Hud"
	hud.hunter = hunter
	hud.dragon = dragon
	hud.pet = pet
	hud.slice = self
	add_child(hud)
	_drop_light = OmniLight3D.new()
	_drop_light.light_color = Color(1.0, 0.85, 0.4)
	_drop_light.omni_range = 14.0
	_drop_light.light_energy = 0.0
	_drop_light.visible = false
	add_child(_drop_light)
	if OS.get_environment("REBIRTH_FORCE_SKILL") != "":
		dragon.force_next = OS.get_environment("REBIRTH_FORCE_SKILL")
	if mode != "play":
		autopilot = RbAutopilot.new(self)
	if mode == "selftest":
		var st := RbSelftest.new()
		st.name = "Selftest"
		add_child(st)
	elif mode == "play":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	print("rebirth3d: valley %d tris · glb dir %s" % [valley.tri_count, RbGlb.dir()])

func _build_environment() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.015, 0.02, 0.06)
	sm.sky_horizon_color = Color(0.06, 0.07, 0.15)
	sm.ground_bottom_color = Color(0.01, 0.01, 0.02)
	sm.ground_horizon_color = Color(0.05, 0.05, 0.1)
	sm.sun_angle_max = 8.0
	sm.sun_curve = 0.2
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.28, 0.32, 0.50)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.15
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.07, 0.14)
	env.fog_density = 0.010
	env.fog_sky_affect = 0.5
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.12
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	if RenderingServer.get_current_rendering_method() != "gl_compatibility":
		# Forward+ only (Ricardo's flip, never from an agent shell): volumetric
		# fog for the fire pits and SDFGI so the fields light the cliffs.
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = 0.02
		env.volumetric_fog_albedo = Color(0.6, 0.65, 0.8)
		env.sdfgi_enabled = true
		env.ssao_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	we.name = "WorldEnvironment"
	add_child(we)
	var moon := DirectionalLight3D.new()
	moon.name = "Moon"
	moon.rotation_degrees = Vector3(-48.0, 35.0, 0.0)
	moon.light_color = Color(0.55, 0.62, 0.88)
	moon.light_energy = 0.85
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 120.0
	add_child(moon)

func _unhandled_input(event: InputEvent) -> void:
	if mode != "play":
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		cam.orbit(event.relative.x, event.relative.y)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	var t0 := Time.get_ticks_usec()
	_time += delta
	_state_t += delta
	var intent: RbInput.Intent = autopilot.tick(delta) if autopilot != null else RbInput.poll()
	if intent.lock:
		if hunter.lock_target == null and dragon.state != "dead":
			hunter.lock_target = dragon
			cam.lock = dragon
		else:
			hunter.lock_target = null
			cam.lock = null
	if intent.rematch and state != "fight" and _state_t > 1.0:
		rematch()
	hunter.tick(intent, delta, cam.yaw)
	dragon.tick(delta)
	pet.tick(intent, delta)
	if state == "drop":
		_drop_light.light_energy = 2.5 + sin(_state_t * 6.0) * 1.2
		if _state_t > 2.5:
			hud.prompt = "R — REMATCH"
	_phys_ms_acc += (Time.get_ticks_usec() - t0) / 1000.0
	_phys_ticks += 1

func _process(delta: float) -> void:
	_frames += 1
	valley.flicker(_time)
	cam.update(delta)
	if mode == "capture":
		if _capture_event != "":
			var fired := (_capture_event == "enrage" and dragon.enraged) or (_capture_event == "slain" and state == "drop") \
				or (_capture_event.begins_with("tele:") and dragon.state == "tele" and dragon.skill == _capture_event.substr(5) and dragon.telegraph_left <= 0.30)
			var wait := _capture_delay if _capture_delay >= 0.0 else (0.0 if _capture_event.begins_with("tele:") else 0.5)
			if fired and _capture_event_t < 0.0:
				_capture_event_t = 0.0
			elif _capture_event_t >= 0.0:
				_capture_event_t += delta
				if _capture_event_t >= wait:
					_capture()
					_capture_event = ""
					_capture_at = _frames   # quit two frames later via the frame path
		elif _frames == _capture_at:
			_capture()
		elif _frames == _capture_at + 2:
			get_tree().quit(0)

func _capture() -> void:
	var tag := OS.get_environment("REBIRTH_CAPTURE")
	var img := get_viewport().get_texture().get_image()
	var dir := ProjectSettings.globalize_path("res://captures")
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join("rebirth_%s.png" % tag)
	var err := img.save_png(path)
	print("rebirth3d: capture %s -> %s (%dx%d) · fps %d · phys avg %.2f ms/tick" % [
		"OK" if err == OK else "FAIL %d" % err, path, img.get_width(), img.get_height(), Engine.get_frames_per_second(), _phys_ms_acc / maxf(_phys_ticks, 1)])

func _on_dragon_slain() -> void:
	state = "drop"
	_state_t = 0.0
	kills += 1
	hunter.lock_target = null
	cam.lock = null
	var drop: String = DROPS[(kills - 1) % DROPS.size()]
	hud.show_toast("LEGENDARY DROP — %s" % drop, 4.0)
	hud.prompt = ""
	_drop_light.position = dragon.position + Vector3(0, 2.0, 0)
	_drop_light.visible = true
	fx.ring(dragon.position, 4.0, Color(1.0, 0.85, 0.3, 1.0), 1.2)
	fx.ring(dragon.position, 7.0, Color(1.0, 0.85, 0.3, 0.6), 1.6)
	fx.spark(dragon.position + Vector3(0, 2.5, 0), Color(1.0, 0.9, 0.5))
	print("rebirth3d: dragon slain at t=%.1fs · drop '%s' · hunter hp %.0f · avoids %d · max combo %d" % [_time, drop, hunter.hp, hunter.stats["iframe_avoids"], hunter.stats["max_combo"]])

func _on_hunter_died() -> void:
	state = "dead"
	_state_t = 0.0
	hud.show_toast("SLAIN BY THE WYRM", 3.0)
	hud.prompt = "R — TRY AGAIN"
	print("rebirth3d: hunter slain at t=%.1fs · dragon hp %.0f · last skill %s" % [_time, dragon.hp, dragon.skill])

func rematch() -> void:
	state = "fight"
	_state_t = 0.0
	hud.prompt = ""
	hud.toast = ""
	_drop_light.visible = false
	_drop_light.light_energy = 0.0
	fx.clear_all()
	dragon.reset()
	hunter.reset()
	pet.reset()
	if autopilot != null:
		hunter.lock_target = dragon
		cam.lock = dragon
	print("rebirth3d: rematch #%d" % kills)
