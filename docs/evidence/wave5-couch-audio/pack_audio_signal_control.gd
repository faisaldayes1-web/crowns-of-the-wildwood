extends SceneTree
# Agent: Codex-faisal. External diagnostic for exact exported before/after packs.
func _init() -> void:
	call_deferred("_run")
func frames(n: int) -> void:
	for i in n:
		await process_frame
func sample_event(sound, capture: AudioEffectCapture, pos: Vector3) -> float:
	for voice in sound.pool_3d:
		voice.stop()
	await create_timer(0.2).timeout
	capture.clear_buffer()
	sound._last.clear()
	sound.play("arrow_hit", pos, 0.0, 0.0)
	await create_timer(0.3).timeout
	var peak := 0.0
	for sample in capture.get_buffer(capture.get_frames_available()):
		peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
	return peak
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
	game.set_process(false)
	for unit in game.units:
		unit.set_physics_process(false)
		unit.set_process(false)
	game.sfx.ambience.stop()
	game.sfx.music.stop()
	game.sfx.battle.stop()
	game.sfx.sting_player.stop()
	for voice in game.sfx.pool_ui:
		voice.stop()
	var capture := AudioEffectCapture.new()
	capture.buffer_length = 1.0
	AudioServer.add_bus_effect(AudioServer.get_bus_index("SFX"), capture)
	for voice in game.sfx.pool_3d:
		voice.stop()
	await create_timer(0.3).timeout
	capture.clear_buffer()
	game.sfx._last.clear()
	game.sfx.play("arrow_hit", second, 0.0, 0.0)
	var active: int = game.sfx.pool_3d.filter(func(voice): return voice.playing).size()
	print("PACK_AUDIO seats=",game.panes.size()," distance=",first.distance_to(second)," p2_impact_voices=",active)
	await create_timer(0.3).timeout
	var count := capture.get_frames_available()
	var buffer := capture.get_buffer(count)
	var peak := 0.0
	for sample in buffer:
		peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
	print("MIX_SIGNAL frames=",count," peak=",peak," active_voices=",active)
	paused = false
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var destination := OS.get_environment("CROWNS_CAPTURE_STILL")
		var result := root.get_texture().get_image().save_png(destination)
		print("CAPTURE ",destination," result=",result)
	for voice in game.sfx.pool_3d:
		voice.stop()
	capture.clear_buffer()
	game.sfx.ui("arrow_hit",0.0,1.0)
	await create_timer(0.3).timeout
	var control := capture.get_buffer(capture.get_frames_available())
	var control_peak := 0.0
	for sample in control:
		control_peak=maxf(control_peak,maxf(absf(sample.x),absf(sample.y)))
	print("UI_CONTROL peak=",control_peak," root_listener=",root.audio_listener_enable_3d," camera=",root.get_camera_3d())
	var p1_peak := await sample_event(game.sfx, capture, first)
	var far_peak := await sample_event(game.sfx, capture, Vector3(2000, 0, 2000))
	game.sfx.enabled = false
	var muted_peak := await sample_event(game.sfx, capture, second)
	game.sfx.enabled = true
	game.couch_active = false
	game.camera.current = true
	game.sfx.set_listener(first)
	var solo_peak := await sample_event(game.sfx, capture, first)
	game.camera.current = false
	game.couch_active = true
	game.sfx.set_listener(first)
	var restored_peak := await sample_event(game.sfx, capture, second)
	print("SIGNAL_GATES p1=", p1_peak, " p2=", peak, " far=", far_peak, " muted=", muted_peak, " solo=", solo_peak, " restored=", restored_peak)
	var expected_fixed := OS.get_environment("CROWNS_EXPECT_FIXED") == "1"
	var ok := control_peak > 0.01 and solo_peak > 0.01 and far_peak < 0.0001 and muted_peak < 0.0001
	if expected_fixed:
		ok = ok and p1_peak > 0.01 and peak > 0.01 and restored_peak > 0.01
	else:
		ok = ok and p1_peak < 0.0001 and peak < 0.0001 and restored_peak < 0.0001
	print("PASS SIGNAL_GATES" if ok else "FAIL SIGNAL_GATES")
	game._flush_save()
	game.queue_free()
	current_scene = null
	await frames(4)
	quit(0 if ok else 1)
