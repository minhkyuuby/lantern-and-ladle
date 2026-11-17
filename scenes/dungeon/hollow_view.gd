class_name HollowView
extends Control
## Full-screen dungeon view: one corridor per party (the party leader walks through the rooms)
## and a row of floor cards. Party settings live in the Dives drawer.

const W := 1280.0
const H := 656.0
const TOP := 136.0
const ROW_H := 150.0
const INFO := Rect2(24, 0, 300, 132)
const CORR_X := 340.0
const CORR_W := 916.0
const CHAR := Vector2(54, 78)

const RESULT_COLORS := {
	"win": Color("6fa868"), "fail": Color("c0645a"), "forage": Color("5fa8a0"),
	"treasure": Color("d8b05a"), "boss": Color("c08ad0"), "boss_fail": Color("8a4a64"),
}
const RESULT_ICONS := {"win": "⚔", "fail": "💥", "forage": "🌿", "treasure": "💰", "boss": "👑", "boss_fail": "💥"}

var sim: Sim
var header: Label
var rows: Array = []
var floor_cards: Array = []


func _ready() -> void:
	sim = Game.sim
	size = Vector2(W, H)
	clip_contents = true
	add_child(UIKit.rect(Color("17110e"), Vector2.ZERO, size))
	add_child(_glow(Vector2(W / 2, H), 700, Color(0.45, 0.32, 0.6, 0.18)))
	header = UIKit.label("", 18, UIKit.ACCENT)
	header.position = Vector2(150, 98)
	add_child(header)
	_build_floor_cards()
	sim.events.parties_changed.connect(_rebuild)
	sim.events.room_resolved.connect(_on_room)
	sim.events.floor_unlocked.connect(func(_i): _build_floor_cards())
	sim.events.hired.connect(func(_c): _rebuild())
	Game.resynced.connect(_rebuild)
	_rebuild()


func _rebuild() -> void:
	for r in rows:
		r["root"].queue_free()
	rows.clear()
	for i in sim.state.parties.size():
		var root := Control.new()
		root.position = Vector2(0, TOP + i * ROW_H)
		root.size = Vector2(W, ROW_H)
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(root)
		root.add_child(UIKit.rect(UIKit.PANEL, INFO.position, INFO.size, 8))
		var title := UIKit.label("", 16)
		title.position = INFO.position + Vector2(12, 8)
		root.add_child(title)
		var members := UIKit.label("", 13, UIKit.MUTED)
		members.position = INFO.position + Vector2(12, 34)
		members.size = Vector2(INFO.size.x - 24, 18)
		members.clip_text = true
		root.add_child(members)
		var state := UIKit.label("", 13, UIKit.INFO)
		state.position = INFO.position + Vector2(12, 58)
		root.add_child(state)
		var stam := UIKit.bar(UIKit.GOOD, 7)
		stam.position = INFO.position + Vector2(12, 92)
		stam.size = Vector2(INFO.size.x - 24, 7)
		root.add_child(stam)
		var sl := UIKit.label("stamina", 11, UIKit.MUTED)
		sl.position = INFO.position + Vector2(12, 102)
		root.add_child(sl)
		var corridor := UIKit.rect(Color("2e2a20"), Vector2(CORR_X, 0), Vector2(CORR_W, 100), 8)
		root.add_child(corridor)
		var rooms := Control.new()
		rooms.position = Vector2(CORR_X, 0)
		rooms.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(rooms)
		var leader := _leader(sim.state.parties[i])
		var token := Actor.new().setup("🧭", Color("e0c08a"), "", CHAR, SpriteLib.crew(leader) if leader else null)
		token.position = Vector2(CORR_X + 10, 96 - CHAR.y)
		root.add_child(token)
		var log_lbl := UIKit.label("", 13)
		log_lbl.position = Vector2(CORR_X + 6, 106)
		log_lbl.size = Vector2(CORR_W - 12, 20)
		log_lbl.clip_text = true
		root.add_child(log_lbl)
		rows.append({"root": root, "title": title, "members": members, "state": state, "stam": stam,
			"corridor": corridor, "rooms": rooms, "token": token, "log": log_lbl, "key": ""})


func _leader(p: Party) -> Character:
	var ms := sim.expedition.members(p)
	return ms[0] if not ms.is_empty() else null


