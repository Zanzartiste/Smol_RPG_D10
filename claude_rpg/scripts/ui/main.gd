extends Control
## Écran principal : fiche du personnage à gauche, scène courante à droite.
## La zone de droite affiche tour à tour le hub (choix du lieu), le menu d'un lieu qui a des boutiques,
## un événement, le lancer de dés, son résultat, un combat ou la mort. L'inventaire et les boutiques
## s'ouvrent dans une fenêtre par-dessus (`_overlay`).
## Raccourcis : touches 1 à 9 pour choisir une option ; n'importe quelle touche accélère les dés ;
## F12 active ou désactive le mode debug (choix verrouillés visibles) ; Échap sauvegarde et revient au menu ;
## I ouvre l'inventaire (bouton « Inventaire » sous la fiche, hors combat).
## La partie est sauvegardée automatiquement (voir Saves), et aussi à la fermeture de la fenêtre.

const CREATION_SCENE := "res://scenes/creation.tscn"
const TITLE_SCENE := "res://scenes/title.tscn"
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
var _inventory_button := Button.new()
var _carnet_button := Button.new()
var _rest_button := Button.new()
var _last_social_session: Dictionary = {}
var _on_hub := false  # le hub est affiché (la montée de niveau ne se fait que là)
var _leveling := false  # montée de niveau en cours (ses choix s'enchaînent avant le retour au hub)
var _overlay: Control  # fenêtre ouverte par-dessus l'écran : inventaire ou boutique (null sinon)
var _event_on_screen: Dictionary = {}  # événement dont les choix sont affichés (pour les réafficher en debug)
var drawer := SideDrawer.new()  # tiroir latéral : personnage, inventaire, quêtes, relations, sorts


func _ready() -> void:
	theme = UITheme.build()
	Game.life_changed.connect(_refresh_sheet)
	Game.debug_changed.connect(_on_debug_changed)
	_setup_debug_badge()
	_inventory_button.text = tr("Inventaire (I)")
	_inventory_button.pressed.connect(open_inventory, CONNECT_DEFERRED)
	var buttons := HBoxContainer.new()
	sheet_text.get_parent().add_child(buttons)
	_inventory_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(_inventory_button)
	_carnet_button.text = tr("Carnet (C)")
	_carnet_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_carnet_button.pressed.connect(open_carnet, CONNECT_DEFERRED)
	buttons.add_child(_carnet_button)
	_rest_button.pressed.connect(_on_rest, CONNECT_DEFERRED)
	_rest_button.tooltip_text = tr("Repos long jusqu'au matin, selon le lieu (touche R)")
	sheet_text.get_parent().add_child(_rest_button)
	# La fiche, l'inventaire et le carnet vivent dans le tiroir latéral : plus de colonne de gauche (les
	# raccourcis I, C et R restent ; le repos est aussi proposé au hub et dans chaque lieu).
	sheet_text.get_parent().get_parent().visible = false
	$Margin.add_theme_constant_override("margin_right", 16 + int(SideDrawer.TAB_WIDTH))  # place des onglets
	if Game.life == null or Game.life.dead:
		if not Saves.load_life():
			Game.new_life()  # scène lancée directement, sans sauvegarde ni création
	drawer.life = Game.life
	drawer.inventory_requested.connect(open_inventory)
	drawer.carnet_requested.connect(open_carnet)
	drawer.level_up_requested.connect(_on_level_up_requested)
	add_child(drawer)
	_refresh_sheet()
	_show_hub()
	# Un combat interrompu (jeu fermé pendant la bataille) reprend immédiatement.
	if not Game.life.pending_combat.is_empty():
		_run_combat.call_deferred(Game.life.pending_combat)
	if not DB.errors.is_empty():
		body_text.text += "\n\n[color=%s]%s\n%s[/color]" % [
			UITheme.BAD.to_html(false), tr("Erreurs dans les données :"), "\n".join(PackedStringArray(DB.errors))]


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or _overlay != null:
		return
	# Raccourcis du tiroir (P, Q, J, E, M, N ; Échap replie une page épinglée), même en combat.
	if not dice_tray.is_playing() and drawer.handle_key(key.keycode):
		accept_event()
		return
	if combat_view.visible:
		return
	if key.keycode == KEY_I and not dice_tray.is_playing():
		open_inventory()
		accept_event()
		return
	if key.keycode == KEY_R and not dice_tray.is_playing():
		_on_rest()
		accept_event()
		return
	if key.keycode == KEY_C and not dice_tray.is_playing():
		open_carnet()
		accept_event()
		return
	if key.keycode == KEY_F12:
		Game.toggle_debug()
		accept_event()
		return
	if key.keycode == KEY_ESCAPE and not dice_tray.is_playing():
		_on_menu()
		accept_event()
		return
	if dice_tray.is_playing():
		dice_tray.skip()
		accept_event()
		return
	var index: int = key.keycode - KEY_1
	if index >= 0 and index < choices_box.get_child_count():
		var child := choices_box.get_child(index)
		var button := (child if child is Button else child.get_child(0)) as Button
		if not button.disabled:
			button.pressed.emit()
			accept_event()


