class_name DataValidator
extends RefCounted
## Vérifie la cohérence des données JSON : champs obligatoires, types connus, références
## (objets, compétences, événements...). Les erreurs sont ajoutées à db.errors.


static func validate(db: Node) -> void:
	var errors: Array[String] = db.errors
	_validate_rules(db, errors)
	_validate_rule_tables(db, errors)
	_validate_species(db, errors)
	_validate_classes(db, errors)
	_validate_backgrounds(db, errors)
	_validate_combat_data(db, errors)
	_validate_items(db, errors)
	_validate_damage_types(db, errors)
	_validate_economy(db, errors)
	_validate_social(db, errors)
	_validate_quests(db, errors)
	for id: String in db.events:
		_validate_event(db, db.events[id], errors)


static func _validate_rules(db: Node, errors: Array[String]) -> void:
	for key in ["standard_array", "point_buy", "genders", "sizes", "time_slots", "life_stages", "days_per_year", "dice"]:
		if not db.rules.has(key):
			errors.append("rules.json : champ « %s » manquant" % key)
	if db.rules.get("standard_array", []).size() != db.abilities.size():
		errors.append("rules.json : standard_array doit avoir une valeur par attribut")
	var xp_table: Array = db.rules.get("xp_by_level", [])
	for level in db.rules.get("advancement_levels", []):
		if int(level) < 2 or int(level) > xp_table.size():
			errors.append("rules.json : niveau d'amélioration hors limites : %s" % level)
	var cp: Dictionary = db.rules.get("creator_points", {})
	for upgrade: Dictionary in cp.get("upgrades", []):
		var ctx := "rules.json › creator_points › %s" % upgrade.get("id", "?")
		if upgrade.get("type") not in ["point_buy", "level", "gold"]:
			errors.append(ctx + " : type inconnu « %s » (point_buy, level, gold)" % upgrade.get("type"))
		var cost: Variant = upgrade.get("cost", 0)
		if cost is Array and cost.size() < int(upgrade.get("max", 1)):
			errors.append(ctx + " : il faut un coût par rang (max = %d)" % int(upgrade.get("max", 1)))
	var point_buy: Dictionary = db.rules.get("point_buy", {})
	var costs: Dictionary = point_buy.get("costs", {})
	for value in range(int(point_buy.get("min", 8)), int(point_buy.get("max", 15)) + 1):
		if not costs.has(str(value)):
			errors.append("rules.json : point_buy.costs ne donne pas le coût de %d" % value)
	if point_buy.get("bonuses", []).size() > db.abilities.size():
		errors.append("rules.json : trop de bonus d'attributs dans point_buy.bonuses")


## Attributs, compétences, dons, équipement, types de dégâts, états.
static func _validate_rule_tables(db: Node, errors: Array[String]) -> void:
	for table in ["abilities", "skills", "damage_types", "status_effects", "equipment"]:
		if db.get(table).is_empty():
			errors.append("%s.json : aucune entrée" % table)
	for ability: Dictionary in db.abilities.values():
		if not ability.has("name") or not ability.has("short"):
			errors.append("abilities.json › %s : name et short obligatoires" % ability["id"])
	for skill: Dictionary in db.skills.values():
		var abilities: Variant = skill.get("abilities", [])
		if typeof(abilities) != TYPE_ARRAY or abilities.is_empty():
			errors.append("skills.json › %s : « abilities » doit être une liste d'attributs non vide" % skill["id"])
		else:
			for ability_id in abilities:
				_expect_ref(db.abilities, ability_id, "attribut", "skills.json › %s" % skill["id"], errors)
		if skill.get("category") not in Skills.CATEGORY_NAMES:
			errors.append("skills.json › %s : catégorie inconnue « %s » (%s)" % [skill["id"], skill.get("category"),
				Skills.CATEGORY_NAMES.keys()])
	for language: Dictionary in db.rules.get("languages", []):
		if not language.has("id") or not language.has("name"):
			errors.append("rules.json › languages : chaque langue a un id et un name")

	for feat: Dictionary in db.feats.values():
		var ctx := "feats.json › %s" % feat["id"]
		if feat.get("category", "general") not in ["origin", "general", "fighting_style"]:
			errors.append(ctx + " : catégorie inconnue « %s » (origin, general ou fighting_style)" % feat.get("category"))
		_validate_modifiers(db, feat.get("modifiers", []), ctx, errors, true)
		_validate_conditions(db, feat.get("prerequisites", []), ctx + " › prerequisites", errors)
		_validate_choices(db, feat.get("choices", []), ctx, errors)
		for action_id in feat.get("actions", []):
			_expect_ref(db.actions, action_id, "action", ctx, errors)

	for item: Dictionary in db.equipment.values():
		var ctx := "equipment.json › %s" % item["id"]
		match item.get("category"):
			"weapon":
				_validate_pool_spec(db, item.get("damage"), ctx + " › damage", errors)
				_expect_ref(db.damage_types, item.get("damage_type"), "type de dégâts", ctx, errors)
				for prop in item.get("properties", []):
					if prop not in Equipment.PROPERTY_NAMES:
						errors.append(ctx + " : propriété inconnue « %s »" % prop)
				_validate_bonus_damage(db, item.get("bonus_damage", []), ctx, errors)
			"armor":
				if item.get("armor_type") not in Equipment.ARMOR_TYPE_NAMES:
					errors.append(ctx + " : armor_type doit valoir clothing, light, medium ou heavy")
				elif not item.has("strength") and not db.rules.get("armor_strength", {}).has(item.get("armor_type")):
					errors.append(ctx + " : aucune Force requise définie pour « %s » (rules.json › armor_strength)" % item.get("armor_type"))
				if not item.has("armor"):
					errors.append(ctx + " : armor (points d'Armure) manquant")
			"shield":
				if not item.has("armor"):
					errors.append(ctx + " : armor (points d'Armure) manquant")
			"accessory":
				pass
			_:
				errors.append(ctx + " : catégorie inconnue « %s » (weapon, armor, shield, accessory)" % item.get("category"))
		_validate_modifiers(db, item.get("modifiers", []), ctx, errors, true)
	if not db.equipment.has(Equipment.UNARMED):
		errors.append("equipment.json : l'entrée « %s » (mains nues) est obligatoire" % Equipment.UNARMED)


