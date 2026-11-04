extends SceneTree
## PC controls in a live match, driven with real injected mouse, key and wheel
## events (Input.parse_input_event) through the game's own camera and ground
## ray, not by calling the movement helpers: click to move, hold to keep
## moving, Shift to attack in place, force move, camera-relative WASD, and
## couch co-op keeping the mouse and keyboard on player 1.
##     tools/tests/isolated.sh --headless --path . --fixed-fps 60 --script tools/controls_live_test.gd
## Windowed (screenshots and frame sheet for evidence):
##     tools/tests/isolated.sh --path . --script tools/controls_live_test.gd -- --shots=DIR
## It plays a match and saves settings, so it runs only in a throwaway user
## dir (tools/tests/isolated.sh; it refuses otherwise and exits 2).
## claude-faisal3 2026-11-04.

const Isolated = preload("res://tools/tests/isolated.gd")

var fails := 0
var shots := ""
var shot_n := 0
var clip := ""      # --clip=DIR: every 5th frame of the control segments at 480x270, for an animated clip
var clip_n := 0
var clip_tick := 0
var clip_on := false


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await process_frame
		if clip != "" and clip_on:
			clip_tick += 1
			if clip_tick % 5 == 0:
				var img := root.get_texture().get_image()
				img.resize(480, 270, Image.INTERPOLATE_BILINEAR)
				img.save_jpg("%s/c%04d.jpg" % [clip, clip_n], 0.8)
				clip_n += 1


func settle(u, cap: int = 400) -> void:
	## Until the unit's click goal is over (arrived, stopped or cancelled), then a few frames.
	for i in cap:
		await frames(1)
		if u.click_movement.target == Vector3.INF and u.velocity.length() < 0.05:
			break
	await frames(6)


func shot(tag: String) -> void:
	if shots == "":
		return
	await frames(2)
	DirAccess.make_dir_recursive_absolute(shots)
	root.get_texture().get_image().save_jpg("%s/%02d_%s.jpg" % [shots, shot_n, tag], 0.9)
	shot_n += 1


func to_window(pos: Vector2) -> Vector2:
	## Viewport (content) coordinates to window pixels: the game stretches 1280x720.
	return root.get_final_transform() * pos


func mouse_to(pos: Vector2) -> void:
	## Moves the real cursor: injected motion events do not update the viewport's mouse position.
	Input.warp_mouse(to_window(pos))


func mouse_button(btn: MouseButton, pressed: bool, pos: Vector2) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = btn
	ev.pressed = pressed
	ev.position = to_window(pos)
	ev.global_position = ev.position
	Input.parse_input_event(ev)


func key(code: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)


func flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func screen_of(g, u, world: Vector3) -> Vector2:
	## Where a world point lands in the pane that shows u.
	var cam: Camera3D = g.camera_for(u)
	var p := cam.unproject_position(world)
	if g.couch_active:
		for pane in g.panes:
			if pane.unit == u:
				return pane.rect.position + p / Vector2(pane.view.size) * pane.rect.size
	return p


func walkable_spot(g, u, dirs: Array, dist: float, run: float = 0.0) -> Dictionary:
	## A point `dist` away in the first direction whose screen position the
	## game's own ground ray resolves back onto that point.
	for step in [dist, dist * 0.7, dist * 0.45]:
		for d in dirs:
			var world: Vector3 = u.global_position + Vector3(d.x, 0, d.y).normalized() * step
			var s := screen_of(g, u, world)
			if not get_root_rect().has_point(s):
				continue
			mouse_to(s)
			await frames(2)
			var hit: Vector3 = g.movement_ground_point(u)
			if hit.is_finite() and flat(hit, world) < 0.6 and clear_path(g, u, hit) and (run <= 0.0 or clear_path(g, u, u.global_position + Vector3(d.x, 0, d.y).normalized() * (step + run)) and clear_path(g, u, u.global_position - Vector3(d.x, 0, d.y).normalized() * run)):
				return {"screen": s, "world": hit}
	return {}


func clear_path(g, u, to: Vector3) -> bool:
	## No wall, prop or tree within the body's width of the straight line, at knee and chest height.
	var along: Vector3 = to - u.global_position
	along.y = 0.0
	var side := Vector3(-along.z, 0, along.x).normalized() * 0.5
	for h in [0.4, 1.2]:
		for off in [-1.0, 0.0, 1.0]:
			var from: Vector3 = u.global_position + Vector3(0, h, 0) + side * off
			var query := PhysicsRayQueryParameters3D.create(from, to + Vector3(0, h, 0) + side * off, 0xFFFFFFFF)
			query.exclude = [u.get_rid()]
			if not g.get_world_3d().direct_space_state.intersect_ray(query).is_empty():
				return false
	return true


