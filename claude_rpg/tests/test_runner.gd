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
	"_test_actions",
	"_test_spell_progression",
	"_test_class_features",
	"_test_combat",
	"_test_combat_turns",
	"_test_companions",
	"_test_creation",
	"_test_creator_points",
	"_test_dice_tray",
	"_test_saves",
	"_test_simulation",
	"_test_art",
]


func _ready() -> void:
	# Les tests n'écrivent jamais dans les vraies sauvegardes (voir _test_saves, qui utilise un dossier à part).
	Saves.enabled = false
	Saves.directory = "user://test_saves"
	Meta.reset()  # indépendant des sauvegardes éventuelles du joueur
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
	_expect(c.age_years() == 18 and c.life_stage() == "adult", "gobelin de 18 ans adulte (majorité)")
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
	_expect(StatusEffects.name_of("poisoned") == "Poison" and StatusEffects.name_of("burning") == "Brûlure", "états")

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
	_expect(sword.damage_expr({"type": "attack", "weapon": true}) == "1d10+4", "Frappe brutale : +1 aux dégâts d'arme")
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
	DB.creatures["_golem"] = {"id": "_golem", "name": "Golem", "ac": 1, "hp": "100", "abilities": {},
		"actions": [{"name": "Poing", "weight": 1, "target": "enemy", "effects": [{"type": "damage", "damage": "1", "damage_type": "bludgeoning"}]}],
		"defenses": {"resistances": ["slashing"]}}
	Game.start_life(Character.create("human", "fighter", "Testeur"), 3)
	var combat := Game.start_combat({"enemies": ["_golem"]})
	var golem := combat.enemies()[0]
	var beats := combat.perform(combat.hero, Actions.def("weapon_attack"), golem)
	if beats.size() == 3:
		_expect(100 - golem.hp <= 13 and "résistance" in beats[2]["text"], "combat : résistance appliquée")
	DB.creatures.erase("_golem")
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


func _test_creator_points() -> bool:
	var backup := Meta.to_dict()
	_expect(CreatorPoints.earned_for(0) == 1 and CreatorPoints.earned_for(350) == 3, "gain : 1 par 100 XP, au moins 1")
	var meta := MetaState.new()
	var life := _new_life("human", "fighter")
	life.character.add_xp(450)
	life.die("Test")
	meta.record_life(life)
	_expect(meta.creator_points == 4 and meta.chronicle[0]["creator_points"] == 4, "gain crédité à la mort et noté")
	meta.free()

	_expect(CreatorPoints.rank_cost("start_level", 1) == 6 and CreatorPoints.rank_cost("start_level", 2) == 12,
		"coût croissant par rang")
	_expect(CreatorPoints.total_cost({"start_level": 2, "purse": 1}) == 19, "coût total des bonus")
	var c := Character.create("human", "fighter", "x")
	CreatorPoints.apply(c, {"start_level": 2, "purse": 1})
	_expect(c.level == 3 and c.hp == c.max_hp and c.gold == 15 + 25, "bonus : niveau de départ et bourse")

	# Écran de création : les bonus sont payés au lancement, dans la limite du solde.
	Meta.reset()
	Meta.creator_points = 30
	var screen: Control = load("res://scenes/creation.tscn").instantiate()
	add_child(screen)
	screen._on_class_selected("fighter")
	screen._on_rank("start_level", 1)
	screen._on_rank("ability_point", 1)
	screen._on_rank("ability_point", 1)
	_expect(screen._point_buy.remaining() == 2 and screen.build_character().level == 2, "création : bonus appliqués à l'aperçu")
	screen._on_rank("start_level", 1)
	screen._on_rank("start_level", 1)
	_expect(screen._cp_ranks["start_level"] == 2, "création : impossible de dépasser le solde (6 + 12 + 20 > 30)")
	_expect(screen.confirm_creation() and Meta.creator_points == 30 - 18 - 4 and Game.life.character.level == 3,
		"création : les Creator Points sont dépensés au lancement")
	screen.free()

	Meta.creator_points = 15
	_expect(Meta.buy_unlock("species:elf") and Meta.creator_points == 0 and Meta.is_species_available("elf"),
		"déblocage définitif acheté")
	_expect(not Meta.buy_unlock("class:rogue"), "déblocage refusé sans assez de points")
	Meta.load_dict(backup)
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
## Joue un combat entièrement en automatique et retourne le résultat de Game.finish_combat().
func _auto_combat(spec: Dictionary) -> Dictionary:
	_play_out(Game.start_combat(spec))
	return Game.finish_combat()


