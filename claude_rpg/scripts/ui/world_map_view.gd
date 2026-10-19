class_name WorldMapView
extends Control
## Fenêtre de la carte du monde (touche V ou onglet Carte du tiroir), consultable partout. Chaque lieu est un point :
## rouge (sauvage), bleu (sûr : ville, domicile), vert (lieu actuel), relié à ses voisins par des segments.
## Un contour doré marque les lieux déjà visités, où l'on peut se rendre directement ; un contour clair, les
## voisins encore inconnus. Cliquer un point accessible y emmène (signal travel_requested). Règles : WorldMap.

signal changed  # (contrat des fenêtres du hub, inutilisé ici)
signal closed
signal travel_requested(location_id: String)

const RADIUS := 13.0
const WILD := Color("#c4513a")
const SAFE := Color("#4f7fc4")
const HERE := Color("#6fb24f")
const UNKNOWN := Color("#d8d0bf")

var life: LifeState
var block_reason := ""  # non vide : la carte se consulte, mais on ne peut pas se déplacer (combat, prison…)
var _canvas := Control.new()


func _init(life_state: LifeState, blocked := "") -> void:
	life = life_state
	block_reason = blocked


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
	panel.custom_minimum_size = Vector2(minf(900, get_viewport_rect().size.x - 32), minf(600, get_viewport_rect().size.y - 32))
	center.add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	panel.add_child(root)

	var header := HBoxContainer.new()
	var title := Label.new()
	title.text = tr("Carte")
	title.theme_type_variation = &"TitleLabel"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := Button.new()
	close.text = tr("Fermer (Échap)")
	close.pressed.connect(close_view, CONNECT_DEFERRED)
	header.add_child(close)
	root.add_child(header)

	var legend := RichTextLabel.new()
	legend.bbcode_enabled = true
	legend.fit_content = true
	legend.text = "[color=%s]●[/color] %s   [color=%s]●[/color] %s   [color=%s]●[/color] %s   [color=%s]○[/color] %s" % [
		HERE.to_html(false), tr("vous êtes ici"), SAFE.to_html(false), tr("lieu sûr"), WILD.to_html(false), tr("lieu sauvage"),
		UITheme.GOLD.to_html(false), tr("déjà visité : cliquez pour y aller")]
	root.add_child(legend)
	if block_reason != "":
		var blocked := Label.new()
		blocked.text = block_reason
		blocked.add_theme_color_override("font_color", UITheme.BAD)
		root.add_child(blocked)

	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.draw.connect(_draw_map)
	_canvas.gui_input.connect(_on_canvas_input)
	_canvas.resized.connect(_layout_labels)
	root.add_child(_canvas)
	for loc_id: String in DB.location_order:
		var label := Label.new()
		label.name = loc_id
		label.text = DB.locations[loc_id]["name"]
		label.add_theme_font_size_override("font_size", 14)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_canvas.add_child(label)


func close_view() -> void:
	closed.emit()
	queue_free()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode in [KEY_ESCAPE, KEY_V]:
		accept_event()
		close_view()


func _point(loc_id: String) -> Vector2:
	var margin := Vector2(40, 30)
	return margin + WorldMap.position_of(loc_id) * (_canvas.size - margin * 2)


func _draw_map() -> void:
	var here := WorldMap.current(life)
	for loc_id: String in DB.location_order:
		for other: String in WorldMap.links_of(loc_id):
			if loc_id < other:
				_canvas.draw_line(_point(loc_id), _point(other), UITheme.TEXT_DIM, 3.0, true)
	for loc_id: String in DB.location_order:
		var p := _point(loc_id)
		var color := HERE if loc_id == here else (SAFE if WorldMap.is_safe(loc_id) else WILD)
		if loc_id != here and not WorldMap.can_travel(life, loc_id) and not WorldMap.is_visited(life, loc_id):
			color = color.darkened(0.5)
		_canvas.draw_circle(p, RADIUS, color, true, -1.0, true)
		if loc_id != here and (WorldMap.can_travel(life, loc_id) or WorldMap.is_visited(life, loc_id)):
			var ring := UITheme.GOLD if WorldMap.is_visited(life, loc_id) else UNKNOWN
			_canvas.draw_arc(p, RADIUS + 4, 0, TAU, 32, ring, 3.0, true)


func _layout_labels() -> void:
	for label: Label in _canvas.get_children():
		label.reset_size()
		label.position = _point(label.name) + Vector2(-label.size.x / 2, RADIUS + 6)
	_canvas.queue_redraw()


## Lieu sous le pointeur ("" sinon).
func location_at(pos: Vector2) -> String:
	for loc_id: String in DB.location_order:
		if pos.distance_to(_point(loc_id)) <= RADIUS + 8:
			return loc_id
	return ""


func _on_canvas_input(event: InputEvent) -> void:
	var loc_id := location_at(_canvas.get_local_mouse_position())
	if event is InputEventMouseMotion:
		_canvas.tooltip_text = _tooltip(loc_id)
		_canvas.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if _can_go(loc_id) else Control.CURSOR_ARROW
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT and _can_go(loc_id):
		accept_event()
		travel_requested.emit(loc_id)
		close_view()


func _can_go(loc_id: String) -> bool:
	return block_reason == "" and WorldMap.can_travel(life, loc_id)


func _tooltip(loc_id: String) -> String:
	if loc_id == "":
		return ""
	var loc: Dictionary = DB.locations[loc_id]
	var status := tr("Vous êtes ici.")
	if loc_id != WorldMap.current(life):
		status = tr("Trop loin : passez par un lieu voisin.")
		if WorldMap.can_travel(life, loc_id):
			status = block_reason if block_reason != "" else tr("Cliquez pour y aller.")
	return "%s\n%s\n%s" % [loc["name"], loc.get("description", ""), status]
