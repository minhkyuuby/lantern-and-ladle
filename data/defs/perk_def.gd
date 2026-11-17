class_name PerkDef
extends Resource
## Permanent bonus bought with Golden Ladles (earned at the Festival of Lanterns). Survives resets.

@export var id: String = ""
@export var display_name: String = ""
@export var icon: String = ""
@export_multiline var description: String = ""
## start_gold | chef_levels | adv_levels | price | xp | traffic | dive_speed
@export var effect: String = ""
## Amount added per level.
@export var amount: float = 1.0
## Ladle cost of level n (0-based) = base_cost + cost_step * n.
@export var base_cost: int = 1
@export var cost_step: int = 1
@export var max_level: int = 5
@export var sort_order: int = 0


func cost_at(level: int) -> int:
	return base_cost + cost_step * level
