extends Control
## Écran principal : fiche du personnage à gauche, scène courante à droite.
## La zone de droite affiche tour à tour le hub (choix du lieu), un événement, son résultat ou la mort.
## Raccourcis : touches 1 à 9 pour choisir une option.

@onready var portrait: TextureRect = %Portrait
@onready var name_label: Label = %NameLabel
@onready var sheet_text: RichTextLabel = %SheetText
@onready var illustration: TextureRect = %Illustration
@onready var title_label: Label = %TitleLabel
@onready var body_text: RichTextLabel = %BodyText
@onready var choices_box: VBoxContainer = %Choices


func _ready() -> void:
	theme = UITheme.build()
	Game.life_changed.connect(_refresh_sheet)
	Game.new_life()
	_show_hub()
	if not DB.errors.is_empty():
		body_text.text += "\n\n[color=%s]%s\n%s[/color]" % [
			UITheme.BAD.to_html(false), tr("Erreurs dans les données :"), "\n".join(PackedStringArray(DB.errors))]


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
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
	body_text.text = tr("%s, %s %s, s'éteint à l'âge de %d ans, au %de jour de son aventure.") % [
		ch.name, DB.races[ch.race_id]["name"], DB.classes[ch.class_id]["name"], ch.age_years(), life.day]
	body_text.text += "\n\n[color=%s]%s[/color]" % [UITheme.BAD.to_html(false), life.death_cause]
	body_text.text += "\n\n" + tr("Vies vécues dans ce monde : %d") % Meta.chronicle.size()
	_clear_choices()
	_add_choice(tr("Commencer une nouvelle vie"), _on_new_life)


# --- Actions -----------------------------------------------------------------

func _on_location_chosen(location_id: String) -> void:
	_show_event(Game.draw_event(location_id))


func _on_choice(choice: Dictionary) -> void:
	_show_result(Game.resolve_choice(choice))


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
	Game.new_life()
	_show_hub()


# --- Fiche du personnage -----------------------------------------------------

func _refresh_sheet() -> void:
	var ch := Game.life.character
	var gold := UITheme.GOLD.to_html(false)
	var dim := UITheme.TEXT_DIM.to_html(false)
	portrait.texture = ArtProvider.portrait(ch)
	name_label.text = ch.name

	var t := "%s %s\n" % [DB.races[ch.race_id]["name"], DB.classes[ch.class_id]["name"]]
	t += tr("%d ans — %s") % [ch.age_years(), DB.life_stage_name(ch.life_stage())] + "\n\n"
	t += "[color=%s]PV[/color] %d / %d    [color=%s]%s[/color] %d po\n" % [
		gold, ch.hp, ch.max_hp, gold, tr("Or"), ch.gold]
	t += "[color=%s]%s[/color] %d    [color=%s]XP[/color] %d\n\n" % [gold, tr("Niveau"), ch.level, gold, ch.xp]

	t += "[table=2]"
	for ability: Dictionary in DB.rules["abilities"]:
		var id: String = ability["id"]
		t += "[cell][color=%s]%s[/color] %d (%s)   [/cell]" % [
			gold, ability["short"], ch.abilities[id], _signed(ch.ability_mod(id))]
	t += "[/table]\n\n"

	t += "[color=%s]%s[/color]\n" % [gold, tr("Compétences")]
	for skill: Dictionary in DB.rules["skills"]:
		var line := "%s %s" % [skill["name"], _signed(ch.skill_mod(skill["id"]))]
		t += (line if ch.is_proficient(skill["id"]) else "[color=%s]%s[/color]" % [dim, line]) + "\n"

	t += "\n[color=%s]%s[/color]\n" % [gold, tr("Inventaire")]
	if ch.inventory.is_empty():
		t += "[color=%s]—[/color]\n" % dim
	for item_id: String in ch.inventory:
		t += "%s ×%d\n" % [DB.items[item_id]["name"], ch.inventory[item_id]]
	sheet_text.text = t


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


func _signed(value: int) -> String:
	return ("+%d" % value) if value >= 0 else str(value)
