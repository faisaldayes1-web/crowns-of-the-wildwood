extends Node3D
## A healing orb that sits at a fixed spot on the map. Anyone who is hurt can
## walk over it to get hearts back; it comes back a while later.

const Stats = preload("res://scripts/stats.gd")

var game
var active := true
var respawn_timer := 0.0
var orb: MeshInstance3D
var orb_mat: StandardMaterial3D
var t := 0.0


func setup(p_game, pos: Vector3) -> void:
	game = p_game
	position = pos

	var pad := MeshInstance3D.new()
	var pad_mesh := CylinderMesh.new()
	pad_mesh.top_radius = 0.9
	pad_mesh.bottom_radius = 0.9
	pad_mesh.height = 0.08
	pad.mesh = pad_mesh
	pad.position.y = 0.04
	var pad_mat := StandardMaterial3D.new()
	pad_mat.albedo_color = Color(0.85, 0.85, 0.8)
	pad.material_override = pad_mat
	add_child(pad)

	orb = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.38
	sphere.height = 0.76
	orb.mesh = sphere
	orb.position.y = 1.0
	orb_mat = StandardMaterial3D.new()
	orb_mat.albedo_color = Color(0.3, 1.0, 0.5)
	orb_mat.emission_enabled = true
	orb_mat.emission = Color(0.2, 0.9, 0.4)
	orb_mat.emission_energy_multiplier = 1.5
	orb.material_override = orb_mat
	add_child(orb)

	# A little cross so it reads as healing.
	for size in [Vector3(0.5, 0.14, 0.14), Vector3(0.14, 0.5, 0.14)]:
		var bar := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = size
		bar.mesh = box
		var bar_mat := StandardMaterial3D.new()
		bar_mat.albedo_color = Color.WHITE
		bar_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bar.material_override = bar_mat
		orb.add_child(bar)


func _process(delta: float) -> void:
	t += delta
	if not active:
		respawn_timer -= delta
		if respawn_timer <= 0.0:
			active = true
			orb.visible = true
		return
	orb.position.y = 1.0 + sin(t * 3.0) * 0.15
	orb.rotation.y += delta * 1.5
	for u in game.units:
		if u.dead or u.hearts >= Stats.MAX_HEARTS:
			continue
		var offset: Vector3 = u.global_position - global_position
		if absf(offset.y) < 1.5 and Vector2(offset.x, offset.z).length() < 1.0:
			u.heal(Stats.HEAL_ORB_HEARTS)
			game.spawn_burst(global_position, 1.3, Color(0.3, 1.0, 0.5))
			if u == game.player:
				game.announce("+%d hearts" % Stats.HEAL_ORB_HEARTS)
			active = false
			orb.visible = false
			respawn_timer = Stats.HEAL_ORB_RESPAWN
			return