## Joue tous les tours d'un combat (héros compris) jusqu'à son issue.
func _play_out(combat: Combat) -> void:
	var guard := 0
	while not combat.is_over() and guard < 300:
		guard += 1
		var actor := combat.current()
		combat.start_turn()
		if not combat.is_over() and not combat.skipped:
			if actor.is_player_controlled():
				combat.auto_turn(actor)
			else:
				combat.ai_turn(actor)
		combat.end_turn()
	_expect(guard < 300, "le combat se termine")


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
	# Guerrier humain au modèle : FOR 17 (+3), maîtrise +2, épée longue à deux mains 1d10, cotte de mailles CA 16.
	Game.start_life(Character.create("human", "fighter", "Testeur"), 99)
	var life := Game.life
	var fighter := Combatant.from_character(life.character, true)
	_expect(fighter.attack_bonus({"type": "attack", "weapon": true}) == 5 and fighter.damage_expr({"type": "attack", "weapon": true}) == "1d10+3",
		"attaque du guerrier : +5, épée longue à deux mains 1d10+3")
	_expect(fighter.damage_type({"type": "attack", "weapon": true}) == "slashing", "épée longue : dégâts tranchants")
	_expect(life.character.armor_class() == 16, "CA du guerrier : 16")
	var mage := Combatant.from_character(Character.create("goblin", "wizard", "Mage"), true)
	_expect(mage.attack_bonus(Actions.def("fire_bolt")["effects"][0]) == 5, "trait de feu : INT +3 + maîtrise")

	var combat := Game.start_combat({"enemies": ["wolf", "wolf"]})
	_expect(combat.combatants.size() == 3 and combat.order.size() == 3, "combat : héros + 2 loups")
	_expect(combat.enemies()[0].name == "Loup A" and combat.enemies()[1].name == "Loup B", "ennemis identiques numérotés")
	_play_out(combat)
	var result := Game.finish_combat()
	_expect(result["outcome"] in ["victory", "defeat"], "le combat aboutit à une victoire ou une défaite")
	if result["outcome"] == "victory":
		_expect(life.character.item_count("wolf_pelt") == 2 and life.character.xp == 100, "victoire : XP et butin")
	else:
		_expect(life.dead and life.death_cause == "Dévoré par un loup", "défaite mortelle : cause de la mort")

	# Créature de test imparable pour forcer les défaites.
	DB.creatures["_ogre"] = {"id": "_ogre", "name": "Ogre", "ac": 30, "hp": "500", "abilities": {"dex": 30},
		"actions": [{"name": "Massue", "weight": 1, "target": "enemy", "effects": [{"type": "attack", "to_hit": 50, "damage": "100", "damage_type": "bludgeoning"}]}],
		"xp": 0}
	Game.start_life(Character.create("human", "fighter", "Testeur"), 5)
	result = _auto_combat({"enemies": ["_ogre"], "on_defeat": "knockout",
		"defeat": {"text": "K.-O.", "effects": [{"type": "gold", "amount": -5}]}})
	_expect(result["outcome"] == "defeat" and not Game.life.dead and Game.life.character.hp == 1,
		"K.-O. : défaite non mortelle, 1 PV")
	_expect(Game.life.character.gold == 10 and result["text"] == "K.-O.", "K.-O. : effets de l'issue « defeat »")
	result = _auto_combat({"enemies": ["_ogre"]})
	_expect(result["outcome"] == "defeat" and Game.life.dead and Game.life.death_cause == "Tué par Ogre", "défaite mortelle")

	Game.start_life(Character.create("human", "fighter", "Testeur"), 6)
	combat = Game.start_combat({"enemies": ["_ogre"], "flee_dc": -100,
		"fled": {"text": "Ouf", "effects": [{"type": "set_flag", "id": "ran"}]}})
	var guard := 0
	while not combat.is_over() and guard < 50:
		guard += 1
		combat.start_turn()
		if combat.current().is_hero():
			combat.flee(combat.current())
		combat.end_turn()
	result = Game.finish_combat()
	_expect(result["outcome"] == "fled" and Game.life.has_flag("ran"), "fuite : issue « fled » et ses effets")
	DB.creatures.erase("_ogre")
	return true


