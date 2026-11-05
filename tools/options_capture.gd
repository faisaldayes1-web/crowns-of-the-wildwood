extends SceneTree
## Real title/pause options capture. Agent: Codex-faisal3.
## CROWNS_CAPTURE_DIR=... and isolated user-data marker required.
## -- --before uses the retained, unmodified HUD page for a matched baseline.
const Isolated = preload("res://tools/tests/isolated.gd")
var game
var out_dir := ""


func _initialize() -> void:
	call_deferred("run")


func shot(label: String) -> void:
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := out_dir.path_join(label + ".png")
	var error := root.get_texture().get_image().save_png(path)
	print("CAPTURE %s result=%d actual=%s" % [path, error, DisplayServer.window_get_size()])


func run() -> void:
	if not Isolated.ok("tools/options_capture.gd") or DisplayServer.get_name() == "headless":
		quit(2)
		return
	out_dir = OS.get_environment("CROWNS_CAPTURE_DIR")
	DirAccess.make_dir_recursive_absolute(out_dir)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	var deadline := Time.get_ticks_msec() + 180000
	while game.main_menu == null or game.menus_warming or is_instance_valid(game.loading_layer):
		if Time.get_ticks_msec() > deadline:
			quit(1)
			return
		await process_frame
	game.needs_name = false
	game.name_editing = false
	game.howto_seen = true
	game.main_menu.overlay = ""
	game.hero_name = "Player 1"
	game.menu_tab = 5
	game.menu_open = true
	game._route_options_screen()
	var screen = game.options_screen
	if "--before" in OS.get_cmdline_user_args():
		# Keep the route consumed but hide its CanvasLayer. The existing HUD
		# still draws the unchanged old page beneath it. No baseline source edit.
		screen.hide()
		await shot("before-settings")
	else:
		for tab in 5:
			screen.select_tab(tab)
			await shot("after-" + screen.TABS[tab].to_lower())
		if "--interactive" in OS.get_cmdline_user_args():
			return
	game._flush_save()
	game.free()
	for i in 4:
		await process_frame
	quit(0)
