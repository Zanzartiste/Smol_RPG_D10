extends Control
## Écran principal : fiche du personnage à gauche, scène courante à droite.
## La zone de droite affiche tour à tour le hub (choix du lieu), un événement, le lancer de dés,
## son résultat, un combat ou la mort.
## Raccourcis : touches 1 à 9 pour choisir une option ; n'importe quelle touche accélère les dés ;
## F12 active ou désactive le mode debug (choix verrouillés visibles).

const CREATION_SCENE := "res://scenes/creation.tscn"
const DECK_BUILDER_SCENE := "res://scenes/deck_builder.tscn"
const MAX_CHOICES_HEIGHT := 330  # au-delà, la liste de choix défile


@onready var portrait: TextureRect = %Portrait
@onready var name_label: Label = %NameLabel
@onready var sheet_text: RichTextLabel = %SheetText
@onready var illustration: TextureRect = %Illustration
@onready var dice_tray: DiceTray = %DiceTray
@onready var content_box: VBoxContainer = %ContentBox
@onready var combat_view: CombatView = %CombatView
@onready var title_label: Label = %TitleLabel
@onready var body_text: RichTextLabel = %BodyText
@onready var choices_box: VBoxContainer = %Choices
@onready var choices_scroll: ScrollContainer = %ChoicesScroll

var _debug_badge := Label.new()
var _event_on_screen: Dictionary = {}  # événement dont les choix sont affichés (pour les réafficher en debug)


func _ready() -> void:
	theme = UITheme.build()
	Game.life_changed.connect(_refresh_sheet)
	Game.debug_changed.connect(_on_debug_changed)
	_setup_debug_badge()
	if Game.life == null or Game.life.dead:
		Game.new_life()  # scène lancée directement, sans passer par la création
	_refresh_sheet()
	_show_hub()
	if not DB.errors.is_empty():
		body_text.text += "\n\n[color=%s]%s\n%s[/color]" % [
			UITheme.BAD.to_html(false), tr("Erreurs dans les données :"), "\n".join(PackedStringArray(DB.errors))]


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or combat_view.visible:
		return
	if key.keycode == KEY_F12:
		Game.toggle_debug()
		accept_event()
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
	# Un membre du groupe a gagné une amélioration en montant de niveau : on la lui fait choisir d'abord.
	for member in Game.life.party():
		if member.can_increase_ability():
			_show_ability_choice(member)
			return
		if member.can_choose_feat():
			_show_feat_choice(member)
			return
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
	_add_choice(tr("Composer son deck (%d cartes)") % life.character.deck_size(), _on_deck_builder)


func _show_event(ev: Dictionary) -> void:
	var life := Game.life
	Game.begin_event(ev)
	illustration.texture = ArtProvider.event_image(ev, life)
	title_label.text = Loc.fill(Loc.t("evt.%s.title" % ev["id"], ev.get("title", "")), life)
	body_text.text = Loc.fill(Loc.t("evt.%s.text" % ev["id"], ev.get("text", "")), life)
	_show_event_choices(ev)


func _show_event_choices(ev: Dictionary) -> void:
	var life := Game.life
	_clear_choices()
	_event_on_screen = ev
	for entry in EventEngine.visible_choices(ev, life, Meta, Game.debug):
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
	if not result.get("combat", {}).is_empty():
		_add_choice(tr("Combattre !"), _run_combat.bind(result["combat"]))
	else:
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


func _show_ability_choice(member: Character) -> void:
	title_label.text = tr("Amélioration — %s") % member.name
	body_text.text = tr("%s a atteint le niveau %d : choisissez l'attribut à augmenter de 1 (maximum %d).") % [
		member.name, member.level, Progression.max_ability_score()]
	_clear_choices()
	for id in Abilities.ids():
		var score := int(member.abilities[id])
		var button := _add_choice("%s : %d → %d" % [Abilities.name_of(id), score, score + 1],
			_on_ability_chosen.bind(member, id), member.can_raise(id))
		button.tooltip_text = Abilities.description_of(id)


