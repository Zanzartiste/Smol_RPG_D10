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
	"_test_point_buy",
	"_test_rule_apis",
	"_test_equipment",
	"_test_feats",
	"_test_defenses",
	"_test_effects",
	"_test_aging",
	"_test_engine",
	"_test_dice_expressions",
	"_test_combat",
	"_test_companions",
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


func _new_life(species := "goblin", cls := "wizard", options := {}) -> LifeState:
	var life := LifeState.new()
	life.rng.seed = 42
	life.character = Character.create(species, cls, "Testeur", options)
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
	# Modèle du magicien : 15/14/13/12/10/8 selon ses priorités, +2 INT, +1 CON. Aucun effet de l'espèce.
	var c := Character.create("goblin", "wizard", "Grik", {"background": "sage", "gender": "female"})
	_expect(c.abilities["int"] == 17 and c.abilities["con"] == 15, "modèle du magicien : INT 15+2, CON 14+1")
	_expect(c.abilities["dex"] == 13 and c.abilities["str"] == 8, "l'espèce ne modifie pas les attributs")
	# Passé Érudit -> don « Érudit des arcanes » : +1 INT (17 -> 18) et maîtrise de Nature.
	_expect(c.has_feat("scholar") and c.ability_score("int") == 18, "don du passé appliqué à la création")
	_expect(c.ability_mod("int") == 4 and c.ability_mod("str") == -1, "modificateurs")
	_expect(c.skill_mod("arcana") == 6, "Arcanes maîtrisé (classe) : +4 +2")
	_expect(c.is_proficient("history") and c.skill_mod("history") == 6, "Histoire maîtrisée (passé Érudit)")
	_expect(c.is_proficient("nature"), "Nature maîtrisée (don du passé)")
	_expect(c.skill_mod("athletics") == -1, "Athlétisme non maîtrisé : -1")
	_expect(c.max_hp == 6 + 2, "PV : d6 + CON")
	_expect(c.size() == "small" and Character.create("human", "wizard", "H").size() == "medium",
		"la taille dépend de l'espèce")
	_expect(c.age_years() == 12 and c.life_stage() == "adult", "gobelin de 12 ans adulte")
	_expect(Character.create("human", "fighter", "N", {"background": "noble"}).gold == 15 + 25, "or du passé Noble")

	# PV : d10 + CON (+2) au niveau 1 pour un guerrier au modèle (CON 15).
	var life := _new_life("human", "fighter")
	var f := life.character
	_expect(f.max_hp == 12 and f.hp == 12, "PV du guerrier : 10 + 2")
	f.hp = 7
	life.change_ability("con", -2, "test")
	_expect(f.max_hp == 11 and f.hp == 6, "CON 15 -> 13 : PV max et actuels -1")
	life.change_ability("con", 4, "test")
	_expect(f.max_hp == 13 and f.hp == 8, "CON 13 -> 17 : PV max et actuels +2")
	f.add_xp(300)
	_expect(f.level == 2 and f.max_hp == 13 + 6 + 3, "niveau 2 : + (d10/2 + 1) + CON")
	f.hp = 1
	life.change_ability("con", -10, "Affaibli")
	_expect(life.dead and life.death_cause == "Affaibli", "une baisse de CON qui vide les PV tue")
	var levels := c.add_xp(300)
	_expect(levels == [2] and c.level == 2, "300 XP => niveau 2")
	c.age_days = DB.days_per_year() * 30
	_expect(c.life_stage() == "elder", "gobelin de 42 ans âgé")
	return true


