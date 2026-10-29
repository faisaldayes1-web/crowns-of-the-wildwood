extends SceneTree
## Agent: claude-faisal3, 2026-10-29 loading pass. game.gd _rock_mesh (every
## boulder, bush and leaf blob) was rebuilt to skip a GPU upload and read-back
## per blob; this checks it still makes the very same rocks as the old code
## (kept below as _old_rock), and that the CPU copy it keeps for
## scripts/static_batch.gd matches the mesh.
## tools/tests/isolated.sh --headless --path . --script tools/rock_mesh_test.gd

var failures := 0


func check(ok: bool, message: String) -> void:
	print(("PASS " if ok else "FAIL ") + message)
	if not ok:
		failures += 1


func _old_rock(seed: int, radius: float, jitter: float) -> ArrayMesh:
	## game.gd _rock_mesh as it was on main 874287a.
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 9
	sphere.rings = 5
	var arrays := sphere.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var moved := {}
	for i in verts.size():
		var key := verts[i].snapped(Vector3.ONE * 0.001)
		if not moved.has(key):
			moved[key] = verts[i] * (1.0 + r.randf_range(-jitter, jitter))
		verts[i] = moved[key]
	arrays[Mesh.ARRAY_VERTEX] = verts
	var st := SurfaceTool.new()
	var tmp := ArrayMesh.new()
	tmp.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	st.create_from(tmp, 0)
	st.deindex()
	st.generate_normals()
	return st.commit()


func _init() -> void:
	var game = load("res://scripts/game.gd").new()   # (not in the tree: no _ready)
	var rng := RandomNumberGenerator.new()
	rng.seed = 29
	var worst_pos := 0.0
	var worst_normal := 0.0
	var worst_copy := 0.0
	var sizes_ok := true
	var empty := 0
	for k in 300:
		var seed := rng.randi_range(0, 200000)
		var radius := rng.randf_range(0.15, 3.0)
		var jitter: float = [0.22, 0.14, 0.15, 0.18, 0.25, 0.1][k % 6]
		var want := _old_rock(seed, radius, jitter).surface_get_arrays(0)
		var mesh: ArrayMesh = game._rock_mesh(seed, radius, jitter)
		var got := mesh.surface_get_arrays(0)
		var kept: Array = mesh.get_meta(&"batch_arrays", [])
		var wv: PackedVector3Array = want[Mesh.ARRAY_VERTEX]
		var gv: PackedVector3Array = got[Mesh.ARRAY_VERTEX]
		if wv.is_empty():
			empty += 1
		if kept.is_empty() or gv.size() != wv.size() or (kept[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() != wv.size():
			sizes_ok = false
			continue
		var kv: PackedVector3Array = kept[Mesh.ARRAY_VERTEX]
		var wn: PackedVector3Array = want[Mesh.ARRAY_NORMAL]
		var gn: PackedVector3Array = got[Mesh.ARRAY_NORMAL]
		for i in wv.size():
			worst_pos = maxf(worst_pos, wv[i].distance_to(gv[i]))
			worst_copy = maxf(worst_copy, gv[i].distance_to(kv[i]))
			worst_normal = maxf(worst_normal, wn[i].distance_to(gn[i]))
	game.free()
	print("ROCKS 300 compared: worst vertex %.7f m, worst normal %.5f, worst kept copy %.7f m" % [worst_pos, worst_normal, worst_copy])
	check(empty == 0, "the old rocks have geometry to compare (%d empty)" % empty)
	check(sizes_ok, "every rock has the old vertex count and keeps its arrays")
	check(worst_pos < 0.0001, "every rock vertex is where it was")
	check(worst_normal < 0.01, "every rock normal is as it was")
	check(worst_copy < 0.0001, "the kept CPU copy matches the mesh")
	print("rock mesh test: %d failure(s)" % failures)
	quit(1 if failures else 0)
