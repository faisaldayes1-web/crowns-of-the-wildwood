extends RefCounted
## Small outfit touches from the character art sheet, added on top of the
## KayKit models: a knotted scarf for Knights and Rangers in their side's
## colour (or the player's trim colour), with its tails flying behind.

static func _bone_node(skeleton: Skeleton3D, bone: String) -> Node3D:
	## A node that follows `bone`, with model-space coordinates.
	var b := skeleton.find_bone(bone)
	if b < 0:
		return null
	var att := BoneAttachment3D.new()
	att.bone_name = bone
	skeleton.add_child(att)
	var n := Node3D.new()
	n.transform = skeleton.get_bone_global_rest(b).affine_inverse()
	att.add_child(n)
	return n


static func dress(skeleton: Skeleton3D, role: int, color: Color, outline: Material) -> void:
	if role != 1 and role != 2:   # Knight, Ranger
		return
	var n := _bone_node(skeleton, "chest")
	if n == null:
		return
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = color
	cloth.roughness = 0.9
	cloth.rim_enabled = true
	cloth.rim = 0.3
	cloth.next_pass = outline
	var dark := cloth.duplicate()
	dark.albedo_color = color.darkened(0.25)
	# The wrap round the neck.
	var wrap := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.24
	tor.outer_radius = 0.43
	tor.rings = 20
	tor.ring_segments = 10
	wrap.mesh = tor
	wrap.material_override = cloth
	wrap.position = Vector3(0, 1.19, 0.0)
	wrap.scale = Vector3(1.0, 0.55, 0.92)
	n.add_child(wrap)
	# The knot at the side and two tails trailing behind.
	var knot := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.11
	s.height = 0.2
	knot.mesh = s
	knot.material_override = cloth
	knot.position = Vector3(0.22, 1.14, 0.24)
	n.add_child(knot)
	for k in 2:
		var tail := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.15, 0.36 - k * 0.08, 0.04)
		tail.mesh = b
		tail.material_override = dark if k == 1 else cloth
		tail.position = Vector3(0.26 + k * 0.08, 0.98 + k * 0.03, 0.26 - k * 0.03)
		tail.rotation = Vector3(-0.25, 0.4, 0.35 + k * 0.3)
		n.add_child(tail)
