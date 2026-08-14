# PROTOTYPE HARNESS — the 3D ALTERNATIVE VIEW (docs/design/22, canon §12.33).
# Same dh-procgen world, same GenForge sprite bundles, same input actions —
# rendered as a perspective 3D scene: tile art textures the ground plane, rock
# tiles extrude into real occluding geometry, actors are pixel billboards lit
# by REAL 3D lights (moon directional + hero lantern + glowshroom omnis).
# Everything code-built like the 2D prototype; the 2D game is untouched and
# remains canon. Run: godot --path game res://prototype3d/hunt3d.tscn
#
# What this experiment reuses as-is: world data (Proto3DWorldData -> the same
# dh-server dump), tile atlas + prop textures (ProtoSprites), actor bundles
# (ProtoBundleArt.frames_for -> AnimatedSprite3D), walkability rules, input
# actions, scatter hashes (same world -> same trees). What it does NOT port:
# combat/FX/UI — that's the real cost of a 3D product, and it is presentation
# code by design (the C++ sim never knew the renderer existed).
extends Node3D

const RADIUS := 2                  # 5x5 chunk window, parity with the 2D boot
const PROP_RADIUS := 52.0          # billboard scatter cap (Sprite3D doesn't batch)
const SHROOM_LIGHTS := 12          # nearest glowshrooms that get real omnis
const HERO_SPEED := 5.5            # tiles/s (1 unit = 1 tile)

var data: Proto3DWorldData
var hero: Node3D
var hero_spr: AnimatedSprite3D
var cam: Camera3D
var _atlas_img: Image
var _creatures: Array = []         # [ {node, spr, target: Vector2, next_think} ]
var _attacking := false

func _ready() -> void:
	data = Proto3DWorldData.new()
	if not data.load_window(RADIUS):
		push_error("HUNT3D: no world data")
		return
	print("hunt3d seed: ", data.seed_used, " chunks: ", data.chunks.size())
	_atlas_img = ProtoSprites.make_tile_atlas().get_image()
	_build_environment()
	_build_terrain()
	_scatter_props()
	_spawn_hero()
	_spawn_creatures()

# --- world building ---------------------------------------------------------

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("070b12")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.30, 0.34, 0.55)   # the 2D night ambient
	env.ambient_light_energy = 0.55
	env.fog_enabled = true
	env.fog_light_color = Color("0a1020")
	env.fog_density = 0.022
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-52.0, 28.0, 0.0)
	moon.light_color = Color(0.55, 0.62, 0.85)
	moon.light_energy = 0.35
	add_child(moon)

