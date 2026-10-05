extends Node3D
## One match: builds the valley map, spawns both teams and runs the
## capture-the-monarch rules. Everything is built in code from simple shapes,
## so it can be swapped for real art later without changing the rules.

const Stats = preload("res://scripts/stats.gd")
const Unit = preload("res://scripts/unit.gd")
const Monarch = preload("res://scripts/monarch.gd")
const Projectile = preload("res://scripts/projectile.gd")
const Gate = preload("res://scripts/gate.gd")
const Hud = preload("res://scripts/hud.gd")
const HealOrb = preload("res://scripts/heal_orb.gd")
const Trap = preload("res://scripts/trap.gd")
const Role = Stats.Role

const TEAM_SIZE := 5
const CAPTURES_TO_WIN := Stats.CAPTURES_TO_WIN
# Each bot's class and job, in spawn order. The player takes the first slot.
const LINEUP := [
	[Role.KNIGHT, "attack"], [Role.RANGER, "attack"], [Role.MAGE, "attack"],
	[Role.HEALER, "support"], [Role.RANGER, "wall"],
]

# Castle geometry. Each castle is an outer castle wall ringing a yard, with the
# keep (the building: throne and class stations) standing inside at the back.
# The wall's front faces the middle of the map, has the breakable door in it,
# and carries a walkway you climb up to from the yard and shoot down from.
const CASTLE_X := 44.0        # centre of the walled area (x), mirrored for the two teams
const CASTLE_DEPTH := 11.0    # half-depth of the walled area (x)
const CASTLE_HALF_Z := 12.0   # half-width of the walled area (z)
const WALL_H := 3.0
const WALK_Y := 3.6           # height of the walkway floor
const KEEP_SETBACK := 8.5     # yard depth between the front wall and the keep
const KEEP_HALF_Z := 8.5
const KEEP_H := 2.6
const KEEP_DOOR_HALF := 4.5   # the keep's open archway
const CAPTURE_RADIUS := 3.0
const STATION_RADIUS := 1.3
const CAMERA_OFFSET := Vector3(0, 15.5, 11)
const MONARCH_TITLES := ["Elf Queen", "Human King"]

var map_half := Vector2(58, 26)
var playing := false
var game_over := false
var player_team := 0
var score := [0, 0]
var winner_team := -1
var thrones: Array[Vector3] = []
var monarchs: Array = []
var units: Array = []
var gates: Array = []
var ramps: Array = []       # ramps[team] = [{bottom, top} at -z, {bottom, top} at +z]
var wall_posts: Array = []  # wall_posts[team] = [post at -z, post at +z]
var heal_orbs: Array = []
var time_left := Stats.MATCH_TIME
var player

var camera: Camera3D
var hud
var message_label: Label
var banner: Label
var respawn_label: Label
# stations[team] maps a class (Stats.Role) to its station position in that castle.
var stations := [{}, {}]
var message_timer := 0.0
# Run with "-- --demo" to watch bots play each other (used for testing).
var demo := false
var shot_frame := 900


func _ready() -> void:
	randomize()
	_setup_input()
	_build_world()
	_build_hud()
	demo = "--demo" in OS.get_cmdline_user_args()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot-frame="):
			shot_frame = int(arg.trim_prefix("--shot-frame="))
	if demo:
		_start_match(0)
		return
	banner.visible = false


func _process(delta: float) -> void:
	_debug_hooks()
	if not playing and not game_over:
		if Input.is_action_just_pressed("pick_elves"):
			_start_match(0)
		elif Input.is_action_just_pressed("pick_humans"):
			_start_match(1)
		return
	if game_over:
		if demo and not "--debug-end" in OS.get_cmdline_user_args():
			print("Match over: Elves %d, Humans %d" % [score[0], score[1]])
			get_tree().quit()
		if Input.is_action_just_pressed("restart"):
			get_tree().reload_current_scene()
		return

	time_left -= delta
	if time_left <= 0.0:
		_end_on_time()
		return
	_check_rules()
	_check_stations()
	_update_respawn_timer()
	_update_camera(delta)
	if demo and Engine.get_process_frames() % 1800 == 0:
		print("t=%ds  score %d-%d  monarchs %s / %s  doors %d / %d" % [Engine.get_process_frames() / 60,
			score[0], score[1], monarchs[0].state, monarchs[1].state, gates[0].hp, gates[1].hp])
		for u in units:
			print("   team%d %s %s hearts=%d dead=%s" % [u.team, u.role_name(), u.global_position.snapped(Vector3.ONE * 0.1), u.hearts, u.dead])
	if message_timer > 0.0:
		message_timer -= delta
		if message_timer <= 0.0:
			message_label.text = ""


