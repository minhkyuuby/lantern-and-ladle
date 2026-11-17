extends SceneTree
## Draws the prototype's pixel art in code and writes PNGs to res://assets/sprites/.
##   godot --headless --path . --script res://tools/gen_sprites.gd
##   godot --headless --path . --import      # so Godot picks up new/changed images
## Also writes docs/sprites_preview.png (4x contact sheet) for review.
##
## Cozy style rules: chibi proportions (big round heads), warm slightly-muted palette, rosy cheeks,
## soft top-left light, and "selective" outlines — each outline pixel is a dark warm tint of the
## colour it borders instead of one hard black line.

const ROOT := "res://assets/sprites/"
const EXPRESSIONS := ["neutral", "happy", "sad", "surprised", "angry"]

# --- Cozy palette ---------------------------------------------------------------
const INK := Color("3b2420")  # warm brown that every outline leans toward
const SKIN := Color("f6d2b0")
const SKIN_TAN := Color("e8b98e")
const SKIN_DEEP := Color("c08a62")
const BLUSH := Color(0.94, 0.55, 0.55, 0.55)
const MOUTH := Color("b8645c")
const EYE := Color("43302e")
const CREAM := Color("fbf3e4")
const LINEN := Color("e6d8c3")
const PANTS := Color("6b5a6e")
const BOOTS := Color("5a3e30")
const BELT := Color("7a4e34")
const GOLD := Color("f0c463")
const GOLD_SH := Color("c9973f")
const RED := Color("d96a54")
const STEEL := Color("b9b3b0")
const COPPER := Color("c9845a")
const COPPER_SH := Color("9c5e3e")
const WOOD := Color("9a6a46")
const WOOD_SH := Color("74492f")


class Canvas:
	extends RefCounted
	var img: Image
	var w: int
	var h: int
	const M := 1  # margin so the outline never touches the edge

	func _init(pw: int, ph: int) -> void:
		w = pw + 2 * M
		h = ph + 2 * M
		img = Image.create(w, h, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))

	func px(x: int, y: int, c: Color) -> void:
		var X := x + M
		var Y := y + M
		if X < 0 or Y < 0 or X >= w or Y >= h:
			return
		if c.a < 1.0 and c.a > 0.0:
			var under := img.get_pixel(X, Y)
			if under.a > 0.0:
				c = Color(under.lerp(Color(c.r, c.g, c.b), c.a), 1.0)
		img.set_pixel(X, Y, c)

	func clear(x: int, y: int) -> void:
		var X := x + M
		var Y := y + M
		if X >= 0 and Y >= 0 and X < w and Y < h:
			img.set_pixel(X, Y, Color(0, 0, 0, 0))

	func rect(x: int, y: int, rw: int, rh: int, c: Color) -> void:
		for i in rw:
			for j in rh:
				px(x + i, y + j, c)

	## Rectangle with its corners rounded by `r` pixels (stair-step).
	func rrect(x: int, y: int, rw: int, rh: int, r: int, c: Color) -> void:
		rect(x, y, rw, rh, c)
		for k in r:
			for j in r - k:
				clear(x + j, y + k)
				clear(x + rw - 1 - j, y + k)
				clear(x + j, y + rh - 1 - k)
				clear(x + rw - 1 - j, y + rh - 1 - k)

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

	## Selective outline: each empty pixel touching a solid one takes a dark warm tint of the
	## darkest colour it touches.
	func outline(ink: Color) -> void:
		var src := img.duplicate() as Image
		for y in h:
			for x in w:
				if src.get_pixel(x, y).a > 0.0:
					continue
				var best := Color(0, 0, 0, 0)
				var best_l := 9.0
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nx: int = x + d.x
					var ny: int = y + d.y
					if nx >= 0 and ny >= 0 and nx < w and ny < h:
						var n := src.get_pixel(nx, ny)
						if n.a > 0.5 and n.get_luminance() < best_l:
							best = n
							best_l = n.get_luminance()
				if best.a > 0.0:
					img.set_pixel(x, y, Color(best.darkened(0.55).lerp(ink, 0.55), 1.0))


var _all: Array = []  # [group, Image] for the preview sheet


