class_name PixelArt
extends RefCounted
## Images pixel art générées par script, en attendant les illustrations définitives.
## Tout est déterministe : mêmes paramètres et même graine => même image.
## ArtProvider utilise automatiquement les vraies images de res://assets/ quand elles existent.

const PORTRAIT_SIZE := 32
const SCENE_W := 160
const SCENE_H := 48
const OUTLINE := Color(0.08, 0.06, 0.05)

## Dégradé du ciel (haut, horizon) selon le moment de la journée.
const SKY := {
	"morning": [Color(0.50, 0.66, 0.82), Color(0.95, 0.84, 0.64)],
	"afternoon": [Color(0.31, 0.56, 0.80), Color(0.75, 0.87, 0.94)],
	"evening": [Color(0.14, 0.11, 0.28), Color(0.85, 0.46, 0.29)],
}


# --- Portraits ---------------------------------------------------------------

## `with_background` = false : personnage détouré (sprites de combat).
static func portrait(species_art: Dictionary, class_art: Dictionary, stage: String, seed_value: int,
		with_background := true) -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var s := PORTRAIT_SIZE
	var fig := Image.create(s, s, false, Image.FORMAT_RGBA8)

	var skin := _pick(species_art.get("skin", ["#d9a57b"]), rng)
	var hair := _pick(species_art.get("hair", ["#3a2b1a"]), rng)
	var eye := _pick(species_art.get("eyes", ["#3b5d8a"]), rng)
	var outfit := Color(String(class_art.get("outfit", "#555560")))
	var accent := Color(String(class_art.get("accent", "#b08d57")))
	var ears: String = species_art.get("ears", "round")
	var headgear: String = class_art.get("headgear", "")
	var hair_style := rng.randi_range(0, 2)  # 0 courts, 1 longs, 2 chauve
	if ears == "goblin" and rng.randf() < 0.4:
		hair_style = 2
	var bearded := ears == "round" and rng.randf() < 0.35
	match stage:
		"elder":
			hair = hair.lerp(Color(0.6, 0.6, 0.6), 0.65)
		"venerable":
			hair = hair.lerp(Color(0.9, 0.9, 0.9), 0.85)
	var child := stage == "child"
	var young := child or stage == "teen"
	if young and hair_style == 2:
		hair_style = 0

	# Géométrie de la tête (centre horizontal = 16, symétrie x <-> 31 - x).
	var hx := 5 if child else 6  # demi-largeur entière de la tête
	var rx := float(hx)
	var ry := 6.0 if child else 7.0
	var cy := 16.0 if child else (14.0 if stage == "teen" else 13.0)
	if ears == "goblin":
		hx += 1
		rx += 1.0
		ry -= 1.0
		cy += 1.0
	var head_top := int(cy - ry)
	var chin := int(cy + ry)
	var ey := int(cy)

	# Buste et cou.
	var torso_top := chin + 1
	var half := 8 if child else 11
	for y in range(torso_top, s):
		var h := half - maxi(0, 2 - (y - torso_top))
		_hline(fig, 16 - h, 15 + h, y, outfit)
		for x in range(19, 16 + h):
			_shade(fig, x, y, 0.2)
	_hline(fig, 14, 17, chin - 1, skin.darkened(0.2))
	_hline(fig, 14, 17, chin, skin.darkened(0.2))
	for i in 2:
		_hline(fig, 14 + i, 17 - i, torso_top + i, skin.darkened(0.2))
	for i in 4:
		_sym(fig, 13 + i, torso_top + i, accent)

	# Arrière-plan de la tête : capuche, cheveux longs, oreilles.
	if headgear == "hood":
		_ellipse(fig, 16.0, cy - 0.5, rx + 2.0, ry + 1.5, outfit.darkened(0.15))
	elif hair_style == 1:
		for y in range(ey - 2, chin + 3):
			_hline(fig, 16 - hx - 1, 15 + hx + 1, y, hair.darkened(0.1))
	_draw_ears(fig, ears, ey, hx, skin)

	# Tête.
	_ellipse(fig, 16.0, cy, rx, ry, skin)
	for y in range(head_top, chin + 1):
		for x in range(17 + int(rx * 0.3), 16 + hx):
			_shade(fig, x, y, 0.12)

	# Cheveux.
	if hair_style != 2 and headgear != "helmet":
		for y in range(head_top - 1, ey - 1):
			for x in s:
				if _inside(x, y, 16.0, cy, rx + 0.5, ry + 0.8) and y <= cy - ry * 0.4:
					fig.set_pixel(x, y, hair)
		for y in range(int(cy - ry * 0.4), ey):
			_sym(fig, 16 - hx, y, hair)

	# Yeux, sourcils, nez, bouche.
	var brow := hair.darkened(0.3) if hair_style != 2 else skin.darkened(0.4)
	if ears == "goblin":
		_sym(fig, 12, ey, eye)
		_sym(fig, 13, ey, eye.lightened(0.4))
		_sym(fig, 12, ey - 1, brow)
		_sym(fig, 13, ey - 2, brow)
		for y in range(ey + 1, ey + 4):
			_hline(fig, 15, 16, y, skin.darkened(0.25))
		_hline(fig, 15, 16, ey + 3, skin.darkened(0.1))
	else:
		_sym(fig, 12, ey, Color(0.91, 0.88, 0.82))
		_sym(fig, 13, ey, eye)
		_hline(fig, 12, 13, ey - 2, brow)
		_hline(fig, 18, 19, ey - 2, brow)
		_px(fig, 16, ey + 1, skin.darkened(0.2))
		_px(fig, 16, ey + 2, skin.darkened(0.25))
	var mouth_y := ey + 4
	if ears == "goblin":
		_hline(fig, 13, 18, mouth_y, skin.darkened(0.5))
		_px(fig, 14, mouth_y + 1, Color(0.94, 0.92, 0.84))
	else:
		_hline(fig, 14, 17, mouth_y, skin.darkened(0.45))

	# Barbe (adultes humains).
	if bearded and not young:
		for y in range(mouth_y - 1, chin + 2):
			for x in s:
				if _inside(x, y, 16.0, cy, rx + 0.3, ry + 1.0):
					fig.set_pixel(x, y, hair)
		_hline(fig, 14, 17, mouth_y, hair.darkened(0.45))

	# Rides.
	if stage in ["elder", "venerable"]:
		_sym(fig, 11, ey + 1, skin.darkened(0.3))
		_sym(fig, 12, ey + 1, skin.darkened(0.2))
		if hair_style == 2 or headgear == "":
			_hline(fig, 14, 17, head_top + 3, skin.darkened(0.2))

	# Couvre-chef de classe.
	match headgear:
		"wizard_hat":
			var brim_y := head_top + 2
			for y in range(0, brim_y):
				var t := float(brim_y - 1 - y) / maxf(1.0, brim_y - 1)
				var w := int(round(lerpf(hx, 0.5, t)))
				var bend := int(t * t * 3.0)
				_hline(fig, 16 - w + bend, 15 + w + bend, y, outfit)
				_px(fig, 15 + w + bend, y, outfit.darkened(0.25))
			_hline(fig, 16 - hx, 15 + hx, brim_y - 1, accent)
			_hline(fig, 16 - hx - 3, 15 + hx + 3, brim_y, outfit.darkened(0.2))
		"helmet":
			var steel := Color(0.54, 0.56, 0.6)
			for y in range(head_top - 1, ey - 1):
				for x in s:
					if _inside(x, y, 16.0, cy, rx + 0.8, ry + 0.8):
						fig.set_pixel(x, y, steel.lightened(0.2) if x < 14 else steel)
			_hline(fig, 16 - hx - 1, 15 + hx + 1, ey - 2, steel.darkened(0.3))
			for y in range(ey - 1, ey + 2):
				_hline(fig, 15, 16, y, steel.darkened(0.1))
			for y in range(head_top - 3, head_top):
				_hline(fig, 15, 16, y, accent)
		"hood":
			for y in range(head_top - 2, head_top + 3):
				for x in s:
					if _inside(x, y, 16.0, cy - 0.5, rx + 2.0, ry + 1.5):
						fig.set_pixel(x, y, outfit.darkened(0.15))
			_hline(fig, 16 - hx + 1, 15 + hx - 1, head_top + 3, skin.darkened(0.35))

	# Contour puis fond.
	var outlined := _outlined(fig)
	if not with_background:
		return outlined
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var bg_top := outfit.darkened(0.8)
	var bg_bottom := outfit.darkened(0.6)
	for y in s:
		for x in s:
			var d := Vector2(x - 15.5, y - 15.5).length() / 22.0
			img.set_pixel(x, y, bg_top.lerp(bg_bottom, y / float(s - 1)).darkened(d * 0.4))
	img.blend_rect(outlined, Rect2i(0, 0, s, s), Vector2i.ZERO)
	return img