func _debug_hooks() -> void:
	## Testing aids: "--shot=<png>" saves a screenshot at frame --shot-frame
	## (default 900); "--debug-end" ends the match a second before that.
	var frame := Engine.get_process_frames()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot=") and frame == shot_frame:
			get_viewport().get_texture().get_image().save_png(arg.trim_prefix("--shot="))
		if arg == "--debug-end" and playing and frame == shot_frame - 60:
			_finish(1)


# --- Rules -----------------------------------------------------------------

func _check_rules() -> void:
	for m in monarchs:
		if m.state == Monarch.State.CARRIED:
			var carrier = m.carrier
			var to_throne: Vector3 = thrones[carrier.team] - carrier.global_position
			to_throne.y = 0.0
			if to_throne.length() < CAPTURE_RADIUS:
				_score_capture(carrier, m)
		elif m.state == Monarch.State.DROPPED:
			# A teammate touching a dropped monarch sends them straight home.
			for u in units:
				if u.team == m.team and not u.dead and _flat_dist(u.global_position, m.global_position) < 1.5:
					m.go_home()
					announce("The %s is safe again." % m.title)
					break


func _score_capture(carrier, m) -> void:
	carrier.carrying = null
	m.go_home()
	score[carrier.team] += 1
	var team_name: String = Stats.FACTIONS[carrier.team].name
	if score[carrier.team] >= CAPTURES_TO_WIN:
		_finish(carrier.team)
	else:
		announce("The %s captured the %s!" % [team_name, m.title])
	print("Capture: %s  (score %d - %d)" % [team_name, score[0], score[1]])


func _end_on_time() -> void:
	time_left = 0.0
	if score[0] == score[1]:
		_finish(-1)
	else:
		_finish(0 if score[0] > score[1] else 1)
	print("Time up")


func _finish(winner: int) -> void:
	playing = false
	game_over = true
	var line := "Time's up: it's a draw, %d to %d." % [score[0], score[1]]
	var outcome := "DRAW"
	if winner >= 0:
		outcome = "VICTORY!" if winner == player_team else "DEFEAT"
		line = "The %s win %d to %d." % [Stats.FACTIONS[winner].name, score[winner], score[1 - winner]]
	winner_team = winner
	announce(line)


func try_interact(u) -> void:
	if u.dead:
		return
	if u.carrying:
		drop_monarch(u)
		return
	var m = monarchs[1 - u.team]
	if m.state != Monarch.State.CARRIED and _flat_dist(u.global_position, m.global_position) < Unit.PICKUP_RANGE:
		m.pick_up(u)
		u.carrying = m
		announce("The %s has been taken by the %s!" % [m.title, Stats.FACTIONS[u.team].name])


func drop_monarch(u) -> void:
	var m = u.carrying
	if m == null:
		return
	u.carrying = null
	m.drop_at(u.global_position)


func _check_stations() -> void:
	# Stepping onto a class station transforms you into that class.
	for u in units:
		if u.dead or u.carrying:
			continue
		for role in stations[u.team]:
			# Bots only use the station for the class they were assigned.
			if not u.is_player and role != u.bot_class:
				continue
			if u.role != role and _flat_dist(u.global_position, stations[u.team][role]) < STATION_RADIUS:
				u.set_role(role)
				if u == player:
					announce("You are now a %s." % u.role_name())


func station_position(team: int, role: int) -> Vector3:
	return stations[team][role]


func wall_post(team: int, z_side: float) -> Vector3:
	return wall_posts[team][0 if z_side < 0.0 else 1]


func nearest_orb(pos: Vector3, radius: float):
	## The closest healing orb that is currently up, within radius, or null.
	var best = null
	var best_dist := radius
	for orb in heal_orbs:
		if not orb.active:
			continue
		var d := _flat_dist(pos, orb.global_position)
		if d < best_dist:
			best_dist = d
			best = orb
	return best


func _update_respawn_timer() -> void:
	if player and player.dead:
		respawn_label.text = "You fell!\nRespawning in %d" % ceili(player.respawn_timer)
		respawn_label.visible = true
	else:
		respawn_label.visible = false


# --- Castles and routing -----------------------------------------------------

func _front_x(team: int) -> float:
	return (-1.0 if team == 0 else 1.0) * (CASTLE_X - CASTLE_DEPTH)


func _keep_x(team: int) -> float:
	## The keep's front wall (x).
	return (-1.0 if team == 0 else 1.0) * (CASTLE_X - CASTLE_DEPTH + KEEP_SETBACK)


