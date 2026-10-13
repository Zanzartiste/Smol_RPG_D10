extends Control
## Écran titre : continuer la vie en cours, commencer une nouvelle vie, consulter la chronique du monde.
## Les actions destructrices (abandonner la vie en cours, effacer le monde) demandent un second clic.

const MAIN_SCENE := "res://scenes/main.tscn"
const CREATION_SCENE := "res://scenes/creation.tscn"

@onready var art: TextureRect = %Art
@onready var continue_button: Button = %ContinueButton
@onready var new_life_button: Button = %NewLifeButton
@onready var quit_button: Button = %QuitButton
@onready var reset_button: Button = %ResetButton
@onready var summary_text: RichTextLabel = %SummaryText
@onready var chronicle_text: RichTextLabel = %ChronicleText

var _confirm_new_life := false
var _confirm_reset := false


func _ready() -> void:
	theme = UITheme.build()
	art.texture = ImageTexture.create_from_image(PixelArt.scene("town", "evening", 7))
	continue_button.pressed.connect(_on_continue)
	new_life_button.pressed.connect(_on_new_life)
	quit_button.pressed.connect(func(): get_tree().quit())
	quit_button.visible = not OS.has_feature("web")
	reset_button.pressed.connect(_on_reset)
	var options_button := Button.new()
	options_button.text = tr("Options")
	options_button.pressed.connect(open_options, CONNECT_DEFERRED)
	quit_button.get_parent().add_child(options_button)
	quit_button.get_parent().move_child(options_button, quit_button.get_index())
	_refresh()


## Fenêtre des options (réglages enregistrés dans la méta).
func open_options() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.65)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var title := Label.new()
	title.text = tr("Options")
	title.theme_type_variation = &"TitleLabel"
	box.add_child(title)
	var manual := CheckBox.new()
	manual.text = tr("Choisir soi-même l'attribut des tests de compétence")
	manual.tooltip_text = tr("Sinon, le meilleur attribut est utilisé automatiquement.")
	manual.button_pressed = Meta.settings.get("manual_skill_ability", false)
	manual.toggled.connect(func(on: bool):
		Meta.settings["manual_skill_ability"] = on
		Saves.save_meta())
	box.add_child(manual)
	var many := CheckBox.new()
	many.text = tr("Règle des dés nombreux")
	many.tooltip_text = tr("À partir de 10 dés, chaque tranche de 10 dés est remplacée par seuil + 1 succès automatiques.")
	many.button_pressed = Meta.settings.get("many_dice", false)
	many.toggled.connect(func(on: bool):
		Meta.settings["many_dice"] = on
		Saves.save_meta())
	box.add_child(many)
	var close := Button.new()
	close.text = tr("Fermer")
	close.pressed.connect(overlay.queue_free)
	box.add_child(close)
	add_child(overlay)


func _refresh() -> void:
	var has_life := Saves.has_life()
	continue_button.visible = has_life
	new_life_button.text = tr("Abandonner la vie en cours ? (cliquer pour confirmer)") if _confirm_new_life \
		else tr("Nouvelle vie")
	reset_button.text = tr("Tout effacer ? (cliquer pour confirmer)") if _confirm_reset else tr("Nouveau monde")
	if has_life:
		continue_button.grab_focus()
	else:
		new_life_button.grab_focus()
	summary_text.text = _summary()
	chronicle_text.text = _chronicle()


func _on_continue() -> void:
	if Saves.load_life():
		get_tree().change_scene_to_file(MAIN_SCENE)


func _on_new_life() -> void:
	if Saves.has_life() and not _confirm_new_life:
		_confirm_new_life = true
		_refresh()
		return
	Saves.delete_life()
	Game.life = null
	get_tree().change_scene_to_file(CREATION_SCENE)


func _on_reset() -> void:
	if not _confirm_reset:
		_confirm_reset = true
		_refresh()
		return
	_confirm_reset = false
	Saves.reset_world()
	_refresh()


## Le monde : nombre de vies, déblocages, événements marquants.
func _summary() -> String:
	var gold := UITheme.GOLD.to_html(false)
	var t := "[color=%s]%s[/color] %d\n" % [gold, tr("Vies vécues dans ce monde :"), Meta.chronicle.size()]
	t += "[color=%s]%s[/color] %d\n" % [gold, tr("Creator Points :"), Meta.creator_points]
	var unlocked := PackedStringArray()
	for id: String in Meta.unlocks:
		unlocked.append(Meta.unlock_name(id))
	t += "[color=%s]%s[/color] %s\n" % [gold, tr("Déblocages :"), ", ".join(unlocked) if not unlocked.is_empty() else "—"]
	if Saves.has_life():
		var data: Dictionary = Saves.peek_life().get("character", {})
		t += "\n[color=%s]%s[/color] %s, %s %s, %s" % [gold, tr("Vie en cours :"), data.get("name", "?"),
			DB.species.get(data.get("species_id", ""), {}).get("name", ""), DB.classes.get(data.get("class_id", ""), {}).get("name", ""),
			tr("niveau %d") % int(data.get("level", 1))]
	return t


## Les vies passées, de la plus récente à la plus ancienne.
func _chronicle() -> String:
	if Meta.chronicle.is_empty():
		return "[color=%s]%s[/color]" % [UITheme.TEXT_DIM.to_html(false), tr("Aucune vie n'a encore été vécue dans ce monde.")]
	var lines := PackedStringArray()
	for i in range(Meta.chronicle.size() - 1, -1, -1):
		var life: Dictionary = Meta.chronicle[i]
		lines.append("[color=%s]%s[/color], %s %s — %s\n[color=%s]%s[/color]" % [
			UITheme.GOLD.to_html(false), life.get("name", "?"),
			DB.species.get(life.get("species", ""), {}).get("name", ""), DB.classes.get(life.get("class", ""), {}).get("name", ""),
			tr("niveau %d, mort à %d ans au jour %d, +%d CP") % [int(life.get("level", 1)), int(life.get("age", 0)),
				int(life.get("days", 1)), int(life.get("creator_points", 0))],
			UITheme.TEXT_DIM.to_html(false), life.get("cause", "")])
	return "\n\n".join(lines)
