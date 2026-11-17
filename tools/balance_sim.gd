extends SceneTree
## Headless economy run. Prints one CSV row per in-game day.
##   godot --headless --path . --script res://tools/balance_sim.gd -- --days=30 [--idle] [--seed=7] [--save]
##   ... -- --seasons=4 [--days=80]   bot holds the festival after each Hive Queen, buys perks, plays on
## --save writes the final state to the game's save slot, handy for testing late-game screens.
## Default uses a simple "player bot" that hires and buys upgrades; --idle never touches anything.

var sim: Sim
var bot := true
var last_report := {}


func _init() -> void:
	var days := 30
	var seed := 7
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--days="):
			days = int(a.get_slice("=", 1))
		elif a.begins_with("--seed="):
			seed = int(a.get_slice("=", 1))
		elif a == "--idle":
			bot = false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seasons="):
			_run_seasons(int(a.get_slice("=", 1)), days, seed)
			quit()
			return
	var db := ContentDB.load_default()
	sim = Sim.new(db, null, seed)
	var milestones: Array[String] = []
	sim.events.logged.connect(func(t, important):
		if important and ("unlocked" in t or "recipe" in t.to_lower() or "beaten" in t or "opens" in t or "Hired" in t or "Upgrade" in t):
			milestones.append(t))
	print("day,gold,renown,debt,served,revenue,turned_away,left_queue,no_food,angry,spoiled,loot,roster,max_floor,chef_lv,adv_lv,recipes,upgrades")
	sim.events.day_ended.connect(_on_day)
	var t := 0.0
	while sim.state.day <= days:
		sim.tick(1.0)
		t += 1.0
		if bot and fmod(t, 20.0) < 1.0:
			_bot()
	print("\nmilestones:")
	for m in milestones:
		print("  ", m)
	print("\nfinished: slice_complete=%s hours_played=%.2f" % [sim.state.slice_complete, sim.state.time_total / 3600.0])
	if "--save" in OS.get_cmdline_user_args():
		SaveSystem.save(sim.state)
		print("saved to ", ProjectSettings.globalize_path(SaveSystem.PATH))
	quit()


## Plays several seasons back to back; prints one summary row per season.
func _run_seasons(seasons: int, max_days: int, seed: int) -> void:
	var db := ContentDB.load_default()
	var legacy := {}
	print("season,rat_king_day,orchard_day,hive_queen_day,hours,earned,ladles_awarded,ladles_total,perks")
	for n in seasons:
		sim = Sim.new(db, null, seed + n, legacy)
		# spend ladles: cheapest affordable perk first
		var bought := true
		while bought:
			bought = false
			var best: PerkDef = null
			for p in db.perks:
				if sim.progression.perk_block_reason(p) == "" and (best == null or sim.progression.perk_cost(p) < sim.progression.perk_cost(best)):
					best = p
			if best:
				bought = sim.progression.buy_perk(best.id)
		var marks := {"rk": 0, "orch": 0}
		sim.events.logged.connect(func(t, _i):
			if "Rat King is beaten" in t:
				marks["rk"] = sim.state.day
			elif "Sunken Orchard opens" in t:
				marks["orch"] = sim.state.day)
		sim.events.day_ended.connect(func(r): last_report = r)
		last_report = {}
		var t := 0.0
		while not sim.state.slice_complete and sim.state.day <= max_days:
			sim.tick(1.0)
			t += 1.0
			if fmod(t, 20.0) < 1.0:
				_bot()
		var perk_str := ""
		for p in db.perks:
			perk_str += "%s%d " % [p.id.left(4), sim.state.perk_level(p.id)]
		var hq := sim.state.day if sim.state.slice_complete else -1
		legacy = sim.festival_legacy()
		print("%d,%d,%d,%d,%.1f,%d,%d,%d,%s" % [n + 1, marks["rk"], marks["orch"], hq, sim.state.time_total / 3600.0,
			sim.state.run_earned, legacy["award"], legacy["ladles"], perk_str])
		if not sim.state.slice_complete:
			print("  (season %d hit the %d-day cap without beating the Hive Queen)" % [n + 1, max_days])
			return


func _on_day(r: Dictionary) -> void:
	last_report = r
	var s := sim.state
	var chef_lv := 0
	for c in s.by_role(Character.CHEF):
		chef_lv = maxi(chef_lv, c.level)
	var adv_lv := 0
	for c in s.by_role(Character.ADVENTURER):
		adv_lv = maxi(adv_lv, c.level)
	var ups := 0
	for k in s.upgrades:
		ups += int(s.upgrades[k])
	print("%d,%d,%.1f,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d" % [
		r["day"], s.gold, s.renown, s.debt, r["served"], r["revenue"] + r["tips"], r["turned_away"],
		r["left_queue"], r["no_food"], r["left_angry"], r["spoiled"], r["loot"], s.roster.size(),
		s.max_floor, chef_lv, adv_lv, s.unlocked_recipes.size(), ups])


## A naive player: keep 2 days of wages in reserve, fix the most visible bottleneck.
func _bot() -> void:
	var s := sim.state
	var reserve := sim.economy.total_wages() * 2.0
	var spare := s.gold - reserve
	if spare <= 0:
		return
	var advs := s.by_role(Character.ADVENTURER).size()
	var servers := s.by_role(Character.SERVER).size()
	var chefs := s.by_role(Character.CHEF).size()
	# Biome gates first: save up for the permit and the oven as soon as they're available.
	for gate in ["orchard_permit", "clay_oven"]:
		var gu := sim.db.upgrade(gate)
		if s.upgrade_level(gate) == 0 and gu.requires_boss in s.bosses_beaten:
			if sim.progression.upgrade_block_reason(gu) == "" and sim.progression.upgrade_cost(gu) <= spare:
				sim.progression.buy_upgrade(gate)
			return
	var want := ""
	var adv_slots := sim.party_slots() * sim.b.max_party_size
	if advs >= adv_slots and sim.progression.upgrade_block_reason(sim.db.upgrade("party_charter")) == "":
		sim.progression.buy_upgrade("party_charter")
		return
	if servers == 0:
		want = Character.SERVER
	elif last_report.get("no_food", 0) > last_report.get("left_angry", 0) and advs < adv_slots:
		want = Character.ADVENTURER
	elif last_report.get("left_angry", 0) > 2 and chefs < 3:
		want = Character.CHEF
	elif advs < mini(chefs * 2, adv_slots):
		want = Character.ADVENTURER
	if want != "":
		for c in s.candidates:
			if c.role == want and sim.progression.hire_fee(c) <= spare and sim.progression.hire_block_reason(c) == "":
				sim.progression.hire(c.id)
				return
		if s.roster.size() >= sim.roster_cap():
			var bunks := sim.db.upgrade("guild_bunks")
			if sim.progression.upgrade_cost(bunks) <= spare:
				sim.progression.buy_upgrade("guild_bunks")
				return
	var best: UpgradeDef = null
	for u in sim.db.upgrades:
		if sim.progression.upgrade_block_reason(u) == "" and sim.progression.upgrade_cost(u) <= spare:
			if best == null or sim.progression.upgrade_cost(u) < sim.progression.upgrade_cost(best):
				best = u
	if best:
		sim.progression.buy_upgrade(best.id)
