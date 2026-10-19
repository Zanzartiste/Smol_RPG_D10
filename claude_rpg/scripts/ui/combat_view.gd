class_name CombatView
extends VBoxContainer
## Écran de combat : champ de bataille, journal et barre d'actions du personnage actif.
## Usage : `var result = await combat_view.run(spec, background)`. Le résultat est celui de
## Game.finish_combat() (même format qu'un résultat d'événement).
##
## Au tour d'un personnage (héros ou compagnon), le joueur choisit UNE action : une action de classe
## (puis sa cible si besoin, en cliquant sur le champ de bataille), un objet, la fuite, ou passer.
## Certaines actions (Fougue) en donnent une de plus : le tour continue tant qu'il en reste.
## Les créatures (ennemis, invocations) jouent seules. Quand l'une d'elles attaque un personnage du joueur
## qui a gardé des actions, le joueur choisit sa réaction : contre-attaquer (avant le jet), esquiver (si
## l'attaque touche), parer (avant les dégâts) — sauf si l'IA joue ce personnage.
## Les étapes du combat (Combat.stream) sont animées au fil de l'eau, y compris avant un choix de réaction.
## Les actions sont rangées par catégorie (Attaques, Sorts, Capacités, Objets, Lancer).
## Raccourcis : 1-9 pour les actions (et les réactions), Tab change de catégorie, Échap annule le ciblage ;
## une touche accélère les dés.

signal _turn_finished
signal _reaction_chosen(react: bool)

const LOG_LINES := 6
const CATEGORIES := ["attacks", "spells", "abilities", "items", "throw"]
const CATEGORY_NAMES := {"attacks": "Attaques", "spells": "Sorts", "abilities": "Capacités", "items": "Objets", "throw": "Lancer"}

@onready var background: TextureRect = %Background
@onready var battle: BattleView = %Battle
@onready var dice_tray: DiceTray = %CombatDice
@onready var turn_label: Label = %TurnLabel
@onready var log_text: RichTextLabel = %LogText
@onready var hint_label: Label = %HintLabel
@onready var action_bar: VBoxContainer = %ActionBar

var combat: Combat
var _actor: Combatant  # personnage contrôlé par le joueur dont c'est le tour (null sinon)
var _busy := false  # une animation est en cours : pas d'entrée joueur
var _pending := {}  # action en attente de cible : {"kind": "action"|"item", "action"/"item"}
var _log_shown := 0
var _stream_pos := 0  # étapes de Combat.stream déjà animées
var _reaction := {}  # réaction en attente du joueur : {"target", "kind", "info"}
var _catcher: ClickCatcher  # attente d'un clic (rythme du combat), null sinon
var _action_buttons: Array[Button] = []  # choix numérotés (1-9) de la catégorie ouverte, ou réactions
var _entries := {}  # catégorie -> choix (voir _collect_entries)
var _category := "attacks"  # catégorie ouverte, gardée d'un tour à l'autre
var _tab_buttons := {}
var _entries_row: HFlowContainer


func _ready() -> void:
	battle.target_chosen.connect(_on_target_chosen)


## Joue un combat jusqu'au bout et retourne son résultat (voir Game.finish_combat).
func run(spec: Dictionary, background_texture: Texture2D) -> Dictionary:
	combat = Game.start_combat(spec)
	combat.reaction_chooser = _choose_reaction
	background.texture = background_texture
	battle.show_combat(combat)
	_log_shown = combat.log.size()
	_stream_pos = combat.stream.size()
	_refresh()
	var paced: bool = Meta.settings.get("click_to_continue_combat", true)
	dice_tray.hold = paced
	await dice_tray.play(combat.initiative_roll, true)  # tous les dés d'initiative en même temps
	while not combat.is_over():
		var actor := combat.current()
		_refresh()
		combat.start_turn()
		await _play_stream()
		if combat.is_over():
			break
		if not combat.skipped:
			if actor.is_player_controlled() and actor.is_auto():
				await get_tree().create_timer(0.3).timeout
				await combat.auto_turn(actor)
				await _play_stream()
			elif actor.is_player_controlled():
				_actor = actor
				_refresh()
				await _turn_finished
				_actor = null
				_cancel_pending()
			else:
				if paced:
					await _wait_click(tr("Au tour de %s — cliquez pour continuer") % actor.name)
				else:
					await get_tree().create_timer(0.45).timeout
				await combat.ai_turn(actor)
				await _play_stream()
		combat.end_turn()
	_log_shown = combat.log.size()
	_refresh()
	dice_tray.hold = false
	await get_tree().create_timer(0.8).timeout
	return Game.finish_combat()


