class_name ManaView
extends Control
## Affiche la réserve de mana du héros pour ce tour (une pastille par mana disponible).

var pool: Dictionary = {}:
	set(value):
		pool = value
		queue_redraw()


func _ready() -> void:
	custom_minimum_size = Vector2(160, 24)


func _draw() -> void:
	var font := get_theme_default_font()
	var x := 10.0
	var symbols: Array[String] = []
	for color in Mana.color_ids() + [Mana.COLORLESS]:
		for i in int(pool.get(color, 0)):
			symbols.append(color)
	if symbols.is_empty():
		draw_string(font, Vector2(0, 17), Loc.ui("Mana épuisé"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UITheme.TEXT_DIM)
		return
	for symbol in symbols:
		ManaIcons.draw_symbol(self, Vector2(x, size.y / 2.0), 9.0, symbol, font)
		x += 21.0
