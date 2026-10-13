class_name Crafting
extends RefCounted
## API de la fabrication (data/recipes.json) et de l'amélioration d'équipement (rules.json › forge).
##
## Recette : {"id", "result": id d'objet, "count"? (1), "station": "forge" | "alchemy",
##            "materials": {id: quantité}, "gold"? (0), "difficulty"? (1)}
## Fabriquer demande un test de la compétence de la station (rules.json › crafting).
## Amélioration : une arme, une armure ou un bouclier ordinaire devient « +1 », puis « +2 », « +3 ».
## L'objet amélioré a l'id "<base>@<rang>" (ex. "longsword@2"), décrit par Equipment.def :
## un dé d'attaque et +1 au seuil des dégâts par rang pour une arme, +1 Armure par rang pour une armure
## ou un bouclier.

const UPGRADE_SEPARATOR := "@"


static func _crafting(key: String, default: Variant) -> Variant:
	return DB.rules.get("crafting", {}).get(key, default)


## Test d'une recette : {"skill", "ability"?, "difficulty"}.
static func check_for(recipe_def: Dictionary) -> Dictionary:
	var spec: Dictionary = _crafting("station_skills", {}).get(recipe_def.get("station", ""), {"skill": "crafting"}).duplicate()
	spec["difficulty"] = int(recipe_def.get("difficulty", 1))
	return spec


## Métier qui se dessine à force de fabriquer à une station (« Forgeronne ») : "" sous le seuil.
static func profession(station: String, crafted: int, gender: String) -> String:
	if crafted < int(_crafting("profession_threshold", 5)):
		return ""
	return Loc.gendered(String(_crafting("professions", {}).get(station, "")), gender)


static func recipes_for(station: String) -> Array:
	return DB.recipes.values().filter(func(r): return r.get("station") == station)


static func recipe(id: String) -> Dictionary:
	return DB.recipes.get(id, {})


## Pourquoi la recette est impossible ("" si elle est possible) : or ou matériaux manquants.
static func missing_for(recipe_def: Dictionary, life: LifeState) -> String:
	var missing := PackedStringArray()
	var materials: Dictionary = recipe_def.get("materials", {})
	for item_id: String in materials:
		var lacking := int(materials[item_id]) - life.character.item_count(item_id)
		if lacking > 0:
			missing.append("%s ×%d" % [Items.name_of(item_id), lacking])
	var gold := int(recipe_def.get("gold", 0))
	if life.character.gold < gold:
		missing.append(Loc.ui("%d po") % (gold - life.character.gold))
	return Loc.ui("il manque : %s") % ", ".join(missing) if not missing.is_empty() else ""


## Ex. « Minerai de fer ×2, 1 po ».
static func cost_text(recipe_def: Dictionary) -> String:
	var parts := PackedStringArray()
	var materials: Dictionary = recipe_def.get("materials", {})
	for item_id: String in materials:
		parts.append("%s ×%d" % [Items.name_of(item_id), int(materials[item_id])])
	if int(recipe_def.get("gold", 0)) > 0:
		parts.append(Loc.ui("%d po") % int(recipe_def["gold"]))
	return ", ".join(parts)


# --- Amélioration -----------------------------------------------------------------

static func _forge(key: String, default: Variant) -> Variant:
	return DB.rules.get("forge", {}).get(key, default)


static func max_upgrade() -> int:
	return _forge("upgrade_costs", []).size()


## Rang d'amélioration d'un id ("longsword@2" -> 2, "longsword" -> 0).
static func upgrade_rank(item_id: String) -> int:
	var parts := item_id.split(UPGRADE_SEPARATOR)
	return int(parts[1]) if parts.size() == 2 else 0


## Id de l'objet de base ("longsword@2" -> "longsword").
static func base_id(item_id: String) -> String:
	return item_id.split(UPGRADE_SEPARATOR)[0]


static func upgraded_id(item_id: String) -> String:
	return "%s%s%d" % [base_id(item_id), UPGRADE_SEPARATOR, upgrade_rank(item_id) + 1]


## Seuls les armes, armures (pas les vêtements) et boucliers ordinaires (pas déjà magiques) s'améliorent, jusqu'au rang max.
static func can_upgrade(item_id: String) -> bool:
	var base: Dictionary = DB.equipment.get(base_id(item_id), {})
	return base.get("category") in ["weapon", "armor", "shield"] and base_id(item_id) != Equipment.UNARMED \
		and base.get("armor_type", "") != "clothing" and base.get("rarity", "common") == "common" \
		and upgrade_rank(item_id) < max_upgrade()


## Coût en po du rang suivant.
static func upgrade_cost(item_id: String) -> int:
	return int(_forge("upgrade_costs", [0])[clampi(upgrade_rank(item_id), 0, max_upgrade() - 1)])


## Définition d'un objet amélioré (appelée par Equipment.def pour les ids "base@rang").
static func upgraded_def(item_id: String) -> Dictionary:
	var base: Dictionary = DB.equipment.get(base_id(item_id), {})
	var rank := upgrade_rank(item_id)
	if base.is_empty() or rank <= 0:
		return {}
	var item := base.duplicate(true)
	item["id"] = item_id
	item["name"] = "%s +%d" % [base["name"], rank]
	var rarities: Array = _forge("upgrade_rarities", ["uncommon"])
	item["rarity"] = rarities[clampi(rank - 1, 0, rarities.size() - 1)]
	var value := int(base.get("value", 0))
	var costs: Array = _forge("upgrade_costs", [])
	for i in mini(rank, costs.size()):
		value += int(costs[i])
	item["value"] = value
	var mods: Array = item.get("modifiers", [])
	if base.get("category") == "weapon":
		mods.append({"type": "weapon_attack", "amount": rank})
		mods.append({"type": "weapon_damage", "amount": rank})
	else:
		mods.append({"type": "armor", "amount": rank})
	item["modifiers"] = mods
	return item
