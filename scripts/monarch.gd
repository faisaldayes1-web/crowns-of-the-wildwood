extends Node3D
## A team's crown. Rests on its cushioned pedestal in the throne room until an
## enemy grabs it, rides high over the carrier's head, and floats back home on
## its own if dropped. (It was a king or queen until 2026-10-07; the class
## keeps its old name so the rest of the game needn't change.)

enum State { HOME, CARRIED, DROPPED }


const WALK_HOME_SPEED := 1.5
const CARRY_HEIGHT := 2.3
const REST_HEIGHT := 1.2      # on the pedestal's cushion
const DROP_HEIGHT := 0.7

var team := 0
var state := State.HOME
var carrier = null
var home := Vector3.ZERO
var title := ""
var model
var label: Label3D


func setup(p_team: int, p_home: Vector3, color: Color, p_title: String) -> void:
	team = p_team
	home = p_home
	title = p_title
	position = home

	model = _build_crown(team == 0)
	model.scale = Vector3.ONE * 1.5
	add_child(model)
	model.position.y = REST_HEIGHT

	label = Label3D.new()
	label.text = title.to_upper()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 34
	label.pixel_size = 0.009
	label.outline_size = 12
	label.outline_modulate = Color(0.08, 0.06, 0.04)
	label.modulate = Color(1.0, 0.9, 0.4)
	label.position.y = 3.1
	add_child(label)


func pick_up(unit) -> void:
	label.visible = false
	state = State.CARRIED
	carrier = unit


func drop_at(where: Vector3) -> void:
	label.visible = true
	state = State.DROPPED
	carrier = null
	global_position = Vector3(where.x, 0.0, where.z)


func go_home() -> void:
	label.visible = true
	state = State.HOME
	carrier = null
	global_position = home


func _process(delta: float) -> void:
	_t += delta
	model.rotation.y += delta * 0.8
	match state:
		State.HOME:
			model.position.y = REST_HEIGHT + sin(_t * 2.0) * 0.05
		State.CARRIED:
			model.position.y = 0.0
			if carrier:
				global_position = carrier.global_position + Vector3(0, CARRY_HEIGHT, 0)
		State.DROPPED:
			model.position.y = DROP_HEIGHT + sin(_t * 3.0) * 0.08
			var to_home := home - global_position
			to_home.y = 0.0
			if to_home.length() < 0.2:
				go_home()
			else:
				global_position += to_home.normalized() * WALK_HOME_SPEED * delta


var _t := 0.0


func _build_crown(elf: bool) -> Node3D:
	## A chunky cartoon crown: a gold band with five points, ball tips and
	## gems (emerald for the Elves, sapphire for the Humans), and a glow.
	var root := Node3D.new()
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(1.0, 0.78, 0.25)
	gold.metallic = 0.85
	gold.roughness = 0.3
	gold.emission_enabled = true
	gold.emission = Color(1.0, 0.7, 0.2)
	gold.emission_energy_multiplier = 0.35
	var gem := StandardMaterial3D.new()
	gem.albedo_color = Color(0.2, 0.85, 0.45) if elf else Color(0.2, 0.45, 1.0)
	gem.emission_enabled = true
	gem.emission = gem.albedo_color
	gem.emission_energy_multiplier = 0.8
	var band := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.42
	bm.bottom_radius = 0.38
	bm.height = 0.22
	bm.radial_segments = 20
	band.mesh = bm
	band.material_override = gold
	root.add_child(band)
	var rim := MeshInstance3D.new()
	var rm := TorusMesh.new()
	rm.inner_radius = 0.36
	rm.outer_radius = 0.45
	rim.mesh = rm
	rim.position.y = -0.1
	rim.material_override = gold
	root.add_child(rim)
	for k in 5:
		var a := k * TAU / 5.0
		var out := Vector3(cos(a), 0, sin(a))
		var spike := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(0.3, 0.36, 0.08)
		spike.mesh = pm
		spike.position = out * 0.4 + Vector3(0, 0.28, 0)
		spike.rotation.y = -a + PI / 2.0
		spike.material_override = gold
		root.add_child(spike)
		var ball := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.06
		sm.height = 0.12
		ball.mesh = sm
		ball.position = out * 0.4 + Vector3(0, 0.48, 0)
		ball.material_override = gold
		root.add_child(ball)
		var g := MeshInstance3D.new()
		var gm := SphereMesh.new()
		gm.radius = 0.055
		gm.height = 0.11
		g.mesh = gm
		g.scale = Vector3(1, 1, 0.5)
		g.position = out * 0.43
		g.rotation.y = -a + PI / 2.0
		g.material_override = gem
		root.add_child(g)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.85, 0.45)
	light.light_energy = 0.8
	light.omni_range = 3.0
	light.position.y = 0.4
	root.add_child(light)
	# Sparkles drifting up off it.
	var p := CPUParticles3D.new()
	p.amount = 10
	p.lifetime = 1.6
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.5
	p.direction = Vector3.UP
	p.spread = 30.0
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 0.5
	p.gravity = Vector3.ZERO
	var dot := SphereMesh.new()
	dot.radius = 0.03
	dot.height = 0.06
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.albedo_color = Color(1.0, 0.95, 0.6)
	dot.material = dm
	p.mesh = dot
	root.add_child(p)
	return root
