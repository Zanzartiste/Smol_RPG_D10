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
## Raccourcis : 1-9 pour les actions (et les réactions), Échap annule le ciblage ; une touche accélère les dés.

signal _turn_finished
signal _reaction_chosen(react: bool)

const LOG_LINES := 6

@onready var background: TextureRect = %Background
@onready var battle: BattleView = %Battle
@onready var dice_tray: DiceTray = %CombatDice
@onready var turn_label: Label = %TurnLabel
@onready var log_text: RichTextLabel = %LogText
@onready var hint_label: Label = %HintLabel
@onready var action_bar: HFlowContainer = %ActionBar

var combat: Combat
var _actor: Combatant  # personnage contrôlé par le joueur dont c'est le tour (null sinon)
var _busy := false  # une animation est en cours : pas d'entrée joueur
var _pending := {}  # action en attente de cible : {"kind": "action"|"item", "action"/"item"}
var _log_shown := 0
var _stream_pos := 0  # étapes de Combat.stream déjà animées
var _reaction := {}  # réaction en attente du joueur : {"target", "kind", "info"}
var _action_buttons: Array[Button] = []


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
	catcher.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	await catcher.clicked
	catcher.queue_free()


## Couche invisible plein écran qui attend un clic ou une touche de validation.
class ClickCatcher extends Control:
	signal clicked

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			accept_event()
			clicked.emit()

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


## Une action par bouton (avec ses dés, son bonus et ses utilisations), puis Objet, Fuir et Passer.
func _fill_action_bar() -> void:
	for child in action_bar.get_children():
		action_bar.remove_child(child)
		child.queue_free()
	_action_buttons.clear()
	if not _reaction.is_empty():
		_fill_reaction_bar()
		return
	if _actor == null or combat.is_over():
		return
	var enabled := not _busy
	for choice in combat.action_choices(_actor):
		var action: Dictionary = choice["action"]
		var label := "%d. %s" % [_action_buttons.size() + 1, _action_label(_actor, action)]
		if not choice["available"]:
			label += " (%s)" % choice["reason"]
		var button := _button(label, _on_action_pressed.bind(action), enabled and choice["available"])
		button.tooltip_text = "%s\n%s" % [action.get("description", ""), Actions.text_of(action["id"])]
		_action_buttons.append(button)
	var items := combat.usable_items()
	var item_menu := MenuButton.new()
	item_menu.text = tr("Objet")
	item_menu.flat = false
	item_menu.disabled = not enabled or items.is_empty()
	for i in items.size():
		item_menu.get_popup().add_item("%s ×%d" % [items[i]["item"]["name"], items[i]["count"]], i)
	item_menu.get_popup().id_pressed.connect(_on_item_chosen, CONNECT_DEFERRED)
	action_bar.add_child(item_menu)
	if combat.can_flee_now(_actor):
		_button(tr("Fuir (%d %%)") % roundi(combat.flee_chance(_actor) * 100), _on_flee_pressed, enabled)
	var auto := _button(tr("IA : %s") % (tr("oui") if _actor.is_auto() else tr("non")), _on_auto_toggled, enabled)
	auto.tooltip_text = tr("Laisser l'IA jouer ce personnage (à partir de maintenant)")
	_button(tr("Fin du tour"), _on_pass_pressed, enabled)


## Ex. « Attaque (Épée longue) — tranchant, 2d10 ≤ 8, toucher 2d10 ≤ 7 », « Projectile magique — force, 3d10 ≤ 6 [2/2] ».
func _action_label(actor: Combatant, action: Dictionary) -> String:
	var label: String = action["name"]
	for e: Dictionary in action.get("effects", []):
		if e.get("type") in ["attack", "damage"]:
			if e.get("weapon") is bool and e.get("weapon"):
				label += " (%s)" % Equipment.name_of(actor.character.weapon_id())
			var type := actor.damage_type(e)
			var attack := actor.attack_pool(e) if e.get("type") == "attack" else {}
			var damage := actor.damage_pool(e, attack)
			label += " — %s%s" % [(DamageTypes.name_of(type).to_lower() + " ") if type != "" else "",
				Dice.pool_text(int(damage["count"]), int(damage["threshold"]))]
			for part: Dictionary in actor.bonus_damage(e):
				label += " + %s %s" % [DamageTypes.name_of(part["damage_type"]).to_lower(),
					Dice.pool_text(int(part.get("dice", 1)), int(part.get("threshold", 5)))]
			if not attack.is_empty():
				label += tr(", toucher %s") % Dice.pool_text(int(attack["count"]), int(attack["threshold"]))
			break
	var key := actor.resource_key(action)
	if key != "":
		var left := int(actor.character.resources.get(key, 0))
		if Spellcasting.is_slot(key):
			label += tr(" [coût %d · %d/%d]") % [Spellcasting.cost_of(action), left, actor.character.max_resource(key)]
		else:
			label += " [%d/%d]" % [left, actor.character.max_resource(key)]
	if action.has("per_combat"):
		label += " [%d/%d]" % [int(actor.uses.get(action["id"], 0)), int(action["per_combat"])]
	return label


func _button(text: String, on_pressed: Callable, enabled: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.disabled = not enabled
	button.pressed.connect(on_pressed, CONNECT_DEFERRED)
	action_bar.add_child(button)
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
			yes = tr("Parer")
			no = tr("Encaisser")
		"counterspell":
			yes = tr("Contrer le sort")
			no = tr("Laisser faire")
	_action_buttons.append(_button("1. " + yes, _on_reaction.bind(true), true))
	_action_buttons.append(_button("2. " + no, _on_reaction.bind(false), true))


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
	elif key.keycode >= KEY_1 and key.keycode <= KEY_9:
		var index: int = key.keycode - KEY_1
		if index < _action_buttons.size() and not _action_buttons[index].disabled:
			_action_buttons[index].pressed.emit()
	else:
		return
	accept_event()