func _init() -> void:
	for dir in ["crew", "customers", "stations", "ingredients", "portraits"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT + dir))

	# Crew
	_save("crew", "maro", _person({"skin": SKIN_TAN, "hair": "none", "hat": "toque", "beard": Color("7a5038"),
		"outfit": Color("8d9ab0"), "apron": true, "belt": false}))
	_save("crew", "chef", _person({"skin": SKIN, "hair": "short", "hair_c": Color("8a5a3c"), "hat": "toque",
		"outfit": Color("a9b8c8"), "apron": true, "belt": false}))
	_save("crew", "server", _person({"skin": SKIN_DEEP, "hair": "neat", "hair_c": Color("4a3436"),
		"outfit": Color("4f6a8e"), "shirt": CREAM, "bowtie": true}))
	_save("crew", "pip", _person({"skin": SKIN, "hair": "messy", "hair_c": Color("e8874a"),
		"outfit": Color("5b86c0"), "scarf": RED, "sword": true, "compass": true}))
	_save("crew", "adventurer", _person({"skin": SKIN_TAN, "hair": "none", "hat": "helmet",
		"outfit": Color("a8744c"), "sword": true}))

	# Customers
	_save("customers", "townsfolk", _person({"skin": SKIN, "hair": "short", "hair_c": Color("8a5a3c"),
		"outfit": Color("7d9cd0")}))
	_save("customers", "adventurer", _person({"skin": SKIN, "hair": "none", "hat": "hood", "hat_c": Color("6fa068"),
		"ears": true, "outfit": Color("8cb87a")}))
	_save("customers", "noble", _person({"skin": SKIN, "hair": "long", "hair_c": Color("f2d88a"), "hat": "crown",
		"outfit": Color("9a74c0"), "collar": true, "belt": false}))
	_save("customers", "merchant", _person({"skin": SKIN_TAN, "hair": "short", "hair_c": Color("4a3436"),
		"hat": "wide", "hat_c": Color("8a6244"), "outfit": Color("d8b25a"), "backpack": true}))

	# Stations (idle + cooking)
	for kind in ["grill", "pot", "oven"]:
		_save("stations", kind + "_idle", _station(kind, false))
		_save("stations", kind + "_cook", _station(kind, true))

	# Ingredients
	for id in ["mushroom", "rat_meat", "glowroot", "slime", "blossom", "honey"]:
		_save("ingredients", id, _ingredient(id))

	# Story portraits: every expression for the speaking cast
	var cast := {
		"maro": {"skin": SKIN_TAN, "hat": "toque", "beard": Color("7a5038"), "brow": Color("6a4430"),
			"outfit": Color("8d9ab0"), "detail": "apron"},
		"pip": {"skin": SKIN, "hair": "messy", "hair_c": Color("e8874a"), "outfit": Color("5b86c0"),
			"detail": "scarf"},
		"odessa": {"skin": Color("f2ccb0"), "hair": "bun", "hair_c": Color("e9e2da"), "brow": Color("c9c0b8"),
			"outfit": Color("b49ac8"), "glasses": true, "detail": "shawl", "wrinkles": true},
		"bramblewick": {"skin": Color("f0c8a8"), "hair": "sides", "hair_c": Color("ece6de"), "brow": Color("ece6de"),
			"mustache": Color("ece6de"), "outfit": STEEL, "detail": "armor", "wrinkles": true},
		"tull": {"skin": SKIN_DEEP, "hair": "shaved", "outfit": Color("e0965a"), "detail": "robe",
			"brow": Color("5a3a2c")},
	}
	for who in cast:
		for ex in EXPRESSIONS:
			_save("portraits", "%s_%s" % [who, ex], _bust(cast[who], ex))
		_save("portraits", who, _bust(cast[who], "neutral"))
	_save("portraits", "moth_masked", _portrait_moth(true, "neutral"))
	_save("portraits", "moth", _portrait_moth(false, "neutral"))
	_save("portraits", "moth_happy", _portrait_moth(false, "happy"))

	_preview("res://docs/sprites_preview.png")
	quit()


func _save(group: String, name: String, c: Canvas) -> void:
	var path := ROOT + group + "/" + name + ".png"
	c.img.save_png(path)
	_all.append([group, c.img])


func _shade(c: Color) -> Color:
	return c.darkened(0.18).lerp(Color("6a4a5a"), 0.08)


func _light(c: Color) -> Color:
	return c.lightened(0.18)


# --- Characters (16x24, chibi) ------------------------------------------------------

