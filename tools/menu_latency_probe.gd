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
	var actions: Array = [["play", null], ["back", null], ["customize", null], ["back", null], ["store", null], ["back", null], ["credits", null], ["close", null], ["progress", null], ["close", null], ["play", null], ["to_lobby", null], ["back", null], ["back", null]]
	if capture:
		actions = [["play", null], ["back", null], ["customize", null], ["char_tab", 5], ["back", null], ["store", null], ["store_tab", 2], ["store_tab", 4], ["back", null], ["online", null], ["back", null], ["credits", null], ["close", null], ["progress", null], ["close", null], ["play", null], ["to_lobby", null], ["back", null], ["back", null]]
	if "--all-menus" in OS.get_cmdline_user_args():
		actions = [["play", null], ["back", null], ["customize", null]]
		for i in 6: actions.append(["char_tab", i])
		actions.append_array([["back", null], ["store", null]])
		for i in game.main_menu.store.TABS.size(): actions.append(["store_tab", i])
		actions.append_array([["back", null], ["online", null], ["back", null], ["tutorial", null], ["howto_step", 1], ["howto_more", null]])
		for i in game.Guide.TOPICS.size(): actions.append(["topic", i])
		actions.append_array([["close", null], ["credits", null], ["close", null], ["progress", null], ["close", null], ["players", null], ["close", null], ["settings", null]])
		for i in game.menu_tabs(): actions.append(["probe_options", i])
		actions.append_array([["probe_close_options", null], ["play", null], ["to_lobby", null], ["back", null], ["back", null]])
	print("PROBE_VIEWPORT ", root.size)
	for cycle in (1 if capture else 3):
		for entry in actions:
			var action: String = entry[0]
			var arg = entry[1]
			await create_timer(0.65 if capture else 0.35).timeout
			await RenderingServer.frame_post_draw
			var start := Time.get_ticks_usec()
			if capture:
				# Exercise the normal HUD hit-test path with its visible cursor.
				var found := false
				var target: String = "confirm" if action == "back" and game.main_menu.screen == "character" else action
				for button in game.hud.menu_buttons:
					if button[1] == target and (arg == null or button[2] == arg):
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
				if action == "probe_options": game.menu_tab = arg
				elif action == "probe_close_options": game.menu_open = false
				else: game.main_menu._press(action, arg)
			var handler := Time.get_ticks_usec() - start
			await RenderingServer.frame_post_draw
			var shown := Time.get_ticks_usec() - start
			print("MENU_TIMING,%d,%s,%.3f,%.3f" % [cycle, action + ("_" + str(arg) if arg != null else ""), handler / 1000.0, shown / 1000.0])
			if capture and action == "to_lobby":
				root.get_texture().get_image().save_png(OS.get_environment("CROWNS_CAPTURE_STILL"))
	quit()
