class_name CombatView
extends VBoxContainer
## Écran de combat : champ de bataille, journal et barre d'actions du personnage actif.
## Usage : `var result = await combat_view.run(spec, background)`. Le résultat est celui de
## Game.finish_combat() (même format qu'un résultat d'événement).
##
## Au tour d'un personnage (héros ou compagnon), le joueur choisit UNE action : une action de classe
## (puis sa cible si besoin, en cliquant sur le champ de bataille), un objet, la fuite, ou passer.
## Certaines actions (Fougue) en donnent une de plus : le tour continue tant qu'il en reste.
## Les créatures (ennemis, invocations) jouent seules.
## Raccourcis : 1-9 pour les actions, Échap annule le ciblage ; une touche accélère les dés.

signal _turn_finished

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
var _action_buttons: Array[Button] = []


func _ready() -> void:
	battle.target_chosen.connect(_on_target_chosen)


## Joue un combat jusqu'au bout et retourne son résultat (voir Game.finish_combat).
func run(spec: Dictionary, background_texture: Texture2D) -> Dictionary:
	combat = Game.start_combat(spec)
	background.texture = background_texture
	battle.show_combat(combat)
	_log_shown = combat.log.size()
	_refresh()
	await dice_tray.play(combat.initiative_roll, true)  # tous les dés d'initiative en même temps
	while not combat.is_over():
		var actor := combat.current()
		_refresh()
		await _play(combat.start_turn())
		if combat.is_over():
			break
		if not combat.skipped:
			if actor.is_player_controlled() and actor.is_auto():
				await get_tree().create_timer(0.3).timeout
				await _play(combat.auto_turn(actor))
			elif actor.is_player_controlled():
				_actor = actor
				_refresh()
				await _turn_finished
				_actor = null
				_cancel_pending()
			else:
				await get_tree().create_timer(0.45).timeout
				await _play(combat.ai_turn(actor))
		combat.end_turn()
	_log_shown = combat.log.size()
	_refresh()
	await get_tree().create_timer(0.8).timeout
	return Game.finish_combat()


# --- Affichage ---------------------------------------------------------------

func _refresh() -> void:
	battle.refresh()
	if combat.is_over():
		turn_label.text = {"victory": tr("Victoire !"), "defeat": tr("Défaite…"), "fled": tr("Fuite")}.get(combat.outcome, "")
	else:
		turn_label.text = tr("Round %d — au tour de %s") % [combat.round_number, combat.current().name]
	var lines := combat.log.slice(maxi(0, _log_shown - LOG_LINES), _log_shown)
	log_text.text = "\n".join(PackedStringArray(lines))
	if not _pending.is_empty():
		hint_label.text = tr("Choisissez une cible sur le champ de bataille (Échap pour annuler).")
	elif _actor != null and not _busy:
		hint_label.text = tr("%s : action %d · action bonus %d") % [_actor.name, maxi(0, combat.actions_left),
			maxi(0, combat.bonus_left)]
	else:
		hint_label.text = ""
	_fill_action_bar()


## Une action par bouton (avec ses dés, son bonus et ses utilisations), puis Objet, Fuir et Passer.
func _fill_action_bar() -> void:
	for child in action_bar.get_children():
		action_bar.remove_child(child)
		child.queue_free()
	_action_buttons.clear()
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
		var chance := clampf((21 - (combat.flee_dc() - _actor.check_mod("dex"))) / 20.0, 0.05, 0.95)
		_button(tr("Fuir (%d %%)") % roundi(chance * 100), _on_flee_pressed, enabled)
	var auto := _button(tr("IA : %s") % (tr("oui") if _actor.is_auto() else tr("non")), _on_auto_toggled, enabled)
	auto.tooltip_text = tr("Laisser l'IA jouer ce personnage (à partir de maintenant)")
	_button(tr("Fin du tour"), _on_pass_pressed, enabled)


## Ex. « Attaque (Épée longue) — 1d10+3 tranchant, +5 », « Projectile magique — 3d4+3 force [2/2] ».
func _action_label(actor: Combatant, action: Dictionary) -> String:
	var label: String = action["name"]
	for e: Dictionary in action.get("effects", []):
		if e.get("type") in ["attack", "damage"]:
			if e.get("weapon") is bool and e.get("weapon"):
				label += " (%s)" % Equipment.name_of(actor.character.weapon_id())
			var type := actor.damage_type(e)
			label += " — %s%s" % [actor.damage_expr(e), (" " + DamageTypes.name_of(type).to_lower()) if type != "" else ""]
			for part: Dictionary in actor.bonus_damage(e):
				label += " + %s %s" % [part["damage"], DamageTypes.name_of(part["damage_type"]).to_lower()]
			if e.get("type") == "attack":
				label += ", %s" % CharacterSheet.signed(actor.attack_bonus(e))
			break
	var key := actor.resource_key(action)
	if key != "":
		var left := int(actor.character.resources.get(key, 0))
		if Spellcasting.is_slot(key):
			label += tr(" [niv. %d : %d/%d]") % [Spellcasting.slot_level(key), left, actor.character.max_resource(key)]
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


## Anime une liste d'étapes : jets de dés, journal, PV.
func _play(beats: Array[Dictionary]) -> void:
	_busy = true
	_refresh()
	for beat in beats:
		if not beat["roll"].is_empty():
			await dice_tray.play(beat["roll"], beat["fast"])
		_log_shown += 1
		_refresh()
	_log_shown = combat.log.size()
	_busy = false
	_refresh()


## Joue l'action du personnage actif, anime le résultat, puis termine son tour (sauf s'il lui reste
## une action, ex. après Fougue).
func _act(beats: Array[Dictionary]) -> void:
	await _play(beats)
	if not combat.can_act_again():
		_turn_finished.emit()


# --- Choix du joueur ---------------------------------------------------------

func _on_action_pressed(action: Dictionary) -> void:
	if _actor == null or _busy:
		return
	var target: String = action.get("target", "enemy")
	if target in CombatEffects.CHOSEN_TARGETS:
		_ask_target({"kind": "action", "action": action}, combat.targets(_actor, target))
	else:
		_act(combat.perform(_actor, action))


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
			_act(combat.perform(_actor, pending["action"], target))
		"item":
			_act(combat.use_item(_actor, pending["item"], target))


func _cancel_pending() -> void:
	_pending = {}
	battle.set_targetable([])
	_refresh()


func _on_flee_pressed() -> void:
	if _actor != null and not _busy:
		_act(combat.flee(_actor))


func _on_auto_toggled() -> void:
	if _actor == null or _busy:
		return
	_actor.character.auto_combat = not _actor.character.auto_combat
	if _actor.character.auto_combat:
		await _play(combat.auto_turn(_actor))
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
