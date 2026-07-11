# PROTOTYPE HARNESS — minimap over the dh-procgen chunk dump. Terrain is baked
# ONCE into a texture (1 px per tile, scaled into a 144x144 widget); entity dots
# are redrawn ~4x/s. The shipping map/fog system is a dh-sim concern (docs/tech/21).
class_name ProtoMinimap
extends CanvasLayer

const MAP_SIZE := 144.0
const COLS := [Color("16303b"), Color("2c4a33"), Color("223a2b"), Color("3a3f49")]

var _overlay: Node2D
var _origin_tile := Vector2i.ZERO
var _span_tiles := Vector2i.ONE
var _accum := 0.0

func _ready() -> void:
	layer = 2
	var world := get_tree().get_first_node_in_group("world") as ProtoWorld
	if world == null or world.chunks.is_empty():
		return
	# Compute the tile span dynamically from the dumped chunk keys.
	var keys: Array = world.chunks.keys()
	var min_c: Vector2i = keys[0]
	var max_c: Vector2i = keys[0]
	for key in keys:
		min_c.x = mini(min_c.x, key.x)
		min_c.y = mini(min_c.y, key.y)
		max_c.x = maxi(max_c.x, key.x)
		max_c.y = maxi(max_c.y, key.y)
	_origin_tile = min_c * ProtoWorld.CHUNK
	_span_tiles = (max_c - min_c + Vector2i.ONE) * ProtoWorld.CHUNK

	var img := Image.create_empty(_span_tiles.x, _span_tiles.y, false, Image.FORMAT_RGBA8)
	img.fill(Color("0c1216"))
	for key in keys:
		var tiles: PackedByteArray = world.chunks[key]
		var bx: int = (key.x - min_c.x) * ProtoWorld.CHUNK
		var by: int = (key.y - min_c.y) * ProtoWorld.CHUNK
		for i in tiles.size():
			@warning_ignore("integer_division")
			img.set_pixel(bx + (i % ProtoWorld.CHUNK), by + (i / ProtoWorld.CHUNK),
					COLS[tiles[i]])

	var vp := get_viewport().get_visible_rect().size
	var origin := Vector2(vp.x - MAP_SIZE - 8.0, 8.0)
	var rect := TextureRect.new()
	rect.texture = ImageTexture.create_from_image(img)
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

func _process(delta: float) -> void:
	if _overlay == null:
		return
	_accum += delta
	if _accum >= 0.25:  # dots refresh ~4x/s
		_accum = 0.0
		_overlay.queue_redraw()

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
