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
## Combat déclenché mais pas encore terminé : il reprend au chargement d'une sauvegarde
## (quitter le jeu ne permet pas d'esquiver un combat).
var pending_combat: Dictionary = {}


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


## Modifie la valeur de base d'un attribut. Un attribut qui tombe à 0 tue le personnage.
## Les PV sont recalculés (la CON en dépend) : s'ils tombent à 0, le personnage meurt aussi.
func change_ability(ability_id: String, amount: int, cause: String) -> void:
	character.abilities[ability_id] = clampi(int(character.abilities.get(ability_id, 10)) + amount, 0, 30)
	character.refresh_max_hp()
	if character.ability_score(ability_id) <= 0 or character.hp <= 0:
		die(cause)


## Vieillesse : passé l'âge limite de l'espèce (aging_age), chaque nouvelle année retire 1
## à un attribut tiré au hasard. Le personnage finit par mourir quand l'un d'eux atteint 0.
func _check_old_age() -> void:
	var limit := int(DB.species[character.species_id].get("aging_age", 0))
	if limit <= 0 or character.age_years() <= limit:
		return
	var ids := Abilities.ids()
	var id: String = ids[rng.randi_range(0, ids.size() - 1)]
	notices.append(Loc.ui("Le poids des ans : %s −1.") % Abilities.name_of(id))
	change_ability(id, -1, Loc.ui("Mort de vieillesse"))


# --- Sauvegarde ----------------------------------------------------------------

# --- Sac du groupe -------------------------------------------------------------
# Le sac est celui du héros (character.inventory) : les compagnons s'équipent et se soignent en y
# puisant, et ce qu'ils retirent y retourne.

func inventory() -> Dictionary:
	return character.inventory


## Équipe un membre du groupe avec un objet du sac ; les objets retirés retournent dans le sac.
func equip(member: Character, item_id: String) -> bool:
	if not Items.is_equipment(item_id) or character.item_count(item_id) <= 0:
		return false
	character.remove_item(item_id)
	for removed in member.equip(item_id):
		if removed != Equipment.UNARMED:
			character.add_item(removed)
	return true


## Retire l'objet d'un emplacement d'un membre du groupe et le range dans le sac.
func unequip(member: Character, slot: String) -> bool:
	var removed := member.unequip(slot)
	if removed == "":
		return false
	if removed != Equipment.UNARMED:
		character.add_item(removed)
	return true


## Utilise un objet du sac hors combat sur un membre du groupe. Retourne le texte du résultat
## ("" si l'objet n'est pas utilisable).
func use_item(item_id: String, member: Character) -> String:
	if not Items.is_usable_outside_combat(item_id) or character.item_count(item_id) <= 0:
		return ""
	character.remove_item(item_id)
	var before := member.hp
	var roll := Dice.roll_expr(String(Items.def(item_id)["use"]["heal"]), rng)
	member.hp = mini(member.max_hp, member.hp + maxi(1, int(roll["total"])))
	return Loc.ui("%s : %s récupère %d PV.") % [Items.name_of(item_id), member.name, member.hp - before]


## Jette des objets du sac ; retourne le nombre jeté.
func drop_item(item_id: String, count := 1) -> int:
	return character.remove_item(item_id, count)


func to_dict() -> Dictionary:
	return {
		"character": character.to_dict(),
		"companions": companions.map(func(c): return c.to_dict()),
		"rng_seed": str(rng.seed),  # en texte : les entiers 64 bits ne survivent pas aux décimaux du JSON
		"rng_state": str(rng.state),
		"day": day, "slot": slot, "flags": flags, "seen": seen, "last_seen_day": last_seen_day,
		"dead": dead, "death_cause": death_cause, "recorded": recorded, "notices": notices,
		"pending_combat": pending_combat,
	}


static func from_dict(data: Dictionary) -> LifeState:
	var life := LifeState.new()
	life.character = Character.from_dict(data.get("character", {}))
	for c: Dictionary in data.get("companions", []):
		life.companions.append(Character.from_dict(c))
	life.rng.seed = String(data.get("rng_seed", "0")).to_int()
	life.rng.state = String(data.get("rng_state", "0")).to_int()
	life.day = int(data.get("day", 1))
	life.slot = int(data.get("slot", 0))
	life.flags = data.get("flags", {})
	life.seen = Character._int_dict(data.get("seen", {}))
	life.last_seen_day = Character._int_dict(data.get("last_seen_day", {}))
	life.dead = data.get("dead", false)
	life.death_cause = data.get("death_cause", "")
	life.recorded = data.get("recorded", false)
	life.notices.assign(data.get("notices", []))
	life.pending_combat = data.get("pending_combat", {})
	return life
