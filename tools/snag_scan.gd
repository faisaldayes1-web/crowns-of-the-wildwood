extends SceneTree
## Finds snags indoors: spots inside the castles (yard, keep, cellar) where a
## player's body walking a straight line gets held up by something a player
## cannot see as a wall (a low lip, a floor seam, a prop's collider sticking
## out), although a body could pass there. Drops the player's own capsule
## (same shape, mask and CharacterBody settings) on a 0.5 m grid and walks it
## 1.2 m in 8 directions; a walk that ends under 0.35 m from its start while
## a lifted body sweep says the way is open is a snag.
##     godot --headless --path . --script tools/snag_scan.gd -- --play [--map=2] [--all]
## (--all scans the whole map, not just the castles.) Prints SNAG lines
## grouped on a 1 m grid with what the body hit, and a total.

const STEP := 0.5
const MASK := 1 | 16
const SPEED := 6.0

var space: PhysicsDirectSpaceState3D
var shape := CapsuleShape3D.new()
var body


func _init() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for i in 20:
		await physics_frame
	space = game.get_world_3d().direct_space_state
	shape.radius = 0.4
	shape.height = 1.6
	# Walk a real unit (its own step-up included), frozen so it does not think.
	for u in game.units:
		u.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
		u.process_mode = Node.PROCESS_MODE_DISABLED
	body = game.units[0]
	body.collision_mask = MASK
	await physics_frame
	var all := "--all" in OS.get_cmdline_user_args()
	var hx: float = maxf(game.map_half.x, game.CASTLE_X + game.CASTLE_DEPTH + game.CELLAR_DEPTH)
	var hz: float = game.map_half.y
	var groups := {}
	var tested := 0
	for ix in range(-int(hx / STEP), int(hx / STEP) + 1):
		for iz in range(-int(hz / STEP), int(hz / STEP) + 1):
			var x := ix * STEP
			var z := iz * STEP
			var top := 14.0
			for n in 3:
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, top, z), Vector3(x, -4.0, z), MASK))
				if hit.is_empty():
					break
				var p: Vector3 = hit.position
				top = p.y - 0.05
				if hit.normal.y < 0.6:
					continue
				var inside: bool = all
				for t in 2:
					inside = inside or game._inside_castle(t, p) or game._in_cellar(t, p) or game._inside_keep(t, p)
				if not inside or not _fits(p, 0.4):
					continue
				tested += 1
				for d in 8:
					var a := TAU * d / 8.0
					var dir := Vector3(cos(a), 0, sin(a))
					if not _open(p, dir * 1.0):
						continue
					var res := _walk(p, dir)
					if res[0] < 0.35:
						var key := "%d,%d,%d" % [roundi(p.x), roundi(p.y * 2.0), roundi(p.z)]
						if not groups.has(key):
							groups[key] = [p, 0, {}]
						groups[key][1] += 1
						for h in res[1]:
							groups[key][2][h] = true
	var keys := groups.keys()
	keys.sort_custom(func(a, b): return groups[a][1] > groups[b][1])
	for k in keys:
		var g: Array = groups[k]
		print("SNAG at %s blocked=%d hits=%s" % [g[0].snapped(Vector3.ONE * 0.1), g[1], g[2].keys()])
	print("SNAG spots tested=%d snags=%d" % [tested, keys.size()])
	quit()


func _fits(p: Vector3, r: float) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var c := CapsuleShape3D.new()
	c.radius = r
	c.height = 1.6
	q.shape = c
	q.collision_mask = MASK
	q.transform = Transform3D(Basis(), p + Vector3(0, 0.88, 0))
	return space.intersect_shape(q, 1).is_empty()


func _open(p: Vector3, motion: Vector3) -> bool:
	## A body lifted over 0.35 m of lip could pass: so a block is a snag.
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.collision_mask = MASK
	q.transform = Transform3D(Basis(), p + Vector3(0, 0.8 + 0.35, 0))
	q.motion = motion
	return space.cast_motion(q)[0] >= 0.999


func _walk(p: Vector3, dir: Vector3) -> Array:
	body.global_position = p + Vector3(0, 0.02, 0)
	body.velocity = Vector3.ZERO
	var hits := []
	for i in 12:   # 12 ticks at run speed = 1.2 m
		body.velocity = Vector3(dir.x * SPEED, 0.0 if body.is_on_floor() else body.velocity.y - 9.8 / 60.0, dir.z * SPEED)
		var from: Vector3 = body.global_position
		body.move_and_slide()
		if body.has_method("_step_up"):
			body._step_up(from, Vector3(dir.x, 0, dir.z) * SPEED / 60.0)
		for c in body.get_slide_collision_count():
			var col: KinematicCollision3D = body.get_slide_collision(c)
			if col.get_normal().y < 0.6:
				var o: Object = col.get_collider()
				var nm: String = o.name if o else "?"
				if o and o.get_parent() and o.get_parent().name != "Main":
					nm = "%s/%s" % [o.get_parent().name, nm]
				if o is Node3D:
					for ch in o.get_children():
						if ch is CollisionShape3D and ch.shape is BoxShape3D:
							nm += "[box %s at %s]" % [ch.shape.size.snapped(Vector3.ONE * 0.01), ch.global_position.snapped(Vector3.ONE * 0.01)]
				hits.append("%s@%s" % [nm, col.get_position().snapped(Vector3.ONE * 0.1)])
	var moved: float = Vector2(body.global_position.x - p.x, body.global_position.z - p.z).length()
	return [moved, hits.slice(0, 2)]