func _inside_keep(team: int, p: Vector3) -> bool:
	var side := -1.0 if team == 0 else 1.0
	var kx := _keep_x(team)
	var bx := side * (CASTLE_X + CASTLE_DEPTH)
	return (p.x - kx) * side > 0.0 and (bx - p.x) * side > 0.0 and absf(p.z) < KEEP_HALF_Z + 0.5


func _inside_castle(team: int, p: Vector3) -> bool:
	var side := -1.0 if team == 0 else 1.0
	var fx := side * (CASTLE_X - CASTLE_DEPTH)
	var bx := side * (CASTLE_X + CASTLE_DEPTH)
	return (p.x - fx) * side > 0.0 and (bx - p.x) * side > 0.0 and absf(p.z) < CASTLE_HALF_Z + 0.5


func enemy_inside_castle(team: int) -> bool:
	var fx := _front_x(team)
	for u in units:
		if u.team == team or u.dead:
			continue
		if _inside_castle(team, u.global_position) \
				or (absf(u.global_position.x - fx) < 1.5 and absf(u.global_position.z) < Stats.DOOR_HALF + 0.5):
			return true
	return false


func gate_blocking(team: int, from: Vector3, to: Vector3):
	## The enemy door, if it is standing and between these two points.
	var gate = gates[1 - team]
	if not gate.is_intact():
		return null
	return gate if _inside_castle(1 - team, from) != _inside_castle(1 - team, to) else null


func route_point(from: Vector3, to: Vector3) -> Vector3:
	## The next place to walk toward on the way to `to`: the ramp when the goal
	## is up on the walls, the castle door when the outer wall is in the way,
	## the keep's archway when the keep's walls are, else `to`.
	var target := to
	if to.y > 2.0 and from.y < WALK_Y - 0.2:
		var c := 0 if to.x < 0.0 else 1
		var ramp: Dictionary = ramps[c][0] if to.z < 0.0 else ramps[c][1]
		if from.y < 0.5 and _flat_dist(from, ramp.bottom) > 1.2:
			target = ramp.bottom
		else:
			return ramp.top
	for c in 2:
		if _inside_castle(c, from) != _inside_castle(c, target):
			var fx := _front_x(c)
			return Vector3(fx + (1.8 if target.x > from.x else -1.8), 0.0, 0.0)
		if _inside_keep(c, from) != _inside_keep(c, target):
			var kx := _keep_x(c)
			return Vector3(kx + (1.5 if target.x > from.x else -1.5), 0.0, 0.0)
	return target


# --- Effects -----------------------------------------------------------------

func spawn_shot(u, dir: Vector3, s: Dictionary, color: Color) -> void:
	## An arrow, spell or bolt. `s` carries damage, gate_damage, range and
	## optionally splash and speed (see projectile.gd).
	var shot = Projectile.new()
	add_child(shot)
	shot.setup(self, u.team, u.global_position, dir, s, color)


func spawn_trap(u, pos: Vector3, a: Dictionary) -> void:
	var trap = Trap.new()
	add_child(trap)
	trap.setup(self, u.team, Vector3(pos.x, u.global_position.y, pos.z), a)


func spawn_burst(where: Vector3, radius: float, color: Color) -> void:
	var ring := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.05
	ring.mesh = disc
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color, 0.45)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = mat
	add_child(ring)
	ring.global_position = Vector3(where.x, where.y + 0.15, where.z)
	get_tree().create_timer(0.25).timeout.connect(ring.queue_free)


func spawn_swing(u, aim: Vector3) -> void:
	var swing := MeshInstance3D.new()
	var slab := BoxMesh.new()
	slab.size = Vector3(1.6, 0.05, 0.7)
	swing.mesh = slab
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 1, 1, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	swing.material_override = mat
	add_child(swing)
	swing.global_position = u.global_position + aim * 1.1 + Vector3(0, 1.0, 0)
	swing.rotation.y = atan2(-aim.x, -aim.z)
	get_tree().create_timer(0.12).timeout.connect(swing.queue_free)


func announce(text: String) -> void:
	if message_label:
		message_label.text = text
		message_timer = 3.0


func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# --- Match setup -----------------------------------------------------------

