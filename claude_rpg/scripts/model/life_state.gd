class_name LifeState
extends RefCounted
## État d'une vie en cours : le personnage, le temps, les flags et l'historique des événements.
## Tout ce qui est ici disparaît à la mort (sauf ce que MetaState en retient).

var character: Character
var companions: Array[Character] = []
var rng := RandomNumberGenerator.new()
var day := 1
var slot := int(DB.rules.get("start_slot", 0))  # index dans DB.time_slots() (périodes de 4 h)
var flags: Dictionary = {}
var seen: Dictionary = {}  # id d'événement -> nombre de fois vu
var last_seen_day: Dictionary = {}  # id d'événement -> dernier jour où il a été vu
var dead := false
var death_cause := ""
var recorded := false  # déjà inscrite dans la chronique
var notices: Array[String] = []  # messages à afficher au prochain retour au hub
var reputation: Dictionary = {}  # id de lieu -> réputation du héros (−100 à 100)
var location := ""  # dernier lieu visité (où l'on se repose)
var crafted: Dictionary = {}  # station -> objets fabriqués (le métier se dessine)
var quests: Dictionary = {}  # id de quête -> {"status": "active" | "done" | "failed", "step"} (voir Quests)
## Journal de la vie, dans l'ordre : [{"day", "slot", "kind", "text"}]. Sortes : event, combat, quest, social,
## level, world (voir JOURNAL_KINDS).
var journal: Array[Dictionary] = []
var notes := ""  # notes libres du joueur (onglet Notes du tiroir)
var quest_defs: Dictionary = {}  # quêtes générées (demandes des PNJ) : id -> définition (voir Quests)

const JOURNAL_KINDS := {"event": "Événements", "combat": "Combats", "quest": "Quêtes", "social": "Relations",
	"level": "Progression", "world": "Le monde"}
const JOURNAL_MAX := 400
var last_initiative_day := -1  # dernier jour du monde où un PNJ est venu vous voir
## Combat déclenché mais pas encore terminé : il reprend au chargement d'une sauvegarde
## (quitter le jeu ne permet pas d'esquiver un combat).
var pending_combat: Dictionary = {}
var bestiary: Array[String] = []  # créatures dont on connaît les points faibles (Chercher les points faibles)
var shops: Dictionary = {}  # id de boutique -> {"stock": {id: quantité}, "restocked": jour du dernier réassort}


func slot_id() -> String:
	return DB.time_slots()[slot]["id"]


func slot_name() -> String:
	return DB.time_slots()[slot]["name"]


func has_flag(id: String) -> bool:
	return bool(flags.get(id, false))


func has_companion(template_id: String) -> bool:
	return companions.any(func(c): return c.template_id == template_id)


## Le héros puis ses compagnons.
func party() -> Array[Character]:
	var result: Array[Character] = [character]
	result.append_array(companions)
	return result


func mark_seen(event_id: String) -> void:
	seen[event_id] = int(seen.get(event_id, 0)) + 1
	last_seen_day[event_id] = day


func die(cause: String) -> void:
	if dead:
		return
	dead = true
	death_cause = cause
	character.hp = 0


func advance_time(slots: int) -> void:
	for i in slots:
		if dead:
			return
		slot += 1
		if slot >= DB.slots_per_day():
			slot = 0
			_new_day()


func take_notices() -> Array[String]:
	var result: Array[String] = notices.duplicate()
	notices.clear()
	for notice in result:
		log_journal("world", notice)
	return result


## Ajoute une entrée au journal (les plus anciennes disparaissent au-delà de JOURNAL_MAX).
func log_journal(kind: String, text: String) -> void:
	if text.strip_edges() == "":
		return
	journal.append({"day": day, "slot": slot, "kind": kind, "text": text})
	if journal.size() > JOURNAL_MAX:
		journal = journal.slice(journal.size() - JOURNAL_MAX)


