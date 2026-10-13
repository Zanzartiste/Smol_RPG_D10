class_name InventoryView
extends Control
## Fenêtre d'inventaire, ouverte depuis la fiche (bouton « Inventaire » ou touche I).
## À gauche : l'équipement du membre du groupe sélectionné (héros ou compagnon), avec « Retirer ».
## À droite : le sac du groupe (celui du héros), avec « Équiper » (sur le membre sélectionné),
## « Utiliser » (soins, sur le membre sélectionné) et « Jeter » ; filtres par catégorie et recherche.
## En haut : la charge du groupe (sac + objets portés) et sa capacité.
## Toute la logique passe par LifeState (equip, unequip, use_item, drop_item).

signal changed  # l'inventaire ou l'équipement a changé (pour rafraîchir la fiche)
signal closed

var life: LifeState
var _member: Character
var _message := ""
var _filter := "all"
var _search := ""

var _member_tabs := HBoxContainer.new()
var _gold_label := Label.new()
var _equipment_box := VBoxContainer.new()
var _stats_text := RichTextLabel.new()
var _bag_box := VBoxContainer.new()
var _filter_box := HBoxContainer.new()
var _search_edit := LineEdit.new()
var _load_label := Label.new()
var _message_label := RichTextLabel.new()


func _init(life_state: LifeState) -> void:
	life = life_state
	_member = life.character


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
	panel.custom_minimum_size = Vector2(980, 600)
	center.add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	panel.add_child(root)

	var header := HBoxContainer.new()
	var title := Label.new()
	title.text = tr("Inventaire")
	title.theme_type_variation = &"TitleLabel"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(_load_label)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(16, 0)
	header.add_child(spacer)
	_gold_label.add_theme_color_override("font_color", UITheme.GOLD)
	header.add_child(_gold_label)
	var close := Button.new()
	close.text = tr("Fermer (Échap)")
	close.pressed.connect(close_view, CONNECT_DEFERRED)
	header.add_child(close)
	root.add_child(header)
	root.add_child(_member_tabs)

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 20)
	root.add_child(columns)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(380, 0)
	left.add_child(_section(tr("Équipement")))
	left.add_child(_equipment_box)
	_stats_text.bbcode_enabled = true
	_stats_text.fit_content = true
	left.add_child(_stats_text)
	columns.add_child(left)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(_section(tr("Sac du groupe")))
	right.add_child(_filter_box)
	_search_edit.placeholder_text = tr("Rechercher un objet…")
	_search_edit.clear_button_enabled = true
	_search_edit.text_changed.connect(_on_search_changed)
	right.add_child(_search_edit)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_bag_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bag_box.add_theme_constant_override("separation", 6)
	scroll.add_child(_bag_box)
	right.add_child(scroll)
	columns.add_child(right)

	_message_label.bbcode_enabled = true
	_message_label.fit_content = true
	root.add_child(_message_label)
	refresh()


func close_view() -> void:
	closed.emit()
	queue_free()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and (key.keycode == KEY_ESCAPE \
			or (key.keycode == KEY_I and not _search_edit.has_focus())):
		accept_event()
		close_view()


## Membre du groupe affiché à gauche, cible de « Équiper » et « Utiliser ».
func select_member(member: Character) -> void:
	_member = member
	refresh()


## Filtre du sac : une clé de Items.FILTERS.
func set_filter(filter: String) -> void:
	_filter = filter
	refresh()


func _on_search_changed(text: String) -> void:
	_search = text.strip_edges()
	_fill_bag()


func refresh() -> void:
	life.refresh_load()
	_gold_label.text = tr("Or : %d po") % life.character.gold
	_load_label.text = tr("Charge : %.1f / %.0f kg") % [life.carried_weight(), life.carry_capacity()]
	_load_label.add_theme_color_override("font_color",
		UITheme.BAD if life.carried_weight() > life.carry_capacity() else UITheme.TEXT_DIM)
	_fill_member_tabs()
	_fill_filters()
	_fill_equipment()
	_fill_bag()
	_message_label.text = _message


# --- Construction -------------------------------------------------------------

func _fill_member_tabs() -> void:
	_clear(_member_tabs)
	for member in life.party():
		var button := Button.new()
		button.text = member.name
		button.toggle_mode = true
		button.button_pressed = member == _member
		button.pressed.connect(select_member.bind(member), CONNECT_DEFERRED)
		_member_tabs.add_child(button)


func _fill_filters() -> void:
	_clear(_filter_box)
	for filter: String in Items.FILTERS:
		var count := life.inventory().keys().filter(func(id): return Items.matches(id, filter)).size()
		if filter != "all" and count == 0:
			continue
		var button := Button.new()
		button.text = "%s (%d)" % [tr(Items.FILTERS[filter]["name"]), count]
		button.toggle_mode = true
		button.button_pressed = filter == _filter
		button.pressed.connect(set_filter.bind(filter), CONNECT_DEFERRED)
		_filter_box.add_child(button)


