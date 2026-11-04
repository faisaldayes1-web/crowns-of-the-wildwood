extends SceneTree
## Agent: claude-faisal3. Oblique and overview stills of a real map, for polish before/after shots.
## Run through tools/tests/isolated.sh with a window (not --headless):
##   CROWNS_CAPTURE_DIR=out godot --path . --resolution 1600x900 --script tools/map_survey_capture.gd -- --map=4
## Units are frozen and hidden; fog and tilt shift stay on so the shots show what a player sees.
const Isolated = preload("res://tools/tests/isolated.gd")
# [label, camera position, look-at target]
const SHOTS := [
	["a-top", Vector3(0, 150, 1), Vector3(0, 0, 0)],
	["b-road-west", Vector3(-30, 7, 9), Vector3(-45, 0, 0)],
	["c-road-mid", Vector3(-8, 6, 8), Vector3(8, 0, 0)],
	["d-road-east", Vector3(30, 7, 9), Vector3(45, 0, 0)],
	["e-north-bridge", Vector3(-6, 8, -9), Vector3(0, 0, -20)],
	["f-south-bridge", Vector3(6, 8, 9), Vector3(0, 0, 20)],
	["g-elf-gate", Vector3(-50, 7, 8), Vector3(-62, 1, 0)],
	["h-human-gate", Vector3(50, 7, 8), Vector3(62, 1, 0)],
	["i-low-road", Vector3(-20, 1.8, 2), Vector3(0, 0.5, 0)],
	# The match camera (CAMERA_OFFSET, fov 40) over the crossing and a gate; j- keeps the fortify barrier, k- drops it.
	["j-game-barrier", Vector3(-4, 19, 16), Vector3(-4, 0, 0)],
	["k-game-clear", Vector3(-4, 19, 16), Vector3(-4, 0, 0)],
	["l-game-bridge", Vector3(0, 19, 36), Vector3(0, 0, 20)],
	["m-game-gate", Vector3(-52, 19, 16), Vector3(-52, 0, 0)],
]
var game
var output := ""

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if not Isolated.ok("map_survey_capture") or DisplayServer.get_name() == "headless":
		quit(2)
		return
	output = OS.get_environment("CROWNS_CAPTURE_DIR")
	if output.is_empty():
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	var deadline := Time.get_ticks_msec() + 240000
	while game.main_menu == null or game.menus_warming or not game.world_ready or is_instance_valid(game.loading_layer):
		if Time.get_ticks_msec() > deadline:
			push_error("Survey load timeout")
			quit(1)
			return
		await process_frame
	game.needs_name = false
	game.name_editing = false
	game.howto_seen = true
	game.main_menu.overlay = ""
	game._start_match(0)
	while not game.playing or is_instance_valid(game.loading_layer):
		await process_frame
	game.process_mode = Node.PROCESS_MODE_DISABLED
	for actor in game.units + game.monarchs + game.guides + game.blessings + game.turrets:
		if is_instance_valid(actor) and actor is Node3D:
			actor.hide()
	for layer in root.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	for label in root.find_children("*", "Label3D", true, false):
		label.visible = false
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.far = 1000.0
	cam.fov = 60.0
	cam.make_current()
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			only = arg.trim_prefix("--shot=")
	for shot in SHOTS:
		if only != "" and not shot[0].begins_with(only):
			continue
		cam.position = shot[1]
		cam.fov = 40.0 if shot[0][0] in "jklm" else 60.0
		if is_instance_valid(game.barrier):
			game.barrier.visible = shot[0][0] != "k" and shot[0][0] != "l" and shot[0][0] != "m"
		cam.look_at(shot[2], Vector3.UP if shot[0] != "a-top" else Vector3(0, 0, -1))
		for i in 6:
			await process_frame
		await RenderingServer.frame_post_draw
		var path: String = output.path_join("map%d-%s.png" % [game.map_variant, shot[0]])
		if root.get_texture().get_image().save_png(path) != OK:
			push_error("Capture failed: " + path)
			quit(1)
			return
		print("CAPTURE ", path)
	print("SURVEY_DONE map=", game.map_variant)
	quit()
