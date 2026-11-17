class_name Character
extends RefCounted

const CHEF := "chef"
const SERVER := "server"
const ADVENTURER := "adventurer"

var id: int = 0
var name: String = ""
var role: String = CHEF
var level: int = 1
var xp: float = 0.0
## Chef: cooking speed multiplier. Server: delivery speed multiplier.
var speed: float = 1.0
## Chef: chance to raise dish quality.
var skill: float = 1.0
var power: float = 5.0
var luck: float = 2.0
var stamina: float = 100.0
var max_stamina: float = 100.0
var wage: int = 10
## idle | working | diving | resting
var status: String = "idle"


func xp_to_next(b: BalanceConfig) -> float:
	return b.xp_base * pow(float(level), b.xp_exp)


## Returns true if at least one level was gained.
func add_xp(amount: float, b: BalanceConfig) -> bool:
	xp += amount
	var leveled := false
	while xp >= xp_to_next(b):
		xp -= xp_to_next(b)
		level += 1
		leveled = true
		match role:
			CHEF:
				speed += 0.08
				skill += 1.0
			SERVER:
				speed += 0.12
			ADVENTURER:
				power += 1.5
				luck += 0.8
				max_stamina += 5.0
		wage += b.wage_per_level
	return leveled


func icon() -> String:
	match role:
		CHEF:
			return "🍳"
		SERVER:
			return "🛎"
		_:
			return "🗡"


func role_name() -> String:
	return role.capitalize()


func stat_line() -> String:
	match role:
		CHEF:
			return "Speed %.2f · Skill %.1f" % [speed, skill]
		SERVER:
			return "Speed %.2f" % speed
		_:
			return "Power %.1f · Luck %.1f" % [power, luck]


func to_dict() -> Dictionary:
	return {
		"id": id, "name": name, "role": role, "level": level, "xp": xp,
		"speed": speed, "skill": skill, "power": power, "luck": luck,
		"stamina": stamina, "max_stamina": max_stamina, "wage": wage, "status": status,
	}


static func from_dict(d: Dictionary) -> Character:
	var c := Character.new()
	c.id = int(d.get("id", 0))
	c.name = str(d.get("name", "?"))
	c.role = str(d.get("role", CHEF))
	c.level = int(d.get("level", 1))
	c.xp = float(d.get("xp", 0.0))
	c.speed = float(d.get("speed", 1.0))
	c.skill = float(d.get("skill", 1.0))
	c.power = float(d.get("power", 5.0))
	c.luck = float(d.get("luck", 2.0))
	c.stamina = float(d.get("stamina", 100.0))
	c.max_stamina = float(d.get("max_stamina", 100.0))
	c.wage = int(d.get("wage", 10))
	c.status = str(d.get("status", "idle"))
	return c
