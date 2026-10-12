class_name CombatView
extends VBoxContainer
## Écran de combat : champ de bataille, mana, journal, main de cartes et actions de base.
## Usage : `var result = await combat_view.run(spec, background)`. Le résultat est celui de
## Game.finish_combat() (même format qu'un résultat d'événement).
##
## Tour du héros : cliquer une carte jouable (puis sa cible si besoin), « Attaque » (arme) ou « Objet »
## (une action de base par tour), « Fuir », puis « Fin du tour ».
## Raccourcis : 1-7 pour les cartes, A attaque, Espace fin du tour, Échap annule ; une touche accélère les dés.

signal _turn_finished

const LOG_LINES := 4

@onready var background: TextureRect = %Background
@onready var battle: BattleView = %Battle
@onready var dice_tray: DiceTray = %CombatDice
@onready var turn_label: Label = %TurnLabel
@onready var mana_view: ManaView = %ManaView
@onready var deck_label: Label = %DeckLabel
@onready var log_text: RichTextLabel = %LogText
@onready var hand_view: HandView = %Hand
@onready var hint_label: Label = %HintLabel
@onready var attack_button: Button = %AttackButton
@onready var item_button: MenuButton = %ItemButton
@onready var flee_button: Button = %FleeButton
@onready var end_turn_button: Button = %EndTurnButton

var combat: Combat
var _busy := false  # une animation est en cours : pas d'entrée joueur
var _hero_turn := false
var _pending := {}  # action en attente de cible : {"kind": "card"|"attack"|"item", "index"/"item"}
var _log_shown := 0


func _ready() -> void:
	hand_view.card_pressed.connect(_on_card_pressed)
	battle.target_chosen.connect(_on_target_chosen)
	attack_button.pressed.connect(_on_attack_pressed)
	flee_button.pressed.connect(_on_flee_pressed)
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	item_button.get_popup().id_pressed.connect(_on_item_chosen)


## Joue un combat jusqu'au bout et retourne son résultat (voir Game.finish_combat).
func run(spec: Dictionary, background_texture: Texture2D) -> Dictionary:
	combat = Game.start_combat(spec)
	background.texture = background_texture
	battle.show_combat(combat)
	_log_shown = combat.log.size()
	_refresh()
	while not combat.is_over():
		var actor := combat.current()
		_refresh()
		await _play(combat.start_turn())
		if combat.is_over():
			break
		if not combat.skipped:
			if actor.is_hero():
				_hero_turn = true
				_refresh()
				await _turn_finished
				_hero_turn = false
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
	mana_view.pool = combat.mana if _hero_turn else {}
	deck_label.text = tr("Pioche %d · Défausse %d") % [combat.deck.library.size(), combat.deck.discard.size()]
	if combat.is_over():
		turn_label.text = {"victory": tr("Victoire !"), "defeat": tr("Défaite…"), "fled": tr("Fuite")}.get(combat.outcome, "")
	else:
		turn_label.text = tr("Round %d — %s") % [combat.round_number, combat.current().name]
	var lines := combat.log.slice(maxi(0, _log_shown - LOG_LINES), _log_shown)
	log_text.text = "\n".join(PackedStringArray(lines))
	var playable: Array[bool] = []
	for i in combat.deck.hand.size():
		playable.append(_hero_turn and not _busy and combat.card_unplayable_reason(i) == "")
	hand_view.show_hand(combat.deck.hand, playable, _pending.get("index", -1) if _pending.get("kind") == "card" else -1)
	var can_act := _hero_turn and not _busy
	var basic_ok := can_act and combat.basic_actions_left > 0
	attack_button.disabled = not basic_ok or combat.living("enemy").is_empty()
	attack_button.text = tr("Attaque — %s") % combat.basic_attack_name()
	item_button.disabled = not basic_ok or combat.usable_items().is_empty()
	flee_button.disabled = not can_act or not combat.can_flee()
	end_turn_button.disabled = not can_act
	_fill_item_menu()
	if _pending.is_empty():
		hint_label.text = tr("Votre tour : jouez des cartes, puis une action de base.") if can_act else ""
	else:
		hint_label.text = tr("Choisissez une cible (Échap pour annuler).")


func _fill_item_menu() -> void:
	var popup := item_button.get_popup()
	popup.clear()
	var items := combat.usable_items()
	for i in items.size():
		popup.add_item("%s ×%d" % [items[i]["item"]["name"], items[i]["count"]], i)


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
	if combat.is_over() and _hero_turn:
		_turn_finished.emit()


# --- Actions du héros --------------------------------------------------------

func _on_card_pressed(index: int) -> void:
	if not _hero_turn or _busy or combat.card_unplayable_reason(index) != "":
		return
	if _pending.get("kind") == "card" and _pending.get("index") == index:
		_cancel_pending()
		return
	var card := combat.deck.hand[index]
	var target := Cards.target_of(card)
	if target in Cards.CHOSEN_TARGETS:
		_ask_target({"kind": "card", "index": index}, combat.targets(combat.hero, target))
	else:
		_play(combat.play_card(index))


func _on_attack_pressed() -> void:
	if _hero_turn and not _busy:
		_ask_target({"kind": "attack"}, combat.targets(combat.hero, "enemy"))


func _on_item_chosen(menu_index: int) -> void:
	var items := combat.usable_items()
	if menu_index < items.size():
		var item: Dictionary = items[menu_index]["item"]
		_ask_target({"kind": "item", "item": item["id"]}, combat.targets(combat.hero, item["use"].get("target", "ally")))


## Demande une cible ; s'il n'y en a qu'une, l'action est jouée directement.
func _ask_target(action: Dictionary, candidates: Array[Combatant]) -> void:
	if candidates.is_empty():
		return
	if candidates.size() == 1:
		_execute(action, candidates[0])
		return
	_pending = action
	battle.set_targetable(candidates)
	_refresh()


func _on_target_chosen(target: Combatant) -> void:
	if _pending.is_empty() or _busy:
		return
	var action := _pending
	_cancel_pending()
	_execute(action, target)


func _execute(action: Dictionary, target: Combatant) -> void:
	match action["kind"]:
		"card":
			_play(combat.play_card(action["index"], target))
		"attack":
			_play(combat.basic_attack(target))
		"item":
			_play(combat.use_item(action["item"], target))


func _cancel_pending() -> void:
	_pending = {}
	battle.set_targetable([])
	_refresh()


func _on_flee_pressed() -> void:
	if not _hero_turn or _busy:
		return
	await _play(combat.flee())
	_turn_finished.emit()


func _on_end_turn_pressed() -> void:
	if _hero_turn and not _busy:
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
	elif key.keycode == KEY_SPACE:
		_on_end_turn_pressed()
	elif key.keycode == KEY_A:
		_on_attack_pressed()
	elif key.keycode >= KEY_1 and key.keycode <= KEY_9:
		var index: int = key.keycode - KEY_1
		if index < combat.deck.hand.size():
			_on_card_pressed(index)
	else:
		return
	accept_event()
