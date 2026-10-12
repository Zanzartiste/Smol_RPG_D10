class_name Dice
extends RefCounted
## Tests de caractéristique façon d20 : d20 + modificateur >= DD.
## Comme dans Baldur's Gate 3, un 20 naturel réussit toujours et un 1 naturel échoue toujours.
## Un test s'écrit {"skill": "athletics", "dc": 12} ou {"ability": "dex", "dc": 12}.


static func modifier(ch: Character, check: Dictionary) -> int:
	if check.has("skill"):
		return ch.skill_mod(check["skill"])
	return ch.ability_mod(check.get("ability", "str"))


static func label(check: Dictionary) -> String:
	var stat_name: String
	if check.has("skill"):
		stat_name = DB.skills[check["skill"]]["name"]
	else:
		stat_name = DB.abilities[check["ability"]]["name"]
	return Loc.ui("%s DD %d") % [stat_name, int(check["dc"])]


static func success_chance(ch: Character, check: Dictionary) -> float:
	var needed := int(check["dc"]) - modifier(ch, check)  # résultat minimum au d20
	return clampf((21 - needed) / 20.0, 0.05, 0.95)


static func roll_check(ch: Character, check: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var die := rng.randi_range(1, 20)
	var mod := modifier(ch, check)
	var dc := int(check["dc"])
	var success := die == 20 or (die != 1 and die + mod >= dc)
	return {
		"dice": [{"sides": 20, "value": die}],
		"die": die,
		"mod": mod,
		"total": die + mod,
		"dc": dc,
		"success": success,
		"label": label(check),
		"stat": DB.skills[check["skill"]]["name"] if check.has("skill") else DB.abilities[check["ability"]]["name"],
	}
