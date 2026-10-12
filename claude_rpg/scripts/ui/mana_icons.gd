class_name ManaIcons
extends RefCounted
## Dessin des symboles de mana (pastilles colorées avec leur lettre ou leur nombre).


## Dessine un symbole (« R », « C », « 2 »…) centré en `center` sur `canvas`.
static func draw_symbol(canvas: CanvasItem, center: Vector2, radius: float, symbol: String, font: Font) -> void:
	var color_id := Mana.GENERIC if symbol.is_valid_int() else symbol
	var fill := Mana.color_value(color_id)
	canvas.draw_circle(center + Vector2(0.8, 1.2), radius, Color(0, 0, 0, 0.45))
	canvas.draw_circle(center, radius, fill)
	canvas.draw_arc(center, radius, 0.0, TAU, 20, fill.darkened(0.45), 1.2, true)
	var label := symbol if symbol.is_valid_int() or symbol == Mana.COLORLESS else symbol
	var font_size := int(radius * 1.5)
	var size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	canvas.draw_string(font, center + Vector2(-size.x / 2.0, font_size * 0.36), label, HORIZONTAL_ALIGNMENT_LEFT,
		-1, font_size, Mana.ink_value(color_id))


## Dessine une suite de symboles alignés à droite de `right` (pour un coût de carte).
static func draw_cost(canvas: CanvasItem, right: Vector2, radius: float, cost: String, font: Font) -> void:
	var symbols := Mana.symbols(cost)
	for i in symbols.size():
		var x := right.x - radius - (symbols.size() - 1 - i) * (radius * 2.0 + 1.0)
		draw_symbol(canvas, Vector2(x, right.y), radius, symbols[i], font)
