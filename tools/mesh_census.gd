extends SceneTree
## Draw-call census of the match world: how many visible MeshInstance3D nodes
## there are, how many sit under a script (moving or breakable things) and
## how many are plain static scenery, and how the static ones group by
## (mesh, materials). Each group of two or more is one MultiMesh candidate.
##     godot --headless --path . --script tools/mesh_census.gd -- --demo --seed=7 [--map=N]


func _scripted_ancestor(n: Node, game: Node) -> bool:
	var p := n
	while p and p != game:
		if p.get_script() != null:
			return true
		p = p.get_parent()
	return false


func _init() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for i in 30:
		await process_frame
	var total := 0
	var scripted := 0
	var casters := 0
	var groups := {}
	var mats := {}
	var meshes := {}
	for n in game.find_children("*", "MeshInstance3D", true, false):
		if not n.is_visible_in_tree() or n.mesh == null:
			continue
		total += 1
		if n.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			casters += 1
		if _scripted_ancestor(n, game):
			scripted += 1
			continue
		var key := str(n.mesh.get_instance_id()) + "|" + str(n.material_override.get_instance_id() if n.material_override else 0)
		for s in n.get_surface_override_material_count():
			var m = n.get_surface_override_material(s)
			key += "|" + str(m.get_instance_id() if m else 0)
		groups[key] = groups.get(key, 0) + 1
		meshes[n.mesh.get_instance_id()] = n.mesh.get_class()
		var m0 = n.material_override if n.material_override else (n.get_active_material(0))
		if m0:
			mats[m0.get_instance_id()] = true
	var multi := 0
	var singles := 0
	var counts := groups.values()
	counts.sort()
	counts.reverse()
	for c in counts:
		if c >= 2:
			multi += c
		else:
			singles += 1
	var classes := {}
	for k in meshes:
		classes[meshes[k]] = classes.get(meshes[k], 0) + 1
	print("CENSUS visible mesh instances %d, shadow casters %d, under a script %d, static %d" % [total, casters, scripted, total - scripted])
	print("CENSUS static groups %d: %d instances in groups of 2+ (%d groups), %d singletons" % [groups.size(), multi, groups.size() - singles, singles])
	print("CENSUS biggest groups: %s" % str(counts.slice(0, 25)))
	print("CENSUS unique meshes %d by class %s, unique first materials %d" % [meshes.size(), str(classes), mats.size()])
	var mm := 0
	for n in game.find_children("*", "MultiMeshInstance3D", true, false):
		mm += 1
	print("CENSUS multimesh nodes %d" % mm)
	quit()