func _build_floor_cards() -> void:
	for c in floor_cards:
		c.queue_free()
	floor_cards.clear()
	var y := TOP + 2 * ROW_H + 6
	var lbl := UIKit.label("Floors", 14, UIKit.ACCENT)
	lbl.position = Vector2(24, y)
	add_child(lbl)
	floor_cards.append(lbl)
	var n := sim.db.floors.size()
	var cw := (W - 48 - (n - 1) * 10) / n
	for i in n:
		var fd := sim.db.floors[i]
		var card := PanelContainer.new()
		card.position = Vector2(24 + i * (cw + 10), y + 26)
		card.custom_minimum_size = Vector2(cw, 0)
		card.add_theme_stylebox_override("panel", UIKit.style(fd.color.darkened(0.25), 8, fd.color.lightened(0.15), 2, 10))
		add_child(card)
		floor_cards.append(card)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		card.add_child(v)
		v.add_child(UIKit.label("%s  F%d" % [fd.biome, fd.index], 11, UIKit.MUTED))
		v.add_child(UIKit.label(fd.display_name, 15))
		var info := UIKit.wrap_label("", 11, UIKit.TEXT)
		info.set_meta("floor", fd.index)
		v.add_child(info)


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
	(row["corridor"].get_theme_stylebox("panel") as StyleBoxFlat).bg_color = fd.color.darkened(0.2)
	var n := maxi(1, p.room_count)
	var w := CORR_W / n
	for i in n:
		var col: Color = RESULT_COLORS.get(p.room_results[i], Color.GRAY) if i < p.room_results.size() else Color(0, 0, 0, 0.28)
		var box := UIKit.rect(col, Vector2(i * w + 6, 10), Vector2(w - 12, 80), 8)
		rooms.add_child(box)
		var icon := UIKit.label("", 22)
		icon.position = Vector2(w / 2 - 12, 34)
		box.add_child(icon)
		if i < p.room_results.size():
			icon.text = RESULT_ICONS.get(p.room_results[i], "")
		elif sim.expedition.boss_active(fd.index) and i == n - 1:
			icon.text = "👑"


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
		(box.get_child(0) as Label).text = RESULT_ICONS.get(result, "")
		rows[i]["token"].say(RESULT_ICONS.get(result, ""))


func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
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
		row["members"].text = "  ".join(PackedStringArray(ms.map(func(c): return "%s %d" % [c.name, c.level]))) if not ms.is_empty() else "No members — assign in 🗺 Dives"
		var stam := 0.0
		for c in ms:
			stam += c.stamina / c.max_stamina
		row["stam"].value = stam / maxi(1, ms.size())
		var token: Actor = row["token"]
		match p.state:
			Party.DIVING:
				var fd := sim.db.floor_def(p.current_floor)
				row["state"].text = "Diving F%d %s · room %d/%d" % [p.current_floor, fd.display_name, mini(p.room_idx + 1, p.room_count), p.room_count]
				token.visible = true
				var frac := clampf(p.elapsed / maxf(1.0, p.duration), 0.0, 1.0)
				token.position.x = CORR_X + 10 + frac * (CORR_W - CHAR.x - 20)
			Party.RESTING:
				row["state"].text = "💤 Resting at the guild"
				token.visible = false
			_:
				row["state"].text = "Idle" + ("" if p.repeat else " (standing order off)")
				token.visible = false
		row["log"].text = p.last_log
	for c in floor_cards:
		if c is PanelContainer:
			var info: Label = c.get_child(0).get_child(2)
			var idx: int = info.get_meta("floor")
			var fd := sim.db.floor_def(idx)
			if idx > s.max_floor:
				info.text = "🔒 " + (sim.progression.floor_lock_reason(idx) if idx == s.max_floor + 1 else "Locked")
				c.modulate = Color(1, 1, 1, 0.6)
			else:
				var boss := ""
				if fd.boss_name != "":
					boss = "  ·  👑 beaten" if idx in s.bosses_beaten else ("  ·  👑 waiting" if sim.expedition.boss_active(idx) else "  ·  👑 after %d clears" % fd.boss_after_clears)
				info.text = "danger %d · cleared %d×%s" % [int(fd.danger), s.cleared_count(idx), boss]
				c.modulate = Color.WHITE


func _glow(pos: Vector2, r: float, color: Color) -> TextureRect:
	var g := Gradient.new()
	g.set_color(0, color)
	g.set_color(1, Color(color.r, color.g, color.b, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	var t := TextureRect.new()
	t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.size = Vector2(r * 2, r)
	t.position = pos - Vector2(r, r * 0.5)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t