func _mat(tex: Texture2D, unshaded := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.roughness = 1.0
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

func _tile_variant(gx: int, gy: int) -> int:
	# same anti-repetition recipe as the 2D floor (world_gen._pick_variant)
	var n := clampf((ProtoSprites.macro_noise(gx, gy, 131) - 0.5) * 1.9 + 0.5, 0.0, 1.0)
	var jitter := (ProtoSprites._speck(gx, gy, 91) - 0.5) * 1.6
	return clampi(int(n * 3.999 + jitter), 0, 3)

# Ground: ONE textured plane per chunk — the 2D tile atlas composited into a
# 1024px chunk texture (16px texels stay chunky through nearest filtering).
# Rock tiles additionally extrude as a MultiMesh of boxes: real 3D occlusion
# the 2D view faked with an SDF. Water tiles get a translucent sheet slightly
# below grade so shores read as banks.
func _build_terrain() -> void:
	const T := ProtoWorld.TILE
	var rock_tex := ImageTexture.create_from_image(
			_atlas_img.get_region(Rect2i(ProtoWorld.T_ROCK * 4 * T, 0, T, T)))
	var rock_mat := _mat(rock_tex)
	var water_mat := StandardMaterial3D.new()
	water_mat.albedo_color = Color(0.10, 0.22, 0.38, 0.8)
	water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_mat.roughness = 0.08
	water_mat.metallic = 0.35
	water_mat.emission_enabled = true
	water_mat.emission = Color(0.05, 0.12, 0.22)
	water_mat.emission_energy_multiplier = 0.6
	for key in data.chunks:
		var tiles: PackedByteArray = data.chunks[key]
		var img := Image.create(CHUNK_PX(), CHUNK_PX(), false, Image.FORMAT_RGBA8)
		var rocks: Array[Vector3] = []
		var waters: Array[Vector2i] = []
		for i in ProtoWorld.CHUNK * ProtoWorld.CHUNK:
			var lx: int = i % ProtoWorld.CHUNK
			@warning_ignore("integer_division")
			var ly: int = i / ProtoWorld.CHUNK
			var gx: int = key.x * ProtoWorld.CHUNK + lx
			var gy: int = key.y * ProtoWorld.CHUNK + ly
			var t := tiles[i]
			var col := int(t) * 4 + _tile_variant(gx, gy)
			img.blit_rect(_atlas_img, Rect2i(col * T, 0, T, T), Vector2i(lx * T, ly * T))
			if t == ProtoWorld.T_ROCK:
				var h := 0.7 + ProtoSprites._speck(gx, gy, 313) * 0.9
				rocks.append(Vector3(gx + 0.5, h, gy + 0.5))
			elif t == ProtoWorld.T_WATER:
				waters.append(Vector2i(gx, gy))
		var plane := PlaneMesh.new()
		plane.size = Vector2(ProtoWorld.CHUNK, ProtoWorld.CHUNK)
		var mi := MeshInstance3D.new()
		mi.mesh = plane
		mi.material_override = _mat(ImageTexture.create_from_image(img))
		mi.position = Vector3((key.x + 0.5) * ProtoWorld.CHUNK, 0.0,
				(key.y + 0.5) * ProtoWorld.CHUNK)
		add_child(mi)
		if not rocks.is_empty():
			add_child(_multibox(rocks, rock_mat))
		if not waters.is_empty():
			add_child(_water_sheet(waters, water_mat))

func CHUNK_PX() -> int:
	return ProtoWorld.CHUNK * ProtoWorld.TILE

func _multibox(spots: Array[Vector3], mat: StandardMaterial3D) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	box.material = mat
	mm.mesh = box
	mm.instance_count = spots.size()
	for k in spots.size():
		var s := spots[k]
		var xf := Transform3D(Basis.from_scale(Vector3(1.0, s.y, 1.0)),
				Vector3(s.x, s.y * 0.5, s.z))
		mm.set_instance_transform(k, xf)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	return mmi

func _water_sheet(tiles: Array[Vector2i], mat: StandardMaterial3D) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var quad := PlaneMesh.new()
	quad.size = Vector2.ONE
	quad.material = mat
	mm.mesh = quad
	mm.instance_count = tiles.size()
	for k in tiles.size():
		mm.set_instance_transform(k, Transform3D(Basis.IDENTITY,
				Vector3(tiles[k].x + 0.5, -0.12, tiles[k].y + 0.5)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	return mmi

# Prop billboards: the 2D prop textures standing up in 3D, scattered by the
# SAME coordinate hashes as world_gen — the two views agree on every tree.
# Capped by radius: Sprite3D doesn't batch, so the demo dresses the arena
# around spawn, not all 25 chunks.
func _scatter_props() -> void:
	var spawn := data.spawn_point()
	var shrooms: Array[Vector2] = []
	var count := 0
	for key in data.chunks:
		var tiles: PackedByteArray = data.chunks[key]
		for i in ProtoWorld.CHUNK * ProtoWorld.CHUNK:
			var t := tiles[i]
			if t == ProtoWorld.T_WATER or t == ProtoWorld.T_ROCK:
				continue
			var gx: int = key.x * ProtoWorld.CHUNK + (i % ProtoWorld.CHUNK)
			@warning_ignore("integer_division")
			var gy: int = key.y * ProtoWorld.CHUNK + (i / ProtoWorld.CHUNK)
			var p := Vector2(gx + 0.5, gy + 0.5)
			if p.distance_to(spawn) > PROP_RADIUS:
				continue
			var h := ProtoSprites._speck(gx, gy, 4177)
			var tex: Texture2D = null
			var shroom := false
			if t == ProtoWorld.T_FOREST and h < 0.06:
				tex = ProtoSprites.prop_tex(
						"tree_a" if ProtoSprites._speck(gx, gy, 5501) < 0.5 else "tree_b")
			elif h > 0.985:
				tex = ProtoSprites.prop_tex("glowshroom")
				shroom = true
			if tex == null:
				continue
			var s := Sprite3D.new()
			s.texture = tex
			s.pixel_size = 1.0 / float(ProtoWorld.TILE)
			s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
			s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
			s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			s.offset = Vector2(0.0, tex.get_height() * 0.5)
			s.position = Vector3(p.x, 0.0, p.y)
			if shroom:
				s.modulate = Color(1.15, 1.3, 1.3)
				shrooms.append(p)
			add_child(s)
			count += 1
	# real 3D light from the nearest glowshrooms — the registry idea, literal
	shrooms.sort_custom(func(a, b): return a.distance_squared_to(spawn) < b.distance_squared_to(spawn))
	for k in mini(SHROOM_LIGHTS, shrooms.size()):
		var l := OmniLight3D.new()
		l.light_color = Color(0.45, 0.95, 1.0)
		l.omni_range = 4.5
		l.light_energy = 0.9
		l.position = Vector3(shrooms[k].x, 0.8, shrooms[k].y)
		add_child(l)
	print("hunt3d props: ", count, " (", shrooms.size(), " shrooms)")

# --- actors ------------------------------------------------------------------

static var _frames3d_cache := {}

# The 2D bundles wrap frames in CanvasTexture (diffuse+normal for the sprite
# N·L stack) — a 2D-renderer type the 3D pipeline samples as white. Unwrap to
# the diffuse textures once per actor; the 2D SpriteFrames stay untouched.
static func _frames_3d(actor: String) -> SpriteFrames:
	if _frames3d_cache.has(actor):
		return _frames3d_cache[actor]
	var src := ProtoBundleArt.frames_for(actor)
	var out := SpriteFrames.new()
	out.remove_animation("default")
	for anim in src.get_animation_names():
		out.add_animation(anim)
		out.set_animation_speed(anim, src.get_animation_speed(anim))
		out.set_animation_loop(anim, src.get_animation_loop(anim))
		for f in src.get_frame_count(anim):
			var tex := src.get_frame_texture(anim, f)
			if tex is CanvasTexture:
				tex = (tex as CanvasTexture).diffuse_texture
			out.add_frame(anim, tex, src.get_frame_duration(anim, f))
	_frames3d_cache[actor] = out
	return out

func _billboard_actor(actor: String) -> AnimatedSprite3D:
	var spr := AnimatedSprite3D.new()
	spr.sprite_frames = _frames_3d(actor)   # the whole bestiary, one unwrap
	spr.pixel_size = 1.0 / float(ProtoWorld.TILE)
	spr.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	spr.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	spr.offset = Vector2(0.0, 23.0)   # bundle anchor (26,49): feet on the ground
	spr.play("idle")
	return spr

func _spawn_hero() -> void:
	var spawn := data.spawn_point()
	hero = Node3D.new()
	hero.position = Vector3(spawn.x, 0.0, spawn.y)
	add_child(hero)
	hero_spr = _billboard_actor("hero")
	hero.add_child(hero_spr)
	hero_spr.animation_finished.connect(func() -> void: _attacking = false)
	var lantern := OmniLight3D.new()
	lantern.light_color = Color(1.0, 0.75, 0.45)
	lantern.omni_range = 8.0
	lantern.light_energy = 1.7
	lantern.position = Vector3(0.0, 1.6, 0.0)
	hero.add_child(lantern)
	cam = Camera3D.new()
	cam.fov = 48.0
	add_child(cam)
	_snap_camera(1.0)

func _spawn_creatures() -> void:
	var kinds := ["fen_boar", "gloamfen_stalker", "marsh_drake", "serpent", "shade"]
	for i in 8:
		var p := data.random_walkable_in_ring(
				Vector2(hero.position.x, hero.position.z), 6.0, 18.0)
		var n := Node3D.new()
		n.position = Vector3(p.x, 0.0, p.y)
		add_child(n)
		var spr := _billboard_actor(kinds[i % kinds.size()])
		n.add_child(spr)
		_creatures.append({"node": n, "spr": spr, "target": p,
				"next_think": randf() * 2.0})

# --- per-frame ---------------------------------------------------------------

func _process(dt: float) -> void:
	if hero == null:
		return
	_move_hero(dt)
	_wander(dt)
	_snap_camera(1.0 - pow(0.001, dt))   # framerate-independent follow

func _move_hero(dt: float) -> void:
	# the SAME input actions as the 2D prototype (project.godot InputMap)
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if Input.is_action_just_pressed("attack") and not _attacking:
		_attacking = true
		hero_spr.play("attack")
	if input != Vector2.ZERO:
		var pos := Vector2(hero.position.x, hero.position.z)
		var next := pos + input * HERO_SPEED * dt
		if data.is_walkable(next):
			pos = next
		elif data.is_walkable(Vector2(next.x, pos.y)):   # wall slide, 2D parity
			pos.x = next.x
		elif data.is_walkable(Vector2(pos.x, next.y)):
			pos.y = next.y
		hero.position = Vector3(pos.x, 0.0, pos.y)
		hero_spr.flip_h = input.x < -0.01 if absf(input.x) > 0.01 else hero_spr.flip_h
		if not _attacking and hero_spr.animation != "walk":
			hero_spr.play("walk")
	elif not _attacking and hero_spr.animation != "idle":
		hero_spr.play("idle")

func _wander(dt: float) -> void:
	for c in _creatures:
		c.next_think -= dt
		var node: Node3D = c.node
		var pos := Vector2(node.position.x, node.position.z)
		if c.next_think <= 0.0:
			c.next_think = randf_range(2.5, 5.0)
			c.target = data.random_walkable_in_ring(pos, 2.0, 6.0)
		var d: Vector2 = c.target - pos
		var spr: AnimatedSprite3D = c.spr
		if d.length() > 0.3:
			var step := d.normalized() * 2.2 * dt
			if data.is_walkable(pos + step):
				pos += step
				node.position = Vector3(pos.x, 0.0, pos.y)
			spr.flip_h = d.x < 0.0
			if spr.sprite_frames.has_animation("walk"):
				if spr.animation != "walk":
					spr.play("walk")
		elif spr.animation != "idle":
			spr.play("idle")

func _snap_camera(w: float) -> void:
	var target := hero.position + Vector3(0.0, 8.5, 7.0)
	cam.position = cam.position.lerp(target, w)
	cam.look_at(hero.position + Vector3(0.0, 0.8, 0.0))
