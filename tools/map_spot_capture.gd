extends SceneTree
## Agent: claude-faisallaptop (cf-crowns-mapaudit-1105l). Fixed-camera shots of named spots, at the game's own
## camera angle (as in Faisal's screenshots), so a before and an after frame compare 1:1. Units, HUD and labels
## are hidden. Spots are "label:x:z" (the camera looks at x,z from 11 up and 9 south, fov 50, like spot_capture):
##   CROWNS_CAPTURE_DIR=out tools/tests/isolated.sh --path . --resolution 1920x1080 \
##     --script tools/map_spot_capture.gd -- --map=0 --tag=before --spots="fence:-37:-10;stub:-31:-11"
## Add :h:d to a spot to change the camera height and back-off (default 11 and 9; 24 and 3 is near overhead).
const Isolated = preload("res://tools/tests/isolated.gd")

var game


func _initialize() -> void:
	call_deferred("run")


func _arg(prefix: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			return arg.trim_prefix(prefix)
	return ""


func run() -> void:
	if not Isolated.ok("map_spot_capture") or DisplayServer.get_name() == "headless":
		quit(2)
		return
	var out := OS.get_environment("CROWNS_CAPTURE_DIR")
	if out.is_empty():
		quit(2)
		return
	var tag := _arg("--tag=")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	var deadline := Time.get_ticks_msec() + 240000
	while game.main_menu == null or game.menus_warming or not game.world_ready or is_instance_valid(game.loading_layer):
		if Time.get_ticks_msec() > deadline:
			push_error("Capture load timeout")
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
	game._begin_battle()
	for i in 300:   # (the battle-start shockwave is a tween: frozen mid-ring it painted a 30 m gold disc over every pass 1 and 2 frame)
		await process_frame
	var dir := out
	if tag != "":
		dir = out.path_join(tag)
	DirAccess.make_dir_recursive_absolute(dir)
	var actors: Array = []
	for actor in game.units + game.monarchs + game.guides + game.blessings + game.turrets:
		if is_instance_valid(actor) and actor is Node3D:
			actors.append(actor)
	if "--live" not in OS.get_cmdline_user_args():   # --live keeps the game running (lamps, day grade) with the units hidden
		game.process_mode = Node.PROCESS_MODE_DISABLED
	for actor in actors:
		actor.hide()
	for layer in root.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	for label in root.find_children("*", "Label3D", true, false):
		label.visible = false
	if "--fell" in OS.get_cmdline_user_args():   # every lumber tree and ore deposit as the gatherers leave it
		for n in game.economy.nodes:
			n.stock = 0
			n.regrow_left = 999.0
			n._refresh()
	if "--nolights" in OS.get_cmdline_user_args():
		for l in game.find_children("*", "OmniLight3D", true, false):
			l.visible = false
	var cam: Camera3D = game.camera   # the game's own camera: its environment and grade, as in a real match
	cam.fov = 50.0
	cam.make_current()
	var slug := "map%d" % game.map_variant
	# --near=x:z:r lists every placed prop and block within r of x,z (to find what a screenshot shows)
	var near := _arg("--near=").split(":")
	if near.size() == 3 and game.lmap != null:
		var cc := Vector2(float(near[0]), float(near[1]))
		print("NEAR lanes kind=", game.lmap.kind, " height_here=", game.lmap.height(cc.x, cc.y), " terrain meshes=", game.find_children("*", "MeshInstance3D", true, false).filter(func(n): return n.has_meta("terrain")).size())
	if near.size() == 3:
		var c := Vector2(float(near[0]), float(near[1]))
		for ap in game.audit_props:
			if is_instance_valid(ap[1]) and ap[1] is Node3D and Vector2(ap[1].position.x, ap[1].position.z).distance_to(c) < float(near[2]):
				print("NEAR prop ", ap[0], " ", ap[1].position, " scale ", ap[1].scale.x)
		for mi in game.find_children("*", "MeshInstance3D", true, false):
			var m: Material = mi.material_override if mi.material_override != null else (mi.mesh.surface_get_material(0) if mi.mesh != null and mi.mesh.get_surface_count() > 0 else null)
			var aabb: AABB = mi.global_transform * mi.get_aabb()
			if m is BaseMaterial3D and (m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or m.blend_mode != BaseMaterial3D.BLEND_MODE_MIX) and Vector2(aabb.get_center().x, aabb.get_center().z).distance_to(c) < float(near[2]) and aabb.size.x > 2.0:
				print("NEAR translucent ", mi.get_path(), " ", aabb, " col ", m.albedo_color, " vis ", mi.is_visible_in_tree())
		for blk in game.audit_blocks:
			var b: AABB = blk[1]
			if Vector2(b.get_center().x, b.get_center().z).distance_to(c) < float(near[2]):
				print("NEAR block ", blk[0], " ", b)
	for spec in _arg("--spots=").split(";", false):
		var p := spec.split(":")
		if p.size() < 3:
			continue
		var at := Vector3(float(p[1]), 0.0, float(p[2]))
		var up := float(p[3]) if p.size() > 3 else 11.0
		var back := float(p[4]) if p.size() > 4 else 9.0
		var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(at.x, 60.0, at.z), Vector3(at.x, -10.0, at.z)))
		if not hit.is_empty():
			at.y = float(hit.position.y)
		for i in 8:
			# Set after the game's own camera follow has run (it moves the camera each frame while live)
			await RenderingServer.frame_pre_draw
			cam.make_current()
			cam.fov = 50.0
			cam.global_position = at + Vector3(0, up, back)
			cam.look_at(at, Vector3.UP)
		await RenderingServer.frame_post_draw
		var path := dir.path_join("%s-%s.jpg" % [slug, p[0]])
		root.get_texture().get_image().save_jpg(path, 0.92)
		print("SPOT ", path, " at ", at)
	print("SPOT_DONE ", slug, " source=", OS.get_environment("CROWNS_SOURCE_SHA"))
	quit()