func _start_match(team: int) -> void:
	player_team = team
	winner_team = -1
	banner.visible = false
	for t in 2:
		var side := -1.0 if t == 0 else 1.0
		for i in TEAM_SIZE:
			var u = Unit.new()
			add_child(u)
			var spawn := Vector3(side * (CASTLE_X + CASTLE_DEPTH - 2.5), 0.0, -5.0 + i * 2.5)
			var is_player := t == player_team and i == 0 and not demo
			u.setup(self, t, is_player, spawn)
			u.bot_class = LINEUP[i][0]
			u.bot_job = LINEUP[i][1]
			units.append(u)
			if is_player or (demo and player == null):
				player = u
	camera.global_position = player.global_position + CAMERA_OFFSET
	playing = true
	announce("Move with WASD, aim with the mouse, left click to attack, Q and E for abilities, Shift to dodge, F to grab the monarch.")


func _update_camera(delta: float) -> void:
	if player == null:
		return
	var target: Vector3 = player.global_position + CAMERA_OFFSET
	camera.global_position = camera.global_position.lerp(target, clampf(delta * 5.0, 0.0, 1.0))


# --- World -----------------------------------------------------------------

func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	return mat


func _add_block(pos: Vector3, size: Vector3, color: Color, solid: bool) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _material(color)
	if solid:
		var body := StaticBody3D.new()
		body.position = pos
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		shape.shape = box_shape
		body.add_child(shape)
		body.add_child(mesh)
		add_child(body)
	else:
		mesh.position = pos
		add_child(mesh)


func _add_ramp(from: Vector3, to: Vector3, width: float, color: Color) -> void:
	## A solid slab whose top surface runs from `from` up to `to`.
	var dir := to - from
	var thickness := 0.4
	var body := StaticBody3D.new()
	var slab_basis := Basis.looking_at(dir.normalized(), Vector3.UP)
	body.basis = slab_basis
	body.position = (from + to) / 2.0 - slab_basis.y * (thickness / 2.0)
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(width, thickness, dir.length())
	shape.shape = box_shape
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = box_shape.size
	mesh.mesh = box
	mesh.material_override = _material(color)
	body.add_child(mesh)
	add_child(body)


func _add_boulder(pos: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.2
	shape.shape = sphere
	shape.position.y = 0.8
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var rock := SphereMesh.new()
	rock.radius = 1.2
	rock.height = 2.4
	mesh.mesh = rock
	mesh.position.y = 0.8
	mesh.material_override = _material(Color(0.5, 0.5, 0.48))
	body.add_child(mesh)
	add_child(body)


func _add_tree(pos: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.5
	cyl.height = 3.0
	shape.shape = cyl
	shape.position.y = 1.5
	body.add_child(shape)

	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.3
	trunk_mesh.bottom_radius = 0.4
	trunk_mesh.height = 1.6
	trunk.mesh = trunk_mesh
	trunk.position.y = 0.8
	trunk.material_override = _material(Color(0.4, 0.27, 0.15))
	body.add_child(trunk)

	var crown := MeshInstance3D.new()
	var crown_mesh := CylinderMesh.new()
	crown_mesh.top_radius = 0.0
	crown_mesh.bottom_radius = 1.4
	crown_mesh.height = 2.8
	crown.mesh = crown_mesh
	crown.position.y = 2.8
	crown.material_override = _material(Color(0.15, 0.45, 0.2))
	body.add_child(crown)
	add_child(body)


func _add_cover() -> void:
	## Low barricades and boulders in the contested middle. Shots stop at
	## them, so there is always somewhere to duck. Everything is mirrored.
	var wood := Color(0.5, 0.35, 0.2)
	var barricades := [[Vector3(6, 0, 4), 3.5], [Vector3(7, 0, -6), 3.5], [Vector3(14, 0, 1), 4.0],
		[Vector3(13, 0, 9), 3.0], [Vector3(21, 0, -4), 3.5], [Vector3(20, 0, 7), 3.0]]
	for b in barricades:
		for m in [1.0, -1.0]:
			var c: Vector3 = b[0] * m
			_add_block(Vector3(c.x, 0.6, c.z), Vector3(0.6, 1.2, b[1]), wood, true)
			_add_block(Vector3(c.x, 0.8, c.z - b[1] / 2.0), Vector3(0.8, 1.6, 0.4), wood.darkened(0.3), false)
			_add_block(Vector3(c.x, 0.8, c.z + b[1] / 2.0), Vector3(0.8, 1.6, 0.4), wood.darkened(0.3), false)
	var boulders := [Vector3(3, 0, -11), Vector3(11, 0, -13), Vector3(17, 0, 13), Vector3(24, 0, -6), Vector3(28, 0, 9)]
	for p in boulders:
		_add_boulder(p)
		_add_boulder(-p)


func _add_heal_orbs() -> void:
	## Healing orbs at fixed spots: the road's centre, the field's flanks, and
	## one in each castle yard. Mirrored for fairness.
	var spots := [Vector3(0, 0, 0), Vector3(0, 0, 16), Vector3(18, 0, -11), Vector3(37.5, 0, 0)]
	for p in spots:
		var orb = HealOrb.new()
		add_child(orb)
		orb.setup(self, p)
		heal_orbs.append(orb)
		if p.length() > 0.1:
			var mirror = HealOrb.new()
			add_child(mirror)
			mirror.setup(self, -p)
			heal_orbs.append(mirror)


func _add_flag(pos: Vector3, color: Color, side: float) -> void:
	var pole := MeshInstance3D.new()
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.06
	pole_mesh.bottom_radius = 0.08
	pole_mesh.height = 2.6
	pole.mesh = pole_mesh
	pole.position = pos + Vector3(0, 1.3, 0)
	pole.material_override = _material(Color(0.35, 0.25, 0.15))
	add_child(pole)
	var cloth := MeshInstance3D.new()
	var cloth_mesh := BoxMesh.new()
	cloth_mesh.size = Vector3(1.4, 0.9, 0.06)
	cloth.mesh = cloth_mesh
	cloth.position = pos + Vector3(-side * 0.75, 2.1, 0)
	cloth.material_override = _material(color)
	add_child(cloth)
	var crest := MeshInstance3D.new()
	var crest_mesh := BoxMesh.new()
	crest_mesh.size = Vector3(0.4, 0.3, 0.08)
	crest.mesh = crest_mesh
	crest.position = pos + Vector3(-side * 0.75, 2.1, 0)
	crest.material_override = _material(Color(1.0, 0.82, 0.2))
	add_child(crest)


func _add_torch(pos: Vector3) -> void:
	_add_block(pos + Vector3(0, 1.0, 0), Vector3(0.14, 2.0, 0.14), Color(0.3, 0.2, 0.1), false)
	var flame := MeshInstance3D.new()
	var flame_mesh := SphereMesh.new()
	flame_mesh.radius = 0.22
	flame_mesh.height = 0.5
	flame.mesh = flame_mesh
	flame.position = pos + Vector3(0, 2.2, 0)
	var mat := _material(Color(1.0, 0.6, 0.15))
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.5, 0.1)
	mat.emission_energy_multiplier = 2.0
	flame.material_override = mat
	add_child(flame)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.7, 0.35)
	light.light_energy = 1.6
	light.omni_range = 7.0
	light.position = pos + Vector3(0, 2.4, 0)
	add_child(light)


