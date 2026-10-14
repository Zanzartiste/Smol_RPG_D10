class_name Weather
extends RefCounted
## Saisons et météo du jour. Réglages : data/rules.json › calendar.
##   seasons : [{"id", "name", "weather": {id de météo: poids}}] — l'année est partagée en parts égales ;
##   weathers : [{"id", "name", "light"?: "dim" | "dark", "wild_only"?}] — "light" assombrit les combats.
## La météo d'un jour est tirée de façon déterministe (le même jour donne toujours le même temps).
## Conditions d'événement : {"type": "season", "in": [...]} et {"type": "weather", "in": [...]}.


static func _calendar() -> Dictionary:
	return DB.rules.get("calendar", {})


static func seasons() -> Array:
	return _calendar().get("seasons", [])


static func weathers() -> Array:
	return _calendar().get("weathers", [])


## Saison d'un jour (jour 1 = début du printemps) : {"id", "name", "weather"}.
static func season_of(day: int) -> Dictionary:
	var list := seasons()
	if list.is_empty():
		return {}
	var day_of_year := posmod(day - 1, DB.days_per_year())
	var index := mini(list.size() - 1, floori(day_of_year * list.size() / float(DB.days_per_year())))
	return list[index]


static func weather_def(id: String) -> Dictionary:
	for w: Dictionary in weathers():
		if w["id"] == id:
			return w
	return {}


## Météo d'un jour : tirée selon les poids de la saison, toujours la même pour un jour donné.
static func weather_of(day: int) -> Dictionary:
	var weights: Dictionary = season_of(day).get("weather", {})
	if weights.is_empty():
		return {}
	var total := 0.0
	for id: String in weights:
		total += float(weights[id])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(day * 7919 + 104729)
	var r := rng.randf() * total
	for id: String in weights:
		r -= float(weights[id])
		if r < 0.0:
			return weather_def(id)
	return weather_def(weights.keys().back())


## « Printemps, pluie ».
static func describe(day: int) -> String:
	var season := season_of(day)
	var weather := weather_of(day)
	if season.is_empty():
		return ""
	return "%s, %s" % [season["name"], String(weather.get("name", "")).to_lower()] if not weather.is_empty() else season["name"]
