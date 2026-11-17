class_name GameState
extends RefCounted
## Everything that is saved. Restaurant customers/jobs are transient and not part of it.

var gold: float = 0.0
var renown: float = 0.0
var debt: float = 0.0
var day: int = 1
var phase: int = 0
var phase_time: float = 0.0
var time_total: float = 0.0

var inventory := Inventory.new()
var roster: Array[Character] = []
var parties: Array[Party] = []
var candidates: Array[Character] = []
var board_day: int = 1

var upgrades: Dictionary = {}  # upgrade id -> level
var unlocked_recipes: Array[String] = []
var disabled_recipes: Array[String] = []
var scrolls: Array[String] = []
var max_floor: int = 1
var floors_cleared: Dictionary = {}  # "1" -> count
var bosses_beaten: Array[int] = []  # floor indices whose boss is defeated
## True once the deepest floor's boss is beaten.
var slice_complete: bool = false
var rice_target: int = 10

# Legacy — carried over by the Festival of Lanterns.
var ladles: int = 0
var perks: Dictionary = {}  # perk id -> level
var festivals: int = 0
## Revenue + tips earned this season (drives the festival's ladle award).
var run_earned: float = 0.0

var report: Dictionary = {}
var log_lines: Array[String] = []
var next_id: int = 1
var rng_seed: int = 0
var rng_state: int = 0


func new_id() -> int:
	next_id += 1
	return next_id - 1


func upgrade_level(id: String) -> int:
	return int(upgrades.get(id, 0))


func perk_level(id: String) -> int:
	return int(perks.get(id, 0))


func get_char(id: int) -> Character:
	for c in roster:
		if c.id == id:
			return c
	return null


func by_role(role: String) -> Array[Character]:
	var out: Array[Character] = []
	for c in roster:
		if c.role == role:
			out.append(c)
	return out


func party_of(char_id: int) -> Party:
	for p in parties:
		if char_id in p.members:
			return p
	return null


func cleared_count(floor_index: int) -> int:
	return int(floors_cleared.get(str(floor_index), 0))


static func empty_report() -> Dictionary:
	return {
		"served": 0, "revenue": 0.0, "tips": 0.0, "cooked": 0,
		"turned_away": 0, "left_queue": 0, "no_food": 0, "left_angry": 0,
		"wages_paid": 0.0, "debt": 0.0, "market_spent": 0.0,
		"spoiled": 0, "loot": 0,
	}


func to_dict() -> Dictionary:
	var d := {
		"gold": gold, "renown": renown, "debt": debt, "day": day, "phase": phase,
		"phase_time": phase_time, "time_total": time_total,
		"inventory": inventory.to_array(),
		"roster": roster.map(func(c): return c.to_dict()),
		"parties": parties.map(func(p): return p.to_dict()),
		"candidates": candidates.map(func(c): return c.to_dict()),
		"board_day": board_day, "upgrades": upgrades.duplicate(),
		"unlocked_recipes": Array(unlocked_recipes), "disabled_recipes": Array(disabled_recipes),
		"scrolls": Array(scrolls), "max_floor": max_floor, "floors_cleared": floors_cleared.duplicate(),
		"slice_complete": slice_complete, "bosses_beaten": Array(bosses_beaten), "rice_target": rice_target,
		"ladles": ladles, "perks": perks.duplicate(), "festivals": festivals, "run_earned": run_earned,
		"report": report.duplicate(), "log_lines": Array(log_lines.slice(-60)),
		"next_id": next_id, "rng_seed": str(rng_seed), "rng_state": str(rng_state),
	}
	return d


static func from_dict(d: Dictionary) -> GameState:
	var s := GameState.new()
	s.gold = float(d.get("gold", 0))
	s.renown = float(d.get("renown", 0))
	s.debt = float(d.get("debt", 0))
	s.day = int(d.get("day", 1))
	s.phase = int(d.get("phase", 0))
	s.phase_time = float(d.get("phase_time", 0))
	s.time_total = float(d.get("time_total", 0))
	s.inventory.load_array(d.get("inventory", []))
	for c in d.get("roster", []):
		s.roster.append(Character.from_dict(c))
	for p in d.get("parties", []):
		s.parties.append(Party.from_dict(p))
	for c in d.get("candidates", []):
		s.candidates.append(Character.from_dict(c))
	s.board_day = int(d.get("board_day", 1))
	for k in d.get("upgrades", {}):
		s.upgrades[str(k)] = int(d["upgrades"][k])
	s.unlocked_recipes.assign(d.get("unlocked_recipes", []))
	s.disabled_recipes.assign(d.get("disabled_recipes", []))
	s.scrolls.assign(d.get("scrolls", []))
	s.max_floor = int(d.get("max_floor", 1))
	for k in d.get("floors_cleared", {}):
		s.floors_cleared[str(k)] = int(d["floors_cleared"][k])
	s.slice_complete = bool(d.get("slice_complete", false))
	if d.has("bosses_beaten"):
		for f in d["bosses_beaten"]:
			s.bosses_beaten.append(int(f))
	elif s.slice_complete:
		# Saves from the one-biome prototype: "slice complete" meant the Rat King (Floor 3) was beaten.
		s.bosses_beaten.append(3)
		s.slice_complete = false
	s.rice_target = int(d.get("rice_target", 10))
	s.ladles = int(d.get("ladles", 0))
	for k in d.get("perks", {}):
		s.perks[str(k)] = int(d["perks"][k])
	s.festivals = int(d.get("festivals", 0))
	s.run_earned = float(d.get("run_earned", 0.0))
	s.report = empty_report()
	var rep: Dictionary = d.get("report", {})
	for k in rep:
		s.report[k] = rep[k]
	s.log_lines.assign(d.get("log_lines", []))
	s.next_id = int(d.get("next_id", 1))
	s.rng_seed = int(str(d.get("rng_seed", "0")))
	s.rng_state = int(str(d.get("rng_state", "0")))
	return s
