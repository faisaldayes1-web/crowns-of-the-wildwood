extends Node
## Combat effects showcase for renders and captures:
##   godot --path . --fixed-fps 30 --write-movie out.png --quit-after 150 -- --play --fxshow
## Puts six bots round the player on open ground, keeps them pinned there
## with full hearts so they trade blows, and fires a scripted run of hits,
## spells, heals and a fall in front of the camera.
## With --fxwall as well: arrows and a fireball fired at the Human front wall
## and door from outside, and a defender's arrow at its own door from inside;
## every shot stops on the wall or door and the defender inside is unhurt.
## With --skills=<Knight|Ranger|Mage|Healer|Rogue> instead: that class on each
## side casts both of its abilities, Elf first, then Human, at stand-ins
## (one capture per class for the skill looks).
## With --grab: the player grabs a class seal (pop), grabs at nothing (whiff)
## twice (whiffs).
## With --fluid: the player Knight runs while swinging, taps attack fast, and
## turns: for before/after clips of the combat flow.

const Stats = preload("res://scripts/stats.gd")
const Role = Stats.Role

var game
var t := 0.0
var started := false
var cast: Array = []
var spots: Array = []
var events := []
var center := Vector3(-20, 0, 3)


func _physics_process(delta: float) -> void:
	if game.player == null:
		return
	if not started:
		started = true
		_stage()
		return
	t += delta
	for i in cast.size():
		var u = cast[i]
		if not is_instance_valid(u) or u.dead:
			continue
		u.global_position = spots[i]
		u.velocity = Vector3.ZERO
		u.knockback = Vector3.ZERO
		if u.hearts < 2:
			u.hearts = 4
	for k in awake.size():
		if awake[k] > 0.0:
			awake[k] -= delta
			if awake[k] <= 0.0 and casters.size() == 2 and not casters[k].is_player:
				casters[k].process_mode = Node.PROCESS_MODE_DISABLED
	while not events.is_empty() and t >= events[0][0]:
		var e: Array = events.pop_front()
		call(e[1])


func _stage() -> void:
	if "--fxwall" in OS.get_cmdline_user_args():
		_stage_wall()
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--at="):
			center = Vector3(float(arg.get_slice("=", 1).get_slice(",", 0)), 0, float(arg.get_slice("=", 1).get_slice(",", 1)))
	if "--fluid" in OS.get_cmdline_user_args():
		_stage_fluid()
		return
	if "--grab" in OS.get_cmdline_user_args():
		_stage_grab()
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--skills="):
			_stage_skills(arg.get_slice("=", 1))
			return
	var p = game.player
	p.global_position = center
	game.cam_zoom = 0.6   # closer than play, so the effects read in captures
	p.spawn_protect = 0.0
	p.set_role(Role.KNIGHT)
	var elves := []
	var humans := []
	for u in game.units:
		if u == p:
			continue
		if u.team == p.team and elves.size() < 3:
			elves.append(u)
		elif u.team != p.team and humans.size() < 3:
			humans.append(u)
	for u in game.units:
		if u != p and not u in elves and not u in humans:
			u.process_mode = Node.PROCESS_MODE_DISABLED
			u.global_position = Vector3(200, -50, 200)
	var roles_e := [Role.HEALER, Role.MAGE, Role.ROGUE]
	var roles_h := [Role.KNIGHT, Role.MAGE, Role.BASE]
	var offs_e := [Vector3(-2.5, 0, 1.8), Vector3(-3.0, 0, -1.6), Vector3(1.2, 0, 2.6)]
	var offs_h := [Vector3(1.6, 0, 0.2), Vector3(4.2, 0, -1.8), Vector3(2.6, 0, 2.8)]
	for i in 3:
		_place(elves[i], roles_e[i], center + offs_e[i])
		_place(humans[i], roles_h[i], center + offs_h[i])
	events = [[0.3, "_knight_swing"], [0.8, "_venom"], [1.2, "_fireball"], [1.9, "_heal"], [2.3, "_frost"],
		[2.8, "_knight_swing"], [3.1, "_cleave"], [3.6, "_curse"], [4.1, "_bramble"], [4.5, "_fall"]]


func _place(u, role: int, at: Vector3) -> void:
	u.set_role(role)
	u.spawn_protect = 0.0
	u.home_defense = false
	u.global_position = at
	cast.append(u)
	spots.append(at)


