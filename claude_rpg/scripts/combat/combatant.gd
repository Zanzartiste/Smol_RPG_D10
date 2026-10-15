class_name Combatant
extends RefCounted
## Participant à un combat :
##   - "hero"      : le personnage joué (Character), contrôlé par le joueur ;
##   - "companion" : un compagnon (Character), contrôlé par le joueur lui aussi ;
##   - "creature"  : une créature du bestiaire (ennemi ou invocation), contrôlée par l'IA.
## Les personnages agissent avec les actions de leur classe (actions.json) ; les créatures avec les leurs.
## Pour un personnage, les PV sont ceux du Character : les dégâts persistent après le combat.
## Les jets sont des réserves de d10 (voir Dice) : {"count": dés, "threshold": seuil}.

var id := ""  # unique dans le combat
var name := ""
var side := "ally"  # "ally" ou "enemy"
var kind := "creature"  # "hero", "companion" ou "creature"
var character: Character
var creature: Dictionary = {}
var summoned := false  # invoqué pendant le combat (disparaît à la fin)
var initiative := 0
var statuses: Dictionary = {}  # id d'état -> charges
var intent: Dictionary = {}  # action annoncée, exécutée au prochain tour (ennemis)
var uses: Dictionary = {}  # id d'action -> utilisations restantes dans ce combat (per_combat)
var reaction_used := false  # Esquive instinctive déjà utilisée ce round, rendue à son tour
var savage_used := false  # Frappe brutale déjà utilisée ce tour
var reactions := 0  # actions gardées à la fin de son tour : esquives, parades, contre-attaques
var parries_used := 0  # parades pendant le tour en cours (une par main armée)
var fast_hands_used := false  # Mains lestes déjà utilisées ce tour
var cunning_used := false  # Ruse (Se cacher sans dépenser d'action) déjà utilisée ce tour
var fled := false  # a quitté le combat (créature lâche) : ni XP ni butin
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


static func from_creature(creature_id: String, label: String, side_id: String, _rng: RandomNumberGenerator = null) -> Combatant:
	var c := Combatant.new()
	c.creature = Creatures.def(creature_id)
	c.kind = "creature"
	c.side = side_id
	c.name = label
	if c.creature.has("hp"):
		c._max_hp = maxi(1, int(c.creature["hp"]))
	else:
		# Comme un personnage : (taille + 2) × CON + 7.
		c._max_hp = Character.hp_from(c.ability_score("con"), c.size())
	c._hp = c._max_hp
	return c


func is_ally() -> bool:
	return side == "ally"


func is_hero() -> bool:
	return kind == "hero"


func is_alive() -> bool:
	return hp > 0 and not fled


## Archétype d'IA d'une créature (creatures.json › "ai") : "brute" (par défaut, cible au hasard) ou
## "hunter" (vise le plus blessé).
func ai_kind() -> String:
	return creature.get("ai", "brute")


## Moral d'une créature (creatures.json › "morale") : "fearless" (par défaut), "coward" (s'enfuit quand
## ses PV sont bas), "pack" (s'enfuit quand le chef de meute tombe, ou la moitié du groupe).
func morale() -> String:
	return creature.get("morale", "fearless")


## Chef de meute (creatures.json › "leader") : sa chute fait fuir la meute.
func is_leader() -> bool:
	return creature.get("leader", false)


func max_hp() -> int:
	return character.max_hp if character != null else _max_hp


# --- Attributs, compétences, défenses ----------------------------------------

## Valeur d'un attribut (personnage : avec ses modificateurs ; créature : "abilities", 4 par défaut).
func ability_score(ability_id: String) -> int:
	if character != null:
		return character.ability_score(ability_id)
	return int(creature.get("abilities", {}).get(ability_id, 4))


## Rang d'une compétence. Créature : "skills", sinon le rang de départ (1, 2 si instinctive).
func skill_rank(skill_id: String) -> int:
	if character != null:
		return character.skill_rank(skill_id)
	var skill := Skills.resolve(spell_skill() if skill_id == Skills.SPELL else skill_id)
	return int(creature.get("skills", {}).get(skill, Skills.base_rank(skill)))