func _test_actions() -> bool:
	# Actions de classe, utilisations par combat et emplacements de sort.
	Game.start_life(Character.create("goblin", "wizard", "Mage"), 7)
	var combat := Game.start_combat({"enemies": ["giant_rat", "giant_rat"]})
	var mage := combat.hero
	var names := combat.action_choices(mage).map(func(c): return c["action"]["id"])
	_expect(names == Game.life.character.combat_actions(), "actions du magicien : celles de sa classe")
	var missile := Actions.def("magic_missile")
	combat.perform(mage, missile, combat.living("enemy")[0])
	combat.perform(mage, missile, combat.living("enemy")[0] if not combat.living("enemy").is_empty() else null)
	_expect(Game.life.character.resources["spell_slot_1"] == 0, "projectile magique : 2 emplacements dépensés")
	_expect(combat.action_unavailable_reason(mage, missile) == "plus d'emplacement de sort de niveau 1", "plus d'emplacement")
	_expect(combat.action_unavailable_reason(mage, Actions.def("fire_bolt")) == ""
		or combat.living("enemy").is_empty(), "tour de magie à volonté")
	Game.finish_combat()
	Effects.apply_all([{"type": "long_rest"}], Game.life, Meta)
	_expect(Game.life.character.resources["spell_slot_1"] == 2, "repos long : emplacements restaurés")

	Game.start_life(Character.create("human", "fighter", "Guerrier"), 8)
	combat = Game.start_combat({"enemies": ["wolf"]})
	var wind := Actions.def("second_wind")
	combat.hero.hp = 3
	combat.perform(combat.hero, wind)
	_expect(combat.hero.hp > 3 and combat.action_unavailable_reason(combat.hero, wind) == "déjà utilisée",
		"Second souffle : soigne, une fois par combat")
	Game.combat = null
	_expect(Actions.text_of("pommel_strike") == "Attaque avec votre arme. Si elle touche : 1 Étourdi.",
		"texte généré d'une action")
	_expect(Actions.text_of("burning_hands").begins_with("Tous les ennemis : Inflige 3d6 feu (sauvegarde de DEX : moitié)"),
		"texte : cible multiple et sauvegarde")
	return true


## Personnage amené à un niveau par l'XP (aptitudes et emplacements compris).
func _at_level(species: String, cls: String, level: int) -> Character:
	var ch := Character.create(species, cls, "Niv%d" % level)
	ch.add_xp(Progression.xp_for(level) - ch.xp)
	return ch


