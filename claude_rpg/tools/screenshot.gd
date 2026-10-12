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
	await _capture("1_creation.png")
	Game.start_life(creation.build_character(), 7)
	creation.queue_free()

	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _capture("2_hub.png")
	main._on_location_chosen("forest")
	await _capture("3_event.png")

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
	get_tree().quit()


func _capture(file: String) -> void:
	for i in 3:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(file))
