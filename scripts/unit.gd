extends CharacterBody3D
## One soldier on either team, driven by the local player or by a simple bot brain.
## Everyone starts as a plain Elf or Human and transforms by stepping onto a
## class station in their castle. Dying resets you to the plain form.
## All class numbers live in stats.gd.

const Stats = preload("res://scripts/stats.gd")
const Monarch = preload("res://scripts/monarch.gd")
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
var dodge_timer := 0.0      # time left in the current dash
var dodge_cooldown := 0.0   # time until the next dodge is ready
var dodge_dir := Vector3.ZERO
var carrying = null
var spawn_point := Vector3.ZERO
var facing := Vector3(1, 0, 0)

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
var body_mat: StandardMaterial3D
var hat: MeshInstance3D
var hat_mat: StandardMaterial3D
var gear: MeshInstance3D
var gear_mat: StandardMaterial3D
var overhead: Node3D
var label: Label3D
var heart_mats: Array[StandardMaterial3D] = []


func setup(p_game, p_team: int, p_is_player: bool, p_spawn: Vector3) -> void:
	game = p_game
	team = p_team
	is_player = p_is_player
	spawn_point = p_spawn
	position = p_spawn
	facing = Vector3(1, 0, 0) if team == 0 else Vector3(-1, 0, 0)
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

	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.4
	body_mesh.height = 1.6
	body.mesh = body_mesh
	body.position.y = 0.8
	body_mat = StandardMaterial3D.new()
	body.material_override = body_mat
	build.add_child(body)

	# A small nose so you can tell which way someone faces.
	var nose := MeshInstance3D.new()
	var nose_mesh := BoxMesh.new()
	nose_mesh.size = Vector3(0.2, 0.2, 0.35)
	nose.mesh = nose_mesh
	nose.position = Vector3(0, 1.2, -0.45)
	nose.material_override = body_mat
	build.add_child(nose)

	hat = MeshInstance3D.new()
	hat_mat = StandardMaterial3D.new()
	hat.material_override = hat_mat
	build.add_child(hat)

	gear = MeshInstance3D.new()
	gear_mat = StandardMaterial3D.new()
	gear.material_override = gear_mat
	build.add_child(gear)

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


func set_role(new_role: int) -> void:
	role = new_role
	hearts = Stats.MAX_HEARTS
	energy = energy_max()
	var s := stats()
	build.scale = s.build
	body_mat.albedo_color = Stats.FACTIONS[team].color
	hat.visible = role != Role.BASE
	gear.visible = role != Role.BASE
	hat_mat.albedo_color = s.color
	gear_mat.albedo_color = Color(0.4, 0.3, 0.2)
	match role:
		Role.KNIGHT:
			var helm := SphereMesh.new()
			helm.radius = 0.32
			helm.height = 0.4
			hat.mesh = helm
			hat.position = Vector3(0, 1.72, 0)
			var shield := BoxMesh.new()
			shield.size = Vector3(0.12, 0.8, 0.6)
			gear.mesh = shield
			gear.position = Vector3(-0.5, 0.9, -0.1)
			gear_mat.albedo_color = Stats.FACTIONS[team].color.darkened(0.3)
		Role.RANGER:
			var hood := CylinderMesh.new()
			hood.top_radius = 0.0
			hood.bottom_radius = 0.34
			hood.height = 0.5
			hat.mesh = hood
			hat.position = Vector3(0, 1.75, 0)
			var bow := BoxMesh.new()
			bow.size = Vector3(0.08, 1.0, 0.08)
			gear.mesh = bow
			gear.position = Vector3(0.45, 1.0, -0.3)
		Role.MAGE:
			var wizard := CylinderMesh.new()
			wizard.top_radius = 0.0
			wizard.bottom_radius = 0.42
			wizard.height = 0.9
			hat.mesh = wizard
			hat.position = Vector3(0, 1.95, 0)
			var staff := BoxMesh.new()
			staff.size = Vector3(0.08, 1.6, 0.08)
			gear.mesh = staff
			gear.position = Vector3(0.5, 0.9, -0.2)
			gear_mat.albedo_color = Color(0.5, 0.35, 0.9)
		Role.HEALER:
			var hood := SphereMesh.new()
			hood.radius = 0.36
			hood.height = 0.55
			hat.mesh = hood
			hat.position = Vector3(0, 1.62, 0.05)
			var staff := BoxMesh.new()
			staff.size = Vector3(0.08, 1.5, 0.08)
			gear.mesh = staff
			gear.position = Vector3(0.5, 0.85, -0.2)
			gear_mat.albedo_color = Color(0.2, 0.85, 0.4)
	_refresh_overhead()


func _refresh_overhead() -> void:
	var tag := "YOU · " if is_player else ""
	label.text = tag + role_name()
	label.modulate = Color(1, 1, 0.6) if is_player else Color(1, 1, 1)
	for i in heart_mats.size():
		heart_mats[i].albedo_color = Color(0.95, 0.15, 0.2) if i < hearts else Color(0.2, 0.2, 0.2)


func take_damage(amount: int) -> void:
	if dead or dodge_timer > 0.0:
		return  # mid-dodge: untouchable
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
	return dodge_cooldown <= 0.0 and not dead and carrying == null


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


