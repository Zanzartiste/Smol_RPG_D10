extends Control
## Écran principal : fiche du personnage à gauche, scène courante à droite.
## La zone de droite affiche tour à tour le hub (choix du lieu), un événement, le lancer de dés,
## son résultat, un combat ou la mort.
## Raccourcis : touches 1 à 9 pour choisir une option ; n'importe quelle touche accélère les dés ;
## F12 active ou désactive le mode debug (choix verrouillés visibles).

const CREATION_SCENE := "res://scenes/creation.tscn"
const COMBAT_LOG_LINES := 9
const MAX_CHOICES_HEIGHT := 330  # au-delà, la liste de choix défile

## Émis quand le joueur a choisi l'action (et la cible) d'un allié pendant un combat.
signal _combat_choice_made(choice: Dictionary)

@onready var portrait: TextureRect = %Portrait
@onready var name_label: Label = %NameLabel
@onready var sheet_text: RichTextLabel = %SheetText
@onready var illustration: TextureRect = %Illustration
@onready var dice_tray: DiceTray = %DiceTray
@onready var battle_view: BattleView = %BattleView
@onready var title_label: Label = %TitleLabel
@onready var body_text: RichTextLabel = %BodyText
@onready var choices_box: VBoxContainer = %Choices
@onready var choices_scroll: ScrollContainer = %ChoicesScroll

var _debug_badge := Label.new()
var _event_on_screen: Dictionary = {}  # événement dont les choix sont affichés (pour les réafficher en debug)
var _log_shown := 0  # nombre de lignes du journal de combat déjà révélées


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
	if key == null or not key.pressed or key.echo:
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
	# Un membre du groupe a gagné un don en montant de niveau : on le lui fait choisir d'abord.
	for member in Game.life.party():
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


func _on_new_life() -> void:
	get_tree().change_scene_to_file(CREATION_SCENE)


# --- Combat ------------------------------------------------------------------

## Boucle de combat : à chaque tour, le joueur choisit pour les alliés, les ennemis jouent seuls ;
## chaque étape est animée (dés, PV, journal), puis l'issue est appliquée et affichée.
func _run_combat(spec: Dictionary) -> void:
	var combat := Game.start_combat(spec)
	battle_view.show_combat(combat)
	title_label.text = tr("Combat !")
	_log_shown = combat.log.size()
	while not combat.is_over():
		var actor := combat.current()
		battle_view.refresh()
		_show_combat_log(combat)
		var choice: Dictionary
		if actor.is_ally():
			_show_action_menu(combat, actor)
			choice = await _combat_choice_made
		else:
			_clear_choices()
			await get_tree().create_timer(0.5).timeout
			choice = combat.auto_choice(actor)
		_clear_choices()
		var target: Combatant = choice.get("target")
		var hp_before := target.hp if target != null else 0
		for beat in combat.perform(actor, choice["action"], target):
			if not beat["roll"].is_empty():
				await dice_tray.play(beat["roll"], beat["fast"])
			_log_shown += 1
			_show_combat_log(combat)
			battle_view.refresh()
		if target != null and target.hp < hp_before:
			battle_view.flash(target)
		_refresh_sheet()
		combat.end_turn()
	_log_shown = combat.log.size()
	_show_combat_log(combat)
	battle_view.refresh()
	await get_tree().create_timer(0.8).timeout
	var result := Game.finish_combat()
	battle_view.hide_combat()
	title_label.text = {"victory": tr("Victoire"), "defeat": tr("Défaite"), "fled": tr("Fuite")}.get(result["outcome"], "")
	_show_result(result)


func _show_combat_log(combat: Combat) -> void:
	var header := ""
	if not combat.is_over():
		header = "[color=%s]%s[/color]\n" % [UITheme.GOLD.to_html(false),
			tr("Round %d — au tour de %s") % [combat.round_number, combat.current().name]]
	var shown := combat.log.slice(0, _log_shown)
	body_text.text = header + "\n".join(PackedStringArray(shown.slice(maxi(0, shown.size() - COMBAT_LOG_LINES))))


func _show_action_menu(combat: Combat, actor: Combatant) -> void:
	_clear_choices()
	for action in actor.actions():
		var reason := actor.unavailable_reason(action)
		var label := _action_label(actor, action)
		if reason != "":
			label += "   (%s)" % reason
		_add_choice(label, _on_action_picked.bind(combat, actor, action), reason == "")
	if not combat.usable_items().is_empty():
		_add_choice(tr("Objets…"), _show_item_menu.bind(combat, actor))
	if combat.can_flee():
		var chance := clampf((21 - (combat.flee_dc() - actor.ability_mod("dex"))) / 20.0, 0.05, 0.95)
		_add_choice(tr("Fuir   [Dextérité DD %d — %d %%]") % [combat.flee_dc(), roundi(chance * 100)],
			_combat_choice_made.emit.bind({"action": {"id": Combat.ACTION_FLEE}}))


func _action_label(actor: Combatant, action: Dictionary) -> String:
	var label: String = action["name"]
	match action.get("type"):
		"attack":
			var weapon := " (%s)" % Equipment.name_of(actor.character.weapon_id()) if action.get("damage") == "weapon" else ""
			label += "%s — %s %s, %s au toucher" % [weapon, actor.damage_expr(action),
				DamageTypes.name_of(actor.damage_type(action)).to_lower(), CharacterSheet.signed(actor.attack_bonus(action))]
		"auto":
			label += " — %s %s, touche toujours" % [actor.damage_expr(action), DamageTypes.name_of(actor.damage_type(action)).to_lower()]
		"heal":
			label += " — soigne %s" % actor.heal_expr(action)
	if action.has("cost"):
		label += tr("   [emplacements : %d / %d]") % [
			int(actor.character.resources.get(action["cost"], 0)), actor.character.max_resource(action["cost"])]
	if action.has("per_combat"):
		label += tr("   [%d / %d par combat]") % [int(actor.uses.get(action["id"], 0)), int(action["per_combat"])]
	return label


func _on_action_picked(combat: Combat, actor: Combatant, action: Dictionary) -> void:
	var candidates := combat.targets(actor, action)
	if candidates.size() == 1:
		_combat_choice_made.emit({"action": action, "target": candidates[0]})
		return
	_show_target_menu(candidates, {"action": action}, _show_action_menu.bind(combat, actor))


func _show_item_menu(combat: Combat, actor: Combatant) -> void:
	_clear_choices()
	for entry in combat.usable_items():
		var item: Dictionary = entry["item"]
		var action := {"id": Combat.ACTION_ITEM, "item": item["id"], "target": item["use"].get("target", "ally")}
		var candidates := combat.targets(actor, action)
		var pick := func():
			if candidates.size() == 1:
				_combat_choice_made.emit({"action": action, "target": candidates[0]})
			else:
				_show_target_menu(candidates, {"action": action}, _show_item_menu.bind(combat, actor))
		_add_choice("%s ×%d — %s" % [item["name"], entry["count"], item.get("description", "")], pick)
	_add_choice(tr("Retour"), _show_action_menu.bind(combat, actor))


func _show_target_menu(candidates: Array[Combatant], choice: Dictionary, back: Callable) -> void:
	_clear_choices()
	for target in candidates:
		var with_target := choice.duplicate()
		with_target["target"] = target
		_add_choice("%s — %d / %d PV, CA %d" % [target.name, target.hp, target.max_hp(), target.armor_class()],
			_combat_choice_made.emit.bind(with_target))
	_add_choice(tr("Retour"), back)


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
