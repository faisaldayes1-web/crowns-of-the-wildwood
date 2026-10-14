extends SceneTree
## Finds places a player could get stuck: open floor a player's body fits on
## but cannot walk out of (a pocket behind props or walls that a Blink, a
## knockback or a spawn could drop someone into). Flood-fills a 0.5 m grid of
## standing spots from both spawns with the player's capsule, then lists the
## free spots the fill never reached that sit right next to ones it did.
##     godot --headless --path . --script tools/stuck_scan.gd -- --play [--map=2]
## Prints POCKET lines (centre, size in cells, floor height) and a total.

const STEP := 0.5
const RADIUS := 0.4
const HEIGHT := 1.6
const MASK := 1 | 16
const LIFT := 0.3          # steps and ramp lips lower than this are walked over

var space: PhysicsDirectSpaceState3D
var shape := CapsuleShape3D.new()
var floors := {}    # Vector2i -> Array[float] floor heights in that cell
var free := {}      # "x,z,h" -> Vector3 standing spot (capsule fits)
var reached := {}


func _init() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for i in 20:
		await physics_frame
	space = game.get_world_3d().direct_space_state
	shape.radius = RADIUS
	shape.height = HEIGHT
	var hx: float = maxf(game.map_half.x, game.CASTLE_X + game.CASTLE_DEPTH + game.CELLAR_DEPTH)
	var hz: float = game.map_half.y
	var nx := int(hx / STEP)
	var nz := int(hz / STEP)
	for ix in range(-nx, nx + 1):
		for iz in range(-nz, nz + 1):
			_sample(Vector2i(ix, iz))
	print("SCAN cells=%d free spots=%d" % [floors.size(), free.size()])
	var queue: Array = []
	for u in game.units:
		var k: String = _nearest_key(u.spawn_point)
		if k != "" and not reached.has(k):
			reached[k] = true
			queue.append(k)
	var head := 0
	while head < queue.size():
		var k: String = queue[head]
		head += 1
		var p: Vector3 = free[k]
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
			var c: Vector2i = Vector2i(roundi(p.x / STEP), roundi(p.z / STEP)) + d
			for y in floors.get(c, []):
				if absf(y - p.y) > 0.45:
					continue
				var nk := _key(c, y)
				if reached.has(nk) or not free.has(nk):
					continue
				if _can_walk(p, free[nk]):
					reached[nk] = true
					queue.append(nk)
	print("SCAN reachable=%d" % reached.size())
	# Unreached free spots next to reached ones, grouped into pockets.
	var seen := {}
	var pockets := []
	for k in free:
		if reached.has(k) or seen.has(k):
			continue
		var group := _group(k, seen)
		var touches := false
		for gk in group:
			if _next_to_reached(free[gk]):
				touches = true
				break
		if touches:
			pockets.append(group)
	pockets.sort_custom(func(a, b): return a.size() > b.size())
	for g in pockets:
		var c := Vector3.ZERO
		for gk in g:
			c += free[gk]
		c /= float(g.size())
		var out: float = await _walk_out(game, free[g[0]])
		print("POCKET at (%.1f, %.1f, %.1f) cells=%d walk-out=%.1fm%s" % [c.x, c.y, c.z, g.size(), out, "" if out > 1.5 else "  TRAPPED"])
	print("SCAN pockets=%d" % pockets.size())
	quit()


func _walk_out(game, p: Vector3) -> float:
	## Drop a player-sized body on the spot and try to walk away in 16
	## directions (1 s each, run speed): the furthest it gets.
	var body := CharacterBody3D.new()
	body.collision_layer = 0
	body.collision_mask = MASK
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position.y = HEIGHT / 2.0
	body.add_child(cs)
	game.add_child(body)
	var best := 0.0
	for i in 16:
		var a := TAU * i / 16.0
		body.global_position = p + Vector3(0, 0.05, 0)
		await physics_frame
		for f in 60:
			body.velocity = Vector3(cos(a) * 6.0, -9.8 * 0.2, sin(a) * 6.0)
			body.move_and_slide()
			await physics_frame
		best = maxf(best, Vector2(body.global_position.x - p.x, body.global_position.z - p.z).length())
	body.queue_free()
	return best


func _key(c: Vector2i, y: float) -> String:
	return "%d,%d,%d" % [c.x, c.y, roundi(y * 4.0)]


func _sample(c: Vector2i) -> void:
	var x := c.x * STEP
	var z := c.y * STEP
	var top := 14.0
	var list: Array = []
	for n in 4:
		var q := PhysicsRayQueryParameters3D.create(Vector3(x, top, z), Vector3(x, -3.0, z), MASK)
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			break
		var y: float = hit.position.y
		if hit.normal.y > 0.6:
			list.append(y)
			var p := Vector3(x, y, z)
			if _fits(p):
				free[_key(c, y)] = p
		top = y - 0.05
	floors[c] = list


func _fits(p: Vector3) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.collision_mask = MASK
	q.transform = Transform3D(Basis(), p + Vector3(0, HEIGHT / 2.0 + 0.08, 0))
	return space.intersect_shape(q, 1).is_empty()


func _can_walk(a: Vector3, b: Vector3) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.collision_mask = MASK
	var lift := maxf(a.y, b.y) + HEIGHT / 2.0 + LIFT
	q.transform = Transform3D(Basis(), Vector3(a.x, lift, a.z))
	q.motion = Vector3(b.x - a.x, 0, b.z - a.z)
	var r := space.cast_motion(q)
	return r[0] >= 0.999


func _nearest_key(p: Vector3) -> String:
	var best := ""
	var bd := INF
	var c0 := Vector2i(roundi(p.x / STEP), roundi(p.z / STEP))
	for dx in range(-3, 4):
		for dz in range(-3, 4):
			var c := c0 + Vector2i(dx, dz)
			for y in floors.get(c, []):
				var k := _key(c, y)
				if free.has(k):
					var d: float = free[k].distance_to(p)
					if d < bd:
						bd = d
						best = k
	return best


func _group(start: String, seen: Dictionary) -> Array:
	var out := [start]
	seen[start] = true
	var i := 0
	while i < out.size():
		var p: Vector3 = free[out[i]]
		i += 1
		var c0 := Vector2i(roundi(p.x / STEP), roundi(p.z / STEP))
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				var c := c0 + Vector2i(dx, dz)
				for y in floors.get(c, []):
					if absf(y - p.y) > 0.45:
						continue
					var k := _key(c, y)
					if free.has(k) and not reached.has(k) and not seen.has(k):
						seen[k] = true
						out.append(k)
	return out


func _next_to_reached(p: Vector3) -> bool:
	var c0 := Vector2i(roundi(p.x / STEP), roundi(p.z / STEP))
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			var c := c0 + Vector2i(dx, dz)
			for y in floors.get(c, []):
				if absf(y - p.y) <= 0.45 and reached.has(_key(c, y)):
					return true
	return false
