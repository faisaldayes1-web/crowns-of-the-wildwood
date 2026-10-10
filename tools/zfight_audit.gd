extends SceneTree
## Finds z-fighting: pairs of visible mesh faces that lie in the same plane
## (within 3 mm), face the same way and overlap. Boxes, quads, planes and
## cylinder caps on axis-aligned transforms are checked. Run from the root:
##     godot --headless --path . --script tools/zfight_audit.gd -- --play [--map=2] [--near=x,z,r]
## Prints one ZFIGHT line per pair (largest overlap first) and a total.

const EPS := 0.003

var faces := {}   # "axis|sign|plane bucket" -> [[plane, rect(Rect2), node path, size]]


func _init() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for i in 12:
		await process_frame
	var near := Vector3.ZERO
	var near_r := INF
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--near="):
			var v := a.trim_prefix("--near=").split(",")
			near = Vector3(float(v[0]), 0, float(v[1]))
			near_r = float(v[2])
	var n := 0
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		if not mi.is_visible_in_tree() or mi.mesh == null:
			continue
		var p: Vector3 = mi.global_position
		if Vector2(p.x - near.x, p.z - near.z).length() > near_r:
			continue
		n += _add(mi)
	var hits := []
	for key in faces:
		var list: Array = faces[key]
		var parts: PackedStringArray = key.split("|")
		var nxt: String = "%s|%s|%d" % [parts[0], parts[1], int(parts[2]) + 1]
		var other: Array = faces.get(nxt, [])
		for i in list.size():
			for j in range(i + 1, list.size() + other.size()):
				var a: Array = list[i]
				var b: Array = list[j] if j < list.size() else other[j - list.size()]
				if absf(a[0] - b[0]) > EPS:
					continue
				var inter: Rect2 = a[1].intersection(b[1])
				var area := inter.get_area()
				if area > 0.0004 and a[2] != b[2]:
					hits.append([area, key, a, b])
	hits.sort_custom(func(x, y): return x[0] > y[0])
	hits = hits.filter(func(h): return not (h[1].get_slice("|", 1) == "-" and h[1].get_slice("|", 0) in ["y", "z"]))   # bottoms and backs never face the camera
	for h in hits.slice(0, 120):
		print("ZFIGHT %.3f m2  %s  plane %.3f\n   %s\n   %s" % [h[0], h[1].get_slice("|", 0) + h[1].get_slice("|", 1), h[2][0], h[2][2], h[3][2]])
	print("ZFIGHT total %d pairs over %d meshes" % [hits.size(), n])
	quit()


func _axis_of(v: Vector3) -> int:
	var a := v.abs()
	if a.x > 0.999 * v.length():
		return 0
	if a.y > 0.999 * v.length():
		return 1
	if a.z > 0.999 * v.length():
		return 2
	return -1


func _face(axis: int, sgn: int, plane: float, lo: Vector3, hi: Vector3, who: String) -> void:
	var u := (axis + 1) % 3
	var w := (axis + 2) % 3
	var rect := Rect2(Vector2(lo[u], lo[w]), Vector2(hi[u] - lo[u], hi[w] - lo[w]))
	var key := "%s|%s|%d" % ["xyz"[axis], "+" if sgn > 0 else "-", floori(plane / 0.01)]
	if not faces.has(key):
		faces[key] = []
	faces[key].append([plane, rect, who])


func _add(mi: MeshInstance3D) -> int:
	var t: Transform3D = mi.global_transform
	var b := t.basis
	var ax := [_axis_of(b.x), _axis_of(b.y), _axis_of(b.z)]
	if -1 in ax:
		return 0
	var who := "%s %s at %s mat=%s" % [mi.mesh.get_class(), str(mi.mesh.get("size")) if mi.mesh.get("size") != null else "", str(mi.global_position.snapped(Vector3.ONE * 0.01)), (mi.material_override.resource_name if mi.material_override and mi.material_override.resource_name != "" else (str(mi.material_override.get("albedo_color")) if mi.material_override else "-"))] + " [" + String(mi.get_path()).get_file() + "]"
	var m = mi.mesh
	var half := Vector3.ZERO
	var kinds := []   # local face normals to keep
	if m is BoxMesh:
		half = m.size / 2.0
		kinds = [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]
	elif m is QuadMesh:
		half = Vector3(m.size.x / 2.0, m.size.y / 2.0, 0.0)
		kinds = [Vector3.BACK]
	elif m is PlaneMesh:
		half = Vector3(m.size.x / 2.0, 0.0, m.size.y / 2.0)
		kinds = [Vector3.UP]
	elif m is CylinderMesh:
		var r: float = maxf(m.top_radius, m.bottom_radius) * 0.7   # inscribed-ish square
		half = Vector3(r, m.height / 2.0, r)
		kinds = [Vector3.UP] if m.top_radius > 0.05 else []
	else:
		return 0
	for nl in kinds:
		var c: Vector3 = nl * half   # face centre in local space
		var wn: Vector3 = (b * nl).normalized()
		var axis := _axis_of(wn)
		var sgn := 1 if wn[axis] > 0.0 else -1
		var wc: Vector3 = t * c
		# The face's world extents: transform the box corners on that face.
		var lo := Vector3(INF, INF, INF)
		var hi := -lo
		for sx in [-1.0, 1.0]:
			for sy in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					var corner := Vector3(sx * half.x, sy * half.y, sz * half.z)
					if nl.x != 0.0: corner.x = c.x
					if nl.y != 0.0: corner.y = c.y
					if nl.z != 0.0: corner.z = c.z
					var wp: Vector3 = t * corner
					lo = lo.min(wp)
					hi = hi.max(wp)
		_face(axis, sgn, wc[axis], lo, hi, who)
	return 1