## Modificateurs (dons, espèces, équipement). `abilities_allowed` = false pour les espèces.
static func _validate_modifiers(db: Node, mods: Variant, ctx: String, errors: Array[String], abilities_allowed: bool) -> void:
	if typeof(mods) != TYPE_ARRAY:
		errors.append(ctx + " : « modifiers » doit être une liste")
		return
	for m: Variant in mods:
		if typeof(m) != TYPE_DICTIONARY or not Modifiers.SCHEMA.has(m.get("type", "")):
			errors.append(ctx + " : modificateur invalide %s (types : %s)" % [str(m), Modifiers.SCHEMA.keys()])
			continue
		var missing: Array = Modifiers.SCHEMA[m["type"]].filter(func(k): return not m.has(k))
		if not missing.is_empty():
			errors.append(ctx + " : modificateur « %s » sans %s" % [m["type"], missing])
			continue
		match m["type"]:
			"ability":
				if not abilities_allowed:
					errors.append(ctx + " : une espèce ne doit pas modifier les attributs")
				_expect_ref(db.abilities, m["id"], "attribut", ctx, errors)
			"skill_rank":
				_expect_ref(db.skills, m["id"], "compétence", ctx, errors)
			"resist_proficiency":
				_expect_ref(db.abilities, m["id"], "attribut", ctx, errors)
			"resistance", "immunity", "vulnerability":
				_expect_ref(db.damage_types, m["damage_type"], "type de dégâts", ctx, errors)
			"status_immunity":
				_expect_ref(db.status_effects, m["status"], "état", ctx, errors)


## Défenses au format JSON ({"resistances": [...], ...}).
static func _validate_defenses(db: Node, data: Variant, ctx: String, errors: Array[String]) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		errors.append(ctx + " : « defenses » doit être un objet")
		return
	for key: String in data:
		var kind: Variant = Defenses.JSON_KEYS.find_key(key)
		if kind == null:
			errors.append(ctx + " : défense inconnue « %s » (attendu %s)" % [key, Defenses.JSON_KEYS.values()])
			continue
		for id in data[key]:
			if kind == Defenses.STATUS_IMMUNITY:
				_expect_ref(db.status_effects, id, "état", ctx, errors)
			else:
				_expect_ref(db.damage_types, id, "type de dégâts", ctx, errors)


static func _validate_species(db: Node, errors: Array[String]) -> void:
	var stage_ids := _ids(db.rules.get("life_stages", []))
	var size_ids: Array = db.rules.get("sizes", []).map(func(s): return int(s.get("value", 0)))
	for species: Dictionary in db.species.values():
		var ctx := "species.json › %s" % species["id"]
		if species.get("names", []).is_empty():
			errors.append(ctx + " : liste de noms vide")
		if typeof(species.get("size")) not in [TYPE_INT, TYPE_FLOAT] or int(species.get("size")) not in size_ids:
			errors.append(ctx + " : taille inconnue « %s » (voir rules.json › sizes)" % species.get("size"))
		if not species.has("aging_age"):
			errors.append(ctx + " : aging_age (âge à partir duquel on vieillit) manquant")
		for resource_id: String in species.get("resources", {}):
			if typeof(species["resources"][resource_id]) not in [TYPE_INT, TYPE_FLOAT]:
				errors.append(ctx + " : la ressource « %s » doit être un nombre" % resource_id)
		if species.has("ability_bonus"):
			errors.append(ctx + " : une espèce ne doit pas modifier les attributs (ability_bonus)")
		_validate_modifiers(db, species.get("modifiers", []), ctx, errors, false)
		_validate_choices(db, species.get("choices", []), ctx, errors)
		var majority := int(db.rules.get("majority_age", 18))
		if int(species.get("start_age", 18)) < majority or int(species.get("age_stages", {}).get("adult", majority)) < majority:
			errors.append(ctx + " : start_age et l'étape adult doivent valoir au moins %d (rules.json › majority_age)" % majority)
		for stage: String in species.get("age_stages", {}):
			if stage not in stage_ids:
				errors.append(ctx + " : étape de vie inconnue « %s »" % stage)


