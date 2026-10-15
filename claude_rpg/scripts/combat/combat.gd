class_name Combat
extends RefCounted
## Combat au tour par tour, en réserves de d10 à succès (voir docs/systeme_de_jeu.md). Aucune
## dépendance à l'interface : chaque action retourne des « étapes » (texte + jet de dés) que
## l'interface anime, l'état étant déjà à jour.
##
## Déroulement : ordre d'initiative (1d10 + DEX + INT ; égalité : DEX, puis INT, puis au hasard).
## Chaque tour commence par start_turn() (états, réactions non utilisées -> Préparé), puis le combattant
## dispose de deux actions (`actions_left`) :
##   - héros et compagnons (contrôlés par le joueur) : une action de classe (perform), un objet
##     (use_item) ou la fuite (flee) ;
##   - créatures (ennemis, invocations) : ai_turn(). Un ennemi peut annoncer une action, jouée au tour suivant.
## Les actions non utilisées deviennent des réactions (esquive, parade, contre-attaque) jusqu'au tour
## suivant du combattant. end_turn() passe au suivant. Réglages : rules.json › combat.
##
## Réactions des personnages du joueur (sauf en mode automatique) : `reaction_chooser` est appelé à
## chaque occasion et peut attendre le joueur ; les fonctions qui résolvent des effets (perform,
## ai_turn, auto_turn…) sont donc des coroutines, à appeler avec await. Toutes les étapes sont aussi
## ajoutées à `stream`, dans l'ordre, pour que l'interface puisse les animer au fil de l'eau.
##
## Attaque : [rang] d10 contre l'attribut, difficulté = Esquive naturelle de la cible (mêlée) ou son
## Couvert (distance) ; les succès au-delà donnent un critique (relances des dés de dégâts ratés).
## Dégâts : un succès = un point de dégâts ; l'Armure de la cible baisse le seuil des dégâts.
##
## Spécification (effet "combat" d'un événement) :
##   {"enemies": ["wolf", ...], "flee": true, "flee_difficulty": 2, "on_defeat": "death" | "knockout",
##    "light"?: "dim" | "dark", "victory": {text, effects}, "defeat": {text, effects}, "fled": {text, effects}}

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
var initiative_roll: Dictionary = {}  # lancer d'initiative de tous les combattants, animé en une fois
var hero_down_cause := ""  # cause de la mort si tout le groupe tombe après le héros
var skipped := false  # le combattant actif passe son tour (étourdi, mort pendant ses états…)
var actions_left := 2  # actions restantes au combattant actif pendant ce tour
## Choix d'une réaction par le joueur : (cible: Combatant, sorte: "counter" | "dodge" | "parry",
## infos: Dictionary) -> bool. Peut être une coroutine (fenêtre de choix). Sans lui, choix automatique.
var reaction_chooser: Callable
var stream: Array[Dictionary] = []  # toutes les étapes, dans l'ordre (voir _beat)
var _next_id := 0


static func setting(key: String, default: Variant) -> Variant:
	return DB.rules.get("combat", {}).get(key, default)


## Places occupées par une créature d'une taille donnée (échelle de −4 à 5).
static func size_slots(size: int) -> float:
	return float(setting("size_slots", {}).get(str(clampi(size, -4, 5)), 1.0))


## Échelle du sprite d'une créature d'une taille donnée.
static func sprite_scale(size: int) -> float:
	return float(setting("sprite_scale", {}).get(str(clampi(size, -4, 5)), 1.0))


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
		_add(Combatant.from_creature(id, label, "enemy"))
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


## Difficulté de la fuite : "flee_difficulty" du combat, sinon rules.json (2).
func flee_difficulty() -> int:
	return int(spec.get("flee_difficulty", setting("flee_difficulty", 2)))


## Réserve de fuite : Physique (DEX), un dé de moins si l'état l'impose (Effrayé).
func flee_pool(actor: Combatant) -> Dictionary:
	return actor.skill_pool("physique", "dex", -1 if actor.has_status_flag("check_disadvantage") else 0)


func flee_chance(actor: Combatant) -> float:
	var pool := flee_pool(actor)
	return Dice.chance(int(pool["count"]), int(pool["threshold"]), flee_difficulty())


func capacity_used(side: String) -> float:
	var used := 0.0
	for c in living(side):
		used += c.slots()
	return used


func can_add(side: String, size: int) -> bool:
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


# --- Défenses : Esquive naturelle, Couvert, surprise ------------------------------------

## Couvert d'une cible contre les attaques à distance : 1 par défaut (jamais moins) ; −1 par taille ≥ 2
## et ≥ 4, −1 si elle est immobile ; +1 par taille ≤ −2 et ≤ −4, +1 si elle est cachée, +1 dans la
## pénombre, +2 dans le noir (spécification "light"), +1 si elle est en mouvement.
func cover(target: Combatant) -> int:
	var rules: Dictionary = setting("cover", {})
	var value := int(rules.get("base", 1))
	var size := target.size()
	value -= int(size >= 2) + int(size >= 4) + int(target.has_status_flag("immobile"))
	value += int(size <= -2) + int(size <= -4) + int(target.has_status_flag("hidden")) + int(target.has_status_flag("moving"))
	match spec.get("light", ""):
		"dim":
			value += 1
		"dark":
			value += 2
	return maxi(int(rules.get("min", 1)), value)


## Attaque surprise : l'attaquant est caché, ou la cible ignore sa présence (endormie, paralysée).
func is_surprise(actor: Combatant, target: Combatant) -> bool:
	return actor.has_status_flag("attack_surprise") or target.has_status_flag("unaware")


## Difficulté d'une attaque : Couvert de la cible (distance) ; sinon son Esquive naturelle, ou 1 par
## surprise. Les états la modifient (+1 si l'attaquant est aveuglé ou effrayé, −1 contre une cible à
## terre ou entravée…).
func attack_difficulty(actor: Combatant, target: Combatant, effect: Dictionary) -> int:
	var difficulty := 0
	if actor.is_ranged_attack(effect):
		difficulty = cover(target)
	elif is_surprise(actor, target):
		difficulty = 1
	else:
		difficulty = target.natural_dodge()
	difficulty += int(actor.has_status_flag("attack_disadvantage")) - int(target.has_status_flag("attacked_advantage")) \
		+ int(target.has_status_flag("attacked_disadvantage"))
	return maxi(0, difficulty)


## Chance qu'une attaque touche (avant les réactions), pour l'interface et l'IA.
func hit_chance(actor: Combatant, target: Combatant, effect: Dictionary) -> float:
	var pool := actor.attack_pool(effect)
	var bonus := int(setting("prepared_dice", 2)) if actor.is_prepared() else 0
	return Dice.chance(int(pool["count"]) + bonus, int(pool["threshold"]), attack_difficulty(actor, target, effect))


