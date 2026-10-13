class_name Character
extends RefCounted
## Un personnage (le héros ou un compagnon). Règles inspirées du SRD 5e.
## Les règles elles-mêmes vivent dans scripts/rules/ (Abilities, Skills, Feats, Equipment,
## DamageTypes, Modifiers, Defenses, ClassFeatures, Spellcasting) : ce script ne fait que les combiner.

var name := ""
var species_id := ""
var class_id := ""  # classe principale (celle de la création : sauvegardes, compétences de classe, portrait)
var class_levels: Dictionary = {}  # id de classe -> niveau dans cette classe (multiclassage)
var pending_class_levels := 0  # niveaux gagnés dont la classe reste à choisir (au hub)
var background_id := ""  # passé ("" = aucun)
var gender := ""  # sans effet sur l'apparence ; sert aux accords dans les textes
var abilities: Dictionary = {}  # valeurs de base (achat de points, vieillesse…) ; voir ability_score()
var feats: Array[String] = []  # dons
var choices: Dictionary = {}  # « source/id du choix » -> valeurs choisies (voir Choices)
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
var npc_id := ""  # PNJ du monde lié à ce personnage (compagnon recruté, ou compagnon avec relation)
var auto_combat := false  # en combat, l'IA joue ce personnage
var load_penalty := 0  # malus de charge du groupe (calculé par LifeState.refresh_load, non sauvegardé)
var resources: Dictionary = {}  # ressources restantes (spell_slot_1…, indomitable…), rechargées par un repos long


## Options : "abilities" (scores, sinon modèle de la classe), "background", "gender",
## "choices" ({clé: valeurs} pour les choix faits à la création ; sinon leurs valeurs par défaut).
static func create(species: String, cls: String, char_name: String, options: Dictionary = {}) -> Character:
	var c := Character.new()
	c.species_id = species
	c.class_id = cls
	c.class_levels = {cls: 1}
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
	var given: Dictionary = options.get("choices", {})
	for key: String in given:
		for value: String in given[key]:
			c.choose(key, value)
	c.apply_default_choices(true)


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
	c.class_levels = {c.class_id: c.level}
	c.xp = Progression.xp_for(c.level)
	c.complete_all_choices()  # un compagnon arrive avec ses choix déjà faits
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
	for entry: Dictionary in choice_specs():
		result.append_array(Choices.modifiers_from(entry["spec"], choices.get(entry["key"], [])))
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


# --- Compétences : rangs ---------------------------------------------------------------
# Rang = rang de départ (1, 2 si instinctive ; Magie : 0, ou 2 pour un lanceur de sorts)
#        + 1 par passé qui la donne + rangs de la classe (skill_ranks) + modificateurs "skill_rank"
#        (choix de classe, dons, Expertise, équipement…).
# Test = d20 + modificateur d'attribut + rang.

## Le personnage lance-t-il des sorts par sa classe ?
func is_caster() -> bool:
	return class_levels.keys().any(func(cls): return DB.classes[cls].has("spellcasting"))


## Rangs de compétence donnés par les classes (skill_ranks) : le meilleur parmi ses classes.
func _class_skill_ranks(skill_id: String) -> int:
	var best := 0
	for cls: String in class_levels:
		best = maxi(best, int(DB.classes[cls].get("skill_ranks", {}).get(skill_id, 0)))
	return best


func skill_base_rank(skill_id: String) -> int:
	return Skills.base_rank(Skills.resolve(skill_id), is_caster())


func skill_rank(skill_id: String) -> int:
	var id := Skills.resolve(skill_id)
	var rank := skill_base_rank(id) + _class_skill_ranks(id)
	if id in DB.backgrounds.get(background_id, {}).get("skills", []):
		rank += 1
	return rank + Modifiers.sum(modifiers(), "skill_rank", id)


## Compétence entraînée : rang au-dessus du rang de départ (Expertise, Talent fiable).
func is_trained(skill_id: String) -> bool:
	return skill_rank(skill_id) > skill_base_rank(skill_id)


