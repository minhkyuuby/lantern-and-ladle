class_name Hud
extends Control
## Floating HUD over the scene:
##   top-left   gold chip (+ renown, ladles, wages owed) and a short Goals list
##   top-centre OPEN / CLOSED lantern sign with time left in the phase
##   top-right  day, speed buttons, story button and a ⚙ menu (save, debug)

signal debug_pressed
signal story_pressed
signal hollow_requested

var sim: Sim
var gold: Label
var sub: Label
var sign_label: Label
var phase_label: Label
var phase_bar: ProgressBar
var day: Label
var story_button: Button
var speed_buttons: Array[Button] = []
var goals_box: VBoxContainer
var goals_panel: PanelContainer
var _goal_labels: Array[Label] = []
var _pulse: Tween
var _goals_t := 0.0
## Gold already earned but still flying up from the counter; not shown until it lands.
var gold_in_flight: float = 0.0


func _ready() -> void:
	sim = Game.sim
	size = Vector2(1280, 120)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# --- gold chip ---
	var chip := _chip(Vector2(14, 12))
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 0)
	chip.add_child(cv)
	gold = UIKit.label("", 24, UIKit.ACCENT)
	cv.add_child(gold)
	sub = UIKit.label("", 13, UIKit.MUTED)
	cv.add_child(sub)

	# --- goals ---
	goals_panel = _chip(Vector2(14, 92))
	var gp := goals_panel
	gp.custom_minimum_size.x = 300
	goals_box = VBoxContainer.new()
	goals_box.add_theme_constant_override("separation", 3)
	gp.add_child(goals_box)
	goals_box.add_child(UIKit.label("Goals", 13, UIKit.ACCENT))
	for i in 4:
		var l := UIKit.label("", 13)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 280
		l.mouse_filter = Control.MOUSE_FILTER_STOP
		l.gui_input.connect(_on_goal_click.bind(i))
		goals_box.add_child(l)
		_goal_labels.append(l)

	# --- lantern sign ---
	var sign := _chip(Vector2(520, 10))
	sign.custom_minimum_size.x = 240
	var sv := VBoxContainer.new()
	sv.alignment = BoxContainer.ALIGNMENT_CENTER
	sign.add_child(sv)
	sign_label = UIKit.label("", 22, UIKit.ACCENT)
	sign_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sv.add_child(sign_label)
	phase_label = UIKit.label("", 12, UIKit.MUTED)
	phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sv.add_child(phase_label)
	phase_bar = UIKit.bar(UIKit.ACCENT, 5)
	sv.add_child(phase_bar)

	# --- day, speed, story, menu ---
	var right := _chip(Vector2(0, 12))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	right.add_child(h)
	day = UIKit.label("", 16)
	day.custom_minimum_size.x = 92
	h.add_child(day)
	for s in Game.SPEEDS:
		var label := "⏸" if s == 0.0 else "%d×" % int(s)
		var b := UIKit.button(label, func(): Game.set_speed(s))
		b.toggle_mode = true
		b.custom_minimum_size.x = 38
		speed_buttons.append(b)
		h.add_child(b)
	story_button = UIKit.button("", func(): story_pressed.emit())
	story_button.tooltip_text = "A story scene is waiting — click to play it"
	story_button.add_theme_stylebox_override("normal", UIKit.style(Color("8a5a30"), 5, UIKit.ACCENT, 2, 6))
	story_button.visible = false
	h.add_child(story_button)
	var menu := MenuButton.new()
	menu.text = "⚙"
	menu.flat = false
	menu.focus_mode = Control.FOCUS_NONE
	menu.add_theme_stylebox_override("normal", UIKit.style(Color("5a4130"), 5, Color.TRANSPARENT, 0, 6))
	menu.get_popup().add_item("💾 Save now", 0)
	menu.get_popup().add_item("🛠 Debug panel (F1)", 1)
	menu.get_popup().id_pressed.connect(func(id: int):
		if id == 0:
			Game.save_now()
		else:
			debug_pressed.emit())
	h.add_child(menu)
	right.resized.connect(func(): right.position.x = 1280 - 14 - right.size.x)
	(func(): right.position.x = 1280 - 14 - right.size.x).call_deferred()

	Game.speed_changed.connect(func(_s): _sync_speed())
	_sync_speed()