# --- Écrans ------------------------------------------------------------------

## Bouton « Monter de niveau » de la fiche : seulement depuis le hub (pas au milieu d'un événement).
func _on_level_up_requested() -> void:
	if not _on_hub:
		Game.life.notices.append(tr("Vous monterez de niveau de retour en ville."))
		return
	drawer.close()
	_leveling = true
	_show_hub()


func _show_hub() -> void:
	# Montée de niveau demandée : ses choix s'enchaînent, membre par membre, puis retour au hub.
	Saves.save_all()
	_on_hub = false
	for member in Game.life.party() if _leveling else []:
		if member.pending_class_levels > 0:
			_show_class_level_choice(member)
			return
		var pending := member.pending_choice()
		if not pending.is_empty():
			_show_pending_choice(member, pending)
			return
		if member.can_increase_ability():
			_show_ability_choice(member)
			return
		if member.can_choose_feat():
			_show_feat_choice(member)
			return
		if member.can_spend_skill_point():
			_show_skill_point_choice(member)
			return
	_leveling = false
	drawer.refresh()
	var life := Game.life
	var visit := Social.initiative_event(life)  # un PNJ vient parfois vous voir
	if not visit.is_empty():
		_show_event(visit)
		return
	illustration.texture = ArtProvider.location_image("town", life)
	title_label.text = tr("Jour %d — %s — %s") % [life.day, life.slot_name(), Weather.describe(life.day)]
	var text := ""
	for notice in life.take_notices():
		text += "[color=%s]• %s[/color]\n" % [UITheme.GOLD.to_html(false), notice]
	body_text.text = text + tr("Où souhaitez-vous aller ?")
	_clear_choices()
	for loc_id in DB.location_order:
		var loc: Dictionary = DB.locations[loc_id]
		_add_choice("%s — %s" % [loc["name"], loc.get("description", "")], _on_location_chosen.bind(loc_id))
	_add_choice("%s (R)" % Game.rest_name(), _on_rest)
	_on_hub = true

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
	var show_locked: bool = Game.debug or Meta.settings.get("show_locked_choices", false)
	for entry in EventEngine.visible_choices(ev, life, Meta, show_locked):
		var choice: Dictionary = entry["choice"]
		var label := Loc.fill(Loc.t("evt.%s.%s.text" % [ev["id"], choice["id"]], choice.get("text", "")), life)
		if choice.has("check"):
			var parts := PackedStringArray()
			if Meta.settings.get("show_check_skill", true):
				parts.append(Dice.label(choice["check"]))
			if Meta.settings.get("show_check_chance", true):
				parts.append("%d %%" % roundi(Dice.success_chance(life.character, choice["check"]) * 100))
			if not parts.is_empty():
				label += "   [%s]" % " — ".join(parts)
		if not entry["available"]:
			label += "   (%s)" % entry["reason"]
		var button := _add_choice(label, _on_choice.bind(choice), entry["available"])
		if entry["available"] and choice.has("check") and Meta.settings.get("manual_skill_ability", false):
			_add_ability_buttons(button, choice)


