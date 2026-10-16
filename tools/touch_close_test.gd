extends SceneTree
## Every panel can be shut with a finger (Faisal 2026-10-14: on the iPad the
## wood upgrade strip and the training panel would not close). Taps are real
## InputEventScreenTouch events, so Godot also sends its emulated mouse click
## the way an iPad does; a panel that reacts to both toggles twice. Also
## checks the Controls tab's layout pick. Run from the project root:
##     godot --headless --path . --script tools/touch_close_test.gd

const Stats = preload("res://scripts/stats.gd")

var fails := 0
var game
var hud


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func frames(n: int = 2) -> void:
	for i in n:
		await process_frame


func finger(at: Vector2) -> void:
	## One finger down and up, like a quick tap on the glass. (Window
	## coordinates: the headless window is tiny and the game stretches.)
	at = root.get_final_transform() * at
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.position = at
	e.pressed = true
	Input.parse_input_event(e)
	Input.flush_buffered_events()
	await frames(2)
	var u := InputEventScreenTouch.new()
	u.index = 0
	u.position = at
	u.pressed = false
	Input.parse_input_event(u)
	Input.flush_buffered_events()
	await frames(3)


func rect_for(action) -> Rect2:
	for e in hud.touch_rects:
		if typeof(e[1]) == typeof(action) and e[1] == action:
			return e[0]
	return Rect2()


