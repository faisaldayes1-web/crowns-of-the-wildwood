extends SceneTree
## Agent: Codex-faisal. Changed-source desktop art/layout regression, NOT a player journey.
const Isolated = preload("res://tools/tests/isolated.gd")
var game
var out_dir := ""
var began := 0
var done := false
var original := {}
var shots: Array = []

func _initialize() -> void:
	began = Time.get_ticks_msec()
	call_deferred("run")

func run() -> void:
	if not Isolated.ok("Codex-faisal-daylight-compare") or DisplayServer.get_name() == "headless":
		finish(2, "isolation/render guard")
		return
	out_dir = OS.get_environment("CROWNS_CAPTURE_DIR")
	if out_dir.is_empty():
		finish(2, "missing capture directory")
		return
	seed(7)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while game.main_menu == null or game.menus_warming or is_instance_valid(game.loading_layer):
		await process_frame
		if done: return
	game.touch_active = false
	game.needs_name = false
	game.name_editing = false
	game.howto_seen = true
	game.hero_name = "Player 1"
	game.main_menu.overlay = ""
	for action in ["play", "to_lobby", "start"]:
		game.main_menu._press(action, null)
		await frames(5)
	while not game.playing or game.player == null or is_instance_valid(game.loading_layer):
		await process_frame
		if done: return
	await frames(10)
	if not is_instance_valid(game.fill_light):
		finish(1, "expected actual fill light missing")
		return
	# Pause ordinary simulation after normal menu handlers finish loading.
	# Renderer shader TIME may still advance: this is not pixel-identical perf.
	paused = true
	if not variant_and_layout_checks():
		finish(1, "variant/layout regression")
		return
	await capture("01-day-desktop")
	if done: return
	root.size = Vector2i(1440, 810)
	await frames(10)
	await capture("02-day-wide")
	if done: return
	root.size = Vector2i(960, 540)
	await frames(10)
	await capture("03-day-compact")
	if done: return
	paused = false
	game._flush_save()
	game.queue_free()
	await frames(30)
	finish(0, "THREE_CHANGED_SOURCE_LAYOUT_FRAMES_REQUIRE_VISUAL_REVIEW")

func grade() -> Dictionary:
	var values := {}
	for key in ["ambient_light_energy", "ambient_light_color", "ambient_light_sky_contribution", "adjustment_enabled", "ssao_enabled", "ambient_light_source", "adjustment_saturation", "adjustment_contrast", "adjustment_brightness", "ssao_radius", "ssao_intensity", "ssao_power"]:
		values[key] = game.world_environment.get(key)
	return {"environment": values, "sun_color": game.sun_light.light_color, "sun_energy": game.sun_light.light_energy, "fill_energy": game.fill_light.light_energy if game.fill_light else -1.0}

func capture(label: String) -> void:
	await frames(5)
	await RenderingServer.frame_post_draw
	var path := out_dir.path_join(label + ".png")
	if FileAccess.file_exists(path) or root.get_texture().get_image().save_png(path) != OK:
		finish(1, "capture failed")
		return
	var snapshot := {"transform": str(game.camera.global_transform), "projection": game.camera.projection, "fov":game.camera.fov, "size":game.camera.size, "near":game.camera.near,"far":game.camera.far,"time_left":game.time_left,"prep_left":game.prep_left,"player_position":str(game.player.global_position)}
	var item := {"label": label, "sha256": FileAccess.get_sha256(path), "camera": snapshot, "grade": grade(), "simulation_paused": paused, "viewport": str(root.size)}
	shots.append(item)
	print("C1_DAYLIGHT_CAPTURE " + JSON.stringify(item))

func frames(count: int) -> void:
	for i in count:
		await process_frame
		if done: return

func _process(_delta: float) -> bool:
	if not done and Time.get_ticks_msec() - began > 105000:
		finish(1, "bounded deadline")
	return false

func finish(code: int, reason: String) -> void:
	if done: return
	done = true
	print("C1_DAYLIGHT_TERMINAL " + JSON.stringify({"exit":code,"reason":reason,"shots":shots,"pid":OS.get_process_id(),"limits":"Staged same-camera daylight art experiment, not gameplay/performance/material qualification"}))
	quit(code)

func variant_and_layout_checks() -> bool:
	var style: Variant = load("res://scripts/visual/style_profile.gd")
	var probe: Variant = load("res://scripts/game.gd").new()
	probe.world_environment = Environment.new()
	probe.sun_light = DirectionalLight3D.new()
	probe.fill_light = DirectionalLight3D.new()
	probe.account_xp = 100000000
	probe.map_variant = 0
	probe._style_light()
	var ok: bool = is_equal_approx(probe.world_environment.ssao_intensity, style.DAY.ao_intensity) and is_equal_approx(probe.sun_light.light_energy, style.DAY.sun_energy)
	probe.map_variant = 1
	probe._style_light()
	ok = ok and probe.night() and is_equal_approx(probe.world_environment.ssao_intensity, 3.2) and is_equal_approx(probe.sun_light.light_energy, style.NIGHT.sun_energy)
	probe.map_variant = 0
	probe._style_light()
	probe.season = "winter"
	probe._style_light()
	ok = ok and is_equal_approx(probe.world_environment.ssao_intensity, 3.2)
	probe.season = ""
	probe._style_light()
	var ember := Node3D.new()
	probe.vmap = ember
	probe._style_light()
	ok = ok and is_equal_approx(probe.world_environment.ssao_intensity, 3.2) and is_equal_approx(probe.world_environment.ambient_light_energy, style.EMBER.ambient_energy)
	probe.vmap = null
	ember.free()
	probe._style_light()
	ok = ok and is_equal_approx(probe.world_environment.ssao_radius, style.DAY.ao_radius) and is_equal_approx(probe.world_environment.ssao_power, style.DAY.ao_power)
	probe.sun_light.free()
	probe.fill_light.free()
	probe.free()
	var hud: Variant = load("res://scripts/hud.gd").new()
	var cases := [[640, false], [960, false], [1140, true], [1179, true], [1180, false], [1280, false], [1920, false]]
	for pair in cases:
		hud.size = Vector2(pair[0], 720)
		ok = ok and hud._corner_score() == pair[1]
	hud.free()
	print("C1_VISUAL_VARIANTS " + JSON.stringify({"passed":ok,"layout_cases":cases,"actual_style_light_calls":7,"limits":"Method-level map-transition guard; not full-world night/Ember gameplay or hardware"}))
	return ok
