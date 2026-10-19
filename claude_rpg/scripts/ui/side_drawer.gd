class_name SideDrawer
extends Control
## Tiroir latéral droit : caché hors de l'écran, il ne laisse dépasser que des onglets. Survoler un
## onglet déroule sa page ; elle se replie quand la souris s'en va. Cliquer sur un onglet épingle la page
## (elle reste ouverte jusqu'au clic suivant).
## Onglets : Personnage (PV), Inventaire (or), Quêtes, Journal, Relations, Sorts (lanceurs de sorts seulement),
## Notes, puis Carte (un bouton qui ouvre la carte du monde, même en combat ou pendant un événement).
## Raccourcis (voir SHORTCUTS) : P, I (page), Q, J, E, M, N, V (carte) ; Échap replie une page épinglée.
## Les détails (calculs, descriptions) s'affichent au survol de chaque ligne.

signal inventory_requested
signal carnet_requested
signal level_up_requested
signal map_requested

const PANEL_WIDTH := 440.0
const TAB_WIDTH := 132.0
const TAB_HEIGHT := 44.0
const TOP_MARGIN := 60.0
const CLOSE_DELAY := 0.35  # secondes hors du tiroir avant qu'il se replie
const SPEED := 7.0  # vitesse d'ouverture (fraction par seconde)

const PAGES := ["character", "inventory", "quests", "journal", "social", "spells", "notes"]
## Touche -> page (l'inventaire complet reste sur I, le carnet sur C).
const SHORTCUTS := {KEY_P: "character", KEY_Q: "quests", KEY_J: "journal", KEY_E: "social", KEY_M: "spells", KEY_N: "notes"}
const JOURNAL_SHOWN := 150  # entrées affichées au plus (les plus récentes)

var life: LifeState
var locked := false  # pendant un combat : on ne change ni l'équipement ni les sorts
var member: Character  # personnage affiché (héros ou compagnon)

var _slider := Control.new()
var _tabs := VBoxContainer.new()
var _panel := PanelContainer.new()
var _scroll := ScrollContainer.new()
var _content := VBoxContainer.new()
var _tab_buttons := {}  # id de page -> Button
var _current := ""  # page ouverte ("" : tiroir replié)
var _pinned := false
var _open := 0.0  # 0 replié, 1 déroulé
var _outside := 0.0  # temps passé hors du tiroir
var _skills_open := true  # section Compétences dépliée
var _journal_filter := ""  # sorte d'entrées du journal affichée ("" : toutes)
var _level_up_glow := false  # un membre du groupe peut monter de niveau
var _tab_timer := 0.0  # rafraîchissement régulier des onglets


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_slider)
	_tabs.add_theme_constant_override("separation", 6)
	_tabs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slider.add_child(_tabs)
	for page_id: String in PAGES:
		var tab := Button.new()
		tab.custom_minimum_size = Vector2(TAB_WIDTH, TAB_HEIGHT)
		tab.toggle_mode = true
		tab.alignment = HORIZONTAL_ALIGNMENT_LEFT
		tab.clip_text = true
		tab.mouse_entered.connect(_on_tab_hovered.bind(page_id))
		tab.pressed.connect(_on_tab_pressed.bind(page_id))
		_tabs.add_child(tab)
		_tab_buttons[page_id] = tab
	var map_tab := Button.new()
	map_tab.custom_minimum_size = Vector2(TAB_WIDTH, TAB_HEIGHT)
	map_tab.alignment = HORIZONTAL_ALIGNMENT_LEFT
	map_tab.text = tr("Carte")
	map_tab.tooltip_text = tr("Carte du monde (raccourci : V)")
	map_tab.pressed.connect(func(): map_requested.emit())
	_tabs.add_child(map_tab)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_slider.add_child(_panel)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(_scroll)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 6)
	_scroll.add_child(_content)
	refresh()