func _test_spell_progression() -> bool:
	_expect(Spellcasting.slots("full", 1) == {"spell_slot_1": 2}
		and Spellcasting.slots("full", 5) == {"spell_slot_1": 4, "spell_slot_2": 3, "spell_slot_3": 2}, "table SRD des emplacements")
	_expect(Spellcasting.slots("half", 1).is_empty() and Spellcasting.slots("half", 5) == {"spell_slot_1": 4, "spell_slot_2": 2},
		"demi-lanceur : rien au niveau 1")
	_expect(Spellcasting.slots("full", 20).size() == 9, "niveau 20 : emplacements jusqu'au 9e niveau")

	var mage := Character.create("goblin", "wizard", "Mage")
	mage.resources["spell_slot_1"] = 0
	mage.add_xp(Progression.xp_for(3) - mage.xp)
	_expect(mage.resources["spell_slot_1"] == 2 and mage.resources["spell_slot_2"] == 2,
		"montée de niveau : les emplacements gagnés sont disponibles, les dépensés le restent")
	mage.long_rest()
	_expect(mage.resources == {"spell_slot_1": 4, "spell_slot_2": 2}, "repos long : tous les emplacements")
	_expect(ClassFeatures.announce(mage, 3).size() == 2, "annonce : nouvelle aptitude et nouveaux emplacements")

	var old := Character.from_dict({"species_id": "goblin", "class_id": "wizard", "level": 1, "resources": {"spell_slot": 1}})
	_expect(old.resources == {"spell_slot_1": 2}, "ancienne sauvegarde : ressources converties")

	# Tours de magie qui montent avec le niveau, sorts lancés à un niveau supérieur.
	var hero := Combatant.from_character(Character.create("human", "wizard", "W"), true)
	var bolt: Dictionary = Actions.def("fire_bolt")["effects"][0]
	_expect(hero.damage_expr(bolt) == "1d10", "Trait de feu : 1d10 au niveau 1")
	hero.character.level = 5
	_expect(hero.damage_expr(bolt) == "2d10", "Trait de feu : 2d10 au niveau 5")
	hero.character.level = 17
	_expect(hero.damage_expr(bolt) == "4d10", "Trait de feu : 4d10 au niveau 17")

	Game.start_life(_at_level("human", "wizard", 5), 21)
	var combat := Game.start_combat({"enemies": ["dire_wolf"]})
	var missiles := combat.action_choices(combat.hero).filter(func(c): return c["action"]["id"] == "magic_missile")
	_expect(missiles.size() == 3, "Projectile magique proposé aux niveaux 1, 2 et 3")
	var high: Dictionary = missiles[2]["action"]
	_expect(high["name"] == "Projectile magique (niv. 3)" and high["effects"][0]["damage"] == "3d4+3+1d4+1+1d4+1",
		"niveau 3 : deux projectiles de plus")
	combat.perform(combat.hero, high, combat.living("enemy")[0])
	_expect(Game.life.character.resources["spell_slot_3"] == 1 and Game.life.character.resources["spell_slot_1"] == 4,
		"l'emplacement du niveau choisi est dépensé")
	_expect(combat.action_choices(combat.hero).any(func(c): return c["action"]["id"] == "fireball"), "Boule de feu au niveau 5")
	Game.combat = null
	return true


