class_name CombatEffects
extends RefCounted
## Effets de combat, communs aux actions des classes (actions.json) et des créatures (creatures.json).
## Les jets sont des réserves de d10 (voir Dice et docs/systeme_de_jeu.md).
##   {"type": "attack", "weapon": true | "<id d'arme>", "ability"?: "spell" | "str"…, "skill"?: "physique",
##    "damage"?: {"threshold"?: "weapon" | "spell" | attribut | N, "bonus"?: N, "dice"?: N, "skill"?},
##    "damage_type"?: "fire", "ranged"?: true}
##        Jet d'attaque ([rang] d10 contre l'attribut) contre l'Esquive naturelle de la cible (mêlée) ou
##        son Couvert (distance), puis dégâts : [rang + dice] d10 contre le seuil, un succès = un point.
##        Les effets qui suivent une attaque ne s'appliquent que si elle touche (jusqu'à l'attaque suivante).
##   {"type": "damage", "damage": {"dice": 3, "threshold": 6}, "damage_type": "force"}   dégâts sans jet d'attaque
##   {"type": "heal", "amount": {"dice": 2, "skill"?: "medicine", "threshold": "wis" | N}}   soins (un succès = 1 PV)
##   {"type": "status", "status": "poisoned", "stacks": 3}         ajoute des charges d'état
##   {"type": "cleanse", "status": "poisoned" | "negative"}        retire un état, ou tous les négatifs
##   {"type": "summon", "creature": "familiar"}                    invoque une créature dans son camp
##   {"type": "extra_action"}                                     une action de plus ce tour (Fougue)
##   {"type": "check", "skill": "stealth", "difficulty": 2}        test de compétence de l'acteur,
##   {"type": "check", "skill": "persuasion", "ability": "str", "vs_resist": "wis"}  ou en opposition
##        contre la résistance de la cible. Raté : les effets suivants sont ignorés.
##        "natural_skill": "survival" : contre une créature naturelle ("natural"), la meilleure des deux compétences.
## Champs communs facultatifs :
##   "resist": {"ability": "dex"}  la cible résiste (voir Character.resist_pool) : contre des dégâts,
##        chaque succès retire un point ; contre un autre effet, opposition avec la réserve
##        d'incantation de l'acteur (il faut plus de succès qu'elle, sinon l'effet et les suivants sont ignorés).
##   "scaling": {"table": "cantrip" | "sneak_attack", "class"?}  dés de dégâts en plus selon le niveau
##        (rules.json › dice_scaling).
##   "upcast": 1   dés de dégâts en plus par niveau d'emplacement au-delà du niveau du sort (Spellcasting).
##   "bonus_damage": [{"dice": 2, "threshold": 5, "damage_type": "fire"}]  dégâts d'autres types ajoutés
##        (lancés à part) ; une arme peut aussi en porter (Equipment).

## type -> champs obligatoires (utilisé par DataValidator)
const SCHEMA := {
	"attack": [],
	"damage": ["damage"],
	"heal": ["amount"],
	"status": ["status", "stacks"],
	"cleanse": ["status"],
	"summon": ["creature"],
	"extra_action": [],
	"check": ["skill"],
	"reveal_weaknesses": [],
}
## Cibles possibles d'une action (actions.json, actions des créatures).
const TARGETS := ["enemy", "all_enemies", "ally", "all_allies", "self", "none"]
## Cibles qui demandent un choix (au joueur, ou à l'IA).
const CHOSEN_TARGETS := ["enemy", "ally"]

## Effets qui ne visent personne : ils s'appliquent une seule fois, quelle que soit la cible.
const UNTARGETED := ["summon", "extra_action"]

const TARGET_PREFIX := {
	"all_enemies": "Tous les ennemis : ",
	"all_allies": "Tous les alliés : ",
	"self": "",
	"ally": "Un allié : ",
}


