class_name StaffPanel
extends TabPanel


func _connect() -> void:
	sim.events.hired.connect(mark_dirty)
	sim.events.dismissed.connect(mark_dirty)


func build() -> void:
	var head := add(UIKit.label("", 13, UIKit.MUTED)) as Label
	live(func():
		var debt := "" if sim.state.debt <= 0 else "  ·  owed %dg!" % int(ceil(sim.state.debt))
		head.text = "Crew %d/%d  ·  wages %dg per dawn%s" % [sim.state.roster.size(), sim.roster_cap(), sim.economy.total_wages(), debt])
	for c in sim.state.roster:
		var v := card()
		var h := row()
		var title := UIKit.label("", 15)
		h.add_child(title)
		h.add_child(spacer())
		var dismiss := UIKit.button("Dismiss", func(): sim.progression.dismiss(c.id))
		dismiss.add_theme_font_size_override("font_size", 11)
		h.add_child(dismiss)
		v.add_child(h)
		var stats := UIKit.label("", 12, UIKit.MUTED)
		v.add_child(stats)
		var xp := UIKit.bar(UIKit.INFO, 4)
		v.add_child(xp)
		var stam: ProgressBar = null
		if c.role == Character.ADVENTURER:
			stam = UIKit.bar(UIKit.GOOD, 6)
			v.add_child(stam)
		live(func():
			title.text = "%s %s — %s Lv %d" % [c.icon(), c.name, c.role_name(), c.level]
			var p := sim.state.party_of(c.id)
			var where := (" · " + p.name) if p else ("" if c.role != Character.ADVENTURER else " · no party")
			stats.text = "%s · wage %dg · %s%s" % [c.stat_line(), c.wage, c.status, where]
			xp.value = c.xp / c.xp_to_next(sim.b)
			if stam:
				stam.value = c.stamina / c.max_stamina
			var why := sim.progression.dismiss_block_reason(c)
			dismiss.disabled = why != ""
			dismiss.tooltip_text = why)
