extends CharacterBody3D
## One soldier on either team, driven by the local player or by a simple bot brain.
## Everyone starts as a plain Elf or Human and transforms by stepping onto a
## class station in their castle. Dying resets you to the plain form and
## wipes the experience you earned this life. All numbers live in stats.gd.

const Stats = preload("res://scripts/stats.gd")
const Monarch = preload("res://scripts/monarch.gd")
const CharacterModel = preload("res://scripts/character_model.gd")
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
var blocking := false       # shield up (hold right click): blocks hits from the front
var root_timer := 0.0       # snared: can't move
var haste_timer := 0.0      # blessed: faster
var knockback := Vector3.ZERO
var carrying = null
var spawn_point := Vector3.ZERO
var facing := Vector3(1, 0, 0)
var kills := 0

# Experience this life. Levels give rank points; ranks are kept per class so
# switching class at a station starts that class's ranks fresh.
var xp := 0
var level := 1
var points := 0
var ranks := {}             # role -> [attack, q, e, vigor]

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
var bot_block_timer := 0.0
var stuck_time := 0.0
var sidestep_timer := 0.0   # while > 0 the bot commits to walking around an obstacle
var sidestep_sign := 1.0

var shape: CollisionShape3D
var build: Node3D
var model                     # character_model.gd: the animated KayKit model
var flash_mats: Array = []    # materials that turn red when hit
var death_timer := 0.0        # the body stays for a moment after dying
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
	collision_mask = 1 | 16 | (8 if team == 0 else 4)  # world, river banks, enemy door

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
	var guard_mesh := SphereMesh.new()
	guard_mesh.radius = 1.15
	guard_mesh.height = 2.3
	guard_mesh.radial_segments = 16
	guard_mesh.rings = 8
	guard_ring.mesh = guard_mesh
	guard_ring.position.y = 1.0
	var guard_mat := StandardMaterial3D.new()
	guard_mat.albedo_color = Color(0.5, 0.75, 1.0, 0.3)
	guard_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	guard_mat.emission_enabled = true
	guard_mat.emission = Color(0.4, 0.6, 1.0)
	guard_mat.emission_energy_multiplier = 0.8
	guard_mat.rim_enabled = true
	guard_mat.rim = 1.0
	guard_mat.rim_tint = 0.2
	guard_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
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
	var base := Stats.MANA_MAX if energy_kind() == "mana" else Stats.STAMINA_MAX
	return base + Stats.VIGOR_ENERGY * rank(3)


func can_block() -> bool:
	return stats().get("block", false)


func abilities() -> Array:
	return stats().abilities


func set_role(new_role: int) -> void:
	role = new_role
	hearts = Stats.MAX_HEARTS
	energy = energy_max()
	ability_timers = [0.0, 0.0]
	blocking = false
	if model == null:
		model = CharacterModel.new()
		build.add_child(model)
	model.setup(team, role)
	flash_mats = model.flash_mats
	_refresh_overhead()


func _refresh_overhead() -> void:
	var tag := "YOU · " if is_player else ""
	var lvl := ("  ★%d" % level) if level > 1 else ""
	label.text = tag + role_name() + lvl
	label.modulate = Color(1, 1, 0.6) if is_player else Color(1, 1, 1)
	for i in heart_mats.size():
		heart_mats[i].albedo_color = Color(0.95, 0.15, 0.2) if i < hearts else Color(0.2, 0.2, 0.2)


# --- Experience and ranks ----------------------------------------------------

func rank(track: int) -> int:
	## 0 = attack, 1 = Q, 2 = E, 3 = vigor.
	if not ranks.has(role):
		return 0
	return ranks[role][track]


func track_available(track: int) -> bool:
	return track == 0 or track == 3 or track - 1 < abilities().size()


