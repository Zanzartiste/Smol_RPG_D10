class_name Loc
extends RefCounted
## Aide à la localisation.
## - Textes d'interface : la chaîne française sert de clé (style gettext) -> Loc.ui("Continuer").
## - Textes des données : clé dérivée de l'id (ex. "evt.forest_wolf.text"), le texte français
##   du JSON sert de valeur par défaut tant qu'aucune traduction n'existe.


static func ui(text: String) -> String:
	return String(TranslationServer.translate(text))


static func t(key: String, fallback: String) -> String:
	var translated := String(TranslationServer.translate(key))
	return fallback if translated == key else translated


## Remplace les variables {name}, {race}, {class} dans un texte.
static func fill(text: String, life: LifeState) -> String:
	if life == null or life.character == null:
		return text
	var ch := life.character
	return text.format({
		"name": ch.name,
		"race": DB.races[ch.race_id]["name"],
		"class": DB.classes[ch.class_id]["name"],
	})