## Attend un clic n'importe où (ou Entrée / Espace), comme pour les dés : rythme du combat
## (option click_to_continue_combat). Le texte s'affiche en bas de l'écran.
func _wait_click(text: String) -> void:
	var catcher := ClickCatcher.new()
	catcher.top_level = true  # hors de la mise en page du conteneur : couvre tout l'écran de combat
	catcher.position = global_position
	catcher.size = size
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", UITheme.GOLD)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	label.position.y -= 140
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	catcher.add_child(label)
	add_child(catcher)
	_catcher = catcher
	await catcher.clicked
	_catcher = null
	catcher.queue_free()


## Un clic n'importe où sur l'écran de combat fait avancer : dés en cours, puis « cliquez pour continuer ».
func _input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT or not is_visible_in_tree():
		return
	var hovered := get_viewport().gui_get_hovered_control()
	if hovered == null or not (hovered == self or is_ancestor_of(hovered)):
		return  # clic sur le tiroir ou une fenêtre par-dessus
	if dice_tray.is_playing():
		dice_tray.skip()
		get_viewport().set_input_as_handled()
	elif _catcher != null:
		get_viewport().set_input_as_handled()
		_catcher.clicked.emit()


## Couche invisible plein écran qui attend un clic ou une touche de validation.
class ClickCatcher extends Control:
	signal clicked

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP  # bloque les boutons en dessous ; le clic passe par CombatView._input

	func _unhandled_input(event: InputEvent) -> void:
		if event.is_action_pressed("ui_accept"):
			get_viewport().set_input_as_handled()
			clicked.emit()


# --- Affichage ---------------------------------------------------------------

func _refresh() -> void:
	battle.refresh()
	if combat.is_over():
		turn_label.text = {"victory": tr("Victoire !"), "defeat": tr("Défaite…"), "fled": tr("Fuite")}.get(combat.outcome, "")
	else:
		turn_label.text = tr("Round %d — au tour de %s") % [combat.round_number, combat.current().name]
	var lines := combat.log.slice(maxi(0, _log_shown - LOG_LINES), _log_shown)
	log_text.text = "\n".join(PackedStringArray(lines))
	if not _reaction.is_empty():
		hint_label.text = _reaction_text()
	elif not _pending.is_empty():
		hint_label.text = tr("Choisissez une cible sur le champ de bataille (Échap pour annuler).")
	elif _actor != null and not _busy:
		hint_label.text = tr("%s : %d action(s) restante(s) ; celles gardées serviront à se défendre") % [_actor.name,
			maxi(0, combat.actions_left)]
	else:
		hint_label.text = ""
	_fill_action_bar()


## Barre d'actions en deux lignes : les catégories (Attaques, Sorts, Capacités, Objets, Lancer) avec Fuir, IA et Fin du
## tour, puis les choix de la catégorie ouverte. Survoler une catégorie l'ouvre (souris) ; un clic aussi (tactile).
func _fill_action_bar() -> void:
	_clear(action_bar)
	_action_buttons.clear()
	_tab_buttons.clear()
	_entries = {}
	_entries_row = null
	if not _reaction.is_empty():
		_entries_row = _row()
		_fill_reaction_bar()
		return
	if _actor == null or combat.is_over():
		return
	var enabled := not _busy
	_entries = _collect_entries(enabled)
	if _entries[_category].is_empty():
		for cat: String in CATEGORIES:
			if not _entries[cat].is_empty():
				_category = cat
				break
	var tabs := _row()
	for cat: String in CATEGORIES:
		var tab := Button.new()
		tab.text = tr(CATEGORY_NAMES[cat])
		tab.toggle_mode = true
		tab.button_pressed = cat == _category
		tab.disabled = _entries[cat].is_empty()
		tab.custom_minimum_size.x = 104
		tab.pressed.connect(_show_category.bind(cat), CONNECT_DEFERRED)
		tab.mouse_entered.connect(_show_category.bind(cat))
		tabs.add_child(tab)
		_tab_buttons[cat] = tab
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_child(spacer)
	if combat.can_flee_now(_actor):
		_button(tr("Fuir (%d %%)") % roundi(combat.flee_chance(_actor) * 100), _on_flee_pressed, enabled, tabs)
	var auto := _button(tr("IA : %s") % (tr("oui") if _actor.is_auto() else tr("non")), _on_auto_toggled, enabled, tabs)
	auto.tooltip_text = tr("Laisser l'IA jouer ce personnage (à partir de maintenant)")
	_button(tr("Fin du tour"), _on_pass_pressed, enabled, tabs)
	_entries_row = _row()
	_fill_entries()


