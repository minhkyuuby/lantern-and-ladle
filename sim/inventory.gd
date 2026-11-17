class_name Inventory
extends RefCounted
## Ingredient stacks keyed by (id, quality, age). Quality: 0 Common, 1 Good, 2 Fine, 3 Perfect.

const QUALITY_NAMES := ["Common", "Good", "Fine", "Perfect"]
const QUALITY_SHORT := ["C", "G", "F", "P"]

## Each stack: {"id": String, "q": int, "age": int, "n": int}
var stacks: Array = []


func add(id: String, q: int, n: int = 1, age: int = 0) -> void:
	if n <= 0:
		return
	for s in stacks:
		if s["id"] == id and s["q"] == q and s["age"] == age:
			s["n"] += n
			return
	stacks.append({"id": id, "q": q, "age": age, "n": n})


func count(id: String) -> int:
	var t := 0
	for s in stacks:
		if s["id"] == id:
			t += int(s["n"])
	return t


func has_all(req: Dictionary) -> bool:
	for id in req:
		if count(id) < int(req[id]):
			return false
	return true


## How many times `req` can be satisfied.
func portions(req: Dictionary) -> int:
	var best := 1 << 30
	for id in req:
		best = mini(best, count(id) / maxi(1, int(req[id])))
	return 0 if req.is_empty() else best


## Takes n items, oldest first (then best quality). Returns the qualities taken.
func take(id: String, n: int) -> Array:
	var mine := stacks.filter(func(s): return s["id"] == id)
	mine.sort_custom(func(a, b): return a["age"] > b["age"] or (a["age"] == b["age"] and a["q"] > b["q"]))
	var out: Array = []
	for s in mine:
		while n > 0 and s["n"] > 0:
			s["n"] -= 1
			n -= 1
			out.append(int(s["q"]))
		if n <= 0:
			break
	_prune()
	return out


func quality_breakdown(id: String) -> Array:
	var out := [0, 0, 0, 0]
	for s in stacks:
		if s["id"] == id:
			out[int(s["q"])] += int(s["n"])
	return out


func oldest_age(id: String) -> int:
	var a := -1
	for s in stacks:
		if s["id"] == id:
			a = maxi(a, int(s["age"]))
	return a


## Called at dawn: perishables age a day and lose one quality tier; too-old stacks spoil.
## Returns the number of spoiled items.
func dawn_age(fresh_days: int, db: ContentDB) -> int:
	var spoiled := 0
	for s in stacks:
		var def: IngredientDef = db.ingredients.get(s["id"])
		if def == null or not def.spoils:
			continue
		s["age"] += 1
		s["q"] = maxi(0, int(s["q"]) - 1)
		if s["age"] > fresh_days:
			spoiled += int(s["n"])
			s["n"] = 0
	_merge()
	return spoiled


func total_items() -> int:
	var t := 0
	for s in stacks:
		t += int(s["n"])
	return t


func _prune() -> void:
	stacks = stacks.filter(func(s): return s["n"] > 0)


func _merge() -> void:
	var old := stacks
	stacks = []
	for s in old:
		if s["n"] > 0:
			add(s["id"], s["q"], s["n"], s["age"])


func to_array() -> Array:
	return stacks.duplicate(true)


func load_array(arr: Array) -> void:
	stacks = []
	for s in arr:
		add(str(s["id"]), int(s["q"]), int(s["n"]), int(s["age"]))
