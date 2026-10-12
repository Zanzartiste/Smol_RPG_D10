extends Node
## Ouvre les écrans du jeu, joue quelques actions et enregistre des captures d'écran.
## Nécessite un rendu (pas de --headless) :
##   godot --path . res://tools/screenshot.tscn -- <dossier_de_sortie>

var out_dir := ""


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else ProjectSettings.globalize_path("user://screenshots")
	DirAccess.make_dir_recursive_absolute(out_dir)

	var creation: Control = load("res://scenes/creation.tscn").instantiate()
	add_child(creation)
	for tab in creation.pages.get_tab_count():
		creation.tab_buttons.get_child(tab).button_pressed = true
		creation.pages.current_tab = tab
		await _capture("1_creation_%d.png" % tab)
	Game.start_life(creation.build_character(), 7)
	creation.queue_free()

	var builder: Control = load("res://scenes/deck_builder.tscn").instantiate()
	add_child(builder)
	await _capture("1b_deck_builder.png")
	builder.queue_free()

	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _capture("2_hub.png")
	main._on_location_chosen("forest")
	await _capture("3_event.png")
	Game.toggle_debug()
	await _capture("3b_event_debug.png")
	Game.toggle_debug()

	# Premier choix avec un test de dés.
	var with_check: Array = EventEngine.visible_choices(Game.current_event, Game.life, Meta).filter(
		func(c): return c["available"] and c["choice"].has("check"))
	if not with_check.is_empty():
		main._on_choice(with_check[0]["choice"])
		await get_tree().create_timer(0.35).timeout
		await _capture("4_dice_rolling.png")
		while not main.dice_tray._phase == 2:
			await get_tree().process_frame
		await get_tree().create_timer(0.3).timeout
		await _capture("5_dice_result.png")
		while main.dice_tray.is_playing():
			await get_tree().process_frame
		await _capture("6_result.png")

	# Montée au niveau 2 : choix d'un don.
	if not Game.life.dead:
		Game.life.character.add_xp(300)
		main._refresh_sheet()
		main._show_hub()
		await _capture("6b_feat_choice.png")
		main.choices_box.get_child(0).pressed.emit()
		await _wait_frames(3)

	# Combat avec Mira contre un groupe mixte (Mira joue seule, le héros joue ses cartes).
	Effects.apply_all([{"type": "recruit", "companion": "mira"}], Game.life, Meta)
	Game.life.character.hp = Game.life.character.max_hp
	main._refresh_sheet()
	main.illustration.texture = ArtProvider.location_image("forest", Game.life)
	main._run_combat({"enemies": ["dire_wolf", "bandit", "giant_rat"]})
	var view: CombatView = main.combat_view
	await _wait_for_hero(view)
	await _capture("7_combat.png")
	# Première carte jouable qui demande une cible, sinon l'attaque de base.
	var chosen := -1
	for i in view.combat.deck.hand.size():
		if view.combat.card_unplayable_reason(i) == "" and Cards.target_of(view.combat.deck.hand[i]) == "enemy":
			chosen = i
			break
	if chosen >= 0:
		view._on_card_pressed(chosen)
	else:
		view._on_attack_pressed()
	await _wait_frames(4)
	await _capture("8_combat_targeting.png")
	view._on_target_chosen(view.combat.living("enemy")[0])
	await get_tree().create_timer(0.35).timeout
	await _capture("9_combat_dice.png")
	# Le reste du combat en accéléré : le héros attaque puis termine son tour.
	Engine.time_scale = 4.0
	while view.visible:
		await _wait_for_hero(view)
		if not view.visible:
			break
		if not view.attack_button.disabled:
			view._on_attack_pressed()
			if not view._pending.is_empty():
				view._on_target_chosen(view.combat.living("enemy")[0])
			await _wait_for_hero(view)
		if view.visible and view._hero_turn:
			view._on_end_turn_pressed()
		await _wait_frames(2)
	Engine.time_scale = 1.0
	await _capture("10_combat_end.png")
	get_tree().quit()


## Attend que le héros puisse agir (ou que le combat soit terminé).
func _wait_for_hero(view: CombatView) -> void:
	while view.visible and (not view._hero_turn or view._busy):
		await get_tree().process_frame


func _wait_frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _capture(file: String) -> void:
	for i in 3:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(file))
