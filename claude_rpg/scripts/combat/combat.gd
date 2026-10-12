class_name Combat
extends RefCounted
## Déroulement d'un combat au tour par tour, façon D&D 5e simplifié :
## initiative (d20 + DEX), jets d'attaque contre la CA, dégâts, critiques sur 20 naturel.
## Aucune dépendance à l'interface : chaque action retourne une liste d'« étapes » (texte + jet de dés)
## que l'interface anime, l'état étant déjà à jour.
##
## Spécification (effet "combat" d'un événement) :
##   {"enemies": ["wolf", ...], "flee": true, "flee_dc": 12, "on_defeat": "death" | "knockout",
##    "victory": {text, effects}, "defeat": {text, effects}, "fled": {text, effects}}

const ACTION_ITEM := "_item"
const ACTION_FLEE := "_flee"
const DEFAULT_FLEE_DC := 12

var spec: Dictionary
var life: LifeState
var rng: RandomNumberGenerator
var combatants: Array[Combatant] = []
var order: Array[Combatant] = []  # ordre d'initiative
var turn := 0  # index dans `order`
var round_number := 1
var outcome := ""  # "" en cours, puis "victory", "defeat" ou "fled"
var log: Array[String] = []


func _init(combat_spec: Dictionary, life_state: LifeState) -> void:
	spec = combat_spec
	life = life_state
	rng = life.rng
	combatants.append(Combatant.from_character(life.character, true))
	for companion in life.companions:
		if companion.hp > 0:
			combatants.append(Combatant.from_character(companion, false))
	var enemy_ids: Array = spec.get("enemies", [])
	for i in enemy_ids.size():
		var id: String = enemy_ids[i]
		var label: String = DB.enemies[id]["name"]
		if enemy_ids.count(id) > 1:
			label += " " + "ABCDEFGH"[enemy_ids.slice(0, i).count(id)]
		var enemy := Combatant.from_enemy(id, label, rng)
		enemy.id = "enemy_%d" % i
		combatants.append(enemy)
	_roll_initiative()


# --- Accès -------------------------------------------------------------------

func current() -> Combatant:
	return order[turn]


func is_over() -> bool:
	return outcome != ""


func allies() -> Array[Combatant]:
	return _select(func(c): return c.is_ally())


func enemies() -> Array[Combatant]:
	return _select(func(c): return not c.is_ally())


func living(side: String) -> Array[Combatant]:
	return _select(func(c): return c.side == side and c.is_alive())


func _select(predicate: Callable) -> Array[Combatant]:
	var result: Array[Combatant] = []
	for c in combatants:
		if predicate.call(c):
			result.append(c)
	return result


func can_flee() -> bool:
	return spec.get("flee", true)


func flee_dc() -> int:
	return int(spec.get("flee_dc", DEFAULT_FLEE_DC))


## Objets du héros utilisables en combat : [{item, count}].
func usable_items() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item_id: String in life.character.inventory:
		if DB.items[item_id].has("use"):
			result.append({"item": DB.items[item_id], "count": life.character.item_count(item_id)})
	return result


## Cibles possibles d'une action pour un acteur.
func targets(actor: Combatant, action: Dictionary) -> Array[Combatant]:
	var opponents := "enemy" if actor.is_ally() else "ally"
	match action.get("target", "enemy"):
		"self":
			var only_self: Array[Combatant] = [actor]
			return only_self
		"ally":
			return living(actor.side)
	return living(opponents)


# --- Actions -----------------------------------------------------------------

