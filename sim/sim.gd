class_name Sim
extends RefCounted
## Pure simulation. Drives live play, offline catch-up and the headless balance script.

enum Phase { DAY, DUSK, NIGHT }
const PHASE_NAMES := ["Day", "Dusk", "Night"]

var db: ContentDB
var b: BalanceConfig
var state: GameState
var events := SimEvents.new()
var rng := RandomNumberGenerator.new()

var expedition: ExpeditionSim
var restaurant: RestaurantSim
var economy: Economy
var progression: Progression
var story: StoryDirector


## p_legacy (from festival_legacy()) starts a new season that keeps ladles, perks and festival count.
func _init(p_db: ContentDB, p_state: GameState = null, p_seed: int = -1, p_legacy: Dictionary = {}) -> void:
	db = p_db
	b = db.balance
	expedition = ExpeditionSim.new(self)
	restaurant = RestaurantSim.new(self)
	economy = Economy.new(self)
	progression = Progression.new(self)
	story = StoryDirector.new(self)
	if p_state == null:
		_new_game(p_seed, p_legacy)
	else:
		state = p_state
		rng.seed = state.rng_seed
		rng.state = state.rng_state
		progression.ensure_parties()
		progression.check_recipe_unlocks(true)
		progression.check_floor_unlocks()
		if state.phase == Phase.NIGHT:
			restaurant.open()
	story.refresh()


func _new_game(p_seed: int, legacy: Dictionary) -> void:
	state = GameState.new()
	if p_seed >= 0:
		rng.seed = p_seed
	else:
		rng.randomize()
	state.rng_seed = rng.seed
	state.ladles = int(legacy.get("ladles", 0))
	state.perks = legacy.get("perks", {}).duplicate()
	state.festivals = int(legacy.get("festivals", 0))
	# Story memories carry over between seasons (scenes don't replay); season bonuses don't.
	var st: Dictionary = legacy.get("story", {}).duplicate(true)
	st["bonuses"] = {}
	st["queue"] = []
	state.story = st
	state.gold = b.start_gold + perk_amount("start_gold")
	state.rice_target = b.rice_target
	state.report = GameState.empty_report()

	var maro := Character.new()
	maro.id = state.new_id()
	maro.name = "Maro"
	maro.role = Character.CHEF
	maro.wage = b.wage_chef
	var pip := Character.new()
	pip.id = state.new_id()
	pip.name = "Pip"
	pip.role = Character.ADVENTURER
	pip.power = 5.0
	pip.luck = 3.0
	pip.wage = b.wage_adventurer
	for i in int(perk_amount("chef_levels")):
		maro.add_xp(maro.xp_to_next(b), b)
	for i in int(perk_amount("adv_levels")):
		pip.add_xp(pip.xp_to_next(b), b)
	pip.stamina = pip.max_stamina
	state.roster.append(maro)
	state.roster.append(pip)

	progression.ensure_parties()  # also auto-assigns Pip to Party A
	progression.check_recipe_unlocks(true)
	progression.refresh_board()
	state.inventory.add("rice", 0, b.rice_target)
	if state.festivals == 0:
		log_msg("You inherit a shabby stall in the Gloamhollow night market. Maro sharpens his knife; Pip heads into the Hollow.", true)
	else:
		log_msg("Season %d begins. The festival lanterns are packed away, but Gloamhollow remembers your cooking." % (state.festivals + 1), true)


# --- Festival of Lanterns (prestige) -----------------------------------------

func can_hold_festival() -> bool:
	return state.slice_complete


## Ladles earned by holding the festival now: 5 for beating the Hive Queen + √(season earnings / 1000).
func festival_award() -> int:
	return 5 + int(floor(sqrt(maxf(0.0, state.run_earned) / 1000.0)))


## What carries over into the next season.
func festival_legacy() -> Dictionary:
	var award := festival_award()
	return {
		"ladles": state.ladles + award, "perks": state.perks.duplicate(),
		"festivals": state.festivals + 1, "award": award, "run_earned": state.run_earned, "days": state.day,
		"story": state.story.duplicate(true),
	}


## Season-long bonuses earned through story choices.
func story_amount(effect: String) -> float:
	return story.bonus(effect)


func perk_amount(effect: String) -> float:
	var t := 0.0
	for p in db.perks:
		if p.effect == effect:
			t += p.amount * state.perk_level(p.id)
	return t


# --- Clock -----------------------------------------------------------------

