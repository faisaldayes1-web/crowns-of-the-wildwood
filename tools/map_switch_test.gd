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
## (--debug-unlock opens the Moonlit Wildwood, a level-10 unlock):
##     godot --headless --path . --script tools/map_switch_test.gd -- --debug-unlock
##     xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 640x360 --script tools/map_switch_test.gd -- --debug-unlock

const Stats = preload("res://scripts/stats.gd")
const CARD := {0: 0, 1: 1, 2: 3, 3: 2, 4: 4}   # map_variant -> SELECT MAP card
const NAMES := {0: "Wildwood", 1: "Moonlit", 2: "Ember Pass", 3: "Stonekeep", 4: "Twilight"}
const SEASON := {0: "", 1: "", 2: "", 3: "winter", 4: "twilight"}

var fails := 0
var base_children := 0


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
	var cfg := "user://controls.cfg"
	var saved := FileAccess.get_file_as_bytes(cfg) if FileAccess.file_exists(cfg) else PackedByteArray()
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
	for v in [1, 2, 0, 2, 1, 0, 3, 4, 3, 2, 4, 1, 3, 0, 4, 0]:
		g = await _pick(v)
	# Back-to-back matches on different maps without restarting.
	for step in [[2, false], [0, false], [1, false], [2, false], [2, true], [0, true], [1, false], [3, false], [4, false], [3, true], [4, true], [0, false]]:
		g = await _pick(step[0]) if g.map_variant != step[0] else g
		if g.main_menu.screen != "map":
			g.main_menu._press("play", null)
		g = await _play(step[0], step[1])
	g._flush_save()
	if saved.is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg + ".bak"))
	else:
		var f := FileAccess.open(cfg, FileAccess.WRITE)
		f.store_buffer(saved)
		f.close()
	print("map switch test: %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)