func spend_point(track: int) -> bool:
	if points <= 0 or dead or not track_available(track) or rank(track) >= Stats.MAX_RANK:
		return false
	if not ranks.has(role):
		ranks[role] = [0, 0, 0, 0]
	ranks[role][track] += 1
	points -= 1
	if track == 3:
		energy = minf(energy + Stats.VIGOR_ENERGY, energy_max())
	game.spawn_ring(global_position, 1.6, Color(1.0, 0.85, 0.3), 0.5)
	game.spawn_splash(global_position + Vector3(0, 1.0, 0), Color(1.0, 0.85, 0.3), 14, 3.0, 0.5)
	game.spawn_flash(global_position, Color(1.0, 0.85, 0.3), 2.0, 0.3)
	if is_player:
		game.spawn_popup(global_position + Vector3(0, 2.2, 0), "%s rank %d" % [track_name(track), rank(track)], Color(1, 0.9, 0.5))
	return true


func track_name(track: int) -> String:
	match track:
		0: return stats().attack_name
		1, 2: return abilities()[track - 1].name if track - 1 < abilities().size() else "-"
	return "Vigor"


func gain_xp(amount: int) -> void:
	if dead or amount <= 0:
		return
	xp += amount
	var new_level := Stats.level_for_xp(xp)
	if new_level > level:
		points += new_level - level
		level = new_level
		_refresh_overhead()
		game.spawn_pillar(global_position, Color(1.0, 0.9, 0.4), 4.5, 1.0)
		game.spawn_ring(global_position, 2.2, Color(1.0, 0.9, 0.4), 0.6)
		game.spawn_splash(global_position + Vector3(0, 0.6, 0), Color(1.0, 0.9, 0.4), 24, 4.5, 0.9, true)
		game.spawn_popup(global_position + Vector3(0, 2.4, 0), "LEVEL %d" % level, Color(1, 0.9, 0.4))
		if is_player:
			game.announce("Level %d! Press Tab to rank up an ability." % level)
		else:
			_bot_spend()


func _bot_spend() -> void:
	# Bots like their attack first, then Q, E, then Vigor, and keep going round.
	var order := [0, 1, 2, 3]
	var guard := 0
	while points > 0 and guard < 16:
		guard += 1
		for t in order:
			if points > 0 and track_available(t) and rank(t) < Stats.MAX_RANK:
				spend_point(t)
				break
		var any_left := false
		for t in order:
			any_left = any_left or (track_available(t) and rank(t) < Stats.MAX_RANK)
		if not any_left:
			break


func ranked(a: Dictionary, track: int) -> Dictionary:
	## A copy of an attack or ability with this unit's rank applied.
	var r := rank(track)
	if r == 0:
		return a
	var out := a.duplicate()
	out.cooldown = a.cooldown * (1.0 - Stats.RANK_COOLDOWN_CUT * r)
	out.cost = a.cost * (1.0 - Stats.RANK_COST_CUT * r)
	if r >= 2:
		for key in ["distance", "radius", "duration", "haste", "splash", "heal_radius", "root", "range"]:
			if a.has(key):
				out[key] = a[key] * (1.0 + Stats.RANK_EFFECT_BOOST)
		if a.has("arrows"):
			out.arrows = a.arrows + 2
	if r >= 3:
		if a.has("heal"):
			out.heal = a.heal + 1
		if a.has("damage") and a.get("kind", "") != "bash":
			out.damage = a.damage + 1
		if a.has("gate_damage"):
			out.gate_damage = a.gate_damage + 1
	return out


func attack_stats() -> Dictionary:
	return ranked(stats(), 0)


func ability(i: int) -> Dictionary:
	return ranked(abilities()[i], i + 1)


func vigor_speed() -> float:
	return 1.0 + Stats.VIGOR_SPEED * rank(3)


# --- Damage ------------------------------------------------------------------