func tick(dt: float) -> void:
	state.time_total += dt
	_advance_clock(dt)
	expedition.tick(dt)
	if state.phase == Phase.NIGHT:
		restaurant.tick(dt)
	progression.tick(dt)
	state.rng_state = rng.state


## Runs the sim for `seconds` of game time in steps of `dt` (used for offline catch-up).
func step(seconds: float, dt: float) -> void:
	var left := seconds
	while left > 0.0:
		var s := minf(dt, left)
		tick(s)
		left -= s


func phase_length(phase: int) -> float:
	match phase:
		Phase.DAY:
			return b.day_length
		Phase.DUSK:
			return b.dusk_length
		_:
			return b.night_length


func phase_progress() -> float:
	return clampf(state.phase_time / phase_length(state.phase), 0.0, 1.0)


func skip_phase() -> void:
	state.phase_time = phase_length(state.phase)
	_advance_clock(0.0)


func _advance_clock(dt: float) -> void:
	state.phase_time += dt
	while state.phase_time >= phase_length(state.phase):
		state.phase_time -= phase_length(state.phase)
		_end_phase()


func _end_phase() -> void:
	match state.phase:
		Phase.DAY:
			state.phase = Phase.DUSK
			economy.on_dusk()
			restaurant.announce_menu()
		Phase.DUSK:
			state.phase = Phase.NIGHT
			restaurant.open()
		_:
			restaurant.close()
			_dawn()
			state.phase = Phase.DAY
	events.phase_changed.emit(state.phase)


func _dawn() -> void:
	economy.settle_wages()
	state.report["spoiled"] = state.inventory.dawn_age(fresh_days(), db)
	if state.report["spoiled"] > 0:
		log_msg("%d ingredients spoiled overnight." % state.report["spoiled"])
	var rep := state.report.duplicate()
	rep["day"] = state.day
	rep["gold"] = state.gold
	rep["renown"] = state.renown
	state.day += 1
	state.report = GameState.empty_report()
	progression.on_dawn()
	events.day_ended.emit(rep)


# --- Derived values --------------------------------------------------------

func upgrade_amount(effect: String) -> float:
	var t := 0.0
	for u in db.upgrades:
		if u.effect == effect:
			t += u.amount * state.upgrade_level(u.id)
	return t


func seats() -> int:
	return mini(b.max_seats, b.base_seats + int(upgrade_amount("seats")))


func station_count(type: String) -> int:
	match type:
		"grill":
			return b.base_grills + int(upgrade_amount("grill"))
		"pot":
			return b.base_pots + int(upgrade_amount("pot"))
		"oven":
			return b.base_ovens + int(upgrade_amount("oven"))
	return 0


func fresh_days() -> int:
	return b.fresh_days + int(upgrade_amount("freshness"))


func traffic() -> float:
	var t := b.base_traffic * (1.0 + state.renown * b.renown_traffic + upgrade_amount("traffic") + perk_amount("traffic") + story_amount("traffic"))
	return maxf(b.min_traffic, t)


func cook_speed_bonus() -> float:
	return 1.0 + upgrade_amount("cook_speed") + story_amount("cook_speed")


func roster_cap() -> int:
	return b.roster_cap + int(upgrade_amount("roster"))


func party_slots() -> int:
	return 1 + int(upgrade_amount("party"))


func work_factor() -> float:
	return b.debt_slowdown if state.debt > 0.0 else 1.0


func is_on_menu(r: RecipeDef) -> bool:
	return r.id in state.unlocked_recipes and not (r.id in state.disabled_recipes)


func can_cook_now(r: RecipeDef) -> bool:
	return is_on_menu(r) and station_count(r.station) > 0 and state.inventory.has_all(r.ingredients)


# --- Helpers ---------------------------------------------------------------

func add_gold(amount: float) -> void:
	state.gold += amount


func report_add(key: String, amount) -> void:
	state.report[key] = state.report.get(key, 0) + amount


func log_msg(text: String, important: bool = false) -> void:
	var line := "[D%d] %s" % [state.day, text]
	state.log_lines.append(line)
	if state.log_lines.size() > 200:
		state.log_lines = state.log_lines.slice(-200)
	events.logged.emit(line, important)


func weighted_key(weights: Dictionary) -> String:
	var total := 0.0
	for k in weights:
		total += float(weights[k])
	var roll := rng.randf() * total
	for k in weights:
		roll -= float(weights[k])
		if roll <= 0.0:
			return str(k)
	return str(weights.keys().back())
