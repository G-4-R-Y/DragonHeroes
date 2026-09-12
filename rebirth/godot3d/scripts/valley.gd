# REBIRTH / Godot 3D — the night valley. Procedural heightfield: a flat fighting
# floor (the bowl) with a rising rim, chunked into 6x6 meshes so the
# compatibility renderer's per-mesh light cap (8 omnis) is spread across the
# ground; rocks are ONE MultiMesh; glowshrooms and fire pits are REAL lights
# ("fire and darkness are media that light the world", canon §12.27).
class_name RbValley
extends Node3D

const SIZE := 180.0            # metres across
const CHUNKS := 6
const CELLS := 14              # cells per chunk side -> 84x84 grid
const BOWL_R := 30.0           # flat floor radius
const RIM_H := 22.0
const SEED := 7
const ROCKS := 160
const SHROOMS := 10
const PITS := 4

var noise := FastNoiseLite.new()
var tri_count := 0
var pits: Array[OmniLight3D] = []
var _pit_phase: Array[float] = []
var shrooms: Array[OmniLight3D] = []
var rng := RandomNumberGenerator.new()

func height_at(x: float, z: float) -> float:
	var r := sqrt(x * x + z * z)
	var rim := smoothstep(BOWL_R, BOWL_R + 28.0, r) * RIM_H
	var n := noise.get_noise_2d(x, z)
	var amp := lerpf(0.12, 4.5, smoothstep(BOWL_R - 6.0, BOWL_R + 20.0, r))
	return rim + n * amp

func normal_at(x: float, z: float) -> Vector3:
	var e := 0.5
	var hl := height_at(x - e, z)
	var hr := height_at(x + e, z)
	var hd := height_at(x, z - e)
	var hu := height_at(x, z + e)
	return Vector3(hl - hr, 2.0 * e, hd - hu).normalized()

func build() -> void:
	noise.seed = SEED
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.035
	noise.fractal_octaves = 4
	rng.seed = SEED
	var ground := StandardMaterial3D.new()
	ground.vertex_color_use_as_albedo = true
	ground.roughness = 0.95
	ground.metallic = 0.0
	for cx in CHUNKS:
		for cz in CHUNKS:
			_build_chunk(cx, cz, ground)
	_scatter_rocks()
	_glowshrooms()
	_fire_pits()
	_mist()

func _color_at(x: float, z: float, h: float) -> Color:
	var r := sqrt(x * x + z * z)
	var earth := Color(0.17, 0.135, 0.11)
	var scorch := Color(0.11, 0.09, 0.085)
	var moss := Color(0.10, 0.16, 0.09)
	var rock := Color(0.23, 0.22, 0.25)
	var c := earth.lerp(scorch, clampf(1.0 - r / 12.0, 0.0, 1.0) * 0.7)
	c = c.lerp(moss, smoothstep(BOWL_R - 4.0, BOWL_R + 10.0, r))
	c = c.lerp(rock, smoothstep(6.0, 16.0, h))
	var v := noise.get_noise_2d(x * 3.1 + 100.0, z * 3.1) * 0.06
	return Color(c.r + v, c.g + v, c.b + v)

func _build_chunk(cx: int, cz: int, mat: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cell := SIZE / (CHUNKS * CELLS)
	var ox := -SIZE / 2.0 + cx * CELLS * cell
	var oz := -SIZE / 2.0 + cz * CELLS * cell
	for i in CELLS + 1:
		for j in CELLS + 1:
			var x := ox + i * cell
			var z := oz + j * cell
			var h := height_at(x, z)
			st.set_normal(normal_at(x, z))
			st.set_color(_color_at(x, z, h))
			st.set_uv(Vector2(i, j) / float(CELLS))
			st.add_vertex(Vector3(x, h, z))
	var w := CELLS + 1
	for i in CELLS:
		for j in CELLS:
			var a := i * w + j
			var b := a + 1
			var c := a + w
			var d := c + 1
			st.add_index(a); st.add_index(b); st.add_index(c)
			st.add_index(b); st.add_index(d); st.add_index(c)
			tri_count += 2
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.name = "Chunk_%d_%d" % [cx, cz]
	add_child(mi)

func _scatter_rocks() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	mm.mesh = box
	mm.instance_count = ROCKS
	for i in ROCKS:
		var ang := rng.randf() * TAU
		var r := rng.randf_range(BOWL_R - 3.0, BOWL_R + 34.0)
		var x := cos(ang) * r
		var z := sin(ang) * r
		var s := Vector3(rng.randf_range(1.0, 4.5), rng.randf_range(0.8, 3.5), rng.randf_range(1.0, 4.0))
		var b := Basis.from_euler(Vector3(rng.randf_range(-0.25, 0.25), rng.randf() * TAU, rng.randf_range(-0.2, 0.2)))
		b = b.scaled(s)
		mm.set_instance_transform(i, Transform3D(b, Vector3(x, height_at(x, z) + s.y * 0.25, z)))
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.20, 0.19, 0.22)
	mat.roughness = 1.0
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.name = "Rocks"
	add_child(mmi)

