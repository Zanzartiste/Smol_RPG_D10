extends Node
## Autoload « DB » : charge toutes les données de jeu (JSON de res://data/) au démarrage.
## Les erreurs de contenu détectées par DataValidator sont listées dans `errors`.

const DATA_DIR := "res://data/"

var rules: Dictionary = {}
var abilities: Dictionary = {}  # id -> {id, name, short}
var skills: Dictionary = {}  # id -> {id, name, ability}
var races: Dictionary = {}
var classes: Dictionary = {}
var items: Dictionary = {}
var locations: Dictionary = {}
var location_order: Array[String] = []
var events: Dictionary = {}
var events_by_location: Dictionary = {}  # id de lieu -> Array des événements tirables
var errors: Array[String] = []


func _ready() -> void:
	load_all()


func load_all() -> void:
	errors.clear()
	rules = _load_json("rules.json", {})
	abilities = _index_by_id(rules.get("abilities", []), "rules.json (abilities)")
	skills = _index_by_id(rules.get("skills", []), "rules.json (skills)")
	races = _index_by_id(_load_json("races.json", []), "races.json")
	classes = _index_by_id(_load_json("classes.json", []), "classes.json")
	items = _index_by_id(_load_json("items.json", []), "items.json")
	locations = _index_by_id(_load_json("locations.json", []), "locations.json")
	location_order.assign(locations.keys())

	events.clear()
	events_by_location.clear()
	for file in DirAccess.get_files_at(DATA_DIR + "events"):
		if file.get_extension() != "json":
			continue
		for ev in _load_json("events/" + file, []):
			_register_event(ev, file)

	DataValidator.validate(self)
	for e in errors:
		push_error("[Données] " + e)


func events_for(location_id: String) -> Array:
	return events_by_location.get(location_id, [])


func time_slots() -> Array:
	return rules.get("time_slots", [{"id": "day", "name": "Jour"}])


func slots_per_day() -> int:
	return time_slots().size()


func days_per_year() -> int:
	return maxi(1, int(rules.get("days_per_year", 10)))


func life_stage_name(stage_id: String) -> String:
	for stage: Dictionary in rules.get("life_stages", []):
		if stage["id"] == stage_id:
			return stage["name"]
	return stage_id


func _register_event(ev: Variant, file: String) -> void:
	if typeof(ev) != TYPE_DICTIONARY or not ev.has("id"):
		errors.append("events/%s : événement sans id" % file)
		return
	var id: String = ev["id"]
	if events.has(id):
		errors.append("events/%s : id d'événement en double « %s »" % [file, id])
		return
	ev["_file"] = file
	events[id] = ev
	var location: Variant = ev.get("location")
	if location != null:
		if not events_by_location.has(location):
			events_by_location[location] = []
		events_by_location[location].append(ev)


func _load_json(rel_path: String, default_value: Variant) -> Variant:
	var path := DATA_DIR + rel_path
	if not FileAccess.file_exists(path):
		errors.append("Fichier introuvable : " + path)
		return default_value
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		errors.append("%s, ligne %d : %s" % [path, json.get_error_line(), json.get_error_message()])
		return default_value
	if typeof(json.data) != typeof(default_value):
		errors.append("%s : type racine inattendu" % path)
		return default_value
	return json.data


func _index_by_id(list: Variant, source: String) -> Dictionary:
	var result := {}
	if typeof(list) != TYPE_ARRAY:
		return result
	for entry: Variant in list:
		if typeof(entry) != TYPE_DICTIONARY or not entry.has("id"):
			errors.append("%s : entrée sans id" % source)
			continue
		if result.has(entry["id"]):
			errors.append("%s : id en double « %s »" % [source, entry["id"]])
		result[entry["id"]] = entry
	return result
