class_name CombatDeck
extends RefCounted
## Le deck du héros pendant un combat : bibliothèque (pioche), main et défausse.
## Quand la bibliothèque est vide, la défausse est remélangée pour en former une nouvelle.

var library: Array[String] = []
var hand: Array[String] = []
var discard: Array[String] = []
var _rng: RandomNumberGenerator
var _max_hand := 7


func _init(deck: Dictionary, rng: RandomNumberGenerator, max_hand := 7) -> void:
	_rng = rng
	_max_hand = max_hand
	for card_id: String in deck:
		for i in int(deck[card_id]):
			library.append(card_id)
	_shuffle(library)


## Pioche jusqu'à `count` cartes (sans dépasser la main maximale) ; retourne les cartes piochées.
func draw(count: int) -> Array[String]:
	var drawn: Array[String] = []
	for i in count:
		if hand.size() >= _max_hand:
			break
		if library.is_empty():
			if discard.is_empty():
				break
			library = discard.duplicate()
			discard.clear()
			_shuffle(library)
		var card: String = library.pop_back()
		hand.append(card)
		drawn.append(card)
	return drawn


## Joue la carte d'index `index` de la main : elle part à la défausse.
func play(index: int) -> String:
	var card: String = hand[index]
	hand.remove_at(index)
	discard.append(card)
	return card


func _shuffle(cards: Array[String]) -> void:
	# Mélange de Fisher-Yates avec le générateur de la vie (parties reproductibles).
	for i in range(cards.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp := cards[i]
		cards[i] = cards[j]
		cards[j] = tmp
