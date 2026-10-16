extends Node
## Autoload « Game » : déroulement de la vie en cours (création, événements, temps, mort).
## L'interface appelle ces fonctions puis se met à jour via les signaux.

signal life_changed
signal life_ended
signal debug_changed

var life: LifeState
var current_event: Dictionary = {}
## Mode debug : affiche notamment les choix verrouillés. F12 en jeu, ou lancer avec « -- --debug ».
var debug := "--debug" in OS.get_cmdline_user_args()


func toggle_debug() -> void:
	debug = not debug
	debug_changed.emit()


## Commence une vie avec un personnage créé (écran de création).
func start_life(character: Character, seed_value: int = 0) -> void:
	life = LifeState.new()
	life.rng.seed = seed_value if seed_value != 0 else randi()
	life.character = character
	_place_in_start_district(life)
	Social.on_new_life()  # les relations avec le héros repartent de zéro, les souvenirs restent
	current_event = {}
	life_changed.emit()
	Saves.save_all()


## Quartier de départ selon le passé (rules.json › districts) : lieu de départ, marqueur district_<id>, annonce.
static func _place_in_start_district(life: LifeState) -> void:
	var districts: Dictionary = DB.rules.get("districts", {})
	var district_id: String = DB.backgrounds.get(life.character.background_id, {}).get("start_district", districts.get("default", ""))
	for d: Dictionary in districts.get("list", []):
		if d["id"] == district_id:
			life.location = d["location"]
			life.flags["district_" + district_id] = true
			life.notices.append(Loc.ui("Votre vie commence dans %s.") % d["name"])