func take_damage(amount: int, attacker = null, from: Vector3 = Vector3.INF, knock: float = 0.0) -> bool:
	## Returns true if the hit landed. `from` is where the hit came from, for
	## knockback and for the shield: a raised shield stops hits from the front.
	if dead or dodge_timer > 0.0 or guard_timer > 0.0:
		return false  # mid-dodge or behind the shield wall: untouchable
	var push := Vector3.ZERO
	if from.is_finite():
		push = global_position - from
		push.y = 0.0
		push = push.normalized() if push.length() > 0.05 else facing
	if blocking and from.is_finite() and facing.dot(-push) > 0.1:
		# Blocked: no damage, but it costs stamina and shoves you a little.
		energy -= Stats.BLOCK_COST
		knockback = push * knock * 0.5
		game.spawn_splash(global_position + facing * 0.6 + Vector3(0, 1.0, 0), Color(0.9, 0.95, 1.0), 10, 4.0, 0.3)
		game.spawn_popup(global_position + Vector3(0, 2.0, 0), "BLOCKED", Color(0.75, 0.85, 1.0))
		if energy <= 0.0:
			energy = 0.0
			blocking = false
			model.release()
		return false
	hearts -= amount
	flash_timer = 0.15
	knockback = push * knock
	if attacker and attacker != self:
		attacker.gain_xp(Stats.XP_HIT * amount)
	game.spawn_splash(global_position + Vector3(0, 1.0, 0), Color(1.0, 0.3, 0.25), 10, 3.5, 0.4)
	game.spawn_popup(global_position + Vector3(0, 2.0, 0), "-%d" % amount, Color(1, 0.35, 0.3))
	if is_player:
		game.shake(0.35)
	if hearts <= 0:
		if attacker and attacker != self:
			attacker.gain_xp(Stats.XP_KILL)
			attacker.kills += 1
		_die()
		return true
	_refresh_overhead()
	if model and model._now() >= model.busy_until:
		model.play_once("Hit_A", 1.5)
	# Bots roll sideways away from whatever just hit them, half the time.
	if not is_player and dodge_ready() and randf() < 0.5:
		try_dodge(facing.cross(Vector3.UP) * (1.0 if randf() < 0.5 else -1.0))
	return true


func heal(amount: int, healer = null) -> int:
	if dead:
		return 0
	var before := hearts
	hearts = mini(hearts + amount, Stats.MAX_HEARTS)
	var healed := hearts - before
	if healed > 0:
		_refresh_overhead()
		game.spawn_splash(global_position + Vector3(0, 0.4, 0), Color(0.4, 1.0, 0.5), 12, 2.0, 0.9, true)
		game.spawn_popup(global_position + Vector3(0, 2.0, 0), "+%d" % healed, Color(0.4, 1.0, 0.5))
		if healer and healer != self:
			healer.gain_xp(Stats.XP_HEAL * healed)
	return healed


func dodge_ready() -> bool:
	return dodge_cooldown <= 0.0 and not dead and carrying == null and root_timer <= 0.0 \
		and energy >= Stats.DODGE_COST


func try_dodge(dir: Vector3) -> void:
	if not dodge_ready():
		return
	dir.y = 0.0
	dodge_dir = dir.normalized() if dir.length() > 0.05 else facing
	facing = dodge_dir
	rotation.y = atan2(-facing.x, -facing.z)
	dodge_timer = Stats.DODGE_TIME
	dodge_cooldown = Stats.DODGE_COOLDOWN
	energy -= Stats.DODGE_COST
	blocking = false
	model.play_once("Dodge_Forward", 2.2)
	game.spawn_splash(global_position + Vector3(0, 0.2, 0), Color(0.9, 0.85, 0.7), 10, 2.5, 0.5)
	game.spawn_ring(global_position, 1.0, Color(1, 1, 1), 0.3, 0.2)


func ability_ready(i: int) -> bool:
	return i < abilities().size() and ability_timers[i] <= 0.0 and not dead and carrying == null \
		and energy >= ability(i).cost


