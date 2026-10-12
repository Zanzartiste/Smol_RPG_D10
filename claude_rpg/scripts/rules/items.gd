class_name Items
extends RefCounted
## API des objets du sac, quelle que soit leur origine :
##   - items.json     : consommables (potions…), matériaux, trésors ;
##   - equipment.json : armes, armures, boucliers, accessoires (voir Equipment).
## Les ids sont uniques entre les deux fichiers (vérifié par DataValidator) : un inventaire
## ({id: quantité}) peut donc mélanger les deux.
##
## Champs communs : "name", "description"?, "value"? (prix en po), "rarity"? (common, uncommon, rare,
## very_rare, legendary). Un consommable a "use": {"heal"?: "2d4+2", "cleanse"?: "poisoned",
## "target": "ally"}.

const RARITIES := ["common", "uncommon", "rare", "very_rare", "legendary"]
const RARITY_NAMES := {
	"common": "commun", "uncommon": "peu commun", "rare": "rare", "very_rare": "très rare", "legendary": "légendaire",
}
const RARITY_COLORS := {
	"common": "#d8cfc0", "uncommon": "#6fbf5a", "rare": "#5a8fd8", "very_rare": "#a36ad8", "legendary": "#e0a030",
}


static func has(id: String) -> bool:
	return DB.items.has(id) or DB.equipment.has(id)


static func def(id: String) -> Dictionary:
	return DB.items.get(id, DB.equipment.get(id, {}))


static func name_of(id: String) -> String:
	return def(id).get("name", id)


static func description_of(id: String) -> String:
	return def(id).get("description", "")


static func value_of(id: String) -> int:
	return int(def(id).get("value", 0))


static func rarity_of(id: String) -> String:
	return def(id).get("rarity", "common")


static func rarity_color(id: String) -> Color:
	return Color(String(RARITY_COLORS.get(rarity_of(id), "#d8cfc0")))


## L'objet se porte (arme, armure, bouclier, accessoire) ?
static func is_equipment(id: String) -> bool:
	return DB.equipment.has(id) and id != Equipment.UNARMED


static func is_usable(id: String) -> bool:
	return def(id).has("use")


## Utilisable hors combat : seuls les soins ont un sens (les états n'existent qu'en combat).
static func is_usable_outside_combat(id: String) -> bool:
	return def(id).get("use", {}).has("heal")


## Nom coloré selon la rareté, en BBCode.
static func bbcode_name(id: String) -> String:
	return "[color=#%s]%s[/color]" % [rarity_color(id).to_html(false), name_of(id)]


## Ligne de description : effet d'équipement ou d'usage, rareté, valeur.
static func summary(id: String) -> String:
	var parts := PackedStringArray()
	if is_equipment(id):
		parts.append(Equipment.describe(id))
		var mods := Equipment.modifiers_of(id)
		if not mods.is_empty():
			parts.append(Modifiers.describe_all(mods))
	var use: Dictionary = def(id).get("use", {})
	if use.has("heal"):
		parts.append(Loc.ui("Soigne %s PV") % use["heal"])
	if use.has("cleanse"):
		parts.append(Loc.ui("Retire %s") % StatusEffects.name_of(use["cleanse"]))
	if rarity_of(id) != "common":
		parts.append(Loc.ui(RARITY_NAMES[rarity_of(id)]))
	if value_of(id) > 0:
		parts.append(Loc.ui("%d po") % value_of(id))
	return " · ".join(parts)
