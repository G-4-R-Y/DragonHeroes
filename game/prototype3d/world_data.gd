# PROTOTYPE HARNESS (3D view experiment, docs/design/22) — headless world data:
# the same dh-server window dump the 2D prototype streams, minus every Node2D.
# Proves the architecture bet: worldgen/sim/content are view-agnostic; only the
# presentation binds to a renderer. Constants alias ProtoWorld's so the two
# views can never drift on tile semantics.
class_name Proto3DWorldData
extends RefCounted

const TILE := ProtoWorld.TILE
const CHUNK := ProtoWorld.CHUNK
const T_WATER := ProtoWorld.T_WATER
const T_GRASS := ProtoWorld.T_GRASS
const T_FOREST := ProtoWorld.T_FOREST
const T_ROCK := ProtoWorld.T_ROCK

var chunks := {}          # Vector2i -> PackedByteArray
var seed_used := 0

# Loads a (2r+1)x(2r+1) window around origin: live dh-server dump when the sim
# binary exists, else the shipped island fallback (same degradation ladder as
# the 2D path).
func load_window(radius: int) -> bool:
	var bin := ProjectSettings.globalize_path("res://../sim/build/libs/dh-server/dh-server")
	var raw := ""
	if FileAccess.file_exists(bin):
		seed_used = randi()
		var out := ProjectSettings.globalize_path("user://world3d.json")
		var code := OS.execute(bin, ["--dump-window",
				"%d,%d,%d,%d" % [-radius, -radius, radius, radius],
				"--seed", str(seed_used), "--out", out])
		if code == 0:
			raw = FileAccess.get_file_as_string("user://world3d.json")
	if raw == "":
		for p in ["res://prototype/worlds/world_0.json", "res://prototype/chunks.json"]:
			if FileAccess.file_exists(p):
				raw = FileAccess.get_file_as_string(p)
				break
	if raw == "":
		return false
	var data: Dictionary = JSON.parse_string(raw)
	for c in data["chunks"]:
		var tiles: Array = c["tiles"]
		var packed := PackedByteArray()
		packed.resize(CHUNK * CHUNK)
		for i in tiles.size():
			packed[i] = int(tiles[i])
		chunks[Vector2i(int(c["cx"]), int(c["cy"]))] = packed
	return not chunks.is_empty()

func tile_grid(tx: int, ty: int) -> int:
	var key := Vector2i(floori(float(tx) / CHUNK), floori(float(ty) / CHUNK))
	if not chunks.has(key):
		return T_ROCK  # outside the window = impassable (same fence as 2D)
	return chunks[key][(ty - key.y * CHUNK) * CHUNK + (tx - key.x * CHUNK)]

# 3D ground plane is XZ; 1 unit = 1 tile. `p` is a world-space XZ position.
func is_walkable(p: Vector2) -> bool:
	var t := tile_grid(floori(p.x), floori(p.y))
	return t == T_GRASS or t == T_FOREST

func random_walkable_in_ring(center: Vector2, r_min: float, r_max: float) -> Vector2:
	for _i in 200:
		var p := center + Vector2.from_angle(randf() * TAU) * randf_range(r_min, r_max)
		if is_walkable(p):
			return p
	return center

func spawn_point() -> Vector2:
	return Vector2(0.5, 0.5) if is_walkable(Vector2(0.5, 0.5)) \
			else random_walkable_in_ring(Vector2.ZERO, 0.0, 40.0)
