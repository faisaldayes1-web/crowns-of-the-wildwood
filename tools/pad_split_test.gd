extends SceneTree
## Split screen with gamepads, the way players do it (CW-4 release gate T06,
## simulated): in the READY UP lobby three pads press A to join and A again
## to ready, the match starts with four panes, and then each pad's left
## stick and the keyboard move only their own player. Also checks that a pad
## nobody joined with moves nobody, and that B on a pad dodges only its
## player. Input is simulated with Input.parse_input_event, so this does not
## replace a test with real controllers (it shows the game routes each
## device to the right player).
##     godot --headless --path . --script tools/pad_split_test.gd
## The settings file is backed up to disk first and restored at the end
## (also on the next run if this one was killed); a lock file keeps two
## settings-writing tests from running at once.
## claude-faisallaptop 2026-10-17.

const CFG := "user://controls.cfg"
const BACKUP := "user://controls.cfg.pad_test_backup"

const LOCK := "user://settings_test.lock"


static func take_lock() -> bool:
	## Tests that rewrite the settings file take turns: two at once broke
	## each other's map picks (2026-10-17). A lock older than 90 minutes is
	## a killed run's and is taken over.
	if FileAccess.file_exists(LOCK):
		var age := Time.get_unix_time_from_system() - FileAccess.get_modified_time(LOCK)
		if age < 90 * 60:
			return false
	var f := FileAccess.open(LOCK, FileAccess.WRITE)
	f.store_string(str(OS.get_process_id()))
	f.close()
	return true


static func drop_lock() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(LOCK))

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await process_frame


func pad_button(device: int, button: JoyButton, pressed: bool) -> void:
	var ev := InputEventJoypadButton.new()
	ev.device = device
	ev.button_index = button
	ev.pressed = pressed
	Input.parse_input_event(ev)


func pad_stick(device: int, x: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.device = device
	ev.axis = JOY_AXIS_LEFT_X
	ev.axis_value = x
	Input.parse_input_event(ev)


func key(code: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)


func moved(g, before: Array) -> Array:
	var out := []
	for k in g.locals.size():
		out.append(g._flat_dist(g.locals[k].global_position, before[k]))
	return out


func positions(g) -> Array:
	return g.locals.map(func(u): return u.global_position)


func _restore() -> void:
	if FileAccess.file_exists(BACKUP):
		var b := FileAccess.get_file_as_bytes(BACKUP)
		if b.is_empty():
			DirAccess.remove_absolute(ProjectSettings.globalize_path(CFG))
		else:
			var f := FileAccess.open(CFG, FileAccess.WRITE)
			f.store_buffer(b)
			f.close()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BACKUP))


func _init() -> void:
	if not take_lock():
		print("pad split test: SKIPPED, another settings test is running (%s)" % LOCK)
		quit(2)
		return
	_restore()   # a killed earlier run left its backup: put the player's settings back first
	var f := FileAccess.open(BACKUP, FileAccess.WRITE)
	f.store_buffer(FileAccess.get_file_as_bytes(CFG) if FileAccess.file_exists(CFG) else PackedByteArray())
	f.close()
	var g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	current_scene = g
	for i in 400:
		if g.main_menu and not g.get("menus_warming"):
			break
		await process_frame
	await frames(10)
	var m = g.main_menu
	g.split_screen = true
	m._press("play", null)
	m._press("to_lobby", null)
	await frames(5)
	check(m.screen == "lobby", "on the READY UP lobby (got %s)" % m.screen)
	for d in [0, 1, 2]:
		pad_button(d, JOY_BUTTON_A, true)
		await frames(2)
		pad_button(d, JOY_BUTTON_A, false)
		await frames(2)
	check(g.couch_players == 4 and m.join_pads == [0, 1, 2], "three pads joined with A (players %d, pads %s)" % [g.couch_players, m.join_pads])
	for d in [0, 1, 2]:
		pad_button(d, JOY_BUTTON_A, true)
		await frames(2)
		pad_button(d, JOY_BUTTON_A, false)
		await frames(2)
	check(m.readied[1] and m.readied[2] and m.readied[3], "each pad readied with A again")
	m.start()
	await frames(30)
	check(g.playing and g.couch_active and g.panes.size() == 4, "the match started with four panes")
	check(g.bound_pads.slice(1) == [0, 1, 2], "players 2-4 are bound to the pads they joined with (%s)" % str(g.bound_pads))
	g.prep_left = 0.0   # (the fortify barrier is mid-field; the players stand in the cellar anyway)
	await frames(30)
	# Each pad's stick moves its own player and nobody else.
	for d in [0, 1, 2]:
		var before := positions(g)
		pad_stick(d, 1.0)
		await frames(50)
		pad_stick(d, 0.0)
		await frames(10)
		var mv := moved(g, before)
		var others := true
		for k in 4:
			if k != d + 1 and mv[k] > 0.4:
				others = false
		check(mv[d + 1] > 1.5 and others, "pad %d's stick moves player %d only (moved %s)" % [d, d + 2, str(mv.map(func(x): return snappedf(x, 0.01)))])
	# The keyboard moves player 1 only.
	var before_k := positions(g)
	key(KEY_D, true)
	await frames(50)
	key(KEY_D, false)
	await frames(10)
	var mk := moved(g, before_k)
	check(mk[0] > 1.5 and mk[1] < 0.4 and mk[2] < 0.4 and mk[3] < 0.4, "the keyboard moves player 1 only (moved %s)" % str(mk.map(func(x): return snappedf(x, 0.01))))
	# A pad nobody joined with drives nobody.
	var before_x := positions(g)
	pad_stick(3, 1.0)
	await frames(50)
	pad_stick(3, 0.0)
	await frames(10)
	var mx := moved(g, before_x)
	check(mx.all(func(x): return x < 0.4), "a fourth pad nobody joined with moves nobody (moved %s)" % str(mx.map(func(x): return snappedf(x, 0.01))))
	# B (dodge) on pad 1 dodges player 3 only.
	var before_b := positions(g)
	pad_stick(1, -1.0)
	await frames(3)
	pad_button(1, JOY_BUTTON_B, true)
	await frames(3)
	pad_button(1, JOY_BUTTON_B, false)
	pad_stick(1, 0.0)
	await frames(30)
	var mb := moved(g, before_b)
	check(mb[2] > 0.5 and mb[0] < 0.4 and mb[1] < 0.4 and mb[3] < 0.4, "pad 1's B dodges player 3 only (moved %s)" % str(mb.map(func(x): return snappedf(x, 0.01))))
	g._finish(0)
	await frames(10)
	_restore()
	drop_lock()
	print("pad split test: %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)
