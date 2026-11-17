class_name DialogRunner
extends RefCounted
## Steps through one parsed scene. The UI calls advance() to get the next thing to show
## ("say", "choice" or "end") and choose() when the player picks an option.

var scene: Dictionary
var director: StoryDirector
var pc: int = 0
var finished: bool = false


func _init(p_scene: Dictionary, p_director: StoryDirector) -> void:
	scene = p_scene
	director = p_director


## Runs effects and jumps until something needs showing.
## Returns {"t": "say", who, face, text} | {"t": "choice", options: [{text, index}]} | {"t": "end"}.
func advance() -> Dictionary:
	var steps: Array = scene["steps"]
	var guard := 0
	while pc < steps.size() and guard < 1000:
		guard += 1
		var st: Dictionary = steps[pc]
		match st["t"]:
			"say":
				pc += 1
				return st
			"choice":
				var shown: Array = []
				for i in st["options"].size():
					var opt: Dictionary = st["options"][i]
					if opt["cond"].is_empty() or director.check(opt["cond"]):
						shown.append({"text": opt["text"], "index": i})
				if shown.is_empty():
					pc += 1
					continue
				return {"t": "choice", "options": shown}
			"do":
				director.apply(st["effect"])
				pc += 1
			"goto":
				_jump(st["to"])
			"if":
				if director.check(st["cond"]):
					_jump(st["to"])
				else:
					pc += 1
			_:
				pc = steps.size()
	finished = true
	return {"t": "end"}


## Picks option `index` (the original index from the choice step) at the current choice.
func choose(index: int) -> void:
	var st: Dictionary = scene["steps"][pc]
	if st["t"] != "choice":
		return
	_jump(st["options"][index]["goto"])


func _jump(label: String) -> void:
	if label == "end":
		pc = scene["steps"].size()
	else:
		pc = int(scene["labels"].get(label, scene["steps"].size()))
