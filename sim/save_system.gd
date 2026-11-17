class_name SaveSystem
extends RefCounted

const PATH := "user://save.json"
const VERSION := 1


static func save(state: GameState) -> void:
	var d := state.to_dict()
	d["version"] = VERSION
	d["saved_at"] = Time.get_unix_time_from_system()
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		push_error("SaveSystem: cannot write %s" % PATH)
		return
	f.store_string(JSON.stringify(d))


static func load_dict() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return {}
	var txt := FileAccess.get_file_as_string(PATH)
	var parsed = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("SaveSystem: save file unreadable, starting fresh")
		return {}
	if int(parsed.get("version", 0)) != VERSION:
		push_warning("SaveSystem: save version mismatch, starting fresh")
		return {}
	return parsed


static func delete_save() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