static func _validate_classes(db: Node, errors: Array[String]) -> void:
	var ability_ids: Array = db.abilities.keys()
	for cls: Dictionary in db.classes.values():
		var ctx := "classes.json › %s" % cls["id"]
		var priority: Array = cls.get("ability_priority", [])
		if priority.size() != ability_ids.size() or ability_ids.any(func(a): return a not in priority):
			errors.append(ctx + " : ability_priority doit contenir chaque attribut une fois")
		_validate_skills_and_items(db, cls, ctx, errors)
		var equipment: Dictionary = cls.get("equipment", {})
		for slot: String in equipment:
			if slot not in Equipment.SLOTS:
				errors.append(ctx + " : emplacement inconnu « %s » (attendu %s)" % [slot, Equipment.SLOTS])
			elif not db.equipment.has(equipment[slot]):
				errors.append(ctx + " : équipement inconnu « %s »" % equipment[slot])
			elif slot not in Equipment.slots_for(equipment[slot]):
				errors.append(ctx + " : « %s » ne va pas dans l'emplacement « %s »" % [equipment[slot], slot])
		_validate_choices(db, cls.get("choices", []), ctx, errors)
		for skill_id: String in cls.get("skill_ranks", {}):
			_expect_ref(db.skills, skill_id, "compétence (skill_ranks)", ctx, errors)
		for ability_id in cls.get("resist_proficiencies", []):
			_expect_ref(db.abilities, ability_id, "attribut (resist_proficiencies)", ctx, errors)
		if cls.has("spell_slots") and cls["spell_slots"] not in Spellcasting.progressions():
			errors.append(ctx + " : spell_slots « %s » inconnu (rules.json › spell_slots : %s)" % [
				cls["spell_slots"], Spellcasting.progressions()])
		var feature_ids := {}
		for feature: Dictionary in cls.get("features", []):
			var fctx := "%s › aptitude %s" % [ctx, feature.get("id", "?")]
			for key in ["level", "id", "name", "description"]:
				if not feature.has(key):
					errors.append(fctx + " : champ « %s » manquant" % key)
			if feature_ids.has(feature.get("id")):
				errors.append(fctx + " : id en double")
			feature_ids[feature.get("id")] = true
			if int(feature.get("level", 0)) < 1 or int(feature.get("level", 0)) > Progression.max_level():
				errors.append(fctx + " : niveau hors de 1–%d" % Progression.max_level())
			for action_id in feature.get("actions", []):
				_expect_ref(db.actions, action_id, "action", fctx, errors)
			_validate_modifiers(db, feature.get("modifiers", []), fctx, errors, true)
			_validate_choices(db, feature.get("choices", []), fctx, errors)


static func _validate_backgrounds(db: Node, errors: Array[String]) -> void:
	for background: Dictionary in db.backgrounds.values():
		var ctx := "backgrounds.json › %s" % background["id"]
		if background.get("skills", []).is_empty():
			errors.append(ctx + " : aucune compétence maîtrisée")
		if background.has("feat"):
			_expect_ref(db.feats, background["feat"], "don", ctx, errors)
		else:
			errors.append(ctx + " : chaque passé doit accorder un don (feat)")
		_validate_skills_and_items(db, background, ctx, errors)


static func _validate_combat_data(db: Node, errors: Array[String]) -> void:
	var combat: Dictionary = db.rules.get("combat", {})
	for key in ["side_capacity", "size_slots", "sprite_scale", "actions_per_turn", "dodge_divisor", "prepared_dice"]:
		if not combat.has(key):
			errors.append("rules.json › combat : champ « %s » manquant" % key)

	# Actions de classe (actions.json).
	_validate_ai_actions(db, db.actions.values(), "actions.json", errors)

	var size_ids: Array = db.rules.get("sizes", []).map(func(s): return int(s.get("value", 0)))
	for creature: Dictionary in db.creatures.values():
		var ctx := "creatures.json › %s" % creature["id"]
		for key in ["name", "abilities", "actions"]:
			if not creature.has(key):
				errors.append(ctx + " : champ « %s » manquant" % key)
		if creature.has("hp") and int(creature["hp"]) < 1:
			errors.append(ctx + " : PV invalides « %s » (un nombre ; sans « hp » : CON × 1,414^taille)" % creature.get("hp"))
		for ability_id: String in creature.get("abilities", {}):
			_expect_ref(db.abilities, ability_id, "attribut", ctx, errors)
		if creature.has("gold") and not Dice.is_valid_expr(creature["gold"]):
			errors.append(ctx + " : or invalide « %s »" % creature["gold"])
		if creature.get("ai", "brute") not in ["brute", "hunter", "coward"]:
			errors.append(ctx + " : archétype d'IA inconnu « %s » (brute, hunter, coward)" % creature.get("ai"))
		if int(creature.get("size", 0)) not in size_ids:
			errors.append(ctx + " : taille inconnue « %s »" % creature.get("size"))
		_validate_ai_actions(db, creature.get("actions", []), ctx, errors)
		if creature.has("defenses"):
			_validate_defenses(db, creature["defenses"], ctx, errors)
		for skill_id: String in creature.get("skills", {}):
			_expect_ref(db.skills, skill_id, "compétence", ctx, errors)
		for action_id in db.rules.get("common_actions", []):
			_expect_ref(db.actions, action_id, "action commune", "rules.json › common_actions", errors)
		for loot: Dictionary in creature.get("loot", []):
			_expect_item(db, loot.get("item"), ctx, errors)

	for cls: Dictionary in db.classes.values():
		var ctx := "classes.json › %s" % cls["id"]
		if cls.get("actions", []).is_empty():
			errors.append(ctx + " : aucune action de combat")
		var resource_ids: Array = cls.get("resources", {}).keys()
		var action_ids: Array = cls.get("actions", []).duplicate()
		for feature: Dictionary in cls.get("features", []):
			resource_ids.append_array(feature.get("resources", {}).keys())
			action_ids.append_array(feature.get("actions", []))
		for action_id: String in action_ids:
			_expect_ref(db.actions, action_id, "action", ctx, errors)
			var cost: String = db.actions.get(action_id, {}).get("cost", "")
			if cost == "spell_slot":
				if not cls.has("spell_slots"):
					errors.append(ctx + " : l'action « %s » coûte un emplacement de sort, mais la classe n'a pas de spell_slots" % action_id)
			elif cost != "" and cost not in resource_ids:
				errors.append(ctx + " : l'action « %s » coûte « %s », absent des resources de la classe et de ses aptitudes" % [action_id, cost])

	for companion: Dictionary in db.companions.values():
		var ctx := "companions.json › %s" % companion["id"]
		_expect_ref(db.species, companion.get("species"), "espèce", ctx, errors)
		_expect_ref(db.classes, companion.get("class"), "classe", ctx, errors)
		if companion.get("background", "") != "":
			_expect_ref(db.backgrounds, companion["background"], "passé", ctx, errors)
		for feat_id in companion.get("feats", []):
			_expect_ref(db.feats, feat_id, "don", ctx, errors)

	for item: Dictionary in db.items.values():
		if not item.has("use"):
			continue
		var use: Dictionary = item["use"]
		if use.has("heal"):
			_validate_pool_spec(db, use["heal"], "items.json › %s › use.heal" % item["id"], errors)
		if use.has("cleanse") and use["cleanse"] != "negative":
			_expect_ref(db.status_effects, use["cleanse"], "état", "items.json › %s" % item["id"], errors)