func _test_rule_apis() -> bool:
	_expect(Abilities.ids() == ["str", "dex", "con", "int", "wis", "cha"], "attributs dans l'ordre du JSON")
	_expect(Abilities.name_of("wis") == "Sagesse" and Abilities.short_of("wis") == "SAG", "noms d'attributs")
	_expect(Abilities.modifier(8) == -1 and Abilities.modifier(15) == 2 and Abilities.modifier(1) == -5, "modificateurs")
	_expect(Skills.ids().size() == 18 and Skills.ability_of("stealth") == "dex", "compétences")
	_expect(Skills.names_of(["arcana", "history"]) == "Arcanes, Histoire", "noms de compétences")
	_expect(DamageTypes.ids().size() == 13 and DamageTypes.name_of("fire") == "Feu", "types de dégâts")
	_expect(DamageTypes.is_physical("slashing") and not DamageTypes.is_physical("fire"), "dégâts physiques")
	_expect(StatusEffects.name_of("poisoned") == "Empoisonné", "états")

	# Ajouter un attribut ou une compétence dans les données se répercute partout.
	DB.skills["_cooking"] = {"id": "_cooking", "name": "Cuisine", "ability": "wis"}
	var c := Character.create("human", "fighter", "Chef")
	_expect(c.skill_mod("_cooking") == c.ability_mod("wis") and "Cuisine" in CharacterSheet.bbcode(c),
		"une nouvelle compétence est utilisable et affichée sans autre modification")
	DB.skills.erase("_cooking")
	return true


func _test_equipment() -> bool:
	_expect(Equipment.armor_class("", "", 2) == 12, "sans armure : 10 + DEX")
	_expect(Equipment.armor_class("leather", "", 3) == 14, "armure légère : base + DEX")
	_expect(Equipment.armor_class("breastplate", "", 3) == 16, "armure intermédiaire : DEX plafonnée à 2")
	_expect(Equipment.armor_class("chain_mail", "shield", 3) == 18, "armure lourde + bouclier : DEX ignorée")
	_expect(Equipment.attack_ability("rapier", 3, 1) == "str" and Equipment.attack_ability("rapier", 1, 3) == "dex",
		"finesse : meilleur de FOR et DEX")
	_expect(Equipment.attack_ability("shortbow", 5, 0) == "dex", "arme à distance : DEX")
	_expect(Equipment.weapon_damage("longsword") == "1d8" and Equipment.weapon_damage("longsword", true) == "1d10",
		"arme polyvalente")
	_expect(Equipment.describe("longsword") == "Épée longue — 1d8 tranchant (polyvalente 1d10)", "description d'arme")

	var c := Character.create("human", "fighter", "Testeur")
	_expect(c.weapon_id() == "longsword" and c.armor_class() == 16, "équipement de départ de la classe")
	c.equip("shield")
	_expect(c.armor_class() == 18 and c.weapon_damage() == "1d8", "bouclier : +2 CA, épée à une main")
	c.equip("greataxe")
	_expect(not c.equipment.has("off_hand") and c.weapon_damage() == "1d12", "arme à deux mains : le bouclier est retiré")
	c.equip("shield")
	_expect(c.weapon_id() == Equipment.UNARMED, "bouclier : l'arme à deux mains est rangée")

	var life := _new_life("human", "fighter")
	Effects.apply_all([{"type": "equip", "id": "rapier"}], life, Meta)
	_expect(Conditions.check({"type": "equipped", "id": "rapier"}, life, Meta), "effet equip et condition equipped")
	return true