func _aim(from, to) -> Vector3:
	var d: Vector3 = to.global_position - from.global_position
	d.y = 0.0
	return d.normalized()


func _knight_swing() -> void:
	var p = game.player
	var target = cast[1]   # the Human Knight next to us
	p.facing = _aim(p, target)
	p.energy = p.energy_max()
	p._attack(p.facing)


func _venom() -> void:
	var rogue = cast[4]
	rogue.variants[Role.ROGUE] = 0
	rogue._stats_cache = {}
	var target = cast[5]
	rogue.global_position = target.global_position - Vector3(1.0, 0, 0)
	spots[4] = rogue.global_position
	rogue.energy = rogue.energy_max()
	rogue._attack(Vector3(1, 0, 0))


func _fireball() -> void:
	var mage = cast[2]
	mage.energy = mage.energy_max()
	mage.ability_timers = [0.0, 0.0]
	mage.use_ability(0, _aim(mage, cast[3]))


func _heal() -> void:
	var healer = cast[0]
	game.player.hearts = 2
	healer.energy = healer.energy_max()
	healer._attack(Vector3(1, 0, 0))


func _frost() -> void:
	var b := {"damage": 1, "gate_damage": 1, "range": 9.0, "splash": 3.0, "shot_speed": 26.0, "frost": true, "root": 1.0}
	game.spawn_shot(cast[3], _aim(cast[3], game.player), b, Color(0.6, 0.85, 1.0))


func _cleave() -> void:
	var p = game.player
	p.variants[Role.KNIGHT] = 0
	p._stats_cache = {}
	p.energy = p.energy_max()
	p.ability_timers = [0.0, 0.0]
	p.use_ability(0, _aim(p, cast[1]))


func _curse() -> void:
	var a := {"damage": 1, "radius": 4.0, "slow": 2.0}
	var priest = cast[5]
	game.sfx.play("curse", priest.global_position)
	var fx: Node = game.get_node("Fx")
	fx.cast(priest, Color(0.6, 0.25, 0.85))
	for u in cast.slice(0, 3) + [game.player]:
		u.take_damage(a.damage, priest, priest.global_position, 3.0, {"slow": a.slow, "fx": "dark"})
	game.spawn_ring(priest.global_position, a.radius, Color(0.6, 0.25, 0.85), 0.7, 0.2)


func _bramble() -> void:
	var b := {"damage": 1, "gate_damage": 1, "range": 9.0, "splash": 3.0, "shot_speed": 26.0, "nature": true, "root": 1.3}
	game.spawn_shot(cast[2], _aim(cast[2], cast[3]), b, Color(0.5, 0.9, 0.35))


func _fall() -> void:
	var v = cast[5]
	v.hearts = 1
	v.take_damage(1, game.player, game.player.global_position, 6.0, {"fx": "heavy"})


# --- Walls stop shots (--fxwall) ---------------------------------------------

var wall_x := 0.0


func _stage_wall() -> void:
	var p = game.player
	wall_x = game.gates[1].position.x
	center = Vector3(wall_x - 7.0, 0, 1.5)
	p.global_position = center
	game.cam_zoom = 0.75
	# Park the camera over the wall so both sides of it are in view.
	game.cam_lock = Vector3(wall_x - 1.0, 0, 0.0)
	game.cam_pos = game.cam_lock + game.CAMERA_OFFSET * game.cam_zoom
	p.spawn_protect = 0.0
	p.set_role(Role.RANGER)
	var defender = null
	for u in game.units:
		if u == p:
			continue
		if defender == null and u.team == 1:
			defender = u
			continue
		u.process_mode = Node.PROCESS_MODE_DISABLED
		u.global_position = Vector3(200, -50, 200)
	defender.set_role(Role.RANGER)
	defender.spawn_protect = 0.0
	defender.process_mode = Node.PROCESS_MODE_DISABLED   # stands still for the camera
	defender.global_position = Vector3(wall_x + 4.0, 0, 1.0)
	cast.append(defender)
	spots.append(defender.global_position)
	events = [[0.3, "_arrow_wall"], [0.75, "_arrow_wall"], [1.2, "_arrow_door"], [1.7, "_fireball_wall"],
		[2.6, "_defender_door"], [3.1, "_arrow_wall"]]


