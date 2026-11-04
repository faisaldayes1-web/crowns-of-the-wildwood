extends SceneTree
## Turns tools/blender/kit_trees.py's vertex streams into the forest kit's
## modelled tree meshes (claude-faisal/crowns-polish round 5):
##     blender -b --factory-startup -P tools/blender/kit_trees.py -- C:/Temp/kit
##     godot --headless --path . --script tools/import_kit_trees.gd -- C:/Temp/kit
## Each assets/models/kit/<name>.res is an ArrayMesh whose vertex colour
## carries (shade, hue, kind, 1); forest_kit.gd maps it through each map's
## palette when it builds the tree.

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var src: String = args[0] if args.size() > 0 else "C:/Temp/kit"
	DirAccess.make_dir_recursive_absolute("res://assets/models/kit")
	for name in ["pine0", "pine1", "pine2", "broad0", "broad1", "broad2"]:
		var f := FileAccess.open(src.path_join(name + ".bin"), FileAccess.READ)
		if f == null:
			push_error("missing " + name)
			continue
		var data := f.get_buffer(f.get_length()).to_float32_array()
		var n := data.size() / 9
		var pos := PackedVector3Array()
		var nrm := PackedVector3Array()
		var col := PackedColorArray()
		pos.resize(n)
		nrm.resize(n)
		col.resize(n)
		for i in n:
			var o := i * 9
			pos[i] = Vector3(data[o], data[o + 1], data[o + 2])
			nrm[i] = Vector3(data[o + 3], data[o + 4], data[o + 5]).normalized()
			col[i] = Color(data[o + 6], data[o + 7], data[o + 8], 1.0)
		# Wind each triangle so its face matches its vertex normals (Godot
		# draws clockwise front faces).
		for t in range(0, n, 3):
			var fn := (pos[t + 1] - pos[t]).cross(pos[t + 2] - pos[t])
			if fn.dot(nrm[t] + nrm[t + 1] + nrm[t + 2]) > 0.0:
				var p := pos[t + 1]; pos[t + 1] = pos[t + 2]; pos[t + 2] = p
				var q := nrm[t + 1]; nrm[t + 1] = nrm[t + 2]; nrm[t + 2] = q
				var c := col[t + 1]; col[t + 1] = col[t + 2]; col[t + 2] = c
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = pos
		arr[Mesh.ARRAY_NORMAL] = nrm
		arr[Mesh.ARRAY_COLOR] = col
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var err := ResourceSaver.save(m, "res://assets/models/kit/%s.res" % name)
		print("KIT %s %d tris save %d" % [name, n / 3, err])
	quit()
