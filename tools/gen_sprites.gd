extends SceneTree
## Draws the prototype's pixel-art sprites in code and writes PNGs to res://assets/sprites/.
##   godot --headless --path . --script res://tools/gen_sprites.gd
## Then run `godot --headless --path . --import` so Godot picks up new/changed images.
## Also writes docs/sprites_preview.png (4x contact sheet) for review.

const ROOT := "res://assets/sprites/"

# --- Palette (warm night market) ---------------------------------------------
const OUT := Color("1e1426")
const SKIN := Color("f2c9a0")
const SKIN_SH := Color("d9a37a")
const SKIN_TAN := Color("e0b48c")
const SKIN_DARK := Color("b9784f")
const BLUSH := Color("e89a8a")
const MOUTH := Color("a85a52")
const EYE := Color("2a1a2e")
const WHITE := Color("f4efe6")
const LGREY := Color("c9c3cf")
const PANTS := Color("4a3b5c")
const PANTS_SH := Color("3b2e4a")
const BOOTS := Color("3a2a22")
const BELT := Color("5a3a26")
const GOLD := Color("f2c14e")
const GOLD_SH := Color("c9952e")
const RED := Color("d94b3b")
const SILVER := Color("c8d0dc")
const STEEL := Color("8a93a6")


class Canvas:
	extends RefCounted
	var img: Image
	var w: int
	var h: int
	## Drawing coordinates are offset by a 1px margin so the outline never hits the edge.
	const M := 1

	func _init(pw: int, ph: int) -> void:
		w = pw + 2 * M
		h = ph + 2 * M
		img = Image.create(w, h, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))

	func px(x: int, y: int, c: Color) -> void:
		var X := x + M
		var Y := y + M
		if X >= 0 and Y >= 0 and X < w and Y < h:
			img.set_pixel(X, Y, c)

	func clear(x: int, y: int) -> void:
		px(x, y, Color(0, 0, 0, 0))

	func rect(x: int, y: int, rw: int, rh: int, c: Color) -> void:
		for i in rw:
			for j in rh:
				px(x + i, y + j, c)

	func ellipse(cx: float, cy: float, rx: float, ry: float, c: Color) -> void:
		for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
			for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
				var dx := (x + 0.5 - cx) / rx
				var dy := (y + 0.5 - cy) / ry
				if dx * dx + dy * dy <= 1.0:
					px(x, y, c)

	func line(x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
		var n := maxi(absi(x1 - x0), absi(y1 - y0))
		for i in n + 1:
			var t := float(i) / maxf(1.0, n)
			px(int(round(lerpf(x0, x1, t))), int(round(lerpf(y0, y1, t))), c)

	## Every empty pixel touching a solid one becomes the outline colour.
	func outline(c: Color) -> void:
		var src := img.duplicate() as Image
		for y in h:
			for x in w:
				if src.get_pixel(x, y).a > 0.0:
					continue
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nx: int = x + d.x
					var ny: int = y + d.y
					if nx >= 0 and ny >= 0 and nx < w and ny < h and src.get_pixel(nx, ny).a > 0.5:
						img.set_pixel(x, y, c)
						break


var _all: Array = []  # [group, Image] for the preview sheet


func _init() -> void:
	for dir in ["crew", "customers", "stations", "ingredients", "portraits"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT + dir))

	# Crew
	_save("crew", "maro", _person({"skin": SKIN_TAN, "hair": "none", "hat": "toque", "beard": Color("5a3a26"),
		"outfit": Color("8a8fa8"), "apron": true, "belt": false}))
	_save("crew", "chef", _person({"skin": SKIN, "hair": "short", "hair_c": Color("6b4226"), "hat": "toque",
		"outfit": Color("a8b0c8"), "apron": true, "belt": false}))
	_save("crew", "server", _person({"skin": SKIN_DARK, "hair": "neat", "hair_c": Color("2a2230"),
		"outfit": Color("2e3f6b"), "shirt": WHITE, "bowtie": true}))
	_save("crew", "pip", _person({"skin": SKIN, "hair": "messy", "hair_c": Color("e07a3a"),
		"outfit": Color("3f6fb0"), "scarf": RED, "sword": true, "compass": true}))
	_save("crew", "adventurer", _person({"skin": SKIN_TAN, "hair": "none", "hat": "helmet",
		"outfit": Color("8a5a36"), "sword": true}))

	# Customers
	_save("customers", "townsfolk", _person({"skin": SKIN, "hair": "short", "hair_c": Color("6b4226"),
		"outfit": Color("5d7fc0")}))
	_save("customers", "adventurer", _person({"skin": SKIN, "hair": "none", "hat": "hood", "hat_c": Color("4f8a4a"),
		"ears": true, "outfit": Color("6a9a5a")}))
	_save("customers", "noble", _person({"skin": SKIN, "hair": "long", "hair_c": Color("f0d27a"), "hat": "crown",
		"outfit": Color("7a4ea8"), "collar": true, "belt": false}))
	_save("customers", "merchant", _person({"skin": SKIN_TAN, "hair": "short", "hair_c": Color("2a2230"),
		"hat": "wide", "hat_c": Color("6b4a2e"), "outfit": Color("c9a03e"), "backpack": true}))

	# Stations (idle + cooking)
	for kind in ["grill", "pot", "oven"]:
		_save("stations", kind + "_idle", _station(kind, false))
		_save("stations", kind + "_cook", _station(kind, true))

	# Ingredients
	for id in ["mushroom", "rat_meat", "glowroot", "slime", "blossom", "honey"]:
		_save("ingredients", id, _ingredient(id))

	# Story portraits
	_save("portraits", "bramblewick", _portrait_bramblewick())
	_save("portraits", "moth_masked", _portrait_moth(true))
	_save("portraits", "moth", _portrait_moth(false))

	_preview("res://docs/sprites_preview.png")
	quit()


