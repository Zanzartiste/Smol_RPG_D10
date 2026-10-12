class_name Conditions
extends RefCounted
## Évaluation des conditions décrites dans les JSON (événements et choix).
## Une liste de conditions est un ET logique ; utiliser "any" pour un OU, "not" pour une négation.
## Référence du format : docs/modele_donnees.md

## type -> champs obligatoires (utilisé par DataValidator)
const SCHEMA := {
	"flag": ["id"],
	"world_flag": ["id"],
	"unlocked": ["id"],
	"seen": ["event"],
	"ability": ["id"],
	"skill_proficient": ["id"],
	"race": ["in"],
	"class": ["in"],
	"life_stage": ["in"],
	"age": [],
	"gold": [],
	"item": ["id"],
	"time": ["in"],
	"level": [],
	"not": ["condition"],
	"any": ["conditions"],
}


static func check_all(conditions: Array, life: LifeState, meta: MetaState) -> bool:
	for c: Dictionary in conditions:
		if not check(c, life, meta):
			return false
	return true


static func check(c: Dictionary, life: LifeState, meta: MetaState) -> bool:
	var ch := life.character
	match String(c.get("type", "")):
		"flag":
			return life.has_flag(c["id"])
		"world_flag":
			return meta.has_world_flag(c["id"])
		"unlocked":
			return meta.is_unlocked(c["id"])
		"seen":
			return life.seen.has(c["event"])
		"ability":
			return _in_range(int(ch.abilities.get(c["id"], 10)), c)
		"skill_proficient":
			return ch.is_proficient(c["id"])
		"race":
			return ch.race_id in c["in"]
		"class":
			return ch.class_id in c["in"]
		"life_stage":
			return ch.life_stage() in c["in"]
		"age":
			return _in_range(ch.age_years(), c)
		"gold":
			return _in_range(ch.gold, c)
		"item":
			return ch.item_count(c["id"]) >= int(c.get("min", 1))
		"time":
			return life.slot_id() in c["in"]
		"level":
			return _in_range(ch.level, c)
		"not":
			return not check(c["condition"], life, meta)
		"any":
			for sub: Dictionary in c["conditions"]:
				if check(sub, life, meta):
					return true
			return false
	push_warning("Condition inconnue : %s" % c)
	return false


## Texte court expliquant une condition au joueur (ex. « INT 12+ »).
## Retourne "" pour les conditions qu'on ne veut pas dévoiler (flags...).
static func describe(c: Dictionary) -> String:
	match String(c.get("type", "")):
		"ability":
			return _range_text(DB.abilities[c["id"]]["short"], c)
		"skill_proficient":
			return Loc.ui("Maîtrise : %s") % DB.skills[c["id"]]["name"]
		"race":
			return " / ".join(PackedStringArray(c["in"].map(func(id): return DB.races[id]["name"])))
		"class":
			return " / ".join(PackedStringArray(c["in"].map(func(id): return DB.classes[id]["name"])))
		"life_stage":
			return " / ".join(PackedStringArray(c["in"].map(DB.life_stage_name)))
		"age":
			return _range_text(Loc.ui("Âge"), c)
		"gold":
			return _range_text(Loc.ui("Or"), c)
		"item":
			return "%s ×%d" % [DB.items[c["id"]]["name"], int(c.get("min", 1))]
		"time":
			var names := []
			for slot: Dictionary in DB.time_slots():
				if slot["id"] in c["in"]:
					names.append(slot["name"])
			return " / ".join(PackedStringArray(names))
		"level":
			return _range_text(Loc.ui("Niveau"), c)
	return ""


static func _in_range(value: float, c: Dictionary) -> bool:
	if c.has("min") and value < float(c["min"]):
		return false
	if c.has("max") and value > float(c["max"]):
		return false
	return true


static func _range_text(label: String, c: Dictionary) -> String:
	if c.has("min") and c.has("max"):
		return "%s %d-%d" % [label, int(c["min"]), int(c["max"])]
	if c.has("min"):
		return "%s %d+" % [label, int(c["min"])]
	if c.has("max"):
		return "%s ≤ %d" % [label, int(c["max"])]
	return label
