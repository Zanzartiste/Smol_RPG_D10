class_name DamageTypes
extends RefCounted
## API des types de dégâts (tranchant, feu…). Définitions : data/damage_types.json.
## Le calcul des dégâts subis tient compte des défenses de la cible (voir Defenses) :
## immunité -> 0, résistance -> moitié (arrondie à l'inférieur), vulnérabilité -> double.
## Résistance et vulnérabilité au même type s'annulent.


static func ids() -> Array[String]:
	var result: Array[String] = []
	result.assign(DB.damage_types.keys())
	return result


static func has(id: String) -> bool:
	return DB.damage_types.has(id)


static func name_of(id: String) -> String:
	return DB.damage_types.get(id, {}).get("name", id)


## Dégâts physiques (contondant, perforant, tranchant).
static func is_physical(id: String) -> bool:
	return DB.damage_types.get(id, {}).get("physical", false)


## Dégâts réellement subis. Retourne {"amount": int, "note": String} ; la note explique
## l'effet des défenses (« résistance », « immunité », « vulnérabilité »), vide sinon.
static func apply(amount: int, damage_type: String, defenses: Defenses) -> Dictionary:
	if defenses == null or damage_type == "":
		return {"amount": amount, "note": ""}
	if defenses.has(Defenses.IMMUNITY, damage_type):
		return {"amount": 0, "note": Loc.ui("immunité")}
	var resistant := defenses.has(Defenses.RESISTANCE, damage_type)
	var vulnerable := defenses.has(Defenses.VULNERABILITY, damage_type)
	if resistant and not vulnerable:
		return {"amount": floori(amount / 2.0), "note": Loc.ui("résistance")}
	if vulnerable and not resistant:
		return {"amount": amount * 2, "note": Loc.ui("vulnérabilité")}
	return {"amount": amount, "note": ""}
