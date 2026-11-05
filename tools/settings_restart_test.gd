extends SceneTree

const Isolated = preload("res://tools/tests/isolated.gd")
## Every option the player can change survives a restart: sets each one to a
## non-default value, saves, throws the game scene away, starts a new one and
## checks the values came back (options_menu_test.gd checks the write; this
## checks the read). Run from the project root, through the wrapper:
##     tools/tests/isolated.sh --headless --path . --script tools/settings_restart_test.gd
## Agent: claude-faisal3 (2026-11-04, completeness pass).

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _boot() -> Node:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	var deadline := Time.get_ticks_msec() + 120000
	while game.main_menu == null or game.menus_warming or is_instance_valid(game.loading_layer):
		if Time.get_ticks_msec() > deadline:
			return game
		await process_frame
	return game


func _init() -> void:
	if not Isolated.ok("tools/settings_restart_test.gd"):   # it writes the save: only in a throwaway user dir
		quit(2)
		return
	var game = await _boot()
	var want := {
		"bot_difficulty": "Hard", "chat_visible": false, "rosters_visible": true, "couch_mode": "coop",
		"screen_shake": false, "damage_numbers": false, "show_fps": true, "vsync": false,
		"fps_cap": 60, "render_scale": 0.75, "gfx_quality": 1, "gfx_picked": true,
		"window_mode": "borderless", "window_size": Vector2i(1600, 900), "rumble_on": false, "pad_style": "ps", "control_layout": "keyboard",
		"pc_movement": "wasd", "combine_move_attack": true, "wheel_zoom": true,
		"map_variant": 3, "split_screen": true, "split_layout": "horizontal",
		"hero_name": "Restarter", "hero_hair": 1, "hero_skin": 2, "banner_bg": 1,
	}
	for k in want:
		if k == "vsync":
			game.vsync_on = want[k]
		else:
			game.set(k, want[k])
	game.sfx.sound_volume = 0.35
	game.sfx.music_volume = 0.15
	game._save_settings()
	game._flush_save()
	game.free()
	await process_frame
	game = await _boot()
	for k in want:
		var got = game.vsync_on if k == "vsync" else game.get(k)
		check(got == want[k], "%s survives a restart (%s, wanted %s)" % [k, str(got), str(want[k])])
	check(is_equal_approx(game.sfx.sound_volume, 0.35) and is_equal_approx(game.sfx.music_volume, 0.15), "sound and music volume survive a restart")
	check(game.fullscreen, "fullscreen follows the saved window mode")
	game.free()
	print("settings restart test: %d failure(s)" % fails)
	for i in 8:
		await process_frame
	quit(1 if fails > 0 else 0)
