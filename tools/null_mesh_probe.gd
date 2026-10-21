extends SceneTree
## Codex-faisal: bounded diagnostic of dummy-renderer mesh lifetime.

func _init() -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = BoxMesh.new()
	root.add_child(instance)
	await process_frame # SceneTree initialization has not entered nodes before this.
	if "--guard" in OS.get_cmdline_user_args():
		var guard := preload("res://scripts/headless_mesh_lifetime.gd")
		guard.watch(instance)
		guard.watch(instance) # Repeated world hooks must not duplicate connections.
		var original := instance.mesh
		root.remove_child(instance)
		if DisplayServer.get_name() == "headless" and instance.mesh != null:
			push_error("HEADLESS_MESH_TEST detach failed")
			quit(1)
			return
		root.add_child(instance)
		if instance.mesh != original:
			push_error("HEADLESS_MESH_TEST re-entry did not restore mesh")
			quit(1)
			return
		root.remove_child(instance)
		var replacement := SphereMesh.new()
		instance.mesh = replacement
		root.add_child(instance)
		if instance.mesh != replacement:
			push_error("HEADLESS_MESH_TEST overwrote replacement mesh")
			quit(1)
			return
		print("HEADLESS_MESH_TEST PASS repeated watch, detach, re-entry, replacement")
	await process_frame
	print("PROBE built mesh")
	if "--detach" in OS.get_cmdline_user_args():
		instance.mesh = null
		print("PROBE detached mesh")
	if "--free-first" in OS.get_cmdline_user_args():
		instance.free()
		print("PROBE freed instance")
	print("PROBE quit")
	quit()
