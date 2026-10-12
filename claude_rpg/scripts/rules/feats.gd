class_name Feats
extends RefCounted
## API des dons (Vigilant, Robuste…). Définitions : data/feats.json.
## Un don a des prérequis (mêmes conditions que les événements, évaluées sur le personnage)
## et des modificateurs (voir Modifiers) appliqués automatiquement au personnage qui le possède.


static func ids() -> Array[String]:
	var result: Array[String] = []
	result.assign(DB.feats.keys())
	return result


static func all() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	result.assign(DB.feats.values())
	return result


static func has(id: String) -> bool:
	return DB.feats.has(id)


static func name_of(id: String) -> String:
	return DB.feats.get(id, {}).get("name", id)


static func description_of(id: String) -> String:
	return DB.feats.get(id, {}).get("description", "")


static func modifiers_of(id: String) -> Array:
	return DB.feats.get(id, {}).get("modifiers", [])


## Prérequis remplis ? Seules les conditions portant sur le personnage ont du sens ici
## (ability, level, species, class, background, skill_proficient, size...).
static func meets_prerequisites(id: String, ch: Character) -> bool:
	var life := LifeState.new()
	life.character = ch
	return Conditions.check_all(DB.feats.get(id, {}).get("prerequisites", []), life, null)
