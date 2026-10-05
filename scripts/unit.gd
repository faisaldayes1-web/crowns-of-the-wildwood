extends CharacterBody3D
## One soldier on either team, driven by the local player or by a simple bot brain.
## Everyone starts as a plain Elf or Human and transforms by stepping onto a
## class station in their castle. Dying resets you to the plain form.
## All class numbers and movesets live in stats.gd.

const Stats = preload("res://scripts/stats.gd")
const Monarch = preload("res://scripts/monarch.gd")
const Builder = preload("res://scripts/character_builder.gd")
const Role = Stats.Role

const GRAVITY := 20.0
const PICKUP_RANGE := 1.8

var game
var team := 0
var role: int = Role.BASE
var is_player := false
var hearts := Stats.MAX_HEARTS
var energy := 100.0
var dead := false
var respawn_timer := 0.0
var attack_timer := 0.0
var flash_timer := 0.0
var ability_timers := [0.0, 0.0]
var dodge_timer := 0.0      # time left in the current dash
var dodge_cooldown := 0.0   # time until the next dodge is ready
var dodge_dir := Vector3.ZERO
var bash_timer := 0.0       # a Knight's Shield Bash is a dash that hurts
var bash_speed := 0.0
var bash_hit: Array = []
var guard_timer := 0.0      # Shield Wall: no damage gets through
var root_timer := 0.0       # snared: can't move
var haste_timer := 0.0      # blessed: faster
var knockback := Vector3.ZERO
var carrying = null
var spawn_point := Vector3.ZERO
var facing := Vector3(1, 0, 0)

# Where attacks go. The player aims with the mouse or the right stick, so
# aiming is independent of walking; bots aim at whatever they are fighting.
var aim := Vector3(1, 0, 0)
var aim_point := Vector3.ZERO
var aim_mode := "move"      # "mouse", "stick", or "move" (aim follows walking)
var last_mouse := Vector2(-1, -1)

# Bots: "attack" raids the enemy castle, "wall" shoots from the ramparts over
# the door, "support" follows a raider (healers), "defend" guards the throne.
var bot_job := "attack"
var bot_class: int = Role.KNIGHT
var bot_offset := Vector3.ZERO
var stuck_time := 0.0
var sidestep_timer := 0.0   # while > 0 the bot commits to walking around an obstacle
var sidestep_sign := 1.0

var shape: CollisionShape3D
var build: Node3D
var rig := {}                 # pivots from character_builder.gd
var flash_mats: Array = []    # materials that turn red when hit
var base_colors: Array = []
var walk_phase := 0.0
var swing := 0.0              # weapon-arm swing, 1.0 right after an attack
var guard_ring: MeshInstance3D
var overhead: Node3D
var label: Label3D
var heart_mats: Array[StandardMaterial3D] = []
var aim_marker: MeshInstance3D
var aim_ring: MeshInstance3D


