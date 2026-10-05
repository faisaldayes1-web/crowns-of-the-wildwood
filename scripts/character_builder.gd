extends RefCounted
## Builds the chunky low-poly character models out of primitive meshes, in the
## style of the concept sheet: big head, small body, class gear, faction look
## (elves: pointed ears, blond hair, leaf greens; humans: brown hair, steel
## and blue). Returns the pivots unit.gd animates.

const Stats = preload("res://scripts/stats.gd")
const Role = Stats.Role

const STEEL := Color(0.72, 0.74, 0.78)
const DARK_STEEL := Color(0.45, 0.47, 0.52)
const LEATHER := Color(0.42, 0.28, 0.15)
const WOOD := Color(0.5, 0.33, 0.17)
const GOLD := Color(0.95, 0.78, 0.25)
const CLOTH_WHITE := Color(0.93, 0.92, 0.85)
const EYE := Color(0.12, 0.1, 0.1)


static func palette(team: int, role: int) -> Dictionary:
	## Colours for one faction + class, after the concept sheet swatches.
	var elf := team == 0
	var p := {
		"skin": Color(0.97, 0.86, 0.74) if elf else Color(0.94, 0.78, 0.62),
		"hair": Color(0.93, 0.8, 0.4) if elf else Color(0.4, 0.25, 0.12),
		"pants": Color(0.35, 0.25, 0.15),
		"boots": Color(0.3, 0.2, 0.12),
		"accent": GOLD,
	}
	match role:
		Role.BASE:
			p.tunic = Color(0.55, 0.65, 0.4) if elf else Color(0.45, 0.5, 0.7)
		Role.KNIGHT:
			p.tunic = Color(0.2, 0.5, 0.25) if elf else Color(0.15, 0.3, 0.75)
			p.pants = DARK_STEEL
			p.boots = DARK_STEEL
		Role.RANGER:
			p.tunic = Color(0.3, 0.5, 0.2) if elf else Color(0.2, 0.42, 0.22)
			p.hood = Color(0.25, 0.42, 0.18) if elf else Color(0.18, 0.36, 0.2)
			p.pants = Color(0.5, 0.36, 0.2)
		Role.MAGE:
			p.tunic = Color(0.45, 0.3, 0.85) if elf else Color(0.18, 0.28, 0.8)
			p.hair = Color(0.9, 0.9, 0.95) if elf else p.hair
			p.gem = Color(0.75, 0.4, 1.0) if elf else Color(0.3, 0.6, 1.0)
		Role.HEALER:
			p.tunic = CLOTH_WHITE
			p.trim = Color(0.3, 0.55, 0.25)
			p.gem = Color(0.3, 0.95, 0.5)
	return p