## Texte lisible d'une liste d'effets, ex. « Attaque avec votre arme (+1d6). Si elle touche : 1 Affaibli. »
static func describe_all(effects: Array, target := "enemy") -> String:
	var sentences := PackedStringArray()
	var after_attack := false
	var after_check := false
	for e: Dictionary in effects:
		var text := describe(e)
		if after_attack and e.get("type") not in ["attack", "check"] and e.get("type") not in UNTARGETED:
			var lead := Loc.ui("Si c'est réussi : %s") if after_check else Loc.ui("Si elle touche : %s")
			text = lead % text.substr(0, 1).to_lower() + text.substr(1)
		if e.get("type") in ["attack", "check"]:
			after_attack = true
			after_check = e.get("type") == "check"
		sentences.append(text)
	return Loc.ui(TARGET_PREFIX.get(target, "")) + ". ".join(sentences) + "."


static func describe(e: Dictionary) -> String:
	match e.get("type"):
		"attack":
			var text := ""
			if e.get("weapon") is bool and e.get("weapon"):
				text = Loc.ui("Attaque avec votre arme")
			elif e.get("weapon") is String:
				text = Loc.ui("Attaque (%s)") % Equipment.name_of(e["weapon"])
			elif e.get("ability") == "spell":
				text = Loc.ui("Attaque de sort : %s") % _damage_text(e)
			else:
				text = Loc.ui("Attaque : %s") % _damage_text(e)
			if e.has("scaling") and e["scaling"].get("table") == "sneak_attack":
				text += Loc.ui(" (+1 dé de dégâts par palier)")
			return text
		"damage":
			return Loc.ui("Inflige %s") % _damage_text(e) + _resist_text(e)
		"heal":
			var spec: Variant = e["amount"]
			return Loc.ui("Soigne (%s)") % (_pool_text(spec) if spec is Dictionary else str(spec)) + _resist_text(e)
		"status":
			return Loc.ui("%d %s") % [int(e["stacks"]), StatusEffects.name_of(e["status"])] + _resist_text(e)
		"cleanse":
			if e["status"] == "negative":
				return Loc.ui("Retire les états négatifs")
			return Loc.ui("Retire %s") % StatusEffects.name_of(e["status"])
		"summon":
			return Loc.ui("Invoque : %s") % Creatures.name_of(e["creature"])
		"extra_action":
			return Loc.ui("Une action de plus ce tour")
		"check":
			var skill := Skills.name_of(e["skill"]) + (" (%s)" % Abilities.short_of(e["ability"]) if e.has("ability") else "")
			if e.has("vs_resist"):
				return Loc.ui("Test de %s contre la résistance (%s) de la cible") % [skill, Abilities.name_of(e["vs_resist"])]
			return Loc.ui("Test de %s (difficulté %d)") % [skill, Dice.difficulty_of(e)]
	return str(e)


## Ex. « (la cible résiste avec la DEX) ».
static func _resist_text(e: Dictionary) -> String:
	if not e.has("resist"):
		return ""
	return Loc.ui(" (la cible résiste : %s)") % Abilities.short_of(e["resist"].get("ability", "con"))


## Ex. « 3 dés, seuil 6 », « Médecine, seuil SAG ».
static func _pool_text(spec: Dictionary) -> String:
	var parts := PackedStringArray()
	if spec.has("skill"):
		parts.append(Skills.name_of(spec["skill"]) + (" + %d" % int(spec["dice"]) if int(spec.get("dice", 0)) > 0 else ""))
	elif spec.has("dice"):
		parts.append(Loc.ui("%d dé(s)") % int(spec["dice"]))
	var threshold: Variant = spec.get("threshold", "weapon")
	if threshold is String:
		var name := Loc.ui("attaque") if threshold == "weapon" else (Loc.ui("sort") if threshold == "spell" else Abilities.short_of(threshold))
		parts.append(Loc.ui("seuil %s") % name + (" %+d" % int(spec["bonus"]) if int(spec.get("bonus", 0)) != 0 else ""))
	else:
		parts.append(Loc.ui("seuil %d") % (int(threshold) + int(spec.get("bonus", 0))))
	return ", ".join(parts)


static func _damage_text(e: Dictionary) -> String:
	var type: String = e.get("damage_type", "")
	var spec: Variant = e.get("damage", {})
	var text := _pool_text(spec if spec is Dictionary else {})
	if type != "":
		text = DamageTypes.name_of(type).to_lower() + " (" + text + ")"
	for part: Dictionary in e.get("bonus_damage", []):
		text += " + %s (%s)" % [DamageTypes.name_of(part["damage_type"]).to_lower(), _pool_text(part)]
	return text