func setup(p_game, p_team: int, p_is_player: bool, p_spawn: Vector3) -> void:
	game = p_game
	team = p_team
	is_player = p_is_player
	spawn_point = p_spawn
	position = p_spawn
	facing = Vector3(1, 0, 0) if team == 0 else Vector3(-1, 0, 0)
	aim = facing
	rotation.y = atan2(-facing.x, -facing.z)
	bot_offset = Vector3(randf_range(-2.5, 2.5), 0, randf_range(-2.5, 2.5))
	sidestep_sign = 1.0 if bot_offset.x > 0.0 else -1.0
	collision_layer = 2
	# The world, plus the ENEMY door (layer 4 = human door, layer 3 = elf door).
	collision_mask = 1 | (8 if team == 0 else 4)

	shape = CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.6
	shape.shape = capsule
	shape.position.y = 0.8
	add_child(shape)

	build = Node3D.new()
	add_child(build)

	# A soft shadow blob so everyone reads clearly from above.
	var blob := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.5
	disc.bottom_radius = 0.5
	disc.height = 0.02
	blob.mesh = disc
	blob.position.y = 0.02
	var blob_mat := StandardMaterial3D.new()
	blob_mat.albedo_color = Color(0, 0, 0, 0.3)
	blob_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	blob_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	blob.material_override = blob_mat
	add_child(blob)

	# Shield Wall glow, hidden until used.
	guard_ring = MeshInstance3D.new()
	var guard_mesh := TorusMesh.new()
	guard_mesh.inner_radius = 0.75
	guard_mesh.outer_radius = 0.95
	guard_ring.mesh = guard_mesh
	guard_ring.position.y = 1.0
	var guard_mat := StandardMaterial3D.new()
	guard_mat.albedo_color = Color(0.5, 0.75, 1.0)
	guard_mat.emission_enabled = true
	guard_mat.emission = Color(0.4, 0.6, 1.0)
	guard_ring.material_override = guard_mat
	guard_ring.visible = false
	add_child(guard_ring)

	if is_player:
		var ring := MeshInstance3D.new()
		var ring_mesh := TorusMesh.new()
		ring_mesh.inner_radius = 0.6
		ring_mesh.outer_radius = 0.8
		ring.mesh = ring_mesh
		ring.position.y = 0.05
		var ring_mat := StandardMaterial3D.new()
		ring_mat.albedo_color = Color(1, 1, 0.3)
		ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ring.material_override = ring_mat
		add_child(ring)

		# A pointer on the ground showing where you aim, and a ring at the cursor.
		aim_marker = MeshInstance3D.new()
		aim_marker.top_level = true
		var bar := BoxMesh.new()
		bar.size = Vector3(0.14, 0.04, 1.0)
		aim_marker.mesh = bar
		var bar_mat := StandardMaterial3D.new()
		bar_mat.albedo_color = Color(1, 1, 0.3)
		bar_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		aim_marker.material_override = bar_mat
		add_child(aim_marker)
		aim_ring = MeshInstance3D.new()
		aim_ring.top_level = true
		var cursor_mesh := TorusMesh.new()
		cursor_mesh.inner_radius = 0.28
		cursor_mesh.outer_radius = 0.4
		aim_ring.mesh = cursor_mesh
		aim_ring.material_override = bar_mat
		add_child(aim_ring)

	# Name and hearts float above the head, tilted to face the camera.
	overhead = Node3D.new()
	overhead.top_level = true
	overhead.rotation_degrees.x = -55.0
	add_child(overhead)
	label = Label3D.new()
	label.no_depth_test = true
	label.font_size = 26
	label.pixel_size = 0.012
	label.outline_size = 8
	label.position.y = 0.35
	overhead.add_child(label)
	for i in Stats.MAX_HEARTS:
		var heart := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(0.24, 0.22)
		heart.mesh = quad
		heart.position.x = (i - (Stats.MAX_HEARTS - 1) / 2.0) * 0.3
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.no_depth_test = true
		mat.render_priority = 1
		heart.material_override = mat
		heart_mats.append(mat)
		overhead.add_child(heart)

	set_role(Role.BASE)


func stats() -> Dictionary:
	return Stats.ROLES[role]


func role_name() -> String:
	return Stats.FACTIONS[team].roles[role]


func energy_kind() -> String:
	return stats().energy


func energy_max() -> float:
	return Stats.MANA_MAX if energy_kind() == "mana" else Stats.STAMINA_MAX


func abilities() -> Array:
	return stats().abilities


func set_role(new_role: int) -> void:
	role = new_role
	hearts = Stats.MAX_HEARTS
	energy = energy_max()
	ability_timers = [0.0, 0.0]
	var s := stats()
	build.scale = s.build
	rig = Builder.build(build, team, role)
	flash_mats = rig.flash_mats
	base_colors = []
	for m in flash_mats:
		base_colors.append(m.albedo_color)
	walk_phase = 0.0
	swing = 0.0
	_refresh_overhead()


func _refresh_overhead() -> void:
	var tag := "YOU · " if is_player else ""
	label.text = tag + role_name()
	label.modulate = Color(1, 1, 0.6) if is_player else Color(1, 1, 1)
	for i in heart_mats.size():
		heart_mats[i].albedo_color = Color(0.95, 0.15, 0.2) if i < hearts else Color(0.2, 0.2, 0.2)


func take_damage(amount: int) -> void:
	if dead or dodge_timer > 0.0 or guard_timer > 0.0:
		return  # mid-dodge or behind the shield: untouchable
	hearts -= amount
	flash_timer = 0.15
	if hearts <= 0:
		_die()
		return
	_refresh_overhead()
	# Bots roll sideways away from whatever just hit them, half the time.
	if not is_player and dodge_ready() and randf() < 0.5:
		try_dodge(facing.cross(Vector3.UP) * (1.0 if randf() < 0.5 else -1.0))


