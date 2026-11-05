extends SceneTree
## Agent: claude-faisallaptop (cf-crowns-mapaudit-1105k, pass 2). Walkable hills on the Wildwood (map 0) and
## Twilight Grove (map 4): a unit-sized body walked from the paving up the bank climbs the terrain (never sinks
## into it), stops at the reach, and clamp_walk() agrees. Needs a window (the world builds behind the menus):
##   tools/tests/isolated.sh --path . --resolution 960x540 --script tools/hill_walk_test.gd -- --map=0
const Isolated = preload("res://tools/tests/isolated.gd")
var game
var fails := 0


func _initialize() -> void:
	call_deferred("run")


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func run() -> void:
	if not Isolated.ok("hill_walk_test") or DisplayServer.get_name() == "headless":
		quit(2)
		return
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	var deadline := Time.get_ticks_msec() + 240000
	while game.main_menu == null or game.menus_warming or not game.world_ready or is_instance_valid(game.loading_layer):
		if Time.get_ticks_msec() > deadline:
			push_error("load timeout")
			quit(1)
			return
		await process_frame
	game.needs_name = false
	game.name_editing = false
	game.howto_seen = true
	game.main_menu.overlay = ""
	game._start_match(0)
	while not game.playing or is_instance_valid(game.loading_layer):
		await process_frame
	for i in 20:
		await physics_frame
	var lm = game.lmap
	_check(lm != null and lm.kind != "winter", "a bank map (kind %s)" % (lm.kind if lm else "none"))
	# Probe points: along the paving edge, outward, on both halves. Find edges by walking out from path centres.
	var tested := 0
	var climbed := 0
	for s in lm.segs:
		if tested >= 12:
			break
		var a: Vector3 = lm.pos[s[0]]
		var b: Vector3 = lm.pos[s[1]]
		var mid := (a + b) * 0.5
		var dir := Vector3(b.x - a.x, 0, b.z - a.z)
		if dir.length() < 6.0 or absf(mid.x) > 44.0:
			continue
		var side := Vector3(-dir.z, 0, dir.x).normalized()
		for sgn in [1.0, -1.0]:
			# the paving edge on this side
			var d := 0.0
			while d < 12.0 and lm.walkable(mid + side * sgn * d):
				d += 0.1
			var edge: Vector3 = mid + side * sgn * d
			if d >= 12.0 or lm.height(edge.x, edge.z) < -1.0 or lm.field(edge + side * sgn * 3.0) < 1.0:
				continue   # a plaza, or another lane runs close by
			if Vector2(edge.x, edge.z).length() < 12.0:
				continue   # the centrepiece (Twilight's pool, the Wildwood's moat): a kerb or water, not a bank
			# on_hill agrees with the reach, clamp_walk keeps a point on the bank and pulls back one beyond it
			var in_bank: Vector3 = edge + side * sgn * 1.0
			var beyond: Vector3 = edge + side * sgn * (lm.HILL_REACH + 2.0)
			_check(lm.on_hill(in_bank) and lm.clamp_walk(in_bank) == in_bank, "bank point kept at %s" % in_bank.snapped(Vector3.ONE * 0.1))
			var pulled: Vector3 = lm.clamp_walk(beyond)
			_check(lm.field(pulled) < lm.HILL_REACH + 0.05, "point beyond the reach pulled back to the bank (field %.2f)" % lm.field(pulled))
			# a body walks out from the paving over the bank
			var body := CharacterBody3D.new()
			var cs := CollisionShape3D.new()
			var cap := CapsuleShape3D.new()
			cap.radius = 0.35
			cap.height = 1.4
			cs.shape = cap
			cs.position.y = 0.7
			body.add_child(cs)
			body.collision_mask = 1
			game.add_child(body)
			body.global_position = edge - side * sgn * 0.5 + Vector3(0, 0.05, 0)
			var top_y := 0.0
			for f in 150:
				body.velocity = side * sgn * 3.0 + Vector3(0, -9.8 * (1.0 / 60.0) * 10.0, 0)
				body.move_and_slide()
				body.global_position = lm.clamp_walk(body.global_position)
				await physics_frame
				top_y = maxf(top_y, body.global_position.y)
			var p := body.global_position
			var ground := maxf(lm.height(p.x, p.z), 0.0)
			_check(lm.field(p) < lm.HILL_REACH + 0.1, "body stopped within the reach (field %.2f)" % lm.field(p))
			_check(p.y > ground - 0.15, "body not sunk into the bank (y %.2f, ground %.2f)" % [p.y, ground])
			if top_y > 0.2:
				climbed += 1
			body.queue_free()
			tested += 1
			break
	_check(tested >= 4, "probed %d lanes" % tested)
	_check(climbed >= 1, "at least one body climbed the bank (%d)" % climbed)
	print("HILL_WALK_DONE map=", game.map_variant, " fails=", fails)
	quit(1 if fails > 0 else 0)
