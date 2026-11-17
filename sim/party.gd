class_name Party
extends RefCounted

const IDLE := "idle"
const DIVING := "diving"
const RESTING := "resting"

var id: int = 0
var name: String = "Party A"
var members: Array[int] = []
## Floor chosen by the player (used when auto_floor is false).
var floor_index: int = 1
## Auto: let the party pick its floor (see auto_mode).
var auto_floor: bool = true
## "deepest": deepest floor with a safe success chance.
## "restock": the safe floor whose loot best covers what the menu is short of.
var auto_mode: String = "deepest"
## Standing order: keep diving whenever rested.
var repeat: bool = true
var state: String = IDLE
## Number of dives started (lets views notice back-to-back dives).
var dives: int = 0

# Active dive
var current_floor: int = 1
var elapsed: float = 0.0
var duration: float = 0.0
var room_count: int = 0
var room_idx: int = 0
var room_results: Array = []  # "win" | "fail" | "forage" | "treasure" | "boss" | "boss_fail"
var loot: Array = []  # [ingredient_id, quality]
var boss_defeated: bool = false
var last_log: String = ""


func to_dict() -> Dictionary:
	return {
		"id": id, "name": name, "members": Array(members), "floor_index": floor_index,
		"auto_floor": auto_floor, "auto_mode": auto_mode, "repeat": repeat, "state": state, "dives": dives,
		"current_floor": current_floor, "elapsed": elapsed, "duration": duration,
		"room_count": room_count, "room_idx": room_idx, "room_results": room_results.duplicate(),
		"loot": loot.duplicate(true), "boss_defeated": boss_defeated, "last_log": last_log,
	}


static func from_dict(d: Dictionary) -> Party:
	var p := Party.new()
	p.id = int(d.get("id", 0))
	p.name = str(d.get("name", "Party"))
	for m in d.get("members", []):
		p.members.append(int(m))
	p.floor_index = int(d.get("floor_index", 1))
	p.auto_floor = bool(d.get("auto_floor", true))
	p.auto_mode = str(d.get("auto_mode", "deepest"))
	p.repeat = bool(d.get("repeat", true))
	p.state = str(d.get("state", IDLE))
	p.dives = int(d.get("dives", 0))
	p.current_floor = int(d.get("current_floor", 1))
	p.elapsed = float(d.get("elapsed", 0.0))
	p.duration = float(d.get("duration", 0.0))
	p.room_count = int(d.get("room_count", 0))
	p.room_idx = int(d.get("room_idx", 0))
	p.room_results = Array(d.get("room_results", []))
	for e in d.get("loot", []):
		p.loot.append([str(e[0]), int(e[1])])
	p.boss_defeated = bool(d.get("boss_defeated", false))
	p.last_log = str(d.get("last_log", ""))
	return p