func _test_feats() -> bool:
	var life := _new_life("human", "wizard")
	var c := life.character
	var hp := c.max_hp
	var init := c.initiative_bonus()
	Effects.apply_all([{"type": "add_feat", "id": "tough"}, {"type": "add_feat", "id": "alert"}], life, Meta)
	_expect(c.max_hp == hp + 2 and c.hp == c.max_hp, "Robuste : +2 PV par niveau")
	_expect(c.initiative_bonus() == init + 5, "Vigilant : +5 à l'initiative")
	c.add_xp(300)
	_expect(c.max_hp == hp + 2 + 4 + 2 + 2, "Robuste suit les niveaux")
	var str_before := c.ability_score("str")
	c.add_feat("athlete")
	_expect(c.ability_score("str") == str_before + 1 and c.abilities["str"] == str_before, "Athlète : +1 FOR (bonus, base inchangée)")
	_expect(c.is_proficient("athletics"), "Athlète : maîtrise d'Athlétisme")
	_expect(Conditions.check({"type": "has_feat", "id": "alert"}, life, Meta), "condition has_feat")
	_expect(not c.add_feat("alert"), "pas de don en double")

	# Chaque passé accorde un don ; tous les 4 niveaux : +1 attribut au choix et un don.
	for bg_id: String in DB.backgrounds:
		_expect(Feats.has(Feats.for_background(bg_id)), "le passé %s accorde un don" % bg_id)
	var soldier := Character.create("human", "fighter", "Soldat", {"background": "soldier"})
	var sword := Combatant.from_character(soldier, true)
	_expect(sword.damage_expr(DB.actions["weapon_attack"]) == "1d10+4", "Frappe brutale : +1 aux dégâts d'arme")
	var hero := Character.create("human", "fighter", "Héros")
	hero.add_xp(300)
	_expect(hero.level == 2 and not hero.has_pending_advancement(), "niveau 2 : pas d'amélioration")
	hero.add_xp(2700 - 300)
	_expect(hero.level == 4 and hero.pending_feats == 1 and hero.pending_ability_points == 1, "niveau 4 : attribut + don")
	_expect(hero.increase_ability("str") and hero.abilities["str"] == 18, "+1 FOR (17 -> 18)")
	_expect(hero.pending_ability_points == 0 and not hero.increase_ability("dex"), "un seul point à placer")
	_expect("alert" in hero.available_feats() and "elemental_adept" not in hero.available_feats(),
		"dons disponibles selon les prérequis")
	_expect(not hero.choose_feat("elemental_adept"), "impossible de choisir un don sans les prérequis")
	_expect(hero.choose_feat("alert") and hero.pending_feats == 0 and hero.has_feat("alert"), "choix d'un don")
	hero.add_xp(355000)
	_expect(hero.level == Progression.max_level() and Progression.max_level() == 20, "niveau maximum 20")
	_expect(hero.pending_feats == 4 and hero.pending_ability_points == 4, "améliorations aux niveaux 8, 12, 16 et 20")
	_expect(hero.proficiency_bonus() == 6, "maîtrise +6 au niveau 20")
	var clumsy := Character.create("human", "wizard", "x",
		{"abilities": {"str": 8, "dex": 10, "con": 14, "int": 15, "wis": 12, "cha": 13}})
	_expect(not Feats.meets_prerequisites("defensive_duelist", clumsy),
		"prérequis non remplis (DEX 13)")
	_expect(Feats.meets_prerequisites("defensive_duelist", Character.create("human", "rogue", "x")),
		"prérequis remplis")
	return true