func _test_class_features() -> bool:
	DB.creatures["_target"] = {"id": "_target", "name": "Cible", "ac": 1, "hp": "200",
		"actions": [{"name": "Rien", "weight": 1, "target": "self", "effects": [{"type": "status", "status": "shielded", "stacks": 0}]}]}

	# Jets de sauvegarde.
	var fighter := Character.create("human", "fighter", "G")
	_expect(fighter.is_proficient_save("con") and not fighter.is_proficient_save("dex")
		and fighter.save_mod("con") == fighter.ability_mod("con") + 2, "sauvegardes maîtrisées de la classe")
	var check := {"save": "con", "dc": 10}
	_expect(Dice.modifier(fighter, check) == fighter.save_mod("con") and Dice.stat_name(check) == "Sauvegarde de Constitution",
		"test de sauvegarde dans un événement")

	# Guerrier : Fougue, Attaque supplémentaire, Inflexible.
	Game.start_life(_at_level("human", "fighter", 9), 31)
	var combat := Game.start_combat({"enemies": ["_target"]})
	var hero := combat.hero
	combat.turn = combat.order.find(hero)
	combat.start_turn()
	combat.perform(hero, Actions.def("action_surge"))
	_expect(combat.actions_left == 2 and combat.can_act_again(), "Fougue : une action de plus, sans coûter la sienne")
	var before := combat.log.size()
	combat.perform(hero, Actions.def("weapon_attack"), combat.enemies()[0])
	_expect(combat.log.slice(before).count("Niv9 : attaque supplémentaire.") == 1, "Attaque supplémentaire : deux coups au niveau 9")
	_expect(combat.actions_left == 1, "il reste l'action gagnée par la Fougue")
	var beats: Array[Dictionary] = []
	_expect(Game.life.character.resources["indomitable"] == 1, "Inflexible : 1 utilisation au niveau 9")
	combat._saving_throw(combat.enemies()[0], hero, {"ability": "dex", "dc": 100}, beats, true)
	_expect(Game.life.character.resources["indomitable"] == 0 and beats.size() == 2, "Inflexible : relance une sauvegarde ratée")
	Game.combat = null

	# Roublard : Expertise, Attaque sournoise, Esquive instinctive, Dérobade, Talent fiable.
	var rogue := _at_level("goblin", "rogue", 11)
	_expect(rogue.skill_mod("stealth") == rogue.ability_mod("dex") + 2 * rogue.proficiency_bonus(), "Expertise : maîtrise doublée")
	var sneak := Combatant.from_character(rogue, true)
	_expect(sneak.damage_expr(Actions.def("sneak_attack")["effects"][0]).ends_with("+6d6"), "Attaque sournoise : 6d6 au niveau 11")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var lowest := 20
	for i in 40:
		lowest = mini(lowest, Dice.roll_check(rogue, {"skill": "stealth", "dc": 30}, rng)["die"])
	_expect(lowest == 10, "Talent fiable : jamais moins de 10 au d20")

	Game.start_life(rogue, 41)
	combat = Game.start_combat({"enemies": ["_target"]})
	hero = combat.hero
	var target := combat.enemies()[0]
	var hp := hero.hp
	combat._roll_damage(target, hero, "10", "", false, beats, 1.0, true)
	combat._roll_damage(target, hero, "10", "", false, beats, 1.0, true)
	_expect(hp - hero.hp == 5 + 10, "Esquive instinctive : la première attaque du round est divisée par deux")
	hp = hero.hp
	combat._apply(target, {"type": "damage", "damage": "10", "save": {"ability": "dex", "half": true, "dc": -100}}, hero, true)
	_expect(hero.hp == hp, "Dérobade : sauvegarde réussie, aucun dégât")
	combat._apply(target, {"type": "damage", "damage": "10", "save": {"ability": "dex", "half": true, "dc": 100}}, hero, true)
	_expect(hp - hero.hp == 5, "Dérobade : sauvegarde ratée, moitié des dégâts")
	Game.combat = null

	# Sauvegarde contre un sort : moitié des dégâts, et l'état qui suit est évité.
	Game.start_life(_at_level("human", "wizard", 1), 51)
	combat = Game.start_combat({"enemies": ["_target"]})
	target = combat.enemies()[0]
	hp = target.hp
	combat._resolve(combat.hero, [{"type": "damage", "damage": "10", "damage_type": "fire", "save": {"ability": "dex", "half": true, "dc": -100}},
		{"type": "status", "status": "burning", "stacks": 1}], "enemy", target, true)
	_expect(hp - target.hp == 5 and target.stacks("burning") == 0, "sauvegarde réussie : moitié et pas d'état")
	Game.combat = null
	DB.creatures.erase("_target")
	return true


