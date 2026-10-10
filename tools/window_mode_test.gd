extends SceneTree
## The window keeps its mode (full screen, maximized) through a match and
## back: run with a display (not headless), e.g. under xvfb-run:
##     xvfb-run -a sh -c 'openbox & godot --path . --script tools/window_mode_test.gd'
## (a window manager is needed for "maximized" to mean anything).

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _init() -> void:
	var cfg := "user://controls.cfg"
	var saved := FileAccess.get_file_as_bytes(cfg) if FileAccess.file_exists(cfg) else PackedByteArray()
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for i in 5:
		await process_frame
	for want in ["maximized", "fullscreen"]:
		if want == "maximized":
			game.fullscreen = false
			game.apply_graphics()
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
		else:
			game.fullscreen = true
			game.apply_graphics()
			game._save_settings()
		for i in 5:
			await process_frame
		var mode := DisplayServer.window_get_mode()
		print("mode before: ", mode)
		game.main_menu._press("play", null)
		game.main_menu._press("to_lobby", null)
		game.main_menu.start()
		for i in 10:
			await process_frame
		game.apply_graphics()
		check(DisplayServer.window_get_mode() == mode, "%s survives a match start" % want)
		game.queue_free()
		for i in 2:
			await process_frame
		game = load("res://scenes/main.tscn").instantiate()   # what the end of a match does (scene reload)
		root.add_child(game)
		for i in 10:
			await process_frame
		check(DisplayServer.window_get_mode() == mode, "%s survives the reload after a match (mode %d)" % [want, DisplayServer.window_get_mode()])
	if saved.is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
	else:
		FileAccess.open(cfg, FileAccess.WRITE).store_buffer(saved)
	print("window mode: %d failure(s)" % fails)
	quit()
