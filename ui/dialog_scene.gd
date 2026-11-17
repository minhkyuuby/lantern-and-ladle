class_name DialogScene
extends Control
## Focused story scene: pauses the game, dims the stall, shows big pixel busts with expressions,
## a parchment text box with a name plate and typewriter text, and numbered dialog options.

signal closed(scene_id: String)

const PORTRAIT_SCALE := 7
const BOX_Y := 520.0
const BOX := Rect2(50, BOX_Y, 1180, 180)
const SLOT_X := [96.0, 1280.0 - 96.0 - 34.0 * 7]
const CPS := 48.0  # typewriter characters per second
const INK := Color("3b2420")
const PAPER := Color("f6ead2")
const PAPER_EDGE := Color("7a4e34")
const DIM := Color(0.55, 0.5, 0.48, 1.0)

## Who's who: display name, name-plate colour, and preferred side (0 left = your crew, 1 right = visitors).
const SPEAKERS := {
	"maro": {"name": "Maro", "color": Color("c98a4a"), "side": 0},
	"pip": {"name": "Pip", "color": Color("d9704a"), "side": 0},
	"odessa": {"name": "✉ Odessa's letter", "color": Color("9a7ab0"), "side": 1},
	"bramblewick": {"name": "Sir Bramblewick", "color": Color("8a8f9a"), "side": 1},
	"tull": {"name": "Brother Tull", "color": Color("d0803e"), "side": 1},
	"moth": {"name": "Moth", "color": Color("7a64a0"), "side": 1},
}

var runner: DialogRunner
var scene_id: String = ""
var _prev_speed: float = 1.0
var _typing: bool = false
var _shown: float = 0.0
var _choices_up: bool = false
var _speaker: String = ""
var _t: float = 0.0

var _pics: Array = []  # [TextureRect, TextureRect]
var _slot_who: Array = ["", ""]
var _slot_last: Array = [-1.0, -1.0]
var _line_no: int = 0
var _base_y: float = 0.0

var _title: Label
var _plate: PanelContainer
var _plate_label: Label
var _text: RichTextLabel
var _next: Label
var _choices: VBoxContainer
var _fx: Control


func _ready() -> void:
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.09, 0.05, 0.03, 0.66)
	dim.size = size
	dim.gui_input.connect(_on_click)
	add_child(dim)
	# warm spotlight behind the speakers
	add_child(_glow(Vector2(640, 470), 520, Color(1.0, 0.72, 0.42, 0.20)))

	for i in 2:
		var r := TextureRect.new()
		r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		r.size = Vector2(34, 34) * PORTRAIT_SCALE
		r.pivot_offset = Vector2(r.size.x / 2.0, r.size.y)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.visible = false
		add_child(r)
		_pics.append(r)
	_base_y = BOX_Y - _pics[0].size.y + 18.0

	var box := Panel.new()
	box.position = BOX.position
	box.size = BOX.size
	var bs := UIKit.style(PAPER, 12, PAPER_EDGE, 4)
	bs.shadow_color = Color(0, 0, 0, 0.35)
	bs.shadow_size = 10
	box.add_theme_stylebox_override("panel", bs)
	box.gui_input.connect(_on_click)
	add_child(box)
	box.add_child(UIKit.rect(Color("ead8b8"), Vector2(16, BOX.size.y - 20), Vector2(BOX.size.x - 32, 3), 1))

	_plate = PanelContainer.new()
	_plate.position = Vector2(BOX.position.x + 40, BOX_Y - 24)
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_plate)
	_plate_label = UIKit.label("", 19, PAPER)
	_plate_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.35))
	_plate_label.add_theme_constant_override("outline_size", 3)
	_plate.add_child(_plate_label)

	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.scroll_active = false
	_text.position = Vector2(BOX.position.x + 40, BOX_Y + 34)
	_text.size = Vector2(BOX.size.x - 80, 110)
	_text.add_theme_color_override("default_color", INK)
	_text.add_theme_font_size_override("normal_font_size", 21)
	_text.add_theme_font_size_override("italics_font_size", 21)
	_text.add_theme_constant_override("line_separation", 6)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_text)

	_next = UIKit.label("▼", 18, PAPER_EDGE)
	_next.position = Vector2(BOX.end.x - 40, BOX.end.y - 40)
	add_child(_next)

	# Scene title on its own little sign, so it never reads over the HUD underneath.
	var sign := PanelContainer.new()
	sign.position = Vector2(20, 12)
	sign.add_theme_stylebox_override("panel", UIKit.style(UIKit.PANEL, 8, UIKit.ACCENT, 2, 8))
	sign.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sign)
	_title = UIKit.label("", 16, UIKit.ACCENT)
	sign.add_child(_title)
	var skip := UIKit.button("Skip ⏭", _skip)
	skip.tooltip_text = "Skip to the next choice"
	skip.add_theme_color_override("font_color", PAPER_EDGE)
	skip.add_theme_stylebox_override("normal", UIKit.style(Color("ead8b8"), 6, Color.TRANSPARENT, 0, 6))
	skip.add_theme_stylebox_override("hover", UIKit.style(Color("ffdca0"), 6, Color.TRANSPARENT, 0, 6))
	skip.position = Vector2(BOX.end.x - 104, BOX_Y + 10)
	add_child(skip)

	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 10)
	_choices.alignment = BoxContainer.ALIGNMENT_END
	_choices.position = Vector2(340, 120)
	_choices.size = Vector2(600, BOX_Y - 140)
	add_child(_choices)

	_fx = Control.new()
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.size = size
	add_child(_fx)
	Game.sim.events.story_effect.connect(_on_effect)


