extends SceneTree
## Agent: Codex-faisal/ui. Real viewport state captures, not input-playtest proof.
## Requires isolated saves; CROWNS_CAPTURE_DIR chooses the output folder.
## --map=N picks a map; Moonlit (1) also needs --debug-unlock.
const Isolated = preload("res://tools/tests/isolated.gd")
var game
var out_dir := ""
var failed := false

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if not Isolated.ok("crowns_visual_capture") or DisplayServer.get_name() == "headless":
		quit(2)
		return
	out_dir = OS.get_environment("CROWNS_CAPTURE_DIR")
	if out_dir.is_empty():
		push_error("CROWNS_CAPTURE_DIR must name a capture directory")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	var deadline := Time.get_ticks_msec() + 120000
	while game.main_menu == null or game.menus_warming or is_instance_valid(game.loading_layer):
		if Time.get_ticks_msec() > deadline:
			push_error("Bounded menu load timed out")
			quit(1)
			return
		await process_frame
	game.touch_active = "--capture-touch" in OS.get_cmdline_user_args()
	game.needs_name = false
	game.name_editing = false
	game.howto_seen = true
	game.hero_name = "Player 1"
	game.main_menu.overlay = ""
	await capture("01-title")
	await press("play")
	await capture("02-map")
	# Moonlit Wildwood (--map=1) unlocks at an account level a throwaway
	# save never has: say so instead of timing out in the lobby.
	if not game.main_menu._card_open(game.main_menu.map_pick):
		push_error("The picked map is locked for this save: add --debug-unlock")
		quit(2)
		return
	await press("to_lobby")
	await capture("03-ready")
	await press("start")
	deadline = Time.get_ticks_msec() + 120000
	while not game.playing or game.player == null or is_instance_valid(game.loading_layer):
		if Time.get_ticks_msec() > deadline:
			push_error("Bounded match load timed out")
			quit(1)
			return
		await process_frame
	var phase_before: float = game.prep_left
	await create_timer(0.2).timeout
	if game.prep_left >= phase_before:
		failed = true
		push_error("Simulation clock did not advance after loading")
	await capture("04-match-spawn")
	# Explicit deterministic visual state staging, not claimed user actions.
	game.prep_left = 0.0
	game.time_left = 589.0
	await capture("05-live-battle")
	# The HUD's FPS counter averages the last second, so a capture taken a
	# few frames after the load hitch reads a few FPS. CROWNS_CAPTURE_SETTLE
	# (seconds) also takes a settled shot and prints the steady frame rate.
	var settle := float(OS.get_environment("CROWNS_CAPTURE_SETTLE"))
	if settle > 0.0:
		print("FPS at 05-live-battle: ", Engine.get_frames_per_second())
		await create_timer(settle).timeout
		print("FPS after %.1fs settle: %d" % [settle, Engine.get_frames_per_second()])
		await capture("05b-live-battle-settled")
	game.menu_open = true
	game.menu_tab = 0
	await capture("06-paused-map")
	game.menu_open = false
	game.player.set_role(game.Role.KNIGHT)
	game.player.class_banner = game.player.CLASS_BANNER_TIME - 0.5
	await capture("07-class-knight")
	# CROWNS_CAPTURE_AT="x,z;x,z;..." (claude-faisal/crowns-visual2): the
	# player is staged at each world spot in turn (the camera follows) and
	# a shot "08-at-<i>" is taken there, for map-wide visual passes.
	var spots := OS.get_environment("CROWNS_CAPTURE_AT")
	if not spots.is_empty():
		game.menu_open = false
		game.player.class_banner = 0.0
		var si := 0
		for spot in spots.split(";", false):
			var xz := spot.split(",")
			if xz.size() < 2:
				continue
			game.player.global_position = Vector3(float(xz[0]), game.player.global_position.y, float(xz[1]))
			game.player.velocity = Vector3.ZERO
			game.prep_left = 60.0   # (prep: nobody fights while the camera tours)
			for i in 40:
				await process_frame
			await capture("08-at-%d" % si)
			si += 1
	var report := FileAccess.open(out_dir.path_join("capture.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"agent": "Codex-faisal/ui", "viewport": str(root.size), "state_staging": true, "live_battle_fixture": "quiet courtyard battle-phase HUD comparison; no combat action claimed", "hit_rect_checks_pass": not failed}, "  "))
	game.queue_free()
	for i in 30:
		await process_frame
	quit(1 if failed else 0)

func press(id: String) -> void:
	# Validate current geometry and use the existing menu handler.
	var found := false
	for button in game.hud.menu_buttons:
		if button[1] == id:
			var r: Rect2 = button[0]
			found = r.size.x > 0 and r.size.y > 0 and Rect2(Vector2.ZERO, game.hud.size).encloses(r)
			break
	if not found:
		failed = true
		push_error("Missing or out-of-bounds action: " + id)
	game.main_menu._press(id, null)
	await process_frame

func capture(label: String) -> void:
	for i in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(out_dir.path_join(label + ".png"))
	if result != OK:
		failed = true
		push_error("Capture failed: " + label)
	print("CAPTURE ", label)
