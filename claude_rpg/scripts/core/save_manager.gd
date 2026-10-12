extends Node
## Autoload « Saves » : sauvegarde et chargement, en JSON dans user:// (sur le Web : stockage du navigateur).
##   meta.json : ce qui survit à la mort (monde, déblocages, chronique des vies)
##   life.json : la vie en cours (personnage, compagnons, temps, flags…), supprimé à la mort
## Sauvegarde automatique : retour au hub, après un choix, après un combat, à la mort et à la fermeture.
## Un combat déclenché mais pas terminé (LifeState.pending_combat) reprend au chargement.

const VERSION := 1

## Dossier des sauvegardes (les tests utilisent un dossier à part).
var directory := "user://"
## false : aucune écriture (ex. scènes lancées pour des captures d'écran).
var enabled := true


func _ready() -> void:
	load_meta()


func meta_path() -> String:
	return directory.path_join("meta.json")


func life_path() -> String:
	return directory.path_join("life.json")


## Sauvegarde la méta et la vie en cours (ou supprime la sauvegarde de vie si le personnage est mort).
func save_all() -> void:
	if not enabled:
		return
	_write(meta_path(), Meta.to_dict())
	if Game.life != null and not Game.life.dead:
		_write(life_path(), Game.life.to_dict())
	else:
		delete_life()


func load_meta() -> void:
	var data := _read(meta_path())
	if not data.is_empty():
		Meta.load_dict(data)


## Une vie en cours peut-elle être reprise ?
func has_life() -> bool:
	return not _read(life_path()).is_empty()


## Contenu de la sauvegarde de vie, sans la charger ({} s'il n'y en a pas) : pour l'écran titre.
func peek_life() -> Dictionary:
	return _read(life_path())


## Charge la vie en cours dans Game.life ; retourne false s'il n'y en a pas.
func load_life() -> bool:
	var data := _read(life_path())
	if data.is_empty():
		return false
	Game.life = LifeState.from_dict(data)
	Game.life_changed.emit()
	return true


func delete_life() -> void:
	if FileAccess.file_exists(life_path()):
		DirAccess.remove_absolute(life_path())


## Efface tout (nouveau monde) : méta et vie en cours.
func reset_world() -> void:
	Meta.reset()
	delete_life()
	Game.life = null
	if enabled:
		_write(meta_path(), Meta.to_dict())


func _write(path: String, data: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Sauvegarde impossible : %s (%s)" % [path, error_string(FileAccess.get_open_error())])
		return
	file.store_string(JSON.stringify({"version": VERSION, "data": data}, "\t"))


## Lit une sauvegarde ; retourne {} si elle est absente, illisible ou d'une autre version.
func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY or int(parsed.get("version", -1)) != VERSION:
		push_warning("Sauvegarde ignorée (illisible ou d'une autre version) : " + path)
		return {}
	return parsed.get("data", {})
