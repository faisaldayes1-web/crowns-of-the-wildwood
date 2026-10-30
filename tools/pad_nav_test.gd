extends SceneTree

const Isolated = preload("res://tools/tests/isolated.gd")
## Every menu and screen on a gamepad alone: real InputEventJoypadButton /
## Motion events on device 0 (A, B, D-pad, stick, LB / RB, Start, View),
## no mouse and no direct calls. For each screen it lists what can be
## clicked, walks the D-pad graph the cursor follows (game._snap_cursor)
## from where the cursor appears, and flags any button it can't reach;
## then it drives the flow with the pad: A opens, B backs out. Also the
## rebind regression (#85 / #87): a key or pad button that is also a tab
## key binds without switching the Options tab. Run from the project root:
##     tools/tests/isolated.sh --headless --path . --script tools/pad_nav_test.gd
## claude-faisal/padnav 2026-10-30.

const Stats = preload("res://scripts/stats.gd")

var fails := 0
var game
var hud
var audit: Array = []   # [screen, buttons, reachable, A, B, notes]


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func frames(n: int = 2) -> void:
	for i in n:
		await process_frame


func jb(btn: int, dev: int = 0) -> void:
	## One press and release of a pad button.
	var e := InputEventJoypadButton.new()
	e.device = dev
	e.button_index = btn
	e.pressed = true
	e.pressure = 1.0
	Input.parse_input_event(e)
	await frames(2)
	var r := e.duplicate()
	r.pressed = false
	r.pressure = 0.0
	Input.parse_input_event(r)
	await frames(2)


func stick(x: float, y: float, dev: int = 0) -> void:
	for a in [[JOY_AXIS_LEFT_X, x], [JOY_AXIS_LEFT_Y, y]]:
		var e := InputEventJoypadMotion.new()
		e.device = dev
		e.axis = a[0]
		e.axis_value = a[1]
		Input.parse_input_event(e)


