extends RefCounted
## Small reusable chamfered masonry. Visual only; never creates collision.
## Agent: Codex-faisal/world.

static func mesh(size: Vector3, bevel: float = 0.08) -> ArrayMesh:
	var b := minf(bevel, minf(size.x, minf(size.y, size.z)) * 0.24)
	var x := size.x * 0.5
	var z := size.z * 0.5
	var y := size.y * 0.5
	var outline := [Vector2(-x + b, -z), Vector2(x - b, -z), Vector2(x, -z + b), Vector2(x, z - b), Vector2(x - b, z), Vector2(-x + b, z), Vector2(-x, z - b), Vector2(-x, -z + b)]
	var rings: Array = []
	for layer in 4:
		var ring: Array[Vector3] = []
		var h: float = [-y, -y + b, y - b, y][layer]
		for p in outline:
			var inset := Vector2(signf(p.x), signf(p.y)) * b if layer in [0, 3] else Vector2.ZERO
			ring.append(Vector3(p.x - inset.x, h, p.y - inset.y))
		rings.append(ring)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for layer in 3:
		for i in 8:
			var j := (i + 1) % 8
			_tri(st, rings[layer][i], rings[layer + 1][i], rings[layer + 1][j])
			_tri(st, rings[layer][i], rings[layer + 1][j], rings[layer][j])
	for i in 8:
		var j := (i + 1) % 8
		_tri(st, Vector3(0, y, 0), rings[3][j], rings[3][i])
		_tri(st, Vector3(0, -y, 0), rings[0][i], rings[0][j])
	st.generate_normals()
	return preload("res://scripts/static_batch.gd").kept_mesh(st)   # (a CPU copy for the match-start batching)

static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.set_smooth_group(-1)
	st.add_vertex(a)
	st.add_vertex(c)
	st.add_vertex(b)
