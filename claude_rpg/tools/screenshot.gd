extends Node
## Ouvre les écrans du jeu, joue quelques actions et enregistre des captures d'écran.
## Nécessite un rendu (pas de --headless) :
##   godot --path . res://tools/screenshot.tscn -- <dossier_de_sortie>

var out_dir := ""


func _ready() -> void:
	Saves.enabled = false  # les captures ne touchent pas aux vraies sauvegardes
	Meta.settings["click_to_continue_combat"] = false  # les combats capturés avancent seuls
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else ProjectSettings.globalize_path("user://screenshots")
	DirAccess.make_dir_recursive_absolute(out_dir)

	# Écran titre, avec une chronique d'exemple.
	Meta.chronicle.append({"name": "Grik", "species": "goblin", "class": "wizard", "age": 13, "days": 41, "level": 2,
		"cause": "Dévoré par un loup"})
	Meta.unlock("class:rogue")
	var title: Control = load("res://scenes/title.tscn").instantiate()
	add_child(title)
	await _capture("0_title.png")
	title.queue_free()
	Meta.reset()
	Meta.creator_points = 23  # pour montrer l'onglet Creator Points

	var creation: Control = load("res://scenes/creation.tscn").instantiate()
	add_child(creation)
	creation._species_buttons["tiefling"].button_pressed = true
	creation._on_species_selected("tiefling")  # pour montrer le choix d'ascendance
	creation._class_buttons["fighter"].button_pressed = true
	creation._on_class_selected("fighter")
	creation._on_background_selected("custom")  # le passé Sur mesure : ses longues listes de choix
	for tab in creation.pages.get_tab_count():
		creation.tab_buttons.get_child(tab).button_pressed = true
		creation.pages.current_tab = tab
		await _capture("1_creation_%d.png" % tab)
	Game.start_life(creation.build_character(), 7)
	creation.queue_free()

	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _capture("2_hub.png")
	# Tiroir latéral : chaque page (une quête en cours pour l'exemple).
	Quests.apply(Game.life, "ysolde_herbs", "start")
	main._refresh_sheet()
	for page_id: String in SideDrawer.PAGES:
		if main.drawer._tab_buttons[page_id].visible:
			main.drawer._on_tab_pressed(page_id)  # épinglée : la souris de l'outil n'est pas sur le tiroir
			await get_tree().create_timer(0.4).timeout
			await _capture("2_drawer_%s.png" % page_id)
	main.drawer.close()
	await get_tree().create_timer(0.4).timeout
	for item_id in ["longsword_plus_1", "ring_of_protection", "ring_fire_resistance", "potion_heal"]:
		Game.life.character.add_item(item_id)
	Game.life.companions.append(Character.create_companion("mira"))
	main._refresh_sheet()
	main.open_inventory()
	main._overlay._on_equip("ring_of_protection")
	await _capture("2b_inventory.png")
	main._overlay.close_view()
	Game.life.character.gold = 120
	Game.life.character.add_item("wolf_pelt", 2)
	Game.life.character.add_item("iron_ore", 1)
	main._on_location_chosen("town")
	await _capture("2c_town_menu.png")
	main.open_shop("forge")
	for tab in ["buy", "sell", "craft", "upgrade"]:
		main._overlay.show_tab(tab)
		await _capture("2d_forge_%s.png" % tab)
	main._overlay.close_view()
	# Social : gens présents, conversation, échange, carnet.
	main._show_people("town")
	await _capture("2e_people.png")
	var people := Social.at_location("town", Game.life.rng)
	var target: Npc = people.filter(func(n): return n.role == "innkeeper")[0]
	target.player["friendship"] = 35
	main.open_social(target)
	var social: SocialView = main._overlay
	for action_id in ["chat", "ask_about", "joke", "flirt"]:
		social._on_action(action_id)
	await _capture("2f_social.png")
	main._open_npc_trade(target, social)
	await _capture("2g_trade.png")
	get_children().back()
	for child in main.get_children():
		if child is NpcTradeView:
			child.close_view()
	social.close_view()
	main.open_carnet()
	await _capture("2h_carnet.png")
	main._overlay.close_view()
	main.drawer.open("map")
	await _capture("2i_map.png")
	main.drawer.close()
	main._show_hub()
	Meta.settings["manual_skill_ability"] = true  # pour montrer les boutons d'attribut
	main._on_location_chosen("forest")
	main._show_event(DB.events["forest_wolf"])  # un événement avec des tests de dés
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

	# Combat avec Mira contre un groupe mixte (le joueur contrôle le héros et Mira).
	Effects.apply_all([{"type": "recruit", "companion": "mira"}], Game.life, Meta)
	Game.life.character.hp = Game.life.character.max_hp
	main._refresh_sheet()
	main.illustration.texture = ArtProvider.location_image("forest", Game.life)
	main._run_combat({"enemies": ["dire_wolf", "bandit", "giant_rat"]})
	var view: CombatView = main.combat_view
	await get_tree().create_timer(1.2).timeout
	await _capture("6c_initiative.png")
	await _wait_for_hero(view)
	await _capture("7_combat.png")
	# Une action qui demande une cible (plusieurs ennemis : le champ de bataille passe en mode ciblage).
	view._on_action_pressed(Actions.def("weapon_attack"))
	await _wait_frames(4)
	await _capture("8_combat_targeting.png")
	view._on_target_chosen(view.combat.living("enemy")[0])
	await get_tree().create_timer(0.35).timeout
	await _capture("9_combat_dice.png")
	# Le reste du combat en accéléré : chaque personnage joue l'action choisie automatiquement.
	Engine.time_scale = 4.0
	while view.visible:
		await _wait_for_hero(view)
		if not view.visible:
			break
		if view.combat.actions_left == 1 and not _reaction_shot:
			view._on_pass_pressed()  # garde une action : une réaction sera proposée au tour ennemi
			await _wait_frames(2)
			continue
		var choice := view.combat.auto_choice(view._actor)
		if choice["target"] != null and choice["action"].get("target") in CombatEffects.CHOSEN_TARGETS:
			view._execute({"kind": "action", "action": choice["action"]}, choice["target"])
		else:
			view._on_action_pressed(choice["action"])
		await _wait_frames(2)
	Engine.time_scale = 1.0
	await _capture("10_combat_end.png")
	get_tree().quit()


var _reaction_shot := false


## Attend que le héros puisse agir (ou que le combat soit terminé). Une réaction proposée est capturée
## (la première fois), puis acceptée.
func _wait_for_hero(view: CombatView) -> void:
	while view.visible and (view._actor == null or view._busy):
		if not view._reaction.is_empty():
			if not _reaction_shot:
				_reaction_shot = true
				var scale := Engine.time_scale
				Engine.time_scale = 1.0
				await _capture("9b_reaction.png")
				Engine.time_scale = scale
			view._on_reaction(true)
		await get_tree().process_frame


func _wait_frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _capture(file: String) -> void:
	for i in 3:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(file))