## Ancien nom : « maîtrisée » = entraînée (conditions skill_proficient).
func is_proficient(skill_id: String) -> bool:
	return is_trained(skill_id)


## Meilleur attribut utilisable pour une compétence (encombrement compris).
func best_skill_ability(skill_id: String) -> String:
	var best := ""
	for ability: String in Skills.abilities_of(Skills.resolve(skill_id)):
		if best == "" or check_mod(ability) > check_mod(best):
			best = ability
	return best


## Bonus d'un test de compétence : modificateur de l'attribut (imposé, ou le meilleur) + rang.
func skill_mod(skill_id: String, ability := "") -> int:
	var used := ability if ability != "" else best_skill_ability(skill_id)
	return check_mod(used) + skill_rank(skill_id)


## Test d'attribut (événements) : modificateur moins l'encombrement pour FOR et DEX.
func check_mod(ability_id: String) -> int:
	return ability_mod(ability_id) - roll_penalty(ability_id)


## Jets de sauvegarde (provisoire, en attendant leur refonte) : un rang par attribut, 1 au départ,
## +1 si la classe le maîtrise, +1 par modificateur "save_proficiency" (don Résistant).
func is_proficient_save(ability_id: String) -> bool:
	return ability_id in DB.classes[class_id].get("saving_throws", []) \
		or Modifiers.grants(modifiers(), "save_proficiency", ability_id)


func save_rank(ability_id: String) -> int:
	var rank := 1 + (1 if ability_id in DB.classes[class_id].get("saving_throws", []) else 0)
	for m: Dictionary in modifiers():
		if m.get("type") == "save_proficiency" and m.get("id") == ability_id:
			rank += 1
	return rank


func save_mod(ability_id: String) -> int:
	return ability_mod(ability_id) + save_rank(ability_id) + Modifiers.sum(modifiers(), "saving_throws") \
		- roll_penalty(ability_id)


## Perception passive : 10 + bonus de Perception (repérer sans lancer de dé).
func passive(skill_id: String) -> int:
	return 10 + skill_mod(skill_id)


# --- Langues --------------------------------------------------------------------------

## Langues connues : celles connues de tous (Commun) et celles choisies (une par rang de Langues).
func known_languages() -> Array[String]:
	var result := Skills.common_languages()
	for id: String in choices.get("skill/languages", []):
		result.append(id)
	return result


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


## Dons que le personnage peut choisir en montant de niveau : prérequis remplis, pas encore possédés,
## et pas un style de combat (ceux-là s'obtiennent par l'aptitude Style de combat).
func available_feats() -> Array[String]:
	var result: Array[String] = []
	for feat_id in Feats.ids():
		if Feats.category_of(feat_id) != "fighting_style" and not has_feat(feat_id) and Feats.meets_prerequisites(feat_id, self):
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


# --- Choix (compétences de classe, ascendance, styles, sous-classe, options de dons) ---

## Tous les choix du personnage : [{"key", "spec", "source"}] (voir Choices).
func choice_specs() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for spec: Dictionary in DB.species[species_id].get("choices", []):
		result.append({"key": "species/" + spec["id"], "spec": spec, "source": DB.species[species_id]["name"]})
	for spec: Dictionary in DB.classes[class_id].get("choices", []):
		result.append({"key": "class/" + spec["id"], "spec": spec, "source": DB.classes[class_id]["name"]})
	for pair in _class_features():
		var feature: Dictionary = pair[1]
		for spec: Dictionary in feature.get("choices", []):
			result.append({"key": _feature_key(pair[0], feature, spec), "spec": spec, "source": feature["name"]})
	for feat_id in feats:
		for spec: Dictionary in DB.feats.get(feat_id, {}).get("choices", []):
			result.append({"key": "feat:%s/%s" % [feat_id, spec["id"]], "spec": spec, "source": Feats.name_of(feat_id)})
	# Langues : une langue à choisir par rang de la compétence Langues.
	var language_count := _languages_rank()
	if language_count > 0:
		result.append({"key": "skill/languages", "source": Skills.name_of("languages"), "spec": {
			"id": "languages", "name": Loc.ui("Langues apprises"), "type": "language", "count": language_count}})
	return result


