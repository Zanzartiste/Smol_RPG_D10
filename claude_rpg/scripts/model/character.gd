class_name Character
extends RefCounted
## Un personnage (le héros ou un compagnon). Règles inspirées du SRD 5e.
## Les règles elles-mêmes vivent dans scripts/rules/ (Abilities, Skills, Feats, Equipment,
## DamageTypes, Modifiers, Defenses, ClassFeatures, Spellcasting) : ce script ne fait que les combiner.

var name := ""
var species_id := ""
var class_id := ""
var background_id := ""  # passé ("" = aucun)
var gender := ""  # sans effet sur l'apparence ; sert aux accords dans les textes
var abilities: Dictionary = {}  # valeurs de base (achat de points, vieillesse…) ; voir ability_score()
var feats: Array[String] = []  # dons
var pending_feats := 0  # dons à choisir (gagnés en montant de niveau)
var pending_ability_points := 0  # points d'attribut à répartir (gagnés en montant de niveau)
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
var load_penalty := 0  # malus de charge du groupe (calculé par LifeState.refresh_load, non sauvegardé)
var resources: Dictionary = {}  # ressources restantes (spell_slot_1…, indomitable…), rechargées par un repos long


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
	var background_feat := Feats.for_background(c.background_id)
	if background_feat != "":
		c.feats.append(background_feat)
	c.equipment = class_data.get("equipment", {}).duplicate()
	c.pending_feats += int(DB.species[species].get("bonus_feats", 0))  # ex. don en plus des humains


	c.max_hp = c.compute_max_hp()
	c.hp = c.max_hp
	c.resources = c.max_resources()
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
	c.xp = Progression.xp_for(c.level)
	c.max_hp = c.compute_max_hp()
	c.hp = c.max_hp
	c.resources = c.max_resources()
	return c


static func _pick(list: Array, rng: RandomNumberGenerator) -> Variant:
	return list[rng.randi_range(0, list.size() - 1)]


# --- Modificateurs (espèce, aptitudes de classe, dons, équipement) ---------

## Tous les modificateurs qui s'appliquent au personnage.
func modifiers() -> Array:
	var result: Array = []
	result.append_array(DB.species[species_id].get("modifiers", []))
	for feature: Dictionary in features():
		result.append_array(feature.get("modifiers", []))
	for feat_id in feats:
		result.append_array(Feats.modifiers_of(feat_id))
	for slot: String in equipment:
		result.append_array(Equipment.modifiers_of(equipment[slot]))
	return result


## Le personnage a-t-il un modificateur sans valeur (ex. "evasion", "uncanny_dodge") ?
func has_modifier(type: String) -> bool:
	return modifiers().any(func(m): return m.get("type") == type)


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
	return Progression.proficiency_bonus(level)


## Compétences maîtrisées : classe, passé et modificateurs (dons…).
func is_proficient(skill_id: String) -> bool:
	return skill_id in DB.classes[class_id].get("skills", []) \
		or skill_id in DB.backgrounds.get(background_id, {}).get("skills", []) \
		or Modifiers.grants(modifiers(), "skill_proficiency", skill_id)


## Expertise : bonus de maîtrise doublé dans la compétence.
func has_expertise(skill_id: String) -> bool:
	return is_proficient(skill_id) and Modifiers.grants(modifiers(), "skill_expertise", skill_id)


func skill_mod(skill_id: String) -> int:
	var proficiency := 0
	if is_proficient(skill_id):
		proficiency = proficiency_bonus() * (2 if has_expertise(skill_id) else 1)
	var ability := Skills.ability_of(skill_id)
	return ability_mod(ability) + proficiency - roll_penalty(ability)


## Test d'attribut (événements) : modificateur moins l'encombrement pour FOR et DEX.
func check_mod(ability_id: String) -> int:
	return ability_mod(ability_id) - roll_penalty(ability_id)


