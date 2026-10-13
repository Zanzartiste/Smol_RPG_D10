class_name ClassFeatures
extends RefCounted
## API des aptitudes de classe gagnées en montant de niveau (classes.json › features).
## Une aptitude : {"level", "id", "name", "description",
##                 "actions"?: [ids d'actions.json gagnées],
##                 "modifiers"?: [modificateurs, voir Modifiers],
##                 "resources"?: {id: quantité ajoutée, rechargée par un repos long}}
## Les quantités de ressources de plusieurs aptitudes s'additionnent (ex. Inflexible 1 + 1 + 1).


static func of_class(class_id: String) -> Array:
	return DB.classes.get(class_id, {}).get("features", [])


## Aptitudes acquises jusqu'à un niveau de classe (inclus).
static func up_to(class_id: String, class_level: int) -> Array:
	return of_class(class_id).filter(func(f): return int(f["level"]) <= class_level)


## Aptitudes gagnées exactement à un niveau de classe.
static func at_level(class_id: String, class_level: int) -> Array:
	return of_class(class_id).filter(func(f): return int(f["level"]) == class_level)


## Lignes à afficher quand un personnage atteint un niveau dans une classe (la principale par défaut),
## ex. « Mira : nouvelle aptitude, Fougue. »
static func announce(ch: Character, class_level: int, cls := "") -> Array[String]:
	var lines: Array[String] = []
	var class_id := cls if cls != "" else ch.class_id
	for feature: Dictionary in at_level(class_id, class_level):
		lines.append(Loc.ui("%s : nouvelle aptitude, %s.") % [ch.name, feature["name"]])
	var before := Spellcasting.slots(DB.classes[class_id].get("spell_slots", ""), class_level - 1)
	var after := Spellcasting.slots(DB.classes[class_id].get("spell_slots", ""), class_level)
	if after != before:
		lines.append(Loc.ui("%s : %s.") % [ch.name, slots_text(after)])
	return lines


## Ex. « emplacements de sort : niv. 1 ×4, niv. 2 ×2 ».
static func slots_text(slots: Dictionary) -> String:
	var parts := PackedStringArray()
	for key: String in slots:
		parts.append(Loc.ui("niv. %d ×%d") % [Spellcasting.slot_level(key), int(slots[key])])
	return Loc.ui("emplacements de sort : %s") % ", ".join(parts)
