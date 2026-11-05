extends SceneTree
## Real title/pause options capture. Agent: Codex-faisal3.
## CROWNS_CAPTURE_DIR=... and isolated user-data marker required.
## -- --before uses the retained, unmodified HUD page for a matched baseline.
const Isolated = preload("res://tools/tests/isolated.gd")
var game
var out_dir := ""
var capture_view: Viewport


func _initialize() -> void:
	call_deferred("run")


func shot(label: String) -> void:
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := out_dir.path_join(label + ".png")
	var pixels := capture_view.get_texture().get_image()
	var error := pixels.save_png(path)
	print("CAPTURE %s result=%d pixels=%s native_window=%s" % [path, error, pixels.get_size(), DisplayServer.window_get_size()])
	if error != OK:
		push_error("Could not save capture: " + path)
		quit(1)


func run() -> void:
	if not Isolated.ok("tools/options_capture.gd") or DisplayServer.get_name() == "headless":
		quit(2)
		return
	out_dir = OS.get_environment("CROWNS_CAPTURE_DIR")
	DirAccess.make_dir_recursive_absolute(out_dir)
	capture_view = root
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--canvas="):
			var parts := arg.trim_prefix("--canvas=").split("x")
			var canvas := SubViewport.new()
			canvas.size = Vector2i(int(parts[0]), int(parts[1]))
			canvas.size_2d_override = Vector2i(1280, 720)
			canvas.size_2d_override_stretch = true
			canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			root.add_child(canvas)
			capture_view = canvas
	game = load("res://scenes/main.tscn").instantiate()
	capture_view.add_child(game)
	current_scene = game
	var deadline := Time.get_ticks_msec() + 180000
	while game.main_menu == null or game.menus_warming or not game.world_ready or is_instance_valid(game.loading_layer):
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
	current_scene = null
	game.queue_free()
	for i in 60:
		await process_frame
	quit(0)
