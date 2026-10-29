extends SceneTree
# Agent: Codex-faisal. External diagnostic for exact exported before/after packs.
func _init() -> void:
	call_deferred("_run")
func frames(n: int) -> void:
	for i in n:
		await process_frame
func _run() -> void:
	var base := OS.get_environment("CROWNS_TEST_USER_BASE").replace("\\", "/")
	if base == "" or not OS.get_user_data_dir().replace("\\", "/").begins_with(base + "/"):
		quit(2)
		return
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await frames(20)
	while game.menus_warming:
		await process_frame
	game.main_menu._press("play", null)
	game.main_menu._press("to_lobby", null)
	game.main_menu.add_player(3)
	game.main_menu._press("readied", 1)
	game.main_menu.start()
	await frames(60)
	var deadline := Time.get_ticks_msec() + 120000
	while is_instance_valid(game.loading_layer) and Time.get_ticks_msec() < deadline:
		await process_frame
	if not game.couch_active or game.panes.size() != 2 or is_instance_valid(game.loading_layer):
		print("FAIL two-seat playable scene")
		quit(3)
		return
	var first: Vector3 = game.locals[0].global_position
	var second: Vector3 = game.locals[1].global_position
	game.sfx.set_listener(first)
	for voice in game.sfx.pool_3d:
		voice.stop()
	game.sfx._last.clear()
	game.sfx.play("arrow_hit", second, 0.0, 0.0)
	var active: int = game.sfx.pool_3d.filter(func(voice): return voice.playing).size()
	print("PACK_AUDIO seats=",game.panes.size()," distance=",first.distance_to(second)," p2_impact_voices=",active)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var destination := OS.get_environment("CROWNS_CAPTURE_STILL")
		var result := root.get_texture().get_image().save_png(destination)
		print("CAPTURE ",destination," result=",result)
	game._flush_save()
	game.queue_free()
	current_scene = null
	await frames(4)
	quit(0)