func _glowshrooms() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.35
	mesh.height = 0.7
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.7, 0.65)
	mat.emission_enabled = true
	mat.emission = Color(0.25, 0.95, 0.85)
	mat.emission_energy_multiplier = 2.5
	for i in SHROOMS:
		var ang := (i / float(SHROOMS)) * TAU + rng.randf_range(-0.3, 0.3)
		var r := rng.randf_range(12.0, BOWL_R - 2.0)
		var pos := Vector3(cos(ang) * r, 0.0, sin(ang) * r)
		pos.y = height_at(pos.x, pos.z)
		var cluster := Node3D.new()
		cluster.position = pos
		cluster.name = "Shroom_%d" % i
		add_child(cluster)
		for k in 3:
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			mi.material_override = mat
			mi.position = Vector3(rng.randf_range(-0.8, 0.8), 0.3, rng.randf_range(-0.8, 0.8))
			mi.scale = Vector3.ONE * rng.randf_range(0.6, 1.2)
			cluster.add_child(mi)
		var l := OmniLight3D.new()
		l.light_color = Color(0.25, 0.9, 0.8)
		l.omni_range = 7.5
		l.light_energy = 1.3
		l.position = Vector3(0.0, 0.9, 0.0)
		cluster.add_child(l)
		shrooms.append(l)

func _fire_pits() -> void:
	var disc := CylinderMesh.new()
	disc.top_radius = 1.2
	disc.bottom_radius = 1.4
	disc.height = 0.25
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.18, 0.05)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.42, 0.08)
	mat.emission_energy_multiplier = 3.0
	for i in PITS:
		var ang := (i / float(PITS)) * TAU + 0.6
		var r := 21.0
		var pos := Vector3(cos(ang) * r, 0.0, sin(ang) * r)
		pos.y = height_at(pos.x, pos.z)
		var pit := Node3D.new()
		pit.position = pos
		pit.name = "Pit_%d" % i
		add_child(pit)
		var mi := MeshInstance3D.new()
		mi.mesh = disc
		mi.material_override = mat
		mi.position.y = 0.1
		pit.add_child(mi)
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.55, 0.2)
		l.omni_range = 13.0
		l.light_energy = 2.6
		l.position = Vector3(0.0, 1.4, 0.0)
		l.shadow_enabled = false
		pit.add_child(l)
		pits.append(l)
		_pit_phase.append(rng.randf() * TAU)
		pit.add_child(_embers())

func _embers() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 40
	p.lifetime = 2.2
	p.position.y = 0.4
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 25.0
	pm.initial_velocity_min = 1.2
	pm.initial_velocity_max = 2.6
	pm.gravity = Vector3(0.0, 0.6, 0.0)
	pm.scale_min = 0.7
	pm.scale_max = 1.3
	pm.color = Color(1.0, 0.55, 0.15)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.9
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.12, 0.12)   # world-size quads: per-particle scale stays ~1
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.6, 0.2)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.45, 0.1)
	m.emission_energy_multiplier = 2.0
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	q.material = m
	p.draw_pass_1 = q
	return p

func _mist() -> void:
	var p := GPUParticles3D.new()
	p.name = "Mist"
	p.amount = 70
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.position.y = 0.8
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(34.0, 0.4, 34.0)
	pm.direction = Vector3(1.0, 0.0, 0.3)
	pm.spread = 40.0
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.6
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.8
	pm.scale_max = 1.4
	pm.color = Color(0.45, 0.52, 0.7, 0.10)
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(8.0, 8.0)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.45, 0.52, 0.7, 0.10)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.no_depth_test = false
	q.material = m
	p.draw_pass_1 = q
	add_child(p)

func flicker(t: float) -> void:
	for i in pits.size():
		var ph := _pit_phase[i]
		pits[i].light_energy = 2.6 + sin(t * 9.0 + ph) * 0.35 + sin(t * 23.0 + ph * 2.0) * 0.18
