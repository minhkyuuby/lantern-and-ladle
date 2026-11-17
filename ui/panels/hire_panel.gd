class_name HirePanel
extends TabPanel


func _connect() -> void:
	sim.events.board_refreshed.connect(mark_dirty)
	sim.events.hired.connect(mark_dirty)


func build() -> void:
	var head := add(UIKit.label("", 13, UIKit.MUTED)) as Label
	live(func():
		var days := sim.b.board_refresh_days - (sim.state.day - sim.state.board_day)
		head.text = "📋 Notice board — new faces in %d day(s)\nCrew %d/%d" % [maxi(1, days), sim.state.roster.size(), sim.roster_cap()])
	if sim.state.candidates.is_empty():
		add(UIKit.wrap_label("Nobody's looking for work right now. Check back after the next refresh."))
	for c in sim.state.candidates:
		var v := card()
		v.add_child(UIKit.label("%s %s — %s Lv %d" % [c.icon(), c.name, c.role_name(), c.level], 15))
		v.add_child(UIKit.label("%s · wage %dg/day" % [c.stat_line(), c.wage], 12, UIKit.MUTED))
		var blurb := ""
		match c.role:
			Character.CHEF:
				blurb = "Cooks one dish at a time — more chefs, more dishes at once. Higher skill = better dishes."
			Character.SERVER:
				blurb = "Delivers dishes so chefs can keep cooking."
			_:
				blurb = "Joins a party to dive the Hollow for ingredients."
		v.add_child(UIKit.wrap_label(blurb, 11))
		var fee := sim.progression.hire_fee(c)
		var btn := UIKit.button("Hire (%dg)" % fee, func(): sim.progression.hire(c.id))
		v.add_child(btn)
		live(func():
			var why := sim.progression.hire_block_reason(c)
			btn.disabled = why != ""
			btn.text = "Hire (%dg)" % fee if why == "" else why)
