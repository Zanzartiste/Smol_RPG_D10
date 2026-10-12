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
	for id: String in db.events:
		_validate_event(db, db.events[id], errors)


static func _validate_rules(db: Node, errors: Array[String]) -> void:
	for key in ["standard_array", "point_buy", "genders", "sizes", "time_slots", "life_stages", "days_per_year"]:
		if not db.rules.has(key):
			errors.append("rules.json : champ « %s » manquant" % key)
	if db.rules.get("standard_array", []).size() != db.abilities.size():
		errors.append("rules.json : standard_array doit avoir une valeur par attribut")
	var xp_table: Array = db.rules.get("xp_by_level", [])
	if db.rules.get("proficiency_by_level", []).size() != xp_table.size():
		errors.append("rules.json : proficiency_by_level doit avoir autant d'entrées que xp_by_level")
	for level in db.rules.get("advancement_levels", []):
		if int(level) < 2 or int(level) > xp_table.size():
			errors.append("rules.json : niveau d'amélioration hors limites : %s" % level)
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
		if not db.abilities.has(skill.get("ability")):
			errors.append("skills.json › %s : attribut inconnu « %s »" % [skill["id"], skill.get("ability")])

	for feat: Dictionary in db.feats.values():
		var ctx := "feats.json › %s" % feat["id"]
		if feat.get("category", "general") not in ["origin", "general"]:
			errors.append(ctx + " : catégorie inconnue « %s » (origin ou general)" % feat.get("category"))
		_validate_modifiers(db, feat.get("modifiers", []), ctx, errors, true)
		_validate_conditions(db, feat.get("prerequisites", []), ctx + " › prerequisites", errors)

	for item: Dictionary in db.equipment.values():
		var ctx := "equipment.json › %s" % item["id"]
		match item.get("category"):
			"weapon":
				if not Dice.is_valid_expr(item.get("damage", "")):
					errors.append(ctx + " : dégâts invalides « %s »" % item.get("damage"))
				_expect_ref(db.damage_types, item.get("damage_type"), "type de dégâts", ctx, errors)
				for prop in item.get("properties", []):
					if prop not in Equipment.PROPERTY_NAMES:
						errors.append(ctx + " : propriété inconnue « %s »" % prop)
				if "versatile" in item.get("properties", []) and not Dice.is_valid_expr(item.get("versatile_damage", "")):
					errors.append(ctx + " : arme polyvalente sans versatile_damage valide")
			"armor":
				if item.get("armor_type") not in Equipment.ARMOR_TYPE_NAMES:
					errors.append(ctx + " : armor_type doit valoir light, medium ou heavy")
				if not item.has("base_ac"):
					errors.append(ctx + " : base_ac manquant")
			"shield":
				pass
			_:
				errors.append(ctx + " : catégorie inconnue « %s » (weapon, armor, shield)" % item.get("category"))
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
			"skill_proficiency":
				_expect_ref(db.skills, m["id"], "compétence", ctx, errors)
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
	var size_ids := _ids(db.rules.get("sizes", []))
	for species: Dictionary in db.species.values():
		var ctx := "species.json › %s" % species["id"]
		if species.get("names", []).is_empty():
			errors.append(ctx + " : liste de noms vide")
		if species.get("size") not in size_ids:
			errors.append(ctx + " : taille inconnue « %s » (voir rules.json › sizes)" % species.get("size"))
		if not species.has("aging_age"):
			errors.append(ctx + " : aging_age (âge à partir duquel on vieillit) manquant")
		if species.has("ability_bonus"):
			errors.append(ctx + " : une espèce ne doit pas modifier les attributs (ability_bonus)")
		_validate_modifiers(db, species.get("modifiers", []), ctx, errors, false)
		for stage: String in species.get("age_stages", {}):
			if stage not in stage_ids:
				errors.append(ctx + " : étape de vie inconnue « %s »" % stage)


