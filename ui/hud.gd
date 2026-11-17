class_name Hud
extends PanelContainer

signal debug_pressed

var sim: Sim
var gold: Label
var renown: Label
var debt: Label
var ladles: Label
var day: Label
var phase: Label
var phase_bar: ProgressBar
var speed_buttons: Array[Button] = []
var _pulse: Tween
## Gold already earned but still flying up from the counter; not shown until it lands.
var gold_in_flight: float = 0.0


func _ready() -> void:
	sim = Game.sim
	add_theme_stylebox_override("panel", UIKit.style(Color("100c16"), 0, Color.TRANSPARENT, 0, 6))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	add_child(h)
	var title := UIKit.label("🏮 Lantern & Ladle", 16, UIKit.ACCENT)
	h.add_child(title)
	gold = UIKit.label("", 16, UIKit.ACCENT)
	gold.custom_minimum_size.x = 110
	h.add_child(gold)
	renown = UIKit.label("", 15, UIKit.INFO)
	renown.custom_minimum_size.x = 110
	h.add_child(renown)
	ladles = UIKit.label("", 15, UIKit.ACCENT)
	h.add_child(ladles)
	debt = UIKit.label("", 14, UIKit.BAD)
	h.add_child(debt)
	day = UIKit.label("", 15)
	h.add_child(day)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 1)
	pv.custom_minimum_size.x = 170
	phase = UIKit.label("", 12, UIKit.MUTED)
	pv.add_child(phase)
	phase_bar = UIKit.bar(UIKit.ACCENT, 6)
	pv.add_child(phase_bar)
	h.add_child(pv)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(sp)
	for s in Game.SPEEDS:
		var label := "⏸" if s == 0.0 else "%d×" % int(s)
		var b := UIKit.button(label, func(): Game.set_speed(s))
		b.toggle_mode = true
		b.custom_minimum_size.x = 38
		speed_buttons.append(b)
		h.add_child(b)
	h.add_child(UIKit.button("💾", func(): Game.save_now()))
	h.add_child(UIKit.button("🛠 Debug", func(): debug_pressed.emit()))
	Game.speed_changed.connect(func(_s): _sync_speed())
	_sync_speed()


## Where flying gold should land (global coordinates).
func gold_target() -> Vector2:
	return gold.get_global_rect().get_center()


## Little bounce + flash when coins land on the counter.
func pulse_gold() -> void:
	gold.pivot_offset = gold.size / 2.0
	if _pulse and _pulse.is_valid():
		_pulse.kill()
	gold.scale = Vector2(1.18, 1.18)
	gold.modulate = Color(1.35, 1.25, 0.9)
	_pulse = gold.create_tween().set_parallel(true)
	_pulse.tween_property(gold, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pulse.tween_property(gold, "modulate", Color.WHITE, 0.3)


func _sync_speed() -> void:
	for i in speed_buttons.size():
		speed_buttons[i].set_pressed_no_signal(is_equal_approx(Game.SPEEDS[i], Game.time_scale))


func _process(_delta: float) -> void:
	var s := sim.state
	gold.text = "💰 %dg" % int(floor(s.gold - gold_in_flight))
	renown.text = "⭐ %.0f renown" % s.renown
	debt.text = ("owed %dg" % int(ceil(s.debt))) if s.debt > 0 else ""
	ladles.text = ("🥄 %d" % s.ladles) if s.ladles > 0 or s.festivals > 0 else ""
	day.text = ("Day %d" % s.day) if s.festivals == 0 else ("S%d · Day %d" % [s.festivals + 1, s.day])
	var left := sim.phase_length(s.phase) - s.phase_time
	var icon: String = ["☀", "🌆", "🌙"][s.phase]
	phase.text = "%s %s — %ds left" % [icon, Sim.PHASE_NAMES[s.phase], int(left)]
	phase_bar.value = sim.phase_progress()