func _process(delta: float) -> void:
	if _level_up_glow:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 250.0)
		_tab_buttons["character"].modulate = Color.WHITE.lerp(UITheme.GOLD * 1.6, pulse)
	_tab_timer += delta
	if _tab_timer > 0.5 and life != null:
		_tab_timer = 0.0
		_refresh_tabs()
	if _current != "" and not _pinned:
		var mouse := get_global_mouse_position()
		var inside := _tabs.get_global_rect().has_point(mouse) or (_open > 0.05 and _panel.get_global_rect().has_point(mouse))
		_outside = 0.0 if inside else _outside + delta
		if _outside > CLOSE_DELAY:
			close()
	var target := 1.0 if _current != "" else 0.0
	if not is_equal_approx(_open, target):
		_open = move_toward(_open, target, delta * SPEED)
	_layout()


func _layout() -> void:
	var height := maxf(0.0, size.y - TOP_MARGIN - 16.0)
	_slider.position = Vector2(size.x - TAB_WIDTH - PANEL_WIDTH * ease(_open, 0.4), TOP_MARGIN)
	_slider.size = Vector2(TAB_WIDTH + PANEL_WIDTH, height)
	_tabs.position = Vector2.ZERO
	_tabs.size = Vector2(TAB_WIDTH, height)
	_panel.position = Vector2(TAB_WIDTH, 0)
	_panel.size = Vector2(PANEL_WIDTH, height)
	_panel.visible = _open > 0.0


## La page est-elle ouverte (pour les tests et les autres écrans) ?
func is_open() -> bool:
	return _current != ""


func open(page_id: String) -> void:
	if not _tab_buttons.has(page_id) or not _tab_buttons[page_id].visible:
		return
	_current = page_id
	_outside = 0.0
	_build_page()


func close() -> void:
	_current = ""
	_pinned = false
	_update_tab_states()


func _on_tab_hovered(page_id: String) -> void:
	if not _pinned or _current == "":
		open(page_id)


func _on_tab_pressed(page_id: String) -> void:
	if _pinned and _current == page_id:
		close()
		return
	open(page_id)
	_pinned = true
	_update_tab_states()


## Met les onglets et la page ouverte à jour (après un changement : PV, or, sorts…).
func refresh() -> void:
	if life == null:
		return
	if member == null or (member != life.character and member not in life.companions):
		member = life.character
	_refresh_tabs()
	if _current != "":
		_build_page()


## Textes des onglets (appelé souvent : les PV changent en combat).
func _refresh_tabs() -> void:
	var hero := life.character
	_tab_buttons["character"].text = tr("PV %d/%d") % [hero.hp, hero.max_hp]
	_tab_buttons["character"].add_theme_color_override("font_color",
		UITheme.BAD if hero.hp <= hero.max_hp / 3.0 else UITheme.TEXT)
	_tab_buttons["character"].tooltip_text = tr("Personnage")
	# Une montée de niveau attend : l'onglet brille (voir _process).
	_level_up_glow = life.party().any(func(c): return c.has_level_up())
	if not _level_up_glow:
		_tab_buttons["character"].modulate = Color.WHITE
	_tab_buttons["inventory"].text = short_gold(hero.gold)
	_tab_buttons["inventory"].tooltip_text = tr("Inventaire et équipement")
	_tab_buttons["quests"].text = tr("Quêtes (%d)") % Quests.with_status(life, "active").size()
	_tab_buttons["social"].text = tr("Relations")
	_tab_buttons["journal"].text = tr("Journal")
	_tab_buttons["notes"].text = tr("Notes")
	for key: int in SHORTCUTS:
		_tab_buttons[SHORTCUTS[key]].tooltip_text = tr("Raccourci : %s") % OS.get_keycode_string(key)
	var casters := life.party().filter(func(c): return c.max_resource(Spellcasting.SLOT_KEY) > 0 or not c.known_spells().is_empty())
	_tab_buttons["spells"].visible = not casters.is_empty()
	if not casters.is_empty():
		var caster: Character = casters[0]
		_tab_buttons["spells"].text = tr("Sorts %d/%d") % [int(caster.resources.get(Spellcasting.SLOT_KEY, 0)),
			caster.max_resource(Spellcasting.SLOT_KEY)]
	if _current == "spells" and casters.is_empty():
		close()
	_update_tab_states()