func _person(s: Dictionary) -> Canvas:
	var cv := Canvas.new(16, 24)
	var skin: Color = s.get("skin", SKIN)
	var outfit: Color = s.get("outfit", Color("7d9cd0"))
	var osh := _shade(outfit)

	if s.get("backpack", false):
		cv.rrect(12, 12, 3, 6, 1, WOOD)
		cv.rect(12, 13, 3, 1, WOOD_SH)

	# legs + boots (short and round)
	cv.rect(5, 19, 3, 2, PANTS)
	cv.rect(8, 19, 3, 2, _shade(PANTS))
	cv.rrect(4, 21, 4, 2, 1, BOOTS)
	cv.rrect(8, 21, 4, 2, 1, BOOTS)
	# torso + arms
	cv.rrect(4, 12, 8, 7, 1, outfit)
	cv.rect(10, 13, 1, 6, osh)
	cv.rect(5, 13, 1, 4, _light(outfit))
	cv.rrect(2, 13, 2, 5, 1, osh)
	cv.rrect(12, 13, 2, 5, 1, osh)
	cv.px(2, 17, skin)
	cv.px(13, 17, skin)
	if s.has("shirt"):
		cv.rect(6, 12, 4, 6, s["shirt"])
	if s.get("belt", true):
		cv.rect(4, 17, 8, 1, BELT)
	if s.get("apron", false):
		cv.rrect(5, 13, 6, 6, 1, CREAM)
		cv.rect(9, 14, 1, 4, LINEN)
		cv.px(5, 12, CREAM)
		cv.px(10, 12, CREAM)
	if s.get("collar", false):
		cv.rect(5, 12, 6, 1, CREAM)
		cv.px(7, 14, GOLD)
		cv.px(7, 16, GOLD)
	if s.get("bowtie", false):
		cv.px(6, 12, RED)
		cv.px(7, 12, _shade(RED))
		cv.px(8, 12, RED)
	if s.has("scarf"):
		cv.rect(4, 12, 8, 1, s["scarf"])
		cv.px(10, 13, s["scarf"])
		cv.px(11, 14, s["scarf"])
	if s.get("compass", false):
		cv.px(7, 17, GOLD)
		cv.px(8, 17, GOLD_SH)

	# big round head
	cv.rrect(3, 1, 10, 11, 2, skin)
	cv.rect(12, 4, 1, 5, _shade(skin))
	cv.rect(5, 11, 6, 1, _shade(skin))
	cv.px(5, 6, EYE)
	cv.px(5, 7, EYE)
	cv.px(10, 6, EYE)
	cv.px(10, 7, EYE)
	cv.rect(3, 8, 2, 1, BLUSH)
	cv.rect(11, 8, 2, 1, BLUSH)
	cv.px(7, 9, MOUTH)
	cv.px(8, 9, MOUTH)
	if s.get("ears", false):
		cv.px(2, 6, skin)
		cv.px(1, 5, skin)
		cv.px(13, 6, skin)
		cv.px(14, 5, skin)
	if s.has("beard"):
		var b: Color = s["beard"]
		cv.rrect(4, 8, 8, 4, 1, b)
		cv.rect(5, 8, 6, 1, _shade(b))
		cv.px(7, 9, Color("d98a7a"))
		cv.px(8, 9, Color("d98a7a"))

	# hair
	var hc: Color = s.get("hair_c", Color("8a5a3c"))
	match s.get("hair", "short"):
		"short":
			cv.rrect(3, 0, 10, 4, 2, hc)
			cv.rect(3, 3, 1, 3, hc)
			cv.rect(12, 3, 1, 3, hc)
			cv.px(5, 4, hc)
			cv.px(9, 4, hc)
			cv.px(5, 1, _light(hc))
		"neat":
			cv.rrect(3, 0, 10, 3, 2, hc)
			cv.rect(3, 3, 1, 2, hc)
			cv.rect(12, 3, 1, 2, hc)
			cv.px(9, 1, _light(hc))
		"messy":
			cv.rrect(3, 0, 10, 4, 2, hc)
			cv.px(4, -1, hc)
			cv.px(7, -1, hc)
			cv.px(10, -1, hc)
			cv.px(2, 2, hc)
			cv.px(13, 2, hc)
			cv.px(4, 4, hc)
			cv.px(6, 4, hc)
			cv.px(9, 4, hc)
			cv.rect(3, 4, 1, 3, hc)
			cv.rect(12, 4, 1, 3, hc)
			cv.px(6, 1, _light(hc))
		"long":
			cv.rrect(3, 0, 10, 4, 2, hc)
			cv.rect(2, 3, 1, 9, hc)
			cv.rect(13, 3, 1, 9, hc)
			cv.rect(3, 3, 1, 4, hc)
			cv.rect(12, 3, 1, 4, hc)
			cv.px(6, 1, _light(hc))

	# hats
	var hat_c: Color = s.get("hat_c", CREAM)
	match s.get("hat", ""):
		"toque":
			cv.ellipse(8, 0.5, 6, 2.5, CREAM)
			cv.rect(4, 1, 8, 2, CREAM)
			cv.rect(4, 3, 8, 1, LINEN)
			cv.px(5, -1, Color.WHITE)
		"crown":
			cv.rect(4, 1, 8, 1, GOLD)
			cv.px(4, 0, GOLD)
			cv.px(7, 0, GOLD)
			cv.px(8, 0, GOLD)
			cv.px(11, 0, GOLD)
			cv.px(7, 1, RED)
		"hood":
			cv.rrect(2, 0, 12, 5, 2, hat_c)
			cv.rect(2, 4, 1, 7, hat_c)
			cv.rect(13, 4, 1, 7, hat_c)
			cv.rect(3, 4, 10, 1, _shade(hat_c))
		"wide":
			cv.rrect(1, 3, 14, 2, 1, hat_c)
			cv.rrect(4, 0, 8, 4, 1, hat_c)
			cv.rect(4, 2, 8, 1, RED)
			cv.px(12, -1, GOLD)
			cv.px(11, 0, GOLD)
		"helmet":
			cv.rrect(3, 0, 10, 5, 2, STEEL)
			cv.rect(3, 4, 1, 3, STEEL)
			cv.rect(12, 4, 1, 3, STEEL)
			cv.px(5, 1, Color.WHITE)
	if s.get("sword", false):
		cv.rect(14, 10, 1, 7, Color("dcd6d0"))
		cv.px(14, 9, Color.WHITE)
		cv.px(13, 17, BELT)
		cv.px(14, 17, GOLD_SH)
		cv.px(15, 17, BELT)

	cv.outline(INK)
	return cv


