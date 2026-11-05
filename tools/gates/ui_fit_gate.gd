extends SceneTree
## CI gate (claude-faisal/crowns-gates 2026-11-04): text fits its box and the
## screen. Every lettering helper notes its lines into Hud.fit_log (scripts/
## hud.gd fit_note); this walks the screens and panels at 720p, 1080p and
## 1440p and fails on any line wider than the box it was given ("BOX") or
## running off the screen or its split pane ("OFFSCREEN").
##   menus (--menus): title and its overlays, map pick, lobby, store, options
##   match (--couch=1..4, split screen from 2): HUD in prep and battle, every
##     pause tab, the class banner, the scoreboard and the end-of-match summary.
## Run from the project root:
##   tools/tests/isolated.sh --headless --path . --script tools/gates/ui_fit_gate.gd -- --menus --seed=7
##   tools/tests/isolated.sh --headless --path . --script tools/gates/ui_fit_gate.gd -- --play --couch=3 --seed=7

const Isolated = preload("res://tools/tests/isolated.gd")
const Hud = preload("res://scripts/hud.gd")
const SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]

var game
var issues := {}      # issue key -> first screen it showed on
var screens := 0
var shots := OS.get_environment("CROWNS_GATE_SHOTS")   # where to keep the tiny screen shots ("" = none)


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	if not Isolated.ok("tools/gates/ui_fit_gate.gd"):
		quit(2)
		return
	var args := OS.get_cmdline_user_args()
	if shots != "":
		DirAccess.make_dir_recursive_absolute(shots)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	# The checker checks itself: a line far too wide for its box must be caught.
	Hud.fit_log = {}
	Hud.fit_note(Control.new(), ThemeDB.fallback_font, Vector2(10, 40), "MUCH TOO LONG FOR ITS BOX", HORIZONTAL_ALIGNMENT_LEFT, 20.0, 16, "selftest")
	if Hud.fit_log.size() != 1:
		return _fail_out("the fit checker missed a line that runs past its box")
	Hud.fit_log = null
	var deadline := Time.get_ticks_msec() + 180000
	if "--menus" in args:
		while game.main_menu == null or game.menus_warming or is_instance_valid(game.loading_layer):
			if Time.get_ticks_msec() > deadline:
				return _fail_out("the title never came up")
			await process_frame
		game.needs_name = false
		game.name_editing = false
		game.howto_seen = true
		game.hero_name = "Player 1"
		var mm = game.main_menu
		for ov in ["", "howto", "credits", "progress", "players", "tutorial"]:
			mm.screen = "title"
			mm.overlay = ov
			await sweep("title" + ("/" + ov if ov != "" else ""))
		mm.overlay = ""
		for sc in ["character", "store"]:
			mm.screen = sc
			await sweep("menu/" + sc)
		mm.screen = "title"
		for tab in game.menu_tabs():
			game.menu_open = true
			game.menu_tab = tab
			await sweep("options/tab%d" % tab)
		game.menu_open = false
		# Into a match the way the capture tool goes (tools/crowns_visual_capture.gd).
		for step in [["play", "menu/map"], ["to_lobby", "menu/lobby"]]:
			mm._press(step[0], null)
			for i in 3:
				await process_frame
			await sweep(step[1])
		mm._press("start", null)
	deadline = Time.get_ticks_msec() + 300000   # (software rendering on a CI runner builds the match slowly)
	while not game.playing or game.player == null or is_instance_valid(game.loading_layer):
		if Time.get_ticks_msec() > deadline:
			return _fail_out("the match never started")
		await process_frame
	for i in 30:
		await process_frame   # the panes settle (scripts/game.gd _layout_panes)
	await sweep("match/prep")
	game.prep_left = 0.0
	for i in 30:
		await process_frame
	await sweep("match/battle")
	for tab in game.menu_tabs():
		game.menu_open = true
		game.menu_tab = tab
		await sweep("pause/tab%d" % tab)
	game.menu_open = false
	game.player.class_banner = game.player.CLASS_BANNER_TIME - 0.5
	await sweep("match/class-banner")
	game.player.class_banner = 0.0
	if "show_board" in game:
		game.show_board = true
		await sweep("match/scoreboard")
		game.show_board = false
	game._finish(game.player_team)
	for i in 30:
		await process_frame
	await sweep("summary")
	await create_timer(4.0).timeout   # (time, not frames: software rendering runs a few frames a second)
	await sweep("summary/settled")
	_report()


func huds() -> Array:
	var out: Array = []
	for n in root.find_children("*", "Control", true, false):
		if n.get_script() == Hud:
			out.append(n)
	return out


func set_3d(on: bool) -> void:
	root.disable_3d = not on
	for p in game.panes:
		if p.view != null and is_instance_valid(p.view):
			p.view.disable_3d = not on


func sweep(label: String) -> void:
	for sz in SIZES:
		if DisplayServer.get_name() != "headless":
			root.size = sz
			# Only the first size draws the 3D world (and its shot): the text
			# checks need the 2D layout, and software rendering of the world
			# at 1440p costs a CI runner minutes.
			set_3d(sz == SIZES[0])
		for i in 3:
			await process_frame
		Hud.fit_log = {}
		var before: int = Hud.fit_lines
		for h in huds():
			h.queue_redraw()
		await process_frame
		await process_frame
		var log: Dictionary = Hud.fit_log
		Hud.fit_log = null
		screens += 1
		if Hud.fit_lines == before:
			issues["gate|%s|no lettering was drawn" % label] = "%s @%dx%d" % [label, sz.x, sz.y]
		if sz == SIZES[0] and shots != "" and DisplayServer.get_name() != "headless":
			# A tiny shot of each screen (CI uploads them only when a gate fails).
			await RenderingServer.frame_post_draw
			var img := root.get_texture().get_image()
			img.resize(480, 270, Image.INTERPOLATE_BILINEAR)
			img.save_jpg(shots.path_join(label.replace("/", "-") + ".jpg"), 0.7)
		for k in log:
			if not issues.has(k):
				issues[k] = "%s @%dx%d" % [label, sz.x, sz.y]
	var hs: Array = []
	for h in huds():
		if h.size.x >= 200.0:
			hs.append(str(h.size))
	if screens <= SIZES.size():
		print("UI window %s, HUD %s" % [root.size, hs[0] if not hs.is_empty() else "none"])
	set_3d(true)
	print("UI screen %s swept, HUD sizes %s (%d issues so far)" % [label, ", ".join(hs), issues.size()])


func _fail_out(why: String) -> void:
	print("FAIL ", why)
	print("ui fit gate: 1 failure(s)")
	quit(1)


func _report() -> void:
	var keys := issues.keys()
	keys.sort()
	for k in keys:
		var p: PackedStringArray = k.split("|")
		print("FAIL UI %s: \"%s\" %s (%s)" % [p[0], p[1], p[2], issues[k]])
	print("ui fit gate: %d screens x sizes swept, %d failure(s)" % [screens, keys.size()])
	game.queue_free()
	for i in 10:
		await process_frame
	quit(1 if keys.size() > 0 else 0)
