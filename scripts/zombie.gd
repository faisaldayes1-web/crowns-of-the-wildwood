extends Node3D
## A graveyard zombie on the Moonlit Wildwood (scripts/graveyard.gd drives it:
## gy.tick calls step() every frame, so it pauses with the match). It claws
## up out of its grave, shambles after the nearest unit it is hostile to,
## swipes for one heart, and crumbles back into the earth when it is killed
## or its time is up. `team` is the Cursed Bell's holder (-1: nobody, and it
## attacks everyone); its eyes, glow and the ring at its feet take that
## team's colour. Built from primitives, nothing licensed.
## claude-faisal/crowns-graveyard 2026-11-04.

const Stats = preload("res://scripts/stats.gd")

enum State { RISE, WALK, ATTACK, DIE }

const NEUTRAL_GLOW := Color(0.78, 0.45, 1.0)   # nobody holds the bell: a ghostly violet

var game
var gy
var id := 0
var team := -1
var hp := 3
var state := State.RISE
var t := 0.0              # seconds in the current state
var age := 0.0
var attack_cd := 0.6
var target = null
var retarget := 0.0
var wander := Vector3.INF
var wander_cd := 0.0
var home := Vector3.ZERO
var facing := Vector3.FORWARD
var puppet := false       # an online client's copy: placed from the host's snapshot
var net_to := Vector3.ZERO
var phase := 0.0
var stall := 0.0          # seconds walking without getting anywhere (tests read it)
var moved := 0.0          # metres walked (tests read it)
var dirt_at := 0.0
var _check_at := 0.0      # every 1.5 s: did we get anywhere?
var _check_pos := Vector3.INF
var _detour := Vector3.ZERO
var _detour_left := 0.0
var _detour_side := 1.0

var body: Node3D
var arm_l: Node3D
var arm_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var head: Node3D
var eye_mat: StandardMaterial3D
var ring_mat: StandardMaterial3D
var glow: OmniLight3D
var ring: MeshInstance3D
var sash_mat: StandardMaterial3D


func setup(p_game, p_gy, p_id: int, at: Vector3, p_team: int, p_puppet: bool = false) -> void:
	game = p_game
	gy = p_gy
	id = p_id
	home = at
	puppet = p_puppet
	position = Vector3(at.x, -1.9, at.z)
	net_to = at
	hp = Stats.GRAVEYARD.hp
	phase = fmod(float(p_id) * 1.37, TAU)
	rotation.y = phase
	facing = Vector3(sin(phase), 0, cos(phase))
	_build()
	set_team(p_team)


func hostile_to(unit_team: int) -> bool:
	return state != State.DIE and state != State.RISE and team != unit_team


func alive() -> bool:
	return state != State.DIE


func set_team(p_team: int) -> void:
	team = p_team
	var c: Color = NEUTRAL_GLOW if team < 0 else game._team_color(team).lightened(0.08)
	if eye_mat:
		eye_mat.albedo_color = c
		eye_mat.emission = c
	if ring_mat:
		ring_mat.albedo_color = Color(c.r, c.g, c.b, 0.75)
		ring_mat.emission = c
	if sash_mat:
		sash_mat.albedo_color = c
		sash_mat.emission = c
	if glow:
		glow.light_color = c


# --- Looks -----------------------------------------------------------------

