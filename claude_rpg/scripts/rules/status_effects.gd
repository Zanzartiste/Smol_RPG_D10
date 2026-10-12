class_name StatusEffects
extends RefCounted
## API des états (empoisonné, charmé, endormi…). Définitions : data/status_effects.json.
## Pour l'instant, les états servent aux immunités (Defenses) ; leurs effets en jeu viendront plus tard.


static func ids() -> Array[String]:
	var result: Array[String] = []
	result.assign(DB.status_effects.keys())
	return result


static func has(id: String) -> bool:
	return DB.status_effects.has(id)


static func name_of(id: String) -> String:
	return DB.status_effects.get(id, {}).get("name", id)


static func description_of(id: String) -> String:
	return DB.status_effects.get(id, {}).get("description", "")
