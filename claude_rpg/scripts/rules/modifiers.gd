class_name Modifiers
extends RefCounted
## Modificateurs accordés par une source (don, espèce, équipement…) et appliqués au personnage.
## Une liste de modificateurs s'écrit en JSON, ex. :
##   [{"type": "ability", "id": "str", "amount": 1}, {"type": "resistance", "damage_type": "fire"}]
## Pour ajouter un nouveau type : le déclarer dans SCHEMA, puis l'utiliser dans Character.

## type -> champs obligatoires (utilisé par DataValidator)
const SCHEMA := {
	"ability": ["id", "amount"],  # bonus à un attribut
	"skill_rank": ["id", "amount"],  # rangs en plus dans une compétence
	"hp_per_level": ["amount"],  # PV max en plus, par niveau
	"max_hp": ["amount"],  # PV max en plus (Robuste)
	"initiative": ["amount"],  # points d'initiative en plus
	"armor": ["amount"],  # points d'Armure en plus
	"natural_dodge": ["amount"],  # Esquive naturelle en plus
	"weapon_damage": ["amount"],  # dés de dégâts d'arme en plus
	"weapon_attack": ["amount"],  # dés en plus aux attaques avec une arme
	"resist_dice": ["amount"],  # dés en plus pour résister
	"resistance": ["damage_type"],
	"immunity": ["damage_type"],
	"vulnerability": ["damage_type"],
	"status_immunity": ["status"],
	"resist_proficiency": ["id"],  # un dé de plus pour résister avec un attribut
	"extra_attack": ["amount"],  # attaques en plus pour l'action Attaque
	"uncanny_dodge": [],  # une fois par round, dégâts d'une attaque divisés par deux
	"evasion": [],  # résister aux dégâts avec la DEX : chaque succès retire deux points
	"reliable_talent": [],  # test d'une compétence entraînée : au moins un succès
	"relentless_endurance": [],
	"critical_range": ["amount"],  # succès comptés en plus pour le critique (Critique amélioré : 1)
	"initiative_advantage": [],  # deux d10 à l'initiative, on garde le meilleur (Champion)
	"skill_advantage": ["id"],  # un dé de plus aux tests d'une compétence
	"spellcasting_ability": ["id"],  # attribut d'incantation hors classe (Initié à la magie)
	"savage_attacker": [],  # une fois par tour, un dé de dégâts de plus sur une attaque d'arme réussie (Frappe brutale)
	"daily_ability_die": ["id", "resource"],  # test raté sous cet attribut : un dé de plus, une fois par jour (ressource)
	"lucky": [],  # un échec critique devient un simple échec, une fois par jour (ressource lucky)
	"check_tag_die": ["tag"],  # un dé de plus aux tests marqués de ce tag ("tags" du test : swim, orientation, forage)
	"climate_adapted": ["id"],  # pas de jet contre ce climat (hot, cold)
	"feat_flag": ["id"],  # effet propre à un système pas encore en jeu (mini-jeux, pièges, déchiffrage…)
	"ignore_resistance": ["damage_type"],  # ignore la résistance des cibles à ce type (Adepte élémentaire)
	"ranged_attack": ["amount"],  # dés en plus aux attaques à distance (Archerie)
	"armored": ["amount"],  # points d'Armure en plus avec une vraie armure (Défense)
	"great_weapon_fighting": [],  # arme à deux mains : on relance une fois les dés de dégâts ratés
	"dueling": ["amount"],  # dés de dégâts en plus avec une arme de mêlée à une main, l'autre sans arme (À une main)
	"unarmed_fighting": ["amount"],  # dés de dégâts en plus à mains nues (À mains nues)
	"improvised_damage": ["amount"],  # dés de dégâts en plus avec une arme improvisée (Bagarreur de taverne)
	"two_weapon_fighting": [],  # une Attaque peut frapper des deux mains (À deux armes)
	"critical_damage_dice": ["amount"],  # dés de dégâts en plus sur un critique (Attaques précises du Roublard)
	"encumbrance_reduction": ["amount"],  # encombrement réduit (Entraînement aux armures lourdes)
	"potent_cantrip": [],  # tour de magie raté : moitié des dégâts (Évocateur)
	"empowered_evocation": [],  # un dé de dégâts de plus aux sorts d'évocation
	"fast_hands": [],  # utiliser un objet ne coûte pas l'action, une fois par tour (Voleur)
	"survivor": [],
	"cunning_action": [],  # Se cacher ne coûte pas d'action, une fois par tour (Ruse du Roublard)  # début de tour à moitié de PV ou moins : récupère 5 + CON (Champion)  # tombe à 1 PV au lieu de 0 (ressource relentless_endurance, repos long)
}

## Types de modificateurs qui deviennent des défenses (type -> sorte de Defenses).
const DEFENSE_TYPES := {
	"resistance": Defenses.RESISTANCE,
	"immunity": Defenses.IMMUNITY,
	"vulnerability": Defenses.VULNERABILITY,
	"status_immunity": Defenses.STATUS_IMMUNITY,
}


## Somme des montants d'un type (et d'une cible, pour "ability").
static func sum(mods: Array, type: String, id := "") -> int:
	var total := 0
	for m: Dictionary in mods:
		if m.get("type") == type and (id == "" or m.get("id") == id):
			total += int(m.get("amount", 0))
	return total


