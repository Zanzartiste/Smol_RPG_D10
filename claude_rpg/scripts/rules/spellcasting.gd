class_name Spellcasting
extends RefCounted
## API de l'incantation (SRD 5.1) : emplacements de sort par niveau, DD des sorts, sorts lancés à un
## niveau supérieur et dés qui augmentent avec le niveau. Réglages : data/rules.json
##   spell_slots   : {"full": [...], "half": [...]} ; ligne n = niveau de classe n, colonne i = emplacements
##                   de niveau i+1. Une classe s'y rattache par "spell_slots": "full" | "half".
##   dice_scaling  : {"cantrip": {"1": 1, "5": 2, ...}} ; nombre de dés selon le niveau de classe.
##
## Les emplacements sont des ressources du personnage : "spell_slot_1" … "spell_slot_9".
## Une action qui en consomme s'écrit {"cost": "spell_slot", "spell_level": 1} ; un effet peut
## préciser "upcast": "1d6" (dégâts ajoutés par niveau d'emplacement au-delà de spell_level).

const SLOT_PREFIX := "spell_slot_"
const MAX_SPELL_LEVEL := 9


static func slot_key(spell_level: int) -> String:
	return SLOT_PREFIX + str(spell_level)


static func is_slot(resource_id: String) -> bool:
	return resource_id.begins_with(SLOT_PREFIX)


static func slot_level(resource_id: String) -> int:
	return int(resource_id.trim_prefix(SLOT_PREFIX))


## Emplacements d'une progression ("full", "half") à un niveau de classe : {"spell_slot_1": 4, ...}.
static func slots(progression: String, class_level: int) -> Dictionary:
	var result := {}
	var table: Array = DB.rules.get("spell_slots", {}).get(progression, [])
	if table.is_empty() or class_level < 1:
		return result
	var row: Array = table[clampi(class_level - 1, 0, table.size() - 1)]
	for i in row.size():
		if int(row[i]) > 0:
			result[slot_key(i + 1)] = int(row[i])
	return result


static func progressions() -> Array:
	return DB.rules.get("spell_slots", {}).keys().filter(func(k): return not k.begins_with("_"))


## DD des sorts d'un personnage : 8 + rang de Magie + modificateur de l'attribut d'incantation.
static func save_dc(ch: Character) -> int:
	return 8 + ch.skill_rank("magic") + ch.ability_mod(ch.action_ability("spell"))


# --- Dés qui augmentent avec le niveau ----------------------------------------

static func scaling_tables() -> Array:
	return DB.rules.get("dice_scaling", {}).keys().filter(func(k): return not k.begins_with("_"))


## Nombre de dés d'une table à un niveau de classe (palier le plus haut atteint), 1 par défaut.
static func dice_count(table: String, class_level: int) -> int:
	var steps: Dictionary = DB.rules.get("dice_scaling", {}).get(table, {})
	var best_level := 0
	var count := 1
	for key: String in steps:
		if int(key) <= class_level and int(key) >= best_level:
			best_level = int(key)
			count = int(steps[key])
	return count


## Remplace le nombre du premier dé d'une expression : with_dice_count("1d10+2", 3) -> "3d10+2".
static func with_dice_count(expr: String, count: int) -> String:
	var regex := RegEx.create_from_string("^(\\d*)d")
	return regex.sub(expr, "%dd" % count)


# --- Sorts lancés à un niveau supérieur ----------------------------------------

## L'action a-t-elle un effet amélioré par un emplacement de niveau supérieur ?
static func can_upcast(action: Dictionary) -> bool:
	return action.get("effects", []).any(func(e): return e.has("upcast"))


## Copie d'une action lancée avec un emplacement de niveau `level` : "slot_level" est fixé et chaque
## effet "upcast" ajoute ses dégâts par niveau au-delà du niveau du sort.
static func at_level(action: Dictionary, level: int) -> Dictionary:
	var variant := action.duplicate(true)
	variant["slot_level"] = level
	var extra := level - int(action.get("spell_level", 1))
	if extra > 0:
		variant["name"] = Loc.ui("%s (niv. %d)") % [action["name"], level]
		for e: Dictionary in variant.get("effects", []):
			if e.has("upcast"):
				for i in extra:
					e["damage"] = "%s+%s" % [e["damage"], e["upcast"]]
	return variant
