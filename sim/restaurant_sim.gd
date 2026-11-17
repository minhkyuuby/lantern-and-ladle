class_name RestaurantSim
extends RefCounted
## Night service: customers queue, sit, order, chefs cook at stations, servers deliver, customers pay.

const STATION_TYPES := ["grill", "pot", "oven"]


class Customer:
	extends RefCounted
	var id: int = 0
	var type: CustomerTypeDef
	## queue | waiting | eating | left
	var state: String = "queue"
	var seat: int = -1
	var wait: float = 0.0
	var patience: float = 30.0
	var recipe: RecipeDef
	var job: Job = null
	var quality: int = 0
	var eat_left: float = 0.0


class Job:
	extends RefCounted
	var id: int = 0
	var customer: Customer = null
	var recipe: RecipeDef
	var taken: Array = []  # [ingredient_id, quality] for refunds
	var quality: int = 0
	## queued | cooking | ready | delivering
	var state: String = "queued"
	var progress: float = 0.0
	var station: int = -1
	var worker: int = -1
	var deliver_left: float = 0.0
	var deliver_total: float = 0.0


class Station:
	extends RefCounted
	var type: String = "grill"
	var job: Job = null
	var boost: float = 0.0
	var cooldown: float = 0.0


var sim: Sim
var is_open: bool = false
var customers: Array[Customer] = []
var queue: Array[Customer] = []
var seats: Array = []  # Customer or null
var jobs: Array[Job] = []
var stations: Array[Station] = []
var tasks: Dictionary = {}  # worker char id -> Job
var spawn_acc: float = 0.0
var _next_id: int = 1


func _init(s: Sim) -> void:
	sim = s


func ensure_layout() -> void:
	var n := sim.seats()
	while seats.size() < n:
		seats.append(null)
	for type in STATION_TYPES:
		var have := 0
		for st in stations:
			if st.type == type:
				have += 1
		while have < sim.station_count(type):
			var st := Station.new()
			st.type = type
			stations.append(st)
			have += 1


func staff() -> Array[Character]:
	var out: Array[Character] = []
	for c in sim.state.roster:
		if c.role == Character.CHEF or c.role == Character.SERVER:
			out.append(c)
	return out


func announce_menu() -> void:
	var names: Array[String] = []
	for r in sim.db.recipe_list():
		if sim.can_cook_now(r):
			names.append(r.icon + " " + r.display_name)
	if names.is_empty():
		sim.log_msg("Dusk: nothing to cook tonight… the pantry is empty.")
	else:
		sim.log_msg("Dusk: tonight's menu — " + ", ".join(PackedStringArray(names)))


func open() -> void:
	ensure_layout()
	is_open = true
	spawn_acc = 0.0
	for c in staff():
		c.status = "working"
	sim.events.restaurant_opened.emit()


func close() -> void:
	for c in customers.duplicate():
		_leave(c, "closing")
	for st in stations:
		st.job = null
	jobs.clear()
	tasks.clear()
	queue.clear()
	is_open = false
	for c in staff():
		c.status = "idle"
	sim.events.restaurant_closed.emit()


func tick(dt: float) -> void:
	if not is_open:
		return
	ensure_layout()
	_spawn(dt)
	_tick_queue(dt)
	_seat_from_queue()
	_tick_waiting(dt)
	_assign_workers()
	_tick_cooking(dt)
	_tick_delivery(dt)
	_tick_eating(dt)
	for st in stations:
		st.boost = maxf(0.0, st.boost - dt)
		st.cooldown = maxf(0.0, st.cooldown - dt)


# --- Player actions --------------------------------------------------------

func boost_station(idx: int) -> bool:
	if idx < 0 or idx >= stations.size():
		return false
	var st := stations[idx]
	if st.cooldown > 0.0:
		return false
	st.boost = sim.b.boost_duration
	st.cooldown = sim.b.boost_cooldown
	sim.events.station_boosted.emit(idx)
	return true


## Player hands a ready dish to the customer instantly.
func serve_now(customer_id: int) -> bool:
	for job in jobs:
		if job.customer and job.customer.id == customer_id and (job.state == "ready" or job.state == "delivering"):
			_complete_delivery(job)
			return true
	return false