func _add_station(team: int, role: int, pos: Vector3) -> void:
	stations[team][role] = pos
	var color: Color = Stats.ROLES[role].color
	_add_block(pos + Vector3(0, 0.05, 0), Vector3(2.2, 0.1, 2.2), color.darkened(0.3), false)

	var pad := MeshInstance3D.new()
	var pad_mesh := CylinderMesh.new()
	pad_mesh.top_radius = STATION_RADIUS
	pad_mesh.bottom_radius = STATION_RADIUS
	pad_mesh.height = 0.06
	pad.mesh = pad_mesh
	var pad_mat := _material(color)
	pad_mat.emission_enabled = true
	pad_mat.emission = color * 0.4
	pad.material_override = pad_mat
	pad.position = pos + Vector3(0, 0.12, 0)
	add_child(pad)

	# A floating, spinning hat shows which class this station gives.
	var icon := MeshInstance3D.new()
	match role:
		Role.KNIGHT:
			var helm := SphereMesh.new()
			helm.radius = 0.4
			helm.height = 0.5
			icon.mesh = helm
		Role.RANGER:
			var hood := CylinderMesh.new()
			hood.top_radius = 0.0
			hood.bottom_radius = 0.4
			hood.height = 0.6
			icon.mesh = hood
		Role.MAGE:
			var wizard := CylinderMesh.new()
			wizard.top_radius = 0.0
			wizard.bottom_radius = 0.45
			wizard.height = 1.0
			icon.mesh = wizard
		Role.HEALER:
			var gem := SphereMesh.new()
			gem.radius = 0.3
			gem.height = 0.6
			icon.mesh = gem
	icon.material_override = _material(color)
	icon.position = pos + Vector3(0, 1.4, 0)
	add_child(icon)
	var spin := icon.create_tween().set_loops()
	spin.tween_property(icon, "rotation:y", TAU, 3.0).from(0.0)

	var label := Label3D.new()
	label.text = Stats.FACTIONS[team].roles[role]
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 32
	label.pixel_size = 0.012
	label.outline_size = 8
	label.position = pos + Vector3(0, 2.3, 0)
	add_child(label)


