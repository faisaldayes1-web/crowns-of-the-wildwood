extends SceneTree

const Isolated = preload("res://tools/tests/isolated.gd")
## The two scene reloads the menus go through, with a window (the menu
## warm-up that caused both bugs only runs with one):
##  - picking Ember Pass rebuilds the world and must come back to SELECT MAP
##    on Ember Pass, not the title (Faisal 2026-10-15: "switch maps to ember
##    and hit play it kicks you off to the main menu");
##  - a button still held from the summary's CONTINUE must not drag the
##    volume sliders on the Settings tab the warm-up shows ("finish a game
##    it sends you to the main menu with the volume maxed").
## Run from the project root:
##     xvfb-run -a tools/tests/isolated.sh --path . --rendering-driver opengl3 --script tools/reload_menu_test.gd

const Stats = preload("res://scripts/stats.gd")

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _game():
	return current_scene


func _init() -> void:
	if not Isolated.ok("tools/reload_menu_test.gd"):   # it writes the save: only in a throwaway user dir
		quit(2)
		return
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await _frames(90)
	var m = game.main_menu
	check(m != null and m.screen == "title", "the game opens on the title")
	if game.vmap:
		# Start from the Wildwood so picking Ember Pass rebuilds the world.
		m._press("play", null)
		m._press("map_card", 0)
		await _frames(150)
		game = _game()
		m = game.main_menu
	m._press("play", null)
	check(m.screen == "map", "PLAY opens SELECT MAP")
	var ember := -1
	for i in m.MAP_CARDS.size():
		if m.MAP_CARDS[i][2] >= 0 and Stats.MAPS[m.MAP_CARDS[i][2]][1] == "volcano":
			ember = i
	m._press("map_card", ember)
	await _frames(150)
	game = _game()
	m = game.main_menu
	check(game.vmap != null, "Ember Pass rebuilt the world")
	check(m.screen == "map", "back on SELECT MAP after the rebuild (on %s)" % m.screen)
	check(m.map_pick == ember, "Ember Pass is the picked card")
	m._press("to_lobby", null)
	check(m.screen == "lobby", "START MATCH opens READY UP on Ember Pass")

	# The volume: set it low, hold the button down as on the summary's
	# CONTINUE, reload, and keep the pointer on the sliders while the
	# warm-up flips through the screens.
	game.sfx.sound_volume = 0.3
	game.sfx.music_volume = 0.25
	game._save_settings()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(1200, 650)
	Input.parse_input_event(press)
	await _frames(2)
	reload_current_scene()
	for i in 150:
		await process_frame
		var g = _game()
		if g and g.hud and not g.hud.volume_sliders.is_empty():
			var r: Rect2 = g.hud.volume_sliders[0][0]
			var at := r.position + Vector2(r.size.x - 2.0, r.size.y * 0.5)
			Input.warp_mouse(at)
			var mv := InputEventMouseMotion.new()
			mv.position = at
			mv.button_mask = MOUSE_BUTTON_MASK_LEFT
			Input.parse_input_event(mv)
	game = _game()
	check(is_equal_approx(game.sfx.sound_volume, 0.3) and is_equal_approx(game.sfx.music_volume, 0.25),
		"a held button does not move the volume after a reload (sound %.2f, music %.2f)" % [game.sfx.sound_volume, game.sfx.music_volume])
	var up := press.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
	await _frames(2)
	game._flush_save()
	print("reload_menu_test: %s" % ("OK" if fails == 0 else "%d failures" % fails))
	quit(1 if fails else 0)
