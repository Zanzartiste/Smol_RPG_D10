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


# --- Chercher… (locations.json › hunt, encounters, stranger_difficulty) ---------------

## Groupe de créatures au hasard d'un lieu sauvage (locations.json › encounters), [] s'il n'y en a pas.
static func random_encounter(location_id: String, rng: RandomNumberGenerator) -> Array:
	var groups: Array = DB.locations.get(location_id, {}).get("encounters", [])
	return [] if groups.is_empty() else groups[rng.randi_range(0, groups.size() - 1)].duplicate()


## Effets d'une rencontre imprévue : combat contre un groupe au hasard du lieu (`more` créatures en plus).
static func _ambush_effects(location_id: String, rng: RandomNumberGenerator, more := 0) -> Array:
	var enemies := random_encounter(location_id, rng)
	if enemies.is_empty():
		return []
	for i in more:
		enemies.append(enemies[0])
	return [{"type": "combat", "enemies": enemies}]


## Dans la nature, une recherche ratée mène à autre chose : un événement du lieu (une fois sur deux, s'il y
## en a d'éligibles), sinon une embuscade. Retourne {} hors d'un lieu sauvage.
static func mishap_event(location_id: String, life: LifeState, meta: MetaState, ambush_text := "") -> Dictionary:
	if not DB.locations.get(location_id, {}).get("wild", false):
		return {}
	if life.rng.randf() < 0.5 and not eligible_events(location_id, life, meta).is_empty():
		return pick_event(location_id, life, meta)
	var text := ambush_text if ambush_text != "" else Loc.ui("Quelque chose vous a repéré pendant vos recherches.")
	var ambush := ambush_event(location_id, life.rng, text)
	if ambush.is_empty() and not eligible_events(location_id, life, meta).is_empty():
		return pick_event(location_id, life, meta)
	return ambush


## Effet d'une recherche ratée dans la nature : on enchaîne sur mishap_event ([] hors d'un lieu sauvage).
static func _mishap_effects(location_id: String) -> Array:
	if not DB.locations.get(location_id, {}).get("wild", false):
		return []
	return [{"type": "random_event", "location": location_id}]


## Chasse : chercher une créature précise du lieu (test, Nature dans la nature). Réussite : on la trouve
## (critique : un groupe plus nombreux) ; échec : autre chose vous trouve (lieu sauvage), sinon rien.
static func hunt_event(location_id: String, rng: RandomNumberGenerator) -> Dictionary:
	var location: Dictionary = DB.locations.get(location_id, {})
	var choices: Array = []
	for hunt: Dictionary in location.get("hunt", []):
		var enemies: Array = hunt["enemies"].duplicate()
		var more: Array = enemies + ([hunt["extra"]] if hunt.has("extra") else [])
		var ambush := _mishap_effects(location_id)
		var ambush_more := _ambush_effects(location_id, rng, 1)
		choices.append({"id": hunt["id"], "text": Loc.ui("Chercher %s") % hunt["name"],
			"check": {"skill": hunt.get("skill", "survival"), "difficulty": int(hunt.get("difficulty", 2))},
			"critical_success": {"text": Loc.ui("Vous les trouvez… et ils sont plus nombreux que prévu."),
				"effects": [{"type": "combat", "enemies": more}]},
			"success": {"text": Loc.ui("Vous trouvez ce que vous cherchiez."), "effects": [{"type": "combat", "enemies": enemies}]},
			"failure": {"text": Loc.ui("Vous ne trouvez pas leur trace… mais vous tombez sur autre chose.") if not ambush.is_empty()
				else Loc.ui("Vous ne trouvez aucune trace."), "effects": ambush},
			"critical_failure": {"text": Loc.ui("Vous vous faites surprendre !") if not ambush_more.is_empty()
				else Loc.ui("Vous perdez votre temps."), "effects": ambush_more},
		})
	if choices.is_empty():
		return {}
	choices.append({"id": "back", "text": Loc.ui("Renoncer"), "outcome": {"text": Loc.ui("Vous laissez tomber."), "effects": []}})
	return {"id": "hunt_" + location_id, "location": null, "title": Loc.ui("Chasse — %s") % location["name"],
		"text": Loc.ui("Que cherchez-vous ?"), "choices": choices}


