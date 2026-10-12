class_name Dice
extends RefCounted
## Tests de caractéristique façon d20 : d20 + modificateur >= DD.
## Comme dans Baldur's Gate 3, un 20 naturel réussit toujours et un 1 naturel échoue toujours.
## Un test s'écrit {"skill": "athletics", "dc": 12}, {"ability": "dex", "dc": 12}
## ou {"save": "con", "dc": 12} (jet de sauvegarde : maîtrise si la classe le maîtrise).


static var _term_regex := RegEx.create_from_string("([+-]?)\\s*(?:(\\d*)d(\\d+)|(\\d+))")


## Vérifie qu'une expression de dés est valide : « 2d6+3 », « 1d10 », « 3d4+1d6-1 », « 5 ».
static func is_valid_expr(expr: String) -> bool:
	var compact := expr.replace(" ", "")
	if compact == "":
		return false
	var rebuilt := ""
	for m in _term_regex.search_all(compact):
		rebuilt += m.get_string()
	return rebuilt == compact and not compact.begins_with("+")


## Lance une expression de dés. `critical` double le nombre de dés (coup critique).
## Retourne {"dice": [{"sides", "value"}...], "bonus": int, "total": int}.
static func roll_expr(expr: String, rng: RandomNumberGenerator, critical := false) -> Dictionary:
	var dice: Array[Dictionary] = []
	var bonus := 0
	var total := 0
	for m in _term_regex.search_all(expr.replace(" ", "")):
		var sign := -1 if m.get_string(1) == "-" else 1
		if m.get_string(3) != "":
			var count := int(m.get_string(2)) if m.get_string(2) != "" else 1
			if critical:
				count *= 2
			for i in count:
				var value := rng.randi_range(1, int(m.get_string(3)))
				dice.append({"sides": int(m.get_string(3)), "value": value})
				total += sign * value
		else:
			bonus += sign * int(m.get_string(4))
	total += bonus
	return {"dice": dice, "bonus": bonus, "total": total}


## Valeur moyenne d'une expression (ex. « 2d6+3 » -> 10.0).
static func average(expr: String) -> float:
	var total := 0.0
	for m in _term_regex.search_all(expr.replace(" ", "")):
		var sign := -1.0 if m.get_string(1) == "-" else 1.0
		if m.get_string(3) != "":
			var count := int(m.get_string(2)) if m.get_string(2) != "" else 1
			total += sign * count * (int(m.get_string(3)) + 1) / 2.0
		else:
			total += sign * int(m.get_string(4))
	return total


## Ajoute un modificateur à une expression : add_mod("1d8", 3) -> "1d8+3", add_mod("1d8", -1) -> "1d8-1".
static func add_mod(expr: String, mod: int) -> String:
	if mod == 0:
		return expr
	return "%s%s%d" % [expr, "+" if mod > 0 else "-", absi(mod)]


static func modifier(ch: Character, check: Dictionary) -> int:
	if check.has("skill"):
		return ch.skill_mod(check["skill"])
	if check.has("save"):
		return ch.save_mod(check["save"])
	return ch.ability_mod(check.get("ability", "str"))


## Talent fiable : un test de compétence maîtrisée ne descend jamais sous 10 au d20.
static func minimum_die(ch: Character, check: Dictionary) -> int:
	if check.has("skill") and ch.is_proficient(check["skill"]) and ch.has_modifier("reliable_talent"):
		return 10
	return 1


static func label(check: Dictionary) -> String:
	return Loc.ui("%s DD %d") % [stat_name(check), int(check["dc"])]


## Nom de la compétence ou de l'attribut testé.
static func stat_name(check: Dictionary) -> String:
	if check.has("skill"):
		return Skills.name_of(check["skill"])
	if check.has("save"):
		return Loc.ui("Sauvegarde de %s") % Abilities.name_of(check["save"])
	return Abilities.name_of(check.get("ability", "str"))


static func success_chance(ch: Character, check: Dictionary) -> float:
	var needed := int(check["dc"]) - modifier(ch, check)  # résultat minimum au d20
	if minimum_die(ch, check) + modifier(ch, check) >= int(check["dc"]):
		return 1.0
	return clampf((21 - needed) / 20.0, 0.05, 0.95)


static func roll_check(ch: Character, check: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var die := maxi(rng.randi_range(1, 20), minimum_die(ch, check))
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
		"stat": stat_name(check),
	}