@warning_ignore("integer_division")
static func _draw_ears(img: Image, kind: String, ey: int, hx: int, skin: Color) -> void:
	var inner := skin.darkened(0.25)
	match kind:
		"round":
			for y in range(ey - 1, ey + 2):
				_sym(img, 16 - hx - 1, y, skin)
			_sym(img, 16 - hx - 1, ey, inner)
		"elf":
			for i in 5:
				_sym(img, 16 - hx - 1 - i, ey - i, skin)
				_sym(img, 16 - hx - 1 - i, ey - i + 1, inner if i > 0 else skin)
		"goblin":
			for i in range(1, 7):
				var top := ey - 1 - i / 3
				var h := maxi(1, 4 - i / 2)
				for y in range(top, top + h):
					_sym(img, 16 - hx - i + 1, y, skin)
				if h > 2:
					_sym(img, 16 - hx - i + 1, top + 1, inner)


# --- Créatures ---------------------------------------------------------------

## Sprite de combat détouré (32×32) d'un ennemi, d'après son champ "art" (enemies.json).
static func creature(art: Dictionary, seed_value: int) -> Image:
	match art.get("type", ""):
		"humanoid":
			return portrait(art.get("species_art", {}), art.get("class_art", {}), "adult", seed_value, false)
		"wolf":
			return _wolf(art)
		"rat":
			return _rat(art)
	var img := Image.create(PORTRAIT_SIZE, PORTRAIT_SIZE, false, Image.FORMAT_RGBA8)
	_ellipse(img, 16.0, 18.0, 9.0, 9.0, Color(0.5, 0.3, 0.5))
	return _outlined(img)


