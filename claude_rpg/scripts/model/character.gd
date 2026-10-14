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
var pending_skill_points := 0  # points de compétence à répartir (gagnés en montant de niveau)
var skill_points: Dictionary = {}  # id de compétence -> rangs achetés avec des points de compétence
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
var resources: Dictionary = {}  # ressources restantes (spell_slot, indomitable…), rechargées par un repos long
var equipped_spells: Array[String] = []  # sorts équipés (utilisables en combat), parmi les sorts connus
var seen_spells: Array[String] = []  # sorts déjà proposés (un sort appris est équipé d'office s'il reste de la place)


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
		c.abilities[ability] = int(scores.get(ability, 4))
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
	c.sync_spells()
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
	c.sync_spells()
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
	return int(abilities.get(ability_id, 4)) + Modifiers.sum(modifiers(), "ability", ability_id)


# --- Compétences : rangs et réserves de dés ---------------------------------------------
# Attributs : de 3 à 8 pour un humain (4 pour une personne ordinaire) ; la valeur sert de seuil.
# Rang = rang de départ (1, 2 si instinctive ; Magie : 0, ou 2 pour un lanceur de sorts)
#        + 1 par passé qui la donne + rangs de la classe (skill_ranks) + modificateurs "skill_rank"
#        (choix de classe, dons, Expertise, équipement…).
# Test = [rang] d10 contre un seuil égal à l'attribut (voir Dice).

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
	var rank := skill_base_rank(id) + _class_skill_ranks(id) + int(skill_points.get(id, 0))
	if id in DB.backgrounds.get(background_id, {}).get("skills", []):
		rank += 1
	return rank + Modifiers.sum(modifiers(), "skill_rank", id)


## Détail du rang d'une compétence, pour l'affichage : [[source, rangs], ...].
func skill_rank_parts(skill_id: String) -> Array:
	var id := Skills.resolve(skill_id)
	var parts: Array = [[Loc.ui("départ"), skill_base_rank(id)]]
	if _class_skill_ranks(id) > 0:
		parts.append([Loc.ui("classe"), _class_skill_ranks(id)])
	if id in DB.backgrounds.get(background_id, {}).get("skills", []):
		parts.append([Loc.ui("passé"), 1])
	if int(skill_points.get(id, 0)) > 0:
		parts.append([Loc.ui("points de compétence"), int(skill_points[id])])
	var bonus := Modifiers.sum(modifiers(), "skill_rank", id)
	if bonus != 0:
		parts.append([Loc.ui("choix, dons, aptitudes, objets"), bonus])
	return parts


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
		if best == "" or _pool_value(ability) > _pool_value(best):
			best = ability
	return best


## Valeur d'un attribut pour départager deux attributs : le seuil, moins un point par dé de malus.
func _pool_value(ability_id: String) -> int:
	return ability_score(ability_id) - roll_penalty(ability_id)


## Réserve d'un test de compétence : {"count": rang + bonus − encombrement, "threshold": attribut}.
func skill_pool(skill_id: String, ability := "", bonus := 0) -> Dictionary:
	var used := ability if ability != "" else best_skill_ability(skill_id)
	return {"count": skill_rank(skill_id) + bonus - roll_penalty(used), "threshold": ability_score(used),
		"ability": used}


## Test d'attribut seul (sans compétence) : rules.json › dice › attribute_dice dés.
func ability_pool(ability_id: String, bonus := 0) -> Dictionary:
	return {"count": int(Dice.setting("attribute_dice", 2)) + bonus - roll_penalty(ability_id),
		"threshold": ability_score(ability_id), "ability": ability_id}


## Résistance maîtrisée (classe de départ, ou Résistant) : un dé de plus pour résister.
func is_proficient_save(ability_id: String) -> bool:
	return ability_id in DB.classes[class_id].get("resist_proficiencies", []) \
		or Modifiers.grants(modifiers(), "resist_proficiency", ability_id)