func _save(group: String, name: String, c: Canvas) -> void:
	var path := ROOT + group + "/" + name + ".png"
	c.img.save_png(path)
	_all.append([group, c.img])
	print("wrote ", path, "  ", c.w, "x", c.h)


# --- Characters (16x24) ---------------------------------------------------------

func _shade(c: Color) -> Color:
	return c.darkened(0.22)


func _person(s: Dictionary) -> Canvas:
	var cv := Canvas.new(16, 24)
	var skin: Color = s.get("skin", SKIN)
	var outfit: Color = s.get("outfit", Color("5d7fc0"))
	var osh := _shade(outfit)

	if s.get("backpack", false):
		cv.rect(12, 11, 3, 6, Color("8a5a36"))
		cv.rect(12, 11, 3, 1, Color("6b4226"))

	# legs + boots
	cv.rect(5, 18, 3, 3, PANTS)
	cv.rect(8, 18, 3, 3, PANTS_SH)
	cv.rect(5, 21, 3, 2, BOOTS)
	cv.rect(8, 21, 3, 2, BOOTS)
	# torso + arms + hands
	cv.rect(4, 11, 8, 7, outfit)
	cv.rect(10, 11, 2, 7, osh)
	cv.rect(3, 12, 1, 5, osh)
	cv.rect(12, 12, 1, 5, osh)
	cv.px(3, 17, skin)
	cv.px(12, 17, skin)
	if s.has("shirt"):
		cv.rect(6, 11, 4, 6, s["shirt"])
	if s.get("belt", true):
		cv.rect(4, 17, 8, 1, BELT)
	if s.get("apron", false):
		cv.rect(5, 12, 6, 7, WHITE)
		cv.rect(5, 11, 1, 1, WHITE)
		cv.rect(10, 11, 1, 1, WHITE)
		cv.rect(9, 12, 2, 7, LGREY)
	if s.get("collar", false):
		cv.rect(5, 11, 6, 1, WHITE)
		cv.px(7, 13, GOLD)
		cv.px(7, 15, GOLD)
	if s.get("bowtie", false):
		cv.px(6, 11, RED)
		cv.px(7, 11, Color("8a2a20"))
		cv.px(8, 11, RED)
	if s.has("scarf"):
		cv.rect(5, 11, 6, 1, s["scarf"])
		cv.px(10, 12, s["scarf"])
		cv.px(11, 13, s["scarf"])
	if s.get("compass", false):
		cv.px(7, 17, GOLD)
		cv.px(8, 17, GOLD_SH)

	# head
	cv.rect(4, 3, 8, 8, skin)
	cv.rect(11, 4, 1, 6, SKIN_SH if skin == SKIN else _shade(skin))
	for p in [Vector2i(4, 3), Vector2i(11, 3), Vector2i(4, 10), Vector2i(11, 10)]:
		cv.clear(p.x, p.y)
	cv.px(6, 7, EYE)
	cv.px(9, 7, EYE)
	cv.px(5, 8, BLUSH)
	cv.px(10, 8, BLUSH)
	cv.px(7, 9, MOUTH)
	cv.px(8, 9, MOUTH)
	if s.get("ears", false):
		cv.px(3, 6, skin)
		cv.px(3, 7, skin)
		cv.px(2, 5, skin)
		cv.px(12, 6, skin)
		cv.px(12, 7, skin)
		cv.px(13, 5, skin)
	if s.has("beard"):
		var b: Color = s["beard"]
		cv.rect(5, 8, 6, 3, b)
		cv.rect(6, 11, 4, 1, b)
		cv.rect(6, 8, 4, 1, b.darkened(0.25))
		cv.px(7, 9, MOUTH)
		cv.px(8, 9, MOUTH)

	# hair
	var hc: Color = s.get("hair_c", Color("6b4226"))
	match s.get("hair", "short"):
		"short":
			cv.rect(4, 2, 8, 3, hc)
			cv.clear(4, 2)
			cv.clear(11, 2)
			cv.rect(4, 5, 1, 2, hc)
			cv.rect(11, 5, 1, 2, hc)
		"neat":
			cv.rect(4, 2, 8, 2, hc)
			cv.rect(4, 4, 1, 2, hc)
			cv.rect(11, 4, 1, 2, hc)
			cv.px(9, 2, hc.lightened(0.3))
		"messy":
			cv.rect(4, 2, 8, 3, hc)
			cv.px(5, 1, hc)
			cv.px(8, 1, hc)
			cv.px(10, 1, hc)
			cv.px(3, 3, hc)
			cv.px(12, 3, hc)
			cv.px(5, 5, hc)
			cv.px(7, 5, hc)
			cv.rect(4, 5, 1, 2, hc)
			cv.rect(11, 5, 1, 2, hc)
		"long":
			cv.rect(4, 2, 8, 3, hc)
			cv.rect(3, 4, 1, 8, hc)
			cv.rect(12, 4, 1, 8, hc)
			cv.rect(4, 5, 1, 3, hc)
			cv.rect(11, 5, 1, 3, hc)

	# hats
	var hat_c: Color = s.get("hat_c", WHITE)
	match s.get("hat", ""):
		"toque":
			cv.rect(3, 0, 10, 2, WHITE)
			cv.clear(3, 0)
			cv.clear(12, 0)
			cv.rect(4, 2, 8, 1, LGREY)
			cv.px(6, 0, LGREY)
			cv.px(9, 1, LGREY)
		"crown":
			cv.rect(4, 2, 8, 1, GOLD)
			cv.px(4, 1, GOLD)
			cv.px(7, 1, GOLD)
			cv.px(8, 1, GOLD)
			cv.px(11, 1, GOLD)
			cv.px(7, 2, RED)
			cv.px(8, 2, GOLD_SH)
		"hood":
			cv.rect(3, 2, 10, 3, hat_c)
			cv.clear(3, 2)
			cv.clear(12, 2)
			cv.rect(3, 5, 1, 6, hat_c)
			cv.rect(12, 5, 1, 6, hat_c)
			cv.rect(4, 4, 8, 1, _shade(hat_c))
		"wide":
			cv.rect(2, 4, 12, 1, hat_c)
			cv.rect(4, 1, 8, 3, hat_c)
			cv.rect(4, 3, 8, 1, RED)
			cv.px(12, 0, GOLD)
			cv.px(11, 1, GOLD)
		"helmet":
			cv.rect(4, 2, 8, 3, STEEL)
			cv.clear(4, 2)
			cv.clear(11, 2)
			cv.rect(4, 5, 1, 3, STEEL)
			cv.rect(11, 5, 1, 3, STEEL)
			cv.rect(7, 5, 2, 2, STEEL)
			cv.px(6, 2, SILVER)
	if s.get("sword", false):
		cv.rect(13, 9, 1, 7, SILVER)
		cv.px(13, 8, WHITE)
		cv.px(12, 16, BELT)
		cv.px(13, 16, GOLD_SH)
		cv.px(14, 16, BELT)
		cv.px(13, 17, BELT)

	cv.outline(OUT)
	return cv


