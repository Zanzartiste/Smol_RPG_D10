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
	"passive": ["skill", "min"],
	"reputation": ["location"],  # {"location", "min"?, "max"?} : réputation du héros dans un lieu
	"quest": ["id"],  # {"id", "status"?: active | done | failed | none, "step"?: minimum} (voir Quests)
	"species": ["in"],
	"class": ["in"],
	"background": ["in"],
	"size": [],  # "in": [valeurs], ou "min" / "max" sur l'échelle de −4 à 5
	"gender": ["in"],
	"life_stage": ["in"],
	"age": [],
	"gold": [],
	"item": ["id"],
	"companion": ["id"],
	"has_feat": ["id"],
	"equipped": ["id"],
	"defense": ["kind", "id"],
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
			return _in_range(ch.ability_score(c["id"]), c)
		"skill_proficient":
			return ch.is_proficient(c["id"])
		"passive":
			return ch.passive(c["skill"]) >= int(c["min"])
		"reputation":
			var value := int(life.reputation.get(c["location"], 0))
			return value >= int(c.get("min", -100)) and value <= int(c.get("max", 100))
		"quest":
			var state: Dictionary = life.quests.get(c["id"], {})
			var status: String = c.get("status", "active")
			if status == "none":
				return state.is_empty()
			return state.get("status", "") == status and int(state.get("step", 0)) >= int(c.get("step", 0))
		"species":
			return ch.species_id in c["in"]
		"class":
			return c["in"].any(func(cls): return ch.has_class(cls))
		"background":
			return ch.background_id in c["in"]
		"size":
			if c.has("in"):
				return ch.size() in c["in"].map(func(v): return int(v))
			return ch.size() >= int(c.get("min", -99)) and ch.size() <= int(c.get("max", 99))
		"gender":
			return ch.gender in c["in"]
		"life_stage":
			return ch.life_stage() in c["in"]
		"age":
			return _in_range(ch.age_years(), c)
		"gold":
			return _in_range(ch.gold, c)
		"item":
			return ch.item_count(c["id"]) >= int(c.get("min", 1))
		"companion":
			return life.has_companion(c["id"])
		"has_feat":
			return ch.has_feat(c["id"])
		"equipped":
			return c["id"] in ch.equipment.values()
		"defense":
			return ch.all_defenses().has(c["kind"], c["id"])
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
			return _range_text(Abilities.short_of(c["id"]), c)
		"skill_proficient":
			return Loc.ui("Maîtrise : %s") % Skills.name_of(c["id"])
		"has_feat":
			return Loc.ui("Don : %s") % Feats.name_of(c["id"])
		"equipped":
			return Loc.ui("Équipé : %s") % Equipment.name_of(c["id"])
		"species":
			return " / ".join(PackedStringArray(c["in"].map(func(id): return DB.species[id]["name"])))
		"class":
			return " / ".join(PackedStringArray(c["in"].map(func(id): return DB.classes[id]["name"])))
		"background":
			return Loc.ui("Passé : %s") % " / ".join(PackedStringArray(c["in"].map(
				func(id): return DB.backgrounds[id]["name"])))
		"size":
			if c.has("in"):
				return Loc.ui("Taille : %s") % " / ".join(PackedStringArray(c["in"].map(DB.size_name)))
			if c.has("max"):
				return Loc.ui("Taille %s ou moins") % DB.size_name(c["max"]).to_lower()
			return Loc.ui("Taille %s ou plus") % DB.size_name(c["min"]).to_lower()
		"gender":
			return " / ".join(PackedStringArray(c["in"].map(DB.gender_name)))
		"life_stage":
			return " / ".join(PackedStringArray(c["in"].map(DB.life_stage_name)))
		"age":
			return _range_text(Loc.ui("Âge"), c)
		"gold":
			return _range_text(Loc.ui("Or"), c)
		"item":
			return "%s ×%d" % [Items.name_of(c["id"]), int(c.get("min", 1))]
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