# --- Portrait busts (32x32), with expressions ------------------------------------------

func _bust(s: Dictionary, ex: String) -> Canvas:
	var cv := Canvas.new(32, 32)
	var skin: Color = s.get("skin", SKIN)
	var outfit: Color = s.get("outfit", Color("7d9cd0"))
	var brow: Color = s.get("brow", s.get("hair_c", Color("6a4430")).darkened(0.15))

	# shoulders + neck
	cv.rrect(3, 23, 26, 9, 4, outfit)
	cv.rect(20, 25, 6, 7, _shade(outfit))
	cv.rect(6, 25, 3, 5, _light(outfit))
	cv.rect(13, 20, 6, 4, _shade(skin))
	match s.get("detail", ""):
		"apron":
			cv.rect(10, 23, 2, 9, CREAM)
			cv.rect(20, 23, 2, 9, CREAM)
			cv.rect(12, 28, 8, 4, CREAM)
		"scarf":
			cv.rrect(9, 20, 14, 4, 1, RED)
			cv.rect(19, 24, 3, 4, RED)
			cv.rect(10, 21, 12, 1, _light(RED))
			cv.px(14, 28, GOLD)
			cv.px(15, 28, GOLD_SH)
		"shawl":
			cv.rrect(5, 22, 22, 5, 2, Color("8e6a9e"))
			cv.ellipse(16, 25, 1.6, 1.6, GOLD)
		"armor":
			cv.ellipse(7, 25, 5.5, 3.5, _light(STEEL))
			cv.ellipse(25, 25, 5.5, 3.5, _light(STEEL))
			cv.rect(13, 26, 6, 6, Color("8e8784"))
			cv.px(16, 24, GOLD)
		"robe":
			cv.line(10, 23, 16, 30, Color("b8703e"))
			cv.line(22, 23, 16, 30, Color("b8703e"))
			cv.rect(15, 27, 2, 3, GOLD)
			cv.px(15, 26, GOLD_SH)
			cv.px(16, 30, Color("ffe7a0"))

	# head (big and round)
	cv.rrect(7, 4, 18, 18, 4, skin)
	cv.rect(23, 8, 2, 10, _shade(skin))
	cv.rect(11, 21, 10, 1, _shade(skin))
	cv.rect(9, 6, 2, 3, _light(skin))
	cv.ellipse(6.5, 13.5, 1.5, 2, skin)
	cv.ellipse(25.5, 13.5, 1.5, 2, _shade(skin))
	if s.get("wrinkles", false):
		cv.px(9, 15, _shade(skin))
		cv.px(22, 15, _shade(skin))

	# hair
	var hc: Color = s.get("hair_c", Color("8a5a3c"))
	match s.get("hair", ""):
		"messy":
			cv.rrect(6, 2, 20, 8, 4, hc)
			for x in [7, 11, 15, 19, 23]:
				cv.px(x, 1, hc)
				cv.px(x + 1, 0, hc)
			for x in [8, 12, 17, 21]:
				cv.rect(x, 9, 2, 2, hc)
			cv.rect(6, 9, 2, 5, hc)
			cv.rect(24, 9, 2, 5, hc)
			cv.rect(10, 3, 4, 1, _light(hc))
		"bun":
			cv.ellipse(16, 2.5, 5, 3.5, hc)
			cv.rrect(7, 3, 18, 6, 3, hc)
			cv.rect(7, 8, 2, 6, hc)
			cv.rect(23, 8, 2, 6, hc)
			cv.rect(13, 1, 4, 1, _light(hc))
			cv.px(19, 3, GOLD)
		"sides":
			cv.rrect(5, 9, 3, 9, 1, hc)
			cv.rrect(24, 9, 3, 9, 1, hc)
		"shaved":
			cv.rect(10, 4, 12, 2, _shade(skin).lerp(Color("6a4a3a"), 0.15))

	# hats
	if s.get("hat", "") == "toque":
		cv.ellipse(16, 2, 10, 4, CREAM)
		cv.rect(8, 2, 16, 4, CREAM)
		cv.rect(8, 6, 16, 2, LINEN)
		cv.rect(11, 0, 3, 1, Color.WHITE)

	_face(cv, ex, brow, s)

	cv.outline(INK)
	return cv