## Loup vu de profil, tourné vers la gauche.
@warning_ignore("integer_division")
static func _wolf(art: Dictionary) -> Image:
	var img := Image.create(PORTRAIT_SIZE, PORTRAIT_SIZE, false, Image.FORMAT_RGBA8)
	var fur := Color(String(art.get("fur", "#8a8a90")))
	var belly := Color(String(art.get("belly", "#b8b4ac")))
	var eye := Color(String(art.get("eyes", "#e8c547")))
	# Queue, pattes arrière (plus sombres), corps, pattes avant.
	for i in 6:
		_rect(img, 25 + i, 15 - i / 2, 2, 2, fur.darkened(0.1))
	for x in [21, 24]:
		_rect(img, x, 20, 2, 8, fur.darkened(0.25))
	_ellipse(img, 18.0, 18.0, 9.0, 5.0, fur)
	_ellipse(img, 18.0, 20.0, 7.0, 2.5, belly)
	for x in [11, 14]:
		_rect(img, x, 20, 2, 8, fur.darkened(0.1))
	# Cou, tête, museau, oreilles, œil.
	_ellipse(img, 11.0, 15.0, 4.0, 4.5, fur)
	_ellipse(img, 7.5, 13.0, 4.0, 3.5, fur)
	_rect(img, 1, 13, 5, 3, fur.lightened(0.05))
	_rect(img, 1, 15, 4, 1, belly)
	_px(img, 1, 13, Color(0.1, 0.08, 0.08))
	for i in 3:
		_hline(img, 6 + i / 2, 7, 9 + i, fur.darkened(0.15))
		_hline(img, 9, 10 - i / 2, 9 + i, fur.darkened(0.15))
	_px(img, 7, 12, eye)
	_shade_rect(img, 10, 13, 18, 3, 0.15)
	return _outlined(img)


## Rat géant vu de profil, tourné vers la gauche.
static func _rat(art: Dictionary) -> Image:
	var img := Image.create(PORTRAIT_SIZE, PORTRAIT_SIZE, false, Image.FORMAT_RGBA8)
	var fur := Color(String(art.get("fur", "#6a5a4a")))
	var eye := Color(String(art.get("eyes", "#e0402a")))
	var pink := Color(0.85, 0.6, 0.6)
	for i in 10:
		_px(img, 21 + i, 22 - int(sin(i * 0.5) * 3.0), pink)
	_ellipse(img, 16.0, 21.0, 7.0, 4.5, fur)
	_ellipse(img, 9.0, 20.0, 3.5, 3.0, fur)
	_rect(img, 4, 20, 3, 2, fur.lightened(0.1))
	_px(img, 4, 20, pink)
	_ellipse(img, 10.0, 16.5, 1.6, 1.6, pink.darkened(0.2))
	_px(img, 8, 19, eye)
	for x in [11, 13, 18, 20]:
		_rect(img, x, 25, 1, 2, pink.darkened(0.1))
	_shade_rect(img, 10, 23, 14, 3, 0.2)
	return _outlined(img)


