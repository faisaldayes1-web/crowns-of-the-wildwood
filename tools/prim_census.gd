extends SceneTree
## Where do the primitives go? Lists the scene's heaviest mesh nodes by
## triangles, split by whether they cast sun shadows (a caster is drawn once
## per cascade). Run: godot --path . --script tools/prim_census.gd -- --demo --seed=7 --map=3 --gfx=1
## claude-faisal3 2026-11-04.
func _init() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 14000:
		await process_frame
	var rows := {}
	var total := 0
	var cast := 0
	for n in root.find_children("*", "GeometryInstance3D", true, false):
		if not n.is_visible_in_tree():
			continue
		var tris := 0
		var mesh: Mesh = null
		var mult := 1
		if n is MeshInstance3D:
			mesh = n.mesh
		elif n is MultiMeshInstance3D and n.multimesh:
			mesh = n.multimesh.mesh
			mult = n.multimesh.visible_instance_count if n.multimesh.visible_instance_count >= 0 else n.multimesh.instance_count
		if mesh == null:
			continue
		for s in mesh.get_surface_count():
			var a := mesh.surface_get_arrays(s)
			var idx = a[Mesh.ARRAY_INDEX]
			tris += (idx.size() if idx != null else a[Mesh.ARRAY_VERTEX].size()) / 3
		tris *= mult
		total += tris
		var casts: bool = n.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if casts:
			cast += tris
		var key := "%s|%s|%s" % [n.get_class(), str(n.get_parent().name).left(14), "cast" if casts else "nocast"]
		var mname := mesh.resource_name if mesh.resource_name != "" else str(n.name).left(20)
		key = "%s|%s" % [key, mname]
		rows[key] = rows.get(key, 0) + tris
		if n is MultiMeshInstance3D and tris > 30000:
			print("CENSUS-MM tris=%d inst=%d meshtris=%d at=%s mesh=%s name=%s shader=%s" % [tris, mult, tris / maxi(mult, 1), n.global_position, mesh.get_class(), n.name, (n.material_override.shader.resource_path if n.material_override is ShaderMaterial else "-")])
	var keys := rows.keys()
	keys.sort_custom(func(a, b): return rows[a] > rows[b])
	print("CENSUS total_tris=%d casting=%d" % [total, cast])
	for k in keys.slice(0, 25):
		print("CENSUS %9d  %s" % [rows[k], k])
	quit()
