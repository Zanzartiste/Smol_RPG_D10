class_name Combatant
extends RefCounted
## Participant à un combat :
##   - "hero"      : le personnage joué (Character), contrôlé par le joueur ;
##   - "companion" : un compagnon (Character), contrôlé par le joueur lui aussi ;
##   - "creature"  : une créature du bestiaire (ennemi ou invocation), contrôlée par l'IA.
## Les personnages agissent avec les actions de leur classe (actions.json) ; les créatures avec les leurs.
## Pour un personnage, les PV sont ceux du Character : les dégâts persistent après le combat.

var id := ""  # unique dans le combat
var name := ""
var side := "ally"  # "ally" ou "enemy"
var kind := "creature"  # "hero", "companion" ou "creature"
var character: Character
var creature: Dictionary = {}
var summoned := false  # invoqué pendant le combat (disparaît à la fin)
var initiative := 0
var statuses: Dictionary = {}  # id d'état -> charges
var intent: Dictionary = {}  # action préparée, exécutée au prochain tour (ennemis)
var uses: Dictionary = {}  # id d'action -> utilisations restantes dans ce combat (per_combat)
var reaction_used := false  # réaction déjà utilisée ce round (Esquive instinctive…), rendue à son tour
var _hp := 0
var _max_hp := 0

var hp: int:
	get:
		return character.hp if character != null else _hp
	set(value):
		if character != null:
			character.hp = value
		else:
			_hp = value


static func from_character(ch: Character, hero: bool) -> Combatant:
	var c := Combatant.new()
	c.character = ch
	c.kind = "hero" if hero else "companion"
	c.id = "hero" if hero else "ally_" + ch.template_id
	c.name = ch.name
	for action in c.combat_actions():
		if action.has("per_combat"):
			c.uses[action["id"]] = int(action["per_combat"])
	return c


static func from_creature(creature_id: String, label: String, side_id: String, rng: RandomNumberGenerator) -> Combatant:
	var c := Combatant.new()
	c.creature = Creatures.def(creature_id)
	c.kind = "creature"
	c.side = side_id
	c.name = label
	c._max_hp = maxi(1, Dice.roll_expr(str(c.creature.get("hp", "1")), rng)["total"])
	c._hp = c._max_hp
	return c


func is_ally() -> bool:
	return side == "ally"


func is_hero() -> bool:
	return kind == "hero"


func is_alive() -> bool:
	return hp > 0


func max_hp() -> int:
	return character.max_hp if character != null else _max_hp


func armor_class() -> int:
	return character.armor_class() if character != null else int(creature.get("ac", 10))


func ability_mod(ability_id: String) -> int:
	if character != null:
		return character.ability_mod(ability_id)
	return Abilities.modifier(int(creature.get("abilities", {}).get(ability_id, 10)))


## Jet de sauvegarde : modificateur d'attribut (+ maîtrise pour un personnage, + "saves" pour une créature).
func save_mod(ability_id: String) -> int:
	if character != null:
		return character.save_mod(ability_id)
	return ability_mod(ability_id) + int(creature.get("saves", {}).get(ability_id, 0))


## DD des jets de sauvegarde imposés : DD des sorts pour un personnage, "save_dc" pour une créature.
func save_dc() -> int:
	return Spellcasting.save_dc(character) if character != null else int(creature.get("save_dc", 10))


func has_modifier(type: String) -> bool:
	return character != null and character.has_modifier(type)


## Attaques en plus pour l'action Attaque (Attaque supplémentaire).
func extra_attacks() -> int:
	return Modifiers.sum(character.modifiers(), "extra_attack") if character != null else 0


func initiative_bonus() -> int:
	return character.initiative_bonus() if character != null else ability_mod("dex")


## Résistances, immunités et vulnérabilités (voir Defenses).
func defenses() -> Defenses:
	return character.all_defenses() if character != null else Defenses.from_dict(creature.get("defenses", {}))


func size() -> String:
	return character.size() if character != null else creature.get("size", "medium")


## Places occupées dans son camp (rules.json › combat.size_slots).
func slots() -> float:
	return Combat.size_slots(size())


## Le joueur choisit les actions des personnages (héros et compagnons) ; l'IA celles des créatures.
func is_player_controlled() -> bool:
	return character != null


## Actions de combat : celles de la classe (actions.json) pour un personnage, celles de la créature sinon.
func combat_actions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if character != null:
		for action_id in character.combat_actions():
			result.append(Actions.def(action_id))
	else:
		result.assign(creature.get("actions", []))
	return result