## Choix de chaque catégorie : {"title", "details", "tooltip", "enabled", "call"}.
func _collect_entries(enabled: bool) -> Dictionary:
	var result := {}
	for cat: String in CATEGORIES:
		result[cat] = []
	for choice in combat.action_choices(_actor):
		var action: Dictionary = choice["action"]
		var cat := "abilities"
		if Spellcasting.is_spell(action):
			cat = "spells"
		elif action.get("effects", []).any(func(e): return e.get("type") == "attack"):
			cat = "attacks"
		var parts := _action_label(_actor, action)
		result[cat].append({"title": parts[0], "details": parts[1] if choice["available"] else choice["reason"],
			"tooltip": "%s\n%s" % [action.get("description", ""), Actions.text_of(action["id"])],
			"enabled": enabled and choice["available"], "call": _on_action_pressed.bind(action)})
	var can_throw := combat.actions_left > 0 and not combat.living("enemy").is_empty()
	var throwables := combat.throwables(_actor)
	for i in throwables.size():
		var entry: Dictionary = throwables[i]
		var weapon := Combat.throw_weapon(entry["id"])
		result["throw"].append({
			"title": entry["name"] + (tr(" (en main)") if entry["slot"] != "" else " ×%d" % entry["count"]),
			"details": Equipment.damage_text(Equipment.weapon_damage(weapon)) + (tr(", improvisée") if weapon != entry["id"] else ""),
			"tooltip": tr("Lancer un objet ou l'arme tenue (une action). Ce qui n'est pas fait pour être lancé compte comme une arme improvisée ; l'objet est perdu jusqu'à la fin du combat, et ramassé après une victoire."),
			"enabled": enabled and can_throw, "call": _on_throw_chosen.bind(i)})
	var items := combat.usable_items()
	for i in items.size():
		var item: Dictionary = items[i]["item"]
		result["items"].append({"title": "%s ×%d" % [item["name"], items[i]["count"]], "details": "",
			"tooltip": Items.description_of(item["id"]), "enabled": enabled, "call": _on_item_chosen.bind(i)})
	return result


## Ouvre une catégorie (survol ou clic) sans reconstruire les onglets.
func _show_category(cat: String) -> void:
	if _entries_row == null or not _reaction.is_empty() or _entries.get(cat, []).is_empty():
		return
	for other: String in _tab_buttons:
		_tab_buttons[other].set_pressed_no_signal(other == cat)
	if cat == _category:
		return
	_category = cat
	_fill_entries()


func _fill_entries() -> void:
	_clear(_entries_row)
	_action_buttons.clear()
	for entry: Dictionary in _entries[_category]:
		var text := "%d. %s" % [_action_buttons.size() + 1, entry["title"]]
		if entry["details"] != "":
			text += "\n" + entry["details"]
		var button := _button(text, entry["call"], entry["enabled"], _entries_row)
		button.tooltip_text = entry["tooltip"]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.x = 210
		button.add_theme_font_size_override("font_size", 14)
		_action_buttons.append(button)


## Titre et détails d'une action, ex. « Attaque (Épée longue) » / « tranchant 2d10 ≤ 8, toucher 2d10 ≤ 7 »,
## « Projectile magique [coût 1 · 2/4] » / « force 3d10 ≤ 6 ».
func _action_label(actor: Combatant, action: Dictionary) -> Array[String]:
	var title: String = action["name"]
	var details := ""
	for e: Dictionary in action.get("effects", []):
		if e.get("type") in ["attack", "damage"]:
			if e.get("weapon") is bool and e.get("weapon"):
				title += " (%s)" % Equipment.name_of(actor.character.weapon_id())
			var type := actor.damage_type(e)
			var attack := actor.attack_pool(e) if e.get("type") == "attack" else {}
			var damage := actor.damage_pool(e, attack)
			details = "%s%s" % [(DamageTypes.name_of(type).to_lower() + " ") if type != "" else "",
				Dice.pool_text(int(damage["count"]), int(damage["threshold"]))]
			for part: Dictionary in actor.bonus_damage(e):
				details += " + %s %s" % [DamageTypes.name_of(part["damage_type"]).to_lower(),
					Dice.pool_text(int(part.get("dice", 1)), int(part.get("threshold", 5)))]
			if not attack.is_empty():
				details += tr(", toucher %s") % Dice.pool_text(int(attack["count"]), int(attack["threshold"]))
			break
	var key := actor.resource_key(action)
	if key != "":
		var left := int(actor.character.resources.get(key, 0))
		if Spellcasting.is_slot(key):
			title += tr(" [coût %d · %d/%d]") % [Spellcasting.cost_of(action), left, actor.character.max_resource(key)]
		else:
			title += " [%d/%d]" % [left, actor.character.max_resource(key)]
	if action.has("per_combat"):
		title += " [%d/%d]" % [int(actor.uses.get(action["id"], 0)), int(action["per_combat"])]
	return [title, details]


