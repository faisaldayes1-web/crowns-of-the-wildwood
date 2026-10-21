extends SceneTree

const Isolated = preload("res://tools/tests/isolated.gd")
## Walks the main menu headlessly: title -> SELECT MAP -> READY UP -> match,
## with a 2v2, a joined second player and a side switch, and checks what the
## match spawned. Run from the project root:
##     tools/tests/isolated.sh --headless --path . --script tools/menu_flow_test.gd

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _init() -> void:
	if not Isolated.ok("tools/menu_flow_test.gd"):   # it writes the save: only in a throwaway user dir
		quit(2)
		return
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for i in 5:
		await process_frame
	var m = game.main_menu
	check(m != null and m.screen == "title", "the game opens on the title")
	m._press("play", null)
	check(m.screen == "map", "PLAY opens SELECT MAP")
	# Every built map is open now (Stonekeep, card 2, since #31); the
	# Moonlit Wildwood (card 1) stays locked below account level 10.
	if game.unlocked():
		print("SKIP  a locked map cannot be picked (the Moonlit Wildwood is unlocked here)")
	else:
		m._press("map_card", 1)
		check(m.map_pick == 0, "a locked map cannot be picked")
	m._press("difficulty", "Hard")
	check(game.bot_difficulty == "Hard", "HARDCORE sets the Hard bots")
	# The live game may be fixed at 4v4 (no team size buttons); then the
	# press does nothing and the checks below expect the fixed size.
	m._press("team_size", 2)
	var size: int = game.team_size
	check(size == 2 or size == 4, "TEAM SIZE is 2v2, or fixed at 4v4 (got %d)" % size)
	m._press("to_lobby", null)
	check(m.screen == "lobby", "START MATCH opens READY UP")
	var slots: Array = m.lobby_slots()
	check(slots.size() == 4 and slots[0].kind == "local" and slots[1].kind == "bot" and slots[1].ally and not slots[2].ally,
		"solo lobby shows you, an ally bot and the enemy bots")
	m._press("side", [0, 1])
	check(game.lobby_sides[0] == 1, "player 1 switches to the Humans")
	if Input.get_connected_joypads().is_empty():
		m.add_player(-1)
		check(game.couch_players == 1, "clicking JOIN with no free controller adds nobody (one keyboard player only)")
	m.add_player(3)
	check(game.couch_players == 2 and game.split_screen and m.join_pads == [3], "a pad joins as player 2")
	m._press("split_layout", "horizontal")
	check(game.split_layout == "horizontal", "READY UP: two players can split HORIZONTAL (top and bottom)")
	m.start()
	check(not game.playing, "the match waits for player 2 to ready up")
	m._press("readied", 1)
	m._press("side", [1, 0])
	m.start()
	for i in 3:
		await process_frame
	check(game.playing, "the match starts once everyone is ready")
	check(game.units.size() == size * 2, "%dv%d spawns %d fighters (got %d)" % [size, size, size * 2, game.units.size()])
	check(game.player.team == 1 and game.locals[1].team == 0, "players 1 and 2 are on the sides they picked")
	check(game.local_pad(1) == 3, "player 2 keeps the pad they joined with")
	check(game.menu_stage == null, "the menu stage is gone")
	check(game.couch_active and not game.camera.current, "the split panes have the cameras (current=%s)" % game.camera.current)
	if game.couch_active:
		var r0: Rect2 = game.panes[0].rect
		var r1: Rect2 = game.panes[1].rect
		check(r0.position.y == 0.0 and r1.position.y > r0.end.y - 1.0 and r1.position.x == 0.0, "horizontal split: player 1 on top, player 2 below (%s, %s)" % [r0, r1])
		game.set_split_layout("vertical")
		r0 = game.panes[0].rect
		r1 = game.panes[1].rect
		check(r1.position.x > r0.end.x - 1.0 and r1.position.y == 0.0, "vertical split (switched mid-match): side by side (%s, %s)" % [r0, r1])
		check(game.panes[0].box.get_global_rect().size.x * game.panes[0].box.scale.x > 0.0, "the panes are drawn")
		# Each device drives one player: player 2's pad (3) is not bound to
		# player 1's actions, which would otherwise answer to every pad.
		var shared := false
		for action in ["move_left", "attack", "aim_right", "dodge"]:
			for ev in InputMap.action_get_events(action):
				if (ev is InputEventJoypadButton or ev is InputEventJoypadMotion) and (ev.device == -1 or ev.device == 3):
					shared = true
		check(not shared, "player 2's controller does not drive player 1")
		var own := false
		for ev in InputMap.action_get_events("p2_move_left"):
			if ev is InputEventJoypadMotion and ev.device == 3:
				own = true
		check(own, "player 2's controller drives player 2")
		# Player 1 aims with the mouse inside their own (left) pane; the
		# cursor over player 2's pane is held to player 1's edge.
		check(game.locals[0].has_mouse and not game.locals[1].has_mouse, "player 1 has the keyboard and mouse, player 2 the pad")
		var mm := InputEventMouseMotion.new()
		mm.position = Vector2(1100, 360)
		mm.global_position = mm.position
		Input.parse_input_event(mm)
		await process_frame
		var mp: Vector2 = game.mouse_for(game.locals[0])
		check(mp.x > 0.0 and mp.x <= float(game.panes[0].view.size.x) + 0.5, "the mouse over player 2's pane stays in player 1's pane (%s)" % str(mp))
		check(game.panes[0].zoom > 1.0 and game.panes[0].hud.size.y > game.panes[0].hud.size.x, "vertical split: tall panes pull the camera back and get a tall HUD")
	print("menu flow: %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)