func _init() -> void:
	var cfg := "user://controls.cfg"
	var backup := FileAccess.get_file_as_bytes(cfg) if FileAccess.file_exists(cfg) else PackedByteArray()
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await frames(5)
	hud = game.hud
	hud.set_anchors_preset(Control.PRESET_TOP_LEFT)
	hud.size = Vector2(1280, 720)
	game.touch.size = Vector2(1280, 720)
	game.control_layout = "auto"
	game.apply_control_layout()
	await frames(3)
	check(not game.touch_active, "Auto on a computer starts on the keyboard layout, even with a touch screen")

	var m = game.main_menu
	m._press("play", null)
	m._press("team_size", 1)
	m._press("to_lobby", null)
	m.start()
	await frames(10)
	check(game.playing, "a 1v1 match starts")
	var p = game.player
	p.spawn_protect = 999.0
	p.set_role(Stats.Role.KNIGHT)
	await frames(3)
	# A finger in the empty middle of the field turns the touch layout on.
	await finger(Vector2(900, 400))
	await frames(3)
	check(game.touch_active and hud.touch_ui, "a real touch turns the touch layout on")

	# --- The LEVEL UP strip (with the Training tile): its X puts it away ----
	game.time_left = 200.0   # late in the match: Training is on the strip
	p.points = 1
	await frames(4)
	var x := rect_for(hud.hide_quick)
	check(x.has_area(), "the LEVEL UP strip draws an X on touch")
	var before: int = p.points
	await finger(x.get_center())
	await frames(3)
	check(rect_for(hud.hide_quick).size == Vector2.ZERO and hud.quick_buttons.is_empty(), "tapping the X closes the LEVEL UP strip")
	check(p.points == before, "closing the strip spent nothing")
	p.points += 1
	await frames(3)
	check(not hud.quick_buttons.is_empty(), "a new point brings the strip back")

	# A LEVEL UP rank tile buys ONE rank per tap (the emulated click used to buy a second).
	p.spawn_protect = 999.0
	if p.has_method("calm_left"):
		p.set("calm", 0.0)
	var tile := Rect2()
	for e in hud.touch_rects:
		if typeof(e[1]) == TYPE_STRING and e[1] == "quick_tap":
			tile = e[0]
			break
	p.points = 2
	await frames(3)
	if tile.has_area() and p.calm_left() <= 0.0:
		var pts: int = p.points
		await finger(tile.get_center())
		await frames(3)
		check(p.points == pts - 1, "one tap on a LEVEL UP tile spends exactly one point (%d -> %d)" % [pts, p.points])
	else:
		print("SKIP  rank tile (in combat or none)")

	# --- The Veteran Training panel: its X closes it ---------------------------
	p.points = 0
	var econ = game.economy
	econ.training_open = true
	await frames(4)
	var tx := Rect2()
	for e in hud.touch_rects:
		if e[1] is Callable and e[1] == Callable(econ, "close_training"):
			tx = e[0]
	check(tx.has_area(), "the training panel draws an X on touch")
	await finger(tx.get_center())
	await frames(3)
	check(not econ.training_open, "tapping the X closes the training panel")
	# Even for a player whose hat has a move (no training slot, G is the move).
	econ.training_open = true
	await frames(3)
	var tx2 := rect_for(Callable(econ, "close_training"))
	check(tx2.has_area(), "the X is there whatever the hat carries")

	# The training slot: one tap opens the panel, one closes it (it toggled twice).
	econ.training_open = false
	await frames(3)
	var slot := Rect2()
	for e in hud.touch_rects:
		if typeof(e[1]) == TYPE_STRING and e[1] == "ability_3":
			slot = e[0]
	if slot.has_area():
		await finger(slot.get_center())
		await frames(3)
		check(econ.training_open, "one tap on the TRAINING slot opens the panel")
		await finger(slot.get_center())
		await frames(3)
		check(not econ.training_open, "a second tap on the slot closes it")
	else:
		print("SKIP  training slot not drawn for this class")

	# --- The pause menu: the X and RESUME close it ------------------------------
	econ.training_open = false
	await frames(2)
	var pause := rect_for("menu")
	check(pause.has_area(), "the touch layout has a pause button")
	await finger(pause.get_center())
	await frames(4)
	check(game.menu_open, "tapping pause opens the menu")
	await finger(hud.close_button.get_center())
	await frames(4)
	check(not game.menu_open, "tapping the X closes the pause menu")

	# --- Chat: a tap outside closes it ------------------------------------------
	game.chat_open = true
	await frames(3)
	await finger(Vector2(640, 300))
	await frames(3)
	check(not game.chat_open, "a tap closes the chat box")

	# --- Controls tab: the layout pick ------------------------------------------
	game.menu_open = true
	game.get_tree().paused = true
	game.menu_tab = 4
	await frames(4)
	var kb := Rect2()
	for b in hud.toggle_buttons:
		if b[1] == "layout_keyboard":
			kb = b[0]
	check(kb.has_area(), "Controls shows the CONTROL LAYOUT choices")
	await finger(kb.get_center())
	await frames(4)
	check(game.control_layout == "keyboard" and not game.touch_active, "KEYBOARD & MOUSE turns the touch layout off")
	var cf := ConfigFile.new()
	cf.load(cfg)
	check(cf.get_value("settings", "control_layout", "") == "keyboard", "the layout pick is saved")
	var tb := Rect2()
	for b in hud.toggle_buttons:
		if b[1] == "layout_touch":
			tb = b[0]
	await finger(tb.get_center())
	await frames(4)
	check(game.control_layout == "touch" and game.touch_active, "a tap still works the menu, and TOUCH brings the thumb layout back")
	# A rebind started by a tap is cancelled by the next tap, not bound to a mouse click.
	var row := Rect2()
	for b in hud.bind_buttons:
		row = b[0]
		break
	var act := ""
	for b in hud.bind_buttons:
		act = b[1]
		break
	var was: String = game.binding_text(act, "key")
	await finger(row.get_center())
	await frames(3)
	check(game.rebinding == act, "a tap on a Controls row starts the rebind")
	await finger(Vector2(200, 650))
	await frames(3)
	check(game.rebinding == "" and game.binding_text(act, "key") == was, "the next tap cancels it and the key stays as it was")
	game.control_layout = "auto"
	game.apply_control_layout()

	print("TOUCH CLOSE TEST: %d failed" % fails)
	if backup.is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
	else:
		var f := FileAccess.open(cfg, FileAccess.WRITE)
		f.store_buffer(backup)
		f.close()
	quit(fails)
