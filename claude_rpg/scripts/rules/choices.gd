class_name Choices
extends RefCounted
## API des choix à faire par le joueur : compétences de classe, ascendance, style de combat,
## sous-classe, options d'un don… Ils sont décrits dans les données ("choices") d'une espèce, d'une
## classe, d'une aptitude de classe (ou de sous-classe) ou d'un don :
##   {"id", "name", "type": "skill" | "ability" | "damage_type" | "feat" | "action" | "option" | "language",
##    "count"? (1), "options"? (ids, ou objets pour "option"), "default"? (ids),
##    "modifiers"? : modèles de modificateurs, "$" étant remplacé par la valeur choisie,
##    "from"? : "trained" (compétences déjà entraînées, pour l'Expertise),
##    "category"? : catégorie de don (type "feat"), "cost"? : ressource des actions choisies (type "action"),
##    "allow_repeat"? : la même valeur peut être choisie plusieurs fois (Amélioration d'attribut),
##    "at_creation"? : proposé à l'écran de création (sinon au hub, à la première occasion),
##    "multiclass"? : choix de classe aussi proposé (au hub) à qui prend cette classe en multiclassage}
## Type "action" : on ne propose ni une action déjà connue, ni un sort d'un niveau que le personnage ne
## peut pas encore lancer (sauf si le choix a un "cost" propre, comme Initié à la magie).
## Une option (type "option") est un objet {"id", "name", "description", "modifiers"?, "actions"?,
## "features"? (aptitudes par niveau : une sous-classe)}.
## Les valeurs choisies sont dans Character.choices, sous la clé « source/id du choix »
## (ex. "class/skills", "species/ancestry", "feat:skilled/skills", "feature:subclass/subclass").

const PLACEHOLDER := "$"


## Remplace "$" par la valeur choisie dans un modèle de modificateur.
static func fill(template: Dictionary, value: String) -> Dictionary:
	var result := {}
	for key: String in template:
		result[key] = value if typeof(template[key]) == TYPE_STRING and template[key] == PLACEHOLDER else template[key]
	return result


## Option (type "option") par son id.
static func option(spec: Dictionary, option_id: String) -> Dictionary:
	for o: Dictionary in spec.get("options", []):
		if o.get("id") == option_id:
			return o
	return {}


## Nom lisible d'une valeur choisie.
static func value_name(spec: Dictionary, value: String) -> String:
	match spec.get("type"):
		"skill":
			return Skills.name_of(value)
		"ability":
			return Abilities.name_of(value)
		"damage_type":
			return DamageTypes.name_of(value)
		"feat":
			return Feats.name_of(value)
		"action":
			return Actions.name_of(value)
		"language":
			return Skills.language_name(value)
		"option":
			return option(spec, value).get("name", value)
	return value


## Description d'une valeur (infobulle).
static func value_description(spec: Dictionary, value: String) -> String:
	match spec.get("type"):
		"feat":
			return Feats.summary_of(value)
		"action":
			return Actions.def(value).get("description", "") + " " + Actions.text_of(value)
		"option":
			return option(spec, value).get("description", "")
		"ability":
			return Abilities.description_of(value)
	return ""


## Valeurs proposées pour un choix (sans celles déjà prises, sauf allow_repeat).
static func options_for(spec: Dictionary, ch: Character, taken: Array) -> Array[String]:
	var candidates: Array = []
	match spec.get("type"):
		"skill":
			candidates = spec.get("options", Skills.ids())
		"ability":
			candidates = spec.get("options", Abilities.ids())
		"damage_type":
			candidates = spec.get("options", DamageTypes.ids())
		"feat":
			candidates = Feats.ids().filter(func(id): return Feats.category_of(id) == spec.get("category", Feats.category_of(id)) \
				and not ch.has_feat(id) and Feats.meets_prerequisites(id, ch))
		"action":
			var known: Array = ch._all_combat_actions()
			candidates = spec.get("options", []).filter(func(id): return id not in known and (spec.has("cost")
				or int(Actions.def(id).get("spell_level", 0)) <= ch.max_spell_level()))
		"option":
			candidates = spec.get("options", []).map(func(o): return o["id"])
		"language":
			candidates = Skills.languages().map(func(l): return l["id"]).filter(func(id): return id not in Skills.common_languages())
	var result: Array[String] = []
	for value: String in candidates:
		if value in taken and not spec.get("allow_repeat", false):
			continue
		if spec.get("type") == "skill":
			# Une compétence déjà donnée par le passé ne se choisit pas comme compétence de classe.
			if spec.get("id") == "skills" and spec.get("from", "") == "" \
					and value in DB.backgrounds.get(ch.background_id, {}).get("skills", []):
				continue
			if spec.get("from") == "trained" and not ch.is_trained(value):
				continue
		result.append(value)
	return result


## Modificateurs accordés par des valeurs choisies.
static func modifiers_from(spec: Dictionary, values: Array) -> Array:
	var result: Array = []
	for value: String in values:
		for template: Dictionary in spec.get("modifiers", []):
			result.append(fill(template, value))
		if spec.get("type") == "option":
			result.append_array(option(spec, value).get("modifiers", []))
	return result


## Actions accordées par des valeurs choisies (ids, éventuellement « action|coût »).
static func actions_from(spec: Dictionary, values: Array) -> Array:
	var result: Array = []
	for value: String in values:
		if spec.get("type") == "action":
			result.append(value + ("|" + spec["cost"] if spec.has("cost") else ""))
		elif spec.get("type") == "option":
			result.append_array(option(spec, value).get("actions", []))
	return result


## Aptitudes accordées par des options choisies (sous-classe), tous niveaux confondus.
static func features_from(spec: Dictionary, values: Array) -> Array:
	var result: Array = []
	if spec.get("type") == "option":
		for value: String in values:
			result.append_array(option(spec, value).get("features", []))
	return result
