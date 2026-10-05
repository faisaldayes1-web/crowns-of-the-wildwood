extends Node3D
## An arrow or spell. Flies straight, hits the first enemy (or enemy gate) it
## reaches, and spells splash everyone nearby.

const Gate = preload("res://scripts/gate.gd")

const SPEED := 22.0
const HIT_RADIUS := 0.7

var game
var team := 0
var damage := 1
var gate_damage := 1
var splash := 0.0
var direction := Vector3.FORWARD
var life := 0.6


func setup(p_game, p_team: int, from: Vector3, p_direction: Vector3, stats: Dictionary, color: Color) -> void:
	game = p_game
	team = p_team
	damage = stats.damage
	gate_damage = stats.gate_damage
	splash = stats.get("splash", 0.0)
	direction = p_direction.normalized()
	life = stats.range / SPEED
	position = from + Vector3(0, 1.1, 0)

	var mesh := MeshInstance3D.new()
	if splash > 0.0:
		var orb := SphereMesh.new()
		orb.radius = 0.25
		orb.height = 0.5
		mesh.mesh = orb
	else:
		var shaft := BoxMesh.new()
		shaft.size = Vector3(0.08, 0.08, 0.7)
		mesh.mesh = shaft
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.5 if splash > 0.0 else 0.4
	mesh.material_override = mat
	add_child(mesh)
	rotation.y = atan2(-direction.x, -direction.z)


func _physics_process(delta: float) -> void:
	var before := global_position
	global_position += direction * SPEED * delta
	life -= delta
	if life <= 0.0:
		_burst()
		return

	var gate = game.gates[1 - team]
	if gate.is_intact() and (before.x - gate.position.x) * (global_position.x - gate.position.x) <= 0.0 \
			and absf(global_position.z) < Gate.HALF_OPENING:
		gate.take_hit(gate_damage)
		_burst()
		return

	for unit in game.units:
		if unit.team == team or unit.dead:
			continue
		var offset: Vector3 = unit.global_position - global_position
		offset.y = 0.0
		if offset.length() < HIT_RADIUS:
			if splash <= 0.0:
				unit.take_damage(damage)
			_burst()
			return


func _burst() -> void:
	if splash > 0.0:
		for unit in game.units:
			if unit.team == team or unit.dead:
				continue
			var offset: Vector3 = unit.global_position - global_position
			offset.y = 0.0
			if offset.length() < splash:
				unit.take_damage(damage)
		game.spawn_burst(global_position, splash, Color(0.7, 0.5, 1.0))
	queue_free()
