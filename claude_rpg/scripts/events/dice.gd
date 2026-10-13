class_name Dice
extends RefCounted
## Système de dés : réserves de d10 à succès (voir docs/systeme_de_jeu.md).
##
## Un jet lance N d10 (N = rang de la compétence) contre un **seuil** (souvent la valeur d'un attribut) :
## chaque dé inférieur ou égal au seuil est un **succès**. Un 9 ou un 10 n'en donne jamais ; un 1 en
## donne toujours et se relance (il peut redonner un succès, ou un 1 relancé à son tour). Le jet réussit
## si le nombre de succès atteint la **difficulté** ; les succès au-delà sont des succès supplémentaires.
##   - seuil au-dessus de 8 : autant de dés en plus, au seuil 8 ;
##   - moins d'un dé (malus) : on lance 1 dé et le seuil baisse d'autant ;
##   - option « dés nombreux » (Meta.settings › many_dice) : chaque tranche de 10 dés est remplacée par
##     seuil + 1 succès automatiques ;
##   - réussite critique N : N × 3 succès supplémentaires (rules.json › dice › critical_step) ;
##   - échec critique : aucun succès.
##
## Un test s'écrit {"skill": "physique", "difficulty": 2} (avec le meilleur attribut de la compétence),
## {"skill": "persuasion", "ability": "str", "difficulty": 2} (attribut imposé : intimider),
## {"ability": "dex", "difficulty": 1} (attribut seul : rules.json › dice › attribute_dice dés) ou
## {"resist": "con", "difficulty": 1} (résister : voir Character.resist_pool).
## "bonus" : dés en plus (ou en moins) ; "advantage": true / "disadvantage": true : difficulté −1 / +1.

const MAX_FACE_SUCCESS := 8  # un 9 ou un 10 n'est jamais un succès
const MAX_CHAIN := 20  # garde-fou pour les 1 relancés en chaîne

static var _term_regex := RegEx.create_from_string("([+-]?)\\s*(?:(\\d*)d(\\d+)|(\\d+))")


static func setting(key: String, default: Variant) -> Variant:
	return DB.rules.get("dice", {}).get(key, default)


# --- Réserves de d10 ---------------------------------------------------------------------

## Ramène une réserve à des valeurs jouables : {"count", "threshold", "auto"} (auto : succès
## automatiques de la règle des dés nombreux).
static func normalize(count: int, threshold: int, many_dice := false) -> Dictionary:
	if threshold > MAX_FACE_SUCCESS:
		count += threshold - MAX_FACE_SUCCESS
		threshold = MAX_FACE_SUCCESS
	if count < 1:
		threshold -= 1 - count
		count = 1
	var auto := 0
	if many_dice:
		while count >= 10:
			count -= 10
			auto += maxi(0, threshold) + 1
	return {"count": count, "threshold": threshold, "auto": auto}


static func many_dice_enabled() -> bool:
	return Meta != null and Meta.settings.get("many_dice", false)


## Un dé est-il un succès ?
static func is_success(value: int, threshold: int) -> bool:
	return value == 1 or (value <= threshold and value <= MAX_FACE_SUCCESS)


## Lance une réserve. `crit_rerolls` : nombre de fois où l'on peut relancer les dés en échec (dégâts
## d'une réussite critique) ; les dés nés d'un 1 ne sont pas relancés ainsi, mais un dé relancé qui fait
## 1 se relance comme d'habitude.
## Retourne {"dice": [{"sides": 10, "value", "success", "extra"?: né d'un 1, "dropped"?: relancé},
##   ...], "successes", "count", "threshold", "auto"}.
static func roll_pool(rng: RandomNumberGenerator, count: int, threshold: int, crit_rerolls := 0) -> Dictionary:
	var pool := normalize(count, threshold, many_dice_enabled())
	var t: int = pool["threshold"]
	var dice: Array[Dictionary] = []
	var successes: int = pool["auto"]
	var primaries: Array[int] = []  # index des dés relançables par un critique
	for i in int(pool["count"]):
		primaries.append(dice.size())
		successes += _roll_die(rng, t, dice, false)
	for pass_index in crit_rerolls:
		var rerolled := false
		for k in primaries.size():
			var index := primaries[k]
			if dice[index]["success"]:
				continue
			dice[index]["dropped"] = true
			primaries[k] = dice.size()
			successes += _roll_die(rng, t, dice, false, true)
			rerolled = true
		if not rerolled:
			break
	return {"dice": dice, "successes": successes, "count": pool["count"], "threshold": t, "auto": pool["auto"]}