## Résister à un effet (poison, sort, peur…) : la compétence liée à l'attribut (rules.json › dice ›
## resist_skills : Physique pour FOR, DEX et CON, Perspicacité pour SAG…), contre un seuil égal à
## l'attribut ; +1 dé par maîtrise (classe de départ, Résistant) et par modificateur "resist_dice".
func resist_pool(ability_id: String, bonus := 0) -> Dictionary:
	var skill: String = Dice.setting("resist_skills", {}).get(ability_id, "physique")
	var dice := skill_rank(skill) + bonus + Modifiers.sum(modifiers(), "resist_dice")
	if ability_id in DB.classes[class_id].get("resist_proficiencies", []):
		dice += 1
	for m: Dictionary in modifiers():
		if m.get("type") == "resist_proficiency" and m.get("id") == ability_id:
			dice += 1
	return {"count": dice - roll_penalty(ability_id), "threshold": ability_score(ability_id), "ability": ability_id}


## Valeur passive (repérer sans lancer de dé) : nombre moyen de succès de la réserve, arrondi.
func passive(skill_id: String) -> int:
	var pool := skill_pool(skill_id)
	return roundi(Dice.expected(int(pool["count"]), int(pool["threshold"])))


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
	return can_increase_ability() or can_choose_feat() or can_spend_skill_point()


# --- Points de compétence (rules.json › skill_points) ----------------------------

static func _skill_rules() -> Dictionary:
	return DB.rules.get("skill_points", {})


## Rang le plus haut qu'on peut atteindre avec des points de compétence à ce niveau.
func max_trained_rank() -> int:
	var rules := _skill_rules()
	return int(rules.get("max_rank_base", 3)) + floori(level * float(rules.get("max_rank_per_level", 0.5)))


func can_raise_skill(skill_id: String) -> bool:
	return pending_skill_points > 0 and skill_rank(skill_id) < max_trained_rank()


## Reste-t-il un point de compétence à placer (et une compétence sous le plafond) ?
func can_spend_skill_point() -> bool:
	return pending_skill_points > 0 and Skills.ids().any(func(id): return can_raise_skill(id))


