class_name LedgerPopup
extends PanelContainer
## Dawn report / "while you were away" card. Auto-hides so idle play never blocks.

var title: Label
var body: VBoxContainer
var _hide_t: float = -1.0


func _ready() -> void:
	add_theme_stylebox_override("panel", UIKit.style(Color("2b2136"), 10, UIKit.ACCENT, 2, 14))
	custom_minimum_size = Vector2(420, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	add_child(v)
	title = UIKit.label("", 18, UIKit.ACCENT)
	v.add_child(title)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 2)
	v.add_child(body)
	var close := UIKit.button("Close", hide)
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	v.add_child(close)
	visible = false


func show_report(heading: String, lines: Array, auto_hide: float = 9.0) -> void:
	title.text = heading
	for ch in body.get_children():
		ch.queue_free()
	for l in lines:
		var color := UIKit.TEXT
		var s := str(l)
		if s.begins_with("Hint:"):
			color = UIKit.INFO
		elif s.begins_with("⚠"):
			color = UIKit.BAD
		body.add_child(UIKit.wrap_label(s, 13, color))
	visible = true
	_hide_t = auto_hide
	position = Vector2((860 - 420) / 2.0, 70)
	size = Vector2(420, 0)
	# Wrapped labels only know their height after a layout pass; shrink to fit then.
	(func(): size = Vector2(420, 0)).call_deferred()


func _process(delta: float) -> void:
	if visible and _hide_t > 0.0:
		_hide_t -= delta
		if _hide_t <= 0.0:
			visible = false


static func lines_for_day(r: Dictionary) -> Array[String]:
	var out: Array[String] = []
	out.append("Dishes served: %d   earned %dg (+%dg tips)" % [r["served"], r["revenue"], r["tips"]])
	out.append("Wages paid: %dg   market: %dg" % [r["wages_paid"], r["market_spent"]])
	out.append("Ingredients gathered: %d   spoiled: %d" % [r["loot"], r["spoiled"]])
	var lost: int = r["no_food"] + r["left_angry"] + r["turned_away"] + r["left_queue"]
	if lost > 0:
		out.append("Lost customers — no food: %d · slow service: %d · no seat: %d" % [r["no_food"], r["left_angry"], r["turned_away"] + r["left_queue"]])
	if r["debt"] > 0:
		out.append("⚠ Unpaid wages: %dg — the crew works slower until paid." % int(ceil(r["debt"])))
	var no_seat: int = r["turned_away"] + r["left_queue"]
	if r["no_food"] > maxi(r["left_angry"], no_seat) and r["no_food"] > 0:
		out.append("Hint: the kitchen ran out of ingredients — more adventurers or deeper floors.")
	elif r["left_angry"] > maxi(no_seat, 1):
		out.append("Hint: service is too slow — hire a server/chef, add stations or kitchen tools.")
	elif no_seat > 2:
		out.append("Hint: customers couldn't get a seat — buy extra stools.")
	return out
