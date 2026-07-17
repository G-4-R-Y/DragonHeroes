# PROTOTYPE HARNESS — renders the REAL dh-procgen world (chunks.json is dumped by
# `dh-server --dump-chunks`, docs/tech/24). No worldgen logic lives engine-side.
# Tile variants + prop scatter are deterministic coordinate hashes — pure dressing,
# never gameplay (props are visual only and do not affect walkability). The same
# rule covers the anti-procgen-look layers: macro variant patches, the macro tint
# quad and the dual-grid boundary layer are ALL visual-only — walkability always
# reads the raw world grid.
class_name ProtoWorld
extends Node2D

const TILE := 16          # 16 px = 1 m (prototype scale)
const CHUNK := 64
const T_WATER := 0
const T_GRASS := 1
const T_FOREST := 2
const T_ROCK := 3

# Dual-grid boundary dressing (Oskar Stålberg corners) — flip off to fall back
# to hard tile edges for A/B comparison captures.
const DUAL_GRID := true

var chunks := {}          # Vector2i(cx,cy) -> PackedByteArray (tiles)
var _layer: TileMapLayer
var _shroom_pos: Array = []   # glowshroom prop positions -> darkness light holes
var _sway_mat: ShaderMaterial # shared wind/walk-through material for foliage
var _spawn_cache := Vector2.ZERO
var _spawn_valid := false

func _ready() -> void:
	y_sort_enabled = true
	var raw := _load_world_json()
	assert(raw != "", "no world dump — run: dh-server --dump-chunks 4 --out game/prototype/chunks.json")
	var data: Dictionary = JSON.parse_string(raw)
	print("world seed: ", data.get("seed", "?"))
	_build_world(data)

# A NEW map every hunt (Ricardo): invoke the real dh-server binary with a random
# seed and load the fresh dh-procgen dump. Falls back to the 6 shipped variants
# (prototype/worlds/), then chunks.json. The shipping path generates in-process
# via the dh-godot GDExtension — no subprocess, no dumps (docs/tech/24).
func _load_world_json() -> String:
	var bin := ProjectSettings.globalize_path("res://../sim/build/libs/dh-server/dh-server")
	if FileAccess.file_exists(bin):
		var out := ProjectSettings.globalize_path("user://world_live.json")
		var code := OS.execute(bin, ["--dump-chunks", "4",
				"--seed", str(randi()), "--out", out])
		if code == 0:
			var raw := FileAccess.get_file_as_string("user://world_live.json")
			if raw != "":
				return raw
	var variants: Array[String] = []
	for i in 6:
		var p := "res://prototype/worlds/world_%d.json" % i
		if FileAccess.file_exists(p):
			variants.append(p)
	if not variants.is_empty():
		return FileAccess.get_file_as_string(variants.pick_random())
	return FileAccess.get_file_as_string("res://prototype/chunks.json")

func _build_world(data: Dictionary) -> void:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = ProtoSprites.make_tile_atlas()
	atlas.texture_region_size = Vector2i(TILE, TILE)
	for i in 16:              # 4 types x 4 variants (column = type*4+variant)
		atlas.create_tile(Vector2i(i, 0))
	ts.add_source(atlas, 0)

	_layer = TileMapLayer.new()
	_layer.tile_set = ts
	_layer.z_index = -10
	add_child(_layer)

	for c in data["chunks"]:
		var cx := int(c["cx"])
		var cy := int(c["cy"])
		var tiles: Array = c["tiles"]
		var packed := PackedByteArray()
		packed.resize(CHUNK * CHUNK)
		for i in tiles.size():
			var t := int(tiles[i])
			packed[i] = t
			var gx := cx * CHUNK + (i % CHUNK)
			@warning_ignore("integer_division")
			var gy := cy * CHUNK + (i / CHUNK)
			_layer.set_cell(Vector2i(gx, gy), 0, Vector2i(t * 4 + _pick_variant(gx, gy), 0))
		chunks[Vector2i(cx, cy)] = packed
	if DUAL_GRID:
		_build_transitions()
	_scatter_props()
	_build_water_overlay()
	var tint := ProtoMacroTint.new()   # macro brightness/hue drift over the floor
	tint.name = "MacroTint"
	add_child(tint)
	call_deferred("_bake_light_sdf")
	set_process(true)

