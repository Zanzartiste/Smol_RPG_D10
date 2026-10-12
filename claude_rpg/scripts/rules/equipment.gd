class_name Equipment
extends RefCounted
## API de l'équipement (armes, armures, boucliers). Définitions : data/equipment.json.
## Classes, personnages et ennemis ne font que référencer des ids d'équipement : modifier une arme ici
## (dégâts, type, propriétés) la modifie partout.
##
## Arme  : {"category": "weapon", "damage": "1d8", "damage_type": "slashing",
##          "properties": ["finesse", "light", "thrown", "versatile", "heavy", "two_handed", "ranged"],
##          "versatile_damage": "1d10"}
## Armure : {"category": "armor", "armor_type": "clothing" | "light" | "medium" | "heavy", "base_ac": 11,
##           "strength"?: N}  Force nécessaire pour la porter sans malus ; par défaut celle de son type
##           (rules.json › armor_strength : vêtements 0, légère 10, intermédiaire 12, lourde 14).
##           En dessous, elle reste portable mais encombre (rules.json › encumbered_modifiers).
## Bouclier : {"category": "shield", "ac_bonus": 2}
## Accessoire : {"category": "accessory", "slot": "cloak" | "amulet" | "ring"}
## Facultatif pour tous : "modifiers" (voir Modifiers), "rarity", "value", "description" (voir Items).
## Facultatif pour une arme : "bonus_damage": [{"damage": "2d6", "damage_type": "fire"}], dégâts d'autres
## types ajoutés à chaque coup (une épée enflammée : tranchant + feu).
## Un objet magique est un équipement avec des modificateurs, ex. une épée +1 :
##   "modifiers": [{"type": "weapon_attack", "amount": 1}, {"type": "weapon_damage", "amount": 1}]

const SLOTS := ["main_hand", "off_hand", "armor", "cloak", "amulet", "ring"]
const ACCESSORY_SLOTS := ["cloak", "amulet", "ring"]
const SLOT_NAMES := {
	"main_hand": "Main principale", "off_hand": "Main secondaire", "armor": "Armure",
	"cloak": "Cape", "amulet": "Amulette", "ring": "Anneau",
}
const UNARMED := "unarmed"
const MEDIUM_ARMOR_DEX_CAP := 2

const PROPERTY_NAMES := {
	"finesse": "finesse", "light": "légère", "thrown": "lancer", "versatile": "polyvalente",
	"heavy": "lourde", "two_handed": "à deux mains", "ranged": "à distance",
}
const ARMOR_TYPE_NAMES := {"clothing": "vêtement", "light": "légère", "medium": "intermédiaire", "heavy": "lourde"}


static func ids() -> Array[String]:
	var result: Array[String] = []
	result.assign(DB.equipment.keys())
	return result


static func has(id: String) -> bool:
	return DB.equipment.has(id)


static func def(id: String) -> Dictionary:
	return DB.equipment.get(id, {})


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


## Dégâts d'une arme ; une arme polyvalente tenue à deux mains utilise ses dégâts « versatile ».
static func weapon_damage(id: String, two_hands := false) -> String:
	var weapon := def(id)
	if two_hands and has_property(id, "versatile") and weapon.has("versatile_damage"):
		return weapon["versatile_damage"]
	return weapon.get("damage", "1")


static func damage_type_of(id: String) -> String:
	return def(id).get("damage_type", "bludgeoning")


## Attribut d'attaque d'une arme : DEX pour une arme à distance, le meilleur de FOR/DEX pour une
## arme de finesse, FOR sinon.
static func attack_ability(id: String, str_mod: int, dex_mod: int) -> String:
	if has_property(id, "ranged"):
		return "dex"
	if has_property(id, "finesse"):
		return "dex" if dex_mod > str_mod else "str"
	return "str"


## Force nécessaire pour porter un équipement sans malus (0 si aucune) : "strength" de l'objet, sinon celle de son
## type d'armure (rules.json › armor_strength).
static func strength_required(id: String) -> int:
	var item := def(id)
	if item.has("strength"):
		return int(item["strength"])
	if is_armor(id):
		return int(DB.rules.get("armor_strength", {}).get(item.get("armor_type", ""), 0))
	return 0


## Classe d'armure : sans armure 10 + DEX ; vêtements et armure légère base + DEX ; intermédiaire base + DEX (max 2) ;
## lourde base seule ; + bonus du bouclier.
static func armor_class(armor_id: String, shield_id: String, dex_mod: int) -> int:
	var ac := 10 + dex_mod
	if is_armor(armor_id):
		var armor := def(armor_id)
		var base := int(armor.get("base_ac", 10))
		match armor.get("armor_type", "light"):
			"clothing", "light":
				ac = base + dex_mod
			"medium":
				ac = base + mini(dex_mod, MEDIUM_ARMOR_DEX_CAP)
			"heavy":
				ac = base
	if is_shield(shield_id):
		ac += int(def(shield_id).get("ac_bonus", 2))
	return ac


static func modifiers_of(id: String) -> Array:
	return def(id).get("modifiers", [])


## Description courte, ex. « Épée longue — 1d8 tranchant (polyvalente 1d10) ».
static func describe(id: String) -> String:
	var item := def(id)
	match item.get("category", ""):
		"weapon":
			var text := "%s — %s %s" % [item["name"], item.get("damage", "1"),
				DamageTypes.name_of(damage_type_of(id)).to_lower()]
			for part: Dictionary in item.get("bonus_damage", []):
				text += " + %s %s" % [part["damage"], DamageTypes.name_of(part["damage_type"]).to_lower()]
			var props := PackedStringArray()
			for prop: String in item.get("properties", []):
				var label: String = PROPERTY_NAMES.get(prop, prop)
				if prop == "versatile" and item.has("versatile_damage"):
					label += " " + item["versatile_damage"]
				props.append(label)
			return text + (" (%s)" % ", ".join(props) if not props.is_empty() else "")
		"armor":
			var text := "%s — CA %d (%s)" % [item["name"], int(item.get("base_ac", 10)),
				ARMOR_TYPE_NAMES.get(item.get("armor_type", "light"), "")]
			if strength_required(id) > 0:
				text += Loc.ui(", FOR %d") % strength_required(id)
			return text
		"shield":
			return "%s — CA +%d" % [item["name"], int(item.get("ac_bonus", 2))]
		"accessory":
			return "%s — %s" % [item["name"], slot_name(slot_for(id)).to_lower()]
	return item.get("name", id)
