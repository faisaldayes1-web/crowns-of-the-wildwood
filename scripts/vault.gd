extends StaticBody3D
## The Crown Vault: the throne room's doors. They only block the enemy team
## (defenders walk through), break open after enough hits on the lock, swing
## wide to expose the monarch, and lock again a while later once no enemy is
## left in the keep. Humans hang iron-banded oak; Elves weave living bark
## bound with glowing crystal.

const Stats = preload("res://scripts/stats.gd")

var game
var team := 0
var hp := Stats.VAULT_HITS
var open := false
var relock_timer := 0.0
var side := 1.0
var lock_pos := Vector3.ZERO     # where attackers stand to break the lock
var shape: CollisionShape3D
var door: Node3D                 # the doorway node; its two leaves swing open
var leaves: Array = []
var door_angle := 0.0
var bar_mats: Array = []
var label: Label3D
var glow_light: OmniLight3D


func setup(p_game, p_team: int, throne: Vector3, p_side: float) -> void:
	game = p_game
	team = p_team
	side = p_side
	var elf := team == 0
	# The doors sit in the throne room's front wall (game.gd _build_throne_room).
	var front_x: float = throne.x - side * game.ROOM_FRONT
	var half: float = game.ROOM_DOOR_HALF
	position = Vector3(throne.x, 0, 0)
	lock_pos = Vector3(front_x, 0, 0)
	collision_layer = 4 if team == 0 else 8
	collision_mask = 0

	var leaf_mat: StandardMaterial3D
	var band_mat: StandardMaterial3D
	if elf:
		leaf_mat = game._pbr("bark", 0.6, Color(0.62, 0.56, 0.42))
		band_mat = StandardMaterial3D.new()
		band_mat.albedo_color = Color(0.55, 0.95, 0.8)
		band_mat.emission_enabled = true
		band_mat.emission = Color(0.3, 0.9, 0.7)
		band_mat.emission_energy_multiplier = 0.9
	else:
		leaf_mat = game._pbr("wood_dark", 0.5, Color(0.8, 0.7, 0.6))
		band_mat = game._iron()
	# Two door leaves, each hinged on its post, swinging into the room.
	door = Node3D.new()
	door.position = Vector3(front_x - throne.x, 0, 0)
	add_child(door)
	for zs in [-1.0, 1.0]:
		var hinge := Node3D.new()
		hinge.position = Vector3(0, 0, zs * half)
		door.add_child(hinge)
		leaves.append(hinge)
		var leaf := MeshInstance3D.new()
		var lm := BoxMesh.new()
		lm.size = Vector3(0.18, 2.2, half)
		leaf.mesh = lm
		leaf.position = Vector3(0, 1.1, -zs * half / 2.0)
		leaf.material_override = leaf_mat
		hinge.add_child(leaf)
		for y in [0.5, 1.1, 1.7]:
			var band := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.24, 0.12, half - 0.1)
			band.mesh = bm
			band.position = Vector3(0, y, -zs * half / 2.0)
			band.material_override = band_mat
			hinge.add_child(band)
			bar_mats.append(band_mat)
		# The lock plate where the leaves meet.
		var lock := MeshInstance3D.new()
		var km := BoxMesh.new()
		km.size = Vector3(0.3, 0.5, 0.3)
		lock.mesh = km
		lock.position = Vector3(0, 1.1, -zs * (half - 0.2))
		var lock_mat := StandardMaterial3D.new()
		lock_mat.albedo_color = Color(0.95, 0.78, 0.25)
		lock_mat.metallic = 0.8
		lock_mat.roughness = 0.3
		lock.material_override = lock_mat
		hinge.add_child(lock)
	shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.5, 2.6, half * 2 + 0.2)
	shape.shape = box
	shape.position = Vector3(front_x - throne.x, 1.3, 0)
	add_child(shape)

	label = Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 30
	label.pixel_size = 0.0085
	label.outline_size = 12
	label.outline_modulate = Color(0.08, 0.06, 0.04)
	label.position = Vector3(front_x - throne.x, 3.3, 0)
	add_child(label)
	glow_light = OmniLight3D.new()
	glow_light.light_color = Color(0.4, 1.0, 0.8) if elf else Color(1.0, 0.75, 0.4)
	glow_light.light_energy = 1.2
	glow_light.omni_range = 7.0
	glow_light.position = Vector3(0, 2.5, 0)
	add_child(glow_light)
	_refresh()


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
		game.announce("The %s Crown Vault is open! The %s is exposed!" % [Stats.FACTIONS[team].name, game.monarchs[team].title.to_lower()])
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
	# Out of the way until someone starts on the lock (it sat on the crown's label).
	label.visible = open or hp < Stats.VAULT_HITS


func _process(delta: float) -> void:
	# The doors swing into the room when open and shut when they relock.
	var target := 1.6 if open else 0.0
	door_angle = move_toward(door_angle, target, delta * 2.2)
	for i in leaves.size():
		leaves[i].rotation.y = door_angle * side * (1.0 if i == 0 else -1.0)
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
