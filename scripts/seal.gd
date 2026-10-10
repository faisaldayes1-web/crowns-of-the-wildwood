extends Node3D
## A class hat: the headgear you grab in your cellar to become that class,
## after Fat Princess's hat machines. It hovers over a pedestal, turning
## slowly. Walk up and press the interact key (bots simply step on it).

const Stats = preload("res://scripts/stats.gd")

var game
var team := 0
var role := 0
var seal: Node3D
var ring: MeshInstance3D
var light: OmniLight3D
var prompt: Label3D
var t := 0.0
var near := false
var locked := false
var lift := 0.0   # the pedestal stands on a stone base in the open courtyard


func setup(p_game, p_team: int, p_role: int, pos: Vector3) -> void:
	game = p_game
	team = p_team
	role = p_role
	position = pos
	var color: Color = Stats.ROLES[role].color
	var elf := team == 0
	# The open courtyard's stations (the Wildwood Elves, 2026-10-09): the
	# pedestal is carved cream sandstone with a gold cap and stands on the
	# station's layered stone base (game.gd _add_elf_class_station).
	var open: bool = elf and game.cellar_floor(p_team) >= 0.0
	if open:
		lift = 0.24

	# The pedestal: a bark stump for the Elves, a stone plinth for the Humans.
	var ped := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.42 if elf else 0.36
	cyl.bottom_radius = 0.5 if elf else 0.44
	cyl.height = 0.8
	cyl.radial_segments = 10 if elf else 8
	if open:
		cyl.top_radius = 0.34
		cyl.bottom_radius = 0.42
		cyl.radial_segments = 8
	ped.mesh = cyl
	ped.position.y = 0.4 + lift
	ped.material_override = game._ashlar(Color(0.95, 0.92, 0.86)) if open else (game._pbr("bark", 0.6, Color(0.8, 0.76, 0.62)) if elf else game._pbr("stone", 0.5, Color(0.9, 0.86, 0.78)))
	add_child(ped)
	var cap := MeshInstance3D.new()
	var cap_mesh := CylinderMesh.new()
	cap_mesh.top_radius = 0.5
	cap_mesh.bottom_radius = 0.46
	cap_mesh.height = 0.08
	if open:
		cap_mesh.top_radius = 0.42
		cap_mesh.bottom_radius = 0.38
		cap_mesh.radial_segments = 8
	cap.mesh = cap_mesh
	cap.position.y = 0.84 + lift
	var cap_mat: StandardMaterial3D = game._material(Color(0.5, 0.78, 0.6) if elf and not open else Color(0.95, 0.78, 0.3))
	cap_mat.metallic = 0.2 if elf and not open else 0.7
	cap_mat.roughness = 0.6 if elf and not open else 0.35
	cap_mat.emission_enabled = elf and not open
	cap_mat.emission = Color(0.3, 0.7, 0.5)
	cap_mat.emission_energy_multiplier = 0.3
	cap.material_override = cap_mat
	add_child(cap)

	# A soft class-colour glow on the floor around the pedestal (on the stone
	# base's outer step in the open courtyard, and quieter there).
	ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.8 if open else 0.95
	torus.outer_radius = 0.96 if open else 1.15
	ring.mesh = torus
	ring.position.y = 0.13 if open else 0.06
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(color, 0.45 if open else 0.55)
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.emission_enabled = true
	rm.emission = color
	rm.emission_energy_multiplier = 0.8 if open else 1.2
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = rm
	add_child(ring)

	# The hat itself: the class's headgear, floating over the pedestal and
	# turning slowly (after Fat Princess's hats). Grab it to become the class.
	seal = Node3D.new()
	seal.position.y = 1.4 + lift
	seal.scale = Vector3.ONE * 1.4   # chunky, but the alcove sign must stay visible
	add_child(seal)
	locked = role == Stats.Role.ROGUE and not game.unlocked()
	_build_hat(seal, elf)
	if locked:
		for m in seal.find_children("*", "MeshInstance3D", true, false):
			var mat := m.material_override as StandardMaterial3D
			if mat:
				mat.albedo_color = mat.albedo_color.lerp(Color(0.4, 0.4, 0.45), 0.7)

	var sparks := CPUParticles3D.new()
	sparks.amount = 10
	sparks.lifetime = 2.0
	sparks.preprocess = 2.0
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sparks.emission_sphere_radius = 0.6
	sparks.direction = Vector3.UP
	sparks.spread = 20.0
	sparks.initial_velocity_min = 0.2
	sparks.initial_velocity_max = 0.5
	sparks.gravity = Vector3.ZERO
	sparks.scale_amount_min = 0.03
	sparks.scale_amount_max = 0.07
	var smesh := SphereMesh.new()
	smesh.radius = 0.5
	smesh.height = 1.0
	var sm := StandardMaterial3D.new()
	sm.albedo_color = color
	sm.emission_enabled = true
	sm.emission = color
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smesh.material = sm
	sparks.mesh = smesh
	sparks.position.y = 1.4 + lift
	add_child(sparks)

	light = OmniLight3D.new()
	light.light_color = color
	light.light_energy = 0.9
	light.omni_range = 4.0
	light.position.y = 1.6 + lift
	add_child(light)

	var name_label := Label3D.new()
	name_label.text = class_title().to_upper()
	name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_label.no_depth_test = true
	name_label.font_size = 30
	name_label.pixel_size = 0.01
	name_label.outline_size = 8
	name_label.modulate = color.lightened(0.3)
	name_label.position.y = 0.95
	name_label.visible = false   # the alcove sign above names the class
	add_child(name_label)

	prompt = Label3D.new()
	prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	prompt.no_depth_test = true
	prompt.font_size = 34
	prompt.pixel_size = 0.011
	prompt.outline_size = 9
	prompt.modulate = Color(1.0, 0.95, 0.8)
	prompt.position.y = 2.5
	prompt.visible = false
	add_child(prompt)
	# The whole stand is built a size up so the class choice reads from the
	# camera at a glance (in_reach measures from the centre, unaffected).
	scale = Vector3.ONE * 1.1


