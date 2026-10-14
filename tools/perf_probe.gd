extends SceneTree
## Warm frame-time and render statistics of a match with the real renderer
## (not headless), at a few fixed camera spots:
##     godot --path . --resolution 1280x720 --script tools/perf_probe.gd -- --play --seed=7 --gfx=2 [--map=2]
## For each spot: WARM warm-up frames (first-use shaders, streaming), then TIMED
## timed frames. Prints median / p95 / p99 frame time, the render monitors
## (draw calls, objects, primitives) and memory, and a node census once.
## Run it alone: a second heavy process on the machine skews every number.

const WARM := 30
const TIMED := 90   # a software renderer manages ~1 frame a second: keep runs short
const SPOTS := [Vector3(0, 0, 0), Vector3(-60, 0, 0), Vector3(30, 0, 18), Vector3(60, 0, 0)]


func _init() -> void:
	var t0 := Time.get_ticks_msec()
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	print("PERF startup (scene ready) %d ms" % (Time.get_ticks_msec() - t0))
	var kinds := {}
	var casters := 0
	var mm_instances := 0
	for n in root.find_children("*", "", true, false):
		kinds[n.get_class()] = kinds.get(n.get_class(), 0) + 1
		if n is GeometryInstance3D and n.visible and n.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			casters += 1
		if n is MultiMeshInstance3D and n.multimesh:
			mm_instances += n.multimesh.instance_count
	print("PERF nodes=%d mesh=%d multimesh_nodes=%d multimesh_instances=%d omni=%d shadow_casters=%d" % [
		root.find_children("*", "", true, false).size(), kinds.get("MeshInstance3D", 0), kinds.get("MultiMeshInstance3D", 0),
		mm_instances, kinds.get("OmniLight3D", 0), casters])
	for spot in SPOTS:
		if game.vmap and absf(spot.z) > 15.0:
			spot.z = 0.0
		game.cam_lock = spot
		game.cam_pos = spot + game.CAMERA_OFFSET * game.cam_zoom
		var times: Array = []
		var hitch := 0
		for i in WARM:
			await process_frame
		var last := Time.get_ticks_usec()
		var draws := 0.0
		var objs := 0.0
		var prims := 0.0
		for i in TIMED:
			await process_frame
			var now := Time.get_ticks_usec()
			times.append((now - last) / 1000.0)
			last = now
			draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			objs += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
			prims += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		times.sort()
		var med: float = times[times.size() / 2]
		for t in times:
			if t > med * 3.0:
				hitch += 1
		print("PERF spot %s median %.1f ms  p95 %.1f  p99 %.1f  max %.1f  hitches(>3x median) %d  draws %.0f  objects %.0f  prims %.0f" % [
			spot, med, times[int(times.size() * 0.95)], times[int(times.size() * 0.99)], times[-1], hitch, draws / TIMED, objs / TIMED, prims / TIMED])
	print("PERF memory static %.0f MB  video %.0f MB  texture %.0f MB  buffer %.0f MB" % [
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0, Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / 1048576.0])
	print("PERF adapter %s / %s" % [RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_vendor()])
	quit()