## Commence une vie avec un personnage aléatoire (tests, lancement direct de la scène principale).
func new_life(seed_value: int = 0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value if seed_value != 0 else randi()
	start_life(Character.create_random(rng, Meta), rng.seed)


func draw_event(location_id: String) -> Dictionary:
	return EventEngine.pick_event(location_id, life, Meta)


func begin_event(ev: Dictionary) -> void:
	current_event = ev
	life.mark_seen(ev["id"])
	Meta.mark_event_seen(ev["id"])


## Lance les dés d'un choix avec test, sans appliquer ses effets.
func roll_check(choice: Dictionary) -> Dictionary:
	return Dice.roll_check(life.character, choice["check"], life.rng)


func resolve_choice(choice: Dictionary, roll: Dictionary = {}) -> Dictionary:
	var result := EventEngine.resolve_choice(current_event, choice, life, Meta, roll)
	if not result["combat"].is_empty():
		life.pending_combat = result["combat"]  # reprendra au chargement si on quitte avant de le jouer
	_after_change()
	Saves.save_all()
	return result


## Combat en cours (null hors combat).
var combat: Combat


func start_combat(spec: Dictionary) -> Combat:
	# Brouillard, orage : un combat en plein air se déroule dans la pénombre (Couvert +1).
	if not spec.has("light") and DB.locations.get(life.location, {}).get("rest", {}).get("type", "") == "camp":
		var light: String = Weather.weather_of(life.day).get("light", "")
		if light != "":
			spec = spec.duplicate()
			spec["light"] = light
	life.pending_combat = spec
	combat = Combat.new(spec, life)
	return combat


## Applique l'issue du combat : récompenses, compagnons tombés, K.-O., puis effets de l'issue
## (victory / defeat / fled). Retourne un résultat au même format que resolve_choice().
func finish_combat() -> Dictionary:
	var c := combat
	combat = null
	life.pending_combat = {}
	var lines: Array[String] = []
	var knockout: bool = c.spec.get("on_defeat", "death") == "knockout"

	if c.outcome == "victory":
		var xp := 0
		for enemy in c.enemies():
			if enemy.fled:
				continue  # une créature enfuie ne laisse ni XP ni butin
			var creature := enemy.creature
			xp += int(creature.get("xp", 0))
			if creature.has("gold"):
				var gold := maxi(0, int(Dice.roll_expr(creature["gold"], life.rng)["total"]))
				life.character.gold += gold
				lines.append(Loc.ui("Butin : %d po") % gold)
			for loot: Dictionary in creature.get("loot", []):
				if life.rng.randf() < float(loot.get("chance", 1.0)):
					life.character.add_item(loot["item"], int(loot.get("count", 1)))
					lines.append(Loc.ui("Butin : %s ×%d") % [Items.name_of(loot["item"]), int(loot.get("count", 1))])
		# Chaque membre du groupe encore debout gagne toute l'XP.
		for member in life.party():
			if member.hp > 0 and xp > 0:
				for new_level in member.add_xp(xp):
					lines.append(Loc.ui("%s atteint le niveau %d ! (classe à choisir)") % [member.name, new_level])
					life.log_journal("level", Loc.ui("%s atteint le niveau %d.") % [member.name, new_level])
		if xp > 0:
			lines.push_front(Loc.ui("+%d XP") % xp)
		var picked := c.recover_thrown()
		if not picked.is_empty():
			lines.append(Loc.ui("Vous ramassez : %s.") % ", ".join(PackedStringArray(picked)))

	# Les membres du groupe à 0 PV étaient inconscients : après une victoire ou une fuite (ou une bagarre),
	# les autres les ramènent à eux (1 PV). Si tout le groupe est tombé dans un combat mortel, ils meurent.
	var wiped: bool = c.outcome == "defeat" and not knockout
	for companion in life.companions.duplicate():
		if companion.hp <= 0:
			if wiped:
				life.companions.erase(companion)
				lines.append(Loc.ui("%s a péri au combat.") % companion.name)
			else:
				companion.hp = 1
				lines.append(Loc.ui("%s reprend connaissance.") % companion.name)
	if life.character.hp <= 0 and not life.dead:
		life.character.hp = 1
		if not knockout:
			lines.append(Loc.ui("Vos compagnons vous ramènent à vous."))

	var key := c.outcome
	var foes := PackedStringArray(c.enemies().map(func(e): return e.name))
	life.log_journal("combat", {"victory": Loc.ui("Victoire contre : %s."), "fled": Loc.ui("Fuite devant : %s."),
		"defeat": Loc.ui("Défaite contre : %s.")}.get(key, "%s") % ", ".join(foes))
	var outcome: Dictionary = c.spec.get(key, {})
	var default_texts := {
		"victory": Loc.ui("Vous êtes {g:victorieux|victorieuse|victorieux·se}."),
		"fled": Loc.ui("Vous parvenez à fuir."),
		"defeat": Loc.ui("Vous êtes {g:vaincu|vaincue|vaincu·e}."),
	}
	var applied := Effects.apply_all(outcome.get("effects", []), life, Meta)
	lines.append_array(applied["lines"])
	if not applied["combat"].is_empty():
		life.pending_combat = applied["combat"]
	_after_change()
	Saves.save_all()
	return {"outcome": key, "text": outcome.get("text", default_texts.get(key, "")), "roll": {},
		"lines": lines, "goto": applied["goto"], "combat": applied["combat"]}


## Fin d'une séquence d'événements (sans « goto ») : le temps avance d'un créneau.
func end_event() -> void:
	current_event = {}
	life.advance_time(1)
	_after_change()
	Saves.save_all()


## Repos du lieu actuel (rules : locations.json › rest) : camper (gratuit, une nuit agitée est possible),
## nuit à l'auberge (payante), dormir chez soi. Repos long : deux périodes, tout le groupe récupère tout ;
## repos court (`short`, gratuit, sans limite) : une période, la moitié des PV et du mana manquants. Retourne {"ok", "text",
## "event_location"} (lieu d'un événement qui interrompt le repos, ou "").
func rest(short := false) -> Dictionary:
	var loc_id := life.location if life.location != "" else DB.location_order[0]
	var spec: Dictionary = DB.locations.get(loc_id, {}).get("rest", {})
	if spec.is_empty():
		return {"ok": false, "text": Loc.ui("Impossible de se reposer ici."), "event_location": ""}
	var cost := 0 if short else int(spec.get("cost", 0))
	if life.character.gold < cost:
		return {"ok": false, "text": Loc.ui("Pas assez d'or (%d po).") % cost, "event_location": ""}
	life.character.gold -= cost
	life.advance_time(1 if short else 2)
	for member in life.party():
		if member.hp > 0:
			if short:
				member.short_rest()
			else:
				member.long_rest()
	var text: String = Loc.ui("Vous faites une pause de quelques heures.") if short else {"camp": Loc.ui("Vous montez le camp et dormez à la belle étoile."),
		"inn": Loc.ui("Vous louez une chambre à l'auberge (%d po) et dormez d'un sommeil de plomb.") % cost,
		"home": Loc.ui("Vous dormez chez vous, dans votre lit.")}.get(spec.get("type", ""), "")
	text += "\n" + (Loc.ui("Le groupe a repris un peu de forces.") if short else Loc.ui("Le groupe a récupéré ses forces."))
	var event_location := ""
	if life.rng.randf() < float(spec.get("event_chance", 0.0)) * (0.5 if short else 1.0):
		event_location = loc_id
		text += "\n" + Loc.ui("Mais la nuit est agitée…")
	_after_change()
	Saves.save_all()
	return {"ok": true, "text": text, "event_location": event_location}


## Nom du repos possible au lieu actuel (bouton de la fiche).
func rest_name() -> String:
	var loc_id := life.location if life != null and life.location != "" else DB.location_order[0]
	return DB.locations.get(loc_id, {}).get("rest", {}).get("name", Loc.ui("Se reposer"))


## Fin d'une interaction sociale : elle a pris un créneau de la journée.
func end_interaction(extra_time := 0) -> void:
	life.advance_time(1 + extra_time)
	_after_change()
	Saves.save_all()


func _after_change() -> void:
	life_changed.emit()
	if life.dead and not life.recorded:
		life.recorded = true
		Social.on_hero_death(life)
		Meta.record_life(life)
		Saves.save_all()  # la méta garde la vie dans la chronique, la sauvegarde de vie est supprimée
		life_ended.emit()
