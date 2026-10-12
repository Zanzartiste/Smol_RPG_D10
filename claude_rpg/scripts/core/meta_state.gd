class_name MetaState
extends Node
## Autoload « Meta » : tout ce qui survit à la mort du personnage
## (état du monde, déblocages, chronique des vies). Sauvegarde sur disque : à venir.

var world_flags: Dictionary = {}
var unlocks: Dictionary = {}  # "species:elf", "class:rogue"... -> true
var seen_events: Dictionary = {}  # id d'événement -> nombre de fois vu, toutes vies confondues
var chronicle: Array[Dictionary] = []


func has_world_flag(id: String) -> bool:
	return bool(world_flags.get(id, false))


func set_world_flag(id: String, value := true) -> void:
	if value:
		world_flags[id] = true
	else:
		world_flags.erase(id)


func is_unlocked(id: String) -> bool:
	return unlocks.has(id)


## Retourne true si le déblocage est nouveau.
func unlock(id: String) -> bool:
	if unlocks.has(id):
		return false
	unlocks[id] = true
	return true


func unlock_name(id: String) -> String:
	var parts := id.split(":")
	if parts.size() == 2:
		match parts[0]:
			"species":
				return DB.species.get(parts[1], {}).get("name", id)
			"class":
				return DB.classes.get(parts[1], {}).get("name", id)
	return id


func is_species_available(species_id: String) -> bool:
	return not DB.species[species_id].get("locked", false) or is_unlocked("species:" + species_id)


func is_class_available(class_id: String) -> bool:
	return not DB.classes[class_id].get("locked", false) or is_unlocked("class:" + class_id)


func mark_event_seen(event_id: String) -> void:
	seen_events[event_id] = int(seen_events.get(event_id, 0)) + 1


func record_life(life: LifeState) -> void:
	var ch := life.character
	chronicle.append({
		"name": ch.name,
		"species": ch.species_id,
		"class": ch.class_id,
		"age": ch.age_years(),
		"days": life.day,
		"level": ch.level,
		"cause": life.death_cause,
	})


# --- Sauvegarde ----------------------------------------------------------------

func to_dict() -> Dictionary:
	return {"world_flags": world_flags, "unlocks": unlocks, "seen_events": seen_events, "chronicle": chronicle}


func load_dict(data: Dictionary) -> void:
	world_flags = data.get("world_flags", {})
	unlocks = data.get("unlocks", {})
	seen_events = Character._int_dict(data.get("seen_events", {}))
	chronicle.clear()
	for entry: Dictionary in data.get("chronicle", []):
		var life := entry.duplicate()
		for key in ["age", "days", "level"]:
			life[key] = int(life.get(key, 0))
		chronicle.append(life)


## Efface toute la méta-progression (nouveau monde).
func reset() -> void:
	load_dict({})
