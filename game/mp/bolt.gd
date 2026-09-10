# MP — one pooled replicated bolt dot (docs/tech/33): a colored circle + hot
# core, drawn (no texture), recycled across snapshots.
extends Node2D

var col := Color("ff7a33")

func _draw() -> void:
	draw_circle(Vector2.ZERO, 4.0, Color(col.r, col.g, col.b, 0.45))
	draw_circle(Vector2.ZERO, 2.0, col.lightened(0.5))
