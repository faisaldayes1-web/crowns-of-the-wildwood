extends SceneTree
## Triangle census of a map's static world: triangles per top-level owner
## (the node directly under the game) for meshes and MultiMeshes, split into
## shadow casters and non-casters, with the biggest single meshes. The sun's
## shadow pass draws every caster again, so caster triangles count twice.
##     godot --path . --script tools/tri_census.gd -- --demo --seed=7 --map=N --debug-unlock
## claude-faisal3 2026-11-05.


func _tris(m: Mesh) -> int:
	var t := 0
	for s in m.get_surface_count():
		var arr := m.surface_get_arrays(s)
		var idx = arr[Mesh.ARRAY_INDEX]
		if idx != null and idx.size() > 0:
			t += idx.size() / 3
		else:
			t += arr[Mesh.ARRAY_VERTEX].size() / 3
	return t


func _init() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for i in 60:
		await process_frame
	var by_owner := {}
	var big := []
	var cache := {}
	for n in game.find_children("*", "GeometryInstance3D", true, false):
		if not n.visible or not n.is_inside_tree():
			continue
		var m: Mesh = null
		var inst := 1
		if n is MeshInstance3D:
			m = n.mesh
		elif n is MultiMeshInstance3D and n.multimesh:
			m = n.multimesh.mesh
			inst = n.multimesh.visible_instance_count if n.multimesh.visible_instance_count >= 0 else n.multimesh.instance_count
		if m == null:
			continue
		if not cache.has(m):
			cache[m] = _tris(m)
		var t: int = cache[m] * inst
		var top: Node = n
		while top.get_parent() != null and top.get_parent() != game:
			top = top.get_parent()
		var key := "%s [%s]" % [top.name, top.get_script().resource_path.get_file() if top.get_script() else top.get_class()]
		var rec: Array = by_owner.get(key, [0, 0, 0])
		rec[0] += t
		if n.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			rec[1] += t
		rec[2] += 1
		by_owner[key] = rec
		var what := ""
		if n is MultiMeshInstance3D:
			what = " multimesh x%d of %d tris, mesh %s" % [inst, cache[m], m.resource_path.get_file() if m.resource_path != "" else m.get_class()]
		big.append([t, str(n.get_path()) + what, n.cast_shadow != 0])
	var keys := by_owner.keys()
	keys.sort_custom(func(a, b): return by_owner[a][0] > by_owner[b][0])
	var total := 0
	var casters := 0
	for k in by_owner:
		total += by_owner[k][0]
		casters += by_owner[k][1]
	print("TRI total=%d casters=%d (shadow pass adds that again)" % [total, casters])
	for k in keys.slice(0, 25):
		print("TRI %9d tris %9d casters %5d nodes  %s" % [by_owner[k][0], by_owner[k][1], by_owner[k][2], k])
	big.sort_custom(func(a, b): return a[0] > b[0])
	for b in big.slice(0, 15):
		print("TRIBIG %9d caster=%s %s" % [b[0], str(b[2]), b[1]])
	quit()
