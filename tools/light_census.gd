extends SceneTree
## Omni lights in a map's world, grouped by range and energy: where the
## light count comes from. claude-faisal3 2026-11-05.
##     godot --path . --script tools/light_census.gd -- --demo --seed=7 --map=N --debug-unlock


func _init() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for i in 60:
		await process_frame
	var groups := {}
	var total := 0
	for l in game.find_children("*", "OmniLight3D", true, false):
		if not l.visible:
			continue
		total += 1
		var key := "range %4.1f energy %.2f shadow=%s parent=%s" % [l.omni_range, l.light_energy, str(l.shadow_enabled), l.get_parent().get_script().resource_path.get_file() if l.get_parent().get_script() else l.get_parent().get_class()]
		groups[key] = groups.get(key, 0) + 1
	print("LIGHTS total=%d" % total)
	var keys := groups.keys()
	keys.sort_custom(func(a, b): return groups[a] > groups[b])
	for k in keys.slice(0, 20):
		print("LIGHTS %4d  %s" % [groups[k], k])
	quit()
