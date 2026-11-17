class_name IngredientDef
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var icon: String = ""
@export var color: Color = Color.WHITE
## "dungeon" items come from expeditions, "market" items are bought with gold.
@export var source: String = "dungeon"
@export var market_price: int = 0
@export var spoils: bool = true
@export var sort_order: int = 0
