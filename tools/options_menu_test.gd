extends SceneTree

const Isolated = preload("res://tools/tests/isolated.gd")
## Clicks every control of the main menu, the OPTIONS board and the in-match
## PAUSED board headlessly and checks each one does what it says and is
## saved. Taps go through game.touch_tap, the same path a click or a finger
## takes, at the centre of the rect the HUD drew. Run from the project root:
##     tools/tests/isolated.sh --headless --path . --script tools/options_menu_test.gd

const Stats = preload("res://scripts/stats.gd")

var fails := 0
var game
var hud


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func frames(n: int = 2) -> void:
	for i in n:
		await process_frame


func tap(r: Rect2) -> void:
	game.touch_tap = r.get_center()
	await frames(3)


func saved(section: String, key: String):
	var cfg := ConfigFile.new()
	cfg.load("user://controls.cfg")
	return cfg.get_value(section, key)


func press(action: String) -> void:
	Input.action_press(action)
	await frames(2)
	Input.action_release(action)
	await frames(2)


func find3(list: Array, key, arg) -> Rect2:
	for b in list:
		if b[1] == key and b[2] == arg:
			return b[0]
	return Rect2()


func find(list: Array, key) -> Rect2:
	for b in list:
		if b[1] == key:
			return b[0]
	return Rect2()


