class_name PointBuy
extends RefCounted
## Répartition des attributs par achat de points, façon Baldur's Gate 3 / D&D 5e :
## chaque attribut part du minimum, les points s'achètent selon un barème (rules.json › point_buy),
## puis des bonus (+2 et +1) s'appliquent à des attributs différents.
## L'espèce n'a aucune influence sur les attributs.

var base: Dictionary = {}  # id d'attribut -> valeur avant bonus
var bonuses: Array = []  # bonuses[i] = id de l'attribut qui reçoit le i-ème bonus (ex. [+2, +1])


## Modèle proposé par une classe : répartition standard selon ses priorités,
## +2 sur l'attribut principal et +1 sur le secondaire.
static func from_class(class_id: String) -> PointBuy:
	var pb := PointBuy.new()
	var priority: Array = DB.classes[class_id]["ability_priority"]
	var scores: Array = DB.rules["standard_array"]
	for i in priority.size():
		pb.base[priority[i]] = int(scores[i])
	for i in bonus_amounts().size():
		pb.bonuses.append(priority[i])
	return pb


static func bonus_amounts() -> Array:
	return _rules().get("bonuses", [2, 1])


static func min_score() -> int:
	return int(_rules().get("min", 8))


static func max_score() -> int:
	return int(_rules().get("max", 15))


static func budget() -> int:
	return int(_rules().get("budget", 27))


static func cost_of(value: int) -> int:
	return int(_rules()["costs"].get(str(value), 999))


func spent() -> int:
	var total := 0
	for id: String in base:
		total += cost_of(base[id])
	return total


func remaining() -> int:
	return budget() - spent()


## Coût du prochain point dans cet attribut.
func next_cost(id: String) -> int:
	return cost_of(base[id] + 1) - cost_of(base[id])


func can_increase(id: String) -> bool:
	return base[id] < max_score() and next_cost(id) <= remaining()


func can_decrease(id: String) -> bool:
	return base[id] > min_score()


func increase(id: String) -> void:
	if can_increase(id):
		base[id] += 1


func decrease(id: String) -> void:
	if can_decrease(id):
		base[id] -= 1


## Attribue le bonus n° `index` à un attribut ; si un autre bonus y était déjà, les deux s'échangent.
func set_bonus(index: int, ability_id: String) -> void:
	var other := bonuses.find(ability_id)
	if other != -1 and other != index:
		bonuses[other] = bonuses[index]
	bonuses[index] = ability_id


func bonus_for(ability_id: String) -> int:
	var total := 0
	var amounts := bonus_amounts()
	for i in bonuses.size():
		if bonuses[i] == ability_id:
			total += int(amounts[i])
	return total


func final_score(ability_id: String) -> int:
	return base[ability_id] + bonus_for(ability_id)


func final_scores() -> Dictionary:
	var result := {}
	for id: String in base:
		result[id] = final_score(id)
	return result


func is_valid() -> bool:
	if remaining() < 0:
		return false
	for id: String in base:
		if base[id] < min_score() or base[id] > max_score():
			return false
	var distinct := {}
	for id in bonuses:
		distinct[id] = true
	return distinct.size() == bonuses.size()


static func _rules() -> Dictionary:
	return DB.rules.get("point_buy", {})
