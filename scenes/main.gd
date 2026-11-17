extends Control
## Builds the screen: one full-size view at a time (Stall or Hollow), a floating HUD, a bottom
## button bar, and a side drawer that shows one management panel at a time.

const VIEW_H := 656.0

var hud: Hud
var restaurant: RestaurantView
var hollow: HollowView
var bar: BottomBar
var drawer: Drawer
var ledger: LedgerPopup
var toasts: Toasts
var debug: DebugPanel
var fx: Control
var dialog: DialogScene
var _story_wait: float = 0.0


func _ready() -> void:
	theme = UIKit.make_theme()
	add_child(UIKit.rect(UIKit.BG, Vector2.ZERO, Vector2(1280, 720)))

	restaurant = RestaurantView.new()
	add_child(restaurant)
	hollow = HollowView.new()
	hollow.visible = false
	add_child(hollow)

	hud = Hud.new()
	add_child(hud)
	hud.hollow_requested.connect(func(): _show_view("hollow"))

	toasts = Toasts.new()
	toasts.position = Vector2(440, 96)
	toasts.size = Vector2(400, 0)
	add_child(toasts)

	ledger = LedgerPopup.new()
	add_child(ledger)

	drawer = Drawer.new()
	add_child(drawer)
	drawer.add_panel("crew", "👥 Crew", StaffPanel.new())
	drawer.add_panel("hire", "📋 Hire", HirePanel.new())
	drawer.add_panel("dives", "🗺 Dives", ExpeditionPanel.new())
	drawer.add_panel("menu", "📜 Menu", MenuPanel.new())
	drawer.add_panel("pantry", "🧺 Pantry", PantryPanel.new())
	drawer.add_panel("shop", "🛒 Shop", UpgradesPanel.new())
	drawer.add_panel("legacy", "🏮 Legacy", LegacyPanel.new())
	drawer.add_panel("log", "📓 Log", LogPanel.new())

	bar = BottomBar.new()
	bar.position = Vector2(0, VIEW_H)
	add_child(bar)
	bar.view_selected.connect(_show_view)
	bar.panel_pressed.connect(func(p): drawer.toggle(p))
	drawer.panel_changed.connect(func(p): bar.set_open_panel(p))

	debug = DebugPanel.new()
	debug.position = Vector2(640, 80)
	add_child(debug)

	# Topmost layer for effects that cross panels (gold flying to the HUD).
	fx = Control.new()
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx.size = Vector2(1280, 720)
	add_child(fx)
	restaurant.gold_popped.connect(_fly_gold)
	debug.report_ready.connect(func(t, lines): ledger.show_report(t, lines, 15.0))
	hud.debug_pressed.connect(func(): debug.visible = not debug.visible)

	# Story scenes sit above everything else.
	dialog = DialogScene.new()
	add_child(dialog)
	hud.story_pressed.connect(_open_next_story)
	var forced := Game.arg("story")  # test hook: --story=SCENE_ID [--story-advance=N]
	if forced != "":
		(func():
			dialog.open(forced)
			dialog.debug_advance(int(Game.arg("story-advance")))).call_deferred()

	var ev := Game.sim.events
	ev.day_ended.connect(_on_day_ended)
	ev.logged.connect(func(line: String, important: bool):
		if important and not Game.catching_up:
			toasts.push(line))

	# test hooks: --panel=crew|hire|dives|… opens a drawer, --view=hollow switches view
	if Game.arg("panel") != "":
		drawer.open(Game.arg("panel"))
	if Game.arg("view") != "":
		_show_view(Game.arg("view"))

	if not Game.startup_report.is_empty():
		ledger.show_report(Game.startup_report["title"], Game.startup_report["lines"], 20.0)
		Game.startup_report = {}


## "+12g" pops over the seat, then arcs up to the HUD gold counter, shrinking, and bounces it on arrival.
func _fly_gold(start: Vector2, box: Vector2, amount: float) -> void:
	if not restaurant.visible:
		return  # the coins still count; no animation while looking at the Hollow
	hud.gold_in_flight += amount  # the counter only counts it once it lands
	var l := UIKit.label("+%dg" % int(round(amount)), 14, UIKit.ACCENT)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = box
	l.pivot_offset = box / 2.0
	l.position = start - fx.global_position
	fx.add_child(l)

	# Faster game speed -> quicker flights, so coins don't pile up at 10x.
	var d := clampf(1.1 / sqrt(maxf(1.0, Game.time_scale)), 0.5, 1.1)
	var target := hud.gold_target() - fx.global_position - box / 2.0
	var hold := l.position + Vector2(0, -10)
	var tw := l.create_tween()
	tw.tween_property(l, "position", hold, d * 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(d * 0.1)
	tw.set_parallel(true)
	tw.tween_property(l, "position:x", target.x, d * 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(l, "position:y", target.y, d * 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(l, "scale", Vector2(0.75, 0.75), d * 0.6).set_ease(Tween.EASE_IN)
	tw.tween_property(l, "modulate:a", 0.85, d * 0.6).set_ease(Tween.EASE_IN)
	tw.set_parallel(false)
	tw.tween_callback(func():
		hud.gold_in_flight = maxf(0.0, hud.gold_in_flight - amount)
		hud.pulse_gold())
	tw.tween_callback(l.queue_free)


## Waiting scenes open on their own at 1–2× (after a short beat); at faster speeds, or while
## paused, they wait behind the 📖 button so idle play is never interrupted.
func _process(delta: float) -> void:
	var q := Game.sim.story.queue()
	hud.set_story_count(0 if dialog.is_open() else q.size())
	if dialog.is_open() or q.is_empty() or Game.catching_up or ledger.visible:
		_story_wait = 0.0
		return
	if Game.time_scale > 0.0 and Game.time_scale <= 2.0:
		_story_wait += delta
		if _story_wait >= 0.8:
			_story_wait = 0.0
			_open_next_story()


func _open_next_story() -> void:
	var q := Game.sim.story.queue()
	if dialog.is_open() or q.is_empty():
		return
	if not dialog.open(q[0]):
		Game.sim.story.finish(q[0])  # unknown scene id (e.g. removed file): drop it


func _show_view(view: String) -> void:
	restaurant.visible = view != "hollow"
	hollow.visible = view == "hollow"
	hud.show_goals(view != "hollow")
	bar.set_view("hollow" if view == "hollow" else "stall")


func _on_day_ended(r: Dictionary) -> void:
	if Game.catching_up:
		return
	ledger.show_report("🌅 Dawn Ledger — Day %d" % r["day"], LedgerPopup.lines_for_day(r))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F1:
				debug.visible = not debug.visible
			KEY_TAB:
				_show_view("stall" if hollow.visible else "hollow")
			KEY_ESCAPE:
				drawer.close()
			KEY_SPACE:
				Game.set_speed(0.0 if Game.time_scale > 0.0 else 1.0)
			KEY_1:
				Game.set_speed(1.0)
			KEY_2:
				Game.set_speed(2.0)
			KEY_3:
				Game.set_speed(4.0)
			KEY_4:
				Game.set_speed(10.0)
