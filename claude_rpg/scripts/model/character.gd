class_name Character
extends RefCounted
## Un personnage (le héros, et plus tard les compagnons). Règles inspirées du SRD 5e.

var name := ""
var species_id := ""
var class_id := ""
var background_id := ""  # passé ("" = aucun)
var gender := ""  # sans effet sur l'apparence ; sert aux accords dans les textes
var abilities: Dictionary = {}  # id d'attribut -> valeur ; 0 = mort
var level := 1
var xp := 0
var hp := 1
var max_hp := 1
var gold := 0
var inventory: Dictionary = {}  # id d'objet -> quantité
var start_age := 18
var age_days := 0  # jours vécus depuis le début de la partie
var art_seed := 0  # graine des variations du portrait procédural


## Options : "abilities" (scores finaux, sinon modèle de la classe), "background", "gender".
static func create(species: String, cls: String, char_name: String, options: Dictionary = {}) -> Character:
	var c := Character.new()
	c.species_id = species
	c.class_id = cls
	c.name = char_name
	c.background_id = options.get("background", "")
	c.gender = options.get("gender", "nonbinary")
	var class_data: Dictionary = DB.classes[cls]
	var background: Dictionary = DB.backgrounds.get(c.background_id, {})

	var scores: Dictionary = options.get("abilities", {})
	if scores.is_empty():
		scores = PointBuy.from_class(cls).final_scores()
	for ability: String in DB.abilities:
		c.abilities[ability] = int(scores.get(ability, 10))

	c.max_hp = maxi(1, int(class_data["hit_die"]) + c.ability_mod("con"))
	c.hp = c.max_hp
	c.gold = int(DB.rules.get("start_gold", 0)) + int(background.get("gold", 0))
	for source: Dictionary in [class_data, background]:
		var start_items: Dictionary = source.get("start_items", {})
		for item_id: String in start_items:
			c.add_item(item_id, int(start_items[item_id]))
	c.start_age = int(DB.species[species].get("start_age", 18))
	return c


## Personnage aléatoire parmi les espèces et classes débloquées.
static func create_random(rng: RandomNumberGenerator, meta: MetaState) -> Character:
	var species_ids: Array = DB.species.keys().filter(meta.is_species_available)
	var class_ids: Array = DB.classes.keys().filter(meta.is_class_available)
	var background_ids: Array = DB.backgrounds.keys()
	var genders: Array = DB.rules["genders"]
	var species: String = _pick(species_ids, rng)
	var names: Array = DB.species[species].get("names", ["Sans-Nom"])
	var c := create(species, _pick(class_ids, rng), _pick(names, rng), {
		"background": _pick(background_ids, rng) if not background_ids.is_empty() else "",
		"gender": _pick(genders, rng)["id"],
	})
	c.art_seed = rng.randi()
	return c


static func _pick(list: Array, rng: RandomNumberGenerator) -> Variant:
	return list[rng.randi_range(0, list.size() - 1)]


func ability_mod(ability_id: String) -> int:
	return floori((int(abilities.get(ability_id, 10)) - 10) / 2.0)


func proficiency_bonus() -> int:
	var table: Array = DB.rules.get("proficiency_by_level", [2])
	return int(table[clampi(level - 1, 0, table.size() - 1)])


## Compétences maîtrisées : celles de la classe et celles du passé.
func is_proficient(skill_id: String) -> bool:
	return skill_id in DB.classes[class_id].get("skills", []) \
		or skill_id in DB.backgrounds.get(background_id, {}).get("skills", [])


func skill_mod(skill_id: String) -> int:
	var ability: String = DB.skills[skill_id]["ability"]
	return ability_mod(ability) + (proficiency_bonus() if is_proficient(skill_id) else 0)


## Catégorie de taille, déterminée par l'espèce (tiny, small, medium, large).
func size() -> String:
	return DB.species[species_id].get("size", "medium")


@warning_ignore("integer_division")
func age_years() -> int:
	return start_age + age_days / DB.days_per_year()


func life_stage() -> String:
	var thresholds: Dictionary = DB.species[species_id].get("age_stages", {})
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
