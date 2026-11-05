extends SceneTree
## Windowed captures of the screens reworked on 11-05 (claude-faisal3): the
## guide dialogue, the class banner, the Veteran Training card, and the
## Create Your Character ARMOR tab. Run (1920x1080):
##   CROWNS_CAPTURE_DIR=out tools/tests/isolated.sh --path . --resolution 1920x1080 --script tools/ui_capture3.gd -- --play
## Add --menu-only to skip the in-match screens (a quick ARMOR check).
const Isolated = preload("res://tools/tests/isolated.gd")
const Stats = preload("res://scripts/stats.gd")

var game
var out := ""


func _initialize() -> void:
	call_deferred("run")


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("UI3 saved ", name)


func run() -> void:
	if not Isolated.ok("ui_capture3") or DisplayServer.get_name() == "headless":
		quit(2)
		return
	out = OS.get_environment("CROWNS_CAPTURE_DIR")
	DirAccess.make_dir_recursive_absolute(out)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	if "--menu-only" in OS.get_cmdline_user_args():
		await _menu_shots()
		quit(0)
		return
	var waited := 0
	while (not game.playing or game.player == null or not game.player.is_on_floor() or (game.loading_layer != null and game.loading_layer.visible)) and waited < 6000:
		await process_frame
		waited += 1
	await _frames(90)
	var p = game.player
	for u in game.units:
		if u != p:
			u.process_mode = Node.PROCESS_MODE_DISABLED
	# 1. The guide's dialogue (she closes the talk when you walk away, so stand beside her).
	var guide_npc = game.guides[p.team]
	p.global_position = guide_npc.global_position + Vector3(1.4, 0.1, 1.4)
	await _frames(10)
	game.guide_open = true
	game.guide_page = 0
	await _frames(120)
	await _shot("dialogue-page")
	game.guide_page = -1
	game.guide_topic = -1
	await _frames(20)
	await _shot("dialogue-topics")
	game.guide_topic = 0
	await _frames(60)
	await _shot("dialogue-answer")
	game.guide_open = false
	game.guide_topic = -1
	game.guide_page = -1
	await _frames(20)
	if "--only-dialogue" in OS.get_cmdline_user_args():
		quit(0)
		return
	# 2. The class banner.
	p.set_role(Stats.Role.MAGE)
	p.class_banner = p.CLASS_BANNER_TIME - 0.6
	await _frames(40)
	await _shot("class-banner")
	p.class_banner = 0.0
	# 3. The Veteran Training / action card at the class's hat machine, late game.
	game.prep_left = 0.0
	game.time_left = Stats.MATCH_TIME - Stats.ECONOMY.train_after - 30.0
	var seal = game.seals[p.team][Stats.Role.KNIGHT]
	p.global_position = seal.global_position + Vector3(0, 0.1, 1.2)
	p.set_role(Stats.Role.KNIGHT)
	await _frames(60)
	await _shot("action-card")
	game.economy.training_open = true
	await _frames(30)
	await _shot("veteran-training")
	game.economy.training_open = false
	await _menu_shots()
	quit(0)


func _menu_shots() -> void:
	var waited := 0
	while (game.main_menu == null or game.menus_warming or is_instance_valid(game.loading_layer)) and waited < 6000:
		await process_frame
		waited += 1
	await _frames(60)
	game.main_menu._press("customize", null)
	await _frames(60)
	game.main_menu.char_tab = 3
	await _frames(40)
	for cat in 6:
		game.main_menu.armor_cat = cat
		game.main_menu.armor_page = 0
		await _frames(25)
		await _shot("armor-%d" % cat)
	game.main_menu.armor_cat = 2
	game.main_menu.armor_page = 1
	await _frames(25)
	await _shot("armor-hat-page2")