func use_ability(i: int, dir: Vector3) -> void:
	if not ability_ready(i):
		return
	var a: Dictionary = ability(i)
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.05 else facing
	energy -= a.cost
	ability_timers[i] = a.cooldown
	facing = dir
	blocking = false
	match a.kind:
		"bash": model.play_once("1H_Melee_Attack_Stab", 1.6)
		"guard": model.hold("Blocking")
		"volley": model.play_once("2H_Ranged_Shoot", 1.2)
		"trap": model.play_once("Interact", 1.5)
		"fireball": model.play_once("Spellcast_Long", 1.4)
		"blink": model.play_once("Spellcast_Raise", 2.0)
		"blessing": model.play_once("Spellcast_Long", 1.2)
		"smite": model.play_once("Spellcast_Shoot", 1.6)
	rotation.y = atan2(-facing.x, -facing.z)
	match a.kind:
		"bash":
			# A short dash that hits and shoves everyone in its path.
			dodge_dir = dir
			bash_timer = 0.2
			bash_speed = a.distance / 0.2
			bash_hit = []
			game.spawn_splash(global_position + Vector3(0, 0.3, 0), Color(0.8, 0.85, 1.0), 12, 3.0, 0.4)
			game.spawn_ring(global_position, 1.8, Color(0.7, 0.8, 1.0), 0.35)
		"guard":
			guard_timer = a.duration
			guard_ring.visible = true
			game.spawn_ring(global_position, 2.0, Color(0.5, 0.75, 1.0), 0.4)
			game.spawn_flash(global_position, Color(0.5, 0.75, 1.0), 2.0, 0.3)
		"volley":
			for k in a.arrows:
				var ang: float = deg_to_rad(a.spread) * (float(k) / (a.arrows - 1) - 0.5)
				game.spawn_shot(self, dir.rotated(Vector3.UP, ang),
					{"damage": a.damage, "gate_damage": 1, "range": a.range, "shot_speed": a.shot_speed}, Color(0.95, 0.9, 0.7))
			game.spawn_splash(global_position + dir * 0.8 + Vector3(0, 1.1, 0), Color(0.95, 0.9, 0.7), 8, 3.0, 0.25)
			_recoil(dir, 3.0)
		"trap":
			game.spawn_trap(self, global_position + dir * 1.5, a)
		"fireball":
			game.spawn_shot(self, dir, {"damage": a.damage, "gate_damage": 4, "range": a.range,
				"splash": a.splash, "shot_speed": a.shot_speed, "fire": true}, Color(1.0, 0.5, 0.1))
			game.spawn_flash(global_position + dir, Color(1.0, 0.55, 0.15), 3.0, 0.3)
			_recoil(dir, 3.5)
		"blink":
			var from := global_position + Vector3(0, 0.9, 0)
			var to: Vector3 = from + dir * a.distance
			var ray := PhysicsRayQueryParameters3D.create(from, to, collision_mask)
			var hit := get_world_3d().direct_space_state.intersect_ray(ray)
			if hit:
				to = hit.position - dir * 0.8
			game.spawn_splash(global_position + Vector3(0, 1.0, 0), Color(0.7, 0.45, 1.0), 16, 3.0, 0.5)
			game.spawn_ring(global_position, 1.5, Color(0.7, 0.45, 1.0), 0.4)
			game.spawn_flash(global_position, Color(0.7, 0.45, 1.0), 2.5, 0.3)
			global_position = Vector3(to.x, global_position.y, to.z)
			game.spawn_splash(global_position + Vector3(0, 1.0, 0), Color(0.7, 0.45, 1.0), 16, 3.0, 0.5)
			game.spawn_ring(global_position, 1.5, Color(0.7, 0.45, 1.0), 0.4)
			game.spawn_flash(global_position, Color(0.7, 0.45, 1.0), 2.5, 0.3)
		"blessing":
			for ally in game.units:
				if ally.team == team and not ally.dead and _flat_to(ally.global_position).length() <= a.radius:
					ally.heal(a.heal, self)
					ally.haste_timer = a.haste
			game.spawn_ring(global_position, a.radius, Color(1.0, 0.95, 0.5), 0.7)
			game.spawn_pillar(global_position, Color(1.0, 0.95, 0.6), 4.0, 0.8)
			game.spawn_flash(global_position, Color(1.0, 0.95, 0.5), 4.0, 0.5)
			game.spawn_splash(global_position + Vector3(0, 0.5, 0), Color(1.0, 0.95, 0.5), 30, 5.0, 1.0, true)
		"smite":
			game.spawn_shot(self, dir, {"damage": a.damage, "gate_damage": 1, "range": a.range,
				"shot_speed": a.shot_speed, "holy": true}, Color(1.0, 0.95, 0.5))
			game.spawn_flash(global_position + dir, Color(1.0, 0.95, 0.5), 2.0, 0.25)
			_recoil(dir, 2.0)


func _recoil(dir: Vector3, amount: float) -> void:
	knockback -= dir * amount
	if is_player:
		game.shake(amount * 0.05)