func _mat(c: Color, rough: float = 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


func _part(parent: Node3D, mesh: Mesh, at: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = at
	mi.rotation = rot
	mi.material_override = mat
	parent.add_child(mi)
	return mi


func _box(x: float, y: float, z: float) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3(x, y, z)
	return b


func _build() -> void:
	## A hunched, cartoony corpse: mossy grey-green skin, a torn tunic and
	## trousers, long arms held out in front, glowing eyes.
	var skin := _mat(Color(0.64, 0.8, 0.52))
	var rag := _mat(Color(0.46, 0.4, 0.52))
	var cloth := _mat(Color(0.36, 0.3, 0.25))
	var dark := _mat(Color(0.12, 0.1, 0.1))
	body = Node3D.new()
	body.scale = Vector3.ONE * 1.15
	add_child(body)
	# Legs hinge at the hip so they can swing.
	for s in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(s * 0.16, 0.78, 0)
		body.add_child(hip)
		_part(hip, _box(0.2, 0.62, 0.22), Vector3(0, -0.33, 0), cloth)
		_part(hip, _box(0.22, 0.12, 0.3), Vector3(0, -0.72, 0.05), dark)
		if s < 0.0:
			leg_l = hip
		else:
			leg_r = hip
	var torso := Node3D.new()
	torso.position = Vector3(0, 0.8, 0)
	torso.rotation.x = 0.28   # the hunch
	body.add_child(torso)
	_part(torso, _box(0.5, 0.62, 0.3), Vector3(0, 0.32, 0), rag)
	_part(torso, _box(0.34, 0.16, 0.06), Vector3(0.06, 0.18, 0.16), skin, Vector3(0, 0, 0.3))   # skin through the tear
	_part(torso, _box(0.54, 0.08, 0.34), Vector3(0, 0.03, 0), cloth)   # belt of rope
	# A glowing shroud-sash across the chest in the bell holder's colour.
	sash_mat = StandardMaterial3D.new()
	sash_mat.emission_enabled = true
	sash_mat.emission_energy_multiplier = 1.6
	_part(torso, _box(0.14, 0.7, 0.04), Vector3(-0.02, 0.32, 0.165), sash_mat, Vector3(0, 0, 0.6))
	_part(torso, _box(0.14, 0.7, 0.04), Vector3(-0.02, 0.32, -0.165), sash_mat, Vector3(0, 0, -0.6))
	# Arms hinge at the shoulder, held out straight in front.
	for s in [-1.0, 1.0]:
		var sh := Node3D.new()
		sh.position = Vector3(s * 0.33, 0.56, 0)
		torso.add_child(sh)
		_part(sh, _box(0.15, 0.15, 0.62), Vector3(0, 0, 0.3), rag)
		_part(sh, _box(0.13, 0.12, 0.2), Vector3(0, -0.01, 0.7), skin)
		for f in 3:
			_part(sh, _box(0.03, 0.03, 0.12), Vector3(-0.04 + f * 0.04, -0.03, 0.85), skin)
		sh.rotation.x = -1.35
		if s < 0.0:
			arm_l = sh
		else:
			arm_r = sh
	head = Node3D.new()
	head.position = Vector3(0, 0.72, 0.06)
	head.rotation.z = 0.22   # lolling to one side
	torso.add_child(head)
	var skull := SphereMesh.new()
	skull.radius = 0.22
	skull.height = 0.42
	_part(head, skull, Vector3(0, 0.15, 0), skin)
	_part(head, _box(0.26, 0.08, 0.14), Vector3(0, 0.0, 0.1), skin)        # slack jaw
	_part(head, _box(0.18, 0.03, 0.02), Vector3(0, 0.03, 0.17), dark)      # mouth
	_part(head, _box(0.3, 0.1, 0.36), Vector3(0.03, 0.31, -0.02), dark, Vector3(0, 0, -0.2))   # matted hair
	eye_mat = StandardMaterial3D.new()
	eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	eye_mat.emission_enabled = true
	eye_mat.emission_energy_multiplier = 3.0
	var eye := SphereMesh.new()
	eye.radius = 0.045
	eye.height = 0.09
	for s in [-1.0, 1.0]:
		_part(head, eye, Vector3(s * 0.085, 0.17, 0.19), eye_mat)
	# The allegiance ring at its feet and a faint glow.
	ring_mat = StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.emission_enabled = true
	ring_mat.emission_energy_multiplier = 1.4
	ring_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var tor := TorusMesh.new()
	tor.inner_radius = 0.55
	tor.outer_radius = 0.75
	tor.rings = 24
	tor.ring_segments = 4
	ring = _part(self, tor, Vector3(0, 0.04, 0), ring_mat)
	ring.scale = Vector3(1, 0.15, 1)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glow = OmniLight3D.new()
	glow.position = Vector3(0, 1.3, 0.2)
	glow.light_energy = 1.5
	glow.omni_range = 3.6
	add_child(glow)


# --- Behaviour ---------------------------------------------------------------

func step(delta: float) -> void:
	t += delta
	age += delta
	if puppet:
		_puppet_step(delta)
		return
	match state:
		State.RISE:
			_rise_step()
		State.DIE:
			_die_step()
		_:
			if age > Stats.GRAVEYARD.life + Stats.GRAVEYARD.rise_time:
				crumble(false)
				return
			_think(delta)
	_animate()


func _rise_step() -> void:
	var rt: float = Stats.GRAVEYARD.rise_time
	var k := clampf(t / rt, 0.0, 1.0)
	# Out of the ground in jerks, the arms first.
	var e := 1.0 - pow(1.0 - k, 2.2)
	position.y = lerpf(-1.9, 0.0, e) + (sin(t * 38.0) * 0.03 if k < 0.9 else 0.0)
	body.rotation.x = lerpf(0.55, 0.0, e)
	if arm_l:
		arm_l.rotation.x = -2.4 + sin(t * 9.0) * 0.4
		arm_r.rotation.x = -2.4 + sin(t * 9.0 + 1.5) * 0.4
	if t >= dirt_at and k < 0.95:
		dirt_at = t + 0.3
		game.spawn_splash(Vector3(position.x, 0.15, position.z), Color(0.28, 0.21, 0.15), 6, 2.6, 0.5)
	if k >= 1.0:
		position.y = 0.0
		state = State.WALK
		t = 0.0


func _die_step() -> void:
	# Sinks back down, tipping over, and is gone.
	position.y = -t * 1.2
	body.rotation.x = minf(t * 1.6, 1.2)
	if ring_mat:
		ring_mat.albedo_color.a = maxf(0.0, 0.55 - t)
	if glow:
		glow.light_energy = maxf(0.0, 1.5 - t * 1.5)
	if t > 1.4:
		gy.forget(self)
		queue_free()


func crumble(killed: bool) -> void:
	if state == State.DIE:
		return
	state = State.DIE
	t = 0.0
	var at := Vector3(position.x, 0.6, position.z)
	game.spawn_splash(at, Color(0.3, 0.24, 0.18), 14, 3.0, 0.6)
	game.spawn_splash(at + Vector3(0, 0.6, 0), Color(0.55, 0.6, 0.5), 8, 1.2, 1.0, true)
	if killed:
		game.sfx.play("zombie_groan", at, -4.0, 0.15)


func take_hit(amount: int, attacker = null) -> bool:
	## A unit's swing, arrow or spell. Returns true when it landed.
	if state == State.DIE or state == State.RISE or puppet:
		return false
	hp -= maxi(amount, 1)
	game.spawn_splash(position + Vector3(0, 1.1, 0), Color(0.45, 0.6, 0.35), 8, 3.0, 0.35)
	game.sfx.play("hit_flesh", position, -6.0, 0.15)
	if hp <= 0:
		if attacker and is_instance_valid(attacker) and attacker.has_method("gain_xp"):
			attacker.gain_xp(Stats.GRAVEYARD.xp_kill, "combat")
		gy.kills[attacker.team if attacker and is_instance_valid(attacker) and "team" in attacker else 2] += 1
		crumble(true)
	return true


func _valid_target(u) -> bool:
	return is_instance_valid(u) and not u.dead and not u.downed and u.team != team \
		and u.stealth_timer <= 0.0 and u.global_position.y > -0.5 and u.global_position.y < 1.2


func _pick_target():
	var g: Dictionary = Stats.GRAVEYARD
	var reach: float = g.aggro if team < 0 else g.march_aggro
	var best = null
	var best_d := reach
	for u in game.units:
		if not _valid_target(u):
			continue
		var d := _flat(u.global_position - position)
		if team < 0 and _flat(u.global_position - gy.CENTER) > g.leash:
			continue   # neutral zombies keep to the graveyard
		if not gy.walkable_for(u.global_position):
			continue   # up a wall or inside a castle: out of reach
		if d < best_d:
			best_d = d
			best = u
	return best


func _think(delta: float) -> void:
	var g: Dictionary = Stats.GRAVEYARD
	attack_cd -= delta
	retarget -= delta
	if retarget <= 0.0 or not _valid_target(target):
		retarget = 0.4
		target = _pick_target()
	var goal := Vector3.INF
	if target:
		var to: Vector3 = target.global_position - position
		to.y = 0.0
		if to.length() <= g.attack_range:
			facing = to.normalized() if to.length() > 0.05 else facing
			if attack_cd <= 0.0:
				attack_cd = g.attack_cooldown
				state = State.ATTACK
				t = 0.0
				if target.take_damage(g.damage, null, position, 3.0):
					gy.bites[target.team] += g.damage
				game.spawn_splash(target.global_position + Vector3(0, 1.0, 0), Color(0.4, 0.75, 0.3), 6, 2.0, 0.3)
				game.sfx.play("zombie_groan", position, -8.0, 0.2)
			elif state == State.ATTACK and t > 0.55:
				state = State.WALK
			return
		goal = target.global_position
	if state == State.ATTACK and t > 0.55:
		state = State.WALK
	if goal == Vector3.INF:
		if team < 0:
			wander_cd -= delta
			if wander == Vector3.INF or wander_cd <= 0.0 or _flat(wander - position) < 0.6:
				wander = gy.wander_point(home, id + int(age * 10.0))
				wander_cd = 6.0
			goal = wander
		else:
			goal = gy.march_goal(team, position)
	_walk_to(goal, delta)


func _walk_to(goal: Vector3, delta: float) -> void:
	var next: Vector3 = gy.route(position, goal)
	var to := next - position
	to.y = 0.0
	if to.length() < 0.3 and _flat(goal - position) > 0.5:
		to = goal - position   # standing on a waypoint (the corner of a cover stack): on toward the goal
		to.y = 0.0
	if to.length() < 0.3:
		stall = 0.0
		_check_pos = Vector3.INF
		return
	var dir := to.normalized()
	# Caught on something (a wall stub, a tree, a crowd): step round it.
	if age >= _check_at:
		if _check_pos != Vector3.INF and _flat(position - _check_pos) < 0.9 and to.length() > 1.0:
			stall += 1.5
			_detour_side = -_detour_side
			_detour = Vector3(-dir.z, 0, dir.x) * _detour_side
			_detour_left = 1.2
		elif _check_pos != Vector3.INF:
			stall = 0.0
		_check_pos = position
		_check_at = age + 1.5
	if _detour_left > 0.0:
		_detour_left -= delta
		dir = (dir * 0.3 + _detour).normalized()
	dir = (dir + gy.avoid(self) * 0.9).normalized()
	facing = facing.lerp(dir, clampf(delta * 5.0, 0.0, 1.0)).normalized()
	var spd: float = Stats.GRAVEYARD.speed * (0.75 + 0.25 * absf(sin(age * 2.6 + phase)))   # a lurching gait
	var before := position
	var p := position + dir * spd * delta
	p = gy.clamp_walk(before, p)
	p.y = gy.ground_y(p)
	position = p
	moved += _flat(position - before)


func _puppet_step(delta: float) -> void:
	var k := clampf(delta * 8.0, 0.0, 1.0)
	position.x = lerpf(position.x, net_to.x, k)
	position.z = lerpf(position.z, net_to.z, k)
	if state == State.RISE:
		_rise_step()
	elif state == State.DIE:
		_die_step()
		return
	_animate()


func _animate() -> void:
	if facing.length() > 0.1 and state != State.RISE and not puppet:
		rotation.y = lerp_angle(rotation.y, atan2(facing.x, facing.z), 0.2)
	var w := age * 5.2 + phase
	if state == State.RISE:
		return
	body.rotation.z = sin(w * 0.5) * 0.12          # the sway
	body.position.y = absf(sin(w)) * 0.05
	leg_l.rotation.x = sin(w) * 0.45
	leg_r.rotation.x = -sin(w) * 0.45
	if state == State.ATTACK:
		var k := clampf(t / 0.3, 0.0, 1.0)
		var swipe := sin(k * PI)
		arm_l.rotation.x = -1.35 - swipe * 0.9
		arm_r.rotation.x = -1.35 - swipe * 0.9
		body.rotation.x = swipe * 0.25
	else:
		arm_l.rotation.x = -1.35 + sin(w * 0.9) * 0.12
		arm_r.rotation.x = -1.35 + sin(w * 0.9 + 2.0) * 0.12
		body.rotation.x = 0.0
	if ring_mat:
		ring_mat.emission_energy_multiplier = 1.2 + 0.4 * sin(age * 3.0 + phase)


static func _flat(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()
