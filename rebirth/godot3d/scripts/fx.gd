# REBIRTH / Godot 3D — pooled VFX. Every telegraph ring/cone, fire field, meteor,
# spark and slash arc is allocated ONCE at boot and reused; a request that finds
# no free slot recycles the oldest and bumps `overflow` (the selftest asserts 0).
# Node-per-effect at boot, never per hit — the 2D game's pool doctrine (canon §12.19).
# Fire fields and meteors carry OmniLights: effects light the world (canon §12.27).
class_name RbFx
extends Node3D

const RINGS := 16
const CONES := 4
const FIELDS := 6
const METEORS := 8
const SPARKS := 10
const SLASHES := 3

var overflow := 0
var _rings: Array[Dictionary] = []
var _cones: Array[Dictionary] = []
var _fields: Array[Dictionary] = []
var _meteors: Array[Dictionary] = []
var _sparks: Array[Dictionary] = []
var _slashes: Array[Dictionary] = []
var _serial := 0
var valley: RbValley

func _ready() -> void:
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.965
	ring_mesh.outer_radius = 1.0
	# TorusMesh: `rings` = segments around the MAJOR circle (smoothness of the ring),
	# `ring_segments` = tube cross-section. 6/48 was the wrong way round: a hexagon with a round tube.
	ring_mesh.rings = 48
	ring_mesh.ring_segments = 6
	for i in RINGS:
		_rings.append(_pooled(ring_mesh, Color(1, 0.3, 0.1, 0.8), true))
	var cone_mesh := _sector_mesh(35.0)
	for i in CONES:
		_cones.append(_pooled(cone_mesh, Color(1, 0.35, 0.1, 0.45), true))
	var slash_mesh := _sector_mesh(45.0)
	for i in SLASHES:
		_slashes.append(_pooled(slash_mesh, Color(0.9, 0.95, 1.0, 0.7), true))
	for i in FIELDS:
		_fields.append(_make_field())
	for i in METEORS:
		_meteors.append(_make_meteor())
	for i in SPARKS:
		_sparks.append(_make_spark())

# --- construction -----------------------------------------------------------

func _pooled(mesh: Mesh, color: Color, additive: bool) -> Dictionary:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = color
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = true
	mi.material_override = m
	mi.visible = false
	add_child(mi)
	return {"node": mi, "mat": m, "active": false, "t": 0.0, "dur": 0.0, "color": color, "serial": 0, "base_alpha": color.a}

func _sector_mesh(half_deg: float) -> ArrayMesh:
	# unit flat fan on XZ, apex at origin, pointing -Z (Godot forward), y slightly up
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 16
	var a0 := deg_to_rad(-half_deg)
	var a1 := deg_to_rad(half_deg)
	for i in segs:
		var t0 := a0 + (a1 - a0) * i / float(segs)
		var t1 := a0 + (a1 - a0) * (i + 1) / float(segs)
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(Vector3(sin(t0), 0.0, -cos(t0)))
		st.add_vertex(Vector3(sin(t1), 0.0, -cos(t1)))
	return st.commit()

func _make_field() -> Dictionary:
	var root := Node3D.new()
	root.visible = false
	add_child(root)
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.0
	cyl.height = 0.06
	disc.mesh = cyl
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.9, 0.25, 0.05)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.4, 0.08)
	m.emission_energy_multiplier = 3.5
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color.a = 0.85
	disc.material_override = m
	disc.position.y = 0.05
	root.add_child(disc)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.5, 0.15)
	l.omni_range = 10.0
	l.light_energy = 3.2
	l.position.y = 1.2
	l.shadow_enabled = false
	root.add_child(l)
	var p := GPUParticles3D.new()
	p.amount = 48
	p.lifetime = 1.4
	p.emitting = false
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 1.0
	pm.direction = Vector3.UP
	pm.spread = 20.0
	pm.initial_velocity_min = 1.5
	pm.initial_velocity_max = 3.5
	pm.gravity = Vector3(0, 1.0, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	pm.color = Color(1.0, 0.5, 0.1)
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.3, 0.3)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.albedo_color = Color(1.0, 0.45, 0.1, 0.9)
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.vertex_color_use_as_albedo = true
	q.material = qm
	p.draw_pass_1 = q
	p.position.y = 0.3
	root.add_child(p)
	return {"node": root, "disc": disc, "light": l, "particles": p, "active": false, "t": 0.0, "dur": 0.0, "radius": 1.0, "serial": 0, "pos": Vector3.ZERO}