static func _shade_rect(img: Image, x: int, y: int, w: int, h: int, amount: float) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			_shade(img, xx, yy, amount)


# --- Décors ------------------------------------------------------------------

## Illustration panoramique d'un lieu ("forest", "town", "home"...) au moment donné de la journée.
static func scene(kind: String, slot_id: String, seed_value: int) -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var img := Image.create(SCENE_W, SCENE_H, false, Image.FORMAT_RGBA8)
	var sky: Array = SKY.get(slot_id, SKY["afternoon"])
	var night := slot_id == "evening"
	match kind:
		"forest":
			_forest(img, sky, night, rng)
		"town":
			_town(img, sky, night, rng)
		"home":
			_home(img, sky, night, rng)
		_:
			_sky(img, sky, night, rng, SCENE_H)
			_rect(img, 0, 40, SCENE_W, 8, Color(0.2, 0.18, 0.14))
	return img


static func _sky(img: Image, sky: Array, night: bool, rng: RandomNumberGenerator, height: int) -> void:
	for y in height:
		var col: Color = sky[0].lerp(sky[1], y / float(height - 1))
		for x in img.get_width():
			img.set_pixel(x, y, col)
	if night:
		for i in 25:
			_px(img, rng.randi_range(0, img.get_width() - 1), rng.randi_range(0, int(height * 0.5)), Color(1, 0.95, 0.8, 0.8))


static func _forest(img: Image, sky: Array, night: bool, rng: RandomNumberGenerator) -> void:
	_sky(img, sky, night, rng, SCENE_H)
	var hill: Color = sky[1].lerp(Color(0.18, 0.29, 0.23), 0.6)
	var phase := rng.randf() * TAU
	for x in SCENE_W:
		var top := 28 + int(3.0 * sin(x * 0.05 + phase) + 2.0 * sin(x * 0.13 + phase * 2.0))
		_rect(img, x, top, 1, SCENE_H - top, hill)
	var layers := [
		{"count": 16, "base": [32, 36], "height": [10, 16], "color": Color(0.18, 0.29, 0.2).lerp(sky[1], 0.35)},
		{"count": 10, "base": [39, 42], "height": [14, 22], "color": Color(0.14, 0.22, 0.16)},
		{"count": 6, "base": [47, 50], "height": [22, 32], "color": Color(0.09, 0.15, 0.11)},
	]
	for layer: Dictionary in layers:
		if layer == layers[2]:
			_rect(img, 0, 42, SCENE_W, 6, Color(0.11, 0.14, 0.09))
			for i in 60:
				_px(img, rng.randi_range(0, SCENE_W - 1), rng.randi_range(42, 47), Color(0.2, 0.3, 0.14))
		for i in layer["count"]:
			var x := rng.randi_range(-4, SCENE_W + 4)
			var base := rng.randi_range(layer["base"][0], layer["base"][1])
			var h := rng.randi_range(layer["height"][0], layer["height"][1])
			_pine(img, x, base, h, layer["color"])
	if night:
		_tint(img, Color(0.1, 0.08, 0.19), 0.35)


@warning_ignore("integer_division")
static func _pine(img: Image, cx: int, base_y: int, h: int, col: Color) -> void:
	_rect(img, cx, base_y - 3, 2, 3, Color(0.23, 0.16, 0.12).lerp(col, 0.4))
	var tier_len := maxi(3, h / 3)
	for i in h:
		var y := base_y - 3 - i
		var taper := 1.0 - float(i) / h  # 1 à la base, 0 au sommet
		var saw := 1.0 - float(i % tier_len) / tier_len  # étages de branches
		var w := int(round(taper * h * 0.34 * (0.55 + 0.45 * saw)))
		_hline(img, cx - w, cx + 1 + w, y, col)
		_px(img, cx - w, y, col.lightened(0.12))


