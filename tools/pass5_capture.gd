extends SceneTree
## Agent: Codex-faisal. Native selected spawn camera, no generated artwork.
const Isolated = preload("res://tools/tests/isolated.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if not Isolated.ok("pass5_capture") or DisplayServer.get_name() == "headless":
		quit(2)
		return
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	var deadline := Time.get_ticks_msec() + 240000
	while not game.playing or game.player == null or is_instance_valid(game.loading_layer):
		if Time.get_ticks_msec() > deadline:
			push_error("Pass 5 match load timed out")
			quit(1)
			return
		await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	for unit in game.units:
		unit.set_process(false)
		unit.set_physics_process(false)
	game.prep_left = 15.0
	game.chat_visible = false
	game.hud.queue_redraw()
	for i in 2:
		await process_frame
	await RenderingServer.frame_post_draw
	var out := OS.get_environment("CROWNS_CAPTURE_DIR")
	DirAccess.make_dir_recursive_absolute(out)
	root.get_texture().get_image().save_png(out.path_join("spawn.png"))
	print("Pass 5 native spawn captured")
	game.queue_free()
	await process_frame
	await process_frame
	quit()
