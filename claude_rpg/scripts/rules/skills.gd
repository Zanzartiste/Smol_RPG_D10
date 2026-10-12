class_name Skills
extends RefCounted
## API des compétences (Athlétisme, Discrétion…). Définitions : data/skills.json.
## Chaque compétence dépend d'un attribut (Abilities). Ajouter ou modifier une compétence dans le JSON
## suffit : fiche, tests d'événements, classes, passés et validation suivent automatiquement.


## Ids dans l'ordre d'affichage.
static func ids() -> Array[String]:
	var result: Array[String] = []
	result.assign(DB.skills.keys())
	return result


static func all() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	result.assign(DB.skills.values())
	return result


static func has(id: String) -> bool:
	return DB.skills.has(id)


static func name_of(id: String) -> String:
	return DB.skills.get(id, {}).get("name", id)


## Attribut associé (ex. "athletics" -> "str").
static func ability_of(id: String) -> String:
	return DB.skills.get(id, {}).get("ability", "str")


static func names_of(ids_list: Array) -> String:
	return ", ".join(PackedStringArray(ids_list.map(func(id): return name_of(id))))
