class_name Actions
extends RefCounted
## API des actions de combat des classes (attaques, sorts, capacités). Définitions : data/actions.json.
## Une action : {"id", "name", "description", "target", "effects": [...] (voir CombatEffects),
##               "cost"?: ressource consommée, rechargée par un repos long ("spell_slot" : un emplacement
##                        d'au moins "spell_level", voir Spellcasting),
##               "per_combat"?: nombre d'utilisations par combat,
##               "attack_action"?: true pour l'action Attaque (Attaque supplémentaire),
##               "free"?: true si l'action ne consomme pas l'action du tour (Fougue)}
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


## Nom lisible d'une ressource (ex. "spell_slot_2" -> « emplacement de sort de niveau 2 »).
static func resource_name(resource_id: String) -> String:
	if Spellcasting.is_slot(resource_id):
		return Loc.ui("emplacement de sort de niveau %d") % Spellcasting.slot_level(resource_id)
	return {"spell_slot": Loc.ui("emplacement de sort"), "indomitable": Loc.ui("Inflexible"),
		"relentless_endurance": Loc.ui("Endurance implacable")}.get(resource_id, resource_id)