## Test pour trouver quelqu'un à qui parler : Nature (stranger_difficulty) dans un lieu sauvage, aucun en ville ({}).
static func stranger_check(location_id: String) -> Dictionary:
	var location: Dictionary = DB.locations.get(location_id, {})
	if not location.get("wild", false):
		return {}
	return {"skill": "survival", "difficulty": int(location.get("stranger_difficulty", 3))}


## Embuscade (un seul choix : se défendre) après une recherche ratée ; {} si le lieu n'a pas de rencontres.
static func ambush_event(location_id: String, rng: RandomNumberGenerator, text: String) -> Dictionary:
	var effects := _ambush_effects(location_id, rng)
	if effects.is_empty():
		return {}
	return {"id": "ambush_" + location_id, "location": null, "title": Loc.ui("Embuscade"), "text": text,
		"choices": [{"id": "fight", "text": Loc.ui("Se défendre"), "outcome": {"text": "", "effects": effects}}]}


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


## Événement de récolte d'un lieu sauvage (locations.json › gather) : un choix par ressource, avec un test
## (réussite : la ressource ; réussite critique : le double ; échec critique : une blessure), puis Retour.
## Ressource : {"id", "name", "item", "count"? (1), "skill", "ability"?, "difficulty", "failure"?, "fumble"?,
## "fumble_hp"?}. Retourne {} si le lieu n'a rien à récolter.
static func gather_event(location_id: String, rng: RandomNumberGenerator = null) -> Dictionary:
	if rng == null:
		rng = RandomNumberGenerator.new()
	var location: Dictionary = DB.locations.get(location_id, {})
	var resources: Array = location.get("gather", [])
	if resources.is_empty():
		return {}
	var choices: Array = []
	for res: Dictionary in resources:
		var count := int(res.get("count", 1))
		var check := {"skill": res["skill"], "difficulty": int(res.get("difficulty", 1))}
		if res.has("ability"):
			check["ability"] = res["ability"]
		var got := Loc.ui("Vous récoltez : %s ×%d.")
		choices.append({
			"id": res["id"], "text": res["name"], "check": check,
			"critical_success": {"text": got % [Items.name_of(res["item"]), count * 2],
				"effects": [{"type": "add_item", "id": res["item"], "count": count * 2}]},
			"success": {"text": got % [Items.name_of(res["item"]), count],
				"effects": [{"type": "add_item", "id": res["item"], "count": count}]},
			"failure": {"text": res.get("failure", Loc.ui("Vous rentrez bredouille.")), "effects": _mishap_effects(location_id)},
			"critical_failure": {"text": res.get("fumble", Loc.ui("Vous vous blessez.")),
				"effects": [{"type": "hp", "amount": int(res.get("fumble_hp", -1)), "cause": Loc.ui("Mort en cherchant des ressources")}]
					+ _ambush_effects(location_id, rng)},
		})
	choices.append({"id": "back", "text": Loc.ui("Renoncer"), "outcome": {"text": Loc.ui("Vous laissez tomber."), "effects": []}})
	return {"id": "gather_" + location_id, "location": null, "title": Loc.ui("Récolte — %s") % location["name"],
		"text": Loc.ui("Vous prenez le temps de fouiller les environs. Que cherchez-vous ?"), "choices": choices}


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
	var summary := Loc.fill(Loc.t(key, outcome.get("text", "")), life)
	life.log_journal("event", "%s — %s" % [Loc.fill(Loc.t("evt.%s.title" % ev["id"], ev.get("title", "")), life), summary]
		if summary != "" else Loc.fill(Loc.t("evt.%s.title" % ev["id"], ev.get("title", "")), life))
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
