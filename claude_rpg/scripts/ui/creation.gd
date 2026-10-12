extends Control
## Écran de création de personnage : race, classe, nom et apparence, avec aperçu de la fiche.
## Les races et classes verrouillées sont visibles mais grisées, avec l'indice pour les débloquer.

const MAIN_SCENE := "res://scenes/main.tscn"

@onready var portrait: TextureRect = %Portrait
@onready var appearance_button: Button = %AppearanceButton
@onready var name_edit: LineEdit = %NameEdit
@onready var random_name_button: Button = %RandomNameButton
@onready var sheet_text: RichTextLabel = %SheetText
@onready var race_buttons: HFlowContainer = %RaceButtons
@onready var race_text: RichTextLabel = %RaceText
@onready var class_buttons: HFlowContainer = %ClassButtons
@onready var class_text: RichTextLabel = %ClassText
@onready var footer_text: RichTextLabel = %FooterText
@onready var start_button: Button = %StartButton

var _race := ""
var _class := ""
var _art_seed := 0
var _name_is_random := true  # le nom suit la race tant que le joueur ne l'a pas tapé lui-même
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	theme = UITheme.build()
	_rng.randomize()
	_art_seed = _rng.randi()
	var races := _fill_buttons(race_buttons, DB.races, Meta.is_race_available, _on_race_selected)
	var classes := _fill_buttons(class_buttons, DB.classes, Meta.is_class_available, _on_class_selected)
	appearance_button.pressed.connect(_on_appearance_pressed)
	random_name_button.pressed.connect(_randomize_name)
	name_edit.text_changed.connect(_on_name_typed)
	name_edit.text_submitted.connect(func(_text): _on_start())
	start_button.pressed.connect(_on_start)
	footer_text.text = _footer()

	# Sélection initiale aléatoire parmi ce qui est disponible.
	var race_ids: Array = DB.races.keys().filter(Meta.is_race_available)
	var class_ids: Array = DB.classes.keys().filter(Meta.is_class_available)
	_class = class_ids[_rng.randi_range(0, class_ids.size() - 1)]
	var race_id: String = race_ids[_rng.randi_range(0, race_ids.size() - 1)]
	classes[_class].button_pressed = true
	races[race_id].button_pressed = true
	_on_race_selected(race_id)


## Crée un bouton à bascule par entrée ; retourne {id: bouton}.
func _fill_buttons(container: Container, table: Dictionary, is_available: Callable, on_select: Callable) -> Dictionary:
	var group := ButtonGroup.new()
	var buttons := {}
	for id: String in table:
		var button := Button.new()
		button.text = table[id]["name"]
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size = Vector2(130, 0)
		button.disabled = not is_available.call(id)
		if button.disabled:
			button.tooltip_text = table[id].get("unlock_hint", "")
		button.pressed.connect(on_select.bind(id))
		container.add_child(button)
		buttons[id] = button
	return buttons


func _on_race_selected(race_id: String) -> void:
	_race = race_id
	if _name_is_random:
		_randomize_name()
	_refresh()


func _on_class_selected(class_id: String) -> void:
	_class = class_id
	_refresh()


func _on_appearance_pressed() -> void:
	_art_seed = _rng.randi()
	_refresh()


func _on_name_typed(_text: String) -> void:
	_name_is_random = false
	_refresh()


func _randomize_name() -> void:
	var names: Array = DB.races[_race].get("names", ["Sans-Nom"])
	var current := name_edit.text
	var picked: String = names[_rng.randi_range(0, names.size() - 1)]
	if names.size() > 1:
		while picked == current:
			picked = names[_rng.randi_range(0, names.size() - 1)]
	name_edit.text = picked
	_name_is_random = true
	_refresh()


func build_character() -> Character:
	var ch := Character.create(_race, _class, name_edit.text.strip_edges())
	ch.art_seed = _art_seed
	return ch


func _refresh() -> void:
	if _race == "" or _class == "":
		return
	var ch := build_character()
	portrait.texture = ArtProvider.portrait(ch)
	sheet_text.text = CharacterSheet.bbcode(ch)
	race_text.text = _race_info(DB.races[_race])
	class_text.text = _class_info(DB.classes[_class])
	start_button.disabled = ch.name == ""


func _on_start() -> void:
	if start_button.disabled:
		return
	Game.start_life(build_character())
	get_tree().change_scene_to_file(MAIN_SCENE)


# --- Textes ------------------------------------------------------------------

func _race_info(race: Dictionary) -> String:
	var bonuses := PackedStringArray()
	var bonus: Dictionary = race.get("ability_bonus", {})
	for ability: String in bonus:
		bonuses.append("%s %s" % [CharacterSheet.signed(int(bonus[ability])), DB.abilities[ability]["short"]])
	var stages: Dictionary = race.get("age_stages", {})
	return "[i]%s[/i]\n[color=%s]%s[/color] %s   [color=%s]%s[/color] %s" % [
		race.get("description", ""),
		_gold(), tr("Bonus :"), ", ".join(bonuses),
		_gold(), tr("Adulte à :"), tr("%d ans") % int(stages.get("adult", 0))]


func _class_info(cls: Dictionary) -> String:
	var skills := PackedStringArray()
	for skill: String in cls.get("skills", []):
		skills.append(DB.skills[skill]["name"])
	return "[i]%s[/i]\n[color=%s]%s[/color] d%d   [color=%s]%s[/color] %s" % [
		cls.get("description", ""),
		_gold(), tr("Dé de vie :"), int(cls["hit_die"]),
		_gold(), tr("Maîtrises :"), ", ".join(skills)]


## Indices de déblocage et souvenir de la vie précédente.
func _footer() -> String:
	var dim := UITheme.TEXT_DIM.to_html(false)
	var lines := PackedStringArray()
	for race: Dictionary in DB.races.values():
		if not Meta.is_race_available(race["id"]):
			lines.append("[color=%s]%s %s — %s[/color]" % [dim, tr("Verrouillé :"), race["name"], race.get("unlock_hint", "?")])
	for cls: Dictionary in DB.classes.values():
		if not Meta.is_class_available(cls["id"]):
			lines.append("[color=%s]%s %s — %s[/color]" % [dim, tr("Verrouillé :"), cls["name"], cls.get("unlock_hint", "?")])
	if not Meta.chronicle.is_empty():
		var last: Dictionary = Meta.chronicle.back()
		lines.append("")
		lines.append("[color=%s]%s[/color] %s, %s %s, %s" % [
			_gold(), tr("Vie précédente :"), last["name"], DB.races[last["race"]]["name"],
			DB.classes[last["class"]]["name"], tr("mort à %d ans — %s") % [last["age"], last["cause"]]])
	return "\n".join(lines)


func _gold() -> String:
	return UITheme.GOLD.to_html(false)
