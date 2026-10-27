extends SceneTree
## Agent: Codex-faisal. Diagnostic fixture, not a production lifecycle patch.
func _init():
	var g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	current_scene = g
	for i in 180:
		await process_frame
	print("DIAG user=", OS.get_user_data_dir())
	print("DIAG teardown after 180 frames; mode=", OS.get_environment("C68_MODE"))
	if OS.get_environment("C68_MODE") == "drain":
		g.queue_free()
		current_scene = null
		for i in 30:
			await process_frame
	quit()