# Macro variation: a ~50-tile value noise picks each region's DOMINANT atlas
# variant and the per-tile hash only jitters around it — texture repetition
# breaks into organic patches (mossy vs worn regions) instead of the uniform
# 4-variant confetti that screams procgen.
func _pick_variant(gx: int, gy: int) -> int:
	var n := clampf((ProtoSprites.macro_noise(gx, gy, 131) - 0.5) * 1.9 + 0.5, 0.0, 1.0)
	var jitter := (ProtoSprites._speck(gx, gy, 91) - 0.5) * 1.6
	return clampi(int(n * 3.999 + jitter), 0, 3)

# Dual-grid autotiling (Oskar Stålberg corners): a HALF-TILE-SHIFTED display
# TileMapLayer whose every cell straddles four world tiles; mixed grass/forest
# and grass/rock corner sets repaint with 1 of 16 rounded transition tiles
# (ProtoSprites.make_transition_atlas), dissolving the hard procgen tile edges.
# Cells touching water or a forest|rock meeting keep the hard edge (out of the
# two shipped pairs). Pure dressing — is_walkable still reads the world grid.
func _build_transitions() -> void:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = ProtoSprites.make_transition_atlas(
			[[T_FOREST, T_GRASS], [T_ROCK, T_GRASS]])
	atlas.texture_region_size = Vector2i(TILE, TILE)
	for i in 32:              # 2 pairs x 16 corner masks (column = pair*16+mask)
		atlas.create_tile(Vector2i(i, 0))
	ts.add_source(atlas, 0)
	var layer := TileMapLayer.new()
	layer.name = "Transitions"
	layer.tile_set = ts
	layer.position = Vector2(TILE, TILE) * 0.5   # the dual-grid half-tile shift
	layer.z_index = -9        # over the base floor (-10), under macro tint (-8)
	add_child(layer)
	var bounds := _chunk_bounds()
	var kmin: Vector2i = bounds[0]
	var kmax: Vector2i = bounds[1]
	# row scan carrying the right-edge corners into the next cell (the display
	# grid shares corners) — this pass touches EVERY cell once per hunt, so it
	# stays allocation-free: type-presence is a bitmask, not an array
	const PAIR_FG := (1 << T_FOREST) | (1 << T_GRASS)
	const PAIR_RG := (1 << T_ROCK) | (1 << T_GRASS)
	var x0 := kmin.x * CHUNK - 1
	var x1 := (kmax.x + 1) * CHUNK
	for gy in range(kmin.y * CHUNK - 1, (kmax.y + 1) * CHUNK):
		var tl := _tile_grid(x0, gy)              # display cell corners = the
		var bl := _tile_grid(x0, gy + 1)          # 4 world tiles it straddles
		for gx in range(x0, x1):
			var tr := _tile_grid(gx + 1, gy)
			var br := _tile_grid(gx + 1, gy + 1)
			var bits := (1 << tl) | (1 << tr) | (1 << bl) | (1 << br)
			# exactly {forest,grass} or {rock,grass} — anything else (uniform,
			# touches water, forest meets rock) keeps the hard edge
			if bits == PAIR_FG or bits == PAIR_RG:
				var pair := 0 if bits == PAIR_FG else 1
				var a := T_FOREST if pair == 0 else T_ROCK
				var mask := (1 if tl == a else 0) | (2 if tr == a else 0) \
						| (4 if bl == a else 0) | (8 if br == a else 0)
				layer.set_cell(Vector2i(gx, gy), 0, Vector2i(pair * 16 + mask, 0))
			tl = tr
			bl = br

# Foliage sway needs the hero's position once per frame (walk-through push).
func _process(_dt: float) -> void:
	if _sway_mat == null:
		return
	var p := get_tree().get_first_node_in_group("player")
	if p != null:
		_sway_mat.set_shader_parameter("player_pos", (p as Node2D).global_position)

