class_name Combat
extends RefCounted
## Combat au tour par tour façon D&D 5e simplifié. Aucune dépendance à l'interface : chaque action
## retourne des « étapes » (texte + jet de dés) que l'interface anime, l'état étant déjà à jour.
##
## Déroulement : ordre d'initiative (d20 + DEX). Chaque tour commence par start_turn() (effets des
## états, tour passé si étourdi), puis le combattant fait UNE action (plus s'il a une action en plus,
## ex. Fougue : voir `actions_left`) :
##   - héros et compagnons (contrôlés par le joueur) : une action de classe (perform), un objet
##     (use_item) ou la fuite (flee) ;
##   - créatures (ennemis, invocations) : ai_turn(). Un ennemi peut « préparer » une action annoncée.
## end_turn() passe au suivant. Réglages : rules.json › combat.
##
## Spécification (effet "combat" d'un événement) :
##   {"enemies": ["wolf", ...], "flee": true, "flee_dc": 12, "on_defeat": "death" | "knockout",
##    "victory": {text, effects}, "defeat": {text, effects}, "fled": {text, effects}}

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
var hero: Combatant
var skipped := false  # le combattant actif passe son tour (étourdi, mort pendant ses états…)
var actions_left := 1  # actions restantes au combattant actif pendant ce tour
var _next_id := 0


static func setting(key: String, default: Variant) -> Variant:
	return DB.rules.get("combat", {}).get(key, default)


## Places occupées par une créature d'une taille donnée.
static func size_slots(size: String) -> float:
	return float(setting("size_slots", {}).get(size, 1.0))


func _init(combat_spec: Dictionary, life_state: LifeState) -> void:
	spec = combat_spec
	life = life_state
	rng = life.rng
	hero = Combatant.from_character(life.character, true)
	combatants.append(hero)
	for companion in life.companions:
		var c := Combatant.from_character(companion, false)
		if companion.hp > 0 and can_add("ally", c.size()):
			combatants.append(c)
	var enemy_ids: Array = spec.get("enemies", [])
	for i in enemy_ids.size():
		var id: String = enemy_ids[i]
		var label := Creatures.name_of(id)
		if enemy_ids.count(id) > 1:
			label += " " + "ABCDEFGH"[enemy_ids.slice(0, i).count(id)]
		_add(Combatant.from_creature(id, label, "enemy", rng))
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


func can_flee() -> bool:
	return spec.get("flee", true)


## Le combattant actif peut-il fuir (Entravé l'en empêche) ?
func can_flee_now(actor: Combatant) -> bool:
	return can_flee() and not actor.has_status_flag("no_flee")


## Avantage d'une attaque : états de l'attaquant et de la cible (+1, -1 ou 0).
func attack_advantage(actor: Combatant, target: Combatant) -> int:
	var advantages := (1 if actor.has_status_flag("attack_advantage") else 0) + (1 if target.has_status_flag("attacked_advantage") else 0)
	var disadvantages := (1 if actor.has_status_flag("attack_disadvantage") else 0) + (1 if target.has_status_flag("attacked_disadvantage") else 0)
	return Dice.combine_advantage(advantages, disadvantages)


func flee_dc() -> int:
	return int(spec.get("flee_dc", DEFAULT_FLEE_DC))


func capacity_used(side: String) -> float:
	var used := 0.0
	for c in living(side):
		used += c.slots()
	return used


func can_add(side: String, size: String) -> bool:
	return capacity_used(side) + size_slots(size) <= float(setting("side_capacity", 4)) + 0.001


## Objets du héros utilisables en combat : [{item, count}].
func usable_items() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item_id: String in life.character.inventory:
		if Items.is_usable(item_id):
			result.append({"item": Items.def(item_id), "count": life.character.item_count(item_id)})
	return result


## Cibles possibles pour un acteur et un type de cible ("enemy", "ally", "self"…).
func targets(actor: Combatant, target: String) -> Array[Combatant]:
	var opposing := "enemy" if actor.is_ally() else "ally"
	match target:
		"self":
			var only_self: Array[Combatant] = [actor]
			return only_self
		"ally", "all_allies":
			return living(actor.side)
		"enemy", "all_enemies":
			return living(opposing)
	var none: Array[Combatant] = []
	return none