func _new_day() -> void:
	var old_age := character.age_years()
	var old_stage := character.life_stage()
	day += 1
	character.age_days += 1
	Meta.world_day += 1
	Social.daily_tick(self)  # le monde vit : liens entre PNJ, couples, naissances
	if character.age_years() != old_age:
		notices.append(Loc.ui("Vous avez maintenant %d ans.") % character.age_years())
		var stage := character.life_stage()
		if stage != old_stage:
			notices.append(Loc.ui("Nouvelle étape de vie : %s.") % DB.life_stage_name(stage))
		_check_old_age()


## Modifie la valeur de base d'un attribut. Un attribut qui tombe à 0 tue le personnage.
## Les PV sont recalculés (la CON en dépend) : s'ils tombent à 0, le personnage meurt aussi.
func change_ability(ability_id: String, amount: int, cause: String) -> void:
	character.abilities[ability_id] = clampi(int(character.abilities.get(ability_id, 4)) + amount, 0, 20)
	character.refresh_max_hp()
	if character.ability_score(ability_id) <= 0 or character.hp <= 0:
		die(cause)


## Vieillesse : passé l'âge limite de l'espèce (aging_age), chaque nouvelle année a une chance
## (rules.json › aging_chance) de retirer 1 à un attribut tiré au hasard. Le personnage finit par
## mourir quand l'un d'eux atteint 0.
func _check_old_age() -> void:
	var limit := int(DB.species[character.species_id].get("aging_age", 0))
	if limit <= 0 or character.age_years() <= limit:
		return
	if rng.randf() >= float(DB.rules.get("aging_chance", 1.0)):
		return
	var ids := Abilities.ids()
	var id: String = ids[rng.randi_range(0, ids.size() - 1)]
	notices.append(Loc.ui("Le poids des ans : %s −1.") % Abilities.name_of(id))
	change_ability(id, -1, Loc.ui("Mort de vieillesse"))


# --- Sac du groupe -------------------------------------------------------------
# Le sac est celui du héros (character.inventory) : les compagnons s'équipent et se soignent en y
# puisant, et ce qu'ils retirent y retourne.

func inventory() -> Dictionary:
	return character.inventory


## Poids du sac (kg).
func bag_weight() -> float:
	var total := 0.0
	for item_id: String in character.inventory:
		total += Items.weight_of(item_id) * int(character.inventory[item_id])
	return total


## Charge du groupe : le sac et tout ce que portent les membres debout (kg).
func carried_weight() -> float:
	var total := bag_weight()
	for member in party():
		total += member.equipped_weight()
	return total


## Capacité du groupe : somme des capacités de ses membres (kg).
func carry_capacity() -> float:
	var total := 0.0
	for member in party():
		total += member.carry_capacity()
	return total


## Recalcule le malus de charge de chaque membre : 1 par tranche de overload_percent_per_penalty %
## au-delà de la capacité du groupe. À appeler après tout changement du sac ou de l'équipement.
func refresh_load() -> void:
	var capacity := maxf(carry_capacity(), 1.0)
	var over := (carried_weight() - capacity) / capacity * 100.0
	var step := float(DB.rules.get("encumbrance", {}).get("overload_percent_per_penalty", 10))
	var penalty := ceili(over / step) if over > 0.0 else 0
	for member in party():
		member.load_penalty = penalty


## Équipe un membre du groupe avec un objet du sac ; les objets retirés retournent dans le sac.
func equip(member: Character, item_id: String, slot := "") -> bool:
	if not Items.is_equipment(item_id) or character.item_count(item_id) <= 0:
		return false
	character.remove_item(item_id)
	for removed in member.equip(item_id, slot):
		if removed != Equipment.UNARMED:
			character.add_item(removed)
	refresh_load()
	return true


## Retire l'objet d'un emplacement d'un membre du groupe et le range dans le sac.
func unequip(member: Character, slot: String) -> bool:
	var removed := member.unequip(slot)
	if removed == "":
		return false
	if removed != Equipment.UNARMED:
		character.add_item(removed)
	refresh_load()
	return true


