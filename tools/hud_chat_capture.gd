extends SceneTree
## Agent: Codex-faisal. Real game render with staged busy-chat/full-cargo state.
const Isolated = preload("res://tools/tests/isolated.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if not Isolated.ok("hud_chat_capture") or DisplayServer.get_name() == "headless":
		quit(2)
		return
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	var deadline := Time.get_ticks_msec() + 240000
	while not game.playing or game.player == null or is_instance_valid(game.loading_layer):
		if Time.get_ticks_msec() > deadline:
			push_error("HUD capture match load timed out")
			quit(1)
			return
		await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	for unit in game.units:
		unit.set_process(false)
		unit.set_physics_process(false)
	game.prep_left = 0.0
	game.time_left = 520.0
	game.rosters_visible = false
	game.chat_visible = true
	game.economy.cargo[game.player] = {"wood": game.Stats.ECONOMY.carry_max, "ore": 0}
	game.chat_log.clear()
	for i in 12:
		game.chat_system("Battle update %d: defend the castle and bring supplies home." % i)
	game.kill_feed.clear()
	for i in 5:
		game.kill_feed.append({"killer": "Elven Knight", "kteam": 0, "krole": 0,
			"victim": "Human Ranger", "vteam": 1, "vrole": 1, "time": Time.get_ticks_msec() / 1000.0})
	game.hud.queue_redraw()
	for i in 12:
		# A background capture can render slowly on a shared GPU. Keep the
		# staged recent events alive rather than photographing expired rows.
		for message in game.chat_log:
			message.time = Time.get_ticks_msec() / 1000.0
		for message in game.kill_feed:
			message.time = Time.get_ticks_msec() / 1000.0 - 0.5
		game.hud.queue_redraw()
		await process_frame
	await RenderingServer.frame_post_draw
	var out := OS.get_environment("CROWNS_CAPTURE_DIR")
	DirAccess.make_dir_recursive_absolute(out)
	root.get_texture().get_image().save_png(out.path_join("busy-chat.png"))
	game.chat_open = true
	game.hud.queue_redraw()
	for i in 3:
		for message in game.kill_feed:
			message.time = Time.get_ticks_msec() / 1000.0 - 0.5
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join("typing-chat.png"))
	print("HUD chat capture: complete (staged state, not input playtest)")
	quit()
