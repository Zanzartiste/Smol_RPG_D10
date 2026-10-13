class_name CarnetView
extends Control
## Carnet des PNJ rencontrés dans cette vie (bouton « Carnet » sous la fiche, touche C) : liste à gauche,
## fiche du PNJ choisi à droite (portrait, rôle, statut, jauges, traits, faits, souvenirs), et la
## réputation du héros par lieu.

signal closed
signal changed  # non utilisé (lecture seule), pour l'interface commune des fenêtres

var life: LifeState
var _selected: Npc
var _list := VBoxContainer.new()
var _portrait := TextureRect.new()
var _text := RichTextLabel.new()


func _init(life_state: LifeState) -> void:
	life = life_state


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1000, 600)
	center.add_child(panel)
	var root := VBoxContainer.new()
	panel.add_child(root)
	var header := HBoxContainer.new()
	var title := Label.new()
	title.text = tr("Carnet")
	title.theme_type_variation = &"TitleLabel"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := Button.new()
	close.text = tr("Fermer (Échap)")
	close.pressed.connect(close_view, CONNECT_DEFERRED)
	header.add_child(close)
	root.add_child(header)
	var reputation := Label.new()
	var parts := PackedStringArray()
	for loc_id: String in DB.location_order:
		parts.append("%s : %s" % [DB.locations[loc_id]["name"], Social.reputation_name(int(life.reputation.get(loc_id, 0)))])
	reputation.text = tr("Réputation — %s") % " · ".join(parts)
	reputation.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	root.add_child(reputation)
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 16)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(300, 0)
	scroll.add_child(_list)
	columns.add_child(scroll)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_portrait.custom_minimum_size = Vector2(96, 96)
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	right.add_child(_portrait)
	_text.bbcode_enabled = true
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_text)
	columns.add_child(right)
	root.add_child(columns)
	var known := Social.known_npcs()
	for n in known:
		var button := Button.new()
		button.text = "%s — %s (%s)" % [n.name, n.role_name(), Social.status_name(n)]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(select.bind(n), CONNECT_DEFERRED)
		_list.add_child(button)
	if known.is_empty():
		_text.text = tr("Vous n'avez encore rencontré personne dans cette vie.")
	else:
		select(known[0])


func select(n: Npc) -> void:
	_selected = n
	_portrait.texture = SocialView.npc_portrait(n)
	var gold := UITheme.GOLD.to_html(false)
	_text.text = "[font_size=24][color=%s]%s[/color][/font_size]\n%s · %s · %s · %s\n\n" % [gold, n.name, n.role_name(),
		DB.species[n.species]["name"], tr("%d ans") % n.age(Meta.world_day), Social.status_name(n)] + SocialView.describe(n, life, false)


func close_view() -> void:
	closed.emit()
	queue_free()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode in [KEY_ESCAPE, KEY_C]:
		accept_event()
		close_view()
