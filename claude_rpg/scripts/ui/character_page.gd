class_name CharacterPage
extends VBoxContainer
## Fiche de personnage en contrôles (libellés avec le détail au survol), partagée par le tiroir latéral et
## l'écran de création : identité, PV et initiative, Esquive naturelle et Armure, attributs, compétences
## repliables, aptitudes et dons. Options : portrait et barre d'XP (tiroir), passé et équipement (création).

signal skills_toggled(open: bool)

var with_portrait := true
var with_xp := true
var with_gear := false  # passé et équipement (écran de création)
var skills_open := true
var _character: Character


func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 6)


func show_character(ch: Character) -> void:
	_character = ch
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_build_header(ch)
	if with_xp:
		_add_xp_bar(ch)
	add_child(HSeparator.new())
	_build_defenses(ch)
	add_child(HSeparator.new())
	_build_abilities(ch)
	if with_gear:
		add_child(HSeparator.new())
		_build_gear(ch)
	add_child(HSeparator.new())
	_build_skills(ch)
	_build_features(ch)


func _build_header(ch: Character) -> void:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	if with_portrait:
		var portrait := TextureRect.new()
		portrait.texture = ArtProvider.portrait(ch)
		portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		portrait.custom_minimum_size = Vector2(88, 88)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		header.add_child(portrait)
	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_child(identity)
	if with_portrait:
		identity.add_child(make_label(ch.name, "", "TitleLabel"))
	var species_name: String = DB.species[ch.species_id]["name"]
	if DB.species[ch.species_id].get("choices", []).any(func(s): return s.get("type") == "option"):
		for key: String in ch.choices:
			if key.begins_with("species/"):
				species_name += " (%s)" % ch.choice_label(key)
	identity.add_child(make_label("%s %s" % [species_name, DB.gender_name(ch.gender)], tr("Taille : %s · %d ans (%s)") % [
		DB.size_name(ch.size()), ch.age_years(), DB.life_stage_name(ch.life_stage())]))
	var classes := PackedStringArray()
	for cls: String in ch.class_levels:
		classes.append(tr("%s niv. %d") % [DB.classes[cls]["name"], int(ch.class_levels[cls])])
	identity.add_child(make_label(", ".join(classes), subclass_text(ch)))
	add_child(header)


func _build_defenses(ch: Character) -> void:
	var dex := ch.ability_score("dex")
	var initiative := tr("Dextérité %d + Intelligence %d") % [dex, ch.ability_score("int")]
	if ch.has_modifier("initiative_rank"):
		initiative += tr(" + Physique %d (Vigilant)") % ch.skill_rank("physique")
	if ch.roll_penalty("dex") > 0:
		initiative += tr(" − %d (encombrement)") % ch.roll_penalty("dex")
	_add_pair(make_label(tr("PV : %d / %d") % [ch.hp, ch.max_hp], tr("(taille %d + 2) × Constitution %d + 7%s") % [
		ch.size(), ch.ability_score("con"), _extra_hp_text(ch)]),
		make_label(tr("Initiative : %d") % ch.initiative_base(), initiative + tr("\n+ 1d10 au début du combat.")))
	_add_pair(make_label(tr("Esquive naturelle : %d") % ch.natural_dodge(), tr("Dextérité %d ÷ 3 = %d (au moins 1)%s.\nC'est la difficulté des attaques de mêlée contre %s.") % [
		dex, maxi(1, floori(dex / 3.0)), _signed_extra(Modifiers.sum(ch.modifiers(), "natural_dodge")), ch.name]),
		make_label(tr("Armure : %d") % ch.armor(), _parts_text(ch.armor_parts(), tr("Aucune armure.")) +
			tr("\nBaisse d'autant le seuil des dégâts subis (sans passer sous 1).")))
	if ch.is_encumbered():
		add_child(make_label(tr("Encombré : −%d dé(s) aux jets de FOR et DEX") % ch.encumbrance_penalty(), "", "", UITheme.BAD))


func _build_abilities(ch: Character) -> void:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 28)
	for ability_id: String in Abilities.ids():
		var resist := ch.resist_pool(ability_id)
		var tip := "%s\n%s" % [Abilities.description_of(ability_id), tr("Résister : %s%s") % [
			Dice.pool_text(int(resist["count"]), int(resist["threshold"])), tr(" (maîtrisée)") if ch.is_proficient_save(ability_id) else ""]]
		grid.add_child(make_label("%s %d" % [Abilities.short_of(ability_id), ch.ability_score(ability_id)], tip))
	add_child(grid)


## Passé, langues et équipement (création : on voit ce avec quoi on part).
func _build_gear(ch: Character) -> void:
	if ch.background_id != "":
		var background: Dictionary = DB.backgrounds[ch.background_id]
		add_child(make_label(tr("Passé : %s") % background["name"], background.get("description", "")))
	add_child(make_label(tr("Langues : %s") % ", ".join(PackedStringArray(ch.known_languages().map(
		func(l): return Skills.language_name(l)))), ""))
	for slot in Equipment.SLOTS:
		var item_id: String = ch.equipment.get(slot, "")
		if item_id == "":
			continue
		var label := make_label("%s : %s" % [Equipment.slot_name(slot), Items.name_of(item_id)],
			Items.summary(item_id) + "\n" + Items.description_of(item_id))
		label.add_theme_color_override("font_color", Items.rarity_color(item_id))
		add_child(label)