func _chip(pos: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	p.position = pos
	p.add_theme_stylebox_override("panel", UIKit.style(Color(0.09, 0.06, 0.05, 0.94), 10, Color(0.95, 0.72, 0.38, 0.35), 2, 10))
	add_child(p)
	return p


func show_goals(on: bool) -> void:
	goals_panel.visible = on


## Shows "📖 n" while story scenes are waiting; it pulses gently.
func set_story_count(n: int) -> void:
	story_button.visible = n > 0
	if n > 0:
		story_button.text = "📖 %d" % n
		story_button.modulate = Color(1, 1, 1, 0.75 + 0.25 * sin(Time.get_ticks_msec() / 250.0))


## Where flying gold should land (global coordinates).
func gold_target() -> Vector2:
	return gold.get_global_rect().get_center()


## Little bounce + flash when coins land on the counter.
func pulse_gold() -> void:
	gold.pivot_offset = gold.size / 2.0
	if _pulse and _pulse.is_valid():
		_pulse.kill()
	gold.scale = Vector2(1.15, 1.15)
	gold.modulate = Color(1.35, 1.25, 0.9)
	_pulse = gold.create_tween().set_parallel(true)
	_pulse.tween_property(gold, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pulse.tween_property(gold, "modulate", Color.WHITE, 0.3)


func _sync_speed() -> void:
	for i in speed_buttons.size():
		speed_buttons[i].set_pressed_no_signal(is_equal_approx(Game.SPEEDS[i], Game.time_scale))


func _process(delta: float) -> void:
	var s := sim.state
	gold.text = "💰 %d" % int(floor(s.gold - gold_in_flight))
	var parts: Array[String] = ["⭐ %d" % int(s.renown)]
	if s.ladles > 0 or s.festivals > 0:
		parts.append("🥄 %d" % s.ladles)
	if s.debt > 0:
		parts.append("owed %dg" % int(ceil(s.debt)))
	sub.text = "   ".join(PackedStringArray(parts))
	day.text = ("Day %d" % s.day) if s.festivals == 0 else ("S%d · Day %d" % [s.festivals + 1, s.day])
	var left := int(sim.phase_length(s.phase) - s.phase_time)
	match s.phase:
		Sim.Phase.NIGHT:
			sign_label.text = "🏮 OPEN 🏮"
			sign_label.add_theme_color_override("font_color", UIKit.ACCENT)
			phase_label.text = "Night service · closes in %d:%02d" % [left / 60, left % 60]
		Sim.Phase.DUSK:
			sign_label.text = "Opening soon"
			sign_label.add_theme_color_override("font_color", Color("f2d8b0"))
			phase_label.text = "Dusk · prepping the menu · %ds" % left
		_:
			sign_label.text = "CLOSED"
			sign_label.add_theme_color_override("font_color", UIKit.MUTED)
			phase_label.text = "Daytime · adventurers dive · opens in %d:%02d" % [(left + 20) / 60, (left + 20) % 60]
	phase_bar.value = sim.phase_progress()
	_goals_t -= delta
	if _goals_t <= 0.0:
		_goals_t = 0.5
		_update_goals()


var _goal_actions: Array = []


func _update_goals() -> void:
	var goals := _goals()
	_goal_actions.clear()
	for i in _goal_labels.size():
		var l := _goal_labels[i]
		l.visible = i < goals.size()
		if i < goals.size():
			l.text = goals[i][0]
			l.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if goals[i][1] != "" else Control.CURSOR_ARROW
			_goal_actions.append(goals[i][1])


## Up to four short goals: [text, action] where action "hollow" switches to the dungeon view.
func _goals() -> Array:
	var out: Array = []
	var s := sim.state
	if s.slice_complete:
		out.append(["🏮 Hold the Festival of Lanterns (Legacy)", ""])
	elif s.max_floor < sim.db.floors.size():
		var nf := s.max_floor + 1
		out.append(["⛏ Open Floor %d: %s" % [nf, sim.progression.floor_lock_reason(nf)], "hollow"])
	else:
		var last := sim.db.floor_def(s.max_floor)
		if last.boss_name != "" and not (last.index in s.bosses_beaten):
			out.append(["👑 Beat %s on Floor %d" % [last.boss_name, last.index], "hollow"])
	if s.by_role(Character.SERVER).is_empty() and s.day >= 2:
		out.append(["🛎 Hire a server so the chef can keep cooking", ""])
	for p in s.parties:
		if p.state == Party.DIVING:
			out.append(["🧭 %s · F%d · room %d/%d" % [p.name, p.current_floor, mini(p.room_idx + 1, p.room_count), p.room_count], "hollow"])
		elif p.state == Party.RESTING:
			out.append(["💤 %s resting" % p.name, "hollow"])
	return out.slice(0, 4)


func _on_goal_click(e: InputEvent, i: int) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		if i < _goal_actions.size() and _goal_actions[i] == "hollow":
			hollow_requested.emit()
