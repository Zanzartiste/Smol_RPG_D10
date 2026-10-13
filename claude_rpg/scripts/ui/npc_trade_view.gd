class_name NpcTradeView
extends Control
## Fenêtre d'échange avec un PNJ, à la façon de Baldur's Gate 3 : à gauche votre sac (Vendre, Offrir), à
## droite ce que propose le PNJ (Acheter, Demander gratuitement). Un PNJ marchand propose le stock de sa
## boutique et a une bourse illimitée ; un autre PNJ échange ce qu'il possède, dans la limite de son or.
## Les prix tiennent compte de la Persuasion et de l'amitié (voir Social).

signal changed
signal closed

var life: LifeState
var npc: Npc
var session: Dictionary
var _message := ""

var _gold_label := Label.new()
var _bag_box := VBoxContainer.new()
var _goods_box := VBoxContainer.new()
var _message_label := RichTextLabel.new()


func _init(life_state: LifeState, target: Npc, social_session: Dictionary) -> void:
	life = life_state
	npc = target
	session = social_session


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1060, 600)
	center.add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	panel.add_child(root)
	var header := HBoxContainer.new()
	var title := Label.new()
	title.text = tr("Échange avec %s") % npc.name
	title.theme_type_variation = &"TitleLabel"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_gold_label.add_theme_color_override("font_color", UITheme.GOLD)
	header.add_child(_gold_label)
	var close := Button.new()
	close.text = tr("Fermer (Échap)")
	close.pressed.connect(close_view, CONNECT_DEFERRED)
	header.add_child(close)
	root.add_child(header)
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 20)
	for pair in [[tr("Votre sac"), _bag_box], [tr("Ce que propose %s") % npc.name, _goods_box]]:
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var label := Label.new()
		label.text = pair[0]
		label.theme_type_variation = &"SectionLabel"
		column.add_child(label)
		var scroll := ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		pair[1].size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(pair[1])
		column.add_child(scroll)
		columns.add_child(column)
	root.add_child(columns)
	_message_label.bbcode_enabled = true
	_message_label.fit_content = true
	root.add_child(_message_label)
	refresh()


func close_view() -> void:
	closed.emit()
	queue_free()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		accept_event()
		close_view()


func refresh() -> void:
	var purse := tr("bourse de marchand") if npc.role_def().has("shop") else tr("%d po") % npc.gold
	_gold_label.text = tr("Votre or : %d po · %s : %s") % [life.character.gold, npc.name, purse]
	_clear(_bag_box)
	for item_id: String in _sorted(life.inventory().keys()):
		var row := _row(_bag_box, item_id, life.character.item_count(item_id))
		if Shops.buys("", item_id):
			_button(row, tr("Vendre (%d po)") % Social.sell_price(npc, item_id, life), _on_sell.bind(item_id))
		if not Items.is_quest(item_id):
			_button(row, tr("Offrir"), _on_gift.bind(item_id))
	var goods := Social.goods(npc, life)
	_clear(_goods_box)
	for item_id: String in _sorted(goods.keys()):
		var row := _row(_goods_box, item_id, int(goods[item_id]))
		var price := Social.buy_price(npc, item_id, life)
		var buy := _button(row, tr("Acheter (%d po)") % price, _on_buy.bind(item_id))
		buy.disabled = life.character.gold < price
		_button(row, tr("Demander"), _on_ask.bind(item_id))
	_message_label.text = _message


func _on_sell(item_id: String) -> void:
	var price := Social.sell_price(npc, item_id, life)
	_after(tr("Vendu : %s (+%d po).") % [Items.name_of(item_id), price] if Social.sell(npc, item_id, life)
		else tr("%s n'a pas assez d'or.") % npc.name)


func _on_buy(item_id: String) -> void:
	var price := Social.buy_price(npc, item_id, life)
	if Social.buy(npc, item_id, life):
		_after(tr("Acheté : %s (−%d po).") % [Items.name_of(item_id), price])


func _on_gift(item_id: String) -> void:
	var text := Social.gift(npc, item_id, life)
	if text != "":
		session["acted"] = true
		_after(text)


func _on_ask(item_id: String) -> void:
	var text := Social.ask_free(npc, item_id, life, session)
	if text != "":
		session["acted"] = true
		_after(text)


func _after(message: String) -> void:
	_message = "[color=%s]%s[/color]" % [UITheme.GOLD.to_html(false), message]
	refresh()
	changed.emit()


func _row(box: VBoxContainer, item_id: String, count: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text = "%s ×%d\n[font_size=14][color=%s]%s[/color][/font_size]" % [Items.bbcode_name(item_id), count,
		UITheme.TEXT_DIM.to_html(false), Items.summary(item_id)]
	row.add_child(label)
	box.add_child(row)
	return row


func _button(row: HBoxContainer, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(callback, CONNECT_DEFERRED)
	row.add_child(button)
	return button


func _sorted(ids: Array) -> Array:
	var result := ids.duplicate()
	result.sort_custom(func(a, b): return Items.name_of(a) < Items.name_of(b))
	return result


func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
