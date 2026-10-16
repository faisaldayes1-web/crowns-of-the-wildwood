extends SceneTree
## Times CharacterModel.setup (the model rebuild a respawn, class pick or
## promotion does) and the frame after it, with the real renderer.
##     godot --path . --resolution 1280x720 --script tools/model_bench.gd

const CharacterModel = preload("res://scripts/character_model.gd")
const Stats = preload("res://scripts/stats.gd")


func _init() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.5, 4)
	root.add_child(cam)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, -30, 0)
	root.add_child(light)
	var models := []
	for i in 6:
		var m := CharacterModel.new()
		m.position = Vector3(i - 2.5, 0, 0)
		root.add_child(m)
		models.append(m)
	var roles := [Stats.Role.BASE, Stats.Role.KNIGHT, Stats.Role.RANGER, Stats.Role.MAGE, Stats.Role.HEALER, Stats.Role.ROGUE]
	var setup_ms := []
	var frame_ms := []
	var rounds := 8
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--rounds="):
			rounds = int(a.trim_prefix("--rounds="))
	for it in rounds:
		for i in models.size():
			var t0 := Time.get_ticks_usec()
			models[i].setup(it % 2, roles[(i + it) % roles.size()], "", {}, 1 + it % 3)
			var t1 := Time.get_ticks_usec()
			await process_frame
			var t2 := Time.get_ticks_usec()
			await process_frame
			if it > 0:   # the first round loads everything from disk
				setup_ms.append((t1 - t0) / 1000.0)
				frame_ms.append((t2 - t1) / 1000.0)
	setup_ms.sort()
	frame_ms.sort()
	print("BENCH setup median %.2f ms max %.2f | next frame median %.2f ms max %.2f" % [setup_ms[setup_ms.size() / 2], setup_ms[-1], frame_ms[frame_ms.size() / 2], frame_ms[-1]])
	quit()
