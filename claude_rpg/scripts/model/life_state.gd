class_name LifeState
extends RefCounted
## État d'une vie en cours : le personnage, le temps, les flags et l'historique des événements.
## Tout ce qui est ici disparaît à la mort (sauf ce que MetaState en retient).

var character: Character
var companions: Array[Character] = []
var rng := RandomNumberGenerator.new()
var day := 1
var slot := 0  # index dans DB.time_slots()
var flags: Dictionary = {}
var seen: Dictionary = {}  # id d'événement -> nombre de fois vu
var last_seen_day: Dictionary = {}  # id d'événement -> dernier jour où il a été vu
var dead := false
var death_cause := ""
var recorded := false  # déjà inscrite dans la chronique
var notices: Array[String] = []  # messages à afficher au prochain retour au hub


func slot_id() -> String:
	return DB.time_slots()[slot]["id"]


func slot_name() -> String:
	return DB.time_slots()[slot]["name"]


func has_flag(id: String) -> bool:
	return bool(flags.get(id, false))


func has_companion(template_id: String) -> bool:
	return companions.any(func(c): return c.template_id == template_id)


## Le héros puis ses compagnons.
func party() -> Array[Character]:
	var result: Array[Character] = [character]
	result.append_array(companions)
	return result


func mark_seen(event_id: String) -> void:
	seen[event_id] = int(seen.get(event_id, 0)) + 1
	last_seen_day[event_id] = day


func die(cause: String) -> void:
	if dead:
		return
	dead = true
	death_cause = cause
	character.hp = 0


func advance_time(slots: int) -> void:
	for i in slots:
		if dead:
			return
		slot += 1
		if slot >= DB.slots_per_day():
			slot = 0
			_new_day()


func take_notices() -> Array[String]:
	var result: Array[String] = notices.duplicate()
	notices.clear()
	return result


func _new_day() -> void:
	var old_age := character.age_years()
	var old_stage := character.life_stage()
	day += 1
	character.age_days += 1
	if character.age_years() != old_age:
		notices.append(Loc.ui("Vous avez maintenant %d ans.") % character.age_years())
		var stage := character.life_stage()
		if stage != old_stage:
			notices.append(Loc.ui("Nouvelle étape de vie : %s.") % DB.life_stage_name(stage))
		_check_old_age()


## Modifie un attribut. Un attribut qui tombe à 0 tue le personnage.
## Un changement de Constitution recalcule les PV (et peut aussi tuer si les PV tombent à 0).
func change_ability(ability_id: String, amount: int, cause: String) -> void:
	var value := clampi(int(character.abilities.get(ability_id, 10)) + amount, 0, 30)
	character.abilities[ability_id] = value
	if ability_id == "con":
		character.refresh_max_hp()
	if value <= 0 or character.hp <= 0:
		die(cause)


## Vieillesse : passé l'âge limite de l'espèce (aging_age), chaque nouvelle année retire 1
## à un attribut tiré au hasard. Le personnage finit par mourir quand l'un d'eux atteint 0.
func _check_old_age() -> void:
	var limit := int(DB.species[character.species_id].get("aging_age", 0))
	if limit <= 0 or character.age_years() <= limit:
		return
	var ids: Array = DB.abilities.keys()
	var id: String = ids[rng.randi_range(0, ids.size() - 1)]
	notices.append(Loc.ui("Le poids des ans : %s −1.") % DB.abilities[id]["name"])
	change_ability(id, -1, Loc.ui("Mort de vieillesse"))