## Actions de combat (classes, créatures) : {"name", "target", "effects", "weight"?, "announced"?,
## "cost"?, "per_combat"?}.
static func _validate_ai_actions(db: Node, actions: Variant, ctx: String, errors: Array[String]) -> void:
	if typeof(actions) != TYPE_ARRAY or actions.is_empty():
		errors.append(ctx + " : il faut au moins une action")
		return
	for action: Dictionary in actions:
		var actx := "%s › action %s" % [ctx, action.get("id", action.get("name", "?"))]
		if not action.has("name"):
			errors.append(actx + " : nom manquant")
		if action.get("target", "enemy") not in CombatEffects.TARGETS:
			errors.append(actx + " : cible inconnue « %s » (%s)" % [action.get("target"), CombatEffects.TARGETS])
		if action.get("cost") == "spell_slot":
			var spell_level := int(action.get("spell_level", 0))
			if spell_level < 1 or spell_level > Spellcasting.MAX_SPELL_LEVEL:
				errors.append(actx + " : un sort à emplacement doit avoir un spell_level de 1 à 9")
		_validate_combat_effects(db, action.get("effects", []), actx, errors)


static func _validate_combat_effects(db: Node, effects: Variant, ctx: String, errors: Array[String]) -> void:
	if typeof(effects) != TYPE_ARRAY or effects.is_empty():
		errors.append(ctx + " : « effects » doit être une liste non vide")
		return
	for e: Variant in effects:
		if typeof(e) != TYPE_DICTIONARY or not CombatEffects.SCHEMA.has(e.get("type", "")):
			errors.append(ctx + " : effet de combat invalide %s (types : %s)" % [str(e), CombatEffects.SCHEMA.keys()])
			continue
		if e.has("save") or e.has("dc") or e.has("to_hit"):
			errors.append(ctx + " : save, dc et to_hit n'existent plus (resist, difficulty ; voir docs/systeme_de_jeu.md)")
		if e.has("resist"):
			var resist: Variant = e["resist"]
			if typeof(resist) != TYPE_DICTIONARY or not db.abilities.has(resist.get("ability", "")):
				errors.append(ctx + " : resist doit valoir {\"ability\": <attribut>, \"skill\"?}")
		_validate_bonus_damage(db, e.get("bonus_damage", []), ctx, errors)
		if e.has("upcast") and (typeof(e["upcast"]) not in [TYPE_INT, TYPE_FLOAT] or int(e["upcast"]) < 1):
			errors.append(ctx + " : upcast doit être un nombre de dés « %s »" % str(e["upcast"]))
		if e.has("scaling"):
			var scaling: Variant = e["scaling"]
			if typeof(scaling) != TYPE_DICTIONARY or scaling.get("table", "") not in Spellcasting.scaling_tables():
				errors.append(ctx + " : scaling doit valoir {\"table\": %s, \"class\"?}" % [Spellcasting.scaling_tables()])
		var missing: Array = CombatEffects.SCHEMA[e["type"]].filter(func(k): return not e.has(k))
		if not missing.is_empty():
			errors.append(ctx + " : effet « %s » sans %s" % [e["type"], missing])
			continue
		match e["type"]:
			"attack":
				var weapon: Variant = e.get("weapon")
				if weapon is String:
					_expect_ref(db.equipment, weapon, "arme", ctx, errors)
				elif not (weapon is bool and weapon):
					_validate_pool_spec(db, e.get("damage"), ctx + " › damage", errors)
					_expect_ref(db.damage_types, e.get("damage_type"), "type de dégâts", ctx, errors)
				if e.has("skill"):
					_expect_ref(db.skills, e["skill"], "compétence", ctx, errors)
				if e.has("ability") and e["ability"] not in ["spell", "weapon"]:
					_expect_ref(db.abilities, e["ability"], "attribut", ctx, errors)
			"damage":
				_validate_pool_spec(db, e["damage"], ctx + " › damage", errors)
				_expect_ref(db.damage_types, e.get("damage_type"), "type de dégâts", ctx, errors)
			"heal":
				_validate_pool_spec(db, e["amount"], ctx + " › amount", errors)
			"status":
				_expect_ref(db.status_effects, e["status"], "état", ctx, errors)
			"cleanse":
				if e["status"] != "negative":
					_expect_ref(db.status_effects, e["status"], "état", ctx, errors)
			"summon":
				_expect_ref(db.creatures, e["creature"], "créature", ctx, errors)
			"check":
				_expect_ref(db.skills, e["skill"], "compétence", ctx, errors)
				if e.has("vs_resist"):
					_expect_ref(db.abilities, e["vs_resist"], "attribut", ctx, errors)
				elif not e.has("difficulty"):
					errors.append(ctx + " : test sans difficulty (ni vs_resist)")


