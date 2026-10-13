class_name Creatures
extends RefCounted
## API du bestiaire : ennemis et invocations. Définitions : data/creatures.json.
## Une créature : {"id", "name", "size", "hp"?, "armor"?, "abilities", "skills"?, "actions": [...],
##                 "xp"?, "gold"?, "loot"?, "defenses"?, "death_cause"?, "summon"?, "art"}
## Une action : {"name", "weight", "target", "announced"?, "effects": [...] (voir CombatEffects)}.
## Une action « announced » est annoncée un tour à l'avance (visible par le joueur), puis exécutée.


static func ids() -> Array[String]:
	var result: Array[String] = []
	result.assign(DB.creatures.keys())
	return result


static func has(id: String) -> bool:
	return DB.creatures.has(id)


static func def(id: String) -> Dictionary:
	return DB.creatures.get(id, {})


static func name_of(id: String) -> String:
	return def(id).get("name", id)


static func size_of(id: String) -> int:
	return int(def(id).get("size", 0))


static func actions_of(id: String) -> Array:
	return def(id).get("actions", [])


static func is_summon(id: String) -> bool:
	return def(id).get("summon", false)
