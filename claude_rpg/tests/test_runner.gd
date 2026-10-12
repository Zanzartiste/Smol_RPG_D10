extends Node
## Tests automatisés, sans interface. Lancer depuis le dossier claude_rpg :
##   godot --headless --path . res://tests/test_runner.tscn
## Code de sortie : 0 si tout passe, 1 sinon.

var _checks := 0
var _failures := 0


const TESTS := [
	"_test_data",
	"_test_character",
	"_test_conditions",
	"_test_effects",
	"_test_engine",
	"_test_creation",
	"_test_dice_tray",
	"_test_simulation",
	"_test_art",
]


func _ready() -> void:
	for test: String in TESTS:
		# Une erreur de script interrompt la fonction, qui retourne alors null au lieu de true.
		_expect(call(test) == true, "%s s'exécute jusqu'au bout (voir les erreurs ci-dessus)" % test)
	print("\n%d vérifications, %d échec(s)" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("ÉCHEC : " + label)


func _new_life(race := "goblin", cls := "wizard") -> LifeState:
	var life := LifeState.new()
	life.rng.seed = 42
	life.character = Character.create(race, cls, "Testeur")
	return life


func _test_data() -> bool:
	for e in DB.errors:
		printerr("  " + e)
	_expect(DB.errors.is_empty(), "les données JSON sont valides")
	_expect(DB.events.size() >= 15, "au moins 15 événements chargés")
	for loc_id in DB.location_order:
		_expect(not DB.events_for(loc_id).is_empty(), "le lieu %s a des événements" % loc_id)
	return true

func _test_character() -> bool:
	var c := Character.create("goblin", "wizard", "Grik")
	_expect(c.abilities["int"] == 15, "magicien : INT 15")
	_expect(c.abilities["dex"] == 15, "gobelin : DEX 13 + 2")
	_expect(c.ability_mod("int") == 2, "modificateur INT +2")
	_expect(c.ability_mod("str") == -1, "modificateur FOR -1")
	_expect(c.skill_mod("arcana") == 4, "Arcanes maîtrisé : +2 +2")
	_expect(c.skill_mod("athletics") == -1, "Athlétisme non maîtrisé : -1")
	_expect(c.max_hp == 6 + 2, "PV : d6 + CON")
	_expect(c.age_years() == 12 and c.life_stage() == "adult", "gobelin de 12 ans adulte")
	var levels := c.add_xp(300)
	_expect(levels == [2] and c.level == 2, "300 XP => niveau 2")
	c.age_days = DB.days_per_year() * 30
	_expect(c.life_stage() == "elder", "gobelin de 42 ans âgé")
	return true

func _test_conditions() -> bool:
	var life := _new_life()
	var meta := MetaState.new()
	_expect(Conditions.check({"type": "race", "in": ["goblin"]}, life, meta), "condition race")
	_expect(not Conditions.check({"type": "class", "in": ["fighter"]}, life, meta), "condition classe")
	_expect(Conditions.check({"type": "ability", "id": "int", "min": 15}, life, meta), "condition attribut min")
	_expect(not Conditions.check({"type": "flag", "id": "x"}, life, meta), "flag absent")
	life.flags["x"] = true
	_expect(Conditions.check({"type": "flag", "id": "x"}, life, meta), "flag présent")
	_expect(not Conditions.check({"type": "not", "condition": {"type": "flag", "id": "x"}}, life, meta), "not")
	_expect(Conditions.check({"type": "any", "conditions": [
		{"type": "flag", "id": "nope"}, {"type": "gold", "min": 1}]}, life, meta), "any")
	_expect(Conditions.check({"type": "time", "in": ["morning"]}, life, meta), "matin au départ")
	_expect(Conditions.describe({"type": "ability", "id": "int", "min": 12}) == "INT 12+", "description de condition")
	meta.free()
	return true

func _test_effects() -> bool:
	var life := _new_life()
	var meta := MetaState.new()
	var ch := life.character
	var res := Effects.apply_all([
		{"type": "gold", "amount": 10},
		{"type": "add_item", "id": "healing_herbs", "count": 3},
		{"type": "set_world_flag", "id": "w"},
		{"type": "unlock", "id": "race:elf"},
		{"type": "goto", "event": "forest_wisp"},
	], life, meta)
	_expect(ch.gold == 25, "gain d'or")
	_expect(ch.item_count("healing_herbs") == 3, "ajout d'objets")
	_expect(meta.has_world_flag("w"), "flag monde")
	_expect(meta.is_race_available("elf"), "déblocage de race")
	_expect(res["goto"] == "forest_wisp", "goto")
	Effects.apply_all([{"type": "gold", "amount": -100}], life, meta)
	_expect(ch.gold == 0, "l'or ne descend pas sous 0")
	Effects.apply_all([{"type": "hp", "amount": -99, "cause": "Test"}], life, meta)
	_expect(life.dead and life.death_cause == "Test" and ch.hp == 0, "mort par PV à 0")
	meta.free()
	return true

func _test_engine() -> bool:
	var life := _new_life("human", "fighter")
	var meta := MetaState.new()
	var ev: Dictionary = DB.events["town_merchant_meet"]
	_expect(EventEngine.is_eligible(ev, life, meta), "événement unique éligible au départ")
	life.mark_seen("town_merchant_meet")
	_expect(not EventEngine.is_eligible(ev, life, meta), "événement unique plus éligible après passage")
	_expect(not EventEngine.is_eligible(DB.events["town_guards_goblin"], life, meta), "événement gobelin exclu pour un humain")
	_expect(not EventEngine.is_eligible(DB.events["town_tavern_brawl"], life, meta), "taverne exclue le matin")
	life.advance_time(2)
	_expect(life.slot_id() == "evening", "le temps avance jusqu'au soir")
	_expect(EventEngine.is_eligible(DB.events["town_tavern_brawl"], life, meta), "taverne possible le soir")
	life.advance_time(1)
	_expect(life.day == 2 and life.slot == 0, "nouveau jour")

	var market: Dictionary = DB.events["town_market"]
	life.character.gold = 0
	var choices := EventEngine.visible_choices(market, life, meta)
	_expect(choices.size() == 4, "les choix verrouillés restent visibles")
	_expect(not choices[0]["available"] and choices[0]["reason"] == "Or 10+", "raison du verrouillage affichée")

	var shrine: Dictionary = DB.events["forest_shrine"]
	_expect(EventEngine.visible_choices(shrine, life, meta).size() == 2, "choix masqué sans le flag")
	meta.free()
	return true

func _test_creation() -> bool:
	var screen: Control = load("res://scenes/creation.tscn").instantiate()
	add_child(screen)
	var ch: Character = screen.build_character()
	_expect(ch.name != "", "création : un nom est proposé")
	_expect(Meta.is_race_available(ch.race_id) and Meta.is_class_available(ch.class_id),
		"création : race et classe de départ disponibles")
	var locked := 0
	for button: Button in screen.race_buttons.get_children() + screen.class_buttons.get_children():
		if button.disabled:
			locked += 1
	_expect(locked == 2, "création : Elfe et Roublard verrouillés au départ")
	screen._on_class_selected("fighter")
	screen.name_edit.text = "Bob"
	screen._on_name_typed("Bob")
	screen._on_race_selected("goblin")
	ch = screen.build_character()
	_expect(ch.name == "Bob" and ch.class_id == "fighter" and ch.race_id == "goblin",
		"création : le nom tapé est conservé au changement de race")
	screen.free()
	return true

func _test_dice_tray() -> bool:
	var tray := DiceTray.new()
	tray.size = Vector2(800, 240)
	add_child(tray)
	tray.play({"dice": [{"sides": 20, "value": 17}, {"sides": 6, "value": 3}, {"sides": 8, "value": 8}],
		"mod": 2, "dc": 12, "success": true, "stat": "Test"})
	_expect(tray.is_playing() and tray._notation() == "Test : 1d20 + 1d6 + 1d8 + 2", "dés : notation")
	var elapsed := 0.0
	var on_tray := true
	while tray.is_playing() and elapsed < 10.0:
		tray._process(1.0 / 60.0)
		for d in tray._dice:
			on_tray = on_tray and Rect2(Vector2.ZERO, tray.size).grow(1.0).has_point(d["pos"])
		elapsed += 1.0 / 60.0
	_expect(on_tray, "dés : restent sur le plateau")
	_expect(not tray.is_playing() and elapsed < 5.0, "dés : l'animation se termine (%.1f s)" % elapsed)
	_expect(tray._dice.map(func(d): return d["shown"]) == [17, 3, 8], "dés : affichent les valeurs tirées")
	tray.free()
	return true

## Joue des centaines d'actions au hasard sur plusieurs vies pour débusquer les erreurs d'exécution.
func _test_simulation() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var deaths := 0
	Game.new_life(1)
	for step in 1500:
		if Game.life.dead:
			deaths += 1
			Game.new_life(step + 2)
		# Rarement à la maison, pour que des personnages meurent et que la chronique soit testée.
		var loc: String = "home" if rng.randf() < 0.1 else ["town", "forest"][rng.randi_range(0, 1)]
		var ev := Game.draw_event(loc)
		var guard := 0
		while not ev.is_empty() and guard < 10:
			guard += 1
			Game.begin_event(ev)
			var options := EventEngine.visible_choices(ev, Game.life, Meta).filter(func(c): return c["available"])
			if options.is_empty():
				_expect(false, "%s : aucun choix disponible" % ev["id"])
				break
			var result := Game.resolve_choice(options[rng.randi_range(0, options.size() - 1)]["choice"])
			if Game.life.dead:
				break
			ev = DB.events[result["goto"]] if result["goto"] != "" else {}
		if not Game.life.dead:
			Game.end_event()
	var unseen := DB.events.keys().filter(func(id): return not Meta.seen_events.has(id))
	print("Simulation : %d morts, %d vies en chronique, événements jamais tirés : %s" % [
		deaths, Meta.chronicle.size(), unseen])
	_expect(deaths > 0, "la simulation produit des morts")
	_expect(Meta.chronicle.size() == deaths + (1 if Game.life.dead else 0), "chaque mort est inscrite dans la chronique")
	_expect(unseen.size() <= 2, "presque tous les événements sont atteignables")
	return true

func _test_art() -> bool:
	var c := Character.create("goblin", "wizard", "Grik")
	var img := PixelArt.portrait(DB.races["goblin"]["art"], DB.classes["wizard"]["art"], "adult", 7)
	_expect(img.get_width() == PixelArt.PORTRAIT_SIZE, "portrait généré")
	_expect(img.get_data() == PixelArt.portrait(DB.races["goblin"]["art"], DB.classes["wizard"]["art"], "adult", 7).get_data(),
		"portrait déterministe")
	_expect(ArtProvider.portrait(c) != null, "ArtProvider fournit un portrait")
	for kind in ["forest", "town", "home", "unknown"]:
		_expect(PixelArt.scene(kind, "evening", 3).get_width() == PixelArt.SCENE_W, "décor %s généré" % kind)
	return true