func _arrow_at(target: Vector3) -> void:
	var p = game.player
	var d: Vector3 = target - p.global_position
	d.y = 0.0
	p.facing = d.normalized()
	p.rotation.y = atan2(-p.facing.x, -p.facing.z)
	p.energy = p.energy_max()
	p.attack_timer = 0.0
	p._attack(p.facing)


func _arrow_wall() -> void:
	_arrow_at(Vector3(wall_x, 0, 4.6 + randf_range(-0.4, 0.4)))


func _arrow_door() -> void:
	_arrow_at(Vector3(wall_x, 0, 0.5))


func _fireball_wall() -> void:
	var p = game.player
	game.spawn_shot(p, (Vector3(wall_x, 0, 0.5) - p.global_position).normalized(), {"damage": 1, "gate_damage": 1, "range": 14.0, "splash": 3.5, "shot_speed": 24.0, "fire": true},
		Color(1.0, 0.5, 0.1))
	game.get_node("Fx").cast(p, Color(1.0, 0.55, 0.15))


func _defender_door() -> void:
	# The defender shoots at its own door from inside: that stops too.
	var d = cast[0]
	d.energy = d.energy_max()
	d.attack_timer = 0.0
	var dir: Vector3 = Vector3(wall_x, 0, 0.0) - d.global_position
	dir.y = 0.0
	d.facing = dir.normalized()
	d.rotation.y = atan2(-d.facing.x, -d.facing.z)
	d._attack(d.facing)


# --- Skill looks per class (--skills=<class>) --------------------------------

var casters: Array = []     # [elf, human]
var caster_spots: Array = []
var awake: Array = [0.0, 0.0]   # seconds a caster runs freely (dashes move over frames)


func _stage_skills(cls: String) -> void:
	var role: int = {"knight": Role.KNIGHT, "ranger": Role.RANGER, "mage": Role.MAGE, "healer": Role.HEALER,
		"rogue": Role.ROGUE, "engineer": Role.ENGINEER}.get(cls.to_lower(), Role.KNIGHT)
	var p = game.player
	game.cam_zoom = 0.72
	game.cam_lock = center + Vector3(0, 0, 0.6)
	game.cam_pos = game.cam_lock + game.CAMERA_OFFSET * game.cam_zoom
	var elf_c = p
	var human_c = null
	var elf_d = null
	var human_d = null
	for u in game.units:
		if u == p:
			continue
		if u.team == p.team and elf_d == null:
			elf_d = u
		elif u.team != p.team and human_c == null:
			human_c = u
		elif u.team != p.team and human_d == null:
			human_d = u
		else:
			u.process_mode = Node.PROCESS_MODE_DISABLED
			u.global_position = Vector3(200, -50, 200)
	casters = [elf_c, human_c]
	caster_spots = [center + Vector3(-4.0, 0, -1.4), center + Vector3(4.0, 0, 2.2)]
	for i in 2:
		var c = casters[i]
		c.set_role(role)
		c.spawn_protect = 0.0
		c.home_defense = false
		c.global_position = caster_spots[i]
	human_c.process_mode = Node.PROCESS_MODE_DISABLED
	# Stand-ins to take the hits: an Elf in front of the Human and the other way round.
	_place(human_d, Role.KNIGHT, center + Vector3(2.0, 0, -1.4))
	_place(elf_d, Role.KNIGHT, center + Vector3(-2.0, 0, 2.2))
	for d in [human_d, elf_d]:
		d.process_mode = Node.PROCESS_MODE_DISABLED
		d.hearts = 2   # hurt, so heals show
	for u in [human_c, human_d, elf_d]:
		u.model.process_mode = Node.PROCESS_MODE_ALWAYS   # keep animating while pinned
	events = [[0.4, "_elf_q"], [1.9, "_elf_e"], [3.4, "_human_q"], [4.9, "_human_e"]]
	_clear_stage(7.0)


func _clear_stage(r: float) -> void:
	## Hide trees, rocks and props right round the stage so the casts read
	## (capture only; nothing solid is changed).
	for v in game.find_children("*", "GeometryInstance3D", true, false):
		var n: Node = v
		var skip := false
		while n != null and n != game:
			if n in game.units or n.name == "Fx":
				skip = true
				break
			n = n.get_parent()
		if skip:
			continue
		var box: AABB = v.get_aabb()
		var size: float = (box.size * v.global_transform.basis.get_scale()).length()
		var at: Vector3 = v.global_transform * box.get_center()
		if size < 9.0 and Vector2(at.x - center.x, at.z - center.z).length() < r and at.y > 0.15:
			v.visible = false