# Deterministic prop dressing: trees on forest, rocks on rock-adjacent grass,
# glowshrooms on grass/forest. Y-sorted so entities walk in front/behind.
func _scatter_props() -> void:
	var props := Node2D.new()
	props.name = "Props"
	props.y_sort_enabled = true
	add_child(props)
	var spawn := spawn_point()
	var skip_r := 3.0 * TILE
	for key in chunks:
		var tiles: PackedByteArray = chunks[key]
		for i in CHUNK * CHUNK:
			var t := tiles[i]
			if t == T_WATER or t == T_ROCK:
				continue
			var gx: int = key.x * CHUNK + (i % CHUNK)
			@warning_ignore("integer_division")
			var gy: int = key.y * CHUNK + (i / CHUNK)
			var h := ProtoSprites._speck(gx, gy, 4177)
			var tex: Texture2D = null
			var shroom := false
			var foliage := false
			if t == T_FOREST and h < 0.06:
				tex = ProtoSprites.prop_tex(
						"tree_a" if ProtoSprites._speck(gx, gy, 5501) < 0.5 else "tree_b")
				foliage = true
			elif t == T_GRASS and h < 0.04 and _near_rock(gx, gy):
				tex = ProtoSprites.prop_tex("rock")
			elif h > 0.985:
				tex = ProtoSprites.prop_tex("glowshroom")
				shroom = true
				foliage = true
			if tex == null:
				continue
			var pos := Vector2((gx + 0.5) * TILE, (gy + 0.5) * TILE)
			pos.x += (ProtoSprites._speck(gx, gy, 616) - 0.5) * 10.0
			pos.y += (ProtoSprites._speck(gx, gy, 717) - 0.5) * 6.0
			if pos.distance_to(spawn) < skip_r:
				continue
			var s := Sprite2D.new()
			s.texture = tex
			s.offset = Vector2(0.0, -tex.get_height() / 2.0 + 1.0)  # base sits on origin
			s.position = pos
			if foliage:   # trees + shrooms sway in the wind / bend from the hero;
				s.material = _sway_material()   # rocks obviously don't
			props.add_child(s)
			if shroom:
				_shroom_pos.append(pos)
	# Glowshrooms become environment LIGHT SOURCES in the darkness model —
	# registered deferred (main assembles its darkness node after world gen).
	if not _shroom_pos.is_empty():
		call_deferred("_register_shroom_lights")

func _register_shroom_lights() -> void:
	# darkness statics only — NO ProtoLights pool entries (a map scatters dozens
	# of shrooms; indefinite pool lights would flood the 32-slot gameplay pool).
	# The hole reveals the ground and the sprite itself supplies the cyan.
	var m := get_tree().get_first_node_in_group("main")
	if m == null or m.get("darkness") == null:
		return
	for pos in _shroom_pos:
		m.darkness.add_static(pos, 34.0, 0.55, 0.5, 2.2)

func _sway_material() -> ShaderMaterial:
	if _sway_mat == null:
		_sway_mat = ShaderMaterial.new()
		_sway_mat.shader = preload("res://prototype/shaders/prop_sway.gdshader")
	return _sway_mat

# Animated water: ONE MultiMesh quad per water tile over the static tile art
# (one draw call for every lake on the map). INSTANCE_CUSTOM carries the shore
# mask (land N/E/S/W) so the shader's foam hugs real coastlines. z=-6: above
# the tile floor, below the field decals (-5) and everything alive.
func _build_water_overlay() -> void:
	var water: Array = []
	for key in chunks:
		var tiles: PackedByteArray = chunks[key]
		for i in CHUNK * CHUNK:
			if tiles[i] != T_WATER:
				continue
			@warning_ignore("integer_division")
			water.append(Vector2i(key.x * CHUNK + (i % CHUNK),
					key.y * CHUNK + (i / CHUNK)))
	if water.is_empty():
		return
	var mmi := MultiMeshInstance2D.new()
	mmi.name = "WaterOverlay"
	mmi.z_as_relative = false
	mmi.z_index = -6
	mmi.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_custom_data = true
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	mm.mesh = q
	mm.instance_count = water.size()
	mmi.multimesh = mm
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://prototype/shaders/water.gdshader")
	mmi.material = mat
	add_child(mmi)
	for k in water.size():
		var t: Vector2i = water[k]
		var pos := Vector2((t.x + 0.5) * TILE, (t.y + 0.5) * TILE)
		mm.set_instance_transform_2d(k,
				Transform2D(Vector2(TILE, 0), Vector2(0, TILE), pos))
		mm.set_instance_custom_data(k, Color(
				1.0 if _tile_grid(t.x, t.y - 1) != T_WATER else 0.0,
				1.0 if _tile_grid(t.x + 1, t.y) != T_WATER else 0.0,
				1.0 if _tile_grid(t.x, t.y + 1) != T_WATER else 0.0,
				1.0 if _tile_grid(t.x - 1, t.y) != T_WATER else 0.0))