## Option « choisir l'attribut » : de petits boutons, un par attribut possible, accolés au choix ;
## le choix lui-même utilise le meilleur attribut.
func _add_ability_buttons(button: Button, choice: Dictionary) -> void:
	var abilities := Dice.ability_options(choice["check"])
	if abilities.is_empty():
		return
	var row := HBoxContainer.new()
	choices_box.add_child(row)
	choices_box.move_child(row, button.get_index())
	choices_box.remove_child(button)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(button)
	for ability: String in abilities:
		var check: Dictionary = choice["check"].duplicate()
		check["ability"] = ability
		var forced := choice.duplicate()
		forced["check"] = check
		var small := Button.new()
		small.text = "%s %d %%" % [Abilities.short_of(ability), roundi(Dice.success_chance(Game.life.character, check) * 100)]
		small.tooltip_text = tr("Faire le test avec : %s") % Abilities.name_of(ability)
		small.pressed.connect(_on_choice.bind(forced), CONNECT_DEFERRED)
		row.add_child(small)


func _show_result(result: Dictionary) -> void:
	var life := Game.life
	var text := Loc.fill(result["text"], life)
	var roll: Dictionary = result["roll"]
	if not roll.is_empty():
		var color := UITheme.GOOD if roll["success"] else UITheme.BAD
		text += "\n\n[color=%s]%s[/color]" % [color.to_html(false), roll["text"]]
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
	if not Meta.chronicle.is_empty():
		var earned := int(Meta.chronicle.back().get("creator_points", 0))
		body_text.text += "\n[color=%s]%s[/color]" % [UITheme.GOLD.to_html(false),
			tr("+%d Creator Points (%d XP gagnée) — total : %d") % [earned, ch.xp, Meta.creator_points]]
	_clear_choices()
	_add_choice(tr("Commencer une nouvelle vie"), _on_new_life)
	_add_choice(tr("Menu principal"), _on_menu)


## Niveau gagné : choix de la classe qui progresse (multiclassage libre).
func _show_class_level_choice(member: Character) -> void:
	illustration.texture = ArtProvider.location_image("town", Game.life)
	title_label.text = tr("Niveau %d — %s") % [member.level - member.pending_class_levels + 1, member.name]
	body_text.text = tr("%s gagne un niveau. Dans quelle classe ?") % member.name
	_clear_choices()
	for cls: String in DB.classes:
		if not Meta.is_class_available(cls) and not member.has_class(cls):
			continue
		var next := member.class_level(cls) + 1
		var gains := PackedStringArray(ClassFeatures.at_level(cls, next).map(func(f): return f["name"]))
		if Progression.is_advancement_level(next):
			gains.append(tr("amélioration"))
		var label := tr("%s niveau %d") % [DB.classes[cls]["name"], next]
		if not gains.is_empty():
			label += " — " + ", ".join(gains)
		_add_choice(label, _on_class_level_chosen.bind(member, cls))


func _on_class_level_chosen(member: Character, cls: String) -> void:
	Game.life.notices.append_array(member.assign_class_level(cls))
	_refresh_sheet()
	_show_hub()