# --- Stations (32x20) -------------------------------------------------------------

func _station(kind: String, cooking: bool) -> Canvas:
	var cv := Canvas.new(32, 20)
	match kind:
		"grill":
			cv.rect(4, 15, 2, 5, Color("3a3a48"))
			cv.rect(26, 15, 2, 5, Color("3a3a48"))
			cv.rect(2, 8, 28, 8, Color("5a5a6e"))
			cv.rect(2, 14, 28, 2, Color("48485a"))
			for x in range(6, 26, 5):
				cv.rect(x, 10, 3, 1, Color("2a2a36"))
			cv.rect(1, 6, 30, 2, Color("2a2a36"))
			for x in range(2, 30, 3):
				cv.px(x, 6, Color("8a8a9e"))
			for x in range(3, 29, 4):
				cv.px(x, 7, Color("f0903a") if cooking else Color("6a3a2a"))
		"pot":
			cv.rect(6, 16, 20, 4, Color("4a3a3a"))
			cv.rect(13, 17, 6, 2, Color("f0903a") if cooking else Color("2a1a18"))
			cv.ellipse(16, 11, 11, 6, Color("4a6a8a"))
			cv.rect(5, 6, 22, 2, Color("6a8aaa"))
			cv.rect(2, 9, 3, 2, Color("3a4a5a"))
			cv.rect(27, 9, 3, 2, Color("3a4a5a"))
			cv.rect(8, 9, 2, 6, Color("6a8aaa"))
			cv.rect(7, 6, 18, 1, Color("8acf6a") if cooking else Color("3a4a5a"))
		"oven":
			cv.rect(1, 18, 30, 2, Color("6a5a52"))
			cv.rect(22, 0, 4, 6, Color("8a4a2e"))
			cv.ellipse(16, 13, 14, 9, Color("b8643a"))
			cv.rect(2, 13, 28, 5, Color("b8643a"))
			for y in [8, 12, 16]:
				for x in range(4 + (y % 8), 28, 6):
					cv.rect(x, y, 3, 1, Color("94502e"))
			var mouth := Color("f0903a") if cooking else Color("2a1a18")
			cv.ellipse(16, 14, 6, 4, mouth)
			cv.rect(10, 14, 12, 4, mouth)
			if cooking:
				cv.rect(13, 15, 6, 3, Color("ffd36a"))
	cv.outline(OUT)
	if cooking:
		var steam := Color(1, 1, 1, 0.75)
		match kind:
			"grill":
				for p in [Vector2i(5, 4), Vector2i(6, 3), Vector2i(12, 4), Vector2i(13, 2), Vector2i(20, 4), Vector2i(21, 3), Vector2i(27, 4)]:
					cv.px(p.x, p.y, Color("ffb347"))
				for p in [Vector2i(6, 5), Vector2i(13, 5), Vector2i(21, 5)]:
					cv.px(p.x, p.y, Color("ffe08a"))
			"pot":
				for p in [Vector2i(10, 3), Vector2i(11, 2), Vector2i(10, 0), Vector2i(16, 3), Vector2i(17, 1), Vector2i(22, 3), Vector2i(21, 1)]:
					cv.px(p.x, p.y, steam)
			"oven":
				for p in [Vector2i(23, -1), Vector2i(24, -2)]:
					cv.px(p.x, p.y, steam)
	return cv


