extends RefCounted
## Godot 4.3's dummy renderer reports a null mesh while destroying an attached
## MeshInstance3D. Detach on exit, before destruction; restore on re-entry so
## temporary removals/reparenting preserve the resource. No rendered-game hook.
## Agent: Codex-faisal

const SAVED_MESH := &"cw_headless_detached_mesh"

static func watch(node: Node) -> void:
	if DisplayServer.get_name() != "headless" or not node is MeshInstance3D:
		return
	var exiting := _detach.bind(node)
	if not node.tree_exiting.is_connected(exiting):
		node.tree_exiting.connect(exiting)
		node.tree_entered.connect(_restore.bind(node))
	_restore(node)

static func _detach(node: MeshInstance3D) -> void:
	if node.mesh != null:
		node.set_meta(SAVED_MESH, node.mesh)
		node.mesh = null

static func _restore(node: MeshInstance3D) -> void:
	if node.has_meta(SAVED_MESH):
		if node.mesh == null:
			node.mesh = node.get_meta(SAVED_MESH)
		node.remove_meta(SAVED_MESH)
