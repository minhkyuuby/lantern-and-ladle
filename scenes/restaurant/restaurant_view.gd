class_name RestaurantView
extends Control
## The stall as one flat side view (everyone only walks left and right):
##   kitchen zone (left)  — chefs stand behind the stove counter and cook
##   serving zone (right) — a long bar; staff walk behind it, customers sit on stools in front
##                          of it (seen from behind) and come and go through the door on the right.

## A customer paid `amount`: show it in a box of `box_size` at `global_pos` (top-left).
signal gold_popped(global_pos: Vector2, box_size: Vector2, amount: float)

const W := 1280.0
const H := 656.0
const CHAR := Vector2(72, 104)  # 18x26 sprites at 4x

const KITCHEN_END := 404.0
const BAR_X0 := 420.0
const BAR_X1 := 1150.0
const COUNTER_TOP := 572.0  # top surface of both counters
const COUNTER_BOTTOM := 648.0
const STAFF_FEET := 606.0  # staff lane, behind the counters
const CUST_FEET := 646.0  # customer lane, in front of the bar
const SEAT_X0 := 448.0
const SEAT_DX := 88.0
const CHEF_X0 := 40.0
const SERVER_X0 := 436.0
const QUEUE_X0 := 1166.0
const QUEUE_DX := 26.0
const EXIT_X := 1310.0
const SHELF := Rect2(290, 440, 220, 44)  # the pass: ready dishes wait here

var sim: Sim
var customer_actors := {}  # customer id -> Actor
var staff_actors := {}  # character id -> Actor
var stools: Array = []  # {seat, leg, lock}
var _layer_staff: Control
var _layer_front: Control
var _layer_cust: Control
var _fx: Control
var _cards: HBoxContainer
var _board_rows: VBoxContainer
var _board_foot: Label
var _board_t := 0.0
var _steam_t := 0.0
var _pops := {}  # seat -> [last pop time, stack index]


func _ready() -> void:
	sim = Game.sim
	custom_minimum_size = Vector2(W, H)
	size = Vector2(W, H)
	clip_contents = true
	_build_back()
	_layer_staff = _layer()
	_build_counters()
	_layer_front = _layer()  # stools
	_layer_cust = _layer()
	_fx = _layer()
	_build_stools()

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
	e.chef_boosted.connect(_on_boosted)
	e.hired.connect(func(_c): _sync_staff())
	e.dismissed.connect(func(_c): _sync_staff())
	e.upgrade_bought.connect(func(_u): _sync_stools())
	e.restaurant_closed.connect(_sync_staff)
	Game.resynced.connect(rebuild)
	rebuild()


func _layer() -> Control:
	var c := Control.new()
	c.size = size
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	return c


func _live() -> bool:
	return not Game.catching_up


# --- Scenery -------------------------------------------------------------------