func _test_defenses() -> bool:
	var d := Defenses.from_dict({"resistances": ["fire"], "immunities": ["poison"], "vulnerabilities": ["cold"],
		"status_immunities": ["poisoned"]})
	_expect(DamageTypes.apply(9, "fire", d)["amount"] == 4, "résistance : moitié, arrondie à l'inférieur")
	_expect(DamageTypes.apply(9, "poison", d)["amount"] == 0, "immunité : 0")
	_expect(DamageTypes.apply(9, "cold", d)["amount"] == 18, "vulnérabilité : double")
	_expect(DamageTypes.apply(9, "slashing", d) == {"amount": 9, "note": ""}, "pas de défense : inchangé")
	d.add(Defenses.VULNERABILITY, "fire")
	_expect(DamageTypes.apply(9, "fire", d)["amount"] == 9, "résistance et vulnérabilité s'annulent")
	_expect(d.is_immune_to_status("poisoned") and Defenses.from_dict(d.to_dict()).to_dict() == d.to_dict(),
		"immunité d'état et aller-retour JSON")
	_expect(d.describe().begins_with("Résistances : Feu"), "description des défenses")

	# Défenses de l'espèce (elfe : immunisé au sommeil magique) et défenses propres au personnage.
	var elf := Character.create("elf", "wizard", "Lia")
	_expect(elf.all_defenses().is_immune_to_status("asleep"), "elfe : immunité à l'état Endormi")
	var life := _new_life("human", "fighter")
	Effects.apply_all([{"type": "add_defense", "kind": "resistance", "id": "fire"}], life, Meta)
	_expect(life.character.all_defenses().has(Defenses.RESISTANCE, "fire"), "effet add_defense")
	_expect(Conditions.check({"type": "defense", "kind": "resistance", "id": "fire"}, life, Meta), "condition defense")
	var hp := life.character.hp
	var res := Effects.apply_all([{"type": "hp", "amount": -6, "damage_type": "fire"}], life, Meta)
	_expect(life.character.hp == hp - 3 and res["lines"][0] == "-3 PV (résistance)", "dégâts d'événement typés et résistance")

	# En combat : un ennemi résistant aux dégâts tranchants encaisse la moitié.
	DB.enemies["_golem"] = {"id": "_golem", "name": "Golem", "ac": 1, "hp": "100", "abilities": {},
		"attacks": [{"name": "Poing", "to_hit": 0, "damage": "1", "damage_type": "bludgeoning"}],
		"defenses": {"resistances": ["slashing"]}}
	Game.start_life(Character.create("human", "fighter", "Testeur"), 3)
	var combat := Game.start_combat({"enemies": ["_golem"]})
	var golem := combat.enemies()[0]
	var hero := combat.allies()[0]
	var beats := combat.perform(hero, DB.actions["weapon_attack"], golem)
	if beats.size() == 2:
		var dealt := 100 - golem.hp
		_expect(dealt <= floori((10 + 3) * 2 / 2.0) and "résistance" in beats[1]["text"], "combat : résistance appliquée")
	DB.enemies.erase("_golem")
	Game.combat = null

	# Validation : une espèce ne peut pas modifier les attributs.
	var errors: Array[String] = []
	DataValidator._validate_modifiers(DB, [{"type": "ability", "id": "str", "amount": 2}], "test", errors, false)
	_expect(errors.any(func(e): return "espèce" in e), "le validateur refuse un bonus d'attribut d'espèce")
	return true


func _test_point_buy() -> bool:
	var pb := PointBuy.from_class("wizard")
	_expect(pb.remaining() == 0 and pb.is_valid(), "le modèle de classe dépense exactement 27 points")
	_expect(not pb.can_increase("str"), "plus de points disponibles")
	pb.decrease("int")
	_expect(pb.base["int"] == 14 and pb.remaining() == 2, "15 -> 14 rend 2 points")
	pb.increase("str")
	_expect(pb.base["str"] == 9 and pb.remaining() == 1, "8 -> 9 coûte 1 point")
	for i in 10:
		pb.decrease("str")
	_expect(pb.base["str"] == 8, "pas en dessous de 8")
	pb.set_bonus(1, "int")
	_expect(pb.bonuses == ["con", "int"] and pb.final_score("con") == 16 and pb.final_score("int") == 15,
		"donner le +1 à l'attribut du +2 échange les bonus")
	var max_pb := PointBuy.from_class("fighter")
	max_pb.decrease("con")
	max_pb.decrease("con")
	_expect(not max_pb.can_increase("str"), "pas au-dessus de 15 avant bonus")
	return true


