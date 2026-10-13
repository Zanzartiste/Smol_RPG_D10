class_name DiceTray
extends Control
## Plateau de lancer de dés animé : les dés sont jetés sur la table, glissent, tournent,
## rebondissent sur les bords et entre eux, puis s'immobilisent sur leur résultat.
## Usage : `await dice_tray.play(roll)`, ou `play(roll, true)` pour un lancer rapide (ennemis, dégâts).
## Un clic ou une touche accélère l'animation (voir skip()).
##
## `roll` : {"dice": [{"sides": 20, "value": 14, "dropped"?: true}, ...], "mod": 2, "stat": "Athlétisme",
##           "dc": 13, "dc_label": "CA", "success": true}  (dc, dc_label, success et stat sont facultatifs)

signal finished

const DIE_RADIUS := 34.0
const FRICTION := 0.15  # part de la vitesse conservée au bout d'une seconde
const BOUNCE := 0.55  # part de la vitesse conservée lors d'un rebond
const SETTLE_SPEED := 45.0  # en dessous (px/s), le dé s'immobilise
const RESULT_TIME := 1.2  # durée d'affichage du verdict
const NUMBER_SIZE := 26

const BODY := Color("#e9dcc0")
const INK := Color("#3a1d14")

var _dice: Array[Dictionary] = []
var _roll: Dictionary = {}
var _phase := 0  # 0 inactif, 1 roulement, 2 verdict
var _friction := FRICTION
var _result_time := RESULT_TIME
var _result_timer := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(false)
	_rng.randomize()


func is_playing() -> bool:
	return _phase != 0


func play(roll: Dictionary, fast := false) -> void:
	_roll = roll
	_friction = 0.02 if fast else FRICTION
	_result_time = 0.6 if fast else RESULT_TIME
	_dice.clear()
	var specs: Array = roll.get("dice", [])
	for i in specs.size():
		var sides := int(specs[i]["sides"])
		var lane := (i - (specs.size() - 1) / 2.0) * DIE_RADIUS * 1.8
		_dice.append({
			"sides": sides,
			"value": int(specs[i]["value"]),
			"dropped": specs[i].get("dropped", false),  # dé écarté (avantage ou désavantage)
			"shown": _rng.randi_range(1, sides),
			"pos": Vector2(_play_area().position.x, clampf(_play_area().get_center().y + lane,
				_play_area().position.y, _play_area().end.y)),
			"vel": Vector2.from_angle(_rng.randf_range(-0.5, 0.5)) * _rng.randf_range(750.0, 1050.0),
			"angle": _rng.randf_range(0.0, TAU),
			"spin": _rng.randf_range(-16.0, 16.0),
			"flicker": 0.0,
			"settled": false,
			"target_angle": 0.0,
			"pop": 0.0,
		})
	_phase = 1
	visible = true
	set_process(true)
	queue_redraw()
	await finished


## Zone où peuvent se trouver les centres des dés : tout le plateau, sauf la bande de la notation
## en haut et celle du verdict en bas.
func _play_area() -> Rect2:
	var top := 48.0 + DIE_RADIUS
	var bottom := 44.0 + DIE_RADIUS
	return Rect2(DIE_RADIUS, top, maxf(0.0, size.x - DIE_RADIUS * 2.0), maxf(0.0, size.y - top - bottom))


## Premier appel : immobilise les dés. Second appel : passe le verdict.
func skip() -> void:
	if _phase == 1:
		for d in _dice:
			if not d["settled"]:
				_settle(d)
		_phase = 2
		_result_timer = 0.6
	elif _phase == 2:
		_result_timer = 0.0


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		skip()
		accept_event()


func _process(delta: float) -> void:
	for d in _dice:
		_step(d, delta)
	_collide()
	if _phase == 1 and _dice.all(func(d): return d["settled"]):
		_phase = 2
		_result_timer = _result_time
	elif _phase == 2:
		_result_timer -= delta
		if _result_timer <= 0.0:
			_phase = 0
			visible = false
			set_process(false)
			finished.emit()
	queue_redraw()


