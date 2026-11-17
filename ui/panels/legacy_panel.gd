class_name LegacyPanel
extends TabPanel
## Festival of Lanterns (prestige) and the Golden Ladle perk shop.

var _confirm: ConfirmationDialog


func _connect() -> void:
	sim.events.perk_bought.connect(mark_dirty)
	sim.events.slice_completed.connect(mark_dirty)
	_confirm = ConfirmationDialog.new()
	_confirm.title = "Festival of Lanterns"
	_confirm.ok_button_text = "Light the lanterns"
	_confirm.confirmed.connect(func(): Game.hold_festival())
	add_child(_confirm)


func build() -> void:
	var head := add(UIKit.label("", 15, UIKit.ACCENT)) as Label
	live(func(): head.text = "🥄 %d Golden Ladles  ·  season %d" % [sim.state.ladles, sim.state.festivals + 1])

	var v := card(Color("3a2a1e"))
	v.add_child(UIKit.label("🏮 Festival of Lanterns", 15, UIKit.ACCENT))
	v.add_child(UIKit.wrap_label("Throw a festival to end the season. Gold, crew, upgrades, recipes and floors start over at day 1; Golden Ladles and perks stay forever. The more gold this season earned, the more ladles you get.", 12))
	var info := UIKit.label("", 12)
	v.add_child(info)
	var btn := UIKit.button("", _ask)
	v.add_child(btn)
	live(func():
		info.text = "Earned this season: %dg  →  %d 🥄 if held now" % [int(sim.state.run_earned), sim.festival_award()]
		btn.disabled = not sim.can_hold_festival()
		btn.text = "Hold the festival" if sim.can_hold_festival() else "Beat the Hive Queen (Floor 6) first")

	add(UIKit.label("Permanent perks", 14, UIKit.ACCENT))
	for p in sim.db.perks:
		var c := card()
		var h := row()
		var title := UIKit.label("", 14)
		h.add_child(title)
		h.add_child(spacer())
		var buy := UIKit.button("", func(): sim.progression.buy_perk(p.id))
		h.add_child(buy)
		c.add_child(h)
		c.add_child(UIKit.wrap_label(p.description, 11))
		live(func():
			title.text = "%s %s  (%d/%d)" % [p.icon, p.display_name, sim.state.perk_level(p.id), p.max_level]
			var why := sim.progression.perk_block_reason(p)
			buy.disabled = why != ""
			buy.text = ("Buy %d 🥄" % sim.progression.perk_cost(p)) if why == "" else why)


func _ask() -> void:
	_confirm.dialog_text = "End season %d and earn %d 🥄 Golden Ladles?\n\nEverything except ladles and perks starts over." % [
		sim.state.festivals + 1, sim.festival_award()]
	_confirm.popup_centered()
