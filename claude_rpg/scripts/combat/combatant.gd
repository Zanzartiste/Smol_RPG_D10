class_name Combatant
extends RefCounted
## Participant à un combat : un membre du groupe (Character) ou un ennemi (enemies.json).
## Pour un membre du groupe, les PV sont ceux du personnage : les dégâts persistent après le combat.

var id := ""  # unique dans le combat
var name := ""
var side := "ally"  # "ally" ou "enemy"
var character: Character  # alliés uniquement
var enemy: Dictionary = {}  # ennemis uniquement
var is_hero := false
var initiative := 0
var uses: Dictionary = {}  # id d'action -> utilisations restantes dans ce combat (per_combat)
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
	c.id = "hero" if hero else "ally_" + ch.template_id
	c.name = ch.name
	c.is_hero = hero
	c._reset_uses()
	return c


static func from_enemy(enemy_id: String, label: String, rng: RandomNumberGenerator) -> Combatant:
	var c := Combatant.new()
	c.enemy = DB.enemies[enemy_id]
	c.side = "enemy"
	c.name = label
	c._max_hp = maxi(1, Dice.roll_expr(c.enemy["hp"], rng)["total"])
	c._hp = c._max_hp
	return c


func is_ally() -> bool:
	return side == "ally"


func is_alive() -> bool:
	return hp > 0


func max_hp() -> int:
	return character.max_hp if character != null else _max_hp


func armor_class() -> int:
	return character.armor_class() if character != null else int(enemy.get("ac", 10))


func ability_mod(ability_id: String) -> int:
	if character != null:
		return character.ability_mod(ability_id)
	return Abilities.modifier(int(enemy.get("abilities", {}).get(ability_id, 10)))


func initiative_bonus() -> int:
	return character.initiative_bonus() if character != null else ability_mod("dex")


## Résistances, immunités et vulnérabilités (voir Defenses).
func defenses() -> Defenses:
	return character.all_defenses() if character != null else Defenses.from_dict(enemy.get("defenses", {}))


## Taille (pour l'affichage) : espèce du personnage ou taille de l'ennemi.
func size() -> String:
	return character.size() if character != null else enemy.get("size", "medium")


## Actions de combat disponibles (définitions d'actions.json, ou attaques de l'ennemi).
func actions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if character != null:
		for action_id: String in DB.classes[character.class_id].get("actions", []):
			result.append(DB.actions[action_id])
	else:
		var attacks: Array = enemy.get("attacks", [])
		for i in attacks.size():
			var attack: Dictionary = attacks[i]
			# Une attaque peut citer une arme du catalogue (Equipment) au lieu de dégâts explicites.
			var weapon: String = attack.get("weapon", "")
			var damage: String = attack.get("damage", Equipment.weapon_damage(weapon) if weapon != "" else "1")
			if attack.has("damage_bonus"):
				damage = Dice.add_mod(damage, int(attack["damage_bonus"]))
			result.append({
				"id": "enemy_attack_%d" % i, "name": attack["name"], "type": "attack", "target": "enemy",
				"to_hit": int(attack["to_hit"]), "damage": damage,
				"damage_type": attack.get("damage_type", Equipment.damage_type_of(weapon) if weapon != "" else "bludgeoning"),
			})
	return result


## Bonus au jet d'attaque pour une action.
func attack_bonus(action: Dictionary) -> int:
	if action.has("to_hit"):
		return int(action["to_hit"])
	return character.attack_bonus(action.get("ability", "weapon"))


## Expression de dégâts d'une action, ex. « 1d8+3 » ou « 1d8+3+1d6 ».
func damage_expr(action: Dictionary) -> String:
	var expr: String = action.get("damage", "1")
	if character == null:
		return expr
	var ability := character.action_ability(action.get("ability", "weapon"))
	var bonus := 0
	if expr == "weapon":
		expr = character.weapon_damage()
		bonus += Modifiers.sum(character.modifiers(), "weapon_damage")
	if action.get("add_mod", false):
		bonus += character.ability_mod(ability)
	expr = Dice.add_mod(expr, bonus)
	if action.has("extra_damage"):
		expr += "+" + action["extra_damage"]
	return expr


## Type de dégâts d'une action ("weapon" = celui de l'arme en main).
func damage_type(action: Dictionary) -> String:
	var type: String = action.get("damage_type", "")
	if type == "weapon" and character != null:
		return character.weapon_damage_type()
	return type


## Expression de soins, « level » étant remplacé par le niveau du personnage.
func heal_expr(action: Dictionary) -> String:
	var level := character.level if character != null else 1
	return String(action.get("heal", "1")).replace("level", str(level))


## Une action peut-elle être utilisée ? Retourne "" si oui, sinon la raison.
func unavailable_reason(action: Dictionary) -> String:
	if action.has("per_combat") and int(uses.get(action["id"], 0)) <= 0:
		return Loc.ui("déjà utilisé")
	if action.has("cost") and character != null and int(character.resources.get(action["cost"], 0)) <= 0:
		return Loc.ui("plus d'emplacement")
	return ""


func consume(action: Dictionary) -> void:
	if action.has("per_combat"):
		uses[action["id"]] = int(uses.get(action["id"], 0)) - 1
	if action.has("cost") and character != null:
		character.resources[action["cost"]] = int(character.resources.get(action["cost"], 0)) - 1


func _reset_uses() -> void:
	for action in actions():
		if action.has("per_combat"):
			uses[action["id"]] = int(action["per_combat"])