func _update_tab_states() -> void:
	for page_id: String in _tab_buttons:
		_tab_buttons[page_id].set_pressed_no_signal(page_id == _current)


## « 950 po », « 1,2k po », « 3,4M po ».
static func short_gold(gold: int) -> String:
	if gold >= 1000000:
		return ("%.1fM po" % (floorf(gold / 100000.0) / 10.0)).replace(".", ",").replace(",0M", "M")
	if gold >= 1000:
		return ("%.1fk po" % (floorf(gold / 100.0) / 10.0)).replace(".", ",").replace(",0k", "k")
	return "%d po" % gold


# --- Pages ---------------------------------------------------------------------

func _build_page() -> void:
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	match _current:
		"character":
			_build_character()
		"inventory":
			_build_inventory()
		"quests":
			_build_quests()
		"journal":
			_build_journal()
		"notes":
			_build_notes()
		"social":
			_build_social()
		"spells":
			_build_spells()
	_update_tab_states()


## Boutons pour choisir le personnage affiché (s'il y a des compagnons). `only` : filtre éventuel.
func _member_selector(only: Callable = Callable()) -> void:
	var members := life.party().filter(func(c): return not only.is_valid() or only.call(c))
	if members.size() <= 1:
		if not members.is_empty():
			member = members[0]
		return
	if member not in members:
		member = members[0]
	var row := HBoxContainer.new()
	for c: Character in members:
		var button := Button.new()
		button.text = c.name
		button.toggle_mode = true
		button.button_pressed = c == member
		button.pressed.connect(func():
			member = c
			_build_page())
		row.add_child(button)
	_content.add_child(row)


func _build_character() -> void:
	_member_selector()
	if life.party().any(func(c): return c.has_level_up()):
		_add_button(tr("★ Monter de niveau"), func(): level_up_requested.emit(), not locked)
	var page := CharacterPage.new()
	page.skills_open = _skills_open
	page.skills_toggled.connect(func(open): _skills_open = open)
	_content.add_child(page)
	page.show_character(member)


func _build_inventory() -> void:
	var hero := life.character
	_add_label(tr("Or : %d po") % hero.gold, "", "SectionLabel")
	_add_separator()
	_member_selector()
	_add_label(tr("Équipement de %s") % member.name, "", "", UITheme.TEXT_DIM)
	for slot in Equipment.SLOTS:
		var item_id: String = member.equipment.get(slot, "")
		if item_id == "":
			_add_label("%s : —" % Equipment.slot_name(slot), "", "", UITheme.TEXT_DIM)
			continue
		var label := _add_label("%s : %s" % [Equipment.slot_name(slot), Items.name_of(item_id)],
			Items.summary(item_id) + "\n" + Items.description_of(item_id))
		label.add_theme_color_override("font_color", Items.rarity_color(item_id))
	_add_separator()
	_add_label(tr("Sac du groupe"), "", "", UITheme.TEXT_DIM)
	if hero.inventory.is_empty():
		_add_label("—", "")
	for item_id: String in hero.inventory:
		var label := _add_label("%s ×%d" % [Items.name_of(item_id), hero.item_count(item_id)],
			Items.summary(item_id) + "\n" + Items.description_of(item_id))
		label.add_theme_color_override("font_color", Items.rarity_color(item_id))
	_add_button(tr("Gérer l'inventaire (I)"), func(): inventory_requested.emit(), not locked)


