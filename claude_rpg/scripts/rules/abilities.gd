class_name Abilities
extends RefCounted
## API des attributs (Force, Dextérité…). Définitions : data/abilities.json.
## Tout le code passe par ici : ajouter, renommer ou retirer un attribut dans le JSON suffit
## (fiche, création, achat de points, tests, conditions et validation suivent automatiquement).


## Ids dans l'ordre d'affichage.
static func ids() -> Array[String]:
	var result: Array[String] = []
	result.assign(DB.abilities.keys())
	return result


static func all() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	result.assign(DB.abilities.values())
	return result


static func has(id: String) -> bool:
	return DB.abilities.has(id)


static func name_of(id: String) -> String:
	return DB.abilities.get(id, {}).get("name", id)


## Abréviation (FOR, DEX…).
static func short_of(id: String) -> String:
	return DB.abilities.get(id, {}).get("short", id.to_upper())


static func description_of(id: String) -> String:
	return DB.abilities.get(id, {}).get("description", "")


## Modificateur d'une valeur d'attribut : (valeur - 10) / 2, arrondi à l'inférieur.
static func modifier(score: int) -> int:
	return floori((score - 10) / 2.0)