## Eyes, brows, cheeks and mouth for an expression. Eyes sit at x 11-12 / 19-20, y 12-14.
func _face(cv: Canvas, ex: String, brow: Color, s: Dictionary) -> void:
	var eye_l := Vector2i(11, 12)
	var eye_r := Vector2i(19, 12)
	match ex:
		"happy":
			for e in [eye_l, eye_r]:
				cv.px(e.x - 1, e.y + 2, EYE)
				cv.px(e.x, e.y + 1, EYE)
				cv.px(e.x + 1, e.y + 1, EYE)
				cv.px(e.x + 2, e.y + 2, EYE)
		"sad":
			for e in [eye_l, eye_r]:
				cv.rect(e.x, e.y + 1, 2, 2, EYE)
				cv.px(e.x, e.y + 1, Color.WHITE)
			cv.rect(11, 16, 1, 2, Color(0.55, 0.75, 0.95, 0.9))
		"surprised":
			for e in [eye_l, eye_r]:
				cv.rect(e.x, e.y - 1, 2, 4, EYE)
				cv.px(e.x, e.y - 1, Color.WHITE)
		"angry":
			for e in [eye_l, eye_r]:
				cv.rect(e.x, e.y + 1, 2, 2, EYE)
				cv.px(e.x + 1, e.y + 1, Color.WHITE)
		_:
			for e in [eye_l, eye_r]:
				cv.rect(e.x, e.y, 2, 3, EYE)
				cv.px(e.x, e.y, Color.WHITE)

	# brows
	match ex:
		"sad":
			cv.rect(10, 10, 2, 1, brow)
			cv.rect(12, 9, 2, 1, brow)
			cv.rect(18, 9, 2, 1, brow)
			cv.rect(20, 10, 2, 1, brow)
		"angry":
			cv.rect(10, 9, 2, 1, brow)
			cv.rect(12, 10, 2, 1, brow)
			cv.rect(18, 10, 2, 1, brow)
			cv.rect(20, 9, 2, 1, brow)
		"surprised":
			cv.rect(10, 8, 4, 1, brow)
			cv.rect(18, 8, 4, 1, brow)
		_:
			cv.rect(10, 10, 4, 1, brow)
			cv.rect(18, 10, 4, 1, brow)

	if s.get("glasses", false):
		var frame := GOLD_SH
		for e in [eye_l, eye_r]:
			cv.rect(e.x - 2, e.y - 1, 6, 1, frame)
			cv.rect(e.x - 2, e.y + 3, 6, 1, frame)
			cv.rect(e.x - 2, e.y - 1, 1, 5, frame)
			cv.rect(e.x + 3, e.y - 1, 1, 5, frame)
		cv.rect(15, 13, 2, 1, frame)

	# cheeks
	var blush := BLUSH if ex != "angry" else Color(0.9, 0.4, 0.35, 0.6)
	cv.rect(8, 16, 3, 1, blush)
	cv.rect(21, 16, 3, 1, blush)
	if ex == "happy":
		cv.rect(8, 17, 3, 1, blush)
		cv.rect(21, 17, 3, 1, blush)

	# beard / mustache go under the mouth
	if s.has("beard"):
		var b: Color = s["beard"]
		cv.rrect(9, 16, 14, 7, 3, b)
		cv.rect(11, 16, 10, 1, _shade(b))
	if s.has("mustache"):
		var m: Color = s["mustache"]
		cv.rrect(11, 17, 10, 2, 1, m)
		cv.px(10, 18, m)
		cv.px(21, 18, m)
		cv.px(10, 19, m)
		cv.px(21, 19, m)

	var mouth_y := 19 if (s.has("beard") or s.has("mustache")) else 18
	match ex:
		"happy":
			cv.rect(14, mouth_y, 4, 1, MOUTH)
			cv.rect(15, mouth_y + 1, 2, 1, Color("e88a8a"))
			cv.px(13, mouth_y - 1, MOUTH)
			cv.px(18, mouth_y - 1, MOUTH)
		"sad":
			cv.rect(15, mouth_y, 2, 1, MOUTH)
			cv.px(14, mouth_y + 1, MOUTH)
			cv.px(17, mouth_y + 1, MOUTH)
		"surprised":
			cv.rect(15, mouth_y, 2, 2, MOUTH)
		"angry":
			cv.rect(14, mouth_y, 4, 1, MOUTH)
		_:
			cv.rect(15, mouth_y, 2, 1, MOUTH)
			cv.px(14, mouth_y - 1, MOUTH)
			cv.px(17, mouth_y - 1, MOUTH)


