class_name DebugPanel
extends PanelContainer

signal report_ready(title: String, lines: Array)


func _ready() -> void:
	add_theme_stylebox_override("panel", UIKit.style(Color("1d1626f5"), 8, UIKit.INFO, 2, 10))
	var v := VBoxContainer.new()
	add_child(v)
	v.add_child(UIKit.label("🛠 Debug (F1)", 15, UIKit.INFO))
	var sim := Game.sim
	v.add_child(UIKit.button("+500 gold", func(): sim.state.gold += 500))
	v.add_child(UIKit.button("+25 renown", func(): sim.state.renown += 25))
	v.add_child(UIKit.button("Skip to next phase", func(): sim.skip_phase()))
	v.add_child(UIKit.button("Beat every boss (enables festival)", func():
		for fd in sim.db.floors:
			if fd.boss_name != "" and not (fd.index in sim.state.bosses_beaten):
				sim.state.bosses_beaten.append(fd.index)
		sim.state.slice_complete = true
		sim.events.slice_completed.emit()))
	v.add_child(UIKit.button("Simulate 1h offline", func(): _offline(3600.0)))
	v.add_child(UIKit.button("Simulate 8h offline", func(): _offline(8 * 3600.0)))
	v.add_child(UIKit.button("Save now", func(): Game.save_now()))
	var reset := UIKit.button("Reset save (new game)", func(): Game.reset_game())
	reset.add_theme_color_override("font_color", UIKit.BAD)
	v.add_child(reset)
	v.add_child(UIKit.button("Close", hide))
	visible = false


func _offline(seconds: float) -> void:
	var r := Game.catch_up(seconds)
	report_ready.emit(r["title"], r["lines"])
