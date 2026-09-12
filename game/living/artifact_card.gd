# Tooltips grow vertically at a bounded reading width; authoring a longer
# artifact story must not produce a label wider than the 640px viewport.
extends PanelContainer

func _make_custom_tooltip(for_text: String) -> Object:
	var text := Label.new()
	text.custom_minimum_size.x = 260
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.text = for_text
	text.theme = ProtoTheme.get_theme()
	return text
