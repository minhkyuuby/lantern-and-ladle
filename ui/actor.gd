class_name Actor
extends Control
## Placeholder character: rounded body, emoji face, caption, speech bubble and a small bar.

signal clicked

## Caption width; keep it below the spacing between neighbouring actors so names never collide.
const CAPTION_W := 46.0

var body: Panel
var face: Label
var caption: Label
var bubble: Label
var bar: ProgressBar
var _tween: Tween
## While walking via the aisle, bubble and bar stay hidden so they don't cover seated customers.
var _walking: bool = false


## With `sprite`, the pixel-art character replaces the coloured body + emoji face.
func setup(icon_text: String, color: Color, caption_text: String = "", size_px: Vector2 = Vector2(38, 50), sprite: Texture2D = null) -> Actor:
	size = size_px
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if sprite:
		body = UIKit.rect(Color(0, 0, 0, 0.3), Vector2(5, size_px.y - 5), Vector2(size_px.x - 10, 6), 3)  # ground shadow
		add_child(body)
		var pic := SpriteLib.view(sprite, SpriteLib.CHAR_SCALE)
		pic.position = Vector2((size_px.x - pic.size.x) / 2.0, size_px.y - pic.size.y)
		add_child(pic)
	else:
		body = UIKit.rect(color, Vector2.ZERO, size_px, 12)
		add_child(body)
	face = UIKit.label(icon_text, int(size_px.x * 0.5))
	face.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	face.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	face.size = Vector2(size_px.x, size_px.y * 0.75)
	face.visible = sprite == null
	add_child(face)
	caption = UIKit.label(caption_text, 10, UIKit.TEXT)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.clip_text = true
	caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	caption.size = Vector2(CAPTION_W, 14)
	caption.position = Vector2(size_px.x / 2.0 - CAPTION_W / 2.0, size_px.y + 1.0)
	caption.visible = caption_text != ""
	add_child(caption)
	bubble = UIKit.label("", 16)
	bubble.add_theme_stylebox_override("normal", UIKit.style(Color(1, 1, 1, 0.92), 8, Color.TRANSPARENT, 0, 2))
	bubble.add_theme_color_override("font_color", Color("2a2030"))
	bubble.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bubble.size = Vector2(36, 26)
	bubble.position = Vector2(size_px.x / 2.0 - 18.0, -32.0)
	bubble.visible = false
	add_child(bubble)
	bar = UIKit.bar(UIKit.GOOD, 5)
	bar.position = Vector2(0, -6)
	bar.size = Vector2(size_px.x, 5)
	bar.visible = false
	add_child(bar)
	return self


func make_clickable() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			clicked.emit())


func move_to(target: Vector2, duration: float) -> Tween:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "position", target, maxf(duration, 0.02)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return _tween


func say(text: String) -> void:
	bubble.text = text
	bubble.visible = text != "" and not _walking


func set_bar(value: float, color: Color) -> void:
	bar.visible = not _walking
	bar.value = value
	(bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = color


## Walks via an aisle row (down, across, up) so we never pass through seated customers.
func walk_via(target: Vector2, duration: float, aisle_y: float, pause: float = 0.0, clear_bubble: bool = false) -> Tween:
	if _tween and _tween.is_valid():
		_tween.kill()
	var d := maxf(duration, 0.06)
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if pause > 0.0:
		_tween.tween_interval(pause)
	if clear_bubble:
		_tween.tween_callback(say.bind(""))
	_tween.tween_callback(_set_walking.bind(true))
	_tween.tween_property(self, "position:y", aisle_y, d * 0.2)
	_tween.tween_property(self, "position:x", target.x, d * 0.6)
	_tween.tween_property(self, "position:y", target.y, d * 0.2)
	_tween.tween_callback(_set_walking.bind(false))
	return _tween


func _set_walking(on: bool) -> void:
	_walking = on
	bubble.visible = bubble.text != "" and not on
	if on:
		bar.visible = false


## Shows an emote briefly, then walks out via the aisle and frees itself.
func leave_via(target: Vector2, duration: float, aisle_y: float, pause: float = 0.0) -> void:
	walk_via(target, duration, aisle_y, pause, true).tween_callback(queue_free)