## Un choix à faire (compétences, style de combat, sous-classe, options d'un don…), une valeur à la fois.
func _show_pending_choice(member: Character, entry: Dictionary) -> void:
	var spec: Dictionary = entry["spec"]
	var taken: Array = member.choices.get(entry["key"], [])
	var count := int(spec.get("count", 1))
	illustration.texture = ArtProvider.location_image("town", Game.life)
	title_label.text = tr("%s — %s") % [spec.get("name", entry["source"]), member.name]
	body_text.text = tr("%s (%s) : choisissez %d option(s).") % [member.name, entry["source"], count]
	if count > 1:
		body_text.text += " " + tr("Choix %d sur %d.") % [taken.size() + 1, count]
	if not taken.is_empty():
		body_text.text += "\n" + tr("Déjà choisi : %s") % member.choice_label(entry["key"])
	_clear_choices()
	for value in member.choice_options(entry["key"]):
		var description := Choices.value_description(spec, value).strip_edges()
		var label := Choices.value_name(spec, value) + (" — " + description if description != "" else "")
		var button := _add_choice(label, _on_pending_chosen.bind(member, entry["key"], value))
		button.tooltip_text = description


func _on_pending_chosen(member: Character, key: String, value: String) -> void:
	member.choose(key, value)
	_refresh_sheet()
	_show_hub()


func _show_ability_choice(member: Character) -> void:
	title_label.text = tr("Amélioration — %s") % member.name
	body_text.text = tr("%s a atteint le niveau %d : choisissez l'attribut à augmenter de 1.") % [member.name, member.level]
	if Progression.max_ability_score() > 0:
		body_text.text += " " + tr("(maximum %d)") % Progression.max_ability_score()
	_clear_choices()
	for id in Abilities.ids():
		var score := int(member.abilities[id])
		var button := _add_choice("%s : %d → %d" % [Abilities.name_of(id), score, score + 1],
			_on_ability_chosen.bind(member, id), member.can_raise(id))
		button.tooltip_text = Abilities.description_of(id)


## Point de compétence gagné en montant de niveau : +1 rang dans la compétence choisie.
func _show_skill_point_choice(member: Character) -> void:
	title_label.text = tr("Compétences — %s") % member.name
	body_text.text = tr("%s a progressé : choisissez la compétence qui gagne un rang.") % member.name
	if member.pending_skill_points > 1:
		body_text.text += " " + tr("(%d points à placer)") % member.pending_skill_points
	_clear_choices()
	for skill_id in Skills.ids():
		var rank := member.skill_rank(skill_id)
		var button := _add_choice("%s : %d → %d" % [Skills.name_of(skill_id), rank, rank + 1],
			_on_skill_point_chosen.bind(member, skill_id), member.can_raise_skill(skill_id))
		button.tooltip_text = Skills.description_of(skill_id)


func _on_skill_point_chosen(member: Character, skill_id: String) -> void:
	member.spend_skill_point(skill_id)
	_refresh_sheet()
	_show_hub()


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



## Un lieu avec des boutiques ou des habitants ouvre son menu ; les autres tirent directement un événement.
func _on_location_chosen(location_id: String) -> void:
	Game.life.location = location_id
	_refresh_sheet()
	if Shops.of_location(location_id).is_empty() and not _has_people(location_id):
		_show_event(Game.draw_event(location_id))
	else:
		_show_location_menu(location_id)


func _has_people(location_id: String) -> bool:
	return not Social.roles_in(location_id).is_empty()


## Menu d'un lieu : se promener (événement au hasard), entrer dans une boutique, ou revenir.
## Les boutiques ne font pas passer le temps.
func _show_location_menu(location_id: String) -> void:
	var loc: Dictionary = DB.locations[location_id]
	illustration.texture = ArtProvider.location_image(loc.get("art", location_id), Game.life)
	title_label.text = loc["name"]
	body_text.text = loc.get("description", "")
	_clear_choices()
	_add_choice(tr("Se promener (événement au hasard)"), _show_event_from.bind(location_id))
	if not EventEngine.gather_event(location_id).is_empty():
		_add_choice(tr("Chercher des ressources"), func(): _show_event(EventEngine.gather_event(location_id)))
	if _has_people(location_id):
		_add_choice(tr("Parler à quelqu'un"), _show_people.bind(location_id))
	for shop_id in Shops.of_location(location_id):
		_add_choice("%s — %s" % [Shops.name_of(shop_id), Shops.def(shop_id).get("description", "")],
			open_shop.bind(shop_id))
	_add_choice("%s (R)" % Game.rest_name(), _on_rest)
	_add_choice(tr("Retour"), _show_hub)


