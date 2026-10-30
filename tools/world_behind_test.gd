extends SceneTree
## Agent: claude-faisal3, 2026-10-29 loading pass (PERF-05). The title comes
## up before the match world is built; the world is built behind the menus.
## A scene reload (a map switch) or a quit while it builds must finish it
## first: its paused build steps held renderer resources past shutdown and
## Godot 4.3 crashed on exit. Run rendered; CI also fails on a leak report.
## tools/tests/isolated.sh --path . --script tools/world_behind_test.gd -- --world-behind

const Isolated = preload("res://tools/tests/isolated.gd")
var failures := 0


func check(ok: bool, message: String) -> void:
	print(("PASS " if ok else "FAIL ") + message)
	if not ok:
		failures += 1


func _init() -> void:
	if not Isolated.ok("tools/world_behind_test.gd"):
		quit(2)
		return
	if DisplayServer.get_name() == "headless":
		print("FAIL the world-behind test needs a real display")
		quit(2)
		return
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	_run.call_deferred()


func _title(old_id: int) -> Node:
	var deadline := Time.get_ticks_msec() + 240000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		var g = current_scene
		if g != null and is_instance_valid(g) and g.get_instance_id() != old_id and g.main_menu != null \
				and not g.menus_warming and not g._stream_world and not is_instance_valid(g.loading_layer):
			return g
	return null


func _run() -> void:
	var began := Time.get_ticks_msec()
	var game = await _title(0)
	check(game != null, "the title comes up")
	if game == null:
		quit(1)
		return
	print("WORLD_BEHIND title_ms=%d world_ready=%s" % [Time.get_ticks_msec() - began, game.world_ready])
	check(not game.world_ready, "the title is up before the match world is built")
	# A map switch while the world builds: the old scene finishes its world,
	# then the new one comes up and builds its own behind its title.
	var old_id: int = game.get_instance_id()
	game._reload_scene()
	game = await _title(old_id)
	check(game != null and not game.world_ready, "a reload mid-build comes back to a title, its world building behind")
	var mains := 0
	for n in root.get_children():
		if n.get_script() == load("res://scripts/game.gd"):
			mains += 1
	check(mains == 1, "exactly one game scene after the reload")
	# Quitting mid-build (the title's EXIT and closing the window do this).
	if game != null:
		game.finish_world_now()
		check(game.world_ready, "quitting mid-build finishes the world first")
		game._flush_save()
	print("world behind test: %d failure(s)" % failures)
	quit(1 if failures else 0)