func is_open() -> bool:
	return visible


## Opens a scene by id (normally the first one in the story queue).
func open(id: String) -> bool:
	var sc: Dictionary = Game.db.scenes.get(id, {})
	if sc.is_empty():
		return false
	scene_id = id
	runner = DialogRunner.new(sc, Game.sim.story)
	_prev_speed = Game.time_scale
	Game.set_speed(0.0)
	_title.text = "📖  " + str(sc.get("title", ""))
	_slot_who = ["", ""]
	_slot_last = [-1.0, -1.0]
	_line_no = 0
	for p in _pics:
		p.visible = false
	for c in _choices.get_children():
		c.queue_free()
	_choices_up = false
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.25)
	_step()
	return true


func _step() -> void:
	var st := runner.advance()
	match st["t"]:
		"say":
			_show_line(st)
		"choice":
			_show_choices(st["options"])
		_:
			_close()


func _show_line(st: Dictionary) -> void:
	var who: String = st["who"]
	var face: String = st["face"] if st["face"] != "" else "neutral"
	var text: String = st["text"]
	_speaker = who
	_line_no += 1
	if who == "narrator":
		_plate.visible = false
		_text.text = "[i]" + text + "[/i]"
		_text.add_theme_color_override("default_color", Color("6a4a3a"))
		_light(-1)
	else:
		var info: Dictionary = SPEAKERS.get(who, {"name": who.capitalize(), "color": Color("8a6a50"), "side": 1})
		_plate.visible = true
		_plate_label.text = "  %s  " % info["name"]
		_plate.add_theme_stylebox_override("panel", UIKit.style(info["color"], 7, PAPER_EDGE, 3, 6))
		_text.text = text
		_text.add_theme_color_override("default_color", INK)
		var slot := _place(who, int(info["side"]), face)
		var plate_w := _plate_label.get_minimum_size().x + 12.0
		_plate.position.x = BOX.position.x + 40 if slot == 0 else BOX.end.x - 40 - plate_w
		_light(slot)
	_text.visible_characters = 0
	_shown = 0.0
	_typing = true
	_next.visible = false


