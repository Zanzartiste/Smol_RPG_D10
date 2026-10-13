class_name Equipment
extends RefCounted
## API de l'équipement (armes, armures, boucliers). Définitions : data/equipment.json.
## Classes, personnages et ennemis ne font que référencer des ids d'équipement : modifier une arme ici
## (dégâts, type, propriétés) la modifie partout.
##
## Arme  : {"category": "weapon", "damage": {"threshold"?: "weapon" | "str" | "dex" | N, "bonus"?: N, "dice"?: N},
##          "damage_type": "slashing",
##          "properties": ["finesse", "light", "thrown", "versatile", "heavy", "two_handed", "ranged"]}
##   Dégâts : [rang de la compétence d'attaque + dice] d10 contre un seuil : l'attribut d'attaque
##   ("weapon", par défaut), un attribut imposé, ou un seuil fixe (arcs), + "bonus". Une arme
##   polyvalente tenue à deux mains a +1 au seuil. "parry"?: {"ability", "bonus"} : seuil de parade.
## Armure : {"category": "armor", "armor_type": "clothing" | "light" | "medium" | "heavy", "armor": N,
##           "strength"?: N}  N : points d'Armure (baissent le seuil des dégâts subis). Force nécessaire
##           pour la porter sans malus ; par défaut celle de son type (rules.json › armor_strength :
##           vêtements 0, légère 4, intermédiaire 5, lourde 6). En dessous, elle reste portable mais encombre.
## Bouclier : {"category": "shield", "armor": 1} (permet aussi de parer les attaques à distance)
## Accessoire : {"category": "accessory", "slot": "head" | "cloak" | "hands" | "legs" | "feet" | "neck" | "ring"}
##           (un anneau va dans ring_1, ou ring_2 si le premier est pris)
## Tous : "weight" (kg) ; le poids porté par le groupe peut l'encombrer (voir Character).
## Facultatif pour tous : "modifiers" (voir Modifiers), "rarity", "value", "description" (voir Items).
## Facultatif pour une arme : "bonus_damage": [{"dice": 2, "threshold": 5, "damage_type": "fire"}], dégâts
## d'autres types ajoutés à chaque coup (une épée enflammée : tranchant + feu).
## Un objet magique est un équipement avec des modificateurs, ex. une épée +1 (un dé d'attaque et +1 au
## seuil de dégâts) : "modifiers": [{"type": "weapon_attack", "amount": 1}, {"type": "weapon_damage", "amount": 1}]

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
const VERSATILE_BONUS := 1  # seuil de dégâts en plus pour une arme polyvalente tenue à deux mains

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
## mains nues -> Armes de mêlée ou Physique, le reste -> Armes de mêlée).
static func skills_for(id: String) -> Array:
	var weapon := def(id)
	if weapon.has("skill"):
		return [weapon["skill"]]
	if id == UNARMED:
		return ["weapon_melee", "physique"]
	if has_property(id, "ranged"):
		return ["weapon_ranged"]
	return ["weapon_melee"]


## Poids en kg.
static func weight_of(id: String) -> float:
	return float(def(id).get("weight", 0.0))


## Dégâts d'une arme : {"threshold": "weapon" | attribut | N, "bonus", "dice"} ; une arme polyvalente
## tenue à deux mains a +1 au seuil.
static func weapon_damage(id: String, two_hands := false) -> Dictionary:
	var spec: Dictionary = def(id).get("damage", {})
	var result := {"threshold": spec.get("threshold", "weapon"), "bonus": int(spec.get("bonus", 0)), "dice": int(spec.get("dice", 0))}
	if two_hands and has_property(id, "versatile"):
		result["bonus"] = int(result["bonus"]) + VERSATILE_BONUS
	return result


## Texte d'une réserve de dégâts : « seuil FOR +1 », « seuil 6, +1 dé ».
static func damage_text(spec: Dictionary) -> String:
	var threshold: Variant = spec.get("threshold", "weapon")
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


## Attribut d'attaque d'une arme : DEX pour une arme à distance, le meilleur de FOR/DEX pour une
## arme de finesse, FOR sinon.
static func attack_ability(id: String, str_value: int, dex_value: int) -> String:
	if has_property(id, "ranged"):
		return "dex"
	if has_property(id, "finesse"):
		return "dex" if dex_value > str_value else "str"
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


## Points d'Armure d'une armure ou d'un bouclier (0 pour le reste).
static func armor_value(id: String) -> int:
	if is_armor(id) or is_shield(id):
		return int(def(id).get("armor", 0))
	return 0


static func modifiers_of(id: String) -> Array:
	return def(id).get("modifiers", [])


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
			for prop: String in item.get("properties", []):
				var label: String = PROPERTY_NAMES.get(prop, prop)
				if prop == "versatile":
					label += Loc.ui(" : +1 à deux mains")
				props.append(label)
			return text + (" (%s)" % ", ".join(props) if not props.is_empty() else "")
		"armor":
			var text := Loc.ui("%s — Armure %d (%s)") % [item["name"], armor_value(id),
				ARMOR_TYPE_NAMES.get(item.get("armor_type", "light"), "")]
			if strength_required(id) > 0:
				text += Loc.ui(", FOR %d") % strength_required(id)
			return text
		"shield":
			return Loc.ui("%s — Armure +%d") % [item["name"], armor_value(id)]
		"accessory":
			return "%s — %s" % [item["name"], slot_name(slot_for(id)).to_lower()]
	return item.get("name", id)