func _build_quests() -> void:
	var active := Quests.with_status(life, "active")
	_add_label(tr("Quêtes en cours"), "", "SectionLabel")
	if active.is_empty():
		_add_label(tr("Aucune quête en cours."), "", "", UITheme.TEXT_DIM)
	for quest_id in active:
		var quest := Quests.def(quest_id)
		_add_label(Quests.name_of(quest_id), quest.get("description", ""), "", UITheme.GOLD)
		var giver := PackedStringArray()
		if quest.has("giver"):
			giver.append(quest["giver"])
		if quest.has("location"):
			giver.append(DB.locations.get(quest["location"], {}).get("name", quest["location"]))
		if not giver.is_empty():
			_add_label(" · ".join(giver), "", "", UITheme.TEXT_DIM)
		_add_label(Quests.step_text(quest_id, int(life.quests[quest_id].get("step", 0))), "")
	for status: String in ["done", "failed"]:
		var finished := Quests.with_status(life, status)
		if finished.is_empty():
			continue
		_add_separator()
		_add_label(tr("Quêtes accomplies") if status == "done" else tr("Quêtes échouées"), "", "", UITheme.TEXT_DIM)
		for quest_id in finished:
			_add_label(Quests.name_of(quest_id), Quests.def(quest_id).get("description", ""), "", UITheme.TEXT_DIM)


## Journal : les entrées les plus récentes d'abord, groupées par jour, avec un filtre par sorte.
func _build_journal() -> void:
	_add_label(tr("Journal"), "", "SectionLabel")
	var filters := HFlowContainer.new()
	var kinds := [""]
	for entry: Dictionary in life.journal:
		if entry["kind"] not in kinds:
			kinds.append(entry["kind"])
	for kind: String in kinds:
		var button := Button.new()
		button.text = tr("Tout") if kind == "" else tr(LifeState.JOURNAL_KINDS.get(kind, kind))
		button.toggle_mode = true
		button.button_pressed = kind == _journal_filter
		button.pressed.connect(func():
			_journal_filter = kind
			_build_page())
		filters.add_child(button)
	_content.add_child(filters)
	var entries := life.journal.filter(func(e): return _journal_filter == "" or e["kind"] == _journal_filter)
	if entries.is_empty():
		_add_label(tr("Rien à raconter pour l'instant."), "", "", UITheme.TEXT_DIM)
		return
	entries = entries.slice(maxi(0, entries.size() - JOURNAL_SHOWN))
	entries.reverse()
	var current_day := -1
	var slots := DB.time_slots()
	for entry: Dictionary in entries:
		if int(entry["day"]) != current_day:
			current_day = int(entry["day"])
			_add_separator()
			_add_label(tr("Jour %d") % current_day, "", "", UITheme.GOLD)
		var slot_name: String = slots[clampi(int(entry["slot"]), 0, slots.size() - 1)]["name"]
		_add_label("%s — %s" % [slot_name, entry["text"]], tr(LifeState.JOURNAL_KINDS.get(entry["kind"], "")))


## Notes libres du joueur, sauvegardées avec la vie.
func _build_notes() -> void:
	_add_label(tr("Notes"), tr("Ce que vous voulez retenir : pistes, prix, noms…"), "SectionLabel")
	var edit := TextEdit.new()
	edit.text = life.notes
	edit.placeholder_text = tr("Écrivez ici…")
	edit.custom_minimum_size = Vector2(0, 420)
	edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	edit.text_changed.connect(func(): life.notes = edit.text)
	_content.add_child(edit)


## Raccourci clavier : ouvre (épingle) ou replie la page correspondante. Retourne true si la touche est prise.
func handle_key(keycode: int) -> bool:
	if keycode == KEY_ESCAPE and _pinned:
		close()
		return true
	if not SHORTCUTS.has(keycode):
		return false
	_on_tab_pressed(SHORTCUTS[keycode])
	return true