## Rang de Langues, lu sans passer par les choix (pour éviter une boucle choix -> modificateurs).
func _languages_rank() -> int:
	var rank := skill_base_rank("languages") + _class_skill_ranks("languages")
	if "languages" in DB.backgrounds.get(background_id, {}).get("skills", []):
		rank += 1
	return rank


func _choice_entry(key: String) -> Dictionary:
	for entry in choice_specs():
		if entry["key"] == key:
			return entry
	return {}


## Valeurs encore proposées pour un choix.
func choice_options(key: String) -> Array[String]:
	var entry := _choice_entry(key)
	if entry.is_empty():
		var none: Array[String] = []
		return none
	return Choices.options_for(entry["spec"], self, choices.get(key, []))


## Premier choix en attente (incomplet et avec des options), ou {}.
func pending_choice() -> Dictionary:
	for entry in choice_specs():
		var taken: Array = choices.get(entry["key"], [])
		if taken.size() < int(entry["spec"].get("count", 1)) and not choice_options(entry["key"]).is_empty():
			return entry
	return {}


## Fait un choix ; retourne false si la valeur n'est pas proposée. Un don choisi est acquis.
func choose(key: String, value: String) -> bool:
	var entry := _choice_entry(key)
	if entry.is_empty() or value not in choice_options(key):
		return false
	var taken: Array = choices.get(key, [])
	if taken.size() >= int(entry["spec"].get("count", 1)):
		return false
	taken.append(value)
	choices[key] = taken
	if entry["spec"].get("type") == "feat":
		feats.append(value)
	refresh_max_hp()
	return true


## Complète les choix en attente avec leurs valeurs par défaut (seulement ceux de la création si
## `creation_only`).
func apply_default_choices(creation_only := false) -> void:
	for entry in choice_specs():
		if creation_only and not entry["spec"].get("at_creation", false):
			continue
		for value: String in entry["spec"].get("default", []):
			if choices.get(entry["key"], []).size() < int(entry["spec"].get("count", 1)):
				choose(entry["key"], value)


## Complète tous les choix (valeurs par défaut, puis premières options) : compagnons, personnages générés.
func complete_all_choices() -> void:
	while pending_class_levels > 0:
		assign_class_level(class_id)  # niveaux en attente : dans la classe principale
	apply_default_choices()
	for i in 50:
		var entry := pending_choice()
		if entry.is_empty():
			return
		choose(entry["key"], choice_options(entry["key"])[0])


## Ex. « Tieffelin (Feu infernal) » ; « Guerrier (Champion) ».
func choice_label(key: String) -> String:
	var entry := _choice_entry(key)
	var values: Array = choices.get(key, [])
	if entry.is_empty() or values.is_empty():
		return ""
	return ", ".join(PackedStringArray(values.map(func(v): return Choices.value_name(entry["spec"], v))))


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


## Points de Force qui manquent pour porter un équipement sans malus (0 si aucun). Entraînement aux
## armures lourdes réduit la Force conseillée.
func strength_missing(item_id: String) -> int:
	var required := Equipment.strength_required(item_id)
	if required > 0:
		required -= Modifiers.sum(modifiers(), "armor_strength_reduction")
	return maxi(0, required - ability_score("str"))


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
		ability_score("str") + missing, ability_score("str"), penalty]


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
	var mods := modifiers()
	var ac := Equipment.armor_class(equipment.get("armor", ""), equipment.get("off_hand", ""), ability_mod("dex")) \
		+ Modifiers.sum(mods, "ac")
	var armor := Equipment.def(equipment.get("armor", ""))
	if not armor.is_empty() and armor.get("armor_type") != "clothing":
		ac += Modifiers.sum(mods, "armored_ac")  # style Défense
	return ac


func initiative_bonus() -> int:
	var mods := modifiers()
	var bonus := ability_mod("dex") + Modifiers.sum(mods, "initiative") - roll_penalty("dex")
	if has_modifier("initiative_proficiency"):
		bonus += skill_rank("physique")  # Vigilant
	return bonus


