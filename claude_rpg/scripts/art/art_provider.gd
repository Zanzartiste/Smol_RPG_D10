class_name ArtProvider
extends RefCounted
## Point d'accès unique aux images du jeu.
## Si une image définitive existe dans res://assets/, elle est utilisée ; sinon on génère
## un placeholder pixel art (PixelArt). Pour remplacer un placeholder, il suffit de déposer le fichier :
##   portraits : res://assets/portraits/<species>_<classe>_<étape>.png   (ex. goblin_wizard_adult.png)
##   événements : res://assets/events/<id_événement>.png
##   lieux      : res://assets/locations/<id_lieu>.png
##   créatures  : res://assets/creatures/<id_créature>.png

const PORTRAIT_DIR := "res://assets/portraits/"
const EVENT_DIR := "res://assets/events/"
const LOCATION_DIR := "res://assets/locations/"
const CREATURE_DIR := "res://assets/creatures/"

static var _cache: Dictionary = {}


static func portrait(ch: Character) -> Texture2D:
	var stage := ch.life_stage()
	var file := "%s%s_%s_%s.png" % [PORTRAIT_DIR, ch.species_id, ch.class_id, stage]
	if ResourceLoader.exists(file):
		return load(file)
	var key := "portrait:%s:%s:%s:%d" % [ch.species_id, ch.class_id, stage, ch.art_seed]
	if not _cache.has(key):
		var species_art: Dictionary = DB.species[ch.species_id].get("art", {})
		var class_art: Dictionary = DB.classes[ch.class_id].get("art", {})
		_cache[key] = ImageTexture.create_from_image(PixelArt.portrait(species_art, class_art, stage, ch.art_seed))
	return _cache[key]


## Image d'un combattant sur le champ de bataille : personnage détouré ou sprite de créature.
static func combatant(c: Combatant) -> Texture2D:
	if c.character != null:
		return character_sprite(c.character)
	return creature(c.creature["id"])


## Sprite d'une créature du bestiaire (res://assets/creatures/<id>.png s'il existe).
static func creature(creature_id: String) -> Texture2D:
	var file: String = CREATURE_DIR + creature_id + ".png"
	if ResourceLoader.exists(file):
		return load(file)
	var key: String = "creature:" + creature_id
	if not _cache.has(key):
		_cache[key] = ImageTexture.create_from_image(PixelArt.creature(Creatures.def(creature_id).get("art", {}), hash(creature_id)))
	return _cache[key]


## Sprite détouré d'un personnage (héros, compagnon) pour le champ de bataille.
static func character_sprite(ch: Character) -> Texture2D:
	var key := "sprite:%s:%s:%s:%d" % [ch.species_id, ch.class_id, ch.life_stage(), ch.art_seed]
	if not _cache.has(key):
		var species_art: Dictionary = DB.species[ch.species_id].get("art", {})
		var class_art: Dictionary = DB.classes[ch.class_id].get("art", {})
		_cache[key] = ImageTexture.create_from_image(PixelArt.portrait(species_art, class_art, ch.life_stage(), ch.art_seed, false))
	return _cache[key]


static func event_image(ev: Dictionary, life: LifeState) -> Texture2D:
	var file: String = EVENT_DIR + ev["id"] + ".png"
	if ResourceLoader.exists(file):
		return load(file)
	var location: Variant = ev.get("location")
	var kind: String = ev.get("art", DB.locations.get(location, {}).get("art", "forest" if location == null else ""))
	return _scene(kind, life.slot_id(), hash(ev["id"]))


static func location_image(location_id: String, life: LifeState) -> Texture2D:
	var file := LOCATION_DIR + location_id + ".png"
	if ResourceLoader.exists(file):
		return load(file)
	var kind: String = DB.locations.get(location_id, {}).get("art", "")
	return _scene(kind, life.slot_id(), hash(location_id))


static func _scene(kind: String, slot_id: String, seed_value: int) -> Texture2D:
	var key := "scene:%s:%s:%d" % [kind, slot_id, seed_value]
	if not _cache.has(key):
		_cache[key] = ImageTexture.create_from_image(PixelArt.scene(kind, slot_id, seed_value))
	return _cache[key]