func _build_castle(team: int) -> void:
	var side := -1.0 if team == 0 else 1.0
	var color: Color = Stats.FACTIONS[team].color
	var stone := Color(0.45, 0.32, 0.2) if team == 0 else Color(0.6, 0.6, 0.62)
	var cx := side * CASTLE_X
	var fx := _front_x(team)                      # outer wall's front, facing the middle
	var bx := side * (CASTLE_X + CASTLE_DEPTH)    # outer wall's back
	var kx := _keep_x(team)                       # the keep's front
	var hz := CASTLE_HALF_Z

	# --- The outer castle wall: a ring around the yard. ---
	_add_block(Vector3(cx, 0.01, 0), Vector3(CASTLE_DEPTH * 2, 0.02, hz * 2), color.darkened(0.5), false)
	_add_block(Vector3(bx, WALL_H / 2.0, 0), Vector3(1, WALL_H, hz * 2 + 1), stone, true)
	_add_block(Vector3(cx, WALL_H / 2.0, -hz), Vector3(CASTLE_DEPTH * 2 + 1, WALL_H, 1), stone, true)
	_add_block(Vector3(cx, WALL_H / 2.0, hz), Vector3(CASTLE_DEPTH * 2 + 1, WALL_H, 1), stone, true)
	# Battlements along the side and back walls.
	for k in 7:
		var zz := -hz + 1.5 + k * (hz * 2 - 3.0) / 6.0
		_add_block(Vector3(bx, WALL_H + 0.3, zz), Vector3(1.2, 0.6, 1.0), stone.darkened(0.15), false)
	for k in 6:
		var xx := fx + side * (2.0 + k * (CASTLE_DEPTH * 2 - 4.0) / 5.0)
		_add_block(Vector3(xx, WALL_H + 0.3, -hz), Vector3(1.0, 0.6, 1.2), stone.darkened(0.15), false)
		_add_block(Vector3(xx, WALL_H + 0.3, hz), Vector3(1.0, 0.6, 1.2), stone.darkened(0.15), false)

	# Front wall either side of the door, with the rampart walkway and parapet on top.
	var seg := hz - Stats.DOOR_HALF
	var zc := Stats.DOOR_HALF + seg / 2.0
	_add_block(Vector3(fx, WALL_H / 2.0, -zc), Vector3(1, WALL_H, seg), stone, true)
	_add_block(Vector3(fx, WALL_H / 2.0, zc), Vector3(1, WALL_H, seg), stone, true)
	_add_block(Vector3(fx, WALK_Y - 0.3, 0), Vector3(2.4, 0.6, hz * 2 + 1), stone.lightened(0.15), true)
	_add_block(Vector3(fx - side * 1.05, WALK_Y + 0.25, 0), Vector3(0.3, 0.5, hz * 2 + 1), stone.darkened(0.15), true)
	for z in [-hz - 0.5, hz + 0.5]:
		_add_block(Vector3(fx, 2.6, z), Vector3(2.4, 5.2, 2.4), stone.darkened(0.2), true)
		_add_block(Vector3(bx, 2.6, z), Vector3(2.4, 5.2, 2.4), stone.darkened(0.2), true)

	# Ramps from the yard up to the walkway, one at each end of the front wall.
	ramps.append([])
	for zs in [-1.0, 1.0]:
		var z: float = zs * (hz - 2.5)
		var bottom := Vector3(fx + side * (KEEP_SETBACK - 1.5), 0.0, z)
		var top := Vector3(fx + side * 1.2, WALK_Y, z)
		_add_ramp(bottom + Vector3(0, -0.3, 0), top, 2.2, stone.lightened(0.1))
		ramps[team].append({"bottom": bottom, "top": top})
	# Archer posts on the walkway, either side of the door.
	wall_posts.append([Vector3(fx, WALK_Y, -(Stats.DOOR_HALF + 2.0)), Vector3(fx, WALK_Y, Stats.DOOR_HALF + 2.0)])

	# Flags on the towers and torches by the door and the keep.
	for z in [-hz - 0.5, hz + 0.5]:
		_add_flag(Vector3(fx, 5.2, z), color, side)
		_add_flag(Vector3(bx, 5.2, z), color, side)
	for z in [-(Stats.DOOR_HALF + 1.0), Stats.DOOR_HALF + 1.0]:
		_add_torch(Vector3(fx - side * 1.1, 0, z))
		_add_torch(Vector3(kx - side * 0.9, 0, z * 1.2))

	# The breakable door.
	var gate = Gate.new()
	add_child(gate)
	gate.setup(self, team, fx)
	gates.append(gate)

	# --- The keep: the building inside the wall, with an open archway. ---
	var khz := KEEP_HALF_Z
	var kdepth := absf(bx - kx)
	var kcx := (kx + bx) / 2.0
	var keep_stone := stone.lightened(0.25)
	_add_block(Vector3(kcx, 0.03, 0), Vector3(kdepth, 0.04, khz * 2), keep_stone.darkened(0.35), false)
	_add_block(Vector3(kcx, KEEP_H / 2.0, -khz), Vector3(kdepth, KEEP_H, 0.8), keep_stone, true)
	_add_block(Vector3(kcx, KEEP_H / 2.0, khz), Vector3(kdepth, KEEP_H, 0.8), keep_stone, true)
	var kseg := khz - KEEP_DOOR_HALF
	var kzc := KEEP_DOOR_HALF + kseg / 2.0
	_add_block(Vector3(kx, KEEP_H / 2.0, -kzc), Vector3(0.8, KEEP_H, kseg), keep_stone, true)
	_add_block(Vector3(kx, KEEP_H / 2.0, kzc), Vector3(0.8, KEEP_H, kseg), keep_stone, true)
	# Arch over the doorway, well above head height.
	_add_block(Vector3(kx, KEEP_H + 0.1, 0), Vector3(1.0, 0.7, KEEP_DOOR_HALF * 2 + 0.8), keep_stone.darkened(0.1), false)
	for z in [-khz, khz]:
		_add_block(Vector3(kx, KEEP_H / 2.0 + 0.5, z), Vector3(1.6, KEEP_H + 1.0, 1.6), keep_stone.darkened(0.15), true)
	# Banners in the team colour on the keep's front.
	for z in [-(KEEP_DOOR_HALF + 1.2), KEEP_DOOR_HALF + 1.2]:
		_add_block(Vector3(kx - side * 0.5, 1.8, z), Vector3(0.1, 1.6, 0.7), color, false)

	# Throne on a dais inside the keep. Carry the enemy monarch here to score.
	var throne := Vector3(kx + side * 6.0, 0, 0)
	thrones.append(throne)
	_add_block(throne + Vector3(side * 1.5, 0.15, 0), Vector3(3, 0.3, 4), Color(0.75, 0.6, 0.25), false)
	_add_block(throne + Vector3(side * 2.4, 1.2, 0), Vector3(0.4, 2.0, 1.6), color.darkened(0.2), false)

	# Class stations along the keep's side walls, near the spawn.
	_add_station(team, Role.KNIGHT, Vector3(kx + side * 3.5, 0, -6.0))
	_add_station(team, Role.RANGER, Vector3(kx + side * 7.5, 0, -6.0))
	_add_station(team, Role.MAGE, Vector3(kx + side * 3.5, 0, 6.0))
	_add_station(team, Role.HEALER, Vector3(kx + side * 7.5, 0, 6.0))

	var ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = CAPTURE_RADIUS - 0.15
	ring_mesh.outer_radius = CAPTURE_RADIUS
	ring.mesh = ring_mesh
	ring.position = throne + Vector3(0, 0.05, 0)
	var ring_mat := _material(Color(1.0, 0.85, 0.3))
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = ring_mat
	add_child(ring)

	var m = Monarch.new()
	add_child(m)
	m.setup(team, throne, color, MONARCH_TITLES[team])
	monarchs.append(m)