## Utilise un objet du sac hors combat sur un membre du groupe. Retourne le texte du résultat
## ("" si l'objet n'est pas utilisable).
func use_item(item_id: String, member: Character) -> String:
	if not Items.is_usable_outside_combat(item_id) or character.item_count(item_id) <= 0:
		return ""
	character.remove_item(item_id)
	var before := member.hp
	var heal: Dictionary = Items.def(item_id)["use"]["heal"]
	var roll := Dice.roll_pool(rng, int(heal.get("dice", 1)), int(heal.get("threshold", 5)))
	member.hp = mini(member.max_hp, member.hp + maxi(1, int(roll["successes"])))
	return Loc.ui("%s : %s récupère %d PV.") % [Items.name_of(item_id), member.name, member.hp - before]


## Jette des objets du sac (pas les objets de quête) ; retourne le nombre jeté.
func drop_item(item_id: String, count := 1) -> int:
	if Items.is_quest(item_id):
		return 0
	var dropped := character.remove_item(item_id, count)
	refresh_load()
	return dropped


# --- Boutiques, fabrication, forge ------------------------------------------------

## Stock actuel d'une boutique, reconstitué si son délai de réassort est passé.
func shop_stock(shop_id: String) -> Dictionary:
	var shop := Shops.def(shop_id)
	var state: Dictionary = shops.get(shop_id, {})
	if state.is_empty() or day - int(state.get("restocked", 0)) >= int(shop.get("restock_days", 7)):
		state = {"stock": Character._int_dict(shop.get("stock", {})), "restocked": day}
		shops[shop_id] = state
	return state["stock"]


## Achète un objet ; retourne false si la boutique n'en a plus ou si l'or manque.
func buy(shop_id: String, item_id: String) -> bool:
	var stock := shop_stock(shop_id)
	var price := Shops.buy_price(shop_id, item_id, self)
	if int(stock.get(item_id, 0)) <= 0 or character.gold < price:
		return false
	character.gold -= price
	stock[item_id] = int(stock[item_id]) - 1
	if stock[item_id] <= 0:
		stock.erase(item_id)
	character.add_item(item_id)
	refresh_load()
	return true


## Vend un objet du sac à une boutique qui le rachète ; il rejoint son stock.
func sell(shop_id: String, item_id: String) -> bool:
	if character.item_count(item_id) <= 0 or not Shops.buys(shop_id, item_id):
		return false
	var stock := shop_stock(shop_id)
	character.gold += Shops.sell_price(item_id, self, Shops.def(shop_id).get("location", ""))
	character.remove_item(item_id)
	stock[item_id] = int(stock.get(item_id, 0)) + 1
	refresh_load()
	return true


## Fabrique une recette avec les matériaux et l'or du sac : test de la compétence de la station (voir
## Crafting.check_for). Un échec gâche une partie des matériaux et l'or.
## Retourne {"ok": possible, "success", "text"}.
func craft(recipe_id: String) -> Dictionary:
	var recipe := Crafting.recipe(recipe_id)
	if recipe.is_empty() or Crafting.missing_for(recipe, self) != "":
		return {"ok": false, "success": false, "text": ""}
	var roll := Dice.roll_check(character, Crafting.check_for(recipe), rng)
	var materials: Dictionary = recipe.get("materials", {})
	var loss := 1.0 if roll["success"] else float(DB.rules.get("crafting", {}).get("failure_loss", 0.5))
	for item_id: String in materials:
		character.remove_item(item_id, ceili(int(materials[item_id]) * loss))
	character.gold -= int(recipe.get("gold", 0))
	var text: String = roll["text"] + " — "
	if roll["success"]:
		character.add_item(recipe["result"], int(recipe.get("count", 1)))
		var station: String = recipe.get("station", "")
		crafted[station] = int(crafted.get(station, 0)) + 1
		text += Loc.ui("réussi : %s.") % Items.name_of(recipe["result"])
	else:
		text += Loc.ui("raté, une partie des matériaux est gâchée.")
	refresh_load()
	return {"ok": true, "success": roll["success"], "text": text}