func _build_social() -> void:
	_add_label(tr("Réputation"), "", "SectionLabel")
	for location_id: String in DB.location_order:
		if DB.locations[location_id].get("rest", {}).get("type", "") == "home":
			continue
		var value := int(life.reputation.get(location_id, 0))
		_add_label("%s : %s (%+d)" % [DB.locations[location_id]["name"], Social.reputation_name(value), value],
			tr("Au-delà de +20 : meilleur accueil et prix plus doux ; sous −20 : prix plus élevés."))
	_add_separator()
	_add_label(tr("Factions"), "", "SectionLabel")
	_add_label(tr("Aucune faction pour l'instant."), "", "", UITheme.TEXT_DIM)
	_add_separator()
	_add_label(tr("Relations"), "", "SectionLabel")
	var known := Social.known_npcs()
	known.sort_custom(func(a, b): return int(a.player.get("friendship", 0)) > int(b.player.get("friendship", 0)))
	if known.is_empty():
		_add_label(tr("Vous ne connaissez encore personne."), "", "", UITheme.TEXT_DIM)
	for n in known:
		var status := Social.status_name(n)
		var traits := PackedStringArray(n.known_traits.map(func(t): return DB.traits.get(t, {}).get("name", t)))
		var tip := tr("Amitié %d · Amour %d · Confiance %d") % [int(n.player.get("friendship", 0)),
			int(n.player.get("love", 0)), int(n.player.get("trust", 0))]
		if not traits.is_empty():
			tip += "\n" + tr("Traits : %s") % ", ".join(traits)
		_add_label("%s — %s%s" % [n.name, n.role_name(), (" · " + status) if status != "" else ""], tip)
	_add_button(tr("Ouvrir le carnet (C)"), func(): carnet_requested.emit(), not locked)


func _build_spells() -> void:
	_member_selector(func(c): return c.max_resource(Spellcasting.SLOT_KEY) > 0 or not c.known_spells().is_empty())
	var ch := member
	_add_label(tr("Sorts de %s") % ch.name, "", "SectionLabel")
	_add_label(tr("Mana : %d / %d") % [int(ch.resources.get(Spellcasting.SLOT_KEY, 0)), ch.max_resource(Spellcasting.SLOT_KEY)],
		tr("Un sort de niveau N coûte N mana ; le mana manquant se paie en PV. Un repos long le restaure.\nSorts jusqu'au niveau %d.") % ch.max_spell_level())
	_add_label(tr("Sorts équipés : %d / %d") % [ch.equipped_spells.size(), ch.max_equipped_spells()],
		tr("Seuls les sorts équipés sont utilisables en combat : 2 + rang de %s (%d). Les tours de magie sont toujours prêts, en plus.") % [
			Skills.name_of(ch.spell_skill()), ch.skill_rank(Skills.SPELL)])
	if locked:
		_add_label(tr("On ne change pas ses sorts pendant un combat."), "", "", UITheme.TEXT_DIM)
	_add_separator()
	for action_id in ch.known_spells():
		var action := Actions.def(action_id)
		var equipped := ch.is_spell_equipped(action_id)
		var cantrip := Spellcasting.is_cantrip(action)
		var check := CheckBox.new()
		var level := int(action.get("spell_level", 0))
		check.text = "%s — %s" % [action["name"], tr("tour de magie, toujours prêt") if cantrip else tr("niv. %d, coût %d") % [level, level]]
		check.button_pressed = equipped
		check.disabled = cantrip or locked or (not equipped and ch.equipped_spells.size() >= ch.max_equipped_spells())
		check.tooltip_text = "%s\n%s" % [action.get("description", ""), Actions.text_of(action_id)]
		check.toggled.connect(func(on: bool):
			if on:
				ch.equip_spell(action_id)
			else:
				ch.unequip_spell(action_id)
			refresh())
		_content.add_child(check)


# --- Petits éléments ---------------------------------------------------------------

func _make_label(text: String, tooltip: String, variation := "", color := Color(0, 0, 0, 0)) -> Label:
	return CharacterPage.make_label(text, tooltip, variation, color)


func _add_label(text: String, tooltip: String, variation := "", color := Color(0, 0, 0, 0)) -> Label:
	var label := _make_label(text, tooltip, variation, color)
	_content.add_child(label)
	return label


## Deux éléments côte à côte, chacun sur la moitié de la largeur.
func _add_pair(left: Control, right: Control) -> void:
	var row := HBoxContainer.new()
	for item in [left, right]:
		item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item.size_flags_stretch_ratio = 1.0
		row.add_child(item)
	_content.add_child(row)


func _add_separator() -> void:
	_content.add_child(HSeparator.new())


func _add_button(text: String, on_pressed: Callable, enabled := true) -> void:
	var button := Button.new()
	button.text = text
	button.disabled = not enabled
	button.pressed.connect(on_pressed, CONNECT_DEFERRED)
	_content.add_child(button)
