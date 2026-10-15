class_name CharacterSheet
extends RefCounted
## Texte BBCode de la fiche d'un personnage (écran principal et écran de création).


static func bbcode(ch: Character) -> String:
	var gold := UITheme.GOLD.to_html(false)
	var dim := UITheme.TEXT_DIM.to_html(false)

	var species_name: String = DB.species[ch.species_id]["name"]
	for key: String in ch.choices:
		if key.begins_with("species/") and DB.species[ch.species_id].get("choices", []).any(func(s): return s.get("type") == "option"):
			species_name += " (%s)" % ch.choice_label(key)
	var class_name_text: String = ch.classes_text()
	for key: String in ch.choices:
		if key.ends_with("/subclass"):
			class_name_text += " (%s)" % ch.choice_label(key)
	var t := "%s %s · %s\n" % [species_name, class_name_text, DB.gender_name(ch.gender)]
	if DB.backgrounds.has(ch.background_id):
		t += "[color=%s]%s[/color] %s   " % [gold, Loc.ui("Passé"), DB.backgrounds[ch.background_id]["name"]]
	t += "[color=%s]%s[/color] %s\n" % [gold, Loc.ui("Taille"), DB.size_name(ch.size())]
	t += Loc.ui("%d ans — %s") % [ch.age_years(), DB.life_stage_name(ch.life_stage())] + "\n\n"
	t += "[color=%s]PV[/color] %d / %d    [color=%s]%s[/color] %d    [color=%s]%s[/color] %d    [color=%s]%s[/color] %d po\n" % [
		gold, ch.hp, ch.max_hp, gold, Loc.ui("Esquive naturelle"), ch.natural_dodge(), gold, Loc.ui("Armure"), ch.armor(),
		gold, Loc.ui("Or"), ch.gold]
	t += "[color=%s]%s[/color] %d (+1d10)\n" % [gold, Loc.ui("Initiative"), ch.initiative_base()]
	t += "[color=%s]%s[/color] %d    [color=%s]XP[/color] %d\n" % [gold, Loc.ui("Niveau"), ch.level, gold, ch.xp]
	for resource_id: String in ch.max_resources():
		if Spellcasting.is_slot(resource_id):
			t += "[color=%s]%s[/color] %d / %d (%s)\n" % [gold, Loc.ui("Mana"),
				int(ch.resources.get(resource_id, 0)), ch.max_resource(resource_id),
				Loc.ui("sorts jusqu'au niveau %d") % ch.max_spell_level()]
		else:
			t += "[color=%s]%s[/color] %d / %d\n" % [gold, Actions.resource_name(resource_id),
				int(ch.resources.get(resource_id, 0)), ch.max_resource(resource_id)]
	var saves := PackedStringArray()
	for id in Abilities.ids():
		var pool := ch.resist_pool(id)
		var text := "%s %s" % [Abilities.short_of(id), Dice.pool_text(int(pool["count"]), int(pool["threshold"]))]
		saves.append(text if ch.is_proficient_save(id) else "[color=%s]%s[/color]" % [dim, text])
	t += "[color=%s]%s[/color] %s\n" % [gold, Loc.ui("Résister"), " · ".join(saves)]
	t += "[color=%s]%s[/color] %s\n" % [gold, Loc.ui("Langues"),
		", ".join(PackedStringArray(ch.known_languages().map(func(l): return Skills.language_name(l))))]
	t += "\n"

	t += "[table=3]"
	for id in Abilities.ids():
		t += "[cell][color=%s]%s[/color] %d  [/cell]" % [gold, Abilities.short_of(id), ch.ability_score(id)]
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
	if Game.life != null and Game.life.character == ch and not Game.life.professions().is_empty():
		t += "[color=%s]%s[/color] %s\n" % [gold, Loc.ui("Métier"), ", ".join(PackedStringArray(Game.life.professions()))]
	if ch.is_encumbered():
		t += "[color=%s]%s[/color]\n" % [UITheme.BAD.to_html(false),
			Loc.ui("Encombrement %d : Dextérité −%d") % [ch.encumbrance(), ch.encumbrance()]]
	t += "\n"

	# Compétences par catégorie : réserve (rang d10 ≤ meilleur attribut) ; entraînées en clair, les autres grisées.
	t += "[color=%s]%s[/color]\n" % [gold, Loc.ui("Compétences (rang d10 ≤ attribut)")]
	for category: String in Skills.CATEGORY_NAMES:
		var ids := Skills.ids_in(category)
		if ids.is_empty():
			continue
		t += "[color=%s][i]%s[/i][/color]\n[table=2]" % [dim, Loc.ui(Skills.CATEGORY_NAMES[category])]
		for id in ids:
			var pool := ch.skill_pool(id)
			var line := "%s %s" % [Skills.name_of(id), Dice.pool_text(int(pool["count"]), int(pool["threshold"]))]
			t += "[cell]%s  [/cell]" % (line if ch.is_trained(id) else "[color=%s]%s[/color]" % [dim, line])
		t += "[/table]\n"
	t += "\n"

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
		t += Loc.ui("%s (%s %d) — %d / %d PV, Esquive %d, Armure %d\n") % [
			c.name, c.classes_text(), c.level, c.hp, c.max_hp, c.natural_dodge(), c.armor()]
	return t


static func signed(value: int) -> String:
	return ("+%d" % value) if value >= 0 else str(value)
