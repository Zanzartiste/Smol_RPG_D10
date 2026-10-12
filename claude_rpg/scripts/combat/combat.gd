class_name Combat
extends RefCounted
## Combat au tour par tour avec decks (façon Magic: The Gathering) et jets de dés (façon D&D).
## Aucune dépendance à l'interface : chaque action retourne des « étapes » (texte + jet de dés)
## que l'interface anime, l'état étant déjà à jour.
##
## Déroulement : ordre d'initiative (d20 + DEX). Chaque tour commence par start_turn() (effets des
## états, tour passé si étourdi ; pour le héros : mana et pioche), puis :
##   - le héros joue des cartes (mana) et une action de base (attaque d'arme ou objet), ou fuit ;
##   - les autres agissent via ai_turn() (les ennemis peuvent « préparer » une action annoncée).
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
var deck: CombatDeck
var mana: Dictionary = {}  # réserve de mana du héros pour ce tour
var hero_turns := 0  # nombre de tours joués par le héros (le mana généré en dépend)
var basic_actions_left := 0
var skipped := false  # le combattant actif passe son tour (étourdi, mort pendant ses états…)
var _mana_shares: Dictionary = {}
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

	var ch := life.character
	deck = CombatDeck.new(ch.deck, rng, int(setting("max_hand_size", 7)))
	_mana_shares = Mana.deck_shares(ch.deck)
	var opening := deck.draw(maxi(1, ch.ability_mod("int")))
	log.append(Loc.ui("Main de départ : %d carte(s) (modificateur d'Intelligence).") % opening.size())
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
		if DB.items[item_id].has("use"):
			result.append({"item": DB.items[item_id], "count": life.character.item_count(item_id)})
	return result


## Cibles possibles pour un acteur et un type de cible ("enemy", "ally", "self"…).
func targets(actor: Combatant, target: String) -> Array[Combatant]:
	var own := actor.side
	var opposing := "enemy" if actor.is_ally() else "ally"
	match target:
		"self":
			var only_self: Array[Combatant] = [actor]
			return only_self
		"ally", "all_allies":
			return living(own)
		"enemy", "all_enemies":
			return living(opposing)
	var none: Array[Combatant] = []
	return none


# --- Début de tour -----------------------------------------------------------

## Début du tour du combattant actif : effets des états, puis mana et pioche pour le héros.
## Après l'appel, `skipped` indique si le combattant passe son tour.
func start_turn() -> Array[Dictionary]:
	var actor := current()
	var beats: Array[Dictionary] = []
	skipped = false
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
	if actor.is_hero() and not skipped and not is_over():
		hero_turns += 1
		mana = Mana.generate(mini(hero_turns, int(setting("max_mana", 10))), _mana_shares)
		basic_actions_left = int(setting("basic_actions_per_turn", 1))
		if hero_turns > 1:
			var drawn := deck.draw(int(setting("draw_per_turn", 1)))
			if not drawn.is_empty():
				_beat(beats, Loc.ui("%s pioche : %s.") % [actor.name, ", ".join(PackedStringArray(drawn.map(func(id): return Cards.name_of(id))))])
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


# --- Actions du héros --------------------------------------------------------

## Raison pour laquelle la carte d'index `index` ne peut pas être jouée ("" si elle peut l'être).
func card_unplayable_reason(index: int) -> String:
	var card := deck.hand[index]
	if not Mana.can_pay(mana, Cards.cost_of(card)):
		return Loc.ui("mana insuffisant")
	var target := Cards.target_of(card)
	if target in ["enemy", "all_enemies"] and living("enemy").is_empty():
		return Loc.ui("aucune cible")
	for e: Dictionary in Cards.effects_of(card):
		if e.get("type") == "summon" and not can_add("ally", Creatures.size_of(e["creature"])):
			return Loc.ui("plus de place dans votre camp")
	return ""


## Joue une carte de la main (le mana est dépensé). `target` est requis pour les cibles "enemy" / "ally".
func play_card(index: int, target: Combatant = null) -> Array[Dictionary]:
	var card := deck.hand[index]
	mana = Mana.pay(mana, Cards.cost_of(card))["pool"]
	deck.play(index)
	var beats: Array[Dictionary] = []
	_beat(beats, Loc.ui("%s joue %s.") % [hero.name, Cards.name_of(card)])
	beats.append_array(_resolve(hero, Cards.effects_of(card), Cards.target_of(card), target, false))
	_check_end()
	return beats


## Attaque de base (action de base) : celle de la classe (classes.json › basic_attack, ex. un tour de
## magie à volonté pour le magicien), sinon une attaque avec l'arme équipée.
func basic_attack(target: Combatant) -> Array[Dictionary]:
	basic_actions_left -= 1
	var beats := _resolve(hero, basic_attack_effects(), "enemy", target, false)
	_check_end()
	return beats


