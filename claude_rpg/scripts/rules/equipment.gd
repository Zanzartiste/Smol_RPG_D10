class_name Equipment
extends RefCounted
## API de l'équipement (armes, armures, boucliers). Définitions : data/equipment.json.
## Classes, personnages et ennemis ne font que référencer des ids d'équipement : modifier une arme ici
## (dégâts, type, propriétés) la modifie partout.
##
## Arme  : {"category": "weapon", "skill"?: "physique", "damage": {"dice": N, "threshold": "str" | "dex" | N, "bonus"?: N},
##          "damage_type": "slashing", "parry"?: N, "parry_two_hands"?: N, "weight"?: N, "weight_two_hands"?: N,
##          "crit_bonus"?: N, "reload"?: N, "fragile"?: N, "properties": [...] (voir PROPERTY_NAMES)}
##   Attaque : [rang de la compétence] d10 contre la DEX. Compétence : "skill", sinon Armes de trait (à distance)
##   ou Armes de mêlée.
##   Dégâts : "dice" d10 (les dés de l'arme, sans le rang) contre "threshold" (FOR par défaut, DEX, ou un seuil
##   fixe pour les arcs et les arbalètes), + "bonus" (épée bâtarde : FOR +1).
##   "parry" : seuil de parade à une main ("parry_two_hands" : à deux mains). Sans "parry", l'arme ne pare pas.
##   "weight" / "weight_two_hands" : poids dans l'encombrement, tenue à une ou à deux mains. Sans "weight",
##   elle ne se tient qu'à deux mains (propriété "two_handed" : arcs). On la tient à deux mains si l'autre est libre.
##   "crit_bonus" : dégâts en plus sur un critique (Perçante). "reload" : actions pour recharger après un tir.
##   "fragile" (Imprévisible) : l'arme se brise si le jet d'attaque fait au moins autant de 10.
## Armure : {"category": "armor", "armor_type": "clothing" | "light" | "medium" | "heavy", "armor": N, "weight": N}
##           N : points d'Armure (baissent le seuil des dégâts subis) ; "weight" : poids dans l'encombrement.
## Bouclier : {"category": "shield", "armor": 1, "parry": 4, "weight": N} (pare aussi les attaques à distance)
## Accessoire : {"category": "accessory", "slot": "head" | "cloak" | "hands" | "legs" | "feet" | "neck" | "ring"}
##           (un anneau va dans ring_1, ou ring_2 si le premier est pris ; son poids ne compte pas)
## Encombrement (voir Character.encumbrance) : poids de l'armure, du bouclier et des armes en main.
## Facultatif pour tous : "modifiers" (voir Modifiers), "rarity", "value", "description" (voir Items).
## Facultatif pour une arme : "bonus_damage": [{"dice": 2, "threshold": 5, "damage_type": "fire"}], dégâts
## d'autres types ajoutés à chaque coup (une épée enflammée : tranchant + feu).
## Un objet magique est un équipement avec des modificateurs, ex. une épée +1 (un dé d'attaque et un
## dé de dégâts) : "modifiers": [{"type": "weapon_attack", "amount": 1}, {"type": "weapon_damage", "amount": 1}]

const SLOTS := ["main_hand", "off_hand", "head", "armor", "cloak", "hands", "legs", "feet", "neck", "ring_1", "ring_2"]
const ACCESSORY_SLOTS := ["head", "cloak", "hands", "legs", "feet", "neck", "ring"]
const SLOT_NAMES := {
	"main_hand": "Main principale", "off_hand": "Main secondaire", "head": "Couvre-chef", "armor": "Torse", "cloak": "Cape",
	"hands": "Gants", "legs": "Jambes", "feet": "Chaussures", "neck": "Collier", "ring": "Anneau",
	"ring_1": "Anneau", "ring_2": "Anneau",
}
## Emplacements multiples : un type d'emplacement -> ses emplacements réels.
const SLOT_GROUPS := {"ring": ["ring_1", "ring_2"]}
const UNARMED := "unarmed"
const ATTACK_ABILITY := "dex"  # attribut d'attaque de toutes les armes

const PROPERTY_NAMES := {
	"ranged": "à distance", "two_handed": "à deux mains", "thrown": "de lancer", "dangerous_parry": "parade dangereuse",
	"impact": "à impact", "reach": "allonge", "assassin": "assassine", "crossbow": "arbalète",
}
const ARMOR_TYPE_NAMES := {"clothing": "vêtement", "light": "légère", "medium": "intermédiaire", "heavy": "lourde"}


