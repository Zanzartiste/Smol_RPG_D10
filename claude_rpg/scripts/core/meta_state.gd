class_name MetaState
extends Node
## Autoload « Meta » : tout ce qui survit à la mort du personnage
## (état du monde, déblocages, chronique des vies). Sauvegarde sur disque : à venir.

var world_flags: Dictionary = {}
var unlocks: Dictionary = {}  # "species:elf", "class:rogue"... -> true
var seen_events: Dictionary = {}  # id d'événement -> nombre de fois vu, toutes vies confondues
var chronicle: Array[Dictionary] = []
var creator_points := 0
## Monde vivant : PNJ (id -> Npc), horloge du monde (jours, toutes vies confondues), grossesses en cours.
var npcs: Dictionary = {}
var world_day := 0
var pregnancies: Array = []
var next_npc_id := 0
## Réglages du joueur (conservés même quand on efface le monde) :
##   manual_skill_ability : choisir soi-même l'attribut d'un test de compétence (sinon le meilleur) ;
##   many_dice : règle des dés nombreux (10 dés -> seuil + 1 succès automatiques, voir Dice).
var settings := {"manual_skill_ability": false, "many_dice": false, "auto_reactions": false}  # Creator Points disponibles (gagnés à chaque mort, dépensés à la création)


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


## Dépense des Creator Points ; retourne false si le solde est insuffisant.
func spend_creator_points(amount: int) -> bool:
	if amount > creator_points:
		return false
	creator_points -= amount
	return true


## Achète le déblocage définitif d'une espèce ou d'une classe ("species:elf", "class:rogue").
func buy_unlock(unlock_id: String) -> bool:
	var cost := CreatorPoints.unlock_cost(unlock_id)
	if cost <= 0 or is_unlocked(unlock_id) or not spend_creator_points(cost):
		return false
	unlock(unlock_id)
	return true


func is_species_available(species_id: String) -> bool:
	return not DB.species[species_id].get("locked", false) or is_unlocked("species:" + species_id)


func is_class_available(class_id: String) -> bool:
	return not DB.classes[class_id].get("locked", false) or is_unlocked("class:" + class_id)


func mark_event_seen(event_id: String) -> void:
	seen_events[event_id] = int(seen_events.get(event_id, 0)) + 1


## Inscrit la vie dans la chronique et crédite les Creator Points gagnés (selon l'XP du héros).
func record_life(life: LifeState) -> void:
	var ch := life.character
	var earned := CreatorPoints.earned_for(ch.xp)
	creator_points += earned
	chronicle.append({
		"xp": ch.xp,
		"creator_points": earned,
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
	return {"world_flags": world_flags, "unlocks": unlocks, "seen_events": seen_events, "chronicle": chronicle,
		"creator_points": creator_points, "settings": settings,
		"npcs": npcs.values().map(func(n): return n.to_dict()), "world_day": world_day, "pregnancies": pregnancies,
		"next_npc_id": next_npc_id}


func load_dict(data: Dictionary) -> void:
	world_flags = data.get("world_flags", {})
	unlocks = data.get("unlocks", {})
	seen_events = Character._int_dict(data.get("seen_events", {}))
	creator_points = int(data.get("creator_points", 0))
	settings.merge(data.get("settings", {}), true)
	npcs.clear()
	for entry: Dictionary in data.get("npcs", []):
		var n := Npc.from_dict(entry)
		npcs[n.id] = n
	world_day = int(data.get("world_day", 0))
	pregnancies = data.get("pregnancies", [])
	next_npc_id = int(data.get("next_npc_id", 0))
	chronicle.clear()
	for entry: Dictionary in data.get("chronicle", []):
		var life := entry.duplicate()
		for key in ["age", "days", "level", "xp", "creator_points"]:
			life[key] = int(life.get(key, 0))
		chronicle.append(life)


## Efface toute la méta-progression (nouveau monde).
func reset() -> void:
	var kept := settings.duplicate()
	load_dict({})
	settings = kept
