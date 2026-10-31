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
	# claude-faisal/stutter 2026-10-30: spheres, prisms, planes, quads and tori too.
	for k in 120:
		var sp := SphereMesh.new()
		sp.radius = rng.randf_range(0.02, 6.0)
		sp.height = sp.radius * 2.0 if k % 3 == 0 else rng.randf_range(0.02, 10.0)
		sp.radial_segments = [6, 8, 10, 12, 16, 24, 64][k % 7]
		sp.rings = [3, 4, 6, 8, 12, 32][k % 6]
		sp.is_hemisphere = k % 4 == 0
		same_shape = _compare(sp, worst) and same_shape
	for k in 60:
		var pr := PrismMesh.new()
		pr.size = Vector3(rng.randf_range(0.02, 8.0), rng.randf_range(0.02, 8.0), rng.randf_range(0.02, 8.0))
		pr.left_to_right = [0.0, 0.5, 1.0, rng.randf()][k % 4]
		if k % 5 == 0:
			pr.subdivide_width = rng.randi_range(0, 2)
			pr.subdivide_height = rng.randi_range(0, 2)
			pr.subdivide_depth = rng.randi_range(0, 2)
		same_shape = _compare(pr, worst) and same_shape
	for k in 60:
		var pl: PlaneMesh = QuadMesh.new() if k % 2 == 0 else PlaneMesh.new()
		pl.size = Vector2(rng.randf_range(0.02, 20.0), rng.randf_range(0.02, 20.0))
		pl.orientation = [PlaneMesh.FACE_X, PlaneMesh.FACE_Y, PlaneMesh.FACE_Z][k % 3]
		if k % 4 == 0:
			pl.center_offset = Vector3(rng.randf_range(-2, 2), rng.randf_range(-2, 2), rng.randf_range(-2, 2))
		if k % 5 == 0:
			pl.subdivide_width = rng.randi_range(0, 3)
			pl.subdivide_depth = rng.randi_range(0, 3)
		same_shape = _compare(pl, worst) and same_shape
	for k in 60:
		var to := TorusMesh.new()
		to.inner_radius = rng.randf_range(0.02, 3.0)
		to.outer_radius = to.inner_radius + rng.randf_range(0.02, 2.0)
		if k % 6 == 0:
			var swap := to.inner_radius
			to.inner_radius = to.outer_radius
			to.outer_radius = swap
		to.rings = [8, 12, 16, 24, 64][k % 5]
		to.ring_segments = [4, 6, 8, 12, 32][k % 5]
		same_shape = _compare(to, worst) and same_shape
	var flipped := BoxMesh.new()
	flipped.flip_faces = true
	print("PRIMS compared %d (%d left to the read-back): worst position %.7f of size, normal %.5f, uv %.6f, tangent %.5f" % [
		worst.compared, worst.skipped, worst.pos, worst.normal, worst.uv, worst.tangent])
	check(same_shape, "every box, cylinder, sphere, prism, plane, quad and torus has the read-back's vertex count and triangles")
	check(worst.compared == 700, "all 700 shapes are worked out on the CPU")
	check(worst.pos < 0.00002, "every vertex is where the read-back has it")   # (tori: ring angles rebuilt from float32 normals)
	check(worst.normal < 0.003, "every normal matches the read-back")
	check(worst.uv < 0.00001 and worst.tangent < 0.005,   # (the read-back's tangents are octahedral-compressed: ~0.003 off)
		"UVs and tangents match the read-back")
	check(StaticBatch._scaled_primitive(flipped).is_empty(), "a flipped box is left to the read-back")
	print("batch primitive test: %d failure(s)" % failures)
	quit(1 if failures else 0)
