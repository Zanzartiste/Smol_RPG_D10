class_name WorldMap
## Carte du monde (locations.json › "map" : {"x", "y"} entre 0 et 1, "links" : lieux reliés).
## On peut se rendre dans un lieu déjà visité (téléportation, par simplicité) ou dans un lieu relié au lieu
## actuel (on le découvre). Les liaisons valent dans les deux sens.


static func position_of(location_id: String) -> Vector2:
	var map: Dictionary = DB.locations.get(location_id, {}).get("map", {})
	return Vector2(float(map.get("x", 0.5)), float(map.get("y", 0.5)))


## Lieux reliés à `location_id` (dans un sens ou dans l'autre).
static func links_of(location_id: String) -> Array[String]:
	var result: Array[String] = []
	for other: String in DB.locations[location_id].get("links", []):
		if other not in result:
			result.append(other)
	for loc: Dictionary in DB.locations.values():
		if location_id in loc.get("links", []) and loc["id"] not in result:
			result.append(loc["id"])
	return result


## Lieu sûr (ville, domicile) : ni sauvage ni dangereux.
static func is_safe(location_id: String) -> bool:
	var loc: Dictionary = DB.locations.get(location_id, {})
	return not loc.get("wild", false) and not loc.get("unsafe", false)


static func current(life: LifeState) -> String:
	return life.location if life.location != "" else DB.location_order[0]


static func is_visited(life: LifeState, location_id: String) -> bool:
	return location_id in life.visited or location_id == current(life)


## Peut-on s'y rendre depuis le lieu actuel ?
static func can_travel(life: LifeState, location_id: String) -> bool:
	var here := current(life)
	return location_id != here and DB.locations.has(location_id) \
		and (is_visited(life, location_id) or location_id in links_of(here))


## Se rend dans un lieu (sans passer de temps pour l'instant) et le marque comme visité.
static func travel(life: LifeState, location_id: String) -> void:
	visit(life, current(life))
	life.location = location_id
	visit(life, location_id)


static func visit(life: LifeState, location_id: String) -> void:
	if location_id not in life.visited:
		life.visited.append(location_id)