func _test_conditions() -> bool:
	var life := _new_life()
	var meta := MetaState.new()
	_expect(Conditions.check({"type": "species", "in": ["goblin"]}, life, meta), "condition espèce")
	_expect(Conditions.check({"type": "size", "in": ["small"]}, life, meta), "condition taille")
	_expect(Conditions.check({"type": "gender", "in": ["nonbinary"]}, life, meta), "condition genre (par défaut)")
	_expect(not Conditions.check({"type": "background", "in": ["sage"]}, life, meta), "condition passé")
	_expect(Conditions.describe({"type": "size", "in": ["tiny", "small"]}) == "Taille : Très petite / Petite",
		"description de la condition de taille")
	_expect(Loc.gendered("Vous êtes {g:prêt|prête|prêt·e} !", "female") == "Vous êtes prête !", "accord féminin")
	_expect(Loc.gendered("{g:il|elle|iel} et {g:un|une|un·e}", "nonbinary") == "iel et un·e", "accord neutre")
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
		{"type": "unlock", "id": "species:elf"},
		{"type": "goto", "event": "forest_wisp"},
	], life, meta)
	_expect(ch.gold == 25, "gain d'or")
	_expect(ch.item_count("healing_herbs") == 3, "ajout d'objets")
	_expect(meta.has_world_flag("w"), "flag monde")
	_expect(meta.is_species_available("elf"), "déblocage d'espèce")
	_expect(res["goto"] == "forest_wisp", "goto")
	Effects.apply_all([{"type": "gold", "amount": -100}], life, meta)
	_expect(ch.gold == 0, "l'or ne descend pas sous 0")
	Effects.apply_all([{"type": "hp", "amount": -99, "cause": "Test"}], life, meta)
	_expect(life.dead and life.death_cause == "Test" and ch.hp == 0, "mort par PV à 0")

	life = _new_life()
	Effects.apply_all([{"type": "ability", "id": "str", "amount": -20, "cause": "Épuisé"}], life, meta)
	_expect(life.dead and life.death_cause == "Épuisé", "un attribut à 0 tue le personnage")
	meta.free()
	return true


func _test_aging() -> bool:
	var life := _new_life("human", "fighter")
	var ch := life.character
	var per_year := DB.days_per_year() * DB.slots_per_day()
	life.advance_time(per_year * (60 - 18))
	_expect(ch.age_years() == 60 and ch.abilities == Character.create("human", "fighter", "x").abilities,
		"pas de perte d'attribut jusqu'à l'âge limite")
	var total_before := 0
	for id in ch.abilities:
		total_before += ch.abilities[id]
	life.take_notices()
	life.advance_time(per_year)
	var total_after := 0
	for id in ch.abilities:
		total_after += ch.abilities[id]
	_expect(total_after == total_before - 1, "au-delà de l'âge limite, -1 à un attribut par an")
	_expect(life.take_notices().any(func(n): return n.begins_with("Le poids des ans")), "le joueur est prévenu")
	life.advance_time(per_year * 200)
	_expect(life.dead and life.death_cause == "Mort de vieillesse", "la vieillesse finit par tuer")
	_expect(ch.abilities.values().has(0), "mort quand un attribut atteint 0")
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
	_expect(choices.size() == 1 and choices[0]["choice"]["id"] == "leave", "les choix verrouillés sont cachés")
	choices = EventEngine.visible_choices(market, life, meta, true)
	_expect(choices.size() == 4, "en debug, les choix verrouillés sont visibles")
	_expect(not choices[0]["available"] and choices[0]["reason"] == "Or 10+", "en debug, la raison est affichée")

	var shrine: Dictionary = DB.events["forest_shrine"]
	_expect(EventEngine.visible_choices(shrine, life, meta).size() == 2, "choix secrets cachés sans le flag ni le passé")

	# Validation : un événement dont tous les choix ont des conditions pourrait bloquer le joueur.
	var errors: Array[String] = []
	var trap := {"id": "trap", "location": "town", "text": "?", "choices": [
		{"id": "a", "text": "A", "conditions": [{"type": "gold", "min": 1}], "outcome": {"text": "", "effects": []}}]}
	DataValidator._validate_event(DB, trap, errors)
	_expect(errors.any(func(e): return "sans condition" in e), "le validateur refuse un événement sans issue")
	errors.clear()
	DataValidator._validate_effects(DB, [{"type": "combat", "enemies": ["wolf"]}, {"type": "xp", "amount": 1}], "test", errors)
	_expect(errors.any(func(e): return "dernier" in e), "le validateur exige que le combat soit le dernier effet")
	meta.free()
	return true

