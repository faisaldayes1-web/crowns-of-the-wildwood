extends Node3D
## A team's monarch. Sits on the throne until an enemy grabs them, rides on the
## carrier's shoulders, and walks back home on their own if dropped.

enum State { HOME, CARRIED, DROPPED }

const WALK_HOME_SPEED := 1.5
const CARRY_HEIGHT := 1.9

var team := 0
var state := State.HOME
var carrier = null
var home := Vector3.ZERO
var title := ""


func setup(p_team: int, p_home: Vector3, color: Color, p_title: String) -> void:
	team = p_team
	home = p_home
	title = p_title
	position = home

	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.5
	body_mesh.height = 1.4
	body.mesh = body_mesh
	body.position.y = 0.7
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = color.lightened(0.35)
	body.material_override = body_mat
	add_child(body)

	var crown := MeshInstance3D.new()
	var crown_mesh := CylinderMesh.new()
	crown_mesh.top_radius = 0.32
	crown_mesh.bottom_radius = 0.26
	crown_mesh.height = 0.3
	crown.mesh = crown_mesh
	crown.position.y = 1.55
	var crown_mat := StandardMaterial3D.new()
	crown_mat.albedo_color = Color(1.0, 0.82, 0.2)
	crown_mat.metallic = 0.8
	crown_mat.roughness = 0.3
	crown.material_override = crown_mat
	add_child(crown)

	var label := Label3D.new()
	label.text = title
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 40
	label.pixel_size = 0.012
	label.outline_size = 10
	label.modulate = Color(1.0, 0.9, 0.4)
	label.position.y = 2.3
	add_child(label)


func pick_up(unit) -> void:
	state = State.CARRIED
	carrier = unit


func drop_at(where: Vector3) -> void:
	state = State.DROPPED
	carrier = null
	global_position = Vector3(where.x, 0.0, where.z)


func go_home() -> void:
	state = State.HOME
	carrier = null
	global_position = home


func _process(delta: float) -> void:
	match state:
		State.CARRIED:
			if carrier:
				global_position = carrier.global_position + Vector3(0, CARRY_HEIGHT, 0)
		State.DROPPED:
			var to_home := home - global_position
			to_home.y = 0.0
			if to_home.length() < 0.2:
				go_home()
			else:
				global_position += to_home.normalized() * WALK_HOME_SPEED * delta