func _build_back() -> void:
	# warm plank wall
	add_child(UIKit.rect(Color("4a3328"), Vector2.ZERO, Vector2(W, COUNTER_TOP + 20)))
	for i in 17:
		add_child(UIKit.rect(Color("3e2a21"), Vector2(i * 78 + 30, 0), Vector2(2, COUNTER_TOP + 20)))
	add_child(UIKit.rect(Color("5a3e2e"), Vector2(0, 0), Vector2(W, 14)))
	add_child(UIKit.rect(Color("6e4a34"), Vector2(0, 92), Vector2(W, 8)))  # beam
	# kitchen: tiled wall, hood, sign
	add_child(UIKit.rect(Color("54402f"), Vector2(0, 100), Vector2(KITCHEN_END, COUNTER_TOP - 80)))
	for y in range(110, int(COUNTER_TOP) - 20, 26):
		for x in range(8 + (y / 26 % 2) * 13, int(KITCHEN_END) - 20, 26):
			add_child(UIKit.rect(Color(1, 1, 1, 0.035), Vector2(x, y), Vector2(22, 22), 2))
	add_child(UIKit.rect(Color("6a4a3a"), Vector2(20, 300), Vector2(KITCHEN_END - 40, 26), 6))  # hood
	add_child(UIKit.rect(Color("7a5644"), Vector2(36, 326), Vector2(KITCHEN_END - 72, 10), 3))
	var ks := UIKit.label("~ KITCHEN ~", 14, Color("f2d8b0"))
	ks.position = Vector2(KITCHEN_END / 2 - 48, 304)
	add_child(ks)
	add_child(UIKit.rect(Color("3a281f"), Vector2(KITCHEN_END, 100), Vector2(14, COUNTER_TOP)))  # pillar
	# serving zone: tonight's menu board, and a shelf of jars
	_build_board(Rect2(560, 130, 330, 250))
	add_child(UIKit.rect(Color("6e4a34"), Vector2(920, 372), Vector2(210, 8), 2))
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for j in 7:
		var cols := [Color("e8b860"), Color("9bcf7a"), Color("e2805f"), Color("c8b0e0"), Color("f0d8a8"), Color("8cc4b8")]
		var c: Color = cols[j % cols.size()].darkened(0.12)
		var hgt := rng.randi_range(18, 30)
		add_child(UIKit.rect(c, Vector2(930 + j * 28, 372 - hgt), Vector2(16, hgt), 4))
		add_child(UIKit.rect(Color("8a5a3c"), Vector2(933 + j * 28, 368 - hgt), Vector2(10, 4), 1))
	# the pass shelf where finished dishes wait
	add_child(UIKit.rect(Color("6e4a34"), Vector2(SHELF.position.x, SHELF.end.y), Vector2(SHELF.size.x, 8), 2))
	var pass_lbl := UIKit.label("PASS", 11, Color("c8a888"))
	pass_lbl.position = Vector2(SHELF.position.x + 4, SHELF.end.y + 8)
	add_child(pass_lbl)
	_cards = HBoxContainer.new()
	_cards.position = SHELF.position
	_cards.size = SHELF.size
	_cards.add_theme_constant_override("separation", 4)
	_cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cards)
	# door and the night street outside
	add_child(UIKit.rect(Color("1e2336"), Vector2(1162, 180), Vector2(W - 1162, H - 180)))
	for i in 10:
		add_child(UIKit.rect(Color(1, 0.95, 0.8, rng.randf_range(0.3, 0.9)), Vector2(rng.randf_range(1172, 1270), rng.randf_range(196, 440)), Vector2(2, 2)))
	add_child(UIKit.rect(Color("3a281f"), Vector2(1152, 170), Vector2(12, H - 170)))
	# floor
	add_child(UIKit.rect(Color("2e2119"), Vector2(0, COUNTER_BOTTOM), Vector2(W, H - COUNTER_BOTTOM)))
	add_child(UIKit.rect(Color("3a2a20"), Vector2(0, COUNTER_BOTTOM), Vector2(W, 3)))
	# hanging lanterns and their light
	for x in [200, 520, 930, 1080]:
		add_child(_glow(Vector2(x, 140), 190, Color(1.0, 0.72, 0.42, 0.17)))
		add_child(UIKit.rect(Color("8a5a3c"), Vector2(x - 1, 100), Vector2(2, 26)))
		add_child(UIKit.rect(Color("f0a860"), Vector2(x - 9, 126), Vector2(18, 22), 6))
		add_child(UIKit.rect(Color("ffd890"), Vector2(x - 5, 131), Vector2(10, 12), 4))


func _build_counters() -> void:
	# kitchen stove counter
	add_child(UIKit.rect(Color("4a3a36"), Vector2(16, COUNTER_TOP), Vector2(KITCHEN_END - 24, 12), 3))
	add_child(UIKit.rect(Color("7a4a38"), Vector2(16, COUNTER_TOP + 12), Vector2(KITCHEN_END - 24, COUNTER_BOTTOM - COUNTER_TOP - 12)))
	for x in range(26, int(KITCHEN_END) - 20, 46):
		add_child(UIKit.rect(Color("8a5440"), Vector2(x, COUNTER_TOP + 22), Vector2(38, 18), 3))
		add_child(UIKit.rect(Color("8a5440"), Vector2(x, COUNTER_TOP + 46), Vector2(38, 18), 3))
	# serving bar
	add_child(_glow(Vector2((BAR_X0 + BAR_X1) / 2, COUNTER_TOP), 420, Color(1.0, 0.65, 0.35, 0.10)))
	add_child(UIKit.rect(Color("b07a4e"), Vector2(BAR_X0, COUNTER_TOP), Vector2(BAR_X1 - BAR_X0, 12), 4))
	add_child(UIKit.rect(Color("8a5a3b"), Vector2(BAR_X0 + 6, COUNTER_TOP + 12), Vector2(BAR_X1 - BAR_X0 - 12, COUNTER_BOTTOM - COUNTER_TOP - 12)))
	for x in range(int(BAR_X0) + 30, int(BAR_X1) - 20, 64):
		add_child(UIKit.rect(Color("7a4e34"), Vector2(x, COUNTER_TOP + 16), Vector2(3, COUNTER_BOTTOM - COUNTER_TOP - 22)))