func _test_creation() -> bool:
	var screen: Control = load("res://scenes/creation.tscn").instantiate()
	add_child(screen)
	var ch: Character = screen.build_character()
	_expect(ch.name != "" and ch.background_id != "" and ch.gender != "", "création : nom, passé et genre proposés")
	_expect(Meta.is_species_available(ch.species_id) and Meta.is_class_available(ch.class_id),
		"création : espèce et classe de départ disponibles")
	var locked := 0
	for button: Button in screen.species_buttons.get_children() + screen.class_buttons.get_children():
		if button.disabled:
			locked += 1
	_expect(locked == 2, "création : Elfe et Roublard verrouillés au départ")
	screen._on_class_selected("fighter")
	screen.name_edit.text = "Bob"
	screen._on_name_typed("Bob")
	screen._on_species_selected("goblin")
	screen._on_background_selected("urchin")
	screen._on_gender_selected("female")
	ch = screen.build_character()
	_expect(ch.name == "Bob" and ch.class_id == "fighter" and ch.species_id == "goblin",
		"création : le nom tapé est conservé au changement d'espèce")
	_expect(ch.background_id == "urchin" and ch.gender == "female" and ch.is_proficient("sleight_of_hand"),
		"création : passé et genre appliqués")
	screen._on_decrease("str")
	screen._on_increase("cha")
	screen._on_bonus(0, "dex")
	ch = screen.build_character()
	_expect(ch.abilities["str"] == 14 and ch.abilities["cha"] == 11 and ch.abilities["dex"] == 15,
		"création : l'achat de points et les bonus modifient le personnage")
	screen._on_class_selected("wizard")
	_expect(screen.build_character().abilities["int"] == 17, "création : changer de classe réapplique son modèle")
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

## Joue un combat entièrement en automatique et retourne le résultat de Game.finish_combat().
func _auto_combat(spec: Dictionary) -> Dictionary:
	var combat := Game.start_combat(spec)
	var guard := 0
	while not combat.is_over() and guard < 500:
		guard += 1
		var actor := combat.current()
		var choice := combat.auto_choice(actor)
		combat.perform(actor, choice["action"], choice["target"])
		combat.end_turn()
	_expect(guard < 500, "le combat se termine")
	return Game.finish_combat()


func _test_dice_expressions() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for expr in ["2d6+3", "1d10", "3d4+1d6-1", "5", "d20"]:
		_expect(Dice.is_valid_expr(expr), "expression valide : " + expr)
	for expr in ["", "2x6", "d", "+3", "1d6+"]:
		_expect(not Dice.is_valid_expr(expr), "expression invalide : " + expr)
	var ok := true
	for i in 200:
		var r := Dice.roll_expr("2d6+3", rng)
		ok = ok and r["dice"].size() == 2 and r["bonus"] == 3 and r["total"] >= 5 and r["total"] <= 15
	_expect(ok, "2d6+3 : deux dés, bonus 3, total entre 5 et 15")
	_expect(Dice.roll_expr("1d8+2", rng, true)["dice"].size() == 2, "critique : dés doublés")
	_expect(Dice.add_mod("1d8", 3) == "1d8+3" and Dice.add_mod("1d8", -1) == "1d8-1"
		and Dice.add_mod("1d8", 0) == "1d8", "ajout de modificateur")
	return true