static func ids() -> Array[String]:
	var result: Array[String] = []
	result.assign(DB.equipment.keys())
	return result


static func has(id: String) -> bool:
	return DB.equipment.has(id) or not Crafting.upgraded_def(id).is_empty()


## Définition d'un équipement ; un id « base@rang » (amélioré à la forge) est calculé par Crafting.
static func def(id: String) -> Dictionary:
	if DB.equipment.has(id):
		return DB.equipment[id]
	return Crafting.upgraded_def(id) if Crafting.UPGRADE_SEPARATOR in id else {}


static func name_of(id: String) -> String:
	return def(id).get("name", id)


static func category_of(id: String) -> String:
	return def(id).get("category", "")


static func is_weapon(id: String) -> bool:
	return category_of(id) == "weapon"


static func is_armor(id: String) -> bool:
	return category_of(id) == "armor"


static func is_shield(id: String) -> bool:
	return category_of(id) == "shield"


static func has_property(id: String, property: String) -> bool:
	return property in def(id).get("properties", [])


## Emplacement naturel d'un équipement : arme -> main_hand, bouclier -> off_hand, armure -> armor,
## accessoire -> son "slot".
static func slot_for(id: String) -> String:
	match category_of(id):
		"weapon":
			return "main_hand"
		"shield":
			return "off_hand"
		"armor":
			return "armor"
		"accessory":
			return def(id).get("slot", "")
	return ""


static func slot_name(slot: String) -> String:
	return Loc.ui(SLOT_NAMES.get(slot, slot))


## Emplacements réels où peut aller un objet (deux pour un anneau).
static func slots_for(id: String) -> Array:
	var slot := slot_for(id)
	return SLOT_GROUPS.get(slot, [slot])


## Compétences d'attaque d'une arme ("skill" de l'arme, sinon : à distance -> Armes de trait,
## le reste -> Armes de mêlée).
static func skills_for(id: String) -> Array:
	var weapon := def(id)
	if weapon.has("skill"):
		return [weapon["skill"]]
	if has_property(id, "ranged"):
		return ["weapon_ranged"]
	return ["weapon_melee"]


## Poids dans l'encombrement ; une arme : tenue à une main, ou à deux (two_hands) si elle le permet.
static func weight_of(id: String, two_hands := false) -> float:
	var item := def(id)
	if is_weapon(id) and (two_hands or not item.has("weight")):
		return float(item.get("weight_two_hands", item.get("weight", 0.0)))
	return float(item.get("weight", 0.0))


## L'arme peut-elle se tenir à une main ?
static func is_one_handed(id: String) -> bool:
	return is_weapon(id) and def(id).has("weight") and not has_property(id, "two_handed")


## L'arme peut-elle se tenir à deux mains ?
static func can_use_two_hands(id: String) -> bool:
	return is_weapon(id) and def(id).has("weight_two_hands")


## Seuil de parade d'une arme ou d'un bouclier (à deux mains : "parry_two_hands") ; -1 s'il ne pare pas.
static func parry_of(id: String, two_hands := false) -> int:
	var item := def(id)
	if not item.has("parry"):
		return -1
	return int(item.get("parry_two_hands", item["parry"])) if two_hands else int(item["parry"])


## Dégâts en plus sur un critique (Perçante).
static func crit_bonus_of(id: String) -> int:
	return int(def(id).get("crit_bonus", 0))


## Actions de rechargement après chaque tir (0 : aucune).
static func reload_of(id: String) -> int:
	return int(def(id).get("reload", 0))


## Imprévisible : nombre de 10 au jet d'attaque qui brisent l'arme (0 : jamais).
static func fragile_of(id: String) -> int:
	return int(def(id).get("fragile", 0))


## Dégâts d'une arme : {"dice", "threshold": attribut | N, "bonus", "fixed": true} (les dés de l'arme,
## sans le rang de la compétence).
static func weapon_damage(id: String) -> Dictionary:
	var spec: Dictionary = def(id).get("damage", {})
	return {"threshold": spec.get("threshold", "str"), "bonus": int(spec.get("bonus", 0)), "dice": int(spec.get("dice", 0)),
		"fixed": true}


