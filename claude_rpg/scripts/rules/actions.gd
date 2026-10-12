class_name Actions
extends RefCounted
## API des actions de combat des classes (attaques, sorts, capacités). Définitions : data/actions.json.
## Une action : {"id", "name", "description", "target", "effects": [...] (voir CombatEffects),
##               "cost"?: ressource consommée (ex. "spell_slot", rechargée par un repos long),
##               "per_combat"?: nombre d'utilisations par combat}
## Une action sans coût ni limite (attaque, tour de magie) est utilisable à volonté.


static func ids() -> Array[String]:
	var result: Array[String] = []
	result.assign(DB.actions.keys())
	return result


static func has(id: String) -> bool:
	return DB.actions.has(id)


static func def(id: String) -> Dictionary:
	return DB.actions.get(id, {})


static func name_of(id: String) -> String:
	return def(id).get("name", id)


static func target_of(id: String) -> String:
	return def(id).get("target", "enemy")


## Texte des effets, ex. « Attaque avec votre arme. Si elle touche : 1 Étourdi. »
static func text_of(id: String) -> String:
	return CombatEffects.describe_all(def(id).get("effects", []), target_of(id))


## Nom lisible d'une ressource (ex. "spell_slot" -> « emplacement de sort »).
static func resource_name(resource_id: String) -> String:
	return {"spell_slot": Loc.ui("emplacement de sort")}.get(resource_id, resource_id)
