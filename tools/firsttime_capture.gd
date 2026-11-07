extends SceneTree
## Agent: claude-faisallaptop/crowns-tutorial-visual. A first-time player's
## walk from a wiped profile: WHO'S PLAYING, the HOW TO PLAY cards, MORE
## QUESTIONS, the map pick, then a match on map 0 with the first-match tips
## (move, class, attack, abilities, goal), a class hat taken at a station and
## a talk with the Wildwood Guide. One PNG per step at the window size.
## No user args on purpose: the game only shows its first-launch flow when
## the command line has none, so the output dir and tag come from the env.
##   CROWNS_CAPTURE_DIR=out CROWNS_CAPTURE_TAG=before tools/tests/isolated.sh \
##     --path . --resolution 1920x1080 --script tools/firsttime_capture.gd
const Isolated = preload("res://tools/tests/isolated.gd")
const Stats = preload("res://scripts/stats.gd")
var game
var out := ""
var tag := "ft"
var n := 0


func _initialize() -> void:
	call_deferred("run")


func _frames(k: int) -> void:
	for i in k:
		await process_frame


func _shot(name: String) -> void:
	await _frames(12)
	await RenderingServer.frame_post_draw
	n += 1
	var vp := Vector2(DisplayServer.window_get_size())
	var path := "%s/%s_%02d_%s_%dx%d.png" % [out, tag, n, name, int(vp.x), int(vp.y)]
	root.get_viewport().get_texture().get_image().save_png(path)
	print("FIRSTTIME saved ", path.get_file())


func _tap(action: String, hold: int = 6) -> void:
	Input.action_press(action)
	await _frames(hold)
	Input.action_release(action)
	await _frames(2)


func _place(at: Vector3) -> void:
	var p = game.player
	p.global_position = at + Vector3(0, 0.3, 0)
	p.velocity = Vector3.ZERO
	await _frames(40)


func run() -> void:
	if not Isolated.ok("firsttime_capture") or DisplayServer.get_name() == "headless":
		quit(2)
		return
	out = OS.get_environment("CROWNS_CAPTURE_DIR")
	if OS.get_environment("CROWNS_CAPTURE_TAG") != "":
		tag = OS.get_environment("CROWNS_CAPTURE_TAG")
	DirAccess.make_dir_recursive_absolute(out)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	var waited := 0
	while (game.main_menu == null or game.menus_warming or is_instance_valid(game.loading_layer)) and waited < 6000:
		await process_frame
		waited += 1
	await _frames(90)
	var m = game.main_menu
	print("FIRSTTIME needs_name=%s howto_seen=%s tips_on=%s tips_done=%s" % [game.needs_name, game.howto_seen, game.tips_on, game.tips_done])
	await _shot("welcome")
	game.hero_name = "Robin"
	await _frames(10)
	await _shot("welcome-named")
	m._press("name_done", null)
	await _frames(10)
	if m.overlay == "players":
		m._press("close", null)
	await _frames(30)
	print("FIRSTTIME after name: overlay=%s" % m.overlay)
	for i in m.HOWTO.size():
		await _shot("howto-%d" % (i + 1))
		if i < m.HOWTO.size() - 1:
			m._press("howto_step", 1)
			await _frames(10)
	# MORE QUESTIONS: the six topics with their pictures.
	m.howto_step = 0
	m._press("howto_more", null)
	for t in 6:
		m._press("topic", t)
		await _shot("questions-%d" % t)
	m._press("close", null)
	await _frames(20)
	await _shot("title")
	m.go("map")
	await _frames(40)
	await _shot("map-pick")
	game._start_match(0)
	waited = 0
	while (not game.playing or game.player == null or not game.player.is_on_floor() or (game.loading_layer != null and game.loading_layer.visible)) and waited < 6000:
		await process_frame
		waited += 1
	await _frames(60)
	await _shot("spawn-prep")
	while game.prep_left > 0.0 and waited < 20000:
		await process_frame
		waited += 1
	await _frames(30)
	await _shot("tip-move")
	Input.action_press("move_up")
	await _frames(70)
	Input.action_release("move_up")
	await _frames(20)
	await _shot("tip-class")
	var p = game.player
	var seal = game.seals[p.team][Stats.Role.KNIGHT]
	var gd = game.guides[p.team]
	var toward: Vector3 = (gd.global_position - seal.global_position)
	toward.y = 0.0
	toward = toward.normalized()
	await _place(seal.global_position + toward * 1.2)
	await _shot("at-knight-hat")
	game.try_interact(p)
	await _frames(30)
	await _shot("took-knight")
	# The class banner and the Veteran Training card hold the tip pill back; wait them out.
	await _frames(420)
	await _shot("tip-attack")
	await _tap("attack")
	await _frames(20)
	await _shot("tip-ability")
	await _tap("ability_1")
	await _frames(30)
	await _shot("tip-goal")
	await _place(gd.global_position + toward * -1.6)
	await _shot("guide-near")
	game.guide_toggle()
	for i in 6:
		await _frames(150)   # the line types itself out
		await _shot("guide-intro-%d" % (i + 1))
		game.guide_advance()
	await _frames(10)
	await _shot("guide-topics")
	for t in 6:
		game.guide_pick(t)
		await _frames(240)
		await _shot("guide-topic-%d" % t)
		game.guide_advance()
	game.guide_close()
	await _frames(20)
	print("FIRSTTIME done role=%s tips_done=%s" % [p.role_name(), game.tips_done])
	game._save_settings()
	game._flush_save()
	game.finish_world_now()
	quit(0)
