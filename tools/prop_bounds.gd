extends SceneTree
func _init():
	var names := []
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--pack="):
			only = arg.trim_prefix("--pack=")
	for pack in ["hex", "dungeon", "halloween", "furniture", "kitchen"]:
		if only != "" and pack != only:
			continue
		var dir := DirAccess.open("res://assets/props/%s" % pack)
		if dir == null:
			continue
		for f in dir.get_files():
			if f.ends_with(".gltf") or f.ends_with(".glb"):
				names.append(pack + "/" + f.trim_suffix(".gltf").trim_suffix(".glb"))
	for n in names:
		var ext := ".glb" if n.begins_with("dungeon/") else ".gltf"
		var sc = load("res://assets/props/%s%s" % [n, ext])
		if sc == null:
			continue
		var inst: Node3D = sc.instantiate()
		get_root().add_child(inst)
		var aabb := AABB()
		var first := true
		for m in inst.find_children("*", "MeshInstance3D", true, false):
			var a: AABB = m.global_transform * m.get_aabb()
			if first:
				aabb = a
				first = false
			else:
				aabb = aabb.merge(a)
		print("%s  min=%s size=%s" % [n, aabb.position.snapped(Vector3(0.01,0.01,0.01)), aabb.size.snapped(Vector3(0.01,0.01,0.01))])
		inst.queue_free()
	quit()
