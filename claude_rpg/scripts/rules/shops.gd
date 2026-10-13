class_name Shops
extends RefCounted
## API des boutiques et services (data/shops.json) et des prix (rules.json › trade).
## Une boutique : {"id", "name", "location", "description", "price_rate" (1.0), "restock_days",
##                 "buys": [catégories achetées au joueur : weapon, armor, shield, accessory,
##                          consumable, material, treasure],
##                 "stock": {id d'objet: quantité, reconstituée tous les restock_days jours},
##                 "crafting"?: "forge" | "alchemy" (recettes de recipes.json de cette station),
##                 "upgrade"?: true (améliore armes, armures et boucliers, voir Crafting)}
## L'état des boutiques (stock restant) vit dans LifeState.shops.


static func ids() -> Array[String]:
	var result: Array[String] = []
	result.assign(DB.shops.keys())
	return result


static func def(id: String) -> Dictionary:
	return DB.shops.get(id, {})


static func name_of(id: String) -> String:
	return def(id).get("name", id)


## Boutiques d'un lieu, dans l'ordre du fichier.
static func of_location(location_id: String) -> Array[String]:
	var result: Array[String] = []
	for id: String in DB.shops:
		if DB.shops[id].get("location") == location_id:
			result.append(id)
	return result


## La boutique rachète-t-elle cet objet ? (catégorie acceptée et valeur non nulle)
static func buys(shop_id: String, item_id: String) -> bool:
	return Items.category_of(item_id) in def(shop_id).get("buys", []) and Items.value_of(item_id) > 0


# --- Prix ----------------------------------------------------------------------

static func _trade(key: String, default: Variant) -> Variant:
	return DB.rules.get("trade", {}).get(key, default)


## Membre du groupe qui négocie : la meilleure valeur dans la compétence de prix (Persuasion).
static func negotiator(life: LifeState) -> Character:
	var skill: String = _trade("price_skill", "persuasion")
	var best := life.character
	for member in life.party():
		if member.hp > 0 and member.skill_mod(skill) > best.skill_mod(skill):
			best = member
	return best


## Remise en fraction (0.15 = 15 %), négative si le négociateur est mauvais.
static func discount(life: LifeState) -> float:
	var mod := negotiator(life).skill_mod(_trade("price_skill", "persuasion"))
	var limit := float(_trade("max_percent", 15))
	return clampf(mod * float(_trade("percent_per_point", 3)), -limit, limit) / 100.0


## Prix d'achat d'un objet dans une boutique (au moins 1 po).
static func buy_price(shop_id: String, item_id: String, life: LifeState) -> int:
	var price := Items.value_of(item_id) * float(def(shop_id).get("price_rate", 1.0)) * (1.0 - discount(life))
	return maxi(1, ceili(price))


## Prix de revente d'un objet (au moins 1 po s'il a de la valeur).
static func sell_price(item_id: String, life: LifeState) -> int:
	if Items.value_of(item_id) <= 0:
		return 0
	var price := Items.value_of(item_id) * float(_trade("sell_rate", 0.5)) * (1.0 + discount(life))
	return maxi(1, floori(price))
