extends SceneTree
## A/B the renderer's big switches in one running bot match: for each
## experiment, a baseline stretch, then the switch, then its stretch, and
## prints the median and p99 frame time, draw calls and GPU time of both.
##     godot --path . --resolution 1920x1080 --script tools/render_ab.gd -- --demo --seed=7 --gfx=2

const SETTLE := 12.0
const SECS := 4.0

var game


func _stretch(vp_rid: RID) -> Array:
	var times := []
	var draws := 0.0
	var gpu := 0.0
	var last := Time.get_ticks_usec()
	var t0 := last
	while Time.get_ticks_usec() - t0 < SECS * 1e6:
		await process_frame
		var now := Time.get_ticks_usec()
		times.append((now - last) / 1000.0)
		last = now
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp_rid)
	times.sort()
	return [times[times.size() / 2], times[int(times.size() * 0.99)], draws / times.size(), gpu / times.size()]


func _switch(what: String, on: bool) -> void:
	var env: Environment = game.world_environment
	match what:
		"sun_shadow":
			game.sun_light.shadow_enabled = on
		"2_splits":
			game.sun_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if on else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		"ssao":
			env.ssao_enabled = on
		"ssil":
			env.ssil_enabled = on
		"glow":
			env.glow_enabled = on
		"dof":
			if game.cam_attrs:
				game.cam_attrs.dof_blur_far_enabled = on
		"lamp_shadows":
			for l in game.lamp_shadows:
				if is_instance_valid(l):
					l.shadow_enabled = on
		"omni_lights":
			for l in root.find_children("*", "OmniLight3D", true, false):
				l.visible = on
		"multimesh":
			for m in root.find_children("*", "MultiMeshInstance3D", true, false):
				m.visible = on
		"hud":
			for h in root.find_children("*", "CanvasLayer", true, false):
				h.visible = on


func _init() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	var vp_rid: RID = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp_rid, true)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < SETTLE * 1000.0:
		await process_frame
	var exps := {"sun_shadow": false, "2_splits": true, "lamp_shadows": false, "omni_lights": false, "multimesh": false, "ssao": false, "ssil": false}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ab="):
			var keep := {}
			for k in a.trim_prefix("--ab=").split(","):
				keep[k] = exps[k]
			exps = keep
	print("AB lamp_shadows=%d omni=%d sun_mode=%d max_dist=%.0f" % [game.lamp_shadows.size(), root.find_children("*", "OmniLight3D", true, false).size(),
		game.sun_light.directional_shadow_mode, game.sun_light.directional_shadow_max_distance])
	for e in exps:
		var a: Array = await _stretch(vp_rid)
		_switch(e, exps[e])
		var b: Array = await _stretch(vp_rid)
		_switch(e, not exps[e])
		print("AB %-13s base median %.2f p99 %.2f draws %5.0f gpu %.2f | switched median %.2f p99 %.2f draws %5.0f gpu %.2f" % [e, a[0], a[1], a[2], a[3], b[0], b[1], b[2], b[3]])
	quit()
