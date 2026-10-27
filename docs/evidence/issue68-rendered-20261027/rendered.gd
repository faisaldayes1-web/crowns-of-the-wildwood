extends SceneTree
## Moving from map to map (Faisal 2026-10-15: "did you fix the bugs and
## crashes when moving from map to map"). Through the menu, picks every map
## pair in both directions (Wildwood, Moonlit Wildwood, Ember Pass, and since
## 2026-10-16 Stonekeep Fortress and Twilight Grove), plays
## back-to-back matches without restarting the game (finish, CONTINUE, pick
## another map, play again), solo and split-screen, and checks after each
## step: the right screen and map, the right world (Ember Pass ground or the
## Wildwood), one game scene in the tree, and the volume and settings kept.
## The runner should also grep the log for SCRIPT ERROR.
## It plays matches and saves, so it runs only in a throwaway user dir
## (tools/tests/isolated.sh; it refuses otherwise and exits 2).
## (--debug-unlock opens the Moonlit Wildwood, a level-10 unlock):
##     tools/tests/isolated.sh --headless --path . --script tools/map_switch_test.gd -- --debug-unlock
##     xvfb-run -a tools/tests/isolated.sh --path . --rendering-driver opengl3 --resolution 640x360 --script tools/map_switch_test.gd -- --debug-unlock

const Stats = preload("res://scripts/stats.gd")
const Isolated = preload("C:/ORY-Cache/qa/crowns-68-rendered-Codex-faisal/isolated.gd")
const CARD := {0: 0, 1: 1, 2: 3, 3: 2, 4: 4}   # map_variant -> SELECT MAP card
const NAMES := {0: "Wildwood", 1: "Moonlit", 2: "Ember Pass", 3: "Stonekeep", 4: "Twilight"}
const SEASON := {0: "", 1: "", 2: "", 3: "winter", 4: "twilight"}

var fails := 0
var base_children := 0
var captured := {}


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _settle():
	## Waits out a scene reload (and the menu warm-up), returns the game.
	await _frames(12)
	var g = current_scene
	for i in 400:
		if g and is_instance_valid(g) and g.main_menu and not g.get("menus_warming"):
			break
		await process_frame
		g = current_scene
	await _frames(6)
	return current_scene


func _state_ok(g, v: int, screen: String, what: String) -> void:
	var m = g.main_menu
	check(m != null and m.screen == screen, "%s: on %s (got %s)" % [what, screen, m.screen if m else "no menu"])
	check(g.map_variant == v, "%s: map is %s (got %d)" % [what, NAMES[v], g.map_variant])
	check((g.vmap != null) == (v == 2) and g.season == SEASON[v], "%s: the %s world is built" % [what, NAMES[v]])
	check(m != null and m.map_pick == CARD[v], "%s: the %s card is picked" % [what, NAMES[v]])
	check(root.get_child_count() == base_children, "%s: one game scene in the tree (%d nodes under root, was %d)" % [what, root.get_child_count(), base_children])
	check(is_equal_approx(g.sfx.sound_volume, 0.3) and is_equal_approx(g.sfx.music_volume, 0.25),
		"%s: volume kept (sound %.2f, music %.2f)" % [what, g.sfx.sound_volume, g.sfx.music_volume])
	check(g.bot_difficulty == "Hard", "%s: bot difficulty kept" % what)


func _pick(v: int):
	var g = current_scene
	var m = g.main_menu
	if m.screen != "map":
		m._press("play", null)
	var from: int = g.map_variant
	m._press("map_card", CARD[v])
	g = await _settle()
	_state_ok(g, v, "map", "%s -> %s" % [NAMES[from], NAMES[v]])
	return g


func _play(v: int, couch: bool):
	## From SELECT MAP: READY UP, start, fight a moment, finish, CONTINUE.
	var g = current_scene
	var m = g.main_menu
	m._press("to_lobby", null)
	if couch:
		m.add_player(3)
		m._press("readied", 1)
	m.start()
	await _frames(20)
	var what := "%s match%s" % [NAMES[v], " (split-screen)" if couch else ""]
	check(g.playing, "%s starts" % what)
	check((g.vmap != null) == (v == 2) and g.map_variant == v, "%s: on the right map" % what)
	if couch:
		check(g.couch_active and g.panes.size() == 2, "%s: two panes" % what)
	await _frames(40)
	# Verify the match reaches the playable view, not merely playing=true
	# while shader warm-up is still hidden behind the loading artwork.
	var deadline := Time.get_ticks_msec() + 120000
	while is_instance_valid(g.loading_layer) and Time.get_ticks_msec() < deadline:
		await process_frame
	check(not is_instance_valid(g.loading_layer), "%s: loading completes" % what)
	var clock_before: float = g.prep_left + g.time_left
	await create_timer(0.6).timeout
	check(g.prep_left + g.time_left < clock_before and is_instance_valid(g.player), "%s: playable simulation advances" % what)
	var evidence := OS.get_environment("CROWNS_MAP_EVIDENCE")
	if evidence == "": evidence = OS.get_user_data_dir().path_join("map-evidence")
	if evidence != "" and not captured.has(v) and DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute(evidence)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(evidence.path_join("map-%d-playable.png" % v))
		captured[v] = true
	# Exercise the real model replacement path; no game source modification.
	for role in [Stats.Role.KNIGHT, Stats.Role.RANGER, Stats.Role.MAGE, Stats.Role.BASE]:
		g.player.set_role(role)
		await _frames(30)
		check(g.player.role == role, "%s: class role %d applied" % [what, role])
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(evidence.path_join("map-%d-class-%d.png" % [v, role]))
	g._finish(0)
	await _frames(10)
	check(g.game_over and g.summary != null, "%s: the match ends on the summary" % what)
	if g.summary:
		g.summary.skip()
	await _frames(4)
	reload_current_scene()   # the summary's CONTINUE
	g = await _settle()
	_state_ok(g, v, "title", "after the %s" % what)
	check(g.couch_players == 1 and not g.playing, "after the %s: back to one player, not playing" % what)
	return g


func _init() -> void:
	if not Isolated.ok("tools/map_switch_test.gd"):
		quit(2)
		return
	var g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	current_scene = g
	g = await _settle()
	base_children = root.get_child_count()
	g.sfx.sound_volume = 0.3
	g.sfx.music_volume = 0.25
	g.bot_difficulty = "Hard"
	g._save_settings()
	# Start from the Wildwood (a saved Ember Pass pick opens there).
	if g.map_variant != 0:
		g = await _pick(0)
	# Every pair, both directions, across the five maps.
	var route := [3, 0]
	if "--loading-replacement" in OS.get_cmdline_user_args(): route = [2, 3]
	for v in route:
		g = await _pick(v)
	# Back-to-back matches on different maps without restarting.
	var matches := [[0, false], [3, true]]
	if "--loading-replacement" in OS.get_cmdline_user_args(): matches = [[3, false], [2, true]]
	for step in matches:
		g = await _pick(step[0]) if g.map_variant != step[0] else g
		if g.main_menu.screen != "map":
			g.main_menu._press("play", null)
		g = await _play(step[0], step[1])
	g._flush_save()
	print("map switch test: %d failure(s)" % fails)
	g.queue_free()
	current_scene = null
	await _frames(4)
	quit(1 if fails > 0 else 0)
