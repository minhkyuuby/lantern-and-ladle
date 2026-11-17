class_name DungeonStrip
extends Control
## Bottom strip: one corridor per party showing rooms, the party token and the latest log line.

const W := 860.0
const H := 272.0
const ROW_H := 112.0
const INFO_W := 250.0
const CORRIDOR_X := 262.0
const CORRIDOR_W := 586.0

const RESULT_COLORS := {
	"win": Color("5f9e5a"), "fail": Color("b0544e"), "forage": Color("4f9a9a"),
	"treasure": Color("d0a84a"), "boss": Color("b06ad0"), "boss_fail": Color("7a3a5a"),
}

var sim: Sim
var header: Label
var rows: Array = []  # per party: Dictionary of nodes


func _ready() -> void:
	sim = Game.sim
	custom_minimum_size = Vector2(W, H)
	size = Vector2(W, H)
	clip_contents = true
	add_child(UIKit.rect(Color("120e18"), Vector2.ZERO, Vector2(W, H)))
	header = UIKit.label("", 14, UIKit.ACCENT)
	header.position = Vector2(12, 6)
	add_child(header)
	sim.events.parties_changed.connect(_rebuild)
	sim.events.room_resolved.connect(_on_room)
	Game.resynced.connect(_rebuild)
	_rebuild()


func _rebuild() -> void:
	for r in rows:
		r["root"].queue_free()
	rows.clear()
	for i in sim.state.parties.size():
		var root := Control.new()
		root.position = Vector2(0, 32 + i * ROW_H)
		root.size = Vector2(W, ROW_H - 6)
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(root)
		root.add_child(UIKit.rect(UIKit.PANEL, Vector2(8, 0), Vector2(INFO_W, ROW_H - 10), 6))
		var title := UIKit.label("", 14, UIKit.TEXT)
		title.position = Vector2(16, 4)
		root.add_child(title)
		var members := UIKit.label("", 12, UIKit.MUTED)
		members.position = Vector2(16, 26)
		members.size = Vector2(INFO_W - 16, 18)
		members.clip_text = true
		root.add_child(members)
		var state := UIKit.label("", 12, UIKit.INFO)
		state.position = Vector2(16, 46)
		root.add_child(state)
		var stam := UIKit.bar(UIKit.GOOD, 6)
		stam.position = Vector2(16, 72)
		stam.size = Vector2(INFO_W - 24, 6)
		root.add_child(stam)
		var stam_lbl := UIKit.label("stamina", 10, UIKit.MUTED)
		stam_lbl.position = Vector2(16, 80)
		root.add_child(stam_lbl)
		var corridor := UIKit.rect(Color("2a2a22"), Vector2(CORRIDOR_X, 0), Vector2(CORRIDOR_W, 62), 6)
		root.add_child(corridor)
		var rooms := Control.new()
		rooms.position = Vector2(CORRIDOR_X, 0)
		rooms.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(rooms)
		var token := Actor.new().setup("🧭", Color("e0c08a"), "", Vector2(26, 30))
		token.position = Vector2(CORRIDOR_X + 4, 16)
		root.add_child(token)
		var log_lbl := UIKit.label("", 12, UIKit.TEXT)
		log_lbl.position = Vector2(CORRIDOR_X + 4, 68)
		log_lbl.size = Vector2(CORRIDOR_W - 8, 18)
		log_lbl.clip_text = true
		root.add_child(log_lbl)
		rows.append({
			"root": root, "title": title, "members": members, "state": state, "stam": stam,
			"corridor": corridor, "rooms": rooms, "token": token, "log": log_lbl, "key": "",
		})


func _room_layout(row: Dictionary, p: Party) -> void:
	var key := "%d-%d-%d-%d" % [p.dives, p.current_floor, p.room_count, int(p.state == Party.DIVING)]
	if row["key"] == key:
		return
	row["key"] = key
	var rooms: Control = row["rooms"]
	for ch in rooms.get_children():
		ch.queue_free()
	if p.state != Party.DIVING:
		return
	var fd := sim.db.floor_def(p.current_floor)
	(row["corridor"].get_theme_stylebox("panel") as StyleBoxFlat).bg_color = fd.color
	var n := maxi(1, p.room_count)
	var w := CORRIDOR_W / n
	for i in n:
		var boss := sim.expedition.boss_active(fd.index) and i == n - 1
		var col: Color = RESULT_COLORS.get(p.room_results[i], Color.GRAY) if i < p.room_results.size() else Color(0, 0, 0, 0.3)
		var box := UIKit.rect(col, Vector2(i * w + 4, 8), Vector2(w - 8, 46), 5)
		if boss:
			var skull := UIKit.label("👑", 18)
			skull.position = Vector2(w / 2 - 12, 10)
			box.add_child(skull)
		rooms.add_child(box)


func _on_room(p, result: String, _text: String) -> void:
	if Game.catching_up:
		return
	var i := sim.state.parties.find(p)
	if i < 0 or i >= rows.size():
		return
	var rooms: Control = rows[i]["rooms"]
	var idx: int = p.room_idx - 1
	if idx >= 0 and idx < rooms.get_child_count():
		var box: Panel = rooms.get_child(idx)
		(box.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = RESULT_COLORS.get(result, Color.GRAY)
		var token: Actor = rows[i]["token"]
		var icon := {"win": "⚔", "fail": "💥", "forage": "🌿", "treasure": "💰", "boss": "👑", "boss_fail": "💥"}
		token.say(icon.get(result, ""))


func _process(_delta: float) -> void:
	var s := sim.state
	header.text = "⛏  The Hollow — %s    deepest floor %d/%d%s" % [
		sim.db.floor_def(s.max_floor).biome, s.max_floor, sim.db.floors.size(), "    ✨ all bosses beaten!" if s.slice_complete else ""]
	for i in mini(rows.size(), s.parties.size()):
		var p: Party = s.parties[i]
		var row: Dictionary = rows[i]
		_room_layout(row, p)
		var ms := sim.expedition.members(p)
		var mode := "Floor %d" % p.floor_index
		if p.auto_floor:
			mode = "Auto: restock" if p.auto_mode == "restock" else "Auto: deepest"
		row["title"].text = "%s  ·  %s" % [p.name, mode]
		row["members"].text = "  ".join(PackedStringArray(ms.map(func(c): return "%s %s %d" % [c.icon(), c.name, c.level]))) if not ms.is_empty() else "No members — assign in Expeditions tab"
		var stam := 0.0
		for c in ms:
			stam += c.stamina / c.max_stamina
		row["stam"].value = stam / maxi(1, ms.size())
		var token: Actor = row["token"]
		match p.state:
			Party.DIVING:
				var fd := sim.db.floor_def(p.current_floor)
				row["state"].text = "Diving F%d %s — room %d/%d" % [p.current_floor, fd.display_name, mini(p.room_idx + 1, p.room_count), p.room_count]
				token.visible = true
				var frac := clampf(p.elapsed / maxf(1.0, p.duration), 0.0, 1.0)
				token.position = Vector2(CORRIDOR_X + 4 + frac * (CORRIDOR_W - 34), 16)
			Party.RESTING:
				row["state"].text = "💤 Resting at the guild"
				token.visible = false
			_:
				row["state"].text = "Idle" + ("" if p.repeat else " (standing order off)")
				token.visible = false
		row["log"].text = p.last_log