## Lance un dé (et ses relances sur 1) ; retourne le nombre de succès.
static func _roll_die(rng: RandomNumberGenerator, threshold: int, dice: Array[Dictionary], extra: bool,
		crit := false) -> int:
	var successes := 0
	var chained := extra
	for i in MAX_CHAIN:
		var value := rng.randi_range(1, 10)
		var success := is_success(value, threshold)
		var die := {"sides": 10, "value": value, "success": success}
		if chained:
			die["extra"] = true
		if crit:
			die["crit"] = true
		dice.append(die)
		if success:
			successes += 1
		if value != 1:
			break
		chained = true
	return successes


## Niveau de réussite critique : N pour N × critical_step succès supplémentaires (0 sinon).
## `bonus` : succès supplémentaires comptés en plus pour le critique (attaque surprise : 2).
static func critical_level(extra: int, bonus := 0) -> int:
	if extra < 0:
		return 0
	return maxi(0, int(floor((extra + bonus) / float(setting("critical_step", 3)))))


## Résultat d'un jet contre une difficulté : {"successes", "difficulty", "success", "extra",
## "critical": niveau, "fumble": aucun succès}.
static func judge(successes: int, difficulty: int, crit_bonus := 0) -> Dictionary:
	var success := successes >= difficulty
	var extra := successes - difficulty
	return {"successes": successes, "difficulty": difficulty, "success": success, "extra": extra,
		"critical": critical_level(extra, crit_bonus) if success else 0, "fumble": successes == 0}


## Probabilités du nombre de succès d'une réserve : tableau P[k] (k de 0 à `cap`).
static func distribution(count: int, threshold: int, cap := 30) -> PackedFloat64Array:
	var pool := normalize(count, threshold, many_dice_enabled())
	var t: int = pool["threshold"]
	var p_one := 0.1
	var p_success := clampf((mini(t, MAX_FACE_SUCCESS) - 1) / 10.0, 0.0, 0.7)
	var p_fail := 1.0 - p_one - p_success
	# Un dé : G(x) = (p_fail + p_success x) / (1 − 0,1 x).
	var single := PackedFloat64Array()
	single.resize(cap + 1)
	single[0] = p_fail
	for k in range(1, cap + 1):
		single[k] = p_one * single[k - 1] + (p_success if k == 1 else 0.0)
	var result := PackedFloat64Array()
	result.resize(cap + 1)
	result[mini(int(pool["auto"]), cap)] = 1.0
	for i in int(pool["count"]):
		var next := PackedFloat64Array()
		next.resize(cap + 1)
		for a in cap + 1:
			if result[a] == 0.0:
				continue
			for b in cap + 1 - a:
				next[a + b] += result[a] * single[b]
		result = next
	return result


## Probabilité d'obtenir au moins `difficulty` succès.
static func chance(count: int, threshold: int, difficulty: int) -> float:
	if difficulty <= 0:
		return 1.0
	var p := 0.0
	var dist := distribution(count, threshold)
	for k in range(difficulty, dist.size()):
		p += dist[k]
	return clampf(p, 0.0, 1.0)


## Nombre moyen de succès d'une réserve.
static func expected(count: int, threshold: int) -> float:
	var pool := normalize(count, threshold, many_dice_enabled())
	var per_die := clampf(mini(int(pool["threshold"]), MAX_FACE_SUCCESS) / 10.0, 0.1, 0.8) / 0.9
	return int(pool["auto"]) + int(pool["count"]) * per_die


## Notation d'une réserve : « 3d10 ≤ 5 ».
static func pool_text(count: int, threshold: int) -> String:
	var pool := normalize(count, threshold)
	return "%dd10 ≤ %d" % [int(pool["count"]), int(pool["threshold"])]


# --- Tests (événements, actions sociales, fabrication) -------------------------------------

## Difficulté d'un test ("difficulty", ou ancien "dc" converti), avec avantage (−1) et désavantage (+1).
static func difficulty_of(check: Dictionary) -> int:
	var difficulty := int(check.get("difficulty", dc_to_difficulty(int(check.get("dc", 10)))))
	if check.get("advantage", false):
		difficulty -= 1
	if check.get("disadvantage", false):
		difficulty += 1
	return maxi(0, difficulty)


## Ancien DD (d20) -> difficulté : 11 ou moins -> 1, 12-14 -> 2, 15-17 -> 3, 18-20 -> 4, 21+ -> 5.
static func dc_to_difficulty(dc: int) -> int:
	return clampi(int(floor((dc - 9) / 3.0)) + 1, 1, 8)


## Attributs entre lesquels le joueur peut choisir pour ce test (vide si l'attribut est imposé ou unique).
static func ability_options(check: Dictionary) -> Array:
	if not check.has("skill") or check.has("ability"):
		return []
	var abilities := Skills.abilities_of(check["skill"])
	return abilities if abilities.size() > 1 else []


