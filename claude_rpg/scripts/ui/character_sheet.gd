class_name CharacterSheet
extends RefCounted
## Texte BBCode de la fiche d'un personnage (écran principal et écran de création).


static func bbcode(ch: Character) -> String:
	var gold := UITheme.GOLD.to_html(false)
	var dim := UITheme.TEXT_DIM.to_html(false)

	var t := "%s %s · %s\n" % [
		DB.species[ch.species_id]["name"], DB.classes[ch.class_id]["name"], DB.gender_name(ch.gender)]
	if DB.backgrounds.has(ch.background_id):
		t += "[color=%s]%s[/color] %s   " % [gold, Loc.ui("Passé"), DB.backgrounds[ch.background_id]["name"]]
	t += "[color=%s]%s[/color] %s\n" % [gold, Loc.ui("Taille"), DB.size_name(ch.size())]
	t += Loc.ui("%d ans — %s") % [ch.age_years(), DB.life_stage_name(ch.life_stage())] + "\n\n"
	t += "[color=%s]PV[/color] %d / %d    [color=%s]%s[/color] %d po\n" % [
		gold, ch.hp, ch.max_hp, gold, Loc.ui("Or"), ch.gold]
	t += "[color=%s]%s[/color] %d    [color=%s]XP[/color] %d\n\n" % [gold, Loc.ui("Niveau"), ch.level, gold, ch.xp]

	t += "[table=3]"
	for ability: Dictionary in DB.rules["abilities"]:
		var id: String = ability["id"]
		t += "[cell][color=%s]%s[/color] %d (%s)  [/cell]" % [
			gold, ability["short"], ch.abilities[id], signed(ch.ability_mod(id))]
	t += "[/table]\n\n"

	# Compétences : maîtrisées en clair, les autres grisées.
	t += "[color=%s]%s[/color]\n[table=2]" % [gold, Loc.ui("Compétences")]
	for skill: Dictionary in DB.rules["skills"]:
		var line := "%s %s" % [skill["name"], signed(ch.skill_mod(skill["id"]))]
		t += "[cell]%s  [/cell]" % (line if ch.is_proficient(skill["id"]) else "[color=%s]%s[/color]" % [dim, line])
	t += "[/table]\n\n"

	t += "[color=%s]%s[/color]\n" % [gold, Loc.ui("Inventaire")]
	if ch.inventory.is_empty():
		t += "[color=%s]—[/color]\n" % dim
	for item_id: String in ch.inventory:
		t += "%s ×%d\n" % [DB.items[item_id]["name"], ch.inventory[item_id]]
	return t


static func signed(value: int) -> String:
	return ("+%d" % value) if value >= 0 else str(value)
