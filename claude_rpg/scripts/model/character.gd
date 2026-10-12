class_name Character
extends RefCounted
## Un personnage (le héros ou un compagnon). Règles inspirées du SRD 5e.
## Les règles elles-mêmes vivent dans scripts/rules/ (Abilities, Skills, Feats, Equipment,
## DamageTypes, Modifiers, Defenses) : ce script ne fait que les combiner.

var name := ""
var species_id := ""
var class_id := ""
var background_id := ""  # passé ("" = aucun)
var gender := ""  # sans effet sur l'apparence ; sert aux accords dans les textes
var abilities: Dictionary = {}  # valeurs de base (achat de points, vieillesse…) ; voir ability_score()
var feats: Array[String] = []  # dons
var pending_feats := 0  # dons à choisir (gagnés en montant de niveau)
var equipment: Dictionary = {}  # emplacement (Equipment.SLOTS) -> id d'équipement
var defenses := Defenses.new()  # défenses propres au personnage (accordées par des événements)
var level := 1
var xp := 0
var hp := 1
var max_hp := 1
var gold := 0
var inventory: Dictionary = {}  # id d'objet -> quantité
var start_age := 18
var age_days := 0  # jours vécus depuis le début de la partie
var art_seed := 0  # graine des variations du portrait procédural
var template_id := ""  # pour un compagnon : son id dans companions.json
var resources: Dictionary = {}  # ressources restantes (ex. spell_slot), rechargées par un repos long


## Options : "abilities" (scores, sinon modèle de la classe), "background", "gender".
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
	for ability in Abilities.ids():
		c.abilities[ability] = int(scores.get(ability, 10))
	c.equipment = class_data.get("equipment", {}).duplicate()
	var background_feat := Feats.for_background(c.background_id)
	if background_feat != "":
		c.feats.append(background_feat)

	c.max_hp = c.compute_max_hp()
	c.hp = c.max_hp
	c.resources = class_data.get("resources", {}).duplicate()
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


## Compagnon décrit dans companions.json.
static func create_companion(companion_id: String) -> Character:
	var t: Dictionary = DB.companions[companion_id]
	var c := create(t["species"], t["class"], t["name"], {
		"background": t.get("background", ""), "gender": t.get("gender", "nonbinary")})
	c.template_id = companion_id
	c.art_seed = int(t.get("art_seed", hash(companion_id)))
	for feat_id: String in t.get("feats", []):
		c.feats.append(feat_id)
	c.level = int(t.get("level", 1))
	c.xp = int(DB.rules["xp_by_level"][c.level - 1])
	c.max_hp = c.compute_max_hp()
	c.hp = c.max_hp
	return c


static func _pick(list: Array, rng: RandomNumberGenerator) -> Variant:
	return list[rng.randi_range(0, list.size() - 1)]


# --- Modificateurs (espèce, dons, équipement) -------------------------------

## Tous les modificateurs qui s'appliquent au personnage.
func modifiers() -> Array:
	var result: Array = []
	result.append_array(DB.species[species_id].get("modifiers", []))
	for feat_id in feats:
		result.append_array(Feats.modifiers_of(feat_id))
	for slot: String in equipment:
		result.append_array(Equipment.modifiers_of(equipment[slot]))
	return result


## Défenses complètes : celles du personnage + celles de l'espèce, des dons et de l'équipement.
func all_defenses() -> Defenses:
	var result := Modifiers.defenses(modifiers())
	result.merge(defenses)
	return result


# --- Attributs et compétences ------------------------------------------------

## Valeur d'un attribut : base + modificateurs (dons…).
func ability_score(ability_id: String) -> int:
	return int(abilities.get(ability_id, 10)) + Modifiers.sum(modifiers(), "ability", ability_id)


func ability_mod(ability_id: String) -> int:
	return Abilities.modifier(ability_score(ability_id))


func proficiency_bonus() -> int:
	var table: Array = DB.rules.get("proficiency_by_level", [2])
	return int(table[clampi(level - 1, 0, table.size() - 1)])


## Compétences maîtrisées : classe, passé et modificateurs (dons…).
func is_proficient(skill_id: String) -> bool:
	return skill_id in DB.classes[class_id].get("skills", []) \
		or skill_id in DB.backgrounds.get(background_id, {}).get("skills", []) \
		or Modifiers.grants(modifiers(), "skill_proficiency", skill_id)


func skill_mod(skill_id: String) -> int:
	return ability_mod(Skills.ability_of(skill_id)) + (proficiency_bonus() if is_proficient(skill_id) else 0)


# --- Dons --------------------------------------------------------------------

func has_feat(feat_id: String) -> bool:
	return feat_id in feats


## Ajoute un don ; retourne false si le personnage l'a déjà.
func add_feat(feat_id: String) -> bool:
	if has_feat(feat_id):
		return false
	feats.append(feat_id)
	refresh_max_hp()  # le don peut changer la CON ou les PV par niveau
	return true


