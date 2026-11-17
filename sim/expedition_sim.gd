class_name ExpeditionSim
extends RefCounted
## Auto-resolved dungeon dives: a party walks through rooms, each rolled against party stats.

var sim: Sim


func _init(s: Sim) -> void:
	sim = s


func members(p: Party) -> Array[Character]:
	var out: Array[Character] = []
	for id in p.members:
		var c := sim.state.get_char(id)
		if c:
			out.append(c)
	return out


## Party power, including the Forged Gear bonus for every member.
func power(p: Party) -> float:
	var gear := sim.upgrade_amount("power") + sim.story_amount("power")
	var t := 0.0
	for c in members(p):
		t += c.power + gear
	return t


func avg_luck(p: Party) -> float:
	var ms := members(p)
	if ms.is_empty():
		return 0.0
	var t := 0.0
	for c in ms:
		t += c.luck
	return t / ms.size()


func success_chance(p: Party, floor_index: int, boss: bool = false) -> float:
	var pw := power(p)
	if pw <= 0.0:
		return 0.0
	var fd := sim.db.floor_def(floor_index)
	var danger := fd.danger * (fd.boss_danger_mult if boss else 1.0)
	return clampf(pw / (pw + danger * sim.b.combat_k), 0.05, 0.97)


## True once the floor's boss guards the last room.
func boss_active(floor_index: int) -> bool:
	var fd := sim.db.floor_def(floor_index)
	return fd.boss_name != "" and sim.state.cleared_count(floor_index) >= fd.boss_after_clears


func target_floor(p: Party) -> int:
	if not p.auto_floor:
		return clampi(p.floor_index, 1, sim.state.max_floor)
	var safe: Array[int] = [1]
	for i in range(2, sim.state.max_floor + 1):
		if success_chance(p, i) >= sim.b.auto_floor_min_success:
			safe.append(i)
	if p.auto_mode != "restock":
		return safe.back()
	var needs := pantry_needs()
	var best: int = safe.back()
	var best_score := -1.0
	for i in safe:
		var score := restock_score(i, needs)
		if score > best_score + 0.001 or (absf(score - best_score) <= 0.001 and i > best):
			best = i
			best_score = score
	return best


## ingredient id -> how many short of a comfortable stock, for dungeon ingredients the menu uses.
func pantry_needs() -> Dictionary:
	var needs := {}
	for r in sim.db.recipe_list():
		if not sim.is_on_menu(r) or sim.station_count(r.station) <= 0:
			continue
		for id in r.ingredients:
			var def: IngredientDef = sim.db.ingredients.get(id)
			if def == null or def.source != "dungeon":
				continue
			needs[id] = maxi(0, sim.b.restock_target - sim.state.inventory.count(id))
	return needs


## How well a floor's loot table covers the current shortages (weighted share of loot that's needed).
func restock_score(floor_index: int, needs: Dictionary) -> float:
	var fd := sim.db.floor_def(floor_index)
	var total := 0.0
	for id in fd.loot:
		total += float(fd.loot[id])
	if total <= 0.0:
		return 0.0
	var score := 0.0
	for id in fd.loot:
		score += float(fd.loot[id]) / total * float(needs.get(id, 0))
	# Deeper floors return more items per room.
	return score * (fd.loot_per_success.x + fd.loot_per_success.y) * 0.5


func can_start(p: Party) -> bool:
	var ms := members(p)
	if ms.is_empty():
		return false
	for c in ms:
		if c.stamina < c.max_stamina * sim.b.rest_threshold:
			return false
	return true


func tick(dt: float) -> void:
	for p in sim.state.parties:
		match p.state:
			Party.IDLE:
				if p.repeat and can_start(p):
					start(p)
			Party.RESTING:
				var rested := true
				for c in members(p):
					if c.stamina < c.max_stamina * 0.95:
						rested = false
				if rested:
					p.state = Party.IDLE
					for c in members(p):
						c.status = "idle"
			Party.DIVING:
				_advance(p, dt)


func start(p: Party) -> bool:
	if p.state == Party.DIVING or members(p).is_empty():
		return false
	var f := target_floor(p)
	var fd := sim.db.floor_def(f)
	p.current_floor = f
	p.duration = fd.duration / (1.0 + sim.perk_amount("dive_speed"))
	p.room_count = fd.rooms
	p.room_idx = 0
	p.elapsed = 0.0
	p.room_results.clear()
	p.loot.clear()
	p.boss_defeated = false
	p.state = Party.DIVING
	p.dives += 1
	for c in members(p):
		c.status = "diving"
	p.last_log = "Heading down to %s…" % fd.display_name
	sim.events.expedition_started.emit(p)
	return true


func recall(p: Party) -> void:
	if p.state == Party.DIVING:
		p.last_log = "Recalled early."
		_finish(p, false)


func _advance(p: Party, dt: float) -> void:
	p.elapsed += dt
	var interval := p.duration / float(maxi(1, p.room_count))
	while p.state == Party.DIVING and p.room_idx < p.room_count and p.elapsed >= interval * (p.room_idx + 1):
		_resolve_room(p)
	if p.state == Party.DIVING and p.room_idx >= p.room_count:
		_finish(p, true)


