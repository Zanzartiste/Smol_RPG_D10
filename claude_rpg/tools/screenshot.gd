extends Node
## Lance l'écran principal, joue quelques actions puis enregistre des captures d'écran.
## Nécessite un rendu (pas de --headless) :
##   godot --path . res://tools/screenshot.tscn -- <dossier_de_sortie>

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else ProjectSettings.globalize_path("user://screenshots")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	Game.new_life(7)
	main._show_hub()
	await _capture(out_dir.path_join("1_hub.png"))
	main._on_location_chosen("forest")
	await _capture(out_dir.path_join("2_event.png"))
	var first_available: Dictionary = EventEngine.visible_choices(Game.current_event, Game.life, Meta).filter(
		func(c): return c["available"])[0]
	main._on_choice(first_available["choice"])
	await _capture(out_dir.path_join("3_result.png"))
	get_tree().quit()


func _capture(path: String) -> void:
	for i in 3:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
