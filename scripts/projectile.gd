extends Node3D
## An arrow or spell. Flies straight, stops at walls, cover, trees and the enemy
## door, hits the first enemy it reaches, and spells splash everyone nearby.
## Shots fired from up on the castle walls arc down to ground level.

const Stats = preload("res://scripts/stats.gd")

const HIT_RADIUS := 0.7
const FLIGHT_HEIGHT := 1.1   # how high above the feet a shot flies

var game
var team := 0
var damage := 1
var gate_damage := 1
var splash := 0.0
var direction := Vector3.FORWARD
var life := 0.6
var fall_speed := 0.0
var speed := 30.0
var query_mask := 1
var owner_unit = null      # who fired it, for experience
var fire := false
var color := Color.WHITE


func setup(p_game, p_team: int, from: Vector3, p_direction: Vector3, stats: Dictionary, p_color: Color) -> void:
	game = p_game
	team = p_team
	damage = stats.damage
	gate_damage = stats.gate_damage
	splash = stats.get("splash", 0.0)
	direction = p_direction.normalized()
	speed = stats.get("shot_speed", 30.0)
	fire = stats.get("fire", false)
	color = p_color
	life = stats.range / speed
	position = from + Vector3(0, FLIGHT_HEIGHT, 0)
	# From the ramparts, shots come down to ground level over most of their range.
	if position.y > FLIGHT_HEIGHT + 0.5:
		fall_speed = (position.y - FLIGHT_HEIGHT) / (stats.range * 0.8 / speed)
	# The world, plus the enemy door (layer 4 = human door, layer 3 = elf door).
	query_mask = 1 | (8 if team == 0 else 4)

	var mesh := MeshInstance3D.new()
	if splash > 0.0:
		var orb := SphereMesh.new()
		orb.radius = 0.25 if damage < 2 else 0.45
		orb.height = orb.radius * 2.0
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
	var after := before + direction * speed * delta
	if fall_speed > 0.0:
		after.y = maxf(after.y - fall_speed * delta, FLIGHT_HEIGHT)

	# Anything solid in the way stops the shot. The enemy door takes damage.
	var ray := PhysicsRayQueryParameters3D.create(before, after, query_mask)
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if hit:
		global_position = hit.position
		var gate = game.gates[1 - team]
		if hit.collider == gate:
			gate.take_hit(gate_damage)
		_burst()
		return

	global_position = after
	life -= delta
	if life <= 0.0:
		_burst()
		return

	for unit in game.units:
		if unit.team == team or unit.dead:
			continue
		var offset: Vector3 = unit.global_position - global_position
		offset.y = 0.0
		# Must pass through the body: a shot sailing over someone's head misses.
		if offset.length() < HIT_RADIUS and absf(global_position.y - (unit.global_position.y + 1.0)) < 1.5:
			if splash <= 0.0:
				unit.take_damage(damage, owner_unit, global_position - direction, Stats.KNOCK_SHOT)
			_burst()
			return


func _burst() -> void:
	if splash > 0.0:
		# Magic rains down on everyone near the impact, walls or no walls.
		for unit in game.units:
			if unit.team == team or unit.dead:
				continue
			var offset: Vector3 = unit.global_position - global_position
			offset.y = 0.0
			if offset.length() < splash:
				unit.take_damage(damage, owner_unit, global_position, Stats.KNOCK_SPLASH)
		game.spawn_burst(global_position, splash, Color(1.0, 0.55, 0.15) if fire else Color(0.7, 0.5, 1.0))
		if fire:
			game.spawn_splash(global_position, Color(1.0, 0.6, 0.15), 40, 9.0, 0.7)
			game.spawn_splash(global_position + Vector3(0, 0.5, 0), Color(0.25, 0.22, 0.2), 16, 2.5, 1.2, true)
			game.shake_at(global_position, 0.5)
		else:
			game.spawn_splash(global_position, color, 14, 4.0, 0.4)
	else:
		game.spawn_splash(global_position, color, 8, 3.0, 0.3)
	queue_free()