func _show_feat_choice(member: Character) -> void:
	title_label.text = tr("Nouveau don — %s") % member.name
	body_text.text = tr("%s a atteint le niveau %d et peut choisir un nouveau don.") % [member.name, member.level]
	if member.pending_feats > 1:
		body_text.text += " " + tr("(%d dons à choisir)") % member.pending_feats
	_clear_choices()
	for feat_id in member.available_feats():
		var button := _add_choice("%s — %s" % [Feats.name_of(feat_id), Modifiers.describe_all(Feats.modifiers_of(feat_id))],
			_on_feat_chosen.bind(member, feat_id))
		button.tooltip_text = Feats.description_of(feat_id)


# --- Actions -----------------------------------------------------------------

func _on_ability_chosen(member: Character, ability_id: String) -> void:
	member.increase_ability(ability_id)
	_refresh_sheet()
	_show_hub()


func _on_feat_chosen(member: Character, feat_id: String) -> void:
	member.choose_feat(feat_id)
	_refresh_sheet()
	_show_hub()



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


func _on_deck_builder() -> void:
	get_tree().change_scene_to_file(DECK_BUILDER_SCENE)


func _on_new_life() -> void:
	get_tree().change_scene_to_file(CREATION_SCENE)


# --- Combat ------------------------------------------------------------------

## Le combat se joue dans l'écran dédié (CombatView), qui remplace le contenu le temps de la bataille.
func _run_combat(spec: Dictionary) -> void:
	content_box.visible = false
	combat_view.visible = true
	var result: Dictionary = await combat_view.run(spec, illustration.texture)
	combat_view.visible = false
	content_box.visible = true
	_refresh_sheet()
	title_label.text = {"victory": tr("Victoire"), "defeat": tr("Défaite"), "fled": tr("Fuite")}.get(result["outcome"], "")
	_show_result(result)


func _refresh_sheet() -> void:
	var ch := Game.life.character
	portrait.texture = ArtProvider.portrait(ch)
	name_label.text = ch.name
	sheet_text.text = CharacterSheet.bbcode(ch) + CharacterSheet.companions_bbcode(Game.life)


# --- Utilitaires -------------------------------------------------------------

func _clear_choices() -> void:
	_event_on_screen = {}
	for child in choices_box.get_children():
		choices_box.remove_child(child)
		child.queue_free()


func _add_choice(text: String, callback: Callable, enabled := true) -> Button:
	var button := Button.new()
	button.text = "%d. %s" % [choices_box.get_child_count() + 1, text]
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.disabled = not enabled
	button.pressed.connect(callback, CONNECT_DEFERRED)
	choices_box.add_child(button)
	_fit_choices.call_deferred()
	return button


## La zone des choix prend la hauteur de son contenu, sans dépasser MAX_CHOICES_HEIGHT (elle défile alors).
func _fit_choices() -> void:
	choices_scroll.custom_minimum_size.y = mini(int(choices_box.get_combined_minimum_size().y), MAX_CHOICES_HEIGHT)
	choices_scroll.scroll_vertical = 0


# --- Mode debug --------------------------------------------------------------

func _setup_debug_badge() -> void:
	_debug_badge.text = tr("DEBUG (F12)")
	_debug_badge.add_theme_color_override("font_color", UITheme.BAD)
	_debug_badge.add_theme_font_size_override("font_size", 15)
	var badge_box := StyleBoxFlat.new()
	badge_box.bg_color = Color(0.08, 0.06, 0.05, 0.9)
	badge_box.border_color = UITheme.BAD
	badge_box.set_border_width_all(1)
	badge_box.set_content_margin_all(6)
	_debug_badge.add_theme_stylebox_override("normal", badge_box)
	_debug_badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 34)
	_debug_badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_debug_badge.visible = Game.debug
	add_child(_debug_badge)


func _on_debug_changed() -> void:
	_debug_badge.visible = Game.debug
	if not _event_on_screen.is_empty():
		_show_event_choices(_event_on_screen)
