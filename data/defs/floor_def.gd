class_name FloorDef
extends Resource

@export var index: int = 1
@export var display_name: String = ""
@export var biome: String = "Mossy Cellars"
## Upgrade id that must be bought before this floor can unlock (e.g. a permit).
@export var requires_upgrade: String = ""
@export var color: Color = Color(0.25, 0.3, 0.25)
## Seconds of game time for a full dive.
@export var duration: float = 60.0
@export var rooms: int = 4
@export var danger: float = 3.0
## ingredient_id -> weight
@export var loot: Dictionary = {}
## Items rolled per successful room (x = min, y = max).
@export var loot_per_success: Vector2i = Vector2i(1, 2)
@export var xp_per_room: int = 3
## Full clears of this floor needed before the next floor unlocks.
@export var clears_to_unlock: int = 1
## Recipe scroll that can be found in treasure rooms.
@export var scroll_recipe: String = ""
@export var scroll_chance: float = 0.0
## Optional boss in the final room.
@export var boss_name: String = ""
@export var boss_danger_mult: float = 2.0
## The boss only appears once this floor has been fully cleared this many times.
@export var boss_after_clears: int = 0
## ingredient_id -> count, granted when the boss is beaten.
@export var boss_loot: Dictionary = {}
@export var boss_scroll: String = ""