func _init() -> void:
	if not Isolated.ok("tools/options_menu_test.gd"):   # it writes the save: only in a throwaway user dir
		quit(2)
		return
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game   # so LEAVE MATCH can reload it like the real game
	await frames(5)
	hud = game.hud
	# Headless has no real window: give the HUD the game's 16:9 canvas.
	hud.set_anchors_preset(Control.PRESET_TOP_LEFT)
	hud.size = Vector2(1280, 720)
	await frames(3)
	var m = game.main_menu
	# STORE items (scripts/store.gd) open the store until bought: own them all
	# so every Create Your Character choice can be tried.
	for it in Stats.STORE_ITEMS:
		game.owned_items.append("%s:%d" % [it[0], it[1]])

	# --- Main menu: every title button does something --------------------
	var ids := {}
	for b in hud.menu_buttons:
		ids[b[1]] = b[0]
	for id in ["play", "customize", "settings", "tutorial", "credits", "progress", "exit"]:
		check(ids.has(id), "title has the %s button" % id)
	await tap(ids.get("play", Rect2()))
	check(m.screen == "map", "PLAY opens SELECT MAP")
	m.go("title")
	await frames()
	await tap(ids.get("customize", Rect2()))
	await frames()
	check(m.screen == "character", "CUSTOMIZE opens Create Your Character")
	# Every tab of the character screen and every swatch on it.
	for t in 6:
		m.char_tab = t
		await frames()
		var tried := 0
		var dead: Array = []
		for b in hud.menu_buttons.duplicate():
			if b[1] in ["back", "confirm", "char_tab"] or b[0].size.x <= 0.0:
				continue
			var before := [game.hero_body, game.hero_skin, game.hero_face, game.hero_eye, game.hero_mark, game.hero_hair, game.hero_hair_style,
				game.hero_trim, game.hero_look, game.banner_bg, game.banner_emblem, game.banner_frame, m.preview_team, m.preview_role, m.preview_rank, m.char_tab,
				game.hero_outfit, game.hero_hat, game.hero_cape, game.hero_weapon, m.stage.hero_turn_goal if m.stage else 0.0, m.armor_cat, m.armor_page]
			await tap(b[0])
			var after := [game.hero_body, game.hero_skin, game.hero_face, game.hero_eye, game.hero_mark, game.hero_hair, game.hero_hair_style,
				game.hero_trim, game.hero_look, game.banner_bg, game.banner_emblem, game.banner_frame, m.preview_team, m.preview_role, m.preview_rank, m.char_tab,
				game.hero_outfit, game.hero_hat, game.hero_cape, game.hero_weapon, m.stage.hero_turn_goal if m.stage else 0.0, m.armor_cat, m.armor_page]
			tried += 1
			if before == after and not _already(b, before):
				dead.append("%s %s" % [b[1], str(b[2])])
			m.char_tab = t
			m.screen = "character"
			await frames()
		check(dead.is_empty(), "character tab %d: %d controls all respond%s" % [t, tried, "" if dead.is_empty() else " (dead: %s)" % ", ".join(dead)])
	for b in hud.menu_buttons:
		if b[1] == "char_tab" and int(b[2]) == 2:
			await tap(b[0])
	check(m.char_tab == 2, "a character tab button switches tab")
	if m.stage:
		var turn0: float = m.stage.hero_turn_goal
		await tap(find3(hud.menu_buttons, "hero_turn", 1))
		check(is_equal_approx(m.stage.hero_turn_goal, turn0 + PI / 4.0), "the right turn arrow spins the hero 45 degrees")
		await tap(find3(hud.menu_buttons, "hero_turn", -1))
		check(is_equal_approx(m.stage.hero_turn_goal, turn0), "the left turn arrow spins it back")
	m.go("title")
	await frames()
	await tap(ids.get("tutorial", Rect2()))
	check(m.overlay == "howto" and m.howto_step == 0, "TUTORIAL opens the HOW TO PLAY cards")
	await frames()
	for b in hud.menu_buttons:
		if b[1] == "howto_step" and int(b[2]) == 1:
			await tap(b[0])
			break
	check(m.howto_step == 1, "NEXT turns to the second card")
	await frames()
	for b in hud.menu_buttons:
		if b[1] == "howto_step" and int(b[2]) == -1:
			await tap(b[0])
			break
	check(m.howto_step == 0, "BACK turns back to the first card")
	await frames()
	for b in hud.menu_buttons:
		if b[1] == "howto_more":
			await tap(b[0])
			break
	check(m.overlay == "tutorial" and game.howto_seen, "MORE QUESTIONS opens the questions (and marks the cards seen)")
	await frames()
	for b in hud.menu_buttons:
		if b[1] == "topic" and int(b[2]) == 2:
			await tap(b[0])
			break
	check(m.tutorial_topic == 2, "a tutorial topic opens")
	var pics := 0
	for i in 6:
		pics += 1 if m.tutorial_image(i) != null else 0
	check(pics == 6, "every tutorial topic has its gameplay picture (%d / 6)" % pics)
	for b in hud.menu_buttons:
		if b[1] == "close":
			await tap(b[0])
			break
	check(m.overlay == "", "the tutorial closes")
	for id in ["credits", "progress", "players"]:
		await tap(ids.get(id, Rect2()))
		check(m.overlay == id, "%s opens" % id.to_upper())
		if id == "progress":
			# SAVED PROGRESS: EXPORT saves and makes a code; IMPORT with an
			# empty clipboard changes nothing.
			await frames()
			var pb := {}
			for b in hud.menu_buttons:
				pb[b[1]] = b[0]
			check(pb.has("progress_export") and pb.has("progress_import"), "PROGRESS has EXPORT CODE and IMPORT CODE")
			var xp_was: int = game.account_xp
			game.saved_at = -1.0
			await tap(pb.get("progress_export", Rect2()))
			check(game.saved_at >= 0.0, "EXPORT CODE saves the progress")
			await tap(pb.get("progress_import", Rect2()))
			check(game.account_xp == xp_was and m.overlay == "progress", "IMPORT CODE with no code keeps the progress")
		m.overlay = ""
		await frames()
	await tap(ids.get("exit", Rect2()))
	check(m.exit_armed > 0.0, "EXIT asks to be clicked again (and does not quit on one click)")
	m.exit_armed = 0.0

	# --- OPTIONS: dedicated native screen -----------------------------------
	await tap(ids.get("settings", Rect2()))
	await frames(4)
	check(game.menu_open and game.options_screen.active, "SETTINGS opens dedicated OPTIONS")
	var options = game.options_screen
	check(options.TABS == ["Gameplay", "Video", "Audio", "Controls", "Accessibility"], "OPTIONS has exactly the five requested categories")
	for i in options.tabs.size():
		await native_tap(options.tabs[i])
		check(options.category == i, "the %s tab opens by mouse" % options.TABS[i])
	await _settings_page("OPTIONS")
	options.select_tab(2)
	await frames()
	await native_tap(options.row_controls.test)
	var heard := false
	for pl in game.sfx.pool_ui:
		if pl.playing and pl.stream == game.sfx.streams.get("ui_open"):
			heard = true
	check(heard, "Audio test sound plays a real clip")
	await _controls_page()
	options.close_screen()
	await frames()
	check(not game.menu_open, "Back closes title OPTIONS")
	# The legacy class viewer remains a separately owned, read-only page.
	game.menu_open = true
	game.menu_tab = 1
	await frames()
	check(hud.class_buttons.is_empty(), "Classes viewer at the title still has no SELECT buttons")
	await tap(hud.close_button)
	check(not game.menu_open, "the class viewer closes normally")

	# --- In a match: the PAUSED board --------------------------------------
	m._press("play", null)
	m._press("team_size", 1)
	m._press("to_lobby", null)
	m.start()
	var match_deadline := Time.get_ticks_msec() + 120000
	while not game.playing or is_instance_valid(game.loading_layer):
		if Time.get_ticks_msec() > match_deadline:
			check(false, "match loading art retires before paused mouse checks")
			quit(1)
			return
		await frames(1)
	check(game.playing, "a 1v1 match starts")
	var p = game.player
	game.menu_open = true
	game.get_tree().paused = true
	game.menu_tab = 0
	await frames()
	check(hud.tab_ids == [0, 3, 1, 2, 4, 5], "PAUSED has Map, Scoreboard, Classes, Upgrades, Controls, Settings (%s)" % str(hud.tab_ids))
	for i in hud.tab_ids.size():
		var want: int = hud.tab_ids[i]
		await tap(hud.tab_buttons[i])
		check(game.menu_tab == want, "pause: the %s tab opens" % hud.TABS[want])
		if game.options_screen.active:
			game.options_screen.close_screen()
			await frames()
	game.menu_tab = 0
	await frames()
	var z0: float = hud.map_zoom
	await tap(find(hud.zoom_buttons, 1))
	check(hud.map_zoom > z0, "map: + zooms in (%.1f)" % hud.map_zoom)
	await tap(find(hud.zoom_buttons, -1))
	check(is_equal_approx(hud.map_zoom, z0), "map: - zooms out")
	# Upgrades: spend a point, view another class, promote.
	game.menu_tab = 2
	p.points = 4
	await frames()
	check(hud.rank_buttons.size() == 4, "upgrades: four skill rows with + buttons")
	await tap(hud.rank_buttons[3])
	check(p.points == 3 and p.ranks.get(p.role, [0, 0, 0, 0])[3] == 1, "upgrades: + on Vigor spends a point (points %d)" % p.points)
	await tap(find(hud.rank_tab_buttons, Stats.Role.MAGE))
	check(hud.rank_view == Stats.Role.MAGE, "upgrades: a class in CLASS UPGRADES opens its skills")
	hud.rank_view = -1
	p.set_role(Stats.Role.KNIGHT)
	p.points = 3
	await frames()
	for t in 3:
		await tap(hud.rank_buttons[t])
	check(p.variant_unlocked(Stats.Role.KNIGHT), "upgrades: three points in a class unlock its promotion")
	await frames()
	check(hud.variant_buttons.size() == 2, "upgrades: both promotion cards can be picked")
	if hud.variant_buttons.size() > 0:
		await tap(hud.variant_buttons[0][0])
	check(p.variants.get(Stats.Role.KNIGHT, -1) == 0, "upgrades: clicking a promotion card promotes")
	# Classes: SELECT works in the spawn courtyard.
	p.set_role(Stats.Role.BASE)
	p.global_position = game.seals[p.team][Stats.Role.RANGER].global_position + Vector3(1.0, 0, 0)
	game.menu_open = true
	game.get_tree().paused = true
	game.menu_tab = 1
	await frames(3)
	var sel: Rect2 = find(hud.class_buttons, Stats.Role.HEALER)
	check(sel.size.x > 0.0, "classes: SELECT is live in the spawn courtyard")
	await tap(sel)
	check(p.role == Stats.Role.HEALER and not game.menu_open, "classes: SELECT puts the class on and closes the menu")
	game.menu_open = true
	game.get_tree().paused = true
	game.menu_tab = 5
	await frames()
	await _settings_page("PAUSED")
	await _controls_page()
	game.options_screen.close_screen()
	game.menu_tab = 0
	await frames()
	await tap(hud.quit_button)
	check(game.quit_armed > 0.0 and game.playing, "LEAVE MATCH asks to be clicked again")
	await tap(hud.resume_button)
	check(not game.menu_open and not game.get_tree().paused, "RESUME closes the menu and unpauses")
	# The perk key's UPGRADES board.
	game.rank_open = true
	game.rank_player = p
	await frames()
	check(hud.rank_buttons.size() == 4 and hud.close_button.size.x > 0.0, "the perk key opens the UPGRADES board")
	await tap(hud.close_button)
	check(not game.rank_open, "its X closes it")
	# UPGRADES on a gamepad: the D-pad moves the lit row, A buys it, B closes.
	game.pad_active = true
	p.points = 3
	game.rank_open = true
	game.rank_player = p
	await frames(3)
	var lit: int = hud.rank_focus
	await press(p.act_prefix + "rank_4")
	check(hud.rank_focus == mini(lit + 1, 4), "pad: D-pad down lights the next row (%d -> %d)" % [lit, hud.rank_focus])
	await press(p.act_prefix + "rank_1")
	check(hud.rank_focus == lit, "pad: D-pad up goes back")
	var r0: int = p.rank(hud.rank_focus)
	await press(p.act_prefix + "attack")
	check(p.rank(hud.rank_focus) == r0 + 1, "pad: A buys the lit skill")
	check(hud.rank_flash.has(hud.rank_focus), "pad: the bought row flashes")
	await press(p.act_prefix + "rank_6")
	check(hud.rank_view != -1, "pad: RB flips to another class")
	await press(p.act_prefix + "rank_5")
	check(hud.rank_view == -1, "pad: LB flips back")
	await press(p.act_prefix + "dodge")
	check(not game.rank_open, "pad: B closes the board")
	game.pad_active = false
	await frames()
	# Quick upgrades: 1-4 / the D-pad / the LEVEL UP tiles buy a rank in the
	# field once out of the fight for a few seconds.
	p.points = 3
	p.combat_at = -100.0
	await frames(3)
	check(hud.quick_buttons.size() > 0, "quick upgrade: LEVEL UP tiles show with points to spend (%d)" % hud.quick_buttons.size())
	var qt: int = hud.quick_buttons[0][1] if hud.quick_buttons.size() > 0 else 0
	var q0: int = p.rank(qt)
	await press(p.act_prefix + "rank_%d" % (qt + 1))
	check(p.rank(qt) == q0 + 1 and not game.rank_open, "quick upgrade: its key buys a rank without opening the board")
	await frames(2)
	if hud.quick_buttons.size() > 0:
		var qt2: int = hud.quick_buttons[0][1]
		var q2: int = p.rank(qt2)
		await tap(hud.quick_buttons[0][0])
		check(p.rank(qt2) == q2 + 1, "quick upgrade: clicking its tile buys it")
	p.points = 2
	p.combat_at = Time.get_ticks_msec() / 1000.0
	await frames(2)
	var qr: Array = [p.rank(0), p.rank(1), p.rank(2), p.rank(3)]
	await press(p.act_prefix + "rank_4")
	check([p.rank(0), p.rank(1), p.rank(2), p.rank(3)] == qr and hud.quick_deny > 0.0, "quick upgrade: refused while in combat")
	p.combat_at = -100.0
	await frames()
	# The HUD corner squares: the map opens the pause menu, the list the scoreboard tab.
	check(hud.corner_buttons.size() == 2, "HUD corner: two buttons (map, scoreboard; the dead bag is gone)")
	for want in [["menu", 0], ["scoreboard", 3]]:
		await tap(find(hud.corner_buttons, want[0]))
		check(game.menu_open and game.menu_tab == want[1], "HUD corner: %s opens the pause menu on tab %d" % want)
		game.menu_open = false
		game.get_tree().paused = false
		await frames()
	# Touch: every ability tile and corner square presses its action. The
	# first touch switches the HUD to its touch layout, so switch first and
	# read the tiles that layout draws.
	game.touch_active = true
	game.touch.active = true
	await frames(3)
	var tiles: Array = hud.touch_rects.duplicate()
	check(tiles.size() >= 6, "touch: the HUD lists its tiles (%d)" % tiles.size())
	for e in tiles:
		if e[1] is Callable:
			continue   # a close X (tools/touch_close_test.gd checks those)
		if e[1] in ["menu", "scoreboard", "rank_menu", "interact"]:
			continue   # these open screens or grab; checked above
		# A rank tile spends a point, and the LEVEL UP strip re-lays itself
		# out at once: find this tile where the HUD has it now.
		var now_at: Array = hud.touch_rects.filter(func(t): return typeof(t[1]) == TYPE_STRING and t[1] == e[1])
		if now_at.is_empty():
			continue
		game.touch._down(7, now_at[0][0].get_center())
		if e[1] == "quick_tap":
			# A LEVEL UP buy tile is a tap (handled like a click), not a held action.
			check(game.touch_tap != Vector2(-1, -1), "touch: the quick_tap tile taps")
			game.touch._up(7)
			game.touch_tap = Vector2(-1, -1)
			continue
		# The attack tile is also the aim pad (aim_id) on the touch layout.
		var act: String = game.touch.held.get(7, "")
		if act == "" and game.touch.get("aim_id") == 7:
			act = String(game.touch._prefix()) + "attack" if game.touch.has_method("_prefix") else "attack"
		check(act != "" and Input.is_action_pressed(act), "touch: the %s tile presses %s" % [e[1], act])
		game.touch._up(7)
		if act != "":
			Input.action_release(act)
		await frames()
	# Downed (when the build has it): hold interact to skip to the respawn.
	if "downed" in p and p.has_method("_go_down") and p.downed_enabled():
		p.global_position = Vector3(0, 0.5, 0)   # out in the middle, away from teammates who would revive
		await frames(2)
		p._go_down(null)
		await frames(40)
		check(p.downed and not p.dead, "downed: losing the last heart downs you")
		Input.action_press("interact")
		# Physics ticks run behind process frames headlessly: wait on the
		# outcome (well past DOWNED_SKIP_HOLD) rather than a frame count.
		for i in 1500:
			if p.dead:
				break
			await frames(1)
		Input.action_release("interact")
		check(p.dead, "downed: holding the skip button respawns you")
		await frames(5)
	# LEAVE MATCH twice goes back to the title.
	game.menu_open = true
	game.menu_tab = 0
	await frames()
	await tap(hud.quit_button)
	await tap(hud.quit_button)
	await frames(3)
	check(not is_instance_valid(game) or not game.playing, "LEAVE MATCH clicked twice goes back to the title")
	# The end-of-match summary's two buttons (taps reach them too, for the iPad).
	await frames(5)
	game = current_scene
	hud = game.hud
	hud.set_anchors_preset(Control.PRESET_TOP_LEFT)
	hud.size = Vector2(1280, 720)
	m = game.main_menu
	m._press("play", null)
	m._press("to_lobby", null)
	m.start()
	await frames(10)
	game._finish(0)
	await frames(10)
	var sm = game.summary
	check(sm != null, "the match ends on the summary")
	if sm:
		var shown: bool = sm.show_board
		await tap(sm.board_rect)
		check(sm.show_board != shown, "summary: SCOREBOARD switches the view")
		await tap(sm.board_rect)
		if not sm.done():
			await tap(sm.continue_rect)
			check(sm.done(), "summary: the first CONTINUE skips the tally")
		await tap(sm.continue_rect)
		await frames(3)
		check(not is_instance_valid(game) or not game.game_over, "summary: CONTINUE goes back to the title")

	print("options menu: %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)


func _already(b: Array, before: Array) -> bool:
	## A swatch that is already the current choice changes nothing.
	match b[1]:
		"armor_cat": return int(before[-2]) == int(b[2])
		"body": return game.hero_body == int(b[2])
		"skin": return game.hero_skin == int(b[2])
		"face": return game.hero_face == int(b[2])
		"eye": return game.hero_eye == int(b[2])
		"mark": return game.hero_mark == int(b[2])
		"hair": return game.hero_hair == int(b[2])
		"hair_style": return game.hero_hair_style == int(b[2])
		"trim": return game.hero_trim == int(b[2])
		"look": return game.hero_look == int(b[2]) or not game.unlocked()
		"banner_bg": return game.banner_bg == int(b[2])
		"preview_team": return game.main_menu.preview_team == int(b[2])
		"preview_role": return game.main_menu.preview_role == int(b[2])
		"rank": return game.main_menu.preview_rank == int(b[2])
		"gear": return game.get({"outfit": "hero_outfit", "hat": "hero_hat", "cape": "hero_cape", "weapon": "hero_weapon"}[b[2][0]]) == int(b[2][1])
	return false


func native_tap(control: Control, fraction := 0.5) -> void:
	if game.options_screen.rows.is_ancestor_of(control):
		game.options_screen.scroll.ensure_control_visible(control)
	await frames(3)
	var rect := control.get_global_rect()
	var at := Vector2(rect.position.x + rect.size.x * fraction, rect.get_center().y)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.position = at
	ev.global_position = at
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT
	ev.pressed = true
	# These coordinates are in the control's viewport, independent of the
	# physical window/work-area size (including the headless display).
	root.push_input(ev, true)
	await frames(2)
	ev = ev.duplicate()
	ev.pressed = false
	ev.button_mask = 0
	root.push_input(ev, true)
	await frames(2)


func _settings_page(where: String) -> void:
	var options = game.options_screen
	for item in [[0, "chat", "chat_visible", "chat_visible"], [0, "rosters", "rosters_visible", "rosters_shown"],
		[4, "shake", "screen_shake", "screen_shake"], [4, "numbers", "damage_numbers", "damage_numbers"],
		[4, "fps", "show_fps", "show_fps"], [4, "rumble", "rumble_on", "rumble"]]:
		options.select_tab(item[0])
		await frames()
		var was: bool = game.get(item[2])
		await native_tap(options.row_controls[item[1]])
		check(game.get(item[2]) != was and saved("settings", item[3]) == game.get(item[2]), "%s: %s changes and saves" % [where, item[1]])
		await native_tap(options.row_controls[item[1]])
	options.select_tab(0)
	for i in 3:
		await native_tap(options.row_controls.difficulty)
		check(saved("settings", "bot_difficulty") == game.bot_difficulty, "%s: bot difficulty persists" % where)
	for layout in ["horizontal", "vertical"]:
		await native_tap(options.row_controls.split)
		check(game.split_layout == layout and saved("settings", "split_layout") == layout, "%s: split layout %s persists" % [where, layout])
	options.select_tab(1)
	for q in 4:
		options.draft.gfx_quality = q
		options.draft.gfx_picked = true
		options._update_footer()
		await native_tap(options.apply_button)
		check(options.preview_left > 0.0, "%s: quality %d awaits confirmation" % [where, q])
		await native_tap(options.keep_button)
		check(game.gfx_quality == q and saved("settings", "gfx_quality") == q, "%s: confirmed quality %d persists" % [where, q])
	options.select_tab(2)
	for key_name in ["master", "sound", "music"]:
		await native_tap(options.row_controls[key_name], 0.3)
		var value: float = game.sfx.get({"master": "master_volume", "sound": "sound_volume", "music": "music_volume"}[key_name])
		check(absf(value - 0.3) < 0.06 and absf(float(saved("settings", key_name + "_volume")) - value) < 0.01, "%s: native %s slider responds and saves" % [where, key_name])
	var slider: HSlider = options.row_controls.music
	var before = saved("settings", "music_volume")
	slider.drag_started.emit()
	slider.value = 80
	slider.value = 60
	check(saved("settings", "music_volume") == before, "%s: active slider drag does not repeatedly write the save" % where)
	slider.drag_ended.emit(true)
	check(is_equal_approx(float(saved("settings", "music_volume")), 0.6), "%s: slider release persists the final value" % where)


func _controls_page() -> void:
	var options = game.options_screen
	options.select_tab(3)
	for group in 3:
		options.controls_group = group
		options.select_tab(3)
		check(options.row_controls.size() > 1, "controls: group %d has binding rows" % group)
	options.controls_group = 1
	options.select_tab(3)
	await frames()
	await native_tap(options.row_controls.ability_1)
	check(game.rebinding == "ability_1", "controls: keyboard binding waits for a key")
	var ev := InputEventKey.new()
	ev.keycode = KEY_T
	ev.physical_keycode = KEY_T
	ev.pressed = true
	Input.parse_input_event(ev)
	await frames()
	check(game.rebinding == "" and game.binding_text("ability_1", "key") == "T", "controls: real T input rebinds Ability Q")
	options.reset_category()
	check(game.binding_text("ability_1", "key") == "Q", "controls: Reset restores Q and preserves the account")