## Dépense un point de compétence : +1 rang.
func spend_skill_point(skill_id: String) -> bool:
	if not can_raise_skill(skill_id):
		return false
	pending_skill_points -= 1
	skill_points[skill_id] = int(skill_points.get(skill_id, 0)) + 1
	return true


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
	var rank := skill_base_rank("languages") + _class_skill_ranks("languages") + int(skill_points.get("languages", 0))
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
	# Points de compétence : dans les compétences déjà les plus fortes (spécialisation).
	for guard in 40:
		if not can_spend_skill_point():
			break
		var best := ""
		for id in Skills.ids():
			if can_raise_skill(id) and (best == "" or skill_rank(id) > skill_rank(best)):
				best = id
		spend_skill_point(best)
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
	return int(abilities.get(ability_id, 4)) < Progression.max_ability_score()


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
	return Loc.ui("Force %d conseillée (vous avez %d) : −%d dé(s) aux jets de FOR et DEX") % [
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
func weapon_damage() -> Dictionary:
	return Equipment.weapon_damage(weapon_id(), not equipment.has("off_hand"))


func weapon_damage_type() -> String:
	return Equipment.damage_type_of(weapon_id())


## Esquive naturelle : Dextérité ÷ 3 (arrondie à l'inférieur), au moins 1, + modificateurs. C'est la
## difficulté des attaques de mêlée contre le personnage.
func natural_dodge() -> int:
	var divisor := int(DB.rules.get("combat", {}).get("dodge_divisor", 3))
	@warning_ignore("integer_division")
	return maxi(1, ability_score("dex") / divisor) + Modifiers.sum(modifiers(), "natural_dodge")


## Armure : celle de l'armure portée + bouclier + modificateurs ("armor" ; style Défense : "armored",
## avec une vraie armure). Elle baisse le seuil des dégâts subis.
func armor() -> int:
	var mods := modifiers()
	var total := Equipment.armor_value(equipment.get("armor", "")) + Equipment.armor_value(equipment.get("off_hand", "")) \
		+ Modifiers.sum(mods, "armor")
	var worn := Equipment.def(equipment.get("armor", ""))
	if not worn.is_empty() and worn.get("armor_type") != "clothing":
		total += Modifiers.sum(mods, "armored")  # style Défense
	return maxi(0, total)


## Détail de l'Armure, pour l'affichage : [[source, points], ...].
func armor_parts() -> Array:
	var parts: Array = []
	for slot in ["armor", "off_hand"]:
		var item_id: String = equipment.get(slot, "")
		if Equipment.armor_value(item_id) > 0:
			parts.append([Equipment.name_of(item_id), Equipment.armor_value(item_id)])
	var mods := modifiers()
	if Modifiers.sum(mods, "armor") != 0:
		parts.append([Loc.ui("objets et dons"), Modifiers.sum(mods, "armor")])
	var worn := Equipment.def(equipment.get("armor", ""))
	if not worn.is_empty() and worn.get("armor_type") != "clothing" and Modifiers.sum(mods, "armored") != 0:
		parts.append([Loc.ui("style Défense"), Modifiers.sum(mods, "armored")])
	return parts


## Initiative de base : Dextérité + Intelligence (+ rang de Physique avec Vigilant, + modificateurs),
## moins l'encombrement. On y ajoute 1d10 en début de combat.
func initiative_base() -> int:
	var base := ability_score("dex") + ability_score("int") + Modifiers.sum(modifiers(), "initiative") - roll_penalty("dex")
	if has_modifier("initiative_rank"):
		base += skill_rank("physique")  # Vigilant
	return base


## Attribut utilisé par une action : "weapon" (celui de l'arme), "spell" (celui de la classe) ou un id d'attribut.
func action_ability(ability: String) -> String:
	match ability:
		"weapon":
			return Equipment.attack_ability(weapon_id(), ability_score("str") - roll_penalty("str"),
				ability_score("dex") - roll_penalty("dex"))
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


## Réserve d'attaque : [rang de la compétence] d10 contre l'attribut. "weapon" : l'arme en main
## (compétence de son type, voir Equipment.skills_for) ; "spell" : Magie ; un attribut : l'arme
## `weapon` donnée. Retourne {"count", "threshold", "ability"}.
func attack_pool(ability: String, weapon := "", bonus := 0) -> Dictionary:
	var used := action_ability(ability)
	var rank := 0
	if ability == "spell":
		rank = skill_rank("magic")
	else:
		rank = weapon_rank(weapon if weapon != "" else weapon_id())
	return {"count": rank + bonus - roll_penalty(used), "threshold": ability_score(used), "ability": used}


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
	sync_spells()
	return lines


## Progression de lanceur : [progression, niveau]. Avec plusieurs classes de lanceur, niveau cumulé
## (lanceurs complets + demi-lanceurs / 2) sur la table des lanceurs complets, comme dans D&D.
func _caster_progression() -> Array:
	var casters: Array = class_levels.keys().filter(func(cls): return DB.classes[cls].has("spell_slots"))
	if casters.is_empty():
		return ["", 0]
	if casters.size() == 1:
		return [DB.classes[casters[0]]["spell_slots"], class_level(casters[0])]
	var caster_level := 0.0
	for cls: String in casters:
		caster_level += class_level(cls) * (1.0 if DB.classes[cls]["spell_slots"] == "full" else 0.5)
	return ["full", int(caster_level)]


## Emplacements de sort : {"spell_slot": N} (voir Spellcasting).
func spell_slots() -> Dictionary:
	var progression := _caster_progression()
	return Spellcasting.slots(progression[0], progression[1])


## Niveau de sort le plus haut que le personnage peut lancer avec ses emplacements.
func max_spell_level() -> int:
	var progression := _caster_progression()
	return Spellcasting.max_level(progression[0], progression[1])


# --- Sorts connus et équipés -------------------------------------------------------

## Sorts connus gérés par l'équipement (ceux des classes et aptitudes ; pas ceux d'un don comme Initié à
## la magie, toujours disponibles).
func known_spells() -> Array[String]:
	var result: Array[String] = []
	for action_id: String in _all_combat_actions():
		if "|" not in action_id and Spellcasting.is_spell(Actions.def(action_id)):
			result.append(action_id)
	return result


func max_equipped_spells() -> int:
	return Spellcasting.max_equipped(skill_rank("magic"))


## Sort prêt en combat : un tour de magie, ou un sort équipé.
func is_spell_equipped(action_id: String) -> bool:
	return action_id in equipped_spells or Spellcasting.is_cantrip(Actions.def(action_id))


## Équipe un sort connu ; false s'il n'y a plus de place (ou pour un tour de magie, toujours prêt).
func equip_spell(action_id: String) -> bool:
	if action_id in equipped_spells or action_id not in known_spells() or Spellcasting.is_cantrip(Actions.def(action_id)) \
			or equipped_spells.size() >= max_equipped_spells():
		return false
	equipped_spells.append(action_id)
	return true


func unequip_spell(action_id: String) -> bool:
	if action_id not in equipped_spells:
		return false
	equipped_spells.erase(action_id)
	return true


## Met les sorts équipés à jour : oublie les sorts inconnus, et équipe d'office les sorts nouvellement
## appris s'il reste de la place (les tours de magie, toujours prêts, n'y figurent pas).
func sync_spells() -> void:
	var known := known_spells()
	equipped_spells.assign(equipped_spells.filter(func(id): return id in known and not Spellcasting.is_cantrip(Actions.def(id))))
	for action_id in known:
		if action_id in seen_spells or Spellcasting.is_cantrip(Actions.def(action_id)):
			continue
		seen_spells.append(action_id)
		if equipped_spells.size() < max_equipped_spells():
			equipped_spells.append(action_id)


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
	var known := known_spells()
	return _all_combat_actions().filter(func(id): return id not in known or is_spell_equipped(id))


## Toutes les actions, sorts non équipés compris.
func _all_combat_actions() -> Array:
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

## PV d'une Constitution et d'une taille : (taille + 2) × CON + 7, au moins 1 (rules.json › hit_points).
## Humain moyen : 15 ; créature immense et endurante (taille 4, CON 8) : 55. Sert aussi aux créatures.
static func hp_from(con: int, size: int) -> int:
	var rules: Dictionary = DB.rules.get("hit_points", {})
	return maxi(1, (size + int(rules.get("size_offset", 2))) * con + int(rules.get("base", 7)))


## PV max : selon la Constitution et la taille (hp_from), + les PV des
## modificateurs (don Robuste : par niveau). Ni la classe ni le niveau ne les font monter : un
## personnage reste fragile.
func compute_max_hp() -> int:
	var hp := hp_from(ability_score("con"), size())
	var mods := modifiers()
	return hp + Modifiers.sum(mods, "max_hp") + Modifiers.sum(mods, "hp_per_level") * level


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
		pending_skill_points += int(_skill_rules().get("by_level", {}).get(str(level), 0))
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
		"pending_skill_points": pending_skill_points, "skill_points": skill_points,
		"level": level, "xp": xp, "hp": hp, "max_hp": max_hp, "gold": gold, "inventory": inventory,
		"start_age": start_age, "age_days": age_days, "art_seed": art_seed, "template_id": template_id, "npc_id": npc_id, "auto_combat": auto_combat,
		"resources": resources, "equipped_spells": equipped_spells, "seen_spells": seen_spells,
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
	c.pending_skill_points = int(data.get("pending_skill_points", 0))
	c.skill_points = _int_dict(data.get("skill_points", {}))
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
	# Anciennes sauvegardes : emplacements par niveau (spell_slot_2…) -> une seule réserve pondérée.
	var old_slots := 0
	for key: String in c.resources.keys():
		if key.begins_with("spell_slot_"):
			old_slots += int(c.resources[key]) * int(key.trim_prefix("spell_slot_"))
			c.resources.erase(key)
	if old_slots > 0:
		c.resources[Spellcasting.SLOT_KEY] = old_slots
	c.equipped_spells.assign(data.get("equipped_spells", []))
	c.seen_spells.assign(data.get("seen_spells", []))
	c.apply_default_choices(true)  # anciennes sauvegardes : compétences de classe par défaut
	# Anciennes sauvegardes (ex. "spell_slot" unique) : on ne garde que les ressources connues.
	var max_now := c.max_resources()
	for id: String in max_now:
		if not c.resources.has(id):
			c.resources[id] = max_now[id]
	for id: String in c.resources.keys():
		if not max_now.has(id):
			c.resources.erase(id)
	c.sync_spells()
	return c


static func _int_dict(data: Variant) -> Dictionary:
	var result := {}
	if typeof(data) == TYPE_DICTIONARY:
		for key in data:
			result[key] = int(data[key])
	return result
