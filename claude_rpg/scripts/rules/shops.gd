class_name Shops
extends RefCounted
## API des boutiques et services (data/shops.json) et des prix (rules.json › trade).
## Une boutique : {"id", "name", "location", "description", "price_rate" (1.0), "restock_days",
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


## La boutique rachète-t-elle cet objet ? Tout marchand rachète tout ce qui a de la valeur, sauf les
## objets de quête (pas d'allers-retours entre boutiques).
@warning_ignore("unused_parameter")
static func buys(shop_id: String, item_id: String) -> bool:
	return Items.value_of(item_id) > 0 and not Items.is_quest(item_id)


# --- Prix ----------------------------------------------------------------------

static func _trade(key: String, default: Variant) -> Variant:
	return DB.rules.get("trade", {}).get(key, default)


## Talent de négociation d'un personnage : nombre moyen de succès de sa réserve de Persuasion.
static func bargaining(ch: Character) -> float:
	var pool := ch.skill_pool(_trade("price_skill", "persuasion"))
	return Dice.expected(int(pool["count"]), int(pool["threshold"]))


## Membre du groupe qui négocie : le meilleur talent de négociation.
static func negotiator(life: LifeState) -> Character:
	var best := life.character
	for member in life.party():
		if member.hp > 0 and bargaining(member) > bargaining(best):
			best = member
	return best


## Remise en fraction (0.15 = 15 %) : percent_per_success % par succès moyen, au plus max_percent.
static func discount(life: LifeState) -> float:
	var limit := float(_trade("max_percent", 15))
	return clampf(bargaining(negotiator(life)) * float(_trade("percent_per_success", 5)), 0.0, limit) / 100.0


## Effet de la réputation du héros dans un lieu sur les prix : +5 % s'il est respecté, −10 % s'il est honni.
static func reputation_bonus(location_id: String, life: LifeState) -> float:
	var value := int(life.reputation.get(location_id, 0))
	if value >= 20:
		return 0.05
	if value <= -20:
		return -0.10
	return 0.0


## Prix d'achat d'un objet dans une boutique (au moins 1 po). `location_id` : lieu du vendeur sans boutique.
static func buy_price(shop_id: String, item_id: String, life: LifeState, location_id := "") -> int:
	var loc: String = def(shop_id).get("location", location_id)
	var rate := 1.0 - discount(life) - reputation_bonus(loc, life)
	var price := Items.value_of(item_id) * float(def(shop_id).get("price_rate", 1.0)) * rate
	return maxi(1, ceili(price))


## Prix de revente d'un objet (au moins 1 po s'il a de la valeur).
static func sell_price(item_id: String, life: LifeState, location_id := "") -> int:
	if Items.value_of(item_id) <= 0:
		return 0
	var rate := 1.0 + discount(life) + reputation_bonus(location_id, life)
	var price := Items.value_of(item_id) * float(_trade("sell_rate", 0.5)) * rate
	return maxi(1, floori(price))
