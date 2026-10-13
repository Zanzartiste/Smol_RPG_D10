class_name EventEngine
extends RefCounted
## Tirage des événements et résolution des choix. Sans état : tout passe par LifeState et MetaState.

const REPEAT_MODES := ["always", "once_per_life", "once_per_world"]
const DEFAULT_WEIGHT := 10.0


static func is_eligible(ev: Dictionary, life: LifeState, meta: MetaState) -> bool:
	var id: String = ev["id"]
	match ev.get("repeat", "always"):
		"once_per_life":
			if life.seen.has(id):
				return false
		"once_per_world":
			if meta.seen_events.has(id):
				return false
	var cooldown := int(ev.get("cooldown_days", 0))
	if cooldown > 0 and life.last_seen_day.has(id) and life.day - int(life.last_seen_day[id]) < cooldown:
		return false
	return Conditions.check_all(ev.get("conditions", []), life, meta)


static func eligible_events(location_id: String, life: LifeState, meta: MetaState) -> Array:
	return DB.events_for(location_id).filter(func(ev): return is_eligible(ev, life, meta))


## Tirage pondéré parmi les événements éligibles du lieu.
static func pick_event(location_id: String, life: LifeState, meta: MetaState) -> Dictionary:
	var pool := eligible_events(location_id, life, meta)
	if pool.is_empty():
		return fallback_event(location_id)
	var total := 0.0
	for ev: Dictionary in pool:
		total += float(ev.get("weight", DEFAULT_WEIGHT))
	var r := life.rng.randf() * total
	for ev: Dictionary in pool:
		r -= float(ev.get("weight", DEFAULT_WEIGHT))
		if r < 0.0:
			return ev
	return pool.back()


## Événement de secours quand aucun événement n'est éligible.
static func fallback_event(location_id: String) -> Dictionary:
	return {
		"id": "_calm_" + location_id,
		"location": location_id,
		"title": Loc.ui("Un moment calme"),
		"text": Loc.ui("Rien de notable ne se produit."),
		"choices": [{
			"id": "ok",
			"text": Loc.ui("Continuer"),
			"outcome": {"text": Loc.ui("Le temps passe paisiblement."), "effects": []},
		}],
	}


## Liste des choix à afficher : [{choice, available, reason}].
## Les choix dont les conditions ne sont pas remplies n'apparaissent qu'avec `show_locked`
## (mode debug), grisés et accompagnés de la raison.
static func visible_choices(ev: Dictionary, life: LifeState, meta: MetaState,
		show_locked := false) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for choice: Dictionary in ev.get("choices", []):
		var failed: Array = choice.get("conditions", []).filter(
			func(c): return not Conditions.check(c, life, meta))
		if not failed.is_empty() and not show_locked:
			continue
		var reasons := failed.map(Conditions.describe).filter(func(s): return s != "")
		result.append({
			"choice": choice,
			"available": failed.is_empty(),
			"reason": ", ".join(PackedStringArray(reasons)) if not reasons.is_empty() else Loc.ui("conditions non remplies"),
		})
	return result


## Résout un choix : jet éventuel, puis effets du résultat. Une réussite critique utilise l'issue
## "critical_success" si le choix en a une (sinon "success"), un échec critique "critical_failure" (sinon
## "failure").
## `roll` permet de fournir un jet déjà effectué (pour l'animer avant d'appliquer les effets).
## Retourne {"outcome": "outcome"|"success"|"failure"|"critical_success"|"critical_failure", "text", "roll",
## "lines", "goto"}.
static func resolve_choice(ev: Dictionary, choice: Dictionary, life: LifeState, meta: MetaState,
		roll: Dictionary = {}) -> Dictionary:
	var outcome_key := "outcome"
	if choice.has("check"):
		if roll.is_empty():
			roll = Dice.roll_check(life.character, choice["check"], life.rng)
		outcome_key = "success" if roll["success"] else "failure"
		if roll["success"] and int(roll.get("critical", 0)) > 0 and choice.has("critical_success"):
			outcome_key = "critical_success"
		elif not roll["success"] and roll.get("fumble", false) and choice.has("critical_failure"):
			outcome_key = "critical_failure"
	var outcome: Dictionary = choice.get(outcome_key, {})
	var key := "evt.%s.%s.%s" % [ev["id"], choice["id"], outcome_key]
	var applied := Effects.apply_all(outcome.get("effects", []), life, meta)
	# Approbation des compagnons (à la BG3) : {"approval": {"mira": 2}} sur le choix ou son issue.
	var approval: Dictionary = choice.get("approval", {}).duplicate()
	approval.merge(outcome.get("approval", {}), true)
	if not approval.is_empty():
		applied["lines"].append_array(Social.approve(life, approval))
	return {
		"outcome": outcome_key,
		"text": Loc.t(key, outcome.get("text", "")),
		"roll": roll,
		"lines": applied["lines"],
		"goto": applied["goto"],
		"combat": applied["combat"],
	}
