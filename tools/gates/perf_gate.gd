extends SceneTree
## CI gate (claude-faisal/crowns-gates 2026-11-04): one map's render budget
## and its runtime references, with a real renderer (CI: xvfb + Mesa,
## gl_compatibility). Run from the project root:
##   tools/tests/isolated.sh --path . --rendering-method gl_compatibility --resolution 640x360 --script tools/gates/perf_gate.gd -- --play --seed=7 --gfx=0 --map=2
## Budget (tools/gates/perf_budget.json, per map): the worst camera spot's
## draw calls, primitives and objects a frame, the node count, and a
## frame-time proxy: the game's own CPU time a frame (Performance
## TIME_PROCESS + TIME_PHYSICS_PROCESS, median), which software rendering on
## a CI runner does not swamp the way whole-frame time would.
## Runtime references: no visible mesh instance without a mesh, no sprite or
## texture rect without a texture, no shader material without a shader.
## --record prints the measured values as a JSON line (to set the budget).

const Isolated = preload("res://tools/tests/isolated.gd")
const BUDGET := "res://tools/gates/perf_budget.json"
const SPOTS := [Vector3(0, 0, 0), Vector3(-60, 0, 0), Vector3(30, 0, 18), Vector3(60, 0, 0)]
const WARM := 12
const TIMED := 16

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	if not Isolated.ok("tools/gates/perf_gate.gd") or DisplayServer.get_name() == "headless":
		print("perf gate: needs a renderer (not --headless)")
		quit(2)
		return
	var map := "0"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--map="):
			map = a.trim_prefix("--map=")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	var deadline := Time.get_ticks_msec() + 180000
	while not game.playing or game.player == null or is_instance_valid(game.loading_layer):
		if Time.get_ticks_msec() > deadline:
			check(false, "map %s: the match never started" % map)
			return _end(game)
		await process_frame
	game.prep_left = 60.0   # nobody fights while the camera tours
	# --- runtime references
	var bad := {}
	for n in root.find_children("*", "", true, false):
		var why := ""
		if n is MeshInstance3D and n.is_visible_in_tree() and n.mesh == null and not n.has_meta(&"batched"):
			why = "MeshInstance3D without a mesh"
		elif n is Sprite3D and n.is_visible_in_tree() and n.texture == null:
			why = "Sprite3D without a texture"
		elif n is TextureRect and n.is_visible_in_tree() and n.texture == null:
			why = "TextureRect without a texture"
		elif n is GeometryInstance3D and n.material_override is ShaderMaterial and n.material_override.shader == null:
			why = "ShaderMaterial without a shader"
		if why != "":
			var key: String = why + " " + str(n.name).rstrip("0123456789@")
			bad[key] = bad.get(key, 0) + 1
	for k in bad:
		check(false, "map %s: %d x %s" % [map, bad[k], k])
	# --- render budget at the spots
	var worst := {"draws": 0.0, "prims": 0.0, "objects": 0.0, "cpu_ms": 0.0}
	for spot in SPOTS:
		if game.vmap and absf(spot.z) > 15.0:
			spot.z = 0.0
		game.cam_lock = spot
		game.cam_pos = spot + game.CAMERA_OFFSET * game.cam_zoom
		for i in WARM:
			await process_frame
		var draws := 0.0
		var prims := 0.0
		var objs := 0.0
		var cpu: Array = []
		for i in TIMED:
			await process_frame
			draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			prims += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
			objs += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
		for i in 3:
			await create_timer(1.05).timeout   # (the time monitors refresh about once a second)
			cpu.append((Performance.get_monitor(Performance.TIME_PROCESS) + Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0)
		cpu.sort()
		var s := {"draws": draws / TIMED, "prims": prims / TIMED, "objects": objs / TIMED, "cpu_ms": cpu[cpu.size() / 2]}
		print("PERF map %s spot %s draws %.0f prims %.0f objects %.0f cpu %.2f ms" % [map, spot, s.draws, s.prims, s.objects, s.cpu_ms])
		for k in worst:
			worst[k] = maxf(worst[k], s[k])
	worst["nodes"] = float(root.find_children("*", "", true, false).size())
	print("PERF map %s worst %s" % [map, JSON.stringify(worst)])
	var budget: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BUDGET)) if FileAccess.file_exists(BUDGET) else {}
	var mine: Dictionary = budget.get("maps", {}).get(map, {})
	check(not mine.is_empty(), "map %s has no budget in %s" % [map, BUDGET])
	for k in mine:
		if worst.has(k):
			check(worst[k] <= float(mine[k]), "map %s: %s %.1f over the budget %.1f" % [map, k, worst[k], float(mine[k])])
	_end(game)


func _end(game) -> void:
	print("perf gate map: %d failure(s)" % failures)
	game.queue_free()
	for i in 10:
		await process_frame
	quit(1 if failures > 0 else 0)
