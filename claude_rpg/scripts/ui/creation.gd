extends Control
## Écran de création de personnage, en onglets : espèce et genre, classe, passé, attributs, Creator Points.
## Les Creator Points (gagnés par les vies précédentes) achètent des bonus pour cette vie (dépensés au
## lancement) ou des déblocages définitifs d'espèces et de classes (dépensés tout de suite).
## L'aperçu (portrait, nom, fiche) reste visible à gauche et se met à jour en direct.
## Les espèces et classes verrouillées sont visibles mais grisées, avec l'indice pour les débloquer.

const MAIN_SCENE := "res://scenes/main.tscn"

@onready var portrait: TextureRect = %Portrait
@onready var name_edit: LineEdit = %NameEdit
@onready var random_name_button: Button = %RandomNameButton
@onready var appearance_button: Button = %AppearanceButton
@onready var sheet_text: RichTextLabel = %SheetText
@onready var tab_buttons: HBoxContainer = %TabButtons
@onready var pages: TabContainer = %Pages
@onready var species_buttons: HFlowContainer = %SpeciesButtons
@onready var species_text: RichTextLabel = %SpeciesText
@onready var gender_buttons: HFlowContainer = %GenderButtons
@onready var class_buttons: HFlowContainer = %ClassButtons
@onready var class_text: RichTextLabel = %ClassText
@onready var background_buttons: HFlowContainer = %BackgroundButtons
@onready var background_text: RichTextLabel = %BackgroundText
@onready var points_label: Label = %PointsLabel
@onready var ability_grid: GridContainer = %AbilityGrid
@onready var template_button: Button = %TemplateButton
@onready var footer_text: RichTextLabel = %FooterText
@onready var start_button: Button = %StartButton
@onready var points_summary: RichTextLabel = %PointsSummary
@onready var upgrade_grid: GridContainer = %UpgradeGrid
@onready var unlock_box: HFlowContainer = %UnlockBox

var _species := ""
var _class := ""
var _background := ""
var _gender := ""
var _art_seed := 0
var _point_buy: PointBuy
var _name_is_random := true  # le nom suit l'espèce tant que le joueur ne l'a pas tapé lui-même
var _rng := RandomNumberGenerator.new()
var _ability_rows := {}  # id d'attribut -> {value, minus, plus, bonus_buttons, total}
var _cp_ranks := {}  # id d'amélioration (Creator Points) -> rang acheté pour cette vie
var _upgrade_rows := {}  # id d'amélioration -> {rank, cost, minus, plus}
var _species_buttons := {}
var _class_buttons := {}
var _creation_choices := {}  # clé de choix (« class/skills », « species/ancestry ») -> valeurs choisies
var _class_choice_box := VBoxContainer.new()
var _species_choice_box := VBoxContainer.new()


func _ready() -> void:
	theme = UITheme.build()
	_rng.randomize()
	_art_seed = _rng.randi()
	_build_tabs()

	var species := _fill_buttons(species_buttons, DB.species, Meta.is_species_available, _on_species_selected)
	var classes := _fill_buttons(class_buttons, DB.classes, Meta.is_class_available, _on_class_selected)
	_species_buttons = species
	_class_buttons = classes
	var backgrounds := _fill_buttons(background_buttons, DB.backgrounds, func(_id): return true, _on_background_selected)
	var genders := _fill_buttons(gender_buttons, _index(DB.rules["genders"]), func(_id): return true, _on_gender_selected)
	_build_ability_grid()
	_build_upgrade_grid()
	class_text.get_parent().add_child(_class_choice_box)
	species_text.get_parent().add_child(_species_choice_box)
	species_text.get_parent().move_child(_species_choice_box, species_text.get_index() + 1)

	random_name_button.pressed.connect(_randomize_name)
	appearance_button.pressed.connect(_on_appearance_pressed)
	name_edit.text_changed.connect(_on_name_typed)
	name_edit.text_submitted.connect(func(_text): _on_start())
	template_button.pressed.connect(func(): _on_class_selected(_class))
	start_button.pressed.connect(_on_start)
	footer_text.text = _footer()

	# Sélection initiale aléatoire parmi ce qui est disponible.
	for pair in [[species, _on_species_selected], [classes, _on_class_selected],
			[backgrounds, _on_background_selected], [genders, _on_gender_selected]]:
		var buttons: Dictionary = pair[0]
		var available := buttons.keys().filter(func(id): return not buttons[id].disabled)
		var picked: String = available[_rng.randi_range(0, available.size() - 1)]
		buttons[picked].button_pressed = true
		pair[1].call(picked)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and key.keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file("res://scenes/title.tscn")


