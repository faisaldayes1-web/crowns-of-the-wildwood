extends SceneTree
## Native functional and layout regression. Agent: Codex-faisal3.
const Isolated = preload("res://tools/tests/isolated.gd")
var failures := 0
var checks := 0
var game


func check(value: bool, message: String) -> void:
	checks += 1
	print(("PASS " if value else "FAIL ") + message)
	if not value:
		failures += 1


func _initialize() -> void:
	call_deferred("run")


func settle() -> void:
	for i in 4:
		await process_frame


func run() -> void:
	if not Isolated.ok("tools/options_test.gd"):
		quit(2)
		return
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	var deadline := Time.get_ticks_msec() + 180000
	while game.main_menu == null or game.menus_warming or is_instance_valid(game.loading_layer):
		if Time.get_ticks_msec() > deadline:
			check(false, "title loads before deadline")
			quit(1)
			return
		await process_frame
	game.needs_name = false
	game.name_editing = false
	game.menu_open = true
	game.menu_tab = 5
	game._route_options_screen()
	var screen = game.options_screen
	await settle()
	check(screen.active and screen.visible, "title Options opens dedicated screen")
	check(is_equal_approx(game.sfx.master_volume, 0.8) and is_equal_approx(game.sfx.music_volume, 0.6) and is_equal_approx(game.sfx.sound_volume, 0.8), "fresh defaults: Master80 Music60 SFX80")
	check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(0)), 0.8), "Master gain applied on fresh startup")
	screen.select_tab(2)
	await settle()
	screen.row_controls.master.value = 37
	screen.row_controls.music.value = 42
	screen.row_controls.sound.value = 73
	game._flush_save()
	game.sfx.master_volume = 0.1
	game.sfx.music_volume = 0.1
	game.sfx.sound_volume = 0.1
	game._load_controls()
	check(is_equal_approx(game.sfx.master_volume, 0.37) and is_equal_approx(game.sfx.music_volume, 0.42) and is_equal_approx(game.sfx.sound_volume, 0.73), "all three sliders survive settings reload")
	game.sfx.sound_volume = 0.0
	game.sfx.music_volume = 0.01
	game._save_settings()
	game._load_controls()
	check(game.sfx.sound_volume == 0.0 and is_equal_approx(game.sfx.music_volume, 0.01), "explicit saved mute and 1% are preserved as valid player choices")
	screen.reset_category()
	game._load_controls()
	check(is_equal_approx(game.sfx.master_volume, 0.8) and is_equal_approx(game.sfx.music_volume, 0.6) and is_equal_approx(game.sfx.sound_volume, 0.8), "audio reset persists sensible defaults")
	screen.select_tab(1)
	var before: Dictionary = screen.confirmed.duplicate()
	screen.draft.fps_cap = 60 if game.fps_cap != 60 else 120
	check(game.fps_cap == before.fps_cap, "video edits are staged before Apply")
	screen.apply_video()
	check(screen.preview_left > 0.0 and game.fps_cap == screen.draft.fps_cap, "Apply starts a timed preview")
	game._save_settings()
	game._flush_save()
	var cfg := ConfigFile.new()
	game._read_save(cfg)
	check(cfg.get_value("settings", "fps_cap") == before.fps_cap, "unconfirmed preview never enters the save")
	screen.select_tab(2)
	check(screen.category == 1, "preview requires Keep or Revert before another tab")
	screen.revert_video()
	check(game.fps_cap == before.fps_cap and screen.draft == before, "Revert restores confirmed video")
	screen.draft.fps_cap = 120
	screen.apply_video()
	screen._process(16.0)
	check(game.fps_cap == before.fps_cap and screen.preview_left <= 0.0, "timeout restores confirmed video")
	screen.draft.fps_cap = 60
	screen.apply_video()
	screen.keep_video()
	game._load_controls()
	check(game.fps_cap == 60, "Keep changes persists video")
	screen.select_tab(3)
	screen.controls_group = 1
	screen.select_tab(3)
	await settle()
	var key := InputEventKey.new()
	key.keycode = KEY_F8
	key.physical_keycode = KEY_F8
	key.pressed = true
	screen._begin_binding("dodge", "key", screen.row_controls.dodge)
	await settle()
	screen.handle_input(key)
	check(game.binding_text("dodge", "key").contains("F8"), "Keyboard column rebinds and saves")
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_X
	pad.pressed = true
	screen._begin_binding("dodge", "pad", screen.row_controls.dodge)
	await settle()
	screen.handle_input(pad)
	check(InputMap.action_has_event("dodge", pad), "Gamepad column rebinds")
	game._load_controls()
	check(InputMap.action_has_event("dodge", pad) and game.binding_text("dodge", "key").contains("F8"), "keyboard and pad bindings survive reload independently")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	screen._begin_binding("attack", "key", screen.row_controls.attack)
	await settle()
	screen.handle_input(escape)
	check(screen.active and screen.binding_action == "" and game.rebinding == "", "Escape cancels capture without closing options")
	screen._begin_binding("attack", "pad", screen.row_controls.attack.get_parent().get_child(1))
	await settle()
	var cancel := InputEventJoypadButton.new()
	cancel.button_index = JOY_BUTTON_START
	cancel.pressed = true
	screen.handle_input(cancel)
	check(screen.active and screen.binding_action == "", "pad Start cancels binding capture without a keyboard")
	var xp: int = game.account_xp
	screen.reset_category()
	check(game.account_xp == xp, "reset bindings preserves account progress")
	# Native containers perform layout at the same logical sizes used by the
	# project stretch mode. Long Controls pages must remain scrollable.
	for dimensions in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]:
		root.size = dimensions
		for tab in 5:
			screen.select_tab(tab)
			await settle()
			for id in screen.row_controls:
				var c: Control = screen.row_controls[id]
				check(c.size.x >= 150 and c.get_global_rect().end.x <= screen.size.x - 40, "%s %s control fits %s" % [screen.TABS[tab], id, dimensions])
			check(screen.description.get_global_rect().end.y < screen.size.y and screen.apply_button.get_global_rect().end.y < screen.size.y, "%s footer fits %s" % [screen.TABS[tab], dimensions])
	screen.select_tab(2)
	await settle()
	screen.row_controls.master.grab_focus()
	var old: float = screen.row_controls.master.value
	screen._navigate(Vector2.RIGHT)
	check(screen.row_controls.master.value == old + 1, "pad/keyboard left-right adjusts slider by one percent")
	screen._navigate(Vector2.DOWN)
	check(root.gui_get_focus_owner() == screen.row_controls.music, "down moves focus to next setting")
	screen.close_screen()
	check(not screen.active and not game.menu_open, "Back returns to title and consumes the closing input")
	game._flush_save()
	game.free()
	await settle()
	print("OPTIONS_TEST: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
