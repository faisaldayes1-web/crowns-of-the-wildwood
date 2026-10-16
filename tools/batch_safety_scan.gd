extends SceneTree

const StaticBatch = preload("res://scripts/static_batch.gd")
## Safety check for scripts/static_batch.gd. Runs a bot match with batching
## off and reports every scenery mesh the batcher would take that later
## moves, hides, changes mesh or material, or is freed, and every material it
## would merge whose properties change. Each one needs meta "no_batch" (on the
## node or an ancestor, or on the material). Counts frames, so run it with
## --fixed-fps to fast-forward:
##     godot --headless --path . --fixed-fps 60 --script tools/batch_safety_scan.gd -- --demo --seed=7 --no-batch [--map=N] [--scan-frames=36000]


func _pattern(n: Node) -> String:
	var parts := []
	var p := n
	for i in 3:
		if p == null:
			break
		parts.push_front(String(p.name).rstrip("0123456789@").trim_prefix("@"))
		p = p.get_parent()
	return "/".join(parts) + " @" + str(n.global_position.snapped(Vector3.ONE))


func _snap(n: MeshInstance3D) -> String:
	return "%s|%s|%s|%s" % [n.global_transform, n.is_visible_in_tree(), n.mesh.get_instance_id() if n.mesh else 0,
		n.material_override.get_instance_id() if n.material_override else 0]


func _init() -> void:
	var frames := 36000
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--scan-frames="):
			frames = int(a.trim_prefix("--scan-frames="))
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for i in 10:
		await process_frame
	var nodes := {}
	var names := {}
	var mats := {}
	var sigcache := {}
	for n in game.find_children("*", "MeshInstance3D", true, false):
		if n.mesh == null or not n.is_visible_in_tree() or StaticBatch._skip_subtree(n, game):
			continue
		var take := true
		for s in n.mesh.get_surface_count():
			if not StaticBatch._mergeable_material(n.get_active_material(s)):
				take = false
		if not take:
			continue
		nodes[n] = _snap(n)
		names[n] = _pattern(n)
		for s in n.mesh.get_surface_count():
			var m: Material = n.get_active_material(s)
			if not mats.has(m):
				mats[m] = [StaticBatch._sig(m, sigcache), names[n]]
	print("SAFE candidates: %d meshes, %d materials" % [nodes.size(), mats.size()])
	var bad := {}
	var done := 0
	while done < frames and not game.game_over:
		for i in 300:
			await process_frame
			if game.game_over:
				break
		done += 300
		for n in nodes:
			if bad.has(n):
				continue
			if not is_instance_valid(n):
				bad[n] = "freed " + names[n]
			elif _snap(n) != nodes[n]:
				bad[n] = "changed " + names[n]
		for m in mats:
			if not bad.has(m) and is_instance_valid(m) and StaticBatch._sig(m, sigcache) != mats[m][0]:
				bad[m] = "material changed (first user %s)" % mats[m][1]
	var lines := {}
	for k in bad:
		lines[bad[k]] = lines.get(bad[k], 0) + 1
	print("SAFE %d problems after %d frames%s" % [bad.size(), done, "" if bad.size() else ": batching is safe on this map"])
	for l in lines:
		print("SAFE  %4d  %s" % [lines[l], l])
	quit()