func basic_attack_effects() -> Array:
	return DB.classes[hero.character.class_id].get("basic_attack", {}).get("effects", [{"type": "attack", "weapon": true}])


func basic_attack_name() -> String:
	var custom: Dictionary = DB.classes[hero.character.class_id].get("basic_attack", {})
	return custom.get("name", Equipment.name_of(hero.character.weapon_id()))


## Utilise un objet (action de base).
func use_item(item_id: String, target: Combatant) -> Array[Dictionary]:
	basic_actions_left -= 1
	var item: Dictionary = DB.items[item_id]
	life.character.remove_item(item_id)
	var effects: Array = []
	var use: Dictionary = item["use"]
	if use.has("heal"):
		effects.append({"type": "heal", "amount": use["heal"]})
	if use.has("cleanse"):
		effects.append({"type": "cleanse", "status": use["cleanse"]})
	var beats: Array[Dictionary] = []
	_beat(beats, Loc.ui("%s utilise : %s.") % [hero.name, item["name"]])
	beats.append_array(_resolve(hero, effects, "ally", target, false))
	_check_end()
	return beats


## Tentative de fuite (termine le tour) : d20 + DEX contre le DD de fuite.
func flee() -> Array[Dictionary]:
	var die := rng.randi_range(1, 20)
	var mod := hero.ability_mod("dex")
	var success := die == 20 or (die != 1 and die + mod >= flee_dc())
	var beats: Array[Dictionary] = []
	beats.append({"fast": false, "text": Loc.ui("%s tente de fuir : %s.") % [
		hero.name, Loc.ui("réussite") if success else Loc.ui("échec")], "roll": {
		"dice": [{"sides": 20, "value": die}], "mod": mod, "dc": flee_dc(), "success": success,
		"stat": Loc.ui("Fuite (Dextérité)")}})
	log.append(beats[0]["text"])
	if success:
		outcome = "fled"
	return beats


# --- Tours de l'IA -----------------------------------------------------------

## Tour d'un combattant contrôlé par l'IA (ennemi, compagnon, invocation).
## Un ennemi qui a préparé une action l'exécute ; sinon il en choisit une (pondérée) et, si elle est
## « préparée », se contente de l'annoncer.
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
	if target_mode in Cards.CHOSEN_TARGETS:
		var candidates := targets(actor, target_mode)
		if candidates.is_empty():
			return beats
		candidates.sort_custom(func(a, b): return a.hp < b.hp)
		# Les alliés visent le plus faible, les ennemis choisissent au hasard.
		chosen = candidates[0] if actor.is_ally() else candidates[rng.randi_range(0, candidates.size() - 1)]
	_beat(beats, Loc.ui("%s : %s.") % [actor.name, action["name"]])
	beats.append_array(_resolve(actor, action.get("effects", []), target_mode, chosen, not actor.is_ally()))
	_check_end()
	return beats


func _pick_action(actor: Combatant) -> Dictionary:
	var actions := actor.ai_actions().filter(func(a): return not targets(actor, a.get("target", "enemy")).is_empty() \
		or a.get("target") == "none")
	var total := 0.0
	for a: Dictionary in actions:
		total += float(a.get("weight", 1))
	var r := rng.randf() * total
	for a: Dictionary in actions:
		r -= float(a.get("weight", 1))
		if r < 0.0:
			return a
	return actions.back() if not actions.is_empty() else {}


# --- Résolution des effets ---------------------------------------------------

## Applique une liste d'effets. `target_mode` : "enemy", "all_enemies", "ally", "all_allies", "self", "none".
## Les effets qui suivent une attaque ratée sont ignorés (jusqu'à l'attaque suivante).
func _resolve(actor: Combatant, effects: Array, target_mode: String, chosen: Combatant, fast: bool) -> Array[Dictionary]:
	var beats: Array[Dictionary] = []
	var target_list: Array[Combatant] = []
	if target_mode in Cards.CHOSEN_TARGETS:
		if chosen != null:
			target_list.append(chosen)
	else:
		target_list = targets(actor, target_mode)
	# Effets sans cible (pioche, invocation) : une seule fois.
	for e: Dictionary in effects:
		if e.get("type") in CombatEffects.UNTARGETED:
			beats.append_array(_apply(actor, e, null, fast)["beats"])
	for target in target_list:
		var hit := true
		for e: Dictionary in effects:
			if e.get("type") in CombatEffects.UNTARGETED:
				continue
			if e.get("type") == "attack":
				var result := _apply(actor, e, target, fast)
				beats.append_array(result["beats"])
				hit = result["hit"]
			elif hit and target.is_alive():
				beats.append_array(_apply(actor, e, target, fast)["beats"])
	return beats