func _skill(side: int, i: int) -> void:
	var c = casters[side]
	c.global_position = caster_spots[side]
	c.velocity = Vector3.ZERO
	c.energy = c.energy_max()
	c.ability_timers = [0.0, 0.0]
	c.guard_timer = 0.0
	c.stealth_timer = 0.0
	var dir := Vector3(1, 0, 0) if side == 0 else Vector3(-1, 0, 0)
	c.facing = dir
	c.process_mode = Node.PROCESS_MODE_INHERIT
	awake[side] = 0.5
	c.use_ability(i, dir)
	var a: Dictionary = c.ability(i)
	game.spawn_popup(c.global_position + Vector3(0, 2.6, 0), "%s  %s" % ["ELF" if side == 0 else "HUMAN", a.name.to_upper()],
		Color(0.7, 1.0, 0.6) if side == 0 else Color(1.0, 0.9, 0.55))


func _elf_q() -> void:
	_skill(0, 0)


func _elf_e() -> void:
	_skill(0, 1)


func _human_q() -> void:
	_skill(1, 0)


func _human_e() -> void:
	_skill(1, 1)


# --- Grab (--grab) -------------------------------------------------------------

var grab_seal = null


func _stage_grab() -> void:
	var p = game.player
	p.spawn_protect = 0.0
	game.cam_zoom = 0.55
	for u in game.units:
		if u != p:
			u.process_mode = Node.PROCESS_MODE_DISABLED
			u.global_position = Vector3(200, -50, 200)
	grab_seal = game.seals[p.team][Role.RANGER]
	# Stand in front of the seal (camera side), facing it.
	p.global_position = Vector3(grab_seal.global_position.x, p.global_position.y, grab_seal.global_position.z + 1.3)
	_face(p, grab_seal.global_position)
	events = [[0.6, "_grab_seal"], [2.2, "_grab_air"], [3.6, "_grab_air"]]


func _face(u, at: Vector3) -> void:
	var d: Vector3 = at - u.global_position
	d.y = 0.0
	u.facing = d.normalized()
	u.aim = u.facing
	u.rotation.y = atan2(-u.facing.x, -u.facing.z)


func _grab_seal() -> void:
	game.prep_left = 0.0
	game.try_interact(game.player)


func _grab_air() -> void:
	var p = game.player
	game.prep_left = 0.0
	p.global_position.z += 1.6   # step back from the seal: nothing in reach
	_face(p, p.global_position + Vector3(0, 0, 1))
	game.try_interact(p)


# --- Fluid combat (--fluid) -----------------------------------------------------

func _stage_fluid() -> void:
	var p = game.player
	center = Vector3(-11, 0, 13)
	p.global_position = center + Vector3(-5, 0, 2.2)
	p.spawn_protect = 0.0
	p.set_role(Role.KNIGHT)
	p.aim_mode = "stick"
	game.cam_zoom = 0.6
	var dummies := []
	for u in game.units:
		if u == p:
			continue
		if u.team != p.team and dummies.size() < 3:
			dummies.append(u)
			continue
		u.process_mode = Node.PROCESS_MODE_DISABLED
		u.global_position = Vector3(200, -50, 200)
	var at := [Vector3(-2.2, 0, 2.5), Vector3(0.6, 0, 1.9), Vector3(2.8, 0, 2.6)]
	for i in dummies.size():
		_place(dummies[i], Role.BASE, center + at[i])
		dummies[i].process_mode = Node.PROCESS_MODE_DISABLED
		dummies[i].model.process_mode = Node.PROCESS_MODE_ALWAYS
	events = [[0.3, "_run_right"], [2.2, "_stop"], [2.3, "_tap"], [2.45, "_tap"], [2.6, "_tap"], [2.75, "_tap"],
		[3.3, "_run_left"], [5.0, "_stop"]]


func _run_right() -> void:
	Input.action_press("move_right")
	Input.action_press("attack")


func _run_left() -> void:
	Input.action_press("move_left")
	Input.action_press("attack")


func _stop() -> void:
	for a in ["move_right", "move_left", "attack"]:
		Input.action_release(a)


func _tap() -> void:
	Input.action_press("attack")
	get_tree().create_timer(0.05).timeout.connect(func(): Input.action_release("attack"))