func _portrait_moth(masked: bool, ex: String) -> Canvas:
	var cv := Canvas.new(32, 32)
	var cloak := Color("5a4670")
	cv.rrect(3, 23, 26, 9, 4, cloak)
	cv.rect(14, 24, 4, 8, _shade(cloak))
	if masked:
		cv.ellipse(16, 14, 11, 12, cloak)
		cv.ellipse(16, 15, 8, 9, _shade(cloak))
		cv.ellipse(16, 16, 6, 7, CREAM)
		cv.ellipse(13, 15, 1.6, 2.2, EYE)
		cv.ellipse(19, 15, 1.6, 2.2, EYE)
		cv.rect(15, 20, 2, 1, LINEN)
		cv.px(9, 3, Color("e8dcf6"))
		cv.px(23, 3, Color("e8dcf6"))
	else:
		cv.ellipse(16, 23, 12, 5, cloak)
		var face := Color("ddd0f0")
		cv.ellipse(16, 15, 8, 9, face)
		cv.rect(10, 8, 3, 3, _light(face))
		cv.line(13, 7, 9, 1, Color("a088c0"))
		cv.line(19, 7, 23, 1, Color("a088c0"))
		cv.ellipse(8.5, 1.5, 2.2, 1.6, Color("fbf3ff"))
		cv.ellipse(23.5, 1.5, 2.2, 1.6, Color("fbf3ff"))
		if ex == "happy":
			for x in [11, 18]:
				cv.px(x, 16, EYE)
				cv.px(x + 1, 15, EYE)
				cv.px(x + 2, 15, EYE)
				cv.px(x + 3, 16, EYE)
			cv.rect(15, 20, 2, 1, MOUTH)
			cv.px(14, 19, MOUTH)
			cv.px(17, 19, MOUTH)
		else:
			cv.ellipse(13, 15, 2.4, 3, EYE)
			cv.ellipse(19, 15, 2.4, 3, EYE)
			cv.px(12, 13, Color.WHITE)
			cv.px(18, 13, Color.WHITE)
			cv.rect(15, 20, 2, 1, Color("9a7ab8"))
		cv.rect(9, 18, 3, 1, BLUSH)
		cv.rect(20, 18, 3, 1, BLUSH)
	cv.outline(INK)
	return cv


