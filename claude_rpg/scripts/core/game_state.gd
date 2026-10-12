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
