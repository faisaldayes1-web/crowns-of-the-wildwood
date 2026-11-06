extends SceneTree
## Agent: claude-faisal3 (cf-crowns-next-1106d). Windowed check of a real connected DualSense / Edge: how the game names
## the pad, which glyph words each action gets, rumble state read back from the driver, and HUD + menu stills with
## the pad's glyphs on. Needs a window (a pad is only seen by a windowed run). Run:
##   CROWNS_CAPTURE_DIR=out tools/tests/isolated.sh --path . --resolution 1920x1080 --script tools/pad_edge_check.gd -- --tag=edge
const Isolated = preload("res://tools/tests/isolated.gd")
var game
var out := ""
var tag := "edge"


func _initialize() -> void:
	call_deferred("run")


func _frames(k: int) -> void:
	for i in k:
		await process_frame


func _shot(name: String) -> void:
	await _frames(10)
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("%s/%s_%s.png" % [out, tag, name])


func run() -> void:
	if not Isolated.ok("pad_edge_check") or DisplayServer.get_name() == "headless":
		quit(2)
		return
	out = OS.get_environment("CROWNS_CAPTURE_DIR")
	DirAccess.make_dir_recursive_absolute(out)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.trim_prefix("--tag=")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	var waited := 0
	while (game.main_menu == null or game.menus_warming or is_instance_valid(game.loading_layer)) and waited < 6000:
		await process_frame
		waited += 1
	await _frames(120)
	var pads: Array = Input.get_connected_joypads()
	print("PADS ", pads)
	if pads.is_empty():
		print("NO PAD CONNECTED")
		quit(3)
		return
	var d: int = pads[0]
	var kind: String = game.pad_kind(d)
	print("PAD name='%s' guid=%s known=%s kind=%s title='%s'" % [Input.get_joy_name(d), Input.get_joy_guid(d), Input.is_joy_known(d), kind, game.pad_title(d)])
	for act in ["attack", "dodge", "ability1", "ability2", "block", "grab", "interact", "rank_menu", "ui_confirm", "ui_back", "pause", "scoreboard"]:
		if InputMap.has_action(act):
			print("GLYPH %-10s pad=%s" % [act, game.pad_label(act, kind)])
	for b in [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_Y, JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_BACK, JOY_BUTTON_START, JOY_BUTTON_GUIDE, JOY_BUTTON_MISC1, JOY_BUTTON_LEFT_STICK, JOY_BUTTON_RIGHT_STICK]:
		print("BUTTON %2d -> %s" % [b, game._pad_name(b, kind)])
	# Rumble: ask for it, then read the driver's state back.
	game.rumble_on = true
	game.rumble_pad(d, 0.7, 0.7, 1.0)
	await _frames(6)
	print("RUMBLE after start: ", Input.get_joy_vibration_strength(d), " duration ", Input.get_joy_vibration_duration(d))
	await _frames(100)
	print("RUMBLE after 1.6 s: ", Input.get_joy_vibration_strength(d))
	game.rumble_on = false
	game.rumble_pad(d, 1.0, 1.0, 1.0)
	await _frames(6)
	print("RUMBLE with the setting off (expect 0,0): ", Input.get_joy_vibration_strength(d))
	game.rumble_on = true
	# Stills with this pad's glyphs: the title's pointer hint, then the match HUD.
	game.pad_active = true
	game.cursor_shown = true
	await _shot("menu")
	game.main_menu.go("lobby")
	await _frames(40)
	await _shot("readyup")
	game._start_match(0)
	waited = 0
	while (not game.playing or game.player == null or not game.player.is_on_floor() or (game.loading_layer != null and game.loading_layer.visible)) and waited < 6000:
		await process_frame
		waited += 1
	await _frames(150)
	game.pad_active = true
	await _frames(20)
	await _shot("hud")
	game.menu_open = true
	game.menu_tab = 4
	await _frames(40)
	await _shot("controls")
	print("PAD CHECK DONE")
	quit(0)