# --- Ingredients (16x16) ----------------------------------------------------------

func _ingredient(id: String) -> Canvas:
	var cv := Canvas.new(16, 16)
	match id:
		"mushroom":
			cv.rect(6, 9, 4, 6, Color("efe0c8"))
			cv.rect(8, 9, 2, 6, Color("d8c4a6"))
			cv.ellipse(8, 7, 7.5, 4.5, Color("c0503a"))
			cv.rect(1, 8, 14, 1, Color("8a3a2a"))
			cv.px(5, 4, WHITE)
			cv.px(9, 3, WHITE)
			cv.px(11, 6, WHITE)
			cv.px(4, 6, WHITE)
		"rat_meat":
			cv.rect(1, 9, 5, 2, WHITE)
			cv.px(0, 8, WHITE)
			cv.px(0, 11, WHITE)
			cv.ellipse(10, 9, 5.5, 5, Color("d9706a"))
			cv.ellipse(10, 9, 3, 2.5, Color("e8968a"))
			cv.px(9, 7, WHITE)
			cv.px(12, 11, Color("b8504a"))
		"glowroot":
			for i in 10:
				var wdt := maxi(1, 6 - i / 2)
				cv.rect(8 - wdt / 2, 5 + i, wdt, 1, Color("f0a94a"))
			cv.px(7, 7, Color("ffe08a"))
			cv.px(8, 10, Color("ffe08a"))
			cv.px(7, 12, Color("ffe08a"))
			cv.rect(6, 1, 1, 4, Color("5fae4a"))
			cv.rect(8, 0, 1, 5, Color("4f9a3a"))
			cv.rect(10, 2, 1, 3, Color("5fae4a"))
		"slime":
			cv.ellipse(8, 10.5, 7, 4.5, Color("7fd18b"))
			cv.ellipse(8, 6.5, 3.5, 3, Color("7fd18b"))
			cv.rect(2, 13, 12, 1, Color("5fae6b"))
			cv.px(5, 7, WHITE)
			cv.px(6, 6, WHITE)
			cv.px(6, 10, EYE)
			cv.px(10, 10, EYE)
		"blossom":
			var petal := Color("e7a0c0")
			for a in 5:
				var ang := TAU * a / 5.0 - PI / 2.0
				cv.ellipse(8 + cos(ang) * 4, 8 + sin(ang) * 4, 3, 3, petal)
			cv.ellipse(8, 8, 2.2, 2.2, GOLD)
			cv.px(8, 7, Color("fff1a8"))
		"honey":
			cv.rect(3, 5, 10, 10, Color("e0a030"))
			cv.rect(4, 6, 2, 8, Color("f2c860"))
			cv.rect(3, 2, 10, 3, Color("8a5a36"))
			cv.rect(2, 4, 12, 1, Color("6b4226"))
			cv.rect(5, 9, 6, 3, WHITE)
			cv.rect(7, 10, 2, 1, Color("e0a030"))
	cv.outline(OUT)
	return cv