func build_character() -> Character:
	var ch := Character.create(_species, _class, name_edit.text.strip_edges(), {
		"abilities": _point_buy.final_scores(),
		"background": _background,
		"gender": _gender,
		"choices": _creation_choices,
	})
	ch.art_seed = _art_seed
	CreatorPoints.apply(ch, _cp_ranks)  # niveau de départ et or en plus
	return ch


# --- Construction de l'interface ---------------------------------------------

func _build_tabs() -> void:
	var group := ButtonGroup.new()
	for i in pages.get_tab_count():
		var button := Button.new()
		button.text = pages.get_tab_title(i)
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = i == 0
		button.custom_minimum_size = Vector2(120, 0)
		button.pressed.connect(func(): pages.current_tab = i)
		tab_buttons.add_child(button)


## Crée un bouton à bascule par entrée ; retourne {id: bouton}.
func _fill_buttons(container: Container, table: Dictionary, is_available: Callable, on_select: Callable) -> Dictionary:
	var group := ButtonGroup.new()
	var buttons := {}
	for id: String in table:
		var button := Button.new()
		button.text = table[id]["name"]
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size = Vector2(120, 0)
		button.disabled = not is_available.call(id)
		if button.disabled:
			button.tooltip_text = table[id].get("unlock_hint", "")
		button.pressed.connect(on_select.bind(id))
		container.add_child(button)
		buttons[id] = button
	return buttons


## Grille de l'achat de points : Attribut | − | valeur | + | +2 | +1 | total (modificateur).
func _build_ability_grid() -> void:
	var amounts := PointBuy.bonus_amounts()
	for header in [tr("Attribut"), "", tr("Base"), ""] + amounts.map(func(a): return "+%d" % a) + [tr("Total")]:
		var label := Label.new()
		label.text = header
		label.theme_type_variation = &"SectionLabel"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ability_grid.add_child(label)
	ability_grid.columns = 5 + amounts.size()

	var bonus_groups := []
	for i in amounts.size():
		bonus_groups.append(ButtonGroup.new())
	for id in Abilities.ids():
		var row := {"bonus_buttons": []}
		var name_label := Label.new()
		name_label.text = Abilities.name_of(id)
		name_label.tooltip_text = Abilities.description_of(id)
		name_label.mouse_filter = Control.MOUSE_FILTER_PASS
		name_label.custom_minimum_size = Vector2(130, 0)
		ability_grid.add_child(name_label)
		row["minus"] = _small_button("−", _on_decrease.bind(id))
		row["value"] = _centered_label()
		row["plus"] = _small_button("+", _on_increase.bind(id))
		for i in amounts.size():
			var toggle := _small_button("+%d" % amounts[i], _on_bonus.bind(i, id))
			toggle.toggle_mode = true
			toggle.button_group = bonus_groups[i]
			row["bonus_buttons"].append(toggle)
		row["total"] = _centered_label()
		_ability_rows[id] = row


func _small_button(text: String, on_pressed: Callable, parent: Container = null) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(44, 36)
	button.pressed.connect(on_pressed)
	(parent if parent != null else ability_grid).add_child(button)
	return button


func _centered_label() -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(70, 0)
	ability_grid.add_child(label)
	return label


# --- Sélections ---------------------------------------------------------------

func _on_species_selected(species_id: String) -> void:
	_species = species_id
	_reset_creation_choices("species/", DB.species[species_id])
	if _name_is_random:
		_randomize_name()
	_refresh()


