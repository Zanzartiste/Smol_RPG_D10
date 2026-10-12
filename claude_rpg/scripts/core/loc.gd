class_name Loc
extends RefCounted
## Aide à la localisation.
## - Textes d'interface : la chaîne française sert de clé (style gettext) -> Loc.ui("Continuer").
## - Textes des données : clé dérivée de l'id (ex. "evt.forest_wolf.text"), le texte français
##   du JSON sert de valeur par défaut tant qu'aucune traduction n'existe.

## Ordre des formes dans {g:masculin|féminin|neutre}.
const GENDER_FORMS := {"male": 0, "female": 1, "nonbinary": 2}

static var _gender_regex := RegEx.create_from_string("\\{g:([^|}]*)\\|([^|}]*)\\|([^}]*)\\}")


static func ui(text: String) -> String:
	return String(TranslationServer.translate(text))


static func t(key: String, fallback: String) -> String:
	var translated := String(TranslationServer.translate(key))
	return fallback if translated == key else translated


## Remplace les variables d'un texte :
## {name}, {species}, {class}, {background}, et {g:masculin|féminin|neutre} accordé au genre du personnage
## (ex. « Vous êtes {g:prêt|prête|prêt·e} »).
static func fill(text: String, life: LifeState) -> String:
	if life == null or life.character == null:
		return text
	var ch := life.character
	text = gendered(text, ch.gender)
	return text.format({
		"name": ch.name,
		"species": DB.species[ch.species_id]["name"],
		"class": DB.classes[ch.class_id]["name"],
		"background": DB.backgrounds.get(ch.background_id, {}).get("name", ""),
	})


static func gendered(text: String, gender: String) -> String:
	var form: int = GENDER_FORMS.get(gender, 2)
	var result := text
	for m in _gender_regex.search_all(text):
		result = result.replace(m.get_string(), m.get_string(form + 1))
	return result
