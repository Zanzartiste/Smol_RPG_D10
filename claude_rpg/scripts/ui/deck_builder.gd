extends Control
## Composition du deck : la collection à gauche (+/- pour chaque carte), l'aperçu de la carte
## survolée et les statistiques du deck à droite (taille, couleurs, courbe de mana).
## Le deck doit compter au moins rules.json › combat.deck_min_size cartes.

const MAIN_SCENE := "res://scenes/main.tscn"

@onready var card_list: VBoxContainer = %CardList
@onready var preview: CardView = %Preview
@onready var stats_text: RichTextLabel = %StatsText
@onready var curve_holder: Control = %Curve
@onready var all_button: Button = %AllButton
@onready var done_button: Button = %DoneButton

var _character: Character
var _rows := {}  # id de carte -> {count, minus, plus}
var _curve := CurveView.new()


## Petit contrôle qui dessine un coût en pastilles de mana.
class CostView extends Control:
	var cost := ""

	func _draw() -> void:
		ManaIcons.draw_cost(self, Vector2(size.x, size.y / 2.0), 7.0, cost, get_theme_default_font())


## Courbe de mana : nombre de cartes du deck par valeur de mana (0 à 5+).
class CurveView extends Control:
	var counts: Array[int] = [0, 0, 0, 0, 0, 0]

	func _draw() -> void:
		var font := get_theme_default_font()
		var top := 1
		for n in counts:
			top = maxi(top, n)
		var w := size.x / counts.size()
		for i in counts.size():
			var h := (size.y - 18) * counts[i] / float(top)
			draw_rect(Rect2(i * w + 4, size.y - 16 - h, w - 8, h), UITheme.GOLD.darkened(0.2))
			var label := str(i) if i < counts.size() - 1 else "%d+" % i
			draw_string(font, Vector2(i * w + w / 2 - 6, size.y - 2), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UITheme.TEXT_DIM)
			if counts[i] > 0:
				draw_string(font, Vector2(i * w + w / 2 - 6, size.y - 20 - h), str(counts[i]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UITheme.TEXT)


func _ready() -> void:
	theme = UITheme.build()
	if Game.life == null:
		Game.new_life()  # scène lancée directement
	_character = Game.life.character
	curve_holder.add_child(_curve)
	_curve.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	all_button.pressed.connect(_on_all_pressed)
	done_button.pressed.connect(_on_done_pressed)
	_build_list()
	_refresh()


func _build_list() -> void:
	var ids: Array = _character.collection.keys()
	ids.sort_custom(_by_cost_then_name)
	for card_id: String in ids:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		row.mouse_entered.connect(_show_preview.bind(card_id))
		var cost := CostView.new()
		cost.cost = Cards.cost_of(card_id)
		cost.custom_minimum_size = Vector2(64, 22)
		cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(cost)
		var name_label := Label.new()
		name_label.text = "%s — %s" % [Cards.name_of(card_id), Cards.type_name(card_id)]
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.mouse_filter = Control.MOUSE_FILTER_PASS
		name_label.mouse_entered.connect(_show_preview.bind(card_id))
		row.add_child(name_label)
		var minus := _small_button("−", _change.bind(card_id, -1))
		row.add_child(minus)
		var count := Label.new()
		count.custom_minimum_size = Vector2(56, 0)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(count)
		var plus := _small_button("+", _change.bind(card_id, 1))
		row.add_child(plus)
		card_list.add_child(row)
		_rows[card_id] = {"count": count, "minus": minus, "plus": plus}
	if not ids.is_empty():
		_show_preview(ids[0])


func _by_cost_then_name(a: String, b: String) -> bool:
	if Cards.mana_value(a) != Cards.mana_value(b):
		return Cards.mana_value(a) < Cards.mana_value(b)
	return Cards.name_of(a) < Cards.name_of(b)


func _small_button(text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(36, 30)
	button.pressed.connect(on_pressed)
	return button


func _change(card_id: String, delta: int) -> void:
	_character.set_deck_count(card_id, int(_character.deck.get(card_id, 0)) + delta)
	_show_preview(card_id)
	_refresh()


func _show_preview(card_id: String) -> void:
	preview.setup(card_id)
	preview.queue_redraw()


func _on_all_pressed() -> void:
	_character.deck = _character.collection.duplicate()
	_refresh()


func _on_done_pressed() -> void:
	if _character.is_deck_valid():
		get_tree().change_scene_to_file(MAIN_SCENE)


func _refresh() -> void:
	for card_id: String in _rows:
		var row: Dictionary = _rows[card_id]
		var in_deck := int(_character.deck.get(card_id, 0))
		var owned := int(_character.collection.get(card_id, 0))
		row["count"].text = "%d / %d" % [in_deck, owned]
		row["minus"].disabled = in_deck <= 0
		row["plus"].disabled = in_deck >= owned
	var size := _character.deck_size()
	var minimum := int(Combat.setting("deck_min_size", 40))
	var gold := UITheme.GOLD.to_html(false)
	var color := (UITheme.GOOD if size >= minimum else UITheme.BAD).to_html(false)
	var t := "[color=%s]%s[/color] [color=%s]%d[/color] / %d %s\n\n" % [gold, tr("Cartes :"), color, size, minimum, tr("minimum")]
	t += "[color=%s]%s[/color]\n" % [gold, tr("Couleurs (mana généré)")]
	var shares := Mana.deck_shares(_character.deck)
	for color_id in Mana.color_ids() + [Mana.COLORLESS]:
		if shares.has(color_id):
			t += "[color=%s]●[/color] %s : %d %%\n" % [Mana.color_value(color_id).to_html(false), Mana.color_name(color_id),
				roundi(shares[color_id] * 100)]
	t += "\n[color=%s]%s[/color]" % [gold, tr("Courbe de mana")]
	stats_text.text = t
	var counts: Array[int] = [0, 0, 0, 0, 0, 0]
	for card_id: String in _character.deck:
		counts[mini(Cards.mana_value(card_id), 5)] += int(_character.deck[card_id])
	_curve.counts = counts
	_curve.queue_redraw()
	var valid := _character.is_deck_valid()
	done_button.disabled = not valid
	done_button.text = tr("Terminer") if valid else tr("Il faut au moins %d cartes") % minimum