func heal(amount: int) -> void:
	if dead:
		return
	hearts = mini(hearts + amount, Stats.MAX_HEARTS)
	_refresh_overhead()


func dodge_ready() -> bool:
	return dodge_cooldown <= 0.0 and not dead and carrying == null and root_timer <= 0.0


func try_dodge(dir: Vector3) -> void:
	if not dodge_ready():
		return
	dir.y = 0.0
	dodge_dir = dir.normalized() if dir.length() > 0.05 else facing
	facing = dodge_dir
	rotation.y = atan2(-facing.x, -facing.z)
	dodge_timer = Stats.DODGE_TIME
	dodge_cooldown = Stats.DODGE_COOLDOWN
	game.spawn_burst(global_position, 0.8, Color(1, 1, 1))


func ability_ready(i: int) -> bool:
	return i < abilities().size() and ability_timers[i] <= 0.0 and not dead and carrying == null \
		and energy >= abilities()[i].cost


func use_ability(i: int, dir: Vector3) -> void:
	if not ability_ready(i):
		return
	var a: Dictionary = abilities()[i]
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.05 else facing
	energy -= a.cost
	ability_timers[i] = a.cooldown
	swing = 1.0
	facing = dir
	rotation.y = atan2(-facing.x, -facing.z)
	match a.kind:
		"bash":
			# A short dash that hits and shoves everyone in its path.
			dodge_dir = dir
			bash_timer = 0.2
			bash_speed = a.distance / 0.2
			bash_hit = []
			game.spawn_burst(global_position, 1.0, Color(0.8, 0.85, 1.0))
		"guard":
			guard_timer = a.duration
			guard_ring.visible = true
		"volley":
			for k in a.arrows:
				var ang: float = deg_to_rad(a.spread) * (float(k) / (a.arrows - 1) - 0.5)
				game.spawn_shot(self, dir.rotated(Vector3.UP, ang),
					{"damage": a.damage, "gate_damage": 1, "range": a.range}, Color(0.95, 0.9, 0.7))
		"trap":
			game.spawn_trap(self, global_position + dir * 1.5, a)
		"fireball":
			game.spawn_shot(self, dir, {"damage": a.damage, "gate_damage": 4, "range": a.range,
				"splash": a.splash, "speed": a.speed}, Color(1.0, 0.5, 0.1))
		"blink":
			var from := global_position + Vector3(0, 0.9, 0)
			var to: Vector3 = from + dir * a.distance
			var ray := PhysicsRayQueryParameters3D.create(from, to, collision_mask)
			var hit := get_world_3d().direct_space_state.intersect_ray(ray)
			if hit:
				to = hit.position - dir * 0.8
			game.spawn_burst(global_position, 1.0, Color(0.7, 0.45, 1.0))
			global_position = Vector3(to.x, global_position.y, to.z)
			game.spawn_burst(global_position, 1.0, Color(0.7, 0.45, 1.0))
		"blessing":
			for ally in game.units:
				if ally.team == team and not ally.dead and _flat_to(ally.global_position).length() <= a.radius:
					ally.heal(a.heal)
					ally.haste_timer = a.haste
			game.spawn_burst(global_position + Vector3(0, 0.2, 0), a.radius, Color(1.0, 0.95, 0.5))
		"smite":
			game.spawn_shot(self, dir, {"damage": a.damage, "gate_damage": 1, "range": a.range,
				"speed": a.speed}, Color(1.0, 0.95, 0.5))


func _die() -> void:
	dead = true
	hearts = 0
	if carrying:
		game.drop_monarch(self)
	visible = false
	shape.disabled = true
	respawn_timer = Stats.RESPAWN_TIME
	velocity = Vector3.ZERO
	guard_timer = 0.0
	guard_ring.visible = false
	if aim_marker:
		aim_marker.visible = false
		aim_ring.visible = false


func _respawn() -> void:
	dead = false
	set_role(Role.BASE)
	position = spawn_point + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5))
	visible = true
	shape.disabled = false
	if aim_marker:
		aim_marker.visible = true