@warning_ignore("integer_division")
static func _town(img: Image, sky: Array, night: bool, rng: RandomNumberGenerator) -> void:
	_sky(img, sky, night, rng, SCENE_H)
	# Silhouette lointaine : tour du château et toits.
	var far: Color = sky[1].lerp(Color(0.25, 0.25, 0.3), 0.55)
	var tower_x := rng.randi_range(20, SCENE_W - 30)
	_rect(img, tower_x, 10, 9, 30, far)
	for i in 3:
		_rect(img, tower_x + i * 3, 8, 2, 2, far)
	var x := 0
	while x < SCENE_W:
		var w := rng.randi_range(8, 16)
		var top := rng.randi_range(24, 30)
		_rect(img, x, top, w, 40 - top, far)
		x += w
	# Rangée de maisons.
	var walls := [Color(0.72, 0.63, 0.5), Color(0.6, 0.54, 0.44), Color(0.78, 0.69, 0.56)]
	var roofs := [Color(0.48, 0.23, 0.16), Color(0.35, 0.29, 0.23), Color(0.42, 0.18, 0.18)]
	var windows: Array[Vector2i] = []
	x = -rng.randi_range(0, 8)
	var base := 42
	while x < SCENE_W:
		var w := rng.randi_range(14, 24)
		var h := rng.randi_range(11, 17)
		var wall: Color = walls[rng.randi_range(0, walls.size() - 1)]
		var roof: Color = roofs[rng.randi_range(0, roofs.size() - 1)]
		var timber := wall.darkened(0.55)
		_rect(img, x, base - h, w, h, wall)
		_rect(img, x, base - h, 1, h, timber)
		_rect(img, x + w - 1, base - h, 1, h, timber)
		_hline(img, x, x + w - 1, base - h + h / 2, timber)
		var roof_h := (w + 2) / 2
		for i in roof_h:
			_hline(img, x - 1 + i, x + w - i, base - h - 1 - i, roof.lightened(0.1) if i == 0 else roof)
		_rect(img, x + w / 2 - 1, base - 5, 3, 5, Color(0.25, 0.16, 0.1))
		windows.append(Vector2i(x + 3, base - h + 3))
		windows.append(Vector2i(x + w - 5, base - h + 3))
		if rng.randf() < 0.4:
			_rect(img, x + w - 6, base - h - roof_h + 1, 2, 4, Color(0.35, 0.3, 0.28))
		x += w + rng.randi_range(1, 4)
	# Pavés.
	_rect(img, 0, base, SCENE_W, SCENE_H - base, Color(0.29, 0.27, 0.24))
	for i in 120:
		_px(img, rng.randi_range(0, SCENE_W - 1), rng.randi_range(base, SCENE_H - 1),
			Color(0.36, 0.33, 0.3) if rng.randf() < 0.5 else Color(0.22, 0.2, 0.18))
	if night:
		_tint(img, Color(0.1, 0.08, 0.19), 0.4)
	var lit := Color(0.95, 0.76, 0.35)
	var dark := Color(0.17, 0.2, 0.27)
	for wpos in windows:
		_rect(img, wpos.x, wpos.y, 2, 2, lit if night or rng.randf() < 0.15 else dark)