# --- Customers -------------------------------------------------------------

func _spawn(dt: float) -> void:
	spawn_acc += sim.traffic() * dt * sim.rng.randf_range(0.5, 1.5)
	while spawn_acc >= 1.0:
		spawn_acc -= 1.0
		_spawn_one()


func _pick_type() -> CustomerTypeDef:
	var opts := {}
	for t in sim.db.customer_types:
		if sim.state.renown >= t.min_renown:
			opts[t] = t.weight
	var total := 0.0
	for t in opts:
		total += opts[t]
	var roll := sim.rng.randf() * total
	for t in opts:
		roll -= opts[t]
		if roll <= 0.0:
			return t
	return sim.db.customer_types[0]


func _spawn_one() -> void:
	if queue.size() >= sim.b.max_queue:
		sim.report_add("turned_away", 1)
		sim.events.customer_turned_away.emit()
		return
	var c := Customer.new()
	c.id = _next_id
	_next_id += 1
	c.type = _pick_type()
	c.state = "queue"
	c.patience = sim.b.queue_patience
	customers.append(c)
	queue.append(c)
	sim.events.customer_arrived.emit(c)


func _tick_queue(dt: float) -> void:
	for c in queue.duplicate():
		c.wait += dt
		if c.wait >= c.patience:
			sim.report_add("left_queue", 1)
			_leave(c, "impatient")


func _seat_from_queue() -> void:
	while not queue.is_empty():
		var idx := seats.find(null)
		if idx == -1:
			return
		var c: Customer = queue.pop_front()
		seats[idx] = c
		c.seat = idx
		c.wait = 0.0
		c.patience = c.type.patience
		sim.events.customer_seated.emit(c)
		_order(c)


func _pick_recipe(t: CustomerTypeDef) -> RecipeDef:
	var opts: Array[RecipeDef] = []
	var ws: Array[float] = []
	var total := 0.0
	for r in sim.db.recipe_list():
		if not sim.can_cook_now(r):
			continue
		var w := r.appeal
		for tag in r.tags:
			if tag in t.prefers:
				w *= 3.0
		opts.append(r)
		ws.append(w)
		total += w
	if opts.is_empty():
		return null
	var roll := sim.rng.randf() * total
	for i in opts.size():
		roll -= ws[i]
		if roll <= 0.0:
			return opts[i]
	return opts.back()


func _order(c: Customer) -> void:
	var r := _pick_recipe(c.type)
	if r == null:
		sim.report_add("no_food", 1)
		_leave(c, "no_food")
		return
	var job := Job.new()
	job.id = _next_id
	_next_id += 1
	job.customer = c
	job.recipe = r
	var qsum := 0
	var qn := 0
	for id in r.ingredients:
		for q in sim.state.inventory.take(id, int(r.ingredients[id])):
			job.taken.append([id, q])
			qsum += q
			qn += 1
	job.quality = int(floor(float(qsum) / maxi(1, qn)))
	c.recipe = r
	c.job = job
	c.state = "waiting"
	jobs.append(job)
	sim.events.customer_ordered.emit(c)


func _tick_waiting(dt: float) -> void:
	for c in customers.duplicate():
		if c.state != "waiting":
			continue
		c.wait += dt
		if c.wait >= c.patience:
			sim.report_add("left_angry", 1)
			sim.state.renown = maxf(0.0, sim.state.renown - sim.b.angry_renown_loss)
			_leave(c, "angry")


func _tick_eating(dt: float) -> void:
	for c in customers.duplicate():
		if c.state != "eating":
			continue
		c.eat_left -= dt
		if c.eat_left <= 0.0:
			_pay(c)
			_leave(c, "happy")


func _pay(c: Customer) -> void:
	var r := c.recipe
	var price := r.price * float(sim.b.quality_mult[c.quality]) * c.type.price_mult * (1.0 + sim.perk_amount("price"))
	var mood := clampf(1.0 - c.wait / maxf(1.0, c.patience), 0.0, 1.0)
	var tip := price * sim.b.tip_rate * c.type.tip_mult * (0.5 + mood)
	if c.quality < c.type.min_quality:
		tip = 0.0
	sim.add_gold(price + tip)
	sim.state.run_earned += price + tip
	sim.report_add("revenue", price)
	sim.report_add("tips", tip)
	sim.report_add("served", 1)
	sim.state.renown += c.type.renown_gain * (1.0 + 0.25 * c.quality) * 0.2
	sim.events.customer_paid.emit(c, price + tip)