static func build(root: Node3D, team: int, role: int) -> Dictionary:
	## Builds the model under `root` (cleared first) and returns the pivots:
	## torso, head, left_arm, right_arm, left_leg, right_leg, plus the
	## materials that flash when hit (flash_mats).
	for child in root.get_children():
		child.queue_free()
	var p := palette(team, role)
	var elf := team == 0
	var out := {"flash_mats": []}

	var skin := _mat(p.skin)
	var tunic := _mat(p.tunic)
	out.flash_mats.append(skin)
	out.flash_mats.append(tunic)

	# Legs: pivots at the hip so they can swing.
	for side in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(side * 0.16, 0.5, 0)
		root.add_child(leg)
		var robe := role == Role.MAGE or role == Role.HEALER
		if not robe:
			_box(leg, Vector3(0.22, 0.46, 0.26), Vector3(0, -0.23, 0), _mat(p.pants))
		_box(leg, Vector3(0.26, 0.14, 0.34), Vector3(0, -0.45, -0.03), _mat(p.boots))
		out["left_leg" if side < 0 else "right_leg"] = leg

	# Torso pivot carries the body, head and arms so the whole upper body bobs.
	var torso := Node3D.new()
	root.add_child(torso)
	out.torso = torso
	if role == Role.MAGE or role == Role.HEALER:
		# A robe that flares out over the legs.
		var robe := CylinderMesh.new()
		robe.top_radius = 0.3
		robe.bottom_radius = 0.48
		robe.height = 0.75
		_mesh(torso, robe, Vector3(0, 0.4, 0), tunic)
		if role == Role.HEALER:
			var hem := CylinderMesh.new()
			hem.top_radius = 0.47
			hem.bottom_radius = 0.49
			hem.height = 0.1
			_mesh(torso, hem, Vector3(0, 0.08, 0), _mat(p.trim))
	_box(torso, Vector3(0.56, 0.6, 0.4), Vector3(0, 0.8, 0), tunic)
	_box(torso, Vector3(0.6, 0.1, 0.44), Vector3(0, 0.6, 0), _mat(LEATHER))  # belt
	_box(torso, Vector3(0.12, 0.12, 0.05), Vector3(0, 0.6, -0.23), _mat(GOLD))  # buckle

	# Head: a big sphere with eyes, hair and (for elves) pointed ears.
	var head := Node3D.new()
	head.position = Vector3(0, 1.12, 0)
	torso.add_child(head)
	out.head = head
	var skull := SphereMesh.new()
	skull.radius = 0.4
	skull.height = 0.8
	_mesh(head, skull, Vector3(0, 0.38, 0), skin)
	for side in [-1.0, 1.0]:
		_box(head, Vector3(0.08, 0.1, 0.04), Vector3(side * 0.14, 0.42, -0.38), _mat(EYE))
	if elf:
		for side in [-1.0, 1.0]:
			var ear := CylinderMesh.new()
			ear.top_radius = 0.0
			ear.bottom_radius = 0.08
			ear.height = 0.32
			var e := _mesh(head, ear, Vector3(side * 0.5, 0.42, 0), skin)
			e.rotation.z = -side * PI / 2.0
	var hair_mat := _mat(p.hair)
	if role != Role.KNIGHT and role != Role.HEALER:
		# A cap of hair, with a fringe in front.
		_box(head, Vector3(0.82, 0.22, 0.82), Vector3(0, 0.7, 0), hair_mat)
		_box(head, Vector3(0.7, 0.14, 0.12), Vector3(0, 0.6, -0.36), hair_mat)
		if role == Role.MAGE or role == Role.HEALER or (elf and role == Role.RANGER):
			_box(head, Vector3(0.6, 0.5, 0.14), Vector3(0, 0.3, 0.36), hair_mat)  # long hair behind

	# Arms: pivots at the shoulder; the right arm holds the weapon.
	var arms := {}
	for side in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(side * 0.36, 1.05, 0)
		torso.add_child(arm)
		var sleeve := CapsuleMesh.new()
		sleeve.radius = 0.11
		sleeve.height = 0.5
		_mesh(arm, sleeve, Vector3(0, -0.22, 0), tunic)
		var hand := SphereMesh.new()
		hand.radius = 0.12
		hand.height = 0.24
		_mesh(arm, hand, Vector3(0, -0.5, 0), skin)
		arms[side] = arm
	out.left_arm = arms[-1.0]
	out.right_arm = arms[1.0]

	match role:
		Role.BASE:
			# A villager with a wooden club.
			_box(out.right_arm, Vector3(0.1, 0.7, 0.1), Vector3(0, -0.7, 0), _mat(WOOD))
			_box(out.right_arm, Vector3(0.16, 0.22, 0.16), Vector3(0, -1.0, 0), _mat(WOOD.darkened(0.2)))
		Role.KNIGHT:
			_knight(out, p, team, elf, tunic)
		Role.RANGER:
			_ranger(out, p, tunic)
		Role.MAGE:
			_mage(out, p, tunic)
		Role.HEALER:
			_healer(out, p)
	return out