func _row() -> HFlowContainer:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 6)
	action_bar.add_child(row)
	return row


func _clear(container: Container) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _button(text: String, on_pressed: Callable, enabled: bool, parent: Container = null) -> Button:
	var button := Button.new()
	button.text = text
	button.disabled = not enabled
	button.pressed.connect(on_pressed, CONNECT_DEFERRED)
	(parent if parent != null else _entries_row).add_child(button)
	return button


## Anime les étapes du combat pas encore montrées (Combat.stream) : jets de dés, journal, PV.
func _play_stream() -> void:
	_busy = true
	_refresh()
	while _stream_pos < combat.stream.size():
		var beat: Dictionary = combat.stream[_stream_pos]
		_stream_pos += 1
		if not beat["roll"].is_empty():
			await dice_tray.play(beat["roll"], beat["fast"])
		_log_shown += 1
		_refresh()
	_log_shown = combat.log.size()
	_busy = false
	_refresh()


## Joue une action du personnage actif (`action_call` : perform, use_item ou flee liés à leurs arguments),
## anime le résultat, puis termine son tour s'il ne peut plus agir.
func _act(action_call: Callable) -> void:
	_busy = true
	_refresh()
	await action_call.call()
	await _play_stream()
	if not combat.can_act_again():
		_turn_finished.emit()


# --- Réactions ---------------------------------------------------------------

## Appelé par le combat quand un personnage du joueur peut réagir : on montre d'abord ce qui s'est passé,
## puis on attend son choix.
func _choose_reaction(target: Combatant, kind: String, info: Dictionary) -> bool:
	await _play_stream()
	_reaction = {"target": target, "kind": kind, "info": info}
	_refresh()
	var react: bool = await _reaction_chosen
	_reaction = {}
	_refresh()
	return react


## Texte de la réaction proposée.
func _reaction_text() -> String:
	var target: Combatant = _reaction["target"]
	var info: Dictionary = _reaction["info"]
	var attacker: Combatant = info["attacker"]
	var left := tr("%d réaction(s)") % target.reactions
	match _reaction["kind"]:
		"counter":
			var counter: Dictionary = info["counter"]
			var attack: Dictionary = info["attack"]
			return tr("%s attaque %s. Contre-attaquer ? Opposition %s contre %s ; le perdant ne peut pas se défendre (%s).") % [
				attacker.name, target.name, Dice.pool_text(counter["count"], counter["threshold"]),
				Dice.pool_text(attack["count"], attack["threshold"]), left]
		"dodge":
			return tr("%s touche %s : %d succès contre %d. Esquiver avec %s ? (%s)") % [attacker.name, target.name,
				info["successes"], info["difficulty"], Dice.pool_text(info["dodge"]["count"], info["dodge"]["threshold"]), left]
		"parry":
			return tr("%s va subir %d dégâts de %s. Parer avec %s ? Chaque succès retire un point (%s).") % [target.name,
				info["damage"], attacker.name, Dice.pool_text(info["parry"]["count"], info["parry"]["threshold"]), left]
		"counterspell":
			return tr("%s lance %s. Contrer le sort ? Opposition %s contre %s ; il faut plus de succès que lui (%s).") % [
				attacker.name, info["spell"], Dice.pool_text(info["counter"]["count"], info["counter"]["threshold"]),
				Dice.pool_text(info["caster_pool"]["count"], info["caster_pool"]["threshold"]), left]
	return ""