## Texte d'une réserve de dégâts : « 7d10, seuil FOR +1 », « seuil attaque, +1 dé », « seuil 6 ».
static func damage_text(spec: Dictionary) -> String:
	var threshold: Variant = spec.get("threshold", "weapon")
	if spec.get("fixed", false):
		var source: String = Abilities.short_of(threshold) if threshold is String else str(int(threshold))
		var extra := int(spec.get("bonus", 0))
		if extra != 0:
			source += " %s%d" % ["+" if extra > 0 else "−", absi(extra)]
		return Loc.ui("%dd10, seuil %s") % [int(spec.get("dice", 0)), source]
	var text := ""
	if threshold is String:
		text = Loc.ui("seuil %s") % (Loc.ui("attaque") if threshold in ["weapon", "spell"] else Abilities.short_of(threshold))
		var bonus := int(spec.get("bonus", 0))
		if bonus != 0:
			text += " %s%d" % ["+" if bonus > 0 else "−", absi(bonus)]
	else:
		text = Loc.ui("seuil %d") % int(threshold)
	var dice := int(spec.get("dice", 0))
	if dice != 0:
		text += Loc.ui(", %s%d dé(s)") % ["+" if dice > 0 else "−", absi(dice)]
	return text


static func damage_type_of(id: String) -> String:
	return def(id).get("damage_type", "bludgeoning")



## Points d'Armure d'une armure ou d'un bouclier (0 pour le reste).
static func armor_value(id: String) -> int:
	if is_armor(id) or is_shield(id):
		return int(def(id).get("armor", 0))
	return 0


static func modifiers_of(id: String) -> Array:
	return def(id).get("modifiers", [])


## Nombre sans décimale inutile : 4 -> « 4 », 0.5 -> « 0,5 ».
static func _num(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else String.num(value, 1).replace(".", ",")


## Description courte, ex. « Épée longue — 1d8 tranchant (polyvalente 1d10) ».
static func describe(id: String) -> String:
	var item := def(id)
	match item.get("category", ""):
		"weapon":
			var text := "%s — %s, %s" % [item["name"], DamageTypes.name_of(damage_type_of(id)).to_lower(),
				damage_text(weapon_damage(id))]
			for part: Dictionary in item.get("bonus_damage", []):
				text += " + %s %s" % [DamageTypes.name_of(part["damage_type"]).to_lower(),
					Dice.pool_text(int(part.get("dice", 1)), int(part.get("threshold", 5)))]
			var props := PackedStringArray()
			if parry_of(id) >= 0:
				var parry_text := Loc.ui("parade %d") % parry_of(id)
				if parry_of(id, true) != parry_of(id):
					parry_text += Loc.ui(" (%d à deux mains)") % parry_of(id, true)
				props.append(parry_text)
			if is_one_handed(id):
				var weight_text := Loc.ui("poids %s") % _num(weight_of(id))
				if can_use_two_hands(id) and weight_of(id, true) != weight_of(id):
					weight_text += Loc.ui(" (%s à deux mains)") % _num(weight_of(id, true))
				props.append(weight_text)
			else:
				props.append(Loc.ui("poids %s, à deux mains") % _num(weight_of(id, true)))
			if crit_bonus_of(id) > 0:
				props.append(Loc.ui("perçante : +%d dégâts sur un critique") % crit_bonus_of(id))
			if reload_of(id) > 0:
				props.append(Loc.ui("recharge %d") % reload_of(id))
			if fragile_of(id) > 0:
				props.append(Loc.ui("imprévisible (%d)") % fragile_of(id))
			for prop: String in item.get("properties", []):
				if prop != "two_handed":
					props.append(Loc.ui(PROPERTY_NAMES.get(prop, prop)))
			return text + (" (%s)" % ", ".join(props) if not props.is_empty() else "")
		"armor":
			return Loc.ui("%s — Armure %d (%s), poids %s") % [item["name"], armor_value(id),
				ARMOR_TYPE_NAMES.get(item.get("armor_type", "light"), ""), _num(weight_of(id))]
		"shield":
			return Loc.ui("%s — Armure +%d, parade %d, poids %s") % [item["name"], armor_value(id), parry_of(id),
				_num(weight_of(id))]
		"accessory":
			return "%s — %s" % [item["name"], slot_name(slot_for(id)).to_lower()]
	return item.get("name", id)
