class_name ShopView
extends Control
## Fenêtre d'une boutique ou d'un service (shops.json), ouverte depuis le menu d'un lieu.
## Onglets selon la boutique : Acheter (son stock), Vendre (le sac du groupe), Fabriquer (recettes de
## sa station) et Améliorer (forge : objets du sac et objets portés par le groupe).
## Toute la logique passe par LifeState (buy, sell, craft, upgrade) ; les prix par Shops.

signal changed  # or, sac ou équipement modifiés (pour rafraîchir la fiche)
signal closed

const TAB_NAMES := {"buy": "Acheter", "sell": "Vendre", "craft": "Fabriquer", "upgrade": "Améliorer"}

var life: LifeState
var shop_id: String
var _tab := "buy"
var _message := ""

var _gold_label := Label.new()
var _deal_label := RichTextLabel.new()
var _tabs := HBoxContainer.new()
var _list := VBoxContainer.new()
var _message_label := RichTextLabel.new()


func _init(life_state: LifeState, shop: String) -> void:
	life = life_state
	shop_id = shop
	_tab = tabs()[0]


## Onglets proposés par cette boutique.
func tabs() -> Array[String]:
	var result: Array[String] = []
	var shop := Shops.def(shop_id)
	if not shop.get("stock", {}).is_empty():
		result.append("buy")
	result.append("sell")  # tout marchand rachète tout
	if shop.has("crafting"):
		result.append("craft")
	if shop.get("upgrade", false):
		result.append("upgrade")
	return result


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
	panel.custom_minimum_size = Vector2(980, 620)
	center.add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	panel.add_child(root)

	var header := HBoxContainer.new()
	var title := Label.new()
	title.text = Shops.name_of(shop_id)
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

	var description := RichTextLabel.new()
	description.bbcode_enabled = true
	description.fit_content = true
	description.text = "[i]%s[/i]" % Shops.def(shop_id).get("description", "")
	root.add_child(description)
	_deal_label.bbcode_enabled = true
	_deal_label.fit_content = true
	root.add_child(_deal_label)
	root.add_child(_tabs)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)
	root.add_child(scroll)
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


func show_tab(tab: String) -> void:
	_tab = tab
	_message = ""
	refresh()


func refresh() -> void:
	_gold_label.text = tr("Or : %d po") % life.character.gold
	var negotiator := Shops.negotiator(life)
	var skill: String = DB.rules.get("trade", {}).get("price_skill", "persuasion")
	var percent := roundi(Shops.discount(life) * 100)
	_deal_label.text = "[color=%s]%s[/color]" % [UITheme.TEXT_DIM.to_html(false),
		tr("Prix négociés par %s (%s %s) : %s %%") % [negotiator.name, Skills.name_of(skill),
			CharacterSheet.signed(negotiator.skill_mod(skill)), CharacterSheet.signed(-percent)]]
	_clear(_tabs)
	for tab in tabs():
		var button := Button.new()
		button.text = tr(TAB_NAMES[tab])
		button.toggle_mode = true
		button.button_pressed = tab == _tab
		button.pressed.connect(show_tab.bind(tab), CONNECT_DEFERRED)
		_tabs.add_child(button)
	_clear(_list)
	match _tab:
		"buy":
			_fill_buy()
		"sell":
			_fill_sell()
		"craft":
			_fill_craft()
		"upgrade":
			_fill_upgrade()
	if _list.get_child_count() == 0:
		_list.add_child(_dim_label(tr("Rien à proposer ici pour l'instant.")))
	_message_label.text = _message


# --- Onglets ----------------------------------------------------------------------

func _fill_buy() -> void:
	var stock := life.shop_stock(shop_id)
	for item_id: String in _sorted(stock.keys()):
		var price := Shops.buy_price(shop_id, item_id, life)
		var button := _row("%s ×%d" % [Items.bbcode_name(item_id), int(stock[item_id])], Items.summary(item_id),
			tr("Acheter (%d po)") % price, _on_buy.bind(item_id))
		button.disabled = life.character.gold < price


func _fill_sell() -> void:
	_list.add_child(_dim_label(tr("Le marchand rachète tout, sauf les objets de quête. Les objets portés ne sont pas proposés.")))
	for item_id: String in _sorted(life.inventory().keys()):
		if Shops.buys(shop_id, item_id):
			_row("%s ×%d" % [Items.bbcode_name(item_id), life.character.item_count(item_id)], Items.summary(item_id),
				tr("Vendre (%d po)") % Shops.sell_price(item_id, life, Shops.def(shop_id).get("location", "")), _on_sell.bind(item_id))