# --- Portraits (32x32 busts) ------------------------------------------------------

func _portrait_bramblewick() -> Canvas:
	var cv := Canvas.new(32, 32)
	var armor := Color("9aa2b0")
	cv.rect(3, 25, 26, 7, armor)
	cv.ellipse(7, 25, 5, 3.5, Color("b4bccb"))
	cv.ellipse(25, 25, 5, 3.5, Color("b4bccb"))
	cv.rect(14, 26, 4, 6, Color("7a8292"))
	cv.rect(13, 21, 6, 4, SKIN_SH)
	cv.rect(10, 7, 12, 15, SKIN)
	cv.rect(20, 8, 2, 13, SKIN_SH)
	for p in [Vector2i(10, 7), Vector2i(21, 7), Vector2i(10, 21), Vector2i(21, 21)]:
		cv.clear(p.x, p.y)
	var hair := Color("e8e4dc")
	cv.rect(9, 9, 2, 9, hair)
	cv.rect(21, 9, 2, 9, hair)
	cv.rect(12, 6, 8, 1, hair)
	cv.rect(12, 12, 3, 1, hair)
	cv.rect(17, 12, 3, 1, hair)
	cv.px(13, 14, EYE)
	cv.px(18, 14, EYE)
	cv.rect(15, 15, 2, 2, SKIN_SH)
	cv.rect(11, 18, 10, 2, hair)
	cv.px(10, 19, hair)
	cv.px(21, 19, hair)
	cv.px(10, 20, hair)
	cv.px(21, 20, hair)
	cv.px(19, 10, Color("c97a6a"))
	cv.px(18, 11, Color("c97a6a"))
	cv.outline(OUT)
	return cv


