class_name Progression
extends RefCounted
## API de la progression : niveaux, XP et améliorations. Réglages : data/rules.json
##   xp_by_level            : XP nécessaire pour chaque niveau (sa longueur fixe le niveau maximum)
##   advancement            : {"ability_levels": [...], "ability_points": N, "feat_levels": [...], "feats": N} :
##                            niveaux (de classe) qui donnent des points d'attribut, et ceux qui donnent des dons
##   max_ability_score?     : plafond d'un attribut augmenté par une amélioration (absent : pas de plafond)


static func max_level() -> int:
	return DB.rules.get("xp_by_level", [0]).size()


## XP totale nécessaire pour atteindre un niveau.
static func xp_for(level: int) -> int:
	var table: Array = DB.rules.get("xp_by_level", [0])
	return int(table[clampi(level - 1, 0, table.size() - 1)])


## Niveaux d'une liste de rules.json › advancement (entiers : le JSON donne des décimaux, et `4 in [4.0]`
## serait faux).
static func _levels(key: String) -> Array[int]:
	var result: Array[int] = []
	for level in DB.rules.get("advancement", {}).get(key, []):
		result.append(int(level))
	return result


## Points d'attribut gagnés en atteignant ce niveau de classe.
static func ability_points_at(level: int) -> int:
	return int(DB.rules.get("advancement", {}).get("ability_points", 0)) if level in _levels("ability_levels") else 0


## Dons gagnés en atteignant ce niveau de classe.
static func feats_at(level: int) -> int:
	return int(DB.rules.get("advancement", {}).get("feats", 0)) if level in _levels("feat_levels") else 0


static func is_advancement_level(level: int) -> bool:
	return ability_points_at(level) > 0 or feats_at(level) > 0


## Plafond d'un attribut augmenté par une amélioration (0 : aucun).
static func max_ability_score() -> int:
	return int(DB.rules.get("max_ability_score", 0))


## Texte annonçant l'amélioration d'un niveau, ex. « +1 point(s) d'attribut à choisir ».
static func advancement_text(level: int) -> String:
	var parts := PackedStringArray()
	if ability_points_at(level) > 0:
		parts.append(Loc.ui("+%d point(s) d'attribut") % ability_points_at(level))
	if feats_at(level) > 0:
		parts.append(Loc.ui("%d don(s)") % feats_at(level))
	return Loc.ui(" et ").join(parts) + Loc.ui(" à choisir")
