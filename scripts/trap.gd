extends Node3D
## A Ranger's snare trap. The first enemy to step on it takes a hit and is
## rooted in place for a moment. It fades away on its own if nobody does.
## Low and earthy so it is easy to miss: a ring of dark teeth just above
## the ground, no plate. Placed where the Ranger can see: never inside a wall.

var game
var team := 0
var damage := 1
var root_time := 2.0
var life := 30.0
var teeth: Array = []


func setup(p_game, p_team: int, pos: Vector3, a: Dictionary) -> void:
	game = p_game
	team = p_team
	damage = a.damage
	root_time = a.root
	life = a.lifetime
	position = Vector3(pos.x, pos.y + 0.03, pos.z)
	var tooth_mat := StandardMaterial3D.new()
	tooth_mat.albedo_color = Color(0.3, 0.26, 0.2)
	tooth_mat.metallic = 0.4
	tooth_mat.roughness = 0.6
	for i in 8:
		var tooth := MeshInstance3D.new()
		var spike := CylinderMesh.new()
		spike.top_radius = 0.0
		spike.bottom_radius = 0.05
		spike.height = 0.22
		spike.radial_segments = 5
		tooth.mesh = spike
		var ang := TAU * i / 8.0
		tooth.position = Vector3(cos(ang) * 0.42, 0.1, sin(ang) * 0.42)
		tooth.rotation.z = cos(ang) * 0.35
		tooth.rotation.x = -sin(ang) * 0.35
		tooth.material_override = tooth_mat
		add_child(tooth)
		teeth.append(tooth)
	# A thin dark cord between the teeth.
	var cord := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.38
	ring.outer_radius = 0.43
	ring.rings = 16
	ring.ring_segments = 6
	cord.mesh = ring
	cord.position.y = 0.05
	cord.material_override = tooth_mat
	add_child(cord)


func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	for u in game.units:
		if u.team == team or u.dead:
			continue
		var offset: Vector3 = u.global_position - global_position
		if absf(offset.y) < 1.0 and Vector2(offset.x, offset.z).length() < 0.9:
			u.take_damage(damage, null, global_position, 2.0)
			u.root_timer = root_time
			game.spawn_burst(global_position, 1.0, Color(0.85, 0.65, 0.25))
			game.spawn_splash(global_position + Vector3(0, 0.3, 0), Color(0.6, 0.5, 0.35), 14, 3.0, 0.4)
			queue_free()
			return
