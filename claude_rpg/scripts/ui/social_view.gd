class_name SocialView
extends Control
## Fenêtre de dialogue avec un PNJ, à la façon des Sims : en haut, le PNJ (portrait, rôle, statut, humeur
## si on la devine, jauges, traits et faits connus) ; au milieu, le fil de la conversation ; en bas, une
## barre d'actions par catégorie (amical, romantique, hostile, spécial).
## Quitter la conversation après au moins une action fait passer un créneau de la journée
## (signal `closed(acted)`). « Échanger » ouvre la fenêtre d'échange (signal `trade_requested`).

signal changed
signal closed(acted: bool)
signal trade_requested(npc: Npc)

const CATEGORY_NAMES := {"friendly": "Amical", "romantic": "Romantique", "hostile": "Hostile", "special": "Spécial"}
const CATEGORY_COLORS := {"friendly": "#8fbf6a", "romantic": "#e070a0", "hostile": "#d9694a", "special": "#d4b06a"}

var life: LifeState
var npc: Npc
var session := {"acted": false, "understood": false, "mood_known": false}

var _portrait := TextureRect.new()
var _header := RichTextLabel.new()
var _details := RichTextLabel.new()
var _log := RichTextLabel.new()
var _bar := VBoxContainer.new()


func _init(life_state: LifeState, target: Npc) -> void:
	life = life_state
	npc = target


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
	panel.custom_minimum_size = Vector2(1060, 640)
	center.add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	panel.add_child(root)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	_portrait.custom_minimum_size = Vector2(96, 96)
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture = npc_portrait(npc)
	top.add_child(_portrait)
	_header.bbcode_enabled = true
	_header.fit_content = true
	_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_header)
	var leave := Button.new()
	leave.text = tr("Partir (Échap)")
	leave.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	leave.pressed.connect(close_view, CONNECT_DEFERRED)
	top.add_child(leave)
	root.add_child(top)

	var middle := HBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation", 16)
	_details.bbcode_enabled = true
	_details.custom_minimum_size = Vector2(380, 0)
	_details.scroll_following = false
	middle.add_child(_details)
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.add_child(_log)
	root.add_child(middle)
	root.add_child(_bar)

	# Rencontre : Perspicacité passive (humeur, trait caché), salut.
	var first_time: bool = not npc.player.get("met", false)
	Social.meet(npc, life)
	var read := Social.read_npc(life.character, npc)
	session["mood_known"] = read["mood"]
	_say(Social.greeting(npc, life))
	if first_time:
		_say("[i]%s[/i]" % tr("Vous faites la connaissance %s, %s.") % [Loc.de_name(npc.name), npc.role_name().to_lower()])
	if read["trait"] != "":
		_say("[color=%s]%s[/color]" % [UITheme.GOLD.to_html(false),
			tr("Votre perspicacité vous souffle que %s est %s.") % [npc.name, String(DB.traits[read["trait"]]["name"]).to_lower()]])
	if not Social.shares_language(life.character, npc):
		_say("[color=%s]%s[/color]" % [UITheme.BAD.to_html(false),
			tr("%s parle %s, une langue que vous ne connaissez pas.") % [npc.name, Skills.language_name(npc.languages[0])]])
	refresh()


func close_view() -> void:
	closed.emit(session["acted"])
	queue_free()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		accept_event()
		close_view()


static func npc_portrait(n: Npc) -> Texture2D:
	var art: Dictionary = n.role_def().get("art", DB.classes.values()[0].get("art", {}))
	var stage := "adult"
	var stages: Dictionary = DB.species.get(n.species, {}).get("age_stages", {})
	var age := n.age(Meta.world_day)
	for life_stage: Dictionary in DB.rules["life_stages"]:
		if stages.has(life_stage["id"]) and age >= int(stages[life_stage["id"]]):
			stage = life_stage["id"]
	return ImageTexture.create_from_image(PixelArt.portrait(DB.species.get(n.species, {}).get("art", {}), art, stage, n.art_seed))


