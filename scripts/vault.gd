extends StaticBody3D
## The Crown Vault: a barred cage around a team's throne. Its lock gate only
## blocks the enemy team (defenders walk through), breaks after enough hits,
## swings open to reveal the monarch, and locks again a while later once no
## enemy is left in the keep. Humans forge iron bars; Elves grow a lattice of
## glowing crystal.

const Stats = preload("res://scripts/stats.gd")

var game
var team := 0
var hp := Stats.VAULT_HITS
var open := false
var relock_timer := 0.0
var side := 1.0
var lock_pos := Vector3.ZERO     # where attackers stand to break the lock
var shape: CollisionShape3D
var door: Node3D                 # the front bars, hinged at the top
var door_angle := 0.0
var bar_mats: Array = []
var label: Label3D
var glow_light: OmniLight3D


func setup(p_game, p_team: int, throne: Vector3, p_side: float) -> void:
	game = p_game
	team = p_team
	side = p_side
	var elf := team == 0
	# The cage ring sits around the throne; the lock gate faces the archway.
	var front_x := throne.x - side * 2.8
	position = Vector3(throne.x, 0, 0)
	lock_pos = Vector3(front_x, 0, 0)
	collision_layer = 4 if team == 0 else 8
	collision_mask = 0

	var metal := StandardMaterial3D.new()
	if elf:
		metal.albedo_color = Color(0.55, 0.95, 0.8)
		metal.emission_enabled = true
		metal.emission = Color(0.3, 0.9, 0.7)
		metal.emission_energy_multiplier = 0.9
		metal.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		metal.albedo_color.a = 0.75
	else:
		metal.albedo_color = Color(0.3, 0.26, 0.22)
		metal.metallic = 0.6
		metal.roughness = 0.5
	# Side and back bars, solid for the enemy: three colliders and their bars.
	var half_z := 3.4
	var depth := 5.6
	for zs in [-1.0, 1.0]:
		_bars(Vector3(-side * depth / 2.0 + side * 0.0, 0, zs * half_z), Vector3(depth, 0, 0), metal, elf)
		_collider(Vector3(0, 1.3, zs * half_z), Vector3(depth + 0.4, 2.6, 0.3))
	_bars(Vector3(side * depth / 2.0, 0, -half_z), Vector3(0, 0, half_z * 2), metal, elf)
	_collider(Vector3(side * depth / 2.0, 1.3, 0), Vector3(0.3, 2.6, half_z * 2 + 0.4))
	# Corner posts.
	for zs in [-1.0, 1.0]:
		for xs in [-1.0, 1.0]:
			var post := MeshInstance3D.new()
			var pm := BoxMesh.new()
			pm.size = Vector3(0.34, 2.8, 0.34)
			post.mesh = pm
			post.position = Vector3(xs * depth / 2.0, 1.4, zs * half_z)
			var post_mat := StandardMaterial3D.new()
			post_mat.albedo_color = Color(0.5, 0.42, 0.3) if elf else Color(0.4, 0.4, 0.44)
			if elf:
				post_mat.albedo_texture = load("res://assets/textures/bark_color.jpg")
				post_mat.uv1_triplanar = true
				post_mat.uv1_scale = Vector3.ONE * 0.6
			post.material_override = post_mat
			add_child(post)
	# The lock gate: the front bars on a hinge, with its own collider.
	door = Node3D.new()
	door.position = Vector3(-side * depth / 2.0, 2.6, 0)
	add_child(door)
	var gate_bars := Node3D.new()
	gate_bars.position = Vector3(0, -2.6, -half_z)
	door.add_child(gate_bars)
	_bars_into(gate_bars, Vector3.ZERO, Vector3(0, 0, half_z * 2), metal, elf)
	var lock := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(0.4, 0.5, 0.6)
	lock.mesh = lm
	lock.position = Vector3(0, -1.3, 0)
	var lock_mat := StandardMaterial3D.new()
	lock_mat.albedo_color = Color(0.95, 0.78, 0.25)
	lock_mat.metallic = 0.8
	lock_mat.roughness = 0.3
	lock.material_override = lock_mat
	door.add_child(lock)
	shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.4, 2.6, half_z * 2 + 0.4)
	shape.shape = box
	shape.position = Vector3(-side * depth / 2.0, 1.3, 0)
	add_child(shape)

	label = Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 30
	label.pixel_size = 0.011
	label.outline_size = 8
	label.position = Vector3(-side * depth / 2.0, 3.3, 0)
	add_child(label)
	glow_light = OmniLight3D.new()
	glow_light.light_color = Color(0.4, 1.0, 0.8) if elf else Color(1.0, 0.75, 0.4)
	glow_light.light_energy = 1.2
	glow_light.omni_range = 7.0
	glow_light.position = Vector3(0, 2.5, 0)
	add_child(glow_light)
	_refresh()


