extends SceneTree

const Isolated = preload("res://tools/tests/isolated.gd")
## Pad hot-plug (Faisal 11-05): player 1 keeps working on either device while a
## controller is plugged or pulled, in the menu and in a match. SIMULATED:
## joypad events and game._on_pad_changed(), no real pad. Run:
##     tools/tests/isolated.sh --headless --path . --script tools/hotplug_test.gd

var fails := 0
var game
var p


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func frames(n: int = 2) -> void:
	for i in n:
		await physics_frame


func _key(code: int, down: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = down
	Input.parse_input_event(e)
	if down:
		game.menu_input(e)


func _stick(axis: int, v: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.device = 0
	e.axis = axis
	e.axis_value = v
	Input.parse_input_event(e)
	game.menu_input(e)   # the game's own device tracking sees it as it would in play


func _walk_dist(secs: int = 20) -> float:
	var from: Vector3 = p.global_position
	await frames(secs)
	return from.distance_to(p.global_position)


func _init() -> void:
	if not Isolated.ok("tools/hotplug_test.gd"):
		quit(2)
		return
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await frames(5)
	# Plugging a pad in the menu changes nothing on screen state.
	game._on_pad_changed(0, true)
	check(not game.playing, "a pad plugged in at the title does not start anything")
	var m = game.main_menu
	m._press("play", null)
	m._press("team_size", 1)
	m._press("to_lobby", null)
	m.start()
	var waited := 0
	while not game.playing and waited < 3000:
		await physics_frame
		waited += 1
	await frames(60)
	p = game.player
	game.pc_movement = "wasd"
	for u in game.units:
		if u != p:
			u.process_mode = Node.PROCESS_MODE_DISABLED
	p.global_position = Vector3(-14, 0.1, 0)
	p.has_mouse = true
	game.pad_active = false
	await frames(10)

	# 1. Keyboard drives P1 before any pad exists.
	_key(KEY_D, true)
	check(await _walk_dist() > 0.5, "keyboard D walks the hero")
	_key(KEY_D, false)
	await frames(10)

	# 2. A pad is plugged in mid-match while D is held: no latched input remains.
	_key(KEY_D, true)
	await frames(5)
	game._on_pad_changed(0, true)
	_key(KEY_D, false)
	await frames(20)
	var rest: float = await _walk_dist(30)
	check(rest < 0.05, "after plug-in and key release the hero stands still (moved %.2f)" % rest)

	# 3. The pad's stick drives P1 once it is pushed; the hints follow it.
	p.global_position = Vector3(-14, 0.1, 0)
	_stick(JOY_AXIS_LEFT_X, 1.0)
	check(game.pad_active, "pushing the stick makes the pad the active device")
	check(await _walk_dist() > 0.5, "the stick walks the hero")
	_stick(JOY_AXIS_LEFT_X, 0.0)
	await frames(20)

	# 4. Keyboard works again at once without any mode switch (no pad press needed).
	_key(KEY_D, true)
	check(not game.pad_active, "a key press hands control back to the keyboard")
	check(await _walk_dist() > 0.5, "keyboard walks again with the pad still plugged in")
	_key(KEY_D, false)
	await frames(10)

	# 5. The pad is pulled while its stick is held: nothing keeps walking.
	_stick(JOY_AXIS_LEFT_X, 1.0)
	await frames(5)
	game._on_pad_changed(0, false)
	_stick(JOY_AXIS_LEFT_X, 0.0)
	await frames(20)
	var drift: float = await _walk_dist(30)
	check(drift < 0.05, "after the pad is unplugged mid-push the hero stands still (moved %.2f)" % drift)
	check(not game.pad_active, "unplugging the active pad falls back to keyboard hints")

	# 6. Keyboard and mouse still fully work after the unplug.
	_key(KEY_A, true)
	check(await _walk_dist() > 0.5, "keyboard still walks after the unplug")
	_key(KEY_A, false)
	print("HOTPLUG TEST: %d failed" % fails)
	quit(fails)