## Les gens présents dans un lieu, et la possibilité de chercher un garde, un villageois…
func _show_people(location_id: String) -> void:
	title_label.text = tr("%s — Parler à quelqu'un") % DB.locations[location_id]["name"]
	body_text.text = tr("Qui allez-vous voir ? (Les gens vont et viennent selon le moment de la journée.)")
	_clear_choices()
	for n in Social.at_location(location_id, Game.life.rng, Game.life.slot_id()):
		var label := "%s — %s" % [n.name, n.role_name()]
		if n.player.get("met", false):
			label += " (%s)" % Social.status_name(n)
		_add_choice(label, open_social.bind(n))
	for role_id in Social.searchable_roles(location_id):
		_add_choice(tr("Chercher : %s") % String(DB.npc_roles[role_id]["name"]).to_lower(), _on_search.bind(role_id))
	_add_choice(tr("Retour"), _show_location_menu.bind(location_id))


func _on_search(role_id: String) -> void:
	open_social(Social.generate(role_id, Game.life.rng))


## Conversation avec un PNJ (fenêtre par-dessus l'écran). Quitter après avoir agi fait passer un créneau.
func open_social(n: Npc) -> void:
	if not _can_open_overlay():
		return
	var view := SocialView.new(Game.life, n)
	_last_social_session = view.session
	_overlay = view
	view.changed.connect(_refresh_sheet)
	view.trade_requested.connect(_open_npc_trade.bind(view))
	view.closed.connect(_on_social_closed.bind(n.location if n.location != "party" else DB.location_order[0]))
	add_child(view)


func _open_npc_trade(n: Npc, social: SocialView) -> void:
	var trade := NpcTradeView.new(Game.life, n, social.session)
	trade.changed.connect(_refresh_sheet)
	trade.closed.connect(social.refresh)
	add_child(trade)


func _on_social_closed(acted: bool, location_id: String) -> void:
	_overlay = null
	if acted:
		Game.end_interaction(int(_last_social_session.get("extra_time", 0)))
	_refresh_sheet()
	if Game.life.dead:
		_show_death()
	else:
		_show_people(location_id)


## Repos (bouton de la fiche) : hors combat et hors fenêtre ; une nuit agitée tire un événement du lieu.
func _on_rest() -> void:
	if not _can_open_overlay() or not Game.current_event.is_empty():
		return
	var result := Game.rest()
	title_label.text = tr("Repos")
	body_text.text = result["text"]
	_refresh_sheet()
	_clear_choices()
	if result["event_location"] != "":
		_add_choice(tr("Voir ce qui se passe"), _show_event_from.bind(result["event_location"]))
	elif Game.life.dead:
		_add_choice(tr("Continuer"), _show_death)
	else:
		_add_choice(tr("Continuer"), _show_hub)


## Carnet des PNJ rencontrés.
func open_carnet() -> void:
	if _can_open_overlay():
		_open_overlay(CarnetView.new(Game.life))


func _show_event_from(location_id: String) -> void:
	_show_event(Game.draw_event(location_id))


## Pour un choix avec test, on lance et on anime les dés avant d'appliquer les effets,
## pour ne rien dévoiler (PV, or...) avant que les dés ne s'arrêtent.
func _on_choice(choice: Dictionary) -> void:
	var roll := {}
	if choice.has("check"):
		roll = Game.roll_check(choice)
		_clear_choices()
		await dice_tray.play(roll)
		# Dons « une fois par jour » en mode manuel : proposés après un échec.
		for feat_id: String in Dice.daily_feat_options(Game.life.character, roll):
			if await _ask(tr("Test raté. Utiliser %s ?") % Feats.name_of(feat_id), Feats.description_of(feat_id)):
				Dice.use_daily_feat(Game.life.character, roll, feat_id, Game.life.rng)
				await dice_tray.play(roll)
				break
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