## Métiers qui se dessinent (« Forgeronne (7 objets) »).
func professions() -> Array[String]:
	var result: Array[String] = []
	for station: String in crafted:
		var title := Crafting.profession(station, int(crafted[station]), character.gender)
		if title != "":
			result.append(Loc.ui("%s (%d objets)") % [title, int(crafted[station])])
	return result


## Améliore à la forge un objet du sac, ou porté par un membre du groupe (`member`, `slot`).
func upgrade(item_id: String, member: Character = null, slot := "") -> bool:
	if not Crafting.can_upgrade(item_id) or character.gold < Crafting.upgrade_cost(item_id):
		return false
	if member != null:
		if member.equipment.get(slot, "") != item_id:
			return false
		member.equipment[slot] = Crafting.upgraded_id(item_id)
		member.refresh_max_hp()
	else:
		if character.item_count(item_id) <= 0:
			return false
		character.remove_item(item_id)
		character.add_item(Crafting.upgraded_id(item_id))
	character.gold -= Crafting.upgrade_cost(item_id)
	return true


# --- Sauvegarde ----------------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"character": character.to_dict(),
		"companions": companions.map(func(c): return c.to_dict()),
		"rng_seed": str(rng.seed),  # en texte : les entiers 64 bits ne survivent pas aux décimaux du JSON
		"rng_state": str(rng.state),
		"day": day, "slot": slot, "flags": flags, "seen": seen, "last_seen_day": last_seen_day,
		"dead": dead, "death_cause": death_cause, "recorded": recorded, "notices": notices,
		"pending_combat": pending_combat, "shops": shops, "reputation": reputation, "location": location,
		"crafted": crafted, "last_initiative_day": last_initiative_day, "quests": quests, "journal": journal, "notes": notes, "quest_defs": quest_defs,
		"bestiary": bestiary,
	}


static func from_dict(data: Dictionary) -> LifeState:
	var life := LifeState.new()
	life.character = Character.from_dict(data.get("character", {}))
	for c: Dictionary in data.get("companions", []):
		life.companions.append(Character.from_dict(c))
	life.rng.seed = String(data.get("rng_seed", "0")).to_int()
	life.rng.state = String(data.get("rng_state", "0")).to_int()
	life.day = int(data.get("day", 1))
	life.slot = int(data.get("slot", 0))
	life.flags = data.get("flags", {})
	life.seen = Character._int_dict(data.get("seen", {}))
	life.last_seen_day = Character._int_dict(data.get("last_seen_day", {}))
	life.dead = data.get("dead", false)
	life.death_cause = data.get("death_cause", "")
	life.recorded = data.get("recorded", false)
	life.notices.assign(data.get("notices", []))
	life.reputation = Character._int_dict(data.get("reputation", {}))
	life.location = data.get("location", "")
	life.crafted = Character._int_dict(data.get("crafted", {}))
	life.notes = String(data.get("notes", ""))
	life.quest_defs = data.get("quest_defs", {})
	life.bestiary.assign(data.get("bestiary", []))
	for entry: Dictionary in data.get("journal", []):
		life.journal.append({"day": int(entry.get("day", 1)), "slot": int(entry.get("slot", 0)),
			"kind": String(entry.get("kind", "event")), "text": String(entry.get("text", ""))})
	var saved_quests: Dictionary = data.get("quests", {})
	for quest_id: String in saved_quests:
		life.quests[quest_id] = {"status": String(saved_quests[quest_id].get("status", "active")),
			"step": int(saved_quests[quest_id].get("step", 0))}
	life.last_initiative_day = int(data.get("last_initiative_day", -1))
	life.pending_combat = data.get("pending_combat", {})
	var saved_shops: Dictionary = data.get("shops", {})
	for shop_id: String in saved_shops:
		life.shops[shop_id] = {"stock": Character._int_dict(saved_shops[shop_id].get("stock", {})),
			"restocked": int(saved_shops[shop_id].get("restocked", 0))}
	life.refresh_load()
	return life
