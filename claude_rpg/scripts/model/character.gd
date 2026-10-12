class_name Character
extends RefCounted
## Un personnage (le héros, et plus tard les compagnons). Règles inspirées du SRD 5e.

var name := ""
var race_id := ""
var class_id := ""
var abilities: Dictionary = {}  # id d'attribut -> valeur (3-20)
var level := 1
var xp := 0
var hp := 1
var max_hp := 1
var gold := 0
var inventory: Dictionary = {}  # id d'objet -> quantité
var start_age := 18
var age_days := 0  # jours vécus depuis le début de la partie
var art_seed := 0  # graine des variations du portrait procédural


static func create(race: String, cls: String, char_name: String) -> Character:
	var c := Character.new()
	c.race_id = race
	c.class_id = cls
	c.name = char_name
	var race_data: Dictionary = DB.races[race]
	var class_data: Dictionary = DB.classes[cls]

	# Répartition standard (15, 14, 13...) selon les priorités de la classe, puis bonus raciaux.
	var scores: Array = DB.rules["standard_array"]
	var priority: Array = class_data["ability_priority"]
	for i in priority.size():
		c.abilities[priority[i]] = int(scores[i])
	var bonus: Dictionary = race_data.get("ability_bonus", {})
	for ability: String in bonus:
		c.abilities[ability] = int(c.abilities.get(ability, 10)) + int(bonus[ability])

	c.max_hp = maxi(1, int(class_data["hit_die"]) + c.ability_mod("con"))
	c.hp = c.max_hp
	c.gold = int(DB.rules.get("start_gold", 0))
	var start_items: Dictionary = class_data.get("start_items", {})
	for item_id: String in start_items:
		c.add_item(item_id, int(start_items[item_id]))
	c.start_age = int(race_data.get("start_age", 18))
	return c


## Personnage aléatoire parmi les races et classes débloquées.
static func create_random(rng: RandomNumberGenerator, meta: MetaState) -> Character:
	var race_ids: Array = DB.races.keys().filter(meta.is_race_available)
	var class_ids: Array = DB.classes.keys().filter(meta.is_class_available)
	var race: String = race_ids[rng.randi_range(0, race_ids.size() - 1)]
	var cls: String = class_ids[rng.randi_range(0, class_ids.size() - 1)]
	var names: Array = DB.races[race].get("names", ["Sans-Nom"])
	var c := create(race, cls, names[rng.randi_range(0, names.size() - 1)])
	c.art_seed = rng.randi()
	return c


func ability_mod(ability_id: String) -> int:
	return floori((int(abilities.get(ability_id, 10)) - 10) / 2.0)


func proficiency_bonus() -> int:
	var table: Array = DB.rules.get("proficiency_by_level", [2])
	return int(table[clampi(level - 1, 0, table.size() - 1)])


func is_proficient(skill_id: String) -> bool:
	return skill_id in DB.classes[class_id].get("skills", [])


func skill_mod(skill_id: String) -> int:
	var ability: String = DB.skills[skill_id]["ability"]
	return ability_mod(ability) + (proficiency_bonus() if is_proficient(skill_id) else 0)


@warning_ignore("integer_division")
func age_years() -> int:
	return start_age + age_days / DB.days_per_year()


func life_stage() -> String:
	var thresholds: Dictionary = DB.races[race_id].get("age_stages", {})
	var age := age_years()
	var current := "adult"
	for stage: Dictionary in DB.rules["life_stages"]:
		var id: String = stage["id"]
		if thresholds.has(id) and age >= int(thresholds[id]):
			current = id
	return current


## Ajoute de l'XP et retourne la liste des niveaux atteints.
@warning_ignore("integer_division")
func add_xp(amount: int) -> Array[int]:
	xp += amount
	var reached: Array[int] = []
	var table: Array = DB.rules.get("xp_by_level", [0])
	while level < table.size() and xp >= int(table[level]):
		level += 1
		var gain := maxi(1, int(DB.classes[class_id]["hit_die"]) / 2 + 1 + ability_mod("con"))
		max_hp += gain
		hp += gain
		reached.append(level)
	return reached


func item_count(item_id: String) -> int:
	return int(inventory.get(item_id, 0))


func add_item(item_id: String, count := 1) -> void:
	inventory[item_id] = item_count(item_id) + count


## Retire jusqu'à `count` objets et retourne le nombre réellement retiré.
func remove_item(item_id: String, count := 1) -> int:
	var removed := mini(count, item_count(item_id))
	var left := item_count(item_id) - removed
	if left > 0:
		inventory[item_id] = left
	else:
		inventory.erase(item_id)
	return removed
