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
	t += "[color=%s]PV[/color] %d / %d    [color=%s]CA[/color] %d    [color=%s]%s[/color] %d po\n" % [
		gold, ch.hp, ch.max_hp, gold, ch.armor_class(), gold, Loc.ui("Or"), ch.gold]
	t += "[color=%s]%s[/color] %d    [color=%s]XP[/color] %d\n" % [gold, Loc.ui("Niveau"), ch.level, gold, ch.xp]
	var slots := PackedStringArray()
	for resource_id: String in ch.max_resources():
		if Spellcasting.is_slot(resource_id):
			slots.append(Loc.ui("niv. %d : %d/%d") % [Spellcasting.slot_level(resource_id), int(ch.resources.get(resource_id, 0)),
				ch.max_resource(resource_id)])
		else:
			t += "[color=%s]%s[/color] %d / %d\n" % [gold, Actions.resource_name(resource_id),
				int(ch.resources.get(resource_id, 0)), ch.max_resource(resource_id)]
	if not slots.is_empty():
		t += "[color=%s]%s[/color] %s\n" % [gold, Loc.ui("Emplacements de sort"), " · ".join(slots)]
	var saves := PackedStringArray()
	for id in Abilities.ids():
		if ch.is_proficient_save(id):
			saves.append("%s %s" % [Abilities.short_of(id), signed(ch.save_mod(id))])
	if not saves.is_empty():
		t += "[color=%s]%s[/color] %s\n" % [gold, Loc.ui("Sauvegardes maîtrisées"), ", ".join(saves)]
	t += "\n"

	t += "[table=3]"
	for id in Abilities.ids():
		t += "[cell][color=%s]%s[/color] %d (%s)  [/cell]" % [
			gold, Abilities.short_of(id), ch.ability_score(id), signed(ch.ability_mod(id))]
	t += "[/table]\n\n"

	# Équipement, dons, défenses.
	t += "[color=%s]%s[/color]\n" % [gold, Loc.ui("Équipement")]
	for slot in Equipment.SLOTS:
		if ch.equipment.has(slot):
			t += Equipment.describe(ch.equipment[slot]) + "\n"
	var features := ch.features()
	if not features.is_empty():
		t += "[color=%s]%s[/color] %s\n" % [gold, Loc.ui("Aptitudes"),
			", ".join(PackedStringArray(features.map(func(f): return f["name"])))]
	if not ch.feats.is_empty():
		t += "[color=%s]%s[/color] %s\n" % [gold, Loc.ui("Dons"),
			", ".join(PackedStringArray(ch.feats.map(func(id): return Feats.name_of(id))))]
	var defenses := ch.all_defenses()
	if not defenses.is_empty():
		t += defenses.describe() + "\n"
	t += "\n"

	# Compétences : maîtrisées en clair, les autres grisées.
	t += "[color=%s]%s[/color]\n[table=2]" % [gold, Loc.ui("Compétences")]
	for id in Skills.ids():
		var line := "%s %s" % [Skills.name_of(id), signed(ch.skill_mod(id))]
		t += "[cell]%s  [/cell]" % (line if ch.is_proficient(id) else "[color=%s]%s[/color]" % [dim, line])
	t += "[/table]\n\n"

	t += "[color=%s]%s[/color]\n" % [gold, Loc.ui("Inventaire")]
	if ch.inventory.is_empty():
		t += "[color=%s]—[/color]\n" % dim
	for item_id: String in ch.inventory:
		t += "%s ×%d\n" % [Items.bbcode_name(item_id), ch.inventory[item_id]]
	return t


## Lignes « Compagnons » (nom, classe, PV), vide s'il n'y en a pas.
static func companions_bbcode(life: LifeState) -> String:
	if life.companions.is_empty():
		return ""
	var t := "\n[color=%s]%s[/color]\n" % [UITheme.GOLD.to_html(false), Loc.ui("Compagnons")]
	for c in life.companions:
		t += "%s (%s %d) — %d / %d PV, CA %d\n" % [
			c.name, DB.classes[c.class_id]["name"], c.level, c.hp, c.max_hp, c.armor_class()]
	return t


static func signed(value: int) -> String:
	return ("+%d" % value) if value >= 0 else str(value)
