class_name RestaurantView
extends Control
## Side-view cutaway of the stall: kitchen at the back, counter, stools, street queue on the right.

## A customer paid `amount`: show it in a box of `box_size` at `global_pos` (top-left).
signal gold_popped(global_pos: Vector2, box_size: Vector2, amount: float)

const W := 860.0
const H := 400.0
const KITCHEN_H := 190.0
const COUNTER_Y := 190.0
const STATION_X0 := 150.0
const STATION_DX := 90.0
const STATION_Y := 30.0
const STATION_SIZE := Vector2(82, 70)
const STATION_STYLE := {
	"grill": ["🔥 Grill", Color("5a3a3a")],
	"pot": ["🍲 Pot", Color("3a4a5a")],
	"oven": ["🧱 Oven", Color("5a4a32")],
}
const CHEF_IDLE_X0 := 20.0
const STAFF_DX := 50.0  # wider than Actor.CAPTION_W so staff names never touch
const STAFF_Y := 98.0  # keeps staff captions clear of the PASS shelf
const SERVER_IDLE_X0 := 610.0
const SEAT_X0 := 150.0
const SEAT_DX := 66.0
const SEAT_Y := 232.0
## Customers walk along this row (in front of the stools) so they never pass through seated customers.
const AISLE_Y := 300.0
const STREET_X := 700.0
const QUEUE_X0 := 706.0
const QUEUE_DX := 38.0
const EXIT_X := 900.0
## Gold pop-ups: start just above the customer's speech bubble and rise this far.
const POP_Y := SEAT_Y - 34.0
const POP_STACK := 16.0

var sim: Sim
var customer_actors := {}  # customer id -> Actor
var staff_actors := {}  # character id -> Actor
var station_views: Array = []  # {panel, bar, label, style}
var seat_views: Array = []  # {stool, lock}
var pass_label: Label
var sign_label: Label
var info_label: Label
var lantern_label: Label
var _pops := {}  # seat -> [last pop time (s), stack index]


func _ready() -> void:
	sim = Game.sim
	custom_minimum_size = Vector2(W, H)
	size = Vector2(W, H)
	clip_contents = true
	_build_static()
	var e := sim.events
	e.customer_arrived.connect(_on_arrived)
	e.customer_seated.connect(_on_seated)
	e.customer_ordered.connect(_on_ordered)
	e.customer_served.connect(_on_served)
	e.customer_paid.connect(_on_paid)
	e.customer_left.connect(_on_left)
	e.job_started.connect(_on_job_started)
	e.job_ready.connect(_on_job_ready)
	e.job_cancelled.connect(_on_job_cancelled)
	e.delivery_started.connect(_on_delivery_started)
	e.hired.connect(func(_c): _sync_staff())
	e.dismissed.connect(func(_c): _sync_staff())
	e.upgrade_bought.connect(func(_u): _sync_layout())
	e.restaurant_closed.connect(_sync_staff)
	e.station_boosted.connect(_on_boosted)
	Game.resynced.connect(rebuild)
	rebuild()


func _live() -> bool:
	return not Game.catching_up


# --- Static scenery ----------------------------------------------------------

