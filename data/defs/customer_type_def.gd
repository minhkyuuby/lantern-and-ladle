class_name CustomerTypeDef
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var icon: String = ""
@export var color: Color = Color.WHITE
@export var weight: float = 1.0
@export var min_renown: int = 0
## Seconds a seated customer waits for food before leaving angry.
@export var patience: float = 40.0
@export var prefers: Array[String] = []
@export var price_mult: float = 1.0
@export var tip_mult: float = 1.0
@export var renown_gain: float = 1.0
## Below this dish quality (0-3) the customer leaves no tip.
@export var min_quality: int = 0