## Attribut utilisé par une action : "weapon" (celui de l'arme), "spell" (celui de la classe) ou un id d'attribut.
func action_ability(ability: String) -> String:
	match ability:
		"weapon":
			return Equipment.attack_ability(weapon_id(), ability_mod("str"), ability_mod("dex"))
		"spell":
			if DB.classes[class_id].has("spellcasting"):
				return DB.classes[class_id]["spellcasting"]
			for cls: String in class_levels:
				if DB.classes[cls].has("spellcasting"):
					return DB.classes[cls]["spellcasting"]
			for m: Dictionary in modifiers():
				if m.get("type") == "spellcasting_ability":
					return m["id"]  # Initié à la magie
			return "int"
	return ability


## Bonus d'attaque : attribut + rang de la compétence. "weapon" : l'arme en main (compétence de son
## type, voir Equipment.skills_for) ; "spell" : Magie ; un attribut : l'arme `weapon` donnée.
func attack_bonus(ability: String, weapon := "") -> int:
	var used := action_ability(ability)
	var rank := 0
	if ability == "spell":
		rank = skill_rank("magic")
	else:
		rank = weapon_rank(weapon if weapon != "" else weapon_id())
	return ability_mod(used) + rank - roll_penalty(used)


## Rang d'attaque avec une arme : le meilleur rang parmi ses compétences (mains nues : mêlée ou Physique).
func weapon_rank(weapon: String) -> int:
	var best := 0
	for skill_id: String in Equipment.skills_for(weapon):
		best = maxi(best, skill_rank(skill_id))
	return best


# --- Aptitudes de classe et ressources -----------------------------------------

## Niveau dans une classe (la classe principale par défaut).
func class_level(cls := "") -> int:
	return int(class_levels.get(cls if cls != "" else class_id, 0))


func has_class(cls: String) -> bool:
	return class_level(cls) > 0


## Ex. « Guerrier 3 / Magicien 1 » (ou « Guerrier » sans multiclassage).
func classes_text() -> String:
	if class_levels.size() <= 1:
		return DB.classes[class_id]["name"]
	var parts := PackedStringArray()
	for cls: String in class_levels:
		parts.append("%s %d" % [DB.classes[cls]["name"], int(class_levels[cls])])
	return " / ".join(parts)


## Clé d'un choix d'aptitude : « feature:id/choix » pour la classe principale (compatibilité),
## « feature:classe:id/choix » pour les autres.
func _feature_key(cls: String, feature: Dictionary, spec: Dictionary) -> String:
	if cls == class_id:
		return "feature:%s/%s" % [feature["id"], spec["id"]]
	return "feature:%s:%s/%s" % [cls, feature["id"], spec["id"]]


## Aptitudes acquises, par classe : [[classe, aptitude], …], sous-classes comprises.
func _class_features() -> Array:
	var result: Array = []
	for cls: String in class_levels:
		var lvl := int(class_levels[cls])
		for feature: Dictionary in ClassFeatures.up_to(cls, lvl):
			result.append([cls, feature])
			for spec: Dictionary in feature.get("choices", []):
				for sub: Dictionary in Choices.features_from(spec, choices.get(_feature_key(cls, feature, spec), [])):
					if int(sub["level"]) <= lvl:
						result.append([cls, sub])
	return result


## Aptitudes de classe acquises (classes.json › features), y compris celles des sous-classes choisies.
func features() -> Array:
	return _class_features().map(func(pair): return pair[1])


## Monte d'un niveau dans une classe (multiclassage libre, sans prérequis). Les améliorations (attribut +
## don) se comptent par classe. Retourne les lignes à annoncer.
func assign_class_level(cls: String) -> Array[String]:
	var lines: Array[String] = []
	if pending_class_levels <= 0 or not DB.classes.has(cls):
		return lines
	var previous_max := max_resources()
	pending_class_levels -= 1
	class_levels[cls] = class_level(cls) + 1
	var lvl := class_level(cls)
	lines.append(Loc.ui("%s devient %s de niveau %d.") % [name, String(DB.classes[cls]["name"]).to_lower(), lvl])
	lines.append_array(ClassFeatures.announce(self, lvl, cls))
	if Progression.is_advancement_level(lvl):
		pending_ability_points += Progression.ability_points_per_advancement()
		pending_feats += Progression.feats_per_advancement()
		lines.append(Loc.ui("%s : %s.") % [name, Progression.advancement_text()])
	_sync_resources(previous_max)
	refresh_max_hp()
	return lines


