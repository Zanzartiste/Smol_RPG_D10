class_name HandView
extends Control
## La main du héros : cartes alignées et centrées, qui se chevauchent quand elles sont nombreuses.
## Signal `card_pressed(index)` quand le joueur clique une carte.

signal card_pressed(index: int)

const GAP := 6.0

var _cards: Array[CardView] = []


## Affiche une main. `playable[i]` indique si la carte i peut être jouée ; `selected` = index choisi (-1 sinon).
func show_hand(card_ids: Array[String], playable: Array[bool], selected := -1) -> void:
	for card in _cards:
		card.queue_free()
	_cards.clear()
	for i in card_ids.size():
		var card := CardView.new().setup(card_ids[i])
		card.playable = playable[i] if i < playable.size() else true
		card.selected = i == selected
		card.pressed.connect(card_pressed.emit.bind(i))
		add_child(card)
		_cards.append(card)
	_layout()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


func _layout() -> void:
	var n := _cards.size()
	if n == 0:
		return
	var w := CardView.CARD_SIZE.x
	var step := minf(w + GAP, (size.x - w) / maxf(1.0, n - 1)) if n > 1 else 0.0
	var total := w + step * (n - 1)
	var start := (size.x - total) / 2.0
	for i in n:
		_cards[i].position = Vector2(start + step * i, 0)
