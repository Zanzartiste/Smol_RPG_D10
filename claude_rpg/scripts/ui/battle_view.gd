class_name BattleView
extends Control
## Affichage d'un combat par-dessus l'illustration : le groupe à gauche (portrait, PV),
## les ennemis à droite (sprite à l'échelle de leur taille, PV). Le combattant actif est encadré d'or,
## les combattants à terre sont estompés, et un coup reçu fait clignoter la carte en rouge.

const SPRITE_SIZES := {"tiny": 56, "small": 68, "medium": 88, "large": 112}

var _combat: Combat
var _cards := {}  # id du combattant -> {panel, bar, hp_label}
var _allies_box := VBoxContainer.new()
var _enemies_box := HBoxContainer.new()


## Barre de PV dessinée à la main (verte, puis orange, puis rouge).
class HpBar extends Control:
	var ratio := 1.0:
		set(value):
			ratio = clampf(value, 0.0, 1.0)
			queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.04, 0.03))
		var color := UITheme.GOOD if ratio > 0.5 else (Color("#d9a23a") if ratio > 0.25 else UITheme.BAD)
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * ratio, size.y)), color)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.6), false, 1.0)


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	var row := HBoxContainer.new()
	margin.add_child(row)
	_allies_box.alignment = BoxContainer.ALIGNMENT_END
	_allies_box.add_theme_constant_override("separation", 6)
	row.add_child(_allies_box)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_enemies_box.alignment = BoxContainer.ALIGNMENT_END
	_enemies_box.add_theme_constant_override("separation", 10)
	row.add_child(_enemies_box)


func show_combat(combat: Combat) -> void:
	_combat = combat
	_cards.clear()
	for box in [_allies_box, _enemies_box]:
		for child in box.get_children():
			child.queue_free()
	for c in combat.combatants:
		if c.is_ally():
			_allies_box.add_child(_ally_card(c))
		else:
			_enemies_box.add_child(_enemy_card(c))
	visible = true
	refresh()


func hide_combat() -> void:
	visible = false
	_combat = null


func refresh() -> void:
	if _combat == null:
		return
	var active: Combatant = null if _combat.is_over() else _combat.current()
	for c in _combat.combatants:
		var card: Dictionary = _cards[c.id]
		card["bar"].ratio = float(c.hp) / maxf(1.0, c.max_hp())
		card["hp_label"].text = "%d / %d PV" % [c.hp, c.max_hp()]
		card["panel"].add_theme_stylebox_override("panel", _card_style(c == active))
		card["panel"].modulate.a = 1.0 if c.is_alive() else 0.35


## Fait clignoter en rouge la carte d'un combattant (coup reçu).
func flash(c: Combatant) -> void:
	if not _cards.has(c.id):
		return
	var panel: Control = _cards[c.id]["panel"]
	var tween := create_tween()
	tween.tween_property(panel, "self_modulate", Color(1.0, 0.35, 0.35), 0.08)
	tween.tween_property(panel, "self_modulate", Color.WHITE, 0.25)


func _ally_card(c: Combatant) -> Control:
	var panel := PanelContainer.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	row.add_child(_sprite(ArtProvider.combatant(c), 44))
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 2)
	row.add_child(info)
	info.add_child(_label(c.name, 15, UITheme.GOLD if c.is_hero else UITheme.TEXT))
	var bar := HpBar.new()
	bar.custom_minimum_size = Vector2(120, 8)
	info.add_child(bar)
	var hp_label := _label("", 13, UITheme.TEXT)
	info.add_child(hp_label)
	_cards[c.id] = {"panel": panel, "bar": bar, "hp_label": hp_label}
	return panel


func _enemy_card(c: Combatant) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	panel.add_child(column)
	var sprite := _sprite(ArtProvider.combatant(c), SPRITE_SIZES.get(c.size(), 88))
	sprite.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(sprite)
	var name_label := _label(c.name, 15, UITheme.TEXT)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(name_label)
	var bar := HpBar.new()
	bar.custom_minimum_size = Vector2(96, 8)
	column.add_child(bar)
	var hp_label := _label("", 13, UITheme.TEXT)
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hp_label)
	_cards[c.id] = {"panel": panel, "bar": bar, "hp_label": hp_label}
	return panel


func _sprite(texture: Texture2D, side: int) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(side, side)
	return rect


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _card_style(active: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.07, 0.05, 0.04, 0.78)
	box.border_color = UITheme.BORDER_HOVER if active else Color(0.3, 0.25, 0.18)
	box.set_border_width_all(2 if active else 1)
	box.set_corner_radius_all(3)
	box.set_content_margin_all(6)
	return box