# --- Stations (32x20): copper and terracotta ------------------------------------------

func _station(kind: String, cooking: bool) -> Canvas:
	var cv := Canvas.new(32, 20)
	match kind:
		"grill":
			cv.rect(5, 14, 2, 6, WOOD_SH)
			cv.rect(25, 14, 2, 6, WOOD_SH)
			cv.rect(4, 17, 24, 1, WOOD)
			cv.rrect(2, 7, 28, 8, 3, COPPER)
			cv.rect(4, 8, 24, 2, _light(COPPER))
			cv.rect(3, 13, 26, 2, COPPER_SH)
			for x in [8, 15, 22]:
				cv.ellipse(x + 1, 11, 1.5, 1.2, Color("8a4c32"))
			cv.rrect(1, 5, 30, 3, 1, Color("5a3a2e"))
			for x in range(2, 30, 3):
				cv.px(x, 5, Color("a87a5e"))
			for x in range(3, 29, 4):
				cv.px(x, 6, Color("ffa860") if cooking else Color("8a4a36"))
		"pot":
			cv.rrect(6, 15, 20, 5, 1, Color("a8644a"))
			for x in range(7, 25, 4):
				cv.rect(x, 17, 3, 1, Color("8a4e3a"))
			cv.rrect(13, 16, 6, 3, 1, Color("ffb060") if cooking else Color("4a2e28"))
			cv.ellipse(16, 10.5, 11.5, 6, COPPER)
			cv.ellipse(12, 9, 3, 2.5, _light(COPPER))
			cv.rect(20, 11, 6, 3, COPPER_SH)
			cv.rrect(4, 4, 24, 3, 1, Color("dca07a"))
			cv.rrect(1, 8, 4, 3, 1, COPPER_SH)
			cv.rrect(27, 8, 4, 3, 1, COPPER_SH)
			cv.rect(6, 4, 20, 1, Color("b5d68a") if cooking else Color("7a5040"))
		"oven":
			cv.rect(1, 18, 30, 2, Color("8a7466"))
			cv.rrect(21, 0, 5, 7, 1, Color("b06a48"))
			cv.ellipse(16, 13, 14.5, 9.5, Color("d98a5e"))
			cv.rect(2, 13, 28, 5, Color("d98a5e"))
			cv.ellipse(10, 8, 4, 2.5, Color("eaa47a"))
			for y in [9, 13, 16]:
				for x in range(4 + (y % 6), 28, 7):
					cv.rect(x, y, 3, 1, Color("bc6e48"))
			var mouth := Color("ffb060") if cooking else Color("4a2e28")
			cv.ellipse(16, 14, 6, 4, mouth)
			cv.rect(10, 14, 12, 4, mouth)
			if cooking:
				cv.rrect(12, 15, 8, 3, 1, Color("ffe08a"))
			cv.px(28, 17, Color("7ab070"))
			cv.px(29, 16, Color("7ab070"))
			cv.px(29, 17, Color("5a9050"))
	cv.outline(INK)
	if cooking:
		var steam := Color(1, 0.97, 0.92, 0.8)
		match kind:
			"grill":
				for p in [Vector2i(5, 3), Vector2i(6, 2), Vector2i(12, 3), Vector2i(13, 1), Vector2i(20, 3), Vector2i(21, 2), Vector2i(27, 3)]:
					cv.px(p.x, p.y, Color("ffbc6a"))
				for p in [Vector2i(6, 4), Vector2i(13, 4), Vector2i(21, 4)]:
					cv.px(p.x, p.y, Color("ffe7a0"))
			"pot":
				for p in [Vector2i(10, 2), Vector2i(11, 1), Vector2i(10, -1), Vector2i(16, 2), Vector2i(17, 0), Vector2i(22, 2), Vector2i(21, 0)]:
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
			cv.rrect(6, 9, 4, 6, 1, Color("f4e6cf"))
			cv.rect(8, 9, 2, 6, Color("dccaa8"))
			cv.ellipse(8, 7, 7.5, 4.5, Color("d9735a"))
			cv.ellipse(6, 5.5, 3, 1.6, Color("e8957a"))
			cv.rect(1, 8, 14, 1, Color("b05a46"))
			for p in [Vector2i(5, 4), Vector2i(9, 3), Vector2i(11, 6), Vector2i(4, 6)]:
				cv.px(p.x, p.y, CREAM)
		"rat_meat":
			cv.rrect(1, 9, 5, 2, 0, CREAM)
			cv.px(0, 8, CREAM)
			cv.px(0, 11, CREAM)
			cv.ellipse(10, 9, 5.5, 5, Color("e08a7e"))
			cv.ellipse(10, 9, 3, 2.5, Color("f0aa9a"))
			cv.px(8, 6, Color.WHITE)
		"glowroot":
			for i in 10:
				var wdt := maxi(1, 6 - i / 2)
				cv.rect(8 - wdt / 2, 5 + i, wdt, 1, Color("f2ac5a"))
			cv.px(7, 7, Color("fff0b0"))
			cv.px(8, 10, Color("fff0b0"))
			cv.px(7, 12, Color("fff0b0"))
			cv.rect(6, 1, 1, 4, Color("7ab868"))
			cv.rect(8, 0, 1, 5, Color("62a052"))
			cv.rect(10, 2, 1, 3, Color("7ab868"))
		"slime":
			cv.ellipse(8, 10.5, 7, 4.5, Color("9adca0"))
			cv.ellipse(8, 6.5, 3.5, 3, Color("9adca0"))
			cv.rect(2, 13, 12, 1, Color("78c080"))
			cv.px(5, 7, Color.WHITE)
			cv.px(6, 6, Color.WHITE)
			cv.px(6, 10, EYE)
			cv.px(10, 10, EYE)
			cv.rect(4, 11, 2, 1, BLUSH)
			cv.rect(11, 11, 2, 1, BLUSH)
		"blossom":
			for a in 5:
				var ang := TAU * a / 5.0 - PI / 2.0
				cv.ellipse(8 + cos(ang) * 4, 8 + sin(ang) * 4, 3, 3, Color("f2b4cc"))
			cv.ellipse(8, 8, 2.2, 2.2, GOLD)
			cv.px(7, 7, Color("fff4c0"))
		"honey":
			cv.rrect(3, 5, 10, 10, 2, Color("eab048"))
			cv.rect(4, 7, 2, 6, Color("f8d27a"))
			cv.rrect(3, 2, 10, 3, 1, WOOD)
			cv.rect(2, 4, 12, 1, WOOD_SH)
			cv.rrect(5, 9, 6, 3, 1, CREAM)
			cv.rect(7, 10, 2, 1, Color("eab048"))
	cv.outline(INK)
	return cv


