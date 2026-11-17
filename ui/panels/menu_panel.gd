class_name MenuPanel
extends TabPanel


func _connect() -> void:
	sim.events.recipe_unlocked.connect(mark_dirty)
	sim.events.upgrade_bought.connect(mark_dirty)


func build() -> void:
	add(UIKit.wrap_label("The menu builds itself from what's in the pantry. Untick a dish to keep it off tonight's menu.", 12))
	var h := row()
	h.add_child(UIKit.label("🍚 Keep rice stocked at", 13))
	var spin := SpinBox.new()
	spin.min_value = 0
	spin.max_value = 60
	spin.value = sim.state.rice_target
	spin.value_changed.connect(func(val: float): sim.state.rice_target = int(val))
	h.add_child(spin)
	add(h)
	var chef_lv := UIKit.label("", 12, UIKit.MUTED)
	add(chef_lv)
	live(func(): chef_lv.text = "Head chef level %d · rice bought at dusk (1g each)" % sim.progression.head_chef_level())

	for r in sim.db.recipe_list():
		var v := card()
		var top := row()
		var cb := CheckBox.new()
		cb.focus_mode = Control.FOCUS_NONE
		cb.text = "%s %s" % [r.icon, r.display_name]
		cb.button_pressed = not (r.id in sim.state.disabled_recipes)
		cb.toggled.connect(func(on: bool):
			if on:
				sim.state.disabled_recipes.erase(r.id)
			elif not (r.id in sim.state.disabled_recipes):
				sim.state.disabled_recipes.append(r.id))
		top.add_child(cb)
		top.add_child(spacer())
		top.add_child(UIKit.label("%dg" % r.price, 14, UIKit.ACCENT))
		v.add_child(top)
		var ing := ""
		for id in r.ingredients:
			ing += "%s×%d " % [sim.db.ingredient_icon(id), int(r.ingredients[id])]
		v.add_child(UIKit.label("%s· %.0fs · tags: %s" % [ing, r.cook_time, ", ".join(PackedStringArray(r.tags))], 11, UIKit.MUTED))
		var status := UIKit.label("", 12)
		v.add_child(status)
		live(func():
			var unlocked := r.id in sim.state.unlocked_recipes
			cb.disabled = not unlocked
			if not unlocked:
				if r.needs_scroll and not (r.id in sim.state.scrolls):
					status.text = "📜 Needs scroll — %s (and chef Lv %d)" % [r.scroll_hint, r.chef_level]
				else:
					status.text = "🔒 Head chef Lv %d" % r.chef_level
				status.add_theme_color_override("font_color", UIKit.MUTED)
			else:
				var n := sim.state.inventory.portions(r.ingredients)
				status.text = "Can make %d right now" % n
				status.add_theme_color_override("font_color", UIKit.GOOD if n > 0 else UIKit.BAD))
