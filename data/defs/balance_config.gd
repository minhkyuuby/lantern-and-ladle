class_name BalanceConfig
extends Resource
## Every tunable number of the prototype lives here. Edit balance.tres in the inspector.

@export_group("Time")
## Fixed simulation step in game seconds.
@export var tick: float = 0.25
@export var day_length: float = 180.0
@export var dusk_length: float = 20.0
@export var night_length: float = 280.0

@export_group("Start")
@export var start_gold: int = 40
@export var rice_target: int = 10

@export_group("Restaurant")
@export var base_seats: int = 3
@export var max_seats: int = 8
@export var max_queue: int = 4
@export var queue_patience: float = 20.0
## Customers per second at 0 renown.
@export var base_traffic: float = 0.07
## Extra traffic fraction per renown point.
@export var renown_traffic: float = 0.01
@export var min_traffic: float = 0.03
@export var eat_time: float = 6.0
@export var deliver_time: float = 3.0
## Delivery time multiplier when a chef has to deliver (no server hired).
@export var chef_deliver_penalty: float = 1.6
@export var tip_rate: float = 0.15
@export var quality_mult: Array[float] = [1.0, 1.25, 1.6, 2.2]
@export var angry_renown_loss: float = 1.0
@export var skill_quality_chance: float = 0.04
@export var boost_mult: float = 1.6
@export var boost_duration: float = 3.0
@export var boost_cooldown: float = 8.0

@export_group("Dungeon")
@export var combat_k: float = 0.5
@export var room_weights: Dictionary = {"combat": 50, "forage": 35, "treasure": 15}
@export var stamina_per_room: float = 8.0
@export var fail_stamina: float = 15.0
## Party won't start a dive if anyone is below this fraction of max stamina.
@export var rest_threshold: float = 0.35
## Stamina regained per second when not diving.
@export var rest_rate: float = 1.2
@export var auto_floor_min_success: float = 0.65
## "Restock" parties aim to keep this many of each needed ingredient.
@export var restock_target: int = 8

@export_group("Pantry")
@export var fresh_days: int = 2

@export_group("Staff")
@export var wage_chef: int = 15
@export var wage_server: int = 8
@export var wage_adventurer: int = 10
@export var wage_per_level: int = 3
@export var hire_fee_mult: float = 4.0
@export var roster_cap: int = 4
@export var board_size: int = 3
@export var board_refresh_days: int = 2
@export var max_party_size: int = 3
## Work speed multiplier while wages are owed.
@export var debt_slowdown: float = 0.75
@export var xp_base: float = 20.0
@export var xp_exp: float = 1.8

@export_group("Offline")
@export var offline_cap_hours: float = 8.0
@export var offline_dt: float = 1.0