## Actions d'un personnage pour l'interface : [{action, available, reason}]. Un sort qui s'améliore
## avec le niveau d'emplacement apparaît une fois par niveau disponible (voir Combatant.action_variants).
func action_choices(actor: Combatant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for base in actor.combat_actions():
		for action in actor.action_variants(base):
			var reason := action_unavailable_reason(actor, action)
			result.append({"action": action, "available": reason == "", "reason": reason})
	return result


## Le combattant actif peut-il encore agir pendant ce tour (une action, ou une action gratuite) ?
func can_act_again() -> bool:
	if is_over() or not current().is_alive():
		return false
	if actions_left > 0:
		return true
	return action_choices(current()).any(func(c): return c["available"])


func action_unavailable_reason(actor: Combatant, action: Dictionary) -> String:
	var reason := actor.unavailable_reason(action)
	if reason != "":
		return reason
	if actor == current() and not actor.is_free(action) and actions_left <= 0:
		return Loc.ui("plus d'action")
	var target: String = action.get("target", "enemy")
	if target in ["enemy", "all_enemies"] and living("enemy").is_empty():
		return Loc.ui("aucune cible")
	for e: Dictionary in action.get("effects", []):
		if e.get("type") == "summon" and not can_add(actor.side, Creatures.size_of(e["creature"])):
			return Loc.ui("plus de place dans votre camp")
	return ""


# --- Tours -------------------------------------------------------------------

## Début du tour du combattant actif : réactions non utilisées (-> Préparé), effets des états. Après
## l'appel, `skipped` indique si le combattant passe son tour.
func start_turn() -> Array[Dictionary]:
	var actor := current()
	var beats: Array[Dictionary] = []
	skipped = false
	actions_left = actor.actions_per_turn()
	for c in combatants:
		c.parries_used = 0
	actor.reaction_used = false
	actor.savage_used = false
	actor.fast_hands_used = false
	actor.cunning_used = false
	if actor.reactions > 0 and actor.is_alive() and not actor.is_prepared():
		actor.become_prepared()
		_beat(beats, Loc.ui("%s n'a pas eu à se défendre : préparé (+%d dés à son prochain jet de combat).") % [
			actor.name, int(setting("prepared_dice", 2))])
	actor.reactions = 0
	if actor.has_modifier("survivor") and actor.is_alive() and actor.hp <= actor.max_hp() / 2.0:
		@warning_ignore("integer_division")
		var healed := mini(actor.max_hp() - actor.hp, maxi(1, actor.ability_score("con") / 2))
		actor.hp += healed
		_beat(beats, Loc.ui("%s, survivant, récupère %d PV.") % [actor.name, healed])
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


## Fin du tour du combattant actif. Les actions gardées deviennent des réactions (esquive, parade,
## contre-attaque) jusqu'à son prochain tour. Puis on passe au combattant vivant suivant (nouveau round
## après le dernier).
func end_turn() -> void:
	var actor := current()
	actor.reactions = maxi(0, actions_left) if actor.is_alive() and not skipped else 0
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
	var free := actor.is_free(action)
	if free and action.get("id", "") == "hide" and not action.get("free", false):
		actor.cunning_used = true
	var blood := actor.consume(action)
	if not free:
		actions_left -= 1
	var beats: Array[Dictionary] = []
	_beat(beats, Loc.ui("%s : %s.") % [actor.name, action["name"]])
	if blood > 0:
		_beat(beats, Loc.ui("Faute de mana, %s puise %d PV dans sa vie.") % [actor.name, blood])
		if actor.hp <= 0:
			_beat(beats, _on_down(actor, actor, "magic"))
			_check_end()
			return beats
	if await _counterspell(actor, action, beats):
		_check_end()
		return beats
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
		beats.append_array(await _resolve(actor, action.get("effects", []), action.get("target", "enemy"), target,
			not actor.is_player_controlled()))
		if is_over():
			break
	_check_end()
	return beats


## Utilise un objet de l'inventaire du héros (soins, antidote…).
func use_item(actor: Combatant, item_id: String, target: Combatant) -> Array[Dictionary]:
	var item: Dictionary = Items.def(item_id)
	life.character.remove_item(item_id)
	if actor.has_modifier("fast_hands") and not actor.fast_hands_used:
		actor.fast_hands_used = true  # Mains lestes : l'objet ne coûte pas d'action
	else:
		actions_left -= 1
	var use: Dictionary = item["use"]
	if use.has("spell"):
		return await _read_scroll(actor, item, target)
	var effects: Array = []
	if use.has("heal"):
		effects.append({"type": "heal", "amount": use["heal"]})
	if use.has("cleanse"):
		effects.append({"type": "cleanse", "status": use["cleanse"]})
	var beats: Array[Dictionary] = []
	_beat(beats, Loc.ui("%s utilise : %s.") % [actor.name, item["name"]])
	beats.append_array(await _resolve(actor, effects, "ally", target, false))
	_check_end()
	return beats


## Lit un parchemin : le sort part une fois, sans emplacement, avec la compétence des parchemins (rules.json ›
## scrolls › skill : Langues) au lieu de la compétence d'incantation. Il peut débloquer une classe (Magicien).
func _read_scroll(actor: Combatant, item: Dictionary, target: Combatant) -> Array[Dictionary]:
	var use: Dictionary = item["use"]
	var spell := Actions.def(use["spell"])
	var beats: Array[Dictionary] = []
	_beat(beats, Loc.ui("%s lit : %s.") % [actor.name, item["name"]])
	if actor.character != null:
		actor.character.spell_override = String(DB.rules.get("scrolls", {}).get("skill", "languages"))
	if not await _counterspell(actor, spell, beats):
		beats.append_array(await _resolve(actor, spell.get("effects", []), spell.get("target", "enemy"), target,
			not actor.is_player_controlled()))
	if actor.character != null:
		actor.character.spell_override = ""
	if use.has("unlock") and actor.is_ally() and Meta.unlock(use["unlock"]):
		_beat(beats, Loc.ui("Débloqué pour les prochaines vies : %s !") % Meta.unlock_name(use["unlock"]))
	_check_end()
	return beats


## Tentative de fuite du groupe : Physique (DEX) contre la difficulté de fuite. Elle prend tout le tour.
func flee(actor: Combatant) -> Array[Dictionary]:
	actions_left = 0
	var pool := flee_pool(actor)
	var roll := Dice.roll_pool(rng, int(pool["count"]), int(pool["threshold"]))
	var judged := Dice.judge(int(roll["successes"]), flee_difficulty(), 0, roll["dice"])
	var beats: Array[Dictionary] = []
	_beat(beats, Loc.ui("%s tente de fuir : %s.") % [actor.name, Dice.verdict(judged)],
		_roll_info(Loc.ui("Fuite (Physique, DEX)"), roll, judged))
	if judged["success"]:
		outcome = "fled"
	return beats


# --- Tours de l'IA -----------------------------------------------------------

## Tour d'une créature (ennemi ou invocation) : elle joue ses actions, en gardant parfois la dernière
## pour se défendre (rules.json › combat › ai_guard_chance). Une action annoncée au tour précédent est
## jouée en premier ; une action « announced » est d'abord annoncée (elle coûte une action).
func ai_turn(actor: Combatant) -> Array[Dictionary]:
	var beats: Array[Dictionary] = []
	var keep := 1 if actions_left > 1 and rng.randf() < float(setting("ai_guard_chance", 0.25)) else 0
	var intent_ready := not actor.intent.is_empty()
	# Moral : un lâche mal en point, ou une meute qui a perdu son chef (ou la moitié des siens), peut fuir.
	if not actor.is_ally() and _breaks(actor) and rng.randf() < 0.5:
		actor.fled = true
		actor.intent = {}
		_beat(beats, Loc.ui("%s prend la fuite !") % actor.name)
		_check_end()
		return beats
	for guard in 8:
		if actions_left <= keep or is_over() or not actor.is_alive():
			break
		var action: Dictionary
		if intent_ready:
			action = actor.intent
			actor.intent = {}
			intent_ready = false
		else:
			action = _pick_action(actor, actor.intent.is_empty() and not actor.is_ally())
			if action.is_empty():
				if beats.is_empty():
					_beat(beats, Loc.ui("%s ne fait rien.") % actor.name)
				break
			if action.get("announced", false) and not actor.is_ally():
				actor.intent = action
				actions_left -= 1
				_beat(beats, Loc.ui("%s s'apprête à : %s !") % [actor.name, action["name"]])
				continue
		actions_left -= 1
		var target_mode: String = action.get("target", "enemy")
		var chosen: Combatant = null
		if target_mode in CombatEffects.CHOSEN_TARGETS:
			var candidates := targets(actor, target_mode)
			if candidates.is_empty():
				break
			candidates.sort_custom(func(a, b): return a.hp < b.hp)
			# Les invocations alliées et les chasseurs visent le plus faible, les autres ennemis au hasard ;
			# soins et protections vont à l'allié le plus mal en point (en proportion de ses PV).
			var weakest := actor.is_ally() or actor.ai_kind() == "hunter"
			chosen = candidates[0] if weakest else candidates[rng.randi_range(0, candidates.size() - 1)]
			if target_mode == "ally":
				candidates.sort_custom(func(a, b): return float(a.hp) / a.max_hp() < float(b.hp) / b.max_hp())
				chosen = candidates[0]
		_beat(beats, Loc.ui("%s : %s.") % [actor.name, action["name"]])
		if not await _counterspell(actor, action, beats):
			beats.append_array(await _resolve(actor, action.get("effects", []), target_mode, chosen, not actor.is_ally()))
		_check_end()
	return beats


## Le moral d'une créature flanche-t-il ? Lâche : sous coward_hp (30 %) de ses PV. Meute : son chef est
## tombé, ou la moitié de son camp (hors invocations) est hors de combat.
func _breaks(actor: Combatant) -> bool:
	match actor.morale():
		"coward":
			return actor.hp <= actor.max_hp() * float(setting("coward_hp", 0.3))
		"pack":
			var side := combatants.filter(func(c): return c.side == actor.side and not c.summoned)
			if side.any(func(c): return c.is_leader() and not c.is_alive()):
				return true
			var down := side.filter(func(c): return not c.is_alive()).size()
			return side.size() >= 2 and down * 2 >= side.size()
	return false


func _pick_action(actor: Combatant, allow_announced: bool) -> Dictionary:
	var actions := actor.combat_actions().filter(func(a): return (a.get("target") == "none" \
		or not targets(actor, a.get("target", "enemy")).is_empty()) and actor.unavailable_reason(a) == "" \
		and not actor.needs_blood(a) and (allow_announced or not a.get("announced", false)) and _support_weight(actor, a) != 0.0)
	var total := 0.0
	for a: Dictionary in actions:
		total += _support_weight(actor, a)
	var r := rng.randf() * total
	for a: Dictionary in actions:
		r -= _support_weight(actor, a)
		if r < 0.0:
			return a
	return actions.back() if not actions.is_empty() else {}


## Rôle de soutien d'une action : "heal" (elle soigne), "protect" (elle vise des alliés sans soigner :
## protection, bénédiction…), "" sinon.
static func support_role(action: Dictionary) -> String:
	var effects: Array = action.get("effects", [])
	if effects.any(func(e): return e.get("type") == "heal"):
		return "heal"
	if action.get("target", "enemy") in ["ally", "all_allies"]:
		return "protect"
	return ""


## Poids d'une action pour l'IA. Soigner ne sert que si un allié (ou soi) est sous ai_heal_below de ses PV,
## protéger que si un allié est sous ai_protect_below ; alors l'action devient prioritaire (× ai_support_bonus).
func _support_weight(actor: Combatant, action: Dictionary) -> float:
	var weight := float(action.get("weight", 1))
	var role := support_role(action)
	if role == "":
		return weight
	var limit := float(setting("ai_heal_below" if role == "heal" else "ai_protect_below", 0.5 if role == "heal" else 0.75))
	var pool := targets(actor, action.get("target", "self")) if action.get("target", "self") != "none" else [actor]
	if pool.any(func(c): return float(c.hp) / c.max_hp() < limit):
		return weight * float(setting("ai_support_bonus", 3.0))
	return 0.0


## Joue automatiquement toutes les actions d'un personnage pour ce tour (tests, banc d'équilibrage,
## combat automatique).
func auto_turn(actor: Combatant) -> Array[Dictionary]:
	var beats: Array[Dictionary] = []
	for guard in 6:
		if not can_act_again():
			break
		var choice := auto_choice(actor)
		if choice["action"].is_empty():
			break
		beats.append_array(await perform(actor, choice["action"], choice["target"]))
	return beats


## Choix automatique pour un personnage : l'action disponible la plus utile (dégâts attendus, soins ou
## protection si les PV sont bas), contre l'ennemi le plus faible.
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
	var foes := living("enemy" if actor.is_ally() else "ally")
	var spread := foes.size() if action.get("target") == "all_enemies" else 1
	var hurt := actor.hp < actor.max_hp() * 0.5
	var attacks := 1 + (actor.extra_attacks() if action.get("attack_action", false) else 0)
	var foe: Combatant = foes[0] if not foes.is_empty() else null
	for e: Dictionary in action.get("effects", []):
		match e.get("type"):
			"attack":
				var chance := hit_chance(actor, foe, e) if foe != null else 0.5
				var pool := actor.damage_pool(e, actor.attack_pool(e))
				var armor := foe.armor() if foe != null else 0
				var average := Dice.expected(int(pool["count"]), maxi(1, int(pool["threshold"]) - armor))
				for part: Dictionary in actor.bonus_damage(e):
					average += Dice.expected(int(part.get("dice", 1)), int(part.get("threshold", 5)))
				score += average * chance * spread * attacks
			"damage":
				var pool := actor.damage_pool(e)
				score += Dice.expected(int(pool["count"]), int(pool["threshold"])) * spread * (0.7 if e.has("resist") else 1.0)
			"extra_action":
				score += 2.0
			"heal":
				var spec: Variant = e["amount"]
				if spec is Dictionary and hurt:
					var pool := actor.heal_pool(spec)
					score += Dice.expected(int(pool["count"]), int(pool["threshold"]))
			"status":
				var stacks := int(e["stacks"])
				match e["status"]:
					"shielded":
						score += stacks * (0.8 if hurt else 0.3)
					"prepared":
						score += 0.4
					"raging":
						score += 0.5 if hurt else 2.5

					"stunned", "asleep":
						score += 1.5 * spread
					_:
						score += stacks * 0.4 * spread
			"summon":
				score += 2.0
	# Les ressources limitées (emplacements, utilisations par combat) valent un peu moins, et un
	# emplacement de niveau supérieur encore moins.
	if action.has("cost") or action.has("per_combat"):
		score *= 0.9
	if action.has("slot_level"):
		score *= 1.0 - 0.08 * (int(action["slot_level"]) - int(action.get("spell_level", 1)))
	return score


# --- Résolution des effets ---------------------------------------------------

## Applique une liste d'effets. `target_mode` : "enemy", "all_enemies", "ally", "all_allies", "self", "none".
## Les effets qui suivent une attaque ratée, un test raté ou un effet auquel la cible a résisté sont
## ignorés (jusqu'à l'attaque ou au test suivant).
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
			var untargeted: Dictionary = await _apply(actor, e, null, fast)
			beats.append_array(untargeted["beats"])
	for target in target_list:
		var hit := true
		for e: Dictionary in effects:
			if e.get("type") in CombatEffects.UNTARGETED:
				continue
			if e.get("type") in ["attack", "check"] or e.has("resist"):
				if not target.is_alive() or not actor.is_alive():
					break
				var result: Dictionary = await _apply(actor, e, target, fast)
				beats.append_array(result["beats"])
				hit = result["hit"]
			elif hit and target.is_alive():
				var applied: Dictionary = await _apply(actor, e, target, fast)
				beats.append_array(applied["beats"])
	return beats


## Applique un effet à une cible. Retourne {"beats", "hit"} (hit : attaque réussie, test réussi, ou
## effet que la cible n'a pas su repousser).
func _apply(actor: Combatant, e: Dictionary, target: Combatant, fast: bool) -> Dictionary:
	var beats: Array[Dictionary] = []
	var hit := true
	if e.has("resist") and e.get("type") != "damage":
		if _resists(actor, target, e["resist"], beats, fast):
			_beat(beats, Loc.ui("%s n'est pas affecté.") % target.name)
			return {"beats": beats, "hit": false}
	match e.get("type"):
		"attack":
			hit = await _attack(actor, target, e, beats, fast)
			var off_hand := actor.off_hand_attack(e)
			if not off_hand.is_empty() and target.is_alive() and actor.is_alive():
				var penalty := actor.off_hand_penalty()
				_beat(beats, Loc.ui("%s frappe aussi de sa main secondaire%s.") % [actor.name,
					Loc.ui(" (−%d dés)") % penalty if penalty > 0 else ""])
				await _attack(actor, target, off_hand, beats, fast)
		"damage":
			var pool := actor.damage_pool(e)
			var dealt: int = await _roll_damage(actor, target, pool, actor.damage_type(e), 0, beats, {"resist": e.get("resist", {})})
			hit = dealt > 0 or not e.has("resist")
			for part: Dictionary in actor.bonus_damage(e):
				await _roll_damage(actor, target, {"count": int(part.get("dice", 1)), "threshold": int(part.get("threshold", 5))},
					part["damage_type"], 0, beats)
		"heal":
			var spec: Variant = e["amount"]
			var pool := actor.heal_pool(spec if spec is Dictionary else {"dice": 1})
			var roll := Dice.roll_pool(rng, int(pool["count"]), int(pool["threshold"]))
			var before := target.hp
			target.hp = mini(target.max_hp(), target.hp + maxi(1, int(roll["successes"])))
			_beat(beats, Loc.ui("%s récupère %d PV.") % [target.name, target.hp - before],
				_roll_info(Loc.ui("Soins"), roll), true)
		"status":
			var status: String = e["status"]
			if target.defenses().is_immune_to_status(status):
				_beat(beats, Loc.ui("%s est immunisé contre %s.") % [target.name, StatusEffects.name_of(status)])
			elif StatusEffects.has_flag(status, "prepared"):
				target.become_prepared()
				_beat(beats, Loc.ui("%s est préparé (+%d dés à son prochain jet de combat).") % [target.name,
					int(setting("prepared_dice", 2))])
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
		"check":
			hit = _skill_check(actor, target, e, beats, fast)
		"reveal_weaknesses":
			target.weaknesses_known = true
			var known := target.defenses().describe()
			_beat(beats, Loc.ui("Points faibles de %s : %s.") % [target.name, known if known != "" else Loc.ui("ni résistance ni faiblesse particulière")])
		"extra_action":
			actions_left += 1
			_beat(beats, Loc.ui("%s peut agir une fois de plus.") % actor.name)
		"summon":
			var creature_id: String = e["creature"]
			if can_add(actor.side, Creatures.size_of(creature_id)):
				var summon := Combatant.from_creature(creature_id, Creatures.name_of(creature_id), actor.side)
				summon.summoned = true
				summon.initiative = actor.initiative
				_add(summon)
				order.append(summon)
				_beat(beats, Loc.ui("%s invoque : %s.") % [actor.name, summon.name])
	return {"beats": beats, "hit": hit}


## Attaque : jet contre l'Esquive naturelle (ou le Couvert), avec les réactions de la cible :
## contre-attaque (avant le jet), esquive (après un jet réussi), parade (contre les dégâts). Un attaquant
## caché se révèle. Retourne true si l'attaque touche.
func _attack(actor: Combatant, target: Combatant, e: Dictionary, beats: Array[Dictionary], fast: bool) -> bool:
	var hit: bool = await _attack_roll(actor, target, e, beats, fast)
	_reveal(actor)
	return hit


func _attack_roll(actor: Combatant, target: Combatant, e: Dictionary, beats: Array[Dictionary], fast: bool) -> bool:
	var surprise := is_surprise(actor, target)
	var attack := actor.attack_pool(e)
	var can_react := not surprise and target.reactions > 0
	if can_react and _can_counter(actor, target, e):
		var info := {"attacker": actor, "effect": e, "attack": attack, "counter": target.attack_pool(_counter_effect(target)),
			"beats": beats}
		if await _decide(target, "counter", info, _wants_counter(actor, target, e, attack)):
			return await _counter(actor, target, e, attack, beats, fast)
	var difficulty := attack_difficulty(actor, target, e)
	var crit_bonus := actor.critical_bonus() + (int(setting("surprise_crit_bonus", 2)) if surprise else 0)
	var bonus := actor.use_prepared()
	var roll := Dice.roll_pool(rng, int(attack["count"]) + bonus, int(attack["threshold"]))
	var multiplier := actor.attack_successes_multiplier(target)
	roll["successes"] = int(roll["successes"]) * multiplier
	var judged := Dice.judge(int(roll["successes"]), difficulty, crit_bonus, roll["dice"])
	var against := Loc.ui("Couvert") if actor.is_ranged_attack(e) else Loc.ui("Esquive naturelle")
	var notes := PackedStringArray()
	if surprise:
		notes.append(Loc.ui("surprise"))
	if bonus > 0:
		notes.append(Loc.ui("préparé"))
	if multiplier > 1:
		notes.append(Loc.ui("rage : succès ×%d") % multiplier)
	var note := (" (%s)" % ", ".join(notes)) if not notes.is_empty() else ""
	_beat(beats, Loc.ui("%s attaque %s%s : %d succès contre %s %d — %s") % [actor.name, target.name, note,
		int(roll["successes"]), against.to_lower(), difficulty, _attack_verdict(judged)],
		_roll_info("%s → %s" % [actor.name, target.name], roll, judged, against), fast)
	if not judged["success"]:
		if e.get("cantrip", false) and actor.has_modifier("potent_cantrip"):
			_beat(beats, Loc.ui("Tour de magie puissant : la moitié des dégâts passe."))
			await _roll_damage(actor, target, actor.damage_pool(e, attack), actor.damage_type(e), 0, beats,
				{"armor": true, "multiplier": 0.5})
		return false
	var dodge_info := {"attacker": actor, "successes": int(judged["successes"]), "difficulty": difficulty,
		"critical": int(judged["critical"]), "dodge": target.skill_pool("physique", "dex", target_prepared_bonus(target)),
		"beats": beats}
	if can_react and target.reactions > 0 and await _decide(target, "dodge", dodge_info, true):
		var dodged := _dodge(target, beats, fast)
		if dodged > 0:
			judged = Dice.judge(int(judged["successes"]) - dodged, difficulty, crit_bonus)
			_beat(beats, Loc.ui("Il reste %d succès à %s — %s") % [int(judged["successes"]), actor.name, _attack_verdict(judged)])
			if not judged["success"]:
				return false
	await _hit(actor, target, e, attack, int(judged["critical"]), surprise, not surprise, beats, fast)
	return true


func _attack_verdict(judged: Dictionary) -> String:
	if not judged["success"]:
		return Loc.ui("raté")
	var level := int(judged["critical"])
	if level > 0:
		return Loc.ui("critique !") if level == 1 else Loc.ui("critique %d !") % level
	return Loc.ui("touché")


## Esquive de la cible (une réaction) : Physique (DEX). Retourne ses succès, qui retirent autant de
## succès à l'attaque.
func _dodge(target: Combatant, beats: Array[Dictionary], fast: bool) -> int:
	target.reactions -= 1
	var pool := target.skill_pool("physique", "dex", target.use_prepared())
	var roll := Dice.roll_pool(rng, int(pool["count"]), int(pool["threshold"]))
	_beat(beats, Loc.ui("%s esquive : %d succès.") % [target.name, int(roll["successes"])],
		_roll_info(Loc.ui("Esquive (%s)") % target.name, roll), fast)
	return int(roll["successes"])


## Contresort (une réaction) : quand un adversaire lance un sort, un lanceur de sorts qui garde une
## réaction peut le contrer, sans savoir s'il aurait touché. Opposition des compétences d'incantation : il
## faut plus de succès que le lanceur (à égalité, le sort passe). Contré, le sort est perdu (emplacement
## compris). Retourne true si le sort est contré.
func _counterspell(caster: Combatant, action: Dictionary, beats: Array[Dictionary]) -> bool:
	if not Spellcasting.is_spell(action):
		return false
	var candidates := living("enemy" if caster.is_ally() else "ally").filter(
		func(c): return c.reactions > 0 and c.is_spellcaster())
	if candidates.is_empty():
		return false
	candidates.sort_custom(func(a, b): return Dice.expected(a.spell_pool()["count"], a.spell_pool()["threshold"]) \
		> Dice.expected(b.spell_pool()["count"], b.spell_pool()["threshold"]))
	var counter: Combatant = candidates[0]
	var mine := counter.spell_pool()
	var theirs := caster.spell_pool()
	var auto := Dice.expected(mine["count"], mine["threshold"]) > Dice.expected(theirs["count"], theirs["threshold"])
	var info := {"attacker": caster, "spell": action["name"], "counter": mine, "caster_pool": theirs, "beats": beats}
	if not await _decide(counter, "counterspell", info, auto):
		return false
	counter.reactions -= 1
	_beat(beats, Loc.ui("%s tente de contrer le sort !") % counter.name)
	var c_roll := Dice.roll_pool(rng, int(mine["count"]) + counter.use_prepared(), int(mine["threshold"]))
	var s_roll := Dice.roll_pool(rng, int(theirs["count"]), int(theirs["threshold"]))
	_beat(beats, Loc.ui("%s : %d succès.") % [caster.name, int(s_roll["successes"])], _roll_info(Loc.ui("Sort (%s)") % caster.name, s_roll), true)
	var countered := int(c_roll["successes"]) > int(s_roll["successes"])
	_beat(beats, Loc.ui("%s : %d succès — %s") % [counter.name, int(c_roll["successes"]),
		Loc.ui("le sort est contré !") if countered else Loc.ui("le sort passe.")],
		_roll_info(Loc.ui("Contresort (%s)") % counter.name, c_roll), false)
	return countered


## La cible peut-elle contre-attaquer ? Il lui faut une attaque ; contre un tir, une arme de tir.
func _can_counter(actor: Combatant, target: Combatant, e: Dictionary) -> bool:
	var counter := _counter_effect(target)
	if counter.is_empty():
		return false
	return not actor.is_ranged_attack(e) or target.is_ranged_attack(counter)


## Choix automatique : contre-attaquer si l'on a de bonnes chances de l'emporter (plus de succès attendus).
func _wants_counter(actor: Combatant, target: Combatant, _e: Dictionary, attack: Dictionary) -> bool:
	var mine := target.attack_pool(_counter_effect(target))
	var bonus := int(setting("prepared_dice", 2))
	var mine_expected := Dice.expected(int(mine["count"]) + (bonus if target.is_prepared() else 0), int(mine["threshold"]))
	var theirs_expected := Dice.expected(int(attack["count"]) + (bonus if actor.is_prepared() else 0), int(attack["threshold"]))
	return mine_expected > theirs_expected + 0.5


## Attaque utilisée pour contre-attaquer : l'arme du personnage, ou la première attaque de la créature.
func _counter_effect(c: Combatant) -> Dictionary:
	if c.character != null:
		return {"type": "attack", "weapon": true}
	for action: Dictionary in c.combat_actions():
		for e: Dictionary in action.get("effects", []):
			if e.get("type") == "attack":
				return e
	return {}


## Contre-attaque : les deux font un jet d'attaque en opposition (Esquive naturelle ou Couvert à 0) ; le
## plus de succès touche, l'attaquant initial l'emportant en cas d'égalité ; le perdant ne peut ni esquiver
## ni parer. Retourne true si l'attaque initiale touche.
func _counter(actor: Combatant, target: Combatant, e: Dictionary, attack: Dictionary, beats: Array[Dictionary],
		fast: bool) -> bool:
	target.reactions -= 1
	var counter_effect := _counter_effect(target)
	var counter := target.attack_pool(counter_effect)
	_beat(beats, Loc.ui("%s contre-attaque !") % target.name)
	var a_roll := Dice.roll_pool(rng, int(attack["count"]) + actor.use_prepared(), int(attack["threshold"]))
	var d_roll := Dice.roll_pool(rng, int(counter["count"]) + target.use_prepared(), int(counter["threshold"]))
	_beat(beats, Loc.ui("%s : %d succès.") % [actor.name, int(a_roll["successes"])],
		_roll_info(Loc.ui("Attaque (%s)") % actor.name, a_roll), fast)
	_beat(beats, Loc.ui("%s : %d succès.") % [target.name, int(d_roll["successes"])],
		_roll_info(Loc.ui("Contre-attaque (%s)") % target.name, d_roll), fast)
	var a := int(a_roll["successes"]) * actor.attack_successes_multiplier(target)
	var d := int(d_roll["successes"]) * target.attack_successes_multiplier(actor)
	if a >= d:
		var level := Dice.critical_level(a - d, actor.critical_bonus())
		_beat(beats, Loc.ui("%s l'emporte%s.") % [actor.name, Loc.ui(" (critique %d)") % level if level > 0 else ""])
		await _hit(actor, target, e, attack, level, false, false, beats, fast)
		return true
	var counter_level := Dice.critical_level(d - a, target.critical_bonus())
	_beat(beats, Loc.ui("%s l'emporte%s.") % [target.name, Loc.ui(" (critique %d)") % counter_level if counter_level > 0 else ""])
	await _hit(target, actor, counter_effect, counter, counter_level, false, false, beats, fast)
	return false


## Une attaque touche : dégâts (Armure de la cible, critiques), parade éventuelle, dégâts d'autres types.
func _hit(actor: Combatant, target: Combatant, e: Dictionary, attack: Dictionary, critical: int, surprise: bool,
		can_parry: bool, beats: Array[Dictionary], fast: bool) -> void:
	var savage: bool = e.get("weapon") is bool and e.get("weapon") and actor.has_modifier("savage_attacker") \
		and not actor.savage_used
	if savage:
		actor.savage_used = true
	var ignore_armor := surprise and not target.has_natural_armor()
	var rerolls := critical + (1 if actor.great_weapon_fighting(e) else 0)
	var options := {"armor": not ignore_armor, "from_attack": true}
	if can_parry:
		options["parry"] = {"attacker": actor, "effect": e, "fast": fast}
	var pool := actor.damage_pool(e, attack)
	if savage:
		pool["count"] = int(pool["count"]) + 1
		_beat(beats, Loc.ui("Frappe brutale : un dé de dégâts en plus."))
	if critical > 0 and actor.critical_damage_dice() > 0:
		pool["count"] = int(pool["count"]) + actor.critical_damage_dice()
		_beat(beats, Loc.ui("Attaques précises : %d dés de dégâts en plus.") % actor.critical_damage_dice())
	await _roll_damage(actor, target, pool, actor.damage_type(e), rerolls, beats, options)
	for part: Dictionary in actor.bonus_damage(e):
		await _roll_damage(actor, target, {"count": int(part.get("dice", 1)), "threshold": int(part.get("threshold", 5))},
			part["damage_type"], rerolls, beats, {"armor": not ignore_armor})


## La cible peut-elle parer (une réaction, une par main armée et par tour) ? Une attaque à distance ne se
## pare qu'avec un bouclier ; une attaque armée ne se pare pas à mains nues.
func can_parry(attacker: Combatant, target: Combatant, e: Dictionary) -> bool:
	if target.reactions <= 0 or target.parries_used >= target.parries_per_turn():
		return false
	if attacker.is_ranged_attack(e) and not target.has_shield():
		return false
	return not (attacker.is_armed_attack(e) and not target.is_armed())


## Dés en plus d'un combattant préparé (sans consommer l'état), pour l'affichage.
func target_prepared_bonus(c: Combatant) -> int:
	return int(setting("prepared_dice", 2)) if c.is_prepared() else 0


## Parade : Armes de mêlée (arme, bouclier) ou Physique (mains nues), DEX. Retourne ses succès (0 si elle
## n'est pas possible).
func _parry(attacker: Combatant, target: Combatant, e: Dictionary, beats: Array[Dictionary], fast: bool) -> int:
	if not can_parry(attacker, target, e):
		return 0
	target.reactions -= 1
	target.parries_used += 1
	var pool := target.parry_pool(target.use_prepared())
	var roll := Dice.roll_pool(rng, int(pool["count"]), int(pool["threshold"]))
	_beat(beats, Loc.ui("%s pare : %d succès.") % [target.name, int(roll["successes"])],
		_roll_info(Loc.ui("Parade (%s)") % target.name, roll), fast)
	return int(roll["successes"])


## Lance et inflige des dégâts : un succès = un point. `rerolls` : relances des dés ratés (critique).
## Options : "armor" (l'Armure de la cible baisse le seuil, sans passer sous 1), "resist" ({"ability"} :
## chaque succès de la cible retire un point ; Dérobade : deux), "multiplier" (0.5 : Tour de magie
## puissant), "from_attack" (l'Esquive instinctive peut diviser par deux), "parry" ({"attacker", "effect"} : la cible peut parer).
## Retourne les dégâts infligés.
func _roll_damage(actor: Combatant, target: Combatant, pool: Dictionary, type: String, rerolls: int,
		beats: Array[Dictionary], options: Dictionary = {}) -> int:
	if not target.is_alive():
		return 0
	var threshold := int(pool["threshold"])
	var notes := PackedStringArray()
	var armor := target.armor() if options.get("armor", false) else 0
	if armor > 0:
		var lowered := maxi(mini(1, threshold), threshold - armor)
		notes.append(Loc.ui("armure : seuil %d → %d") % [threshold, lowered])
		threshold = lowered
	var roll := Dice.roll_pool(rng, int(pool["count"]), threshold, rerolls)
	if rerolls > 0:
		notes.append(Loc.ui("%d relance(s)") % rerolls)
	var amount := int(roll["successes"])
	var label := Loc.ui("Dégâts") + (" " + DamageTypes.name_of(type).to_lower() if type != "" else "")
	_beat(beats, Loc.ui("%s : %d succès.") % [label, amount], _roll_info(label, roll), true)
	var resist: Dictionary = options.get("resist", {})
	if not resist.is_empty():
		var ability: String = resist.get("ability", "dex")
		var resisted := 0
		if not target.has_status_flag("auto_fail_resist", ability):
			var resist_pool := target.resist_pool(ability)
			var resist_roll := Dice.roll_pool(rng, int(resist_pool["count"]), int(resist_pool["threshold"]))
			resisted = int(resist_roll["successes"]) * (2 if ability == "dex" and target.has_modifier("evasion") else 1)
			_beat(beats, Loc.ui("%s résiste : %d succès.") % [target.name, int(resist_roll["successes"])],
				_roll_info(Loc.ui("Résister (%s)") % Abilities.name_of(ability), resist_roll), true)
		if resisted > 0:
			notes.append(Loc.ui("résiste : −%d") % mini(resisted, amount))
			amount = maxi(0, amount - resisted)
	var parry: Dictionary = options.get("parry", {})
	if not parry.is_empty() and amount > 0 and can_parry(parry["attacker"], target, parry["effect"]) \
			and await _decide(target, "parry", {"attacker": parry["attacker"], "damage": amount, "beats": beats,
				"parry": target.parry_pool(target_prepared_bonus(target))}, true):
		var parried := _parry(parry["attacker"], target, parry["effect"], beats, parry.get("fast", false))
		if parried > 0:
			notes.append(Loc.ui("parade : −%d") % mini(parried, amount))
			amount = maxi(0, amount - parried)
	var multiplier := float(options.get("multiplier", 1.0))
	if multiplier < 1.0:
		amount = int(floor(amount * multiplier))
		notes.append(Loc.ui("moitié"))
	if options.get("from_attack", false) and amount > 1 and target.has_modifier("uncanny_dodge") and not target.reaction_used:
		target.reaction_used = true
		@warning_ignore("integer_division")
		amount = amount / 2
		notes.append(Loc.ui("esquive instinctive"))
	var dealt := _deal_damage(actor, target, amount, type, false, "")
	var inflicted := _status_from_damage(target, type, dealt["amount"])
	var text := Loc.ui("%s subit %d dégâts") % [target.name, dealt["amount"]]
	if not notes.is_empty():
		text += " (%s)" % ", ".join(notes)
	if type != "":
		text += " " + DamageTypes.bbcode_name(type)
	text += dealt["suffix"] + inflicted
	_beat(beats, text)
	return int(dealt["amount"])


## Un type de dégâts peut infliger un état quand il blesse (le feu enflamme…). Retourne le texte ajouté.
func _status_from_damage(target: Combatant, type: String, dealt: int) -> String:
	var status := DamageTypes.status_of(type)
	if status.is_empty() or dealt <= 0 or not target.is_alive() or rng.randf() >= float(status.get("chance", 0.0)):
		return ""
	if target.defenses().is_immune_to_status(status["id"]):
		return ""
	target.add_status(status["id"], int(status.get("stacks", 1)))
	return " " + Loc.ui("%s : +%d %s.") % [target.name, int(status.get("stacks", 1)), StatusEffects.name_of(status["id"])]


## Test de compétence de l'acteur, contre une difficulté ("difficulty") ou en opposition contre la
## résistance de la cible ("vs_resist" : il faut plus de succès qu'elle ; à égalité, rien ne bouge).
## Retourne true si l'acteur réussit.
func _skill_check(actor: Combatant, target: Combatant, e: Dictionary, beats: Array[Dictionary], fast: bool) -> bool:
	var skill: String = e["skill"]
	var bonus := (-1 if actor.has_status_flag("check_disadvantage") else 0) + actor.use_prepared()
	var pool := actor.skill_pool(skill, e.get("ability", ""), bonus)
	var roll := Dice.roll_pool(rng, int(pool["count"]), int(pool["threshold"]))
	var label := Skills.name_of(skill)
	if e.has("vs_resist") or e.has("vs_save"):
		var ability: String = e.get("vs_resist", e.get("vs_save", "wis"))
		var resist_pool := target.resist_pool(ability)
		var resist_roll := Dice.roll_pool(rng, int(resist_pool["count"]), int(resist_pool["threshold"]))
		var success := int(roll["successes"]) > int(resist_roll["successes"])
		_beat(beats, Loc.ui("%s : %s, %d succès contre %d — %s") % [actor.name, label, int(roll["successes"]),
			int(resist_roll["successes"]), Loc.ui("réussi") if success else Loc.ui("raté")],
			_roll_info("%s (%s)" % [label, actor.name], roll), fast)
		_beat(beats, Loc.ui("%s résiste : %d succès.") % [target.name, int(resist_roll["successes"])],
			_roll_info(Loc.ui("Résister (%s)") % Abilities.name_of(ability), resist_roll), true)
		return success
	var judged := Dice.judge(int(roll["successes"]), Dice.difficulty_of(e), 0, roll["dice"])
	_beat(beats, Loc.ui("%s : %s, %d succès / %d — %s") % [actor.name, label, int(roll["successes"]), int(judged["difficulty"]),
		Dice.verdict(judged)], _roll_info("%s (%s)" % [label, actor.name], roll, judged), fast)
	return judged["success"]


## La cible résiste-t-elle à un effet ? Opposition : la réserve d'incantation de l'acteur (ou la
## compétence "skill" de `resist`) contre la résistance de la cible ; il faut plus de succès qu'elle.
## Paralysé : pas de résistance en FOR et DEX.
func _resists(actor: Combatant, target: Combatant, resist: Dictionary, beats: Array[Dictionary], fast: bool) -> bool:
	var ability: String = resist.get("ability", "con")
	if target.has_status_flag("auto_fail_resist", ability):
		_beat(beats, Loc.ui("%s ne peut pas résister.") % target.name)
		return false
	var pool := actor.spell_pool() if not resist.has("skill") else actor.skill_pool(resist["skill"], resist.get("with", ""))
	var roll := Dice.roll_pool(rng, int(pool["count"]), int(pool["threshold"]))
	var resist_pool := target.resist_pool(ability)
	var resist_roll := Dice.roll_pool(rng, int(resist_pool["count"]), int(resist_pool["threshold"]))
	var resisted := int(resist_roll["successes"]) >= int(roll["successes"])
	_beat(beats, Loc.ui("%s : %d succès contre %d pour %s — %s") % [actor.name, int(roll["successes"]),
		int(resist_roll["successes"]), target.name, Loc.ui("résisté") if resisted else Loc.ui("affecté")],
		_roll_info(Loc.ui("Résister (%s, %s)") % [Abilities.name_of(ability), target.name], resist_roll), fast)
	# Inflexible (Guerrier) : relance une résistance ratée.
	if not resisted and target.character != null and int(target.character.resources.get("indomitable", 0)) > 0:
		target.character.resources["indomitable"] = int(target.character.resources["indomitable"]) - 1
		resist_roll = Dice.roll_pool(rng, int(resist_pool["count"]), int(resist_pool["threshold"]))
		resisted = int(resist_roll["successes"]) >= int(roll["successes"])
		_beat(beats, Loc.ui("%s est inflexible et relance : %d succès — %s") % [target.name, int(resist_roll["successes"]),
			Loc.ui("résisté") if resisted else Loc.ui("affecté")],
			_roll_info(Loc.ui("Résister (%s, %s)") % [Abilities.name_of(ability), target.name], resist_roll), fast)
	return resisted


## Inflige des dégâts : défenses (sauf dégâts bruts), puis Protection (sauf dégâts bruts).
## Retourne {"amount": dégâts subis, "suffix": texte complémentaire (« (résistance) », « Vaincu »…)}.
func _deal_damage(source: Combatant, target: Combatant, amount: int, type: String, raw: bool,
		death_cause: String) -> Dictionary:
	var notes := PackedStringArray()
	if not raw and type != "":
		var ignore := source != null and source.character != null \
			and source.character.modifiers().any(func(m): return m.get("type") == "ignore_resistance" and m.get("damage_type") == type)
		var applied := DamageTypes.apply(amount, type, target.defenses(), ignore)
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
	target.reactions = 0
	if not target.is_ally():
		return Loc.ui("%s est vaincu.") % target.name
	if spec.get("on_defeat", "death") == "knockout" and not target.summoned:
		return Loc.ui("%s s'effondre, assommé.") % target.name
	if target.summoned:
		return Loc.ui("%s se dissipe.") % target.name
	if target.is_hero():
		var cause := death_cause
		if cause == "" and attacker != null:
			cause = attacker.creature.get("death_cause", Loc.ui("Tué par %s") % attacker.name)
		hero_down_cause = cause if cause != "" else Loc.ui("Mort au combat")
	# Pas de jets contre la mort : tant qu'un allié tient debout, celui qui tombe est inconscient ;
	# ses compagnons le ramèneront à lui après le combat. Si tout le groupe tombe, c'est la mort.
	return Loc.ui("%s s'effondre, inconscient.") % target.name


## Un attaquant caché se révèle en attaquant.
func _reveal(actor: Combatant) -> void:
	for status_id: String in actor.statuses.keys():
		if StatusEffects.has_flag(status_id, "attack_surprise"):
			actor.remove_status(status_id)


func _decay(actor: Combatant, status_id: String) -> void:
	var amount := StatusEffects.decay_amount(status_id)
	if amount < 0:
		actor.remove_status(status_id)
	elif amount > 0:
		actor.add_status(status_id, -amount)


func _check_end() -> void:
	if outcome != "":
		return
	if life.dead or not _party_standing():
		outcome = "defeat"
		if spec.get("on_defeat", "death") != "knockout" and not life.dead:
			life.die(hero_down_cause if hero_down_cause != "" else Loc.ui("Mort au combat"))
	elif living("enemy").is_empty():
		outcome = "victory"
	if outcome != "":
		log.append({"victory": Loc.ui("Victoire !"), "defeat": Loc.ui("Défaite…")}[outcome])


## Un personnage du groupe (héros ou compagnon, pas une invocation) tient-il encore debout ?
func _party_standing() -> bool:
	return combatants.any(func(c): return c.is_ally() and c.character != null and c.is_alive())


func _beat(beats: Array[Dictionary], text: String, roll: Dictionary = {}, fast := false) -> void:
	var beat := {"text": text, "roll": roll, "fast": fast}
	beats.append(beat)
	stream.append(beat)
	log.append(text)


## Décide d'une réaction : le joueur choisit pour ses personnages (sauf en mode IA, ou avec l'option
## « réactions automatiques »), sinon le choix automatique `auto`.
func _decide(target: Combatant, kind: String, info: Dictionary, auto: bool) -> bool:
	if reaction_chooser.is_valid() and target.is_player_controlled() and not target.is_auto() \
			and not Meta.settings.get("auto_reactions", false):
		var chosen: bool = await reaction_chooser.call(target, kind, info)
		return chosen
	return auto


## Jet de réserve pour le plateau de dés : {"dice", "pool": true, "threshold", "successes", "stat",
## "difficulty"?, "dc_label"?, "success"?, "critical"?, "fumble"?}.
func _roll_info(stat: String, roll: Dictionary, judged: Dictionary = {}, against := "") -> Dictionary:
	var info := {"dice": roll["dice"], "pool": true, "threshold": int(roll["threshold"]),
		"successes": int(roll["successes"]), "auto": int(roll.get("auto", 0)), "stat": stat}
	if not judged.is_empty():
		info["difficulty"] = int(judged["difficulty"])
		info["success"] = judged["success"]
		info["critical"] = int(judged["critical"])
		info["fumble"] = judged["fumble"]
		if against != "":
			info["dc_label"] = against
	return info


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


## Initiative de tous les combattants, lancée d'un coup : 1d10 + initiative de base (DEX + INT). Égalité :
## la plus haute DEX, puis la plus haute INT, puis au hasard. `initiative_roll` garde un dé par
## combattant (avec son nom et son total) pour que l'interface anime tous les dés ensemble.
func _roll_initiative() -> void:
	var parts := PackedStringArray()
	var dice: Array[Dictionary] = []
	var tiebreak := {}
	for c in combatants:
		var die := rng.randi_range(1, 10)
		var entry := {"sides": 10, "value": die}
		if c.has_modifier("initiative_advantage"):
			var other := rng.randi_range(1, 10)
			if other > die:
				die = other
			entry = {"sides": 10, "value": die}
		c.initiative = die + c.initiative_base()
		tiebreak[c] = rng.randf()
		entry["label"] = c.name
		entry["total"] = c.initiative
		dice.append(entry)
	initiative_roll = {"dice": dice, "stat": Loc.ui("Initiative (1d10 + DEX + INT)"), "per_die": true}
	order = combatants.duplicate()
	order.sort_custom(func(a, b):
		if a.initiative != b.initiative:
			return a.initiative > b.initiative
		if a.ability_score("dex") != b.ability_score("dex"):
			return a.ability_score("dex") > b.ability_score("dex")
		if a.ability_score("int") != b.ability_score("int"):
			return a.ability_score("int") > b.ability_score("int")
		return tiebreak[a] > tiebreak[b])
	for c in order:
		parts.append("%s %d" % [c.name, c.initiative])
	log.append(Loc.ui("Initiative : %s") % ", ".join(parts))
	log.append(Loc.ui("— Round %d —") % round_number)
