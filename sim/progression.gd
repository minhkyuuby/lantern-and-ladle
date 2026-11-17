class_name Progression
extends RefCounted
## XP and levels, recipe unlocks, hiring board, upgrades, parties.

const NAMES := [
	"Bram", "Ivy", "Tamsin", "Orrin", "Wren", "Juniper", "Fennick", "Mabel", "Corwin", "Sable",
	"Hollis", "Pell", "Rook", "Briar", "Odo", "Linnea", "Thistle", "Garrick", "Nim", "Ottilie",
	"Basil", "Marigold", "Quill", "Rowan", "Saffi", "Tobin", "Umber", "Vesper", "Yarrow", "Zinnia",
]

var sim: Sim


func _init(s: Sim) -> void:
	sim = s


func tick(dt: float) -> void:
	var rate := sim.b.rest_rate * (1.0 + sim.perk_amount("dive_speed"))
	for c in sim.state.roster:
		if c.status != "diving" and c.stamina < c.max_stamina:
			c.stamina = minf(c.max_stamina, c.stamina + rate * dt)


func on_dawn() -> void:
	if sim.state.day - sim.state.board_day >= sim.b.board_refresh_days:
		refresh_board()


# --- XP / recipes ----------------------------------------------------------

func add_xp(c: Character, amount: float) -> void:
	if c.add_xp(amount * (1.0 + sim.perk_amount("xp")), sim.b):
		sim.log_msg("%s %s reached level %d!" % [c.icon(), c.name, c.level], true)
		sim.events.character_leveled.emit(c)
		if c.role == Character.CHEF:
			check_recipe_unlocks()


func head_chef_level() -> int:
	var lvl := 0
	for c in sim.state.by_role(Character.CHEF):
		lvl = maxi(lvl, c.level)
	return lvl


func check_recipe_unlocks(silent: bool = false) -> void:
	var lvl := head_chef_level()
	for r in sim.db.recipe_list():
		if r.id in sim.state.unlocked_recipes:
			continue
		if lvl >= r.chef_level and (not r.needs_scroll or r.id in sim.state.scrolls):
			sim.state.unlocked_recipes.append(r.id)
			if not silent:
				sim.log_msg("New recipe: %s %s" % [r.icon, r.display_name], true)
			sim.events.recipe_unlocked.emit(r)


func grant_scroll(recipe_id: String) -> void:
	if recipe_id in sim.state.scrolls:
		return
	sim.state.scrolls.append(recipe_id)
	var r: RecipeDef = sim.db.recipes.get(recipe_id)
	sim.log_msg("📜 Found a recipe scroll: %s" % (r.display_name if r else recipe_id), true)
	check_recipe_unlocks()


# --- Characters / hiring ---------------------------------------------------

func make_character(role: String, tier: int) -> Character:
	var c := Character.new()
	c.id = sim.state.new_id()
	c.role = role
	c.name = _random_name()
	var rng := sim.rng
	match role:
		Character.CHEF:
			c.speed = rng.randf_range(0.85, 1.15)
			c.skill = rng.randf_range(0.5, 2.0)
			c.wage = sim.b.wage_chef
		Character.SERVER:
			c.speed = rng.randf_range(0.9, 1.4)
			c.wage = sim.b.wage_server
		_:
			c.power = rng.randf_range(3.5, 6.5)
			c.luck = rng.randf_range(1.0, 4.0)
			c.wage = sim.b.wage_adventurer
	var lvl := rng.randi_range(1, maxi(1, tier))
	for i in lvl - 1:
		c.add_xp(c.xp_to_next(sim.b), sim.b)
	c.xp = 0.0
	c.stamina = c.max_stamina
	return c


func _random_name() -> String:
	var used := {}
	for c in sim.state.roster:
		used[c.name] = true
	for c in sim.state.candidates:
		used[c.name] = true
	for i in 20:
		var n: String = NAMES[sim.rng.randi_range(0, NAMES.size() - 1)]
		if not used.has(n):
			return n
	return NAMES[sim.rng.randi_range(0, NAMES.size() - 1)] + " II"