## Réserve d'un personnage pour un test : {"count", "threshold"}.
static func check_pool(ch: Character, check: Dictionary) -> Dictionary:
	var bonus := int(check.get("bonus", 0))
	if ch != null and check.has("skill") and Modifiers.grants(ch.modifiers(), "skill_advantage", check["skill"]):
		bonus += 1
	if check.has("skill"):
		return ch.skill_pool(check["skill"], check.get("ability", ""), bonus)
	if check.has("resist") or check.has("save"):
		return ch.resist_pool(check.get("resist", check.get("save", "con")), bonus)
	return ch.ability_pool(check.get("ability", "str"), bonus)


static func label(check: Dictionary) -> String:
	return Loc.ui("%s, difficulté %d") % [stat_name(check), difficulty_of(check)]


## Nom de la compétence ou de l'attribut testé.
static func stat_name(check: Dictionary) -> String:
	if check.has("skill"):
		if check.has("ability"):
			return "%s (%s)" % [Skills.name_of(check["skill"]), Abilities.short_of(check["ability"])]
		return Skills.name_of(check["skill"])
	if check.has("resist") or check.has("save"):
		return Loc.ui("Résister (%s)") % Abilities.name_of(check.get("resist", check.get("save", "con")))
	return Abilities.name_of(check.get("ability", "str"))


static func success_chance(ch: Character, check: Dictionary) -> float:
	if reliable(ch, check) and difficulty_of(check) <= 1:
		return 1.0
	var pool := check_pool(ch, check)
	return chance(int(pool["count"]), int(pool["threshold"]), difficulty_of(check))


## Talent fiable : un test d'une compétence entraînée a toujours au moins un succès.
static func reliable(ch: Character, check: Dictionary) -> bool:
	return check.has("skill") and ch.is_trained(check["skill"]) and ch.has_modifier("reliable_talent")


## Lance un test. Retourne le jugement (voir judge) + {"dice", "count", "threshold", "label", "stat",
## "text"} ; "text" résume le jet (« Physique 3d10 ≤ 5 : 2 succès contre difficulté 2 — réussite »).
static func roll_check(ch: Character, check: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var pool := check_pool(ch, check)
	var roll := roll_pool(rng, int(pool["count"]), int(pool["threshold"]))
	if reliable(ch, check):
		roll["successes"] = maxi(1, int(roll["successes"]))
	var result := judge(int(roll["successes"]), difficulty_of(check))
	result.merge(roll)
	result["pool"] = true  # pour le plateau de dés
	result["label"] = label(check)
	result["stat"] = stat_name(check)
	result["text"] = describe(result["stat"], result)
	return result


## Texte d'un jet jugé : « Physique : 3d10 ≤ 5, 2 succès pour une difficulté de 2 — réussite ».
static func describe(stat: String, result: Dictionary) -> String:
	return Loc.ui("%s : %s, %d succès pour une difficulté de %d — %s") % [stat,
		pool_text(int(result["count"]), int(result["threshold"])), int(result["successes"]), int(result["difficulty"]),
		verdict(result)]


## « réussite », « réussite critique 2 », « échec », « échec critique ».
static func verdict(result: Dictionary) -> String:
	if result["success"]:
		var level := int(result.get("critical", 0))
		if level > 0:
			return Loc.ui("réussite critique") + (" %d" % level if level > 1 else "")
		return Loc.ui("réussite")
	return Loc.ui("échec critique") if result.get("fumble", false) else Loc.ui("échec")


# --- Expressions de dés classiques (or trouvé, tirages hors règles) ------------------------

## Vérifie qu'une expression de dés est valide : « 2d6+3 », « 1d10 », « 3d4+1d6-1 », « 5 ».
static func is_valid_expr(expr: String) -> bool:
	var compact := expr.replace(" ", "")
	if compact == "":
		return false
	var rebuilt := ""
	for m in _term_regex.search_all(compact):
		rebuilt += m.get_string()
	return rebuilt == compact and not compact.begins_with("+")


## Lance une expression de dés. Retourne {"dice": [{"sides", "value"}...], "bonus": int, "total": int}.
static func roll_expr(expr: String, rng: RandomNumberGenerator) -> Dictionary:
	var dice: Array[Dictionary] = []
	var bonus := 0
	var total := 0
	for m in _term_regex.search_all(expr.replace(" ", "")):
		var sign := -1 if m.get_string(1) == "-" else 1
		if m.get_string(3) != "":
			var count := int(m.get_string(2)) if m.get_string(2) != "" else 1
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
