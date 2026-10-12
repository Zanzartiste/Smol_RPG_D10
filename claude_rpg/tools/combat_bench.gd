extends Node
## Banc d'équilibrage : joue chaque rencontre des événements de nombreuses fois en automatique,
## pour chaque classe (PV pleins, seul ou avec Mira), et affiche le taux de victoire.
##   godot --headless --path . res://tools/combat_bench.tscn
## Héros et compagnons jouent avec Combat.auto_choice() (action la plus utile), les créatures avec leur IA,
## sans fuite ni objets : c'est une estimation pessimiste. Affiche aussi la durée moyenne en rounds.

const RUNS := 300

var _rounds := 0
var _fights := 0
## Rencontre -> {ennemis, niveau du groupe}
const ENCOUNTERS := {
	"Rats (cave)": {"enemies": ["giant_rat", "giant_rat"], "level": 1},
	"Loup": {"enemies": ["wolf"], "level": 1},
	"Brigands": {"enemies": ["bandit", "bandit"], "level": 1},
	"Colosse (taverne)": {"enemies": ["brute"], "level": 1},
	"Alpha + loup (niv. 2)": {"enemies": ["dire_wolf", "wolf"], "level": 2},
}


func _ready() -> void:
	Saves.enabled = false
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	for with_mira in [false, true]:
		print("\n=== %s ===" % ("Avec Mira" if with_mira else "Seul"))
		var header := "%-24s" % "Rencontre"
		for cls: String in DB.classes:
			header += "%12s" % DB.classes[cls]["name"]
		print(header)
		for label: String in ENCOUNTERS:
			var line := "%-24s" % label
			var encounter: Dictionary = ENCOUNTERS[label]
			for cls: String in DB.classes:
				var wins := 0
				for i in RUNS:
					var life := LifeState.new()
					life.rng.seed = rng.randi()
					life.character = Character.create("human", cls, "Banc")
					if with_mira:
						life.companions.append(Character.create_companion("mira"))
					for member in life.party():
						member.add_xp(int(DB.rules["xp_by_level"][encounter["level"] - 1]) - member.xp)
						member.hp = member.max_hp
					if _fight(encounter["enemies"], life) == "victory":
						wins += 1
				line += "%11d%%" % roundi(100.0 * wins / RUNS)
			print(line + "   (%.1f rounds en moyenne)" % (float(_rounds) / maxi(1, _fights)))
			_rounds = 0
			_fights = 0
	get_tree().quit()


func _fight(enemies: Array, life: LifeState) -> String:
	var combat := Combat.new({"enemies": enemies, "flee": false}, life)
	var guard := 0
	while not combat.is_over() and guard < 300:
		guard += 1
		var actor := combat.current()
		combat.start_turn()
		if not combat.is_over() and not combat.skipped:
			if actor.is_player_controlled():
				var choice := combat.auto_choice(actor)
				combat.perform(actor, choice["action"], choice["target"])
			else:
				combat.ai_turn(actor)
		combat.end_turn()
	_rounds += combat.round_number
	_fights += 1
	return combat.outcome
