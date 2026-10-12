class_name CardView
extends Control
## Une carte façon Magic: The Gathering, dessinée à la main :
## cadre de la couleur de la carte, nom et coût en mana, illustration, ligne de type et rareté, texte.
## Survol : la carte se soulève. Clic : signal `pressed`. Une carte non jouable est assombrie.

signal pressed

const CARD_SIZE := Vector2(118, 164)
const RAISE := 14.0

var card_id := ""
var playable := true:
	set(value):
		playable = value
		queue_redraw()
var selected := false:
	set(value):
		selected = value
		queue_redraw()
var count_badge := 0  # pour la composition du deck : nombre d'exemplaires (0 = pas de badge)

var _hovered := false


func setup(id: String) -> CardView:
	card_id = id
	custom_minimum_size = CARD_SIZE + Vector2(0, RAISE)
	size = custom_minimum_size
	tooltip_text = "%s — %s\n%s" % [Cards.name_of(id), Cards.type_name(id), Cards.text_of(id)]
	mouse_filter = Control.MOUSE_FILTER_STOP
	return self


func _ready() -> void:
	mouse_entered.connect(_set_hovered.bind(true))
	mouse_exited.connect(_set_hovered.bind(false))


func _set_hovered(value: bool) -> void:
	_hovered = value
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit()
		accept_event()


func _draw() -> void:
	if card_id == "":
		return
	var font := get_theme_default_font()
	# La carte est dessinée RAISE pixels plus bas, et remonte au survol ou quand elle est choisie.
	var raised := (_hovered and playable) or selected
	var origin := Vector2(0, 0.0 if raised else RAISE)
	var rect := Rect2(origin, CARD_SIZE)
	var frame := Cards.frame_color(card_id)
	var dim := 1.0 if playable else 0.8

	# Ombre, cadre, fond intérieur.
	draw_rect(Rect2(rect.position + Vector2(3, 4), rect.size), Color(0, 0, 0, 0.45))
	_round_rect(rect, frame.darkened(0.25) * Color(dim, dim, dim))
	var inner := rect.grow(-5)
	_round_rect(inner, Color("#efe4c8").lerp(frame, 0.18) * Color(dim, dim, dim))

	# Nom et coût.
	var name_bar := Rect2(inner.position + Vector2(2, 2), Vector2(inner.size.x - 4, 18))
	_round_rect(name_bar, frame.lightened(0.35) * Color(dim, dim, dim))
	draw_string(font, name_bar.position + Vector2(4, 13), Cards.name_of(card_id), HORIZONTAL_ALIGNMENT_LEFT,
		name_bar.size.x - 8 - Mana.symbols(Cards.cost_of(card_id)).size() * 13, 11, Color("#1e1712"))
	ManaIcons.draw_cost(self, name_bar.position + Vector2(name_bar.size.x - 2, 9), 6.0, Cards.cost_of(card_id), font)

	# Illustration.
	var art_rect := Rect2(inner.position + Vector2(4, 23), Vector2(inner.size.x - 8, 58))
	draw_rect(art_rect.grow(1), Color("#2a211a"))
	draw_texture_rect(ArtProvider.card_art(card_id), art_rect, false, Color(dim, dim, dim))

	# Ligne de type et rareté.
	var type_bar := Rect2(art_rect.position + Vector2(0, art_rect.size.y + 3), Vector2(art_rect.size.x, 14))
	_round_rect(type_bar, frame.lightened(0.35) * Color(dim, dim, dim))
	draw_string(font, type_bar.position + Vector2(3, 11), Cards.type_name(card_id), HORIZONTAL_ALIGNMENT_LEFT,
		-1, 10, Color("#1e1712"))
	var gem := type_bar.position + Vector2(type_bar.size.x - 7, 7)
	var rarity_color := Color(String(Cards.RARITY_COLORS.get(Cards.rarity_of(card_id), "#b8b2a6")))
	draw_colored_polygon(PackedVector2Array([gem + Vector2(0, -4), gem + Vector2(4, 0), gem + Vector2(0, 4),
		gem + Vector2(-4, 0)]), rarity_color)

	# Texte.
	var text_pos := type_bar.position + Vector2(2, type_bar.size.y + 10)
	draw_multiline_string(font, text_pos, Cards.text_of(card_id), HORIZONTAL_ALIGNMENT_LEFT, type_bar.size.x - 4,
		9, 6, Color("#2a211a"))

	if not playable:
		draw_rect(rect, Color(0.05, 0.04, 0.03, 0.45))
	if selected:
		draw_rect(rect.grow(2), UITheme.BORDER_HOVER, false, 2.0)
	elif playable and _hovered:
		draw_rect(rect.grow(1), UITheme.GOLD, false, 1.0)
	if count_badge > 0:
		var badge := rect.position + Vector2(rect.size.x - 4, rect.size.y - 4)
		draw_circle(badge, 11, Color("#1e1712"))
		draw_arc(badge, 11, 0, TAU, 20, UITheme.GOLD, 1.5, true)
		var label := "×%d" % count_badge
		var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		draw_string(font, badge + Vector2(-w / 2.0, 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UITheme.GOLD)


func _round_rect(rect: Rect2, color: Color) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(4)
	draw_style_box(box, rect)
