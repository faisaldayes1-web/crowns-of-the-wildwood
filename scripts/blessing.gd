extends Node3D
## A Blessing of Light: a buff that appears somewhere in the field now and
## then (game.gd spawns them). Walk into the pillar of light to take it:
## Regeneration, Swiftness or Might for a few seconds. It fades if nobody does.

const Stats = preload("res://scripts/stats.gd")

var game
var kind := "Regeneration"
var life := Stats.BLESSING_LIFE
var t := 0.0
var star: Node3D
var ring: MeshInstance3D
var halo: MeshInstance3D
var pillar: MeshInstance3D
var light: OmniLight3D
var color := Color(1.0, 0.9, 0.5)


func setup(p_game, pos: Vector3, p_kind: String) -> void:
	game = p_game
	kind = p_kind
	position = pos
	color = Stats.BLESSING_KINDS[kind].color

	pillar = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.5
	cyl.bottom_radius = 0.9
	cyl.height = 5.0
	cyl.radial_segments = 18
	pillar.mesh = cyl
	pillar.position.y = 2.5
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(color, 0.18)
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.cull_mode = BaseMaterial3D.CULL_DISABLED
	pillar.material_override = pm
	add_child(pillar)

	ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.95
	torus.outer_radius = 1.2
	ring.mesh = torus
	ring.position.y = 0.08
	var rm := StandardMaterial3D.new()
	rm.albedo_color = color
	rm.emission_enabled = true
	rm.emission = color
	rm.emission_energy_multiplier = 1.5
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = rm
	add_child(ring)

	# A tilted halo ring spinning the other way around the star.
	halo = MeshInstance3D.new()
	var ht := TorusMesh.new()
	ht.inner_radius = 0.62
	ht.outer_radius = 0.7
	halo.mesh = ht
	halo.position.y = 1.75
	halo.rotation.x = 0.5
	halo.material_override = rm
	add_child(halo)
	# A soft glowing core behind the star.
	var core := MeshInstance3D.new()
	var cs := SphereMesh.new()
	cs.radius = 0.42
	cs.height = 0.84
	core.mesh = cs
	core.position.y = 1.75
	var corem := StandardMaterial3D.new()
	corem.albedo_color = Color(color, 0.35)
	corem.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	corem.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	corem.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core.material_override = corem
	add_child(core)

	# A floating star: two crossed diamonds.
	star = Node3D.new()
	star.position.y = 1.3
	add_child(star)
	for rot in [0.0, PI / 2.0]:
		var d := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(0.5, 0.9, 0.12)
		d.mesh = prism
		d.rotation.y = rot
		d.material_override = rm
		star.add_child(d)
		var d2 := MeshInstance3D.new()
		d2.mesh = prism
		d2.rotation.y = rot
		d2.rotation.z = PI
		d2.position.y = -0.9
		d2.material_override = rm
		star.add_child(d2)
	star.position.y = 1.75

	var sparks := CPUParticles3D.new()
	sparks.amount = 24
	sparks.lifetime = 1.6
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sparks.emission_sphere_radius = 0.9
	sparks.direction = Vector3.UP
	sparks.spread = 10.0
	sparks.initial_velocity_min = 1.0
	sparks.initial_velocity_max = 2.0
	sparks.gravity = Vector3.ZERO
	sparks.scale_amount_min = 0.05
	sparks.scale_amount_max = 0.12
	sparks.color = color
	var smesh := SphereMesh.new()
	smesh.radius = 0.5
	smesh.height = 1.0
	sparks.mesh = smesh
	var sm := StandardMaterial3D.new()
	sm.albedo_color = color
	sm.emission_enabled = true
	sm.emission = color
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smesh.material = sm
	sparks.position.y = 0.3
	add_child(sparks)

	light = OmniLight3D.new()
	light.light_color = color
	light.light_energy = 2.0
	light.omni_range = 6.0
	light.position.y = 1.5
	add_child(light)


func _process(delta: float) -> void:
	t += delta
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	star.rotation.y += delta * 1.8
	star.position.y = 1.75 + sin(t * 2.5) * 0.15
	ring.rotation.y -= delta * 0.6
	halo.rotation.y -= delta * 1.4
	halo.position.y = star.position.y
	var fade: float = clampf(life / 4.0, 0.0, 1.0)
	pillar.material_override.albedo_color = Color(color, (0.14 + 0.06 * sin(t * 4.0)) * fade)
	light.light_energy = 2.0 * fade
	if game.net_client:
		return   # online: the host hands out blessings
	for u in game.units:
		if u.dead or u.carrying:
			continue
		var offset: Vector3 = u.global_position - global_position
		if absf(offset.y) < 1.5 and Vector2(offset.x, offset.z).length() < 1.2:
			u.apply_blessing(kind)
			game.sfx.play("blessing", global_position, 0.0)
			game.spawn_pillar(global_position, color, 6.0, 1.0)
			game.spawn_ring(global_position, 3.0, color, 0.7)
			game.spawn_splash(global_position + Vector3(0, 0.5, 0), color, 40, 5.0, 1.0, true)
			game.spawn_flash(global_position, color, 5.0, 0.5)
			queue_free()
			return