static func _validate_skills_and_items(db: Node, entry: Dictionary, ctx: String, errors: Array[String]) -> void:
	for skill: String in entry.get("skills", []):
		if not db.skills.has(skill):
			errors.append(ctx + " : compétence inconnue « %s »" % skill)
	for item: String in entry.get("start_items", {}):
		if not db.items.has(item) and not db.equipment.has(item):
			errors.append(ctx + " : objet inconnu « %s »" % item)


static func _ids(list: Array) -> Array:
	return list.map(func(entry): return entry["id"])


static func _validate_event(db: Node, ev: Dictionary, errors: Array[String]) -> void:
	var ctx := "events/%s › %s" % [ev.get("_file", "?"), ev["id"]]
	var location: Variant = ev.get("location")
	if location != null and not db.locations.has(location):
		errors.append(ctx + " : lieu inconnu « %s »" % location)
	if ev.get("repeat", "always") not in EventEngine.REPEAT_MODES:
		errors.append(ctx + " : repeat invalide « %s »" % ev.get("repeat"))
	if not ev.has("text"):
		errors.append(ctx + " : texte manquant")
	_validate_conditions(db, ev.get("conditions", []), ctx, errors)

	var choices: Variant = ev.get("choices", [])
	if typeof(choices) != TYPE_ARRAY or choices.is_empty():
		errors.append(ctx + " : aucun choix")
		return
	# Les choix verrouillés étant cachés, il faut toujours une issue pour ne pas bloquer le joueur.
	if choices.all(func(c): return typeof(c) == TYPE_DICTIONARY and not c.get("conditions", []).is_empty()):
		errors.append(ctx + " : au moins un choix doit être sans condition (sinon le joueur peut se retrouver bloqué)")
	if choices.any(func(c): return typeof(c) == TYPE_DICTIONARY and c.has("hide_if_locked")):
		errors.append(ctx + " : « hide_if_locked » n'existe plus (les choix verrouillés sont toujours cachés hors debug)")
	var choice_ids := {}
	for choice: Dictionary in choices:
		var cctx := "%s › choix %s" % [ctx, choice.get("id", "?")]
		if not choice.has("id") or not choice.has("text"):
			errors.append(cctx + " : id ou texte manquant")
		elif choice_ids.has(choice["id"]):
			errors.append(cctx + " : id de choix en double")
		choice_ids[choice.get("id")] = true
		_validate_conditions(db, choice.get("conditions", []), cctx, errors)

		if choice.has("check"):
			var check: Dictionary = choice["check"]
			if not check.has("difficulty"):
				errors.append(cctx + " : difficulté (difficulty) manquante")
			elif int(check["difficulty"]) < 0:
				errors.append(cctx + " : difficulté négative")
			if check.has("skill") and not db.skills.has(check["skill"]):
				errors.append(cctx + " : compétence inconnue « %s »" % check["skill"])
			elif check.has("ability") and not db.abilities.has(check["ability"]):
				errors.append(cctx + " : attribut inconnu « %s »" % check["ability"])
			elif check.has("resist") and not db.abilities.has(check["resist"]):
				errors.append(cctx + " : résistance inconnue « %s »" % check["resist"])
			elif not check.has("skill") and not check.has("ability") and not check.has("resist"):
				errors.append(cctx + " : le test doit indiquer « skill », « ability » ou « resist »")
			for key in ["success", "failure"]:
				if not choice.has(key):
					errors.append(cctx + " : résultat « %s » manquant" % key)
				else:
					_validate_effects(db, choice[key].get("effects", []), "%s › %s" % [cctx, key], errors)
			for key in ["critical_success", "critical_failure"]:
				if choice.has(key):
					_validate_effects(db, choice[key].get("effects", []), "%s › %s" % [cctx, key], errors)
		elif choice.has("outcome"):
			_validate_effects(db, choice["outcome"].get("effects", []), cctx, errors)
		else:
			errors.append(cctx + " : il faut « outcome », ou « check » + « success » + « failure »")


static func _validate_conditions(db: Node, conditions: Variant, ctx: String, errors: Array[String]) -> void:
	if typeof(conditions) != TYPE_ARRAY:
		errors.append(ctx + " : « conditions » doit être une liste")
		return
	for c: Variant in conditions:
		if typeof(c) != TYPE_DICTIONARY:
			errors.append(ctx + " : condition invalide %s" % str(c))
			continue
		var type: String = c.get("type", "")
		if not Conditions.SCHEMA.has(type):
			errors.append(ctx + " : type de condition inconnu « %s »" % type)
			continue
		var missing: Array = Conditions.SCHEMA[type].filter(func(k): return not c.has(k))
		if not missing.is_empty():
			errors.append(ctx + " : condition « %s » sans %s" % [type, missing])
			continue
		match type:
			"not":
				_validate_conditions(db, [c["condition"]], ctx, errors)
			"any":
				_validate_conditions(db, c["conditions"], ctx, errors)
			"ability":
				_expect_ref(db.abilities, c["id"], "attribut", ctx, errors)
			"skill_proficient":
				_expect_ref(db.skills, c["id"], "compétence", ctx, errors)
			"quest":
				_expect_ref(db.quests, c["id"], "quête", ctx, errors)
				if c.get("status", "active") not in Quests.STATUSES + ["none"]:
					errors.append(ctx + " : statut de quête inconnu « %s »" % c.get("status"))
			"species":
				for id in c["in"]:
					_expect_ref(db.species, id, "espèce", ctx, errors)
			"background":
				for id in c["in"]:
					_expect_ref(db.backgrounds, id, "passé", ctx, errors)
			"size":
				var sizes: Array = db.rules.get("sizes", []).map(func(s): return int(s.get("value", 0)))
				for value in c.get("in", []):
					if int(value) not in sizes:
						errors.append(ctx + " : taille inconnue « %s » (échelle de −4 à 5)" % value)
			"gender", "life_stage":
				var list_key: String = {"gender": "genders", "life_stage": "life_stages"}[type]
				for id in c["in"]:
					if id not in _ids(db.rules.get(list_key, [])):
						errors.append(ctx + " : valeur inconnue « %s » pour la condition « %s »" % [id, type])
			"class":
				for id in c["in"]:
					_expect_ref(db.classes, id, "classe", ctx, errors)
			"item":
				_expect_item(db, c["id"], ctx, errors)
			"seen":
				_expect_ref(db.events, c["event"], "événement", ctx, errors)
			"companion":
				_expect_ref(db.companions, c["id"], "compagnon", ctx, errors)
			"has_feat":
				_expect_ref(db.feats, c["id"], "don", ctx, errors)
			"equipped":
				_expect_ref(db.equipment, c["id"], "équipement", ctx, errors)
			"defense":
				_validate_defense_ref(db, c["kind"], c["id"], ctx, errors)
			"unlocked":
				_validate_unlock_id(db, c["id"], ctx, errors)
			"time":
				var slot_ids: Array = db.time_slots().map(func(s): return s["id"])
				for id in c["in"]:
					if id not in slot_ids:
						errors.append(ctx + " : moment de la journée inconnu « %s »" % id)