func _step(d: Dictionary, delta: float) -> void:
	if d["settled"]:
		d["angle"] = lerp_angle(d["angle"], d["target_angle"], 1.0 - pow(0.0005, delta))
		d["pop"] = maxf(0.0, d["pop"] - delta * 3.0)
		return
	d["pos"] += d["vel"] * delta
	d["angle"] += d["spin"] * delta
	var pos: Vector2 = d["pos"]
	var vel: Vector2 = d["vel"]
	var area := _play_area()
	if pos.x < area.position.x or pos.x > area.end.x:
		vel.x = (absf(vel.x) if pos.x < area.position.x else -absf(vel.x)) * BOUNCE
		pos.x = clampf(pos.x, area.position.x, area.end.x)
		d["spin"] *= -0.7
	if pos.y < area.position.y or pos.y > area.end.y:
		vel.y = (absf(vel.y) if pos.y < area.position.y else -absf(vel.y)) * BOUNCE
		pos.y = clampf(pos.y, area.position.y, area.end.y)
		d["spin"] *= -0.7
	var damp := pow(_friction, delta)
	d["pos"] = pos
	d["vel"] = vel * damp
	d["spin"] *= damp
	# Les faces défilent vite au début, puis de plus en plus lentement.
	d["flicker"] -= delta
	if d["flicker"] <= 0.0:
		d["shown"] = wrapi(d["shown"] + _rng.randi_range(1, d["sides"] - 1), 1, d["sides"] + 1)
		d["flicker"] = lerpf(0.2, 0.04, clampf(vel.length() / 900.0, 0.0, 1.0))
	if vel.length() < SETTLE_SPEED:
		_settle(d)


func _settle(d: Dictionary) -> void:
	d["settled"] = true
	d["shown"] = d["value"]
	d["vel"] = Vector2.ZERO
	d["pop"] = 1.0
	var symmetry := TAU / _shape(d["sides"]).size()
	d["target_angle"] = round(d["angle"] / symmetry) * symmetry


## Chocs entre dés : on les sépare et on échange leurs vitesses le long de l'axe de contact.
func _collide() -> void:
	for i in _dice.size():
		for j in range(i + 1, _dice.size()):
			var a := _dice[i]
			var b := _dice[j]
			var delta: Vector2 = b["pos"] - a["pos"]
			var dist := delta.length()
			if dist >= DIE_RADIUS * 1.8 or dist == 0.0:
				continue
			var n := delta / dist
			var overlap := DIE_RADIUS * 1.8 - dist
			a["pos"] -= n * overlap * 0.5
			b["pos"] += n * overlap * 0.5
			var va: float = a["vel"].dot(n)
			var vb: float = b["vel"].dot(n)
			if va - vb > 0.0:
				a["vel"] += n * (vb - va)
				b["vel"] += n * (va - vb)
				a["spin"] *= -1.0
				b["spin"] *= -1.0


# --- Dessin ------------------------------------------------------------------

func _draw() -> void:
	if _phase == 0:
		return
	var font := get_theme_default_font()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.04, 0.03, 0.75))
	draw_string(font, Vector2(16, 32), _notation(), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UITheme.GOLD)
	if _roll.has("dc"):
		draw_string(font, Vector2(0, 32), "%s %d" % [_roll.get("dc_label", Loc.ui("DD")), _roll["dc"]], HORIZONTAL_ALIGNMENT_RIGHT,
			size.x - 16, 22, UITheme.GOLD)
	for d in _dice:
		_draw_die(d, font)
	if _phase == 2:
		_draw_verdict(font)