## Dons que le personnage peut choisir : prérequis remplis et pas encore possédés.
func available_feats() -> Array[String]:
	var result: Array[String] = []
	for feat_id in Feats.ids():
		if not has_feat(feat_id) and Feats.meets_prerequisites(feat_id, self):
			result.append(feat_id)
	return result


## Le personnage a-t-il un don à choisir (et au moins un don disponible) ?
func can_choose_feat() -> bool:
	return pending_feats > 0 and not available_feats().is_empty()


## Choisit un des dons gagnés en montant de niveau.
func choose_feat(feat_id: String) -> bool:
	if pending_feats <= 0 or feat_id not in available_feats():
		return false
	pending_feats -= 1
	return add_feat(feat_id)


# --- Équipement --------------------------------------------------------------

func weapon_id() -> String:
	return equipment.get("main_hand", Equipment.UNARMED)


## Équipe un objet à son emplacement naturel ; retourne l'id remplacé ("" si aucun).
## Une arme à deux mains libère la main secondaire, un bouclier libère une arme à deux mains.
func equip(item_id: String) -> String:
	var slot := Equipment.slot_for(item_id)
	var previous: String = equipment.get(slot, "")
	equipment[slot] = item_id
	if slot == "main_hand" and Equipment.has_property(item_id, "two_handed"):
		equipment.erase("off_hand")
	if slot == "off_hand" and Equipment.has_property(weapon_id(), "two_handed"):
		equipment.erase("main_hand")
	return previous


func unequip(slot: String) -> void:
	equipment.erase(slot)


## Dégâts de l'arme en main (polyvalente à deux mains si la main secondaire est libre).
func weapon_damage() -> String:
	return Equipment.weapon_damage(weapon_id(), not equipment.has("off_hand"))


func weapon_damage_type() -> String:
	return Equipment.damage_type_of(weapon_id())


## Classe d'armure : armure, DEX, bouclier (voir Equipment.armor_class) + modificateurs.
func armor_class() -> int:
	return Equipment.armor_class(equipment.get("armor", ""), equipment.get("off_hand", ""), ability_mod("dex")) \
		+ Modifiers.sum(modifiers(), "ac")


func initiative_bonus() -> int:
	return ability_mod("dex") + Modifiers.sum(modifiers(), "initiative")


## Attribut utilisé par une action : "weapon" (celui de l'arme), "spell" (celui de la classe) ou un id d'attribut.
func action_ability(ability: String) -> String:
	match ability:
		"weapon":
			return Equipment.attack_ability(weapon_id(), ability_mod("str"), ability_mod("dex"))
		"spell":
			return DB.classes[class_id].get("spellcasting", "int")
	return ability


func attack_bonus(ability: String) -> int:
	return ability_mod(action_ability(ability)) + proficiency_bonus()


func max_resource(resource_id: String) -> int:
	return int(DB.classes[class_id].get("resources", {}).get(resource_id, 0))


## Repos long : PV et ressources (emplacements de sort...) au maximum.
func long_rest() -> void:
	hp = max_hp
	resources = DB.classes[class_id].get("resources", {}).duplicate()


# --- Âge et taille -----------------------------------------------------------

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


# --- PV et niveaux -----------------------------------------------------------

## PV max façon D&D 5e : dé de vie complet + CON au niveau 1, puis (dé / 2 + 1) + CON par niveau,
## au moins 1 PV par niveau ; + les PV par niveau des modificateurs (don Robuste…).
@warning_ignore("integer_division")
func compute_max_hp() -> int:
	var hit_die := int(DB.classes[class_id]["hit_die"])
	var con := ability_mod("con")
	var bonus := Modifiers.sum(modifiers(), "hp_per_level") * level
	return maxi(1, hit_die + con) + (level - 1) * maxi(1, hit_die / 2 + 1 + con) + bonus


## Recalcule les PV max (après un changement de niveau, de Constitution ou de don).
## Les PV actuels suivent la même variation, sans sortir de [0, PV max].
func refresh_max_hp() -> void:
	var new_max := compute_max_hp()
	hp = clampi(hp + new_max - max_hp, 0, new_max)
	max_hp = new_max


## Ajoute de l'XP et retourne la liste des niveaux atteints.
## Atteindre un niveau de Feats.levels() donne un don à choisir (pending_feats).
func add_xp(amount: int) -> Array[int]:
	xp += amount
	var reached: Array[int] = []
	var table: Array = DB.rules.get("xp_by_level", [0])
	while level < table.size() and xp >= int(table[level]):
		level += 1
		refresh_max_hp()
		if level in Feats.levels():
			pending_feats += 1
		reached.append(level)
	return reached


# --- Inventaire --------------------------------------------------------------

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
