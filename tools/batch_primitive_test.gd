extends SceneTree
## Agent: claude-faisal3, 2026-10-29 loading pass. scripts/static_batch.gd
## works boxes' and cylinders' arrays out on the CPU from a unit shape instead
## of reading each back from the GPU; this checks them against the read-back
## for random sizes, grids, cones and caps.
## tools/tests/isolated.sh --headless --path . --script tools/batch_primitive_test.gd

const StaticBatch = preload("res://scripts/static_batch.gd")
var failures := 0


func check(ok: bool, message: String) -> void:
	print(("PASS " if ok else "FAIL ") + message)
	if not ok:
		failures += 1


func _compare(mesh: PrimitiveMesh, worst: Dictionary) -> bool:
	var got: Array = StaticBatch._scaled_primitive(mesh)
	if got.is_empty():
		worst.skipped += 1
		return true
	var want: Array = StaticBatch._lighter(mesh).get_mesh_arrays()
	var wv: PackedVector3Array = want[Mesh.ARRAY_VERTEX]
	var gv: PackedVector3Array = got[Mesh.ARRAY_VERTEX]
	if wv.is_empty() or wv.size() != gv.size() or want[Mesh.ARRAY_INDEX] != got[Mesh.ARRAY_INDEX]:
		return false
	var scale := maxf(mesh.get_aabb().size.length(), 0.001)
	for i in wv.size():
		worst.pos = maxf(worst.pos, wv[i].distance_to(gv[i]) / scale)
		worst.normal = maxf(worst.normal, (want[Mesh.ARRAY_NORMAL][i] as Vector3).distance_to(got[Mesh.ARRAY_NORMAL][i]))
		worst.uv = maxf(worst.uv, (want[Mesh.ARRAY_TEX_UV][i] as Vector2).distance_to(got[Mesh.ARRAY_TEX_UV][i]))
	var wt: PackedFloat32Array = want[Mesh.ARRAY_TANGENT]
	var gt: PackedFloat32Array = got[Mesh.ARRAY_TANGENT]
	for i in wt.size():
		worst.tangent = maxf(worst.tangent, absf(wt[i] - gt[i]))
	worst.compared += 1
	return true


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 29
	var worst := {"pos": 0.0, "normal": 0.0, "uv": 0.0, "tangent": 0.0, "compared": 0, "skipped": 0}
	var same_shape := true
	for k in 150:
		var b := BoxMesh.new()
		b.size = Vector3(rng.randf_range(0.02, 30.0), rng.randf_range(0.02, 12.0), rng.randf_range(0.02, 30.0))
		if k % 5 == 0:
			b.subdivide_width = rng.randi_range(0, 3)
			b.subdivide_height = rng.randi_range(0, 3)
			b.subdivide_depth = rng.randi_range(0, 3)
		same_shape = _compare(b, worst) and same_shape
	for k in 250:
		var c := CylinderMesh.new()
		c.top_radius = 0.0 if k % 7 == 0 else rng.randf_range(0.02, 4.0)
		c.bottom_radius = 0.0 if k % 11 == 0 and c.top_radius > 0.0 else rng.randf_range(0.02, 4.0)
		c.height = rng.randf_range(0.05, 12.0)
		c.radial_segments = [5, 6, 7, 8, 12, 16, 24, 48, 64][k % 9]
		c.rings = rng.randi_range(0, 4)
		c.cap_top = k % 3 != 0
		c.cap_bottom = k % 4 != 0
		same_shape = _compare(c, worst) and same_shape
	var flipped := BoxMesh.new()
	flipped.flip_faces = true
	print("PRIMS compared %d (%d left to the read-back): worst position %.7f of size, normal %.5f, uv %.6f, tangent %.5f" % [
		worst.compared, worst.skipped, worst.pos, worst.normal, worst.uv, worst.tangent])
	check(same_shape, "every box and cylinder has the read-back's vertex count and triangles")
	check(worst.compared == 400, "all 400 shapes are worked out on the CPU")
	check(worst.pos < 0.00001, "every vertex is where the read-back has it")
	check(worst.normal < 0.003, "every normal matches the read-back")
	check(worst.uv < 0.00001 and worst.tangent < 0.003, "UVs and tangents match the read-back")
	check(StaticBatch._scaled_primitive(flipped).is_empty(), "a flipped box is left to the read-back")
	print("batch primitive test: %d failure(s)" % failures)
	quit(1 if failures else 0)