func _build_stools() -> void:
	for i in sim.b.max_seats:
		var x := _seat_x(i) + CHAR.x / 2.0
		var leg := UIKit.rect(Color("4d3527"), Vector2(x - 3, CUST_FEET - 20), Vector2(6, H - CUST_FEET + 20))
		var seat := UIKit.rect(Color("8a5a3c"), Vector2(x - 20, CUST_FEET - 24), Vector2(40, 9), 4)
		_layer_front.add_child(leg)
		_layer_front.add_child(seat)
		var lock := UIKit.label("🔒", 14, UIKit.MUTED)
		lock.position = Vector2(x - 9, COUNTER_TOP - 22)
		_layer_front.add_child(lock)
		stools.append({"seat": seat, "leg": leg, "lock": lock})


func _sync_stools() -> void:
	sim.restaurant.ensure_layout()
	var n := sim.seats()
	for i in stools.size():
		var on := i < n
		stools[i]["seat"].modulate.a = 1.0 if on else 0.3
		stools[i]["leg"].modulate.a = 1.0 if on else 0.3
		stools[i]["lock"].visible = not on


# --- Positions -----------------------------------------------------------------

func _seat_x(i: int) -> float:
	return SEAT_X0 + i * SEAT_DX


func _cust_pos(x: float) -> Vector2:
	return Vector2(x, CUST_FEET - CHAR.y)


func _staff_pos(x: float) -> Vector2:
	return Vector2(x, STAFF_FEET - CHAR.y)


func _idle_pos(c: Character) -> Vector2:
	var same := sim.state.by_role(c.role)
	var i := same.find(c)
	if c.role == Character.CHEF:
		var dx := minf(110.0, (KITCHEN_END - CHEF_X0 - CHAR.x - 10.0) / maxf(1.0, same.size() - 1))
		return _staff_pos(CHEF_X0 + i * dx)
	return _staff_pos(SERVER_X0 + i * 60.0)


# --- Staff -----------------------------------------------------------------------

func _sync_staff() -> void:
	var keep := {}
	for c in sim.restaurant.staff():
		keep[c.id] = true
		if not staff_actors.has(c.id):
			var a := Actor.new().setup(c.icon(), Color("e0c08a"), "", CHAR, SpriteLib.crew(c))
			a.tooltip_text = "%s the %s" % [c.name, c.role_name()]
			if c.role == Character.CHEF:
				a.make_clickable()
				a.tooltip_text += " — click to cheer them on (cooks faster for a moment)"
				var cid := c.id
				a.clicked.connect(func(): sim.restaurant.boost_chef(cid))
			_layer_staff.add_child(a)
			staff_actors[c.id] = a
			a.position = _idle_pos(c)
		elif not sim.restaurant.tasks.has(c.id) or c.role == Character.CHEF:
			if not (sim.restaurant.tasks.has(c.id) and sim.restaurant.tasks[c.id].state == "delivering"):
				staff_actors[c.id].move_to(_idle_pos(c), 0.3)
	for id in staff_actors.keys():
		if not keep.has(id):
			staff_actors[id].queue_free()
			staff_actors.erase(id)


func _staff_back(worker_id: int) -> void:
	var c := sim.state.get_char(worker_id)
	if c and staff_actors.has(worker_id):
		var a: Actor = staff_actors[worker_id]
		var to := _idle_pos(c)
		a.move_to(to, UIKit.real(absf(a.position.x - to.x) / 260.0 + 0.2))
		a.say("")


# --- Customers -------------------------------------------------------------------

func _make_customer(c: RestaurantSim.Customer) -> Actor:
	var tex := SpriteLib.customer(c.type.id + "_back")
	if tex == null:
		tex = SpriteLib.customer(c.type.id)
	var a := Actor.new().setup(c.type.icon, c.type.color, "", CHAR, tex)
	a.bubble.position.y = -106.0  # order bubble floats above the staff lane behind the bar
	a.bar.position.y = -78.0
	a.make_clickable()
	a.tooltip_text = "%s — click to hand over a ready dish" % c.type.display_name
	var cid := c.id
	a.clicked.connect(func(): sim.restaurant.serve_now(cid))
	_layer_cust.add_child(a)
	customer_actors[c.id] = a
	return a


func _layout_queue() -> void:
	for i in sim.restaurant.queue.size():
		var c: RestaurantSim.Customer = sim.restaurant.queue[i]
		if customer_actors.has(c.id):
			customer_actors[c.id].move_to(_cust_pos(QUEUE_X0 + i * QUEUE_DX), UIKit.real(0.8))


