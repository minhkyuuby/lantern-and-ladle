class_name LogPanel
extends VBoxContainer

var text: RichTextLabel
var sim: Sim


func _ready() -> void:
	sim = Game.sim
	text = RichTextLabel.new()
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.scroll_following = true
	text.bbcode_enabled = true
	text.add_theme_font_size_override("normal_font_size", 12)
	add_child(text)
	sim.events.logged.connect(_on_log)
	Game.resynced.connect(_refill)
	_refill()


func _refill() -> void:
	text.clear()
	for l in sim.state.log_lines.slice(-120):
		text.append_text(l + "\n")


func _on_log(line: String, important: bool) -> void:
	if Game.catching_up:
		return
	if important:
		text.append_text("[color=#f2b45a]%s[/color]\n" % line)
	else:
		text.append_text(line + "\n")
