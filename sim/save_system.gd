class_name SaveSystem
extends RefCounted

const PATH := "user://save.json"
const VERSION := 1

## Active save file. Tests and tools switch it with use_slot() so they never touch the player's save.
static var path: String = PATH


static func use_slot(slot: String) -> void:
	path = PATH if slot == "" else "user://save_%s.json" % slot


static func save(state: GameState) -> void:
	var d := state.to_dict()
	d["version"] = VERSION
	d["saved_at"] = Time.get_unix_time_from_system()
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("SaveSystem: cannot write %s" % path)
		return
	f.store_string(JSON.stringify(d))


static func load_dict() -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var txt := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("SaveSystem: save file unreadable, starting fresh")
		return {}
	if int(parsed.get("version", 0)) != VERSION:
		push_warning("SaveSystem: save version mismatch, starting fresh")
		return {}
	return parsed


static func delete_save() -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