func _die() -> void:
	dead = true
	hearts = 0
	if carrying:
		game.drop_monarch(self)
	visible = false
	shape.disabled = true
	respawn_timer = Stats.RESPAWN_TIME
	velocity = Vector3.ZERO


func _respawn() -> void:
	dead = false
	set_role(Role.BASE)
	position = spawn_point + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5))
	visible = true
	shape.disabled = false


func _process(_delta: float) -> void:
	if overhead:
		overhead.global_position = global_position + Vector3(0, 2.3 * build.scale.y + 0.3, 0)


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
	if flash_timer > 0.0:
		flash_timer -= delta
		body_mat.albedo_color = Color(1, 0.3, 0.3) if flash_timer > 0.0 else Stats.FACTIONS[team].color

	var speed: float = Stats.FACTIONS[team].speed * stats().speed
	if carrying:
		speed *= Stats.CARRY_SPEED_MULT

	# Mid-dash: fly in the dodge direction and ignore everything else.
	if dodge_timer > 0.0:
		dodge_timer -= delta
		velocity.x = dodge_dir.x * speed * Stats.DODGE_SPEED_MULT
		velocity.z = dodge_dir.z * speed * Stats.DODGE_SPEED_MULT
		velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
		move_and_slide()
		_clamp_to_map()
		return

	var move := Vector3.ZERO
	var wants_attack := false
	var aim := facing
	if is_player:
		var stick := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		move = Vector3(stick.x, 0, stick.y)
		wants_attack = Input.is_action_pressed("attack")
		if Input.is_action_just_pressed("interact"):
			game.try_interact(self)
		if Input.is_action_just_pressed("dodge"):
			try_dodge(move)
			if dodge_timer > 0.0:
				return
	else:
		var plan := _bot_think()
		move = plan.move
		wants_attack = plan.attack
		aim = plan.aim

	if move.length() > 0.05:
		facing = move.normalized()
		rotation.y = atan2(-facing.x, -facing.z)
	if not is_player and wants_attack and aim.length() > 0.05:
		facing = aim.normalized()
		rotation.y = atan2(-facing.x, -facing.z)

	velocity.x = move.x * speed
	velocity.z = move.z * speed
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()
	_clamp_to_map()

	# Bots that bump into a tree or wall sidestep around it.
	sidestep_timer = maxf(sidestep_timer - delta, 0.0)
	if not is_player and move.length() > 0.1:
		var real := get_real_velocity()
		real.y = 0.0
		stuck_time = stuck_time + delta if real.length() < speed * 0.3 else 0.0

	if wants_attack and carrying == null and attack_timer <= 0.0:
		_attack(facing if is_player else aim)


func _clamp_to_map() -> void:
	position.x = clampf(position.x, -game.map_half.x, game.map_half.x)
	position.z = clampf(position.z, -game.map_half.y, game.map_half.y)


# --- Combat ----------------------------------------------------------------

func _injured_allies_near() -> Array:
	var hurt := []
	for other in game.units:
		if other.team == team and not other.dead and other.hearts < Stats.MAX_HEARTS \
				and _flat_to(other.global_position).length() <= stats().get("heal_radius", 0.0):
			hurt.append(other)
	return hurt


func _attack(aim: Vector3) -> void:
	var s := stats()
	aim.y = 0.0
	aim = aim.normalized()
	var kind: String = s.attack
	if kind == "heal":
		var hurt := _injured_allies_near()
		if not hurt.is_empty() and energy >= s.cost:
			energy -= s.cost
			attack_timer = s.cooldown
			for ally in hurt:
				ally.heal(s.heal)
			game.spawn_burst(global_position + Vector3(0, 0.2, 0), s.heal_radius, Color(0.3, 1.0, 0.5))
			return
		kind = "melee"  # nobody to heal: bonk with the staff, free of mana
	elif energy < s.cost:
		return  # out of stamina or mana
	else:
		energy -= s.cost
	attack_timer = s.cooldown

	if kind == "arrow" or kind == "spell":
		game.spawn_projectile(self, aim)
		return
	game.spawn_swing(self, aim)
	for other in game.units:
		if other.team == team or other.dead:
			continue
		var to := _flat_to(other.global_position)
		var dist := to.length()
		# Swings reach people at your own height, not someone up on a wall.
		if dist <= s.range and absf(other.global_position.y - global_position.y) < 1.5 \
				and (dist < 0.8 or aim.dot(to / dist) > 0.3):
			other.take_damage(s.damage)
	# Swings from the ground also chip away at the enemy door.
	var gate = game.gates[1 - team]
	var gx: float = gate.position.x
	if gate.is_intact() and global_position.y < 1.0 and absf(global_position.x - gx) < s.range + 0.4 \
			and absf(global_position.z) < Stats.DOOR_HALF + 0.5 and aim.x * signf(gx - global_position.x) > 0.3:
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
	if carrying:
		goal = game.thrones[team]
	elif gearing_up:
		goal = game.station_position(team, bot_class)
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

	# Healers patch up anyone hurt nearby before doing anything else.
	if s.attack == "heal" and energy >= s.cost and not _injured_allies_near().is_empty():
		plan.attack = true

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
