extends SceneTree
## Agent: Codex-faisal. Rendered menu timings; requires throwaway saves.
const Isolated = preload("res://tools/tests/isolated.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if not Isolated.ok("menu_latency_probe"):
		quit(2)
		return
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	var capture := "--capture" in OS.get_cmdline_user_args()
	await create_timer(1.0 if capture else 20.0).timeout
	while game.menus_warming:
		await process_frame
	game.needs_name = false
	game.name_editing = false
	game.howto_seen = true
	game.main_menu.overlay = ""
	for cycle in (1 if capture else 3):
		for action in ["play", "back", "customize", "back", "store", "back", "credits", "close", "progress", "close", "play", "to_lobby", "back", "back"]:
			await create_timer(0.65 if capture else 0.35).timeout
			await RenderingServer.frame_post_draw
			var start := Time.get_ticks_usec()
			if capture:
				# Exercise the normal HUD hit-test path with its visible cursor.
				var found := false
				var target: String = "confirm" if action == "back" and game.main_menu.screen == "character" else action
				for button in game.hud.menu_buttons:
					if button[1] == target:
						game.cursor = button[0].get_center()
						game.cursor_shown = true
						game.click_latched = true
						found = true
						break
				if not found:
					push_error("Missing capture button: " + action)
					quit(1)
					return
			else:
				game.main_menu._press(action, null)
			var handler := Time.get_ticks_usec() - start
			await RenderingServer.frame_post_draw
			var shown := Time.get_ticks_usec() - start
			print("MENU_TIMING,%d,%s,%.3f,%.3f" % [cycle, action, handler / 1000.0, shown / 1000.0])
			if capture and action == "to_lobby":
				root.get_texture().get_image().save_png(OS.get_environment("CROWNS_CAPTURE_STILL"))
	quit()
