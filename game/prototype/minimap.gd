# PROTOTYPE HARNESS — window-following minimap over the STREAMING chunk contract
# (docs/tech/29 §3). No one-shot world bake: a 5x5-chunk composite (320x320, 1 px/
# tile) follows the player's chunk, rebuilt via Image.blit_rect from the per-chunk
# blocks world_gen bakes (chunk_map_image) whenever the player crosses a chunk
# boundary or a window chunk loads/unloads. Unloaded space reads as the void color.
# Entity dots are redrawn ~4x/s. The shipping map/fog system is a dh-sim concern
# (docs/tech/21).
class_name ProtoMinimap
extends CanvasLayer

const MAP_SIZE := 144.0
const WINDOW_CHUNKS := 5          # LOAD_RADIUS 2 -> 5x5 live window (docs/tech/29 §2)
const HALF := 2                   # chunks each side of the player's chunk
const WINDOW_TILES := 320         # WINDOW_CHUNKS(5) * ProtoWorld.CHUNK(64), 1 px/tile
const VOID_COL := Color("0c1216") # unloaded/missing blocks (matches world_gen void)

var _world: ProtoWorld
var _overlay: Node2D
var _tex: ImageTexture
var _img: Image
var _loaded := {}                 # Vector2i -> true: chunks currently applied
var _center_chunk := Vector2i.ZERO
var _origin_tile := Vector2i.ZERO
var _span_tiles := Vector2i.ONE
var _accum := 0.0

func _ready() -> void:
	layer = 12   # spec §2.0: above post(5)/damage(6)/HUD(10) — minimap stays crisp
	_world = get_tree().get_first_node_in_group("world") as ProtoWorld
	if _world == null:
		return
	# Streaming contract (docs/tech/29 §2): snapshot the applied chunks, then
	# follow load/unload deltas.
	for key in _world.chunks.keys():
		_loaded[key] = true
	_world.chunk_loaded.connect(_on_chunk_loaded)
	_world.chunk_unloaded.connect(_on_chunk_unloaded)

	_span_tiles = Vector2i(WINDOW_TILES, WINDOW_TILES)   # 320x320, 1 px/tile
	_img = Image.create_empty(WINDOW_TILES, WINDOW_TILES, false, Image.FORMAT_RGBA8)
	_img.fill(VOID_COL)
	_tex = ImageTexture.create_from_image(_img)

	var vp := get_viewport().get_visible_rect().size
	var origin := Vector2(vp.x - MAP_SIZE - 8.0, 8.0)
	var rect := TextureRect.new()
	rect.texture = _tex
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.modulate = Color(1, 1, 1, 0.85)
	rect.position = origin
	rect.size = Vector2(MAP_SIZE, MAP_SIZE)
	add_child(rect)

	_overlay = Node2D.new()
	_overlay.position = origin
	add_child(_overlay)
	_overlay.draw.connect(_draw_overlay)

	_center_chunk = _player_chunk()
	_rebuild()   # first window composite

func _process(delta: float) -> void:
	if _overlay == null:
		return
	var pc := _player_chunk()
	if pc != _center_chunk:   # crossed a chunk boundary — re-center the window
		_center_chunk = pc
		_rebuild()
	_accum += delta
	if _accum >= 0.25:  # dots refresh ~4x/s
		_accum = 0.0
		_overlay.queue_redraw()

# --- window compositing (blit_rect/fill only — no per-pixel loops main-thread) ---

func _player_chunk() -> Vector2i:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return _center_chunk
	var span := float(ProtoWorld.CHUNK * ProtoWorld.TILE)   # px per chunk
	var pos: Vector2 = (player as Node2D).global_position
	return Vector2i(floori(pos.x / span), floori(pos.y / span))

func _in_window(key: Vector2i) -> bool:
	return absi(key.x - _center_chunk.x) <= HALF and absi(key.y - _center_chunk.y) <= HALF

func _on_chunk_loaded(key: Vector2i) -> void:
	_loaded[key] = true
	if _in_window(key):
		_rebuild()

func _on_chunk_unloaded(key: Vector2i) -> void:
	_loaded.erase(key)
	if _in_window(key):
		_rebuild()

# Recomposite the 320x320 window centered on _center_chunk from the per-chunk
# blocks; missing/unloaded blocks fill the void color. _origin_tile follows the
# window so _map_pos stays valid (dots logic unchanged).
func _rebuild() -> void:
	var top_left := _center_chunk - Vector2i(HALF, HALF)
	_origin_tile = top_left * ProtoWorld.CHUNK
	for dy in WINDOW_CHUNKS:
		for dx in WINDOW_CHUNKS:
			var key := top_left + Vector2i(dx, dy)
			var dst := Vector2i(dx, dy) * ProtoWorld.CHUNK
			var block: Image = _world.chunk_map_image(key) if _loaded.has(key) else null
			if block != null:
				_img.blit_rect(block,
						Rect2i(0, 0, ProtoWorld.CHUNK, ProtoWorld.CHUNK), dst)
			else:
				_img.fill_rect(
						Rect2i(dst, Vector2i(ProtoWorld.CHUNK, ProtoWorld.CHUNK)), VOID_COL)
	_tex.update(_img)

func _map_pos(world_pos: Vector2) -> Vector2:
	var px := (world_pos.x / ProtoWorld.TILE - float(_origin_tile.x)) \
			* (MAP_SIZE / float(_span_tiles.x))
	var py := (world_pos.y / ProtoWorld.TILE - float(_origin_tile.y)) \
			* (MAP_SIZE / float(_span_tiles.y))
	return Vector2(clampf(px, 1.0, MAP_SIZE - 2.0), clampf(py, 1.0, MAP_SIZE - 2.0))

func _draw_overlay() -> void:
	# thin border frame
	_overlay.draw_rect(Rect2(-1.0, -1.0, MAP_SIZE + 2.0, MAP_SIZE + 2.0),
			Color("0c1418"), false, 2.0)
	var tree := get_tree()
	var main := tree.get_first_node_in_group("main")
	# untyped: the hunt legendary rides whichever boss chassis its base picked
	var leg: Variant = main.legendary_boss if main else null
	if leg != null and not is_instance_valid(leg):
		leg = null
	for c in tree.get_nodes_in_group("creatures"):
		if c is ProtoBoss or c.dead or c == leg:
			continue
		_overlay.draw_rect(Rect2(_map_pos(c.global_position) - Vector2(0.5, 0.5),
				Vector2(1, 1)), Color("9a6cff"))
	if main and is_instance_valid(main.boss) and not main.boss.dead:
		_overlay.draw_rect(Rect2(_map_pos(main.boss.global_position) - Vector2(1.5, 1.5),
				Vector2(3, 3)), Color("ff7a33"))
	if leg != null and not leg.dead:
		# hunt legendary: magenta DIAMOND — distinct from the Matriarch's
		# orange square at a glance (task 4)
		var lp := _map_pos(leg.global_position)
		_overlay.draw_colored_polygon(PackedVector2Array([
				lp + Vector2(0, -3), lp + Vector2(3, 0),
				lp + Vector2(0, 3), lp + Vector2(-3, 0)]), Color("e05aff"))
	for p in tree.get_nodes_in_group("pet"):
		_overlay.draw_rect(Rect2(_map_pos(p.global_position) - Vector2(1, 1),
				Vector2(2, 2)), Color("59d6e6"))
	var player := tree.get_first_node_in_group("player")
	if player:
		_overlay.draw_rect(Rect2(_map_pos(player.global_position) - Vector2(1, 1),
				Vector2(2, 2)), Color(1, 1, 1))
