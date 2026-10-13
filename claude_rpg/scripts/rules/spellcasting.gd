class_name Spellcasting
extends RefCounted
## API de l'incantation : emplacements de sort, sorts lancés à un niveau supérieur, dés qui augmentent
## avec le niveau, sorts connus et équipés. Réglages : data/rules.json
##   spell_slots   : {"full": [...], "half": [...]} ; ligne n = niveau de classe n, colonne i = nombre de
##                   sorts de niveau i+1 dans la table du SRD. Une classe s'y rattache par
##                   "spell_slots": "full" | "half".
##   dice_scaling  : {"cantrip": {"1": 1, "5": 2, ...}} ; paliers selon le niveau de classe.
##   spells        : {"equipped_base", "equipped_per_magic_rank"} : nombre de sorts équipés (les tours de
##                   magie sont toujours prêts, en plus).
##
## Emplacements simplifiés (décision du 2026-10-13) : une seule réserve, la ressource "spell_slot". Sa
## taille vaut la somme de la table pondérée par le niveau (2 sorts de niveau 1 et 1 de niveau 2 font 4
## emplacements) ; lancer un sort de niveau N coûte N emplacements. La table fixe aussi le niveau de sort
## le plus haut qu'on peut lancer.
## Une action qui en consomme s'écrit {"cost": "spell_slot", "spell_level": 1} ; un effet peut préciser
## "upcast": 1 (dés de dégâts en plus par niveau au-delà de spell_level).

const SLOT_KEY := "spell_slot"
const MAX_SPELL_LEVEL := 9


static func is_slot(resource_id: String) -> bool:
	return resource_id == SLOT_KEY


## Ligne de la table d'une progression à un niveau de classe (vide si aucun sort).
static func _row(progression: String, class_level: int) -> Array:
	var table: Array = DB.rules.get("spell_slots", {}).get(progression, [])
	if table.is_empty() or class_level < 1:
		return []
	return table[clampi(class_level - 1, 0, table.size() - 1)]


## Emplacements d'une progression ("full", "half") à un niveau de classe : {"spell_slot": N} (vide si 0).
static func slots(progression: String, class_level: int) -> Dictionary:
	var total := 0
	var row := _row(progression, class_level)
	for i in row.size():
		total += int(row[i]) * (i + 1)
	return {SLOT_KEY: total} if total > 0 else {}


## Niveau de sort le plus haut qu'une progression permet de lancer à un niveau de classe (0 : aucun).
static func max_level(progression: String, class_level: int) -> int:
	var row := _row(progression, class_level)
	for i in range(row.size() - 1, -1, -1):
		if int(row[i]) > 0:
			return i + 1
	return 0


## Emplacements que coûte une action (le niveau auquel le sort est lancé).
static func cost_of(action: Dictionary) -> int:
	return int(action.get("slot_level", action.get("spell_level", 1)))


## L'action est-elle un sort (tour de magie compris) ?
static func is_spell(action: Dictionary) -> bool:
	return action.has("spell_level") or action.get("cost", "") == SLOT_KEY \
		or action.get("effects", []).any(func(e): return e.get("cantrip", false))


## Tour de magie : un sort sans niveau ni emplacement, toujours prêt (hors de la limite des sorts équipés).
static func is_cantrip(action: Dictionary) -> bool:
	return is_spell(action) and not action.has("spell_level") and action.get("cost", "") != SLOT_KEY


## Nombre de sorts équipés possibles pour un rang de Magie (tours de magie non compris).
static func max_equipped(magic_rank: int) -> int:
	var rules: Dictionary = DB.rules.get("spells", {})
	return int(rules.get("equipped_base", 2)) + int(rules.get("equipped_per_magic_rank", 1)) * magic_rank


static func progressions() -> Array:
	return DB.rules.get("spell_slots", {}).keys().filter(func(k): return not k.begins_with("_"))


# --- Dés qui augmentent avec le niveau ----------------------------------------

static func scaling_tables() -> Array:
	return DB.rules.get("dice_scaling", {}).keys().filter(func(k): return not k.begins_with("_"))


## Palier d'une table à un niveau de classe (le plus haut atteint), 1 par défaut.
static func dice_count(table: String, class_level: int) -> int:
	var steps: Dictionary = DB.rules.get("dice_scaling", {}).get(table, {})
	var best_level := 0
	var count := 1
	for key: String in steps:
		if int(key) <= class_level and int(key) >= best_level:
			best_level = int(key)
			count = int(steps[key])
	return count


# --- Sorts lancés à un niveau supérieur ----------------------------------------

## L'action a-t-elle un effet amélioré par un emplacement de niveau supérieur ?
static func can_upcast(action: Dictionary) -> bool:
	return action.get("effects", []).any(func(e): return e.has("upcast"))


## Copie d'une action lancée avec un emplacement de niveau `level` : "slot_level" est fixé et chaque
## effet "upcast" ajoute ce nombre de dés de dégâts par niveau au-delà du niveau du sort.
static func at_level(action: Dictionary, level: int) -> Dictionary:
	var variant := action.duplicate(true)
	variant["slot_level"] = level
	var extra := level - int(action.get("spell_level", 1))
	if extra > 0:
		variant["name"] = Loc.ui("%s (niv. %d)") % [action["name"], level]
		for e: Dictionary in variant.get("effects", []):
			if e.has("upcast") and e.get("damage") is Dictionary:
				e["damage"]["dice"] = int(e["damage"].get("dice", 0)) + int(e["upcast"]) * extra
	return variant
