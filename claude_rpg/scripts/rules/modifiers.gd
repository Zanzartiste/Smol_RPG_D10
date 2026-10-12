class_name Modifiers
extends RefCounted
## Modificateurs accordés par une source (don, espèce, équipement…) et appliqués au personnage.
## Une liste de modificateurs s'écrit en JSON, ex. :
##   [{"type": "ability", "id": "str", "amount": 1}, {"type": "resistance", "damage_type": "fire"}]
## Pour ajouter un nouveau type : le déclarer dans SCHEMA, puis l'utiliser dans Character.

## type -> champs obligatoires (utilisé par DataValidator)
const SCHEMA := {
	"ability": ["id", "amount"],  # bonus à un attribut
	"skill_proficiency": ["id"],  # maîtrise d'une compétence
	"hp_per_level": ["amount"],  # PV max en plus, par niveau
	"initiative": ["amount"],  # bonus d'initiative
	"ac": ["amount"],  # bonus de CA
	"weapon_damage": ["amount"],  # bonus aux dégâts des attaques d'arme
	"resistance": ["damage_type"],
	"immunity": ["damage_type"],
	"vulnerability": ["damage_type"],
	"status_immunity": ["status"],
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
		"skill_proficiency":
			return Loc.ui("Maîtrise : %s") % Skills.name_of(m["id"])
		"hp_per_level":
			return Loc.ui("%s PV par niveau") % signed
		"initiative":
			return Loc.ui("%s à l'initiative") % signed
		"ac":
			return Loc.ui("%s CA") % signed
		"weapon_damage":
			return Loc.ui("%s aux dégâts d'arme") % signed
		"resistance":
			return Loc.ui("Résistance : %s") % DamageTypes.name_of(m["damage_type"])
		"immunity":
			return Loc.ui("Immunité : %s") % DamageTypes.name_of(m["damage_type"])
		"vulnerability":
			return Loc.ui("Vulnérabilité : %s") % DamageTypes.name_of(m["damage_type"])
		"status_immunity":
			return Loc.ui("Immunité à l'état : %s") % StatusEffects.name_of(m["status"])
	return str(m)


static func describe_all(mods: Array) -> String:
	return ", ".join(PackedStringArray(mods.map(func(m): return describe(m))))
