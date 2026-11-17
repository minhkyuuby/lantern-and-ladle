class_name Toasts
extends VBoxContainer
## Short notifications for important events (unlocks, level-ups, hires).


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 4)


func push(text: String) -> void:
	var p := UIKit.card(Color("3a2d48ee"), 6)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UIKit.label(text.substr(text.find("]") + 2) if text.begins_with("[D") else text, 13, UIKit.ACCENT)
	p.add_child(l)
	add_child(p)
	while get_child_count() > 4:
		get_child(0).free()
	var tw := p.create_tween()
	tw.tween_interval(3.5)
	tw.tween_property(p, "modulate:a", 0.0, 0.6)
	tw.tween_callback(p.queue_free)