func _make_meteor() -> Dictionary:
	var root := Node3D.new()
	root.visible = false
	add_child(root)
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.7
	s.height = 1.4
	mi.mesh = s
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.6, 0.12, 0.02)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.45, 0.1)
	m.emission_energy_multiplier = 4.0
	mi.material_override = m
	root.add_child(mi)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.5, 0.2)
	l.omni_range = 12.0
	l.light_energy = 2.5
	l.shadow_enabled = false
	root.add_child(l)
	return {"node": root, "light": l, "active": false, "t": 0.0, "dur": 0.0, "from": Vector3.ZERO, "to": Vector3.ZERO, "serial": 0, "landed": false}

func _make_spark() -> Dictionary:
	var p := GPUParticles3D.new()
	p.amount = 24
	p.lifetime = 0.45
	p.one_shot = true
	p.explosiveness = 1.0
	p.emitting = false
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.initial_velocity_min = 3.0
	pm.initial_velocity_max = 7.0
	pm.gravity = Vector3(0, -9.0, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.12, 0.12)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.albedo_color = Color(1.0, 0.9, 0.6, 1.0)
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	q.material = qm
	p.draw_pass_1 = q
	add_child(p)
	return {"node": p, "mat": qm, "active": false, "t": 0.0, "dur": 0.5, "serial": 0}

# --- acquisition -----------------------------------------------------------

func _acquire(pool: Array[Dictionary]) -> Dictionary:
	var oldest: Dictionary = pool[0]
	for e in pool:
		if not e["active"]:
			_serial += 1
			e["serial"] = _serial
			return e
		if e["serial"] < oldest["serial"]:
			oldest = e
	overflow += 1
	_serial += 1
	oldest["serial"] = _serial
	return oldest

# --- public API ---------------------------------------------------------------

## Danger ring on the ground. Returns a handle (serial) for ring_update/ring_end.
func ring(pos: Vector3, radius: float, color: Color, dur: float) -> int:
	var e := _acquire(_rings)
	var mi: MeshInstance3D = e["node"]
	mi.visible = true
	mi.position = pos + Vector3(0, 0.12, 0)
	mi.rotation = Vector3(PI / 2.0, 0, 0)
	mi.scale = Vector3(radius, radius, 1.0)
	var mat: StandardMaterial3D = e["mat"]
	mat.albedo_color = color
	e["color"] = color
	e["base_alpha"] = color.a
	e["active"] = true
	e["t"] = 0.0
	e["dur"] = dur
	return e["serial"]

func ring_update(handle: int, pos: Vector3, radius: float) -> void:
	for e in _rings:
		if e["active"] and e["serial"] == handle:
			var mi: MeshInstance3D = e["node"]
			mi.position = pos + Vector3(0, 0.12, 0)
			mi.scale = Vector3(radius, radius, 1.0)

func ring_end(handle: int) -> void:
	for e in _rings:
		if e["active"] and e["serial"] == handle:
			_release(e)

## Danger cone on the ground: apex `pos`, facing `yaw` (Godot -Z at yaw 0), length `range`.
func cone(pos: Vector3, yaw: float, range_m: float, color: Color, dur: float) -> int:
	var e := _acquire(_cones)
	var mi: MeshInstance3D = e["node"]
	mi.visible = true
	mi.position = pos + Vector3(0, 0.14, 0)
	mi.rotation = Vector3(0, yaw, 0)
	mi.scale = Vector3(range_m, 1.0, range_m)
	var mat: StandardMaterial3D = e["mat"]
	mat.albedo_color = color
	e["color"] = color
	e["base_alpha"] = color.a
	e["active"] = true
	e["t"] = 0.0
	e["dur"] = dur
	return e["serial"]

func cone_end(handle: int) -> void:
	for e in _cones:
		if e["active"] and e["serial"] == handle:
			_release(e)

## Hunter slash arc (brief).
func slash(pos: Vector3, yaw: float, reach: float, color: Color) -> void:
	var e := _acquire(_slashes)
	var mi: MeshInstance3D = e["node"]
	mi.visible = true
	mi.position = pos + Vector3(0, 1.1, 0)
	mi.rotation = Vector3(0, yaw, 0)
	mi.scale = Vector3(reach, 1.0, reach)
	var mat: StandardMaterial3D = e["mat"]
	mat.albedo_color = color
	e["color"] = color
	e["base_alpha"] = color.a
	e["active"] = true
	e["t"] = 0.0
	e["dur"] = 0.14

## Burning ground. Damage is the caller's business (query fields_hit).
func field(pos: Vector3, radius: float, dur: float) -> void:
	var e := _acquire(_fields)
	var root: Node3D = e["node"]
	root.visible = true
	root.position = pos
	var disc: MeshInstance3D = e["disc"]
	disc.scale = Vector3(radius, 1.0, radius)
	var p: GPUParticles3D = e["particles"]
	var pm := p.process_material as ParticleProcessMaterial
	pm.emission_sphere_radius = radius
	p.emitting = true
	var l: OmniLight3D = e["light"]
	l.omni_range = radius * 3.5 + 3.0
	e["active"] = true
	e["t"] = 0.0
	e["dur"] = dur
	e["radius"] = radius
	e["pos"] = pos

