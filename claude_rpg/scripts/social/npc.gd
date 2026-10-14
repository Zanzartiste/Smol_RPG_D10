class_name Npc
extends RefCounted
## Un personnage non joueur du monde (forgeronne, garde, villageois…). Il appartient au monde (Meta.npcs) :
## il survit à la mort du héros et se souvient des vies précédentes. Il est généré progressivement
## (voir Social) : nom, rôle, espèce et un trait visible à la rencontre ; les faits (famille, rêve,
## secret…) n'existent qu'une fois révélés, et deviennent alors définitifs.

var id := ""
var name := ""
var role := ""  # id de npc_roles.json
var location := ""  # lieu où on le trouve ("party" s'il a rejoint le groupe)
var species := "human"
var gender := "nonbinary"
var birth_day := 0  # jour du monde de sa naissance (Meta.world_day)
var traits: Array[String] = []  # traits de personnalité (traits.json)
var known_traits: Array[String] = []  # traits connus du joueur (les traits cachés se découvrent)
var likes: Array[String] = []  # catégories d'objets appréciées en cadeau
var dislikes: Array[String] = []
var abilities: Dictionary = {}
var skill_bonus: Dictionary = {}  # rangs en plus (id de compétence -> rangs)
var languages: Array[String] = ["common"]
var facts: Dictionary = {}  # type de fait -> texte, une fois révélé
var memories: Array[Dictionary] = []  # [{"day", "text"}] : ce dont il se souvient (vies passées comprises)
var relations: Dictionary = {}  # id de PNJ -> {"friendship", "love", "trust", "kind": family|friend|partner|rival}
## Relation avec le héros de la vie en cours (remise à zéro à chaque nouvelle vie).
var player: Dictionary = {}
var inventory: Dictionary = {}  # objets (PNJ sans boutique)
var gold := 0
var alive := true
var art_seed := 0
var parents: Array[String] = []  # ids de PNJ, ou "hero:<nom>" pour un enfant du héros


static func new_player_relation() -> Dictionary:
	return {"met": false, "friendship": 0, "love": 0, "trust": 0, "status": "", "open": false, "fear": false}


func _init() -> void:
	player = new_player_relation()


func age(world_day: int) -> int:
	return maxi(0, int((world_day - birth_day) / 365.0))


func role_def() -> Dictionary:
	return DB.npc_roles.get(role, {})


## Lieu où on le trouve à un moment de la journée (npc_roles.json › schedule : {"morning": "forest"…}) ;
## sans emploi du temps, ou hors de son lieu habituel (groupe, déménagement), son lieu tout court.
func location_at(slot_id: String) -> String:
	var schedule: Dictionary = role_def().get("schedule", {})
	if slot_id == "" or location != role_def().get("location", location):
		return location
	return schedule.get(slot_id, location)


func role_name() -> String:
	return Loc.gendered(String(role_def().get("name", role)), gender)


func ability_score(ability_id: String) -> int:
	return int(abilities.get(ability_id, 4))


## Rang d'une compétence : rang de départ (1, 2 si instinctive) + rangs en plus.
func skill_rank(skill_id: String) -> int:
	return Skills.base_rank(skill_id) + int(skill_bonus.get(skill_id, 0))


## Réserve d'un test : [rang] d10 contre le meilleur attribut de la compétence (ou celui imposé).
func skill_pool(skill_id: String, ability := "", bonus := 0) -> Dictionary:
	var used := ability
	if used == "":
		for candidate: String in Skills.abilities_of(skill_id):
			if used == "" or ability_score(candidate) > ability_score(used):
				used = candidate
	return {"count": skill_rank(skill_id) + bonus, "threshold": ability_score(used), "ability": used}


func has_trait(trait_id: String) -> bool:
	return trait_id in traits


## Partenaires PNJ (couples du monde autonome).
func partners() -> Array[String]:
	var result: Array[String] = []
	for other: String in relations:
		if relations[other].get("kind") == "partner":
			result.append(other)
	return result


func remember(world_day: int, text: String) -> void:
	memories.append({"day": world_day, "text": text})


func to_dict() -> Dictionary:
	return {
		"id": id, "name": name, "role": role, "location": location, "species": species, "gender": gender,
		"birth_day": birth_day, "traits": traits, "known_traits": known_traits, "likes": likes, "dislikes": dislikes,
		"abilities": abilities, "skill_bonus": skill_bonus, "languages": languages, "facts": facts,
		"memories": memories, "relations": relations, "player": player, "inventory": inventory, "gold": gold,
		"alive": alive, "art_seed": art_seed, "parents": parents,
	}


static func from_dict(data: Dictionary) -> Npc:
	var n := Npc.new()
	n.id = data.get("id", "")
	n.name = data.get("name", "")
	n.role = data.get("role", "")
	n.location = data.get("location", "")
	n.species = data.get("species", "human")
	n.gender = data.get("gender", "nonbinary")
	n.birth_day = int(data.get("birth_day", 0))
	n.traits.assign(data.get("traits", []))
	n.known_traits.assign(data.get("known_traits", []))
	n.likes.assign(data.get("likes", []))
	n.dislikes.assign(data.get("dislikes", []))
	n.abilities = Character._int_dict(data.get("abilities", {}))
	n.skill_bonus = Character._int_dict(data.get("skill_bonus", {}))
	n.languages.assign(data.get("languages", ["common"]))
	n.facts = data.get("facts", {})
	n.memories.assign(data.get("memories", []))
	n.relations = data.get("relations", {})
	n.player = new_player_relation()
	n.player.merge(data.get("player", {}), true)
	for key in ["friendship", "love", "trust"]:
		n.player[key] = int(n.player[key])
		for other: String in n.relations:
			n.relations[other][key] = int(n.relations[other].get(key, 0))
	n.inventory = Character._int_dict(data.get("inventory", {}))
	n.gold = int(data.get("gold", 0))
	n.alive = data.get("alive", true)
	n.art_seed = int(data.get("art_seed", 0))
	n.parents.assign(data.get("parents", []))
	return n