func _build_static() -> void:
	add_child(UIKit.rect(Color("3a2840"), Vector2.ZERO, Vector2(STREET_X, KITCHEN_H)))
	for i in 7:  # back-wall tiles
		add_child(UIKit.rect(Color(1, 1, 1, 0.03), Vector2(i * 100 + 10, 14), Vector2(80, 8), 3))
	add_child(UIKit.rect(Color("261d30"), Vector2(0, KITCHEN_H), Vector2(STREET_X, H - KITCHEN_H)))
	add_child(UIKit.rect(Color("1b2338"), Vector2(STREET_X, 0), Vector2(W - STREET_X, H)))
	add_child(UIKit.rect(Color("27304a"), Vector2(STREET_X, 290), Vector2(W - STREET_X, 110)))
	var street := UIKit.label("Night Market Street", 11, UIKit.MUTED)
	street.position = Vector2(STREET_X + 10, 300)
	add_child(street)
	# counter
	add_child(UIKit.rect(Color("8a5a3b"), Vector2(10, COUNTER_Y), Vector2(STREET_X - 20, 22), 4))
	add_child(UIKit.rect(Color("a8744d"), Vector2(10, COUNTER_Y), Vector2(STREET_X - 20, 5), 3))
	var pass_bg := UIKit.rect(Color("5a3d2a"), Vector2(14, COUNTER_Y - 26), Vector2(120, 26), 4)
	add_child(pass_bg)
	pass_label = UIKit.label("PASS", 14, UIKit.MUTED)
	pass_label.position = Vector2(20, COUNTER_Y - 25)
	add_child(pass_label)
	lantern_label = UIKit.label("", 13)
	lantern_label.position = Vector2(150, 2)
	add_child(lantern_label)
	sign_label = UIKit.label("", 16, UIKit.ACCENT)
	sign_label.position = Vector2(STREET_X + 10, 12)
	add_child(sign_label)
	info_label = UIKit.label("", 12, UIKit.MUTED)
	info_label.position = Vector2(14, H - 24)
	add_child(info_label)
	for i in sim.b.max_seats:
		var x := SEAT_X0 + i * SEAT_DX
		var stool := UIKit.rect(Color("6b4a35"), Vector2(x + 4, SEAT_Y + 56), Vector2(30, 8), 3)
		var leg := UIKit.rect(Color("4d3527"), Vector2(x + 16, SEAT_Y + 64), Vector2(6, 26))
		add_child(leg)
		add_child(stool)
		var lock := UIKit.label("🔒", 14, UIKit.MUTED)
		lock.position = Vector2(x + 10, SEAT_Y + 20)
		add_child(lock)
		seat_views.append({"stool": stool, "leg": leg, "lock": lock})


func _sync_layout() -> void:
	sim.restaurant.ensure_layout()
	var n := sim.seats()
	for i in seat_views.size():
		var on := i < n
		seat_views[i]["stool"].modulate.a = 1.0 if on else 0.25
		seat_views[i]["leg"].modulate.a = 1.0 if on else 0.25
		seat_views[i]["lock"].visible = not on
	# stations
	var sts := sim.restaurant.stations
	while station_views.size() < sts.size():
		var i := station_views.size()
		var st: RestaurantSim.Station = sts[i]
		var pos := Vector2(STATION_X0 + i * STATION_DX, STATION_Y)
		var look: Array = STATION_STYLE.get(st.type, [st.type.capitalize(), Color("444444")])
		var sty := UIKit.style(look[1], 8, UIKit.ACCENT, 0)
		var panel := Panel.new()
		panel.position = pos
		panel.size = STATION_SIZE
		panel.add_theme_stylebox_override("panel", sty)
		panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		panel.tooltip_text = "Click to boost cooking speed"
		panel.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				sim.restaurant.boost_station(i))
		add_child(panel)
		var lbl := UIKit.label(look[0], 13)
		lbl.position = Vector2(6, 6)
		panel.add_child(lbl)
		var dish := UIKit.label("", 22)
		dish.position = Vector2(48, 26)
		panel.add_child(dish)
		var b := UIKit.bar(UIKit.ACCENT, 6)
		b.position = Vector2(6, STATION_SIZE.y - 12)
		b.size = Vector2(STATION_SIZE.x - 12, 6)
		panel.add_child(b)
		station_views.append({"panel": panel, "bar": b, "dish": dish, "style": sty})
	var lv := sim.state.upgrade_level("lanterns")
	lantern_label.text = "  ".join(PackedStringArray(range(3 + lv * 2).map(func(_i): return "🏮")))


# --- Staff -------------------------------------------------------------------

func _idle_pos(c: Character) -> Vector2:
	var same := sim.state.by_role(c.role)
	var i := same.find(c)
	if c.role == Character.CHEF:
		return Vector2(CHEF_IDLE_X0 + i * STAFF_DX, STAFF_Y)
	return Vector2(SERVER_IDLE_X0 - i * STAFF_DX, STAFF_Y)


