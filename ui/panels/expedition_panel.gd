class_name ExpeditionPanel
extends TabPanel

const RESTOCK_ID := 100


func _connect() -> void:
	sim.events.hired.connect(mark_dirty)
	sim.events.dismissed.connect(mark_dirty)
	sim.events.floor_unlocked.connect(mark_dirty)
	sim.events.parties_changed.connect(mark_dirty)
	sim.events.upgrade_bought.connect(mark_dirty)


func build() -> void:
	var advs := sim.state.by_role(Character.ADVENTURER)
	for p in sim.state.parties:
		var v := card()
		var title := UIKit.label("", 15, UIKit.ACCENT)
		v.add_child(title)
		var odds := UIKit.label("", 12, UIKit.MUTED)
		v.add_child(odds)
		live(func():
			var st := p.state
			if p.state == Party.DIVING:
				st = "diving F%d (%d/%d rooms)" % [p.current_floor, p.room_idx, p.room_count]
			title.text = "%s — %s" % [p.name, st]
			var f := sim.expedition.target_floor(p)
			odds.text = "Next dive: Floor %d · fight win chance %d%% · power %.1f" % [
				f, int(sim.expedition.success_chance(p, f) * 100), sim.expedition.power(p)])

		v.add_child(UIKit.label("Members (max %d):" % sim.b.max_party_size, 12))
		for c in advs:
			var cb := CheckBox.new()
			cb.text = "%s Lv%d  (power %.1f)" % [c.name, c.level, c.power]
			cb.button_pressed = c.id in p.members
			cb.focus_mode = Control.FOCUS_NONE
			cb.toggled.connect(func(on: bool):
				if not sim.progression.set_member(p, c.id, on):
					cb.set_pressed_no_signal(c.id in p.members))
			v.add_child(cb)
			live(func():
				cb.set_pressed_no_signal(c.id in p.members)
				var other := sim.state.party_of(c.id)
				var locked := p.state == Party.DIVING or (other != null and other != p and other.state == Party.DIVING)
				cb.disabled = locked or (not (c.id in p.members) and p.members.size() >= sim.b.max_party_size)
				cb.tooltip_text = "Can't change members mid-dive" if locked else "")

		var h := row()
		var floor_opt := OptionButton.new()
		floor_opt.focus_mode = Control.FOCUS_NONE
		floor_opt.add_item("Auto: deepest safe", 0)
		floor_opt.add_item("Auto: restock pantry", RESTOCK_ID)
		floor_opt.set_item_tooltip(1, "Dives the safe floor whose loot best covers what tonight's menu is short of")
		for i in range(1, sim.state.max_floor + 1):
			floor_opt.add_item("Floor %d: %s" % [i, sim.db.floor_def(i).display_name], i)
		var sel_id := (RESTOCK_ID if p.auto_mode == "restock" else 0) if p.auto_floor else clampi(p.floor_index, 1, sim.state.max_floor)
		floor_opt.select(floor_opt.get_item_index(sel_id))
		floor_opt.item_selected.connect(func(idx: int):
			var fid := floor_opt.get_item_id(idx)
			p.auto_floor = fid == 0 or fid == RESTOCK_ID
			if fid == 0:
				p.auto_mode = "deepest"
			elif fid == RESTOCK_ID:
				p.auto_mode = "restock"
			else:
				p.floor_index = fid)
		h.add_child(floor_opt)
		var rep := CheckBox.new()
		rep.text = "Repeat"
		rep.tooltip_text = "Standing order: dive again whenever rested"
		rep.focus_mode = Control.FOCUS_NONE
		rep.button_pressed = p.repeat
		rep.toggled.connect(func(on: bool): p.repeat = on)
		h.add_child(rep)
		v.add_child(h)

		var h2 := row()
		var send := UIKit.button("Send now", func(): sim.expedition.start(p))
		var recall := UIKit.button("Recall", func(): sim.expedition.recall(p))
		h2.add_child(send)
		h2.add_child(recall)
		v.add_child(h2)
		live(func():
			send.disabled = p.state == Party.DIVING or p.members.is_empty()
			recall.disabled = p.state != Party.DIVING)

	var unassigned := advs.filter(func(c): return sim.state.party_of(c.id) == null)
	if not unassigned.is_empty():
		add(UIKit.wrap_label("Unassigned: " + ", ".join(PackedStringArray(unassigned.map(func(c): return c.name))), 12, UIKit.BAD))

	var biome := ""
	for fd in sim.db.floors:
		if fd.biome != biome:
			biome = fd.biome
			add(UIKit.label(biome, 14, UIKit.ACCENT))
		var v := card(UIKit.PANEL)
		var locked := fd.index > sim.state.max_floor
		v.add_child(UIKit.label("%s F%d %s" % ["🔒" if locked else "⛏", fd.index, fd.display_name], 14))
		if locked:
			var why := UIKit.wrap_label("", 12, UIKit.BAD)
			v.add_child(why)
			var lidx := fd.index
			live(func(): why.text = "To unlock: " + sim.progression.floor_lock_reason(lidx))
		var loot := ""
		for id in fd.loot:
			loot += sim.db.ingredient_icon(id)
		var extra := ""
		if fd.boss_name != "":
			extra = " · boss: %s" % fd.boss_name
		if fd.scroll_recipe != "":
			extra += " · 📜 scroll"
		var info := UIKit.label("", 12, UIKit.MUTED)
		v.add_child(info)
		var idx := fd.index
		live(func():
			var need := ""
			if idx == sim.state.max_floor and idx < sim.db.floors.size():
				need = " · clears %d/%d to unlock next" % [sim.state.cleared_count(idx), fd.clears_to_unlock]
			if fd.boss_name != "" and not sim.expedition.boss_active(idx):
				need += " · boss appears after %d/%d clears" % [sim.state.cleared_count(idx), fd.boss_after_clears]
			elif fd.boss_name != "" and not (idx in sim.state.bosses_beaten):
				need += " · 👑 boss is waiting in the last room"
			info.text = "danger %.0f · %d rooms · %ds · loot %s%s\ncleared %d×%s" % [
				fd.danger, fd.rooms, int(fd.duration), loot, extra, sim.state.cleared_count(idx), need])