# Static world occlusion SDF for shadow-caster lights (canon §12.30): a
# tile-resolution distance field over the impassable T_ROCK cells, baked once
# per hunt with a two-pass chamfer transform and handed to ProtoDarkness. The
# same field is the marching substrate for Radiance Cascades later. Deferred:
# main assembles darkness after world gen.
func _bake_light_sdf() -> void:
	var m := get_tree().get_first_node_in_group("main")
	if m == null or m.get("darkness") == null or chunks.is_empty():
		return
	var bounds := _chunk_bounds()
	var kmin: Vector2i = bounds[0]
	var kmax: Vector2i = bounds[1]
	var tw := (kmax.x - kmin.x + 1) * CHUNK
	var th := (kmax.y - kmin.y + 1) * CHUNK
	const BIG := 1e9
	var dist := PackedFloat32Array()
	dist.resize(tw * th)
	for ty in th:
		for tx in tw:
			dist[ty * tw + tx] = 0.0 if _tile_grid(kmin.x * CHUNK + tx,
					kmin.y * CHUNK + ty) == T_ROCK else BIG
	# chamfer distance transform (3-4 mask ~ 1 / 1.4 tile units), two passes
	for ty in th:
		for tx in tw:
			var i := ty * tw + tx
			if dist[i] == 0.0:
				continue
			var d: float = dist[i]
			if tx > 0:
				d = minf(d, dist[i - 1] + 1.0)
			if ty > 0:
				d = minf(d, dist[i - tw] + 1.0)
				if tx > 0:
					d = minf(d, dist[i - tw - 1] + 1.4)
				if tx < tw - 1:
					d = minf(d, dist[i - tw + 1] + 1.4)
			dist[i] = d
	for ty in range(th - 1, -1, -1):
		for tx in range(tw - 1, -1, -1):
			var i := ty * tw + tx
			var d: float = dist[i]
			if tx < tw - 1:
				d = minf(d, dist[i + 1] + 1.0)
			if ty < th - 1:
				d = minf(d, dist[i + tw] + 1.0)
				if tx < tw - 1:
					d = minf(d, dist[i + tw + 1] + 1.4)
				if tx > 0:
					d = minf(d, dist[i + tw - 1] + 1.4)
			dist[i] = d
	var img := Image.create(tw, th, false, Image.FORMAT_R8)
	for ty in th:
		for tx in tw:
			var px := clampf(dist[ty * tw + tx] * TILE, 0.0, 500.0) / 500.0
			img.set_pixel(tx, ty, Color(px, 0, 0))
	m.darkness.set_sdf(ImageTexture.create_from_image(img),
			Vector2(kmin.x * CHUNK, kmin.y * CHUNK) * TILE,
			Vector2(tw, th) * TILE)

# Chunk-key bounding box of the dumped world: [kmin, kmax], inclusive.
func _chunk_bounds() -> Array:
	var kmin := Vector2i(1 << 20, 1 << 20)
	var kmax := Vector2i(-(1 << 20), -(1 << 20))
	for key in chunks:
		kmin = Vector2i(mini(kmin.x, key.x), mini(kmin.y, key.y))
		kmax = Vector2i(maxi(kmax.x, key.x), maxi(kmax.y, key.y))
	return [kmin, kmax]

func _near_rock(tx: int, ty: int) -> bool:
	return _tile_grid(tx + 1, ty) == T_ROCK or _tile_grid(tx - 1, ty) == T_ROCK \
			or _tile_grid(tx, ty + 1) == T_ROCK or _tile_grid(tx, ty - 1) == T_ROCK

func _tile_grid(tx: int, ty: int) -> int:
	var key := Vector2i(floori(float(tx) / CHUNK), floori(float(ty) / CHUNK))
	if not chunks.has(key):
		return T_ROCK  # outside the dumped area = impassable
	return chunks[key][(ty - key.y * CHUNK) * CHUNK + (tx - key.x * CHUNK)]

func tile_at(world_pos: Vector2) -> int:
	return _tile_grid(floori(world_pos.x / TILE), floori(world_pos.y / TILE))

func is_walkable(world_pos: Vector2) -> bool:
	var t := tile_at(world_pos)
	return t == T_GRASS or t == T_FOREST

# Finds a walkable point in a ring around `center` (meters converted by caller).
func random_walkable_in_ring(center: Vector2, r_min_px: float, r_max_px: float) -> Vector2:
	for _i in 200:
		var ang := randf() * TAU
		var dist := randf_range(r_min_px, r_max_px)
		var p := center + Vector2.from_angle(ang) * dist
		if is_walkable(p):
			return p
	return center

func spawn_point() -> Vector2:
	if not _spawn_valid:
		_spawn_valid = true
		_spawn_cache = Vector2.ZERO if is_walkable(Vector2.ZERO) \
				else random_walkable_in_ring(Vector2.ZERO, 0.0, 40.0 * TILE)
	return _spawn_cache