static func _validate_effects(db: Node, effects: Variant, ctx: String, errors: Array[String]) -> void:
	if typeof(effects) != TYPE_ARRAY:
		errors.append(ctx + " : « effects » doit être une liste")
		return
	for e: Variant in effects:
		if typeof(e) != TYPE_DICTIONARY:
			errors.append(ctx + " : effet invalide %s" % str(e))
			continue
		var type: String = e.get("type", "")
		if not Effects.SCHEMA.has(type):
			errors.append(ctx + " : type d'effet inconnu « %s »" % type)
			continue
		var missing: Array = Effects.SCHEMA[type].filter(func(k): return not e.has(k))
		if not missing.is_empty():
			errors.append(ctx + " : effet « %s » sans %s" % [type, missing])
			continue
		if type == "combat" and e != effects.back():
			errors.append(ctx + " : l'effet « combat » doit être le dernier de la liste")
		match type:
			"combat":
				var slots := 0.0
				for enemy_id in e["enemies"]:
					_expect_ref(db.creatures, enemy_id, "créature", ctx, errors)
					slots += Combat.size_slots(Creatures.size_of(enemy_id))
				var capacity := float(Combat.setting("side_capacity", 4))
				if slots > capacity + 0.001:
					errors.append(ctx + " : trop d'ennemis (%.1f places pour %d disponibles, voir rules.json › combat)" % [slots, capacity])
				if e.get("on_defeat", "death") not in ["death", "knockout"]:
					errors.append(ctx + " : on_defeat doit valoir « death » ou « knockout »")
				for key in ["victory", "defeat", "fled"]:
					if e.has(key):
						_validate_effects(db, e[key].get("effects", []), "%s › %s" % [ctx, key], errors)
			"recruit":
				_expect_ref(db.companions, e["companion"], "compagnon", ctx, errors)
			"add_feat":
				_expect_ref(db.feats, e["id"], "don", ctx, errors)
			"equip":
				_expect_ref(db.equipment, e["id"], "équipement", ctx, errors)
			"add_defense", "remove_defense":
				_validate_defense_ref(db, e["kind"], e["id"], ctx, errors)
			"hp":
				if e.has("damage_type"):
					_expect_ref(db.damage_types, e["damage_type"], "type de dégâts", ctx, errors)
			"add_item", "remove_item":
				_expect_item(db, e["id"], ctx, errors)
			"ability":
				_expect_ref(db.abilities, e["id"], "attribut", ctx, errors)
			"goto":
				_expect_ref(db.events, e["event"], "événement", ctx, errors)
			"unlock":
				_validate_unlock_id(db, e["id"], ctx, errors)
			"quest":
				_expect_ref(db.quests, e["id"], "quête", ctx, errors)
				if e["action"] not in Quests.ACTIONS:
					errors.append(ctx + " : action de quête inconnue « %s » (%s)" % [e["action"], Quests.ACTIONS])


static func _validate_defense_ref(db: Node, kind: String, id: String, ctx: String, errors: Array[String]) -> void:
	if kind not in Defenses.KINDS:
		errors.append(ctx + " : sorte de défense inconnue « %s » (attendu %s)" % [kind, Defenses.KINDS])
	elif kind == Defenses.STATUS_IMMUNITY:
		_expect_ref(db.status_effects, id, "état", ctx, errors)
	else:
		_expect_ref(db.damage_types, id, "type de dégâts", ctx, errors)


static func _validate_unlock_id(db: Node, id: String, ctx: String, errors: Array[String]) -> void:
	var parts := id.split(":")
	if parts.size() != 2 or parts[0] not in ["species", "class"]:
		errors.append(ctx + " : déblocage invalide « %s » (attendu species:<id> ou class:<id>)" % id)
	elif parts[0] == "species":
		_expect_ref(db.species, parts[1], "espèce", ctx, errors)
	else:
		_expect_ref(db.classes, parts[1], "classe", ctx, errors)


