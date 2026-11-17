class_name UIKit
extends RefCounted
## Small helpers for building the placeholder UI in code.

const BG := Color("17121f")
const PANEL := Color("261d31")
const PANEL_LIGHT := Color("352943")
const ACCENT := Color("f2b45a")
const TEXT := Color("f3e9dc")
const MUTED := Color("a99bb5")
const GOOD := Color("7fd18b")
const BAD := Color("e2716a")
const INFO := Color("7fb6e0")


static func label(text: String, size: int = 14, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func wrap_label(text: String, size: int = 13, color: Color = MUTED) -> Label:
	var l := label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 100
	return l


static func style(color: Color, radius: int = 6, border: Color = Color.TRANSPARENT, border_w: int = 0, pad: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(border_w)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad
	s.content_margin_bottom = pad
	return s


static func rect(color: Color, pos: Vector2, size: Vector2, radius: int = 0) -> Panel:
	var p := Panel.new()
	p.position = pos
	p.size = size
	p.add_theme_stylebox_override("panel", style(color, radius))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


static func card(color: Color = PANEL_LIGHT, pad: int = 8) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", style(color, 6, Color.TRANSPARENT, 0, pad))
	return p


static func button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b


static func bar(color: Color, height: float = 8.0) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.min_value = 0.0
	b.max_value = 1.0
	b.step = 0.0
	b.custom_minimum_size.y = height
	b.add_theme_stylebox_override("background", style(Color(0, 0, 0, 0.35), 3))
	b.add_theme_stylebox_override("fill", style(color, 3))
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 14
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("normal", "Button", style(Color("4a3a5c"), 5, Color.TRANSPARENT, 0, 6))
	t.set_stylebox("hover", "Button", style(Color("5c4872"), 5, Color.TRANSPARENT, 0, 6))
	t.set_stylebox("pressed", "Button", style(Color("7a5a3a"), 5, Color.TRANSPARENT, 0, 6))
	t.set_stylebox("disabled", "Button", style(Color("2e2638"), 5, Color.TRANSPARENT, 0, 6))
	t.set_color("font_disabled_color", "Button", Color("6d6278"))
	t.set_stylebox("panel", "TabContainer", style(PANEL, 6, Color.TRANSPARENT, 0, 6))
	t.set_stylebox("tab_selected", "TabContainer", style(PANEL, 5, Color.TRANSPARENT, 0, 6))
	t.set_stylebox("tab_unselected", "TabContainer", style(Color("1e1728"), 5, Color.TRANSPARENT, 0, 6))
	t.set_stylebox("tab_hovered", "TabContainer", style(Color("2e2439"), 5, Color.TRANSPARENT, 0, 6))
	t.set_font_size("font_size", "TabContainer", 13)
	return t


## Short duration for view tweens: sim seconds converted to real seconds.
static func real(sim_seconds: float) -> float:
	return sim_seconds / maxf(1.0, Game.time_scale)