static func _validate_classes(db: Node, errors: Array[String]) -> void:
	var ability_ids: Array = db.abilities.keys()
	for cls: Dictionary in db.classes.values():
		var ctx := "classes.json › %s" % cls["id"]
		if not cls.has("hit_die"):
			errors.append(ctx + " : hit_die manquant")
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
			elif Equipment.slot_for(equipment[slot]) != slot:
				errors.append(ctx + " : « %s » ne va pas dans l'emplacement « %s »" % [equipment[slot], slot])


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
	for key in ["side_capacity", "size_slots", "sprite_scale", "deck_min_size", "max_hand_size", "draw_per_turn", "max_mana"]:
		if not combat.has(key):
			errors.append("rules.json › combat : champ « %s » manquant" % key)
	for color: Dictionary in db.mana_colors.values():
		if color["id"] == Mana.COLORLESS or color["id"].is_valid_int():
			errors.append("mana_colors.json › %s : id réservé (C = incolore, nombres = générique)" % color["id"])

	for card: Dictionary in db.cards.values():
		var ctx := "cards.json › %s" % card["id"]
		if not Mana.is_valid_cost(card.get("cost", "")):
			errors.append(ctx + " : coût invalide « %s » (ex. {1}{R})" % card.get("cost"))
		if card.get("type") not in Cards.TYPE_NAMES:
			errors.append(ctx + " : type inconnu « %s » (%s)" % [card.get("type"), Cards.TYPE_NAMES.keys()])
		if card.get("rarity", "common") not in Cards.RARITY_NAMES:
			errors.append(ctx + " : rareté inconnue « %s »" % card.get("rarity"))
		if card.get("target") not in Cards.TARGETS:
			errors.append(ctx + " : cible inconnue « %s » (%s)" % [card.get("target"), Cards.TARGETS])
		_validate_combat_effects(db, card.get("effects", []), ctx, errors)

	var size_ids := _ids(db.rules.get("sizes", []))
	for creature: Dictionary in db.creatures.values():
		var ctx := "creatures.json › %s" % creature["id"]
		for key in ["name", "ac", "hp", "actions"]:
			if not creature.has(key):
				errors.append(ctx + " : champ « %s » manquant" % key)
		if not Dice.is_valid_expr(str(creature.get("hp", ""))):
			errors.append(ctx + " : PV invalides « %s »" % creature.get("hp"))
		if creature.has("gold") and not Dice.is_valid_expr(creature["gold"]):
			errors.append(ctx + " : or invalide « %s »" % creature["gold"])
		if creature.get("size", "medium") not in size_ids:
			errors.append(ctx + " : taille inconnue « %s »" % creature.get("size"))
		_validate_ai_actions(db, creature.get("actions", []), ctx, errors)
		if creature.has("defenses"):
			_validate_defenses(db, creature["defenses"], ctx, errors)
		for loot: Dictionary in creature.get("loot", []):
			_expect_ref(db.items, loot.get("item"), "objet", ctx, errors)
		for loot: Dictionary in creature.get("loot_cards", []):
			_expect_ref(db.cards, loot.get("card"), "carte", ctx, errors)

	var min_deck := int(combat.get("deck_min_size", 40))
	for cls: Dictionary in db.classes.values():
		var ctx := "classes.json › %s" % cls["id"]
		_validate_card_list(db, cls.get("cards", {}), ctx, errors)
		if Cards.count(cls.get("cards", {})) < min_deck:
			errors.append(ctx + " : la classe doit débloquer au moins %d cartes (deck minimum)" % min_deck)
		_validate_ai_actions(db, cls.get("companion_actions", []), ctx + " › companion_actions", errors)
		if cls.has("basic_attack"):
			_validate_combat_effects(db, cls["basic_attack"].get("effects", []), ctx + " › basic_attack", errors)
	for table in ["species", "backgrounds", "feats", "equipment"]:
		for entry: Dictionary in db.get(table).values():
			_validate_card_list(db, entry.get("cards", {}), "%s.json › %s" % [table, entry["id"]], errors)

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
		if use.has("heal") and not Dice.is_valid_expr(use["heal"]):
			errors.append("items.json › %s : use.heal invalide" % item["id"])
		if use.has("cleanse") and use["cleanse"] != "negative":
			_expect_ref(db.status_effects, use["cleanse"], "état", "items.json › %s" % item["id"], errors)


static func _validate_card_list(db: Node, cards: Variant, ctx: String, errors: Array[String]) -> void:
	if typeof(cards) != TYPE_DICTIONARY:
		errors.append(ctx + " : « cards » doit être un objet {id de carte: nombre}")
		return
	for card_id: String in cards:
		_expect_ref(db.cards, card_id, "carte", ctx, errors)


## Actions de l'IA (créatures, compagnons) : {"name", "weight", "target", "prepared"?, "effects"}.
static func _validate_ai_actions(db: Node, actions: Variant, ctx: String, errors: Array[String]) -> void:
	if typeof(actions) != TYPE_ARRAY or actions.is_empty():
		errors.append(ctx + " : il faut au moins une action")
		return
	for action: Dictionary in actions:
		var actx := "%s › action %s" % [ctx, action.get("name", "?")]
		if not action.has("name"):
			errors.append(actx + " : nom manquant")
		if action.get("target", "enemy") not in Cards.TARGETS:
			errors.append(actx + " : cible inconnue « %s »" % action.get("target"))
		_validate_combat_effects(db, action.get("effects", []), actx, errors)


