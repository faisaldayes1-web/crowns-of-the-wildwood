extends Node3D
## A Ranger's snare trap. The first enemy to step on it takes a hit and is
## rooted in place for a moment. It fades away on its own if nobody does.

var game
var team := 0
var damage := 1
var root_time := 2.0
var life := 30.0


func setup(p_game, p_team: int, pos: Vector3, a: Dictionary) -> void:
	game = p_game
	team = p_team
	damage = a.damage
	root_time = a.root
	life = a.lifetime
	position = Vector3(pos.x, pos.y, pos.z)

	var plate := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.6
	disc.bottom_radius = 0.6
	disc.height = 0.08
	plate.mesh = disc
	plate.position.y = 0.04
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.25, 0.15)
	plate.material_override = mat
	add_child(plate)
	for i in 6:
		var tooth := MeshInstance3D.new()
		var spike := CylinderMesh.new()
		spike.top_radius = 0.0
		spike.bottom_radius = 0.08
		spike.height = 0.35
		tooth.mesh = spike
		var ang := TAU * i / 6.0
		tooth.position = Vector3(cos(ang) * 0.45, 0.2, sin(ang) * 0.45)
		var tooth_mat := StandardMaterial3D.new()
		tooth_mat.albedo_color = Color(0.75, 0.75, 0.7)
		tooth.material_override = tooth_mat
		add_child(tooth)


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
			queue_free()
			return
