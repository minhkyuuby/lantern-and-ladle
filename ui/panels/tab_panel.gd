class_name TabPanel
extends ScrollContainer
## Base for side tabs: rebuild() when structure changes (dirty), cheap live() updaters 4x per second.

var box: VBoxContainer
var sim: Sim
var dirty: bool = true
var _updaters: Array[Callable] = []
var _t: float = 0.0


func _ready() -> void:
	sim = Game.sim
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	Game.resynced.connect(mark_dirty)
	_connect()


func mark_dirty(_a = null, _b = null) -> void:
	dirty = true


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	if dirty:
		dirty = false
		for ch in box.get_children():
			ch.queue_free()
		_updaters.clear()
		build()
		_run_updaters()
	_t += delta
	if _t >= 0.25:
		_t = 0.0
		_run_updaters()


func _run_updaters() -> void:
	for u in _updaters:
		u.call()


## Override: connect sim signals that should trigger a rebuild.
func _connect() -> void:
	pass


## Override: build the tab's content into `box`.
func build() -> void:
	pass


func live(f: Callable) -> void:
	_updaters.append(f)


func add(node: Control) -> Control:
	box.add_child(node)
	return node


## Adds a card and returns its inner VBox.
func card(color: Color = UIKit.PANEL_LIGHT) -> VBoxContainer:
	var c := UIKit.card(color)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	c.add_child(v)
	box.add_child(c)
	return v


func row() -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	return h


func spacer() -> Control:
	var s := Control.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return s