func _die() -> void:
	dead = true
	hearts = 0
	if carrying:
		game.drop_monarch(self)
	shape.disabled = true
	death_timer = 1.1
	model.die()
	respawn_timer = Stats.RESPAWN_TIME
	velocity = Vector3.ZERO
	guard_timer = 0.0
	blocking = false
	guard_ring.visible = false
	# Experience is per life.
	xp = 0
	level = 1
	points = 0
	ranks = {}
	game.spawn_splash(global_position + Vector3(0, 0.8, 0), Color(0.3, 0.3, 0.35), 18, 3.0, 0.8)
	game.spawn_ring(global_position, 1.4, Color(0.6, 0.2, 0.2), 0.5)
	if aim_marker:
		aim_marker.visible = false
		aim_ring.visible = false


func _respawn() -> void:
	dead = false
	set_role(Role.BASE)
	position = spawn_point + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5))
	visible = true
	shape.disabled = false
	model.revive()
	if aim_marker:
		aim_marker.visible = true


func _process(_delta: float) -> void:
	_animate()
	if overhead:
		overhead.global_position = global_position + Vector3(0, (model.height if model else 1.8) + 0.35, 0)
	if aim_marker and not dead:
		aim_marker.global_position = global_position + aim * 1.1 + Vector3(0, 0.08, 0)
		aim_marker.rotation.y = atan2(-aim.x, -aim.z)
		aim_ring.visible = aim_mode == "mouse"
		aim_ring.global_position = Vector3(aim_point.x, global_position.y + 0.08, aim_point.z)


func _animate() -> void:
	if model == null or dead:
		return
	var planar := Vector2(velocity.x, velocity.z).length()
	model.update_locomotion(planar > 0.6)


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
		if death_timer > 0.0:
			death_timer -= delta
			if death_timer <= 0.0:
				visible = false
		if respawn_timer <= 0.0:
			_respawn()
		return

	var regen := Stats.MANA_REGEN if energy_kind() == "mana" else Stats.STAMINA_REGEN
	regen *= Stats.FACTIONS[team].regen_mult * (1.0 + Stats.VIGOR_REGEN * rank(3))
	if blocking:
		energy -= Stats.BLOCK_DRAIN * delta
	else:
		energy = minf(energy + regen * delta, energy_max())
	energy = maxf(energy, 0.0)
	attack_timer = maxf(attack_timer - delta, 0.0)
	dodge_cooldown = maxf(dodge_cooldown - delta, 0.0)
	for i in ability_timers.size():
		ability_timers[i] = maxf(ability_timers[i] - delta, 0.0)
	root_timer = maxf(root_timer - delta, 0.0)
	haste_timer = maxf(haste_timer - delta, 0.0)
	bot_block_timer = maxf(bot_block_timer - delta, 0.0)
	if guard_timer > 0.0:
		guard_timer -= delta
		if guard_timer <= 0.0:
			guard_ring.visible = false
			model.release()
	if flash_timer > 0.0:
		flash_timer -= delta
		for m in flash_mats:
			m.albedo_color = Color(1, 0.35, 0.35) if flash_timer > 0.0 else Color.WHITE

	var speed: float = Stats.FACTIONS[team].speed * stats().speed * vigor_speed()
	if carrying:
		speed *= Stats.CARRY_SPEED_MULT
	if haste_timer > 0.0:
		speed *= 1.3
	if guard_timer > 0.0:
		speed *= 0.5
	elif blocking:
		speed *= Stats.BLOCK_SPEED_MULT

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
					other.take_damage(ability(0).damage, self, global_position, 10.0)
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
	var wants_block := false
	var plan := {}
	if is_player:
		var stick := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		move = Vector3(stick.x, 0, stick.y)
		_update_player_aim(move)
		if not game.menu_blocks_input():
			wants_attack = Input.is_action_pressed("attack")
			wants_block = Input.is_action_pressed("block")
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
		wants_block = plan.get("block", false)
		aim = plan.aim

	# Shield up: hold to block. It drains stamina, slows you and stops attacks.
	var block_now: bool = wants_block and can_block() and energy > 0.0 and carrying == null and guard_timer <= 0.0
	if block_now != blocking:
		blocking = block_now
		if blocking:
			model.hold("Blocking")
		else:
			model.release()

	if root_timer > 0.0:
		move = Vector3.ZERO

	# The player always faces where they aim; bots face where they walk, or
	# whatever they are attacking.
	if is_player:
		facing = aim
	elif (wants_attack or blocking) and aim.length() > 0.05:
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

	if wants_attack and not blocking and carrying == null and attack_timer <= 0.0:
		_attack(aim)
	if plan.has("ability"):
		use_ability(plan.ability, plan.aim)