## Changer de classe réapplique son modèle d'attributs (comme dans BG3).
func _on_class_selected(class_id: String) -> void:
	_class = class_id
	_reset_creation_choices("class/", DB.classes[class_id])
	_point_buy = PointBuy.from_class(class_id)
	_point_buy.extra_budget = CreatorPoints.bonus(_cp_ranks, "point_buy")
	_refresh()


func _on_background_selected(background_id: String) -> void:
	_background = background_id
	# Une compétence déjà donnée par le passé ne peut pas être choisie en plus.
	var granted: Array = DB.backgrounds[background_id].get("skills", [])
	for key: String in _creation_choices:
		_creation_choices[key] = _creation_choices[key].filter(func(v): return v not in granted)
	_fill_missing_choices()
	_refresh()


# --- Choix de création (compétences de classe, ascendance) -----------------------

## Choix proposés à la création par une espèce ou une classe ("at_creation").
func _creation_specs(source: Dictionary) -> Array:
	return source.get("choices", []).filter(func(s): return s.get("at_creation", false))


## Revient aux valeurs par défaut des choix de création d'une source (en évitant les compétences du passé).
func _reset_creation_choices(prefix: String, source: Dictionary) -> void:
	for key: String in _creation_choices.keys():
		if key.begins_with(prefix):
			_creation_choices.erase(key)
	var granted: Array = DB.backgrounds.get(_background, {}).get("skills", [])
	for spec: Dictionary in _creation_specs(source):
		_creation_choices[prefix + spec["id"]] = spec.get("default", []).filter(func(v): return v not in granted)
	_fill_missing_choices()


## Complète les choix de création incomplets avec les premières options libres (une compétence
## par défaut déjà donnée par le passé est remplacée par une autre).
func _fill_missing_choices() -> void:
	var granted: Array = DB.backgrounds.get(_background, {}).get("skills", [])
	for pair in [["species/", DB.species.get(_species, {})], ["class/", DB.classes.get(_class, {})]]:
		for spec: Dictionary in _creation_specs(pair[1]):
			var key: String = pair[0] + spec["id"]
			var values: Array = _creation_choices.get(key, [])
			for o in spec.get("options", []):
				var value: String = o if o is String else o["id"]
				if values.size() >= int(spec.get("count", 1)):
					break
				if value not in values and not (spec.get("type") == "skill" and value in granted):
					values.append(value)
			_creation_choices[key] = values


func _on_creation_choice(key: String, spec: Dictionary, value: String) -> void:
	var values: Array = _creation_choices.get(key, [])
	if value in values:
		values.erase(value)
	elif int(spec.get("count", 1)) == 1:
		values = [value]
	elif values.size() < int(spec.get("count", 1)):
		values.append(value)
	_creation_choices[key] = values
	_refresh()


## Boutons à bascule des choix de création d'une source, dans `box`.
func _fill_creation_choices(box: VBoxContainer, prefix: String, source: Dictionary) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
	var granted: Array = DB.backgrounds.get(_background, {}).get("skills", [])
	for spec: Dictionary in _creation_specs(source):
		var key: String = prefix + spec["id"]
		var values: Array = _creation_choices.get(key, [])
		var count := int(spec.get("count", 1))
		var title := Label.new()
		title.text = tr("%s : %d / %d") % [spec.get("name", ""), values.size(), count]
		title.theme_type_variation = &"SectionLabel"
		box.add_child(title)
		var flow := HFlowContainer.new()
		box.add_child(flow)
		var options: Array = spec.get("options", []).map(func(o): return o if o is String else o["id"])
		for value: String in options:
			var button := Button.new()
			button.text = Choices.value_name(spec, value)
			button.tooltip_text = Choices.value_description(spec, value)
			button.toggle_mode = true
			button.button_pressed = value in values
			if spec.get("type") == "skill" and value in granted:
				button.disabled = true
				button.tooltip_text = tr("Déjà maîtrisée grâce au passé")
			elif value not in values and values.size() >= count and count > 1:
				button.disabled = true
			button.pressed.connect(_on_creation_choice.bind(key, spec, value), CONNECT_DEFERRED)
			flow.add_child(button)


