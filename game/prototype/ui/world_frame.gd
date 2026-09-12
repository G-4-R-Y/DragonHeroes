# Presentation-only menu backdrop. Reuses the approved shrine plate; the
# engraved frame is one cached CanvasItem, redrawn only when its size changes.
extends Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var landscape := TextureRect.new()
	landscape.texture = preload("res://living/shrine.png")
	landscape.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	landscape.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	landscape.modulate = Color(0.42, 0.48, 0.48)
	landscape.mouse_filter = Control.MOUSE_FILTER_IGNORE
	landscape.show_behind_parent = true
	landscape.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(landscape)
	# Behind the controls, a quiet reading surface; the landscape stays visible
	# at the edges. No new texture, shader, light or continuously redrawn effect.
	var veil := ColorRect.new()
	veil.color = Color(0.025, 0.045, 0.05, 0.78)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.show_behind_parent = true
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.offset_left = 54
	veil.offset_right = -54
	add_child(veil)
	# Draw the ornament above these children and below the actual menu.
	resized.connect(queue_redraw)

func _draw() -> void:
	var bronze := ProtoTheme.PANEL_BORDER
	var gold := ProtoTheme.GOLD
	var inset := 8.0
	var right := size.x - inset
	var bottom := size.y - inset
	for corner: Vector2 in [Vector2(inset, inset), Vector2(right, inset),
			Vector2(inset, bottom), Vector2(right, bottom)]:
		var direction := Vector2(1 if corner.x < size.x / 2 else -1,
				1 if corner.y < size.y / 2 else -1)
		draw_line(corner, corner + Vector2(38 * direction.x, 0), bronze, 1)
		draw_line(corner, corner + Vector2(0, 30 * direction.y), bronze, 1)
		var inner := corner + direction * 3
		draw_line(inner, inner + Vector2(14 * direction.x, 0), gold, 1)
		draw_line(inner, inner + Vector2(0, 14 * direction.y), gold, 1)
	for x in [32.0, size.x - 32.0]:
		var c := Vector2(x, size.y * 0.5)
		draw_line(c + Vector2(0, -88), c + Vector2(0, -26), bronze, 1)
		draw_line(c + Vector2(0, 26), c + Vector2(0, 88), bronze, 1)
		var diamond := PackedVector2Array([c + Vector2(0, -15), c + Vector2(9, 0),
				c + Vector2(0, 15), c + Vector2(-9, 0), c + Vector2(0, -15)])
		draw_polyline(diamond, gold.darkened(0.25), 1)
		draw_rect(Rect2(c - Vector2(2, 2), Vector2(4, 4)), ProtoTheme.LUMEN)