## Jets de sauvegarde maîtrisés : ceux de la classe et des modificateurs.
func is_proficient_save(ability_id: String) -> bool:
	return ability_id in DB.classes[class_id].get("saving_throws", []) 		or Modifiers.grants(modifiers(), "save_proficiency", ability_id)


func save_mod(ability_id: String) -> int:
	return ability_mod(ability_id) + (proficiency_bonus() if is_proficient_save(ability_id) else 0) \
		+ Modifiers.sum(modifiers(), "saving_throws") - roll_penalty(ability_id)


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


## Le personnage a-t-il un point d'attribut à placer (et un attribut sous le plafond) ?
func can_increase_ability() -> bool:
	return pending_ability_points > 0 and Abilities.ids().any(func(id): return can_raise(id))


## Une amélioration (attribut ou don) attend-elle un choix du joueur ?
func has_pending_advancement() -> bool:
	return can_increase_ability() or can_choose_feat()


func can_raise(ability_id: String) -> bool:
	return int(abilities.get(ability_id, 10)) < Progression.max_ability_score()


## Dépense un point d'attribut gagné en montant de niveau.
func increase_ability(ability_id: String) -> bool:
	if pending_ability_points <= 0 or not can_raise(ability_id):
		return false
	pending_ability_points -= 1
	abilities[ability_id] = int(abilities[ability_id]) + 1
	refresh_max_hp()
	return true


## Choisit un des dons gagnés en montant de niveau.
func choose_feat(feat_id: String) -> bool:
	if pending_feats <= 0 or feat_id not in available_feats():
		return false
	pending_feats -= 1
	return add_feat(feat_id)


# --- Équipement --------------------------------------------------------------

# --- Encombrement ----------------------------------------------------------------
# Deux sources, cumulées et plafonnées (rules.json › encumbrance) : une armure qui demande plus de
# Force que le personnage n'en a, et la charge du groupe au-delà de sa capacité (load_penalty).
# Le malus s'applique à tous les jets de FOR et de DEX.

static func _encumbrance(key: String, default: Variant) -> Variant:
	return DB.rules.get("encumbrance", {}).get(key, default)


## Points de Force qui manquent pour porter un équipement sans malus (0 si aucun).
func strength_missing(item_id: String) -> int:
	return maxi(0, Equipment.strength_required(item_id) - ability_score("str"))


## Malus dû aux armures trop lourdes.
func armor_penalty() -> int:
	var missing := 0
	for slot: String in equipment:
		missing = maxi(missing, strength_missing(equipment[slot]))
	return ceili(missing / float(_encumbrance("armor_points_per_penalty", 2)))


## Malus total aux jets de FOR et de DEX.
func encumbrance_penalty() -> int:
	return mini(armor_penalty() + load_penalty, int(_encumbrance("max_penalty", 5)))


func is_encumbered() -> bool:
	return encumbrance_penalty() > 0


## Malus d'un jet selon l'attribut utilisé (FOR et DEX seulement).
func roll_penalty(ability_id: String) -> int:
	return encumbrance_penalty() if ability_id in ["str", "dex"] else 0


## Charge que ce personnage peut porter sans malus (kg).
func carry_capacity() -> float:
	return ability_score("str") * float(_encumbrance("carry_per_strength", 7.5))


## Poids de ce que le personnage porte sur lui (kg).
func equipped_weight() -> float:
	var total := 0.0
	for slot: String in equipment:
		total += Equipment.weight_of(equipment[slot])
	return total


## Pourquoi un équipement encombrerait le personnage ("" s'il le porte sans malus de Force).
func encumbrance_reason(item_id: String) -> String:
	var missing := strength_missing(item_id)
	if missing <= 0:
		return ""
	var penalty := ceili(missing / float(_encumbrance("armor_points_per_penalty", 2)))
	return Loc.ui("Force %d conseillée (vous avez %d) : −%d aux jets de FOR et DEX") % [
		Equipment.strength_required(item_id), ability_score("str"), penalty]


