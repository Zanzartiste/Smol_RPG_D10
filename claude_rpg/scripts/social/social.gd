class_name Social
extends RefCounted
## API des interactions sociales et du monde autonome. Données : npc_roles.json, traits.json,
## npc_facts.json, social_actions.json, rules.json › social.
##
## - Les PNJ (Npc) appartiennent au monde : Meta.npcs, avec l'horloge du monde Meta.world_day.
## - Génération progressive : un habitué (forgeronne…) est créé à la première visite de son lieu ; on peut
##   « chercher » un garde ou un villageois (créé à la demande) ; les faits sont tirés quand on les apprend.
## - Relation avec le héros : Amitié, Amour, Confiance (−100 à +100) et un statut (ami, en couple, marié…).
## - Une action sociale (social_actions.json) peut demander un test : compétence du héros contre un DD, ou
##   contre un test de Perspicacité du PNJ ("vs"). Traits et humeur du PNJ modifient DD et gains.
## - Chaque jour, le monde vit : les PNJ d'un même lieu se lient (amitiés, rivalités, couples), les enfants
##   naissent ; des rumeurs en informent le héros.

const GAUGES := ["friendship", "love", "trust"]
const GAUGE_NAMES := {"friendship": "Amitié", "love": "Amour", "trust": "Confiance"}
const ROMANTIC_STATUSES := ["dating", "engaged", "married"]
const STATUS_NAMES := {
	"stranger": "Inconnu", "acquaintance": "Connaissance", "friend": "Ami", "close_friend": "Proche",
	"rival": "Rival", "enemy": "Ennemi", "dating": "En couple", "engaged": "Fiancé", "married": "Marié",
}
## Lettres révélées une à une par les rangs de Langues (les plus fréquentes d'abord).
const LETTER_ORDER := "esaitnrulodcmpvqfbghjxyzkw"
const ALPHABET := "abcdefghijklmnopqrstuvwxyz"


static func setting(key: String, default: Variant) -> Variant:
	return DB.rules.get("social", {}).get(key, default)


# --- Registre des PNJ ------------------------------------------------------------------

static func npc(id: String) -> Npc:
	return Meta.npcs.get(id)


static func all_npcs() -> Array[Npc]:
	var result: Array[Npc] = []
	result.assign(Meta.npcs.values())
	return result


## PNJ présents dans un lieu (les habitués sont créés à la première visite).
static func at_location(location_id: String, rng: RandomNumberGenerator) -> Array[Npc]:
	ensure_regulars(location_id, rng)
	var result: Array[Npc] = []
	for n in all_npcs():
		if n.alive and n.location == location_id and n.age(Meta.world_day) >= 1:
			result.append(n)
	return result


static func ensure_regulars(location_id: String, rng: RandomNumberGenerator) -> void:
	for role: Dictionary in DB.npc_roles.values():
		if role.get("regular", false) and role.get("location") == location_id \
				and not all_npcs().any(func(n): return n.role == role["id"]):
			generate(role["id"], rng)


## Rôles qu'on peut « chercher » dans un lieu (garde, villageois…).
static func searchable_roles(location_id: String) -> Array[String]:
	var result: Array[String] = []
	for role: Dictionary in DB.npc_roles.values():
		if role.get("searchable", false) and role.get("location") == location_id:
			result.append(role["id"])
	return result


## PNJ connus du héros (rencontrés dans cette vie).
static func known_npcs() -> Array[Npc]:
	var result: Array[Npc] = []
	for n in all_npcs():
		if n.player.get("met", false) and n.alive:
			result.append(n)
	return result


## Crée un PNJ d'un rôle. `overrides` : name, species, gender, age, location.
static func generate(role_id: String, rng: RandomNumberGenerator, overrides := {}) -> Npc:
	var role: Dictionary = DB.npc_roles.get(role_id, {})
	var fixed: Dictionary = role.get("fixed", {})
	fixed.merge(overrides, true)
	var n := Npc.new()
	Meta.next_npc_id += 1
	n.id = "%s_%d" % [role_id, Meta.next_npc_id]
	n.role = role_id
	n.location = fixed.get("location", role.get("location", "town"))
	n.species = fixed.get("species", _pick(DB.species.keys(), rng))
	n.gender = fixed.get("gender", _pick(DB.rules["genders"], rng)["id"])
	var species: Dictionary = DB.species[n.species]
	var names: Array = species.get("names", ["Sans-Nom"])
	n.name = fixed.get("name", _pick(names, rng))
	var stages: Dictionary = species.get("age_stages", {})
	var adult := int(stages.get("adult", 18))
	var elder := int(stages.get("elder", 60))
	var age := int(fixed.get("age", rng.randi_range(adult, maxi(adult + 1, elder))))
	n.birth_day = Meta.world_day - age * 365 - rng.randi_range(0, 364)
	var trait_ids: Array = DB.traits.keys()
	trait_ids.shuffle()
	for trait_id: String in trait_ids.slice(0, int(setting("traits_per_npc", 2))):
		n.traits.append(trait_id)
	for trait_id in n.traits:
		if not DB.traits[trait_id].get("hidden", false):
			n.known_traits.append(trait_id)
			break
	var categories: Array = Items.CATEGORIES.duplicate()
	n.likes.append(_pick(categories, rng))
	categories.erase(n.likes[0])
	n.dislikes.append(_pick(categories, rng))
	for ability in Abilities.ids():
		n.abilities[ability] = rng.randi_range(3, 6)
	if rng.randf() < float(role.get("foreign_chance", 0.0)):
		var foreign: Array = Skills.languages().map(func(l): return l["id"]).filter(func(id): return id not in Skills.common_languages())
		n.languages = [_pick(foreign, rng)]
	n.inventory = Character._int_dict(role.get("inventory", {}))
	n.gold = maxi(0, int(Dice.roll_expr(String(role.get("gold", "0")), rng)["total"]))
	n.art_seed = rng.randi()
	# Quelques liens avec les habitants du lieu : amitiés et rivalités.
	for other in all_npcs():
		if other.location == n.location and other.alive and rng.randf() < 0.3:
			var value := rng.randi_range(-40, 50)
			_link(n, other, "friend" if value >= 0 else "rival", value)
	Meta.npcs[n.id] = n
	return n


