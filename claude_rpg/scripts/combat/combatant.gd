class_name Combatant
extends RefCounted
## Participant à un combat :
##   - "hero"      : le personnage joué (Character), qui joue des cartes ;
##   - "companion" : un compagnon (Character), contrôlé par l'IA avec les actions de sa classe ;
##   - "creature"  : une créature du bestiaire (ennemi ou invocation), contrôlée par l'IA.
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


## Actions de l'IA : celles de la créature, ou les actions de compagnon de la classe.
func ai_actions() -> Array:
	if character != null:
		return DB.classes[character.class_id].get("companion_actions", [])
	return creature.get("actions", [])


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
	var ability := "weapon" if _uses_own_weapon(effect) else String(effect.get("ability", "weapon"))
	return character.attack_bonus(ability)


## Expression de dégâts d'un effet "attack" ou "damage", ex. « 1d8+3+1d6 ».
func damage_expr(effect: Dictionary) -> String:
	var expr: String = effect.get("damage", "1")
	var bonus := 0
	if _uses_own_weapon(effect):
		expr = character.weapon_damage()
		bonus += Modifiers.sum(character.modifiers(), "weapon_damage") + character.ability_mod(character.action_ability("weapon"))
	elif effect.get("weapon") is String:
		expr = Equipment.weapon_damage(effect["weapon"])
	elif effect.get("add_mod", false) and character != null:
		bonus += character.ability_mod(character.action_ability(effect.get("ability", "str")))
	expr = Dice.add_mod(expr, bonus)
	if effect.has("extra_damage"):
		expr += "+" + effect["extra_damage"]
	return expr


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
