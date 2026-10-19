extends SceneTree
## Agent: Codex-faisal. All 20 directed map transitions, including rendered
## scene construction, menu warm-up and next frames. Disposable saves only.
const Isolated = preload("res://tools/tests/isolated.gd")
const CARD = {0: 0, 1: 1, 2: 3, 3: 2, 4: 4}
var worst_frame := 0
var last_frame := 0
var measuring := false
var capture_dir := ""
var capture_start := 0
var capture_last := 0
var capture_rows: Array = []

func capture_frame() -> void:
	if capture_dir == "": return
	var now := Time.get_ticks_usec()
	if now - capture_last < 100000: return
	capture_last = now
	var frame := root.get_texture().get_image()
	frame.resize(768, 432, Image.INTERPOLATE_LANCZOS)
	var name := "%05d.jpg" % capture_rows.size()
	frame.save_jpg(capture_dir.path_join(name), 0.85)
	capture_rows.append([name, (now-capture_start)/1000.0])

func _initialize() -> void:
	process_frame.connect(func():
		var now := Time.get_ticks_usec()
		if measuring: worst_frame = maxi(worst_frame, now - last_frame)
		if measuring and now - last_frame > 100000 and "--map-profile" in OS.get_cmdline_user_args():
			print("FRAME_CHUNK ", (now-last_frame)/1000.0, " world=", current_scene.get("_stream_world") if current_scene else "reload", " menu=", current_scene.main_menu != null if current_scene else false)
		last_frame = now)
	call_deferred("run")

func settle() -> void:
	var deadline := Time.get_ticks_msec() + 120000
	for i in 3: await process_frame
	while current_scene == null or current_scene.main_menu == null or current_scene.menus_warming:
		if Time.get_ticks_msec() > deadline:
			push_error("Map did not become ready within 120 seconds")
			quit(1)
			return
		await process_frame
	for i in 3: await process_frame

func run() -> void:
	if not Isolated.ok("map_latency_probe"):
		quit(2)
		return
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await settle()
	var targets := [1,2,3,4,0,2,4,1,3,0,3,1,4,2,0,4,3,2,1,0]
	if "--map-profile" in OS.get_cmdline_user_args(): targets = [2,3]
	var capture := "--capture-maps" in OS.get_cmdline_user_args()
	if capture:
		targets = [1,2,3,4,0]
		await create_timer(2.0).timeout
		game.main_menu.go("map")
		capture_dir = OS.get_environment("CROWNS_CAPTURE_DIR")
		if capture_dir == "": quit(2); return
		DirAccess.make_dir_recursive_absolute(capture_dir)
		capture_start = Time.get_ticks_usec()
		RenderingServer.frame_post_draw.connect(capture_frame)
		await create_timer(1.0).timeout
	for target in targets:
		game = current_scene
		game.needs_name = false
		game.name_editing = false
		game.main_menu.go("map")
		await process_frame
		var source: int = game.map_variant
		worst_frame = 0
		last_frame = Time.get_ticks_usec()
		var start := last_frame
		measuring = true
		if capture:
			var clicked := false
			for button in game.hud.menu_buttons:
				if button[1] == "map_card" and button[2] == CARD[target]:
					game.cursor_shown = true
					game.cursor = button[0].get_center()
					game.click_latched = true
					clicked = true
					break
			if not clicked: push_error("Map card hit target missing"); quit(1); return
		else:
			game.main_menu._press("map_card", CARD[target])
		await settle()
		measuring = false
		game = current_scene
		var correct: bool = game.map_variant == target and game.main_menu.screen == "map" and (game.vmap != null) == (target == 2)
		print("MAP_TIMING,%d,%d,%.3f,%.3f,%s" % [source,target,(Time.get_ticks_usec()-start)/1000.0,worst_frame/1000.0,correct])
		if not correct:
			quit(1)
			return
		if capture: await create_timer(2.5).timeout
	print("MAP_PAIRS_PASS ", targets.size())
	if capture:
		var metadata := FileAccess.open(capture_dir.path_join("frames.json"), FileAccess.WRITE)
		metadata.store_string(JSON.stringify(capture_rows))
		metadata.close()
		capture_dir = ""
	current_scene.queue_free()
	current_scene = null
	for i in 4: await process_frame
	quit()
