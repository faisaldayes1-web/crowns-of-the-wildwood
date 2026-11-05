extends SceneTree
## A split-screen player's gamepad drops mid-match (hot-plug): the match
## pauses so they can plug it back in, a replug keeps the same player bound
## to the same device, and player 2's pad dropping does not flip player 1's
## button hints to keys. Simulated with Input.joy_connection_changed.
##     tools/tests/isolated.sh --headless --path . --script tools/pad_unplug_test.gd
## Runs only in a throwaway user dir (it plays a match and saves settings).
## claude-faisal3 2026-11-04.

const Isolated = preload("res://tools/tests/isolated.gd")

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


func _init() -> void:
	if not Isolated.ok("tools/pad_unplug_test.gd"):
		quit(2)
		return
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
	for d in [0, 1]:
		pad_button(d, JOY_BUTTON_A, true)
		await frames(2)
		pad_button(d, JOY_BUTTON_A, false)
		await frames(2)
	for d in [0, 1]:
		pad_button(d, JOY_BUTTON_A, true)
		await frames(2)
		pad_button(d, JOY_BUTTON_A, false)
		await frames(2)
	m.start()
	await frames(30)
	check(g.playing and g.couch_players == 3, "a three-player split-screen match is running (players %d)" % g.couch_players)
	var bound_before: Array = g.bound_pads.duplicate()
	g.pad_active = true
	check(not g.menu_open and not paused, "not paused before the unplug")
	# Player 2's pad (device 0) drops: pause, and player 1's hints stay on the pad.
	Input.joy_connection_changed.emit(0, false)
	await frames(3)
	check(g.menu_open and paused, "the match pauses when a split-screen player's pad drops")
	check(g.pad_active, "player 1's pad hints survive player 2's pad dropping")
	# Replug: same device id, same player, still bound.
	Input.joy_connection_changed.emit(0, true)
	await frames(3)
	check(g.bound_pads == bound_before, "the replugged pad is still bound to its player (%s)" % str(g.bound_pads))
	# Resume, then a pad nobody holds drops: no pause.
	g.menu_open = false
	paused = false
	await frames(3)
	Input.joy_connection_changed.emit(7, false)
	await frames(3)
	check(not g.menu_open and not paused, "an unbound pad dropping does not pause the match")
	g._finish(0)
	await frames(10)
	print("pad unplug test: %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)