func fields_hit(pos: Vector3) -> bool:
	for e in _fields:
		if e["active"] and Vector2(pos.x - e["pos"].x, pos.z - e["pos"].z).length() <= e["radius"]:
			return true
	return false

## Falling meteor; returns handle. Landed meteors report via meteor_landed(handle).
func meteor(target: Vector3, fall_time: float) -> int:
	var e := _acquire(_meteors)
	var root: Node3D = e["node"]
	root.visible = true
	e["from"] = target + Vector3(-6.0, 34.0, 4.0)
	e["to"] = target
	root.position = e["from"]
	e["active"] = true
	e["landed"] = false
	e["t"] = 0.0
	e["dur"] = fall_time
	return e["serial"]

func meteor_landed(handle: int) -> bool:
	for e in _meteors:
		if e["serial"] == handle:
			return e["landed"]
	return true

func spark(pos: Vector3, color: Color) -> void:
	var e := _acquire(_sparks)
	var p: GPUParticles3D = e["node"]
	p.position = pos
	var m: StandardMaterial3D = e["mat"]
	m.albedo_color = color
	p.restart()
	p.emitting = true
	e["active"] = true
	e["t"] = 0.0

func clear_all() -> void:
	for pool: Array[Dictionary] in [_rings, _cones, _slashes, _sparks]:
		for e in pool:
			if e["active"]:
				_release(e)
	for e in _fields:
		if e["active"]:
			_release_field(e)
	for e in _meteors:
		if e["active"]:
			e["active"] = false
			(e["node"] as Node3D).visible = false

func active_count() -> int:
	var n := 0
	for pool: Array[Dictionary] in [_rings, _cones, _slashes, _sparks, _fields, _meteors]:
		for e in pool:
			if e["active"]:
				n += 1
	return n

# --- ticking -------------------------------------------------------------------

func _release(e: Dictionary) -> void:
	e["active"] = false
	(e["node"] as Node3D).visible = false

func _release_field(e: Dictionary) -> void:
	e["active"] = false
	(e["node"] as Node3D).visible = false
	(e["particles"] as GPUParticles3D).emitting = false

func _process(delta: float) -> void:
	for e in _rings:
		if e["active"]:
			e["t"] += delta
			var mat: StandardMaterial3D = e["mat"]
			var pulse: float = 0.65 + 0.35 * sin(e["t"] * 14.0)
			var c: Color = e["color"]
			mat.albedo_color = Color(c.r, c.g, c.b, e["base_alpha"] * pulse)
			if e["dur"] > 0.0 and e["t"] >= e["dur"]:
				_release(e)
	for e in _cones:
		if e["active"]:
			e["t"] += delta
			var mat: StandardMaterial3D = e["mat"]
			var c: Color = e["color"]
			var k: float = clampf(e["t"] / maxf(e["dur"], 0.01), 0.0, 1.0)
			mat.albedo_color = Color(c.r, c.g, c.b, e["base_alpha"] * (0.5 + 0.5 * k))
			if e["dur"] > 0.0 and e["t"] >= e["dur"]:
				_release(e)
	for e in _slashes:
		if e["active"]:
			e["t"] += delta
			var mat: StandardMaterial3D = e["mat"]
			var c: Color = e["color"]
			mat.albedo_color = Color(c.r, c.g, c.b, e["base_alpha"] * (1.0 - e["t"] / e["dur"]))
			if e["t"] >= e["dur"]:
				_release(e)
	for e in _sparks:
		if e["active"]:
			e["t"] += delta
			if e["t"] >= e["dur"]:
				e["active"] = false
	for e in _fields:
		if e["active"]:
			e["t"] += delta
			var l: OmniLight3D = e["light"]
			var life: float = 1.0 - clampf(e["t"] / e["dur"], 0.0, 1.0)
			l.light_energy = (2.2 + 1.2 * life) + sin(e["t"] * 17.0) * 0.4
			var disc: MeshInstance3D = e["disc"]
			var m := disc.material_override as StandardMaterial3D
			m.emission_energy_multiplier = 1.5 + 2.5 * life
			if e["t"] >= e["dur"]:
				_release_field(e)
	for e in _meteors:
		if e["active"]:
			e["t"] += delta
			var root: Node3D = e["node"]
			var k: float = clampf(e["t"] / e["dur"], 0.0, 1.0)
			root.position = (e["from"] as Vector3).lerp(e["to"], k * k)
			if k >= 1.0 and not e["landed"]:
				e["landed"] = true
				spark(e["to"] + Vector3(0, 0.5, 0), Color(1.0, 0.6, 0.2))
				field(e["to"], 2.2, 3.5)
			if e["t"] >= e["dur"] + 0.05:
				e["active"] = false
				root.visible = false
