extends Node3D
## A team's monarch. Sits on the throne until an enemy grabs them, rides on the
## carrier's shoulders, and walks back home on their own if dropped.

enum State { HOME, CARRIED, DROPPED }

const CharacterModel = preload("res://scripts/character_model.gd")

const WALK_HOME_SPEED := 1.5
const CARRY_HEIGHT := 1.9

var team := 0
var state := State.HOME
var carrier = null
var home := Vector3.ZERO
var title := ""
var model


func setup(p_team: int, p_home: Vector3, color: Color, p_title: String) -> void:
	team = p_team
	home = p_home
	title = p_title
	position = home

	model = CharacterModel.new()
	add_child(model)
	model.setup(team, 0, "queen" if team == 0 else "king")

	var label := Label3D.new()
	label.text = title
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 40
	label.pixel_size = 0.012
	label.outline_size = 10
	label.modulate = Color(1.0, 0.9, 0.4)
	label.position.y = 2.6
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
		State.HOME:
			model.update_locomotion(false)
		State.CARRIED:
			if carrier:
				global_position = carrier.global_position + Vector3(0, CARRY_HEIGHT, 0)
				rotation.y = carrier.rotation.y
			model.hold("Sit_Floor_Idle")
			model.update_locomotion(false)
		State.DROPPED:
			model.release()
			model.update_locomotion(true)
			var to_home := home - global_position
			to_home.y = 0.0
			if to_home.length() < 0.2:
				go_home()
			else:
				var step := to_home.normalized()
				global_position += step * WALK_HOME_SPEED * delta
				rotation.y = atan2(-step.x, -step.z)
