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
	"_test_backlash",
	"_test_class_features",
	"_test_inventory",
	"_test_encumbrance",
	"_test_weapon_properties",
	"_test_throw_and_shield",
	"_test_magic_shield_parry",
	"_test_lost_items_and_stock",
	"_test_world_map",
	"_test_new_species",
	"_test_damage_types",
	"_test_economy",
	"_test_advantage",
	"_test_choices",
	"_test_skill_ranks",
	"_test_social",
	"_test_multiclass_and_rest",
	"_test_social_life",
	"_test_combat",
	"_test_combat_turns",
	"_test_companions",
	"_test_creation",
	"_test_creator_points",
	"_test_enemy_support",
	"_test_npc_requests",
	"_test_dice_tray",
	"_test_quests",
	"_test_side_drawer",
	"_test_saves",
	"_test_simulation",
	"_test_art",
]


func _ready() -> void:
	# Les tests n'écrivent jamais dans les vraies sauvegardes (voir _test_saves, qui utilise un dossier à part).
	Saves.enabled = false
	Saves.directory = "user://test_saves"
	Meta.reset()  # indépendant des sauvegardes éventuelles du joueur
	var args := OS.get_cmdline_user_args()
	var verbose := "--verbose" in args  # godot … -- --verbose : nom de chaque test
	# godot … -- quick : sans la simulation (la plus lente) ; godot … -- creation,quests : seulement les tests
	# dont le nom contient l'un de ces mots (toujours avec _test_data).
	var filters: PackedStringArray = []
	for arg in args:
		if not arg.begins_with("--") and arg != "quick":
			filters.append_array(arg.split(",", false))
	for test: String in TESTS:
		if "quick" in args and test == "_test_simulation":
			continue
		if not filters.is_empty() and test != "_test_data" and not Array(filters).any(func(f): return f in test):
			continue
		if verbose:
			printerr("> " + test)
		# Une erreur de script interrompt la fonction, qui retourne alors null au lieu de true.
		var finished: Variant = await call(test)
		_expect(finished == true, "%s s'exécute jusqu'au bout (voir les erreurs ci-dessus)" % test)
	print("\n%d vérifications, %d échec(s)" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("ÉCHEC : " + label)


## Attribue les niveaux gagnés à la classe principale (au lieu du choix au hub).
func _level_up(ch: Character) -> void:
	while ch.pending_class_levels > 0:
		ch.assign_class_level(ch.class_id)


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
	# Quartier de départ selon le passé : le Marin commence au port, l'Ermite dans la forêt.
	Game.start_life(Character.create("human", "fighter", "Mousse", {"background": "sailor"}), 3)
	_expect(Game.life.has_flag("district_port") and Game.life.location == "town", "Marin : départ au port")
	Game.start_life(Character.create("human", "fighter", "Sage", {"background": "hermit"}), 3)
	_expect(Game.life.has_flag("district_woods") and Game.life.location == "forest", "Ermite : départ en forêt")
	# Modèle du magicien : 3 partout + 9 points, soit 6/5/5/4/4/3 selon ses priorités. Aucun effet de l'espèce.
	var c := Character.create("goblin", "wizard", "Grik", {"background": "sage", "gender": "female"})
	_expect(c.abilities["int"] == 6 and c.abilities["con"] == 5, "modèle du magicien : INT 6, CON 5")
	_expect(c.abilities["dex"] == 5 and c.abilities["str"] == 3, "l'espèce ne modifie pas les attributs")
	# Passé Érudit -> son premier don au choix par défaut (Intuition mystique) ; les dons ne donnent pas d'attribut.
	_expect(c.has_feat("mystic_insight") and c.ability_score("int") == 6, "don du passé appliqué à la création")
	var bare := Character.create("goblin", "wizard", "Nu", {"background": "sage", "skill_ranks": {}})
	_expect(bare.skill_rank("lore") == 4 and bare.skill_pool("lore") == {"count": 4, "threshold": 6, "ability": "int"},
		"Érudition : 1 + passé Érudit 1 + classe 2 : 4d10 contre INT 6")
	_expect(bare.skill_rank("perception") == 2 and bare.skill_pool("perception")["threshold"] == 6,
		"Perception : instinctive (2), avec le meilleur attribut (INT)")
	_expect(c.skill_pool("perception", "wis")["threshold"] == c.ability_score("wis"), "attribut imposé par le test")
	_expect(bare.skill_rank("physique") == 2 and bare.skill_rank("sleight_of_hand") == 1 and bare.skill_rank("determination") == 3
		and not bare.is_trained("physique"), "rangs de départ : instinctive 2, autre 1 ; Détermination 1 + classe 2")
	var free := 0
	for id: String in c.skill_points:
		free += int(c.skill_points[id])
	_expect(free == c.creation_free_ranks() and Skills.ids().all(func(id): return int(c.skill_points.get(id, 0)) == 0 or c.skill_rank(id) <= 5),
		"création : 8 rangs (+ ceux rendus par le plafond) répartis selon la classe, sans pousser une compétence au-delà de 5")
	# Plafond de création : départ + passé + classe ne dépassent pas 5 ; l'excédent revient aux rangs libres.
	var sneaky := Character.create("goblin", "rogue", "S", {"background": "criminal", "skill_ranks": {}})
	_expect(sneaky.skill_rank("stealth") == 5 and sneaky.creation_free_ranks() == 8,
		"Furtivité : instinctive 2 + passé 1 + classe 2 = 5, le plafond de création")
	sneaky.background_id = ""
	DB.backgrounds["_heavy"] = {"id": "_heavy", "name": "Test", "skills": {"stealth": 3}}
	sneaky.background_id = "_heavy"
	_expect(sneaky.skill_rank("stealth") == 5 and sneaky.creation_free_ranks() == 8 + 2, "au-delà de 5 : les rangs reviennent aux rangs libres")
	DB.backgrounds.erase("_heavy")
	_expect(Character.create("human", "rogue", "R", {"skill_ranks": {"arts": 3}}).skill_rank("arts") == 4, "rangs répartis donnés")
	_expect(Character.create("goblin", "fighter", "F").skill_rank(Skills.SPELL) == 0 and c.spell_skill() == "lore"
		and c.skill_rank(Skills.SPELL) == c.skill_rank("lore"), "sorts : Érudition pour le Magicien, rien pour un non-lanceur")

	_expect(c.skill_pool("athletics") == c.skill_pool("physique"), "ancien id (Athlétisme) traduit en Physique")
	_expect(c.max_hp == (-1 + 2) * 5 + 7 and Character.hp_from(4, 0) == 15 and Character.hp_from(8, 4) == 55,
		"PV : (taille + 2) × CON + 7 ; humain moyen 15, colosse endurant 55")
	_expect(c.size() == -1 and Character.create("human", "wizard", "H").size() == 0 and DB.size_name(-1) == "Petite",
		"la taille dépend de l'espèce")
	_expect(c.age_years() == 18 and c.life_stage() == "adult", "gobelin de 18 ans adulte (majorité)")
	_expect(Character.create("human", "fighter", "N", {"background": "noble"}).gold == 15, "pas d'or de passé")

	# PV : Constitution × 1,414^taille ; humain (taille 0) au modèle du guerrier : CON 6.
	var life := _new_life("human", "fighter")
	var f := life.character
	_expect(f.max_hp == 17 and f.hp == 17, "PV du guerrier humain : 2 × CON 5 + 7")
	f.hp = 10
	life.change_ability("con", -2, "test")
	_expect(f.max_hp == 13 and f.hp == 6, "CON 5 -> 3 : PV max et actuels -4")
	life.change_ability("con", 4, "test")
	_expect(f.max_hp == 21 and f.hp == 14, "CON 3 -> 7 : PV max et actuels +8")
	f.add_xp(300)
	_expect(f.level == 2 and f.max_hp == 21, "niveau 2 : les PV ne montent pas avec le niveau")
	_expect(Character.create("dwarf", "fighter", "N").max_hp == 12, "nain (taille −1) : 1 × CON 5 + 7 = 12 PV")
	_expect(f.natural_dodge() == 1 and f.armor() == 3 and f.initiative_base() == 5 + 3,
		"Esquive naturelle DEX 5 / 3 = 1, Armure 3 (cotte de mailles), initiative DEX + INT")
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
	_expect(Skills.ids().size() == 19 and Skills.ability_of("stealth") == "dex" and Skills.abilities_of("physique") == ["str", "dex", "con"],
		"compétences")
	_expect(Skills.names_of(["lore", "physique"]) == "Érudition, Physique" and Skills.resolve("intimidation") == "persuasion",
		"noms de compétences, anciens ids")
	_expect(DamageTypes.ids().size() == 12 and not DamageTypes.has("acid") and DamageTypes.name_of("fire") == "Feu", "types de dégâts")
	_expect(DamageTypes.is_physical("slashing") and not DamageTypes.is_physical("fire"), "dégâts physiques")
	_expect(StatusEffects.name_of("poisoned") == "Poison" and StatusEffects.name_of("prepared") == "Préparé", "états")

	# Ajouter un attribut ou une compétence dans les données se répercute partout.
	DB.skills["_cooking"] = {"id": "_cooking", "name": "Cuisine", "abilities": ["wis"], "category": "knowledge"}
	var c := Character.create("human", "fighter", "Chef")
	_expect(c.skill_pool("_cooking") == {"count": 1, "threshold": c.ability_score("wis"), "ability": "wis"}
		and "Cuisine" in CharacterSheet.bbcode(c), "une nouvelle compétence est utilisable et affichée sans autre modification")
	DB.skills.erase("_cooking")
	return true


func _test_equipment() -> bool:
	_expect(Equipment.armor_value("robe") == 0 and Equipment.armor_value("leather") == 1 and Equipment.armor_value("chain_mail") == 3
		and Equipment.armor_value("shield") == 1 and Equipment.armor_value("longsword") == 0, "points d'Armure")
	_expect(Equipment.weapon_damage("longsword") == {"threshold": "str", "bonus": 0, "dice": 7, "fixed": true}
		and Equipment.weapon_damage("bastard_sword")["bonus"] == 1 and Equipment.weapon_damage("rapier")["threshold"] == "dex"
		and Equipment.weapon_damage("longbow")["threshold"] == 5, "dégâts : dés de l'arme, seuil FOR (+N), DEX ou fixe")
	_expect(Equipment.parry_of("longsword") == 4 and Equipment.parry_of("quarterstaff") == 2 and Equipment.parry_of("quarterstaff", true) == 5
		and Equipment.parry_of("longbow") == -1 and Equipment.parry_of("shield") == 4, "seuils de parade (bâton : 5 à deux mains)")
	_expect(Equipment.weight_of("longsword") == 4.0 and Equipment.weight_of("longsword", true) == 3.0 and Equipment.weight_of("longbow") == 4.0
		and not Equipment.is_one_handed("longbow") and Equipment.is_one_handed("greatsword"), "poids à une et à deux mains")
	_expect(Equipment.skills_for("unarmed") == ["physique"] and Equipment.skills_for("javelin") == ["physique"]
		and Equipment.skills_for("light_crossbow") == ["weapon_ranged"], "compétences : Physique, Armes de trait")
	_expect(Equipment.describe("longsword") == "Épée longue — tranchant, 7d10, seuil FOR (parade 4, poids 4 (3 à deux mains))",
		"description d'arme")

	var c := Character.create("human", "fighter", "Testeur")
	_expect(c.weapon_id() == "longsword" and c.armor() == 3 and c.two_handed_grip(), "équipement de départ : épée tenue à deux mains")
	c.equip("shield")
	_expect(c.armor() == 4 and c.weapon_damage()["dice"] == 7 and not c.two_handed_grip(), "bouclier : +1 Armure, épée à une main")
	c.equip("greataxe")
	_expect(c.equipment.has("off_hand") and not c.two_handed_grip(), "une hache à deux mains se tient aussi à une main (plus lourde)")
	c.equip("longbow")
	_expect(not c.equipment.has("off_hand"), "arc (deux mains seulement) : le bouclier est retiré")
	c.equip("shield")
	_expect(c.weapon_id() == Equipment.UNARMED, "bouclier : l'arc est rangé")
	var older := Character.from_dict({"species_id": "human", "class_id": "fighter", "equipment": {"main_hand": "scimitar",
		"armor": "hide"}, "inventory": {"chain_shirt": 1}})
	_expect(older.equipment == {"main_hand": "shortsword", "armor": "leather"} and older.inventory == {"chain_mail": 1},
		"anciennes sauvegardes : équipements retirés remplacés")

	var life := _new_life("human", "fighter")
	Effects.apply_all([{"type": "equip", "id": "rapier"}], life, Meta)
	_expect(Conditions.check({"type": "equipped", "id": "rapier"}, life, Meta), "effet equip et condition equipped")
	return true


func _test_feats() -> bool:
	var life := _new_life("human", "wizard")
	var c := life.character
	var hp := c.max_hp
	var init := c.initiative_base()
	Effects.apply_all([{"type": "add_feat", "id": "tough"}, {"type": "add_feat", "id": "nimble"}], life, Meta)
	_expect(c.max_hp == hp + 2 and c.hp == c.max_hp, "Robuste : +2 PV")
	_expect(c.initiative_base() == init, "Robuste et Agile ne changent pas l'initiative")
	c.add_xp(300)
	_expect(c.max_hp == hp + 2, "Robuste ne dépend pas du niveau")
	# Agile : une fois par jour, un test raté sous la DEX reçoit un dé de plus.
	c.resources = c.max_resources()
	_expect(c.resources.get("nimble", 0) == 1, "Agile : une utilisation par jour")
	var rng := RandomNumberGenerator.new()
	var used := false
	for seed in 40:
		rng.seed = seed
		var roll := Dice.roll_check(c, {"skill": "stealth", "ability": "dex", "difficulty": 6}, rng)
		if roll.has("feats"):
			used = true
			_expect(roll["dice"].size() == c.skill_pool("stealth", "dex")["count"] + 1 or roll["dice"].size() > 1,
				"Agile : un dé lancé en plus")
			break
	_expect(used and c.resources["nimble"] == 0, "Agile : dépensé après un échec")
	_expect(Dice.fumble_level([{"value": 10}, {"value": 9}, {"value": 10}, {"value": 10, "dropped": true}]) == 2,
		"degré d'échec critique : les dés à 10")
	# Chanceux : un échec critique devient un échec.
	c.add_feat("lucky")
	c.resources = c.max_resources()
	var saved_fumble := false
	for seed in 400:
		rng.seed = seed
		var roll := Dice.roll_check(c, {"skill": "arts", "ability": "cha", "difficulty": 9}, rng)
		if roll.get("feats", []).any(func(n): return "Chanceux" in n):
			saved_fumble = int(roll["fumble_level"]) == Dice.fumble_level(roll["dice"]) - 1 and roll["fumble"] == (roll["fumble_level"] > 0)
			break
	_expect(saved_fumble and c.resources["lucky"] == 0, "Chanceux : un degré d'échec critique en moins")
	# Mode manuel : rien d'office, le don est proposé après l'échec.
	Meta.settings["auto_daily_feats"] = false
	c.resources = c.max_resources()
	var proposed := false
	for seed in 40:
		rng.seed = seed
		var roll := Dice.roll_check(c, {"skill": "stealth", "ability": "dex", "difficulty": 6}, rng)
		if not roll["success"]:
			proposed = not roll.has("feats") and "nimble" in Dice.daily_feat_options(c, roll)
			Dice.use_daily_feat(c, roll, "nimble", rng)
			proposed = proposed and c.resources["nimble"] == 0 and roll.has("feats")
			break
	Meta.settings["auto_daily_feats"] = true
	_expect(proposed, "dons 1/jour manuels : proposés puis utilisés à la demande")
	# Doué : deux compétences au choix ; Aquatique : un dé de plus aux tests marqués « swim ».
	c.add_feat("skilled")
	_expect(int(DB.feats["skilled"]["choices"][0]["count"]) == 2, "Doué : deux compétences")
	c.add_feat("aquatic")
	var swim := Dice.check_pool(c, {"skill": "physique", "tags": ["swim"]})
	_expect(int(swim["count"]) == int(Dice.check_pool(c, {"skill": "physique"})["count"]) + 1, "Aquatique : +1 dé pour nager")
	_expect(Conditions.check({"type": "has_feat", "id": "nimble"}, life, Meta), "condition has_feat")
	_expect(not c.add_feat("nimble"), "pas de don en double")

	# Chaque passé propose des dons ; +1 attribut au choix aux niveaux 5, 10, 15 et 20 (pas de don).
	for bg_id: String in DB.backgrounds:
		var offered := Feats.for_background(bg_id)
		_expect(not offered.is_empty() and offered.all(func(id): return Feats.has(id)), "le passé %s propose des dons" % bg_id)
	# Passé Sur mesure : quatre compétences et un don au choix.
	var free := Character.create("human", "fighter", "Libre", {"background": "custom", "skill_ranks": {},
		"choices": {"background/feat": ["lucky"], "background/skills": ["arts", "medicine", "stealth", "languages"]}})
	var plain := Character.create("human", "fighter", "Base", {"skill_ranks": {}})
	_expect(free.has_feat("lucky") and free.skill_rank("arts") == plain.skill_rank("arts") + 1
		and free.skill_rank("medicine") == plain.skill_rank("medicine") + 1,
		"Sur mesure : don et compétences choisis")
	var soldier := Character.create("human", "fighter", "Soldat", {"background": "soldier",
		"choices": {"background/feat": ["savage_attacker"]}})
	var sword := Combatant.from_character(soldier, true)
	var weapon := {"type": "attack", "weapon": true}
	_expect(sword.damage_pool(weapon, sword.attack_pool(weapon)) == {"count": soldier.skill_rank("weapon_melee") + 2, "threshold": 6}
		and soldier.has_modifier("savage_attacker"), "épée longue à deux mains : rang + 2 dés contre FOR 6 ; Frappe brutale")
	var hero := Character.create("goblin", "fighter", "Héros")  # pas d'humain : il a un don en plus dès le départ
	hero.add_xp(300)
	_level_up(hero)
	_expect(hero.level == 2 and hero.pending_ability_points == 0 and hero.pending_feats == 0 and hero.pending_skill_points == 1, "niveau 2 : pas d'amélioration, un point de compétence")
	hero.add_xp(2700 - 300)
	_level_up(hero)
	_expect(hero.level == 4 and hero.pending_feats == 1 and hero.pending_ability_points == 0, "niveau 4 : un don")
	_expect("lucky" not in hero.available_feats() and hero.choose_feat("heavy_armor_training"), "niveau 4 : pas de don d'origine")
	hero.add_xp(6500 - 2700)
	_level_up(hero)
	_expect(hero.level == 5 and hero.pending_feats == 0 and hero.pending_ability_points == 1, "niveau 5 : +1 attribut, pas de don")
	_expect(hero.increase_ability("str") and hero.abilities["str"] == 7, "+1 FOR (6 -> 7)")
	_expect(hero.pending_ability_points == 0 and not hero.increase_ability("dex"), "un seul point à placer")
	hero.pending_feats = 1  # don en plus (humain, événement)
	_expect("grappler" in hero.available_feats() and "elemental_adept" not in hero.available_feats(),
		"dons disponibles selon les prérequis")
	_expect(not hero.choose_feat("elemental_adept"), "impossible de choisir un don sans les prérequis")
	_expect(hero.choose_feat("grappler") and hero.pending_feats == 0 and hero.has_feat("grappler"), "choix d'un don")
	hero.add_xp(355000)
	_level_up(hero)
	_expect(hero.level == Progression.max_level() and Progression.max_level() == 20, "niveau maximum 20")
	_expect(hero.pending_feats == 4 and hero.pending_ability_points == 3, "attributs aux niveaux 10, 15 et 20, dons aux niveaux 8, 12, 16 et 20")
	hero.abilities["str"] = 12
	_expect(hero.can_raise("str"), "pas de maximum d'attribut")

	var clumsy := Character.create("human", "wizard", "x",
		{"abilities": {"str": 3, "dex": 4, "con": 6, "int": 6, "wis": 5, "cha": 5}})
	_expect(not Feats.meets_prerequisites("defensive_duelist", clumsy), "prérequis non remplis (DEX 5)")
	_expect(Feats.meets_prerequisites("defensive_duelist", Character.create("human", "rogue", "x")), "prérequis remplis")
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
	DB.creatures["_golem"] = {"id": "_golem", "name": "Golem", "hp": 100, "abilities": {"dex": 1},
		"actions": [{"name": "Poing", "weight": 1, "target": "enemy", "effects": [{"type": "damage", "damage": {"dice": 1, "threshold": 1}, "damage_type": "bludgeoning"}]}],
		"defenses": {"resistances": ["slashing"]}}
	Game.start_life(Character.create("human", "fighter", "Testeur"), 3)
	var combat := Game.start_combat({"enemies": ["_golem"]})
	var golem := combat.enemies()[0]
	var beats: Array[Dictionary] = []
	var weapon := {"type": "attack", "weapon": true}
	await combat._hit(combat.hero, golem, weapon, combat.hero.attack_pool(weapon), 3, false, false, beats, true)
	var hurt: Array = beats.filter(func(b): return "subit" in b["text"])
	_expect(not hurt.is_empty() and ("résistance" in hurt[0]["text"] or "subit 0 dégâts" in hurt[0]["text"]),
		"combat : résistance appliquée")
	DB.creatures.erase("_golem")
	Game.combat = null

	# Validation : une espèce ne peut pas modifier les attributs.
	var errors: Array[String] = []
	DataValidator._validate_modifiers(DB, [{"type": "ability", "id": "str", "amount": 2}], "test", errors, false)
	_expect(errors.any(func(e): return "espèce" in e), "le validateur refuse un bonus d'attribut d'espèce")
	return true


func _test_point_buy() -> bool:
	var pb := PointBuy.from_class("wizard")
	_expect(pb.remaining() == 0 and pb.is_valid() and pb.bonuses.is_empty(), "le modèle de classe dépense exactement 9 points, sans bonus")
	_expect(not pb.can_increase("str"), "plus de points disponibles")
	pb.decrease("int")
	_expect(pb.base["int"] == 5 and pb.remaining() == 1 and not pb.is_valid(), "6 -> 5 rend 1 point ; il faut tout dépenser")
	pb.increase("str")
	_expect(pb.base["str"] == 4 and pb.remaining() == 0 and pb.is_valid(), "3 -> 4 coûte 1 point")
	for i in 10:
		pb.decrease("str")
	_expect(pb.base["str"] == 3, "pas en dessous de 3")
	var max_pb := PointBuy.from_class("fighter")
	max_pb.decrease("con")
	max_pb.decrease("con")
	_expect(not max_pb.can_increase("str"), "pas au-dessus de 6")
	return true


func _test_conditions() -> bool:
	var life := _new_life()
	var meta := MetaState.new()
	_expect(Conditions.check({"type": "species", "in": ["goblin"]}, life, meta), "condition espèce")
	_expect(Conditions.check({"type": "size", "in": [-1]}, life, meta) and Conditions.check({"type": "size", "max": -1}, life, meta)
		and not Conditions.check({"type": "size", "min": 0}, life, meta), "condition taille")
	_expect(Conditions.check({"type": "gender", "in": ["nonbinary"]}, life, meta), "condition genre (par défaut)")
	_expect(not Conditions.check({"type": "background", "in": ["sage"]}, life, meta), "condition passé")
	_expect(Conditions.describe({"type": "size", "in": [-2, -1]}) == "Taille : Très petite / Petite",
		"description de la condition de taille")
	_expect(Loc.gendered("Vous êtes {g:prêt|prête|prêt·e} !", "female") == "Vous êtes prête !", "accord féminin")
	_expect(Loc.gendered("{g:il|elle|iel} et {g:un|une|un·e}", "nonbinary") == "iel et un·e", "accord neutre")
	_expect(not Conditions.check({"type": "class", "in": ["fighter"]}, life, meta), "condition classe")
	_expect(Conditions.check({"type": "ability", "id": "int", "min": 6}, life, meta), "condition attribut min")
	_expect(not Conditions.check({"type": "flag", "id": "x"}, life, meta), "flag absent")
	life.flags["x"] = true
	_expect(Conditions.check({"type": "flag", "id": "x"}, life, meta), "flag présent")
	_expect(not Conditions.check({"type": "not", "condition": {"type": "flag", "id": "x"}}, life, meta), "not")
	_expect(Conditions.check({"type": "any", "conditions": [
		{"type": "flag", "id": "nope"}, {"type": "gold", "min": 1}]}, life, meta), "any")
	_expect(Conditions.check({"type": "time", "in": ["morning"]}, life, meta), "matin au départ")
	_expect(Weather.season_of(1)["id"] == "spring" and Weather.season_of(100)["id"] == "summer" and Weather.season_of(300)["id"] == "winter"
		and Conditions.check({"type": "season", "in": ["spring"]}, life, meta), "saisons : le jour 1 ouvre le printemps")
	_expect(Weather.weather_of(5) == Weather.weather_of(5) and not Weather.weather_of(5).is_empty()
		and Conditions.check({"type": "weather", "in": [Weather.weather_of(life.day)["id"]]}, life, meta), "météo du jour stable")
	var seen_weather := {}
	for d in range(1, 120):
		seen_weather[Weather.weather_of(d)["id"]] = true
	_expect(seen_weather.size() >= 4, "la météo varie d'un jour à l'autre")
	_expect(Conditions.describe({"type": "ability", "id": "int", "min": 5}) == "INT 5+", "description de condition")
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
	var chance: Variant = DB.rules.get("aging_chance", 1.0)
	DB.rules["aging_chance"] = 1.0  # une perte chaque année, pour le test
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
	_expect(total_after == total_before - 1, "au-delà de l'âge limite, -1 à un attribut (chance par an)")
	_expect(life.take_notices().any(func(n): return n.begins_with("Le poids des ans")), "le joueur est prévenu")
	life.advance_time(per_year * 200)
	_expect(life.dead and life.death_cause == "Mort de vieillesse", "la vieillesse finit par tuer")
	_expect(ch.abilities.values().has(0) or ch.hp == 0, "mort quand un attribut (ou la CON, donc les PV) atteint 0")
	DB.rules["aging_chance"] = chance
	_expect(not Meta.is_background_available("custom") and Meta.is_background_available("soldier"), "passé Sur mesure verrouillé")
	Meta.record_life(life)
	_expect(Meta.is_background_available("custom"), "mourir de vieillesse débloque le passé Sur mesure")
	Meta.reset()
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
	life.advance_time(2)
	_expect(life.day == 2 and life.slot == 0, "nouveau jour (après la période « Coucher »)")

	var market: Dictionary = DB.events["town_market"]
	life.character.gold = 0
	var choices := EventEngine.visible_choices(market, life, meta)
	_expect(choices.size() == 1 and choices[0]["choice"]["id"] == "leave", "les choix verrouillés sont cachés")
	choices = EventEngine.visible_choices(market, life, meta, true)
	_expect(choices.size() == 4, "en debug, les choix verrouillés sont visibles")
	_expect(not choices[0]["available"] and choices[0]["reason"] == "Or 10+", "en debug, la raison est affichée")

	var shrine: Dictionary = DB.events["forest_shrine"]
	_expect(EventEngine.visible_choices(shrine, life, meta).size() == 2, "choix secrets cachés sans le flag ni le passé")

	# Récolte dans un lieu sauvage : un test par ressource.
	# Chercher… : chasse (combat si on trouve la créature, embuscade sinon), quelqu'un à qui parler.
	var hunt := EventEngine.hunt_event("forest", RandomNumberGenerator.new())
	var wolves: Dictionary = hunt["choices"][0]
	_expect(wolves["success"]["effects"][0] == {"type": "combat", "enemies": ["wolf"]}
		and wolves["critical_success"]["effects"][0]["enemies"].size() == 2 and not wolves["failure"]["effects"].is_empty(),
		"chasse aux loups : trouvés, plus nombreux sur un critique, autre chose sur un échec")
	_expect(EventEngine.hunt_event("town", RandomNumberGenerator.new())["choices"][0]["failure"]["effects"].is_empty(),
		"chasse en ville : un échec ne lance pas de combat")
	_expect(EventEngine.stranger_check("town").is_empty() and EventEngine.stranger_check("forest")["difficulty"] == 3
		and not EventEngine.ambush_event("forest", RandomNumberGenerator.new(), "").is_empty(),
		"chercher quelqu'un : sans test en ville, Nature 3 en forêt, embuscade sinon")
	_expect(wolves["failure"]["effects"] == [{"type": "random_event", "location": "forest"}], "chasse ratée : autre chose arrive")
	var mishaps := {}
	for i in 40:
		var mishap_ev := EventEngine.mishap_event("forest", life, meta)
		mishaps[mishap_ev.get("title") == "Embuscade"] = true
	_expect(mishaps.size() == 2 and EventEngine.mishap_event("town", life, meta).is_empty(),
		"recherche ratée dans la nature : un combat ou un autre événement, rien en ville")
	_expect(Effects.apply_all([{"type": "random_event", "location": "forest"}], life, meta)["goto"] == "@forest",
		"effet random_event : enchaîne sur un événement du lieu")
	var gather := EventEngine.gather_event("forest")
	_expect(EventEngine.gather_event("town").is_empty() and gather["choices"].size() == 4, "récolte : seulement dans les lieux sauvages")
	var errors_gather: Array[String] = []
	DataValidator._validate_event(DB, gather, errors_gather)
	_expect(errors_gather.is_empty(), "récolte : un événement valide %s" % str(errors_gather))
	var herbs: Dictionary = gather["choices"][0]
	var herbs_before := life.character.item_count("healing_herbs")
	var gathered := EventEngine.resolve_choice(gather, herbs, life, meta, {"success": true, "critical": 0, "fumble": false})
	_expect(gathered["outcome"] == "success" and life.character.item_count("healing_herbs") == herbs_before + 1, "récolte réussie : une herbe")

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
	_expect(locked == 2, "création : Elfe et Magicien verrouillés au départ")
	screen._on_class_selected("fighter")
	screen._apply_class_template()
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
	ch = screen.build_character()
	_expect(ch.abilities["str"] == 5 and ch.abilities["cha"] == 5 and ch.abilities["dex"] == 5,
		"création : la répartition des points modifie le personnage")
	screen._suggest_skill_ranks()  # le passé tiré au hasard a pu rendre des rangs (plafond de 5)
	_expect(screen.free_ranks_left() == 0, "création : 12 rangs suggérés")
	var arts_before: int = screen.build_character().skill_rank("arts")
	screen.change_skill_rank("perception", -1)
	_expect(screen.free_ranks_left() == 1 and screen.start_button.disabled, "création : un rang à replacer bloque le départ")
	screen.change_skill_rank("arts", 1)
	_expect(screen.free_ranks_left() == 0 and screen.build_character().skill_rank("arts") == arts_before + 1,
		"création : rang libre placé")
	for i in 5:
		screen.change_skill_rank("arts", 1)
	_expect(screen.build_character().skill_rank("arts") <= 5, "création : pas au-delà de 5")
	screen._on_class_selected("wizard")
	var sheet_labels: Array = screen._sheet.find_children("*", "Label", true, false).map(func(l): return l.text)
	_expect(sheet_labels.any(func(t): return t.begins_with("PV : ")) and not sheet_labels.any(func(t): return "≤" in t or "d10" in t),
		"creation : fiche comme celle du tiroir, sans formules de des")
	var page_titles := range(screen.pages.get_tab_count()).map(func(i): return screen.pages.get_tab_title(i))
	_expect(page_titles[1] == "Apparence", "creation : onglet Apparence %s" % str(page_titles))
	var goblin_skin: String = DB.species["goblin"]["art"]["skin"][2]
	screen._on_class_selected("fighter")
	screen.set_look("skin", goblin_skin)
	screen.set_look("hair_style", "braids")
	screen.set_look("body", "broad")
	ch = screen.build_character()
	_expect(ch.look["skin"] == goblin_skin and ch.look["hair_style"] == "braids" and ch.look["body"] == "broad"
		and Character.from_dict(JSON.parse_string(JSON.stringify(ch.to_dict()))).look == ch.look, "creation : apparence choisie et sauvegardee")
	_expect("#e8e4dc" in screen.look_palette("hair") and not ("#e8e4dc" in screen.look_palette("skin")), "creation : teintes communes pour les cheveux")
	screen._on_species_selected("human")
	_expect(screen._look["skin"] in DB.species["human"]["art"]["skin"] and screen._look["hair_style"] == "braids",
		"creation : changer d'espece retire les couleurs, garde la coupe")
	screen._on_class_selected("wizard")
	_expect(screen.build_character().abilities["int"] == 3, "création : changer de classe garde les attributs répartis")
	screen._apply_class_template()
	_expect(screen.build_character().abilities["int"] == 6, "création : le bouton applique le modèle de la classe")
	screen.free()
	return true


func _test_enemy_support() -> bool:
	Game.start_life(Character.create("human", "fighter", "Heros"), 4)
	var combat := Game.start_combat({"enemies": ["bandit_mender", "bandit"]})
	var mender := combat.enemies()[0]
	var bandit := combat.enemies()[1]
	var heal: Dictionary = mender.combat_actions().filter(func(a): return a["name"] == "Onguent")[0]
	var cover: Dictionary = mender.combat_actions().filter(func(a): return a["name"] == "Couvrir un camarade")[0]
	_expect(Combat.support_role(heal) == "heal" and Combat.support_role(cover) == "protect", "IA : roles de soutien reconnus")
	_expect(combat._support_weight(mender, heal) == 0.0 and combat._support_weight(mender, cover) == 0.0,
		"IA : pas de soins ni de protection quand personne n'est blesse")
	bandit.hp = 2
	_expect(combat._support_weight(mender, heal) > float(heal["weight"]) and combat._support_weight(mender, cover) > 0.0,
		"IA : soigner devient prioritaire quand un allie est mal en point")
	var helped := false
	for i in 12:
		bandit.hp = 2
		combat.turn = combat.order.find(mender)
		combat.start_turn()
		await combat.ai_turn(mender)
		if bandit.hp > 2 or bandit.stacks("shielded") > 0:
			helped = true
			break
	_expect(helped, "IA : le rebouteux soigne ou couvre le brigand blesse")
	return true


func _test_npc_requests() -> bool:
	Saves.enabled = false
	Game.start_life(Character.create("human", "fighter", "Heros"), 5)
	var life := Game.life
	var herbalist: Npc = Social.at_location("town", life.rng).filter(func(x): return x.role == "herbalist")[0]
	var session := {}
	_expect(Social.unavailable_reason("deliver", herbalist, life, session) != "", "demande : rien à remettre au départ")
	_expect(Social.unavailable_reason("ask_work", herbalist, life, session) == "", "demande : l'herboriste a du travail")
	var result := Social.perform("ask_work", herbalist, life, session)
	var quest_id := Social.active_request(herbalist, life)
	_expect(quest_id != "" and life.quests[quest_id]["status"] == "active" and "herbes" in Quests.step_text(quest_id, 0).to_lower(),
		"demande : une quête générée %s" % str(result["lines"]))
	_expect(Social.unavailable_reason("ask_work", herbalist, life, session) != "", "demande : une seule à la fois")
	_expect(Social.unavailable_reason("deliver", herbalist, life, session).begins_with("il vous manque"), "demande : il manque les herbes")
	var loaded := LifeState.from_dict(JSON.parse_string(JSON.stringify(life.to_dict())))
	_expect(loaded.quest_defs.has(quest_id) and loaded.quests[quest_id]["status"] == "active", "demande : sauvegardée")
	life.character.add_item("healing_herbs", 3)
	var gold := life.character.gold
	var friendship := int(herbalist.player["friendship"])
	Social.perform("deliver", herbalist, life, session)
	_expect(life.quests[quest_id]["status"] == "done" and life.character.gold == gold + 12 and life.character.item_count("healing_herbs") == 0
		and int(herbalist.player["friendship"]) > friendship, "demande : remise contre l'or promis et de l'amitié")
	_expect(Social.unavailable_reason("ask_work", herbalist, life, session) == "rien pour l'instant", "demande : délai avant la suivante")
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
	screen._on_increase("wis")
	screen._on_increase("wis")
	screen._on_rank("start_level", 1)
	screen._on_rank("start_level", 1)
	_expect(screen._cp_ranks["start_level"] == 2, "création : impossible de dépasser le solde (6 + 12 + 20 > 30)")
	_expect(screen.confirm_creation() and Meta.creator_points == 30 - 18 - 4 and Game.life.character.level == 3,
		"création : les Creator Points sont dépensés au lancement")
	screen.free()

	Meta.creator_points = 15
	_expect(Meta.buy_unlock("species:elf") and Meta.creator_points == 0 and Meta.is_species_available("elf"),
		"déblocage définitif acheté")
	_expect(not Meta.buy_unlock("class:wizard") and not Meta.is_class_available("wizard"), "une classe ne s'achète pas : elle se débloque par un succès")
	Meta.load_dict(backup)
	return true


func _test_quests() -> bool:
	var life := _new_life("human", "fighter")
	_expect(Quests.has("ysolde_herbs") and Conditions.check({"type": "quest", "id": "ysolde_herbs", "status": "none"}, life, Meta),
		"quête pas encore commencée")
	var res := Effects.apply_all([{"type": "quest", "id": "ysolde_herbs", "action": "start"}], life, Meta)
	_expect(res["lines"] == ["Nouvelle quête : Des herbes pour Ysolde."] and Quests.with_status(life, "active") == ["ysolde_herbs"]
		and Conditions.check({"type": "quest", "id": "ysolde_herbs"}, life, Meta), "commencer une quête")
	Effects.apply_all([{"type": "quest", "id": "ysolde_herbs", "action": "advance"}], life, Meta)
	_expect(int(life.quests["ysolde_herbs"]["step"]) == 1 and Conditions.check({"type": "quest", "id": "ysolde_herbs", "step": 1}, life, Meta),
		"faire avancer une quête")
	Effects.apply_all([{"type": "quest", "id": "ysolde_herbs", "action": "complete"}], life, Meta)
	_expect(Quests.with_status(life, "done") == ["ysolde_herbs"] and Conditions.check({"type": "quest", "id": "ysolde_herbs", "status": "done"}, life, Meta),
		"quête accomplie")
	var saved := LifeState.from_dict(JSON.parse_string(JSON.stringify(life.to_dict())))
	_expect(saved.quests == life.quests, "quêtes sauvegardées")
	_expect(life.journal.any(func(e): return e["kind"] == "quest" and "Quête accomplie" in e["text"])
		and saved.journal == life.journal, "journal : les quêtes y sont notées, et il est sauvegardé")
	# L'événement d'Ysolde lance la quête.
	life = _new_life("human", "fighter")
	var ev: Dictionary = DB.events["town_merchant_meet"]
	EventEngine.resolve_choice(ev, ev["choices"][0], life, Meta)
	_expect(Quests.with_status(life, "active") == ["ysolde_herbs"], "accepter la commande d'Ysolde lance la quête")
	return true


func _test_side_drawer() -> bool:
	_expect(SideDrawer.short_gold(950) == "950 po" and SideDrawer.short_gold(1000) == "1k po" and SideDrawer.short_gold(1250) == "1,2k po"
		and SideDrawer.short_gold(3400000) == "3,4M po", "or abrégé")
	Game.start_life(Character.create("human", "wizard", "Bergot", {"gender": "male"}), 171)
	var life := Game.life
	var drawer := SideDrawer.new()
	drawer.life = life
	drawer.size = Vector2(1280, 720)
	add_child(drawer)
	var hero := life.character
	_expect(drawer._tab_buttons["character"].text == "PV %d/%d" % [hero.hp, hero.max_hp] and drawer._tab_buttons["inventory"].text == "15 po"
		and drawer._tab_buttons["spells"].visible, "onglets : PV, or, sorts (lanceur)")
	for page_id: String in SideDrawer.PAGES:
		drawer.open(page_id)
		_expect(drawer.is_open() and drawer._content.find_children("*", "Control", true, false).size() > 1, "page %s remplie" % page_id)
	drawer.open("character")
	var texts: Array = drawer._content.find_children("*", "Label", true, false).map(func(c): return c.text)
	_expect(texts.has("Bergot") and texts.has("Humain Homme") and texts.has("Magicien niv. 1")
		and texts.has("Esquive naturelle : %d" % hero.natural_dodge()) and texts.has("Armure : 0"), "page personnage : nom, espèce, classes, défenses")
	drawer.open("spells")
	var checks: Array = drawer._content.get_children().filter(func(c): return c is CheckBox)
	_expect(checks.size() == hero.known_spells().size(), "page des sorts : un sort connu par ligne")
	_expect(checks.filter(func(c): return c.disabled and c.button_pressed).size() == 2, "tours de magie : cochés et grisés (toujours prêts)")
	life.log_journal("combat", "Victoire contre : Loup.")
	life.log_journal("quest", "Nouvelle quête : Test.")
	drawer.open("journal")
	var journal_texts: Array = drawer._content.find_children("*", "Label", true, false).map(func(c): return c.text)
	_expect(journal_texts.any(func(t): return "Victoire contre : Loup." in t) and journal_texts.has("Jour %d" % life.day),
		"journal : entrées groupées par jour")
	drawer._journal_filter = "quest"
	drawer.open("journal")
	journal_texts = drawer._content.find_children("*", "Label", true, false).map(func(c): return c.text)
	_expect(not journal_texts.any(func(t): return "Victoire" in t) and journal_texts.any(func(t): return "Nouvelle quête" in t),
		"journal : filtre par sorte")
	_expect(drawer.handle_key(KEY_N) and drawer._current == "notes" and drawer._pinned, "raccourci N : notes épinglées")
	var note_edit: TextEdit = drawer._content.find_children("*", "TextEdit", true, false)[0]
	note_edit.text = "Ysolde paie bien."
	note_edit.text_changed.emit()
	_expect(life.notes == "Ysolde paie bien." and LifeState.from_dict(JSON.parse_string(JSON.stringify(life.to_dict()))).notes == life.notes,
		"notes libres sauvegardées")
	_expect(drawer.handle_key(KEY_ESCAPE) and not drawer.is_open(), "Échap replie la page épinglée")
	drawer.close()
	_expect(not drawer.is_open(), "replier le tiroir")
	var fighter_life := _new_life("human", "fighter")
	drawer.life = fighter_life
	drawer.refresh()
	_expect(not drawer._tab_buttons["spells"].visible, "pas d'onglet Sorts sans lanceur de sorts")
	drawer.free()
	return true


func _test_dice_tray() -> bool:
	var tray := DiceTray.new()
	tray.size = Vector2(800, 240)
	add_child(tray)
	tray.play({"dice": [{"sides": 10, "value": 7, "label": "A", "total": 15}, {"sides": 10, "value": 3, "label": "B", "total": 9},
		{"sides": 10, "value": 8, "label": "C", "total": 12}], "stat": "Initiative", "per_die": true})
	_expect(tray.is_playing() and tray._notation() == "Initiative : 3d10", "dés : notation")
	var elapsed := 0.0
	var on_tray := true
	while tray.is_playing() and elapsed < 10.0:
		tray._process(1.0 / 60.0)
		for d in tray._dice:
			on_tray = on_tray and Rect2(Vector2.ZERO, tray.size).grow(1.0).has_point(d["pos"])
		elapsed += 1.0 / 60.0
	_expect(on_tray, "dés : restent sur le plateau")
	_expect(not tray.is_playing() and elapsed < 5.0, "dés : l'animation se termine (%.1f s)" % elapsed)
	_expect(tray._dice.map(func(d): return d["shown"]) == [7, 3, 8], "dés : affichent les valeurs tirées")

	# Réserve de d10 : notation (sans les dés nés d'un 1), verdict en succès, beaucoup de dés.
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var roll := Dice.roll_pool(rng, 14, 6)
	var info := {"pool": true, "dice": roll["dice"], "threshold": 6, "successes": roll["successes"], "difficulty": 2,
		"success": int(roll["successes"]) >= 2, "critical": 0, "fumble": false, "stat": "Physique"}
	tray.play(info)
	_expect(tray._notation() == "Physique : 14d10 ≤ 6", "réserve : notation")
	elapsed = 0.0
	on_tray = true
	while tray.is_playing() and elapsed < 20.0:
		tray._process(1.0 / 60.0)
		for d in tray._dice:
			on_tray = on_tray and Rect2(Vector2.ZERO, tray.size).grow(DiceTray.DIE_RADIUS).has_point(d["pos"])
		elapsed += 1.0 / 60.0
	_expect(not tray.is_playing() and on_tray, "réserve de 14 dés : animation terminée, dés sur le plateau (%.1f s)" % elapsed)
	tray.free()
	return true


## Joue un combat entièrement en automatique et retourne le résultat de Game.finish_combat().
## Joue un combat entièrement en automatique et retourne le résultat de Game.finish_combat().
func _auto_combat(spec: Dictionary) -> Dictionary:
	await _play_out(Game.start_combat(spec))
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
				await combat.auto_turn(actor)
			else:
				await combat.ai_turn(actor)
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
	_expect(ok, "2d6+3 : deux dés, bonus 3, total entre 5 et 15 (or trouvé)")

	# Réserves de d10 : succès <= seuil, jamais 9 ou 10, toujours 1 (relancé).
	_expect(Dice.is_success(1, 0) and Dice.is_success(5, 5) and not Dice.is_success(6, 5) and not Dice.is_success(9, 12),
		"succès : 1 toujours, 9 et 10 jamais")
	_expect(Dice.normalize(3, 10) == {"count": 5, "threshold": 8, "auto": 0}, "seuil 10 : 2 dés de plus au seuil 8")
	_expect(Dice.normalize(-1, 5) == {"count": 1, "threshold": 3, "auto": 0}, "malus sous 1 dé : le seuil baisse")
	_expect(Dice.normalize(25, 6, true) == {"count": 5, "threshold": 6, "auto": 14}, "dés nombreux : 2 × (seuil + 1)")
	var valid := true
	var total := 0
	for i in 4000:
		var roll := Dice.roll_pool(rng, 3, 5)
		var counted := 0
		var dice: Array = roll["dice"]
		for k in dice.size():
			var d: Dictionary = dice[k]
			valid = valid and d["success"] == Dice.is_success(d["value"], 5)
			counted += 1 if d["success"] else 0
			if d["value"] == 1:
				valid = valid and k + 1 < dice.size() and dice[k + 1].get("extra", false)
		valid = valid and counted == roll["successes"] and dice.filter(func(d): return not d.get("extra", false)).size() == 3
		total += int(roll["successes"])
	_expect(valid, "réserve : succès comptés, chaque 1 suivi d'un dé relancé")
	_expect(absf(total / 4000.0 - Dice.expected(3, 5)) < 0.08, "moyenne conforme : %.2f contre %.2f" % [total / 4000.0, Dice.expected(3, 5)])
	var dist := Dice.distribution(2, 4)
	var sum := 0.0
	for p in dist:
		sum += p
	_expect(absf(sum - 1.0) < 0.001 and absf(Dice.chance(1, 4, 1) - 0.4) < 0.001 and Dice.chance(2, 5, 0) == 1.0,
		"probabilités : 1 dé au seuil 4 = 40 %")

	# Critiques : relances des dés ratés ; échecs critiques.
	valid = true
	for i in 200:
		var roll := Dice.roll_pool(rng, 4, 3, 2)
		var dice: Array = roll["dice"]
		valid = valid and dice.filter(func(d): return d.get("dropped", false)).all(func(d): return not d["success"])
		valid = valid and int(roll["successes"]) == dice.filter(func(d): return d["success"] and not d.get("dropped", false)).size()
	_expect(valid, "critique : seuls les dés ratés sont relancés")
	_expect(Dice.judge(5, 2)["critical"] == 1 and Dice.judge(8, 2)["critical"] == 2 and Dice.judge(4, 2)["critical"] == 0,
		"réussite critique 1 à 3 succès supplémentaires, 2 à 6")
	var ten := [{"sides": 10, "value": 10, "success": false}]
	var nine := [{"sides": 10, "value": 9, "success": false}]
	_expect(Dice.judge(3, 2, 2)["critical"] == 1 and Dice.judge(0, 1, 0, ten)["fumble"] and not Dice.judge(0, 1, 0, nine)["fumble"]
		and not Dice.judge(1, 2, 0, ten)["fumble"],
		"surprise : critique dès 1 succès supplémentaire ; échec critique : aucun succès et un 10")
	Meta.settings["many_dice"] = true
	var many := Dice.roll_pool(rng, 12, 5)
	_expect(many["auto"] == 6 and many["count"] == 2 and many["successes"] >= 6, "option dés nombreux : 10 dés = 6 succès au seuil 5")
	Meta.settings["many_dice"] = false
	var ch := Character.create("human", "fighter", "Testeur")
	var check := {"skill": "physique", "difficulty": 2}
	var result := Dice.roll_check(ch, check, rng)
	var physique := ch.skill_pool("physique")
	_expect(result["text"].begins_with("Physique : %s," % Dice.pool_text(physique["count"], physique["threshold"]))
		and result["pool"], "test : texte du jet, plateau en mode réserve")
	var base := Dice.success_chance(ch, check)
	check["advantage"] = true
	_expect(Dice.success_chance(ch, check) > base, "avantage : difficulté −1")
	check["disadvantage"] = true
	_expect(is_equal_approx(Dice.success_chance(ch, check), base), "avantage et désavantage s'annulent")
	return true


func _test_combat() -> bool:
	# Guerrier humain au modèle : FOR 7, Armes de mêlée 2, épée longue à deux mains (+2 dés), cotte de mailles (Armure 3).
	Game.start_life(Character.create("human", "fighter", "Testeur"), 99)
	var life := Game.life
	var fighter := Combatant.from_character(life.character, true)
	var weapon := {"type": "attack", "weapon": true}
	var attack := fighter.attack_pool(weapon)
	_expect(attack["count"] == life.character.skill_rank("weapon_melee") and attack["threshold"] == fighter.ability_score("dex")
		and fighter.damage_pool(weapon, attack) == {"count": 7, "threshold": fighter.ability_score("str")},
		"guerrier : toucher [Armes de mêlée] d10 ≤ DEX, dégâts 7d10 (épée longue) ≤ FOR")
	_expect(fighter.damage_type(weapon) == "slashing" and fighter.armor() == 3 and fighter.natural_dodge() == 1,
		"épée longue tranchante ; Armure 3, Esquive naturelle 1")
	var mage := Combatant.from_character(Character.create("goblin", "wizard", "Mage"), true)
	var bolt: Dictionary = Actions.def("fire_bolt")["effects"][0]
	var spell := mage.attack_pool(bolt)
	var magic_rank := mage.character.skill_rank(Skills.SPELL)
	_expect(spell["count"] == magic_rank and spell["threshold"] == 6 and mage.damage_pool(bolt, spell) == {"count": 6, "threshold": 6}
		and mage.is_ranged_attack(bolt), "trait de feu : [Magie] d10 ≤ INT 6, dégâts 6 dés seuil INT, à distance")

	var combat := Game.start_combat({"enemies": ["wolf", "wolf"]})
	_expect(combat.combatants.size() == 3 and combat.order.size() == 3, "combat : héros + 2 loups")
	_expect(combat.enemies()[0].name == "Loup A" and combat.enemies()[1].name == "Loup B", "ennemis identiques numérotés")
	var wolf := combat.enemies()[0]
	_expect(wolf.max_hp() == Character.hp_from(5, -1) and wolf.natural_dodge() == 2 and wolf.armor() == 0,
		"loup : PV selon CON et taille, Esquive naturelle 2")
	_expect(combat.cover(wolf) == 1 and combat.cover(combat.hero) == 1, "Couvert : 1 par défaut")
	await _play_out(combat)
	var result := Game.finish_combat()
	_expect(result["outcome"] in ["victory", "defeat"], "le combat aboutit à une victoire ou une défaite")
	if result["outcome"] == "victory":
		var killed := combat.enemies().filter(func(w): return not w.fled).size()
		_expect(life.character.item_count("wolf_pelt") == killed and life.character.xp == 50 * killed, "victoire : XP et butin (loups tués)")
	else:
		_expect(life.dead and life.death_cause == "Dévoré par un loup", "défaite mortelle : cause de la mort")

	# Créature de test imparable pour forcer les défaites.
	DB.creatures["_ogre"] = {"id": "_ogre", "name": "Ogre", "hp": 500, "abilities": {"dex": 30, "str": 30},
		"skills": {"physique": 30},
		"actions": [{"name": "Massue", "weight": 1, "target": "enemy", "effects": [{"type": "attack", "skill": "physique",
			"ability": "str", "damage": {"threshold": 8, "dice": 60}, "damage_type": "bludgeoning"}]}],
		"xp": 0}
	Game.start_life(Character.create("human", "fighter", "Testeur"), 5)
	result = await _auto_combat({"enemies": ["_ogre"], "on_defeat": "knockout",
		"defeat": {"text": "K.-O.", "effects": [{"type": "gold", "amount": -5}]}})
	_expect(result["outcome"] == "defeat" and not Game.life.dead and Game.life.character.hp == 1,
		"K.-O. : défaite non mortelle, 1 PV")
	_expect(Game.life.character.gold == 10 and result["text"] == "K.-O.", "K.-O. : effets de l'issue « defeat »")
	result = await _auto_combat({"enemies": ["_ogre"]})
	_expect(result["outcome"] == "defeat" and Game.life.dead and Game.life.death_cause == "Tué par Ogre", "défaite mortelle")

	Game.start_life(Character.create("human", "fighter", "Testeur"), 6)
	combat = Game.start_combat({"enemies": ["_ogre"], "flee_difficulty": 0,
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

	# Initiative : 1d10 + DEX + INT ; égalité : DEX, puis INT.
	Game.start_life(Character.create("human", "fighter", "Testeur"), 7)
	combat = Game.start_combat({"enemies": ["wolf", "bandit"]})
	var sorted := true
	for i in combat.order.size() - 1:
		var a := combat.order[i]
		var b := combat.order[i + 1]
		sorted = sorted and (a.initiative > b.initiative or (a.initiative == b.initiative
			and a.ability_score("dex") >= b.ability_score("dex")))
	_expect(sorted and combat.initiative_roll["dice"].all(func(d): return d["sides"] == 10), "initiative : d10, ordre décroissant")
	_expect(combat.hero.initiative - Game.life.character.initiative_base() in range(1, 11), "initiative : base + 1d10")
	Game.combat = null
	return true


func _test_actions() -> bool:
	# Actions de classe, utilisations par combat et emplacements de sort.
	Game.start_life(Character.create("goblin", "wizard", "Mage"), 7)
	var combat := Game.start_combat({"enemies": ["giant_rat", "giant_rat"]})
	var mage := combat.hero
	var names := combat.action_choices(mage).map(func(c): return c["action"]["id"])
	_expect(names == Game.life.character.combat_actions(), "actions du magicien : celles de sa classe")
	var missile := Actions.def("magic_missile")
	await combat.perform(mage, missile, combat.living("enemy")[0])
	await combat.perform(mage, missile, combat.living("enemy")[0] if not combat.living("enemy").is_empty() else null)
	_expect(Game.life.character.resources["spell_slot"] == 0, "projectile magique : 2 emplacements dépensés")
	# Chercher les points faibles : un test d'Érudition ; réussi, les défenses de la cible sont connues.
	var rat: Combatant = combat.living("enemy")[0] if not combat.living("enemy").is_empty() else null
	if rat != null:
		Game.life.character.skill_points["lore"] = 30
		combat.actions_left = 2
		await combat.perform(mage, Actions.def("find_weakness"), rat)
		_expect(rat.weaknesses_known, "Chercher les points faibles : défenses révélées")
		_expect(Game.life.bestiary.has("giant_rat") and combat.living("enemy").all(func(c): return c.weaknesses_known),
			"points faibles : connus pour toute l'espèce")
		Game.life.character.skill_points["survival"] = 30
		Game.life.character.skill_points["lore"] = 0
		_expect(combat._best_skill(mage, ["lore", "survival"], 2) == "survival", "points faibles : la meilleure compétence")
	_expect(mage.unavailable_reason(missile) == "", "plus de mana : le sort reste possible, payé en PV")
	var hp_before := mage.hp
	_expect(mage.consume(missile) == 1 and mage.hp == hp_before - 1 and Game.life.character.resources["spell_slot"] == 0, "mana manquant : 1 PV par point")
	Game.finish_combat()
	var again := Game.start_combat({"enemies": ["giant_rat", "bandit"]})
	_expect(again.living("enemy").map(func(c): return c.weaknesses_known) == [true, false], "carnet de bestiaire : points faibles déjà connus")
	Game.finish_combat()
	Game.life.character.resources["spell_slot"] = 0
	Game.life.character.short_rest()
	_expect(Game.life.character.resources["spell_slot"] == 1, "repos court : moitié du mana manquant")
	Effects.apply_all([{"type": "long_rest"}], Game.life, Meta)
	_expect(Game.life.character.resources["spell_slot"] == 2, "repos long : emplacements restaurés")

	# Deux actions par tour ; celles qu'on garde deviennent des réactions, puis Préparé.
	Game.start_life(Character.create("human", "fighter", "Guerrier"), 8)
	combat = Game.start_combat({"enemies": ["wolf"]})
	var hero := combat.hero
	var wind := Actions.def("second_wind")
	combat.turn = combat.order.find(hero)
	combat.start_turn()
	_expect(combat.actions_left == 2, "deux actions par tour")
	hero.hp = 1
	await combat.perform(hero, wind)
	_expect(hero.hp > 1 and combat.actions_left == 1, "Second souffle : une action, il en reste une")
	_expect(combat.action_unavailable_reason(hero, wind) != "" and combat.can_act_again(), "une seule fois")
	combat.end_turn()
	_expect(hero.reactions == 1, "fin de tour avec une action gardée : 1 réaction")
	combat.turn = combat.order.find(hero)
	var beats := combat.start_turn()
	_expect(hero.reactions == 0 and hero.is_prepared() and beats[0]["text"].contains("préparé"),
		"réaction non utilisée : préparé au début de son tour")
	_expect(hero.use_prepared() == 2 and not hero.is_prepared(), "préparé : +2 dés au prochain jet de combat, puis disparaît")
	await combat.perform(hero, Actions.def("prepare"))
	_expect(hero.is_prepared() and combat.actions_left == 1, "action Se préparer")
	hero.statuses.clear()

	# Parade : une par main armée et par tour ; pas d'attaque à distance sans bouclier ; à mains nues contre
	# une arme, la parade est dangereuse.
	var wolf := combat.enemies()[0]
	var bite: Dictionary = wolf.creature["actions"][0]["effects"][0]
	beats.clear()
	hero.reactions = 2
	combat._parry(wolf, hero, bite, beats, true)
	_expect(hero.reactions == 1 and hero.parries_used == 1 and beats.size() == 1, "parade : une réaction")
	_expect(combat._parry(wolf, hero, bite, beats, true) == 0 and hero.reactions == 1, "une seule parade par tour avec une arme")
	hero.parries_used = 0
	_expect(combat._parry(wolf, hero, {"type": "attack", "ranged": true}, beats, true) == 0 and hero.reactions == 1,
		"attaque à distance : pas de parade sans bouclier")
	hero.character.equip("shield")
	_expect(hero.parries_per_turn() == 2, "arme et bouclier : deux parades par tour")
	hero.character.unequip("main_hand")
	hero.character.unequip("off_hand")
	_expect(combat._parry(wolf, hero, {"type": "attack", "weapon": "dagger"}, beats, true) >= 0 and hero.reactions == 0,
		"mains nues contre une arme : parade possible (dangereuse)")
	hero.reactions = 1
	hero.parries_used = 0
	_expect(combat._parry(wolf, hero, bite, beats, true) >= 0 and hero.reactions == 0, "mains nues contre des crocs : parade possible")
	hero.character.equip("longsword")
	hero.reactions = 1
	var dodged := combat._dodge(hero, beats, true)
	_expect(hero.reactions == 0 and dodged >= 0, "esquive : une réaction (Physique, DEX)")

	# Contre-attaque : en opposition, le plus de succès touche ; le perdant ne se défend pas.
	DB.creatures["_duelist"] = {"id": "_duelist", "name": "Bretteur", "hp": 50, "abilities": {"str": 8, "dex": 8},
		"skills": {"physique": 40},
		"actions": [{"name": "Estoc", "weight": 1, "target": "enemy", "effects": [{"type": "attack", "skill": "physique",
			"ability": "dex", "damage": {"threshold": 8, "dice": 2}, "damage_type": "piercing"}]}]}
	Game.start_life(Character.create("human", "fighter", "Guerrier"), 9)
	combat = Game.start_combat({"enemies": ["_duelist"]})
	hero = combat.hero
	var duelist := combat.enemies()[0]
	hero.character.max_hp = 999
	hero.hp = 999
	duelist.reactions = 1
	var before := combat.log.size()
	beats.clear()
	var weapon := {"type": "attack", "weapon": true}
	var duel_hit: bool = await combat._attack(hero, duelist, weapon, beats, true)
	_expect(not duel_hit and duelist.reactions == 0 and hero.hp < 999,
		"contre-attaque : le bretteur l'emporte et touche")
	_expect(combat.log.slice(before).any(func(l): return "contre-attaque" in l), "contre-attaque annoncée")
	hero.reactions = 1
	duelist.reactions = 0
	var hp := duelist.hp
	await combat._hit(hero, duelist, weapon, hero.attack_pool(weapon), 0, false, true, beats, true)
	_expect(duelist.hp <= hp, "attaque qui touche : dégâts")
	DB.creatures.erase("_duelist")

	# Attaque surprise : cachée, l'attaquante ignore l'Esquive naturelle et l'Armure (pas l'armure naturelle).
	hero.add_status("invisible", 2)
	_expect(combat.is_surprise(hero, duelist) and combat.attack_difficulty(hero, duelist, weapon) == 1,
		"attaque surprise : Esquive naturelle 1")
	await combat._attack(hero, duelist, weapon, beats, true)
	_expect(hero.stacks("invisible") == 0, "en attaquant, on se révèle")
	# Réactions choisies par le joueur : contre-attaque, esquive, parade ; jamais demandées en mode IA.
	var asked: Array = []
	var answer := [false]
	combat.reaction_chooser = func(_target: Combatant, kind: String, _info: Dictionary) -> bool:
		asked.append(kind)
		return answer[0]
	var lunge := {"type": "attack", "skill": "physique", "ability": "dex", "damage": {"threshold": 8, "dice": 3},
		"damage_type": "piercing"}
	hero.statuses.clear()
	hero.reactions = 2
	hero.parries_used = 0
	await combat._attack(duelist, hero, lunge, beats, true)
	_expect(asked == ["counter", "dodge", "parry"] and hero.reactions == 2, "réactions proposées puis refusées : aucune dépensée")
	asked.clear()
	answer[0] = true
	await combat._attack(duelist, hero, lunge, beats, true)
	_expect(asked == ["counter"] and hero.reactions == 1, "contre-attaque acceptée : une réaction dépensée")
	var archer := {"type": "attack", "ranged": true, "skill": "physique", "ability": "dex", "damage": {"threshold": 8}}
	asked.clear()
	await combat._attack(duelist, hero, archer, beats, true)
	_expect(not asked.has("counter"), "pas de contre-attaque contre un tir sans arme de tir")
	# Option « réactions automatiques » : plus de question au joueur.
	asked.clear()
	hero.reactions = 2
	Meta.settings["auto_reactions"] = true
	await combat._attack(duelist, hero, lunge, beats, true)
	_expect(asked.is_empty(), "option : réactions automatiques pour tout le groupe")
	Meta.settings["auto_reactions"] = false
	# Contresort : opposition des compétences d'incantation, quand un adversaire lance un sort.
	DB.creatures["_witch"] = {"id": "_witch", "name": "Sorcière", "hp": 30, "abilities": {"int": 8}, "spell_ability": "int",
		"skills": {"lore": 30}, "actions": [{"name": "Rien", "weight": 1, "target": "self", "effects": [{"type": "status", "status": "shielded", "stacks": 0}]}]}
	var witch := Combatant.from_creature("_witch", "Sorcière", "enemy")
	combat._add(witch)
	witch.reactions = 1
	var counter_beats: Array[Dictionary] = []
	var countered: bool = await combat._counterspell(hero, Actions.def("fire_bolt"), counter_beats)
	_expect(countered and witch.reactions == 0, "contresort : la sorcière contre le sort (Érudition 30)")
	_expect(not await combat._counterspell(hero, Actions.def("weapon_attack"), counter_beats), "pas de contresort contre une attaque d'arme")
	DB.creatures.erase("_witch")
	asked.clear()
	hero.reactions = 2
	hero.character.auto_combat = true
	_expect(hero.is_auto(), "IA activable par personnage")
	await combat._attack(duelist, hero, lunge, beats, true)
	_expect(asked.is_empty(), "en mode IA, les réactions sont automatiques")
	Game.combat = null
	_expect(Actions.text_of("pommel_strike") == "Attaque avec votre arme. Si elle touche : 1 Étourdi.",
		"texte généré d'une action")
	_expect(Actions.text_of("sleep").begins_with("Tous les ennemis :") and "résiste : SAG" in Actions.text_of("sleep"),
		"texte : cible multiple et résistance %s" % Actions.text_of("sleep"))
	return true


## Personnage amené à un niveau par l'XP (aptitudes et emplacements compris).
func _at_level(species: String, cls: String, level: int) -> Character:
	var ch := Character.create(species, cls, "Niv%d" % level)
	ch.add_xp(Progression.xp_for(level) - ch.xp)
	ch.complete_all_choices()
	return ch


func _test_backlash() -> bool:
	# Contrecoups (rules.json › backlash) : un tirage par dé à 10 de l'échec critique d'un sort.
	_expect(DB.rules["backlash"]["table"].size() == 10, "table des contrecoups : 10 lignes")
	Game.start_life(_at_level("human", "wizard", 3), 21)
	var combat := Game.start_combat({"enemies": ["wolf", "wolf"]})
	var hero := combat.hero
	var beats: Array[Dictionary] = []
	combat._begin_cast(Actions.def("fire_bolt"))
	combat._note_fumble(2)
	await combat._end_cast(hero, beats)
	_expect(beats.filter(func(b): return String(b["text"]).begins_with("Contrecoup")).size() == 2,
		"échec critique de degré 2 : deux contrecoups")
	beats.clear()
	combat._begin_cast(Actions.def("prepare"))
	combat._note_fumble(3)
	await combat._end_cast(hero, beats)
	_expect(beats.is_empty(), "pas de contrecoup hors d'un sort")
	await combat.backlash(hero, 1, beats, 1)
	_expect(combat.spec.has("weather"), "contrecoup 1 : la météo du combat change")
	# Lignes 6 à 10 : tout le monde, de plus en plus fort, avec un type de dégâts auquel on peut résister.
	var table: Array = DB.rules["backlash"]["table"]
	for face in range(6, 11):
		var effects: Array = table[face - 1]["effects"]
		_expect(effects.all(func(e): return e.get("who") == "all"), "contrecoup %d : frappe tout le monde" % face)
		_expect(face == 6 or int(effects[0].get("extra_dice", 0)) >= int(table[face - 2]["effects"][0].get("extra_dice", 0)),
			"contrecoup %d : au moins aussi fort que le précédent" % face)
	await combat.backlash(hero, 1, beats, 9)
	_expect(hero.stacks("poisoned") > 0 or not hero.is_alive(),
		"contrecoup 9 : le lanceur aussi est empoisonné")
	combat.hero.hp = combat.hero.max_hp()
	# Jet d'incantation : seulement pour un sort sans autre jet du lanceur.
	# Sorts de dégâts : attaques de sort contre le Couvert ; états : opposition ; les autres : jet d'incantation.
	_expect(["fire_bolt", "sleep", "magic_missile", "fireball", "burning_hands"].all(func(id): return Combat.has_caster_roll(Actions.def(id)))
		and not Combat.has_caster_roll(Actions.def("mage_shield")) and not Combat.has_caster_roll(Actions.def("find_familiar")),
		"jet d'incantation : seulement les sorts sans cible à toucher")
	_expect(combat.cast_chance(hero, Actions.def("mage_shield")) < 1.0 and combat.cast_chance(hero, Actions.def("prepare")) == 1.0,
		"jet d'incantation : Bouclier peut échouer, pas une action ordinaire")
	var failed := 0
	for i in 40:
		beats.clear()
		combat._begin_cast(Actions.def("mage_shield"))
		if not combat._cast_check(hero, Actions.def("mage_shield"), beats):
			failed += 1
		combat._casting_level = 0
		combat._cast_fumble = 0
	_expect(failed > 0 and failed < 40, "jet d'incantation : Bouclier réussit ou échoue")
	Game.combat = null
	return true


func _test_throw_and_shield() -> bool:
	# Lancer : arme de lancer telle quelle, le reste en arme improvisée (selon le poids).
	_expect(Combat.throw_weapon("dagger") == "dagger" and Combat.throw_weapon("shield") == "improvised_medium"
		and Combat.throw_weapon("halberd") == "improvised_large", "lancer : dague de lancer, bouclier et hallebarde improvisés")
	var thrower := Character.create("human", "fighter", "Lanceur")
	thrower.equipment["main_hand"] = "dagger"
	thrower.add_item("javelin", 2)
	Game.start_life(thrower, 21)
	var combat := Game.start_combat({"enemies": ["wolf"]})
	var hero := combat.hero
	var choices := combat.throwables(hero)
	_expect(choices[0]["id"] == "dagger" and choices[0]["slot"] == "main_hand"
		and choices.any(func(c): return c["id"] == "javelin" and c["count"] == 2), "lancer : arme en main et objets du sac")
	combat.actions_left = 2
	await combat.throw_item(hero, choices[0], combat.living("enemy")[0])
	_expect(thrower.weapon_id() == Equipment.UNARMED and combat.actions_left == 1 and combat.thrown.size() == 1,
		"lancer la dague : une action, la main est vide")
	await combat.throw_item(hero, combat.throwables(hero).filter(func(c): return c["id"] == "javelin")[0], combat.enemies()[0])
	_expect(thrower.item_count("javelin") == 1, "lancer un javelot : retiré du sac")
	combat.outcome = "victory"
	var result := Game.finish_combat()
	_expect(thrower.weapon_id() == "dagger" and thrower.item_count("javelin") == 2
		and result["lines"].any(func(l): return l.begins_with("Vous ramassez")), "victoire : les objets lancés sont ramassés")

	# Deux mains : chaque Attaque se fait au choix avec l'arme ou le bouclier ; on choisit aussi avec quoi parer.
	var knight := Character.create("human", "fighter", "Bouclier")
	knight.equipment["main_hand"] = "longsword"
	knight.equipment["off_hand"] = "shield"
	Game.start_life(knight, 21)
	combat = Game.start_combat({"enemies": ["dire_wolf"]})
	var variants := combat.hero.action_variants(Actions.def("weapon_attack"))
	_expect(variants.size() == 2 and variants[1]["effects"][0]["weapon"] == "shield"
		and combat.hero.off_hand_attack(variants[0]["effects"][0]).is_empty(), "coup de bouclier : une Attaque au choix, sans seconde attaque")
	_expect(combat.hero.parry_options() == ["longsword", "shield"] and combat.hero.parry_options(true) == ["shield"],
		"parade : l'épée ou le bouclier ; un tir, le bouclier seul")
	combat.hero.parry_choice = "longsword"
	_expect(combat.hero.parry_item() == "longsword" and combat.hero.parry_item(true) == "shield", "parade au choix du joueur")
	combat.hero.parry_choice = ""
	Game.combat = null
	return true


func _test_magic_shield_parry() -> bool:
	# Bouclier magique : un lanceur qui connaît le sort Bouclier peut parer avec, même un tir, par la
	# compétence d'incantation ; la parade coûte le mana du sort. Sans mana, il n'est plus proposé.
	var mage := _at_level("human", "wizard", 5)
	for entry: Dictionary in mage.choice_specs():
		if entry["spec"].get("id") == "spells":
			mage.choices[entry["key"]] = ["magic_missile", "mage_shield", "sleep"]
	mage.equip_spell("mage_shield")
	Game.start_life(mage, 21)
	var combat := Game.start_combat({"enemies": ["dire_wolf"]})
	var hero := combat.hero
	_expect(Combatant.MAGIC_SHIELD in hero.parry_options(true), "bouclier magique : il pare même un tir")
	hero.parry_choice = Combatant.MAGIC_SHIELD
	var pool := hero.parry_pool()
	_expect(pool["item"] == Combatant.MAGIC_SHIELD and pool["count"] == hero.spell_pool()["count"]
		and pool["threshold"] == hero.spell_threshold(), "bouclier magique : jet de Magie contre l'incantation")
	var wolf := combat.enemies()[0]
	var bite: Dictionary = wolf.creature["actions"][0]["effects"][0]
	var mana := int(Game.life.character.resources["spell_slot"])
	var beats: Array[Dictionary] = []
	hero.reactions = 1
	combat._parry(wolf, hero, bite, beats, true)
	_expect(hero.reactions == 0 and int(Game.life.character.resources["spell_slot"]) == mana - Spellcasting.cost_of(Actions.def("mage_shield")),
		"bouclier magique : une réaction et le mana du sort")
	Game.life.character.resources["spell_slot"] = 0
	_expect(Combatant.MAGIC_SHIELD not in hero.parry_options(true), "sans mana, pas de bouclier magique")
	hero.parry_choice = ""
	Game.combat = null
	return true


func _test_world_map() -> bool:
	# Carte : on va dans un lieu relié (on le découvre) ou déjà visité (téléportation) ; les liaisons valent
	# dans les deux sens ; les lieux visités sont sauvegardés.
	Game.start_life(Character.create("human", "fighter", "Carto"), 21)
	var life := Game.life
	life.location = "home"
	life.visited.assign(["home"])
	_expect(WorldMap.links_of("home") == ["town"] and "home" in WorldMap.links_of("town"), "liaisons dans les deux sens")
	_expect(WorldMap.can_travel(life, "town") and not WorldMap.can_travel(life, "forest") and not WorldMap.can_travel(life, "home"),
		"depuis chez soi : la ville voisine, pas la forêt (trop loin) ni le lieu actuel")
	WorldMap.travel(life, "town")
	WorldMap.travel(life, "forest")
	_expect(life.location == "forest" and WorldMap.can_travel(life, "home") and WorldMap.is_visited(life, "home"),
		"un lieu déjà visité est accessible de partout")
	_expect(WorldMap.is_safe("town") and not WorldMap.is_safe("forest"), "lieu sûr ou sauvage")
	_expect(LifeState.from_dict(life.to_dict()).visited == life.visited, "lieux visités sauvegardés")
	return true


func _test_lost_items_and_stock() -> bool:
	# Fiole lancée : elle se brise (pas rendue), son effet s'applique si elle touche.
	_expect(Items.splash_effects("flask_oil")[0]["status"] == "burning" and Items.splash_effects("potion_heal")[0]["type"] == "heal"
		and Items.splash_effects("dagger").is_empty(), "fioles : huile, potion ; une dague ne se brise pas")
	var hero_char := Character.create("human", "fighter", "Fioles")
	hero_char.add_item("flask_oil", 1)
	hero_char.add_item("javelin", 1)
	Game.start_life(hero_char, 21)
	Game.life.location = "forest"
	var combat := Game.start_combat({"enemies": ["wolf"]})
	combat.actions_left = 2
	var oil: Dictionary = combat.throwables(combat.hero).filter(func(c): return c["id"] == "flask_oil")[0]
	var wolf_hp := combat.living("enemy")[0].hp
	var beats: Array[Dictionary] = await combat.throw_item(combat.hero, oil, combat.living("enemy")[0])
	_expect(combat.thrown.is_empty() and beats.any(func(b): return String(b["text"]).ends_with("se brise.")),
		"fiole lancée : elle se brise")
	_expect(combat.enemies()[0].hp == wolf_hp, "fiole lancée : pas de dégâts, seulement son effet")
	await combat.throw_item(combat.hero, combat.throwables(combat.hero).filter(func(c): return c["id"] == "javelin")[0],
		combat.enemies()[0])
	combat.outcome = "fled"
	Game.finish_combat()
	_expect(Game.life.lost_items.get("forest", {}).get("javelin", 0) == 1 and hero_char.item_count("javelin") == 0,
		"fuite : le javelot reste dans la forêt")
	var ev := EventEngine.gather_event("forest", null, Game.life)
	var search: Dictionary = ev["choices"][0]
	_expect(search["id"] == "lost", "récolte : fouiller les lieux d'un combat")
	EventEngine.resolve_choice(ev, search, Game.life, Meta, {"success": true, "critical": 0, "fumble": false})
	_expect(hero_char.item_count("javelin") == 1 and not Game.life.lost_items.has("forest"), "objet perdu retrouvé et retiré de la liste")
	_expect(EventEngine.gather_event("town", null, Game.life).is_empty(), "rien à fouiller en ville")
	# Stock de la semaine : 6 herbes, puis épuisé ; il repousse au début de la semaine suivante.
	ev = EventEngine.gather_event("forest", null, Game.life)
	var herbs: Dictionary = ev["choices"].filter(func(c): return c["id"] == "herbs")[0]
	for i in 4:
		EventEngine.resolve_choice(ev, herbs, Game.life, Meta, {"success": true, "critical": 1, "fumble": false})
	_expect(hero_char.item_count("healing_herbs") == 6 and Game.life.gather_left("forest", DB.locations["forest"]["gather"][0]) == 0,
		"récolte : pas plus que le stock de la semaine")
	herbs = EventEngine.gather_event("forest", null, Game.life)["choices"].filter(func(c): return c["id"] == "herbs")[0]
	_expect(not herbs.has("check"), "récolte épuisée : plus de test")
	var copy := LifeState.from_dict(JSON.parse_string(JSON.stringify(Game.life.to_dict())))
	_expect(copy.gather_left("forest", DB.locations["forest"]["gather"][0]) == 0, "sauvegarde : récoltes de la semaine")
	while Game.life.day < 8:
		Game.life.advance_time(DB.slots_per_day())
	_expect(Game.life.gather_left("forest", DB.locations["forest"]["gather"][0]) == 6, "nouvelle semaine : les herbes ont repoussé")
	# Armes improvisées équipables : Bagarreur de taverne ajoute un dé.
	var brawler := Character.create("human", "fighter", "Bagarreur")
	brawler.equipment["main_hand"] = "big_sausage"
	Game.start_life(brawler, 21)
	combat = Game.start_combat({"enemies": ["wolf"]})
	var attack: Dictionary = Actions.def("weapon_attack")["effects"][0]
	var before := int(combat.hero.damage_pool(attack, combat.hero.attack_pool(attack))["count"])
	brawler.feats.append("tavern_brawler")
	_expect(Equipment.has_property("big_sausage", "improvised")
		and int(combat.hero.damage_pool(attack, combat.hero.attack_pool(attack))["count"]) == before + 1,
		"arme improvisée : +1 dé avec Bagarreur de taverne")
	# Créatures équipées : Armure de l'armure portée, parade avec l'arme, encombrement, butin.
	combat = Game.start_combat({"enemies": ["bandit"]})
	var bandit := combat.enemies()[0]
	_expect(bandit.armor() == Equipment.armor_value("leather") and bandit.parry_item() == "shortsword"
		and bandit.creature_encumbrance() == 0, "brigand : armure de cuir, épée courte (à deux mains), pas encombré")
	bandit.creature = bandit.creature.duplicate(true)
	bandit.creature["equipment"]["armor"] = "chain_mail"
	var heavy := ceili(Equipment.weight_of("chain_mail") + Equipment.weight_of("shortsword", true) - 4 - 5)
	_expect(bandit.creature_encumbrance() == heavy and bandit.ability_score("dex") == maxi(0, 5 - heavy),
		"brigand en cotte de mailles : encombré, DEX réduite")
	var drops := 0
	for i in 20:
		combat = Game.start_combat({"enemies": ["bandit"]})
		combat.outcome = "victory"
		var lines: Array = Game.finish_combat()["lines"]
		drops += lines.filter(func(l): return l == "Butin : Épée courte ×1" or l == "Butin : Armure de cuir ×1").size()
	_expect(drops > 0 and drops < 40, "brigand : son équipement tombe parfois en butin")
	Game.combat = null
	# Ennemis enfuis : ils reviendront peut-être, avec du renfort ; leur camp est sur ses gardes.
	Game.life.location = "forest"
	combat = Game.start_combat({"enemies": ["bandit", "wolf"]})
	combat.enemies()[0].fled = true
	combat.outcome = "victory"
	Game.finish_combat()
	_expect(Game.life.revenge.size() == 1 and Game.life.revenge[0]["enemies"] == ["bandit", "bandit"]
		and Game.life.is_warned("bandits"), "brigand enfui : retour possible avec un renfort, camp prévenu")
	_expect(EventEngine.revenge_event("forest", Game.life).is_empty(), "pas de retour le jour même")
	Game.life.day += 1
	var back := {}
	for i in 30:
		back = EventEngine.revenge_event("forest", Game.life)
		if not back.is_empty():
			break
	_expect(not back.is_empty() and back["choices"][0]["outcome"]["effects"][0]["enemies"] == ["bandit", "bandit"]
		and Game.life.revenge.is_empty(), "les fuyards reviennent une fois")
	combat = Game.start_combat({"enemies": ["bandit", "bandit", "bandit_mender"], "group": "bandits"})
	_expect(combat.enemies().size() == 4 and combat.enemies().all(func(e): return e.is_prepared()),
		"camp prévenu : un brigand de plus, tous préparés")
	Game.life.day += 8
	combat = Game.start_combat({"enemies": ["bandit", "bandit", "bandit_mender"], "group": "bandits"})
	_expect(combat.enemies().size() == 3, "le camp oublie au bout d'une semaine")
	var copy2 := LifeState.from_dict(JSON.parse_string(JSON.stringify(Game.life.to_dict())))
	_expect(copy2.warned.has("bandits"), "sauvegarde : groupes prévenus")
	Game.combat = null
	# Munitions spéciales : une variante d'Attaque par sorte de flèche, avec ses dégâts en plus.
	var archer := Character.create("human", "fighter", "Archère")
	archer.equipment["main_hand"] = "longbow"
	archer.equipment.erase("off_hand")
	archer.add_item("fire_arrow", 1)
	Game.start_life(archer, 21)
	combat = Game.start_combat({"enemies": ["dire_wolf"]})
	var shots := combat.hero.action_variants(Actions.def("weapon_attack")).filter(func(v): return v["effects"][0].has("ammo"))
	_expect(shots.size() == 1 and combat.hero.bonus_damage(shots[0]["effects"][0]).any(func(p): return p["damage_type"] == "fire"),
		"flèche de feu : variante d'attaque avec dégâts de feu")
	combat.actions_left = 2
	await combat.perform(combat.hero, shots[0], combat.living("enemy")[0])
	_expect(archer.item_count("fire_arrow") == 0, "flèche de feu : consommée au tir")
	Game.combat = null
	return true


func _test_spell_progression() -> bool:
	_expect(Spellcasting.slots("full", 1) == {"spell_slot": 2} and Spellcasting.slots("full", 5) == {"spell_slot": 10},
		"mana : niveau de lanceur × 2")
	_expect(Spellcasting.slots("half", 1).is_empty() and Spellcasting.slots("half", 5) == {"spell_slot": 4},
		"demi-lanceur : rien au niveau 1")
	_expect(Spellcasting.max_level("full", 5) == 3 and Spellcasting.max_level("full", 20) == 9 and Spellcasting.max_level("half", 1) == 0,
		"niveau de sort le plus haut selon la table")
	_expect(Spellcasting.cost_of({"spell_level": 2}) == 2 and Spellcasting.cost_of({"spell_level": 1, "slot_level": 3}) == 3,
		"un sort de niveau N coûte N emplacements")

	var mage := Character.create("goblin", "wizard", "Mage")
	mage.resources["spell_slot"] = 0
	mage.add_xp(Progression.xp_for(3) - mage.xp)
	_level_up(mage)
	_expect(mage.resources["spell_slot"] == 4, "montée de niveau : les emplacements gagnés sont disponibles, les dépensés le restent")
	mage.long_rest()
	_expect(mage.resources == {"spell_slot": 6} and mage.max_spell_level() == 2, "repos long : tous les emplacements")
	_expect(ClassFeatures.announce(mage, 3).size() == 2, "annonce : nouvelle aptitude (tradition) et emplacements")

	var old := Character.from_dict({"species_id": "goblin", "class_id": "wizard", "level": 1,
		"resources": {"spell_slot_1": 1, "spell_slot_2": 1}})
	_expect(old.resources == {"spell_slot": 3}, "ancienne sauvegarde : emplacements par niveau convertis")

	# Sorts connus et équipés : seuls les sorts équipés sont proposés en combat.
	var wizard := Character.create("human", "wizard", "W")
	var known := wizard.known_spells()
	_expect(known.size() == 5 and "weapon_attack" not in known and wizard.max_equipped_spells() == 2 + wizard.skill_rank(Skills.SPELL),
		"magicien : 2 tours de magie et 3 sorts choisis à la création ; 2 + rang de Magie équipés")
	_expect(wizard.equipped_spells.size() == 3 and "find_familiar" not in wizard.combat_actions()
		and "weapon_attack" in wizard.combat_actions(), "les sorts choisis sont équipés d'office")
	_expect("fire_bolt" not in wizard.equipped_spells and wizard.is_spell_equipped("fire_bolt") and "ray_of_frost" in wizard.combat_actions()
		and not wizard.equip_spell("fire_bolt") and not wizard.unequip_spell("fire_bolt"), "tours de magie : toujours prêts, hors limite")
	_expect(wizard.unequip_spell("sleep") and "sleep" not in wizard.combat_actions() and wizard.equip_spell("sleep")
		and "sleep" in wizard.combat_actions(), "changer de sort équipé")
	_expect(not wizard.equip_spell("find_familiar"), "on n'équipe qu'un sort connu")
	# Plus de sort appris en montant de niveau (ancienne progression retirée, tableur des classes).
	var apprentice := Character.create("human", "wizard", "A")
	apprentice.add_xp(300)
	_level_up(apprentice)
	_expect(ClassFeatures.at_level("wizard", 2).is_empty() and apprentice.known_spells().size() == 5, "niveau 2 : pas de nouveau sort")
	var reloaded := Character.from_dict(JSON.parse_string(JSON.stringify(wizard.to_dict())))
	_expect(reloaded.equipped_spells == wizard.equipped_spells, "sorts équipés sauvegardés")

	# Tours de magie : un dé de dégâts de plus par palier ; sorts lancés à un niveau supérieur.
	var hero := Combatant.from_character(Character.create("human", "wizard", "W"), true)
	var bolt: Dictionary = Actions.def("fire_bolt")["effects"][0]
	_expect(hero.damage_pool(bolt, hero.attack_pool(bolt))["count"] == 6, "Trait de feu : 6 dés au niveau 1")
	hero.character.level = 5
	_expect(hero.damage_pool(bolt, hero.attack_pool(bolt))["count"] == 7, "Trait de feu : +1 dé au niveau 5")
	hero.character.level = 17
	_expect(hero.damage_pool(bolt, hero.attack_pool(bolt))["count"] == 9, "Trait de feu : +3 dés au niveau 17")

	var evoker := _at_level("human", "wizard", 5)
	evoker.unequip_spell("mage_shield")
	Game.start_life(evoker, 21)
	var combat := Game.start_combat({"enemies": ["dire_wolf"]})
	var missiles := combat.action_choices(combat.hero).filter(func(c): return c["action"]["id"] == "magic_missile")
	_expect(missiles.size() == 3, "Projectile magique proposé aux niveaux 1, 2 et 3")
	var high: Dictionary = missiles[2]["action"]
	_expect(high["name"] == "Projectile magique (niv. 3)" and high["effects"][0]["damage"]["dice"] == 11,
		"niveau 3 : quatre dés de plus")
	_expect(Actions.def("magic_missile")["effects"][0]["damage"]["dice"] == 7, "l'action de base n'est pas modifiée")
	await combat.perform(combat.hero, high, combat.living("enemy")[0])
	_expect(Game.life.character.resources["spell_slot"] == Game.life.character.max_resource("spell_slot") - 3, "lancé au niveau 3 : 3 emplacements dépensés")
	Game.combat = null

	# Parchemin : le sort part une fois, avec la compétence Langues, sans emplacement ; il débloque le Magicien.
	var backup := Meta.to_dict()
	Meta.unlocks.erase("class:wizard")
	var reader := Character.create("human", "fighter", "Lecteur")
	reader.add_item("scroll_fire_bolt")
	Game.start_life(reader, 22)
	combat = Game.start_combat({"enemies": ["dire_wolf"]})
	var reader_c := combat.hero
	reader.spell_override = "languages"
	_expect(reader_c.attack_pool(bolt)["count"] == reader.skill_rank("languages")
		and reader_c.attack_pool(bolt)["ability"] == reader.best_skill_ability("languages"), "parchemin : Langues et son meilleur attribut")
	reader.spell_override = ""
	combat.turn = combat.order.find(reader_c)
	combat.start_turn()
	_expect(combat.usable_items().any(func(i): return i["item"]["id"] == "scroll_fire_bolt"), "parchemin utilisable en combat")
	await combat.use_item(reader_c, "scroll_fire_bolt", combat.living("enemy")[0])
	_expect(reader.item_count("scroll_fire_bolt") == 0 and reader.spell_override == "" and combat.actions_left == 1
		and Meta.is_class_available("wizard"), "parchemin lu : consommé, une action, Magicien débloqué")
	Game.combat = null
	Meta.load_dict(backup)
	return true


func _test_class_features() -> bool:
	DB.creatures["_target"] = {"id": "_target", "name": "Cible", "hp": 200, "abilities": {"int": 8, "dex": 10},
		"skills": {"lore": 40, "physique": 40},
		"actions": [{"name": "Rien", "weight": 1, "target": "self", "effects": [{"type": "status", "status": "shielded", "stacks": 0}]}]}

	# Résister : un simple test de la compétence liée à l'attribut (pas de maîtrise de classe).
	var fighter := Character.create("human", "fighter", "G")
	_expect(not fighter.is_proficient_save("con")
		and fighter.resist_pool("con") == {"count": fighter.skill_rank("physique"), "threshold": fighter.ability_score("con"), "ability": "con"}
		and fighter.resist_pool("wis")["count"] == fighter.skill_rank("determination"), "résister : Physique, Détermination pour SAG")
	var check := {"resist": "con", "difficulty": 1}
	_expect(Dice.check_pool(fighter, check) == fighter.resist_pool("con") and Dice.stat_name(check) == "Résister (Constitution)",
		"test de résistance dans un événement")

	# Ancienne progression du SRD (Fougue, Attaque supplémentaire, Inflexible, Attaque sournoise, Esquive
	# instinctive, Dérobade, Talent fiable) : retirée des classes, mais ses mécaniques restent pour de futurs dons.
	DB.feats["_legacy"] = {"id": "_legacy", "name": "Ancienne progression", "category": "general", "description": "Test.",
		"actions": ["action_surge", "sneak_attack"], "resources": {"indomitable": 1},
		"modifiers": [{"type": "extra_attack", "amount": 1}, {"type": "uncanny_dodge"}, {"type": "evasion"}, {"type": "reliable_talent"}]}
	var veteran := _at_level("human", "fighter", 9)
	veteran.add_feat("_legacy")
	veteran.long_rest()
	Game.start_life(veteran, 31)
	var combat := Game.start_combat({"enemies": ["_target"]})
	var hero := combat.hero
	combat.turn = combat.order.find(hero)
	combat.start_turn()
	await combat.perform(hero, Actions.def("action_surge"))
	_expect(combat.actions_left == 3 and combat.can_act_again(), "Fougue : une action de plus, sans coûter la sienne")
	var before := combat.log.size()
	await combat.perform(hero, Actions.def("weapon_attack"), combat.enemies()[0])
	_expect(combat.log.slice(before).count("Niv9 : attaque supplémentaire.") == 1, "Attaque supplémentaire : deux coups au niveau 9")
	_expect(combat.actions_left == 2, "il reste deux actions")
	var beats: Array[Dictionary] = []
	_expect(Game.life.character.resources["indomitable"] == 1, "Inflexible : 1 utilisation")
	combat._resists(combat.enemies()[0], hero, {"ability": "dex"}, beats, true)
	_expect(Game.life.character.resources["indomitable"] == 0 and beats.size() == 2, "Inflexible : relance une résistance ratée")
	Game.combat = null

	# Roublard : Attaques précises ; puis les mécaniques de l'ancienne progression.
	var rogue := _at_level("goblin", "rogue", 11)
	_expect(Combatant.from_character(rogue, true).critical_damage_dice() == 3
		and Combatant.from_character(fighter, true).critical_damage_dice() == 0, "Attaques précises : 3 dés de plus sur un critique")

	rogue.add_feat("_legacy")
	var sneak := Combatant.from_character(rogue, true)
	var sneak_effect: Dictionary = Actions.def("sneak_attack")["effects"][0]
	var attack := sneak.attack_pool(sneak_effect)
	var plain_dice: int = sneak.damage_pool({"type": "attack", "weapon": true}, attack)["count"]
	_expect(sneak.damage_pool(sneak_effect, attack)["count"] == plain_dice + 6, "Attaque sournoise : 6 dés de plus au niveau 11")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var fewest := 99
	for i in 40:
		fewest = mini(fewest, Dice.roll_check(rogue, {"skill": "stealth", "difficulty": 30}, rng)["successes"])
	_expect(fewest >= 1, "Talent fiable : toujours au moins un succès")

	Game.start_life(rogue, 41)
	combat = Game.start_combat({"enemies": ["_target"]})
	hero = combat.hero
	var target := combat.enemies()[0]
	hero.character.max_hp = 200
	hero.hp = 200
	before = combat.log.size()
	await combat._roll_damage(target, hero, {"count": 12, "threshold": 8}, "", 0, beats, {"from_attack": true})
	await combat._roll_damage(target, hero, {"count": 12, "threshold": 8}, "", 0, beats, {"from_attack": true})
	_expect(combat.log.slice(before).filter(func(l): return "esquive instinctive" in l).size() == 1,
		"Esquive instinctive : la première attaque du round est divisée par deux")
	hero.character.abilities["dex"] = 10
	var hp := hero.hp
	await combat._apply(target, {"type": "damage", "damage": {"dice": 1, "threshold": 1}, "resist": {"ability": "dex"}}, hero, true)
	_expect(hero.hp == hp, "Dérobade : chaque succès de résistance (DEX) retire deux points")
	Game.combat = null

	# Résister à un sort : chaque succès retire un point de dégâts ; repoussé, l'état qui suit est évité.
	Game.start_life(_at_level("human", "wizard", 1), 51)
	combat = Game.start_combat({"enemies": ["_target"]})
	target = combat.enemies()[0]
	hp = target.hp
	await combat._resolve(combat.hero, [{"type": "damage", "damage": {"dice": 1, "threshold": 1}, "damage_type": "fire", "resist": {"ability": "dex"}},
		{"type": "status", "status": "burning", "stacks": 1}], "enemy", target, true)
	_expect(hp == target.hp and target.stacks("burning") == 0, "résisté : aucun dégât et pas d'état")
	Game.combat = null
	DB.creatures.erase("_target")
	DB.feats.erase("_legacy")
	return true


func _test_inventory() -> bool:
	_expect(Items.name_of("potion_heal") == "Potion de soins" and Items.name_of("longsword_plus_1") == "Épée longue +1",
		"Items : objets et équipement au même endroit")
	_expect(Items.is_equipment("ring_of_protection") and not Items.is_equipment("potion_heal")
		and Items.is_usable_outside_combat("potion_heal") and not Items.is_usable_outside_combat("antidote"), "Items : catégories")
	_expect(Equipment.slot_for("amulet_vigor") == "neck" and Equipment.slots_for("ring_fire_resistance") == ["ring_1", "ring_2"]
		and Equipment.slot_for("elven_boots") == "feet", "accessoires : leur emplacement")

	Game.start_life(Character.create("human", "fighter", "Porteur"), 61)
	var life := Game.life
	var hero := life.character
	var combatant := Combatant.from_character(hero, true)
	var weapon_effect: Dictionary = Actions.def("weapon_attack")["effects"][0]
	var attack := combatant.attack_pool(weapon_effect)
	var damage := combatant.damage_pool(weapon_effect, attack)
	var damage_dice: int = damage["count"]
	hero.add_item("longsword_plus_1")
	_expect(life.equip(hero, "longsword_plus_1") and hero.weapon_id() == "longsword_plus_1"
		and hero.item_count("longsword") == 1 and hero.item_count("longsword_plus_1") == 0,
		"équiper depuis le sac : l'ancienne arme retourne dans le sac")
	_expect(combatant.attack_pool(weapon_effect)["count"] == int(attack["count"]) + 1
		and combatant.damage_pool(weapon_effect, attack)["count"] == damage_dice + 1,
		"arme +1 : un dé au toucher et un dé de dégâts")

	hero.add_item("shield")
	hero.add_item("greataxe")
	hero.add_item("longbow")
	life.equip(hero, "shield")
	life.equip(hero, "longbow")
	_expect(hero.item_count("shield") == 1 and hero.item_count("longsword_plus_1") == 1 and not hero.equipment.has("off_hand"),
		"arme à deux mains : bouclier et ancienne arme retournent dans le sac")
	_expect(not life.equip(hero, "plate"), "impossible d'équiper un objet absent du sac")

	var ac := hero.armor()
	var save: int = hero.resist_pool("dex")["count"]
	hero.add_item("ring_of_protection")
	life.equip(hero, "ring_of_protection")
	_expect(hero.armor() == ac + 1 and hero.resist_pool("dex")["count"] == save + 1 and hero.equipment["ring_1"] == "ring_of_protection",
		"Anneau de protection : +1 Armure et un dé pour résister")
	hero.add_item("ring_fire_resistance")
	life.equip(hero, "ring_fire_resistance")
	_expect(hero.equipment["ring_2"] == "ring_fire_resistance" and hero.all_defenses().has(Defenses.RESISTANCE, "fire"),
		"deuxième anneau : second emplacement, résistance au feu")
	hero.add_item("ring_of_protection")
	life.equip(hero, "ring_of_protection")
	_expect(hero.item_count("ring_of_protection") == 1 and hero.equipment["ring_1"] == "ring_of_protection",
		"troisième anneau : il remplace le premier")
	_expect(life.unequip(hero, "ring_1") and hero.armor() == ac and hero.item_count("ring_of_protection") == 2,
		"retirer : l'objet retourne dans le sac")
	var hp := hero.max_hp
	hero.add_item("amulet_vigor")
	life.equip(hero, "amulet_vigor")
	_expect(hero.max_hp == hp + 2, "amulette de vigueur : +2 PV")

	# Compagnon : il puise dans le sac du héros.
	var mira := Character.create_companion("mira")
	life.companions.append(mira)
	hero.add_item("dagger_plus_1")
	_expect(life.equip(mira, "dagger_plus_1") and mira.weapon_id() == "dagger_plus_1" and hero.item_count("dagger_plus_1") == 0,
		"un compagnon s'équipe depuis le sac du groupe")

	# Utiliser et jeter.
	hero.hp = 1
	hero.add_item("potion_heal")
	var potions := hero.item_count("potion_heal")
	_expect(life.use_item("potion_heal", hero) != "" and hero.hp > 1 and hero.item_count("potion_heal") == potions - 1,
		"potion bue hors combat")
	_expect(life.use_item("antidote", hero) == "", "antidote : inutile hors combat")
	_expect(life.drop_item("longbow") == 0 and life.drop_item("shield") == 1 and hero.item_count("shield") == 0, "jeter")

	# Fenêtre d'inventaire.
	var view := InventoryView.new(life)
	add_child(view)
	_expect(view._bag_box.get_child_count() == hero.inventory.size(), "fenêtre : une ligne par objet du sac")
	view.select_member(mira)
	view._on_unequip("main_hand")
	_expect(mira.weapon_id() == Equipment.UNARMED and hero.item_count("dagger_plus_1") == 1, "fenêtre : retirer l'arme de Mira")
	view._on_equip("dagger_plus_1")
	_expect(mira.weapon_id() == "dagger_plus_1", "fenêtre : rééquiper Mira")
	view.close_view()

	var saved := Character.from_dict(JSON.parse_string(JSON.stringify(hero.to_dict())))
	_expect(saved.equipment["ring_2"] == "ring_fire_resistance" and saved.equipment["neck"] == "amulet_vigor",
		"sauvegarde : accessoires équipés")
	var old := Character.from_dict({"species_id": "human", "class_id": "fighter", "equipment": {"amulet": "amulet_vigor",
		"ring": "ring_fire_resistance"}})
	_expect(old.equipment == {"neck": "amulet_vigor", "ring_1": "ring_fire_resistance"}, "anciennes sauvegardes : emplacements convertis")

	# Filtres et recherche de l'inventaire.
	_expect(Items.matches("potion_heal", "consumable") and not Items.matches("potion_heal", "equipment")
		and Items.matches("longsword", "equipment", "épée") and not Items.matches("longsword", "all", "potion"), "filtres et recherche")
	Game.combat = null
	return true


func _test_encumbrance() -> bool:
	var weak := {"str": 3, "dex": 6, "con": 5, "int": 4, "wis": 5, "cha": 5}
	var fighter := Character.create("goblin", "fighter", "Fluet", {"abilities": weak})
	# Mailles 10 + épée longue à deux mains 3 − FOR 3 − CON 5 + taille (−1) × 2 = 3.
	_expect(fighter.equipment["armor"] == "chain_mail" and fighter.equipped_weight() == 13.0 and fighter.encumbrance() == 3,
		"encombrement : poids porté − FOR − CON + taille × 2")
	_expect(fighter.ability_score("dex") == 3 and fighter.initiative_base() == 3 + 4 and fighter.natural_dodge() == 1,
		"encombré : DEX −3 (initiative, Esquive naturelle)")
	_expect(fighter.attack_pool("weapon")["ability"] == "dex" and fighter.attack_pool("weapon")["threshold"] == 3,
		"attaque contre la DEX, encombrement compris")
	_expect(fighter.encumbrance_reason("plate") == "Encombrement 7 : DEX −7" and fighter.encumbrance_reason("robe") == ""
		and fighter.equipment["armor"] == "chain_mail", "ce que coûterait une armure (sans l'équiper)")
	fighter.equip("shield")  # bouclier 3, et l'épée passe à une main (4)
	_expect(fighter.encumbrance() == 7, "bouclier : son poids, et l'épée tenue à une main pèse plus")
	fighter.unequip("armor")
	fighter.unequip("off_hand")
	_expect(fighter.encumbrance() == 0 and fighter.ability_score("dex") == 6, "sans armure : plus encombré")
	DB.species["goblin"]["natural_armor"] = 1
	fighter.equip("chain_mail")
	_expect(fighter.encumbrance() == 5 and fighter.armor() == 4, "armure naturelle : +1 Armure, +2 d'encombrement")
	DB.species["goblin"].erase("natural_armor")
	fighter.equip("plate")
	_expect(fighter.encumbrance() == 7 and fighter.ability_score("dex") == 0, "trop encombré : DEX 0")

	Game.start_life(fighter, 71)
	var combat := Game.start_combat({"enemies": ["wolf"]})
	combat.turn = combat.order.find(combat.hero)
	var beats := combat.start_turn()
	_expect(combat.skipped and beats.any(func(b): return b["text"].contains("Dextérité 0")), "DEX 0 : on ne peut plus agir")
	Game.combat = null
	fighter.add_feat("heavy_armor_training")
	_expect(fighter.encumbrance() == 5, "Entraînement aux armures lourdes : encombrement −2")
	return true


func _test_weapon_properties() -> bool:
	DB.creatures["_swordsman"] = {"id": "_swordsman", "name": "Bretteur", "hp": 500, "abilities": {"str": 5, "dex": 5},
		"skills": {"weapon_melee": 4},
		"actions": [{"name": "Taille", "weight": 1, "target": "enemy", "effects": [{"type": "attack", "weapon": "longsword"}]}]}
	Game.start_life(Character.create("human", "fighter", "Garde"), 5)
	var combat := Game.start_combat({"enemies": ["_swordsman", "wolf"]})
	var hero := combat.hero
	var sword := combat.enemies()[0]
	var wolf := combat.enemies()[1]
	var cut: Dictionary = sword.creature["actions"][0]["effects"][0]
	var bite: Dictionary = wolf.creature["actions"][0]["effects"][0]
	_expect(sword.damage_pool(cut, sword.attack_pool(cut))["count"] == 7 and wolf.damage_pool(bite, wolf.attack_pool(bite))["count"] == 5,
		"dégâts : les dés de l'arme (ou des crocs), sans le rang")
	_expect(sword.attack_pool(cut)["threshold"] == 5 and sword.attack_pool(cut)["ability"] == "dex", "attaque : contre la DEX")

	# Parade : seuil de l'objet qui pare (bâton à deux mains 5, bouclier 4), −1 contre une arme à impact.
	var ch := hero.character
	ch.equip("quarterstaff")
	_expect(hero.parry_pool()["threshold"] == 5 and hero.parry_pool(0, false, true)["threshold"] == 4, "bâton à deux mains : parade 5 (4 contre une hache)")
	ch.equip("shield")
	_expect(hero.parry_pool()["item"] == "shield" and hero.parry_pool()["threshold"] == 4 and hero.parry_pool(0, true)["item"] == "shield",
		"bouclier : parade 4, même contre un tir")
	ch.unequip("off_hand")
	ch.equip("longbow")
	hero.reactions = 1
	_expect(not combat.can_parry(sword, hero, cut), "un arc ne pare pas")

	# Parade dangereuse : à mains nues contre une épée, 1 PV perdu par 10 ; contre des crocs, aucun risque.
	ch.unequip("main_hand")
	ch.max_hp = 999
	hero.hp = 999
	var hurt := false
	var beats: Array[Dictionary] = []
	for i in 40:
		hero.reactions = 1
		hero.parries_used = 0
		combat._parry(wolf, hero, bite, beats, true)
	_expect(hero.hp == 999 and not beats.any(func(b): return b["text"].contains("Parade dangereuse")), "mains nues contre des crocs : sans risque")
	for i in 40:
		hero.reactions = 1
		hero.parries_used = 0
		combat._parry(sword, hero, cut, beats, true)
	hurt = beats.any(func(b): return b["text"].contains("Parade dangereuse"))
	_expect(hurt and hero.hp < 999, "mains nues contre une épée : parade dangereuse")

	# Perçante : dégâts en plus sur un critique.
	var before := wolf.hp
	wolf.hp = 999
	await combat._roll_damage(hero, wolf, {"count": 1, "threshold": 1}, "piercing", 0, beats, {"extra": 3})
	_expect(999 - wolf.hp >= 3, "Perçante : +3 dégâts")
	wolf.hp = before

	# Imprévisible : l'arme improvisée se brise sur un 10 au jet d'attaque.
	ch.equip("improvised_medium")
	hero.hp = hero.max_hp()
	var broken := false
	for i in 60:
		hero.reactions = 0
		sword.reactions = 0
		await combat._attack(hero, sword, {"type": "attack", "weapon": true}, beats, true)
		if ch.weapon_id() == Equipment.UNARMED:
			broken = true
			break
	_expect(broken and beats.any(func(b): return b["text"].contains("se brise")), "Imprévisible : l'arme se brise")

	# Recharge : arbalète légère R2, −1 si l'on a la force de la tenir à une main.
	ch.equip("light_crossbow")
	var attack := Actions.def("weapon_attack")
	var reload := Actions.def(Combatant.RELOAD_ACTION)
	_expect(hero.combat_actions().any(func(a): return a.get("id") == "reload") and hero.unavailable_reason(reload) == "arme chargée",
		"action Recharger, inutile tant que l'arme est chargée")
	var expected := 1 if ch.ability_score("str") >= 5 else 2
	hero.hp = hero.max_hp()
	combat.turn = combat.order.find(hero)
	combat.start_turn()
	combat.actions_left = 5
	await combat.perform(hero, attack, sword)
	_expect(hero.reload_left == expected and hero.unavailable_reason(attack) == "arme à recharger", "après un tir : à recharger")
	for i in expected:
		await combat.perform(hero, reload)
	_expect(hero.reload_left == 0 and hero.unavailable_reason(attack) == "", "rechargée : on peut tirer de nouveau")
	DB.creatures.erase("_swordsman")
	Game.combat = null
	return true


func _test_new_species() -> bool:
	var human := Character.create("human", "wizard", "H")
	_expect(human.pending_choice().get("key") == "species/versatile"
		and human.choice_options("species/versatile").all(func(id): return Feats.category_of(id) == "origin"),
		"humain : un don d'origine en plus à choisir")
	var dwarf := Character.create("dwarf", "fighter", "N")
	_expect(dwarf.age_years() == 50 and dwarf.all_defenses().has(Defenses.RESISTANCE, "poison"), "nain : 50 ans, résistance au poison")
	_expect(Character.create("tiefling", "wizard", "T").all_defenses().has(Defenses.RESISTANCE, "fire"), "tieffelin : résistance au feu")

	var orc := Character.create("orc", "fighter", "O")
	_expect(orc.resources.get("relentless_endurance", 0) == 1, "orc : Endurance implacable (1 par repos long)")
	Game.start_life(orc, 81)
	var combat := Game.start_combat({"enemies": ["wolf"]})
	combat._deal_damage(combat.enemies()[0], combat.hero, 999, "piercing", false, "")
	_expect(combat.hero.hp == 1 and not Game.life.dead and orc.resources["relentless_endurance"] == 0, "Endurance implacable : reste à 1 PV")
	combat._deal_damage(combat.enemies()[0], combat.hero, 999, "piercing", false, "")
	combat._check_end()
	_expect(Game.life.dead, "la deuxième fois, il tombe (seul : mort)")
	Game.combat = null

	for species_id in ["dwarf", "orc", "tiefling"]:
		var img := PixelArt.portrait(DB.species[species_id]["art"], DB.classes["fighter"]["art"], "adult", 3)
		_expect(img.get_width() > 0, "portrait : %s" % species_id)
	return true


func _test_damage_types() -> bool:
	DB.creatures["_target"] = {"id": "_target", "name": "Cible", "hp": 200,
		"actions": [{"name": "Rien", "weight": 1, "target": "self", "effects": [{"type": "status", "status": "shielded", "stacks": 0}]}]}
	_expect(Equipment.describe("flame_tongue").begins_with("Langue de feu — tranchant, 7d10, seuil FOR + feu 2d10 ≤ 5"),
		"arme à deux types de dégâts")

	# Une attaque peut infliger plusieurs types de dégâts, lancés séparément.
	var hero_ch := Character.create("human", "fighter", "Ardent")
	hero_ch.equipment["main_hand"] = "flame_tongue"
	Game.start_life(hero_ch, 91)
	var combat := Game.start_combat({"enemies": ["_target"]})
	var target := combat.enemies()[0]
	target.creature["defenses"] = {"immunities": ["fire"]}
	var before := combat.log.size()
	var beats: Array[Dictionary] = []
	var weapon := {"type": "attack", "weapon": true}
	await combat._hit(combat.hero, target, weapon, combat.hero.attack_pool(weapon), 0, false, false, beats, true)
	var lines := combat.log.slice(before)
	_expect(lines.any(func(l): return "tranchant" in l) and lines.any(func(l): return "feu[/color] (immunité)" in l),
		"tranchant puis feu, chacun avec ses défenses")

	# Le feu peut enflammer (chance réglée dans damage_types.json).
	target.creature["defenses"] = {}
	var backup: Dictionary = DB.damage_types["fire"]["status"]
	DB.damage_types["fire"]["status"] = {"id": "burning", "chance": 1.0, "stacks": 1}
	await combat._roll_damage(combat.hero, target, {"count": 6, "threshold": 8}, "fire", 0, beats)
	_expect(target.stacks("burning") == 1, "dégât de feu : la cible s'enflamme")
	DB.damage_types["fire"]["status"] = backup

	# Le poison est un vrai type : 1 dégât par tour, que la résistance divise (arrondi à l'inférieur).
	target.statuses.clear()
	target.add_status("poisoned", 4)
	var hp := target.hp
	combat.turn = combat.order.find(target)
	combat.start_turn()
	_expect(hp - target.hp == 1 and target.stacks("poisoned") == 3, "état Poison : 1 dégât de poison, puis une charge de moins")
	target.creature["defenses"] = {"resistances": ["poison"]}
	hp = target.hp
	combat.start_turn()
	_expect(hp == target.hp, "état Poison : la résistance l'annule")

	# L'Armure baisse le seuil des dégâts, sans passer sous 1 ; une attaque surprise l'ignore.
	target.creature["armor"] = 5
	before = combat.log.size()
	await combat._roll_damage(combat.hero, target, {"count": 3, "threshold": 4}, "slashing", 0, beats, {"armor": true})
	_expect(combat.log.slice(before).any(func(l): return "armure : seuil 4 → 1" in l), "Armure 5 : seuil 4 → 1")
	before = combat.log.size()
	await combat._hit(combat.hero, target, weapon, combat.hero.attack_pool(weapon), 0, true, false, beats, true)
	_expect(combat.log.slice(before).any(func(l): return "armure" in l), "surprise sans arme assassine : l'armure compte")
	var held := combat.hero.character.weapon_id()
	combat.hero.character.equipment["main_hand"] = "dagger"
	before = combat.log.size()
	await combat._hit(combat.hero, target, weapon, combat.hero.attack_pool(weapon), 0, true, false, beats, true)
	_expect(not combat.log.slice(before).any(func(l): return "armure" in l), "surprise avec une dague (assassine) : armure ignorée")
	combat.hero.character.equipment["main_hand"] = held
	target.creature["natural_armor"] = true
	before = combat.log.size()
	await combat._hit(combat.hero, target, weapon, combat.hero.attack_pool(weapon), 0, true, false, beats, true)
	_expect(combat.log.slice(before).any(func(l): return "armure" in l), "surprise : l'armure naturelle compte")
	Game.combat = null
	DB.creatures.erase("_target")
	return true


func _test_economy() -> bool:
	_expect(Shops.of_location("town") == ["armorer", "apothecary", "forge"] and Shops.of_location("forest").is_empty(),
		"boutiques de Brumeval")
	_expect(Items.category_of("potion_heal") == "consumable" and Items.category_of("longsword") == "weapon", "catégories")

	var hero := Character.create("goblin", "fighter", "Client", {"abilities": {"str": 6, "dex": 5, "con": 5, "int": 4,
		"wis": 5, "cha": 4}})
	Game.start_life(hero, 101)
	var life := Game.life
	_expect(is_equal_approx(Shops.discount(life), minf(0.15, Dice.expected(hero.skill_rank("persuasion"), 4) * 0.05)),
		"CHA 4 : 5 % par succès moyen de Persuasion")
	_expect(Shops.buy_price("apothecary", "potion_heal", life) == 10 and Shops.sell_price("potion_heal", life) == 5,
		"prix : valeur à l'achat (arrondie au-dessus), moitié à la revente")
	hero.abilities["cha"] = 10  # 4 dés au seuil 8 : plafonné à 15 %
	_expect(is_equal_approx(Shops.discount(life), 0.15) and Shops.buy_price("apothecary", "potion_heal", life) == 9
		and Shops.sell_price("potion_heal", life) == 5, "Persuasion : remise plafonnée à 15 %")
	hero.abilities["cha"] = 1
	_expect(Shops.discount(life) >= 0.0 and Shops.discount(life) < 0.02, "mauvais négociateur : presque aucune remise")
	var mira := Character.create_companion("mira")
	mira.abilities["cha"] = 9
	life.companions.append(mira)
	_expect(Shops.negotiator(life) == mira, "le meilleur négociateur du groupe parle")
	life.companions.clear()
	hero.abilities["cha"] = 4

	# Achat, revente, réassort.
	hero.gold = 30
	_expect(life.buy("apothecary", "potion_heal") and hero.gold == 20 and hero.item_count("potion_heal") == 2
		and life.shop_stock("apothecary")["potion_heal"] == 3, "achat : or, sac et stock")
	_expect(life.sell("armorer", "potion_heal") and hero.gold == 25 and life.shop_stock("armorer")["potion_heal"] == 1,
		"tout marchand rachète tout, et l'objet rejoint son stock")
	DB.items["_relic"] = {"id": "_relic", "name": "Relique", "category": "treasure", "value": 50, "quest": true}
	hero.add_item("_relic")
	_expect(not life.sell("armorer", "_relic") and life.drop_item("_relic") == 0, "objet de quête : ni vendu ni jeté")
	hero.remove_item("_relic")
	DB.items.erase("_relic")
	hero.gold = 0
	_expect(not life.buy("armorer", "longsword"), "pas assez d'or")
	life.shop_stock("apothecary").erase("antidote")
	life.day += 3
	_expect(life.shop_stock("apothecary").get("antidote", 0) == 3, "réassort après restock_days jours")
	var saved := LifeState.from_dict(JSON.parse_string(JSON.stringify(life.to_dict())))
	_expect(saved.shop_stock("apothecary") == life.shop_stock("apothecary"), "stock des boutiques sauvegardé")

	# Fabrication.
	var recipe := Crafting.recipe("craft_longsword")
	_expect(Crafting.missing_for(recipe, life) == "il manque : Minerai de fer ×2, 1 po", "fabrication : ce qui manque")
	hero.gold = 5
	hero.add_item("iron_ore", 2)
	DB.recipes["craft_longsword"]["difficulty"] = 0  # réussite assurée
	var crafted := life.craft("craft_longsword")
	_expect(crafted["ok"] and crafted["success"] and hero.item_count("iron_ore") == 0 and hero.gold == 4
		and hero.item_count("longsword") == 1, "fabrication réussie : matériaux et or dépensés")
	DB.recipes["craft_longsword"]["difficulty"] = 100  # échec assuré
	hero.add_item("iron_ore", 2)
	hero.gold = 5
	var failed := life.craft("craft_longsword")
	_expect(failed["ok"] and not failed["success"] and hero.item_count("iron_ore") == 1 and hero.gold == 4,
		"fabrication ratée : la moitié des matériaux gâchée")
	DB.recipes["craft_longsword"].erase("difficulty")
	_expect(Crafting.check_for(Crafting.recipe("craft_longsword")) == {"skill": "crafting", "ability": "dex", "difficulty": 1},
		"test d'Artisanat (DEX) pour la forge, difficulté 1 par défaut")
	life.crafted["forge"] = 5
	hero.gender = "female"
	_expect(life.professions() == ["Forgeronne (5 objets)"], "métier qui se dessine (accordé au genre)")

	# Amélioration à la forge.
	_expect(Crafting.can_upgrade("longsword") and not Crafting.can_upgrade("robe") and not Crafting.can_upgrade("flame_tongue")
		and not Crafting.can_upgrade("longsword@3"), "objets améliorables")
	hero.gold = 1000
	_expect(life.upgrade("longsword") and hero.item_count("longsword@1") == 1 and hero.gold == 950, "+1 depuis le sac")
	_expect(Items.name_of("longsword@1") == "Épée longue +1" and Items.rarity_of("longsword@1") == "uncommon"
		and Items.value_of("longsword@1") == 53, "objet amélioré : nom, rareté, valeur")
	var armor_before := hero.armor()
	_expect(life.upgrade("chain_mail", hero, "armor") and hero.equipment["armor"] == "chain_mail@1"
		and hero.armor() == armor_before + 1, "+1 sur l'armure portée")
	_expect(life.upgrade("chain_mail@1", hero, "armor") and hero.equipment["armor"] == "chain_mail@2" and hero.gold == 750,
		"+2 : 150 po")
	var c := Combatant.from_character(hero, true)
	var weapon := {"type": "attack", "weapon": true}
	var plain: int = c.damage_pool(weapon, c.attack_pool(weapon))["count"]
	life.equip(hero, "longsword@1")
	_expect(c.damage_pool(weapon, c.attack_pool(weapon))["count"] == plain + 1 and hero.weapon_id() == "longsword@1",
		"arme +1 équipée : un dé de dégâts de plus")
	_expect(Shops.buys("forge", "longsword") and Shops.buys("armorer", "chain_mail@2"), "les objets améliorés se revendent")
	return true


func _test_advantage() -> bool:
	# États et difficulté des attaques (avantage : difficulté −1, désavantage : +1).
	DB.creatures["_target"] = {"id": "_target", "name": "Cible", "hp": 200, "abilities": {"dex": 6, "wis": 1},
		"skills": {"insight": 0},
		"actions": [{"name": "Rien", "weight": 1, "target": "self", "effects": [{"type": "status", "status": "shielded", "stacks": 0}]}]}
	Game.start_life(Character.create("human", "fighter", "Testeur"), 111)
	var combat := Game.start_combat({"enemies": ["_target", "_target"]})
	var hero := combat.hero
	var target := combat.enemies()[0]
	var weapon := {"type": "attack", "weapon": true}
	_expect(combat.attack_difficulty(hero, target, weapon) == 2, "mêlée : difficulté = Esquive naturelle (DEX 6 / 3)")
	target.add_status("prone", 1)
	_expect(combat.attack_difficulty(hero, target, weapon) == 1, "À terre : difficulté −1")
	hero.add_status("blinded", 1)
	_expect(combat.attack_difficulty(hero, target, weapon) == 2, "Aveuglé + À terre : ils s'annulent")
	hero.statuses.clear()
	target.statuses.clear()
	var ranged := {"type": "attack", "ranged": true}
	target.add_status("invisible", 1)
	_expect(combat.attack_difficulty(hero, target, ranged) == 2, "distance : Couvert 1, +1 si la cible est cachée")
	target.statuses.clear()
	target.add_status("restrained", 1)
	_expect(combat.cover(target) == 1 and combat.attack_difficulty(hero, target, weapon) == 1, "Entravé : immobile, difficulté −1")
	target.statuses.clear()
	combat.spec["light"] = "dark"
	_expect(combat.cover(target) == 3, "dans le noir : Couvert +2")
	combat.spec.erase("light")

	# Paralysé : ne peut pas résister en DEX, pris par surprise.
	target.add_status("paralyzed", 1)
	var beats: Array[Dictionary] = []
	_expect(not combat._resists(hero, target, {"ability": "dex"}, beats, true), "Paralysé : ne résiste pas (DEX)")
	_expect(combat.is_surprise(hero, target) and combat.attack_difficulty(hero, target, weapon) == 1, "Paralysé : pris par surprise")
	target.statuses.clear()

	# Endormi : passe son tour, se réveille s'il est blessé.
	target.add_status("asleep", 2)
	combat.turn = combat.order.find(target)
	combat.start_turn()
	_expect(combat.skipped and target.stacks("asleep") == 1, "Endormi : passe son tour")
	combat._deal_damage(hero, target, 3, "slashing", false, "")
	_expect(target.stacks("asleep") == 0, "Endormi : réveillé par les dégâts")

	# Charmé : aucune action contre l'ennemi ; Entravé : pas de fuite.
	hero.add_status("charmed", 1)
	_expect(combat.action_unavailable_reason(hero, Actions.def("weapon_attack")) == "charmé"
		and combat.action_unavailable_reason(hero, Actions.def("second_wind")) == "", "Charmé : seulement les actions non hostiles")
	hero.statuses.clear()
	hero.add_status("restrained", 1)
	_expect(not combat.can_flee_now(hero), "Entravé : pas de fuite")
	hero.statuses.clear()

	# Barbare : Rage (action gratuite) : corps à corps seulement, succès des attaques doublés dans les deux sens.
	Game.start_life(Character.create("human", "barbarian", "Brakka"), 113)
	combat = Game.start_combat({"enemies": ["_target"]})
	var brute := combat.hero
	target = combat.enemies()[0]
	combat.turn = combat.order.find(brute)
	combat.start_turn()
	await combat.perform(brute, Actions.def("rage"))
	_expect(brute.stacks("raging") == 1 and combat.actions_left == 2, "Rage : action gratuite")
	_expect(brute.attack_successes_multiplier(target) == 2 and target.attack_successes_multiplier(brute) == 2,
		"Rage : succès ×2 pour ses attaques et celles qu'il subit")
	_expect(combat.action_unavailable_reason(brute, Actions.def("weapon_attack")) == ""
		and combat.action_unavailable_reason(brute, Actions.def("rage")) != ""
		and combat.action_unavailable_reason(brute, Actions.def("prepare")) != "", "Rage : seulement des attaques au corps à corps")
	combat.start_turn()
	_expect(brute.stacks("raging") == 0, "Rage : finit au début de son tour suivant")
	Game.combat = null

	# Sommeil : opposition entre la compétence d'incantation (Érudition) du lanceur et la résistance (SAG).
	var mage := Character.create("human", "wizard", "Mage", {"skill_ranks": {}})  # Érudition 3
	Game.start_life(mage, 112)
	combat = Game.start_combat({"enemies": ["_target"]})
	target = combat.enemies()[0]
	var slept := 0
	for i in 30:
		target.statuses.clear()
		await combat._resolve(combat.hero, [{"type": "status", "status": "asleep", "stacks": 2, "resist": {"ability": "wis"}}],
			"all_enemies", null, true)
		slept += 1 if target.stacks("asleep") == 2 else 0
	_expect(slept > 15 and slept < 30, "Sommeil : la cible s'endort le plus souvent, mais résiste parfois (%d/30)" % slept)
	Game.combat = null
	DB.creatures.erase("_target")
	return true


func _test_choices() -> bool:
	# Rangs de création : 4 du passé, 8 de la classe (plus de choix de compétences de classe).
	var fighter := Character.create("goblin", "fighter", "G", {"background": "acolyte", "skill_ranks": {}})
	_expect(fighter.skill_rank("lore") == 1 + 1 and fighter.skill_rank("insight") == 2 + 1 and fighter.skill_rank("weapon_melee") == 1 + 2
		and fighter.skill_rank("physique") == 2 + 2 and fighter.skill_rank("weapon_siege") == 1 + 1
		and fighter.skill_rank("determination") == 1 + 1 + 1 and not fighter.choices.has("class/skills"), "passé (4 rangs) et classe (8 rangs)")

	# Ascendance du tieffelin.
	var tiefling := Character.create("tiefling", "wizard", "T", {"choices": {"species/ancestry": ["cold"]}})
	_expect(tiefling.all_defenses().has(Defenses.RESISTANCE, "cold") and not tiefling.all_defenses().has(Defenses.RESISTANCE, "fire"),
		"ascendance : Givre abyssal")
	_expect(CharacterSheet.bbcode(tiefling).begins_with("Tieffelin (Givre abyssal)"), "fiche : ascendance affichée")

	# Style de combat (Guerrier niveau 1) : choix en attente, puis effet.
	_expect(fighter.pending_choice().get("key") == "feature:fighting_style/style", "Style de combat à choisir au hub")
	var styles := fighter.choice_options("feature:fighting_style/style")
	_expect(styles.size() == 5 and "unarmed_fighting" in styles and "two_weapon_fighting" in styles and "nimble" not in styles,
		"seulement les cinq dons de style")
	_expect(fighter.choose("feature:fighting_style/style", "dueling") and fighter.has_feat("dueling"), "style À une main choisi")
	var duelist := Combatant.from_character(fighter, true)
	var swing := {"type": "attack", "weapon": true}
	var two_hands: int = duelist.damage_pool(swing, duelist.attack_pool(swing))["count"]
	fighter.equipment["off_hand"] = "shield"
	var with_shield: int = duelist.damage_pool(swing, duelist.attack_pool(swing))["count"]
	fighter.equipment["off_hand"] = "dagger"
	var with_dagger: int = duelist.damage_pool(swing, duelist.attack_pool(swing))["count"]
	fighter.equipment.erase("off_hand")
	_expect(with_shield == two_hands + 1 and with_dagger == two_hands,
		"À une main : un dé de plus avec un bouclier, rien à deux mains ni avec une arme dans l'autre main")
	_expect("dueling" not in fighter.available_feats(), "les styles ne s'obtiennent pas en montant de niveau")
	# Deux armes (pour tous) : chaque Attaque se fait avec l'une ou l'autre ; le style À deux armes frappe des deux.
	var twin := Character.create("goblin", "fighter", "T", {"choices": {"feature:fighting_style/style": ["two_weapon_fighting"]}})
	var plain := Character.create("goblin", "fighter", "P")
	for wielder: Character in [twin, plain]:
		wielder.unequip("main_hand")
		wielder.equip("shortsword")
	plain.equip("dagger")
	_expect(plain.weapon_id() == "dagger" and not plain.equipment.has("off_hand"), "équiper une arme remplace l'arme principale")
	plain.unequip("main_hand")
	plain.equip("shortsword")
	_expect(plain.can_dual_wield("dagger") and plain.can_dual_wield("greataxe") and not plain.can_dual_wield("shortbow")
		and not plain.can_dual_wield("javelin"), "seconde arme : de corps à corps, tenue à une main (même lourde)")
	plain.equip("dagger", "off_hand")
	twin.equip("dagger", "off_hand")
	_expect(plain.weapon_id() == "shortsword" and plain.equipment.get("off_hand") == "dagger", "seconde arme en main secondaire")
	var hand := Combatant.from_character(plain, true)
	var hand_variants := hand.action_variants(Actions.def("weapon_attack"))
	_expect(hand_variants.size() == 2 and hand_variants[1]["effects"][0]["weapon"] == "dagger"
		and hand.attack_pool(hand_variants[1]["effects"][0])["count"] == plain.weapon_rank("dagger")
		and hand.off_hand_attack(swing).is_empty(), "deux armes : une Attaque avec l'une ou l'autre, sans malus ni seconde attaque")
	var dual := Combatant.from_character(twin, true)
	var dual_variants := dual.action_variants(Actions.def("weapon_attack"))
	_expect(dual_variants.size() == 3 and dual.off_hand_attack(dual_variants[2]["effects"][0]).get("weapon") == "dagger",
		"style À deux armes : Attaque des deux mains")
	DB.creatures["_dummy"] = {"id": "_dummy", "name": "Mannequin", "hp": 300, "abilities": {"dex": 1},
		"actions": [{"name": "Rien", "weight": 1, "target": "self", "effects": [{"type": "status", "status": "shielded", "stacks": 0}]}]}
	Game.start_life(twin, 131)
	var duel := Game.start_combat({"enemies": ["_dummy"]})
	duel.turn = duel.order.find(duel.hero)
	duel.start_turn()
	await duel.perform(duel.hero, duel.hero.action_variants(Actions.def("weapon_attack"))[2], duel.enemies()[0])
	_expect(duel.log.any(func(l): return "main secondaire" in l), "À deux armes : l'attaque de la main secondaire suit")
	Game.combat = null
	DB.creatures.erase("_dummy")

	# Sous-classe au niveau 3 : Champion.
	fighter.add_xp(Progression.xp_for(3) - fighter.xp)
	_level_up(fighter)
	_expect(fighter.pending_choice().get("key") == "feature:subclass/subclass", "sous-classe à choisir au niveau 3")
	fighter.choose("feature:subclass/subclass", "champion")
	var champion := Combatant.from_character(fighter, true)
	_expect(champion.critical_bonus() == 1 and fighter.features().any(func(f): return f["id"] == "remarkable_athlete"),
		"Champion : critique avec un succès de moins, Athlète remarquable")
	_expect(Dice.check_pool(fighter, {"skill": "physique", "difficulty": 1})["count"] == fighter.skill_rank("physique") + 1,
		"Athlète remarquable : un dé de plus en Physique")
	_expect(CharacterSheet.bbcode(fighter).contains("Guerrier (Champion)"), "fiche : sous-classe affichée")

	# Doué (Noble) : deux compétences au choix.
	var noble := Character.create("goblin", "wizard", "N", {"background": "noble", "choices": {"background/feat": ["skilled"]}})
	_expect(noble.choices.get("feat:skilled/skills", []).is_empty() and "stealth" in noble.choice_options("feat:skilled/skills"),
		"Doué : choix proposé")
	var stealth_before := noble.skill_rank("stealth")
	for skill in ["stealth", "survival"]:
		noble.choose("feat:skilled/skills", skill)
	_expect(noble.skill_rank("stealth") == stealth_before + 1 and noble.choices["feat:skilled/skills"].size() == 2
		and not noble.choose("feat:skilled/skills", "arts"),
		"Doué : +1 rang dans 2 compétences")

	_expect(not Feats.has("ability_score_improvement") and not Feats.has("defense") and not Feats.has("athlete"),
		"plus d'Amélioration d'attribut, de Défense ni d'Athlète")

	# Initié à la magie (magicien) : un tour de magie au choix, lancé avec l'INT et l'Érudition.
	var knight := Character.create("goblin", "fighter", "K")
	knight.feats.append("magic_initiate_wizard")
	knight.complete_all_choices()
	_expect("fire_bolt" in knight.combat_actions() and knight.action_ability("spell") == "int" and knight.spell_skill() == "lore",
		"Initié à la magie (magicien) : tour de magie, INT, Érudition")
	var druid_friend := Character.create("goblin", "fighter", "D")
	druid_friend.feats.append("magic_initiate_druid")
	druid_friend.complete_all_choices()
	_expect("thorn_whip" in druid_friend.combat_actions() and druid_friend.spell_skill() == "survival",
		"Initié à la magie (druide) : Fouet épineux, Nature")

	# Évocateur : tour de magie puissant ; Voleur : Mains lestes.
	var evoker := _at_level("goblin", "wizard", 10)
	_expect(evoker.choices.get("feature:subclass/subclass") == ["evoker"] and evoker.has_modifier("empowered_evocation"), "Évocateur niveau 10")
	var caster := Combatant.from_character(evoker, true)
	var bolt: Dictionary = Actions.def("fire_bolt")["effects"][0]
	_expect(caster.damage_pool(bolt, caster.attack_pool(bolt))["count"] == 6 + 2,
		"niveau 10 : un dé de tour de magie et un dé d'Évocation renforcée")
	var thief := _at_level("goblin", "rogue", 3)
	thief.add_item("potion_heal")
	Game.start_life(thief, 122)
	var combat := Game.start_combat({"enemies": ["wolf"]})
	combat.turn = combat.order.find(combat.hero)
	combat.start_turn()
	await combat.use_item(combat.hero, "potion_heal", combat.hero)
	_expect(combat.actions_left == 2, "Mains lestes : l'objet ne coûte pas d'action")
	Game.combat = null

	# Style Armes à deux mains : une relance des dés de dégâts ratés, avec une arme à deux mains.
	var brute := Character.create("goblin", "fighter", "B", {"choices": {"feature:fighting_style/style": ["great_weapon_fighting"]}})
	brute.equip("greataxe")
	var weapon := {"type": "attack", "weapon": true}
	_expect(brute.has_feat("great_weapon_fighting") and Combatant.from_character(brute, true).great_weapon_fighting(weapon),
		"Armes à deux mains : relance des dés de dégâts ratés")

	# Compagnon : ses choix sont faits d'office ; sauvegarde des choix.
	var mira := Character.create_companion("mira")
	_expect(mira.pending_choice().is_empty() and mira.choices.has("species/versatile"), "compagnon : choix complétés")
	var saved := Character.from_dict(JSON.parse_string(JSON.stringify(fighter.to_dict())))
	_expect(saved.choices == fighter.choices and saved.armor() == fighter.armor(), "choix sauvegardés")
	return true


func _test_skill_ranks() -> bool:
	# Attaques : [rang de la compétence de l'arme] d10 contre l'attribut ; sorts : compétence d'incantation.
	var fighter := Character.create("goblin", "fighter", "G", {"skill_ranks": {}})
	_expect(fighter.skill_rank("weapon_melee") == 3
		and fighter.attack_pool("weapon") == {"count": 3, "threshold": fighter.ability_score("dex"), "ability": "dex"},
		"Guerrier : Armes de mêlée 1 + 2 (classe), contre la DEX")
	var mage := Character.create("goblin", "wizard", "M", {"skill_ranks": {}})
	_expect(mage.attack_pool("weapon")["count"] == 1 and mage.attack_pool("spell") == {"count": 3, "threshold": 6, "ability": "int"},
		"Magicien : bâton au rang 1, sorts au rang d'Érudition 3 (1 + 2 de classe) contre INT")
	_expect(Equipment.skills_for("longbow") == ["weapon_ranged"] and Equipment.skills_for("unarmed") == ["physique"],
		"compétence de l'arme (mains nues : Physique)")
	_expect(fighter.weapon_rank("unarmed") == fighter.skill_rank("physique"), "mains nues : rang de Physique")
	_expect(fighter.resist_pool("con")["count"] == fighter.skill_rank("physique")
		and fighter.resist_pool("dex")["count"] == fighter.skill_rank("physique"), "résister : pas de maîtrise de classe")


	# Points de compétence : un tous les deux niveaux (2, 4, 6…), +1 rang au choix, sans plafond.
	var learner := Character.create("human", "fighter", "Élève")
	learner.add_xp(Progression.xp_for(4) - learner.xp)
	_level_up(learner)
	var lore_before := learner.skill_rank("lore")
	_expect(learner.pending_skill_points == 2 and learner.has_pending_advancement(),
		"niveau 4 : deux points de compétence (niveaux 2 et 4)")
	_expect(learner.spend_skill_point("lore") and learner.skill_rank("lore") == lore_before + 1 and learner.pending_skill_points == 1,
		"un point : +1 rang")
	_expect(learner.can_raise_skill("lore") and learner.spend_skill_point("lore") and learner.pending_skill_points == 0,
		"deux niveaux d'un coup : deux rangs possibles dans la même compétence")
	var steady := Character.create("human", "fighter", "Pas à pas")
	steady.add_xp(Progression.xp_for(2) - steady.xp)
	_level_up(steady)
	steady.pending_skill_points = 2  # deux points pour un seul niveau
	_expect(steady.spend_skill_point("lore") and not steady.can_raise_skill("lore") and steady.can_raise_skill("arts"),
		"un rang par compétence et par niveau au plus")
	steady.skill_points["lore"] = 10
	_expect(steady.skill_rank("lore") > 10, "pas de plafond de rang après la création")
	var reloaded := Character.from_dict(JSON.parse_string(JSON.stringify(learner.to_dict())))
	_expect(reloaded.skill_points == learner.skill_points and reloaded.level_raises == learner.level_raises, "points de compétence sauvegardés")

	# Langues : une langue à choisir par rang de Langues, en plus du Commun.
	_expect(fighter.known_languages() == ["common"] and fighter.choice_options("skill/languages").size() == 5, "langues à choisir")
	fighter.choose("skill/languages", "elvish")
	_expect(fighter.known_languages() == ["common", "elvish"] and not fighter.choose("skill/languages", "orc"), "rang 1 : une langue")
	var sage := Character.create("human", "wizard", "S", {"background": "sage", "skill_ranks": {}})
	_expect(sage.skill_rank("languages") == 4 and sage.choice_options("skill/languages").size() == 5, "Érudit Magicien : Langues 1 + 1 + 2")


	# Valeur passive (condition d'événement) : succès moyens de la réserve.
	var life := LifeState.new()
	life.character = fighter
	var pool := fighter.skill_pool("perception")
	_expect(fighter.passive("perception") == roundi(Dice.expected(pool["count"], pool["threshold"]))
		and Conditions.check({"type": "passive", "skill": "perception", "min": 0}, life, null)
		and not Conditions.check({"type": "passive", "skill": "perception", "min": 40}, life, null), "Perception passive")

	# Test d'événement : attribut imposé ou meilleur attribut ; choix proposés au joueur.
	_expect(Dice.ability_options({"skill": "physique", "difficulty": 1}) == ["str", "dex", "con"]
		and Dice.ability_options({"skill": "persuasion", "ability": "str", "difficulty": 1}).is_empty()
		and Dice.ability_options({"skill": "stealth", "difficulty": 1}).is_empty(), "attributs proposés au joueur")
	_expect(Dice.check_pool(fighter, {"skill": "persuasion", "ability": "str", "difficulty": 1}) == fighter.skill_pool("persuasion", "str"),
		"intimider : Persuasion avec la FOR")

	# Créatures : rang listé, sinon le rang de départ.
	DB.creatures["_target"] = {"id": "_target", "name": "Cible", "hp": 200, "abilities": {"wis": 4, "dex": 6},
		"skills": {"stealth": 3}, "actions": [{"name": "Rien", "weight": 1, "target": "self", "effects": [{"type": "status", "status": "shielded", "stacks": 0}]}]}
	Game.start_life(fighter, 131)
	var combat := Game.start_combat({"enemies": ["_target"]})
	var target := combat.enemies()[0]
	_expect(target.skill_rank("stealth") == 3 and target.skill_rank("persuasion") == 2 and target.skill_rank("lore") == 1
		and target.skill_pool("stealth") == {"count": 3, "threshold": 6, "ability": "dex"}, "créature : rangs listés, sinon rang de départ")

	# Actions communes : Se préparer, Se cacher, Intimider, Premiers soins.
	_expect(["prepare", "hide", "intimidate", "first_aid"].all(func(id): return id in fighter.combat_actions()), "actions communes")
	await combat._resolve(combat.hero, [{"type": "check", "skill": "stealth", "difficulty": 0}, {"type": "status", "status": "invisible", "stacks": 2}],
		"self", null, true)
	_expect(combat.hero.stacks("invisible") == 2 and combat.is_surprise(combat.hero, target), "Se cacher : invisible, attaque surprise")
	combat.hero.statuses.clear()
	await combat._resolve(combat.hero, [{"type": "check", "skill": "stealth", "difficulty": 100}, {"type": "status", "status": "invisible", "stacks": 2}],
		"self", null, true)
	_expect(combat.hero.stacks("invisible") == 0, "test raté : pas d'effet")
	_expect(Actions.text_of("intimidate") == "Test de Persuasion (FOR) contre la résistance (Sagesse) de la cible. Si c'est réussi : 2 Effrayé.",
		"texte d'Intimider")
	Game.combat = null
	DB.creatures.erase("_target")

	# Réglages : conservés en effaçant le monde.
	Meta.settings["manual_skill_ability"] = true
	Meta.reset()
	_expect(Meta.settings["manual_skill_ability"], "réglages conservés quand on efface le monde")
	var meta := MetaState.new()
	meta.load_dict(Meta.to_dict())
	_expect(meta.settings["manual_skill_ability"] and meta.settings.has("many_dice"), "réglages sauvegardés")
	meta.free()
	Meta.settings["manual_skill_ability"] = false
	return true


func _test_social() -> bool:
	var backup := Meta.to_dict()
	Meta.npcs.clear()
	Meta.pregnancies.clear()
	Game.start_life(Character.create("human", "fighter", "Héros", {"background": "artisan"}), 141)
	var life := Game.life
	var rng := life.rng

	# Habitués créés à la première visite, gens qu'on cherche, génération progressive.
	var people := Social.at_location("town", rng)
	_expect(people.size() >= 4 and people.any(func(n): return n.name == "Hilde" and n.species == "dwarf"),
		"habitués de Brumeval (Hilde la forgeronne…)")
	_expect(Social.at_location("town", rng).size() == people.size(), "les habitués ne sont créés qu'une fois")
	var herbalist_seen := func(loc: String, slot: String) -> bool:
		return Social.at_location(loc, rng, slot).any(func(n): return n.role == "herbalist")
	_expect(herbalist_seen.call("forest", "morning") and not herbalist_seen.call("town", "morning")
		and herbalist_seen.call("town", "afternoon") and not herbalist_seen.call("forest", "evening"),
		"emploi du temps : l'herboriste cueille en forêt le matin, tient boutique ensuite")
	var herbalist: Npc = Social.at_location("town", rng, "afternoon").filter(func(n): return n.role == "herbalist")[0]
	herbalist.player["met"] = true
	_expect(Social.absent_known("town", "morning").has(herbalist) and not Social.absent_known("town", "afternoon").has(herbalist)
		and "Forêt des Murmures" in Social.whereabouts_text(herbalist, "morning")
		and Social.whereabouts_check()["skill"] == "insight", "où est… ? : Perspicacité, le lieu selon l'emploi du temps")
	herbalist.player["met"] = false
	var guard := Social.generate("guard", rng)
	_expect(guard.location == "town" and guard.traits.size() == 2 and guard.facts.is_empty() and guard.age(Meta.world_day) >= 18,
		"garde généré : 2 traits, aucun fait avant de les apprendre")
	_expect(guard.known_traits.size() <= 1, "au plus un trait visible à la rencontre")

	# Actions : jauges, faits révélés (définitifs), statut.
	var session := {"acted": false, "understood": false}
	Social.perform("chat", guard, life, session)
	_expect(guard.player["met"] and guard.player["friendship"] > 0 and session["acted"], "Discuter : Amitié en hausse")
	var result := Social.perform("ask_about", guard, life, session)
	_expect(guard.facts.size() == 1 and String(result["lines"].back()) == guard.facts.values()[0], "Se renseigner : un fait révélé")
	for i in 10:
		Social.reveal_fact(guard, rng)
	_expect(guard.facts.size() == DB.npc_facts.size() and Social.reveal_fact(guard, rng) == "", "tous les faits finissent révélés")
	_expect(Meta.npcs.values().any(func(n): return guard.relations.has(n.id) and n.relations.get(guard.id, {}).get("kind") == "family"),
		"fait de famille : un parent du PNJ est créé et lié")
	guard.player["friendship"] = 35
	_expect(Social.status(guard) == "friend" and Social.status_name(guard) != "", "statut : ami")
	guard.player["friendship"] = -70
	_expect(Social.status(guard) == "enemy", "statut : ennemi")

	# Tests : Perspicacité du PNJ, humeur et traits.
	_expect(Social.mood(guard) == Social.mood(guard) and Social.mood(guard).has("difficulty"), "humeur du jour stable")
	guard.traits = ["romantic", "jovial"]
	_expect(Social.trait_reaction(guard, "flirt")["difficulty"] == -1 and is_equal_approx(Social.trait_reaction(guard, "joke")["gain"], 2.0),
		"traits : difficulté et gains modifiés")
	var outcome := Social.check({"skill": "persuasion", "difficulty": 1}, "chat", guard, life, session)
	_expect(outcome.has("success") and "succès contre difficulté" in outcome["text"], "test social en réserve de d10")

	# Romance : seuils, couple, relation libre, jalousie, mariage, enfant.
	var a := Social.generate("villager", rng)
	var b := Social.generate("villager", rng)
	a.languages = ["common"]
	b.languages = ["common"]
	_expect(Social.unavailable_reason("propose_dating", a, life, session) != "", "se fréquenter : Amour 40 requis")
	a.player["love"] = 50
	a.player["friendship"] = 40
	a.traits = ["generous", "curious"]
	a.player["status"] = "dating"
	_expect(Social.status(a) == "dating" and Social.unavailable_reason("propose_dating", a, life, session) == "déjà fait", "en couple")
	b.player["love"] = 50
	b.player["status"] = "dating"
	b.traits = ["jealous", "proud"]
	_expect(Social.unavailable_reason("propose_open", b, life, session) != "", "un jaloux refuse la relation libre")
	var love_before := int(b.player["love"])
	for i in 6:
		Social.jealousy(a, life)
	_expect(int(b.player["love"]) < love_before, "jalousie : le partenaire l'apprend")
	a.player["open"] = true
	_expect(Social.status_name(a).ends_with("(relation libre)"), "relation libre affichée")
	a.player["love"] = 80
	a.player["trust"] = 50
	a.player["status"] = "engaged"
	Social.perform("marry", a, life, session)
	_expect(a.player["status"] == "married" and a.memories.size() > 0, "mariage, et le PNJ s'en souvient")
	Social.perform("have_child", a, life, session)
	_expect(Meta.pregnancies.size() == 1 and Social.unavailable_reason("have_child", a, life, session) != "", "un enfant en route")
	Meta.world_day = int(Meta.pregnancies[0]["due"])
	Social.daily_tick(life)
	var children := Meta.npcs.values().filter(func(n): return n.parents.has(a.id))
	_expect(children.size() == 1 and children[0].age(Meta.world_day) == 0 and life.notices.any(func(t): return "enfant" in t),
		"naissance : l'enfant est un PNJ, le héros est prévenu")
	Social.perform("break_up", a, life, session)
	_expect(Social.status(a) != "married" and not a.player["open"], "divorce")

	# Monde autonome : les PNJ se lient et forment des couples.
	var c := Social.generate("villager", rng, {"age": 30})
	var d := Social.generate("villager", rng, {"age": 30})
	c.relations[d.id] = {"friendship": 60, "love": 38, "trust": 20, "kind": "friend"}
	d.relations[c.id] = {"friendship": 60, "love": 38, "trust": 20, "kind": "friend"}
	for i in 5:
		Social._npc_interact(c, d, life)
	_expect(c.relations[d.id]["kind"] == "partner" and life.notices.any(func(t): return "Rumeur" in t), "monde autonome : un couple se forme")

	# Langues : texte crypté, une lettre par rang.
	var plain := "Bonjour étranger"
	var crypt := Social.scramble(plain, 1, "elvish")
	var changed := 0
	for i in plain.length():
		changed += 1 if crypt[i] != plain[i] else 0
	_expect(crypt.length() == plain.length() and changed >= 8 and crypt[8] == "é" and crypt[14] == "e" and crypt[7] == " ",
		"crypté : au rang 1, seuls les e (et les espaces) restent lisibles")
	_expect(Social.scramble(plain, 26, "elvish") == plain, "toutes les lettres au rang 26")
	var foreigner := Social.generate("villager", rng)
	foreigner.languages = ["orc"]
	_expect(Social.speak("Il dit « bonjour »", life.character, foreigner) != "Il dit « bonjour »"
		and Social.speak("Il dit « bonjour »", life.character, foreigner).begins_with("Il dit «"), "seules les paroles sont cryptées")
	_expect(Social.unavailable_reason("gestures", foreigner, life, session) == "", "gestes possibles sans langue commune")
	life.character.choose("skill/languages", "orc")
	_expect(Social.speak("« bonjour »", life.character, foreigner) == "« bonjour »", "langue apprise : texte clair")

	# Commerce avec un PNJ : achat, vente, cadeau, demande.
	var innkeeper: Npc = Social.at_location("town", rng).filter(func(n): return n.role == "innkeeper")[0]
	innkeeper.gold = 100
	life.character.gold = 100
	var bought := Social.buy(innkeeper, "potion_heal", life)
	_expect(bought and life.character.item_count("potion_heal") >= 1 and innkeeper.gold > 100, "acheter à un PNJ : son or augmente")
	life.character.add_item("old_amulet")
	var friendship := int(innkeeper.player["friendship"])
	Social.gift(innkeeper, "old_amulet", life)
	_expect(int(innkeeper.player["friendship"]) > friendship and innkeeper.inventory.get("old_amulet", 0) == 1, "cadeau : Amitié")
	var smith: Npc = Social.at_location("town", rng).filter(func(n): return n.role == "blacksmith")[0]
	_expect(Social.goods(smith, life) == life.shop_stock("forge"), "un PNJ marchand propose sa boutique")

	# Recrutement, approbation, souvenirs d'une vie à l'autre.
	guard.player["friendship"] = 70
	var recruited := Social.recruit(guard, life)
	_expect(recruited != null and recruited.npc_id == guard.id and guard.location == "party" and recruited in life.companions,
		"recruter un PNJ ami")
	var lines := Social.approve(life, {guard.id: -200})
	_expect(recruited not in life.companions and lines.size() == 2, "désapprobation : le compagnon quitte le groupe")
	Social.on_hero_death(life)
	_expect(a.memories.back()["text"].begins_with("A connu Héros"), "les PNJ se souviennent du héros mort")
	Social.on_new_life()
	_expect(not a.player["met"] and a.player["status"] == "", "nouvelle vie : relations remises à zéro")

	# Sauvegarde du monde.
	var meta := MetaState.new()
	meta.load_dict(Meta.to_dict())
	_expect(meta.npcs.size() == Meta.npcs.size() and meta.npcs[a.id].memories.size() == a.memories.size(), "PNJ sauvegardés")
	meta.free()
	Meta.load_dict(backup)
	Game.combat = null
	return true


func _test_multiclass_and_rest() -> bool:
	# Multiclassage : chaque niveau gagné se place dans la classe de son choix.
	var hero := Character.create("human", "fighter", "Mixte")
	hero.add_xp(Progression.xp_for(3) - hero.xp)
	_expect(hero.level == 3 and hero.pending_class_levels == 2 and hero.class_level("fighter") == 1, "niveaux en attente de classe")
	var lines := hero.assign_class_level("wizard")
	_expect(hero.class_level("wizard") == 1 and hero.has_class("wizard") and lines[0].contains("magicien de niveau 1"),
		"un niveau de Magicien")
	_expect(hero.choice_options("class:wizard/cantrips") == ["fire_bolt", "ray_of_frost"], "multiclassage : les sorts du magicien sont à choisir")
	hero.apply_default_choices()
	_expect(hero.is_caster() and hero.skill_rank(Skills.SPELL) == hero.fixed_skill_rank(Skills.SPELL) and hero.fixed_skill_rank(Skills.SPELL) == 3 and hero.max_resource("spell_slot") == 2
		and "fire_bolt" in hero.combat_actions() and "second_wind" in hero.combat_actions(), "actions et sorts des deux classes")
	hero.assign_class_level("fighter")
	_expect(hero.class_levels == {"fighter": 2, "wizard": 1} and "pommel_strike" in hero.combat_actions()
		and hero.classes_text() == "Guerrier 2 / Magicien 1", "Guerrier 2 / Magicien 1")
	_expect(Conditions.check({"type": "class", "in": ["wizard"]}, _life_of(hero), null), "condition de classe : toutes les classes")
	_expect(hero.resist_pool("str")["count"] == hero.skill_rank("physique") and not hero.is_proficient_save("int"),
		"résister : pas de maîtrise de classe")
	var saved := Character.from_dict(JSON.parse_string(JSON.stringify(hero.to_dict())))
	_expect(saved.class_levels == hero.class_levels and saved.combat_actions() == hero.combat_actions(), "multiclassage sauvegardé")
	# Améliorations par niveau de classe : Guerrier 5 donne +1 attribut, même au niveau total 6.
	hero.add_xp(Progression.xp_for(6) - hero.xp)
	hero.assign_class_level("fighter")
	hero.assign_class_level("fighter")
	hero.assign_class_level("fighter")
	_expect(hero.class_level("fighter") == 5 and hero.pending_ability_points == 1 and hero.pending_feats == 1,
		"amélioration au niveau 5 de Guerrier (et le don du niveau 4)")
	var old := Character.from_dict({"species_id": "human", "class_id": "rogue", "level": 3})
	_expect(old.class_levels == {"rogue": 3}, "anciennes sauvegardes : tous les niveaux dans la classe principale")

	# Repos selon le lieu.
	Game.start_life(Character.create("human", "fighter", "Dormeur"), 151)
	var life := Game.life
	life.character.hp = 1
	life.location = "town"
	life.character.gold = 3
	_expect(not Game.rest()["ok"] and life.character.hp == 1, "auberge : pas assez d'or")
	life.character.gold = 20
	var day := life.day
	var result := Game.rest()
	_expect(result["ok"] and life.character.gold == 15 and life.character.hp == life.character.max_hp and life.day == day
		and life.slot_id() == "evening", "auberge : 5 po, PV au maximum, deux périodes passées")
	life.character.hp = 1
	_expect(Game.rest(true)["ok"] and life.character.gold == 15 and life.character.hp == 1 + (life.character.max_hp - 1) / 2
		and life.slot_id() == "late", "repos court : gratuit, une période, moitié des PV manquants")
	life.location = "forest"
	_expect(Game.rest_name() == "Camper" and Game.rest()["ok"] and life.character.gold == 15, "camper : gratuit")
	return true


func _life_of(ch: Character) -> LifeState:
	var life := LifeState.new()
	life.character = ch
	return life


func _test_social_life() -> bool:
	var backup := Meta.to_dict()
	Meta.npcs.clear()
	Game.start_life(Character.create("human", "fighter", "Héros"), 161)
	var life := Game.life
	var rng := life.rng
	var friend := Social.generate("villager", rng)
	friend.languages = ["common"]
	var session := {"acted": false, "understood": false}

	# Activités : coût en or et en temps.
	friend.player["friendship"] = 20
	life.character.gold = 3
	_expect(Social.unavailable_reason("dinner", friend, life, session) == "5 po requises", "dîner : il faut 5 po")
	life.character.gold = 10
	Social.perform("dinner", friend, life, session)
	_expect(life.character.gold == 5 and session["extra_time"] == 1 and int(friend.player["friendship"]) > 20,
		"dîner : 5 po, un créneau de plus, amitié")

	# Réputation : accueil à la rencontre, prix, condition d'événement.
	life.reputation["town"] = 40
	var stranger := Social.generate("villager", rng)
	Social.meet(stranger, life)
	_expect(int(stranger.player["friendship"]) == 10, "réputation : meilleur accueil (Amitié + réputation / 4)")
	_expect(Shops.reputation_bonus("town", life) == 0.05 and Conditions.check({"type": "reputation", "location": "town", "min": 30}, life, Meta),
		"réputation : remise et condition")
	Effects.apply_all([{"type": "reputation", "amount": -50, "location": "town"}, {"type": "npc_relation", "npc": friend.id, "trust": 10}], life, Meta)
	_expect(life.reputation["town"] == -10 and int(friend.player["trust"]) >= 10, "effets : réputation et relation")

	# Initiatives : un ami demande un service.
	Meta.npcs.clear()
	friend = Social.generate("villager", rng)
	friend.player["met"] = true
	friend.player["friendship"] = 40
	Meta.npcs[friend.id] = friend
	var visit := {}
	for i in 30:
		life.last_initiative_day = -1
		visit = Social.initiative_event(life)
		if not visit.is_empty():
			break
	_expect(visit.get("id", "").begins_with("npc_favor_") and visit["choices"].size() == 2, "un ami vient demander un service")
	var help: Dictionary = visit["choices"][0]
	var result := EventEngine.resolve_choice(visit, help, life, Meta)
	_expect(int(friend.player["friendship"]) == 48 and result["lines"].size() >= 1, "rendre service : Amitié +8")
	_expect(Social.initiative_event(life).is_empty(), "au plus une visite par jour")
	friend.player["status"] = "dating"
	friend.player["last_seen"] = Meta.world_day - 10
	life.last_initiative_day = -1
	for i in 30:
		life.last_initiative_day = -1
		visit = Social.initiative_event(life)
		if not visit.is_empty():
			break
	_expect(visit.get("id", "").begins_with("npc_neglect_"), "un partenaire délaissé se plaint")

	# Mort des PNJ : de vieillesse, passé l'âge limite ; les proches s'en souviennent, le héros l'apprend.
	var elder := Social.generate("villager", rng, {"age": 120, "species": "human"})
	var heir := Social.generate("villager", rng, {"age": 30})
	elder.relations[heir.id] = {"friendship": 60, "love": 0, "trust": 30, "kind": "family"}
	elder.player["met"] = true
	elder.player["friendship"] = 40
	life.notices.clear()
	for i in 4000:
		if not elder.alive:
			break
		Social._deaths(life)
	_expect(not elder.alive and heir.memories.any(func(m): return elder.name in m["text"])
		and life.notices.any(func(t): return elder.name in t and "vieillesse" in t), "un vieillard finit par mourir de vieillesse")
	var young := Social.generate("villager", rng, {"age": 20, "species": "human"})
	for i in 400:
		Social._deaths(life)
	_expect(young.alive and young not in [] and not Social.known_npcs().has(elder), "les jeunes ne meurent pas de vieillesse ; les morts disparaissent")

	# Enfant d'un héros : mentionné dans la fiche.
	var child := Social.generate("villager", rng, {"age": 5})
	child.parents.assign(["hero:Héros"])
	_expect(SocialView.describe(child, life, false).contains("Enfant de"), "enfant d'un héros : mentionné")
	Meta.load_dict(backup)
	return true


func _test_combat_turns() -> bool:
	# États : poison (dégâts bruts, -1 charge), brûlure (% des PV max), étourdi, protection, affaibli.
	var combat: Combat
	DB.creatures["_dummy"] = {"id": "_dummy", "name": "Mannequin", "hp": 100, "abilities": {"dex": 1},
		"actions": [{"name": "Rien", "weight": 1, "target": "self", "effects": [{"type": "status", "status": "shielded", "stacks": 0}]}]}
	Game.start_life(Character.create("human", "fighter", "Testeur"), 4)
	combat = Game.start_combat({"enemies": ["_dummy"]})
	var dummy := combat.enemies()[0]
	dummy.add_status("poisoned", 3)
	dummy.add_status("burning", 2)
	combat.turn = combat.order.find(dummy)
	combat.start_turn()
	_expect(dummy.hp == 100 - 1 - 10, "poison (1) + brûlure 2 (5 pour cent de 100 par charge)")
	_expect(dummy.stacks("poisoned") == 2 and dummy.stacks("burning") == 1, "chaque état perd une charge")
	dummy.add_status("stunned", 1)
	combat.start_turn()
	_expect(combat.skipped and dummy.stacks("stunned") == 0, "étourdi : le tour est passé")
	var hp := combat.hero.hp
	combat.hero.add_status("shielded", 5)
	combat._deal_damage(dummy, combat.hero, 3, "bludgeoning", false, "")
	_expect(combat.hero.hp == hp and combat.hero.stacks("shielded") == 2, "protection : absorbe les dégâts")
	dummy.add_status("weakened", 2)
	_expect(dummy.damage_dice_modifier() == -2, "affaibli : un dé de dégâts de moins par charge")
	combat.hero.statuses.clear()
	DB.creatures.erase("_dummy")
	Game.combat = null

	# Intentions : une action annoncée un tour est jouée en premier au suivant.
	Game.start_life(Character.create("human", "fighter", "Testeur"), 8)
	combat = Game.start_combat({"enemies": ["dire_wolf"]})
	var alpha := combat.enemies()[0]
	var howl: Dictionary = alpha.creature["actions"][1]
	alpha.intent = howl
	combat.turn = combat.order.find(alpha)
	combat.start_turn()
	var beats: Array[Dictionary] = await combat.ai_turn(alpha)
	_expect(combat.hero.stacks("weakened") == 2, "action annoncée jouée au tour suivant")
	_expect(beats[0]["text"].contains("Hurlement"), "l'action annoncée est jouée en premier")
	Game.combat = null

	# Archétypes d'IA : le chasseur vise le plus blessé ; le lâche s'enfuit, sans XP ni butin.
	Game.start_life(Character.create("human", "fighter", "Testeur"), 12)
	Effects.apply_all([{"type": "recruit", "companion": "mira"}], Game.life, Meta)
	combat = Game.start_combat({"enemies": ["wolf", "bandit"]})
	var hunter := combat.enemies()[0]
	var mira := combat.allies()[1]
	mira.hp = 1
	combat.turn = combat.order.find(hunter)
	combat.start_turn()
	var hunt_beats: Array[Dictionary] = await combat.ai_turn(hunter)
	_expect(hunter.ai_kind() == "hunter" and hunt_beats.any(func(b): return "attaque Mira" in b["text"]), "le loup vise le plus blessé")
	var coward := combat.enemies()[1]
	coward.hp = 1
	var fled := false
	for i in 20:
		combat.turn = combat.order.find(coward)
		combat.start_turn()
		await combat.ai_turn(coward)
		if coward.fled:
			fled = true
			break
	_expect(fled and not coward.is_alive() and combat.living("enemy").size() == 1, "le brigand lâche s'enfuit")
	# Meute : quand le chef tombe, les loups peuvent fuir.
	var pack_combat := Combat.new({"enemies": ["dire_wolf", "wolf"]}, Game.life)
	var alpha_leader := pack_combat.enemies()[0]
	var pack_wolf := pack_combat.enemies()[1]
	_expect(not pack_combat._breaks(pack_wolf), "la meute tient tant que le chef est debout")
	alpha_leader.hp = 0
	_expect(pack_combat._breaks(pack_wolf), "chef tombé : la meute flanche")
	hunter.hp = 0
	combat._check_end()
	var xp_before := Game.life.character.xp
	var won := Game.finish_combat()
	_expect(won["outcome"] == "victory" and Game.life.character.xp - xp_before == int(Creatures.def("wolf")["xp"]),
		"une créature enfuie ne rapporte pas d'XP")

	# Invocations et places : 4 places par camp (petite ½, moyenne 1, grande 2).
	Game.start_life(Character.create("human", "wizard", "Mage"), 9)
	combat = Game.start_combat({"enemies": ["wolf"]})
	_expect(combat.capacity_used("ally") == 1.0, "le héros occupe 1 place")
	var familiar := Actions.def("find_familiar")
	await combat.perform(combat.hero, familiar)
	_expect(combat.living("ally").size() == 2 and combat.living("ally")[1].summoned, "Appel du familier : une invocation")
	for i in 15:
		await combat._apply(combat.hero, {"type": "summon", "creature": "familiar"}, null, false)
	_expect(combat.living("ally").size() == 13 and combat.capacity_used("ally") == 4.0,
		"12 familiers (taille −3 : ¼ de place) + le héros = 4 places, pas plus")
	_expect(combat.action_unavailable_reason(combat.hero, familiar) != "", "plus d'invocation sans place")
	var summon := combat.living("ally")[1]
	var summon_beats: Array[Dictionary] = await combat.ai_turn(summon)
	_expect(not summon.is_player_controlled() and not summon_beats.is_empty(), "l'invocation joue seule")
	Game.combat = null
	_expect(Combat.size_slots(2) == 2.0 and Combat.size_slots(-1) == 0.5 and Combat.size_slots(9) == 4.0, "places selon la taille")
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
	_expect(combat.action_choices(ally).any(func(c): return c["action"]["id"] == "poisoned_blade"),
		"le compagnon a les actions de sa classe")
	var choice := combat.auto_choice(ally)
	var ally_beats: Array[Dictionary] = await combat.perform(ally, choice["action"], choice["target"])
	_expect(not ally_beats.is_empty(), "le compagnon agit")
	# Le compagnon tombe pendant un combat mortel : inconscient, il est ramené à lui après la victoire.
	ally.hp = 0
	combat.enemies()[0].hp = 0
	combat.outcome = "victory"
	var result := Game.finish_combat()
	_expect(life.companions.size() == 1 and life.companions[0].hp == 1 and result["lines"].has("Mira reprend connaissance."),
		"compagnon inconscient, ramené à lui après la victoire")
	# Tout le groupe tombe dans un combat mortel : c'est la mort.
	combat = Game.start_combat({"enemies": ["wolf"]})
	combat.allies()[1].hp = 0
	combat.hero.hp = 0
	combat._check_end()
	result = Game.finish_combat()
	_expect(Game.life.dead and life.companions.is_empty() and result["lines"].has("Mira a péri au combat."),
		"tout le groupe tombe : mort du héros et du compagnon")
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
				result = await _auto_combat(result["combat"])
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
	var looks_differ := {}
	for style in PixelArt.HAIR_STYLES:
		for body in ["slim", "broad"]:
			var look := {"hair_style": style, "body": body, "skin": "#d9a57b", "hair": "#c8462a", "eyes": "#3a8ac0", "beard": false, "headgear": false}
			looks_differ[PixelArt.portrait(DB.species["human"]["art"], DB.classes["fighter"]["art"], "adult", 7, true, look).get_data()] = true
	_expect(looks_differ.size() == PixelArt.HAIR_STYLES.size() * 2, "apparence : chaque coupe et corpulence se voit")
	_expect(ArtProvider.portrait(c) != null, "ArtProvider fournit un portrait")
	for kind in ["forest", "town", "home", "unknown"]:
		_expect(PixelArt.scene(kind, "evening", 3).get_width() == PixelArt.SCENE_W, "décor %s généré" % kind)
	return true
