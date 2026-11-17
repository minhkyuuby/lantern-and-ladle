class_name UpgradeDef
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var icon: String = ""
@export_multiline var description: String = ""
## seats | grill | pot | oven | freshness | traffic | cook_speed | roster | party | power | permit
@export var effect: String = ""
## Amount added per level.
@export var amount: float = 1.0
@export var base_cost: int = 100
@export var cost_mult: float = 1.5
@export var max_level: int = 1
@export var min_renown: int = 0
## Floor index whose boss must be beaten before this can be bought (0 = none).
@export var requires_boss: int = 0
@export var sort_order: int = 0


func cost_at(level: int) -> int:
	return int(round(base_cost * pow(cost_mult, level)))
