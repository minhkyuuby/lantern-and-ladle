extends SceneTree
## godot --headless --path . --script res://tools/run_tests.gd

var _fails := 0
var _passes := 0


func _init() -> void:
	var db := ContentDB.load_default()
	_test_content(db)
	_test_inventory(db)
	_test_wages(db)
	_test_expedition(db)
	_test_restaurant(db)
	_test_deadlock(db)
	_test_biome_two(db)
	_test_festival(db)
	_test_story(db)
	_test_save_roundtrip(db)
	print("\n%d passed, %d failed" % [_passes, _fails])
	quit(1 if _fails > 0 else 0)


func check(cond: bool, what: String) -> void:
	if cond:
		_passes += 1
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)


func _test_content(db: ContentDB) -> void:
	print("content")
	check(db.ingredients.size() == 12, "12 ingredients loaded")
	check(db.recipes.size() == 12, "12 recipes loaded")
	check(db.floors.size() == 6, "6 floors loaded")
	for i in db.floors.size():
		check(db.floors[i].index == i + 1, "floor %d sorted" % (i + 1))
	check(db.upgrades.size() >= 11, "upgrades loaded")
	check(db.customer_types.size() == 4, "4 customer types")
	for fd in db.floors:
		if fd.requires_upgrade != "":
			check(db.upgrade(fd.requires_upgrade) != null, "floor %d gate upgrade exists" % fd.index)
		if fd.scroll_recipe != "":
			check(db.recipes.has(fd.scroll_recipe), "floor %d scroll recipe exists" % fd.index)
		if fd.boss_scroll != "":
			check(db.recipes.has(fd.boss_scroll), "floor %d boss scroll exists" % fd.index)
	for r in db.recipe_list():
		for id in r.ingredients:
			check(db.ingredients.has(id), "%s ingredient %s exists" % [r.id, id])


func _test_inventory(db: ContentDB) -> void:
	print("inventory")
	var inv := Inventory.new()
	inv.add("mushroom", 2, 3)
	inv.add("mushroom", 0, 2, 1)
	check(inv.count("mushroom") == 5, "count sums stacks")
	var qs := inv.take("mushroom", 3)
	check(qs == [0, 0, 2], "take is oldest-first")
	check(inv.count("mushroom") == 2, "count after take")
	inv.add("rice", 0, 5)
	var spoiled := 0
	for d in 3:
		spoiled += inv.dawn_age(2, db)
	check(spoiled == 2 and inv.count("mushroom") == 0, "mushrooms spoil after fresh days")
	check(inv.count("rice") == 5, "rice never spoils")


func _test_wages(db: ContentDB) -> void:
	print("wages")
	var sim := Sim.new(db, null, 1)
	sim.state.gold = 10
	var owed := sim.economy.total_wages()
	sim.economy.settle_wages()
	check(sim.state.gold == 0 and is_equal_approx(sim.state.debt, owed - 10), "shortfall becomes debt")
	check(sim.work_factor() < 1.0, "debt slows work")
	sim.state.gold = 200
	sim.economy.settle_wages()
	check(sim.state.debt == 0 and is_equal_approx(sim.state.gold, 200 - owed - (owed - 10)), "debt repaid next dawn")


func _test_expedition(db: ContentDB) -> void:
	print("expedition")
	var sim := Sim.new(db, null, 2)
	var returned := [0]
	sim.events.expedition_returned.connect(func(_p, _c): returned[0] += 1)
	for i in 400:
		sim.tick(0.25)
	check(returned[0] >= 1, "Pip returned from a dive within 100s")
	for i in 400:
		sim.tick(0.25)
	check(sim.state.report["loot"] > 0, "loot added to pantry (%d)" % sim.state.report["loot"])
	check(sim.state.max_floor >= 1, "floor progress tracked")
	var f3 := db.floor_def(3)
	check(not sim.expedition.boss_active(3), "Rat King hidden before any Floor 3 clears")
	sim.state.floors_cleared["3"] = f3.boss_after_clears
	check(sim.expedition.boss_active(3), "Rat King appears after %d clears" % f3.boss_after_clears)
	sim.state.floors_cleared.erase("3")
	var pip := sim.state.by_role(Character.ADVENTURER)[0]
	check(sim.state.parties[0].members == [pip.id], "Pip is in Party A exactly once")


func _test_restaurant(db: ContentDB) -> void:
	print("restaurant")
	var sim := Sim.new(db, null, 3)
	sim.state.inventory.add("mushroom", 1, 20)
	sim.state.inventory.add("rat_meat", 1, 20)
	sim.state.phase = Sim.Phase.NIGHT
	sim.restaurant.open()
	var gold := sim.state.gold
	for i in 1000:
		sim.tick(0.25)
	check(sim.state.report["served"] > 0, "customers served (%d)" % sim.state.report["served"])
	check(sim.state.gold > gold, "gold earned")
	check(sim.state.by_role(Character.CHEF)[0].xp > 0 or sim.state.by_role(Character.CHEF)[0].level > 1, "chef gained xp")


