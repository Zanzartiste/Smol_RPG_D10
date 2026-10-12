class_name CreatorPoints
extends RefCounted
## API des Creator Points (méta-progression). Réglages : rules.json › creator_points.
## On en gagne à la mort selon le succès de la vie (XP gagnée par le héros) ; on les dépense à la création
## du personnage suivant : améliorations pour cette vie (upgrades) ou déblocage définitif d'une espèce /
## classe (champ "unlock_cost" dans species.json / classes.json).
##
## Une amélioration : {"id", "name", "description", "type": "point_buy" | "level" | "gold", "amount",
##                     "cost": N ou [coût du 1er rang, du 2e…], "max": nombre de rangs}


static func _settings() -> Dictionary:
	return DB.rules.get("creator_points", {})


## Points gagnés pour une vie qui a rapporté `xp` points d'expérience.
@warning_ignore("integer_division")
static func earned_for(xp: int) -> int:
	var per_point := maxi(1, int(_settings().get("xp_per_point", 100)))
	return maxi(int(_settings().get("min_per_life", 0)), xp / per_point)


static func upgrades() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	result.assign(_settings().get("upgrades", []))
	return result


static func upgrade(id: String) -> Dictionary:
	for u in upgrades():
		if u["id"] == id:
			return u
	return {}


static func max_rank(id: String) -> int:
	return int(upgrade(id).get("max", 1))


## Coût du rang `rank` (1 = premier achat) d'une amélioration.
static func rank_cost(id: String, rank: int) -> int:
	var cost: Variant = upgrade(id).get("cost", 0)
	if cost is Array:
		return int(cost[clampi(rank - 1, 0, cost.size() - 1)])
	return int(cost)


## Coût total d'un ensemble de rangs achetés {id: rang}.
static func total_cost(ranks: Dictionary) -> int:
	var total := 0
	for id: String in ranks:
		for rank in range(1, int(ranks[id]) + 1):
			total += rank_cost(id, rank)
	return total


## Bonus total d'un type d'amélioration ("point_buy", "level", "gold") pour des rangs achetés.
static func bonus(ranks: Dictionary, type: String) -> int:
	var total := 0
	for id: String in ranks:
		if upgrade(id).get("type") == type:
			total += int(upgrade(id).get("amount", 0)) * int(ranks[id])
	return total


## Applique au personnage les améliorations « level » et « gold » (le « point_buy » s'applique à la
## répartition des attributs, avant la création). Le niveau de départ donne l'XP correspondante et
## les améliorations des niveaux franchis (attribut, don) restent à choisir en jeu.
static func apply(ch: Character, ranks: Dictionary) -> void:
	var levels := bonus(ranks, "level")
	if levels > 0:
		ch.add_xp(Progression.xp_for(mini(ch.level + levels, Progression.max_level())) - ch.xp)
		ch.hp = ch.max_hp
	ch.gold += bonus(ranks, "gold")


## Coût de déblocage d'une espèce ou d'une classe ("species:elf", "class:rogue"), 0 si non achetable.
static func unlock_cost(unlock_id: String) -> int:
	var parts := unlock_id.split(":")
	if parts.size() != 2:
		return 0
	var table: Dictionary = DB.species if parts[0] == "species" else DB.classes
	return int(table.get(parts[1], {}).get("unlock_cost", 0))
