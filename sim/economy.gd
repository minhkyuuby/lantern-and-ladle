class_name Economy
extends RefCounted
## Market restock at dusk and wage settlement at dawn.

var sim: Sim


func _init(s: Sim) -> void:
	sim = s


func total_wages() -> int:
	var t := 0
	for c in sim.state.roster:
		t += c.wage
	return t


## Buys market ingredients (rice) up to the target so the fallback dish is always possible.
func on_dusk() -> void:
	var rice: IngredientDef = sim.db.ingredients.get("rice")
	if rice == null or rice.market_price <= 0:
		return
	var need := sim.state.rice_target - sim.state.inventory.count("rice")
	if need <= 0:
		return
	var afford := int(maxf(0.0, sim.state.gold) / rice.market_price)
	var n := mini(need, afford)
	if n > 0:
		var cost := float(n * rice.market_price)
		sim.state.gold -= cost
		sim.state.inventory.add("rice", 0, n)
		sim.report_add("market_spent", cost)


## Pays wages plus outstanding debt. A shortfall becomes debt (staff slow down) — never a game over.
func settle_wages() -> void:
	var owed := float(total_wages()) + sim.state.debt
	if sim.state.gold >= owed:
		sim.state.gold -= owed
		sim.state.debt = 0.0
		sim.report_add("wages_paid", owed)
	else:
		var paid := maxf(0.0, sim.state.gold)
		sim.state.gold -= paid
		sim.state.debt = owed - paid
		sim.report_add("wages_paid", paid)
		sim.log_msg("Couldn't pay full wages — %dg owed. The staff grumble and work slower." % int(ceil(sim.state.debt)), true)
	sim.state.report["debt"] = sim.state.debt
