class_name CombatEffects
extends RefCounted
## Effets de combat, communs aux cartes, aux actions des créatures et des compagnons.
##   {"type": "attack", "weapon": true | "<id d'arme>", "ability"?: "spell" | "str"…, "to_hit"?: N,
##    "damage"?: "1d10", "damage_type"?: "fire", "extra_damage"?: "1d6", "add_mod"?: bool}
##        Jet d'attaque contre la CA puis dégâts. Les effets qui suivent une attaque ne s'appliquent
##        que si elle touche (jusqu'à l'attaque suivante).
##   {"type": "damage", "damage": "3d4", "damage_type": "force"}   dégâts automatiques
##   {"type": "heal", "amount": "1d10+level"}                     soins (« level » = niveau)
##   {"type": "status", "status": "poisoned", "stacks": 3}         ajoute des charges d'état
##   {"type": "cleanse", "status": "poisoned" | "negative"}        retire un état, ou tous les négatifs
##   {"type": "draw", "count": 2}                                  le héros pioche
##   {"type": "summon", "creature": "familiar"}                    invoque une créature dans son camp

## type -> champs obligatoires (utilisé par DataValidator)
const SCHEMA := {
	"attack": [],
	"damage": ["damage"],
	"heal": ["amount"],
	"status": ["status", "stacks"],
	"cleanse": ["status"],
	"draw": ["count"],
	"summon": ["creature"],
}
## Effets qui ne visent personne : ils s'appliquent une seule fois, quelle que soit la cible.
const UNTARGETED := ["draw", "summon"]

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
	for e: Dictionary in effects:
		var text := describe(e)
		if after_attack and e.get("type") != "attack" and e.get("type") not in UNTARGETED:
			text = Loc.ui("Si elle touche : %s") % text.substr(0, 1).to_lower() + text.substr(1)
		if e.get("type") == "attack":
			after_attack = true
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
			if e.has("extra_damage"):
				text += Loc.ui(" (+%s dégâts)") % e["extra_damage"]
			return text
		"damage":
			return Loc.ui("Inflige %s") % _damage_text(e)
		"heal":
			return Loc.ui("Soigne %s PV") % String(e["amount"]).replace("level", Loc.ui("niveau"))
		"status":
			return Loc.ui("%d %s") % [int(e["stacks"]), StatusEffects.name_of(e["status"])]
		"cleanse":
			if e["status"] == "negative":
				return Loc.ui("Retire les états négatifs")
			return Loc.ui("Retire %s") % StatusEffects.name_of(e["status"])
		"draw":
			return Loc.ui("Piochez %d carte(s)") % int(e["count"])
		"summon":
			return Loc.ui("Invoque : %s") % Creatures.name_of(e["creature"])
	return str(e)


static func _damage_text(e: Dictionary) -> String:
	var type: String = e.get("damage_type", "")
	var text: String = e.get("damage", "?")
	if type != "":
		text += " " + DamageTypes.name_of(type).to_lower()
	return text
