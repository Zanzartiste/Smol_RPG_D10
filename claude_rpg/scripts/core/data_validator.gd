class_name DataValidator
extends RefCounted
## Vérifie la cohérence des données JSON : champs obligatoires, types connus, références
## (objets, compétences, événements...). Les erreurs sont ajoutées à db.errors.


static func validate(db: Node) -> void:
	var errors: Array[String] = db.errors
	_validate_rules(db, errors)
	_validate_species(db, errors)
	_validate_classes(db, errors)
	_validate_backgrounds(db, errors)
	for id: String in db.events:
		_validate_event(db, db.events[id], errors)


static func _validate_rules(db: Node, errors: Array[String]) -> void:
	for key in ["abilities", "skills", "standard_array", "point_buy", "genders", "sizes", "time_slots",
			"life_stages", "days_per_year"]:
		if not db.rules.has(key):
			errors.append("rules.json : champ « %s » manquant" % key)
	if db.rules.get("standard_array", []).size() != db.abilities.size():
		errors.append("rules.json : standard_array doit avoir une valeur par attribut")
	for skill: Dictionary in db.skills.values():
		if not db.abilities.has(skill.get("ability")):
			errors.append("rules.json : compétence « %s » liée à un attribut inconnu" % skill["id"])
	var point_buy: Dictionary = db.rules.get("point_buy", {})
	var costs: Dictionary = point_buy.get("costs", {})
	for value in range(int(point_buy.get("min", 8)), int(point_buy.get("max", 15)) + 1):
		if not costs.has(str(value)):
			errors.append("rules.json : point_buy.costs ne donne pas le coût de %d" % value)
	if point_buy.get("bonuses", []).size() > db.abilities.size():
		errors.append("rules.json : trop de bonus d'attributs dans point_buy.bonuses")


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


static func _validate_backgrounds(db: Node, errors: Array[String]) -> void:
	for background: Dictionary in db.backgrounds.values():
		var ctx := "backgrounds.json › %s" % background["id"]
		if background.get("skills", []).is_empty():
			errors.append(ctx + " : aucune compétence maîtrisée")
		_validate_skills_and_items(db, background, ctx, errors)


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
		match type:
			"add_item", "remove_item":
				_expect_ref(db.items, e["id"], "objet", ctx, errors)
			"ability":
				_expect_ref(db.abilities, e["id"], "attribut", ctx, errors)
			"goto":
				_expect_ref(db.events, e["event"], "événement", ctx, errors)
			"unlock":
				_validate_unlock_id(db, e["id"], ctx, errors)


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