## Tous les choix de création sont-ils complets ?
func _creation_choices_complete() -> bool:
	for pair in [["species/", DB.species[_species]], ["class/", DB.classes[_class]]]:
		for spec: Dictionary in _creation_specs(pair[1]):
			if _creation_choices.get(pair[0] + spec["id"], []).size() < int(spec.get("count", 1)):
				return false
	return true


func _on_gender_selected(gender_id: String) -> void:
	_gender = gender_id
	_refresh()


func _on_decrease(ability_id: String) -> void:
	_point_buy.decrease(ability_id)
	_refresh()


func _on_increase(ability_id: String) -> void:
	_point_buy.increase(ability_id)
	_refresh()


func _on_bonus(index: int, ability_id: String) -> void:
	_point_buy.set_bonus(index, ability_id)
	_refresh()


func _on_appearance_pressed() -> void:
	_art_seed = _rng.randi()
	_refresh()


func _on_name_typed(_text: String) -> void:
	_name_is_random = false
	_refresh()


func _randomize_name() -> void:
	if _species == "":
		return
	var names: Array = DB.species[_species].get("names", ["Sans-Nom"])
	var picked: String = names[_rng.randi_range(0, names.size() - 1)]
	while names.size() > 1 and picked == name_edit.text:
		picked = names[_rng.randi_range(0, names.size() - 1)]
	name_edit.text = picked
	_name_is_random = true
	_refresh()


func _on_start() -> void:
	if confirm_creation():
		get_tree().change_scene_to_file(MAIN_SCENE)


## Dépense les Creator Points des bonus choisis et commence la vie ; false si impossible.
func confirm_creation() -> bool:
	if start_button.disabled or not Meta.spend_creator_points(CreatorPoints.total_cost(_cp_ranks)):
		return false
	Game.start_life(build_character())
	return true


# --- Creator Points ----------------------------------------------------------

## Grille des améliorations : nom | rang | coût du rang suivant | − | +
func _build_upgrade_grid() -> void:
	for upgrade in CreatorPoints.upgrades():
		var id: String = upgrade["id"]
		var name_label := Label.new()
		name_label.text = upgrade["name"]
		name_label.tooltip_text = upgrade.get("description", "")
		name_label.mouse_filter = Control.MOUSE_FILTER_PASS
		name_label.custom_minimum_size = Vector2(200, 0)
		upgrade_grid.add_child(name_label)
		var rank := Label.new()
		rank.custom_minimum_size = Vector2(56, 0)
		upgrade_grid.add_child(rank)
		var cost := Label.new()
		cost.custom_minimum_size = Vector2(110, 0)
		upgrade_grid.add_child(cost)
		var minus := _small_button("−", _on_rank.bind(id, -1), upgrade_grid)
		var plus := _small_button("+", _on_rank.bind(id, 1), upgrade_grid)
		_upgrade_rows[id] = {"rank": rank, "cost": cost, "minus": minus, "plus": plus}


## Creator Points encore disponibles en tenant compte des bonus sélectionnés.
func _available_points() -> int:
	return Meta.creator_points - CreatorPoints.total_cost(_cp_ranks)


func _on_rank(upgrade_id: String, delta: int) -> void:
	var rank := clampi(int(_cp_ranks.get(upgrade_id, 0)) + delta, 0, CreatorPoints.max_rank(upgrade_id))
	var ranks := _cp_ranks.duplicate()
	ranks[upgrade_id] = rank
	if CreatorPoints.total_cost(ranks) > Meta.creator_points:
		return
	_cp_ranks = ranks
	_point_buy.extra_budget = CreatorPoints.bonus(_cp_ranks, "point_buy")
	_refresh()


func _on_buy_unlock(unlock_id: String) -> void:
	if CreatorPoints.unlock_cost(unlock_id) > _available_points() or not Meta.buy_unlock(unlock_id):
		return
	Saves.save_all()
	var parts := unlock_id.split(":")
	var button: Button = (_species_buttons if parts[0] == "species" else _class_buttons).get(parts[1])
	if button != null:
		button.disabled = false
		button.tooltip_text = ""
	footer_text.text = _footer()
	_refresh()


