class_name SimEvents
extends RefCounted
## Signals the simulation emits. Views listen to these; the sim never touches nodes.

# Clock / meta
signal phase_changed(phase: int)
signal day_ended(report: Dictionary)
signal logged(text: String, important: bool)

# Dungeon
signal expedition_started(party)
signal room_resolved(party, result: String, text: String)
signal expedition_returned(party, cleared: bool)
signal floor_unlocked(index: int)
signal slice_completed()

# Restaurant
signal restaurant_opened()
signal restaurant_closed()
signal customer_arrived(customer)
signal customer_turned_away()
signal customer_seated(customer)
signal customer_ordered(customer)
signal customer_served(customer, worker_id: int)
signal customer_paid(customer, amount: float)
signal customer_left(customer, reason: String)
signal job_started(job, chef)
signal job_ready(job, chef)
signal job_cancelled(job, worker_id: int)
signal delivery_started(job, worker)
signal station_boosted(index: int)

# Progression
signal character_leveled(character)
signal recipe_unlocked(recipe)
signal hired(character)
signal dismissed(character)
signal board_refreshed()
signal upgrade_bought(upgrade)
signal parties_changed()
signal perk_bought(perk)