## "bonus_damage" : [{"dice": 2, "threshold": 5, "damage_type": "fire"}, ...]
static func _validate_bonus_damage(db: Node, parts: Variant, ctx: String, errors: Array[String]) -> void:
	if typeof(parts) != TYPE_ARRAY:
		errors.append(ctx + " : bonus_damage doit être une liste")
		return
	for part: Variant in parts:
		if typeof(part) != TYPE_DICTIONARY or not part.has("dice") or typeof(part.get("threshold")) not in [TYPE_INT, TYPE_FLOAT]:
			errors.append(ctx + " : bonus_damage invalide %s (attendu {\"dice\", \"threshold\", \"damage_type\"})" % str(part))
		else:
			_expect_ref(db.damage_types, part.get("damage_type"), "type de dégâts", ctx, errors)


## Réserve de dégâts ou de soins : {"dice"?: N, "skill"?: compétence, "threshold"?: "weapon" | "spell" |
## attribut | N, "bonus"?: N}.
static func _validate_pool_spec(db: Node, spec: Variant, ctx: String, errors: Array[String]) -> void:
	if typeof(spec) != TYPE_DICTIONARY:
		errors.append(ctx + " : réserve invalide %s (attendu {\"dice\"?, \"skill\"?, \"threshold\"?, \"bonus\"?})" % str(spec))
		return
	for key: String in spec:
		if key not in ["dice", "skill", "threshold", "bonus"]:
			errors.append(ctx + " : champ inconnu « %s »" % key)
	if spec.has("skill"):
		_expect_ref(db.skills, spec["skill"], "compétence", ctx, errors)
	var threshold: Variant = spec.get("threshold", "weapon")
	if threshold is String and threshold not in ["weapon", "spell"] and not db.abilities.has(threshold):
		errors.append(ctx + " : seuil inconnu « %s » (weapon, spell, un attribut ou un nombre)" % threshold)


static func _validate_damage_types(db: Node, errors: Array[String]) -> void:
	for type: Dictionary in db.damage_types.values():
		var status: Dictionary = type.get("status", {})
		if not status.is_empty():
			var ctx := "damage_types.json › %s" % type["id"]
			_expect_ref(db.status_effects, status.get("id"), "état", ctx, errors)
			var chance := float(status.get("chance", -1))
			if chance < 0.0 or chance > 1.0:
				errors.append(ctx + " : status.chance doit être entre 0 et 1")


static func _validate_quests(db: Node, errors: Array[String]) -> void:
	for quest: Dictionary in db.quests.values():
		var ctx := "quests.json › %s" % quest["id"]
		for key in ["name", "description", "steps"]:
			if not quest.has(key):
				errors.append(ctx + " : champ « %s » manquant" % key)
		if quest.get("steps", []).is_empty():
			errors.append(ctx + " : il faut au moins une étape")
		if quest.has("location"):
			_expect_ref(db.locations, quest["location"], "lieu", ctx, errors)


static func _validate_economy(db: Node, errors: Array[String]) -> void:
	for item: Dictionary in db.items.values():
		if item.get("category", "") not in ["consumable", "material", "treasure"]:
			errors.append("items.json › %s : category doit valoir consumable, material ou treasure" % item["id"])
	var stations := {}
	for shop: Dictionary in db.shops.values():
		var ctx := "shops.json › %s" % shop["id"]
		_expect_ref(db.locations, shop.get("location"), "lieu", ctx, errors)
		for item_id: String in shop.get("stock", {}):
			_expect_item(db, item_id, ctx, errors)
		if shop.has("crafting"):
			stations[shop["crafting"]] = true
	for recipe: Dictionary in db.recipes.values():
		var ctx := "recipes.json › %s" % recipe["id"]
		_expect_item(db, recipe.get("result"), ctx, errors)
		if recipe.get("materials", {}).is_empty():
			errors.append(ctx + " : aucun matériau")
		for item_id: String in recipe.get("materials", {}):
			_expect_item(db, item_id, ctx, errors)
		if not db.rules.get("crafting", {}).get("station_skills", {}).has(recipe.get("station")):
			errors.append(ctx + " : station sans compétence (rules.json › crafting › station_skills)")
		if not stations.has(recipe.get("station")):
			errors.append(ctx + " : aucune boutique n'a la station « %s » (shops.json › crafting)" % recipe.get("station"))
	for key in ["sell_rate", "price_skill", "percent_per_success", "max_percent"]:
		if not db.rules.get("trade", {}).has(key):
			errors.append("rules.json › trade : champ « %s » manquant" % key)
	if not db.skills.has(db.rules.get("trade", {}).get("price_skill", "")):
		errors.append("rules.json › trade : price_skill doit être une compétence")


## Choix (voir Choices) d'une espèce, d'une classe, d'une aptitude ou d'un don ; les options d'une
## sous-classe sont vérifiées avec leurs aptitudes.
static func _validate_choices(db: Node, specs: Variant, ctx: String, errors: Array[String]) -> void:
	if typeof(specs) != TYPE_ARRAY:
		errors.append(ctx + " : « choices » doit être une liste")
		return
	for spec: Dictionary in specs:
		var cctx := "%s › choix %s" % [ctx, spec.get("id", "?")]
		var type: String = spec.get("type", "")
		var table: Dictionary = {"skill": db.skills, "ability": db.abilities, "damage_type": db.damage_types,
			"feat": db.feats, "action": db.actions}.get(type, {})
		if type not in ["skill", "ability", "damage_type", "feat", "action", "option"]:
			errors.append(cctx + " : type inconnu « %s »" % type)
			continue
		var option_ids: Array = []
		for o: Variant in spec.get("options", []):
			if type == "option":
				if typeof(o) != TYPE_DICTIONARY or not o.has("id") or not o.has("name"):
					errors.append(cctx + " : une option doit être {\"id\", \"name\", ...}")
					continue
				option_ids.append(o["id"])
				_validate_modifiers(db, o.get("modifiers", []), cctx, errors, true)
				for action_id in o.get("actions", []):
					_expect_ref(db.actions, action_id, "action", cctx, errors)
				_validate_features(db, o.get("features", []), "%s › %s" % [cctx, o["id"]], errors)
			else:
				option_ids.append(o)
				_expect_ref(table, o, type, cctx, errors)
		for value in spec.get("default", []):
			if type != "feat" and not option_ids.is_empty() and value not in option_ids:
				errors.append(cctx + " : valeur par défaut « %s » absente des options" % value)
			elif type == "feat":
				_expect_ref(db.feats, value, "don", cctx, errors)
		var sample: String = str(option_ids[0]) if not option_ids.is_empty() else ("str" if type == "ability" else "")
		if sample != "" and type != "option":
			_validate_modifiers(db, spec.get("modifiers", []).map(func(m): return Choices.fill(m, sample)), cctx, errors, true)