## Variantes d'une action proposées au joueur : un sort amélioré à niveau supérieur ("upcast") existe
## en une variante par niveau d'emplacement disponible ; les autres actions en une seule.
func action_variants(action: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if character != null and action.get("cost") == "spell_slot" and Spellcasting.can_upcast(action):
		for level in range(int(action.get("spell_level", 1)), Spellcasting.MAX_SPELL_LEVEL + 1):
			if int(character.resources.get(Spellcasting.slot_key(level), 0)) > 0:
				result.append(Spellcasting.at_level(action, level))
	if result.is_empty():
		result.append(action)
	return result


## Ressource consommée par une action ("" si aucune). Pour un sort : l'emplacement fixé par la
## variante, sinon le plus bas disponible à partir du niveau du sort.
func resource_key(action: Dictionary) -> String:
	var cost: String = action.get("cost", "")
	if cost != "spell_slot":
		return cost
	if action.has("slot_level"):
		return Spellcasting.slot_key(int(action["slot_level"]))
	var base := int(action.get("spell_level", 1))
	for level in range(base, Spellcasting.MAX_SPELL_LEVEL + 1):
		if character != null and int(character.resources.get(Spellcasting.slot_key(level), 0)) > 0:
			return Spellcasting.slot_key(level)
	return Spellcasting.slot_key(base)


## Une action peut-elle être utilisée ? Retourne "" si oui, sinon la raison.
func unavailable_reason(action: Dictionary) -> String:
	if action.has("per_combat") and int(uses.get(action.get("id", ""), 0)) <= 0:
		return Loc.ui("déjà utilisée")
	var key := resource_key(action)
	if key != "" and character != null and int(character.resources.get(key, 0)) <= 0:
		return Loc.ui("plus d'%s") % Actions.resource_name(key)
	return ""


## Décompte une utilisation (par combat) et la ressource éventuelle (emplacement de sort…).
func consume(action: Dictionary) -> void:
	if action.has("per_combat"):
		uses[action["id"]] = int(uses.get(action["id"], 0)) - 1
	var key := resource_key(action)
	if key != "" and character != null:
		character.resources[key] = int(character.resources.get(key, 0)) - 1


# --- États -------------------------------------------------------------------

func stacks(status_id: String) -> int:
	return int(statuses.get(status_id, 0))


func add_status(status_id: String, amount: int) -> void:
	statuses[status_id] = stacks(status_id) + amount
	if stacks(status_id) <= 0:
		statuses.erase(status_id)


func remove_status(status_id: String) -> void:
	statuses.erase(status_id)


## Modificateur de dégâts infligés dû aux états (ex. Affaibli : -1 par charge).
func damage_modifier() -> int:
	var total := 0
	for status_id: String in statuses:
		total += StatusEffects.damage_dealt_per_stack(status_id) * stacks(status_id)
	return total


# --- Attaques ----------------------------------------------------------------

## Bonus au jet d'attaque d'un effet "attack".
func attack_bonus(effect: Dictionary) -> int:
	if effect.has("to_hit"):
		return int(effect["to_hit"])
	if character == null:
		return 0
	if _uses_own_weapon(effect):
		return character.attack_bonus("weapon") + Modifiers.sum(character.modifiers(), "weapon_attack")
	return character.attack_bonus(String(effect.get("ability", "weapon")))


## Expression de dégâts d'un effet "attack" ou "damage", ex. « 1d8+3+1d6 ».
func damage_expr(effect: Dictionary) -> String:
	var expr: String = effect.get("damage", "1")
	var extra: String = effect.get("extra_damage", "")
	if effect.has("scaling") and character != null:
		var count := Spellcasting.dice_count(effect["scaling"]["table"], character.class_level())
		if effect["scaling"].get("field", "damage") == "extra_damage":
			extra = Spellcasting.with_dice_count(extra, count)
		else:
			expr = Spellcasting.with_dice_count(expr, count)
	var bonus := 0
	if _uses_own_weapon(effect):
		expr = character.weapon_damage()
		bonus += Modifiers.sum(character.modifiers(), "weapon_damage") + character.ability_mod(character.action_ability("weapon"))
	elif effect.get("weapon") is String:
		expr = Equipment.weapon_damage(effect["weapon"])
	elif effect.get("add_mod", false) and character != null:
		bonus += character.ability_mod(character.action_ability(effect.get("ability", "str")))
	expr = Dice.add_mod(expr, bonus)
	if extra != "":
		expr += "+" + extra
	return expr


## Dégâts d'autres types ajoutés à un effet : ceux de l'effet, plus ceux de l'arme s'il l'utilise.
func bonus_damage(effect: Dictionary) -> Array:
	var result: Array = effect.get("bonus_damage", []).duplicate()
	if _uses_own_weapon(effect):
		result.append_array(Equipment.def(character.weapon_id()).get("bonus_damage", []))
	elif effect.get("weapon") is String:
		result.append_array(Equipment.def(effect["weapon"]).get("bonus_damage", []))
	return result


func damage_type(effect: Dictionary) -> String:
	if _uses_own_weapon(effect):
		return character.weapon_damage_type()
	if effect.get("weapon") is String:
		return Equipment.damage_type_of(effect["weapon"])
	return effect.get("damage_type", "")


## Expression de soins, « level » étant remplacé par le niveau du personnage.
func heal_expr(amount: String) -> String:
	return amount.replace("level", str(character.level if character != null else 1))


func _uses_own_weapon(effect: Dictionary) -> bool:
	return character != null and effect.get("weapon") is bool and effect.get("weapon")