## Effets de combat (cartes, actions) : voir CombatEffects.
static func _validate_combat_effects(db: Node, effects: Variant, ctx: String, errors: Array[String]) -> void:
	if typeof(effects) != TYPE_ARRAY or effects.is_empty():
		errors.append(ctx + " : « effects » doit être une liste non vide")
		return
	for e: Variant in effects:
		if typeof(e) != TYPE_DICTIONARY or not CombatEffects.SCHEMA.has(e.get("type", "")):
			errors.append(ctx + " : effet de combat invalide %s (types : %s)" % [str(e), CombatEffects.SCHEMA.keys()])
			continue
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
					if not Dice.is_valid_expr(e.get("damage", "")):
						errors.append(ctx + " : attaque sans dégâts valides (damage, ou weapon)")
					_expect_ref(db.damage_types, e.get("damage_type"), "type de dégâts", ctx, errors)
				if e.has("extra_damage") and not Dice.is_valid_expr(e["extra_damage"]):
					errors.append(ctx + " : extra_damage invalide « %s »" % e["extra_damage"])
			"damage":
				if not Dice.is_valid_expr(e["damage"]):
					errors.append(ctx + " : dégâts invalides « %s »" % e["damage"])
				_expect_ref(db.damage_types, e.get("damage_type"), "type de dégâts", ctx, errors)
			"heal":
				if not Dice.is_valid_expr(String(e["amount"]).replace("level", "1")):
					errors.append(ctx + " : soins invalides « %s »" % e["amount"])
			"status":
				_expect_ref(db.status_effects, e["status"], "état", ctx, errors)
			"cleanse":
				if e["status"] != "negative":
					_expect_ref(db.status_effects, e["status"], "état", ctx, errors)
			"summon":
				_expect_ref(db.creatures, e["creature"], "créature", ctx, errors)


static func _validate_skills_and_items(db: Node, entry: Dictionary, ctx: String, errors: Array[String]) -> void:
	for skill: String in entry.get("skills", []):
		if not db.skills.has(skill):
			errors.append(ctx + " : compétence inconnue « %s »" % skill)
	for item: String in entry.get("start_items", {}):
		if not db.items.has(item):
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
			if not check.has("dc"):
				errors.append(cctx + " : DD (dc) manquant")
			if check.has("skill") and not db.skills.has(check["skill"]):
				errors.append(cctx + " : compétence inconnue « %s »" % check["skill"])
			elif check.has("ability") and not db.abilities.has(check["ability"]):
				errors.append(cctx + " : attribut inconnu « %s »" % check["ability"])
			elif not check.has("skill") and not check.has("ability"):
				errors.append(cctx + " : le test doit indiquer « skill » ou « ability »")
			for key in ["success", "failure"]:
				if not choice.has(key):
					errors.append(cctx + " : résultat « %s » manquant" % key)
				else:
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
			"species":
				for id in c["in"]:
					_expect_ref(db.species, id, "espèce", ctx, errors)
			"background":
				for id in c["in"]:
					_expect_ref(db.backgrounds, id, "passé", ctx, errors)
			"size", "gender", "life_stage":
				var list_key: String = {"size": "sizes", "gender": "genders", "life_stage": "life_stages"}[type]
				for id in c["in"]:
					if id not in _ids(db.rules.get(list_key, [])):
						errors.append(ctx + " : valeur inconnue « %s » pour la condition « %s »" % [id, type])
			"class":
				for id in c["in"]:
					_expect_ref(db.classes, id, "classe", ctx, errors)
			"item":
				_expect_ref(db.items, c["id"], "objet", ctx, errors)
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
				_expect_ref(db.items, e["id"], "objet", ctx, errors)
			"ability":
				_expect_ref(db.abilities, e["id"], "attribut", ctx, errors)
			"goto":
				_expect_ref(db.events, e["event"], "événement", ctx, errors)
			"unlock":
				_validate_unlock_id(db, e["id"], ctx, errors)


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


static func _expect_ref(table: Dictionary, id: Variant, kind: String, ctx: String, errors: Array[String]) -> void:
	if not table.has(id):
		errors.append(ctx + " : %s inconnu(e) « %s »" % [kind, id])