func _sync_staff() -> void:
	var keep := {}
	for c in sim.restaurant.staff():
		keep[c.id] = true
		if not staff_actors.has(c.id):
			var col := Color("e0c08a") if c.role == Character.CHEF else Color("8ac0e0")
			var a := Actor.new().setup(c.icon(), col, c.name)
			add_child(a)
			staff_actors[c.id] = a
			a.position = _idle_pos(c)
		else:
			var a: Actor = staff_actors[c.id]
			if not sim.restaurant.tasks.has(c.id):
				a.move_to(_idle_pos(c), 0.3)
	for id in staff_actors.keys():
		if not keep.has(id):
			staff_actors[id].queue_free()
			staff_actors.erase(id)


func _staff_back(worker_id: int) -> void:
	var c := sim.state.get_char(worker_id)
	if c and staff_actors.has(worker_id):
		staff_actors[worker_id].move_to(_idle_pos(c), UIKit.real(1.0))
		staff_actors[worker_id].say("")


# --- Customers ---------------------------------------------------------------

func _seat_pos(seat: int) -> Vector2:
	return Vector2(SEAT_X0 + seat * SEAT_DX, SEAT_Y)


func _queue_pos(i: int) -> Vector2:
	return Vector2(QUEUE_X0 + i * QUEUE_DX, SEAT_Y)


func _make_customer(c: RestaurantSim.Customer) -> Actor:
	# No caption: icon + colour identify the type, the tooltip names it.
	var a := Actor.new().setup(c.type.icon, c.type.color, "")
	a.make_clickable()
	a.tooltip_text = "%s — click to hand over a ready dish" % c.type.display_name
	var cid := c.id
	a.clicked.connect(func(): sim.restaurant.serve_now(cid))
	add_child(a)
	customer_actors[c.id] = a
	return a


func _layout_queue() -> void:
	for i in sim.restaurant.queue.size():
		var c: RestaurantSim.Customer = sim.restaurant.queue[i]
		if customer_actors.has(c.id):
			customer_actors[c.id].move_to(_queue_pos(i), UIKit.real(1.0))


func _on_arrived(c) -> void:
	if not _live():
		return
	var a := _make_customer(c)
	a.position = Vector2(EXIT_X, SEAT_Y)
	_layout_queue()


func _on_seated(c) -> void:
	if not _live() or not customer_actors.has(c.id):
		return
	customer_actors[c.id].walk_via(_seat_pos(c.seat), UIKit.real(1.6), AISLE_Y)
	_layout_queue()


func _on_ordered(c) -> void:
	if _live() and customer_actors.has(c.id):
		var a: Actor = customer_actors[c.id]
		a.say(c.recipe.icon)
		a.tooltip_text = "%s — ordered %s. Click to hand it over when ready." % [c.type.display_name, c.recipe.display_name]


func _on_served(c, worker_id: int) -> void:
	if not _live():
		return
	if customer_actors.has(c.id):
		var a: Actor = customer_actors[c.id]
		a.say("😋")
		a.bar.visible = false
	_staff_back(worker_id)


func _on_paid(c, amount: float) -> void:
	if _live() and c.seat >= 0:
		_pop_gold(c.seat, amount)