func _test_combat() -> bool:
	# Guerrier humain au modèle : FOR 17 (+3), maîtrise +2, épée longue 1d8, cotte de mailles CA 16.
	Game.start_life(Character.create("human", "fighter", "Testeur"), 99)
	var life := Game.life
	var fighter := Combatant.from_character(life.character, true)
	var attack: Dictionary = DB.actions["weapon_attack"]
	_expect(fighter.attack_bonus(attack) == 5 and fighter.damage_expr(attack) == "1d10+3",
		"attaque du guerrier : +5, épée longue à deux mains 1d10+3")
	_expect(fighter.damage_type(attack) == "slashing", "épée longue : dégâts tranchants")
	_expect(life.character.armor_class() == 16, "CA du guerrier : 16")
	var wizard := Combatant.from_character(Character.create("goblin", "wizard", "Mage"), true)
	_expect(wizard.attack_bonus(DB.actions["fire_bolt"]) == 5, "trait de feu : INT +3 + maîtrise")
	_expect(Character.create("goblin", "wizard", "Mage").armor_class() == 11, "CA du magicien : 10 + DEX")

	var combat := Game.start_combat({"enemies": ["wolf", "wolf"]})
	_expect(combat.combatants.size() == 3 and combat.order.size() == 3, "combat : héros + 2 loups")
	_expect(combat.enemies()[0].name == "Loup A" and combat.enemies()[1].name == "Loup B", "ennemis identiques numérotés")
	var hp := combat.enemies()[0].hp
	_expect(hp >= 4 and hp <= 18, "PV du loup tirés selon 2d8+2")
	var result := _finish_auto(combat)
	_expect(result["outcome"] in ["victory", "defeat"], "le combat aboutit à une victoire ou une défaite")
	if result["outcome"] == "victory":
		_expect(life.character.item_count("wolf_pelt") == 2 and life.character.xp == 100, "victoire : XP et butin")
	else:
		_expect(life.dead and life.death_cause == "Dévoré par un loup", "défaite mortelle : cause de la mort")

	# Ennemi de test imparable pour forcer les défaites.
	DB.enemies["_ogre"] = {"id": "_ogre", "name": "Ogre", "ac": 30, "hp": "500", "abilities": {"dex": 30},
		"attacks": [{"name": "Massue", "to_hit": 50, "damage": "100"}], "xp": 0}
	Game.start_life(Character.create("human", "fighter", "Testeur"), 5)
	result = _auto_combat({"enemies": ["_ogre"], "on_defeat": "knockout",
		"defeat": {"text": "K.-O.", "effects": [{"type": "gold", "amount": -5}]}})
	_expect(result["outcome"] == "defeat" and not Game.life.dead and Game.life.character.hp == 1,
		"K.-O. : défaite non mortelle, 1 PV")
	_expect(Game.life.character.gold == 10 and result["text"] == "K.-O.", "K.-O. : effets de l'issue « defeat »")
	result = _auto_combat({"enemies": ["_ogre"]})
	_expect(result["outcome"] == "defeat" and Game.life.dead and Game.life.death_cause == "Tué par Ogre",
		"défaite mortelle")

	Game.start_life(Character.create("human", "fighter", "Testeur"), 6)
	combat = Game.start_combat({"enemies": ["_ogre"], "flee_dc": -100,
		"fled": {"text": "Ouf", "effects": [{"type": "set_flag", "id": "ran"}]}})
	var guard := 0
	while not combat.is_over() and guard < 50:
		guard += 1
		if combat.current().is_ally():
			combat.perform(combat.current(), {"id": Combat.ACTION_FLEE})
		else:
			combat.current().hp = combat.current().hp  # l'ogre ne joue pas : on passe son tour
		combat.end_turn()
	result = Game.finish_combat()
	_expect(result["outcome"] == "fled" and Game.life.has_flag("ran"), "fuite : issue « fled » et ses effets")
	DB.enemies.erase("_ogre")

	# Sorts et repos.
	Game.start_life(Character.create("goblin", "wizard", "Mage"), 7)
	combat = Game.start_combat({"enemies": ["giant_rat"]})
	var mage := combat.allies()[0]
	var missile: Dictionary = DB.actions["magic_missile"]
	var rat := combat.enemies()[0]
	combat.perform(mage, missile, rat)
	combat.perform(mage, missile, rat)
	_expect(Game.life.character.resources["spell_slot"] == 0 and mage.unavailable_reason(missile) != "",
		"projectile magique : emplacements épuisés")
	_expect(not rat.is_alive() and combat.outcome == "victory", "projectile magique : touche toujours")
	Game.finish_combat()
	Effects.apply_all([{"type": "long_rest"}], Game.life, Meta)
	_expect(Game.life.character.resources["spell_slot"] == 2, "repos long : emplacements restaurés")
	return true


