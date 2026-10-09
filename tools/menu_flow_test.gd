extends SceneTree
## Walks the main menu headlessly: title -> SELECT MAP -> READY UP -> match,
## with a 2v2, a joined second player and a side switch, and checks what the
## match spawned. Run from the project root:
##     godot --headless --path . --script tools/menu_flow_test.gd

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _init() -> void:
	# The menus save as they go: keep the player's own settings file safe.
	var cfg := "user://controls.cfg"
	var saved := FileAccess.get_file_as_bytes(cfg) if FileAccess.file_exists(cfg) else PackedByteArray()
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for i in 5:
		await process_frame
	var m = game.main_menu
	check(m != null and m.screen == "title", "the game opens on the title")
	m._press("play", null)
	check(m.screen == "map", "PLAY opens SELECT MAP")
	m._press("map_card", 2)
	check(m.map_pick == 0, "a coming-soon map cannot be picked")
	m._press("difficulty", "Hard")
	check(game.bot_difficulty == "Hard", "HARDCORE sets the Hard bots")
	m._press("team_size", 2)
	check(game.team_size == 2, "TEAM SIZE 2v2")
	m._press("to_lobby", null)
	check(m.screen == "lobby", "START MATCH opens READY UP")
	var slots: Array = m.lobby_slots()
	check(slots.size() == 4 and slots[0].kind == "local" and slots[1].kind == "bot" and slots[1].ally and not slots[2].ally,
		"solo lobby shows you, an ally bot and the enemy bots")
	m._press("side", [0, 1])
	check(game.lobby_sides[0] == 1, "player 1 switches to the Humans")
	m.add_player(3)
	check(game.couch_players == 2 and game.split_screen and m.join_pads == [3], "a pad joins as player 2")
	m.start()
	check(not game.playing, "the match waits for player 2 to ready up")
	m._press("readied", 1)
	m._press("side", [1, 0])
	m.start()
	for i in 3:
		await process_frame
	check(game.playing, "the match starts once everyone is ready")
	check(game.units.size() == 4, "2v2 spawns four fighters (got %d)" % game.units.size())
	check(game.player.team == 1 and game.locals[1].team == 0, "players 1 and 2 are on the sides they picked")
	check(game.local_pad(1) == 3, "player 2 keeps the pad they joined with")
	check(game.menu_stage == null, "the menu stage is gone")
	check(game.couch_active and not game.camera.current, "the split panes have the cameras (current=%s)" % game.camera.current)
	if saved.is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
	else:
		var f := FileAccess.open(cfg, FileAccess.WRITE)
		f.store_buffer(saved)
		f.close()
	print("menu flow: %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)