func _process(delta: float) -> void:
	_animate(delta)
	if overhead:
		overhead.global_position = global_position + Vector3(0, 2.4 * build.scale.y + 0.25, 0)
	if aim_marker and not dead:
		aim_marker.global_position = global_position + aim * 1.1 + Vector3(0, 0.08, 0)
		aim_marker.rotation.y = atan2(-aim.x, -aim.z)
		aim_ring.visible = aim_mode == "mouse"
		aim_ring.global_position = Vector3(aim_point.x, global_position.y + 0.08, aim_point.z)


func _animate(delta: float) -> void:
	## Walk cycle, idle breathing and the weapon swing. Pure cosmetics.
	if rig.is_empty() or dead:
		return
	var planar := Vector2(velocity.x, velocity.z).length()
	var moving := planar > 0.5
	if moving:
		walk_phase += delta * planar * 1.7
	else:
		walk_phase = lerp_angle(walk_phase, 0.0, delta * 10.0)
	swing = maxf(swing - delta * 4.5, 0.0)
	var leg := sin(walk_phase) * 0.7 if moving else 0.0
	rig.left_leg.rotation.x = leg
	rig.right_leg.rotation.x = -leg
	var arm := sin(walk_phase) * 0.5 if moving else 0.0
	rig.left_arm.rotation.x = -arm
	rig.left_arm.rotation.z = 0.15
	# The weapon arm swings forward and up on an attack, otherwise walks.
	var raise := sin(swing * PI) * 2.2
	rig.right_arm.rotation.x = arm + raise
	rig.right_arm.rotation.z = -0.15 - raise * 0.15
	var t := Time.get_ticks_msec() / 1000.0
	var bob := absf(sin(walk_phase)) * 0.07 if moving else sin(t * 2.0 + float(get_instance_id() % 7)) * 0.015
	rig.torso.position.y = bob
	rig.torso.rotation.x = 0.12 if moving else 0.0
	rig.torso.rotation.z = (sin(walk_phase) * 0.04) if moving else 0.0
	# Dash: lean into it.
	if dodge_timer > 0.0 or bash_timer > 0.0:
		rig.torso.rotation.x = 0.5
		rig.left_leg.rotation.x = 0.8
		rig.right_leg.rotation.x = -0.8


func _update_player_aim(move: Vector3) -> void:
	var cam: Camera3D = game.camera
	var mouse := get_viewport().get_mouse_position()
	var stick := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	if stick.length() > 0.3:
		aim_mode = "stick"
	elif mouse != last_mouse:
		aim_mode = "mouse"
	last_mouse = mouse
	match aim_mode:
		"stick":
			if stick.length() > 0.3:
				aim = Vector3(stick.x, 0, stick.y).normalized()
			elif move.length() > 0.05:
				aim = move.normalized()
			aim_point = global_position + aim * 6.0
		"mouse":
			var plane := Plane(Vector3.UP, global_position.y + 1.0)
			var hit = plane.intersects_ray(cam.project_ray_origin(mouse), cam.project_ray_normal(mouse))
			if hit != null:
				aim_point = hit
				var to: Vector3 = hit - global_position
				to.y = 0.0
				if to.length() > 0.3:
					aim = to.normalized()
		_:
			if move.length() > 0.05:
				aim = move.normalized()
			aim_point = global_position + aim * 6.0


