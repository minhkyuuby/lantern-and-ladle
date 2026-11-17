class_name BottomBar
extends PanelContainer
## Bottom bar: Stall / Hollow view toggle on the left, one icon button per management panel.
## A small dot marks panels with something worth looking at.

signal view_selected(view: String)
signal panel_pressed(panel: String)

const PANELS := [
	["crew", "👥", "Crew"], ["hire", "📋", "Hire"], ["dives", "🗺", "Dives"], ["menu", "📜", "Menu"],
	["pantry", "🧺", "Pantry"], ["shop", "🛒", "Shop"], ["legacy", "🏮", "Legacy"], ["log", "📓", "Log"],
]

var sim: Sim
var _view_buttons := {}
var _panel_buttons := {}
var _dots := {}
var _t := 0.0


func _ready() -> void:
	sim = Game.sim
	size = Vector2(1280, 64)
	add_theme_stylebox_override("panel", UIKit.style(Color("15100d"), 0, Color.TRANSPARENT, 0, 4))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	add_child(h)

	var group := ButtonGroup.new()
	for v in [["stall", "🏮  Stall"], ["hollow", "⛏  Hollow"]]:
		var b := Button.new()
		b.text = v[1]
		b.toggle_mode = true
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(118, 52)
		b.add_theme_font_size_override("font_size", 16)
		b.add_theme_stylebox_override("pressed", UIKit.style(Color("8a6440"), 8, UIKit.ACCENT, 2, 6))
		var id: String = v[0]
		b.pressed.connect(func(): view_selected.emit(id))
		h.add_child(b)
		_view_buttons[id] = b
	_view_buttons["stall"].button_pressed = true

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(sp)
	for p in PANELS:
		var b := Button.new()
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(98, 52)
		b.tooltip_text = p[2]
		b.add_theme_stylebox_override("normal", UIKit.style(Color(0, 0, 0, 0), 8, Color.TRANSPARENT, 0, 4))
		b.add_theme_stylebox_override("hover", UIKit.style(Color("33261e"), 8, Color.TRANSPARENT, 0, 4))
		b.add_theme_stylebox_override("pressed", UIKit.style(Color("4a3424"), 8, UIKit.ACCENT, 2, 4))
		var v := VBoxContainer.new()
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_theme_constant_override("separation", 0)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		b.add_child(v)
		var icon := UIKit.label(p[1], 22)
		icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(icon)
		var name := UIKit.label(p[2], 12, UIKit.MUTED)
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(name)
		var dot := UIKit.rect(UIKit.BAD, Vector2(70, 6), Vector2(9, 9), 5)
		dot.visible = false
		b.add_child(dot)
		var id: String = p[0]
		b.pressed.connect(func(): panel_pressed.emit(id))
		h.add_child(b)
		_panel_buttons[id] = b
		_dots[id] = dot
	var sp2 := Control.new()
	sp2.custom_minimum_size.x = 6
	h.add_child(sp2)


func set_view(view: String) -> void:
	if _view_buttons.has(view):
		_view_buttons[view].button_pressed = true  # also releases the other button in the group


## Marks which panel is open (or none with "").
func set_open_panel(panel: String) -> void:
	for id in _panel_buttons:
		_panel_buttons[id].set_pressed_no_signal(id == panel)


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.5
	var s := sim.state
	var hire := false
	for c in s.candidates:
		if sim.progression.hire_block_reason(c) == "":
			hire = true
	_dots["hire"].visible = hire
	var shop := false
	for u in sim.db.upgrades:
		if sim.progression.upgrade_block_reason(u) == "":
			shop = true
	_dots["shop"].visible = shop
	var legacy := sim.can_hold_festival()
	for p in sim.db.perks:
		if sim.progression.perk_block_reason(p) == "":
			legacy = true
	_dots["legacy"].visible = legacy
	var unassigned := false
	for c in s.by_role(Character.ADVENTURER):
		if s.party_of(c.id) == null:
			unassigned = true
	_dots["dives"].visible = unassigned
	_dots["crew"].visible = s.debt > 0.0