## Deux boutons : réagir ou non.
func _fill_reaction_bar() -> void:
	var info: Dictionary = _reaction["info"]
	var yes := ""
	var no := ""
	match _reaction["kind"]:
		"counter":
			yes = tr("Contre-attaquer")
			no = tr("Laisser venir")
		"dodge":
			# Chance d'éviter le coup : il faut plus de succès que ceux au-delà de la difficulté.
			var need := int(info["successes"]) - int(info["difficulty"]) + 1
			yes = tr("Esquiver (%d %% de l'éviter)") % roundi(Dice.chance(info["dodge"]["count"], info["dodge"]["threshold"], need) * 100)
			no = tr("Ne pas esquiver")
		"parry":
			# Bouclier ou arme : le joueur choisit avec quoi parer.
			var options: Array = info.get("options", [])
			if options.size() > 1:
				var target: Combatant = _reaction["target"]
				for i in options.size():
					target.parry_choice = options[i]
					var pool := target.parry_pool(combat.target_prepared_bonus(target))
					target.parry_choice = ""
					_action_buttons.append(_button("%d. %s" % [i + 1, tr("Parer avec %s (%s)") % [Combatant.parry_item_name(options[i]),
						Dice.pool_text(pool["count"], pool["threshold"])]], _on_parry_with.bind(options[i]), true))
				_action_buttons.append(_button("%d. %s" % [options.size() + 1, tr("Encaisser")], _on_reaction.bind(false), true))
				return
			yes = tr("Parer")
			no = tr("Encaisser")
		"counterspell":
			yes = tr("Contrer le sort")
			no = tr("Laisser faire")
	_action_buttons.append(_button("1. " + yes, _on_reaction.bind(true), true))
	_action_buttons.append(_button("2. " + no, _on_reaction.bind(false), true))


func _on_parry_with(item: String) -> void:
	if not _reaction.is_empty():
		_reaction["target"].parry_choice = item
		_reaction_chosen.emit(true)


func _on_reaction(react: bool) -> void:
	if not _reaction.is_empty():
		_reaction_chosen.emit(react)


# --- Choix du joueur ---------------------------------------------------------

func _on_action_pressed(action: Dictionary) -> void:
	if _actor == null or _busy:
		return
	var target: String = action.get("target", "enemy")
	if target in CombatEffects.CHOSEN_TARGETS:
		_ask_target({"kind": "action", "action": action}, combat.targets(_actor, target))
	else:
		_act(combat.perform.bind(_actor, action))


func _on_item_chosen(menu_index: int) -> void:
	var items := combat.usable_items()
	if _actor != null and not _busy and menu_index < items.size():
		var item: Dictionary = items[menu_index]["item"]
		_ask_target({"kind": "item", "item": item["id"]}, combat.targets(_actor, item["use"].get("target", "ally")))


func _on_throw_chosen(menu_index: int) -> void:
	var throwables := combat.throwables(_actor) if _actor != null else []
	if _actor != null and not _busy and menu_index < throwables.size():
		_ask_target({"kind": "throw", "choice": throwables[menu_index]}, combat.targets(_actor, "enemy"))


## Demande une cible ; s'il n'y en a qu'une, l'action est jouée directement.
func _ask_target(pending: Dictionary, candidates: Array[Combatant]) -> void:
	if candidates.is_empty():
		return
	if candidates.size() == 1:
		_execute(pending, candidates[0])
		return
	_pending = pending
	battle.set_targetable(candidates)
	_refresh()


func _on_target_chosen(target: Combatant) -> void:
	if _pending.is_empty() or _busy:
		return
	var pending := _pending
	_cancel_pending()
	_execute(pending, target)


func _execute(pending: Dictionary, target: Combatant) -> void:
	match pending["kind"]:
		"action":
			_act(combat.perform.bind(_actor, pending["action"], target))
		"item":
			_act(combat.use_item.bind(_actor, pending["item"], target))
		"throw":
			_act(combat.throw_item.bind(_actor, pending["choice"], target))


func _cancel_pending() -> void:
	_pending = {}
	battle.set_targetable([])
	_refresh()


func _on_flee_pressed() -> void:
	if _actor != null and not _busy:
		_act(combat.flee.bind(_actor))


func _on_auto_toggled() -> void:
	if _actor == null or _busy:
		return
	_actor.character.auto_combat = not _actor.character.auto_combat
	if _actor.character.auto_combat:
		_busy = true
		await combat.auto_turn(_actor)
		await _play_stream()
		_turn_finished.emit()
	else:
		_refresh()


func _on_pass_pressed() -> void:
	if _actor != null and not _busy:
		_cancel_pending()
		_turn_finished.emit()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or not is_visible_in_tree():
		return
	if dice_tray.is_playing():
		dice_tray.skip()
	elif key.keycode == KEY_ESCAPE:
		_cancel_pending()
	elif key.keycode == KEY_TAB and not _entries.is_empty():
		var open: Array = CATEGORIES.filter(func(c): return not _entries[c].is_empty())
		if not open.is_empty():
			_show_category(open[(open.find(_category) + 1) % open.size()])
	elif key.keycode >= KEY_1 and key.keycode <= KEY_9:
		var index: int = key.keycode - KEY_1
		if index < _action_buttons.size() and not _action_buttons[index].disabled:
			_action_buttons[index].pressed.emit()
	else:
		return
	accept_event()
