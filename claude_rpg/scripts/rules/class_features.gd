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
	var progression: String = DB.classes[class_id].get("spell_slots", "")
	var before := Spellcasting.slots(progression, class_level - 1)
	var after := Spellcasting.slots(progression, class_level)
	if after != before:
		lines.append(Loc.ui("%s : %s.") % [ch.name, slots_text(int(after.get(Spellcasting.SLOT_KEY, 0)),
			Spellcasting.max_level(progression, class_level))])
	return lines


## Ex. « 8 emplacements de sort (sorts jusqu'au niveau 2) ».
static func slots_text(total: int, max_level: int) -> String:
	return Loc.ui("%d mana (sorts jusqu'au niveau %d)") % [total, max_level]
