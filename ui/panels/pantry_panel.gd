class_name PantryPanel
extends TabPanel

var _refresh_t: float = 0.0


func _process(delta: float) -> void:
	_refresh_t += delta
	if _refresh_t >= 1.0:
		_refresh_t = 0.0
		dirty = true
	super._process(delta)


func build() -> void:
	add(UIKit.wrap_label("Perishables lose a quality tier each dawn and spoil after %d dawns. Better quality sells for more." % sim.fresh_days(), 12))
	var any := false
	for def in sim.db.ingredient_list():
		var n := sim.state.inventory.count(def.id)
		if n <= 0:
			continue
		any = true
		var v := card()
		var h := row()
		h.add_child(UIKit.label("%s %s" % [def.icon, def.display_name], 14))
		h.add_child(spacer())
		h.add_child(UIKit.label("×%d" % n, 15, UIKit.ACCENT))
		v.add_child(h)
		var qb := sim.state.inventory.quality_breakdown(def.id)
		var parts: Array[String] = []
		for q in 4:
			if qb[q] > 0:
				parts.append("%s %d" % [Inventory.QUALITY_NAMES[q], qb[q]])
		var age := sim.state.inventory.oldest_age(def.id)
		var fresh := "never spoils" if not def.spoils else ("oldest: day %d of %d" % [age, sim.fresh_days()])
		v.add_child(UIKit.label("%s · %s" % [" · ".join(PackedStringArray(parts)), fresh], 11,
			UIKit.BAD if def.spoils and age >= sim.fresh_days() else UIKit.MUTED))
	if not any:
		add(UIKit.label("The pantry is empty.", 13, UIKit.MUTED))