func _physics_process(delta: float) -> void:
	if game == null or not game.playing:
		return
	if dead:
		respawn_timer -= delta
		if respawn_timer <= 0.0:
			_respawn()
		return

	var regen := Stats.MANA_REGEN if energy_kind() == "mana" else Stats.STAMINA_REGEN
	energy = minf(energy + regen * Stats.FACTIONS[team].regen_mult * delta, energy_max())
	attack_timer = maxf(attack_timer - delta, 0.0)
	dodge_cooldown = maxf(dodge_cooldown - delta, 0.0)
	for i in ability_timers.size():
		ability_timers[i] = maxf(ability_timers[i] - delta, 0.0)
	root_timer = maxf(root_timer - delta, 0.0)
	haste_timer = maxf(haste_timer - delta, 0.0)
	if guard_timer > 0.0:
		guard_timer -= delta
		if guard_timer <= 0.0:
			guard_ring.visible = false
	if flash_timer > 0.0:
		flash_timer -= delta
		for i in flash_mats.size():
			flash_mats[i].albedo_color = Color(1, 0.3, 0.3) if flash_timer > 0.0 else base_colors[i]

	var speed: float = Stats.FACTIONS[team].speed * stats().speed
	if carrying:
		speed *= Stats.CARRY_SPEED_MULT
	if haste_timer > 0.0:
		speed *= 1.3
	if guard_timer > 0.0:
		speed *= 0.5

	# Mid-dash (dodge or Shield Bash): fly in the dash direction and ignore the rest.
	if dodge_timer > 0.0 or bash_timer > 0.0:
		var dash_speed := speed * Stats.DODGE_SPEED_MULT
		if bash_timer > 0.0:
			bash_timer -= delta
			dash_speed = bash_speed
			for other in game.units:
				if other.team != team and not other.dead and not other in bash_hit \
						and _flat_to(other.global_position).length() < 1.3 \
						and absf(other.global_position.y - global_position.y) < 1.5:
					bash_hit.append(other)
					other.take_damage(abilities()[0].damage)
					other.knockback = dodge_dir * 9.0
		else:
			dodge_timer -= delta
		velocity.x = dodge_dir.x * dash_speed
		velocity.z = dodge_dir.z * dash_speed
		velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
		move_and_slide()
		_clamp_to_map()
		return

	var move := Vector3.ZERO
	var wants_attack := false
	var plan := {}
	if is_player:
		var stick := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		move = Vector3(stick.x, 0, stick.y)
		_update_player_aim(move)
		wants_attack = Input.is_action_pressed("attack")
		if Input.is_action_just_pressed("interact"):
			game.try_interact(self)
		if Input.is_action_just_pressed("ability_1"):
			use_ability(0, aim)
		if Input.is_action_just_pressed("ability_2"):
			use_ability(1, aim)
		if Input.is_action_just_pressed("dodge"):
			try_dodge(move)
		if dodge_timer > 0.0 or bash_timer > 0.0:
			return
	else:
		plan = _bot_think()
		move = plan.move
		wants_attack = plan.attack
		aim = plan.aim

	if root_timer > 0.0:
		move = Vector3.ZERO

	# The player always faces where they aim; bots face where they walk, or
	# whatever they are attacking.
	if is_player:
		facing = aim
	elif wants_attack and aim.length() > 0.05:
		facing = aim.normalized()
	elif move.length() > 0.05:
		facing = move.normalized()
	rotation.y = atan2(-facing.x, -facing.z)

	velocity.x = move.x * speed + knockback.x
	velocity.z = move.z * speed + knockback.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()
	_clamp_to_map()
	knockback = knockback.move_toward(Vector3.ZERO, 40.0 * delta)

	# Bots that bump into a tree or wall sidestep around it.
	sidestep_timer = maxf(sidestep_timer - delta, 0.0)
	if not is_player and move.length() > 0.1:
		var real := get_real_velocity()
		real.y = 0.0
		stuck_time = stuck_time + delta if real.length() < speed * 0.3 else 0.0

	if wants_attack and carrying == null and attack_timer <= 0.0:
		_attack(aim)
	if plan.has("ability"):
		use_ability(plan.ability, plan.aim)


func _clamp_to_map() -> void:
	position.x = clampf(position.x, -game.map_half.x, game.map_half.x)
	position.z = clampf(position.z, -game.map_half.y, game.map_half.y)


# --- Combat ----------------------------------------------------------------

func _injured_allies_near(radius: float = -1.0) -> Array:
	var hurt := []
	var reach: float = stats().get("heal_radius", 0.0) if radius < 0.0 else radius
	for other in game.units:
		if other.team == team and not other.dead and other.hearts < Stats.MAX_HEARTS \
				and _flat_to(other.global_position).length() <= reach:
			hurt.append(other)
	return hurt


