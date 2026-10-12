extends Control
## Écran principal : fiche du personnage à gauche, scène courante à droite.
## La zone de droite affiche tour à tour le hub (choix du lieu), un événement, le lancer de dés,
## son résultat ou la mort.
## Raccourcis : touches 1 à 9 pour choisir une option ; n'importe quelle touche accélère les dés.

const CREATION_SCENE := "res://scenes/creation.tscn"

@onready var portrait: TextureRect = %Portrait
@onready var name_label: Label = %NameLabel
@onready var sheet_text: RichTextLabel = %SheetText
@onready var illustration: TextureRect = %Illustration
@onready var dice_tray: DiceTray = %DiceTray
@onready var title_label: Label = %TitleLabel
@onready var body_text: RichTextLabel = %BodyText
@onready var choices_box: VBoxContainer = %Choices


func _ready() -> void:
	theme = UITheme.build()
	Game.life_changed.connect(_refresh_sheet)
	if Game.life == null or Game.life.dead:
		Game.new_life()  # scène lancée directement, sans passer par la création
	_refresh_sheet()
	_show_hub()
	if not DB.errors.is_empty():
		body_text.text += "\n\n[color=%s]%s\n%s[/color]" % [
			UITheme.BAD.to_html(false), tr("Erreurs dans les données :"), "\n".join(PackedStringArray(DB.errors))]


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if dice_tray.is_playing():
		dice_tray.skip()
		accept_event()
		return
	var index: int = key.keycode - KEY_1
	if index >= 0 and index < choices_box.get_child_count():
		var button := choices_box.get_child(index) as Button
		if not button.disabled:
			button.pressed.emit()
			accept_event()


# --- Écrans ------------------------------------------------------------------

func _show_hub() -> void:
	var life := Game.life
	illustration.texture = ArtProvider.location_image("town", life)
	title_label.text = tr("Jour %d — %s") % [life.day, life.slot_name()]
	var text := ""
	for notice in life.take_notices():
		text += "[color=%s]• %s[/color]\n" % [UITheme.GOLD.to_html(false), notice]
	body_text.text = text + tr("Où souhaitez-vous aller ?")
	_clear_choices()
	for loc_id in DB.location_order:
		var loc: Dictionary = DB.locations[loc_id]
		_add_choice("%s — %s" % [loc["name"], loc.get("description", "")], _on_location_chosen.bind(loc_id))


func _show_event(ev: Dictionary) -> void:
	var life := Game.life
	Game.begin_event(ev)
	illustration.texture = ArtProvider.event_image(ev, life)
	title_label.text = Loc.fill(Loc.t("evt.%s.title" % ev["id"], ev.get("title", "")), life)
	body_text.text = Loc.fill(Loc.t("evt.%s.text" % ev["id"], ev.get("text", "")), life)
	_clear_choices()
	for entry in EventEngine.visible_choices(ev, life, Meta):
		var choice: Dictionary = entry["choice"]
		var label := Loc.fill(Loc.t("evt.%s.%s.text" % [ev["id"], choice["id"]], choice.get("text", "")), life)
		if choice.has("check"):
			var chance := Dice.success_chance(life.character, choice["check"])
			label += "   [%s — %d %%]" % [Dice.label(choice["check"]), roundi(chance * 100)]
		if not entry["available"]:
			label += "   (%s)" % entry["reason"]
		_add_choice(label, _on_choice.bind(choice), entry["available"])


func _show_result(result: Dictionary) -> void:
	var life := Game.life
	var text := Loc.fill(result["text"], life)
	var roll: Dictionary = result["roll"]
	if not roll.is_empty():
		var color := UITheme.GOOD if roll["success"] else UITheme.BAD
		text += "\n\n[color=%s]%s : %d %s %d = %d — %s[/color]" % [
			color.to_html(false), roll["label"], roll["die"], "+" if roll["mod"] >= 0 else "−",
			absi(roll["mod"]), roll["total"], tr("Réussite") if roll["success"] else tr("Échec")]
	if not result["lines"].is_empty():
		text += "\n\n[color=%s]%s[/color]" % [UITheme.GOLD.to_html(false), "\n".join(PackedStringArray(result["lines"]))]
	body_text.text = text
	_clear_choices()
	_add_choice(tr("Continuer"), _on_continue.bind(result["goto"]))


func _show_death() -> void:
	var life := Game.life
	var ch := life.character
	title_label.text = tr("Fin d'une vie")
	body_text.text = ""
	for notice in life.take_notices():
		body_text.text += "[color=%s]• %s[/color]\n" % [UITheme.GOLD.to_html(false), notice]
	body_text.text += tr("%s, %s %s, s'éteint à l'âge de %d ans, au %de jour de son aventure.") % [
		ch.name, DB.species[ch.species_id]["name"], DB.classes[ch.class_id]["name"], ch.age_years(), life.day]
	body_text.text += "\n\n[color=%s]%s[/color]" % [UITheme.BAD.to_html(false), life.death_cause]
	body_text.text += "\n\n" + tr("Vies vécues dans ce monde : %d") % Meta.chronicle.size()
	_clear_choices()
	_add_choice(tr("Commencer une nouvelle vie"), _on_new_life)


# --- Actions -----------------------------------------------------------------

func _on_location_chosen(location_id: String) -> void:
	_show_event(Game.draw_event(location_id))


## Pour un choix avec test, on lance et on anime les dés avant d'appliquer les effets,
## pour ne rien dévoiler (PV, or...) avant que les dés ne s'arrêtent.
func _on_choice(choice: Dictionary) -> void:
	var roll := {}
	if choice.has("check"):
		roll = Game.roll_check(choice)
		_clear_choices()
		await dice_tray.play(roll)
	_show_result(Game.resolve_choice(choice, roll))


func _on_continue(goto: String) -> void:
	if Game.life.dead:
		_show_death()
	elif goto != "":
		_show_event(DB.events[goto])
	else:
		Game.end_event()
		if Game.life.dead:
			_show_death()
		else:
			_show_hub()


func _on_new_life() -> void:
	get_tree().change_scene_to_file(CREATION_SCENE)


func _refresh_sheet() -> void:
	var ch := Game.life.character
	portrait.texture = ArtProvider.portrait(ch)
	name_label.text = ch.name
	sheet_text.text = CharacterSheet.bbcode(ch)


# --- Utilitaires -------------------------------------------------------------

func _clear_choices() -> void:
	for child in choices_box.get_children():
		choices_box.remove_child(child)
		child.queue_free()


func _add_choice(text: String, callback: Callable, enabled := true) -> void:
	var button := Button.new()
	button.text = "%d. %s" % [choices_box.get_child_count() + 1, text]
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.disabled = not enabled
	button.pressed.connect(callback, CONNECT_DEFERRED)
	choices_box.add_child(button)