func _clamp_to_map() -> void:
	position.x = clampf(position.x, -game.map_half.x, game.map_half.x)
	position.z = clampf(position.z, -game.map_half.y, game.map_half.y)


# --- Combat ----------------------------------------------------------------

func _injured_allies_near(radius: float = -1.0) -> Array:
	var hurt := []
	var reach: float = attack_stats().get("heal_radius", 0.0) if radius < 0.0 else radius
	for other in game.units:
		if other.team == team and not other.dead and other.hearts < Stats.MAX_HEARTS \
				and _flat_to(other.global_position).length() <= reach:
			hurt.append(other)
	return hurt


func _attack(dir: Vector3) -> void:
	var s := attack_stats()
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.05 else facing
	var kind: String = s.attack
	if energy < s.cost:
		return  # out of stamina or mana
	if kind == "heal":
		# Mend: heal everyone hurt around you, including yourself. With nobody
		# to heal, the same mana fires a holy bolt at whatever you aim at.
		var hurt := _injured_allies_near()
		energy -= s.cost
		attack_timer = s.cooldown
		if not hurt.is_empty():
			for ally in hurt:
				ally.heal(s.heal, self)
			model.play_once("Spellcast_Raise", 1.6)
			game.spawn_ring(global_position, s.heal_radius, Color(0.3, 1.0, 0.5), 0.6)
			game.spawn_flash(global_position, Color(0.3, 1.0, 0.5), 2.0, 0.4)
			return
		model.play_once("Spellcast_Shoot", 1.6)
		game.spawn_shot(self, dir, {"damage": s.damage, "gate_damage": s.gate_damage, "range": s.range,
			"shot_speed": s.shot_speed, "holy": true}, Color(1.0, 0.95, 0.6))
		_recoil(dir, 1.5)
		return
	energy -= s.cost
	attack_timer = s.cooldown
	model.attack()

	if kind == "arrow":
		game.spawn_shot(self, dir, s, Color(0.95, 0.9, 0.7))
		_recoil(dir, 1.5)
		return
	if kind == "spell":
		game.spawn_shot(self, dir, s, Color(0.7, 0.45, 1.0))
		_recoil(dir, 2.0)
		return
	# Melee: a short lunge into the swing.
	knockback += dir * 2.5
	game.spawn_swing(self, dir)
	var landed := false
	for other in game.units:
		if other.team == team or other.dead:
			continue
		var to := _flat_to(other.global_position)
		var dist := to.length()
		# Swings reach people at your own height, not someone up on a wall.
		if dist <= s.range and absf(other.global_position.y - global_position.y) < 1.5 \
				and (dist < 0.8 or dir.dot(to / dist) > 0.3):
			landed = other.take_damage(s.damage, self, global_position, Stats.KNOCK_MELEE) or landed
	if landed and is_player:
		game.shake(0.12)
	# Swings from the ground also chip away at the enemy door.
	var gate = game.gates[1 - team]
	var gx: float = gate.position.x
	if gate.is_intact() and global_position.y < 1.0 and absf(global_position.x - gx) < s.range + 0.4 \
			and absf(global_position.z) < Stats.DOOR_HALF + 0.5 and dir.x * signf(gx - global_position.x) > 0.3:
		gate.take_hit(s.gate_damage, self)


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
	var s := attack_stats()
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
	if role == Role.HEALER and ability_ready(0) and _injured_allies_near(ability(0).radius).size() >= 2 \
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
		# Knights raise the shield while closing in on an archer or mage.
		if can_block() and not in_range:
			var their_attack: String = enemy.stats().attack
			if (their_attack == "arrow" or their_attack == "spell") and to.length() < 10.0 and randf() < 0.03:
				bot_block_timer = 1.0
		if bot_block_timer > 0.0 and not in_range:
			plan.block = true
			plan.aim = to.normalized()
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
