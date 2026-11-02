extends SceneTree
## Agent: Codex-faisal. Mesh safety and quality budgets for the pine detail pass.

func _initialize() -> void:
	var kit = load("res://scripts/visual/forest_kit.gd").new(null)
	var failures := 0
	for palette in ["day", "night", "winter", "twilight"]:
		kit.palette = palette
		for shape in 3:
			for low in [false, true]:
				kit.low = low
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				kit._make_pine(st, 731, shape, "")
				var mesh := st.commit()
				var arrays := mesh.surface_get_arrays(0)
				var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
				# Bounded detail, including Twilight's existing glowing fruit.
				if verts.size() > (4000 if low else 6500) or verts.size() % 3 != 0:
					failures += 1
				for i in verts.size():
					if not verts[i].is_finite() or not normals[i].is_finite() or normals[i].length() < 0.9:
						failures += 1
				var bounds := mesh.get_aabb()
				if bounds.size.x > 4.1 or bounds.size.z > 4.1 or bounds.size.y > 7.0:
					failures += 1
				print("PINE %s shape%d low=%s vertices=%d bounds=%s" % [palette, shape, low, verts.size(), bounds])
	print("Pass 5 mesh test: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)
