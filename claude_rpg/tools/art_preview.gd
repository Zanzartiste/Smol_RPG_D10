extends Node
## Exporte des planches PNG des images procédurales, pour les vérifier d'un coup d'œil.
##   godot --headless --path . res://tools/art_preview.tscn -- <dossier_de_sortie>
## Sans argument, les planches vont dans user://art_preview/.

const SCALE := 4
const GAP := 2


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else ProjectSettings.globalize_path("user://art_preview")
	DirAccess.make_dir_recursive_absolute(out_dir)

	# Portraits : une ligne par race × classe, une colonne par étape de vie (2 graines).
	var stages: Array = DB.rules["life_stages"].map(func(s): return s["id"])
	var rows: Array[Image] = []
	for race: String in DB.races:
		for cls: String in DB.classes:
			var row: Array[Image] = []
			for seed_value in [11, 12]:
				for stage: String in stages:
					row.append(PixelArt.portrait(DB.races[race]["art"], DB.classes[cls]["art"], stage, hash(race + cls) + seed_value))
			rows.append(_strip(row, true))
	_save(_strip(rows, false), out_dir.path_join("portraits.png"))

	# Décors : une ligne par lieu, une colonne par moment de la journée.
	var scene_rows: Array[Image] = []
	for kind in ["town", "forest", "home"]:
		var row: Array[Image] = []
		for slot: Dictionary in DB.time_slots():
			row.append(PixelArt.scene(kind, slot["id"], hash(kind)))
		scene_rows.append(_strip(row, true))
	_save(_strip(scene_rows, false), out_dir.path_join("scenes.png"))

	print("Planches exportées dans ", out_dir)
	get_tree().quit()


## Assemble des images côte à côte (horizontal) ou les unes sous les autres.
func _strip(images: Array[Image], horizontal: bool) -> Image:
	var w := 0
	var h := 0
	for img in images:
		if horizontal:
			w += img.get_width() + GAP
			h = maxi(h, img.get_height())
		else:
			h += img.get_height() + GAP
			w = maxi(w, img.get_width())
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.05, 0.05, 0.05))
	var pos := 0
	for img in images:
		out.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(pos, 0) if horizontal else Vector2i(0, pos))
		pos += (img.get_width() if horizontal else img.get_height()) + GAP
	return out


func _save(img: Image, path: String) -> void:
	img.resize(img.get_width() * SCALE, img.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
	img.save_png(path)
