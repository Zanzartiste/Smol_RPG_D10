class_name Cards
extends RefCounted
## API des cartes de combat. Définitions : data/cards.json.
## Une carte : {"id", "name", "cost": "{1}{R}", "type": "spell" | "maneuver" | "summon",
##             "rarity": "common" | "uncommon" | "rare" | "mythic",
##             "target": "enemy" | "all_enemies" | "ally" | "all_allies" | "self" | "none",
##             "effects": [...] (voir CombatEffects), "text"?: texte imposé, "art": {"icon": ...}}
## Le texte de la carte est généré à partir de ses effets (sauf "text" imposé).

const TYPE_NAMES := {"spell": "Sort", "maneuver": "Manœuvre", "summon": "Invocation"}
const RARITY_NAMES := {"common": "Commune", "uncommon": "Peu commune", "rare": "Rare", "mythic": "Mythique"}
const RARITY_COLORS := {"common": "#b8b2a6", "uncommon": "#9fc0d8", "rare": "#e2c25a", "mythic": "#e0703a"}
const TARGETS := ["enemy", "all_enemies", "ally", "all_allies", "self", "none"]
## Cibles qui demandent au joueur de choisir.
const CHOSEN_TARGETS := ["enemy", "ally"]


static func ids() -> Array[String]:
	var result: Array[String] = []
	result.assign(DB.cards.keys())
	return result


static func has(id: String) -> bool:
	return DB.cards.has(id)


static func def(id: String) -> Dictionary:
	return DB.cards.get(id, {})


static func name_of(id: String) -> String:
	return def(id).get("name", id)


static func cost_of(id: String) -> String:
	return def(id).get("cost", "")


static func mana_value(id: String) -> int:
	return Mana.mana_value(cost_of(id))


static func colors_of(id: String) -> Array[String]:
	return Mana.colors_of(cost_of(id))


static func type_name(id: String) -> String:
	return TYPE_NAMES.get(def(id).get("type", ""), "")


static func rarity_of(id: String) -> String:
	return def(id).get("rarity", "common")


static func target_of(id: String) -> String:
	return def(id).get("target", "none")


static func effects_of(id: String) -> Array:
	return def(id).get("effects", [])


static func text_of(id: String) -> String:
	if def(id).has("text"):
		return def(id)["text"]
	return CombatEffects.describe_all(effects_of(id), target_of(id))


## Couleur du cadre : celle de la couleur unique, doré si multicolore, gris si incolore.
static func frame_color(id: String) -> Color:
	var colors := colors_of(id)
	if colors.size() == 1:
		return Mana.color_value(colors[0])
	if colors.size() > 1:
		return Color("#c9a85a")
	return Color("#9a948a")


## Taille d'une collection ou d'un deck {id: nombre}.
static func count(cards: Dictionary) -> int:
	var total := 0
	for id in cards:
		total += int(cards[id])
	return total