func _refresh_creator_points() -> void:
	var gold := UITheme.GOLD.to_html(false)
	points_summary.text = "[color=%s]%s[/color] %d   [color=%s]%s[/color] %d\n[color=%s]%s[/color]" % [
		gold, tr("Disponibles :"), _available_points(), gold, tr("Bonus choisis :"), CreatorPoints.total_cost(_cp_ranks),
		UITheme.TEXT_DIM.to_html(false), tr("Gagnés à chaque vie selon l'expérience acquise. Les bonus sont dépensés au lancement de l'aventure.")]
	for id: String in _upgrade_rows:
		var row: Dictionary = _upgrade_rows[id]
		var rank := int(_cp_ranks.get(id, 0))
		var max_rank := CreatorPoints.max_rank(id)
		row["rank"].text = "%d / %d" % [rank, max_rank]
		row["cost"].text = tr("suivant : %d CP") % CreatorPoints.rank_cost(id, rank + 1) if rank < max_rank else tr("maximum")
		row["minus"].disabled = rank <= 0
		row["plus"].disabled = rank >= max_rank or CreatorPoints.rank_cost(id, rank + 1) > _available_points()
	for child in unlock_box.get_children():
		unlock_box.remove_child(child)
		child.queue_free()
	for table: Dictionary in [DB.species, DB.classes]:
		var prefix := "species:" if table == DB.species else "class:"
		for entry: Dictionary in table.values():
			var unlock_id: String = prefix + entry["id"]
			var cost := CreatorPoints.unlock_cost(unlock_id)
			if cost > 0 and not Meta.is_unlocked(unlock_id):
				var button := Button.new()
				button.text = tr("Débloquer : %s (%d CP)") % [entry["name"], cost]
				button.disabled = cost > _available_points()
				button.pressed.connect(_on_buy_unlock.bind(unlock_id), CONNECT_DEFERRED)
				unlock_box.add_child(button)
	if unlock_box.get_child_count() == 0:
		var none := Label.new()
		none.text = tr("Tout est déjà débloqué.")
		none.add_theme_color_override("font_color", UITheme.TEXT_DIM)
		unlock_box.add_child(none)


# --- Rafraîchissement ---------------------------------------------------------

func _refresh() -> void:
	if _species == "" or _class == "" or _background == "" or _gender == "" or _point_buy == null:
		return
	var ch := build_character()
	portrait.texture = ArtProvider.portrait(ch)
	sheet_text.text = CharacterSheet.bbcode(ch)
	species_text.text = _species_info(DB.species[_species])
	class_text.text = _class_info(DB.classes[_class])
	_fill_creation_choices(_class_choice_box, "class/", DB.classes[_class])
	_fill_creation_choices(_species_choice_box, "species/", DB.species[_species])
	background_text.text = _background_info(DB.backgrounds[_background])
	_refresh_abilities()
	_refresh_creator_points()
	start_button.disabled = ch.name == "" or not _point_buy.is_valid() or not _creation_choices_complete()


func _refresh_abilities() -> void:
	points_label.text = tr("Points restants : %d / %d") % [_point_buy.remaining(), _point_buy.total_budget()]
	for id: String in _ability_rows:
		var row: Dictionary = _ability_rows[id]
		row["value"].text = str(_point_buy.base[id])
		row["minus"].disabled = not _point_buy.can_decrease(id)
		row["plus"].disabled = not _point_buy.can_increase(id)
		row["plus"].tooltip_text = tr("Coût : %d") % _point_buy.next_cost(id) if _point_buy.base[id] < PointBuy.max_score() else ""
		for i in row["bonus_buttons"].size():
			row["bonus_buttons"][i].set_pressed_no_signal(_point_buy.bonuses[i] == id)
		var score := _point_buy.final_score(id)
		row["total"].text = "%d (%s)" % [score, CharacterSheet.signed(floori((score - 10) / 2.0))]


# --- Textes ------------------------------------------------------------------