func class_title() -> String:
	return Stats.FACTIONS[team].roles[role]


func in_reach(u) -> bool:
	var offset: Vector3 = u.global_position - global_position
	return absf(offset.y) < 2.0 and Vector2(offset.x, offset.z).length() < Stats.SEAL_REACH


func take(u) -> void:
	## `u` grabs this seal and becomes the class.
	if locked:
		if u == game.player:
			game.toast("The Rogue's hood unlocks at account level %d" % Stats.UNLOCK_LEVEL, Color(1.0, 0.8, 0.5))
		return
	u.set_role(role)
	game.sfx.play("station", u.global_position)
	var color: Color = Stats.ROLES[role].color
	game.spawn_ring(global_position, 2.2, color, 0.5)
	game.spawn_flash(u.global_position + Vector3(0, 1.2, 0), color, 3.0, 0.4)
	game.spawn_splash(u.global_position + Vector3(0, 1.0, 0), color, 22, 3.5, 0.6, true)
	if u == game.player:
		game.chat_system("You put on the %s's hat. You are now a %s." % [class_title(), u.role_name()])   # the class banner says it on screen
	elif u.remote_peer > 0:
		game.announce("You put on the %s's hat. You are now a %s." % [class_title(), u.role_name()], u)
	if u.is_player:
		u.class_banner = u.CLASS_BANNER_TIME


func _process(delta: float) -> void:
	t += delta
	seal.rotation.y += delta * 1.2
	seal.position.y = 1.4 + lift + sin(t * 2.2 + role) * 0.06
	ring.rotation.y -= delta * 0.4
	var p = game.player
	if locked and game.unlocked():
		locked = false
		for m in seal.find_children("*", "MeshInstance3D", true, false):
			m.queue_free()
		_build_hat(seal, team == 0)
	var show: bool = p != null and not p.dead and p.team == team and in_reach(p)
	if show != near:
		near = show
		prompt.visible = show
	if show:
		if locked:
			prompt.text = "LOCKED · ACCOUNT LEVEL %d" % Stats.UNLOCK_LEVEL
		elif p.role == role:
			prompt.text = "Your hat"
		else:
			prompt.text = "[%s]  TAKE THE %s'S HAT" % [game.key_label("interact"), class_title().to_upper()]
		seal.rotation.y += delta * 2.5
		light.light_energy = 1.6 + 0.4 * sin(t * 6.0)
	else:
		light.light_energy = 0.9


