extends Node3D
## A ranged shot. Flies straight and hits the first enemy it passes near.

const SPEED := 24.0
const HIT_RADIUS := 0.7

var game
var team := 0
var damage := 0.0
var direction := Vector3.FORWARD
var life := 0.6


func setup(p_game, p_team: int, from: Vector3, p_direction: Vector3, p_damage: float, max_range: float) -> void:
	game = p_game
	team = p_team
	damage = p_damage
	direction = p_direction.normalized()
	life = max_range / SPEED
	position = from + Vector3(0, 1.1, 0)

	var mesh := MeshInstance3D.new()
	var shaft := BoxMesh.new()
	shaft.size = Vector3(0.08, 0.08, 0.7)
	mesh.mesh = shaft
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.9, 0.7)
	mat.emission_enabled = true
	mat.emission = Color(0.6, 0.5, 0.2)
	mesh.material_override = mat
	add_child(mesh)
	rotation.y = atan2(-direction.x, -direction.z)


func _physics_process(delta: float) -> void:
	global_position += direction * SPEED * delta
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	for unit in game.units:
		if unit.team == team or unit.dead:
			continue
		var offset: Vector3 = unit.global_position - global_position
		offset.y = 0.0
		if offset.length() < HIT_RADIUS:
			unit.take_damage(damage)
			queue_free()
			return