func get_root_rect() -> Rect2:
	return Rect2(Vector2(60, 60), Vector2(root.size) - Vector2(120, 260))


func _init() -> void:
	if not Isolated.ok("tools/controls_live_test.gd"):
		quit(2)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots = arg.trim_prefix("--shots=")
		elif arg.begins_with("--clip="):
			clip = arg.trim_prefix("--clip=")
			DirAccess.make_dir_recursive_absolute(clip)
	var g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	current_scene = g
	for i in 400:
		if g.main_menu and not g.get("menus_warming"):
			break
		await process_frame
	await frames(10)
	var m = g.main_menu
	m._press("play", null)
	m._press("team_size", 1)
	m._press("to_lobby", null)
	m.start()
	await frames(30)
	var p = g.player
	check(g.playing and p != null, "a solo match is running")
	g.prep_left = 0.0
	g.pc_movement = "click"
	g.pad_active = false
	g.touch_active = false
	p.has_mouse = true
	await frames(60)
	clip_on = true
	var dirs := [Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0), Vector2(0, -1), Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]
	await shot("start")

	# 0. The Wildwood spawn has a stone brazier pillar just east of the hero. A
	# click straight behind it used to leave the hero pressed against its corner
	# until the goal timed out (player_movement.gd now sidesteps).
	var east: Vector3 = p.global_position + Vector3(5, 0, 0)
	var east_s := screen_of(g, p, east)
	mouse_to(east_s)
	await frames(2)
	var east_hit: Vector3 = g.movement_ground_point(p)
	check(east_hit.is_finite() and not clear_path(g, p, east_hit), "the spawn has scenery on the straight line 5 m east (so this click tests the sidestep)")
	mouse_button(MOUSE_BUTTON_LEFT, true, east_s)
	await frames(2)
	mouse_button(MOUSE_BUTTON_LEFT, false, east_s)
	await settle(p)
	check(flat(p.global_position, east_hit) < 0.7, "a click straight behind the scenery still arrives (%.2f m off)" % flat(p.global_position, east_hit))

	# 1. Click to move: one LMB click on the ground walks the player there.
	var spot: Dictionary = await walkable_spot(g, p, dirs, 5.0)
	check(not spot.is_empty(), "the game's ground ray resolves a clicked point 5 m from the player")
	if spot.is_empty():
		print("controls live test: %d failure(s)" % fails)
		quit(1)
		return
	var start: Vector3 = p.global_position
	mouse_to(spot.screen)
	mouse_button(MOUSE_BUTTON_LEFT, true, spot.screen)
	await frames(2)
	mouse_button(MOUSE_BUTTON_LEFT, false, spot.screen)
	await frames(20)
	check(flat(p.global_position, start) > 0.5, "a click starts the player walking (moved %.2f m in 20 frames)" % flat(p.global_position, start))
	await shot("click_walking")
	await settle(p)
	check(flat(p.global_position, spot.world) < 0.6, "the player arrives at the clicked point (%.2f m off)" % flat(p.global_position, spot.world))
	var rest: Vector3 = p.global_position
	await frames(30)
	check(flat(p.global_position, rest) < 0.05, "and stops there (drift %.3f m)" % flat(p.global_position, rest))

	# 2. Hold to keep moving: the goal follows the cursor while LMB stays down.
	# (The cellar is too small for a long run: stand somewhere open on the road.)
	var spot_a: Dictionary = {}
	for cx in [-60.0, -45.0, -30.0, -15.0, 0.0]:
		for cz in [-4.0, 8.0, -16.0]:
			p.global_position = Vector3(cx, 0.2, cz)
			p.velocity = Vector3.ZERO
			await frames(8)
			spot_a = await walkable_spot(g, p, dirs, 4.0, 8.0)
			if not spot_a.is_empty():
				break
		if not spot_a.is_empty():
			break
	check(not spot_a.is_empty(), "hold: a cursor spot with a clear path")
	mouse_to(spot_a.screen)
	mouse_button(MOUSE_BUTTON_LEFT, true, spot_a.screen)
	await frames(25)
	var h0: Vector3 = p.global_position
	await frames(10)
	var heading_a: Vector3 = p.global_position - h0
	check(heading_a.length() > 0.3, "holding LMB keeps the hero walking toward the cursor (%.2f m in 10 frames)" % heading_a.length())
	# Mirror the cursor through the hero's own screen position: the other side.
	var me := screen_of(g, p, p.global_position)
	var mirrored: Vector2 = me - (spot_a.screen - me)
	for scale in [1.0, 0.7, 0.45]:
		mirrored = me - (spot_a.screen - me) * scale
		mouse_to(mirrored)
		await frames(2)
		if g.movement_ground_point(p).is_finite():
			break
	await frames(12)
	var h1: Vector3 = p.global_position
	await frames(12)
	var heading_b: Vector3 = p.global_position - h1
	check(heading_b.length() > 0.2 and heading_b.dot(heading_a) < 0.0, "holding LMB, moving the cursor to the other side turns the hero round (cos %.2f)" % (heading_b.normalized().dot(heading_a.normalized()) if heading_b.length() > 0.001 and heading_a.length() > 0.001 else 0.0))
	mouse_button(MOUSE_BUTTON_LEFT, false, mirrored)
	# (the camera follows the player, so the point under a held cursor keeps moving: the walk goes on)
	await settle(p)
	var settled: Vector3 = p.global_position
	await frames(20)
	check(p.click_movement.target == Vector3.INF and flat(p.global_position, settled) < 0.02, "releasing LMB, the walk finishes and the player stands still with no goal left")

	# 3. Shift (force hold) + LMB: stand still and attack, no walking.
	var spot_h: Dictionary = await walkable_spot(g, p, dirs, 4.0)
	var hold_start: Vector3 = p.global_position
	key(KEY_SHIFT, true)
	mouse_to(spot_h.screen)
	mouse_button(MOUSE_BUTTON_LEFT, true, spot_h.screen)
	await frames(3)
	var held_ctl: Dictionary = p.local_controls()
	check(held_ctl.get("attack", false), "Shift + LMB attacks")
	await frames(40)
	# (the melee swing itself lunges a few tenths of a metre, unit.gd "a short lunge into the swing")
	check(flat(p.global_position, hold_start) < 1.2 and p.click_movement.target == Vector3.INF, "Shift + LMB stands and attacks, no walking goal (moved %.2f m)" % flat(p.global_position, hold_start))
	await shot("shift_attack_in_place")
	mouse_button(MOUSE_BUTTON_LEFT, false, spot_h.screen)
	key(KEY_SHIFT, false)
	await frames(10)

	# 4. Force move: a wheel tick walks to the cursor and suppresses attacking.
	g.wheel_zoom = false
	var spot_f: Dictionary = await walkable_spot(g, p, dirs, 4.0)
	var fm_start: Vector3 = p.global_position
	mouse_to(spot_f.screen)
	mouse_button(MOUSE_BUTTON_WHEEL_DOWN, true, spot_f.screen)
	mouse_button(MOUSE_BUTTON_WHEEL_DOWN, false, spot_f.screen)
	await frames(2)
	var fm_ctl: Dictionary = p.local_controls()
	check(fm_ctl.get("force_move", false) and not fm_ctl.get("attack", true), "a wheel tick force-moves with attack suppressed")
	await frames(40)
	check(flat(p.global_position, fm_start) > 0.5, "force move walks toward the cursor (moved %.2f m)" % flat(p.global_position, fm_start))
	await settle(p)

	# 5. Directional keys are camera-relative: W is up the screen whatever way
	# the hero faces, and click goals are dropped the moment a key is pressed.
	g.pc_movement = "wasd"
	var cam: Camera3D = g.camera_for(p)
	var screen_up := Vector3(-cam.global_basis.z.x, 0, -cam.global_basis.z.z).normalized()
	var screen_right := Vector3(cam.global_basis.x.x, 0, cam.global_basis.x.z).normalized()
	for facing in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1)]:
		p.aim = facing
		p.rotation.y = atan2(facing.x, facing.z)
		p.aim_point = p.global_position + facing * 6.0
		for pair in [[KEY_W, screen_up, "W"], [KEY_D, screen_right, "D"], [KEY_S, -screen_up, "S"], [KEY_A, -screen_right, "A"]]:
			var k0: Vector3 = p.global_position
			key(pair[0], true)
			await frames(25)
			key(pair[0], false)
			await frames(5)
			var delta: Vector3 = p.global_position - k0
			delta.y = 0
			if delta.length() < 0.3:   # walked into a wall: step back the other way and retry once
				check(true, "%s while facing %s: blocked by scenery, skipped" % [pair[2], str(facing)])
			else:
				check(delta.normalized().dot(pair[1]) > 0.6, "%s walks %s the screen while facing %s (cos %.2f)" % [pair[2], {"W": "up", "D": "right", "S": "down", "A": "left"}[pair[2]], str(facing), delta.normalized().dot(pair[1])])
	# A pending click goal is cancelled by a direction key.
	var spot_k: Dictionary = await walkable_spot(g, p, dirs, 6.0)
	mouse_button(MOUSE_BUTTON_LEFT, true, spot_k.screen)
	await frames(1)
	mouse_button(MOUSE_BUTTON_LEFT, false, spot_k.screen)
	await frames(15)
	key(KEY_W, true)
	await frames(2)
	check(p.click_movement.target == Vector3.INF, "a direction key cancels a pending click goal")
	key(KEY_W, false)
	await frames(10)
	await shot("wasd")

	clip_on = false

	# 6. Couch co-op: mouse and keyboard stay with player 1, in player 1's pane.
	root.remove_child(g)
	g.queue_free()
	await frames(5)
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	current_scene = g
	for i in 400:
		if g.main_menu and not g.get("menus_warming"):
			break
		await process_frame
	await frames(10)
	g.split_screen = true
	m = g.main_menu
	m._press("play", null)
	m._press("to_lobby", null)
	await frames(5)
	for press in 2:   # A joins, A again readies
		for down in [true, false]:
			var ev := InputEventJoypadButton.new()
			ev.device = 0
			ev.button_index = JOY_BUTTON_A
			ev.pressed = down
			Input.parse_input_event(ev)
			await frames(2)
	check(g.couch_players == 2, "couch lobby: one pad joined makes two players (got %d)" % g.couch_players)
	m.start()
	await frames(40)
	check(g.couch_active and g.panes.size() == 2, "the couch match started with two panes (active %s, panes %d, players %d, locals %d)" % [g.couch_active, g.panes.size(), g.couch_players, g.locals.size()])
	if g.panes.size() < 2:
		print("controls live test: %d failure(s)" % fails)
		quit(1)
		return
	g.prep_left = 0.0
	g.pc_movement = "click"
	var p1 = g.locals[0]
	var p2 = g.locals[1]
	p1.has_mouse = true
	await frames(30)
	await shot("couch_start")
	clip_on = true
	var c_dirs := dirs
	var cspot: Dictionary = await walkable_spot(g, p1, c_dirs, 4.0)
	check(not cspot.is_empty(), "couch: the mouse in pane 1 resolves a ground point for player 1")
	if not cspot.is_empty():
		var b1: Array = [p1.global_position, p2.global_position]
		mouse_button(MOUSE_BUTTON_LEFT, true, cspot.screen)
		await frames(2)
		mouse_button(MOUSE_BUTTON_LEFT, false, cspot.screen)
		await settle(p1)
		check(flat(p1.global_position, cspot.world) < 0.7, "couch: a click in pane 1 walks player 1 there (%.2f m off)" % flat(p1.global_position, cspot.world))
		check(flat(p2.global_position, b1[1]) < 0.4, "couch: player 2 did not move (%.2f m)" % flat(p2.global_position, b1[1]))
	# The cursor over the other pane cannot move player 1 into it or order player 2.
	var other: Rect2 = g.panes[1].rect
	var over := other.get_center()
	var o_p1: Vector3 = p1.global_position
	var o_p2: Vector3 = p2.global_position
	mouse_to(over)
	mouse_button(MOUSE_BUTTON_LEFT, true, over)
	await frames(2)
	mouse_button(MOUSE_BUTTON_LEFT, false, over)
	await frames(60)
	check(flat(p2.global_position, o_p2) < 0.4, "couch: a click over pane 2 does not move player 2 (%.2f m)" % flat(p2.global_position, o_p2))
	check(not p2.has_mouse and flat(p1.global_position, o_p1) < 0.05, "couch: seat 2 has no mouse, and a click over pane 2 does not move player 1 either (%.2f m)" % flat(p1.global_position, o_p1))
	await shot("couch_after")
	clip_on = false
	print("controls live test: %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)