func key(code: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	Input.parse_input_event(e)
	await frames(2)
	var r := e.duplicate()
	r.pressed = false
	Input.parse_input_event(r)
	await frames(2)


func labelled() -> Array:
	## Every clickable thing on screen now, named: [rect, "list:id arg"].
	var out: Array = []
	var menu_live: Array = hud.menu_buttons
	if game.main_menu and game.main_menu.kb_from >= 0 and game.main_menu.pad_keys_on():
		for b in hud.menu_buttons.slice(game.main_menu.kb_from):   # only the letter pad answers
			out.append([b[0], ("menu:%s %s" % [b[1], str(b[2]) if b[2] != null else ""]).strip_edges()])
		return out
	if game.main_menu and game.main_menu.overlay != "" and not game.menu_open:
		menu_live = hud.menu_buttons.slice(game.main_menu.overlay_from)
	for b in menu_live:
		out.append([b[0], ("menu:%s %s" % [b[1], str(b[2]) if b[2] != null else ""]).strip_edges()])
	for pair in [["title", hud.title_buttons], ["hero", hud.hero_buttons], ["couch", hud.couch_buttons], ["bind", hud.bind_buttons],
			["difficulty", hud.difficulty_buttons], ["toggle", hud.toggle_buttons], ["guide", hud.guide_buttons], ["variant", hud.variant_buttons],
			["slider", hud.volume_sliders], ["group", hud.group_buttons], ["class", hud.class_buttons], ["zoom", hud.zoom_buttons], ["ranktab", hud.rank_tab_buttons]]:
		for b in pair[1]:
			if b[0].size.x > 0.0:
				out.append([b[0], "%s:%s" % [pair[0], str(b[1])]])
	for i in hud.tab_buttons.size():
		out.append([hud.tab_buttons[i], "tab:%d" % hud.tab_ids[i]])
	for r in hud.rank_buttons:
		if r is Rect2 and r.size.x > 0.0:
			out.append([r, "rank"])
	for pair in [["options", hud.options_button], ["close", hud.close_button], ["reset", hud.reset_button], ["quit", hud.quit_button], ["resume", hud.resume_button]]:
		if pair[1].size.x > 0.0:
			out.append([pair[1], pair[0]])
	if game.game_over and game.summary:
		out.append([game.summary.board_rect, "summary:board"])
		out.append([game.summary.continue_rect, "summary:continue"])
	return out


func _key_of(r: Rect2) -> String:
	return "%d,%d,%d,%d" % [r.position.x, r.position.y, r.size.x, r.size.y]


func reach_from(start: Vector2) -> Dictionary:
	## The buttons the D-pad can land on from `start`, each with the presses
	## that get there (game._snap_cursor, the real stepping rule).
	var keep: Vector2 = game.cursor
	var seen := {}   # centre key -> [centre, path]
	var queue: Array = [[start, []]]
	var first := true
	while not queue.is_empty():
		var at: Array = queue.pop_front()
		for d in [[Vector2.LEFT, JOY_BUTTON_DPAD_LEFT], [Vector2.RIGHT, JOY_BUTTON_DPAD_RIGHT], [Vector2.UP, JOY_BUTTON_DPAD_UP], [Vector2.DOWN, JOY_BUTTON_DPAD_DOWN]]:
			game.cursor = at[0]
			game._snap_cursor(d[0])
			var to: Vector2 = game.cursor
			if to == at[0]:
				continue
			var k := "%d,%d" % [to.x, to.y]
			if seen.has(k):
				continue
			var path: Array = at[1].duplicate()
			path.append(d[1])
			seen[k] = [to, path]
			queue.append([to, path])
		first = false
	game.cursor = keep
	return seen


func unreachable() -> Array:
	## Clickable things the D-pad can never put the cursor on.
	var start: Vector2 = game.cursor
	var seen := reach_from(start)
	var out: Array = []
	for b in labelled():
		var r: Rect2 = b[0]
		if r.has_point(start):
			continue
		var hit := false
		for v in seen.values():
			if r.has_point(v[0]):
				hit = true
				break
		if not hit:
			out.append(b[1])
	return out


func show_cursor() -> void:
	## A first pad press only shows the cursor.
	if not game.cursor_shown:
		await jb(JOY_BUTTON_DPAD_DOWN)
		await frames(2)


func goto(name_prefix: String) -> bool:
	## Steer the cursor onto the first button whose name starts with this,
	## with D-pad presses only.
	await show_cursor()
	var target := Rect2()
	for b in labelled():
		if str(b[1]) == name_prefix or str(b[1]).begins_with(name_prefix + " "):
			target = b[0]
			break
	if target.size == Vector2.ZERO:
		print("  (no button %s)" % name_prefix)
		return false
	if target.has_point(game.cursor):
		return true
	var seen := reach_from(game.cursor)
	var path: Array = []
	for v in seen.values():
		if target.has_point(v[0]) and (path.is_empty() or v[1].size() < path.size()):
			path = v[1]
	if path.is_empty():
		print("  (can't reach %s from %s)" % [name_prefix, game.cursor])
		return false
	for btn in path:
		await jb(btn)
	await frames(2)
	return target.has_point(game.cursor)


func a_on(name_prefix: String) -> bool:
	var ok := await goto(name_prefix)
	await jb(JOY_BUTTON_A)
	await frames(3)
	return ok


func record(screen: String, a_ok, b_ok, notes: String = "") -> void:
	await frames(2)
	var all := labelled()
	var gaps := unreachable()
	audit.append([screen, all.size(), all.size() - gaps.size(), a_ok, b_ok, notes if gaps.is_empty() else (notes + " unreachable: " + ", ".join(gaps)).strip_edges()])
	print("AUDIT  %-34s buttons=%d reachable=%d  A=%s B=%s  %s" % [screen, all.size(), all.size() - gaps.size(), a_ok, b_ok, audit[-1][5]])
	check(gaps.is_empty(), "%s: the D-pad reaches every button" % screen)


func _init() -> void:
	if not Isolated.ok("tools/pad_nav_test.gd"):
		quit(2)
		return
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await frames(5)
	hud = game.hud
	hud.set_anchors_preset(Control.PRESET_TOP_LEFT)
	hud.size = Vector2(1280, 720)
	while game.main_menu == null or game.menus_warming:
		await frames(1)
	await frames(5)
	var m = game.main_menu
	game.needs_name = false
	m.overlay = ""
	for it in Stats.STORE_ITEMS:
		game.owned_items.append("%s:%d" % [it[0], it[1]])
	await frames(3)

	# --- Title ---------------------------------------------------------------
	await show_cursor()
	check(game.cursor_shown, "a D-pad press shows the cursor on the title")
	await record("title", "-", "-")
	stick(0.0, 1.0)
	await frames(30)
	stick(0.0, 0.0)
	await frames(2)
	check(game.cursor_shown, "the stick steers the cursor")

	# Title buttons that open a screen or overlay, then B comes back.
	for t in [["menu:customize", "screen", "character"], ["menu:store", "screen", "store"], ["menu:play", "screen", "map"],
			["menu:online", "screen", "online"], ["menu:players", "overlay", "players"], ["menu:progress", "overlay", "progress"],
			["menu:credits", "overlay", "credits"], ["menu:tutorial", "overlay", "howto"]]:
		m.go("title")
		m.overlay = ""
		await frames(3)
		var reached := await a_on(t[0])
		var got: String = m.screen if t[1] == "screen" else m.overlay
		check(reached and got == t[2], "title %s: the cursor gets there and A opens %s (got %s)" % [t[0], t[2], got])
		await record("%s (%s)" % [t[2], t[1]], reached and got == t[2], "?")
		if t[2] == "character":
			for tab in 6:
				var ok_tab := await a_on("menu:char_tab %d" % tab)
				check(ok_tab and m.char_tab == tab, "Customize: A on tab %d opens it" % tab)
				await record("customize tab %d" % tab, ok_tab and m.char_tab == tab, "?")
		if t[2] == "store":
			for tab in m.store.TABS.size():
				var ok_tab := await a_on("menu:store_tab %d" % tab)
				check(ok_tab and m.store.tab == tab, "Store: A on tab %d opens it" % tab)
				await record("store tab %d" % tab, ok_tab and m.store.tab == tab, "?")
			# BUY an item (one not owned), EQUIP it, open a chest and close the reveal.
			var it: Array = Stats.STORE_ITEMS[1]
			game.owned_items.erase("%s:%d" % [it[0], it[1]])
			game.account_gold = 999999
			m.open_store(it[0], it[1])
			await frames(3)
			await show_cursor()
			check(await a_on("menu:store_buy"), "Store: the cursor reaches BUY")
			check(m.store.owns(game, it[0], it[1]), "Store: A on BUY buys the item")
			await frames(3)
			if await a_on("menu:store_equip"):
				check(true, "Store: the cursor reaches EQUIP")
			game.account_chests = 1
			await frames(3)
			check(await a_on("menu:store_chest"), "Store: the cursor reaches OPEN")
			check(not m.store.reveal.is_empty(), "Store: A on OPEN opens a chest")
			await record("store chest reveal", not m.store.reveal.is_empty(), "?")
			var t_rev := Time.get_ticks_msec() + 1200
			while Time.get_ticks_msec() < t_rev:
				await frames(1)
			await jb(JOY_BUTTON_A)
			await frames(3)
			check(m.store.reveal.is_empty() and m.screen == "store", "Store: A closes the reveal")
		if t[2] == "howto":
			for i in m.HOWTO.size() + 1:
				if m.overlay != "howto":
					break
				await record("how to play card %d" % m.howto_step, "?", "?")
				await jb(JOY_BUTTON_RIGHT_SHOULDER)
		await jb(JOY_BUTTON_B)
		await frames(3)
		var back_ok: bool = m.screen == "title" and m.overlay == ""
		if not back_ok:
			await jb(JOY_BUTTON_B)
			await frames(3)
		check(m.screen == "title" and m.overlay == "", "B from %s comes back to the title" % t[2])
		audit[audit.size() - 1][4] = back_ok

	# --- Naming a hero on a pad: the letter pad --------------------------------
	m.go("title")
	await frames(3)
	await a_on("menu:players")
	check(m.overlay == "players", "PLAYERS opens")
	var old_name: String = game.hero_name
	check(await a_on("hero:name"), "Players: the cursor reaches the name field")
	await frames(3)
	check(game.name_editing and m.pad_keys_on(), "Players: A on the name field opens the letter pad")
	await record("name letter pad", game.name_editing, "?")
	var typed: String = old_name + m._name_case("B")
	await a_on("menu:name_key B")
	check(game.hero_name == typed, "Letter pad: A types a letter (%s)" % game.hero_name)
	await jb(JOY_BUTTON_B)
	await frames(3)
	check(game.hero_name == old_name and game.name_editing and m.overlay == "players", "Letter pad: B rubs out a letter and stays")
	await a_on("menu:name_done")
	await frames(3)
	check(not game.name_editing and m.overlay == "players" and game.hero_name == (old_name if old_name != "" else "Hero"), "Letter pad: DONE keeps the name and stays on PLAYERS")
	await jb(JOY_BUTTON_B)
	await frames(3)
	check(m.overlay == "", "B closes PLAYERS")

	# --- Map select and Ready Up ---------------------------------------------
	m.go("title")
	await frames(3)
	await a_on("menu:play")
	await record("map select", m.screen == "map", "?")
	await a_on("menu:difficulty Hard")
	check(game.bot_difficulty == "Hard", "Map select: A picks a difficulty")
	await a_on("menu:split true")
	check(game.split_screen, "Map select: A turns split screen on")
	var first: int = m.map_first
	await a_on("menu:map_page 1")
	check(m.map_first != first or m.MAP_CARDS.size() <= m.map_cols, "Map select: the right arrow pages the cards")
	await a_on("menu:to_lobby")
	check(m.screen == "lobby", "Map select: START MATCH opens Ready Up")
	await record("ready up", m.screen == "lobby", "?")
	for dev in [1, 2, 3]:
		await jb(JOY_BUTTON_A, dev)
	check(game.couch_players == 4, "Ready Up: pads 1-3 join with A (players %d)" % game.couch_players)
	await record("ready up, 4 players", "?", "?")
	await jb(JOY_BUTTON_B, 2)
	check(game.couch_players == 3, "Ready Up: a joined pad leaves with B")
	for dev in [1, 3]:
		await jb(JOY_BUTTON_B, dev)
	await jb(JOY_BUTTON_B)
	await frames(3)
	check(m.screen == "map", "Ready Up: B goes back to map select")
	await a_on("menu:split false")
	await jb(JOY_BUTTON_B)
	await frames(3)
	check(m.screen == "title", "Map select: B goes back to the title")

	# --- Options from the title ----------------------------------------------
	await a_on("menu:settings")
	check(game.menu_open, "title OPTIONS opens the options board")
	var tabs: Array = game.menu_tabs()
	for i in tabs.size():
		await frames(3)
		await record("options tab %d" % game.menu_tab, "?", "?")
		await jb(JOY_BUTTON_RIGHT_SHOULDER)
	check(game.menu_tab == tabs[0], "RB cycles every options tab and wraps")
	await jb(JOY_BUTTON_B)
	await frames(3)
	check(not game.menu_open, "B closes the options board")

	# --- Options controls: toggles, sliders, rebinding, RESET ----------------
	await a_on("menu:settings")
	game.menu_tab = 5
	await frames(3)
	var shake: bool = game.screen_shake
	if await a_on("toggle:shake"):
		check(game.screen_shake != shake, "Options: A flips a toggle (screen shake)")
	var vs: bool = game.vsync_on
	if await a_on("toggle:vsync"):
		check(game.vsync_on != vs, "Options: A flips VSync")
	var wm: String = game.window_mode
	if await a_on("toggle:fullscreen"):
		check(game.window_mode != wm, "Options: A steps Display")
	if await a_on("toggle:fullscreen"):
		pass
	if await a_on("toggle:fullscreen"):
		pass
	var gq: int = game.gfx_quality
	if await a_on("toggle:gfx_%d" % ((gq + 1) % 4)):
		check(game.gfx_quality == (gq + 1) % 4, "Options: A picks a Graphics level")
	var tab_now: int = game.menu_tab
	var sound: float = game.sfx.sound_volume
	if await goto("slider:sound"):
		await jb(JOY_BUTTON_DPAD_LEFT)
		check(game.sfx.sound_volume < sound - 0.01, "Options: D-pad left on the sound slider turns it down (%.2f -> %.2f)" % [sound, game.sfx.sound_volume])
		sound = game.sfx.sound_volume
		await jb(JOY_BUTTON_DPAD_RIGHT)
		check(game.sfx.sound_volume > sound + 0.01, "Options: D-pad right on the sound slider turns it up")
	check(game.menu_tab == tab_now, "Options: the slider keys don't switch tabs")
	game.menu_tab = 6
	await frames(3)
	var music: float = game.sfx.music_volume
	if await goto("slider:music"):
		await jb(JOY_BUTTON_DPAD_LEFT)
		check(game.sfx.music_volume < music - 0.01, "Audio: D-pad left on the music slider turns it down")
	# Controls: rebind Move up to keyboard A (also menu_left): the tab stays (#85).
	game.menu_tab = 4
	hud.controls_group = 0
	await frames(3)
	await record("options controls, group 0", "?", "?")
	for g in hud.group_buttons.size():
		await a_on("group:%d" % g)
		check(hud.controls_group == g, "Controls: A opens action group %d" % g)
		await record("options controls, group %d" % g, true, "?")
	await a_on("group:1")
	check(await a_on("bind:move_up"), "Controls: the cursor reaches the Move up row")
	check(game.rebinding == "move_up", "Controls: A on a row waits for a key")
	await key(KEY_A)
	await frames(3)
	check(game.rebinding == "", "Controls: keyboard A binds Move up")
	check(game.binding_text("move_up", "key").contains("A"), "Controls: Move up shows A (%s)" % game.binding_text("move_up", "key"))
	check(game.menu_tab == 4, "Controls: binding A (a tab key) keeps the Controls tab (tab %d)" % game.menu_tab)
	# The same with a pad button that is also RB (menu_right).
	game.menu_tab = 4
	await a_on("group:3")
	check(await a_on("bind:interact"), "Controls: the cursor reaches the Interact row")
	check(game.rebinding == "interact", "Controls: A on Interact waits for a button")
	await jb(JOY_BUTTON_RIGHT_SHOULDER)
	await frames(3)
	check(game.rebinding == "", "Controls: RB binds Interact")
	check(game.menu_tab == 4, "Controls: binding RB (a tab button) keeps the Controls tab (tab %d)" % game.menu_tab)
	# Binding the pad A itself must not click whatever is under the cursor.
	var at_row: Vector2 = game.cursor
	game.menu_tab = 4
	await a_on("group:1")
	check(await a_on("bind:dodge"), "Controls: the cursor reaches the Dodge row")
	at_row = game.cursor
	check(game.rebinding == "dodge", "Controls: A on Dodge waits for a button")
	await jb(JOY_BUTTON_A)
	await frames(3)
	check(game.rebinding == "" and game.pad_label("dodge", "xbox") == "A", "Controls: pad A binds Dodge (%s)" % game.pad_label("dodge", "xbox"))
	check(game.menu_tab == 4 and game.cursor == at_row, "Controls: that A press stays on the row (tab %d, cursor moved %s)" % [game.menu_tab, game.cursor != at_row])
	game.menu_tab = 4
	await frames(3)
	check(await a_on("reset"), "Controls: the cursor reaches RESET")
	await frames(3)
	check(game.binding_text("move_up", "key").contains("W") and game.pad_label("dodge", "xbox") == "B", "Controls: RESET puts the defaults back")
	await jb(JOY_BUTTON_B)
	await frames(3)
	check(not game.menu_open, "B closes the options board")

	# --- In the match ----------------------------------------------------------
	m.start()
	var deadline := Time.get_ticks_msec() + 60000
	while not (game.playing and game.player != null) and Time.get_ticks_msec() < deadline:
		await frames(1)
	check(game.playing, "the match starts")
	await frames(10)
	hud = game.hud
	await jb(JOY_BUTTON_START)
	await frames(3)
	check(game.menu_open, "Start pauses")
	await show_cursor()
	var mtabs: Array = game.menu_tabs()
	var tab0: int = game.menu_tab
	for i in mtabs.size():
		await frames(3)
		await record("pause tab %d" % game.menu_tab, "?", "?")
		await jb(JOY_BUTTON_RIGHT_SHOULDER)
	check(game.menu_tab == tab0, "RB cycles every pause tab and wraps")
	game.menu_tab = 0
	await frames(3)
	var z: float = hud.map_zoom
	if await a_on("zoom:1"):
		check(hud.map_zoom > z, "Pause map: A on + zooms in")
	check(await a_on("quit"), "Pause: the cursor reaches LEAVE MATCH")
	check(game.quit_armed > 0.0 and game.playing, "Pause: one A on LEAVE MATCH only arms it")
	check(await a_on("resume"), "Pause: the cursor reaches RESUME")
	check(not game.menu_open, "Pause: A on RESUME resumes")
	await jb(JOY_BUTTON_START)
	await frames(3)
	await jb(JOY_BUTTON_B)
	await frames(3)
	check(not game.menu_open, "Pause: B resumes")
	# Perks / upgrades (R3).
	game.player.points = 3
	await jb(JOY_BUTTON_RIGHT_STICK)
	await frames(3)
	check(game.rank_open, "R3 opens UPGRADES")
	var lv: int = game.player.total_upgrades()
	await jb(JOY_BUTTON_A)
	await frames(3)
	check(game.player.total_upgrades() > lv or game.player.points < 3, "UPGRADES: A buys the highlighted perk")
	await jb(JOY_BUTTON_B)
	await frames(3)
	check(not game.rank_open, "UPGRADES: B closes")
	# The Guide's menu.
	game.guide_seen = true
	var gd = game.guides[game.player.team]
	game.player.global_position = gd.global_position + Vector3(1.2, 0, 0)
	await frames(3)
	game.guide_toggle()
	await frames(3)
	check(game.guide_open, "the Guide opens")
	await show_cursor()
	await record("guide menu", "?", "?")
	if await a_on("guide:0"):
		check(game.guide_topic == 0, "Guide: A picks a topic")
	await jb(JOY_BUTTON_B)
	await frames(3)
	if game.guide_open:
		await jb(JOY_BUTTON_B)
		await frames(3)
	check(not game.guide_open, "Guide: B closes")
	# End of the match: the summary takes buttons, not the cursor.
	game._finish(0)
	await frames(10)
	var sm = game.summary
	var board: bool = sm.show_board
	await jb(JOY_BUTTON_BACK)
	check(sm.show_board != board, "Summary: View flips the scoreboard")
	await jb(JOY_BUTTON_A)
	check(not sm.done(), "Summary: an A in its first second (a mashed attack) does nothing")
	var t_end := Time.get_ticks_msec() + 1500
	while Time.get_ticks_msec() < t_end:
		await frames(1)
	await jb(JOY_BUTTON_A)
	check(sm.done(), "Summary: A skips the tally")
	audit.append(["match summary", 2, 2, "A skips / continues", "B skips / continues", "View flips the board; no cursor needed"])

	print("\n--- AUDIT TABLE ---")
	for row in audit:
		print("| %s | %d | %d | %s | %s | %s |" % row)
	print("%d failure(s)" % fails)
	quit(1 if fails > 0 else 0)