## Sauvegarde et retour à l'écran titre. Un événement en cours sera repris depuis le hub ;
## un combat déclenché reprendra au chargement.
func _on_menu() -> void:
	if combat_view.visible:
		return
	Saves.save_all()
	get_tree().change_scene_to_file(TITLE_SCENE)


func _notification(what: int) -> void:
	# Fermeture de la fenêtre : on sauvegarde (sauf en plein combat : la sauvegarde d'avant le combat
	# le fera reprendre au chargement).
	if what == NOTIFICATION_WM_CLOSE_REQUEST and Game.life != null and combat_view != null and not combat_view.visible:
		Saves.save_all()


func _on_new_life() -> void:
	get_tree().change_scene_to_file(CREATION_SCENE)


# --- Inventaire ----------------------------------------------------------------

## Ouvre la fenêtre d'inventaire par-dessus l'écran (pas pendant un combat).
func open_inventory() -> void:
	if _can_open_overlay():
		_open_overlay(InventoryView.new(Game.life))


## Ouvre la fenêtre d'une boutique (depuis le menu de son lieu).
func open_shop(shop_id: String) -> void:
	if _can_open_overlay():
		_open_overlay(ShopView.new(Game.life, shop_id))


func _can_open_overlay() -> bool:
	return _overlay == null and not combat_view.visible and Game.life != null and not Game.life.dead


func _open_overlay(view: Control) -> void:
	drawer.close()
	_overlay = view
	view.changed.connect(_refresh_sheet)
	view.closed.connect(_on_overlay_closed)
	add_child(view)


func _on_overlay_closed() -> void:
	_overlay = null
	Saves.save_all()


# --- Combat ------------------------------------------------------------------

## Le combat se joue dans l'écran dédié (CombatView), qui remplace le contenu le temps de la bataille.
func _run_combat(spec: Dictionary) -> void:
	if _overlay != null:
		_overlay.close_view()
	_inventory_button.disabled = true
	_carnet_button.disabled = true
	_rest_button.disabled = true
	drawer.locked = true
	drawer.refresh()
	content_box.visible = false
	combat_view.visible = true
	var result: Dictionary = await combat_view.run(spec, illustration.texture)
	combat_view.visible = false
	content_box.visible = true
	_inventory_button.disabled = false
	_carnet_button.disabled = false
	_rest_button.disabled = false
	drawer.locked = false
	_refresh_sheet()
	title_label.text = {"victory": tr("Victoire"), "defeat": tr("Défaite"), "fled": tr("Fuite")}.get(result["outcome"], "")
	_show_result(result)


func _refresh_sheet() -> void:
	var ch := Game.life.character
	_rest_button.text = "%s (R)" % Game.rest_name()
	portrait.texture = ArtProvider.portrait(ch)
	name_label.text = ch.name
	drawer.life = Game.life
	drawer.refresh()


# --- Utilitaires -------------------------------------------------------------

func _clear_choices() -> void:
	_event_on_screen = {}
	_on_hub = false
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


## Question oui / non dans une fenêtre ; retourne true pour « Oui ».
func _ask(question: String, details: String) -> bool:
	var dialog := ConfirmationDialog.new()
	dialog.title = question
	dialog.dialog_text = details
	dialog.ok_button_text = tr("Oui")
	dialog.cancel_button_text = tr("Non")
	add_child(dialog)
	dialog.popup_centered()
	var answer := [false]
	dialog.confirmed.connect(func(): answer[0] = true)
	await dialog.visibility_changed
	dialog.queue_free()
	return answer[0]