## Réserve d'un test de compétence : {"count", "threshold", "ability"} (attribut imposé, ou le meilleur).
func skill_pool(skill_id: String, ability := "", bonus := 0) -> Dictionary:
	if character != null:
		return character.skill_pool(skill_id, ability, bonus)
	var used := ability
	if used == "":
		for candidate: String in Skills.abilities_of(skill_id):
			if used == "" or ability_score(candidate) > ability_score(used):
				used = candidate
	return {"count": skill_rank(skill_id) + bonus, "threshold": ability_score(used), "ability": used}


## Réserve pour résister à un effet (voir Character.resist_pool). Créature : la compétence liée à
## l'attribut, + "saves" (dés en plus). Un état peut retirer un dé (Entravé : DEX).
func resist_pool(ability_id: String, bonus := 0) -> Dictionary:
	if has_status_flag("resist_penalty", ability_id):
		bonus -= 1
	if character != null:
		return character.resist_pool(ability_id, bonus)
	var skill: String = Dice.setting("resist_skills", {}).get(ability_id, "physique")
	return {"count": skill_rank(skill) + bonus + int(creature.get("saves", {}).get(ability_id, 0)),
		"threshold": ability_score(ability_id), "ability": ability_id}


## Esquive naturelle : DEX ÷ 3 (au moins 1). Difficulté des attaques de mêlée contre lui.
func natural_dodge() -> int:
	if character != null:
		return character.natural_dodge()
	var divisor := int(Combat.setting("dodge_divisor", 3))
	@warning_ignore("integer_division")
	return maxi(1, ability_score("dex") / divisor) + int(creature.get("natural_dodge", 0))


## Armure : baisse d'autant le seuil des dégâts subis (sans passer sous 1).
func armor() -> int:
	return character.armor() if character != null else int(creature.get("armor", 0))


## Armure naturelle (peau épaisse, carapace) : une attaque surprise ne l'ignore pas.
func has_natural_armor() -> bool:
	return character == null and creature.get("natural_armor", false)


## Initiative de base : DEX + INT (+ Vigilant…). On y ajoute 1d10 en début de combat.
func initiative_base() -> int:
	return character.initiative_base() if character != null else ability_score("dex") + ability_score("int")


## Actions par tour (rules.json › combat › actions_per_turn ; une créature peut en avoir plus).
func actions_per_turn() -> int:
	return int(creature.get("actions_per_turn", Combat.setting("actions_per_turn", 2)))


## Seuil d'un sort lancé par ce combattant (attribut d'incantation ; créature : "spell_ability", INT).
func spell_threshold() -> int:
	if character != null:
		return character.ability_score(character.action_ability("spell"))
	return ability_score(creature.get("spell_ability", "int"))


## Compétence d'incantation (personnage : voir Character.spell_skill ; créature : "spell_skill", Érudition).
func spell_skill() -> String:
	if character != null:
		return character.spell_skill()
	return creature.get("spell_skill", "lore")


## Lance-t-il des sorts (pour contrer un sort) ? Créature : si elle a un attribut d'incantation.
func is_spellcaster() -> bool:
	return character.spell_skill() != "" if character != null else creature.has("spell_ability")


## Réserve d'incantation (compétence d'incantation contre l'attribut d'incantation) pour imposer un effet
## à une cible.
func spell_pool(bonus := 0) -> Dictionary:
	return {"count": skill_rank(Skills.SPELL) + bonus, "threshold": spell_threshold(), "ability": "spell"}


## Dés de dégâts en plus sur un critique (Attaques précises du Roublard).
func critical_damage_dice() -> int:
	return Modifiers.sum(character.modifiers(), "critical_damage_dice") if character != null else 0


## Multiplicateur des succès d'une attaque de `self` contre `target` (Rage : ×2 pour l'enragé, qu'il
## attaque ou soit attaqué).
func attack_successes_multiplier(target: Combatant) -> int:
	return _status_multiplier() * (target._status_multiplier() if target != null else 1)


func _status_multiplier() -> int:
	var result := 1
	for status_id: String in statuses:
		result *= maxi(1, int(StatusEffects.def(status_id).get("attack_successes_multiplier", 1)))
	return result