func _leave(c: Customer, reason: String) -> void:
	if c.job != null:
		_cancel_job(c.job)
		c.job = null
	if c.seat >= 0 and c.seat < seats.size() and seats[c.seat] == c:
		seats[c.seat] = null
	queue.erase(c)
	customers.erase(c)
	c.state = "left"
	sim.events.customer_left.emit(c, reason)


# --- Kitchen ---------------------------------------------------------------

func _cancel_job(job: Job) -> void:
	if job.station >= 0:
		stations[job.station].job = null
	var worker := job.worker
	if worker >= 0:
		tasks.erase(worker)
	if job.state == "queued":
		for e in job.taken:
			sim.state.inventory.add(e[0], e[1])
	jobs.erase(job)
	job.customer = null
	sim.events.job_cancelled.emit(job, worker)


func _first_ready_job() -> Job:
	for job in jobs:
		if job.state == "ready" and job.worker < 0:
			return job
	return null


func _assign_workers() -> void:
	var servers := sim.state.by_role(Character.SERVER)
	var has_servers := not servers.is_empty()
	for chef in sim.state.by_role(Character.CHEF):
		if tasks.has(chef.id):
			continue
		if not has_servers:
			var rj := _first_ready_job()
			if rj:
				_start_delivery(rj, chef, true)
				continue
		_try_cook(chef)
	for s in servers:
		if tasks.has(s.id):
			continue
		var rj := _first_ready_job()
		if rj:
			_start_delivery(rj, s, false)


func _try_cook(chef: Character) -> void:
	for job in jobs:
		if job.state != "queued":
			continue
		for i in stations.size():
			var st := stations[i]
			if st.type == job.recipe.station and st.job == null:
				job.state = "cooking"
				job.station = i
				job.worker = chef.id
				job.progress = 0.0
				st.job = job
				tasks[chef.id] = job
				if job.quality < 3 and sim.rng.randf() < chef.skill * sim.b.skill_quality_chance:
					job.quality += 1
				sim.events.job_started.emit(job, chef)
				return


func _tick_cooking(dt: float) -> void:
	for job in jobs.duplicate():
		if job.state != "cooking":
			continue
		var chef := sim.state.get_char(job.worker)
		var spd := (chef.speed if chef else 1.0) * sim.cook_speed_bonus() * sim.work_factor()
		if stations[job.station].boost > 0.0:
			spd *= sim.b.boost_mult
		job.progress += dt * spd
		if job.progress >= job.recipe.cook_time:
			job.state = "ready"
			stations[job.station].job = null
			job.station = -1
			tasks.erase(job.worker)
			job.worker = -1
			sim.report_add("cooked", 1)
			if chef:
				sim.progression.add_xp(chef, job.recipe.xp)
			sim.events.job_ready.emit(job, chef)


func _start_delivery(job: Job, worker: Character, is_chef: bool) -> void:
	job.state = "delivering"
	job.worker = worker.id
	tasks[worker.id] = job
	var t := sim.b.deliver_time / maxf(0.1, worker.speed) / sim.work_factor()
	if is_chef:
		t *= sim.b.chef_deliver_penalty
	job.deliver_left = t
	job.deliver_total = t
	sim.events.delivery_started.emit(job, worker)


func _tick_delivery(dt: float) -> void:
	for job in jobs.duplicate():
		if job.state != "delivering":
			continue
		job.deliver_left -= dt
		if job.deliver_left <= 0.0:
			_complete_delivery(job)


func _complete_delivery(job: Job) -> void:
	var c := job.customer
	var worker := job.worker
	if worker >= 0:
		tasks.erase(worker)
		var w := sim.state.get_char(worker)
		if w and w.role == Character.SERVER:
			sim.progression.add_xp(w, 1)
	jobs.erase(job)
	job.customer = null
	if c == null:
		return
	c.job = null
	c.quality = job.quality
	c.state = "eating"
	c.eat_left = sim.b.eat_time
	sim.events.customer_served.emit(c, worker)