## Emplacements de sort : ceux de sa classe de lanceur ; avec plusieurs, niveau de lanceur cumulé
## (lanceurs complets + demi-lanceurs / 2) sur la table des lanceurs complets, comme dans D&D.
func spell_slots() -> Dictionary:
	var casters: Array = class_levels.keys().filter(func(cls): return DB.classes[cls].has("spell_slots"))
	if casters.is_empty():
		return {}
	if casters.size() == 1:
		return Spellcasting.slots(DB.classes[casters[0]]["spell_slots"], class_level(casters[0]))
	var caster_level := 0.0
	for cls: String in casters:
		caster_level += class_level(cls) * (1.0 if DB.classes[cls]["spell_slots"] == "full" else 0.5)
	return Spellcasting.slots("full", int(caster_level))


## Ressources maximales : celles de l'espèce, de la classe, des aptitudes et des dons, plus les
## emplacements de sort.
func max_resources() -> Dictionary:
	var result: Dictionary = {}
	for cls: String in class_levels:
		var class_resources: Dictionary = DB.classes[cls].get("resources", {})
		for id: String in class_resources:
			result[id] = int(result.get(id, 0)) + int(class_resources[id])
	for feat_id in feats:
		var feat_resources: Dictionary = DB.feats.get(feat_id, {}).get("resources", {})
		for id: String in feat_resources:
			result[id] = int(result.get(id, 0)) + int(feat_resources[id])
	var species_resources: Dictionary = DB.species[species_id].get("resources", {})
	for id: String in species_resources:
		result[id] = int(result.get(id, 0)) + int(species_resources[id])
	for feature: Dictionary in features():
		var granted: Dictionary = feature.get("resources", {})
		for id: String in granted:
			result[id] = int(result.get(id, 0)) + int(granted[id])
	result.merge(spell_slots())
	for id: String in result:
		result[id] = int(result[id])
	return result


func max_resource(resource_id: String) -> int:
	return int(max_resources().get(resource_id, 0))


## Actions de combat : celles de la classe, des aptitudes acquises, des dons et des choix
## (ids de actions.json, ou « action|ressource » pour un sort lancé grâce à un don).
func combat_actions() -> Array:
	var result: Array = DB.classes[class_id].get("actions", []).duplicate()
	var granted: Array = []
	for cls: String in class_levels:
		granted.append_array(DB.classes[cls].get("actions", []))
	for feature: Dictionary in features():
		granted.append_array(feature.get("actions", []))
	for feat_id in feats:
		granted.append_array(DB.feats.get(feat_id, {}).get("actions", []))
	for entry: Dictionary in choice_specs():
		granted.append_array(Choices.actions_from(entry["spec"], choices.get(entry["key"], [])))
	granted.append_array(DB.rules.get("common_actions", []))  # Se cacher, Intimider, Premiers soins
	for action_id: String in granted:
		if action_id not in result and action_id.split("|")[0] not in result:
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

## Taille, déterminée par l'espèce : échelle de −4 (insecte) à 5+ (colosse), 0 pour un humain.
func size() -> int:
	return int(DB.species[species_id].get("size", 0))


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

## PV max : Constitution × size_base ^ taille (rules.json › hit_points), au moins 1, + les PV des
## modificateurs (don Robuste : par niveau). Ni la classe ni le niveau ne les font monter : un
## personnage reste fragile.
func compute_max_hp() -> int:
	var base := float(DB.rules.get("hit_points", {}).get("size_base", 1.4142))
	var hp := maxi(1, roundi(ability_score("con") * pow(base, size())))
	return hp + Modifiers.sum(modifiers(), "hp_per_level") * level


