extends SceneTree
## Average frame time of a match with the real renderer (not headless):
##     godot --path . --script tools/frame_time_probe.gd -- --play --gfx=1
## Skips the first 60 frames (loading, first-use shaders), then times 120.

func _init() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for i in 60:
		await process_frame
	var t := Time.get_ticks_usec()
	var worst := 0
	var last := t
	for i in 120:
		await process_frame
		var now := Time.get_ticks_usec()
		worst = maxi(worst, now - last)
		last = now
	print("FRAMETIME gfx=%d  mean %.1f ms  worst %.1f ms" % [game.gfx_quality, (Time.get_ticks_usec() - t) / 120000.0, worst / 1000.0])
	quit()
