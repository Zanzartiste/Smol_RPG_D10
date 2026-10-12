class_name StatusEffects
extends RefCounted
## API des états (poison, brûlure, étourdi…). Définitions : data/status_effects.json.
## Les états se cumulent en charges (stacks). Mécaniques, toutes facultatives :
##   tick_damage_per_stack           dégâts bruts par charge au début du tour (ignorent défenses et Protection)
##   tick_max_hp_percent_per_stack   dégâts en % des PV max par charge (au moins 1 par charge)
##   tick_damage_type                type des dégâts de tick (les défenses s'appliquent alors)
##   skip_turn                       la créature passe son tour
##   damage_dealt_per_stack          modifie les dégâts infligés (ex. -1 par charge)
##   absorb                          chaque charge absorbe 1 point de dégâts (et est consommée)
##   decay                           charges perdues à chaque tour : un nombre, ou "all"
##   decay_at                        "start" (par défaut) ou "end" du tour de la créature
##   negative                        état négatif (retiré par un effet cleanse « negative »)
##   death_cause                     texte de l'écran de mort si l'état tue le héros


static func ids() -> Array[String]:
	var result: Array[String] = []
	result.assign(DB.status_effects.keys())
	return result


static func has(id: String) -> bool:
	return DB.status_effects.has(id)


static func def(id: String) -> Dictionary:
	return DB.status_effects.get(id, {})


static func name_of(id: String) -> String:
	return def(id).get("name", id)


static func description_of(id: String) -> String:
	return def(id).get("description", "")


static func color_of(id: String) -> Color:
	return Color(String(def(id).get("color", "#c8c0b0")))


static func is_negative(id: String) -> bool:
	return def(id).get("negative", true)


static func skips_turn(id: String) -> bool:
	return def(id).get("skip_turn", false)


static func absorbs(id: String) -> bool:
	return def(id).get("absorb", false)


static func damage_dealt_per_stack(id: String) -> int:
	return int(def(id).get("damage_dealt_per_stack", 0))


## Dégâts infligés au début du tour par `stacks` charges, sur une créature de `max_hp` PV.
static func tick_damage(id: String, stacks: int, max_hp: int) -> int:
	var d := def(id)
	var damage := int(d.get("tick_damage_per_stack", 0)) * stacks
	if d.has("tick_max_hp_percent_per_stack"):
		damage += maxi(stacks, roundi(max_hp * float(d["tick_max_hp_percent_per_stack"]) / 100.0 * stacks))
	return damage


static func tick_damage_type(id: String) -> String:
	return def(id).get("tick_damage_type", "")


## Charges perdues par tour ; -1 = toutes.
static func decay_amount(id: String) -> int:
	var decay: Variant = def(id).get("decay", 0)
	return -1 if decay is String and decay == "all" else int(decay)


static func decays_at_end(id: String) -> bool:
	return def(id).get("decay_at", "start") == "end"


static func death_cause(id: String) -> String:
	return def(id).get("death_cause", Loc.ui("Succombe à : %s") % name_of(id))
