extends SceneTree
## Agent: Codex-faisal2. Actual world captures; no replacement geometry.
## APPDATA must point at a marked throwaway dir; --map chooses the real map.
const Isolated = preload("res://tools/tests/isolated.gd")
var game
var output := ""

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if not Isolated.ok("map_card_capture") or DisplayServer.get_name() == "headless":
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
			push_error("Map capture load timeout")
			quit(1)
			return
		await process_frame
	game.needs_name = false
	game.touch_active = "--capture-touch" in OS.get_cmdline_user_args()
	game.name_editing = false
	game.howto_seen = true
	game.main_menu.overlay = ""
	game.main_menu._press("play", null)
	if not "--assets-only" in OS.get_cmdline_user_args():
		await capture("select-screen")
	if game.main_menu._card_open(1):
		push_error("Capture must retain the locked Moonlit menu state")
		quit(1)
		return
	if "--menu-only" in OS.get_cmdline_user_args():
		quit()
		return
	if game.map_variant == 1 and not game.night():
		push_error("Moonlit capture requires --debug-night (keeps the UI lock)")
		quit(2)
		return
	game._start_match(0)
	while not game.playing or is_instance_valid(game.loading_layer):
		await process_frame
	# Freeze the actual match before moving a dedicated capture camera.
	game.process_mode = Node.PROCESS_MODE_DISABLED
	for actor in game.units + game.monarchs + game.guides + game.blessings + game.turrets:
		if is_instance_valid(actor) and actor is Node3D:
			actor.hide()
	if is_instance_valid(game.barrier):
		game.barrier.hide()
	# Gameplay's distance-based tilt shift is calibrated for its low camera,
	# not an elevated thumbnail/map camera. Keep real materials and lighting.
	if game.cam_attrs:
		game.cam_attrs.dof_blur_far_enabled = false
		game.cam_attrs.dof_blur_near_enabled = false
	game.world_environment.fog_enabled = false
	game.world_environment.volumetric_fog_enabled = false
	for layer in root.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	for label in root.find_children("*", "Label3D", true, false):
		label.visible = false
	# The match can emit shots during its loading fade; omit those transient
	# objects too so a reusable minimap cannot bake a stray projectile.
	for node in game.find_children("*", "Node3D", true, false):
		if node.get_script() and node.get_script().resource_path in ["res://scripts/projectile.gd", "res://scripts/fx.gd", "res://scripts/skill_fx.gd"]:
			node.hide()
	var view := SubViewport.new()
	view.size = Vector2i(1024, 960)
	view.world_3d = root.world_3d
	view.msaa_3d = Viewport.MSAA_4X
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var cam := Camera3D.new()
	view.add_child(cam)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 48.0
	cam.far = 1000.0
	var focus := Vector3.ZERO
	if game.map_variant == 1 or game.map_variant == 3:
		focus = Vector3(58 if game.map_variant == 3 else 44, 0, 0)
		cam.size = 61.0
	elif game.map_variant == 2:
		cam.size = 64.0
	for arg in OS.get_cmdline_user_args():   # framing override for the lane maps: --focus-x=N --card-size=N
		if arg.begins_with("--focus-x="):
			focus.x = float(arg.trim_prefix("--focus-x="))
		elif arg.begins_with("--card-size="):
			cam.size = float(arg.trim_prefix("--card-size="))
	cam.position = focus + Vector3(0, 80, 56)
	cam.look_at(focus)
	cam.make_current()
	await capture("card", view)
	# Full world-map export: north is -Z, east is +X. Frame the existing
	# play space and its surrounding art; this does not redefine walkability.
	view.size = Vector2i(4096, 2304)
	cam.size = 216.0
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.position = Vector3(0, 250, 0)
	cam.rotation_degrees = Vector3(-90, 0, 0)
	await capture("map-clean-4096", view)
	var landmarks := [["ELVEN KEEP", Vector3(-69, 0, 0)], ["HUMAN KEEP", Vector3(69, 0, 0)]]
	if game.map_variant == 2:
		landmarks.append_array([["CROSSING", Vector3(0, 0, -17)], ["FIRE OBJECTIVE", Vector3(0, 0, 17)]])
	else:
		landmarks.append_array([["NORTH BRIDGE", Vector3(0, 0, -20)], ["CENTRAL PLAZA", Vector3.ZERO], ["SOUTH BRIDGE", Vector3(0, 0, 20)]])
	var layer := CanvasLayer.new()
	view.add_child(layer)
	var exported := []
	for landmark in landmarks:
		var pixel := cam.unproject_position(landmark[1])
		var label := Label.new()
		label.text = landmark[0]
		label.add_theme_font_size_override("font_size", 34)
		label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.04))
		label.add_theme_constant_override("outline_size", 14)
		label.position = pixel + Vector2(12, -44)
		layer.add_child(label)
		exported.append({"label": landmark[0], "world_x": landmark[1].x, "world_z": landmark[1].z, "pixel_x": pixel.x, "pixel_y": pixel.y})
	await capture("map-labelled-4096", view)
	var bounds := FileAccess.open(output.path_join("bounds.json"), FileAccess.WRITE)
	bounds.store_string(JSON.stringify({"agent": "Codex-faisal2", "map_variant": game.map_variant, "image_width": 4096, "image_height": 2304, "world_x_min": -108.0, "world_x_max": 108.0, "world_z_min": -60.75, "world_z_max": 60.75, "north": "-Z", "projection": "orthographic", "pixel_mapping": "px=(x+108)/216*4096; py=(z+60.75)/121.5*2304", "bounds_kind": "image extent, not collision or navigation bounds", "landmarks": exported}, "  "))
	print("MAP_CARD_DONE map=", game.map_variant)
	quit()

func capture(label: String, viewport: Viewport = null) -> void:
	if viewport == null:
		viewport = root
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var err := viewport.get_texture().get_image().save_png(output.path_join(label + ".png"))
	if err != OK:
		push_error("Capture failed: " + label)
		quit(1)
	print("CAPTURE ", output.path_join(label + ".png"))