func _on_arrived(c) -> void:
	if not _live():
		return
	var a := _make_customer(c)
	a.position = _cust_pos(EXIT_X)
	_layout_queue()


func _on_seated(c) -> void:
	if not _live() or not customer_actors.has(c.id):
		return
	var a: Actor = customer_actors[c.id]
	var to := _cust_pos(_seat_x(c.seat))
	a.move_to(to, UIKit.real(absf(a.position.x - to.x) / 300.0 + 0.2))
	_layout_queue()


func _on_ordered(c) -> void:
	if _live() and customer_actors.has(c.id):
		var a: Actor = customer_actors[c.id]
		a.say(c.recipe.icon)
		a.tooltip_text = "%s — ordered %s. Click to hand it over when it's ready." % [c.type.display_name, c.recipe.display_name]


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


## Reports where a "+12g" should start (over the seat); main.gd flies it to the HUD gold counter.
func _pop_gold(seat: int, amount: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var prev: Array = _pops.get(seat, [-10.0, -1])
	var n: int = (int(prev[1]) + 1) % 3 if now - float(prev[0]) < 0.4 else 0
	_pops[seat] = [now, n]
	var local := Vector2(_seat_x(seat) + CHAR.x / 2.0 - SEAT_DX / 2.0, CUST_FEET - CHAR.y - 132.0 - n * 16.0)
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
	a.say(emote)
	var dur := UIKit.real(absf(EXIT_X - a.position.x) / 300.0 + 0.2)
	var tw := a.create_tween()
	if emote != "":
		tw.tween_interval(0.3)
	tw.tween_callback(a.say.bind(""))
	tw.tween_property(a, "position:x", EXIT_X, dur).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(a.queue_free)
	_layout_queue()


# --- Kitchen ---------------------------------------------------------------------

func _on_job_started(job, chef) -> void:
	if _live() and staff_actors.has(chef.id):
		staff_actors[chef.id].say(job.recipe.icon)


func _on_job_ready(_job, chef) -> void:
	if _live() and chef and staff_actors.has(chef.id):
		staff_actors[chef.id].say("")
		staff_actors[chef.id].bar.visible = false


func _on_job_cancelled(_job, worker_id: int) -> void:
	if _live() and worker_id >= 0:
		_staff_back(worker_id)


func _on_delivery_started(job, worker) -> void:
	if not _live() or not staff_actors.has(worker.id) or job.customer == null:
		return
	var a: Actor = staff_actors[worker.id]
	a.say(job.recipe.icon)
	a.bar.visible = false
	a.move_to(_staff_pos(_seat_x(job.customer.seat)), UIKit.real(job.deliver_total * 0.9))


func _on_boosted(chef_id: int) -> void:
	if staff_actors.has(chef_id):
		var a: Actor = staff_actors[chef_id]
		a.pivot_offset = Vector2(CHAR.x / 2.0, CHAR.y)
		var tw := a.create_tween()
		tw.tween_property(a, "scale", Vector2(1.12, 0.9), 0.07)
		tw.tween_property(a, "scale", Vector2(0.95, 1.08), 0.08)
		tw.tween_property(a, "scale", Vector2.ONE, 0.1)
		_puff(a.position.x + CHAR.x / 2.0, a.position.y - 6.0, Color("ffd36a"), "✨")


# --- Rebuild / per-frame -----------------------------------------------------------

func rebuild() -> void:
	for a in customer_actors.values():
		a.queue_free()
	customer_actors.clear()
	_sync_stools()
	for c in sim.restaurant.customers:
		var a := _make_customer(c)
		if c.state == "queue":
			a.position = _cust_pos(QUEUE_X0 + sim.restaurant.queue.find(c) * QUEUE_DX)
		else:
			a.position = _cust_pos(_seat_x(c.seat))
			if c.recipe:
				a.say(c.recipe.icon if c.state == "waiting" else "😋")
	for a in staff_actors.values():
		a.queue_free()
	staff_actors.clear()
	_sync_staff()


func _process(delta: float) -> void:
	var r := sim.restaurant
	# patience bars over waiting customers
	for c in r.customers:
		if not customer_actors.has(c.id):
			continue
		var a: Actor = customer_actors[c.id]
		if c.state == "waiting" or c.state == "queue":
			var left := 1.0 - c.wait / maxf(1.0, c.patience)
			a.set_bar(left, UIKit.GOOD if left > 0.5 else (UIKit.ACCENT if left > 0.25 else UIKit.BAD))
	# cooking progress over each busy chef, plus a little steam from the stove
	_steam_t += delta
	var puff := _steam_t >= 0.35
	if puff:
		_steam_t = 0.0
	for id in r.tasks:
		var job: RestaurantSim.Job = r.tasks[id]
		if job.state != "cooking" or not staff_actors.has(id):
			continue
		var a: Actor = staff_actors[id]
		a.set_bar(job.progress / job.recipe.cook_time, UIKit.ACCENT if r.is_boosted(id) else UIKit.GOOD)
		if puff and _live():
			_puff(a.position.x + CHAR.x / 2.0 + randf_range(-10, 10), COUNTER_TOP - 6.0, Color(1, 0.97, 0.92, 0.7))
	# ready dishes on the pass shelf
	var ready: Array = []
	for j in r.jobs:
		if j.state == "ready":
			ready.append(j.recipe.icon)
	if _cards.get_child_count() != mini(ready.size(), 6) or (_cards.get_child_count() > 0 and _cards.get_child(0).get_meta("icons", "") != "".join(ready)):
		for ch in _cards.get_children():
			ch.free()
		for k in mini(ready.size(), 6):
			var card := PanelContainer.new()
			card.add_theme_stylebox_override("panel", UIKit.style(Color("f6ead2"), 5, Color("7a4e34"), 2, 2))
			card.custom_minimum_size = Vector2(30, 40)
			card.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var l := UIKit.label(ready[k], 18)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			card.add_child(l)
			card.set_meta("icons", "".join(ready))
			_cards.add_child(card)
	_board_t -= delta
	if _board_t <= 0.0:
		_board_t = 1.0
		_update_board()


## Chalkboard on the back wall: what can be cooked tonight, and how the night is going.
func _build_board(r: Rect2) -> void:
	add_child(UIKit.rect(Color("6e4a34"), r.position - Vector2(8, 8), r.size + Vector2(16, 16), 6))
	add_child(UIKit.rect(Color("2f3a30"), r.position, r.size, 3))
	var title := UIKit.label("Tonight's Menu", 18, Color("f6ead2"))
	title.position = r.position + Vector2(14, 8)
	add_child(title)
	_board_rows = VBoxContainer.new()
	_board_rows.position = r.position + Vector2(14, 40)
	_board_rows.size = Vector2(r.size.x - 28, r.size.y - 74)
	_board_rows.add_theme_constant_override("separation", 2)
	_board_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_board_rows)
	_board_foot = UIKit.label("", 12, Color("c9d6c0"))
	_board_foot.position = r.position + Vector2(14, r.size.y - 26)
	add_child(_board_foot)


