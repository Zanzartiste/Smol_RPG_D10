class_name DamageTypes
extends RefCounted
## API des types de dégâts (tranchant, feu…). Définitions : data/damage_types.json.
## Le calcul des dégâts subis tient compte des défenses de la cible (voir Defenses) :
## immunité -> 0, résistance -> moitié (arrondie à l'inférieur), vulnérabilité -> double.
## Résistance et vulnérabilité au même type s'annulent.
## Un type peut infliger un état quand il blesse : "status": {"id": "burning", "chance": 0.25, "stacks": 1}
## (le feu enflamme une fois sur quatre). Les dégâts des états eux-mêmes ne le déclenchent pas.


static func ids() -> Array[String]:
	var result: Array[String] = []
	result.assign(DB.damage_types.keys())
	return result


static func has(id: String) -> bool:
	return DB.damage_types.has(id)


static func name_of(id: String) -> String:
	return DB.damage_types.get(id, {}).get("name", id)


## Couleur du type (journal de combat, fiches).
static func color_of(id: String) -> Color:
	return Color(String(DB.damage_types.get(id, {}).get("color", "#d8cfc0")))


## Nom en minuscules, coloré en BBCode.
static func bbcode_name(id: String) -> String:
	return "[color=#%s]%s[/color]" % [color_of(id).to_html(false), name_of(id).to_lower()]


## État que ce type peut infliger : {"id", "chance", "stacks"}, ou {} si aucun.
static func status_of(id: String) -> Dictionary:
	return DB.damage_types.get(id, {}).get("status", {})


## Dégâts physiques (contondant, perforant, tranchant).
static func is_physical(id: String) -> bool:
	return DB.damage_types.get(id, {}).get("physical", false)


## Dégâts réellement subis. Retourne {"amount": int, "note": String} ; la note explique
## l'effet des défenses (« résistance », « immunité », « vulnérabilité »), vide sinon.
static func apply(amount: int, damage_type: String, defenses: Defenses, ignore_resistance := false) -> Dictionary:
	if defenses == null or damage_type == "":
		return {"amount": amount, "note": ""}
	if defenses.has(Defenses.IMMUNITY, damage_type):
		return {"amount": 0, "note": Loc.ui("immunité")}
	var resistant := defenses.has(Defenses.RESISTANCE, damage_type) and not ignore_resistance
	var vulnerable := defenses.has(Defenses.VULNERABILITY, damage_type)
	if resistant and not vulnerable:
		return {"amount": floori(amount / 2.0), "note": Loc.ui("résistance")}
	if vulnerable and not resistant:
		return {"amount": amount * 2, "note": Loc.ui("vulnérabilité")}
	return {"amount": amount, "note": ""}