static func _link(a: Npc, b: Npc, kind: String, friendship: int, love := 0) -> void:
	a.relations[b.id] = {"friendship": friendship, "love": love, "trust": friendship / 2, "kind": kind}
	b.relations[a.id] = {"friendship": friendship, "love": love, "trust": friendship / 2, "kind": kind}


static func _pick(list: Array, rng: RandomNumberGenerator) -> Variant:
	return list[rng.randi_range(0, list.size() - 1)]


# --- Relation avec le héros ------------------------------------------------------------

## Première rencontre : la réputation du héros dans le lieu colore l'accueil (Amitié de départ).
static func meet(n: Npc, life: LifeState) -> void:
	if n.player.get("met", false):
		return
	n.player["met"] = true
	n.player["last_seen"] = Meta.world_day
	change(n, "friendship", int(life.reputation.get(n.location, 0)) / 4)

static func status(n: Npc) -> String:
	if n.player.get("status", "") in ROMANTIC_STATUSES:
		return n.player["status"]
	if not n.player.get("met", false):
		return "stranger"
	var friendship := int(n.player["friendship"])
	if friendship >= 60:
		return "close_friend"
	if friendship >= 30:
		return "friend"
	if friendship <= -60:
		return "enemy"
	if friendship <= -30:
		return "rival"
	return "acquaintance"


static func status_name(n: Npc) -> String:
	var text: String = Loc.gendered({"engaged": "Fiancé{g:|e|·e}", "married": "Marié{g:|e|·e}", "friend": "Ami{g:|e|·e}",
		"enemy": "Ennemi{g:|e|·e}"}.get(status(n), STATUS_NAMES.get(status(n), "")), n.gender)
	if n.player.get("open", false):
		text += Loc.ui(" (relation libre)")
	return text


static func change(n: Npc, gauge: String, amount: int) -> void:
	n.player[gauge] = clampi(int(n.player[gauge]) + amount, -100, 100)


# --- Humeur et traits --------------------------------------------------------------------

## Humeur du jour (déterministe pour un PNJ et un jour) : {"id", "name", "difficulty", "gain"}.
static func mood(n: Npc) -> Dictionary:
	var moods: Array = setting("moods", [{"id": "neutral", "name": "neutre", "difficulty": 0, "gain": 1.0}])
	var weights: Array = moods.map(func(m): return float(m.get("weight", 1)))
	var total := 0.0
	for w in weights:
		total += w
	var r := float(absi(hash("%s:%d" % [n.id, Meta.world_day])) % 1000) / 1000.0 * total
	for i in moods.size():
		r -= weights[i]
		if r < 0.0:
			return moods[i]
	return moods.back()


## Modificateur de difficulté et multiplicateur de gains d'une action selon les traits du PNJ.
static func trait_reaction(n: Npc, action_id: String) -> Dictionary:
	var difficulty := 0
	var gain := 1.0
	for trait_id in n.traits:
		var reaction: Dictionary = DB.traits.get(trait_id, {}).get("reactions", {}).get(action_id, {})
		difficulty += int(reaction.get("difficulty", 0))
		gain *= float(reaction.get("gain", 1.0))
	return {"difficulty": difficulty, "gain": gain}


## Perspicacité passive à la rencontre : humeur détectée, puis un trait caché révélé.
## Retourne {"mood": bool, "trait": id révélé ou ""}.
static func read_npc(ch: Character, n: Npc) -> Dictionary:
	var passive := ch.passive("insight")
	var guard_pool := n.skill_pool("persuasion")
	var guard := roundi(Dice.expected(int(guard_pool["count"]), int(guard_pool["threshold"])))
	var result := {"mood": passive >= guard, "trait": ""}
	if passive >= guard + 2:
		for trait_id in n.traits:
			if trait_id not in n.known_traits:
				n.known_traits.append(trait_id)
				result["trait"] = trait_id
				break
	return result


