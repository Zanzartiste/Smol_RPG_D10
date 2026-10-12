class_name Defenses
extends RefCounted
## Défenses d'une créature : résistances, immunités et vulnérabilités à des types de dégâts
## (DamageTypes), et immunités à des états (StatusEffects).
## Format JSON (ennemis, sauvegarde) :
##   {"resistances": ["fire"], "immunities": ["poison"], "vulnerabilities": ["bludgeoning"],
##    "status_immunities": ["poisoned"]}

const RESISTANCE := "resistance"
const IMMUNITY := "immunity"
const VULNERABILITY := "vulnerability"
const STATUS_IMMUNITY := "status_immunity"
const KINDS := [RESISTANCE, IMMUNITY, VULNERABILITY, STATUS_IMMUNITY]
## Sorte de défense -> clé dans le format JSON.
const JSON_KEYS := {
	RESISTANCE: "resistances", IMMUNITY: "immunities", VULNERABILITY: "vulnerabilities",
	STATUS_IMMUNITY: "status_immunities",
}
const LABELS := {
	RESISTANCE: "Résistances", IMMUNITY: "Immunités", VULNERABILITY: "Vulnérabilités",
	STATUS_IMMUNITY: "Immunités d'état",
}

var _lists := {RESISTANCE: [], IMMUNITY: [], VULNERABILITY: [], STATUS_IMMUNITY: []}


static func from_dict(data: Dictionary) -> Defenses:
	var d := Defenses.new()
	for kind: String in KINDS:
		for id in data.get(JSON_KEYS[kind], []):
			d.add(kind, id)
	return d


func to_dict() -> Dictionary:
	var result := {}
	for kind: String in KINDS:
		if not _lists[kind].is_empty():
			result[JSON_KEYS[kind]] = _lists[kind].duplicate()
	return result


func add(kind: String, id: String) -> void:
	if id not in _lists[kind]:
		_lists[kind].append(id)


func remove(kind: String, id: String) -> void:
	_lists[kind].erase(id)


func has(kind: String, id: String) -> bool:
	return id in _lists.get(kind, [])


func list(kind: String) -> Array:
	return _lists[kind].duplicate()


func is_empty() -> bool:
	return KINDS.all(func(kind): return _lists[kind].is_empty())


## Ajoute toutes les défenses d'une autre instance.
func merge(other: Defenses) -> void:
	for kind: String in KINDS:
		for id in other._lists[kind]:
			add(kind, id)


func is_immune_to_status(status_id: String) -> bool:
	return has(STATUS_IMMUNITY, status_id)


## Texte lisible, ex. « Résistances : Feu, Froid · Immunités d'état : Endormi ».
func describe() -> String:
	var parts := PackedStringArray()
	for kind: String in KINDS:
		if _lists[kind].is_empty():
			continue
		var names: Array = _lists[kind].map(
			func(id): return StatusEffects.name_of(id) if kind == STATUS_IMMUNITY else DamageTypes.name_of(id))
		parts.append("%s : %s" % [Loc.ui(LABELS[kind]), ", ".join(PackedStringArray(names))])
	return " · ".join(parts)
