extends Node
## Autoload « Game » : déroulement de la vie en cours (création, événements, temps, mort).
## L'interface appelle ces fonctions puis se met à jour via les signaux.

signal life_changed
signal life_ended
signal debug_changed

var life: LifeState
var current_event: Dictionary = {}
## Mode debug : affiche notamment les choix verrouillés. F12 en jeu, ou lancer avec « -- --debug ».
var debug := "--debug" in OS.get_cmdline_user_args()


func toggle_debug() -> void:
	debug = not debug
	debug_changed.emit()


## Commence une vie avec un personnage créé (écran de création).
func start_life(character: Character, seed_value: int = 0) -> void:
	life = LifeState.new()
	life.rng.seed = seed_value if seed_value != 0 else randi()
	life.character = character
	current_event = {}
	life_changed.emit()


## Commence une vie avec un personnage aléatoire (tests, lancement direct de la scène principale).
func new_life(seed_value: int = 0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value if seed_value != 0 else randi()
	start_life(Character.create_random(rng, Meta), rng.seed)


func draw_event(location_id: String) -> Dictionary:
	return EventEngine.pick_event(location_id, life, Meta)


func begin_event(ev: Dictionary) -> void:
	current_event = ev
	life.mark_seen(ev["id"])
	Meta.mark_event_seen(ev["id"])


## Lance les dés d'un choix avec test, sans appliquer ses effets.
func roll_check(choice: Dictionary) -> Dictionary:
	return Dice.roll_check(life.character, choice["check"], life.rng)


func resolve_choice(choice: Dictionary, roll: Dictionary = {}) -> Dictionary:
	var result := EventEngine.resolve_choice(current_event, choice, life, Meta, roll)
	_after_change()
	return result


## Combat en cours (null hors combat).
var combat: Combat


func start_combat(spec: Dictionary) -> Combat:
	combat = Combat.new(spec, life)
	return combat


## Applique l'issue du combat : récompenses, compagnons tombés, K.-O., puis effets de l'issue
## (victory / defeat / fled). Retourne un résultat au même format que resolve_choice().
func finish_combat() -> Dictionary:
	var c := combat
	combat = null
	var lines: Array[String] = []
	var knockout: bool = c.spec.get("on_defeat", "death") == "knockout"

	if c.outcome == "victory":
		var xp := 0
		for enemy in c.enemies():
			var creature := enemy.creature
			xp += int(creature.get("xp", 0))
			if creature.has("gold"):
				var gold := maxi(0, int(Dice.roll_expr(creature["gold"], life.rng)["total"]))
				life.character.gold += gold
				lines.append(Loc.ui("Butin : %d po") % gold)
			for loot: Dictionary in creature.get("loot", []):
				if life.rng.randf() < float(loot.get("chance", 1.0)):
					life.character.add_item(loot["item"], int(loot.get("count", 1)))
					lines.append(Loc.ui("Butin : %s ×%d") % [DB.items[loot["item"]]["name"], int(loot.get("count", 1))])
		# Chaque membre du groupe encore debout gagne toute l'XP.
		for member in life.party():
			if member.hp > 0 and xp > 0:
				for new_level in member.add_xp(xp):
					lines.append(Loc.ui("%s atteint le niveau %d !") % [member.name, new_level])
					if Progression.is_advancement_level(new_level):
						lines.append(Loc.ui("%s : %s.") % [member.name, Progression.advancement_text()])
		if xp > 0:
			lines.push_front(Loc.ui("+%d XP") % xp)

	# Compagnons à 0 PV : assommés si le combat n'était pas mortel, morts sinon.
	for companion in life.companions.duplicate():
		if companion.hp <= 0:
			if knockout:
				companion.hp = 1
			else:
				life.companions.erase(companion)
				lines.append(Loc.ui("%s a péri au combat.") % companion.name)
	if knockout and life.character.hp <= 0:
		life.character.hp = 1

	var key := c.outcome
	var outcome: Dictionary = c.spec.get(key, {})
	var default_texts := {
		"victory": Loc.ui("Vous êtes {g:victorieux|victorieuse|victorieux·se}."),
		"fled": Loc.ui("Vous parvenez à fuir."),
		"defeat": Loc.ui("Vous êtes {g:vaincu|vaincue|vaincu·e}."),
	}
	var applied := Effects.apply_all(outcome.get("effects", []), life, Meta)
	lines.append_array(applied["lines"])
	_after_change()
	return {"outcome": key, "text": outcome.get("text", default_texts.get(key, "")), "roll": {},
		"lines": lines, "goto": applied["goto"], "combat": applied["combat"]}


## Fin d'une séquence d'événements (sans « goto ») : le temps avance d'un créneau.
func end_event() -> void:
	current_event = {}
	life.advance_time(1)
	_after_change()


func _after_change() -> void:
	life_changed.emit()
	if life.dead and not life.recorded:
		life.recorded = true
		Meta.record_life(life)
		life_ended.emit()