# --- Langues -----------------------------------------------------------------------------

static func shares_language(ch: Character, n: Npc) -> bool:
	return n.languages.any(func(l): return l in ch.known_languages())


## Paroles d'un PNJ : le texte entre « » est crypté si le héros ne parle pas sa langue ; chaque rang de
## Langues révèle une lettre (les plus fréquentes d'abord).
static func speak(text: String, ch: Character, n: Npc, understood := false) -> String:
	if understood or shares_language(ch, n):
		return text
	var rank := ch.skill_rank("languages")
	var regex := RegEx.create_from_string("«([^»]*)»")
	var result := text
	for m in regex.search_all(text):
		result = result.replace(m.get_string(1), scramble(m.get_string(1), rank, n.languages[0]))
	return result


## Crypte un texte : les lettres non révélées sont remplacées par un alphabet propre à la langue.
static func scramble(text: String, rank: int, language: String) -> String:
	var revealed := LETTER_ORDER.substr(0, clampi(rank, 0, LETTER_ORDER.length()))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(language)
	var cipher := ALPHABET.split("")
	for i in range(cipher.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: String = cipher[i]
		cipher[i] = cipher[j]
		cipher[j] = tmp
	var result := ""
	for c in text:
		var base := _base_letter(c.to_lower())
		var index := ALPHABET.find(base)
		if index == -1 or base in revealed:
			result += c
		else:
			var code: String = cipher[index]
			result += code.to_upper() if c != c.to_lower() else code
	return result


static func _base_letter(c: String) -> String:
	return {"é": "e", "è": "e", "ê": "e", "ë": "e", "à": "a", "â": "a", "î": "i", "ï": "i", "ô": "o", "ù": "u",
		"û": "u", "ç": "c"}.get(c, c)


# --- Actions -------------------------------------------------------------------------------

static func action(id: String) -> Dictionary:
	return DB.social_actions.get(id, {})


static func actions() -> Array:
	return DB.social_actions.values()


## Pourquoi une action est impossible ("" si possible). `session` : état de l'interaction en cours.
static func unavailable_reason(action_id: String, n: Npc, life: LifeState, session: Dictionary) -> String:
	var a := action(action_id)
	var req: Dictionary = a.get("requires", {})
	for gauge in GAUGES:
		if req.has(gauge) and int(n.player[gauge]) < int(req[gauge]):
			return Loc.ui("%s %d requise") % [Loc.ui(GAUGE_NAMES[gauge]), int(req[gauge])]
	if a.has("gold") and life.character.gold < int(a["gold"]):
		return Loc.ui("%d po requises") % int(a["gold"])
	var current := status(n)
	if req.has("status") and current not in req["status"] and not (n.player.get("open") and "open" in req["status"]):
		return Loc.ui("pas avec ce statut")
	if req.has("not_status"):
		if current in req["not_status"] or ("open" in req["not_status"] and n.player.get("open", false)):
			return Loc.ui("déjà fait")
	if a.get("romantic", false):
		var majority := int(DB.rules.get("majority_age", 18))
		if life.character.age_years() < majority or n.age(Meta.world_day) < majority:
			return Loc.ui("réservé aux adultes")
		for trait_id in n.traits:
			if action_id in DB.traits.get(trait_id, {}).get("refuses", []):
				return Loc.ui("%s refuse catégoriquement") % n.name
	match a.get("special", ""):
		"trade":
			if not can_trade(n):
				return Loc.ui("n'a rien à échanger")
		"recruit":
			if not n.role_def().has("class"):
				return Loc.ui("pas aventurier")
			if life.companions.size() >= int(DB.rules.get("max_companions", 1)):
				return Loc.ui("groupe complet")
		"gestures":
			if shares_language(life.character, n) or session.get("understood", false):
				return Loc.ui("vous vous comprenez déjà")
		"child":
			if Meta.pregnancies.any(func(p): return n.id in p.get("parents", [])):
				return Loc.ui("un enfant est déjà en route")
	return ""


## Test d'une action : [rang] d10 du héros contre une difficulté (+ traits et humeur du PNJ), ou en
## opposition contre la compétence "vs" du PNJ (il faut plus de succès que lui ; ses traits et son humeur
## lui ajoutent des dés). Un dé de moins si on ne parle pas la même langue.
## Retourne {"success", "text"}.
static func check(spec: Dictionary, action_id: String, n: Npc, life: LifeState, session: Dictionary) -> Dictionary:
	var ch := life.character
	var skill: String = spec["skill"]
	var language_barrier: bool = skill != "languages" and not shares_language(ch, n) and not session.get("understood", false)
	var pool := ch.skill_pool(skill, spec.get("ability", ""), -1 if language_barrier else 0)
	var roll := Dice.roll_pool(life.rng, int(pool["count"]), int(pool["threshold"]))
	var successes := int(roll["successes"])
	var modifier := int(trait_reaction(n, action_id)["difficulty"]) + int(mood(n).get("difficulty", 0))
	var success := false
	var against := ""
	if spec.has("vs"):
		var npc_pool := n.skill_pool(spec["vs"], "", modifier)
		var npc_roll := Dice.roll_pool(life.rng, int(npc_pool["count"]), int(npc_pool["threshold"]))
		success = successes > int(npc_roll["successes"])
		against = Loc.ui("%s de %s : %d succès") % [Skills.name_of(spec["vs"]), n.name, int(npc_roll["successes"])]
	else:
		var difficulty := maxi(0, Dice.difficulty_of(spec) + modifier)
		success = successes >= difficulty
		against = Loc.ui("difficulté %d") % difficulty
	var text := Loc.ui("%s%s (%s) : %d succès contre %s — %s") % [Skills.name_of(skill),
		Loc.ui(" (barrière de la langue)") if language_barrier else "", Dice.pool_text(int(pool["count"]), int(pool["threshold"])),
		successes, against, Loc.ui("réussi") if success else Loc.ui("raté")]
	return {"success": success, "text": text}


## Joue une action sociale. Retourne {"lines": [...], "open_trade": bool}.
static func perform(action_id: String, n: Npc, life: LifeState, session: Dictionary) -> Dictionary:
	var a := action(action_id)
	var lines: Array[String] = []
	var result := {"lines": lines, "open_trade": false}
	meet(n, life)
	session["acted"] = true
	n.player["last_seen"] = Meta.world_day
	if a.has("gold"):
		life.character.gold -= int(a["gold"])
	session["extra_time"] = int(session.get("extra_time", 0)) + int(a.get("extra_time", 0))
	var success := true
	if a.has("check"):
		var outcome := check(a["check"], action_id, n, life, session)
		success = outcome["success"]
		lines.append("[color=#%s]%s[/color]" % [UITheme.TEXT_DIM.to_html(false), outcome["text"]])
	match a.get("special", ""):
		"reveal_fact":
			var fact := reveal_fact(n, life.rng)
			if fact == "":
				success = false
			else:
				lines.append(fact)
		"trade":
			result["open_trade"] = true
		"recruit":
			var companion := recruit(n, life)
			success = companion != null
		"gestures":
			if success:
				session["understood"] = true
		"child":
			Meta.pregnancies.append({"due": Meta.world_day + int(setting("gestation_days", 270)),
				"parents": ["hero:" + life.character.name, n.id], "species": [life.character.species_id, n.species]})
			n.remember(Meta.world_day, Loc.ui("Attend un enfant avec %s.") % life.character.name)
		"break_up":
			n.player["status"] = ""
			n.player["open"] = false
			n.remember(Meta.world_day, Loc.ui("%s a rompu avec lui.") % life.character.name)
			life.log_journal("social", Loc.ui("Rupture avec %s.") % n.name)
	var effects: Dictionary = a.get("success" if success else "failure", {})
	var gain := float(trait_reaction(n, action_id)["gain"]) * float(mood(n).get("gain", 1.0))
	for gauge in GAUGES:
		if effects.has(gauge):
			var amount := int(effects[gauge])
			change(n, gauge, roundi(amount * gain) if amount > 0 else amount)
	if effects.has("set"):
		if effects["set"] == "open":
			n.player["open"] = true
		else:
			n.player["status"] = effects["set"]
			n.remember(Meta.world_day, Loc.ui("%s avec %s.") % [STATUS_NAMES[effects["set"]], life.character.name])
			life.log_journal("social", Loc.ui("%s avec %s.") % [STATUS_NAMES[effects["set"]], n.name])
	if effects.get("fear", false):
		n.player["fear"] = true
	if effects.has("reputation"):
		change_reputation(life, n.location, int(effects["reputation"]))
	if a.get("romantic", false) and success and effects.has("love"):
		lines.append_array(jealousy(n, life))
	var pool: Array = a.get("lines", {}).get("success" if success else "failure", [])
	if not pool.is_empty():
		lines.append(speak(Loc.gendered(String(_pick(pool, life.rng)).replace("{npc}", n.name), n.gender),
			life.character, n, session.get("understood", false)))
	return result


## Tromper un partenaire : les partenaires sans relation libre l'apprennent parfois (jaloux : plus fort).
static func jealousy(target: Npc, life: LifeState) -> Array[String]:
	var lines: Array[String] = []
	for other in all_npcs():
		if other == target or not other.alive or other.player.get("status", "") not in ROMANTIC_STATUSES or other.player.get("open", false):
			continue
		if life.rng.randf() < float(setting("jealousy_chance", 0.5)):
			var factor := 1.0
			for trait_id in other.traits:
				factor *= float(DB.traits.get(trait_id, {}).get("jealousy", 1.0))
			change(other, "love", -roundi(10 * factor))
			change(other, "trust", -roundi(15 * factor))
			lines.append(Loc.ui("%s a eu vent de votre aventure avec %s…") % [other.name, target.name])
	return lines


# --- Faits révélés ----------------------------------------------------------------------------

## Révèle un nouveau fait sur le PNJ (définitif). Un fait de famille crée un parent du PNJ.
## Retourne le texte, ou "" s'il n'y a plus rien à apprendre.
static func reveal_fact(n: Npc, rng: RandomNumberGenerator) -> String:
	var remaining: Array = DB.npc_facts.values().filter(func(f): return not n.facts.has(f["id"]))
	if remaining.is_empty():
		return ""
	var fact: Dictionary = _pick(remaining, rng)
	var text: String = _pick(fact["values"], rng)
	if fact.get("creates_relative", false):
		var relative := generate("villager", rng, {"location": n.location, "species": n.species})
		relative.languages = n.languages.duplicate()
		_link(n, relative, "family", rng.randi_range(-20, 80))
		var kind: String = {"female": "une sœur", "male": "un frère"}.get(relative.gender, "un·e adelphe")
		text = text.replace("{relative_kind}", kind).replace("{relative}", relative.name)
	text = Loc.gendered(text.replace("{npc}", n.name), n.gender)
	n.facts[fact["id"]] = text
	return text


# --- Recrutement, approbation --------------------------------------------------------------

## Le PNJ rejoint le groupe : un personnage est créé d'après lui (classe de son rôle).
static func recruit(n: Npc, life: LifeState) -> Character:
	var cls: String = n.role_def().get("class", "")
	if cls == "" or life.companions.size() >= int(DB.rules.get("max_companions", 1)):
		return null
	var ch := Character.create(n.species, cls, n.name, {"gender": n.gender})
	ch.npc_id = n.id
	ch.art_seed = n.art_seed
	ch.complete_all_choices()
	life.companions.append(ch)
	n.location = "party"
	n.remember(Meta.world_day, Loc.ui("A rejoint le groupe de %s.") % life.character.name)
	return ch


## PNJ lié à un compagnon (créé au besoin : Mira…).
static func npc_for_companion(ch: Character) -> Npc:
	if ch.npc_id != "" and Meta.npcs.has(ch.npc_id):
		return Meta.npcs[ch.npc_id]
	var n := Npc.new()
	n.id = ch.template_id if ch.template_id != "" else "companion_%s" % ch.name
	n.name = ch.name
	n.role = "companion"
	n.location = "party"
	n.species = ch.species_id
	n.gender = ch.gender
	n.birth_day = Meta.world_day - ch.age_years() * 365
	n.abilities = ch.abilities.duplicate()
	n.player["met"] = true
	n.player["friendship"] = int(setting("companion_start_friendship", 20))
	Meta.npcs[n.id] = n
	ch.npc_id = n.id
	return n


## Approbation des compagnons (champ "approval" d'un choix : {"mira": 3}). Un compagnon dont l'Amitié
## tombe sous le seuil quitte le groupe. Retourne les lignes à afficher.
static func approve(life: LifeState, approval: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	for companion in life.companions.duplicate():
		var key: String = companion.template_id if companion.template_id != "" else companion.npc_id
		if not approval.has(key):
			continue
		var n := npc_for_companion(companion)
		var amount := int(approval[key])
		change(n, "friendship", amount)
		lines.append(Loc.ui("%s %s.") % [companion.name, Loc.ui("approuve") if amount > 0 else Loc.ui("désapprouve")])
		if int(n.player["friendship"]) <= int(setting("leave_threshold", -50)):
			life.companions.erase(companion)
			n.location = DB.location_order[0]
			lines.append(Loc.ui("%s en a assez et quitte le groupe.") % companion.name)
	return lines


# --- Commerce et cadeaux ----------------------------------------------------------------------

static func can_trade(n: Npc) -> bool:
	return n.role_def().has("shop") or not n.inventory.is_empty() or n.gold > 0


## Marchandises du PNJ : le stock de sa boutique, ou son propre inventaire.
static func goods(n: Npc, life: LifeState) -> Dictionary:
	var shop: String = n.role_def().get("shop", "")
	return life.shop_stock(shop) if shop != "" else n.inventory


## Remise d'amitié : 5 % pour un ami, 10 % pour un proche.
static func friendship_discount(n: Npc) -> float:
	return {"friend": 0.05, "close_friend": 0.1}.get(status(n), 0.0)


static func buy_price(n: Npc, item_id: String, life: LifeState) -> int:
	var base := Shops.buy_price(n.role_def().get("shop", ""), item_id, life, n.location)
	return maxi(1, roundi(base * (1.0 - friendship_discount(n))))


static func sell_price(n: Npc, item_id: String, life: LifeState) -> int:
	return roundi(Shops.sell_price(item_id, life, n.location) * (1.0 + friendship_discount(n)))


## Achat auprès d'un PNJ ; son or augmente (sauf boutique).
static func buy(n: Npc, item_id: String, life: LifeState) -> bool:
	var stock := goods(n, life)
	var price := buy_price(n, item_id, life)
	if int(stock.get(item_id, 0)) <= 0 or life.character.gold < price:
		return false
	life.character.gold -= price
	_move(stock, life.character.inventory, item_id)
	if not n.role_def().has("shop"):
		n.gold += price
	life.refresh_load()
	return true


## Vente à un PNJ (limitée par son or, sauf boutique).
static func sell(n: Npc, item_id: String, life: LifeState) -> bool:
	var price := sell_price(n, item_id, life)
	var has_shop: bool = n.role_def().has("shop")
	if life.character.item_count(item_id) <= 0 or not Shops.buys("", item_id) or (not has_shop and n.gold < price):
		return false
	life.character.gold += price
	if not has_shop:
		n.gold -= price
	_move(life.character.inventory, goods(n, life), item_id)
	life.refresh_load()
	return true


## Cadeau : Amitié (et Amour pour un partenaire) selon la valeur et les goûts du PNJ.
static func gift(n: Npc, item_id: String, life: LifeState) -> String:
	if life.character.item_count(item_id) <= 0 or Items.is_quest(item_id):
		return ""
	_move(life.character.inventory, goods(n, life), item_id)
	life.refresh_load()
	var amount := 2.0 + mini(10, Items.value_of(item_id) / 5)
	var category := Items.category_of(item_id)
	var liked: bool = category in n.likes or n.traits.any(func(t): return category in DB.traits.get(t, {}).get("likes", []))
	if liked:
		amount *= 2.0
	elif category in n.dislikes:
		amount *= 0.3
	amount *= float(trait_reaction(n, "gift")["gain"])
	change(n, "friendship", roundi(amount))
	if status(n) in ROMANTIC_STATUSES:
		change(n, "love", roundi(amount / 2.0))
	n.player["met"] = true
	if liked:
		return Loc.ui("%s adore : %s !") % [n.name, Items.name_of(item_id)]
	if category in n.dislikes:
		return Loc.ui("%s accepte %s du bout des doigts.") % [n.name, Items.name_of(item_id)]
	return Loc.ui("%s vous remercie pour : %s.") % [n.name, Items.name_of(item_id)]


## Demander un objet gratuitement : Persuasion contre Perspicacité, plus difficile pour un objet cher.
static func ask_free(n: Npc, item_id: String, life: LifeState, session: Dictionary) -> String:
	var stock := goods(n, life)
	if int(stock.get(item_id, 0)) <= 0:
		return ""
	var spec := {"skill": "persuasion", "vs": "insight"}
	var outcome := check(spec, "ask_free", n, life, session)
	var penalty := Items.value_of(item_id) / 5 - int(n.player["friendship"]) / 20
	var success: bool = outcome["success"] and life.rng.randi_range(0, 10) >= penalty
	if success:
		_move(stock, life.character.inventory, item_id)
		change(n, "friendship", -1)
		life.refresh_load()
		return outcome["text"] + "\n" + Loc.ui("%s vous donne : %s.") % [n.name, Items.name_of(item_id)]
	change(n, "friendship", -3)
	return outcome["text"] + "\n" + Loc.ui("%s refuse de vous le donner.") % n.name


static func _move(from: Dictionary, to: Dictionary, item_id: String) -> void:
	from[item_id] = int(from.get(item_id, 0)) - 1
	if int(from[item_id]) <= 0:
		from.erase(item_id)
	to[item_id] = int(to.get(item_id, 0)) + 1


# --- Réputation ------------------------------------------------------------------------------

static func change_reputation(life: LifeState, location_id: String, amount: int) -> void:
	life.reputation[location_id] = clampi(int(life.reputation.get(location_id, 0)) + amount, -100, 100)


static func reputation_name(value: int) -> String:
	if value >= 20:
		return Loc.ui("Respecté")
	if value >= 5:
		return Loc.ui("Apprécié")
	if value <= -20:
		return Loc.ui("Honni")
	if value <= -5:
		return Loc.ui("Mal vu")
	return Loc.ui("Inconnu")


# --- Monde autonome ---------------------------------------------------------------------------

## Un jour passe dans le monde : liens entre PNJ, couples, naissances. Les rumeurs vont dans les
## notices de la vie en cours.
static func daily_tick(life: LifeState) -> void:
	var by_location := {}
	for n in all_npcs():
		if n.alive and n.location != "party" and n.age(Meta.world_day) >= int(DB.rules.get("majority_age", 18)):
			by_location.get_or_add(n.location, []).append(n)
	for location: String in by_location:
		var people: Array = by_location[location]
		if people.size() < 2:
			continue
		for i in int(setting("daily_pairs", 2)):
			var a: Npc = _pick(people, life.rng)
			var b: Npc = _pick(people, life.rng)
			if a != b:
				_npc_interact(a, b, life)
	_births(life)
	_deaths(life)


## Morts de vieillesse : passé l'âge limite de son espèce (aging_age), un PNJ a chaque année
## old_age_yearly_chance × années de plus de mourir (rules.json › social). Ses proches s'en souviennent ; le
## héros l'apprend s'il le connaissait. Les compagnons du groupe ne meurent pas ainsi.
static func _deaths(life: LifeState) -> void:
	var per_year := float(setting("old_age_yearly_chance", 0.04))
	for n in all_npcs():
		if not n.alive or n.location == "party":
			continue
		var limit := int(DB.species.get(n.species, {}).get("aging_age", 0))
		var over := n.age(Meta.world_day) - limit
		if limit <= 0 or over <= 0:
			continue
		if life.rng.randf() < minf(1.0, per_year * over) / float(DB.days_per_year()):
			die(n, Loc.ui("de vieillesse"), life)


## Un PNJ meurt (`cause` : « de vieillesse »…) : ses proches s'en souviennent, et le héros est prévenu s'il
## le connaissait.
static func die(n: Npc, cause: String, life: LifeState) -> void:
	n.alive = false
	n.remember(Meta.world_day, Loc.ui("Mort %s.") % cause)
	for other_id: String in n.relations:
		var other := npc(other_id)
		if other == null or not other.alive:
			continue
		var kind: String = n.relations[other_id].get("kind", "")
		if kind in ["family", "partner"] or int(n.relations[other_id].get("friendship", 0)) >= 40:
			other.remember(Meta.world_day, Loc.ui("A perdu %s.") % n.name)
	if life != null and n.player.get("met", false):
		var status: String = n.player.get("status", "")
		var close := status in ROMANTIC_STATUSES or int(n.player.get("friendship", 0)) >= 30
		life.notices.append(Loc.ui("%s %s est mort%s %s.") % [Loc.ui("Triste nouvelle :") if close else Loc.ui("On raconte que"),
			n.name, Loc.gendered("{g:|e|·e}", n.gender), cause])


static func _npc_interact(a: Npc, b: Npc, life: LifeState) -> void:
	if not a.relations.has(b.id):
		_link(a, b, "friend", 0)
	var delta := life.rng.randi_range(-2, 3)
	for trait_id in a.traits:
		if trait_id in b.traits:
			delta += 1
	if a.has_trait("grumpy") or b.has_trait("grumpy"):
		delta -= 1
	for pair in [[a, b], [b, a]]:
		var rel: Dictionary = pair[0].relations[pair[1].id]
		rel["friendship"] = clampi(int(rel["friendship"]) + delta, -100, 100)
		if rel.get("kind") == "friend" and int(rel["friendship"]) <= -30:
			rel["kind"] = "rival"
	# Entre amis, on s'offre parfois des objets.
	if int(a.relations[b.id]["friendship"]) >= 40 and not a.inventory.is_empty() and life.rng.randf() < 0.1:
		var item_id: String = _pick(a.inventory.keys(), life.rng)
		_move(a.inventory, b.inventory, item_id)
		b.relations[a.id]["friendship"] = clampi(int(b.relations[a.id]["friendship"]) + 3, -100, 100)
	var rel_ab: Dictionary = a.relations[b.id]
	var single: bool = a.partners().is_empty() and b.partners().is_empty() and a.player.get("status", "") == "" \
		and b.player.get("status", "") == ""
	if single and rel_ab.get("kind") != "family" and int(rel_ab["friendship"]) >= 50:
		for pair in [[a, b], [b, a]]:
			pair[0].relations[pair[1].id]["love"] = int(pair[0].relations[pair[1].id].get("love", 0)) + 3
		if int(a.relations[b.id]["love"]) >= 40:
			a.relations[b.id]["kind"] = "partner"
			b.relations[a.id]["kind"] = "partner"
			life.notices.append(Loc.ui("Rumeur : on raconte que %s et %s se fréquentent.") % [a.name, b.name])


static func _births(life: LifeState) -> void:
	for p: Dictionary in Meta.pregnancies.duplicate():
		if int(p["due"]) > Meta.world_day:
			continue
		Meta.pregnancies.erase(p)
		var parents: Array = p["parents"]
		var parent_npc: Npc = null
		for parent: String in parents:
			if Meta.npcs.has(parent):
				parent_npc = Meta.npcs[parent]
		var species: String = _pick(p.get("species", ["human"]), life.rng)
		var child := generate("villager", life.rng, {"species": species, "age": 0,
			"location": parent_npc.location if parent_npc != null else DB.location_order[0]})
		child.birth_day = Meta.world_day
		child.parents.assign(parents)
		child.languages = parent_npc.languages.duplicate() if parent_npc != null else ["common"]
		if parent_npc != null:
			_link(parent_npc, child, "family", 80)
		var hero_parent: bool = parents.any(func(x): return x == "hero:" + life.character.name)
		if hero_parent:
			child.player["met"] = true
			child.player["friendship"] = 50
			life.notices.append(Loc.ui("Votre enfant est né : %s.") % child.name)
		else:
			life.notices.append(Loc.ui("Une naissance à Brumeval : %s.") % child.name)


# --- Vies successives ------------------------------------------------------------------------

## Mort du héros : les PNJ qui le connaissaient s'en souviennent.
static func on_hero_death(life: LifeState) -> void:
	var ch := life.character
	for n in all_npcs():
		if n.player.get("met", false):
			var bond := status_name(n)
			n.remember(Meta.world_day, Loc.ui("A connu %s (%s), mort à %d ans.") % [ch.name, bond.to_lower(), ch.age_years()])


## Nouvelle vie : les relations avec le héros repartent de zéro (les souvenirs restent).
static func on_new_life() -> void:
	for n in all_npcs():
		if n.location == "party":
			n.location = DB.location_order[0]
		n.player = Npc.new_player_relation()


# --- Initiatives des PNJ ----------------------------------------------------------------------

## Un PNJ connu vient parfois voir le héros (au plus une fois par jour) : un ami demande un service, un
## rival provoque, un partenaire délaissé se plaint. Retourne un événement (même format que les
## événements des données), ou {}.
static func initiative_event(life: LifeState) -> Dictionary:
	if life.last_initiative_day == Meta.world_day or life.rng.randf() >= float(setting("initiative_chance", 0.3)):
		return {}
	life.last_initiative_day = Meta.world_day
	var candidates: Array = []
	for n in known_npcs():
		if n.location == "party":
			continue
		var neglected: bool = status(n) in ROMANTIC_STATUSES and Meta.world_day - int(n.player.get("last_seen", Meta.world_day)) >= int(setting("neglect_days", 7))
		if neglected:
			candidates.append(["neglect", n])
		elif status(n) in ["friend", "close_friend"]:
			candidates.append(["favor", n])
		elif status(n) in ["rival", "enemy"]:
			candidates.append(["rival", n])
	if candidates.is_empty():
		return {}
	var picked: Array = _pick(candidates, life.rng)
	var n: Npc = picked[1]
	var rel := func(changes: Dictionary) -> Dictionary:
		var e := {"type": "npc_relation", "npc": n.id}
		e.merge(changes)
		return e
	match picked[0]:
		"favor":
			return {"id": "npc_favor_" + n.id, "title": Loc.ui("Un service"), "text": Loc.gendered(Loc.ui(
				"%s vient vous trouver : « Tu aurais un moment ? J'aurais besoin d'un coup de main. »") % n.name, n.gender),
				"choices": [
					{"id": "help", "text": Loc.ui("Lui rendre service"), "outcome": {"text": Loc.ui("Vous passez du temps à aider %s, qui vous en est reconnaissant·e.") % n.name,
						"effects": [rel.call({"friendship": 8, "trust": 5}), {"type": "xp", "amount": 10}]}},
					{"id": "refuse", "text": Loc.ui("Refuser poliment"), "outcome": {"text": Loc.ui("%s cache mal sa déception.") % n.name,
						"effects": [rel.call({"friendship": -3})]}}]}
		"rival":
			return {"id": "npc_rival_" + n.id, "title": Loc.ui("Une provocation"), "text": Loc.ui(
				"%s vous bouscule exprès : « Tiens, regardez qui voilà… »") % n.name,
				"choices": [
					{"id": "ignore", "text": Loc.ui("L'ignorer"), "outcome": {"text": Loc.ui("Vous passez votre chemin ; les témoins apprécient votre calme."),
						"effects": [rel.call({"friendship": -2}), {"type": "reputation", "amount": 1, "location": n.location}]}},
					{"id": "retort", "text": Loc.ui("Le remettre à sa place"), "check": {"skill": "persuasion", "ability": "str", "difficulty": 2},
						"success": {"text": Loc.ui("%s recule, mal à l'aise.") % n.name, "effects": [rel.call({"trust": -3})]},
						"failure": {"text": Loc.ui("%s ricane : la foule rit de vous.") % n.name,
							"effects": [rel.call({"friendship": -5}), {"type": "reputation", "amount": -1, "location": n.location}]}}]}
		"neglect":
			return {"id": "npc_neglect_" + n.id, "title": Loc.ui("Des reproches"), "text": Loc.gendered(Loc.ui(
				"%s vous attend, les bras croisés : « On ne te voit plus. Tu m'as oublié{g:|e|·e} ? »") % n.name, n.gender),
				"choices": [
					{"id": "reassure", "text": Loc.ui("Le rassurer"), "check": {"skill": "persuasion", "difficulty": 2},
						"success": {"text": Loc.ui("%s se radoucit et vous serre contre lui·elle.") % n.name, "effects": [rel.call({"love": 5, "trust": 3})]},
						"failure": {"text": Loc.ui("Vos excuses sonnent creux."), "effects": [rel.call({"love": -5, "trust": -3})]}},
					{"id": "time", "text": Loc.ui("Lui consacrer la journée"), "outcome": {"text": Loc.ui("Vous passez la journée ensemble."),
						"effects": [rel.call({"love": 4, "friendship": 2}), {"type": "pass_time", "slots": 2}]}}]}
	return {}


## Ligne d'accueil : salutation selon l'humeur, et parfois un souvenir d'une vie passée.
static func greeting(n: Npc, life: LifeState) -> String:
	var lines: Array = setting("greetings", {}).get(mood(n)["id"], ["« Bonjour. »"])
	var text := "%s : %s" % [n.name, _pick(lines, life.rng)]
	for memory: Dictionary in n.memories:
		if String(memory.get("text", "")).begins_with(Loc.ui("A connu")) and life.rng.randf() < 0.4:
			text += "\n" + Loc.ui("%s vous dévisage : « Vous me rappelez quelqu'un que j'ai connu… »") % n.name
			break
	return speak(text, life.character, n)
