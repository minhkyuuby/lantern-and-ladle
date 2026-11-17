class_name RecipeDef
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var icon: String = ""
## ingredient_id -> count
@export var ingredients: Dictionary = {}
## "grill" or "pot"
@export var station: String = "grill"
@export var cook_time: float = 5.0
@export var price: int = 10
@export var chef_level: int = 1
## If true the recipe also needs its scroll (found in the dungeon) before it unlocks.
@export var needs_scroll: bool = false
@export var scroll_hint: String = ""
@export var tags: Array[String] = []
@export var xp: int = 2
## Base order weight; customers multiply it for each preferred tag.
@export var appeal: float = 1.0
@export var sort_order: int = 0
