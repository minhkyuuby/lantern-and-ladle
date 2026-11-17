class_name DialogParser
extends RefCounted
## Parses the .dlg story-script format into a flat list of steps.
##
##   # comment
##   @id ch1_inheritance            scene id (required)
##   @title Inheritance             shown in the corner of the scene
##   @trigger start                 start | first_return | day N | dusk_day N | floor_unlocked N |
##                                  boss_beaten N | dusk_after SCENE_ID
##   @order 10                      lower plays first when several are queued
##   @requires flag some_flag       optional extra condition (same syntax as ? below)
##
##   == label                       a jump target; blocks fall through to the next one
##   maro (happy): Text…            a line; "(expression)" is optional; "narrator: …" has no portrait
##   ~ affinity maro +1             an effect: flag X | unflag X | affinity WHO ±N | gold ±N |
##                                  renown ±N | bonus EFFECT ±X  (cook_speed, price, power, traffic)
##   -> label                       jump ("-> end" ends the scene)
##   ? flag x -> label              conditional jump: flag X | !flag X | affinity WHO >= N | seen ID
##   * "Option text"                consecutive * lines form one choice; indented lines under an
##     ? flag x                     option are its body: an optional "? cond" first (show only if),
##     ~ effect / line / -> label   then effects, lines and jumps. Without a jump, play continues
##                                  after the choice.

var sc := {}
var _steps: Array = []
var _labels := {}
var _group: Array = []  # options of the open choice group
var _cur = null  # option currently collecting its body
var _deferred: Array = []  # [label, body lines, after label]
var _n_choice := 0
var _say_re := RegEx.new()


static func parse(text: String, source: String = "") -> Dictionary:
	var p := DialogParser.new()
	return p._parse(text, source)


func _parse(text: String, source: String) -> Dictionary:
	_say_re.compile("^([a-z_]+)(?:\\s*\\(([a-z_]+)\\))?\\s*:\\s*(.*)$")
	sc = {"id": "", "title": "", "trigger": [], "order": 100, "requires": [], "steps": _steps,
		"labels": _labels, "errors": [], "source": source}
	var lines := text.split("\n")
	for i in lines.size():
		var raw: String = lines[i]
		var line := raw.strip_edges()
		if line == "" or line.begins_with("#"):
			continue
		var indented := raw.begins_with(" ") or raw.begins_with("\t")
		if _cur != null and indented:
			if line.begins_with("? ") and not ("->" in line) and _cur["body"].is_empty() and _cur["cond"].is_empty():
				_cur["cond"] = Array(line.substr(2).strip_edges().split(" ", false))
			else:
				_cur["body"].append([line, i + 1])
			continue
		if line.begins_with("* "):
			_cur = {"text": _unquote(line.substr(2).strip_edges()), "body": [], "cond": []}
			_group.append(_cur)
			continue
		_close_group()
		if line.begins_with("@"):
			_header(line, i + 1)
		elif line.begins_with("=="):
			_labels[line.substr(2).strip_edges()] = _steps.size()
		else:
			var st := _compile(line, i + 1)
			if not st.is_empty():
				_steps.append(st)
	_close_group()
	# Option bodies live after the main flow; the main flow must never fall into them.
	_steps.append({"t": "end"})
	for d in _deferred:
		_labels[d[0]] = _steps.size()
		for bl in d[1]:
			if bl[0].begins_with("* "):
				_err(bl[1], "nested choices aren't supported; jump to a label instead")
				continue
			var st := _compile(bl[0], bl[1])
			if not st.is_empty():
				_steps.append(st)
		_steps.append({"t": "goto", "to": d[2]})
	_validate()
	return sc


func _close_group() -> void:
	if _group.is_empty():
		return
	_n_choice += 1
	var after := "__after_%d" % _n_choice
	var options: Array = []
	for k in _group.size():
		var opt: Dictionary = _group[k]
		var lbl := "__opt_%d_%d" % [_n_choice, k]
		options.append({"text": opt["text"], "cond": opt["cond"], "goto": lbl})
		_deferred.append([lbl, opt["body"], after])
	_steps.append({"t": "choice", "options": options})
	_labels[after] = _steps.size()
	_group.clear()
	_cur = null


func _header(line: String, n: int) -> void:
	var key := line.substr(1).get_slice(" ", 0)
	var val := line.substr(1 + key.length()).strip_edges()
	match key:
		"id":
			sc["id"] = val
		"title":
			sc["title"] = val
		"trigger":
			sc["trigger"] = Array(val.split(" ", false))
		"order":
			sc["order"] = int(val)
		"requires":
			sc["requires"] = Array(val.split(" ", false))
		_:
			_err(n, "unknown header @%s" % key)


func _compile(line: String, n: int) -> Dictionary:
	if line.begins_with("->"):
		return {"t": "goto", "to": line.substr(2).strip_edges(), "line": n}
	if line.begins_with("~ "):
		return {"t": "do", "effect": Array(line.substr(2).strip_edges().split(" ", false)), "line": n}
	if line.begins_with("? "):
		var parts := line.substr(2).split("->")
		if parts.size() != 2:
			_err(n, "conditional jump needs '? condition -> label'")
			return {}
		return {"t": "if", "cond": Array(parts[0].strip_edges().split(" ", false)), "to": parts[1].strip_edges(), "line": n}
	var m := _say_re.search(line)
	if m == null:
		_err(n, "can't read line: %s" % line)
		return {}
	return {"t": "say", "who": m.get_string(1), "face": m.get_string(2), "text": m.get_string(3), "line": n}


func _validate() -> void:
	if sc["id"] == "":
		_err(0, "missing @id")
	if sc["trigger"].is_empty():
		_err(0, "missing @trigger")
	for st in _steps:
		var targets: Array = []
		if st["t"] == "goto" or st["t"] == "if":
			targets.append(st["to"])
		for t in targets:
			if t != "end" and not _labels.has(t):
				_err(st.get("line", 0), "jump to unknown label '%s'" % t)


func _err(n: int, msg: String) -> void:
	sc["errors"].append("%s:%d: %s" % [sc.get("source", "?"), n, msg])


static func _unquote(s: String) -> String:
	if s.length() >= 2 and s.begins_with("\"") and s.ends_with("\""):
		return s.substr(1, s.length() - 2)
	return s
