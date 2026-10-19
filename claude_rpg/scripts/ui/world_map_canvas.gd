class_name WorldMapCanvas
extends Control
## Dessin de la carte du monde (page Carte du tiroir). Chaque lieu est un point : rouge (sauvage), bleu (sûr :
## ville, domicile), vert (lieu actuel), relié à ses voisins par des segments. Un contour doré marque les lieux
## déjà visités ; un contour clair, les voisins encore inconnus. Cliquer un point accessible émet
## travel_requested, sauf si `block_reason` n'est pas vide (combat, événement, prison…). Règles : WorldMap.

signal travel_requested(location_id: String)

const RADIUS := 12.0
const WILD := Color("#c4513a")
const SAFE := Color("#4f7fc4")
const HERE := Color("#6fb24f")
const UNKNOWN := Color("#d8d0bf")

var life: LifeState
var block_reason := ""


func _init(life_state: LifeState, blocked := "") -> void:
	life = life_state
	block_reason = blocked


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_layout_labels)
	for loc_id: String in DB.location_order:
		var label := Label.new()
		label.name = loc_id
		label.text = DB.locations[loc_id]["name"]
		label.add_theme_font_size_override("font_size", 13)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)


## Légende des couleurs (texte BBCode).
static func legend() -> String:
	return "[color=%s]●[/color] %s   [color=%s]●[/color] %s   [color=%s]●[/color] %s\n[color=%s]○[/color] %s" % [
		HERE.to_html(false), Loc.ui("ici"), SAFE.to_html(false), Loc.ui("lieu sûr"), WILD.to_html(false),
		Loc.ui("sauvage"), UITheme.GOLD.to_html(false), Loc.ui("déjà visité : cliquez pour y aller")]


func _point(loc_id: String) -> Vector2:
	var margin := Vector2(40, 24)
	return margin + WorldMap.position_of(loc_id) * (size - margin * 2)


func _draw() -> void:
	var here := WorldMap.current(life)
	for loc_id: String in DB.location_order:
		for other: String in WorldMap.links_of(loc_id):
			if loc_id < other:
				draw_line(_point(loc_id), _point(other), UITheme.TEXT_DIM, 3.0, true)
	for loc_id: String in DB.location_order:
		var p := _point(loc_id)
		var known := WorldMap.can_travel(life, loc_id) or WorldMap.is_visited(life, loc_id)
		var color := HERE if loc_id == here else (SAFE if WorldMap.is_safe(loc_id) else WILD)
		if loc_id != here and not known:
			color = color.darkened(0.5)
		draw_circle(p, RADIUS, color, true, -1.0, true)
		if loc_id != here and known:
			draw_arc(p, RADIUS + 4, 0, TAU, 32, UITheme.GOLD if WorldMap.is_visited(life, loc_id) else UNKNOWN, 3.0, true)


func _layout_labels() -> void:
	for label: Label in get_children():
		label.reset_size()
		label.position = _point(label.name) + Vector2(-label.size.x / 2, RADIUS + 6)
	queue_redraw()


## Lieu sous le pointeur ("" sinon).
func location_at(pos: Vector2) -> String:
	for loc_id: String in DB.location_order:
		if pos.distance_to(_point(loc_id)) <= RADIUS + 8:
			return loc_id
	return ""


func can_go(loc_id: String) -> bool:
	return block_reason == "" and WorldMap.can_travel(life, loc_id)


func _gui_input(event: InputEvent) -> void:
	var loc_id := location_at(get_local_mouse_position())
	if event is InputEventMouseMotion:
		tooltip_text = _tooltip(loc_id)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if can_go(loc_id) else Control.CURSOR_ARROW
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT and can_go(loc_id):
		accept_event()
		travel_requested.emit(loc_id)


func _tooltip(loc_id: String) -> String:
	if loc_id == "":
		return ""
	var loc: Dictionary = DB.locations[loc_id]
	var status := Loc.ui("Vous êtes ici.")
	if loc_id != WorldMap.current(life):
		status = Loc.ui("Trop loin : passez par un lieu voisin.")
		if WorldMap.can_travel(life, loc_id):
			status = block_reason if block_reason != "" else Loc.ui("Cliquez pour y aller.")
	return "%s\n%s\n%s" % [loc["name"], loc.get("description", ""), status]