func _build_skills(ch: Character) -> void:
	var fold := Button.new()
	fold.flat = true
	fold.alignment = HORIZONTAL_ALIGNMENT_LEFT
	fold.text = ("▾ " if skills_open else "▸ ") + tr("Compétences")
	fold.add_theme_color_override("font_color", UITheme.GOLD)
	fold.pressed.connect(func():
		skills_open = not skills_open
		skills_toggled.emit(skills_open)
		show_character.call_deferred(_character))
	add_child(fold)
	if not skills_open:
		return
	for category: String in Skills.CATEGORY_NAMES:
		var ids := Skills.ids_in(category)
		if ids.is_empty():
			continue
		add_child(make_label(tr(Skills.CATEGORY_NAMES[category]), "", "", UITheme.TEXT_DIM))
		var skills := GridContainer.new()
		skills.columns = 2
		skills.add_theme_constant_override("h_separation", 24)
		for skill_id in ids:
			var label := make_label("%s %d" % [Skills.name_of(skill_id), ch.skill_rank(skill_id)], skill_tip(ch, skill_id))
			if not ch.is_trained(skill_id):
				label.add_theme_color_override("font_color", UITheme.TEXT_DIM)
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			skills.add_child(label)
		add_child(skills)


func _build_features(ch: Character) -> void:
	var features := ch.features()
	if not features.is_empty() or not ch.feats.is_empty():
		add_child(HSeparator.new())
		add_child(make_label(tr("Aptitudes et dons"), "", "", UITheme.TEXT_DIM))
		for feature: Dictionary in features:
			add_child(make_label(feature["name"], feature.get("description", "")))
		for feat_id in ch.feats:
			add_child(make_label(Feats.name_of(feat_id), DB.feats.get(feat_id, {}).get("description", "")))
	var defenses := ch.all_defenses()
	if not defenses.is_empty():
		add_child(make_label(defenses.describe(), ""))


func _add_xp_bar(ch: Character) -> void:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 6)
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	var fill := StyleBoxFlat.new()
	fill.bg_color = UITheme.GOLD
	var back := StyleBoxFlat.new()
	back.bg_color = Color("#3a3128")
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", back)
	if ch.level >= Progression.max_level():
		bar.value = 100
		bar.tooltip_text = tr("XP %d — niveau maximum") % ch.xp
	else:
		var floor_xp := Progression.xp_for(ch.level)
		var next_xp := Progression.xp_for(ch.level + 1)
		bar.value = 100.0 * (ch.xp - floor_xp) / maxf(1.0, next_xp - floor_xp)
		bar.tooltip_text = tr("XP %d / %d (niveau %d)") % [ch.xp, next_xp, ch.level + 1]
	add_child(bar)


## Deux éléments côte à côte, chacun sur la moitié de la largeur.
func _add_pair(left: Control, right: Control) -> void:
	var row := HBoxContainer.new()
	for item in [left, right]:
		item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item.size_flags_stretch_ratio = 1.0
		row.add_child(item)
	add_child(row)


static func make_label(text: String, tooltip: String, variation := "", color := Color(0, 0, 0, 0)) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 60
	if tooltip != "":
		label.tooltip_text = tooltip
		label.mouse_filter = Control.MOUSE_FILTER_STOP
		label.mouse_default_cursor_shape = Control.CURSOR_HELP
	if variation != "":
		label.theme_type_variation = variation
	if color.a > 0.0:
		label.add_theme_color_override("font_color", color)
	return label


static func subclass_text(ch: Character) -> String:
	var parts := PackedStringArray()
	for key: String in ch.choices:
		if key.ends_with("/subclass"):
			parts.append(ch.choice_label(key))
	return (Loc.ui("Voie : %s") % ", ".join(parts)) if not parts.is_empty() else ""


static func _extra_hp_text(ch: Character) -> String:
	var mods := ch.modifiers()
	var extra := Modifiers.sum(mods, "max_hp") + Modifiers.sum(mods, "hp_per_level") * ch.level
	return Loc.ui(" + %d (dons, objets)") % extra if extra != 0 else ""


static func _signed_extra(value: int) -> String:
	return (" %s %d" % ["+" if value > 0 else "−", absi(value)]) if value != 0 else ""


static func _parts_text(parts: Array, empty: String) -> String:
	if parts.is_empty():
		return empty
	return "\n".join(PackedStringArray(parts.map(func(p): return "%s : %+d" % [p[0], int(p[1])])))


## Au survol d'une compétence : ce qu'elle permet de faire, puis son jet.
static func skill_tip(ch: Character, skill_id: String) -> String:
	var abilities := PackedStringArray(Skills.abilities_of(skill_id).map(func(id): return Abilities.short_of(id)))
	var pool := ch.skill_pool(skill_id)
	var lines := PackedStringArray([Skills.description_of(skill_id)])
	if skill_id == "languages":
		lines.append(Loc.ui("Langues connues : %s.") % ", ".join(PackedStringArray(ch.known_languages().map(
			func(l): return Skills.language_name(l)))))
	lines.append("")
	lines.append(Loc.ui("%s · jet : %s%s") % [" / ".join(abilities), Dice.pool_text(int(pool["count"]), int(pool["threshold"])),
		Loc.ui(" · instinctive") if Skills.is_instinctive(skill_id) else ""])
	return "\n".join(lines)