func _test_combat_turns() -> bool:
	# États : poison (dégâts bruts, -1 charge), brûlure (% des PV max), étourdi, protection, affaibli.
	var combat: Combat
	DB.creatures["_dummy"] = {"id": "_dummy", "name": "Mannequin", "ac": 5, "hp": "100", "abilities": {"dex": -50},
		"actions": [{"name": "Rien", "weight": 1, "target": "self", "effects": [{"type": "status", "status": "shielded", "stacks": 0}]}]}
	Game.start_life(Character.create("human", "fighter", "Testeur"), 4)
	combat = Game.start_combat({"enemies": ["_dummy"]})
	var dummy := combat.enemies()[0]
	dummy.add_status("poisoned", 3)
	dummy.add_status("burning", 2)
	combat.turn = combat.order.find(dummy)
	combat.start_turn()
	_expect(dummy.hp == 100 - 3 - 10, "poison 3 + brûlure 2 (5 pour cent de 100 par charge)")
	_expect(dummy.stacks("poisoned") == 2 and dummy.stacks("burning") == 1, "chaque état perd une charge")
	dummy.add_status("stunned", 1)
	combat.start_turn()
	_expect(combat.skipped and dummy.stacks("stunned") == 0, "étourdi : le tour est passé")
	var hp := combat.hero.hp
	combat.hero.add_status("shielded", 5)
	combat._deal_damage(dummy, combat.hero, 3, "bludgeoning", false, "")
	_expect(combat.hero.hp == hp and combat.hero.stacks("shielded") == 2, "protection : absorbe les dégâts")
	dummy.add_status("weakened", 2)
	_expect(dummy.damage_modifier() == -2, "affaibli : -1 dégât par charge")
	combat.hero.statuses.clear()
	DB.creatures.erase("_dummy")
	Game.combat = null

	# Intentions : une action « préparée » est annoncée un tour, puis exécutée au suivant.
	Game.start_life(Character.create("human", "fighter", "Testeur"), 8)
	combat = Game.start_combat({"enemies": ["dire_wolf"]})
	var alpha := combat.enemies()[0]
	var howl: Dictionary = alpha.creature["actions"][1]
	alpha.intent = howl
	var beats := combat.ai_turn(alpha)
	_expect(alpha.intent.is_empty() and combat.hero.stacks("weakened") == 2, "action préparée exécutée au tour suivant")
	_expect(beats[0]["text"].contains("Hurlement"), "l'action préparée est annoncée par son nom")
	Game.combat = null

	# Invocations et places : 4 places par camp (petite ½, moyenne 1, grande 2).
	Game.start_life(Character.create("human", "wizard", "Mage"), 9)
	combat = Game.start_combat({"enemies": ["wolf"]})
	_expect(combat.capacity_used("ally") == 1.0, "le héros occupe 1 place")
	var familiar := Actions.def("find_familiar")
	combat.perform(combat.hero, familiar)
	_expect(combat.living("ally").size() == 2 and combat.living("ally")[1].summoned, "Appel du familier : une invocation")
	for i in 7:
		combat._apply(combat.hero, {"type": "summon", "creature": "familiar"}, null, false)
	_expect(combat.living("ally").size() == 7 and combat.capacity_used("ally") == 4.0,
		"6 familiers (½ place) + le héros = 4 places, pas plus")
	_expect(combat.action_unavailable_reason(combat.hero, familiar) != "", "plus d'invocation sans place")
	var summon := combat.living("ally")[1]
	_expect(not summon.is_player_controlled() and not combat.ai_turn(summon).is_empty(), "l'invocation joue seule")
	Game.combat = null
	_expect(Combat.size_slots("large") == 2.0 and Combat.size_slots("small") == 0.5, "places selon la taille")
	return true


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
	var ally := combat.allies()[1]
	_expect(ally.kind == "companion" and ally.is_player_controlled(), "compagnon contrôlé par le joueur")
	_expect(combat.action_choices(ally).any(func(c): return c["action"]["id"] == "sneak_attack"),
		"le compagnon a les actions de sa classe")
	var choice := combat.auto_choice(ally)
	_expect(not combat.perform(ally, choice["action"], choice["target"]).is_empty(), "le compagnon agit")
	# Le compagnon tombe pendant un combat mortel : il meurt pour de bon.
	ally.hp = 0
	combat.enemies()[0].hp = 0
	combat.outcome = "victory"
	var result := Game.finish_combat()
	_expect(life.companions.is_empty() and result["lines"].has("Mira a péri au combat."), "mort définitive du compagnon")
	_expect(not Conditions.check({"type": "companion", "id": "mira"}, life, Meta), "plus de compagnon")
	return true