func _draw_die(d: Dictionary, font: Font) -> void:
	var sides: int = d["sides"]
	var radius: float = DIE_RADIUS * (1.0 + 0.25 * d["pop"])
	var body := BODY
	var ink := INK
	if d["settled"] and d["dropped"]:
		body = BODY.darkened(0.55)
		ink = INK.lightened(0.35)
	elif d["settled"] and sides == 20 and d["value"] == 20:
		body = UITheme.GOLD.lightened(0.25)
	elif d["settled"] and sides == 20 and d["value"] == 1:
		body = Color("#b8452f")
		ink = Color("#fff3e0")
	var shape := _shape(sides)
	var outline := shape.duplicate()
	outline.append(shape[0])

	draw_set_transform(d["pos"] + Vector2(5, 7), d["angle"], Vector2.ONE * radius)
	draw_colored_polygon(shape, Color(0, 0, 0, 0.4))
	draw_set_transform(d["pos"], d["angle"], Vector2.ONE * radius)
	draw_colored_polygon(shape, body)
	for segment in _facets(sides):
		draw_line(segment[0], segment[1], body.darkened(0.3), 0.04, true)
	draw_polyline(outline, ink, 0.07, true)

	# Le chiffre tourne avec le dé, mais revient droit quand le dé s'immobilise sur une face.
	var symmetry := TAU / shape.size()
	var text_angle := wrapf(d["angle"], -symmetry / 2.0, symmetry / 2.0)
	var text := str(d["shown"])
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, NUMBER_SIZE)
	draw_set_transform(d["pos"], text_angle, Vector2.ONE * (1.0 + 0.25 * d["pop"]))
	draw_string(font, Vector2(-text_size.x / 2.0, NUMBER_SIZE * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		NUMBER_SIZE, ink)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_verdict(font: Font) -> void:
	var total := 0
	var parts := PackedStringArray()
	var kept: Array[Dictionary] = []
	for d in _dice:
		if d["dropped"]:
			continue
		kept.append(d)
		total += int(d["value"])
		parts.append(str(d["value"]))
	var mod := int(_roll.get("mod", 0))
	var line := " + ".join(parts)
	if mod != 0:
		line += (" + %d" if mod > 0 else " − %d") % absi(mod)
	if mod != 0 or kept.size() > 1:
		line += " = %d" % (total + mod)
	var y := size.y - 18.0
	draw_string(font, Vector2(16, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, UITheme.TEXT)
	if _roll.has("success"):
		var ok: bool = _roll["success"]
		var is_attack: bool = _roll.get("dc_label", "") == "CA"
		var verdict := Loc.ui("RÉUSSITE") if ok else Loc.ui("ÉCHEC")
		if is_attack:
			verdict = Loc.ui("TOUCHÉ") if ok else Loc.ui("RATÉ")
		var natural: int = kept[0]["value"] if kept.size() == 1 and kept[0]["sides"] == 20 else 0
		if natural == 20:
			verdict = Loc.ui("CRITIQUE !") if is_attack else Loc.ui("20 NATUREL !")
		elif natural == 1:
			verdict = Loc.ui("1 NATUREL…")
		draw_string(font, Vector2(0, y), verdict, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 16, 30,
			UITheme.GOOD if ok else UITheme.BAD)


## Notation des dés lancés, ex. « Athlétisme : 1d20 + 2 ».
func _notation() -> String:
	var counts := {}
	var dropped := 0
	for d in _dice:
		counts[d["sides"]] = int(counts.get(d["sides"], 0)) + 1
		dropped += 1 if d["dropped"] else 0
	var parts := PackedStringArray()
	for sides in counts:
		parts.append("%dd%d" % [counts[sides], sides])
	var text := " + ".join(parts)
	if dropped > 0:
		text = Loc.ui("2d20, on garde le %s") % (Loc.ui("meilleur") if _roll.get("advantage", 0) > 0 else Loc.ui("pire"))
	var mod := int(_roll.get("mod", 0))
	if mod != 0:
		text += (" + %d" if mod > 0 else " − %d") % absi(mod)
	if _roll.has("stat"):
		text = "%s : %s" % [_roll["stat"], text]
	return text


## Silhouette d'un dé vu de dessus, dans un cercle de rayon 1.
static func _shape(sides: int) -> PackedVector2Array:
	match sides:
		4:
			return _regular(3)
		6:
			return _regular(4, PI / 4.0)
		8:
			return PackedVector2Array([Vector2(0, -1.05), Vector2(0.85, 0), Vector2(0, 1.05), Vector2(-0.85, 0)])
		10:
			return PackedVector2Array([Vector2(0, -1), Vector2(0.92, -0.1), Vector2(0, 0.9), Vector2(-0.92, -0.1)])
		12:
			return _regular(5)
		20:
			return _regular(6)
	return _regular(8, PI / 8.0)


## Arêtes intérieures, pour donner du volume.
static func _facets(sides: int) -> Array:
	var segments := []
	match sides:
		20:
			var outer := _regular(6)
			var inner := _regular(3, -PI / 2.0, 0.55)
			segments.append_array(_loop(inner))
			for i in 3:
				var a := -PI / 2.0 + i * TAU / 3.0
				for v in outer:
					if absf(angle_difference(v.angle(), a)) < PI / 3.0 + 0.01:
						segments.append([inner[i], v])
		12:
			var outer := _regular(5)
			var inner := _regular(5, -PI / 2.0, 0.55)
			segments.append_array(_loop(inner))
			for i in 5:
				segments.append([inner[i], outer[i]])
		8:
			segments.append([Vector2(-0.85, 0), Vector2(0.85, 0)])
		10:
			segments.append([Vector2(0, -1), Vector2(0, 0.9)])
		4:
			for v in _regular(3):
				segments.append([Vector2.ZERO, v])
	return segments


static func _regular(n: int, start := -PI / 2.0, radius := 1.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in n:
		points.append(Vector2.from_angle(start + i * TAU / n) * radius)
	return points


static func _loop(points: PackedVector2Array) -> Array:
	var segments := []
	for i in points.size():
		segments.append([points[i], points[(i + 1) % points.size()]])
	return segments