## Recalcule les PV max (après un changement de niveau, de Constitution ou de don).
## Les PV actuels suivent la même variation, sans sortir de [0, PV max].
func refresh_max_hp() -> void:
	var new_max := compute_max_hp()
	hp = clampi(hp + new_max - max_hp, 0, new_max)
	max_hp = new_max


## Ajoute de l'XP et retourne la liste des niveaux atteints. Chaque niveau gagné attend le choix de sa
## classe (assign_class_level, au hub), qui apporte aptitudes et améliorations.
func add_xp(amount: int) -> Array[int]:
	xp += amount
	var reached: Array[int] = []
	while level < Progression.max_level() and xp >= Progression.xp_for(level + 1):
		level += 1
		pending_class_levels += 1
		reached.append(level)
	if not reached.is_empty():
		refresh_max_hp()
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
		"class_levels": class_levels, "pending_class_levels": pending_class_levels,
		"gender": gender, "abilities": abilities, "feats": feats, "choices": choices, "pending_feats": pending_feats,
		"pending_ability_points": pending_ability_points, "equipment": equipment, "defenses": defenses.to_dict(),
		"level": level, "xp": xp, "hp": hp, "max_hp": max_hp, "gold": gold, "inventory": inventory,
		"start_age": start_age, "age_days": age_days, "art_seed": art_seed, "template_id": template_id, "npc_id": npc_id, "auto_combat": auto_combat,
		"resources": resources,
	}


## Recrée un personnage sauvegardé. Le JSON ne distingue pas entiers et décimaux : on reconvertit.
static func from_dict(data: Dictionary) -> Character:
	var c := Character.new()
	c.name = data.get("name", "")
	c.species_id = data.get("species_id", "")
	c.class_id = data.get("class_id", "")
	c.class_levels = Character._int_dict(data.get("class_levels", {}))
	c.pending_class_levels = int(data.get("pending_class_levels", 0))
	c.background_id = data.get("background_id", "")
	c.gender = data.get("gender", "nonbinary")
	c.abilities = _int_dict(data.get("abilities", {}))
	c.feats.assign(data.get("feats", []))
	c.choices = data.get("choices", {})
	# Anciennes sauvegardes : compétences D&D fusionnées dans les nouvelles.
	for key: String in c.choices.keys():
		c.choices[key] = c.choices[key].map(func(v): return Skills.resolve(v) if Skills.ALIASES.has(v) else v)
	c.pending_feats = int(data.get("pending_feats", 0))
	c.pending_ability_points = int(data.get("pending_ability_points", 0))
	c.equipment = data.get("equipment", {})
	# Anciennes sauvegardes : amulet -> neck, ring -> ring_1.
	for old_slot: String in {"amulet": "neck", "ring": "ring_1"}:
		if c.equipment.has(old_slot):
			c.equipment[{"amulet": "neck", "ring": "ring_1"}[old_slot]] = c.equipment[old_slot]
			c.equipment.erase(old_slot)
	c.defenses = Defenses.from_dict(data.get("defenses", {}))
	c.level = int(data.get("level", 1))
	if c.class_levels.is_empty() and c.class_id != "":
		c.class_levels = {c.class_id: c.level}  # anciennes sauvegardes
	c.xp = int(data.get("xp", 0))
	c.hp = int(data.get("hp", 1))
	c.max_hp = int(data.get("max_hp", 1))
	c.gold = int(data.get("gold", 0))
	c.inventory = _int_dict(data.get("inventory", {}))
	c.start_age = int(data.get("start_age", 18))
	c.age_days = int(data.get("age_days", 0))
	c.art_seed = int(data.get("art_seed", 0))
	c.template_id = data.get("template_id", "")
	c.npc_id = data.get("npc_id", "")
	c.auto_combat = data.get("auto_combat", false)
	c.resources = _int_dict(data.get("resources", {}))
	c.apply_default_choices(true)  # anciennes sauvegardes : compétences de classe par défaut
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
