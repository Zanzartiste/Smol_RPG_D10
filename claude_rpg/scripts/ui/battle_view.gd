class_name BattleView
extends Control
## Champ de bataille : le groupe à gauche, les ennemis à droite, posés sur une même ligne de sol.
## Chaque combattant : intention annoncée (ennemis), sprite à l'échelle de sa taille
## (rules.json › combat.sprite_scale), nom, PV et états. Le combattant actif est encadré d'or ;
## en mode ciblage, les cibles valides sont mises en évidence et cliquables (signal target_chosen).
## Un coup reçu fait clignoter la carte en rouge, les combattants à terre sont estompés.

signal target_chosen(combatant: Combatant)

const BASE_SPRITE := 72.0  # taille d'un sprite de créature moyenne

var _combat: Combat
var _tokens := {}  # id du combattant -> {panel, bar, hp_label, statuses, intent}
var _last_hp := {}
var _targetable: Array[Combatant] = []
var _allies_box := HBoxContainer.new()
var _enemies_box := HBoxContainer.new()


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
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)
	for box in [_allies_box, _enemies_box]:
		box.add_theme_constant_override("separation", 6)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_allies_box)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)
	row.add_child(_enemies_box)


func show_combat(combat: Combat) -> void:
	_combat = combat
	_tokens.clear()
	_last_hp.clear()
	_targetable.clear()
	for box in [_allies_box, _enemies_box]:
		for child in box.get_children():
			child.queue_free()
	refresh()


## Met à jour l'affichage (ajoute les invocations, PV, états, intentions, combattant actif).
func refresh() -> void:
	if _combat == null:
		return
	var active: Combatant = null if _combat.is_over() else _combat.current()
	for c in _combat.combatants:
		if not _tokens.has(c.id):
			var token := _make_token(c)
			(_allies_box if c.is_ally() else _enemies_box).add_child(token)
		var t: Dictionary = _tokens[c.id]
		t["bar"].ratio = float(c.hp) / maxf(1.0, c.max_hp())
		t["hp_label"].text = "%d / %d" % [c.hp, c.max_hp()]
		if c.reactions > 0 and c.is_alive():
			t["hp_label"].text += Loc.ui(" · %d réac.") % c.reactions  # actions gardées pour se défendre
		var targetable := c in _targetable
		t["panel"].add_theme_stylebox_override("panel", _token_style(c == active, targetable))
		t["panel"].modulate.a = 1.0 if c.is_alive() else 0.3
		t["panel"].mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if targetable else Control.CURSOR_ARROW
		t["intent"].text = (Loc.ui("S'apprête : %s") % c.intent["name"]) if not c.intent.is_empty() else ""
		_refresh_statuses(c, t["statuses"])
		if _last_hp.has(c.id) and c.hp < int(_last_hp[c.id]):
			_flash(t["panel"])
		_last_hp[c.id] = c.hp


## Active le mode ciblage sur ces combattants (liste vide = désactivé).
func set_targetable(candidates: Array[Combatant]) -> void:
	_targetable = candidates
	refresh()


func _make_token(c: Combatant) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_SHRINK_END
	panel.gui_input.connect(_on_token_input.bind(c))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 1)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(column)
	var intent := _label("", 12, UITheme.BAD)
	intent.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(intent)
	var side := BASE_SPRITE * Combat.sprite_scale(c.size())
	var sprite := TextureRect.new()
	sprite.texture = ArtProvider.combatant(c)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.custom_minimum_size = Vector2(side, side)
	sprite.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not c.is_ally():
		sprite.flip_h = false
	column.add_child(sprite)
	var name_label := _label(c.name, 13, UITheme.GOLD if c.is_hero() else UITheme.TEXT)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(name_label)
	var bar := HpBar.new()
	bar.custom_minimum_size = Vector2(maxf(64.0, side), 7)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(bar)
	var hp_label := _label("", 11, UITheme.TEXT)
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hp_label)
	var statuses := HFlowContainer.new()
	statuses.add_theme_constant_override("h_separation", 2)
	statuses.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(statuses)
	_tokens[c.id] = {"panel": panel, "bar": bar, "hp_label": hp_label, "statuses": statuses, "intent": intent}
	return panel


func _refresh_statuses(c: Combatant, box: HFlowContainer) -> void:
	for child in box.get_children():
		child.queue_free()
	for status_id: String in c.statuses:
		var chip := _label("%s %d" % [StatusEffects.name_of(status_id).substr(0, 4), c.stacks(status_id)], 10, Color("#1e1712"))
		var style := StyleBoxFlat.new()
		style.bg_color = StatusEffects.color_of(status_id)
		style.set_corner_radius_all(2)
		style.content_margin_left = 3
		style.content_margin_right = 3
		chip.add_theme_stylebox_override("normal", style)
		chip.tooltip_text = "%s (%d) : %s" % [StatusEffects.name_of(status_id), c.stacks(status_id),
			StatusEffects.description_of(status_id)]
		chip.mouse_filter = Control.MOUSE_FILTER_PASS
		box.add_child(chip)


func _on_token_input(event: InputEvent, c: Combatant) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and c in _targetable:
		target_chosen.emit(c)


func _flash(panel: Control) -> void:
	var tween := create_tween()
	tween.tween_property(panel, "self_modulate", Color(1.0, 0.35, 0.35), 0.08)
	tween.tween_property(panel, "self_modulate", Color.WHITE, 0.25)


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _token_style(active: bool, targetable: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.07, 0.05, 0.04, 0.72)
	box.border_color = UITheme.GOOD if targetable else (UITheme.BORDER_HOVER if active else Color(0.3, 0.25, 0.18))
	box.set_border_width_all(2 if active or targetable else 1)
	box.set_corner_radius_all(3)
	box.set_content_margin_all(4)
	return box