func _build_world() -> void:
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.5, 0.7, 0.9)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.75, 0.78, 0.85)
	environment.ambient_light_energy = 0.6
	env.environment = environment
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.shadow_enabled = true
	add_child(sun)

	# Ground.
	_add_block(Vector3(0, -0.5, 0), Vector3(map_half.x * 2 + 80, 1, map_half.y * 2 + 60), Color(0.42, 0.62, 0.3), true)
	# A dirt road from door to door.
	_add_block(Vector3(0, 0.005, 0), Vector3((CASTLE_X - CASTLE_DEPTH) * 2, 0.01, 4), Color(0.6, 0.5, 0.35), false)

	_build_castle(0)
	_build_castle(1)
	_add_cover()
	_add_heal_orbs()

	# Mirrored groves in the contested middle, leaving the road clear.
	var grove := [Vector3(5, 0, 7), Vector3(10, 0, 12), Vector3(16, 0, 6), Vector3(8, 0, 17),
		Vector3(19, 0, 15), Vector3(23, 0, 10), Vector3(3, 0, 13), Vector3(14, 0, 19), Vector3(27, 0, 14)]
	for p in grove:
		_add_tree(p)
		_add_tree(-p)
	# Woods on the castle flanks.
	for p in [Vector3(38, 0, 17), Vector3(46, 0, 19), Vector3(52, 0, 16), Vector3(34, 0, 22)]:
		_add_tree(p)
		_add_tree(-p)
		_add_tree(Vector3(p.x, 0, -p.z))
		_add_tree(Vector3(-p.x, 0, p.z))

	camera = Camera3D.new()
	camera.rotation_degrees = Vector3(-55, 0, 0)
	camera.fov = 55.0
	camera.position = Vector3(0, 40, 26)
	add_child(camera)
	camera.make_current()


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	hud = Hud.new()
	hud.game = self
	layer.add_child(hud)

	message_label = Label.new()
	message_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	message_label.offset_top = 96
	message_label.offset_bottom = 136
	message_label.offset_left = -400
	message_label.offset_right = 400
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 20)
	message_label.add_theme_constant_override("outline_size", 7)
	message_label.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.06))
	message_label.add_theme_color_override("font_color", Color(1, 0.95, 0.75))
	layer.add_child(message_label)


	banner = Label.new()
	banner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size", 30)
	banner.add_theme_constant_override("outline_size", 10)
	banner.add_theme_color_override("font_outline_color", Color.BLACK)
	layer.add_child(banner)

	respawn_label = Label.new()
	respawn_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	respawn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	respawn_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	respawn_label.add_theme_font_size_override("font_size", 44)
	respawn_label.add_theme_constant_override("outline_size", 12)
	respawn_label.add_theme_color_override("font_outline_color", Color.BLACK)
	respawn_label.add_theme_color_override("font_color", Color(1, 0.85, 0.5))
	respawn_label.visible = false
	layer.add_child(respawn_label)