func _finish_auto(combat: Combat) -> Dictionary:
	var guard := 0
	while not combat.is_over() and guard < 500:
		guard += 1
		var choice := combat.auto_choice(combat.current())
		combat.perform(combat.current(), choice["action"], choice["target"])
		combat.end_turn()
	return Game.finish_combat()


func _test_companions() -> bool:
	Game.start_life(Character.create("human", "fighter", "Testeur"), 11)
	var life := Game.life
	var res := Effects.apply_all([{"type": "recruit", "companion": "mira"}], life, Meta)
	_expect(life.companions.size() == 1 and life.has_companion("mira"), "recrutement de Mira")
	_expect(res["lines"] == ["Mira rejoint votre groupe !"], "message de recrutement")
	_expect(Conditions.check({"type": "companion", "id": "mira"}, life, Meta), "condition compagnon")
	var mira := life.companions[0]
	_expect(mira.class_id == "rogue" and mira.gender == "female" and mira.is_proficient("survival"),
		"Mira : roublarde, passé Sauvageon")
	Effects.apply_all([{"type": "recruit", "companion": "mira"}], life, Meta)
	_expect(life.companions.size() == 1, "pas de doublon de compagnon")

	var combat := Game.start_combat({"enemies": ["wolf"]})
	_expect(combat.allies().size() == 2, "le compagnon participe au combat")
	_expect(combat.allies()[1].actions().any(func(a): return a["id"] == "sneak_attack"), "actions de classe du compagnon")
	# Le compagnon tombe pendant un combat mortel : il meurt pour de bon.
	combat.allies()[1].hp = 0
	combat.enemies()[0].hp = 0
	combat.outcome = "victory"
	var result := Game.finish_combat()
	_expect(life.companions.is_empty() and result["lines"].has("Mira a péri au combat."), "mort définitive du compagnon")
	_expect(not Conditions.check({"type": "companion", "id": "mira"}, life, Meta), "plus de compagnon")
	return true


## Joue des centaines d'actions au hasard sur plusieurs vies pour débusquer les erreurs d'exécution.
func _test_simulation() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var deaths := 0
	var combats := 0
	var chronicle_start := Meta.chronicle.size()
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
			while not result["combat"].is_empty() and not Game.life.dead:
				combats += 1
				result = _auto_combat(result["combat"])
			if Game.life.dead:
				break
			ev = DB.events[result["goto"]] if result["goto"] != "" else {}
		if not Game.life.dead:
			Game.end_event()
	var unseen := DB.events.keys().filter(func(id): return not Meta.seen_events.has(id))
	print("Simulation : %d morts, %d combats, %d vies en chronique, événements jamais tirés : %s" % [
		deaths, combats, Meta.chronicle.size(), unseen])
	_expect(combats > 0, "la simulation a déclenché des combats")
	_expect(deaths > 0, "la simulation produit des morts")
	_expect(Meta.chronicle.size() - chronicle_start == deaths + (1 if Game.life.dead else 0),
		"chaque mort est inscrite dans la chronique")
	_expect(unseen.size() <= 2, "presque tous les événements sont atteignables")
	return true

func _test_art() -> bool:
	var c := Character.create("goblin", "wizard", "Grik")
	var img := PixelArt.portrait(DB.species["goblin"]["art"], DB.classes["wizard"]["art"], "adult", 7)
	_expect(img.get_width() == PixelArt.PORTRAIT_SIZE, "portrait généré")
	_expect(img.get_data() == PixelArt.portrait(DB.species["goblin"]["art"], DB.classes["wizard"]["art"], "adult", 7).get_data(),
		"portrait déterministe")
	_expect(ArtProvider.portrait(c) != null, "ArtProvider fournit un portrait")
	for kind in ["forest", "town", "home", "unknown"]:
		_expect(PixelArt.scene(kind, "evening", 3).get_width() == PixelArt.SCENE_W, "décor %s généré" % kind)
	return true
