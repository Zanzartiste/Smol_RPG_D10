extends Node
## Autoload « Game » : déroulement de la vie en cours (création, événements, temps, mort).
## L'interface appelle ces fonctions puis se met à jour via les signaux.

signal life_changed
signal life_ended

var life: LifeState
var current_event: Dictionary = {}


func new_life(seed_value: int = 0) -> void:
	life = LifeState.new()
	life.rng.seed = seed_value if seed_value != 0 else randi()
	life.character = Character.create_random(life.rng, Meta)
	current_event = {}
	life_changed.emit()


func draw_event(location_id: String) -> Dictionary:
	return EventEngine.pick_event(location_id, life, Meta)


func begin_event(ev: Dictionary) -> void:
	current_event = ev
	life.mark_seen(ev["id"])
	Meta.mark_event_seen(ev["id"])


func resolve_choice(choice: Dictionary) -> Dictionary:
	var result := EventEngine.resolve_choice(current_event, choice, life, Meta)
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
