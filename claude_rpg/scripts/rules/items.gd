class_name Items
extends RefCounted
## API des objets du sac, quelle que soit leur origine :
##   - items.json     : consommables (potions…), matériaux, trésors ;
##   - equipment.json : armes, armures, boucliers, accessoires (voir Equipment).
## Les ids sont uniques entre les deux fichiers (vérifié par DataValidator) : un inventaire
## ({id: quantité}) peut donc mélanger les deux.
##
## Champs communs : "name", "description"?, "value"? (prix en po), "rarity"? (common, uncommon, rare,
## very_rare, legendary). Un objet de items.json a une "category" : consumable, material, treasure ;
## l'équipement garde la sienne (weapon, armor, shield, accessory).
## Un consommable a "use": {"heal"?: "2d4+2", "cleanse"?: "poisoned", "target": "ally"}.
## "weight" : poids en kg (voir l'encombrement). "quest": true : objet de quête, ni vendu ni jeté.

const RARITIES := ["common", "uncommon", "rare", "very_rare", "legendary"]
const RARITY_NAMES := {
	"common": "commun", "uncommon": "peu commun", "rare": "rare", "very_rare": "très rare", "legendary": "légendaire",
}
const RARITY_COLORS := {
	"common": "#d8cfc0", "uncommon": "#6fbf5a", "rare": "#5a8fd8", "very_rare": "#a36ad8", "legendary": "#e0a030",
}
const CATEGORIES := ["weapon", "armor", "shield", "accessory", "consumable", "material", "treasure"]
const CATEGORY_NAMES := {
	"weapon": "Armes", "armor": "Armures", "shield": "Boucliers", "accessory": "Accessoires",
	"consumable": "Consommables", "material": "Matériaux", "treasure": "Trésors",
}


static func has(id: String) -> bool:
	return DB.items.has(id) or Equipment.has(id)


static func def(id: String) -> Dictionary:
	return DB.items[id] if DB.items.has(id) else Equipment.def(id)


static func category_of(id: String) -> String:
	return def(id).get("category", "material")


static func name_of(id: String) -> String:
	return def(id).get("name", id)


static func description_of(id: String) -> String:
	return def(id).get("description", "")


static func weight_of(id: String) -> float:
	return float(def(id).get("weight", 0.0))


static func is_quest(id: String) -> bool:
	return def(id).get("quest", false)


## Filtres de l'inventaire : id -> {name, categories}.
const FILTERS := {
	"all": {"name": "Tout", "categories": []},
	"equipment": {"name": "Équipement", "categories": ["weapon", "armor", "shield", "accessory"]},
	"consumable": {"name": "Consommables", "categories": ["consumable"]},
	"material": {"name": "Matériaux", "categories": ["material"]},
	"treasure": {"name": "Trésors", "categories": ["treasure"]},
	"quest": {"name": "Quête", "categories": []},
}


## L'objet passe-t-il le filtre et la recherche (texte contenu dans le nom, sans casse) ?
static func matches(id: String, filter: String, search := "") -> bool:
	if search != "" and not name_of(id).to_lower().contains(search.to_lower()):
		return false
	match filter:
		"all":
			return true
		"quest":
			return is_quest(id)
	return category_of(id) in FILTERS.get(filter, {}).get("categories", [])


static func value_of(id: String) -> int:
	return int(def(id).get("value", 0))


static func rarity_of(id: String) -> String:
	return def(id).get("rarity", "common")


static func rarity_color(id: String) -> Color:
	return Color(String(RARITY_COLORS.get(rarity_of(id), "#d8cfc0")))


## L'objet se porte (arme, armure, bouclier, accessoire) ?
static func is_equipment(id: String) -> bool:
	return Equipment.has(id) and id != Equipment.UNARMED


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
