# PROTOTYPE HARNESS — ground loot. Real drops mint through the economy path
# (docs/tech/26); here they just feel good to vacuum up. kind "item" carries a
# real ProtoItems instance (gear/rune/essence) into the Session inventory.
class_name ProtoPickup
extends Node2D

var kind := "gold"      # gold | stone | snare | item
var amount := 1
var item: Dictionary = {}   # ProtoItems instance when kind == "item"
var _t := randf() * TAU
var _base_y := 0.0
var _warned := false
var _collected := false

func _ready() -> void:
	add_to_group("ground_loot")
	_base_y = position.y
	var s := Sprite2D.new()
	if kind == "item":   # rarity-tinted slot silhouette (sprites.gd icon factory)
		s.texture = ProtoSprites.item_icon(str(item.get("sprite_key", "sword")),
				str(item.get("rarity", "common")))
	else:
		s.texture = ProtoSprites.pickup_tex(kind)  # coin stack / violet gem / snare
	add_child(s)
	# ground glow (canon §4 fake-bloom): rarity color for gear, violet/cyan gems
	var glow_col := Color.TRANSPARENT
	match kind:
		"item":
			var rar := str(item.get("rarity", "common"))
			if rar != "common":
				glow_col = ProtoItems.rarity_color(rar)
		"stone":
			glow_col = Color("b06cff")
		"snare":
			glow_col = Color("7fe7ff")
	if glow_col.a > 0.0:
		add_child(ProtoGlow.make(glow_col, 13.0, 0.42, 4.0, 0.3))

func _physics_process(delta: float) -> void:
	if _collected or is_queued_for_deletion(): return
	_t += delta * 4.0
	position.y = _base_y + sin(_t) * 2.0
	var player := get_tree().get_first_node_in_group("player")
	if player == null or player.dead:
		return
	var main := get_tree().get_first_node_in_group("main")
	if main == null:
		return
	# items stay on the ground while the bag is full (cap 40, proposal)
	var blocked: bool = kind == "item" and not main.can_collect_item()
	if blocked:
		if not _warned and global_position.distance_to(player.global_position) < 14.0:
			_warned = true
			main.damage_number(global_position + Vector2(0, -18), 0,
					Color("ff8a7a"), "inventory full (40)")
		return
	var d := global_position.distance_to(player.global_position)
	if d < 24.0:  # magnet
		global_position = global_position.move_toward(player.global_position, delta * 160.0)
		_base_y = position.y
	if d < 10.0:
		_collected = true  # commit once, even before queue_free drains this frame
		main.collect(kind, amount, global_position, item)
		queue_free()
