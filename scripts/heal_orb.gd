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
var ring: MeshInstance3D
var sparks: CPUParticles3D


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
	pad.material_override = game._pbr("flagstone_moss", 0.5, Color(0.8, 0.84, 0.72))
	add_child(pad)
	# A soft green rune ring on the slab that breathes while the potion waits.
	ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.5
	torus.outer_radius = 0.62
	ring.mesh = torus
	ring.position.y = 0.13
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(0.4, 1.0, 0.55, 0.6)
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.emission_enabled = true
	rm.emission = Color(0.3, 0.95, 0.45)
	rm.emission_energy_multiplier = 1.4
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = rm
	add_child(ring)
	sparks = CPUParticles3D.new()
	sparks.amount = 8
	sparks.lifetime = 1.8
	sparks.preprocess = 1.8
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sparks.emission_sphere_radius = 0.4
	sparks.direction = Vector3.UP
	sparks.spread = 15.0
	sparks.initial_velocity_min = 0.3
	sparks.initial_velocity_max = 0.7
	sparks.gravity = Vector3.ZERO
	sparks.scale_amount_min = 0.03
	sparks.scale_amount_max = 0.06
	var smesh := SphereMesh.new()
	smesh.radius = 0.5
	smesh.height = 1.0
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.5, 1.0, 0.6)
	sm.emission_enabled = true
	sm.emission = Color(0.4, 1.0, 0.5)
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smesh.material = sm
	sparks.mesh = smesh
	sparks.position.y = 0.6
	add_child(sparks)

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
	light.light_color = Color(0.45, 1.0, 0.55)
	light.light_energy = 1.0
	light.omni_range = 3.5
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
			sparks.emitting = true
			game.spawn_splash(global_position + Vector3(0, 0.6, 0), Color(0.5, 1.0, 0.6), 12, 2.0, 0.6, true)
		else:
			# The ring fills back in as the potion brews.
			ring.material_override.albedo_color.a = 0.15 + 0.45 * (1.0 - respawn_timer / Stats.HEAL_ORB_RESPAWN)
		return
	orb.position.y = 0.85 + sin(t * 3.0) * 0.12
	orb.rotation.y += delta * 1.5
	ring.rotation.y += delta * 0.5
	ring.material_override.albedo_color.a = 0.45 + 0.2 * sin(t * 4.0)
	light.light_energy = 1.0 + 0.3 * sin(t * 4.0)
	if game.net_client:
		return  # online: the host hands out potions
	for u in game.units:
		if u.dead or u.hearts >= Stats.MAX_HEARTS:
			continue
		var offset: Vector3 = u.global_position - global_position
		if absf(offset.y) < 1.5 and Vector2(offset.x, offset.z).length() < 1.0:
			u.heal(Stats.HEAL_ORB_HEARTS)
			game.spawn_burst(global_position, 1.3, Color(0.4, 1.0, 0.5))
			game.spawn_splash(global_position + Vector3(0, 0.8, 0), Color(0.45, 1.0, 0.55), 16, 3.0, 0.5, true)
			if u == game.player:
				game.announce("Health potion: +%d hearts" % Stats.HEAL_ORB_HEARTS)
			active = false
			orb.visible = false
			light.visible = false
			sparks.emitting = false
			respawn_timer = Stats.HEAL_ORB_RESPAWN
			return