func _portrait_moth(masked: bool) -> Canvas:
	var cv := Canvas.new(32, 32)
	var cloak := Color("3a2a4e")
	cv.rect(3, 24, 26, 8, cloak)
	cv.rect(14, 24, 4, 8, Color("2e2040"))
	if masked:
		cv.ellipse(16, 14, 11, 12, cloak)
		cv.ellipse(16, 15, 8, 9, Color("2a1c3a"))
		cv.ellipse(16, 16, 6, 7, WHITE)
		cv.ellipse(13, 15, 1.6, 2.2, EYE)
		cv.ellipse(19, 15, 1.6, 2.2, EYE)
		cv.rect(15, 20, 2, 1, LGREY)
		cv.px(10, 3, Color("d9c8f0"))
		cv.px(22, 3, Color("d9c8f0"))
	else:
		cv.ellipse(16, 23, 12, 5, cloak)
		var face := Color("cfc0e8")
		cv.ellipse(16, 15, 7.5, 8.5, face)
		cv.ellipse(13, 15, 2.2, 3, EYE)
		cv.ellipse(19, 15, 2.2, 3, EYE)
		cv.px(12, 13, WHITE)
		cv.px(18, 13, WHITE)
		cv.rect(15, 20, 2, 1, Color("8a6aa8"))
		cv.line(13, 7, 9, 1, Color("8a6aa8"))
		cv.line(19, 7, 23, 1, Color("8a6aa8"))
		cv.ellipse(8.5, 1.5, 2, 1.5, Color("f0e6ff"))
		cv.ellipse(23.5, 1.5, 2, 1.5, Color("f0e6ff"))
	cv.outline(OUT)
	return cv


# --- Preview sheet -----------------------------------------------------------------

func _preview(path: String) -> void:
	const SCALE := 4
	const PAD := 8
	var rows := {}
	var order: Array[String] = []
	for e in _all:
		if not rows.has(e[0]):
			rows[e[0]] = []
			order.append(e[0])
		rows[e[0]].append(e[1])
	var width := 0
	var height := PAD
	for g in order:
		var rw := PAD
		var rh := 0
		for im in rows[g]:
			rw += im.get_width() * SCALE + PAD
			rh = maxi(rh, im.get_height() * SCALE)
		width = maxi(width, rw)
		height += rh + PAD
	var sheet := Image.create(width, height, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("261d30"))
	var y := PAD
	for g in order:
		var x := PAD
		var rh := 0
		for im: Image in rows[g]:
			var big := im.duplicate() as Image
			big.resize(im.get_width() * SCALE, im.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
			sheet.blend_rect(big, Rect2i(Vector2i.ZERO, big.get_size()), Vector2i(x, y))
			x += big.get_width() + PAD
			rh = maxi(rh, big.get_height())
		y += rh + PAD
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	sheet.save_png(path)
	print("wrote ", path)