func _test_deadlock(db: ContentDB) -> void:
	print("deadlock guard")
	var sim := Sim.new(db, null, 4)
	sim.state.gold = 0
	sim.state.inventory = Inventory.new()
	var served_days := [0]
	var days := [0]
	sim.events.day_ended.connect(func(r):
		days[0] += 1
		if r["served"] > 0:
			served_days[0] += 1)
	while days[0] < 6:
		sim.tick(1.0)
	check(served_days[0] >= 5, "broke start still serves on most days (%d/6)" % served_days[0])


func _test_biome_two(db: ContentDB) -> void:
	print("biome two")
	var sim := Sim.new(db, null, 6)
	var s := sim.state
	s.max_floor = 3
	s.floors_cleared = {"1": 99, "2": 99, "3": 99}
	s.gold = 100000
	sim.progression.check_floor_unlocks()
	check(s.max_floor == 3, "Floor 4 stays locked before the Rat King")
	check(sim.progression.upgrade_block_reason(db.upgrade("orchard_permit")).begins_with("Beat"), "permit needs the Rat King")
	s.bosses_beaten.append(3)
	sim.progression.check_floor_unlocks()
	check(s.max_floor == 3, "Floor 4 stays locked without the permit")
	check("Orchard" in sim.progression.floor_lock_reason(4), "lock reason names the permit")
	check(sim.progression.buy_upgrade("orchard_permit"), "permit can be bought after the Rat King")
	check(s.max_floor == 4, "buying the permit opens Floor 4")
	check(sim.progression.floor_lock_reason(5) != "", "Floor 5 still needs Floor 4 clears")

	check(sim.station_count("oven") == 0, "no oven at start")
	check(sim.progression.buy_upgrade("clay_oven"), "oven can be bought")
	sim.restaurant.ensure_layout()
	var ovens := sim.restaurant.stations.filter(func(st): return st.type == "oven")
	check(ovens.size() == 1, "oven station added to the kitchen")

	var p := s.parties[0]
	var before := sim.expedition.power(p)
	check(sim.progression.buy_upgrade("forged_gear"), "gear can be bought")
	check(is_equal_approx(sim.expedition.power(p), before + 3.0 * p.members.size()), "gear adds power per member")

	# Restock mode picks the floor that supplies what the menu lacks.
	s.renown = 100
	check(sim.progression.buy_upgrade("party_charter"), "second party charter bought")
	var pb := s.parties[1]
	check(pb.auto_mode == "restock", "second party defaults to restock mode")
	pb.members.clear()
	pb.members.append(s.by_role(Character.ADVENTURER)[0].id)
	p.members.clear()
	s.inventory = Inventory.new()
	s.inventory.add("blossom", 0, 50)
	s.inventory.add("lantern_fruit", 0, 50)
	s.inventory.add("honey", 0, 50)
	var f := sim.expedition.target_floor(pb)
	check(f < 4, "restock skips Floor 4 when its loot is fully stocked (picked F%d)" % f)
	var old := s.to_dict()
	old.erase("bosses_beaten")
	old["slice_complete"] = true
	var migrated := GameState.from_dict(old)
	check(migrated.bosses_beaten == [3] and not migrated.slice_complete, "old one-biome saves keep the Rat King beaten")


func _test_festival(db: ContentDB) -> void:
	print("festival")
	check(db.perks.size() == 7, "7 perks loaded")
	var sim := Sim.new(db, null, 8)
	check(not sim.can_hold_festival(), "no festival before the Hive Queen")
	sim.state.slice_complete = true
	sim.state.run_earned = 100000.0
	check(sim.festival_award() == 5 + 10, "award = 5 + sqrt(earned/1000)")
	sim.state.ladles = 3
	sim.state.perks = {"nest_egg": 2, "family_recipes": 1, "seasoned_crew": 1}
	sim.state.gold = 99999
	sim.state.day = 40
	var legacy := sim.festival_legacy()
	var next := Sim.new(db, null, 9, legacy)
	var s := next.state
	check(s.ladles == 18 and s.festivals == 1, "ladles and festival count carry over")
	check(s.day == 1 and s.max_floor == 1 and s.upgrades.is_empty() and s.bosses_beaten.is_empty(), "season progress resets")
	check(is_equal_approx(s.gold, db.balance.start_gold + 400), "Nest Egg adds starting gold")
	check(s.by_role(Character.CHEF)[0].level == 2, "Family Recipes raises Maro's starting level")
	check(s.by_role(Character.ADVENTURER)[0].level == 3, "Seasoned Crew raises Pip's starting level")
	check(s.run_earned == 0.0, "season earnings reset")

	check(next.progression.buy_perk("golden_ladle"), "perk can be bought with ladles")
	check(s.ladles == 15 and s.perk_level("golden_ladle") == 1, "perk costs ladles")
	s.ladles = 0
	check(not next.progression.buy_perk("golden_ladle"), "can't buy without ladles")
	var back := GameState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	check(back.ladles == s.ladles and back.perk_level("golden_ladle") == 1 and back.festivals == 1, "legacy survives save/load")


