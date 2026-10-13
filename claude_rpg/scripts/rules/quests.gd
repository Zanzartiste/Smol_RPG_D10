class_name Quests
extends RefCounted
## API des quêtes. Définitions : data/quests.json.
##   {"id", "name", "description", "giver"?: qui la confie, "location"?: id de lieu,
##    "steps": ["Rapporter trois herbes à Ysolde.", ...]}
## L'avancement est dans LifeState.quests : id -> {"status": "active" | "done" | "failed", "step": N}.
## Les événements la font avancer avec l'effet {"type": "quest", "id", "action": "start" | "advance" |
## "complete" | "fail", "step"?: N} et la testent avec la condition {"type": "quest", "id",
## "status"?: "active" (par défaut) | "done" | "failed" | "none", "step"?: N minimum}.

const STATUSES := ["active", "done", "failed"]
const ACTIONS := ["start", "advance", "complete", "fail"]


static func has(id: String) -> bool:
	return DB.quests.has(id)


static func def(id: String) -> Dictionary:
	return DB.quests.get(id, {})


static func name_of(id: String) -> String:
	return def(id).get("name", id)


## Texte de l'étape en cours (la dernière une fois la quête finie).
static func step_text(id: String, step: int) -> String:
	var steps: Array = def(id).get("steps", [])
	if steps.is_empty():
		return ""
	return steps[clampi(step, 0, steps.size() - 1)]


## Applique une action à l'avancement d'une quête ; retourne la ligne à annoncer ("" si rien ne change).
## La ligne est aussi notée dans le journal.
static func apply(life: LifeState, id: String, action: String, step := -1) -> String:
	var line := _apply(life, id, action, step)
	life.log_journal("quest", line)
	return line


static func _apply(life: LifeState, id: String, action: String, step := -1) -> String:
	var state: Dictionary = life.quests.get(id, {})
	match action:
		"start":
			if not state.is_empty():
				return ""
			life.quests[id] = {"status": "active", "step": maxi(0, step)}
			return Loc.ui("Nouvelle quête : %s.") % name_of(id)
		"advance":
			if state.get("status") != "active":
				return ""
			state["step"] = step if step >= 0 else int(state.get("step", 0)) + 1
			return Loc.ui("Quête « %s » : %s") % [name_of(id), step_text(id, int(state["step"]))]
		"complete":
			if state.get("status") == "done":
				return ""
			life.quests[id] = {"status": "done", "step": def(id).get("steps", []).size() - 1}
			return Loc.ui("Quête accomplie : %s.") % name_of(id)
		"fail":
			if state.is_empty() or state.get("status") != "active":
				return ""
			state["status"] = "failed"
			return Loc.ui("Quête échouée : %s.") % name_of(id)
	return ""


## Quêtes d'un statut, dans l'ordre où elles ont commencé : [id].
static func with_status(life: LifeState, status: String) -> Array[String]:
	var result: Array[String] = []
	for id: String in life.quests:
		if life.quests[id].get("status") == status:
			result.append(id)
	return result
