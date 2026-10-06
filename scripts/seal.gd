extends Node3D
## A class seal: the charm you grab in your cellar to become that class.
## It hovers over a pedestal, spinning slowly, with the class crest on its
## face. Walk up and press the interact key (bots simply step on it).

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
var crest_mat: StandardMaterial3D


func setup(p_game, p_team: int, p_role: int, pos: Vector3) -> void:
	game = p_game
	team = p_team
	role = p_role
	position = pos
	var color: Color = Stats.ROLES[role].color
	var elf := team == 0

	# The pedestal: a bark stump for the Elves, a stone plinth for the Humans.
	var ped := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.42 if elf else 0.36
	cyl.bottom_radius = 0.5 if elf else 0.44
	cyl.height = 0.8
	cyl.radial_segments = 10 if elf else 8
	ped.mesh = cyl
	ped.position.y = 0.4
	ped.material_override = game._pbr("bark", 0.6, Color(0.8, 0.76, 0.62)) if elf else game._pbr("stone", 0.5, Color(0.9, 0.86, 0.78))
	add_child(ped)
	var cap := MeshInstance3D.new()
	var cap_mesh := CylinderMesh.new()
	cap_mesh.top_radius = 0.5
	cap_mesh.bottom_radius = 0.46
	cap_mesh.height = 0.08
	cap.mesh = cap_mesh
	cap.position.y = 0.84
	var cap_mat: StandardMaterial3D = game._material(Color(0.5, 0.78, 0.6) if elf else Color(0.95, 0.78, 0.3))
	cap_mat.metallic = 0.2 if elf else 0.7
	cap_mat.roughness = 0.6 if elf else 0.35
	cap_mat.emission_enabled = elf
	cap_mat.emission = Color(0.3, 0.7, 0.5)
	cap_mat.emission_energy_multiplier = 0.3
	cap.material_override = cap_mat
	add_child(cap)

	# A soft class-colour glow on the floor around the pedestal.
	ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.95
	torus.outer_radius = 1.15
	ring.mesh = torus
	ring.position.y = 0.06
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(color, 0.55)
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.emission_enabled = true
	rm.emission = color
	rm.emission_energy_multiplier = 1.2
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = rm
	add_child(ring)

	# The seal itself: a gold (or living silver) rim around the class crest,
	# tilted back so the top-down camera sees its face.
	seal = Node3D.new()
	seal.position.y = 1.55
	add_child(seal)
	var face := Node3D.new()
	face.rotation.x = -0.55
	seal.add_child(face)
	var rim := MeshInstance3D.new()
	var rim_mesh := TorusMesh.new()
	rim_mesh.inner_radius = 0.46
	rim_mesh.outer_radius = 0.56
	rim.mesh = rim_mesh
	rim.rotation.x = PI / 2.0
	var rim_mat := StandardMaterial3D.new()
	rim_mat.albedo_color = Color(0.72, 0.9, 0.78) if elf else Color(0.95, 0.78, 0.3)
	rim_mat.metallic = 0.8
	rim_mat.roughness = 0.3
	rim.material_override = rim_mat
	face.add_child(rim)
	var back := MeshInstance3D.new()
	var back_mesh := CylinderMesh.new()
	back_mesh.top_radius = 0.48
	back_mesh.bottom_radius = 0.48
	back_mesh.height = 0.06
	back.mesh = back_mesh
	back.rotation.x = PI / 2.0
	back.position.z = -0.04
	var back_mat: StandardMaterial3D = game._material(color.darkened(0.45))
	back_mat.metallic = 0.3
	back_mat.roughness = 0.5
	back.material_override = back_mat
	face.add_child(back)
	var crest := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.86, 0.86)
	crest.mesh = quad
	var cm := StandardMaterial3D.new()
	cm.albedo_texture = load("res://assets/ui/icons/class_%s.png" % Stats.Role.keys()[role].to_lower())
	locked = role == Stats.Role.ROGUE and not game.unlocked()
	if locked:
		cm.albedo_color = Color(0.45, 0.45, 0.5)
	cm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	cm.alpha_scissor_threshold = 0.4
	cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cm.cull_mode = BaseMaterial3D.CULL_DISABLED
	crest.material_override = cm
	crest_mat = cm
	face.add_child(crest)
	# Four small gems around the rim, in the class colour.
	for i in 4:
		var gem := MeshInstance3D.new()
		var gm := SphereMesh.new()
		gm.radius = 0.06
		gm.height = 0.12
		gem.mesh = gm
		var a := TAU * i / 4.0 + PI / 4.0
		gem.position = Vector3(cos(a) * 0.51, sin(a) * 0.51, 0.0)
		var gmat: StandardMaterial3D = game._material(color)
		gmat.emission_enabled = true
		gmat.emission = color
		gmat.emission_energy_multiplier = 1.5
		gem.material_override = gmat
		face.add_child(gem)

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
	sparks.position.y = 1.4
	add_child(sparks)

	light = OmniLight3D.new()
	light.light_color = color
	light.light_energy = 0.9
	light.omni_range = 4.0
	light.position.y = 1.6
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


func class_title() -> String:
	return Stats.FACTIONS[team].roles[role]


func in_reach(u) -> bool:
	var offset: Vector3 = u.global_position - global_position
	return absf(offset.y) < 2.0 and Vector2(offset.x, offset.z).length() < Stats.SEAL_REACH


func take(u) -> void:
	## `u` grabs this seal and becomes the class.
	if locked:
		if u == game.player:
			game.toast("The Rogue's seal unlocks at account level %d" % Stats.UNLOCK_LEVEL, Color(1.0, 0.8, 0.5))
		return
	u.set_role(role)
	game.sfx.play("station", u.global_position)
	var color: Color = Stats.ROLES[role].color
	game.spawn_ring(global_position, 2.2, color, 0.5)
	game.spawn_flash(u.global_position + Vector3(0, 1.2, 0), color, 3.0, 0.4)
	game.spawn_splash(u.global_position + Vector3(0, 1.0, 0), color, 22, 3.5, 0.6, true)
	if u == game.player:
		game.announce("You took the %s's seal. You are now a %s." % [class_title(), u.role_name()])


func _process(delta: float) -> void:
	t += delta
	seal.rotation.y += delta * 1.2
	seal.position.y = 1.55 + sin(t * 2.2 + role) * 0.08
	ring.rotation.y -= delta * 0.4
	var p = game.player
	if locked and game.unlocked():
		locked = false
		crest_mat.albedo_color = Color.WHITE
	var show: bool = p != null and not p.dead and p.team == team and in_reach(p)
	if show != near:
		near = show
		prompt.visible = show
	if show:
		if locked:
			prompt.text = "LOCKED · ACCOUNT LEVEL %d" % Stats.UNLOCK_LEVEL
		elif p.role == role:
			prompt.text = "Your seal"
		else:
			prompt.text = "[%s]  TAKE THE %s'S SEAL" % [game.key_label("interact"), class_title().to_upper()]
		seal.rotation.y += delta * 2.5
		light.light_energy = 1.6 + 0.4 * sin(t * 6.0)
	else:
		light.light_energy = 0.9
