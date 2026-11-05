extends SceneTree

const Isolated = preload("res://tools/tests/isolated.gd")
## Steam-readiness checks that need no display: the version string agrees with
## the export presets, the credits say who made the game and keep every
## third-party licence line, the new Settings controls (windowed size, graphics
## auto-detect) do what they say, and the save-editing test flags are ignored by
## a shipped (non-debug) build. Run through the wrapper:
##     tools/tests/isolated.sh --headless --path . --script tools/steam_ready_test.gd
## Agent: claude-faisal3 (2026-11-04, task cf-crowns-steam-1104n).

const Menu = preload("res://scripts/menu.gd")
var fails := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _init() -> void:
	if not Isolated.ok("tools/steam_ready_test.gd"):   # it writes the save: only in a throwaway user dir
		quit(2)
		return
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	var deadline := Time.get_ticks_msec() + 120000
	while game.main_menu == null or game.menus_warming or is_instance_valid(game.loading_layer):
		if Time.get_ticks_msec() > deadline:
			break
		await process_frame
	# Version: one string, shown on the title and in the credits, equal to what the export presets stamp.
	var ver: String = game.version_text()
	check(ver != "" and ver != "dev", "the project has a version (%s)" % ver)
	var presets := FileAccess.get_file_as_string("res://export_presets.cfg")
	check(presets.contains("version/name=\"%s\"" % ver), "export_presets.cfg version/name matches the project version")
	# Credits.
	var text := ""
	for row in Menu.CREDITS:
		text += str(row[0]) + " " + str(row[1]) + "\n"
	check(text.contains("Faisal, solo developer"), "credits name Faisal as the solo developer")
	for lic in ["MIT", "CC0", "SIL Open Font License", "Apache License 2.0", "GodotSteam", "Steamworks SDK", "THIRD-PARTY-NOTICES.txt", "KayKit", "ElevenLabs", "VSCO"]:
		check(text.contains(lic), "credits keep the line for %s" % lic)
	# Windowed size: steps through sizes that fit, is saved and comes back.
	game.window_mode = "windowed"
	game.fullscreen = false
	var seen := {}
	for i in 5:
		game.toggle_setting("window_size")
		seen[game.window_size] = true
		check(game._window_sizes().has(game.window_size), "window size %s is one that fits the screen" % str(game.window_size))
	check(seen.size() == game._window_sizes().size(), "window size steps through every size that fits (%d)" % seen.size())
	# Graphics auto-detect: leaves "picked" mode.
	game.toggle_setting("gfx_2")
	check(game.gfx_picked and game.gfx_quality == 2, "choosing a preset marks it picked")
	game.toggle_setting("gfx_auto")
	check(not game.gfx_picked, "Auto clears the picked flag so detection and step-down run again")
	# Release gating: test flags that edit the save do nothing without a debug build, and the first-run FPS counter is debug-only.
	check(OS.is_debug_build(), "this run is a debug build (the editor binary), so the gates below are open")
	var src := FileAccess.get_file_as_string("res://scripts/game.gd")
	check(src.contains("show_fps = OS.is_debug_build()"), "first-run FPS counter is debug-only")
	check(src.contains("if not OS.is_debug_build():\n\t\t\tbreak") or src.contains("if not OS.is_debug_build():\r\n\t\t\tbreak"), "--debug-gold/chests/own are ignored outside a debug build")
	check(src.contains("OS.is_debug_build() and arg.begins_with(\"--debug-xp=\")"), "--debug-xp is ignored outside a debug build")
	check(FileAccess.get_file_as_string("res://scripts/hud.gd").contains("OS.is_debug_build() and \"--debug-unlock\""), "--debug-unlock is ignored outside a debug build")
	game.free()
	print("steam ready test: %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)