static func _knight(out: Dictionary, p: Dictionary, team: int, elf: bool, tunic: StandardMaterial3D) -> void:
	var steel := _mat(STEEL)
	steel.metallic = 0.6
	steel.roughness = 0.4
	var head: Node3D = out.head
	# Open helmet: a dome, a brow band, cheek guards, a nose guard and a plume.
	var dome := SphereMesh.new()
	dome.radius = 0.46
	dome.height = 0.46
	dome.is_hemisphere = true
	_mesh(head, dome, Vector3(0, 0.5, 0), steel)
	var band := CylinderMesh.new()
	band.top_radius = 0.47
	band.bottom_radius = 0.47
	band.height = 0.1
	_mesh(head, band, Vector3(0, 0.53, 0), _mat(DARK_STEEL))
	for side in [-1.0, 1.0]:
		_box(head, Vector3(0.1, 0.34, 0.3), Vector3(side * 0.42, 0.3, -0.02), steel)
	_box(head, Vector3(0.07, 0.3, 0.06), Vector3(0, 0.36, -0.43), steel)
	var plume := BoxMesh.new()
	plume.size = Vector3(0.12, 0.3, 0.7)
	var plume_color: Color = Stats.FACTIONS[team].color
	_mesh(head, plume, Vector3(0, 0.95, 0.05), _mat(plume_color))
	# Pauldrons and a chest plate over the tabard.
	var torso: Node3D = out.torso
	for side in [-1.0, 1.0]:
		var pad := SphereMesh.new()
		pad.radius = 0.2
		pad.height = 0.3
		_mesh(torso, pad, Vector3(side * 0.38, 1.1, 0), steel)
	_box(torso, Vector3(0.6, 0.4, 0.14), Vector3(0, 0.9, -0.2), steel)
	_box(torso, Vector3(0.3, 0.45, 0.04), Vector3(0, 0.82, -0.29), tunic)  # tabard stripe
	# Sword in the right hand.
	var right: Node3D = out.right_arm
	_box(right, Vector3(0.05, 0.9, 0.16), Vector3(0, -1.0, 0), steel)
	_box(right, Vector3(0.3, 0.06, 0.08), Vector3(0, -0.56, 0), _mat(GOLD))
	_box(right, Vector3(0.08, 0.14, 0.08), Vector3(0, -0.45, 0), _mat(LEATHER))
	# Shield on the left arm, in the team colour with a gold rim and crest.
	var left: Node3D = out.left_arm
	var shield_color: Color = Stats.FACTIONS[team].color
	_box(left, Vector3(0.08, 0.76, 0.6), Vector3(-0.14, -0.3, -0.05), _mat(GOLD))
	_box(left, Vector3(0.1, 0.64, 0.48), Vector3(-0.15, -0.3, -0.05), _mat(shield_color))
	var crest := BoxMesh.new()
	crest.size = Vector3(0.04, 0.26, 0.16) if elf else Vector3(0.04, 0.22, 0.22)
	_mesh(left, crest, Vector3(-0.21, -0.3, -0.05), _mat(GOLD if not elf else Color(0.85, 0.95, 0.8)))


static func _ranger(out: Dictionary, p: Dictionary, tunic: StandardMaterial3D) -> void:
	var head: Node3D = out.head
	var hood := CylinderMesh.new()
	hood.top_radius = 0.0
	hood.bottom_radius = 0.47
	hood.height = 0.6
	var h := _mesh(head, hood, Vector3(0, 0.92, 0.05), _mat(p.hood))
	h.rotation.x = -0.2
	_box(head, Vector3(0.9, 0.12, 0.9), Vector3(0, 0.66, 0), _mat(p.hood))  # hood brim
	var torso: Node3D = out.torso
	# Cloak, quiver and arrows on the back.
	_box(torso, Vector3(0.66, 0.85, 0.08), Vector3(0, 0.72, 0.26), _mat(p.hood))
	var quiver := CylinderMesh.new()
	quiver.top_radius = 0.09
	quiver.bottom_radius = 0.08
	quiver.height = 0.55
	var q := _mesh(torso, quiver, Vector3(0.18, 0.95, 0.32), _mat(LEATHER))
	q.rotation.z = -0.35
	for i in 3:
		var shaft := _box(torso, Vector3(0.03, 0.4, 0.03), Vector3(0.28 + i * 0.03, 1.3 + i * 0.02, 0.32 - i * 0.04), _mat(WOOD))
		shaft.rotation.z = -0.35
		_box(torso, Vector3(0.08, 0.1, 0.03), Vector3(0.37 + i * 0.03, 1.48 + i * 0.02, 0.32 - i * 0.04), _mat(CLOTH_WHITE))
	# Leather bracers and a strap across the chest.
	for arm in [out.left_arm, out.right_arm]:
		_box(arm, Vector3(0.26, 0.18, 0.26), Vector3(0, -0.36, 0), _mat(LEATHER))
	var strap := _box(torso, Vector3(0.1, 0.72, 0.42), Vector3(0, 0.8, 0), _mat(LEATHER))
	strap.rotation.z = 0.6
	# Bow in the left hand: two angled limbs and a string.
	var left: Node3D = out.left_arm
	var wood := _mat(WOOD)
	var upper := _box(left, Vector3(0.06, 0.6, 0.06), Vector3(0, -0.22, -0.2), wood)
	upper.rotation.x = 0.35
	var lower := _box(left, Vector3(0.06, 0.6, 0.06), Vector3(0, -0.78, -0.2), wood)
	lower.rotation.x = -0.35
	_box(left, Vector3(0.015, 1.1, 0.015), Vector3(0, -0.5, -0.02), _mat(CLOTH_WHITE))