func has_modifier(type: String) -> bool:
	return character != null and character.has_modifier(type)


## Succès comptés en plus pour atteindre un critique (Critique amélioré : 1 par aptitude).
func critical_bonus() -> int:
	return Modifiers.sum(character.modifiers(), "critical_range") if character != null else 0


## Attaques en plus pour l'action Attaque (Attaque supplémentaire).
func extra_attacks() -> int:
	return Modifiers.sum(character.modifiers(), "extra_attack") if character != null else 0


## Résistances, immunités et vulnérabilités (voir Defenses).
func defenses() -> Defenses:
	return character.all_defenses() if character != null else Defenses.from_dict(creature.get("defenses", {}))


func size() -> int:
	return character.size() if character != null else int(creature.get("size", 0))


## Places occupées dans son camp (rules.json › combat.size_slots).
func slots() -> float:
	return Combat.size_slots(size())


# --- Actions -----------------------------------------------------------------

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
## en une variante par niveau lançable (jusqu'au niveau de sort le plus haut du personnage) ; les autres
## actions en une seule.
func action_variants(action: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if character != null and action.get("cost") == Spellcasting.SLOT_KEY and Spellcasting.can_upcast(action):
		for level in range(int(action.get("spell_level", 1)), character.max_spell_level() + 1):
			result.append(Spellcasting.at_level(action, level))
	if result.is_empty():
		result.append(action)
	return result


## Ressource consommée par une action ("" si aucune).
func resource_key(action: Dictionary) -> String:
	return action.get("cost", "")


## Quantité de ressource consommée : le niveau du sort pour des emplacements, 1 sinon.
func resource_amount(action: Dictionary) -> int:
	return Spellcasting.cost_of(action) if resource_key(action) == Spellcasting.SLOT_KEY else 1


## L'action ne coûte-t-elle aucune action (Fougue ; Se cacher avec la Ruse, une fois par tour) ?
func is_free(action: Dictionary) -> bool:
	return action.get("free", false) or (action.get("id", "") == "hide" and has_modifier("cunning_action") and not cunning_used)


## L'IA joue-t-elle ce personnage (option par personnage) ?
func is_auto() -> bool:
	return character != null and character.auto_combat


## Le combattant a-t-il un bouclier (pour parer une attaque à distance) ?
func has_shield() -> bool:
	return character != null and Equipment.is_shield(character.equipment.get("off_hand", ""))


## Tient-il une arme (ou un bouclier) en main ? Une créature est armée si une de ses attaques utilise
## une arme.
func is_armed() -> bool:
	if character != null:
		return character.weapon_id() != Equipment.UNARMED or character.equipment.has("off_hand")
	return creature.get("actions", []).any(func(a): return a.get("effects", []).any(func(e): return e.get("weapon") is String))


## Parades possibles par tour : une par main armée (arme et arme ou bouclier), une seule sinon.
func parries_per_turn() -> int:
	if character != null and character.weapon_id() != Equipment.UNARMED and character.equipment.has("off_hand"):
		return 2
	return 1


## Réserve de parade : Armes de mêlée (arme ou bouclier) ou Physique (mains nues), contre la DEX
## (une arme peut imposer un autre seuil : "parry": {"ability", "bonus"}).
func parry_pool(bonus := 0) -> Dictionary:
	var weapon := character.weapon_id() if character != null else ""
	var armed := is_armed()
	var pool := skill_pool("weapon_melee" if armed else "physique", "dex", bonus)
	var parry: Dictionary = Equipment.def(weapon).get("parry", {}) if weapon != "" else {}
	if not parry.is_empty():
		pool["threshold"] = ability_score(parry.get("ability", "dex")) + int(parry.get("bonus", 0))
	return pool


## Une action peut-elle être utilisée ? Retourne "" si oui, sinon la raison.
func unavailable_reason(action: Dictionary) -> String:
	if action.get("target", "enemy") in ["enemy", "all_enemies"] and has_status_flag("no_hostile_actions"):
		return Loc.ui("charmé")
	if has_status_flag("melee_only") and not is_melee_attack_action(action):
		return Loc.ui("en rage : attaques au corps à corps seulement")
	if action.has("per_combat") and int(uses.get(action.get("id", ""), 0)) <= 0:
		return Loc.ui("déjà utilisée")
	var key := resource_key(action)
	if key == Spellcasting.SLOT_KEY and character != null and Spellcasting.cost_of(action) > character.max_spell_level():
		return Loc.ui("sort de niveau trop élevé")
	if key != "" and key != Spellcasting.SLOT_KEY and character != null and int(character.resources.get(key, 0)) < resource_amount(action):
		return Loc.ui("pas assez d'%s") % Actions.resource_name(key) if key == Spellcasting.SLOT_KEY \
			else Loc.ui("plus d'%s") % Actions.resource_name(key)
	return ""


## Décompte une utilisation (par combat) et la ressource éventuelle (mana…). Le mana manquant se paie
## en PV (jusqu'à 0) : retourne les PV dépensés.
func consume(action: Dictionary) -> int:
	if action.has("per_combat"):
		uses[action["id"]] = int(uses.get(action["id"], 0)) - 1
	var key := resource_key(action)
	if key == "" or character == null:
		return 0
	var have := int(character.resources.get(key, 0))
	var cost := resource_amount(action)
	character.resources[key] = maxi(0, have - cost)
	if key != Spellcasting.SLOT_KEY or cost <= have:
		return 0
	var blood := mini(cost - have, hp)
	hp -= blood
	return blood


# --- États -------------------------------------------------------------------

## Un des états actifs a-t-il ce marqueur (voir StatusEffects.has_flag) ?
func has_status_flag(key: String, value := "") -> bool:
	for status_id: String in statuses:
		if StatusEffects.has_flag(status_id, key, value):
			return true
	return false


func stacks(status_id: String) -> int:
	return int(statuses.get(status_id, 0))


func add_status(status_id: String, amount: int) -> void:
	statuses[status_id] = stacks(status_id) + amount
	if stacks(status_id) <= 0:
		statuses.erase(status_id)


func remove_status(status_id: String) -> void:
	statuses.erase(status_id)


## Dés de dégâts en plus ou en moins dus aux états (ex. Affaibli : −1 par charge).
func damage_dice_modifier() -> int:
	var total := 0
	for status_id: String in statuses:
		total += int(StatusEffects.def(status_id).get("damage_dice_per_stack", 0)) * stacks(status_id)
	return total


func is_prepared() -> bool:
	return has_status_flag("prepared")


## Préparé : consomme l'état et retourne les dés en plus (0 s'il n'est pas préparé).
func use_prepared() -> int:
	if not is_prepared():
		return 0
	for status_id: String in statuses.keys():
		if StatusEffects.has_flag(status_id, "prepared"):
			statuses.erase(status_id)
	return int(Combat.setting("prepared_dice", 2))


## Devient Préparé (sans cumul).
func become_prepared() -> void:
	for status_id: String in StatusEffects.ids():
		if StatusEffects.has_flag(status_id, "prepared"):
			statuses[status_id] = 1
			return


# --- Attaques ----------------------------------------------------------------

## Réserve d'attaque d'un effet "attack" : {"count", "threshold", "rank", "skill", "ability"}.
## Personnage : arme en main (+ modificateurs d'arme), arme donnée, ou sort (compétence d'incantation). Créature : "skill"
## et "ability" de l'effet (Physique et FOR par défaut), ou l'arme donnée.
func attack_pool(effect: Dictionary) -> Dictionary:
	var pool := {}
	if character != null:
		if _uses_own_weapon(effect):
			var mods := character.modifiers()
			var bonus := Modifiers.sum(mods, "weapon_attack")
			if Equipment.has_property(character.weapon_id(), "ranged"):
				bonus += Modifiers.sum(mods, "ranged_attack")  # style Archerie
			pool = character.attack_pool("weapon", "", bonus)
			pool["skill"] = _best_weapon_skill(character.weapon_id())
		elif effect.get("weapon") is String:
			pool = character.attack_pool(String(effect.get("ability", "weapon")), effect["weapon"],
				-off_hand_penalty() if effect.get("off_hand", false) else 0)
			pool["skill"] = _best_weapon_skill(effect["weapon"])
		elif effect.get("ability") == "spell":
			pool = character.attack_pool("spell")
			pool["skill"] = spell_skill()
		else:
			pool = character.skill_pool(effect.get("skill", "physique"), effect.get("ability", "str"))
			pool["skill"] = effect.get("skill", "physique")
	elif effect.get("weapon") is String:
		var weapon: String = effect["weapon"]
		var skill := _best_weapon_skill(weapon)
		var ability := Equipment.attack_ability(weapon, ability_score("str"), ability_score("dex"))
		pool = {"count": skill_rank(skill), "threshold": ability_score(ability), "ability": ability, "skill": skill}
	elif effect.get("ability") == "spell":
		pool = spell_pool()
		pool["skill"] = spell_skill()
	else:
		var skill: String = effect.get("skill", "physique")
		pool = skill_pool(skill, effect.get("ability", "str"))
		pool["skill"] = skill
	pool["rank"] = skill_rank(pool["skill"])
	return pool


## Compétence d'arme la plus haute pour une arme (Equipment.skills_for).
func _best_weapon_skill(weapon: String) -> String:
	var best := ""
	for skill_id: String in Equipment.skills_for(weapon):
		if best == "" or skill_rank(skill_id) > skill_rank(best):
			best = skill_id
	return best


## Spécification des dégâts d'un effet : {"threshold": "weapon" | "spell" | attribut | N, "bonus",
## "dice", "skill"?} (celle de l'arme pour une attaque d'arme).
func damage_spec(effect: Dictionary) -> Dictionary:
	if _uses_own_weapon(effect):
		return Equipment.weapon_damage(character.weapon_id(), not character.equipment.has("off_hand"))
	if effect.get("weapon") is String:
		return Equipment.weapon_damage(effect["weapon"])
	var spec: Variant = effect.get("damage", {})
	return spec if spec is Dictionary else {}


## Réserve de dégâts d'un effet : {"count", "threshold"}. Nombre de dés : rang de la compétence
## d'attaque (ou de "skill"), + "dice", + paliers (tours de magie, Attaque sournoise), + états ; seuil :
## l'attribut d'attaque, un attribut, ou fixe, + "bonus". Arme magique et style Duel : des dés en plus.
func damage_pool(effect: Dictionary, attack: Dictionary = {}) -> Dictionary:
	var spec := damage_spec(effect)
	var count := int(spec.get("dice", 0)) + damage_dice_modifier()
	if spec.has("skill"):
		count += skill_rank(spec["skill"])
	elif not attack.is_empty():
		count += int(attack["rank"])
	if effect.has("scaling") and character != null:
		var scaling_class: String = effect["scaling"].get("class", "")
		var scaling_level: int = character.class_level(scaling_class) if scaling_class != "" else character.level
		var steps := Spellcasting.dice_count(effect["scaling"]["table"], scaling_level)
		count += steps - 1 if effect["scaling"]["table"] == "cantrip" else steps
	var threshold := 0
	var source: Variant = spec.get("threshold", "spell" if effect.get("ability") == "spell" else "weapon")
	if source is String:
		match source:
			"weapon":
				threshold = int(attack.get("threshold", ability_score("str")))
			"spell":
				threshold = spell_threshold()
			_:
				threshold = ability_score(source)
	else:
		threshold = int(source)
	threshold += int(spec.get("bonus", 0))
	if character != null:
		var mods := character.modifiers()
		if _uses_own_weapon(effect):
			count += Modifiers.sum(mods, "weapon_damage")
			var weapon := character.weapon_id()
			if weapon == Equipment.UNARMED:
				count += Modifiers.sum(mods, "unarmed_fighting")  # style À mains nues
			elif off_hand_weapon() == "" and not two_handed_grip() and not Equipment.has_property(weapon, "ranged"):
				count += Modifiers.sum(mods, "dueling")  # style À une main
		if effect.get("off_hand", false):
			count -= off_hand_penalty()
		if effect.get("school") == "evocation" and has_modifier("empowered_evocation"):
			count += 1
	return {"count": count, "threshold": threshold}


## Dégâts d'autres types ajoutés à un effet : ceux de l'effet, plus ceux de l'arme s'il l'utilise.
## Chaque partie : {"dice", "threshold", "damage_type"}, lancée à part.
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


## L'attaque est-elle à distance (arme à distance, sort, ou "ranged") ?
func is_ranged_attack(effect: Dictionary) -> bool:
	if effect.get("ability", "") == "spell" or effect.get("ranged", false):
		return true
	if _uses_own_weapon(effect):
		return Equipment.has_property(character.weapon_id(), "ranged")
	return effect.get("weapon") is String and Equipment.has_property(effect["weapon"], "ranged")


## L'attaque est-elle armée (arme, sort) ? Sinon (mains nues, crocs), elle se pare à mains nues.
func is_armed_attack(effect: Dictionary) -> bool:
	if effect.get("ability", "") == "spell":
		return true
	if _uses_own_weapon(effect):
		return character.weapon_id() != Equipment.UNARMED
	return effect.get("weapon") is String and effect["weapon"] != Equipment.UNARMED


## Arme tenue en main secondaire ("" : rien, ou un bouclier).
func off_hand_weapon() -> String:
	if character == null:
		return ""
	var item: String = character.equipment.get("off_hand", "")
	return item if item != "" and Equipment.is_weapon(item) and not Equipment.is_shield(item) else ""


## Attaque de la main secondaire qui suit une attaque avec l'arme principale (une arme dans chaque main) :
## l'effet d'attaque, ou {} s'il n'y en a pas.
func off_hand_attack(effect: Dictionary) -> Dictionary:
	if not _uses_own_weapon(effect) or off_hand_weapon() == "":
		return {}
	var weapon := off_hand_weapon()
	return {"type": "attack", "weapon": weapon, "off_hand": true, "ability": Equipment.attack_ability(weapon,
		ability_score("str") - character.roll_penalty("str"), ability_score("dex") - character.roll_penalty("dex"))}


## Malus (en dés, à l'attaque et aux dégâts) de l'attaque de la main secondaire (rules.json › combat) ;
## aucun avec le style À deux armes.
func off_hand_penalty() -> int:
	if has_modifier("two_weapon_fighting"):
		return 0
	return int(DB.rules.get("combat", {}).get("off_hand_penalty", 2))


## L'action n'est-elle faite que d'attaques au corps à corps (permises pendant la Rage) ?

func is_melee_attack_action(action: Dictionary) -> bool:
	var effects: Array = action.get("effects", [])
	var attacks := effects.filter(func(e): return e.get("type") == "attack")
	return not attacks.is_empty() and attacks.all(func(e): return not is_ranged_attack(e)) \
		and effects.all(func(e): return e.get("type") in ["attack", "status"])


## L'arme est tenue à deux mains (arme à deux mains, ou polyvalente sans rien en main secondaire).

func two_handed_grip() -> bool:
	if character == null:
		return false
	var weapon := character.weapon_id()
	return Equipment.has_property(weapon, "two_handed") \
		or (Equipment.has_property(weapon, "versatile") and not character.equipment.has("off_hand"))


## L'attaque d'arme profite-t-elle du style Armes à deux mains (une relance des dés de dégâts ratés) ?
func great_weapon_fighting(effect: Dictionary) -> bool:
	return _uses_own_weapon(effect) and two_handed_grip() and has_modifier("great_weapon_fighting")


## Réserve de soins : {"dice", "skill"?, "threshold": attribut | N, "bonus"?}.
func heal_pool(spec: Dictionary) -> Dictionary:
	var count := int(spec.get("dice", 0))
	if spec.has("skill"):
		count += skill_rank(spec["skill"])
	var source: Variant = spec.get("threshold", 5)
	var threshold := ability_score(source) if source is String else int(source)
	return {"count": count, "threshold": threshold + int(spec.get("bonus", 0))}


func _uses_own_weapon(effect: Dictionary) -> bool:
	return character != null and effect.get("weapon") is bool and effect.get("weapon")
