class_name ContentDB
extends RefCounted
## Loads every content resource under res://data/content/ and offers lookups.

const ROOT := "res://data/content"

var ingredients: Dictionary = {}  # id -> IngredientDef
var recipes: Dictionary = {}  # id -> RecipeDef
var floors: Array[FloorDef] = []
var upgrades: Array[UpgradeDef] = []
var customer_types: Array[CustomerTypeDef] = []
var perks: Array[PerkDef] = []
var balance: BalanceConfig
## Story scenes parsed from res://data/story/*.dlg, by id.
var scenes: Dictionary = {}
var scene_errors: Array = []
var _scene_list: Array = []

var _recipe_list: Array[RecipeDef] = []
var _ingredient_list: Array[IngredientDef] = []


static func load_default() -> ContentDB:
	var db := ContentDB.new()
	for r in _load_dir(ROOT + "/ingredients"):
		db.ingredients[r.id] = r
		db._ingredient_list.append(r)
	for r in _load_dir(ROOT + "/recipes"):
		db.recipes[r.id] = r
		db._recipe_list.append(r)
	for r in _load_dir(ROOT + "/floors"):
		db.floors.append(r)
	for r in _load_dir(ROOT + "/upgrades"):
		db.upgrades.append(r)
	for r in _load_dir(ROOT + "/customers"):
		db.customer_types.append(r)
	for r in _load_dir(ROOT + "/perks"):
		db.perks.append(r)
	db.perks.sort_custom(func(a, b): return a.sort_order < b.sort_order)
	db.floors.sort_custom(func(a, b): return a.index < b.index)
	db.upgrades.sort_custom(func(a, b): return a.sort_order < b.sort_order)
	db._recipe_list.sort_custom(func(a, b): return a.sort_order < b.sort_order)
	db._ingredient_list.sort_custom(func(a, b): return a.sort_order < b.sort_order)
	db._load_scenes("res://data/story")
	db.balance = load(ROOT + "/balance.tres")
	if db.balance == null:
		push_error("balance.tres missing, using defaults")
		db.balance = BalanceConfig.new()
	return db


static func _load_dir(path: String) -> Array:
	var out: Array = []
	var dir := DirAccess.open(path)
	if dir == null:
		push_error("ContentDB: cannot open %s" % path)
		return out
	for f in dir.get_files():
		var fname := f.trim_suffix(".remap")
		if fname.ends_with(".tres") or fname.ends_with(".res"):
			var res := load(path + "/" + fname)
			if res != null:
				out.append(res)
	return out


func _load_scenes(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for f in dir.get_files():
		if not f.ends_with(".dlg"):
			continue
		var sc := DialogParser.parse(FileAccess.get_file_as_string(path + "/" + f), f)
		for e in sc["errors"]:
			push_error("Story: " + e)
			scene_errors.append(e)
		if sc["id"] != "":
			scenes[sc["id"]] = sc
	_scene_list = scenes.values()
	_scene_list.sort_custom(func(a, b): return a["order"] < b["order"])


func scene_list() -> Array:
	return _scene_list


func recipe_list() -> Array[RecipeDef]:
	return _recipe_list


func ingredient_list() -> Array[IngredientDef]:
	return _ingredient_list


func ingredient_icon(id: String) -> String:
	var d: IngredientDef = ingredients.get(id)
	return d.icon if d else "?"


func ingredient_name(id: String) -> String:
	var d: IngredientDef = ingredients.get(id)
	return d.display_name if d else id


func floor_def(index: int) -> FloorDef:
	return floors[clampi(index, 1, floors.size()) - 1]


func perk(id: String) -> PerkDef:
	for p in perks:
		if p.id == id:
			return p
	return null


func upgrade(id: String) -> UpgradeDef:
	for u in upgrades:
		if u.id == id:
			return u
	return null