func weapon_id() -> String:
	return equipment.get("main_hand", Equipment.UNARMED)


## Équipe un objet à son emplacement naturel ; retourne les ids retirés pour lui faire de la place
## (l'objet de l'emplacement, et la main secondaire libérée par une arme à deux mains, ou l'arme à
## deux mains libérée par un bouclier). Un anneau prend le premier emplacement d'anneau libre.
func equip(item_id: String) -> Array[String]:
	var removed: Array[String] = []
	var candidates := Equipment.slots_for(item_id)
	var slot: String = candidates[0]
	for candidate: String in candidates:
		if not equipment.has(candidate):
			slot = candidate
			break
	if equipment.has(slot):
		removed.append(equipment[slot])
	equipment[slot] = item_id
	if slot == "main_hand" and Equipment.has_property(item_id, "two_handed") and equipment.has("off_hand"):
		removed.append(equipment["off_hand"])
		equipment.erase("off_hand")
	if slot == "off_hand" and Equipment.has_property(weapon_id(), "two_handed"):
		removed.append(equipment["main_hand"])
		equipment.erase("main_hand")
	refresh_max_hp()  # un objet peut changer la CON ou les PV par niveau
	return removed


## Retire l'objet d'un emplacement ; retourne son id ("" si l'emplacement était vide).
func unequip(slot: String) -> String:
	var previous: String = equipment.get(slot, "")
	equipment.erase(slot)
	refresh_max_hp()
	return previous


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
	return ability_mod("dex") + Modifiers.sum(modifiers(), "initiative") - roll_penalty("dex")


## Attribut utilisé par une action : "weapon" (celui de l'arme), "spell" (celui de la classe) ou un id d'attribut.
func action_ability(ability: String) -> String:
	match ability:
		"weapon":
			return Equipment.attack_ability(weapon_id(), ability_mod("str"), ability_mod("dex"))
		"spell":
			return DB.classes[class_id].get("spellcasting", "int")
	return ability


func attack_bonus(ability: String) -> int:
	var used := action_ability(ability)
	return ability_mod(used) + proficiency_bonus() - roll_penalty(used)


# --- Aptitudes de classe et ressources -----------------------------------------

## Niveau dans la classe (égal au niveau du personnage tant qu'il n'y a pas de multiclassage).
func class_level() -> int:
	return level


## Aptitudes de classe acquises (classes.json › features).
func features() -> Array:
	return ClassFeatures.up_to(class_id, class_level())


## Ressources maximales : celles de l'espèce, de la classe et des aptitudes, plus les emplacements de sort.
func max_resources() -> Dictionary:
	var result: Dictionary = DB.classes[class_id].get("resources", {}).duplicate()
	var species_resources: Dictionary = DB.species[species_id].get("resources", {})
	for id: String in species_resources:
		result[id] = int(result.get(id, 0)) + int(species_resources[id])
	for feature: Dictionary in features():
		var granted: Dictionary = feature.get("resources", {})
		for id: String in granted:
			result[id] = int(result.get(id, 0)) + int(granted[id])
	result.merge(Spellcasting.slots(DB.classes[class_id].get("spell_slots", ""), class_level()))
	for id: String in result:
		result[id] = int(result[id])
	return result


func max_resource(resource_id: String) -> int:
	return int(max_resources().get(resource_id, 0))


## Actions de combat : celles de la classe puis celles des aptitudes acquises (ids de actions.json).
func combat_actions() -> Array:
	var result: Array = DB.classes[class_id].get("actions", []).duplicate()
	for feature: Dictionary in features():
		for action_id: String in feature.get("actions", []):
			if action_id not in result:
				result.append(action_id)
	return result


## Repos long : PV et ressources (emplacements de sort…) au maximum.
func long_rest() -> void:
	hp = max_hp
	resources = max_resources()