## Reports where a "+12g" should appear: centred over the seat (seat-wide, so neighbours never overlap).
## Pop-ups at the same seat within a short window stack upward. The main screen animates the flight
## to the HUD, because this view clips anything drawn outside its own rectangle.
func _pop_gold(seat: int, amount: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var prev: Array = _pops.get(seat, [-10.0, -1])
	var n: int = (int(prev[1]) + 1) % 3 if now - float(prev[0]) < 0.4 else 0
	_pops[seat] = [now, n]
	var local := Vector2(SEAT_X0 + seat * SEAT_DX + 19.0 - SEAT_DX / 2.0, POP_Y - n * POP_STACK)
	gold_popped.emit(global_position + local, Vector2(SEAT_DX, 20), amount)


func _on_left(c, reason: String) -> void:
	if not _live() or not customer_actors.has(c.id):
		return
	var a: Actor = customer_actors[c.id]
	customer_actors.erase(c.id)
	a.bar.visible = false
	var emote := ""
	match reason:
		"angry":
			emote = "😠"
		"no_food":
			emote = "🍽❓"
		"impatient":
			emote = "💤"
		"closing":
			emote = "👋"
	# Happy customers leave quietly — the gold pop-up says it all.
	a.say(emote)
	var pause := 0.25 if emote != "" else 0.0
	a.leave_via(Vector2(EXIT_X, AISLE_Y), UIKit.real(2.0), AISLE_Y, pause)
	_layout_queue()


func _on_job_started(job, chef) -> void:
	if not _live() or not staff_actors.has(chef.id):
		return
	var pos := Vector2(STATION_X0 + job.station * STATION_DX + 22, STAFF_Y)
	staff_actors[chef.id].move_to(pos, UIKit.real(0.8))
	staff_actors[chef.id].say("")


func _on_job_ready(_job, chef) -> void:
	if _live() and chef:
		_staff_back(chef.id)


func _on_job_cancelled(_job, worker_id: int) -> void:
	if _live() and worker_id >= 0:
		_staff_back(worker_id)


func _on_delivery_started(job, worker) -> void:
	if not _live() or not staff_actors.has(worker.id) or job.customer == null:
		return
	var a: Actor = staff_actors[worker.id]
	a.say(job.recipe.icon)
	a.move_to(Vector2(SEAT_X0 + job.customer.seat * SEAT_DX, STAFF_Y + 20), UIKit.real(job.deliver_total * 0.9))


func _on_boosted(idx: int) -> void:
	if idx < station_views.size():
		var p: Panel = station_views[idx]["panel"]
		var tw := p.create_tween()
		tw.tween_property(p, "scale", Vector2(1.06, 1.06), 0.08)
		tw.tween_property(p, "scale", Vector2.ONE, 0.12)


# --- Rebuild / per-frame -----------------------------------------------------

func rebuild() -> void:
	for a in customer_actors.values():
		a.queue_free()
	customer_actors.clear()
	_sync_layout()
	for c in sim.restaurant.customers:
		var a := _make_customer(c)
		if c.state == "queue":
			a.position = _queue_pos(sim.restaurant.queue.find(c))
		else:
			a.position = _seat_pos(c.seat)
			if c.recipe:
				a.say(c.recipe.icon if c.state == "waiting" else "😋")
	for a in staff_actors.values():
		a.queue_free()
	staff_actors.clear()
	_sync_staff()


func _process(_delta: float) -> void:
	var r := sim.restaurant
	# patience bars
	for c in r.customers:
		if not customer_actors.has(c.id):
			continue
		var a: Actor = customer_actors[c.id]
		if c.state == "waiting" or c.state == "queue":
			var left := 1.0 - c.wait / maxf(1.0, c.patience)
			a.set_bar(left, UIKit.GOOD if left > 0.5 else (UIKit.ACCENT if left > 0.25 else UIKit.BAD))
	# stations
	for i in mini(station_views.size(), r.stations.size()):
		var st: RestaurantSim.Station = r.stations[i]
		var v: Dictionary = station_views[i]
		v["bar"].value = (st.job.progress / st.job.recipe.cook_time) if st.job else 0.0
		v["dish"].text = st.job.recipe.icon if st.job else ""
		var sty: StyleBoxFlat = v["style"]
		sty.set_border_width_all(3 if st.boost > 0.0 else 0)
		v["panel"].modulate = Color(1, 1, 1, 1) if st.cooldown <= 0.0 or st.boost > 0.0 else Color(0.8, 0.8, 0.8, 1)
	# pass shelf
	var ready := ""
	for j in r.jobs:
		if j.state == "ready":
			ready += j.recipe.icon
	pass_label.text = ready if ready != "" else "PASS"
	# sign + info
	var phase := sim.state.phase
	if phase == Sim.Phase.NIGHT:
		sign_label.text = "🏮 OPEN"
		sign_label.add_theme_color_override("font_color", UIKit.ACCENT)
	elif phase == Sim.Phase.DUSK:
		sign_label.text = "Opening soon…"
		sign_label.add_theme_color_override("font_color", UIKit.MUTED)
	else:
		sign_label.text = "CLOSED (day)"
		sign_label.add_theme_color_override("font_color", UIKit.MUTED)
	var rep := sim.state.report
	info_label.text = "Tonight: %d served · %d no food · %d angry · %d turned away   |   traffic %.2f/s" % [
		rep["served"], rep["no_food"], rep["left_angry"], rep["turned_away"] + rep["left_queue"], sim.traffic()]