## Effectue une action. `action` est une définition d'actions.json (ou d'attaque ennemie),
## ou {"id": "_item", "item": id} / {"id": "_flee"}. Retourne les étapes à animer :
## [{"text": String, "roll": Dictionary (pour le plateau de dés, peut être vide), "fast": bool}].
func perform(actor: Combatant, action: Dictionary, target: Combatant = null) -> Array[Dictionary]:
	var beats: Array[Dictionary] = []
	var fast := not actor.is_ally()
	match action.get("id"):
		ACTION_FLEE:
			_flee(actor, beats)
		ACTION_ITEM:
			_use_item(actor, action, target, beats)
		_:
			actor.consume(action)
			match action.get("type", "attack"):
				"attack":
					_attack(actor, action, target, beats, fast)
				"auto":
					_damage(actor, action, target, false, beats, fast,
						Loc.ui("%s lance %s sur %s.") % [actor.name, action["name"], target.name])
				"heal":
					_heal(actor, target if target != null else actor, actor.heal_expr(action), action["name"], beats, fast)
	for beat in beats:
		log.append(beat["text"])
	_check_end()
	return beats


## Choix automatique : un ennemi attaque un membre du groupe au hasard ; un allié (tests, simulations,
## futur combat automatique) choisit l'attaque aux dégâts attendus les plus élevés contre l'ennemi le plus faible.
func auto_choice(actor: Combatant) -> Dictionary:
	var options := actor.actions().filter(func(a): return actor.unavailable_reason(a) == "" and a.get("target") != "self")
	if not actor.is_ally():
		var action: Dictionary = options[rng.randi_range(0, options.size() - 1)]
		var candidates := targets(actor, action)
		return {"action": action, "target": candidates[rng.randi_range(0, candidates.size() - 1)]}
	var best: Dictionary = options[0]
	for action: Dictionary in options:
		if _expected_damage(actor, action) > _expected_damage(actor, best):
			best = action
	var weakest := targets(actor, best)
	weakest.sort_custom(func(a, b): return a.hp < b.hp)
	return {"action": best, "target": weakest[0]}


## Dégâts moyens d'une action (contre une CA moyenne de 12 pour les attaques).
func _expected_damage(actor: Combatant, action: Dictionary) -> float:
	var damage := Dice.average(actor.damage_expr(action))
	if action.get("type") == "attack":
		damage *= clampf((21.0 - (12 - actor.attack_bonus(action))) / 20.0, 0.05, 0.95)
	return damage


## Passe au combattant vivant suivant (nouveau round après le dernier).
func end_turn() -> void:
	if is_over():
		return
	for i in order.size():
		turn += 1
		if turn >= order.size():
			turn = 0
			round_number += 1
			log.append(Loc.ui("— Round %d —") % round_number)
		if current().is_alive():
			return


func _attack(actor: Combatant, action: Dictionary, target: Combatant, beats: Array[Dictionary], fast: bool) -> void:
	var bonus := actor.attack_bonus(action)
	var die := rng.randi_range(1, 20)
	var ac := target.armor_class()
	var critical := die == 20
	var hit := critical or (die != 1 and die + bonus >= ac)
	var text := Loc.ui("%s attaque %s (%s) : %d + %d = %d contre CA %d — %s") % [
		actor.name, target.name, action["name"], die, bonus, die + bonus, ac,
		Loc.ui("coup critique !") if critical else (Loc.ui("touché") if hit else Loc.ui("raté"))]
	beats.append({"text": text, "fast": fast, "roll": {
		"dice": [{"sides": 20, "value": die}], "mod": bonus, "dc": ac, "dc_label": "CA",
		"success": hit, "stat": "%s → %s" % [action["name"], target.name]}})
	if hit:
		_damage(actor, action, target, critical, beats, fast, "")