func _attack(dir: Vector3) -> void:
	var s := stats()
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.05 else facing
	var kind: String = s.attack
	if kind == "heal":
		var hurt := _injured_allies_near()
		if not hurt.is_empty() and energy >= s.cost:
			energy -= s.cost
			attack_timer = s.cooldown
			for ally in hurt:
				ally.heal(s.heal)
			swing = 1.0
			game.spawn_burst(global_position + Vector3(0, 0.2, 0), s.heal_radius, Color(0.3, 1.0, 0.5))
			return
		kind = "melee"  # nobody to heal: bonk with the staff, free of mana
	elif energy < s.cost:
		return  # out of stamina or mana
	else:
		energy -= s.cost
	attack_timer = s.cooldown
	swing = 1.0

	if kind == "arrow":
		game.spawn_shot(self, dir, s, Color(0.95, 0.9, 0.7))
		return
	if kind == "spell":
		game.spawn_shot(self, dir, s, Color(0.7, 0.45, 1.0))
		return
	game.spawn_swing(self, dir)
	for other in game.units:
		if other.team == team or other.dead:
			continue
		var to := _flat_to(other.global_position)
		var dist := to.length()
		# Swings reach people at your own height, not someone up on a wall.
		if dist <= s.range and absf(other.global_position.y - global_position.y) < 1.5 \
				and (dist < 0.8 or dir.dot(to / dist) > 0.3):
			other.take_damage(s.damage)
	# Swings from the ground also chip away at the enemy door.
	var gate = game.gates[1 - team]
	var gx: float = gate.position.x
	if gate.is_intact() and global_position.y < 1.0 and absf(global_position.x - gx) < s.range + 0.4 \
			and absf(global_position.z) < Stats.DOOR_HALF + 0.5 and dir.x * signf(gx - global_position.x) > 0.3:
		gate.take_hit(s.gate_damage)


# --- Bot brain -------------------------------------------------------------

func _flat_to(target: Vector3) -> Vector3:
	var to := target - global_position
	to.y = 0.0
	return to


func _steer_to(target: Vector3) -> Vector3:
	var to := _flat_to(target)
	if to.length() < 0.6:
		return Vector3.ZERO
	var dir := to.normalized()
	if stuck_time > 0.3:
		# Blocked: commit to walking around the obstacle for a moment, and try
		# the other side next time so a corner can't hold us for good.
		stuck_time = 0.0
		sidestep_timer = 1.2
		sidestep_sign = -sidestep_sign
	if sidestep_timer > 0.0:
		dir = (dir * 0.4 + dir.cross(Vector3.UP) * sidestep_sign).normalized()
	return dir


func _nearest_enemy(radius: float):
	var best = null
	var best_dist := radius
	for other in game.units:
		if other.team == team or other.dead:
			continue
		var d := _flat_to(other.global_position).length()
		if d < best_dist:
			best_dist = d
			best = other
	return best


func _nearest_ally(job: String):
	var best = null
	var best_dist := 1e9
	for other in game.units:
		if other == self or other.team != team or other.dead or other.bot_job != job:
			continue
		var d := _flat_to(other.global_position).length()
		if d < best_dist:
			best_dist = d
			best = other
	return best


func _bot_pick_ability(dist: float) -> int:
	## Which ability (0 or 1) a bot wants to use on an enemy this far away, or -1.
	match role:
		Role.KNIGHT:
			if dist < 4.0 and ability_ready(0) and randf() < 0.03:
				return 0
			if hearts <= 2 and dist < 3.0 and ability_ready(1) and randf() < 0.05:
				return 1
		Role.RANGER:
			if dist <= 12.0 and ability_ready(0) and randf() < 0.02:
				return 0
			if dist < 6.0 and ability_ready(1) and randf() < 0.03:
				return 1
		Role.MAGE:
			if dist <= 10.0 and ability_ready(0) and randf() < 0.02:
				return 0
			if hearts <= 1 and dist < 5.0 and ability_ready(1):
				return 1
		Role.HEALER:
			if _injured_allies_near().is_empty() and dist <= 10.0 and ability_ready(1) and randf() < 0.03:
				return 1
	return -1