func _test_saves() -> bool:
	var meta_backup := Meta.to_dict()
	Saves.enabled = true
	Saves.reset_world()

	# Une vie bien remplie : compagnon, don, équipement, défense, flags, temps, combat en attente.
	Game.start_life(Character.create("goblin", "rogue", "Mibz", {"background": "criminal", "gender": "female"}), 77)
	var life := Game.life
	Effects.apply_all([
		{"type": "recruit", "companion": "mira"}, {"type": "add_feat", "id": "tough"}, {"type": "equip", "id": "shortsword"},
		{"type": "add_defense", "kind": "resistance", "id": "fire"}, {"type": "set_flag", "id": "quest"},
		{"type": "add_item", "id": "antidote", "count": 2}, {"type": "xp", "amount": 350}, {"type": "unlock", "id": "species:elf"},
	], life, Meta)
	life.advance_time(7)
	life.mark_seen("town_market")
	life.pending_combat = {"enemies": ["wolf"]}
	life.rng.randi()
	Saves.save_all()
	var before := JSON.stringify(life.to_dict())
	var next_roll := life.rng.randi()

	Game.life = null
	Meta.reset()
	Saves.load_meta()
	_expect(Meta.is_unlocked("species:elf"), "sauvegarde : la méta est rechargée")
	_expect(Saves.has_life() and Saves.load_life(), "sauvegarde : la vie en cours est rechargée")
	_expect(JSON.stringify(Game.life.to_dict()) == before, "sauvegarde : la vie est identique après rechargement")
	var ch := Game.life.character
	_expect(ch.has_feat("tough") and ch.weapon_id() == "shortsword" and ch.all_defenses().has(Defenses.RESISTANCE, "fire")
		and ch.item_count("antidote") == 2 and ch.level == 2 and Game.life.companions[0].name == "Mira",
		"sauvegarde : don, équipement, défense, objets, niveau et compagnon")
	_expect(typeof(ch.abilities["str"]) == TYPE_INT and typeof(ch.inventory["antidote"]) == TYPE_INT,
		"sauvegarde : les nombres redeviennent des entiers")
	_expect(Game.life.pending_combat == {"enemies": ["wolf"]}, "sauvegarde : le combat en attente est conservé")
	_expect(Game.life.rng.randi() == next_roll, "sauvegarde : le hasard reprend là où il s'était arrêté")

	# À la mort, la vie disparaît des sauvegardes et entre dans la chronique.
	Game.life.die("Test")
	Game._after_change()
	_expect(not Saves.has_life(), "sauvegarde : la vie est supprimée à la mort")
	Meta.reset()
	Saves.load_meta()
	_expect(Meta.chronicle.size() == 1 and Meta.chronicle[0]["name"] == "Mibz", "sauvegarde : la chronique est conservée")

	# Sauvegarde d'une autre version : ignorée.
	var file := FileAccess.open(Saves.life_path(), FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 999, "data": {"day": 3}}))
	file.close()
	_expect(not Saves.has_life(), "sauvegarde d'une autre version ignorée")

	Saves.reset_world()
	Saves.delete_life()
	Saves.enabled = false
	Meta.load_dict(meta_backup)
	return true


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
