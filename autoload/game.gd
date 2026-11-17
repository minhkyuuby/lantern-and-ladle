extends Node
## Owns the live Sim, drives it from real time, autosaves, and handles offline catch-up.
## User args (after `--`): --fresh  --speed=10  --shot=/path.png  --shot-after=8  --quit-after-shot
##                        --tab=N  --festival-now (holds the festival on load if allowed)

signal resynced
signal speed_changed(scale: float)

const SPEEDS := [0.0, 1.0, 2.0, 4.0, 10.0]

var db: ContentDB
var sim: Sim
var time_scale: float = 1.0
var catching_up: bool = false
var enabled: bool = true
## {"title": String, "lines": Array[String]} shown by the main scene after load.
var startup_report: Dictionary = {}

var _acc: float = 0.0
var _autosave_t: float = 0.0
var _real_t: float = 0.0
var _args: Dictionary = {}
var _shot_done: bool = false


func _ready() -> void:
	for a in OS.get_cmdline_args():
		if a == "--script" or a == "-s":
			enabled = false
	if not enabled:
		set_process(false)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	_args = _parse_args()
	get_tree().set_auto_accept_quit(false)
	db = ContentDB.load_default()
	if _args.has("fresh"):
		SaveSystem.delete_save()
	_start()
	if _args.has("speed"):
		set_speed(float(_args["speed"]))
	if _args.has("festival-now"):  # test hook: hold the festival right after loading
		(func(): hold_festival()).call_deferred()


func _start() -> void:
	var d := SaveSystem.load_dict()
	if d.is_empty():
		sim = Sim.new(db)
		return
	sim = Sim.new(db, GameState.from_dict(d))
	var away := Time.get_unix_time_from_system() - float(d.get("saved_at", 0.0))
	if away > 60.0:
		startup_report = catch_up(away)


func set_speed(s: float) -> void:
	time_scale = s
	speed_changed.emit(s)


func _process(delta: float) -> void:
	if sim == null:
		return
	_real_t += delta
	if time_scale > 0.0:
		_acc += delta * time_scale
		var t := db.balance.tick
		var guard := 0
		while _acc >= t and guard < 400:
			sim.tick(t)
			_acc -= t
			guard += 1
		if guard >= 400:
			_acc = 0.0
	_autosave_t += delta
	if _autosave_t >= 30.0:
		save_now()
	if _args.has("shot") and not _shot_done and _real_t >= float(_args.get("shot-after", 6.0)):
		_shot_done = true
		_take_shot(str(_args["shot"]))


func _take_shot(path: String) -> void:
	# --shot-burst=N saves N frames 0.15 s apart as path_0.png, path_1.png, …
	var burst := int(_args.get("shot-burst", 1))
	for i in burst:
		await RenderingServer.frame_post_draw
		var p := path if burst == 1 else path.get_basename() + "_%d.png" % i
		get_viewport().get_texture().get_image().save_png(p)
		print("screenshot saved: ", p)
		if i < burst - 1:
			await get_tree().create_timer(0.15).timeout
	if _args.has("quit-after-shot"):
		save_now()
		get_tree().quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and enabled:
		save_now()
		get_tree().quit()


func save_now() -> void:
	_autosave_t = 0.0
	if sim:
		SaveSystem.save(sim.state)


func reset_game() -> void:
	SaveSystem.delete_save()
	sim = Sim.new(db)
	startup_report = {}
	get_tree().reload_current_scene()


## Prestige: ends the season after the Hive Queen, awards Golden Ladles and starts over at day 1.
func hold_festival() -> bool:
	if sim == null or not sim.can_hold_festival():
		return false
	var legacy := sim.festival_legacy()
	sim = Sim.new(db, null, -1, legacy)
	var lines: Array[String] = []
	lines.append("Gloamhollow celebrates your season: %dg earned over %d days." % [int(legacy["run_earned"]), int(legacy["days"]) - 1])
	lines.append("You earned %d 🥄 Golden Ladles (now %d)." % [legacy["award"], legacy["ladles"]])
	lines.append("Spend them on permanent perks in the Legacy tab.")
	lines.append("Your stall, crew, upgrades and floors start over — perks and ladles stay.")
	startup_report = {"title": "🏮 Festival of Lanterns #%d" % legacy["festivals"], "lines": lines}
	save_now()
	get_tree().reload_current_scene()
	return true


## Fast-forwards the sim and returns a "while you were away" report.
func catch_up(seconds: float) -> Dictionary:
	var secs := minf(seconds, db.balance.offline_cap_hours * 3600.0)
	catching_up = true
	var s := sim.state
	var before_gold := s.gold
	var before_renown := s.renown
	var before_day := s.day
	var before_levels := {}
	for c in s.roster:
		before_levels[c.id] = c.level
	var acc := {"served": 0, "revenue": 0.0, "loot": 0, "spoiled": 0, "highlights": []}
	var on_day := func(r: Dictionary) -> void:
		acc["served"] += r["served"]
		acc["revenue"] += r["revenue"] + r["tips"]
		acc["loot"] += r["loot"]
		acc["spoiled"] += r["spoiled"]
	var on_log := func(text: String, important: bool) -> void:
		if important and acc["highlights"].size() < 8 and not ("reached level" in text):
			acc["highlights"].append(text.substr(text.find("]") + 2) if text.begins_with("[D") else text)
	sim.events.day_ended.connect(on_day)
	sim.events.logged.connect(on_log)
	var start_ms := Time.get_ticks_msec()
	sim.step(secs, db.balance.offline_dt)
	sim.events.day_ended.disconnect(on_day)
	sim.events.logged.disconnect(on_log)
	acc["served"] += s.report["served"]
	acc["revenue"] += s.report["revenue"] + s.report["tips"]
	catching_up = false

	var lines: Array[String] = []
	lines.append("Nights passed: %d" % (s.day - before_day))
	lines.append("Dishes served: %d  (earned %dg)" % [acc["served"], acc["revenue"]])
	lines.append("Gold: %+dg   Renown: %+.1f" % [s.gold - before_gold, s.renown - before_renown])
	lines.append("Ingredients gathered: %d   spoiled: %d" % [acc["loot"], acc["spoiled"]])
	for c in s.roster:
		if before_levels.has(c.id) and c.level > before_levels[c.id]:
			lines.append("%s %s grew to level %d" % [c.icon(), c.name, c.level])
	for h in acc["highlights"]:
		lines.append(h)
	print("catch-up of %.0fs took %d ms" % [secs, Time.get_ticks_msec() - start_ms])
	resynced.emit()
	var hrs := int(secs / 3600.0)
	var mins := int(fmod(secs, 3600.0) / 60.0)
	return {"title": "While you were away (%dh %02dm)" % [hrs, mins], "lines": lines}


func arg(key: String) -> String:
	return str(_args.get(key, ""))


func _parse_args() -> Dictionary:
	var out := {}
	for a in OS.get_cmdline_user_args():
		var s: String = a.trim_prefix("--")
		if "=" in s:
			out[s.get_slice("=", 0)] = s.get_slice("=", 1)
		else:
			out[s] = true
	return out