func _fill_craft() -> void:
	for recipe: Dictionary in Crafting.recipes_for(Shops.def(shop_id)["crafting"]):
		var missing := Crafting.missing_for(recipe, life)
		var detail := Crafting.cost_text(recipe)
		if missing != "":
			detail += "\n[color=%s]%s[/color]" % [UITheme.BAD.to_html(false), missing]
		var count := int(recipe.get("count", 1))
		var button := _row(Items.bbcode_name(recipe["result"]) + (" ×%d" % count if count > 1 else ""), detail,
			tr("Fabriquer (%s, DD %d)") % [Skills.name_of(Crafting.check_for(recipe)["skill"]), int(recipe.get("dc", 10))],
			_on_craft.bind(recipe["id"]))
		button.disabled = missing != ""


func _fill_upgrade() -> void:
	_list.add_child(_dim_label(tr("Armes, armures et boucliers ordinaires : +1, puis +2, puis +%d au maximum.") % Crafting.max_upgrade()))
	for member in life.party():
		for slot: String in member.equipment:
			var item_id: String = member.equipment[slot]
			if Crafting.can_upgrade(item_id):
				_upgrade_row(item_id, tr("porté par %s") % member.name, _on_upgrade.bind(item_id, member, slot))
	for item_id: String in _sorted(life.inventory().keys()):
		if Crafting.can_upgrade(item_id):
			_upgrade_row(item_id, tr("dans le sac"), _on_upgrade.bind(item_id, null, ""))


func _upgrade_row(item_id: String, where: String, callback: Callable) -> void:
	var cost := Crafting.upgrade_cost(item_id)
	var next := Crafting.upgraded_id(item_id)
	var button := _row("%s → %s" % [Items.bbcode_name(item_id), Items.bbcode_name(next)],
		"%s · %s" % [where, Modifiers.describe_all(Equipment.modifiers_of(next))], tr("Améliorer (%d po)") % cost, callback)
	button.disabled = life.character.gold < cost


# --- Actions -----------------------------------------------------------------------

func _on_buy(item_id: String) -> void:
	var price := Shops.buy_price(shop_id, item_id, life)
	if life.buy(shop_id, item_id):
		_after(tr("Acheté : %s (−%d po).") % [Items.name_of(item_id), price])


func _on_sell(item_id: String) -> void:
	var price := Shops.sell_price(item_id, life, Shops.def(shop_id).get("location", ""))
	if life.sell(shop_id, item_id):
		_after(tr("Vendu : %s (+%d po).") % [Items.name_of(item_id), price])


func _on_craft(recipe_id: String) -> void:
	var result := life.craft(recipe_id)
	if result["ok"]:
		_after(result["text"])


func _on_upgrade(item_id: String, member: Character, slot: String) -> void:
	var next := Crafting.upgraded_id(item_id)
	if life.upgrade(item_id, member, slot):
		_after(tr("Amélioré : %s.") % Items.name_of(next))


func _after(message: String) -> void:
	_message = "[color=%s]%s[/color]" % [UITheme.GOLD.to_html(false), message]
	refresh()
	changed.emit()


# --- Utilitaires -----------------------------------------------------------------

## Une ligne : nom (BBCode), détail en petit, et un bouton d'action. Retourne le bouton.
func _row(title: String, detail: String, action: String, callback: Callable) -> Button:
	var row := HBoxContainer.new()
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text = "%s\n[font_size=14][color=%s]%s[/color][/font_size]" % [title, UITheme.TEXT_DIM.to_html(false), detail]
	row.add_child(label)
	var button := Button.new()
	button.text = action
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(callback, CONNECT_DEFERRED)
	row.add_child(button)
	_list.add_child(row)
	return button


## Objets triés par catégorie puis par nom.
func _sorted(item_ids: Array) -> Array:
	var result := item_ids.duplicate()
	result.sort_custom(func(a, b):
		var ca := Items.CATEGORIES.find(Items.category_of(a))
		var cb := Items.CATEGORIES.find(Items.category_of(b))
		return ca < cb or (ca == cb and Items.name_of(a) < Items.name_of(b)))
	return result


func _dim_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
