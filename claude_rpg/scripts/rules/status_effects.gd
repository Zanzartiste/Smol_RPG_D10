class_name StatusEffects
extends RefCounted
## API des états (poison, brûlure, étourdi…). Définitions : data/status_effects.json.
## Les états se cumulent en charges (stacks). Mécaniques, toutes facultatives :
##   tick_damage                     dégâts au début du tour, quel que soit le nombre de charges
##   tick_damage_per_stack           dégâts par charge au début du tour
##   tick_max_hp_percent_per_stack   dégâts en % des PV max par charge (au moins 1 par charge)
##   tick_damage_type                type des dégâts de tick (les défenses s'appliquent alors)
##   skip_turn                       la créature passe son tour
##   damage_dice_per_stack           dés de dégâts en plus ou en moins par charge (ex. -1 : Affaibli)
##   absorb                          chaque charge absorbe 1 point de dégâts (et est consommée)
##   decay                           charges perdues à chaque tour : un nombre, ou "all"
##   decay_at                        "start" (par défaut) ou "end" du tour de la créature
##   negative                        état négatif (retiré par un effet cleanse « negative »)
##   death_cause                     texte de l'écran de mort si l'état tue le héros
##   attack_disadvantage             difficulté +1 à ses attaques
##   attacked_advantage / attacked_disadvantage   difficulté −1 / +1 pour qui l'attaque
##   attack_surprise                 ses attaques prennent la cible par surprise (caché)
##   unaware                         il est pris par surprise (endormi, paralysé)
##   hidden / immobile / moving      Couvert +1 / −1 / +1 contre les attaques à distance
##   resist_penalty: ["dex"]         un dé de moins pour résister avec ces attributs
##   auto_fail_resist: ["str", "dex"] ne peut pas résister avec ces attributs
##   check_disadvantage              un dé de moins à ses tests (fuite)
##   prepared                        +2 dés au prochain jet de combat, puis disparaît (Préparé)
##   no_flee                         ne peut pas fuir
##   no_hostile_actions              ne peut rien entreprendre contre ses ennemis (Charmé)
##   wake_on_damage                  disparaît s'il subit des dégâts (Endormi)


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


## Dégâts infligés au début du tour par `stacks` charges, sur une créature de `max_hp` PV.
static func tick_damage(id: String, stacks: int, max_hp: int) -> int:
	var d := def(id)
	var damage := int(d.get("tick_damage", 0)) + int(d.get("tick_damage_per_stack", 0)) * stacks
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


## L'état a-t-il ce marqueur (true, ou liste contenant `value`) ?
static func has_flag(id: String, key: String, value := "") -> bool:
	var flag: Variant = def(id).get(key, false)
	if flag is Array:
		return value in flag
	return flag is bool and flag


static func death_cause(id: String) -> String:
	return def(id).get("death_cause", Loc.ui("Succombe à : %s") % name_of(id))