## Actions d'un personnage pour l'interface : [{action, available, reason}]. Un sort qui s'améliore
## avec le niveau d'emplacement apparaît une fois par niveau disponible (voir Combatant.action_variants).
func action_choices(actor: Combatant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for base in actor.combat_actions():
		for action in actor.action_variants(base):
			var reason := action_unavailable_reason(actor, action)
			result.append({"action": action, "available": reason == "", "reason": reason})
	return result


## Le combattant actif peut-il encore agir pendant ce tour ?
func can_act_again() -> bool:
	return actions_left > 0 and not is_over() and current().is_alive()


func action_unavailable_reason(actor: Combatant, action: Dictionary) -> String:
	var reason := actor.unavailable_reason(action)
	if reason != "":
		return reason
	var target: String = action.get("target", "enemy")
	if target in ["enemy", "all_enemies"] and living("enemy").is_empty():
		return Loc.ui("aucune cible")
	for e: Dictionary in action.get("effects", []):
		if e.get("type") == "summon" and not can_add(actor.side, Creatures.size_of(e["creature"])):
			return Loc.ui("plus de place dans votre camp")
	return ""


# --- Tours -------------------------------------------------------------------

## Début du tour du combattant actif : effets des états. Après l'appel, `skipped` indique si le
## combattant passe son tour.
func start_turn() -> Array[Dictionary]:
	var actor := current()
	var beats: Array[Dictionary] = []
	skipped = false
	actions_left = 1
	actor.reaction_used = false
	for status_id: String in actor.statuses.keys():
		var stacks := actor.stacks(status_id)
		var damage := StatusEffects.tick_damage(status_id, stacks, actor.max_hp())
		if damage > 0:
			var type := StatusEffects.tick_damage_type(status_id)
			var dealt := _deal_damage(null, actor, damage, type, type == "", StatusEffects.death_cause(status_id))
			_beat(beats, Loc.ui("%s : %s subit %d dégâts") % [StatusEffects.name_of(status_id), actor.name, dealt["amount"]]
				+ dealt["suffix"])
		if StatusEffects.skips_turn(status_id) and stacks > 0:
			skipped = true
			_beat(beats, Loc.ui("%s est %s et passe son tour.") % [actor.name, StatusEffects.name_of(status_id).to_lower()])
		if not StatusEffects.decays_at_end(status_id):
			_decay(actor, status_id)
	if not actor.is_alive():
		skipped = true
	_check_end()
	return beats


## Passe au combattant vivant suivant (nouveau round après le dernier).
func end_turn() -> void:
	var actor := current()
	for status_id: String in actor.statuses.keys():
		if StatusEffects.decays_at_end(status_id):
			_decay(actor, status_id)
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


# --- Actions des personnages (joueur) ----------------------------------------

## Effectue une action de classe. `target` est requis pour les cibles "enemy" / "ally".
## L'action Attaque frappe plusieurs fois avec Attaque supplémentaire : si la cible tombe, les coups
## suivants visent l'ennemi le plus faible.
func perform(actor: Combatant, action: Dictionary, target: Combatant = null) -> Array[Dictionary]:
	actor.consume(action)
	if not action.get("free", false):
		actions_left -= 1
	var beats: Array[Dictionary] = []
	_beat(beats, Loc.ui("%s : %s.") % [actor.name, action["name"]])
	var attacks := 1 + (actor.extra_attacks() if action.get("attack_action", false) else 0)
	for i in attacks:
		if i > 0:
			if target == null or not target.is_alive():
				var others := living("enemy" if actor.is_ally() else "ally")
				if others.is_empty():
					break
				others.sort_custom(func(a, b): return a.hp < b.hp)
				target = others[0]
			_beat(beats, Loc.ui("%s : attaque supplémentaire.") % actor.name)
		beats.append_array(_resolve(actor, action.get("effects", []), action.get("target", "enemy"), target,
			not actor.is_player_controlled()))
		if is_over():
			break
	_check_end()
	return beats


## Utilise un objet de l'inventaire du héros (soins, antidote…).
func use_item(actor: Combatant, item_id: String, target: Combatant) -> Array[Dictionary]:
	var item: Dictionary = Items.def(item_id)
	life.character.remove_item(item_id)
	actions_left -= 1
	var effects: Array = []
	var use: Dictionary = item["use"]
	if use.has("heal"):
		effects.append({"type": "heal", "amount": use["heal"]})
	if use.has("cleanse"):
		effects.append({"type": "cleanse", "status": use["cleanse"]})
	var beats: Array[Dictionary] = []
	_beat(beats, Loc.ui("%s utilise : %s.") % [actor.name, item["name"]])
	beats.append_array(_resolve(actor, effects, "ally", target, false))
	_check_end()
	return beats


## Tentative de fuite du groupe : d20 + DEX contre le DD de fuite.
func flee(actor: Combatant) -> Array[Dictionary]:
	var advantage := -1 if actor.has_status_flag("check_disadvantage") else 0
	var d20 := Dice.roll_d20(rng, advantage)
	var die := int(d20["die"])
	var mod := actor.check_mod("dex")
	var success := die == 20 or (die != 1 and die + mod >= flee_dc())
	actions_left = 0
	var beats: Array[Dictionary] = []
	_beat(beats, Loc.ui("%s tente de fuir : %s.") % [actor.name, Loc.ui("réussite") if success else Loc.ui("échec")],
		{"dice": d20["dice"], "mod": mod, "dc": flee_dc(), "success": success, "advantage": advantage,
		"stat": Loc.ui("Fuite (Dextérité)") + Dice.advantage_text(advantage)})
	if success:
		outcome = "fled"
	return beats


# --- Tours de l'IA -----------------------------------------------------------

## Tour d'une créature (ennemi ou invocation). Un ennemi qui a préparé une action l'exécute ; sinon il
## en choisit une (pondérée) et, si elle est « préparée », se contente de l'annoncer.
func ai_turn(actor: Combatant) -> Array[Dictionary]:
	var beats: Array[Dictionary] = []
	var action: Dictionary
	if not actor.intent.is_empty():
		action = actor.intent
		actor.intent = {}
	else:
		action = _pick_action(actor)
		if action.is_empty():
			_beat(beats, Loc.ui("%s ne fait rien.") % actor.name)
			return beats
		if action.get("prepared", false) and not actor.is_ally():
			actor.intent = action
			_beat(beats, Loc.ui("%s prépare : %s !") % [actor.name, action["name"]])
			return beats
	var target_mode: String = action.get("target", "enemy")
	var chosen: Combatant = null
	if target_mode in CombatEffects.CHOSEN_TARGETS:
		var candidates := targets(actor, target_mode)
		if candidates.is_empty():
			return beats
		candidates.sort_custom(func(a, b): return a.hp < b.hp)
		# Les invocations alliées visent le plus faible, les ennemis choisissent au hasard.
		chosen = candidates[0] if actor.is_ally() else candidates[rng.randi_range(0, candidates.size() - 1)]
	_beat(beats, Loc.ui("%s : %s.") % [actor.name, action["name"]])
	beats.append_array(_resolve(actor, action.get("effects", []), target_mode, chosen, not actor.is_ally()))
	_check_end()
	return beats


func _pick_action(actor: Combatant) -> Dictionary:
	var actions := actor.combat_actions().filter(func(a): return (a.get("target") == "none" \
		or not targets(actor, a.get("target", "enemy")).is_empty()) and actor.unavailable_reason(a) == "")
	var total := 0.0
	for a: Dictionary in actions:
		total += float(a.get("weight", 1))
	var r := rng.randf() * total
	for a: Dictionary in actions:
		r -= float(a.get("weight", 1))
		if r < 0.0:
			return a
	return actions.back() if not actions.is_empty() else {}


## Joue automatiquement toutes les actions d'un personnage pour ce tour (tests, banc d'équilibrage).
func auto_turn(actor: Combatant) -> Array[Dictionary]:
	var beats: Array[Dictionary] = []
	for guard in 5:
		if not can_act_again():
			break
		var choice := auto_choice(actor)
		if choice["action"].is_empty():
			break
		beats.append_array(perform(actor, choice["action"], choice["target"]))
	return beats


## Choix automatique pour un personnage (tests, banc d'équilibrage, futur combat automatique) :
## l'action disponible la plus utile (dégâts attendus, soins ou protection si les PV sont bas),
## contre l'ennemi le plus faible.
func auto_choice(actor: Combatant) -> Dictionary:
	var best: Dictionary = {}
	var best_score := -1.0
	for choice in action_choices(actor):
		if not choice["available"]:
			continue
		var score := _action_score(actor, choice["action"])
		if score > best_score:
			best_score = score
			best = choice["action"]
	var target: Combatant = null
	var mode: String = best.get("target", "enemy")
	if mode in CombatEffects.CHOSEN_TARGETS:
		var candidates := targets(actor, mode)
		if mode == "ally":
			candidates.sort_custom(func(a, b): return float(a.hp) / a.max_hp() < float(b.hp) / b.max_hp())
		else:
			candidates.sort_custom(func(a, b): return a.hp < b.hp)
		target = candidates[0]
	return {"action": best, "target": target}


func _action_score(actor: Combatant, action: Dictionary) -> float:
	var score := 0.0
	var spread := living("enemy").size() if action.get("target") == "all_enemies" else 1
	var hurt := actor.hp < actor.max_hp() * 0.5
	var attacks := 1 + (actor.extra_attacks() if action.get("attack_action", false) else 0)
	for e: Dictionary in action.get("effects", []):
		match e.get("type"):
			"attack":
				var chance := clampf((21.0 - (12 - actor.attack_bonus(e))) / 20.0, 0.05, 0.95)
				var average := Dice.average(actor.damage_expr(e))
				for part: Dictionary in actor.bonus_damage(e):
					average += Dice.average(part["damage"])
				score += average * chance * spread * attacks
			"damage":
				score += Dice.average(actor.damage_expr(e)) * spread * (0.75 if e.has("save") else 1.0)
			"extra_action":
				score += 8.0
			"heal":
				score += Dice.average(actor.heal_expr(String(e["amount"]))) if hurt else 0.0
			"status":
				var stacks := int(e["stacks"])
				match e["status"]:
					"shielded":
						score += stacks * (0.8 if hurt else 0.3)
					"stunned":
						score += 4.0 * spread
					_:
						score += stacks * 1.2 * spread
			"summon":
				score += 5.0
	# Les ressources limitées (emplacements, utilisations par combat) valent un peu moins, et un
	# emplacement de niveau supérieur encore moins.
	if action.has("cost") or action.has("per_combat"):
		score *= 0.9
	if action.has("slot_level"):
		score *= 1.0 - 0.08 * (int(action["slot_level"]) - int(action.get("spell_level", 1)))
	return score


# --- Résolution des effets ---------------------------------------------------

## Applique une liste d'effets. `target_mode` : "enemy", "all_enemies", "ally", "all_allies", "self", "none".
## Les effets qui suivent une attaque ratée ou un jet de sauvegarde réussi sont ignorés (jusqu'à
## l'attaque ou la sauvegarde suivante).
func _resolve(actor: Combatant, effects: Array, target_mode: String, chosen: Combatant, fast: bool) -> Array[Dictionary]:
	var beats: Array[Dictionary] = []
	var target_list: Array[Combatant] = []
	if target_mode in CombatEffects.CHOSEN_TARGETS:
		if chosen != null:
			target_list.append(chosen)
	else:
		target_list = targets(actor, target_mode)
	for e: Dictionary in effects:
		if e.get("type") in CombatEffects.UNTARGETED:
			beats.append_array(_apply(actor, e, null, fast)["beats"])
	for target in target_list:
		var hit := true
		for e: Dictionary in effects:
			if e.get("type") in CombatEffects.UNTARGETED:
				continue
			if e.get("type") == "attack" or e.has("save"):
				if not target.is_alive():
					break
				var result := _apply(actor, e, target, fast)
				beats.append_array(result["beats"])
				hit = result["hit"]
			elif hit and target.is_alive():
				beats.append_array(_apply(actor, e, target, fast)["beats"])
	return beats


## Applique un effet à une cible. Retourne {"beats", "hit"} (hit : attaque réussie ou sauvegarde ratée).
func _apply(actor: Combatant, e: Dictionary, target: Combatant, fast: bool) -> Dictionary:
	var beats: Array[Dictionary] = []
	var hit := true
	var multiplier := 1.0
	if e.has("save"):
		var save: Dictionary = e["save"]
		var saved := _saving_throw(actor, target, save, beats, fast)
		hit = not saved
		var half: bool = save.get("half", false) and e.get("type") == "damage"
		var evasion: bool = half and save["ability"] == "dex" and target.has_modifier("evasion")
		if saved:
			multiplier = 0.0 if evasion or not half else 0.5
		elif evasion:
			multiplier = 0.5
		if multiplier == 0.0:
			_beat(beats, Loc.ui("%s n'est pas affecté.") % target.name)
			return {"beats": beats, "hit": hit}
		if saved and not half:
			return {"beats": beats, "hit": hit}
	match e.get("type"):
		"attack":
			var bonus := actor.attack_bonus(e)
			var advantage := attack_advantage(actor, target)
			var d20 := Dice.roll_d20(rng, advantage)
			var die := int(d20["die"])
			var ac := target.armor_class()
			hit = die == 20 or (die != 1 and die + bonus >= ac)
			var critical := hit and (die >= actor.critical_threshold() or target.has_status_flag("attacked_critical"))
			var text := Loc.ui("%s attaque %s%s : %d + %d = %d contre CA %d — %s") % [
				actor.name, target.name, Dice.advantage_text(advantage), die, bonus, die + bonus, ac,
				Loc.ui("coup critique !") if critical else (Loc.ui("touché") if hit else Loc.ui("raté"))]
			_beat(beats, text, {"dice": d20["dice"], "mod": bonus, "dc": ac, "dc_label": "CA", "advantage": advantage,
				"success": hit, "stat": "%s → %s%s" % [actor.name, target.name, Dice.advantage_text(advantage)]}, fast)
			if hit:
				_roll_damage(actor, target, actor.damage_expr(e), actor.damage_type(e), critical, beats, 1.0, true)
				_roll_bonus_damage(actor, target, e, critical, beats, 1.0)
		"damage":
			_roll_damage(actor, target, actor.damage_expr(e), actor.damage_type(e), false, beats, multiplier)
			_roll_bonus_damage(actor, target, e, false, beats, multiplier)
		"heal":
			var expr := actor.heal_expr(String(e["amount"]))
			var roll := Dice.roll_expr(expr, rng)
			var before := target.hp
			target.hp = mini(target.max_hp(), target.hp + maxi(1, int(roll["total"])))
			_beat(beats, Loc.ui("%s récupère %d PV.") % [target.name, target.hp - before],
				{"dice": roll["dice"], "mod": roll["bonus"], "stat": Loc.ui("Soins (%s)") % expr}, true)
		"status":
			var status: String = e["status"]
			if target.defenses().is_immune_to_status(status):
				_beat(beats, Loc.ui("%s est immunisé contre %s.") % [target.name, StatusEffects.name_of(status)])
			else:
				target.add_status(status, int(e["stacks"]))
				_beat(beats, Loc.ui("%s : +%d %s (%d).") % [target.name, int(e["stacks"]), StatusEffects.name_of(status),
					target.stacks(status)])
		"cleanse":
			var removed := PackedStringArray()
			for status_id: String in target.statuses.keys():
				if status_id == e["status"] or (e["status"] == "negative" and StatusEffects.is_negative(status_id)):
					target.remove_status(status_id)
					removed.append(StatusEffects.name_of(status_id))
			if not removed.is_empty():
				_beat(beats, Loc.ui("%s n'est plus affecté par : %s.") % [target.name, ", ".join(removed)])
		"extra_action":
			actions_left += 1
			_beat(beats, Loc.ui("%s peut agir une fois de plus.") % actor.name)
		"summon":
			var creature_id: String = e["creature"]
			if can_add(actor.side, Creatures.size_of(creature_id)):
				var summon := Combatant.from_creature(creature_id, Creatures.name_of(creature_id), actor.side, rng)
				summon.summoned = true
				summon.initiative = actor.initiative
				_add(summon)
				order.append(summon)
				_beat(beats, Loc.ui("%s invoque : %s.") % [actor.name, summon.name])
	return {"beats": beats, "hit": hit}


## Lance et inflige des dégâts. `multiplier` : 0.5 pour une sauvegarde réussie (moitié, arrondie à
## l'inférieur). `from_attack` : dégâts d'une attaque, que l'Esquive instinctive peut diviser par deux.
func _roll_damage(actor: Combatant, target: Combatant, expr: String, type: String, critical: bool,
		beats: Array[Dictionary], multiplier := 1.0, from_attack := false, main := true) -> void:
	if not target.is_alive():
		return
	var roll := Dice.roll_expr(expr, rng, critical)
	var notes := PackedStringArray()
	if multiplier < 1.0:
		notes.append(Loc.ui("moitié"))
	if from_attack and target.has_modifier("uncanny_dodge") and not target.reaction_used:
		target.reaction_used = true
		multiplier *= 0.5
		notes.append(Loc.ui("esquive instinctive"))
	var amount := maxi(1, int(roll["total"]) + (actor.damage_modifier() if main else 0))
	amount = maxi(1 if multiplier >= 1.0 else 0, int(floor(amount * multiplier)))
	var dealt := _deal_damage(actor, target, amount, type, false, "")
	var inflicted := _status_from_damage(target, type, dealt["amount"])
	var text := Loc.ui("%s subit %d dégâts") % [target.name, dealt["amount"]]
	if not notes.is_empty():
		text += " (%s)" % ", ".join(notes)
	if type != "":
		text += " " + DamageTypes.bbcode_name(type)
	text += dealt["suffix"] + inflicted
	var label := Loc.ui("Dégâts (%s %s)") % [expr, DamageTypes.name_of(type).to_lower()] if type != "" else Loc.ui("Dégâts (%s)") % expr
	_beat(beats, text, {"dice": roll["dice"], "mod": roll["bonus"], "stat": label}, true)


## Dégâts d'autres types d'un effet (et de l'arme) : lancés séparément, chacun avec ses défenses.
func _roll_bonus_damage(actor: Combatant, target: Combatant, e: Dictionary, critical: bool,
		beats: Array[Dictionary], multiplier: float) -> void:
	for part: Dictionary in actor.bonus_damage(e):
		_roll_damage(actor, target, part["damage"], part["damage_type"], critical, beats, multiplier, false, false)


## Un type de dégâts peut infliger un état quand il blesse (le feu enflamme…). Retourne le texte ajouté.
func _status_from_damage(target: Combatant, type: String, dealt: int) -> String:
	var status := DamageTypes.status_of(type)
	if status.is_empty() or dealt <= 0 or not target.is_alive() or rng.randf() >= float(status.get("chance", 0.0)):
		return ""
	if target.defenses().is_immune_to_status(status["id"]):
		return ""
	target.add_status(status["id"], int(status.get("stacks", 1)))
	return " " + Loc.ui("%s : +%d %s.") % [target.name, int(status.get("stacks", 1)), StatusEffects.name_of(status["id"])]


## Jet de sauvegarde de la cible contre le DD de l'acteur (ou "dc"). Inflexible relance un échec.
## Retourne true si la sauvegarde réussit.
func _saving_throw(actor: Combatant, target: Combatant, save: Dictionary, beats: Array[Dictionary], fast: bool) -> bool:
	var ability: String = save["ability"]
	var dc := int(save.get("dc", actor.save_dc()))
	var bonus := target.save_mod(ability)
	var label := Loc.ui("Sauvegarde de %s") % Abilities.name_of(ability)
	if target.has_status_flag("auto_fail_saves", ability):
		_beat(beats, Loc.ui("%s rate automatiquement sa %s.") % [target.name, label.to_lower()])
		return false
	var advantage := Dice.combine_advantage(1 if target.has_save_advantage(ability) else 0,
		1 if target.has_status_flag("save_disadvantage", ability) else 0)
	var d20 := Dice.roll_d20(rng, advantage)
	var die := int(d20["die"])
	var saved := die == 20 or (die != 1 and die + bonus >= dc)
	_beat(beats, Loc.ui("%s : %s%s %d + %d = %d contre DD %d — %s") % [target.name, label.to_lower(),
		Dice.advantage_text(advantage), die, bonus, die + bonus, dc, Loc.ui("réussie") if saved else Loc.ui("ratée")],
		{"dice": d20["dice"], "mod": bonus, "dc": dc, "success": saved, "advantage": advantage,
		"stat": "%s (%s)" % [label, target.name]}, fast)
	if not saved and target.character != null and int(target.character.resources.get("indomitable", 0)) > 0:
		target.character.resources["indomitable"] = int(target.character.resources["indomitable"]) - 1
		die = rng.randi_range(1, 20)
		saved = die == 20 or (die != 1 and die + bonus >= dc)
		_beat(beats, Loc.ui("%s est inflexible et relance : %d + %d = %d — %s") % [target.name, die, bonus, die + bonus,
			Loc.ui("réussie") if saved else Loc.ui("ratée")],
			{"dice": [{"sides": 20, "value": die}], "mod": bonus, "dc": dc, "success": saved, "stat": "%s (%s)" % [label, target.name]},
			fast)
	return saved


## Inflige des dégâts : défenses (sauf dégâts bruts), puis Protection (sauf dégâts bruts).
## Retourne {"amount": dégâts subis, "suffix": texte complémentaire (« (résistance) », « Vaincu »…)}.
func _deal_damage(source: Combatant, target: Combatant, amount: int, type: String, raw: bool,
		death_cause: String) -> Dictionary:
	var notes := PackedStringArray()
	if not raw and type != "":
		var applied := DamageTypes.apply(amount, type, target.defenses())
		amount = applied["amount"]
		if applied["note"] != "":
			notes.append(applied["note"])
	if not raw:
		for status_id: String in target.statuses.keys():
			if StatusEffects.absorbs(status_id) and amount > 0:
				var absorbed := mini(amount, target.stacks(status_id))
				target.add_status(status_id, -absorbed)
				amount -= absorbed
				notes.append(Loc.ui("%d absorbé(s)") % absorbed)
	target.hp = maxi(0, target.hp - amount)
	if amount > 0:
		for status_id: String in target.statuses.keys():
			if StatusEffects.has_flag(status_id, "wake_on_damage"):
				target.remove_status(status_id)
				notes.append(Loc.ui("se réveille"))
	if target.hp == 0 and target.has_modifier("relentless_endurance") \
			and int(target.character.resources.get("relentless_endurance", 0)) > 0:
		target.character.resources["relentless_endurance"] = int(target.character.resources["relentless_endurance"]) - 1
		target.hp = 1
		notes.append(Loc.ui("endurance implacable : reste à 1 PV"))
	var suffix := (" (%s)." % ", ".join(notes)) if not notes.is_empty() else "."
	if not target.is_alive():
		suffix += " " + _on_down(target, source, death_cause)
	return {"amount": amount, "suffix": suffix}


## Un combattant tombe à 0 PV. Le héros meurt si le combat est mortel. Retourne le texte à afficher.
func _on_down(target: Combatant, attacker: Combatant, death_cause: String) -> String:
	target.statuses.clear()
	target.intent = {}
	if not target.is_ally():
		return Loc.ui("%s est vaincu.") % target.name
	if spec.get("on_defeat", "death") == "knockout" and not target.summoned:
		return Loc.ui("%s s'effondre, assommé.") % target.name
	if target.is_hero():
		var cause := death_cause
		if cause == "" and attacker != null:
			cause = attacker.creature.get("death_cause", Loc.ui("Tué par %s") % attacker.name)
		life.die(cause if cause != "" else Loc.ui("Mort au combat"))
	return Loc.ui("%s s'effondre.") % target.name


func _decay(actor: Combatant, status_id: String) -> void:
	var amount := StatusEffects.decay_amount(status_id)
	if amount < 0:
		actor.remove_status(status_id)
	elif amount > 0:
		actor.add_status(status_id, -amount)


func _check_end() -> void:
	if outcome != "":
		return
	if life.dead or not hero.is_alive():
		outcome = "defeat"
	elif living("enemy").is_empty():
		outcome = "victory"
	if outcome != "":
		log.append({"victory": Loc.ui("Victoire !"), "defeat": Loc.ui("Défaite…")}[outcome])


func _beat(beats: Array[Dictionary], text: String, roll: Dictionary = {}, fast := false) -> void:
	beats.append({"text": text, "roll": roll, "fast": fast})
	log.append(text)


func _add(c: Combatant) -> void:
	if c.id == "":
		c.id = "%s_%d" % [c.side, _next_id]
		_next_id += 1
	combatants.append(c)


func _select(predicate: Callable) -> Array[Combatant]:
	var result: Array[Combatant] = []
	for c in combatants:
		if predicate.call(c):
			result.append(c)
	return result


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