## Résumé lisible d'un PNJ (fenêtre de dialogue et carnet).
static func describe(n: Npc, life: LifeState, mood_known: bool) -> String:
	var gold := UITheme.GOLD.to_html(false)
	var dim := UITheme.TEXT_DIM.to_html(false)
	var t := ""
	for gauge: String in Social.GAUGES:
		var value := int(n.player[gauge])
		var color := UITheme.GOOD if value > 0 else (UITheme.BAD if value < 0 else UITheme.TEXT_DIM)
		var filled := clampi(roundi(absf(value) / 10.0), 0, 10)
		t += "[color=%s]%s[/color] [color=%s]%s[/color] %d\n" % [gold, Loc.ui(Social.GAUGE_NAMES[gauge]).rpad(10),
			color.to_html(false), "■".repeat(filled) + "□".repeat(10 - filled), value]
	if mood_known:
		t += "[color=%s]%s[/color] %s\n" % [gold, Loc.ui("Humeur"), Social.mood(n)["name"]]
	var traits := PackedStringArray(n.known_traits.map(func(id): return DB.traits[id]["name"]))
	var hidden := n.traits.size() - n.known_traits.size()
	t += "[color=%s]%s[/color] %s%s\n" % [gold, Loc.ui("Traits"), ", ".join(traits) if not traits.is_empty() else "—",
		(" [color=%s](+%d inconnu)[/color]" % [dim, hidden]) if hidden > 0 else ""]
	t += "[color=%s]%s[/color] %s\n" % [gold, Loc.ui("Langues"),
		", ".join(PackedStringArray(n.languages.map(func(l): return Skills.language_name(l))))]
	if not n.facts.is_empty():
		t += "\n[color=%s]%s[/color]\n" % [gold, Loc.ui("Ce que vous savez")]
		for fact: String in n.facts.values():
			t += "• %s\n" % fact
	for parent: String in n.parents:
		if parent.begins_with("hero:"):
			t += "[color=%s]%s[/color] %s\n" % [gold, Loc.ui("Enfant de"), parent.trim_prefix("hero:")]
	var partners := n.partners()
	if not partners.is_empty():
		t += "[color=%s]%s[/color] %s\n" % [gold, Loc.ui("En couple avec"),
			", ".join(PackedStringArray(partners.map(func(id): return Social.npc(id).name if Social.npc(id) else id)))]
	if not n.memories.is_empty():
		t += "\n[color=%s]%s[/color]\n" % [gold, Loc.ui("Souvenirs")]
		for memory: Dictionary in n.memories.slice(maxi(0, n.memories.size() - 4)):
			t += "[color=%s]• %s[/color]\n" % [dim, memory["text"]]
	return t


func refresh() -> void:
	var gold := UITheme.GOLD.to_html(false)
	_header.text = "[font_size=26][color=%s]%s[/color][/font_size]\n%s · %s · %s\n[color=%s]%s[/color] %s   [color=%s]%s[/color] %s" % [
		gold, npc.name, npc.role_name(), DB.species[npc.species]["name"], tr("%d ans") % npc.age(Meta.world_day),
		gold, tr("Relation"), Social.status_name(npc), gold, tr("Réputation"),
		Social.reputation_name(int(life.reputation.get(npc.location, 0)))]
	_details.text = describe(npc, life, session["mood_known"])
	for child in _bar.get_children():
		_bar.remove_child(child)
		child.queue_free()
	for category: String in CATEGORY_NAMES:
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = tr(CATEGORY_NAMES[category])
		label.custom_minimum_size = Vector2(110, 0)
		label.add_theme_color_override("font_color", Color(String(CATEGORY_COLORS[category])))
		row.add_child(label)
		var flow := HFlowContainer.new()
		flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(flow)
		for a: Dictionary in Social.actions():
			if a.get("category") != category:
				continue
			var reason := Social.unavailable_reason(a["id"], npc, life, session)
			if reason != "" and category == "romantic" and reason != tr("réservé aux adultes") and a["id"] != "flirt":
				continue  # les étapes romantiques n'apparaissent qu'une fois possibles
			if a.get("special") == "gestures" and reason != "":
				continue
			var button := Button.new()
			button.text = a["name"]
			button.disabled = reason != ""
			button.tooltip_text = reason if reason != "" else _check_hint(a)
			button.pressed.connect(_on_action.bind(a["id"]), CONNECT_DEFERRED)
			flow.add_child(button)
		if flow.get_child_count() > 0:
			_bar.add_child(row)
		else:
			row.free()


func _check_hint(a: Dictionary) -> String:
	if not a.has("check"):
		return ""
	var spec: Dictionary = a["check"]
	var skill := Skills.name_of(spec["skill"])
	if spec.has("vs"):
		return tr("Test : %s contre la %s de %s") % [skill, Skills.name_of(spec["vs"]), npc.name]
	var difficulty := maxi(0, Dice.difficulty_of(spec) + int(Social.trait_reaction(npc, a.get("id", ""))["difficulty"])
		+ int(Social.mood(npc).get("difficulty", 0)))
	var pool := life.character.skill_pool(spec["skill"], spec.get("ability", ""))
	return tr("Test : %s, difficulté %d (%d %%)") % [skill, difficulty,
		roundi(Dice.chance(int(pool["count"]), int(pool["threshold"]), difficulty) * 100)]


func _on_action(action_id: String) -> void:
	var result := Social.perform(action_id, npc, life, session)
	_say("[color=%s]> %s[/color]" % [UITheme.GOLD.to_html(false), Social.action(action_id)["name"]])
	for line: String in result["lines"]:
		_say(line)
	refresh()
	changed.emit()
	if result["open_trade"]:
		trade_requested.emit(npc)
	if npc.location == "party":
		_say(tr("%s rejoint votre groupe !") % npc.name)


func _say(text: String) -> void:
	_log.append_text(text + "\n")
