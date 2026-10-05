extends Node3D
## A health potion that sits at a fixed spot on the map. Anyone who is hurt
## can walk over it to get hearts back; it comes back a while later.

const Stats = preload("res://scripts/stats.gd")

var game
var active := true
var respawn_timer := 0.0
var orb: Node3D            # the bottle (kept as "orb" for the HUD and bots)
var t := 0.0
var light: OmniLight3D


func setup(p_game, pos: Vector3) -> void:
	game = p_game
	position = pos

	# A worn stone slab the potion rests on.
	var pad := MeshInstance3D.new()
	var pad_mesh := CylinderMesh.new()
	pad_mesh.top_radius = 0.6
	pad_mesh.bottom_radius = 0.7
	pad_mesh.height = 0.12
	pad.mesh = pad_mesh
	pad.position.y = 0.06
	var pad_mat := StandardMaterial3D.new()
	pad_mat.albedo_color = Color(0.55, 0.52, 0.5)
	pad.material_override = pad_mat
	add_child(pad)

	# The bottle: a round glass body full of red, a neck and a cork.
	orb = Node3D.new()
	orb.position.y = 0.85
	add_child(orb)
	var liquid := StandardMaterial3D.new()
	liquid.albedo_color = Color(0.3, 0.95, 0.4)
	liquid.emission_enabled = true
	liquid.emission = Color(0.25, 0.9, 0.35)
	liquid.emission_energy_multiplier = 1.2
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.9, 1.0, 0.95, 0.22)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.1
	glass.metallic = 0.2
	var body := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.3
	sphere.height = 0.6
	body.mesh = sphere
	body.material_override = liquid
	orb.add_child(body)
	var shell := MeshInstance3D.new()
	var shell_mesh := SphereMesh.new()
	shell_mesh.radius = 0.34
	shell_mesh.height = 0.68
	shell.mesh = shell_mesh
	shell.material_override = glass
	orb.add_child(shell)
	var neck := MeshInstance3D.new()
	var neck_mesh := CylinderMesh.new()
	neck_mesh.top_radius = 0.1
	neck_mesh.bottom_radius = 0.13
	neck_mesh.height = 0.3
	neck.mesh = neck_mesh
	neck.position.y = 0.4
	neck.material_override = glass
	orb.add_child(neck)
	var cork := MeshInstance3D.new()
	var cork_mesh := CylinderMesh.new()
	cork_mesh.top_radius = 0.09
	cork_mesh.bottom_radius = 0.09
	cork_mesh.height = 0.14
	cork.mesh = cork_mesh
	cork.position.y = 0.6
	var cork_mat := StandardMaterial3D.new()
	cork_mat.albedo_color = Color(0.6, 0.45, 0.28)
	cork.material_override = cork_mat
	orb.add_child(cork)
	# A white cross label so it reads as healing from above.
	for size in [Vector3(0.22, 0.06, 0.02), Vector3(0.06, 0.22, 0.02)]:
		var bar := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = size
		bar.mesh = box
		bar.position.z = 0.3
		var bar_mat := StandardMaterial3D.new()
		bar_mat.albedo_color = Color.WHITE
		bar_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bar.material_override = bar_mat
		orb.add_child(bar)
	light = OmniLight3D.new()
	light.light_color = Color(1.0, 0.3, 0.3)
	light.light_energy = 0.8
	light.omni_range = 3.0
	light.position.y = 0.9
	add_child(light)


func _process(delta: float) -> void:
	t += delta
	if not active:
		respawn_timer -= delta
		if respawn_timer <= 0.0:
			active = true
			orb.visible = true
			light.visible = true
			game.spawn_splash(global_position + Vector3(0, 0.6, 0), Color(1.0, 0.4, 0.4), 12, 2.0, 0.6, true)
		return
	orb.position.y = 0.85 + sin(t * 3.0) * 0.12
	orb.rotation.y += delta * 1.5
	for u in game.units:
		if u.dead or u.hearts >= Stats.MAX_HEARTS:
			continue
		var offset: Vector3 = u.global_position - global_position
		if absf(offset.y) < 1.5 and Vector2(offset.x, offset.z).length() < 1.0:
			u.heal(Stats.HEAL_ORB_HEARTS)
			game.spawn_burst(global_position, 1.3, Color(1.0, 0.35, 0.4))
			game.spawn_splash(global_position + Vector3(0, 0.8, 0), Color(1.0, 0.3, 0.35), 16, 3.0, 0.5, true)
			if u == game.player:
				game.announce("Health potion: +%d hearts" % Stats.HEAL_ORB_HEARTS)
			active = false
			orb.visible = false
			light.visible = false
			respawn_timer = Stats.HEAL_ORB_RESPAWN
			return