func _collider(pos: Vector3, size: Vector3) -> void:
	var s := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	s.shape = b
	s.position = pos
	add_child(s)


func _bars(start: Vector3, span: Vector3, mat: Material, elf: bool) -> void:
	_bars_into(self, start, span, mat, elf)


func _bars_into(parent: Node3D, start: Vector3, span: Vector3, mat: Material, elf: bool) -> void:
	# A low stone (or root) plinth under the bars so the cage reads as a
	# built wall rather than floating lines, then thick bars on top.
	var plinth := MeshInstance3D.new()
	var pb := BoxMesh.new()
	pb.size = Vector3(maxf(absf(span.x), 0.5), 0.7, maxf(absf(span.z), 0.5))
	plinth.mesh = pb
	plinth.position = start + span / 2.0 + Vector3(0, 0.35, 0)
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.5, 0.42, 0.3) if elf else Color(0.9, 0.86, 0.78)
	pmat.albedo_texture = load("res://assets/textures/%s_color.jpg" % ("bark" if elf else "stone"))
	pmat.uv1_triplanar = true
	pmat.uv1_world_triplanar = true
	pmat.uv1_scale = Vector3.ONE * 0.5
	plinth.material_override = pmat
	parent.add_child(plinth)
	var n := int(span.length() / 0.7)
	for i in n + 1:
		var bar := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.06 if not elf else 0.05
		cm.bottom_radius = 0.075 if not elf else 0.14
		cm.height = 2.5
		cm.radial_segments = 6
		bar.mesh = cm
		bar.position = start + span * (float(i) / n) + Vector3(0, 1.25, 0)
		if elf:
			bar.rotation.z = sin(i * 1.7) * 0.12
			bar.rotation.x = cos(i * 2.3) * 0.12
		bar.material_override = mat
		parent.add_child(bar)
		bar_mats.append(mat)
	# A top rail.
	var rail := MeshInstance3D.new()
	var rm := BoxMesh.new()
	rm.size = Vector3(maxf(absf(span.x), 0.12), 0.12, maxf(absf(span.z), 0.12))
	rail.mesh = rm
	rail.position = start + span / 2.0 + Vector3(0, 2.5, 0)
	rail.material_override = mat
	parent.add_child(rail)


func is_locked() -> bool:
	return not open


func take_hit(amount: int, attacker = null) -> void:
	if open:
		return
	hp = maxi(hp - amount, 0)
	if attacker:
		attacker.gain_xp(Stats.XP_GATE * amount)
	game.spawn_splash(lock_pos + Vector3(0, 1.2, 0), Color(1.0, 0.85, 0.4), 10, 3.5, 0.4)
	game.shake_at(lock_pos, 0.3)
	game.sfx.play("vault_hit", lock_pos, -2.0, 0.12)
	if hp == 0:
		open = true
		game.sfx.play("vault_open", lock_pos, 2.0)
		relock_timer = Stats.VAULT_RELOCK_TIME
		shape.disabled = true
		game.announce("The %s Crown Vault is open! The %s is exposed!" % [Stats.FACTIONS[team].name, game.monarchs[team].title])
		game.chat_system("The %s vault lock is broken." % Stats.FACTIONS[team].name)
		game.spawn_splash(lock_pos + Vector3(0, 1.0, 0), Color(1.0, 0.85, 0.4), 50, 6.0, 1.0, true)
		game.spawn_flash(lock_pos + Vector3(0, 1.5, 0), Color(1.0, 0.85, 0.4), 4.0, 0.4)
		game.spawn_ring(position, 4.0, Color(1.0, 0.85, 0.4), 0.8)
		game.shake_at(lock_pos, 0.7)
	_refresh()


func _refresh() -> void:
	if open:
		label.text = "Vault open: locks in %d" % ceili(relock_timer)
		label.modulate = Color(1, 0.6, 0.4)
	else:
		label.text = "Crown Vault lock %d / %d" % [hp, Stats.VAULT_HITS]
		label.modulate = Color(1, 0.9, 0.5)


func _process(delta: float) -> void:
	# The lock gate swings up when open and down when it relocks.
	var target := -1.35 if open else 0.0
	door_angle = move_toward(door_angle, target, delta * 2.2)
	door.rotation.z = door_angle * side
	if glow_light:
		glow_light.light_energy = 1.2 + (0.6 * sin(Time.get_ticks_msec() / 200.0) if open else 0.0)
	if not open:
		return
	relock_timer -= delta
	if relock_timer <= 0.0 and not game.enemy_inside_keep(team) and game.monarchs[team].state == 0:
		open = false
		hp = Stats.VAULT_HITS
		shape.disabled = false
		game.sfx.play("door_rebuilt", lock_pos, -4.0, 0.0)
		game.announce("The %s Crown Vault has locked again." % Stats.FACTIONS[team].name)
	_refresh()
