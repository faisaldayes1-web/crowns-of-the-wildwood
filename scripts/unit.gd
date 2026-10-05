extends CharacterBody3D
## One soldier on either team, driven by the local player or by a simple bot brain.

const Monarch = preload("res://scripts/monarch.gd")

# Everyone starts as a plain Elf or Human (BASE) and transforms by stepping
# onto a class station in their castle. Dying resets you to BASE.
enum Role { BASE, WORKER, MELEE, RANGED }

const ROLE_STATS := {
	Role.BASE: {"hp": 60.0, "speed": 1.0, "damage": 6.0, "range": 1.6, "cooldown": 0.7, "hat": Color.WHITE,
		"build": Vector3(0.9, 0.9, 0.9)},
	Role.WORKER: {"hp": 80.0, "speed": 1.1, "damage": 10.0, "range": 1.8, "cooldown": 0.6, "hat": Color(0.55, 0.35, 0.2),
		"build": Vector3(1.15, 0.9, 1.15)},
	Role.MELEE: {"hp": 150.0, "speed": 1.0, "damage": 25.0, "range": 2.2, "cooldown": 0.7, "hat": Color(0.8, 0.8, 0.85),
		"build": Vector3(1.3, 1.12, 1.3)},
	Role.RANGED: {"hp": 90.0, "speed": 0.95, "damage": 18.0, "range": 14.0, "cooldown": 1.0, "hat": Color(0.95, 0.75, 0.2),
		"build": Vector3(0.85, 1.08, 0.85)},
}

# Elves are fast and fragile, humans are slower and tougher.
const FACTIONS := [
	{"name": "Elves", "color": Color(0.3, 0.75, 0.35), "speed": 7.0, "hp_mult": 0.95,
		"roles": ["Elf", "Grovekeeper", "Bladedancer", "Ranger"]},
	{"name": "Humans", "color": Color(0.3, 0.45, 0.9), "speed": 6.0, "hp_mult": 1.15,
		"roles": ["Human", "Laborer", "Knight", "Crossbowman"]},
]

const CARRY_SPEED_MULT := 0.75
const RESPAWN_TIME := 7.0
const GRAVITY := 20.0
const PICKUP_RANGE := 1.8

var game
var team := 0
var role := Role.BASE
var is_player := false
var hp := 100.0
var max_hp := 100.0
var dead := false
var respawn_timer := 0.0
var attack_timer := 0.0
var flash_timer := 0.0
var carrying = null
var spawn_point := Vector3.ZERO
var facing := Vector3(1, 0, 0)

# Bots: "attack" raids the enemy castle, "defend" guards the home throne.
var bot_job := "attack"
var bot_class := Role.MELEE  # the class this bot walks to a station to pick up
var bot_offset := Vector3.ZERO
var stuck_time := 0.0

var shape: CollisionShape3D
var build: Node3D  # body, nose, hat and gear; scaled per class
var gear: MeshInstance3D
var body_mat: StandardMaterial3D
var hat: MeshInstance3D
var hat_mat: StandardMaterial3D
var label: Label3D


func setup(p_game, p_team: int, p_role: int, p_is_player: bool, p_spawn: Vector3) -> void:
	game = p_game
	team = p_team
	is_player = p_is_player
	spawn_point = p_spawn
	position = p_spawn
	facing = Vector3(1, 0, 0) if team == 0 else Vector3(-1, 0, 0)
	rotation.y = atan2(-facing.x, -facing.z)
	bot_offset = Vector3(randf_range(-2.5, 2.5), 0, randf_range(-2.5, 2.5))
	collision_layer = 2
	collision_mask = 1

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
	body_mat.albedo_color = FACTIONS[team].color
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
	hat.position.y = 1.75
	hat_mat = StandardMaterial3D.new()
	hat.material_override = hat_mat
	build.add_child(hat)

	gear = MeshInstance3D.new()
	var gear_mat := StandardMaterial3D.new()
	gear_mat.albedo_color = Color(0.35, 0.3, 0.28)
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

	label = Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 28
	label.pixel_size = 0.012
	label.outline_size = 8
	label.position.y = 2.4
	add_child(label)

	set_role(p_role)


func role_name() -> String:
	return FACTIONS[team].roles[role]


func set_role(new_role: int) -> void:
	role = new_role
	max_hp = ROLE_STATS[role].hp * FACTIONS[team].hp_mult
	hp = max_hp
	build.scale = ROLE_STATS[role].build
	hat.visible = role != Role.BASE
	gear.visible = role != Role.BASE
	match role:
		Role.WORKER:
			var cap := BoxMesh.new()
			cap.size = Vector3(0.55, 0.2, 0.55)
			hat.mesh = cap
			# A hammer.
			var hammer := BoxMesh.new()
			hammer.size = Vector3(0.12, 0.7, 0.12)
			gear.mesh = hammer
			gear.position = Vector3(0.55, 0.9, -0.2)
		Role.MELEE:
			var helm := SphereMesh.new()
			helm.radius = 0.32
			helm.height = 0.4
			hat.mesh = helm
			# A shield.
			var shield := BoxMesh.new()
			shield.size = Vector3(0.12, 0.8, 0.6)
			gear.mesh = shield
			gear.position = Vector3(-0.5, 0.9, -0.1)
		Role.RANGED:
			var hood := CylinderMesh.new()
			hood.top_radius = 0.0
			hood.bottom_radius = 0.32
			hood.height = 0.6
			hat.mesh = hood
			# A bow.
			var bow := BoxMesh.new()
			bow.size = Vector3(0.08, 1.0, 0.08)
			gear.mesh = bow
			gear.position = Vector3(0.45, 1.0, -0.3)
	hat_mat.albedo_color = ROLE_STATS[role].hat
	_update_label()