func _update_board() -> void:
	for ch in _board_rows.get_children():
		ch.free()
	var shown := 0
	for rec in sim.db.recipe_list():
		if not sim.is_on_menu(rec):
			continue
		var n := sim.state.inventory.portions(rec.ingredients)
		if n <= 0 or shown >= 6:
			continue
		shown += 1
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var name := UIKit.label("%s  %s" % [rec.icon, rec.display_name], 14, Color("f6ead2"))
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name.clip_text = true
		row.add_child(name)
		row.add_child(UIKit.label("%dg  ×%d" % [rec.price, n], 13, Color("f2c870")))
		_board_rows.add_child(row)
	if shown == 0:
		_board_rows.add_child(UIKit.label("(the pantry is empty)", 14, Color("c9d6c0")))
	var rep := sim.state.report
	var lost: int = rep["no_food"] + rep["left_angry"] + rep["turned_away"] + rep["left_queue"]
	_board_foot.text = "Served tonight: %d   ·   missed: %d" % [rep["served"], lost]


## A small rising puff (steam, sparkle) at x, y.
func _puff(x: float, y: float, color: Color, text: String = "") -> void:
	var p: Control
	if text != "":
		p = UIKit.label(text, 16, color)
	else:
		p = UIKit.rect(color, Vector2.ZERO, Vector2(8, 8), 4)
	p.position = Vector2(x - 4, y)
	_fx.add_child(p)
	var tw := p.create_tween().set_parallel(true)
	tw.tween_property(p, "position:y", y - 34.0, 0.9).set_ease(Tween.EASE_OUT)
	tw.tween_property(p, "modulate:a", 0.0, 0.9)
	tw.chain().tween_callback(p.queue_free)


## Soft radial light (centre `pos`, radius `r`) that fades to nothing.
func _glow(pos: Vector2, r: float, color: Color) -> TextureRect:
	var g := Gradient.new()
	g.set_color(0, color)
	g.set_color(1, Color(color.r, color.g, color.b, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	var t := TextureRect.new()
	t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.size = Vector2(r * 2, r * 2)
	t.position = pos - Vector2(r, r)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t