static func _mage(out: Dictionary, p: Dictionary, tunic: StandardMaterial3D) -> void:
	var head: Node3D = out.head
	var brim := CylinderMesh.new()
	brim.top_radius = 0.62
	brim.bottom_radius = 0.66
	brim.height = 0.07
	var b := _mesh(head, brim, Vector3(0, 0.72, 0), tunic)
	b.rotation.x = 0.12
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.42
	cone.height = 0.85
	var c := _mesh(head, cone, Vector3(0, 1.1, 0.08), tunic)
	c.rotation.x = 0.25
	_box(head, Vector3(0.9, 0.08, 0.9), Vector3(0, 0.76, 0), _mat(GOLD))  # hat band
	var torso: Node3D = out.torso
	_box(torso, Vector3(0.62, 0.5, 0.1), Vector3(0, 0.95, -0.2), tunic.duplicate())  # mantle
	_box(torso, Vector3(0.64, 0.06, 0.46), Vector3(0, 1.08, 0), _mat(GOLD))  # collar trim
	# Staff with a glowing crystal in the right hand.
	var right: Node3D = out.right_arm
	_box(right, Vector3(0.07, 1.8, 0.07), Vector3(0, -0.1, -0.1), _mat(WOOD))
	var gem_mat := _mat(p.gem)
	gem_mat.emission_enabled = true
	gem_mat.emission = p.gem
	gem_mat.emission_energy_multiplier = 1.4
	var gem := SphereMesh.new()
	gem.radial_segments = 4
	gem.rings = 2
	gem.radius = 0.16
	gem.height = 0.44
	_mesh(right, gem, Vector3(0, 0.95, -0.1), gem_mat)
	_box(right, Vector3(0.2, 0.08, 0.2), Vector3(0, 0.72, -0.1), _mat(GOLD))


static func _healer(out: Dictionary, p: Dictionary) -> void:
	var head: Node3D = out.head
	var white := _mat(CLOTH_WHITE)
	# Veil: a cloth cap with a long fall down the back.
	var veil := SphereMesh.new()
	veil.radius = 0.45
	veil.height = 0.45
	veil.is_hemisphere = true
	_mesh(head, veil, Vector3(0, 0.46, 0), white)
	_box(head, Vector3(0.84, 0.08, 0.84), Vector3(0, 0.5, 0), white)
	_box(head, Vector3(0.78, 0.8, 0.1), Vector3(0, 0.2, 0.4), white)
	_box(head, Vector3(0.1, 0.5, 0.5), Vector3(-0.42, 0.25, 0.12), white)
	_box(head, Vector3(0.1, 0.5, 0.5), Vector3(0.42, 0.25, 0.12), white)
	_box(head, Vector3(0.9, 0.06, 0.9), Vector3(0, 0.72, 0), _mat(GOLD))  # circlet
	var torso: Node3D = out.torso
	_box(torso, Vector3(0.22, 0.6, 0.04), Vector3(0, 0.8, -0.23), _mat(p.trim))  # stole
	_box(torso, Vector3(0.64, 0.08, 0.46), Vector3(0, 1.08, 0), _mat(p.trim))
	# Staff with a green gem held in a gold ring.
	var right: Node3D = out.right_arm
	_box(right, Vector3(0.07, 1.7, 0.07), Vector3(0, -0.15, -0.1), _mat(GOLD.darkened(0.3)))
	var ring := TorusMesh.new()
	ring.inner_radius = 0.16
	ring.outer_radius = 0.24
	var r := _mesh(right, ring, Vector3(0, 0.85, -0.1), _mat(GOLD))
	r.rotation.y = PI / 2.0
	var gem_mat := _mat(p.gem)
	gem_mat.emission_enabled = true
	gem_mat.emission = p.gem
	gem_mat.emission_energy_multiplier = 1.4
	var gem := SphereMesh.new()
	gem.radial_segments = 4
	gem.rings = 2
	gem.radius = 0.12
	gem.height = 0.3
	_mesh(right, gem, Vector3(0, 0.85, -0.1), gem_mat)