## Ajuste les ressources après un changement de niveau : les nouvelles sont pleines, celles qui
## augmentent gagnent la différence, celles qui n'existent plus disparaissent.
func _sync_resources(previous_max: Dictionary) -> void:
	var new_max := max_resources()
	var synced := {}
	for id: String in new_max:
		var gained := int(new_max[id]) - int(previous_max.get(id, 0))
		synced[id] = clampi(int(resources.get(id, 0)) + gained, 0, int(new_max[id]))
	resources = synced


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
## Un niveau d'amélioration (Progression) donne des points d'attribut et des dons à choisir.
func add_xp(amount: int) -> Array[int]:
	xp += amount
	var reached: Array[int] = []
	var previous_max := max_resources()
	while level < Progression.max_level() and xp >= Progression.xp_for(level + 1):
		level += 1
		refresh_max_hp()
		if Progression.is_advancement_level(level):
			pending_ability_points += Progression.ability_points_per_advancement()
			pending_feats += Progression.feats_per_advancement()
		reached.append(level)
	if not reached.is_empty():
		_sync_resources(previous_max)
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


# --- Sauvegarde ----------------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"name": name, "species_id": species_id, "class_id": class_id, "background_id": background_id,
		"gender": gender, "abilities": abilities, "feats": feats, "pending_feats": pending_feats,
		"pending_ability_points": pending_ability_points, "equipment": equipment, "defenses": defenses.to_dict(),
		"level": level, "xp": xp, "hp": hp, "max_hp": max_hp, "gold": gold, "inventory": inventory,
		"start_age": start_age, "age_days": age_days, "art_seed": art_seed, "template_id": template_id,
		"resources": resources,
	}


## Recrée un personnage sauvegardé. Le JSON ne distingue pas entiers et décimaux : on reconvertit.
static func from_dict(data: Dictionary) -> Character:
	var c := Character.new()
	c.name = data.get("name", "")
	c.species_id = data.get("species_id", "")
	c.class_id = data.get("class_id", "")
	c.background_id = data.get("background_id", "")
	c.gender = data.get("gender", "nonbinary")
	c.abilities = _int_dict(data.get("abilities", {}))
	c.feats.assign(data.get("feats", []))
	c.pending_feats = int(data.get("pending_feats", 0))
	c.pending_ability_points = int(data.get("pending_ability_points", 0))
	c.equipment = data.get("equipment", {})
	# Anciennes sauvegardes : amulet -> neck, ring -> ring_1, cloak (supprimé) -> sac.
	for old_slot: String in {"amulet": "neck", "ring": "ring_1"}:
		if c.equipment.has(old_slot):
			c.equipment[{"amulet": "neck", "ring": "ring_1"}[old_slot]] = c.equipment[old_slot]
			c.equipment.erase(old_slot)
	if c.equipment.has("cloak"):
		c.equipment.erase("cloak")
	c.defenses = Defenses.from_dict(data.get("defenses", {}))
	c.level = int(data.get("level", 1))
	c.xp = int(data.get("xp", 0))
	c.hp = int(data.get("hp", 1))
	c.max_hp = int(data.get("max_hp", 1))
	c.gold = int(data.get("gold", 0))
	c.inventory = _int_dict(data.get("inventory", {}))
	c.start_age = int(data.get("start_age", 18))
	c.age_days = int(data.get("age_days", 0))
	c.art_seed = int(data.get("art_seed", 0))
	c.template_id = data.get("template_id", "")
	c.resources = _int_dict(data.get("resources", {}))
	# Anciennes sauvegardes (ex. "spell_slot" unique) : on ne garde que les ressources connues.
	var max_now := c.max_resources()
	for id: String in max_now:
		if not c.resources.has(id):
			c.resources[id] = max_now[id]
	for id: String in c.resources.keys():
		if not max_now.has(id):
			c.resources.erase(id)
	return c


static func _int_dict(data: Variant) -> Dictionary:
	var result := {}
	if typeof(data) == TYPE_DICTIONARY:
		for key in data:
			result[key] = int(data[key])
	return result
