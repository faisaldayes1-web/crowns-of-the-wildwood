extends SceneTree
## The host of an online room switches maps while a joiner waits: the joiner
## must rebuild onto each map (Faisal 2026-10-15, moving from map to map).
## Host side; start a plain joiner next to it:
##     godot --headless --path . --script tools/net_map_switch_test.gd -- --port=24620 --debug-unlock &
##     godot --headless --path . -- --join=127.0.0.1:24620
## The joiner's log should say "NET welcomed: ... map N" for 0, 2, 3, 4 and 1:
## a change of ground rebuilds the joiner's world. Moonlit -> Wildwood only
## changes the light, which the match start sends (net_start_client).

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _settle():
	for i in 30:
		await process_frame
	return current_scene


func _init() -> void:
	var port := 24620
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--port="):
			port = int(arg.trim_prefix("--port="))
	var g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	current_scene = g
	g = await _settle()
	var net = root.get_node_or_null("Net")
	check(net != null, "the Net autoload is there")
	if net == null:
		quit(1)
		return
	if g.map_variant != 0:
		g.select_map(0)
		g = await _settle()
	check(net.host(port), "hosting on %d" % port)
	for i in 1200:
		if not net.multiplayer.get_peers().is_empty():
			break
		await process_frame
	check(not net.multiplayer.get_peers().is_empty(), "the joiner connected")
	# Every map, including Stonekeep Fortress (3) and Twilight Grove (4),
	# which build their own world like Ember Pass (2026-10-17).
	for v in [2, 3, 1, 4, 0]:
		await _settle()
		g = current_scene
		g.main_menu._press("play", null)
		g.main_menu._press("map_card", {0: 0, 1: 1, 2: 3, 3: 2, 4: 4}[v])
		g = await _settle()
		check(g.map_variant == v and (g.vmap != null) == (v == 2) and g.season == ["", "", "", "winter", "twilight"][v] and net.is_host(),
			"host switched to map %d and still hosts" % v)
		check(not net.multiplayer.get_peers().is_empty(), "the joiner is still in the room on map %d" % v)
		for i in 120:
			await process_frame
	net.leave()
	print("NET MAP SWITCH host: %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)