## Puts `who` in a portrait slot (keeping them where they already stand) and sets the expression.
func _place(who: String, side: int, face: String) -> int:
	var slot := _slot_who.find(who)
	if slot == -1:
		if _slot_who[side] == "":
			slot = side
		elif _slot_who[1 - side] == "":
			slot = 1 - side
		else:
			slot = 0 if _slot_last[0] < _slot_last[1] else 1  # replace whoever spoke least recently
		_slot_who[slot] = who
		var pic: TextureRect = _pics[slot]
		pic.visible = true
		var from_x: float = SLOT_X[slot] + (-40.0 if slot == 0 else 40.0)
		pic.position = Vector2(from_x, _base_y)
		pic.modulate.a = 0.0
		var tw := pic.create_tween().set_parallel(true)
		tw.tween_property(pic, "position:x", SLOT_X[slot], 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(pic, "modulate:a", 1.0, 0.2)
	var tex := SpriteLib.get_tex("portraits/%s_%s" % [who, face])
	if tex == null:
		tex = SpriteLib.get_tex("portraits/" + who)
	_pics[slot].texture = tex
	_pics[slot].visible = tex != null
	_slot_last[slot] = float(_line_no)
	return slot


## Lights the speaker's slot, dims the other (-1 dims both, for narration).
func _light(slot: int) -> void:
	for i in 2:
		var pic: TextureRect = _pics[i]
		if not pic.visible:
			continue
		var target := Color(1, 1, 1, pic.modulate.a) if i == slot else Color(DIM.r, DIM.g, DIM.b, pic.modulate.a)
		pic.create_tween().tween_property(pic, "self_modulate", Color(target.r, target.g, target.b, 1.0), 0.15)
		if i == slot:
			pic.scale = Vector2(1.04, 1.04)
			pic.create_tween().tween_property(pic, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _show_choices(options: Array) -> void:
	_choices_up = true
	_next.visible = false
	for c in _choices.get_children():
		c.queue_free()
	for k in options.size():
		var opt: Dictionary = options[k]
		var b := Button.new()
		b.text = "%d   %s" % [k + 1, opt["text"]]
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(600, 48)
		b.add_theme_font_size_override("font_size", 18)
		b.add_theme_color_override("font_color", INK)
		b.add_theme_color_override("font_hover_color", INK)
		b.add_theme_color_override("font_pressed_color", INK)
		b.add_theme_stylebox_override("normal", UIKit.style(PAPER, 10, PAPER_EDGE, 3, 12))
		b.add_theme_stylebox_override("hover", UIKit.style(Color("ffdca0"), 10, PAPER_EDGE, 3, 12))
		b.add_theme_stylebox_override("pressed", UIKit.style(Color("f2b860"), 10, PAPER_EDGE, 3, 12))
		var idx: int = opt["index"]
		b.pressed.connect(func(): _choose(idx))
		_choices.add_child(b)
		b.modulate.a = 0.0
		b.create_tween().tween_property(b, "modulate:a", 1.0, 0.18).set_delay(0.05 * k)


func _choose(index: int) -> void:
	if not _choices_up:
		return
	_choices_up = false
	for c in _choices.get_children():
		c.queue_free()
	runner.choose(index)
	_step()


func _advance() -> void:
	if _choices_up:
		return
	if _typing:
		_typing = false
		_text.visible_characters = -1
		_next.visible = true
		return
	_step()


## Fast-forwards through lines until the next choice (or the end).
func _skip() -> void:
	if _choices_up:
		return
	while true:
		var st := runner.advance()
		if st["t"] == "say":
			continue
		if st["t"] == "choice":
			_typing = false
			_text.visible_characters = -1
			_show_choices(st["options"])
		else:
			_close()
		return


func _close() -> void:
	if not visible:
		return
	Game.sim.story.finish(scene_id)
	var id := scene_id
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func():
		visible = false
		Game.set_speed(_prev_speed if _prev_speed > 0.0 else 1.0)
		closed.emit(id))


## Test hook: finish typing and advance `n` times.
func debug_advance(n: int) -> void:
	for i in n:
		if _choices_up:
			break
		_typing = false
		_step()
	_typing = false
	_text.visible_characters = -1


func _on_click(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		_advance()


func _input(e: InputEvent) -> void:
	if not visible:
		return
	if e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
				_advance()
			KEY_1, KEY_2, KEY_3, KEY_4:
				var k: int = e.keycode - KEY_1
				if _choices_up and k < _choices.get_child_count():
					(_choices.get_child(k) as Button).pressed.emit()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	if _typing:
		_shown += delta * CPS
		_text.visible_characters = int(_shown)
		if _text.visible_characters >= _text.get_total_character_count():
			_typing = false
			_text.visible_characters = -1
			_next.visible = true
	_next.modulate.a = 0.5 + 0.5 * sin(_t * 5.0)
	# the speaker hops a little while talking
	for i in 2:
		var pic: TextureRect = _pics[i]
		if not pic.visible:
			continue
		var talking: bool = _typing and _slot_who[i] == _speaker
		pic.position.y = _base_y - (absf(sin(_t * 14.0)) * 4.0 if talking else 0.0)


func _on_effect(text: String) -> void:
	if not visible:
		return
	var l := UIKit.label(text, 17, UIKit.ACCENT)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 5)
	l.position = Vector2(BOX.end.x - 330, BOX_Y - 60 - _fx.get_child_count() * 26)
	_fx.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", l.position.y - 24, 1.6)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.6).set_delay(1.4)
	tw.tween_callback(l.queue_free)


func _glow(pos: Vector2, r: float, color: Color) -> TextureRect:
	var g := Gradient.new()
	g.set_color(0, color)
	g.set_color(1, Color(color.r, color.g, color.b, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	var t := TextureRect.new()
	t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.size = Vector2(r * 2, r)
	t.position = pos - Vector2(r, r * 0.5)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t
