# ARENA — the flat world stub. Creatures, pets, hag blinks and player dashes all
# gate movement on the "world" group contract (is_walkable / rings); the arena
# is a bounded circular platform, so walkable == inside the boundary.
class_name ArenaWorld
extends Node2D

const TILE := 16.0

@export var radius := 26.0 * TILE   # the fighting ring (px)

func _ready() -> void:
	add_to_group("world")

func is_walkable(pos: Vector2) -> bool:
	return pos.length() <= radius

func random_walkable_in_ring(center: Vector2, r_min: float, r_max: float) -> Vector2:
	for _i in 12:
		var p := center + Vector2.from_angle(randf() * TAU) * randf_range(r_min, r_max)
		if is_walkable(p):
			return p
	return center.limit_length(radius * 0.8)

func spawn_point() -> Vector2:
	return Vector2.ZERO

func clamp_inside(pos: Vector2, margin := 0.0) -> Vector2:
	return pos.limit_length(radius - margin)
