class_name Feats
extends RefCounted
## API des dons (Vigilant, Robuste…). Définitions : data/feats.json.
## Un don a des prérequis (mêmes conditions que les événements, évaluées sur le personnage)
## et des modificateurs (voir Modifiers) appliqués automatiquement au personnage qui le possède.
## On obtient un don : par son passé (backgrounds.json › feat), aux niveaux d'amélioration
## (voir Progression, au choix du joueur), ou par un événement (effet add_feat).
## Catégories : "origin" (dons d'origine, ceux des passés) et "general".


static func ids() -> Array[String]:
	var result: Array[String] = []
	result.assign(DB.feats.keys())
	return result


static func all() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	result.assign(DB.feats.values())
	return result


static func has(id: String) -> bool:
	return DB.feats.has(id)


static func name_of(id: String) -> String:
	return DB.feats.get(id, {}).get("name", id)


static func description_of(id: String) -> String:
	return DB.feats.get(id, {}).get("description", "")


static func category_of(id: String) -> String:
	return DB.feats.get(id, {}).get("category", "general")


## Description complète : texte + effets, ex. « Votre endurance… (+2 PV par niveau) ».
static func summary_of(id: String) -> String:
	var mods := Modifiers.describe_all(modifiers_of(id))
	return description_of(id) + (" (%s)" % mods if mods != "" else "")


## Don accordé par un passé ("" si aucun).
static func for_background(background_id: String) -> String:
	return DB.backgrounds.get(background_id, {}).get("feat", "")


static func modifiers_of(id: String) -> Array:
	return DB.feats.get(id, {}).get("modifiers", [])


## Prérequis remplis ? Seules les conditions portant sur le personnage ont du sens ici
## (ability, level, species, class, background, skill_proficient, size...).
static func meets_prerequisites(id: String, ch: Character) -> bool:
	var life := LifeState.new()
	life.character = ch
	return Conditions.check_all(DB.feats.get(id, {}).get("prerequisites", []), life, null)