# --- Input -----------------------------------------------------------------

func _setup_input() -> void:
	_add_action("move_left", [KEY_A, KEY_LEFT], [], JOY_AXIS_LEFT_X, -1.0)
	_add_action("move_right", [KEY_D, KEY_RIGHT], [], JOY_AXIS_LEFT_X, 1.0)
	_add_action("move_up", [KEY_W, KEY_UP], [], JOY_AXIS_LEFT_Y, -1.0)
	_add_action("move_down", [KEY_S, KEY_DOWN], [], JOY_AXIS_LEFT_Y, 1.0)
	_add_action("aim_left", [], [], JOY_AXIS_RIGHT_X, -1.0)
	_add_action("aim_right", [], [], JOY_AXIS_RIGHT_X, 1.0)
	_add_action("aim_up", [], [], JOY_AXIS_RIGHT_Y, -1.0)
	_add_action("aim_down", [], [], JOY_AXIS_RIGHT_Y, 1.0)
	_add_action("attack", [KEY_SPACE, KEY_J], [JOY_BUTTON_A], JOY_AXIS_TRIGGER_RIGHT, 1.0, [MOUSE_BUTTON_LEFT])
	_add_action("ability_1", [KEY_Q], [JOY_BUTTON_X])
	_add_action("ability_2", [KEY_E], [JOY_BUTTON_Y])
	_add_action("dodge", [KEY_SHIFT, KEY_L], [JOY_BUTTON_B], -1, 0.0, [MOUSE_BUTTON_RIGHT])
	_add_action("interact", [KEY_F, KEY_K], [JOY_BUTTON_RIGHT_SHOULDER])
	_add_action("pick_elves", [KEY_1], [JOY_BUTTON_DPAD_LEFT])
	_add_action("pick_humans", [KEY_2], [JOY_BUTTON_DPAD_RIGHT])
	_add_action("restart", [KEY_R, KEY_ENTER], [JOY_BUTTON_START])


func _add_action(action: StringName, keys: Array, buttons: Array, axis: int = -1, axis_value: float = 0.0,
		mouse_buttons: Array = []) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, 0.25)
	for key in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		InputMap.action_add_event(action, ev)
	for button in buttons:
		var jb := InputEventJoypadButton.new()
		jb.button_index = button
		InputMap.action_add_event(action, jb)
	if axis >= 0:
		var jm := InputEventJoypadMotion.new()
		jm.axis = axis
		jm.axis_value = axis_value
		InputMap.action_add_event(action, jm)
	for button in mouse_buttons:
		var mb := InputEventMouseButton.new()
		mb.button_index = button
		InputMap.action_add_event(action, mb)
