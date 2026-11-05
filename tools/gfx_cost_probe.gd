extends SceneTree
## Which rendering features cost the frame on a given map? In one running bot
## match, switches each feature off for a few seconds between two baseline
## stretches and prints the median frame time (base, off, base again), so
## background load shows up as base-to-base drift. Companion to cost_ab.gd,
## which covers the main thread.
##     godot --path . --resolution 1920x1080 --script tools/gfx_cost_probe.gd -- --demo --seed=7 --map=3 --gfx=2
## claude-faisal3 2026-11-04.

const SETTLE := 14.0
const SECS := 5.0

var game
var saved := []


func _median() -> float:
	# Two seconds of settling first: a switched feature recompiles shaders.
	var t1 := Time.get_ticks_usec()
	while Time.get_ticks_usec() - t1 < 2.0e6:
		await process_frame
	var times := []
	var last := Time.get_ticks_usec()
	var t0 := last
	var vp_rid: RID = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp_rid, true)
	while Time.get_ticks_usec() - t0 < SECS * 1e6:
		await process_frame
		# GPU time, not frame time: the frame cap hides headroom.
		times.append(RenderingServer.viewport_get_measured_render_time_gpu(vp_rid))
	times.sort()
	return times[times.size() / 2]


func _toggle(what: String, off: bool) -> void:
	var vp: Viewport = game.get_viewport()
	var env = game.world_environment
	match what:
		"omni_lights":
			if off:
				saved = []
				for l in root.find_children("*", "OmniLight3D", true, false):
					saved.append([l, l.visible])
					l.visible = false
			else:
				for s in saved:
					if is_instance_valid(s[0]):
						s[0].visible = s[1]
		"omni_big", "omni_small":
			# Lights split at 10 m range: big fills against small torches.
			if off:
				saved = []
				var big: bool = what == "omni_big"
				for l in root.find_children("*", "OmniLight3D", true, false):
					if (l.omni_range >= 10.0) == big:
						saved.append([l, l.visible])
						l.visible = false
			else:
				for s in saved:
					if is_instance_valid(s[0]):
						s[0].visible = s[1]
		"forest", "forest_shadows":
			# The kit's trees, bushes and rocks: hidden, or only their sun shadows.
			if off:
				saved = []
				for n in game.get_children():
					if n is MultiMeshInstance3D and n.name.begins_with("ForestKit_"):
						saved.append([n, n.visible, n.cast_shadow])
						if what == "forest":
							n.visible = false
						else:
							n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			else:
				for s in saved:
					if is_instance_valid(s[0]):
						s[0].visible = s[1]
						s[0].cast_shadow = s[2]
		"lamp_shadows":
			for l in game.lamp_shadows:
				if is_instance_valid(l):
					l.shadow_enabled = not off
		"sun_shadow":
			game.sun_light.shadow_enabled = not off
		"ssao":
			env.ssao_enabled = not off
		"ssil":
			env.ssil_enabled = not off
		"glow":
			env.glow_enabled = not off
		"msaa":
			vp.msaa_3d = Viewport.MSAA_DISABLED if off else Viewport.MSAA_4X
		"hud":
			for h in root.find_children("*", "CanvasLayer", true, false):
				h.visible = not off
		"render_0.75":
			vp.scaling_3d_scale = 0.75 if off else 1.0
		"cascades_2":
			game.sun_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if off else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		"ink":
			for q in root.find_children("*", "MeshInstance3D", true, false):
				if q.material_override == game.ink_mat:
					q.visible = not off
		"shadow_filter_hard":
			var lvl := RenderingServer.SHADOW_QUALITY_HARD if off else RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM
			RenderingServer.directional_soft_shadow_filter_set_quality(lvl)
			RenderingServer.positional_soft_shadow_filter_set_quality(lvl)
		"dof":
			game.cam_attrs.dof_blur_far_enabled = not off
		"fxaa":
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED if off else Viewport.SCREEN_SPACE_AA_FXAA
		"atlas_2048":
			RenderingServer.directional_shadow_atlas_set_size(2048 if off else 4096, true)
		"cascades_1":
			game.sun_light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL if off else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		"filter_vlow":
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW if off else RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)
		"shadow_far_45":
			game.sun_light.directional_shadow_max_distance = 45.0 if off else 70.0


func _init() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < SETTLE * 1000.0:
		await process_frame
	print("GFXCOST omni lights: %d total, %d with range >= 10 m" % [root.find_children("*", "OmniLight3D", true, false).size(), root.find_children("*", "OmniLight3D", true, false).filter(func(l): return l.omni_range >= 10.0).size()])
	print("GFXCOST gpu=%s msaa=%d scale=%.2f shadow_max=%.0f mode=%d" % [RenderingServer.get_video_adapter_name(), game.get_viewport().msaa_3d, game.get_viewport().scaling_3d_scale, game.sun_light.directional_shadow_max_distance, game.sun_light.directional_shadow_mode])
	var all := ["omni_lights", "ssao", "ssil", "glow", "hud", "render_0.75", "cascades_2", "shadow_far_45", "sun_shadow", "ink", "shadow_filter_hard", "dof", "fxaa"]
	var only := all
	var rounds := 1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=").split(",")
		elif arg.begins_with("--rounds="):
			rounds = int(arg.trim_prefix("--rounds="))
	var plan := []
	for r in rounds:
		plan.append_array(only)
	for what in plan:
		var a: float = await _median()
		_toggle(what, true)
		var b: float = await _median()
		_toggle(what, false)
		var c: float = await _median()
		print("GFXCOST %-14s base %.2f  off %.2f  base %.2f   saves ~%.2f ms" % [what, a, b, c, (a + c) / 2.0 - b])
	quit()