func refresh_board() -> void:
	var tier := 1 + int(sim.state.renown / 40.0)
	sim.state.candidates.clear()
	var roles := {Character.CHEF: 1.0, Character.SERVER: 1.2, Character.ADVENTURER: 1.8}
	for i in sim.b.board_size:
		sim.state.candidates.append(make_character(sim.weighted_key(roles), tier))
	sim.state.board_day = sim.state.day
	sim.events.board_refreshed.emit()


func hire_fee(c: Character) -> int:
	return int(c.wage * sim.b.hire_fee_mult)


## Empty string when hiring is possible, otherwise the reason.
func hire_block_reason(c: Character) -> String:
	if sim.state.roster.size() >= sim.roster_cap():
		return "Roster full"
	if sim.state.gold < hire_fee(c):
		return "Need %dg" % hire_fee(c)
	return ""


func hire(char_id: int) -> bool:
	var c: Character = null
	for cand in sim.state.candidates:
		if cand.id == char_id:
			c = cand
	if c == null or hire_block_reason(c) != "":
		return false
	sim.state.gold -= hire_fee(c)
	sim.state.candidates.erase(c)
	sim.state.roster.append(c)
	if c.role == Character.ADVENTURER:
		if not auto_assign(c):
			sim.log_msg("%s has no party slot — buy a Party Charter or swap members." % c.name, true)
	elif sim.state.phase == Sim.Phase.NIGHT:
		c.status = "working"
	sim.log_msg("Hired %s %s the %s." % [c.icon(), c.name, c.role_name()], true)
	sim.events.hired.emit(c)
	return true


func dismiss_block_reason(c: Character) -> String:
	if c.status == "diving":
		return "On a dive"
	if c.role == Character.CHEF and sim.state.by_role(Character.CHEF).size() <= 1:
		return "Last chef"
	if sim.restaurant.tasks.has(c.id):
		return "Busy"
	return ""


func dismiss(char_id: int) -> bool:
	var c := sim.state.get_char(char_id)
	if c == null or dismiss_block_reason(c) != "":
		return false
	for p in sim.state.parties:
		p.members.erase(char_id)
	sim.state.roster.erase(c)
	sim.log_msg("%s left the crew." % c.name)
	sim.events.dismissed.emit(c)
	return true


# --- Parties ---------------------------------------------------------------

func ensure_parties() -> void:
	while sim.state.parties.size() < sim.party_slots():
		var p := Party.new()
		p.id = sim.state.parties.size()
		p.name = "Party %s" % char(65 + p.id)
		if p.id > 0:
			p.auto_mode = "restock"  # extra parties keep the pantry balanced by default
		sim.state.parties.append(p)
	for c in sim.state.by_role(Character.ADVENTURER):
		if sim.state.party_of(c.id) == null:
			auto_assign(c)
	sim.events.parties_changed.emit()


## Puts an adventurer into the first party with room. Returns false if every party is full.
func auto_assign(c: Character) -> bool:
	if sim.state.party_of(c.id) != null:
		return true
	for p in sim.state.parties:
		if p.members.size() < sim.b.max_party_size:
			p.members.append(c.id)
			if p.state == Party.DIVING:
				c.status = "diving"
			sim.events.parties_changed.emit()
			return true
	return false


## Returns false if the change isn't allowed right now.
func set_member(p: Party, char_id: int, on: bool) -> bool:
	if p.state == Party.DIVING:
		return false
	if on:
		if char_id in p.members or p.members.size() >= sim.b.max_party_size:
			return false
		for other in sim.state.parties:
			other.members.erase(char_id)
		p.members.append(char_id)
	else:
		p.members.erase(char_id)
	sim.events.parties_changed.emit()
	return true


# --- Perks (Golden Ladles) -------------------------------------------------

func perk_cost(p: PerkDef) -> int:
	return p.cost_at(sim.state.perk_level(p.id))