func _damage(actor: Combatant, action: Dictionary, target: Combatant, critical: bool,
		beats: Array[Dictionary], fast: bool, intro: String) -> void:
	var expr := actor.damage_expr(action)
	var roll := Dice.roll_expr(expr, rng, critical)
	var type := actor.damage_type(action)
	var applied := DamageTypes.apply(maxi(1, int(roll["total"])), type, target.defenses())
	var amount: int = applied["amount"]
	target.hp = maxi(0, target.hp - amount)
	var text := Loc.ui("%s subit %d dégâts") % [target.name, amount]
	if type != "":
		text += " " + DamageTypes.name_of(type).to_lower()
	text += (" (%s)." % applied["note"]) if applied["note"] != "" else "."
	if intro != "":
		text = intro + " " + text
	if not target.is_alive():
		text += " " + _on_down(target, actor)
	beats.append({"text": text, "fast": true, "roll": {
		"dice": roll["dice"], "mod": roll["bonus"],
		"stat": Loc.ui("Dégâts (%s %s)") % [expr, DamageTypes.name_of(type).to_lower()] if type != "" else Loc.ui("Dégâts (%s)") % expr}})


func _heal(actor: Combatant, target: Combatant, expr: String, source: String,
		beats: Array[Dictionary], fast: bool) -> void:
	var roll := Dice.roll_expr(expr, rng)
	var before := target.hp
	target.hp = mini(target.max_hp(), target.hp + maxi(1, int(roll["total"])))
	beats.append({"text": Loc.ui("%s : %s récupère %d PV.") % [source, target.name, target.hp - before],
		"fast": fast, "roll": {"dice": roll["dice"], "mod": roll["bonus"], "stat": Loc.ui("Soins (%s)") % expr}})


func _use_item(actor: Combatant, action: Dictionary, target: Combatant, beats: Array[Dictionary]) -> void:
	var item: Dictionary = DB.items[action["item"]]
	life.character.remove_item(item["id"])
	var use: Dictionary = item["use"]
	if use.has("heal"):
		_heal(actor, target if target != null else actor, use["heal"], item["name"], beats, false)


func _flee(actor: Combatant, beats: Array[Dictionary]) -> void:
	var die := rng.randi_range(1, 20)
	var mod := actor.ability_mod("dex")
	var success := die == 20 or (die != 1 and die + mod >= flee_dc())
	beats.append({"fast": false, "text": Loc.ui("%s tente de fuir : %s.") % [
		actor.name, Loc.ui("réussite") if success else Loc.ui("échec")], "roll": {
		"dice": [{"sides": 20, "value": die}], "mod": mod, "dc": flee_dc(), "success": success,
		"stat": Loc.ui("Fuite (Dextérité)")}})
	if success:
		outcome = "fled"


## Un combattant tombe à 0 PV. Le héros meurt si le combat est mortel. Retourne le texte à afficher.
func _on_down(target: Combatant, attacker: Combatant) -> String:
	if not target.is_ally():
		return Loc.ui("%s est vaincu.") % target.name
	if spec.get("on_defeat", "death") == "knockout":
		return Loc.ui("%s s'effondre, assommé.") % target.name
	if target.is_hero:
		life.die(attacker.enemy.get("death_cause", Loc.ui("Tué par %s") % attacker.name))
	return Loc.ui("%s s'effondre.") % target.name


func _check_end() -> void:
	if outcome != "":
		return
	var hero_down := not combatants[0].is_alive()
	if life.dead or hero_down or living("ally").is_empty():
		outcome = "defeat"
	elif living("enemy").is_empty():
		outcome = "victory"
	if outcome != "":
		log.append({"victory": Loc.ui("Victoire !"), "defeat": Loc.ui("Défaite…")}[outcome])


func _roll_initiative() -> void:
	var parts := PackedStringArray()
	for c in combatants:
		c.initiative = rng.randi_range(1, 20) + c.initiative_bonus()
	order = combatants.duplicate()
	order.sort_custom(func(a, b): return a.initiative > b.initiative \
		or (a.initiative == b.initiative and a.ability_mod("dex") > b.ability_mod("dex")))
	for c in order:
		parts.append("%s %d" % [c.name, c.initiative])
	log.append(Loc.ui("Initiative : %s") % ", ".join(parts))
	log.append(Loc.ui("— Round %d —") % round_number)