func _bot_think() -> Dictionary:
	var plan := {"move": Vector3.ZERO, "attack": false, "aim": facing}
	var s := stats()
	var mine = game.monarchs[team]
	var theirs = game.monarchs[1 - team]
	var ranged: bool = s.attack == "arrow" or s.attack == "spell"
	var on_ground: bool = global_position.y < 1.0

	# Grab the enemy monarch whenever it's within reach.
	if not carrying and theirs.state != Monarch.State.CARRIED \
			and _flat_to(theirs.global_position).length() < PICKUP_RANGE:
		game.try_interact(self)

	# Choose where to go.
	var goal: Vector3
	var priority_target = null
	var holding_wall := false
	# Fresh spawns always grab their class first; the stations sit by the spawn.
	var gearing_up: bool = role == Role.BASE and bot_class != Role.BASE
	var orb = game.nearest_orb(global_position, 14.0) if hearts <= 2 and not carrying else null
	if carrying:
		goal = game.thrones[team]
	elif gearing_up:
		goal = game.station_position(team, bot_class)
	elif orb:
		goal = orb.global_position
	elif mine.state == Monarch.State.CARRIED:
		priority_target = mine.carrier
		goal = mine.carrier.global_position
	elif mine.state == Monarch.State.DROPPED:
		goal = mine.global_position
	elif theirs.state == Monarch.State.CARRIED:
		goal = theirs.carrier.global_position + bot_offset  # escort our carrier
	elif bot_job == "wall":
		goal = game.wall_post(team, bot_offset.z)
		holding_wall = true
	elif bot_job == "support":
		var buddy = _nearest_ally("attack")
		goal = (buddy.global_position if buddy else game.thrones[team]) + bot_offset * 0.6
	elif bot_job == "attack":
		goal = theirs.global_position
	else:
		goal = game.thrones[team] + Vector3(6.0 if team == 0 else -6.0, 0, 0) + bot_offset
	# Doors and ramps: the next point to walk toward on the way to the goal.
	var next: Vector3 = game.route_point(global_position, goal)

	# Healers patch up anyone hurt nearby before doing anything else, and
	# bless the group when several are hurt.
	if s.attack == "heal" and energy >= s.cost and not _injured_allies_near().is_empty():
		plan.attack = true
	if role == Role.HEALER and ability_ready(0) and _injured_allies_near(abilities()[0].radius).size() >= 2 \
			and randf() < 0.05:
		plan.ability = 0

	# The enemy door stands between us and the goal: break it down.
	var gate = game.gate_blocking(team, global_position, goal)
	if gate and not carrying:
		var side := signf(global_position.x - gate.position.x)
		var standoff := 7.0 if ranged else 1.3
		var spot := Vector3(gate.position.x + side * standoff, 0, clampf(global_position.z, -2.5, 2.5))
		if _nearest_enemy(3.0) == null:
			if _flat_to(spot).length() < 1.0:
				plan.aim = Vector3(-side, 0, 0)
				plan.attack = true
				if role == Role.MAGE and ability_ready(0) and randf() < 0.02:
					plan.ability = 0  # fireballs wreck doors
			else:
				plan.move = _steer_to(game.route_point(global_position, spot))
			return plan

	if carrying:
		plan.move = _steer_to(next)
		return plan

	# Fight anyone nearby, the enemy carrier first.
	var sight := 13.0 if ranged else 7.0
	var enemy = priority_target if priority_target and _flat_to(priority_target.global_position).length() < sight else _nearest_enemy(sight)
	if enemy:
		var to := _flat_to(enemy.global_position)
		var in_range: bool = to.length() <= s.range * 0.9
		if not plan.attack:
			plan.aim = to.normalized()
			plan.attack = in_range
		if not plan.has("ability"):
			var pick := _bot_pick_ability(to.length())
			if pick >= 0:
				plan.ability = pick
				# A Mage's Blink is an escape: away from the enemy.
				plan.aim = -to.normalized() if (role == Role.MAGE and pick == 1) else to.normalized()
		# Wall archers hold their post: shoot what they can reach, chase nobody.
		if holding_wall:
			plan.move = _steer_to(next)
			return plan
		# Raiders keep running for the monarch, hitting whoever is in reach,
		# and only stop to fight someone right on top of them.
		var raiding: bool = gearing_up or (bot_job == "attack" and mine.state == Monarch.State.HOME)
		if raiding and to.length() > 3.0:
			plan.move = _steer_to(next)
			return plan
		if in_range:
			# Shooters on the ground keep a little distance.
			if ranged and on_ground and to.length() < 5.0:
				plan.move = -to.normalized() * 0.6
			return plan
		plan.move = _steer_to(game.route_point(global_position, enemy.global_position))
		return plan

	plan.move = _steer_to(next)
	return plan
