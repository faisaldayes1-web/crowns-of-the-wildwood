extends Node3D
## An arrow or spell. Flies straight, stops at walls, cover, trees and the enemy
## door, hits the first enemy it reaches, and spells splash everyone nearby.
## Shots fired from up on the castle walls arc down to ground level.
## Looks: arrows have a shaft and fletching, arcane bolts a glowing core with
## a sparkle trail, fireballs a burning core with smoke, holy bolts a streak
## of light. Each spell carries its own light.

const Stats = preload("res://scripts/stats.gd")
const Turret = preload("res://scripts/turret.gd")
const Barricade = preload("res://scripts/barricade.gd")

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
var from_turret := false   # a turret bolt (for the demo tallies)
var owner_unit = null      # who fired it, for experience
var fire := false
var holy := false
var frost := false
var drain := false       # each hit heals the shooter a heart
var pierce := false      # flies on through everyone it hits
var effect := {}         # slow / root seconds applied on a hit
var hit_list: Array = []
var color := Color.WHITE
var spin: Node3D


func setup(p_game, p_team: int, from: Vector3, p_direction: Vector3, stats: Dictionary, p_color: Color) -> void:
	game = p_game
	team = p_team
	damage = stats.damage
	gate_damage = stats.gate_damage
	splash = stats.get("splash", 0.0)
	direction = p_direction.normalized()
	speed = stats.get("shot_speed", 30.0)
	fire = stats.get("fire", false)
	holy = stats.get("holy", false)
	frost = stats.get("frost", false)
	drain = stats.get("drain", false)
	pierce = stats.get("pierce", false)
	if stats.has("slow"):
		effect["slow"] = stats.slow
	if stats.has("root"):
		effect["root"] = stats.root
	if stats.get("burn", false):
		effect["burn"] = true
	color = p_color
	life = stats.range / speed
	position = from + Vector3(0, FLIGHT_HEIGHT, 0)
	# From the ramparts, shots come down to ground level over most of their range.
	if position.y > FLIGHT_HEIGHT + 0.5:
		fall_speed = (position.y - FLIGHT_HEIGHT) / (stats.range * 0.8 / speed)
	# The world, plus the enemy door (layer 4 = human door, layer 3 = elf door).
	query_mask = 1 | (8 if team == 0 else 4)
	rotation.y = atan2(-direction.x, -direction.z)
	if fire:
		_build_fireball()
	elif splash > 0.0:
		_build_arcane()
	elif holy:
		_build_holy()
	else:
		_build_arrow()


func _glow(c: Color, energy: float = 2.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mat.emission_enabled = true
	mat.emission = c
	mat.emission_energy_multiplier = energy
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat


func _sphere(radius: float, mat: Material, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.radial_segments = 10
	s.rings = 5
	m.mesh = s
	m.material_override = mat
	m.position = pos
	add_child(m)
	return m


func _trail(c: Color, amount: int, lifetime: float, size: float, rise: float = 0.0) -> void:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.local_coords = false
	p.direction = Vector3(0, 1, 0)
	p.spread = 180.0
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 0.8
	p.gravity = Vector3(0, rise, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	var box := BoxMesh.new()
	box.size = Vector3.ONE * size
	box.material = _glow(c, 1.5)
	p.mesh = box
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = fade
	add_child(p)


func _light(c: Color, energy: float, range_m: float) -> void:
	var l := OmniLight3D.new()
	l.light_color = c
	l.light_energy = energy
	l.omni_range = range_m
	l.shadow_enabled = false
	add_child(l)


func _build_arrow() -> void:
	var shaft := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.05, 0.05, 0.85)
	shaft.mesh = box
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.75, 0.6, 0.4)
	shaft.material_override = wood
	add_child(shaft)
	var tip := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.06
	cone.height = 0.2
	tip.mesh = cone
	tip.rotation.x = -PI / 2.0
	tip.position.z = -0.5
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.85, 0.87, 0.9)
	steel.metallic = 0.6
	tip.material_override = steel
	add_child(tip)
	for side in [-1.0, 1.0]:
		var vane := MeshInstance3D.new()
		var quad := BoxMesh.new()
		quad.size = Vector3(0.01, 0.12, 0.2)
		vane.mesh = quad
		vane.position = Vector3(side * 0.03, 0.04, 0.33)
		vane.rotation.z = side * 0.5
		vane.material_override = _glow(color, 0.3)
		add_child(vane)
	_trail(Color(1, 1, 0.9), 5, 0.15, 0.05)


