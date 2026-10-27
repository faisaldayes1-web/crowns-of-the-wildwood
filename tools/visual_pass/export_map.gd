extends SceneTree
## Agent: Codex-faisal. Capture actual playable Wildwood, never generated topology.
## Run with -- --play --map=0 --seed=7 --no-prep and CROWNS_VISUAL_OUT.
const Isolated = preload("res://tools/tests/isolated.gd")

func _init():
	if not Isolated.ok("visual_pass/export_map"):
		quit(2)
		return
	var out := OS.get_environment("CROWNS_VISUAL_OUT")
	if out.is_empty() or DisplayServer.get_name() == "headless":
		push_error("Rendered export needs CROWNS_VISUAL_OUT and a renderer")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	var g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	current_scene = g
	var deadline := Time.get_ticks_msec() + 180000
	for i in 30:
		await process_frame
	while (not g.playing or is_instance_valid(g.loading_layer)) and Time.get_ticks_msec() < deadline:
		await process_frame
	if not g.playing or is_instance_valid(g.loading_layer):
		push_error("Playable world did not finish loading")
		quit(3)
		return
	paused = true
	# Render the live World3D through a separate viewport: no HUD canvas layers.
	var vp := SubViewport.new()
	vp.size = Vector2i(4096, 4096)
	vp.world_3d = g.get_world_3d()
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_2X
	root.add_child(vp)
	var cam := Camera3D.new()
	vp.add_child(cam)
	var half_extent: float = maxf(g.map_half.x, g.map_half.y)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = half_extent * 2.0
	cam.far = 500.0
	cam.position = Vector3(0, 200, 0)
	cam.look_at(Vector3.ZERO, Vector3(0, 0, -1))
	cam.current = true
	# Match environment minus distance fog, which would hide an orthographic map.
	cam.environment = g.world_environment.duplicate()
	cam.environment.fog_enabled = false
	cam.environment.volumetric_fog_enabled = false
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	var err := vp.get_texture().get_image().save_png(out.path_join("wildwood-clean-4096.png"))
	if err != OK:
		quit(4)
		return
	var landmarks := [
		{"name":"ELVEN CASTLE", "x":-g.CASTLE_X, "z":0.0},
		{"name":"HUMAN CASTLE", "x":g.CASTLE_X, "z":0.0},
		{"name":"NORTH BRIDGE", "x":0.0, "z":g.BRIDGES[0]},
		{"name":"CROWN SHRINE", "x":0.0, "z":g.BRIDGES[1]},
		{"name":"SOUTH BRIDGE", "x":0.0, "z":g.BRIDGES[2]}
	]
	var overlay := CanvasLayer.new()
	vp.add_child(overlay)
	for item in landmarks:
		var label := Label.new()
		label.text = item.name
		label.add_theme_font_size_override("font_size", 44)
		label.add_theme_color_override("font_color", Color("fff3cd"))
		label.add_theme_color_override("font_outline_color", Color("17232c"))
		label.add_theme_constant_override("outline_size", 14)
		var point := Vector2((item.x + half_extent)/(2.0*half_extent), (item.z + half_extent)/(2.0*half_extent))*4096.0
		label.position = point + Vector2(16, 16)
		overlay.add_child(label)
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(out.path_join("wildwood-labelled-4096.png"))
	var data := {"agent":"Codex-faisal", "source":"actual Godot World3D orthographic viewport", "map_variant":g.map_variant,
		"image_size":[4096,4096], "world_axes":{"right":"+X", "down":"+Z", "north":"-Z"},
		"capture_bounds":{"min_x":-half_extent,"max_x":half_extent,"min_z":-half_extent,"max_z":half_extent},
		"playable_bounds":{"min_x":-g.map_half.x,"max_x":g.map_half.x,"min_z":-g.map_half.y,"max_z":g.map_half.y},
		"world_to_uv":"u=(x-min_x)/(max_x-min_x); v=(z-min_z)/(max_z-min_z)", "landmarks":landmarks,
		"notes":"Existing playable map, no topology expansion. Square map includes margin beyond north/south playable bounds. Live units are frozen at capture time."}
	FileAccess.open(out.path_join("wildwood-bounds.json"), FileAccess.WRITE).store_string(JSON.stringify(data, "  "))
	print("MAP_EXPORT PASS 4096 clean, labelled, bounds; playable half=",g.map_half)
	paused = false
	vp.queue_free()
	g.queue_free()
	current_scene = null
	for i in 30:
		await process_frame
	quit()
