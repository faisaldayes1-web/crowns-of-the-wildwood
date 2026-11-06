extends SceneTree
## Agent: claude-faisal3 (cf-crowns-next-1106d). A WINDOWED match for a person to plug/unplug a real gamepad
## (DualSense / Edge) in. Logs every connection event, button press (with the glyph set the HUD would show)
## and pulses rumble when a pad appears. Run from the repo root:
##   CROWNS_PAD_LOG=C:/Temp/padlog.txt tools/tests/isolated.sh --path . --script tools/hotplug_live.gd -- --seconds=600
## Keys: R = rumble pulse on every pad, Shift+Esc = quit. The log is flushed per line.
const Isolated = preload("res://tools/tests/isolated.gd")
var game
var log_file: FileAccess
var t0 := 0.0


func _initialize() -> void:
	call_deferred("run")


func note(s: String) -> void:
	var line := "[%7.2f] %s" % [(Time.get_ticks_msec() / 1000.0) - t0, s]
	print(line)
	if log_file != null:
		log_file.store_line(line)
		log_file.flush()


func describe(d: int) -> String:
	return "device %d name='%s' guid=%s known=%s kind=%s title='%s'" % [d, Input.get_joy_name(d), Input.get_joy_guid(d),
		Input.is_joy_known(d), game.pad_kind(d), game.pad_title(d)]


func run() -> void:
	if not Isolated.ok("hotplug_live") or DisplayServer.get_name() == "headless":
		quit(2)
		return
	var path := OS.get_environment("CROWNS_PAD_LOG")
	if path == "":
		path = "user://padlog.txt"
	log_file = FileAccess.open(path, FileAccess.WRITE)
	var seconds := 600.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seconds="):
			seconds = float(a.trim_prefix("--seconds="))
	t0 = Time.get_ticks_msec() / 1000.0
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	note("log file: %s" % ProjectSettings.globalize_path(path) if path.begins_with("user://") else "log file: %s" % path)
	Input.joy_connection_changed.connect(func(d: int, c: bool) -> void:
		note("%s %s" % ["CONNECTED" if c else "DISCONNECTED", describe(d) if c else "device %d" % d])
		if c:
			game.rumble_pad(d, 0.6, 0.6, 0.5)
			note("  rumble pulse sent to %d" % d)
		note("  pads now: %s | pad_active=%s" % [str(Input.get_connected_joypads()), game.pad_active]))
	for d in Input.get_connected_joypads():
		note("ALREADY CONNECTED " + describe(d))
	note("Start a match (menu), then plug / unplug the pad. R = rumble, Shift+Esc = quit.")
	var waited := 0.0
	while waited < seconds:
		await process_frame
		waited += 1.0 / 60.0
	note("time up")
	quit(0)


func _input(e: InputEvent) -> void:
	if log_file == null:
		return
	if e is InputEventJoypadButton and e.pressed:
		note("BUTTON %d on device %d (%s) glyph kind=%s, game.pad_active=%s" % [e.button_index, e.device, Input.get_joy_name(e.device), game.pad_kind(e.device), game.pad_active])
	elif e is InputEventJoypadMotion and absf(e.axis_value) > 0.9:
		note("AXIS %d=%.2f on device %d" % [e.axis, e.axis_value, e.device])
	elif e is InputEventKey and e.pressed and not e.echo:
		if e.keycode == KEY_R:
			for d in Input.get_connected_joypads():
				game.rumble_pad(d, 1.0, 1.0, 0.6)
				note("manual rumble on %d" % d)
		elif e.keycode == KEY_ESCAPE and Input.is_key_pressed(KEY_SHIFT):
			note("quit")
			quit(0)