func _build_arcane() -> void:
	_sphere(0.17, _glow(Color(0.85, 0.7, 1.0), 3.0))
	spin = Node3D.new()
	add_child(spin)
	for i in 3:
		var ang := TAU * i / 3.0
		var orb := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.06
		s.height = 0.12
		s.radial_segments = 6
		s.rings = 3
		orb.mesh = s
		orb.material_override = _glow(color, 2.5)
		orb.position = Vector3(cos(ang) * 0.3, sin(ang) * 0.3, 0)
		spin.add_child(orb)
	_trail(color, 14, 0.4, 0.08)
	_light(color, 1.2, 4.0)


func _build_fireball() -> void:
	_sphere(0.45, _glow(Color(1.0, 0.45, 0.1), 2.0))
	_sphere(0.26, _glow(Color(1.0, 0.9, 0.5), 4.0))
	_trail(Color(1.0, 0.55, 0.15), 16, 0.35, 0.14)       # embers
	_trail(Color(0.3, 0.26, 0.25), 10, 0.9, 0.22, 1.5)   # smoke
	_light(Color(1.0, 0.6, 0.2), 2.5, 7.0)


func _build_holy() -> void:
	var streak := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.12
	cap.height = 0.9
	cap.radial_segments = 8
	streak.mesh = cap
	streak.rotation.x = PI / 2.0
	streak.material_override = _glow(Color(1.0, 0.97, 0.75), 3.5)
	add_child(streak)
	_trail(Color(1.0, 0.95, 0.6), 10, 0.3, 0.07)
	_light(Color(1.0, 0.95, 0.6), 1.2, 4.0)


func _process(delta: float) -> void:
	if spin:
		spin.rotation.z += delta * 12.0


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
		var vault = game.vaults[1 - team]
		if hit.collider == gate:
			gate.take_hit(gate_damage, owner_unit)
		elif hit.collider == vault:
			vault.take_hit(gate_damage, owner_unit)
		elif hit.collider is Barricade and hit.collider.team != team:
			hit.collider.take_hit(gate_damage, owner_unit)
		elif hit.collider is Turret and hit.collider.team != team:
			hit.collider.take_hit(maxi(damage, 1), owner_unit)
		_burst()
		return

	global_position = after
	# Nothing reaches into the enemy's spawn sanctuary.
	if game._in_cellar(1 - team, Vector3(after.x, -1.0, after.z)):
		queue_free()
		return
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
			if unit in hit_list:
				continue
			if splash <= 0.0:
				var landed: bool = unit.take_damage(damage, owner_unit, global_position - direction, Stats.KNOCK_SHOT, effect)
				if from_turret and unit.dead:
					game.turret_kills[team] += 1
				if landed and drain and owner_unit:
					owner_unit.heal(1, owner_unit)
				if pierce:
					hit_list.append(unit)
					game.spawn_splash(global_position, Color(0.9, 0.85, 0.7), 6, 2.5, 0.3)
					continue
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
			if offset.length() < splash and not unit.is_protected():
				unit.take_damage(damage, owner_unit, global_position, Stats.KNOCK_SPLASH, effect)
		for t in game.turrets.duplicate():
			if t.team != team and game._flat_dist(t.global_position, global_position) < splash + 0.5:
				t.take_hit(damage, owner_unit)
		var ground := Vector3(global_position.x, 0.0, global_position.z)
		game.sfx.play("explosion" if fire and splash > 2.5 else ("frost" if frost else "bolt_hit"), global_position, 0.0 if splash > 2.5 else -5.0, 0.12)
		if fire:
			game.spawn_ring(ground, splash, Color(1.0, 0.6, 0.2), 0.45, 0.2)
			game.spawn_splash(global_position, Color(1.0, 0.6, 0.15), 40, 9.0, 0.7)
			game.spawn_splash(global_position + Vector3(0, 0.5, 0), Color(0.25, 0.22, 0.2), 16, 2.5, 1.2, true)
			game.spawn_flash(ground, Color(1.0, 0.6, 0.2), 6.0, 0.4)
			game.shake_at(global_position, 0.5)
		elif frost:
			game.spawn_ring(ground, splash, color, 0.5, 0.25)
			game.spawn_splash(global_position, Color(0.85, 0.95, 1.0), 30, 5.0, 0.8, true)
			game.spawn_flash(ground, color, 4.0, 0.35)
		else:
			game.spawn_ring(ground, splash, color, 0.35, 0.2)
			game.spawn_splash(global_position, color, 14, 4.0, 0.4)
			game.spawn_flash(ground, color, 2.5, 0.25)
	elif holy:
		game.spawn_splash(global_position, color, 10, 3.0, 0.3)
		game.spawn_flash(global_position, color, 2.0, 0.2)
	else:
		game.sfx.play("arrow_hit", global_position, -6.0, 0.15)
		game.spawn_splash(global_position, Color(0.9, 0.85, 0.7), 6, 2.5, 0.3)
	queue_free()
