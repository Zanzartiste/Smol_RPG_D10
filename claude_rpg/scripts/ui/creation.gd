extends Control
## Écran de création de personnage, en onglets : espèce et genre, classe, passé, attributs.
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

var _species := ""
var _class := ""
var _background := ""
var _gender := ""
var _art_seed := 0
var _point_buy: PointBuy
var _name_is_random := true  # le nom suit l'espèce tant que le joueur ne l'a pas tapé lui-même
var _rng := RandomNumberGenerator.new()
var _ability_rows := {}  # id d'attribut -> {value, minus, plus, bonus_buttons, total}


func _ready() -> void:
	theme = UITheme.build()
	_rng.randomize()
	_art_seed = _rng.randi()
	_build_tabs()

	var species := _fill_buttons(species_buttons, DB.species, Meta.is_species_available, _on_species_selected)
	var classes := _fill_buttons(class_buttons, DB.classes, Meta.is_class_available, _on_class_selected)
	var backgrounds := _fill_buttons(background_buttons, DB.backgrounds, func(_id): return true, _on_background_selected)
	var genders := _fill_buttons(gender_buttons, _index(DB.rules["genders"]), func(_id): return true, _on_gender_selected)
	_build_ability_grid()

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


func build_character() -> Character:
	var ch := Character.create(_species, _class, name_edit.text.strip_edges(), {
		"abilities": _point_buy.final_scores(),
		"background": _background,
		"gender": _gender,
	})
	ch.art_seed = _art_seed
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


func _small_button(text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(44, 36)
	button.pressed.connect(on_pressed)
	ability_grid.add_child(button)
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
	if _name_is_random:
		_randomize_name()
	_refresh()


## Changer de classe réapplique son modèle d'attributs (comme dans BG3).
func _on_class_selected(class_id: String) -> void:
	_class = class_id
	_point_buy = PointBuy.from_class(class_id)
	_refresh()


func _on_background_selected(background_id: String) -> void:
	_background = background_id
	_refresh()


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
	if start_button.disabled:
		return
	Game.start_life(build_character())
	get_tree().change_scene_to_file(MAIN_SCENE)


# --- Rafraîchissement ---------------------------------------------------------

func _refresh() -> void:
	if _species == "" or _class == "" or _background == "" or _gender == "" or _point_buy == null:
		return
	var ch := build_character()
	portrait.texture = ArtProvider.portrait(ch)
	sheet_text.text = CharacterSheet.bbcode(ch)
	species_text.text = _species_info(DB.species[_species])
	class_text.text = _class_info(DB.classes[_class])
	background_text.text = _background_info(DB.backgrounds[_background])
	_refresh_abilities()
	start_button.disabled = ch.name == "" or not _point_buy.is_valid()


func _refresh_abilities() -> void:
	points_label.text = tr("Points restants : %d / %d") % [_point_buy.remaining(), PointBuy.budget()]
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
		_field(tr("Taille :"), DB.size_name(species.get("size", "medium"))),
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
	return "[i]%s[/i]\n%s   %s\n%s" % [
		cls.get("description", ""),
		_field(tr("Dé de vie :"), "d%d" % int(cls["hit_die"])),
		_field(tr("Maîtrises :"), _skill_names(cls.get("skills", []))),
		_field(tr("Équipement :"), " · ".join(gear))]


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
