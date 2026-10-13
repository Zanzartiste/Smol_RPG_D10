class_name Skills
extends RefCounted
## API des compétences (Physique, Furtivité, Armes de mêlée…). Définitions : data/skills.json.
##   {"id", "name", "category": combat | social | roguery | knowledge,
##    "abilities": attributs utilisables (le meilleur par défaut, sauf si le test en impose un),
##    "instinctive"?: true, "base_rank"?, "caster_base_rank"?}
## Chaque compétence a un **rang** : 1 au départ, 2 si elle est instinctive (Magie : 0, ou 2 pour un
## lanceur de sorts). Le passé, la classe, les dons et l'équipement ajoutent des rangs (modificateur
## "skill_rank"). Un test lance [rang] d10 contre un seuil égal à l'attribut (voir Dice).

const CATEGORY_NAMES := {"combat": "Combat", "social": "Social", "roguery": "Roublardise", "knowledge": "Connaissances et métiers"}
## Anciennes compétences (D&D) -> nouvelles, pour les anciennes sauvegardes et les anciens tests.
const ALIASES := {
	"athletics": "physique", "acrobatics": "physique", "arcana": "lore", "history": "lore", "nature": "lore",
	"religion": "lore", "investigation": "perception", "deception": "persuasion", "intimidation": "persuasion",
	"performance": "arts",
}


## Ids dans l'ordre d'affichage.
static func ids() -> Array[String]:
	var result: Array[String] = []
	result.assign(DB.skills.keys())
	return result


static func all() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	result.assign(DB.skills.values())
	return result


static func has(id: String) -> bool:
	return DB.skills.has(id)


## Id actuel d'une compétence (traduit les anciens ids).
static func resolve(id: String) -> String:
	return ALIASES.get(id, id)


static func def(id: String) -> Dictionary:
	return DB.skills.get(resolve(id), {})


static func name_of(id: String) -> String:
	return def(id).get("name", id)


## Ce que fait la compétence (affiché au survol).
static func description_of(id: String) -> String:
	return def(id).get("description", "")


static func category_of(id: String) -> String:
	return def(id).get("category", "knowledge")


static func ids_in(category: String) -> Array[String]:
	var result: Array[String] = []
	for id in ids():
		if category_of(id) == category:
			result.append(id)
	return result


## Attributs utilisables (le premier est l'attribut « principal »).
static func abilities_of(id: String) -> Array:
	return def(id).get("abilities", ["str"])


## Attribut principal (ex. "physique" -> "str").
static func ability_of(id: String) -> String:
	return abilities_of(id)[0]


static func is_instinctive(id: String) -> bool:
	return def(id).get("instinctive", false)


## Rang de départ : 1, 2 si instinctive, ou la valeur de la compétence ("base_rank", "caster_base_rank").
static func base_rank(id: String, caster := false) -> int:
	var skill := def(id)
	if caster and skill.has("caster_base_rank"):
		return int(skill["caster_base_rank"])
	if skill.has("base_rank"):
		return int(skill["base_rank"])
	return 2 if is_instinctive(id) else 1


static func names_of(ids_list: Array) -> String:
	return ", ".join(PackedStringArray(ids_list.map(func(id): return name_of(id))))


# --- Langues (rules.json › languages) ------------------------------------------------

static func languages() -> Array:
	return DB.rules.get("languages", [])


static func language_name(id: String) -> String:
	for language: Dictionary in languages():
		if language["id"] == id:
			return language["name"]
	return id


## Langues connues de tous (le Commun).
static func common_languages() -> Array[String]:
	var result: Array[String] = []
	for language: Dictionary in languages():
		if language.get("known_by_all", false):
			result.append(language["id"])
	return result
