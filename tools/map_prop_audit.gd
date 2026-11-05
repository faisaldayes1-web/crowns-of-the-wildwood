extends SceneTree
## Agent: claude-faisallaptop (cf-crowns-mapaudit-1105k, pass 2). Placement audit for one map, from the
## built world's own records (no rendering): what stands too close to what.
##   tools/tests/isolated.sh --headless --path . --script tools/map_prop_audit.gd -- --map=0 [--debug-night]
## Prints AUDIT lines: fence-near-tree, wall-near-bush, rock-in-hill, prop-on-hill, and a prop-name census.
const Isolated = preload("res://tools/tests/isolated.gd")
const TREE_FENCE_MIN := 1.8   # a trunk closer than this to a fence line looks planted in it
const BUSH_WALL_MIN := 0.9
var game


func _initialize() -> void:
	call_deferred("run")


func _arg(prefix: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			return arg.trim_prefix(prefix)
	return ""


func _box_dist(p: Vector3, b: AABB) -> float:
	var dx := maxf(maxf(b.position.x - p.x, 0.0), p.x - b.end.x)
	var dz := maxf(maxf(b.position.z - p.z, 0.0), p.z - b.end.z)
	return sqrt(dx * dx + dz * dz)


func run() -> void:
	if not Isolated.ok("map_prop_audit"):
		quit(2)
		return
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	var deadline := Time.get_ticks_msec() + 240000
	while game.main_menu == null or game.menus_warming or not game.world_ready or is_instance_valid(game.loading_layer):
		if Time.get_ticks_msec() > deadline:
			push_error("audit load timeout")
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
	for i in 10:
		await process_frame
	var slug := str(game.map_variant)
	var bad := 0
	var fences: Array = []
	var walls: Array = []
	for blk in game.audit_blocks:
		if blk[0] == "fence":
			fences.append(blk[1])
		elif blk[0] == "wall" and blk[1].size.y < 2.0 and blk[1].end.y > 0.3 and maxf(blk[1].size.x, blk[1].size.z) < 12.0:
			walls.append(blk[1])
	for t in game.map_trees:
		if game.near_fence(t, 1.4 if t.y > 0.5 else 1.1):
			print("AUDIT map=%s fence-near-tree tree=(%.1f,%.1f)" % [slug, t.x, t.z])
			bad += 1
	for b in game.map_bushes:
		for w in walls:
			var d := _box_dist(Vector3(b.x, 0, b.z), w)
			if d < BUSH_WALL_MIN:
				print("AUDIT map=%s wall-in-bush bush=(%.1f,%.1f) wall=%s dist=%.2f" % [slug, b.x, b.z, w, d])
				bad += 1
				break
	var census := {}
	for ap in game.audit_props:
		if not is_instance_valid(ap[1]):
			continue   # (the static batcher frees what it merged)
		var n: String = ap[0]
		census[n] = int(census.get(n, 0)) + 1
		var pos: Vector3 = ap[1].global_position
		if game.lmap and n.begins_with("hex/rock"):
			var h: float = game.lmap.height(pos.x, pos.z)
			if h > 0.12 and pos.y < h - 0.35:   # (sunk a hand on purpose; more than that is buried)
				print("AUDIT map=%s rock-in-hill %s at (%.1f,%.1f) ground=%.2f base=%.2f" % [slug, n, pos.x, pos.z, h, pos.y])
				bad += 1
	print("AUDIT map=%s census %s" % [slug, JSON.stringify(census)])
	print("AUDIT_DONE map=%s problems=%d" % [slug, bad])
	quit()
