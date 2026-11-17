class_name Drawer
extends PanelContainer
## Slide-out side drawer that shows one management panel at a time.

signal panel_changed(panel: String)

const W := 430.0
const REST := Vector2(1280 - W - 12, 82)
const HEIGHT := 564.0

var current: String = ""
var _panels := {}  # id -> [title, node]
var _title: Label
var _body: Control
var _tween: Tween


func _ready() -> void:
	position = Vector2(1280, REST.y)
	size = Vector2(W, HEIGHT)
	custom_minimum_size = size
	var st := UIKit.style(Color(0.13, 0.09, 0.07, 0.97), 12, Color(0.95, 0.72, 0.38, 0.5), 2, 12)
	st.shadow_color = Color(0, 0, 0, 0.4)
	st.shadow_size = 12
	add_theme_stylebox_override("panel", st)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	_title = UIKit.label("", 18, UIKit.ACCENT)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	head.add_child(UIKit.button("✕", close))
	_body = Control.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.clip_contents = true
	v.add_child(_body)
	visible = false


func add_panel(id: String, title: String, node: Control) -> void:
	_panels[id] = [title, node]
	node.visible = false
	node.set_anchors_preset(Control.PRESET_FULL_RECT)
	_body.add_child(node)


func toggle(id: String) -> void:
	if current == id:
		close()
	else:
		open(id)


func open(id: String) -> void:
	if not _panels.has(id):
		return
	for k in _panels:
		_panels[k][1].visible = k == id
	_title.text = _panels[id][0]
	var was_open := current != ""
	current = id
	visible = true
	if not was_open:
		_slide(REST.x)
	panel_changed.emit(id)


func close() -> void:
	if current == "":
		return
	current = ""
	_slide(1280.0, true)
	panel_changed.emit("")


func _slide(x: float, hide_after: bool = false) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "position:x", x, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if hide_after:
		_tween.tween_callback(func(): visible = false)
