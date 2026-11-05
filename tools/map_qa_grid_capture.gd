extends SceneTree
## Agent: claude-faisallaptop (cf-crowns-mapaudit-1105h). The release-QA capture grid for one map:
## 16 overhead cells (4x4 over the field, with overlap), 8 ground-level shots and 1 shot with the HUD.
## Units are frozen and hidden for the 24 map shots so reviewers see only the map; the HUD shot is the
## live match view with units and UI. Output is <dir>/<slug>/ plus manifest.json (cell and shot positions).
## Run through tools/tests/isolated.sh with a window (not --headless), at 1080p:
##   CROWNS_CAPTURE_DIR=docs/evidence/qa-1105 tools/tests/isolated.sh --path . --resolution 1920x1080 \
##     --script tools/map_qa_grid_capture.gd -- --map=0 [--tag=before] [--only=ground]
const Isolated = preload("res://tools/tests/isolated.gd")

const SLUGS := ["wildwood", "moonlit", "ember-pass", "stonekeep", "twilight-grove"]
# The field the cells tile: x -60..60 (gate to gate), z -34..34. Each cell is 30 x 17 and the camera
# frames it with a 20% margin so neighbouring cells overlap and nothing falls on a seam.
const FIELD := Rect2(-60.0, -34.0, 120.0, 68.0)
const GRID := 4
const OVERHEAD_FOV := 40.0
const MARGIN := 1.2
const EYE := 1.7
# [label, eye x, eye z, look x, look z]; eye height is EYE over the ground found by a ray.
const GROUND := [
	["g1-west-gate-east", -56.0, 0.0, -20.0, 0.0],
	["g2-east-gate-west", 56.0, 0.0, 20.0, 0.0],
	["g3-north-flank-south", 0.0, -30.0, 0.0, 0.0],
	["g4-south-flank-north", 0.0, 30.0, 0.0, 0.0],
	["g5-centre-west", 4.0, 3.0, -30.0, 0.0],
	["g6-centre-east", -4.0, -3.0, 30.0, 0.0],
	["g7-sw-corner-ne", -34.0, 20.0, 6.0, -2.0],
	["g8-ne-corner-sw", 34.0, -20.0, -6.0, 2.0],
]
var game
var output := ""
var tag := ""
var manifest := {"cells": [], "ground": [], "hud": ""}

func _initialize() -> void:
	call_deferred("run")

func _arg(prefix: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			return arg.trim_prefix(prefix)
	return ""

func run() -> void:
	if not Isolated.ok("map_qa_grid_capture") or DisplayServer.get_name() == "headless":
		quit(2)
		return
	output = OS.get_environment("CROWNS_CAPTURE_DIR")
	if output.is_empty():
		quit(2)
		return
	tag = _arg("--tag=")
	var only := _arg("--only=")
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
	var slug: String = SLUGS[clampi(game.map_variant, 0, SLUGS.size() - 1)]
	var dir := output.path_join(slug)
	if tag != "":
		dir = dir.path_join(tag)
	DirAccess.make_dir_recursive_absolute(dir)
	for i in 30:
		await process_frame
	var layers := root.find_children("*", "CanvasLayer", true, false)
	var labels := root.find_children("*", "Label3D", true, false)
	var actors: Array = []
	for actor in game.units + game.monarchs + game.guides + game.blessings + game.turrets:
		if is_instance_valid(actor) and actor is Node3D:
			actors.append(actor)
	if only == "" or only == "overhead" or only == "ground":
		game.process_mode = Node.PROCESS_MODE_DISABLED
		for actor in actors:
			actor.hide()
		for layer in layers:
			layer.visible = false
		for label in labels:
			label.visible = false
		var cam := Camera3D.new()
		root.add_child(cam)
		cam.far = 1000.0
		cam.make_current()
		if only != "ground":
			await _overhead(cam, dir, slug)
		if only != "overhead":
			await _ground(cam, dir, slug)
		cam.queue_free()
	if only == "" or only == "hud":
		game.process_mode = Node.PROCESS_MODE_INHERIT
		for actor in actors:
			if is_instance_valid(actor):
				actor.show()
		for layer in layers:
			if is_instance_valid(layer):
				layer.visible = true
		for label in labels:
			if is_instance_valid(label):
				label.visible = true
		game.camera.make_current()
		for i in 90:
			await process_frame
		await RenderingServer.frame_post_draw
		var hud_path := dir.path_join("hud-%s.png" % slug)
		root.get_texture().get_image().save_png(hud_path)
		manifest["hud"] = hud_path
		print("CAPTURE ", hud_path)
	manifest["map"] = slug
	manifest["map_variant"] = game.map_variant
	manifest["size"] = [root.size.x, root.size.y]
	manifest["tag"] = tag
	manifest["godot"] = Engine.get_version_info().string
	var f := FileAccess.open(dir.path_join("manifest-%s.json" % slug), FileAccess.WRITE)
	f.store_string(JSON.stringify(manifest, "  "))
	f.close()
	print("QA_GRID_DONE map=", slug, " size=", root.size)
	quit()

func _snap(cam: Camera3D, path: String) -> bool:
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	if root.get_texture().get_image().save_png(path) != OK:
		push_error("Capture failed: " + path)
		quit(1)
		return false
	print("CAPTURE ", path)
	return true

func _overhead(cam: Camera3D, dir: String, slug: String) -> void:
	cam.fov = OVERHEAD_FOV
	var cell := FIELD.size / float(GRID)
	var aspect := float(root.size.x) / float(root.size.y)
	# Height so the vertical span covers the cell's z extent (plus margin) and the horizontal span its x extent.
	var need_v := cell.y * MARGIN * 0.5
	var need_h := cell.x * MARGIN * 0.5 / aspect
	var h := maxf(need_v, need_h) / tan(deg_to_rad(OVERHEAD_FOV * 0.5))
	for row in GRID:
		for col in GRID:
			var c := Vector2(FIELD.position.x + cell.x * (col + 0.5), FIELD.position.y + cell.y * (row + 0.5))
			cam.position = Vector3(c.x, h, c.y)
			cam.look_at(Vector3(c.x, 0, c.y), Vector3(0, 0, -1))
			var path := dir.path_join("overhead-r%d-c%d.png" % [row, col])
			if not await _snap(cam, path):
				return
			manifest["cells"].append({"row": row, "col": col, "centre": [c.x, c.y], "height": h, "file": path})

func _ground_y(x: float, z: float) -> float:
	var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, 60.0, z), Vector3(x, -10.0, z))
	var hit := space.intersect_ray(q)
	return float(hit.position.y) if not hit.is_empty() else 0.0

func _ground(cam: Camera3D, dir: String, slug: String) -> void:
	cam.fov = 70.0
	for g in GROUND:
		var y := _ground_y(g[1], g[2])
		cam.position = Vector3(g[1], y + EYE, g[2])
		cam.look_at(Vector3(g[3], _ground_y(g[3], g[4]) + EYE * 0.8, g[4]), Vector3.UP)
		var path := dir.path_join("%s.png" % g[0])
		if not await _snap(cam, path):
			return
		manifest["ground"].append({"label": g[0], "eye": [g[1], y + EYE, g[2]], "look": [g[3], g[4]], "file": path})
