class_name UpgradesPanel
extends TabPanel


func _connect() -> void:
	sim.events.upgrade_bought.connect(mark_dirty)


func build() -> void:
	for u in sim.db.upgrades:
		var v := card()
		var h := row()
		var title := UIKit.label("", 14)
		h.add_child(title)
		h.add_child(spacer())
		var btn := UIKit.button("", func(): sim.progression.buy_upgrade(u.id))
		h.add_child(btn)
		v.add_child(h)
		v.add_child(UIKit.wrap_label(u.description, 11))
		live(func():
			title.text = "%s %s  (%d/%d)" % [u.icon, u.display_name, sim.state.upgrade_level(u.id), u.max_level]
			var why := sim.progression.upgrade_block_reason(u)
			btn.disabled = why != ""
			btn.text = ("Buy %dg" % sim.progression.upgrade_cost(u)) if why == "" else why)