## Applique un effet à une cible. Retourne {"beats", "hit"} (hit : pour les attaques).
func _apply(actor: Combatant, e: Dictionary, target: Combatant, fast: bool) -> Dictionary:
	var beats: Array[Dictionary] = []
	var hit := true
	match e.get("type"):
		"attack":
			var bonus := actor.attack_bonus(e)
			var die := rng.randi_range(1, 20)
			var ac := target.armor_class()
			var critical := die == 20
			hit = critical or (die != 1 and die + bonus >= ac)
			var text := Loc.ui("%s attaque %s : %d + %d = %d contre CA %d — %s") % [
				actor.name, target.name, die, bonus, die + bonus, ac,
				Loc.ui("coup critique !") if critical else (Loc.ui("touché") if hit else Loc.ui("raté"))]
			_beat(beats, text, {"dice": [{"sides": 20, "value": die}], "mod": bonus, "dc": ac, "dc_label": "CA",
				"success": hit, "stat": "%s → %s" % [actor.name, target.name]}, fast)
			if hit:
				_roll_damage(actor, target, actor.damage_expr(e), actor.damage_type(e), critical, beats)
		"damage":
			_roll_damage(actor, target, actor.damage_expr(e), actor.damage_type(e), false, beats)
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
		"draw":
			if actor.is_hero():
				var drawn := deck.draw(int(e["count"]))
				_beat(beats, Loc.ui("%s pioche %d carte(s).") % [actor.name, drawn.size()])
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


func _roll_damage(actor: Combatant, target: Combatant, expr: String, type: String, critical: bool,
		beats: Array[Dictionary]) -> void:
	var roll := Dice.roll_expr(expr, rng, critical)
	var amount := maxi(1, int(roll["total"]) + actor.damage_modifier())
	var dealt := _deal_damage(actor, target, amount, type, false, "")
	var text := Loc.ui("%s subit %d dégâts") % [target.name, dealt["amount"]]
	if type != "":
		text += " " + DamageTypes.name_of(type).to_lower()
	text += dealt["suffix"]
	var label := Loc.ui("Dégâts (%s %s)") % [expr, DamageTypes.name_of(type).to_lower()] if type != "" else Loc.ui("Dégâts (%s)") % expr
	_beat(beats, text, {"dice": roll["dice"], "mod": roll["bonus"], "stat": label}, true)


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


# --- Jeu automatique (tests, banc d'équilibrage) -----------------------------

## Joue le tour du héros automatiquement : cartes jouables les plus utiles, puis attaque de base.
func auto_hero_turn() -> Array[Dictionary]:
	var beats: Array[Dictionary] = []
	var guard := 0
	while not is_over() and guard < 20:
		guard += 1
		var best := -1
		var best_score := 0.0
		for i in deck.hand.size():
			if card_unplayable_reason(i) == "":
				var score := _card_score(deck.hand[i])
				if score > best_score:
					best_score = score
					best = i
		if best < 0:
			break
		beats.append_array(play_card(best, _auto_target(Cards.target_of(deck.hand[best]))))
	if not is_over() and basic_actions_left > 0 and not living("enemy").is_empty():
		beats.append_array(basic_attack(_auto_target("enemy")))
	return beats


func _auto_target(target: String) -> Combatant:
	if target not in Cards.CHOSEN_TARGETS:
		return null
	var candidates := targets(hero, target)
	if candidates.is_empty():
		return null
	if target == "ally":
		candidates.sort_custom(func(a, b): return float(a.hp) / a.max_hp() < float(b.hp) / b.max_hp())
	else:
		candidates.sort_custom(func(a, b): return a.hp < b.hp)
	return candidates[0]


## Valeur approximative d'une carte pour le jeu automatique.
func _card_score(card: String) -> float:
	var score := 0.0
	var enemies_count := living("enemy").size()
	var spread := enemies_count if Cards.target_of(card) == "all_enemies" else 1
	for e: Dictionary in Cards.effects_of(card):
		match e.get("type"):
			"attack":
				score += Dice.average(hero.damage_expr(e)) * 0.6 * spread
			"damage":
				score += Dice.average(hero.damage_expr(e)) * spread
			"heal":
				score += Dice.average(hero.heal_expr(String(e["amount"]))) if hero.hp < hero.max_hp() * 0.5 else 0.0
			"status":
				var stacks := int(e["stacks"])
				match e["status"]:
					"shielded":
						score += stacks * 0.6
					"stunned":
						score += 4.0 * spread
					_:
						score += stacks * 1.2 * spread
			"draw":
				score += 1.5 * int(e["count"])
			"summon":
				score += 5.0
	return score