func _mat(color: Color, rough: float = 0.6, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	return m


func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func _build_hat(parent: Node3D, elf: bool) -> void:
	## Low-poly headgear per class, in the faction's palette: the Humans wear
	## steel and cloth, the Elves leaf, bark and silver.
	var color: Color = Stats.ROLES[role].color
	var steel := _mat(Color(0.75, 0.78, 0.82) if not elf else Color(0.72, 0.85, 0.78), 0.35, 0.8)
	var gold := _mat(Color(0.95, 0.78, 0.3) if not elf else Color(0.8, 0.92, 0.75), 0.35, 0.7)
	var cloth := _mat(color, 0.9)
	var dark := _mat(color.darkened(0.45), 0.9)
	var leather := _mat(Color(0.45, 0.3, 0.18) if not elf else Color(0.38, 0.5, 0.3), 0.8)
	match role:
		Stats.Role.KNIGHT:
			# A rounded helm with a nose guard and a plume (a leaf crest for the Elves).
			var dome := SphereMesh.new()
			dome.radius = 0.4
			dome.height = 0.8
			dome.radial_segments = 12
			dome.rings = 6
			_mesh(parent, dome, Vector3(0, 0.05, 0), steel)
			var brim := CylinderMesh.new()
			brim.top_radius = 0.44
			brim.bottom_radius = 0.44
			brim.height = 0.1
			brim.radial_segments = 12
			_mesh(parent, brim, Vector3(0, -0.12, 0), gold)
			var nose := BoxMesh.new()
			nose.size = Vector3(0.08, 0.3, 0.06)
			_mesh(parent, nose, Vector3(0, -0.2, 0.4), steel)
			var plume := CylinderMesh.new()
			plume.top_radius = 0.0
			plume.bottom_radius = 0.09
			plume.height = 0.5
			plume.radial_segments = 6
			_mesh(parent, plume, Vector3(0, 0.6, -0.05), cloth, Vector3(0.5, 0, 0))
		Stats.Role.RANGER:
			# A peaked cap with a wide brim and a feather.
			var cone := CylinderMesh.new()
			cone.top_radius = 0.05
			cone.bottom_radius = 0.34
			cone.height = 0.5
			cone.radial_segments = 10
			_mesh(parent, cone, Vector3(0, 0.1, 0), cloth)
			var brim := CylinderMesh.new()
			brim.top_radius = 0.5
			brim.bottom_radius = 0.5
			brim.height = 0.05
			brim.radial_segments = 12
			_mesh(parent, brim, Vector3(0, -0.14, 0), dark, Vector3(0.12, 0, 0.08))
			var feather := BoxMesh.new()
			feather.size = Vector3(0.05, 0.4, 0.12)
			_mesh(parent, feather, Vector3(0.25, 0.3, -0.1), _mat(Color(0.95, 0.9, 0.7)), Vector3(0.3, 0, -0.6))
		Stats.Role.MAGE:
			# A tall, bent wizard's hat with a star.
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 0.32
			cone.height = 0.85
			cone.radial_segments = 10
			_mesh(parent, cone, Vector3(0, 0.3, 0), cloth, Vector3(0, 0, -0.25))
			var brim := CylinderMesh.new()
			brim.top_radius = 0.56
			brim.bottom_radius = 0.56
			brim.height = 0.05
			brim.radial_segments = 12
			_mesh(parent, brim, Vector3(0, -0.14, 0), cloth)
			var band := CylinderMesh.new()
			band.top_radius = 0.31
			band.bottom_radius = 0.34
			band.height = 0.1
			band.radial_segments = 10
			_mesh(parent, band, Vector3(0, -0.06, 0), gold)
			var star := SphereMesh.new()
			star.radius = 0.08
			star.height = 0.16
			var glow := _mat(Color(1.0, 0.95, 0.6))
			glow.emission_enabled = true
			glow.emission = color
			glow.emission_energy_multiplier = 1.2
			_mesh(parent, star, Vector3(0.2, 0.68, 0), glow)
		Stats.Role.HEALER:
			# A tall mitre (a leafy cowl for the Elves) with a bright cross or bloom.
			var mitre := CylinderMesh.new()
			mitre.top_radius = 0.02
			mitre.bottom_radius = 0.36
			mitre.height = 0.75
			mitre.radial_segments = 4
			_mesh(parent, mitre, Vector3(0, 0.25, 0), _mat(Color(0.97, 0.95, 0.85) if not elf else color, 0.9), Vector3(0, PI / 4.0, 0))
			var band := CylinderMesh.new()
			band.top_radius = 0.37
			band.bottom_radius = 0.38
			band.height = 0.12
			band.radial_segments = 10
			_mesh(parent, band, Vector3(0, -0.1, 0), gold)
			var bar := BoxMesh.new()
			bar.size = Vector3(0.06, 0.3, 0.03)
			var cross := _mat(color if not elf else Color(1.0, 0.9, 0.6))
			cross.emission_enabled = true
			cross.emission = cross.albedo_color
			cross.emission_energy_multiplier = 0.8
			_mesh(parent, bar, Vector3(0, 0.3, 0.2), cross)
			var bar2 := BoxMesh.new()
			bar2.size = Vector3(0.2, 0.06, 0.03)
			_mesh(parent, bar2, Vector3(0, 0.34, 0.2), cross)
		Stats.Role.ENGINEER:
			# A hard leather cap with brass goggles pushed up on it.
			var dome := SphereMesh.new()
			dome.radius = 0.38
			dome.height = 0.6
			dome.radial_segments = 12
			dome.rings = 5
			_mesh(parent, dome, Vector3(0, 0.0, 0), leather)
			var brim := CylinderMesh.new()
			brim.top_radius = 0.42
			brim.bottom_radius = 0.42
			brim.height = 0.06
			brim.radial_segments = 12
			_mesh(parent, brim, Vector3(0, -0.14, 0), dark)
			var peak := BoxMesh.new()
			peak.size = Vector3(0.36, 0.04, 0.22)
			_mesh(parent, peak, Vector3(0, -0.14, 0.44), dark)
			for sx in [-0.14, 0.14]:
				var lens := CylinderMesh.new()
				lens.top_radius = 0.1
				lens.bottom_radius = 0.1
				lens.height = 0.08
				lens.radial_segments = 10
				_mesh(parent, lens, Vector3(sx, 0.22, 0.26), gold, Vector3(PI / 2.0 - 0.5, 0, 0))
				var glass := CylinderMesh.new()
				glass.top_radius = 0.07
				glass.bottom_radius = 0.07
				glass.height = 0.1
				glass.radial_segments = 10
				_mesh(parent, glass, Vector3(sx, 0.23, 0.27), _mat(Color(0.5, 0.8, 0.9), 0.2, 0.3), Vector3(PI / 2.0 - 0.5, 0, 0))
		_:
			# The Rogue's hood: a dark cowl with a shadowed face.
			var hood := SphereMesh.new()
			hood.radius = 0.4
			hood.height = 0.9
			hood.radial_segments = 10
			hood.rings = 6
			_mesh(parent, hood, Vector3(0, 0.05, -0.05), _mat(Color(0.2, 0.17, 0.28), 0.95))
			var face := SphereMesh.new()
			face.radius = 0.24
			face.height = 0.42
			face.radial_segments = 8
			var shadow := _mat(Color(0.05, 0.04, 0.08), 1.0)
			_mesh(parent, face, Vector3(0, -0.02, 0.26), shadow)
			var eye := BoxMesh.new()
			eye.size = Vector3(0.07, 0.04, 0.03)
			var glint := _mat(color)
			glint.emission_enabled = true
			glint.emission = color
			glint.emission_energy_multiplier = 1.5
			_mesh(parent, eye, Vector3(-0.08, 0.02, 0.46), glint)
			_mesh(parent, eye, Vector3(0.08, 0.02, 0.46), glint)
			var tail := CylinderMesh.new()
			tail.top_radius = 0.02
			tail.bottom_radius = 0.1
			tail.height = 0.4
			tail.radial_segments = 6
			_mesh(parent, tail, Vector3(0, 0.3, -0.35), _mat(Color(0.2, 0.17, 0.28), 0.95), Vector3(-0.9, 0, 0))