func _update_label() -> void:
	var tag := "YOU · " if is_player else ""
	label.text = "%s%s  %d" % [tag, role_name(), ceili(hp)]
	label.modulate = Color(1, 1, 0.6) if is_player else Color(1, 1, 1)


func take_damage(amount: float) -> void:
	if dead:
		return
	hp -= amount
	flash_timer = 0.12
	if hp <= 0.0:
		_die()
	else:
		_update_label()


func _die() -> void:
	dead = true
	if carrying:
		game.drop_monarch(self)
	visible = false
	shape.disabled = true
	respawn_timer = RESPAWN_TIME
	velocity = Vector3.ZERO


func _respawn() -> void:
	dead = false
	set_role(Role.BASE)
	position = spawn_point + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5))
	visible = true
	shape.disabled = false
	_update_label()


func _physics_process(delta: float) -> void:
	if game == null or not game.playing:
		return
	if dead:
		respawn_timer -= delta
		if respawn_timer <= 0.0:
			_respawn()
		return

	attack_timer = maxf(attack_timer - delta, 0.0)
	if flash_timer > 0.0:
		flash_timer -= delta
		body_mat.albedo_color = Color(1, 0.3, 0.3) if flash_timer > 0.0 else FACTIONS[team].color

	var move := Vector3.ZERO
	var wants_attack := false
	var aim := facing
	if is_player:
		var stick := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		move = Vector3(stick.x, 0, stick.y)
		wants_attack = Input.is_action_pressed("attack")
		if Input.is_action_just_pressed("interact"):
			game.try_interact(self)
	else:
		var plan := _bot_think()
		move = plan.move
		wants_attack = plan.attack
		aim = plan.aim

	var speed: float = FACTIONS[team].speed * ROLE_STATS[role].speed
	if carrying:
		speed *= CARRY_SPEED_MULT
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
	position.x = clampf(position.x, -game.map_half.x, game.map_half.x)
	position.z = clampf(position.z, -game.map_half.y, game.map_half.y)

	# Bots that bump into a tree or wall sidestep around it.
	if not is_player and move.length() > 0.1:
		var real := get_real_velocity()
		real.y = 0.0
		stuck_time = stuck_time + delta if real.length() < speed * 0.3 else 0.0

	if wants_attack and carrying == null and attack_timer <= 0.0:
		_attack(facing if is_player else aim)


func _attack(aim: Vector3) -> void:
	var stats: Dictionary = ROLE_STATS[role]
	attack_timer = stats.cooldown
	aim.y = 0.0
	aim = aim.normalized()
	if role == Role.RANGED:
		game.spawn_arrow(self, aim)
		return
	game.spawn_swing(self, aim)
	for other in game.units:
		if other.team == team or other.dead:
			continue
		var to: Vector3 = other.global_position - global_position
		to.y = 0.0
		var dist := to.length()
		if dist <= stats.range and (dist < 0.8 or aim.dot(to / dist) > 0.3):
			other.take_damage(stats.damage)


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
		# Slide sideways around whatever is in the way.
		dir = (dir + dir.cross(Vector3.UP) * (1.0 if bot_offset.x > 0.0 else -1.0) * 1.5).normalized()
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


func _bot_think() -> Dictionary:
	var plan := {"move": Vector3.ZERO, "attack": false, "aim": facing}
	var mine = game.monarchs[team]
	var theirs = game.monarchs[1 - team]

	# Carrying the enemy monarch: run straight home, no fighting.
	if carrying:
		plan.move = _steer_to(game.thrones[team])
		return plan

	# Grab the enemy monarch whenever it's within reach.
	if theirs.state != Monarch.State.CARRIED and _flat_to(theirs.global_position).length() < PICKUP_RANGE:
		game.try_interact(self)

	# Choose where to go.
	var goal: Vector3
	var priority_target = null
	# Fresh spawns always grab their class first; the stations sit next to the spawn.
	var gearing_up: bool = role == Role.BASE and bot_class != Role.BASE
	if gearing_up:
		goal = game.station_position(team, bot_class)
	elif mine.state == Monarch.State.CARRIED:
		priority_target = mine.carrier
		goal = mine.carrier.global_position
	elif mine.state == Monarch.State.DROPPED:
		goal = mine.global_position
	elif theirs.state == Monarch.State.CARRIED:
		goal = theirs.carrier.global_position + bot_offset  # escort our carrier
	elif bot_job == "attack":
		goal = theirs.global_position
	else:
		goal = game.thrones[team] + Vector3(6.0 if team == 0 else -6.0, 0, 0) + bot_offset

	# Fight anyone nearby, the enemy carrier first.
	var sight := 13.0 if role == Role.RANGED else 7.0
	var enemy = priority_target if priority_target and _flat_to(priority_target.global_position).length() < sight else _nearest_enemy(sight)
	if enemy:
		var to := _flat_to(enemy.global_position)
		var in_range: bool = to.length() <= ROLE_STATS[role].range * 0.9
		plan.aim = to.normalized()
		plan.attack = in_range
		# Raiders keep running for the monarch, hitting whoever is in reach,
		# and only stop to fight someone right on top of them.
		var raiding: bool = gearing_up or (bot_job == "attack" and mine.state == Monarch.State.HOME)
		if raiding and to.length() > 3.0:
			plan.move = _steer_to(goal)
			return plan
		if in_range:
			# Archers keep a little distance.
			if role == Role.RANGED and to.length() < 5.0:
				plan.move = -to.normalized() * 0.6
			return plan
		plan.move = _steer_to(enemy.global_position)
		return plan

	plan.move = _steer_to(goal)
	return plan