func _test_story(db: ContentDB) -> void:
	print("story")
	check(db.scene_errors.is_empty(), "all .dlg scenes parse cleanly %s" % [db.scene_errors])
	check(db.scenes.size() >= 6, "%d story scenes loaded" % db.scenes.size())
	for sc in db.scene_list():
		for st in sc["steps"]:
			if st["t"] == "say" and st["who"] != "narrator":
				var face: String = st["face"] if st["face"] != "" else "neutral"
				var has := ResourceLoader.exists("res://assets/sprites/portraits/%s_%s.png" % [st["who"], face]) \
					or ResourceLoader.exists("res://assets/sprites/portraits/%s.png" % st["who"])
				if not has:
					check(false, "%s line %d: no portrait for %s (%s)" % [sc["id"], st["line"], st["who"], face])

	# Parser: options, bodies, conditions and fall-through
	var sc := DialogParser.parse("""@id t
@trigger start
== start
maro (happy): Hi.
* "One"
  ~ flag one
* "Two"
  ? flag secret
  -> two
narrator: after
-> end
== two
pip: two
""", "inline")
	check(sc["errors"].is_empty(), "inline scene parses %s" % [sc["errors"]])
	var sim := Sim.new(db, null, 21)
	var r := DialogRunner.new(sc, sim.story)
	var s1 := r.advance()
	check(s1["t"] == "say" and s1["who"] == "maro" and s1["face"] == "happy", "first line has speaker + expression")
	var c := r.advance()
	check(c["t"] == "choice" and c["options"].size() == 1, "conditional option hidden without its flag")
	r.choose(c["options"][0]["index"])
	check(r.advance()["text"] == "after", "play continues after the choice")
	check(sim.story.check(["flag", "one"]), "option body effect applied")
	check(r.advance()["t"] == "end", "-> end finishes the scene")

	# Triggers
	sim = Sim.new(db, null, 22)
	check(sim.story.queue() == ["ch1_inheritance"], "new game queues the opening scene only")
	var run := DialogRunner.new(db.scenes["ch1_inheritance"], sim.story)
	var guard := 0
	while guard < 100:
		guard += 1
		var st := run.advance()
		if st["t"] == "choice":
			run.choose(st["options"][0]["index"])
		elif st["t"] == "end":
			break
	sim.story.finish("ch1_inheritance")
	check(sim.story.affinity("maro") == 1 and sim.story.affinity("pip") == 1, "first options raise Maro and Pip affinity")
	sim.step(300.0, 1.0)
	check("pip_first_return" in sim.story.queue(), "first dive back queues 'Gerald'")
	while sim.state.day < 2 or sim.state.phase != Sim.Phase.DUSK:
		sim.tick(1.0)
	check("bramblewick_first" in sim.story.queue(), "dusk of day 2 queues Bramblewick")
	sim.state.max_floor = 3
	sim.story.refresh()
	check("maro_floor3" in sim.story.queue(), "Floor 3 queues Maro's scene")

	# Bonuses feed the game and reset with the festival; memories don't
	var before := sim.cook_speed_bonus()
	sim.story.apply(["bonus", "cook_speed", "+0.10"])
	check(is_equal_approx(sim.cook_speed_bonus(), before + 0.10), "story bonus raises cooking speed")
	var back := GameState.from_dict(JSON.parse_string(JSON.stringify(sim.state.to_dict())))
	check(back.story["affinity"]["maro"] == 1 and "maro_floor3" in back.story["queue"], "story state survives save/load")
	sim.state.slice_complete = true
	var next := Sim.new(db, null, 23, sim.festival_legacy())
	check(next.story.is_seen("ch1_inheritance") and next.story.bonus("cook_speed") == 0.0, "festival keeps memories, clears bonuses")
	check(not ("ch1_inheritance" in next.story.queue()), "seen scenes don't replay next season")


func _test_save_roundtrip(db: ContentDB) -> void:
	print("save")
	var sim := Sim.new(db, null, 5)
	sim.step(900.0, 1.0)
	var d := sim.state.to_dict()
	var json := JSON.stringify(d)
	var back := GameState.from_dict(JSON.parse_string(json))
	check(back.day == sim.state.day, "day survives")
	check(is_equal_approx(back.gold, sim.state.gold), "gold survives")
	check(back.roster.size() == sim.state.roster.size(), "roster survives")
	check(back.inventory.total_items() == sim.state.inventory.total_items(), "inventory survives")
	check(back.parties[0].members == sim.state.parties[0].members, "party members survive")
	var sim2 := Sim.new(db, back)
	sim2.step(600.0, 1.0)
	check(sim2.state.time_total > sim.state.time_total, "loaded sim keeps running")