func _species_info(species: Dictionary) -> String:
	var stages: Dictionary = species.get("age_stages", {})
	var text := "[i]%s[/i]\n%s   %s   %s" % [
		species.get("description", ""),
		_field(tr("Taille :"), DB.size_name(species.get("size", 0))),
		_field(tr("Adulte à :"), tr("%d ans") % int(stages.get("adult", 0))),
		_field(tr("Vieillit dès :"), tr("%d ans") % int(species.get("aging_age", 0)))]
	if not species.get("modifiers", []).is_empty():
		text += "\n" + _field(tr("Traits :"), Modifiers.describe_all(species["modifiers"]))
	return text


func _class_info(cls: Dictionary) -> String:
	var gear := PackedStringArray()
	var equipment: Dictionary = cls.get("equipment", {})
	for slot in Equipment.SLOTS:
		if equipment.has(slot):
			gear.append(Equipment.describe(equipment[slot]))
	var saves := PackedStringArray(cls.get("saving_throws", []).map(func(id): return Abilities.short_of(id)))
	var text := "[i]%s[/i]\n%s   %s\n%s\n%s" % [
		cls.get("description", ""),
		_field(tr("Dé de vie :"), "d%d" % int(cls["hit_die"])),
		_field(tr("Sauvegardes :"), ", ".join(saves)),
		_field(tr("Maîtrises :"), tr("au choix, ci-dessous")),
		_field(tr("Équipement :"), " · ".join(gear))] + "\n" + _field(tr("Actions :"),
		", ".join(PackedStringArray(cls.get("actions", []).map(func(id): return Actions.name_of(id)))))
	if cls.has("spell_slots"):
		text += "\n" + _field(tr("Sorts :"), tr("emplacements de sort qui augmentent avec le niveau (%s)") %
			ClassFeatures.slots_text(Spellcasting.slots(cls["spell_slots"], 1)))
	var features := PackedStringArray()
	for feature: Dictionary in ClassFeatures.of_class(cls["id"]):
		features.append(tr("niv. %d : %s") % [int(feature["level"]), feature["name"]])
	if not features.is_empty():
		text += "\n" + _field(tr("Aptitudes :"), " · ".join(features))
	return text


func _background_info(background: Dictionary) -> String:
	var text := "[i]%s[/i]\n%s" % [
		Loc.gendered(background.get("description", ""), _gender), _field(tr("Maîtrises :"), _skill_names(background.get("skills", [])))]
	var feat_id := Feats.for_background(background["id"])
	if feat_id != "":
		text += "\n" + _field(tr("Don :"), "%s — %s" % [Feats.name_of(feat_id), Feats.summary_of(feat_id)])
	if background.has("gold"):
		text += "   " + _field(tr("Or :"), "+%d po" % int(background["gold"]))
	return text


func _field(label: String, value: String) -> String:
	return "[color=%s]%s[/color] %s" % [UITheme.GOLD.to_html(false), label, value]


func _skill_names(ids: Array) -> String:
	return Skills.names_of(ids)


## Indices de déblocage et souvenir de la vie précédente.
func _footer() -> String:
	var dim := UITheme.TEXT_DIM.to_html(false)
	var lines := PackedStringArray()
	for entry: Dictionary in DB.species.values():
		if not Meta.is_species_available(entry["id"]):
			lines.append("[color=%s]%s %s — %s[/color]" % [dim, tr("Verrouillé :"), entry["name"], entry.get("unlock_hint", "?")])
	for entry: Dictionary in DB.classes.values():
		if not Meta.is_class_available(entry["id"]):
			lines.append("[color=%s]%s %s — %s[/color]" % [dim, tr("Verrouillé :"), entry["name"], entry.get("unlock_hint", "?")])
	if not Meta.chronicle.is_empty():
		var last: Dictionary = Meta.chronicle.back()
		lines.append(_field(tr("Vie précédente :"), "%s, %s %s, %s" % [
			last["name"], DB.species[last["species"]]["name"], DB.classes[last["class"]]["name"],
			tr("mort à %d ans — %s") % [last["age"], last["cause"]]]))
	return "\n".join(lines)


func _index(list: Array) -> Dictionary:
	var result := {}
	for entry: Dictionary in list:
		result[entry["id"]] = entry
	return result