## Aptitudes de classe ou de sous-classe : champs, actions, modificateurs, choix.
static func _validate_features(db: Node, features: Array, ctx: String, errors: Array[String]) -> void:
	for feature: Dictionary in features:
		var fctx := "%s › aptitude %s" % [ctx, feature.get("id", "?")]
		for key in ["level", "id", "name", "description"]:
			if not feature.has(key):
				errors.append(fctx + " : champ « %s » manquant" % key)
		for action_id in feature.get("actions", []):
			_expect_ref(db.actions, action_id, "action", fctx, errors)
		_validate_modifiers(db, feature.get("modifiers", []), fctx, errors, true)
		_validate_choices(db, feature.get("choices", []), fctx, errors)


static func _validate_social(db: Node, errors: Array[String]) -> void:
	for loc: Dictionary in db.locations.values():
		var rest: Dictionary = loc.get("rest", {})
		if not rest.is_empty() and rest.get("type") not in ["camp", "inn", "home"]:
			errors.append("locations.json › %s : rest.type doit valoir camp, inn ou home" % loc["id"])
	for role: Dictionary in db.npc_roles.values():
		var ctx := "npc_roles.json › %s" % role["id"]
		_expect_ref(db.locations, role.get("location"), "lieu", ctx, errors)
		if role.has("shop"):
			_expect_ref(db.shops, role["shop"], "boutique", ctx, errors)
		if role.has("class"):
			_expect_ref(db.classes, role["class"], "classe", ctx, errors)
		if role.get("fixed", {}).has("species"):
			_expect_ref(db.species, role["fixed"]["species"], "espèce", ctx, errors)
		for item_id: String in role.get("inventory", {}):
			_expect_item(db, item_id, ctx, errors)
	for trait_def: Dictionary in db.traits.values():
		var ctx := "traits.json › %s" % trait_def["id"]
		for action_id: String in trait_def.get("reactions", {}):
			if not db.social_actions.has(action_id) and action_id not in ["gift", "ask_free", "trust_gain"]:
				errors.append(ctx + " : réaction à une action inconnue « %s »" % action_id)
		for category in trait_def.get("likes", []):
			if category not in Items.CATEGORIES:
				errors.append(ctx + " : catégorie d'objet inconnue « %s »" % category)
	for fact: Dictionary in db.npc_facts.values():
		if fact.get("values", []).is_empty():
			errors.append("npc_facts.json › %s : aucune valeur" % fact["id"])
	for a: Dictionary in db.social_actions.values():
		var ctx := "social_actions.json › %s" % a["id"]
		if a.get("category") not in ["friendly", "romantic", "hostile", "special"]:
			errors.append(ctx + " : catégorie inconnue « %s »" % a.get("category"))
		if a.has("check"):
			_expect_ref(db.skills, a["check"].get("skill"), "compétence", ctx, errors)
			if a["check"].has("vs"):
				_expect_ref(db.skills, a["check"]["vs"], "compétence", ctx, errors)
		if a.get("special", "") not in ["", "reveal_fact", "trade", "recruit", "gestures", "child", "break_up"]:
			errors.append(ctx + " : special inconnu « %s »" % a["special"])


## Un objet du sac : id de items.json ou de equipment.json.
static func _expect_item(db: Node, id: Variant, ctx: String, errors: Array[String]) -> void:
	if not db.items.has(id) and not db.equipment.has(id):
		errors.append(ctx + " : objet inconnu « %s » (ni dans items.json, ni dans equipment.json)" % id)


static func _validate_items(db: Node, errors: Array[String]) -> void:
	for id: String in db.items:
		if db.equipment.has(id):
			errors.append("items.json › %s : id déjà utilisé dans equipment.json (les ids doivent être uniques)" % id)
	for table: Dictionary in [db.items, db.equipment]:
		for item: Dictionary in table.values():
			var ctx := "%s › %s" % ["items.json" if table == db.items else "equipment.json", item["id"]]
			if item.get("rarity", "common") not in Items.RARITIES:
				errors.append(ctx + " : rareté inconnue « %s » (%s)" % [item.get("rarity"), Items.RARITIES])
			if item.get("category") == "accessory" and item.get("slot") not in Equipment.ACCESSORY_SLOTS:
				errors.append(ctx + " : un accessoire doit avoir un slot parmi %s" % [Equipment.ACCESSORY_SLOTS])
			if table == db.items:
				_validate_modifiers(db, item.get("modifiers", []), ctx, errors, true)


static func _expect_ref(table: Dictionary, id: Variant, kind: String, ctx: String, errors: Array[String]) -> void:
	if not table.has(id):
		errors.append(ctx + " : %s inconnu(e) « %s »" % [kind, id])
