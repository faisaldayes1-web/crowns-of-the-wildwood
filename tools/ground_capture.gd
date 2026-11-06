extends SceneTree
## Agent: claude-faisal3. Ground-level passes with the live HUD: the match camera follows the player to fixed
## stations on every map, so each recapture comes from the same cameras.
##   CROWNS_CAPTURE_DIR=out tools/tests/isolated.sh --path . --resolution 1920x1080 --script tools/ground_capture.gd -- --map=N [--station=prefix]
const Isolated = preload("res://tools/tests/isolated.gd")
const STATIONS := [
	["a-spawn", Vector3(-62, 0, 0)],
	["b-west-road", Vector3(-40, 0, 0)],
	["c-crossing", Vector3(-4, 0, 0)],
	["d-east-road", Vector3(40, 0, 0)],
	["e-human-gate", Vector3(60, 0, 0)],
	["f-north-bridge", Vector3(0, 0, -20)],
	["g-south-bridge", Vector3(0, 0, 20)],
	["h-north-edge", Vector3(-20, 0, -30)],
	["i-south-edge", Vector3(20, 0, 30)],
]
var game
var output := ""

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if not Isolated.ok("ground_capture") or DisplayServer.get_name() == "headless":
		quit(2)
		return
	output = OS.get_environment("CROWNS_CAPTURE_DIR")
	if output.is_empty():
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	var only := ""
	var map_index := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--station="):
			only = arg.trim_prefix("--station=")
		if arg.begins_with("--map="):
			map_index = int(arg.trim_prefix("--map="))
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	var deadline := Time.get_ticks_msec() + 240000
	while game.main_menu == null or game.menus_warming or not game.world_ready or is_instance_valid(game.loading_layer):
		if Time.get_ticks_msec() > deadline:
			push_error("Ground load timeout")
			quit(1)
			return
		await process_frame
	game.needs_name = false
	game.name_editing = false
	game.howto_seen = true
	game.main_menu.overlay = ""
	game.map_variant = map_index
	game._start_match(0)
	while not game.playing or is_instance_valid(game.loading_layer):
		await process_frame
	for i in 120:
		await process_frame
	game.player.revive_protect = 99.0
	for st in STATIONS:
		if only != "" and not st[0].begins_with(only):
			continue
		game.player.global_position = st[1] + Vector3(0, 0.5, 0)
		game.player.velocity = Vector3.ZERO
		game.cam_pos = game.player.global_position + game.CAMERA_OFFSET * game.cam_zoom
		for i in 30:
			game.player.velocity = Vector3.ZERO
			game.player.revive_protect = 99.0
			game.toasts.clear()   # (the teleport trips "HOME DEFENSE LOST")
			await process_frame
		await RenderingServer.frame_post_draw
		var path: String = output.path_join("map%d-%s.png" % [map_index, st[0]])
		if root.get_texture().get_image().save_png(path) != OK:
			push_error("Capture failed: " + path)
			quit(1)
			return
		print("GROUND ", path)
	print("GROUND_DONE map=", map_index)
	quit()
