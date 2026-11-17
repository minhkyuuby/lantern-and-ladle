class_name StoryDirector
extends RefCounted
## Decides when story scenes play, and owns the story state: flags, affinity, seen scenes,
## the queue of scenes waiting to be shown, and season-long story bonuses.
## Triggers are checks against game state, so scenes queue up even during offline catch-up.

const MAX_AFFINITY := 5

var sim: Sim


func _init(s: Sim) -> void:
	sim = s
	var e := sim.events
	e.phase_changed.connect(func(_p): refresh())
	e.expedition_returned.connect(func(_p, _c): refresh())
	e.floor_unlocked.connect(func(_i): refresh())
	e.upgrade_bought.connect(func(_u): refresh())


func data() -> Dictionary:
	var st := sim.state.story
	for k in ["seen", "affinity", "bonuses"]:
		if not st.has(k) or typeof(st[k]) != TYPE_DICTIONARY:
			st[k] = {}
	for k in ["flags", "queue"]:
		if not st.has(k) or typeof(st[k]) != TYPE_ARRAY:
			st[k] = []
	return st


func queue() -> Array:
	return data()["queue"]


func is_seen(id: String) -> bool:
	return data()["seen"].has(id)


## Queues every scene whose trigger is now met (in @order).
func refresh() -> void:
	var d := data()
	for sc in sim.db.scene_list():
		var id: String = sc["id"]
		if d["seen"].has(id) or id in d["queue"]:
			continue
		if _triggered(sc) and (sc["requires"].is_empty() or check(sc["requires"])):
			d["queue"].append(id)
			sim.events.story_queued.emit(id)


func _triggered(sc: Dictionary) -> bool:
	var t: Array = sc["trigger"]
	if t.is_empty():
		return false
	var s := sim.state
	var arg: String = t[1] if t.size() > 1 else ""
	match t[0]:
		"start":
			return true
		"first_return":
			var dives := 0
			for p in s.parties:
				dives += p.dives
			return dives >= 2 or (dives >= 1 and s.parties[0].state != Party.DIVING)
		"day":
			return s.day >= int(arg)
		"dusk_day":
			return s.phase == Sim.Phase.DUSK and s.day >= int(arg)
		"floor_unlocked":
			return s.max_floor >= int(arg)
		"boss_beaten":
			return int(arg) in s.bosses_beaten
		"dusk_after":
			var seen: Dictionary = data()["seen"]
			return seen.has(arg) and s.phase == Sim.Phase.DUSK and s.day > int(seen[arg])
	return false


## Marks a scene as played and removes it from the queue.
func finish(id: String) -> void:
	var d := data()
	d["queue"].erase(id)
	d["seen"][id] = sim.state.day
	sim.events.story_finished.emit(id)


# --- Conditions & effects ---------------------------------------------------------

func check(cond: Array) -> bool:
	if cond.is_empty():
		return true
	var d := data()
	match cond[0]:
		"flag":
			return cond.size() > 1 and cond[1] in d["flags"]
		"!flag":
			return cond.size() > 1 and not (cond[1] in d["flags"])
		"seen":
			return cond.size() > 1 and d["seen"].has(cond[1])
		"affinity":
			if cond.size() < 4:
				return false
			return _compare(float(affinity(cond[1])), cond[2], _num(cond[3]))
	push_warning("StoryDirector: unknown condition %s" % [cond])
	return false


func _compare(a: float, op: String, b: float) -> bool:
	match op:
		">=":
			return a >= b
		">":
			return a > b
		"<=":
			return a <= b
		"<":
			return a < b
		"==":
			return is_equal_approx(a, b)
	return false


func affinity(who: String) -> int:
	return int(data()["affinity"].get(who, 0))


func bonus(effect: String) -> float:
	return float(data()["bonuses"].get(effect, 0.0))


## Applies one effect and announces it (sim.events.story_effect) for the UI.
func apply(e: Array) -> void:
	if e.is_empty():
		return
	var d := data()
	var a: String = e[1] if e.size() > 1 else ""
	match e[0]:
		"flag":
			if not (a in d["flags"]):
				d["flags"].append(a)
		"unflag":
			d["flags"].erase(a)
		"affinity":
			var n := int(_num(e[2] if e.size() > 2 else "1"))
			var v := clampi(affinity(a) + n, 0, MAX_AFFINITY)
			d["affinity"][a] = v
			sim.events.story_effect.emit("%s %s %s" % ["💛" if n > 0 else "💔", a.capitalize(), ("+%d" % n) if n > 0 else str(n)])
		"gold":
			var g := _num(a)
			sim.add_gold(g)
			sim.events.story_effect.emit("💰 %+dg" % int(g))
		"renown":
			var r := _num(a)
			sim.state.renown = maxf(0.0, sim.state.renown + r)
			sim.events.story_effect.emit("⭐ %+d renown" % int(r))
		"bonus":
			var x := _num(e[2] if e.size() > 2 else "0")
			d["bonuses"][a] = bonus(a) + x
			sim.events.story_effect.emit("✨ %s %+d%% this season" % [_bonus_name(a), int(round(x * 100))])
		_:
			push_warning("StoryDirector: unknown effect %s" % [e])


static func _bonus_name(effect: String) -> String:
	match effect:
		"cook_speed":
			return "Cooking speed"
		"price":
			return "Dish prices"
		"power":
			return "Party power"
		"traffic":
			return "Customer traffic"
	return effect.capitalize()


static func _num(s: String) -> float:
	return float(s.trim_prefix("+"))
