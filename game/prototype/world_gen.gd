# PROTOTYPE HARNESS — renders the REAL dh-procgen world (chunks.json is dumped by
# `dh-server --dump-chunks`, docs/tech/24). No worldgen logic lives engine-side.
# Tile variants + prop scatter are deterministic coordinate hashes — pure dressing,
# never gameplay (props are visual only and do not affect walkability).
class_name ProtoWorld
extends Node2D

const TILE := 16          # 16 px = 1 m (prototype scale)
const CHUNK := 64
const T_WATER := 0
const T_GRASS := 1
const T_FOREST := 2
const T_ROCK := 3

var chunks := {}          # Vector2i(cx,cy) -> PackedByteArray (tiles)
var _layer: TileMapLayer
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
			var variant := int(ProtoSprites._speck(gx, gy, 91) * 3.999)
			_layer.set_cell(Vector2i(gx, gy), 0, Vector2i(t * 4 + variant, 0))
		chunks[Vector2i(cx, cy)] = packed
	_scatter_props()

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
			if t == T_FOREST and h < 0.06:
				tex = ProtoSprites.prop_tex(
						"tree_a" if ProtoSprites._speck(gx, gy, 5501) < 0.5 else "tree_b")
			elif t == T_GRASS and h < 0.04 and _near_rock(gx, gy):
				tex = ProtoSprites.prop_tex("rock")
			elif h > 0.985:
				tex = ProtoSprites.prop_tex("glowshroom")
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
			props.add_child(s)

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