func perk_block_reason(p: PerkDef) -> String:
	if sim.state.perk_level(p.id) >= p.max_level:
		return "MAX"
	if sim.state.ladles < perk_cost(p):
		return "Need %d 🥄" % perk_cost(p)
	return ""


func buy_perk(id: String) -> bool:
	var p := sim.db.perk(id)
	if p == null or perk_block_reason(p) != "":
		return false
	sim.state.ladles -= perk_cost(p)
	sim.state.perks[id] = sim.state.perk_level(id) + 1
	sim.log_msg("Legacy perk: %s %s (Lv %d)" % [p.icon, p.display_name, sim.state.perk_level(id)], true)
	sim.events.perk_bought.emit(p)
	return true


# --- Floors ----------------------------------------------------------------

## Why `index` can't be unlocked yet ("" if it can). Only meaningful for the floor right after max_floor.
func floor_lock_reason(index: int) -> String:
	if index <= sim.state.max_floor:
		return ""
	if index > sim.state.max_floor + 1:
		return "Locked"
	var prev := sim.db.floor_def(index - 1)
	var parts: Array[String] = []
	if sim.state.cleared_count(prev.index) < prev.clears_to_unlock:
		parts.append("clear F%d %d/%d times" % [prev.index, sim.state.cleared_count(prev.index), prev.clears_to_unlock])
	if prev.boss_name != "" and not (prev.index in sim.state.bosses_beaten):
		parts.append("beat %s" % prev.boss_name)
	var fd := sim.db.floor_def(index)
	if fd.requires_upgrade != "" and sim.state.upgrade_level(fd.requires_upgrade) == 0:
		var u := sim.db.upgrade(fd.requires_upgrade)
		parts.append("buy the %s" % (u.display_name if u else fd.requires_upgrade))
	return ", ".join(PackedStringArray(parts))


## Unlocks every floor whose requirements are now met.
func check_floor_unlocks() -> void:
	while sim.state.max_floor < sim.db.floors.size():
		var nxt := sim.db.floor_def(sim.state.max_floor + 1)
		if floor_lock_reason(nxt.index) != "":
			return
		var prev_biome := sim.db.floor_def(sim.state.max_floor).biome
		sim.state.max_floor += 1
		if nxt.biome != prev_biome:
			sim.log_msg("🌿 The %s opens! Floor %d: %s" % [nxt.biome, nxt.index, nxt.display_name], true)
		else:
			sim.log_msg("New floor unlocked: %s!" % nxt.display_name, true)
		sim.events.floor_unlocked.emit(sim.state.max_floor)


# --- Upgrades --------------------------------------------------------------

func upgrade_cost(u: UpgradeDef) -> int:
	return u.cost_at(sim.state.upgrade_level(u.id))


func upgrade_block_reason(u: UpgradeDef) -> String:
	if sim.state.upgrade_level(u.id) >= u.max_level:
		return "MAX"
	if u.effect == "seats" and sim.seats() >= sim.b.max_seats:
		return "MAX"
	if u.requires_boss > 0 and not (u.requires_boss in sim.state.bosses_beaten):
		return "Beat %s" % sim.db.floor_def(u.requires_boss).boss_name
	if sim.state.renown < u.min_renown:
		return "Needs %d renown" % u.min_renown
	if sim.state.gold < upgrade_cost(u):
		return "Need %dg" % upgrade_cost(u)
	return ""


func buy_upgrade(id: String) -> bool:
	var u := sim.db.upgrade(id)
	if u == null or upgrade_block_reason(u) != "":
		return false
	sim.state.gold -= upgrade_cost(u)
	sim.state.upgrades[id] = sim.state.upgrade_level(id) + 1
	if u.effect == "party":
		ensure_parties()
	sim.restaurant.ensure_layout()
	sim.log_msg("Upgrade: %s %s (Lv %d)" % [u.icon, u.display_name, sim.state.upgrade_level(id)], true)
	sim.events.upgrade_bought.emit(u)
	check_floor_unlocks()
	return true
