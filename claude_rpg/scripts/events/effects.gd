class_name Effects
extends RefCounted
## Application des effets décrits dans les JSON (résultats des choix).
## Chaque effet produit éventuellement une ligne de résumé affichée au joueur.
## Référence du format : docs/modele_donnees.md

## type -> champs obligatoires (utilisé par DataValidator)
const SCHEMA := {
	"set_flag": ["id"],
	"clear_flag": ["id"],
	"set_world_flag": ["id"],
	"clear_world_flag": ["id"],
	"unlock": ["id"],
	"gold": ["amount"],
	"hp": ["amount"],
	"heal_full": [],
	"xp": ["amount"],
	"ability": ["id", "amount"],
	"add_item": ["id"],
	"remove_item": ["id"],
	"goto": ["event"],
	"pass_time": [],
	"die": [],
}


## Retourne {"lines": Array[String], "goto": String}.
static func apply_all(effects: Array, life: LifeState, meta: MetaState) -> Dictionary:
	var lines: Array[String] = []
	var goto := ""
	var ch := life.character
	for e: Dictionary in effects:
		if life.dead:
			break
		match String(e.get("type", "")):
			"set_flag":
				life.flags[e["id"]] = true
			"clear_flag":
				life.flags.erase(e["id"])
			"set_world_flag":
				meta.set_world_flag(e["id"], true)
			"clear_world_flag":
				meta.set_world_flag(e["id"], false)
			"unlock":
				if meta.unlock(e["id"]):
					lines.append(Loc.ui("Débloqué pour les prochaines vies : %s !") % meta.unlock_name(e["id"]))
			"gold":
				var before := ch.gold
				ch.gold = maxi(0, ch.gold + int(e["amount"]))
				if ch.gold != before:
					lines.append(Loc.ui("%s po") % _signed(ch.gold - before))
			"hp":
				var before := ch.hp
				ch.hp = clampi(ch.hp + int(e["amount"]), 0, ch.max_hp)
				if ch.hp != before:
					lines.append(Loc.ui("%s PV") % _signed(ch.hp - before))
				if ch.hp <= 0:
					life.die(e.get("cause", Loc.ui("Mort de ses blessures")))
			"heal_full":
				var healed := ch.max_hp - ch.hp
				ch.hp = ch.max_hp
				if healed > 0:
					lines.append(Loc.ui("%s PV") % _signed(healed))
			"xp":
				lines.append(Loc.ui("%s XP") % _signed(int(e["amount"])))
				for new_level in ch.add_xp(int(e["amount"])):
					lines.append(Loc.ui("Niveau %d atteint !") % new_level)
			"ability":
				var id: String = e["id"]
				lines.append("%s %s" % [_signed(int(e["amount"])), DB.abilities[id]["short"]])
				life.change_ability(id, int(e["amount"]), e.get("cause", Loc.ui("Vidé de toute force")))
			"add_item":
				var count := int(e.get("count", 1))
				ch.add_item(e["id"], count)
				lines.append(Loc.ui("Obtenu : %s ×%d") % [DB.items[e["id"]]["name"], count])
			"remove_item":
				var removed := ch.remove_item(e["id"], int(e.get("count", 1)))
				if removed > 0:
					lines.append(Loc.ui("Perdu : %s ×%d") % [DB.items[e["id"]]["name"], removed])
			"goto":
				goto = e["event"]
			"pass_time":
				life.advance_time(int(e.get("slots", 0)) + int(e.get("days", 0)) * DB.slots_per_day())
				lines.append(Loc.ui("Le temps passe…"))
			"die":
				life.die(e.get("cause", Loc.ui("Mort mystérieuse")))
			_:
				push_warning("Effet inconnu : %s" % e)
	return {"lines": lines, "goto": goto}


static func _signed(value: int) -> String:
	return ("+%d" % value) if value > 0 else str(value)