# --- Preview sheet -----------------------------------------------------------------

func _preview(path: String) -> void:
	const SCALE := 4
	const PAD := 8
	const MAX_W := 1400
	var rows: Array = []  # each: Array of images
	var group := ""
	var cur: Array = []
	var cur_w := PAD
	for e in _all:
		var im: Image = e[1]
		var iw := im.get_width() * SCALE + PAD
		if e[0] != group or cur_w + iw > MAX_W:
			if not cur.is_empty():
				rows.append(cur)
			cur = []
			cur_w = PAD
			group = e[0]
		cur.append(im)
		cur_w += iw
	if not cur.is_empty():
		rows.append(cur)
	var width := 0
	var height := PAD
	for r in rows:
		var rw := PAD
		var rh := 0
		for im: Image in r:
			rw += im.get_width() * SCALE + PAD
			rh = maxi(rh, im.get_height() * SCALE)
		width = maxi(width, rw)
		height += rh + PAD
	var sheet := Image.create(width, height, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("2e211b"))
	var y := PAD
	for r in rows:
		var x := PAD
		var rh := 0
		for im: Image in r:
			var big := im.duplicate() as Image
			big.resize(im.get_width() * SCALE, im.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
			sheet.blend_rect(big, Rect2i(Vector2i.ZERO, big.get_size()), Vector2i(x, y))
			x += big.get_width() + PAD
			rh = maxi(rh, big.get_height())
		y += rh + PAD
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	sheet.save_png(path)
	print("wrote ", path, " (", _all.size(), " sprites)")