static func grants(mods: Array, type: String, id: String) -> bool:
	return mods.any(func(m): return m.get("type") == type and m.get("id") == id)


static func defenses(mods: Array) -> Defenses:
	var d := Defenses.new()
	for m: Dictionary in mods:
		var kind: String = DEFENSE_TYPES.get(m.get("type"), "")
		if kind != "":
			d.add(kind, m.get("status", m.get("damage_type", "")))
	return d


## Texte lisible d'un modificateur, ex. « +1 FOR », « Maîtrise : Athlétisme », « Résistance : Feu ».
static func describe(m: Dictionary) -> String:
	var amount := int(m.get("amount", 0))
	var signed := ("+%d" % amount) if amount >= 0 else str(amount)
	match m.get("type"):
		"ability":
			return "%s %s" % [signed, Abilities.short_of(m["id"])]
		"skill_rank":
			return Loc.ui("%s rang en %s") % [signed, Skills.name_of(m["id"])]
		"hp_per_level":
			return Loc.ui("%s PV par niveau") % signed
		"max_hp":
			return Loc.ui("%s PV max") % signed
		"initiative":
			return Loc.ui("%s à l'initiative") % signed
		"armor":
			return Loc.ui("%s Armure") % signed
		"natural_dodge":
			return Loc.ui("%s Esquive naturelle") % signed
		"weapon_damage":
			return Loc.ui("%s dé(s) de dégâts d'arme") % signed
		"weapon_attack":
			return Loc.ui("%s dé(s) aux attaques d'arme") % signed
		"resist_dice":
			return Loc.ui("%s dé(s) pour résister") % signed
		"resistance":
			return Loc.ui("Résistance : %s") % DamageTypes.name_of(m["damage_type"])
		"immunity":
			return Loc.ui("Immunité : %s") % DamageTypes.name_of(m["damage_type"])
		"vulnerability":
			return Loc.ui("Vulnérabilité : %s") % DamageTypes.name_of(m["damage_type"])
		"status_immunity":
			return Loc.ui("Immunité à l'état : %s") % StatusEffects.name_of(m["status"])
		"resist_proficiency":
			return Loc.ui("+1 dé pour résister (%s)") % Abilities.name_of(m["id"])
		"extra_attack":
			return Loc.ui("%s attaque(s) par action Attaque") % signed
		"uncanny_dodge":
			return Loc.ui("Esquive instinctive")
		"evasion":
			return Loc.ui("Dérobade")
		"reliable_talent":
			return Loc.ui("Talent fiable")
		"relentless_endurance":
			return Loc.ui("Endurance implacable")
		"critical_range":
			return Loc.ui("Critique : %s succès compté(s) en plus") % signed
		"initiative_advantage":
			return Loc.ui("Initiative : deux d10, le meilleur")
		"skill_advantage":
			return Loc.ui("+1 dé en %s") % Skills.name_of(m["id"])
		"spellcasting_ability":
			return Loc.ui("Incantation : %s") % Abilities.name_of(m["id"])
		"savage_attacker":
			return Loc.ui("Frappe brutale")
		"daily_ability_die":
			return Loc.ui("1/jour : +1 dé à un test raté sous %s") % Abilities.name_of(m["id"])
		"lucky":
			return Loc.ui("1/jour : un échec critique devient un échec")
		"check_tag_die":
			return Loc.ui("+1 dé (%s)") % Loc.ui(m["tag"])
		"climate_adapted":
			return Loc.ui("Adapté au climat : %s") % Loc.ui({"hot": "chaud", "cold": "froid"}.get(m["id"], m["id"]))
		"feat_flag":
			return ""
		"ignore_resistance":
			return Loc.ui("Ignore la résistance : %s") % DamageTypes.name_of(m["damage_type"])
		"ranged_attack":
			return Loc.ui("%s dé(s) aux attaques à distance") % signed
		"armored":
			return Loc.ui("%s Armure en armure") % signed
		"great_weapon_fighting":
			return Loc.ui("Armes à deux mains : relance des dés de dégâts ratés")
		"dueling":
			return Loc.ui("%s dé(s) de dégâts à une main") % signed
		"unarmed_fighting":
			return Loc.ui("%s dé(s) de dégâts à mains nues") % signed
		"improvised_damage":
			return Loc.ui("%s dé(s) de dégâts avec une arme improvisée") % signed
		"two_weapon_fighting":
			return Loc.ui("Deux armes : attaque des deux mains")
		"critical_damage_dice":
			return Loc.ui("%s dé(s) de dégâts sur un critique") % signed

		"encumbrance_reduction":
			return Loc.ui("Encombrement −%d") % amount
		"potent_cantrip":
			return Loc.ui("Tour de magie puissant")
		"empowered_evocation":
			return Loc.ui("Évocation renforcée")
		"fast_hands":
			return Loc.ui("Mains lestes")
		"survivor":
			return Loc.ui("Survivant")
		"cunning_action":
			return Loc.ui("Ruse : se cacher sans dépenser d'action")
	return str(m)


static func describe_all(mods: Array) -> String:
	return ", ".join(PackedStringArray(mods.map(func(m): return describe(m))))