func _fill_equipment() -> void:
	_clear(_equipment_box)
	for slot in Equipment.SLOTS:
		var row := HBoxContainer.new()
		var label := RichTextLabel.new()
		label.bbcode_enabled = true
		label.fit_content = true
		label.scroll_active = false
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var item_id: String = _member.equipment.get(slot, "")
		var dim := UITheme.TEXT_DIM.to_html(false)
		label.text = "[color=%s]%s :[/color] %s" % [dim, Equipment.slot_name(slot),
			Items.bbcode_name(item_id) if item_id != "" else "[color=%s]—[/color]" % dim]
		if item_id != "":
			label.tooltip_text = Items.summary(item_id)
			if _member.encumbrance_reason(item_id) != "":
				label.text += " [color=%s](%s)[/color]" % [UITheme.BAD.to_html(false), tr("encombrant")]
		row.add_child(label)
		if item_id != "" and item_id != Equipment.UNARMED:
			row.add_child(_small_button(tr("Retirer"), _on_unequip.bind(slot)))
		_equipment_box.add_child(row)
	var gold := UITheme.GOLD.to_html(false)
	_stats_text.text = "\n[color=%s]PV[/color] %d / %d    [color=%s]CA[/color] %d\n[color=%s]%s[/color] %s" % [
		gold, _member.hp, _member.max_hp, gold, _member.armor_class(), gold, tr("Arme"),
		Equipment.describe(_member.weapon_id())]
	var defenses := _member.all_defenses()
	if not defenses.is_empty():
		_stats_text.text += "\n" + defenses.describe()


func _fill_bag() -> void:
	_clear(_bag_box)
	var inventory := life.inventory()
	var shown: Array = inventory.keys().filter(func(id): return Items.matches(id, _filter, _search))
	if shown.is_empty():
		var empty := Label.new()
		empty.text = tr("Le sac est vide.") if inventory.is_empty() else tr("Aucun objet ne correspond.")
		empty.add_theme_color_override("font_color", UITheme.TEXT_DIM)
		_bag_box.add_child(empty)
		return
	shown.sort_custom(func(a, b): return Items.name_of(a) < Items.name_of(b))
	for item_id: String in shown:
		var row := HBoxContainer.new()
		var label := RichTextLabel.new()
		label.bbcode_enabled = true
		label.fit_content = true
		label.scroll_active = false
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var weight := Items.weight_of(item_id) * int(inventory[item_id])
		label.text = "%s ×%d\n[font_size=14][color=%s]%s%s[/color][/font_size]" % [Items.bbcode_name(item_id),
			int(inventory[item_id]), UITheme.TEXT_DIM.to_html(false), Items.summary(item_id),
			(" · %s kg" % String.num(weight, 2)) if weight > 0.0 else ""]
		label.tooltip_text = Items.description_of(item_id)
		row.add_child(label)
		if Items.is_equipment(item_id):
			row.add_child(_small_button(tr("Équiper"), _on_equip.bind(item_id)))
			var problem := _member.encumbrance_reason(item_id)
			if problem != "":
				label.text += "\n[font_size=14][color=%s]%s : %s[/color][/font_size]" % [UITheme.BAD.to_html(false),
					_member.name, problem]
		if Items.is_usable_outside_combat(item_id):
			var use := _small_button(tr("Utiliser"), _on_use.bind(item_id))
			use.disabled = _member.hp >= _member.max_hp
			row.add_child(use)
		if not Items.is_quest(item_id):
			row.add_child(_small_button(tr("Jeter"), _on_drop.bind(item_id)))
		_bag_box.add_child(row)


# --- Actions ------------------------------------------------------------------

func _on_equip(item_id: String) -> void:
	if life.equip(_member, item_id):
		_after(tr("%s équipe : %s.") % [_member.name, Items.name_of(item_id)])


func _on_unequip(slot: String) -> void:
	var item_id: String = _member.equipment.get(slot, "")
	if life.unequip(_member, slot):
		_after(tr("%s range : %s.") % [_member.name, Items.name_of(item_id)])


func _on_use(item_id: String) -> void:
	var text := life.use_item(item_id, _member)
	if text != "":
		_after(text)


func _on_drop(item_id: String) -> void:
	if life.drop_item(item_id) > 0:
		_after(tr("Jeté : %s.") % Items.name_of(item_id))


func _after(message: String) -> void:
	_message = "[color=%s]%s[/color]" % [UITheme.GOLD.to_html(false), message]
	refresh()
	changed.emit()


# --- Utilitaires --------------------------------------------------------------

func _section(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"SectionLabel"
	return label


func _small_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(callback, CONNECT_DEFERRED)
	return button


func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