# --- Helpers -----------------------------------------------------------------

static func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	return m


static func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi


static func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	return _mesh(parent, box, pos, mat)


static func build_monarch(root: Node3D, team: int) -> void:
	## The Elf Queen or Human King: a robed figure with a crown and a cape.
	for child in root.get_children():
		child.queue_free()
	var elf := team == 0
	var team_color: Color = Stats.FACTIONS[team].color
	var skin := _mat(Color(0.97, 0.86, 0.74) if elf else Color(0.94, 0.78, 0.62))
	var robe_mat := _mat(team_color.lightened(0.25))
	var robe := CylinderMesh.new()
	robe.top_radius = 0.32
	robe.bottom_radius = 0.6
	robe.height = 0.9
	_mesh(root, robe, Vector3(0, 0.45, 0), robe_mat)
	_box(root, Vector3(0.6, 0.55, 0.42), Vector3(0, 0.95, 0), robe_mat)
	_box(root, Vector3(0.64, 0.1, 0.46), Vector3(0, 0.75, 0), _mat(GOLD))
	_box(root, Vector3(0.14, 0.5, 0.04), Vector3(0, 0.95, -0.23), _mat(GOLD))  # trim
	_box(root, Vector3(0.8, 1.1, 0.08), Vector3(0, 0.7, 0.3), _mat(Color(0.7, 0.12, 0.15)))  # cape
	for side in [-1.0, 1.0]:
		var arm := CapsuleMesh.new()
		arm.radius = 0.1
		arm.height = 0.5
		var a := _mesh(root, arm, Vector3(side * 0.38, 0.95, 0), robe_mat)
		a.rotation.z = side * 0.3
		var hand := SphereMesh.new()
		hand.radius = 0.1
		hand.height = 0.2
		_mesh(root, hand, Vector3(side * 0.46, 0.72, 0), skin)
	var head := Node3D.new()
	head.position.y = 1.25
	root.add_child(head)
	var skull := SphereMesh.new()
	skull.radius = 0.4
	skull.height = 0.8
	_mesh(head, skull, Vector3(0, 0.38, 0), skin)
	for side in [-1.0, 1.0]:
		_box(head, Vector3(0.08, 0.1, 0.04), Vector3(side * 0.14, 0.42, -0.38), _mat(EYE))
	var hair := _mat(Color(0.93, 0.8, 0.4) if elf else Color(0.5, 0.3, 0.15))
	_box(head, Vector3(0.82, 0.22, 0.82), Vector3(0, 0.7, 0), hair)
	_box(head, Vector3(0.7, 0.14, 0.12), Vector3(0, 0.6, -0.36), hair)
	if elf:
		_box(head, Vector3(0.6, 0.7, 0.14), Vector3(0, 0.25, 0.36), hair)
		for side in [-1.0, 1.0]:
			var ear := CylinderMesh.new()
			ear.top_radius = 0.0
			ear.bottom_radius = 0.08
			ear.height = 0.32
			var e := _mesh(head, ear, Vector3(side * 0.5, 0.42, 0), skin)
			e.rotation.z = -side * PI / 2.0
	else:
		_box(head, Vector3(0.5, 0.3, 0.2), Vector3(0, 0.1, -0.3), hair)  # beard
	var gold := _mat(GOLD)
	gold.metallic = 0.7
	gold.roughness = 0.3
	var band := CylinderMesh.new()
	band.top_radius = 0.3
	band.bottom_radius = 0.28
	band.height = 0.18
	_mesh(head, band, Vector3(0, 0.88, 0), gold)
	for i in 5:
		var ang := TAU * i / 5.0
		var spike := CylinderMesh.new()
		spike.top_radius = 0.0
		spike.bottom_radius = 0.06
		spike.height = 0.2
		_mesh(head, spike, Vector3(cos(ang) * 0.28, 1.06, sin(ang) * 0.28), gold)
	var jewel := SphereMesh.new()
	jewel.radius = 0.07
	jewel.height = 0.14
	var jm := _mat(Color(0.9, 0.2, 0.3))
	jm.emission_enabled = true
	jm.emission = Color(0.9, 0.2, 0.3)
	_mesh(head, jewel, Vector3(0, 0.9, -0.3), jm)
