# PROTOTYPE HARNESS — visual attack telegraphs. Color grammar is owned by
# docs/design/17 §6.1; this prototype uses the hostile amber/ember family only.
#
# DEPRECATED (spec §2.4, 2026-07-15) — superseded by ProtoTelegraphs (telegraphs.gd),
# the pooled 24-descriptor / 2-draw-call system held as main.telegraphs. This
# per-cast `ProtoTelegraph.new()` node allocates one Node2D per windup. It is kept
# fully functional ONLY until the 7 call sites (boss.gd / hag.gd / duo_boss.gd /
# pyre_sovereign.gd / terravore_colossus.gd / creature.gd / main.gd) migrate to
# main.telegraphs.ring/.line/.beams (agents M/C/B). Do not add new callers.
class_name ProtoTelegraph
extends Node2D

enum Kind { CIRCLE, LINE }

var kind := Kind.CIRCLE
var radius := 48.0            # px, for CIRCLE
var length := 96.0            # px, for LINE
var width := 20.0             # px, for LINE
var direction := Vector2.RIGHT
var duration := 0.5
var color := Color(1.0, 0.55, 0.15, 0.35)

var _t := 0.0

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _t >= duration:
		queue_free()

func _draw() -> void:
	var fill := clampf(_t / duration, 0.0, 1.0)
	var edge := Color(color.r, color.g, color.b, 0.9)
	if kind == Kind.CIRCLE:
		draw_circle(Vector2.ZERO, radius, Color(color.r, color.g, color.b, 0.16))
		draw_circle(Vector2.ZERO, radius * fill, color)
		draw_arc(Vector2.ZERO, radius, 0, TAU, 48, edge, 2.0)
	else:
		var d := direction.normalized()
		var n := d.orthogonal() * width * 0.5
		var tip := d * length
		draw_colored_polygon(PackedVector2Array([-n, tip - n, tip + n, n]),
				Color(color.r, color.g, color.b, 0.16))
		draw_colored_polygon(PackedVector2Array([-n, tip * fill - n, tip * fill + n, n]), color)
		draw_line(-n, tip - n, edge, 2.0)
		draw_line(n, tip + n, edge, 2.0)