static func _home(img: Image, sky: Array, night: bool, rng: RandomNumberGenerator) -> void:
	# Mur de planches et plancher.
	var plank := Color(0.31, 0.21, 0.15)
	_rect(img, 0, 0, SCENE_W, 38, plank)
	for x in range(0, SCENE_W, 8):
		_rect(img, x, 0, 1, 38, plank.darkened(0.3))
	for i in 20:
		_px(img, rng.randi_range(0, SCENE_W - 1), rng.randi_range(0, 37), plank.darkened(0.2))
	_rect(img, 0, 38, SCENE_W, 10, Color(0.2, 0.14, 0.1))
	for y in [41, 44]:
		_hline(img, 0, SCENE_W - 1, y, Color(0.15, 0.1, 0.07))
	# Fenêtre.
	var window := Image.create(18, 14, false, Image.FORMAT_RGBA8)
	_sky(window, sky, night, rng, 14)
	img.blit_rect(window, Rect2i(0, 0, 18, 14), Vector2i(19, 9))
	_rect(img, 18, 8, 20, 1, Color(0.18, 0.12, 0.08))
	_rect(img, 18, 23, 20, 1, Color(0.18, 0.12, 0.08))
	_rect(img, 18, 8, 1, 16, Color(0.18, 0.12, 0.08))
	_rect(img, 37, 8, 1, 16, Color(0.18, 0.12, 0.08))
	_rect(img, 27, 9, 1, 14, Color(0.18, 0.12, 0.08))
	_rect(img, 19, 15, 18, 1, Color(0.18, 0.12, 0.08))
	# Lit.
	_rect(img, 50, 31, 36, 9, Color(0.36, 0.24, 0.15))
	_rect(img, 51, 30, 34, 6, Color(0.48, 0.16, 0.16))
	_rect(img, 51, 28, 8, 4, Color(0.85, 0.81, 0.75))
	# Cheminée.
	var stone := Color(0.36, 0.35, 0.37)
	_rect(img, 112, 12, 32, 26, stone)
	for i in 30:
		_px(img, rng.randi_range(112, 143), rng.randi_range(12, 37), stone.darkened(0.25))
	_rect(img, 118, 24, 20, 14, Color(0.07, 0.05, 0.04))
	if night:
		_tint(img, Color(0.08, 0.06, 0.12), 0.45)
	for i in 40:
		var fx := rng.randi_range(120, 135)
		var fy := rng.randi_range(29, 37)
		var heat := (fy - 29) / 8.0
		_px(img, fx, fy, Color(1.0, 0.85, 0.3).lerp(Color(0.9, 0.3, 0.1), 1.0 - heat))
	for y in range(36, SCENE_H):
		for x in range(100, 156):
			var glow := 1.0 - Vector2(x - 128, (y - 37) * 2).length() / 28.0
			if glow > 0.0:
				img.set_pixel(x, y, img.get_pixel(x, y).lerp(Color(0.95, 0.55, 0.2), glow * 0.35))


# --- Primitives --------------------------------------------------------------

static func _pick(list: Array, rng: RandomNumberGenerator) -> Color:
	return Color(String(list[rng.randi_range(0, list.size() - 1)]))


static func _inside(x: int, y: int, cx: float, cy: float, rx: float, ry: float) -> bool:
	var dx := (x + 0.5 - cx) / rx
	var dy := (y + 0.5 - cy) / ry
	return dx * dx + dy * dy <= 1.0


static func _ellipse(img: Image, cx: float, cy: float, rx: float, ry: float, col: Color) -> void:
	for y in range(maxi(0, floori(cy - ry)), mini(img.get_height(), ceili(cy + ry) + 1)):
		for x in range(maxi(0, floori(cx - rx)), mini(img.get_width(), ceili(cx + rx) + 1)):
			if _inside(x, y, cx, cy, rx, ry):
				img.set_pixel(x, y, col)


static func _px(img: Image, x: int, y: int, col: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		if col.a < 1.0:
			img.set_pixel(x, y, img.get_pixel(x, y).blend(col))
		else:
			img.set_pixel(x, y, col)


## Pixel et son symétrique par rapport à l'axe vertical de l'image.
static func _sym(img: Image, x: int, y: int, col: Color) -> void:
	_px(img, x, y, col)
	_px(img, img.get_width() - 1 - x, y, col)


static func _hline(img: Image, x0: int, x1: int, y: int, col: Color) -> void:
	for x in range(x0, x1 + 1):
		_px(img, x, y, col)


static func _rect(img: Image, x: int, y: int, w: int, h: int, col: Color) -> void:
	for yy in range(y, y + h):
		_hline(img, x, x + w - 1, yy, col)


static func _shade(img: Image, x: int, y: int, amount: float) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		var c := img.get_pixel(x, y)
		if c.a > 0.0:
			img.set_pixel(x, y, c.darkened(amount))


static func _tint(img: Image, col: Color, amount: float) -> void:
	for y in img.get_height():
		for x in img.get_width():
			img.set_pixel(x, y, img.get_pixel(x, y).lerp(col, amount))


static func _outlined(fig: Image) -> Image:
	var out: Image = fig.duplicate()
	var w := fig.get_width()
	var h := fig.get_height()
	for y in h:
		for x in w:
			if fig.get_pixel(x, y).a > 0.0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = Vector2i(x, y) + d
				if n.x >= 0 and n.y >= 0 and n.x < w and n.y < h and fig.get_pixel(n.x, n.y).a > 0.0:
					out.set_pixel(x, y, OUTLINE)
					break
	return out