func _resolve_room(p: Party) -> void:
	var fd := sim.db.floor_def(p.current_floor)
	var ms := members(p)
	var is_boss := boss_active(p.current_floor) and p.room_idx == p.room_count - 1
	var kind := "boss" if is_boss else sim.weighted_key(sim.b.room_weights)
	var result := ""
	var text := ""
	var names := ", ".join(PackedStringArray(ms.map(func(c): return c.name)))
	for c in ms:
		c.stamina -= sim.b.stamina_per_room

	match kind:
		"combat", "boss":
			var chance := success_chance(p, p.current_floor, is_boss)
			if sim.rng.randf() < chance:
				var got := _roll_loot(p, fd, sim.rng.randi_range(fd.loot_per_success.x, fd.loot_per_success.y), 0.0)
				_give_xp(p, fd.xp_per_room * (3 if is_boss else 1))
				if is_boss:
					result = "boss"
					p.boss_defeated = true
					for id in fd.boss_loot:
						for i in int(fd.boss_loot[id]):
							p.loot.append([str(id), 3])
					text = "%s defeated %s!" % [names, fd.boss_name]
					if fd.boss_scroll != "":
						sim.progression.grant_scroll(fd.boss_scroll)
				else:
					result = "win"
					text = "%s won a fight (+%s)" % [names, got]
			else:
				for c in ms:
					c.stamina -= sim.b.fail_stamina
				result = "boss_fail" if is_boss else "fail"
				text = ("%s was too strong!" % fd.boss_name) if is_boss else ("%s took a beating." % names)
		"forage":
			var n := sim.rng.randi_range(fd.loot_per_success.x, fd.loot_per_success.y)
			if sim.rng.randf() < avg_luck(p) * 0.05:
				n += 1
			var got := _roll_loot(p, fd, n, 0.0)
			_give_xp(p, maxi(1, fd.xp_per_room / 2))
			result = "forage"
			text = "Foraged %s" % got
		_:
			result = "treasure"
			var scroll := fd.scroll_recipe
			if scroll != "" and not (scroll in sim.state.scrolls) and sim.rng.randf() < fd.scroll_chance + avg_luck(p) * 0.01:
				sim.progression.grant_scroll(scroll)
				text = "Found a recipe scroll!"
			else:
				var got := _roll_loot(p, fd, 2, 0.25)
				text = "Opened a chest (+%s)" % got
			_give_xp(p, fd.xp_per_room)

	p.room_idx += 1
	p.room_results.append(result)
	p.last_log = text
	sim.events.room_resolved.emit(p, result, text)

	for c in ms:
		if c.stamina <= 0.0:
			c.stamina = 0.0
	# Exhaustion only cuts a dive short if rooms remain; finishing the last room still counts as a clear.
	if p.room_idx < p.room_count:
		for c in ms:
			if c.stamina <= 0.0:
				p.last_log = "%s was knocked out — limping home." % c.name
				_finish(p, false)
				return


func _roll_loot(p: Party, fd: FloorDef, n: int, bonus: float) -> String:
	var icons := ""
	# Each extra party member has a chance to carry one more item.
	for i in maxi(0, p.members.size() - 1):
		if sim.rng.randf() < 0.5:
			n += 1
	for i in n:
		var id := sim.weighted_key(fd.loot)
		var r := sim.rng.randf() + avg_luck(p) * 0.02 + (fd.index - 1) * 0.05 + bonus
		var q := 0
		if r >= 0.97:
			q = 3
		elif r >= 0.85:
			q = 2
		elif r >= 0.6:
			q = 1
		p.loot.append([id, q])
		icons += sim.db.ingredient_icon(id)
	return icons


func _give_xp(p: Party, amount: int) -> void:
	for c in members(p):
		sim.progression.add_xp(c, amount)


func _finish(p: Party, cleared: bool) -> void:
	var fd := sim.db.floor_def(p.current_floor)
	var counts := {}
	for e in p.loot:
		sim.state.inventory.add(e[0], e[1])
		counts[e[0]] = int(counts.get(e[0], 0)) + 1
	sim.report_add("loot", p.loot.size())
	var parts: Array[String] = []
	for id in counts:
		parts.append("%d %s" % [counts[id], sim.db.ingredient_name(id)])
	sim.log_msg("%s returned from %s: %s" % [p.name, fd.display_name, ", ".join(PackedStringArray(parts)) if not parts.is_empty() else "nothing"])

	if cleared:
		var k := str(p.current_floor)
		var was_active := boss_active(p.current_floor)
		sim.state.floors_cleared[k] = sim.state.cleared_count(p.current_floor) + 1
		if not was_active and boss_active(p.current_floor):
			sim.log_msg("Rumbling from the deep… %s has noticed your crew and now guards Floor %d." % [fd.boss_name, p.current_floor], true)

	if p.boss_defeated and not (p.current_floor in sim.state.bosses_beaten):
		sim.state.bosses_beaten.append(p.current_floor)
		if p.current_floor >= sim.db.floors.size():
			sim.state.slice_complete = true
			sim.log_msg("%s is beaten! You've conquered the %s. Hold the 🏮 Festival of Lanterns (Legacy tab) whenever you're ready for a new season." % [fd.boss_name, fd.biome], true)
			sim.events.slice_completed.emit()
		else:
			var next := sim.db.floor_def(p.current_floor + 1)
			var how := ""
			if next.requires_upgrade != "" and sim.state.upgrade_level(next.requires_upgrade) == 0:
				var u := sim.db.upgrade(next.requires_upgrade)
				how = " Buy the %s %s (Shop tab) to open the %s." % [u.icon, u.display_name, next.biome]
			sim.log_msg("%s is beaten! You've conquered the %s.%s" % [fd.boss_name, fd.biome, how], true)
	sim.progression.check_floor_unlocks()

	p.loot.clear()
	var tired := not can_start(p)
	p.state = Party.RESTING if tired else Party.IDLE
	for c in members(p):
		c.status = "resting" if tired else "idle"
	sim.events.expedition_returned.emit(p, cleared)
