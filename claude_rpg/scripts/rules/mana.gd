class_name Mana
extends RefCounted
## Mana façon Magic: The Gathering. Couleurs : data/mana_colors.json (W, U, B, R, G), plus l'incolore « C ».
##
## Coût d'une carte : chaîne de symboles, ex. « {1}{R} », « {2}{U}{U} », « {C} », « {U}{B} ».
##   {N}  coût générique : payable avec n'importe quel mana
##   {C}  coût incolore : payable uniquement avec du mana incolore
##   {R}  coût coloré   : payable uniquement avec du mana de cette couleur
##
## Réserve (pool) : {"R": 1, "W": 1, "C": 1} ; elle se remplit au début de chaque tour du héros
## (Mana.generate) et le mana non dépensé est perdu.
## Génération : au tour N, N mana (plafonné), répartis selon la part de chaque couleur dans le deck
## (une carte multicolore compte pour moitié dans chaque couleur, une carte sans couleur compte comme
## incolore). Chaque part est arrondie à l'inférieur ; le reste devient du mana incolore (« générique »).
## Ex. deck 50 % blanc / 50 % vert : tour 1 -> {C} ; tour 2 -> {W}{G} ; tour 3 -> {W}{G}{C}.

const COLORLESS := "C"
const GENERIC := "generic"

static var _token_regex := RegEx.create_from_string("\\{([^}]*)\\}")


# --- Couleurs ----------------------------------------------------------------

static func color_ids() -> Array[String]:
	var result: Array[String] = []
	result.assign(DB.mana_colors.keys())
	return result


static func is_color(id: String) -> bool:
	return DB.mana_colors.has(id)


static func color_name(id: String) -> String:
	if id == COLORLESS:
		return Loc.ui("Incolore")
	return DB.mana_colors.get(id, {}).get("name", id)


static func color_value(id: String) -> Color:
	if id == COLORLESS or id == GENERIC:
		return Color("#b8b2a6")
	return Color(String(DB.mana_colors.get(id, {}).get("color", "#b8b2a6")))


## Couleur du texte à poser sur une pastille de cette couleur.
static func ink_value(id: String) -> Color:
	if id == COLORLESS or id == GENERIC:
		return Color("#2a2620")
	return Color(String(DB.mana_colors.get(id, {}).get("ink", "#000000")))


# --- Coûts -------------------------------------------------------------------

## « {2}{R}{R} » -> {"generic": 2, "R": 2}
static func parse(cost: String) -> Dictionary:
	var result := {}
	for m in _token_regex.search_all(cost):
		var symbol := m.get_string(1)
		if symbol.is_valid_int():
			result[GENERIC] = int(result.get(GENERIC, 0)) + int(symbol)
		else:
			result[symbol] = int(result.get(symbol, 0)) + 1
	return result


static func is_valid_cost(cost: String) -> bool:
	var rebuilt := ""
	for m in _token_regex.search_all(cost):
		var symbol := m.get_string(1)
		if not (symbol.is_valid_int() or symbol == COLORLESS or is_color(symbol)):
			return false
		rebuilt += m.get_string()
	return rebuilt == cost


## Symboles d'un coût dans l'ordre d'affichage, ex. ["2", "R", "R"].
static func symbols(cost: String) -> Array[String]:
	var result: Array[String] = []
	for m in _token_regex.search_all(cost):
		result.append(m.get_string(1))
	return result


## Valeur de mana totale d'un coût (« {2}{R} » -> 3).
static func mana_value(cost: String) -> int:
	return total(parse(cost))


## Couleurs d'un coût (sans doublon, sans l'incolore).
static func colors_of(cost: String) -> Array[String]:
	var result: Array[String] = []
	for symbol in symbols(cost):
		if is_color(symbol) and symbol not in result:
			result.append(symbol)
	return result


# --- Réserve -----------------------------------------------------------------

static func total(pool: Dictionary) -> int:
	var sum := 0
	for key in pool:
		sum += int(pool[key])
	return sum


static func can_pay(pool: Dictionary, cost: String) -> bool:
	return pay(pool, cost)["ok"]


## Paie un coût. Retourne {"ok": bool, "pool": réserve restante}.
## Les symboles colorés et incolores sont payés en premier ; le générique ensuite, avec l'incolore
## d'abord puis la couleur la plus abondante (pour garder un maximum de choix).
static func pay(pool: Dictionary, cost: String) -> Dictionary:
	var left := pool.duplicate()
	var needs := parse(cost)
	for symbol: String in needs:
		if symbol == GENERIC:
			continue
		if int(left.get(symbol, 0)) < int(needs[symbol]):
			return {"ok": false, "pool": pool}
		left[symbol] = int(left[symbol]) - int(needs[symbol])
	var generic := int(needs.get(GENERIC, 0))
	while generic > 0:
		var source := COLORLESS if int(left.get(COLORLESS, 0)) > 0 else ""
		if source == "":
			for key: String in left:
				if int(left[key]) > 0 and (source == "" or int(left[key]) > int(left[source])):
					source = key
		if source == "":
			return {"ok": false, "pool": pool}
		left[source] = int(left[source]) - 1
		generic -= 1
	for key in left.keys():
		if int(left[key]) <= 0:
			left.erase(key)
	return {"ok": true, "pool": left}


## Part de chaque couleur (et de l'incolore « C ») dans un deck {id de carte: nombre}.
static func deck_shares(deck: Dictionary) -> Dictionary:
	var weights := {}
	var count := 0
	for card_id: String in deck:
		var n := int(deck[card_id])
		var colors := Cards.colors_of(card_id)
		if colors.is_empty():
			colors = [COLORLESS]
		for color in colors:
			weights[color] = float(weights.get(color, 0.0)) + float(n) / colors.size()
		count += n
	var shares := {}
	for color: String in weights:
		shares[color] = weights[color] / maxf(1.0, count)
	return shares


## Mana généré pour un montant donné et des parts de couleurs (voir deck_shares).
static func generate(amount: int, shares: Dictionary) -> Dictionary:
	var pool := {}
	var given := 0
	for color: String in shares:
		var n := floori(float(shares[color]) * amount + 0.0001)
		if n > 0:
			pool[color] = n
			given += n
	if amount > given:
		pool[COLORLESS] = int(pool.get(COLORLESS, 0)) + amount - given
	return pool


## Réserve lisible, ex. « {R}{W}{C} ».
static func pool_text(pool: Dictionary) -> String:
	var text := ""
	for color in color_ids() + [COLORLESS]:
		for i in int(pool.get(color, 0)):
			text += "{%s}" % color
	return text
