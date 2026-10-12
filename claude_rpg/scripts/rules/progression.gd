class_name Progression
extends RefCounted
## API de la progression : niveaux, XP, bonus de maîtrise et améliorations. Réglages : data/rules.json
##   xp_by_level            : XP nécessaire pour chaque niveau (sa longueur fixe le niveau maximum)
##   proficiency_by_level   : bonus de maîtrise par niveau
##   advancement_levels     : niveaux qui donnent une amélioration (par défaut tous les 4 niveaux)
##   advancement            : contenu d'une amélioration, ex. {"ability_points": 1, "feats": 1}
##   max_ability_score      : plafond d'un attribut augmenté par une amélioration


static func max_level() -> int:
	return DB.rules.get("xp_by_level", [0]).size()


## XP totale nécessaire pour atteindre un niveau.
static func xp_for(level: int) -> int:
	var table: Array = DB.rules.get("xp_by_level", [0])
	return int(table[clampi(level - 1, 0, table.size() - 1)])


static func proficiency_bonus(level: int) -> int:
	var table: Array = DB.rules.get("proficiency_by_level", [2])
	return int(table[clampi(level - 1, 0, table.size() - 1)])


## Niveaux qui donnent une amélioration (entiers : le JSON donne des décimaux, et `4 in [4.0]` serait faux).
static func advancement_levels() -> Array[int]:
	var result: Array[int] = []
	for level in DB.rules.get("advancement_levels", []):
		result.append(int(level))
	return result


static func is_advancement_level(level: int) -> bool:
	return level in advancement_levels()


## Points d'attribut gagnés à un niveau d'amélioration.
static func ability_points_per_advancement() -> int:
	return int(DB.rules.get("advancement", {}).get("ability_points", 0))


## Dons gagnés à un niveau d'amélioration.
static func feats_per_advancement() -> int:
	return int(DB.rules.get("advancement", {}).get("feats", 0))


static func max_ability_score() -> int:
	return int(DB.rules.get("max_ability_score", 20))


## Texte annonçant une amélioration, ex. « +1 point d'attribut et 1 don à choisir ».
static func advancement_text() -> String:
	var parts := PackedStringArray()
	if ability_points_per_advancement() > 0:
		parts.append(Loc.ui("+%d point(s) d'attribut") % ability_points_per_advancement())
	if feats_per_advancement() > 0:
		parts.append(Loc.ui("%d don(s)") % feats_per_advancement())
	return Loc.ui(" et ").join(parts) + Loc.ui(" à choisir")
