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
const Blessing = preload("res://scripts/blessing.gd")
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
const CAMERA_OFFSET := Vector3(0, 21.0, 15.0)  # a long lens: less edge distortion
# The river runs north to south through the middle; three bridges cross it.
const RIVER_HALF := 3.0
const BRIDGES := [-14.0, 0.0, 14.0]
const BRIDGE_HALF := [2.0, 3.0, 2.0]
const BANK_LAYER := 16        # river banks block walkers, not shots
const MONARCH_TITLES := ["Elf Queen", "Human King"]
const CONTROLS_PATH := "user://controls.cfg"
# Actions the player can rebind in the Controls menu (and what to call them).
const REBINDABLE := [["attack", "Base attack"], ["block", "Block"], ["ability_1", "Ability Q"], ["ability_2", "Ability E"],
	["dodge", "Dodge"], ["interact", "Grab / drop"], ["rank_menu", "Perks & ranks"], ["scoreboard", "Scoreboard (hold)"],
	["chat", "Chat"], ["menu", "Pause menu"], ["move_up", "Move up"], ["move_down", "Move down"],
	["move_left", "Move left"], ["move_right", "Move right"]]
const MENU_TABS := 5
const CHAT_LINES := 60
# What bots say. Lines are picked by situation.
const BANTER := {
	"reply": ["On it!", "Cover me!", "Heading to the gate.", "Nice one.", "Rally at the bridge!", "Hold the wall!", "Got your back."],
	"idle": ["Push the gate!", "Archers, hold the wall.", "Rally at the middle bridge.", "Watch the flanks.", "Who's got the healer?"],
	"hurt": ["Need a healer over here!", "I'm hurt, falling back.", "Healer!"],
	"carrying": ["I've got them! Cover me!", "Running it home, clear the way!"],
	"ours_taken": ["They've taken our monarch! Get them!", "Stop the carrier!", "Don't let them cross the river!"],
	"captured": ["That's one for us!", "Beautiful. Again!"],
	"gate_down": ["The door is down, push in!", "Go go go, the gate's open!"],
}

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
var blessings: Array = []
var blessing_timer := 30.0
# Where a Blessing of Light can appear: the field, never inside a castle. Mirrored.
const BLESSING_SPOTS := [Vector3(0, 0, -14), Vector3(0, 0, 14), Vector3(9, 0, 3), Vector3(-9, 0, -3), Vector3(16, 0, -10), Vector3(-16, 0, 10),
	Vector3(22, 0, 2), Vector3(-22, 0, -2), Vector3(10, 0, 16), Vector3(-10, 0, -16)]
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
# Menus. The game menu (Esc) pauses; the rank menu (Tab) is an overlay.
var menu_open := false
var rank_open := false
var menu_tab := 0
var shake_amount := 0.0
var cam_pos := Vector3.ZERO
var click_was := false
var scoreboard_open := false   # held: the match scoreboard overlay
var debug_score := false
var chat_open := false
var chat_text := ""
var chat_log: Array = []       # {who, text, color, time, team}
var rebinding := ""            # action waiting for a new key in the Controls menu
var swallow_frame := -1        # frame on which a key was eaten by chat / rebinding
var bot_chat_timer := 18.0


func _ready() -> void:
	randomize()
	_setup_input()
	_load_controls()
	_build_world()
	_build_hud()
	demo = "--demo" in OS.get_cmdline_user_args()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot-frame="):
			shot_frame = int(arg.trim_prefix("--shot-frame="))
	if demo:
		_start_match(0)
		return
	if "--play" in OS.get_cmdline_user_args():
		_start_match(0)  # testing: straight into a match with a (idle) local player
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
	_tick_blessings(delta)
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
		if frame == shot_frame - 5 and player:
			# Menu screenshots: open the menu a few frames before the shot.
			if arg == "--debug-rank":
				player.level = 3
				player.points = 2
				rank_open = true
			if arg == "--debug-menu":
				menu_open = true
				menu_tab = 0
			if arg.begins_with("--debug-tab="):
				menu_tab = int(arg.trim_prefix("--debug-tab="))
			if arg == "--debug-score":
				debug_score = true
			if arg == "--debug-blessing":
				spawn_blessing(Vector3(0, 0, 0), "Regeneration")
				player.apply_blessing("Might")
			if arg == "--debug-chat":
				chat_open = true
				chat_text = "push the middle bridge, I'll take the wall"
				chat_add("Aelith", "anyone got the healer station?", _team_color(0), true)
				chat_add("Sylvara", "on it, give me a sec", _team_color(0), true)
				chat_add("Garrick", "gg so far", _team_color(1), false)
			if arg == "--debug-variant" and player.role == Role.BASE:
				player.set_role(Role.KNIGHT)
				player.level = 4
				player.points = 1
				player.xp = 200
				player.mastery[Role.KNIGHT] = 3
				player.ranks[Role.KNIGHT] = [2, 1, 0, 0]
				player.choose_variant(Role.KNIGHT, 0)
				player.kills = 3
				player.damage_dealt = 7
		if arg == "--debug-options" and frame == shot_frame - 5 and not playing:
			menu_open = true
			menu_tab = 4
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
	carrier.gain_xp(Stats.XP_CAPTURE)
	spawn_splash(thrones[carrier.team] + Vector3(0, 1, 0), Color(1.0, 0.85, 0.3), 50, 6.0, 1.2, true)
	spawn_pillar(thrones[carrier.team], Color(1.0, 0.85, 0.3), 7.0, 1.4)
	spawn_ring(thrones[carrier.team], 6.0, Color(1.0, 0.9, 0.5), 0.8)
	shake(0.3)
	var team_name: String = Stats.FACTIONS[carrier.team].name
	carrier.captures += 1
	chat_system("%s captured the %s for the %s!" % [carrier.display_name, m.title, team_name])
	_banter(carrier.team, "captured")
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
		u.gain_xp(Stats.XP_GRAB)
		announce("The %s has been taken by the %s!" % [m.title, Stats.FACTIONS[u.team].name])
		chat_system("%s grabbed the %s!" % [u.display_name, m.title])
		_banter(1 - u.team, "ours_taken")
		_banter(u.team, "carrying", u)


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


func nearest_blessing(pos: Vector3, radius: float):
	var best = null
	var best_dist := radius
	for b in blessings:
		if not is_instance_valid(b):
			continue
		var d := _flat_dist(pos, b.global_position)
		if d < best_dist:
			best_dist = d
			best = b
	return best


func _tick_blessings(delta: float) -> void:
	## Now and then a Blessing of Light appears somewhere in the field.
	blessings = blessings.filter(func(b): return is_instance_valid(b))
	blessing_timer -= delta
	if blessing_timer > 0.0 or blessings.size() >= 2:
		return
	blessing_timer = randf_range(Stats.BLESSING_INTERVAL[0], Stats.BLESSING_INTERVAL[1])
	var spot: Vector3 = BLESSING_SPOTS[randi() % BLESSING_SPOTS.size()]
	var kinds: Array = Stats.BLESSING_KINDS.keys()
	spawn_blessing(spot, kinds[randi() % kinds.size()])


func spawn_blessing(spot: Vector3, kind: String) -> void:
	var b = Blessing.new()
	add_child(b)
	b.setup(self, spot, kind)
	blessings.append(b)
	spawn_pillar(spot, Stats.BLESSING_KINDS[kind].color, 7.0, 1.2)
	spawn_ring(spot, 4.0, Stats.BLESSING_KINDS[kind].color, 1.0)
	var where := "near the %s bank" % ("north" if spot.z < -5.0 else ("south" if spot.z > 5.0 else "middle"))
	if absf(spot.x) > 12.0:
		where = "on the %s side" % (Stats.FACTIONS[0].realm if spot.x < 0.0 else Stats.FACTIONS[1].realm)
	announce("A Blessing of %s has appeared %s!" % [kind, where])


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
	# The river: cross at the bridge closest to the way, entering it square on.
	if (from.x < -RIVER_HALF and target.x > RIVER_HALF) or (from.x > RIVER_HALF and target.x < -RIVER_HALF):
		var bz: float = BRIDGES[0]
		var best := 1e9
		for z in BRIDGES:
			var d: float = absf(from.z - z) + absf(target.z - z)
			if d < best:
				best = d
				bz = z
		var side := signf(from.x)
		if absf(from.z - bz) > 1.2 and absf(from.x) > RIVER_HALF + 1.0:
			return Vector3(side * (RIVER_HALF + 2.0), 0.0, bz)
		return Vector3(-side * (RIVER_HALF + 2.5), 0.0, bz)
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
	shot.owner_unit = u
	add_child(shot)
	shot.setup(self, u.team, u.global_position, dir, s, color)


func spawn_trap(u, pos: Vector3, a: Dictionary) -> void:
	# Stop at the first wall, crate or tree between the thrower and the spot.
	var from: Vector3 = u.global_position + Vector3(0, 0.5, 0)
	var to := Vector3(pos.x, u.global_position.y + 0.5, pos.z)
	var ray := PhysicsRayQueryParameters3D.create(from, to, 1 | 16)
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if hit:
		var dir := (to - from).normalized()
		to = hit.position - dir * 0.8
		if (to - from).length() < 0.6:
			return
	var trap = Trap.new()
	add_child(trap)
	trap.setup(self, u.team, Vector3(to.x, u.global_position.y, to.z), a)


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


func spawn_splash(where: Vector3, color: Color, count: int, speed: float, life: float, rise: bool = false) -> void:
	## A one-shot spray of little bits: sparks, splinters, motes.
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = count
	p.lifetime = life
	p.direction = Vector3.UP
	p.spread = 180.0 if not rise else 50.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, 2.5, 0) if rise else Vector3(0, -14.0, 0)
	p.damping_min = 1.0
	p.damping_max = 3.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var box := BoxMesh.new()
	box.size = Vector3(0.14, 0.14, 0.14)
	p.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.8
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	p.mesh.material = mat
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = fade
	add_child(p)
	p.global_position = where
	p.emitting = true
	get_tree().create_timer(life + 0.3).timeout.connect(p.queue_free)


func spawn_popup(where: Vector3, text: String, color: Color) -> void:
	## A number or word that floats up and fades, like damage numbers.
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font_size = 40
	l.pixel_size = 0.012
	l.outline_size = 10
	l.modulate = color
	add_child(l)
	l.global_position = where + Vector3(randf_range(-0.3, 0.3), 0, 0)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "global_position", l.global_position + Vector3(0, 1.4, 0), 0.8).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)


func spawn_ring(where: Vector3, radius: float, color: Color, duration: float = 0.5, thickness: float = 0.12) -> void:
	## A ring that expands outward and fades: shockwaves, heals, blessings.
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.0 - thickness
	torus.outer_radius = 1.0
	torus.rings = 32
	torus.ring_segments = 6
	ring.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = mat
	add_child(ring)
	ring.global_position = where + Vector3(0, 0.12, 0)
	ring.scale = Vector3(0.2, 0.2, 0.2)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(radius, 1.0, radius), duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(mat, "albedo_color:a", 0.0, duration).set_delay(duration * 0.3)
	tw.chain().tween_callback(ring.queue_free)


func spawn_pillar(where: Vector3, color: Color, height: float = 4.0, duration: float = 0.9) -> void:
	## A column of light that narrows and fades: level ups, rank ups, captures.
	var pillar := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.6
	cyl.bottom_radius = 0.9
	cyl.height = height
	cyl.radial_segments = 12
	pillar.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color, 0.55)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	pillar.material_override = mat
	add_child(pillar)
	pillar.global_position = where + Vector3(0, height / 2.0, 0)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(pillar, "scale", Vector3(0.15, 1.3, 0.15), duration).set_ease(Tween.EASE_IN)
	tw.tween_property(mat, "albedo_color:a", 0.0, duration).set_delay(duration * 0.4)
	tw.chain().tween_callback(pillar.queue_free)


func spawn_flash(where: Vector3, color: Color, energy: float = 3.0, duration: float = 0.25) -> void:
	## A brief point light: impacts and casts.
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = 6.0
	light.shadow_enabled = false
	add_child(light)
	light.global_position = where + Vector3(0, 1.0, 0)
	var tw := create_tween()
	tw.tween_property(light, "light_energy", 0.0, duration)
	tw.tween_callback(light.queue_free)


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
	chat_system(text)


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
			u.display_name = "You" if is_player else Stats.BOT_NAMES[t][i % Stats.BOT_NAMES[t].size()]
			units.append(u)
			if is_player or (demo and player == null):
				player = u
	cam_pos = player.global_position + CAMERA_OFFSET
	camera.global_position = cam_pos
	playing = true
	announce("Click to attack, Q and E for abilities, Space to dodge, %s for perks, hold %s for the scoreboard, %s to chat." % [
		key_label("rank_menu"), key_label("scoreboard"), key_label("chat")])


func _update_camera(delta: float) -> void:
	if player == null:
		return
	var target: Vector3 = player.global_position + CAMERA_OFFSET
	cam_pos = cam_pos.lerp(target, clampf(delta * 5.0, 0.0, 1.0))
	shake_amount = move_toward(shake_amount, 0.0, delta * 1.6)
	var jolt := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * shake_amount * 0.35
	camera.global_position = cam_pos + jolt


func shake(amount: float) -> void:
	## Camera recoil for the local player's view.
	shake_amount = maxf(shake_amount, amount)


func shake_at(where: Vector3, amount: float) -> void:
	## A shake that fades with distance from the player.
	if player == null:
		return
	var d := _flat_dist(where, player.global_position)
	if d < 16.0:
		shake(amount * (1.0 - d / 16.0))


func menu_blocks_input() -> bool:
	return menu_open or rank_open or chat_open


func menu_tabs() -> Array:
	## Which menu tabs make sense now: at the title only Classes and Controls.
	return [1, 4] if not playing else [0, 1, 2, 3, 4]


func menu_tick() -> void:
	## Called every frame by the HUD, which keeps running while paused.
	if game_over:
		return
	var eaten: bool = Engine.get_process_frames() == swallow_frame
	if not playing:
		# Title screen: the options menu (controls, classes).
		if not eaten and rebinding == "":
			if Input.is_action_just_pressed("options") and not menu_open:
				menu_open = true
				menu_tab = 4
			elif Input.is_action_just_pressed("menu") and menu_open:
				menu_open = false
	elif chat_open:
		pass  # typing: keys go to menu_input
	else:
		if Input.is_action_just_pressed("menu") and not eaten and rebinding == "":
			menu_open = not menu_open
			rank_open = false
			get_tree().paused = menu_open
		scoreboard_open = (Input.is_action_pressed("scoreboard") or debug_score) and not menu_open and not rank_open
		if menu_open:
			if Input.is_action_just_pressed("quit_match") and rebinding == "":
				get_tree().paused = false
				get_tree().reload_current_scene()
		elif Input.is_action_just_pressed("rank_menu") and player and not demo:
			rank_open = not rank_open
		elif Input.is_action_just_pressed("chat") and player and not demo and not eaten:
			chat_open = true
			chat_text = ""
			rank_open = false
		if rank_open and player:
			if player.dead:
				rank_open = false
			for i in 4:
				if Input.is_action_just_pressed("rank_%d" % (i + 1)):
					player.spend_point(i)
			for i in 2:
				if Input.is_action_just_pressed("rank_%d" % (i + 5)):
					player.choose_variant(player.role, i)
	if menu_open and rebinding == "" and not chat_open:
		var tabs := menu_tabs()
		var at := maxi(tabs.find(menu_tab), 0)
		if Input.is_action_just_pressed("menu_left"):
			menu_tab = tabs[posmod(at - 1, tabs.size())]
		if Input.is_action_just_pressed("menu_right"):
			menu_tab = tabs[posmod(at + 1, tabs.size())]
		if not menu_tab in tabs:
			menu_tab = tabs[0]
	# Bot chatter now and then.
	if playing and not get_tree().paused:
		bot_chat_timer -= get_process_delta_time()
		if bot_chat_timer <= 0.0:
			bot_chat_timer = randf_range(22.0, 40.0)
			_idle_banter()
	# Mouse clicks on menu buttons (the HUD records where it drew them).
	var click := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if click and not click_was and hud and rebinding == "":
		var mouse := get_viewport().get_mouse_position()
		for i in hud.rank_buttons.size():
			if hud.rank_buttons[i].has_point(mouse) and player:
				player.spend_point(i)
		for b in hud.variant_buttons:
			if b[0].has_point(mouse) and player:
				player.choose_variant(b[1], b[2])
		for i in hud.tab_buttons.size():
			if hud.tab_buttons[i].has_point(mouse):
				menu_tab = hud.tab_ids[i]
		for b in hud.bind_buttons:
			if b[0].has_point(mouse):
				rebinding = b[1]
				swallow_frame = Engine.get_process_frames()
		if hud.reset_button.has_point(mouse):
			_reset_controls()
		if hud.options_button.has_point(mouse) and not playing:
			menu_open = true
			menu_tab = 4
		if hud.close_button.has_point(mouse):
			if menu_open:
				menu_open = false
				get_tree().paused = false
			rank_open = false
	click_was = click


func menu_input(event: InputEvent) -> void:
	## Raw key events from the HUD: typing in chat and rebinding controls.
	if rebinding != "":
		if Engine.get_process_frames() == swallow_frame:
			return  # the click that picked the row
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_ESCAPE:
				rebinding = ""
			else:
				_rebind(rebinding, event)
			swallow_frame = Engine.get_process_frames()
		elif (event is InputEventMouseButton or event is InputEventJoypadButton) and event.pressed:
			_rebind(rebinding, event)
			swallow_frame = Engine.get_process_frames()
		return
	if chat_open and event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ENTER, KEY_KP_ENTER:
				if chat_text.strip_edges() != "":
					_send_chat(chat_text.strip_edges())
					chat_open = false
					swallow_frame = Engine.get_process_frames()
				elif Engine.get_process_frames() != swallow_frame:
					chat_open = false
					swallow_frame = Engine.get_process_frames()
			KEY_ESCAPE:
				chat_open = false
				swallow_frame = Engine.get_process_frames()
			KEY_BACKSPACE:
				chat_text = chat_text.left(maxi(chat_text.length() - 1, 0))
			_:
				if event.unicode >= 32 and chat_text.length() < 90:
					chat_text += char(event.unicode)


# --- Chat ------------------------------------------------------------------

func chat_add(who: String, text: String, color: Color, team_only: bool = false) -> void:
	chat_log.append({"who": who, "text": text, "color": color, "time": Time.get_ticks_msec() / 1000.0, "team": team_only})
	if chat_log.size() > CHAT_LINES:
		chat_log.pop_front()


func chat_system(text: String) -> void:
	chat_add("", text, Color(0.8, 0.8, 0.85))


func chat_kill(attacker, victim) -> void:
	if attacker and attacker != victim:
		chat_add("", "%s (%s) slew %s (%s)." % [attacker.display_name, attacker.role_name(), victim.display_name, victim.role_name()], Color(0.9, 0.6, 0.55))
	else:
		chat_add("", "%s (%s) fell." % [victim.display_name, victim.role_name()], Color(0.9, 0.6, 0.55))


func _send_chat(text: String) -> void:
	## Team chat by default; "/all " talks to everyone.
	var team_only := true
	if text.begins_with("/all "):
		text = text.trim_prefix("/all ").strip_edges()
		team_only = false
	elif text.begins_with("/t "):
		text = text.trim_prefix("/t ").strip_edges()
	if text == "":
		return
	chat_add(player.display_name, text, _team_color(player.team), team_only)
	# A teammate answers after a moment.
	if randf() < 0.7:
		_banter(player.team, "reply", null, randf_range(0.8, 2.2))


func _team_color(team: int) -> Color:
	return Stats.FACTIONS[team].color.lightened(0.35)


func _banter(team: int, kind: String, speaker = null, delay: float = -1.0) -> void:
	## A bot on `team` says one of the BANTER lines for `kind`.
	if speaker == null:
		var bots: Array = units.filter(func(u): return u.team == team and not u.is_player and not u.dead)
		if bots.is_empty():
			return
		speaker = bots[randi() % bots.size()]
	elif speaker.is_player:
		return
	var lines: Array = BANTER[kind]
	var line: String = lines[randi() % lines.size()]
	if delay < 0.0:
		delay = randf_range(0.6, 1.8)
	var who: String = speaker.display_name
	get_tree().create_timer(delay).timeout.connect(func(): chat_add(who, line, _team_color(team), true))


func _idle_banter() -> void:
	var bots: Array = units.filter(func(u): return not u.is_player and not u.dead)
	if bots.is_empty():
		return
	var b = bots[randi() % bots.size()]
	var kind := "idle"
	if b.carrying:
		kind = "carrying"
	elif b.hearts <= 2:
		kind = "hurt"
	elif monarchs[b.team].state == Monarch.State.CARRIED:
		kind = "ours_taken"
	_banter(b.team, kind, b, 0.1)


func unit_score(u) -> int:
	return u.kills * Stats.SCORE_KILL + u.captures * Stats.SCORE_CAPTURE + u.healing * Stats.SCORE_HEAL \
		+ u.damage_dealt * Stats.SCORE_DAMAGE + u.total_upgrades() * Stats.SCORE_UPGRADE


# --- Control bindings --------------------------------------------------------

func key_label(action: String) -> String:
	## A short keycap label for the action's first mouse or keyboard binding.
	if DisplayServer.get_name() == "headless":
		return action.to_upper()
	for ev in InputMap.action_get_events(action):
		if ev is InputEventMouseButton:
			return _mouse_name(ev.button_index)
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			return _short_key(_key_name(ev))
	return "-"


func binding_text(action: String, device: String) -> String:
	## Every binding on one device ("key" = keyboard + mouse, "pad" = gamepad).
	var names: Array = []
	for ev in InputMap.action_get_events(action):
		if device == "key":
			if ev is InputEventKey:
				names.append(_key_name(ev))
			elif ev is InputEventMouseButton:
				names.append(_mouse_name(ev.button_index))
		else:
			if ev is InputEventJoypadButton:
				names.append(_pad_name(ev.button_index))
			elif ev is InputEventJoypadMotion:
				if ev.axis == JOY_AXIS_TRIGGER_RIGHT:
					names.append("RT")
				elif ev.axis == JOY_AXIS_TRIGGER_LEFT:
					names.append("LT")
				elif ev.axis == JOY_AXIS_LEFT_X or ev.axis == JOY_AXIS_LEFT_Y:
					names.append("Left stick")
	return " / ".join(names) if not names.is_empty() else "-"


func _key_name(ev: InputEventKey) -> String:
	var code: int = ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode
	return OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(code) if ev.physical_keycode != 0 else code)


func _short_key(name: String) -> String:
	match name:
		"Escape": return "ESC"
		"Backspace": return "BKSP"
		"Space": return "SPACE"
		"Enter": return "ENTER"
		"Shift": return "SHIFT"
		"Ctrl": return "CTRL"
		"Alt": return "ALT"
		"Left": return "←"
		"Right": return "→"
		"Up": return "↑"
		"Down": return "↓"
	return name.to_upper().left(6)


func _mouse_name(button: int) -> String:
	match button:
		MOUSE_BUTTON_LEFT: return "LMB"
		MOUSE_BUTTON_RIGHT: return "RMB"
		MOUSE_BUTTON_MIDDLE: return "MMB"
		MOUSE_BUTTON_XBUTTON1: return "M4"
		MOUSE_BUTTON_XBUTTON2: return "M5"
	return "M%d" % button


func _pad_name(button: int) -> String:
	match button:
		JOY_BUTTON_A: return "A"
		JOY_BUTTON_B: return "B"
		JOY_BUTTON_X: return "X"
		JOY_BUTTON_Y: return "Y"
		JOY_BUTTON_LEFT_SHOULDER: return "LB"
		JOY_BUTTON_RIGHT_SHOULDER: return "RB"
		JOY_BUTTON_BACK: return "Back"
		JOY_BUTTON_START: return "Start"
		JOY_BUTTON_LEFT_STICK: return "LS"
		JOY_BUTTON_RIGHT_STICK: return "RS"
		JOY_BUTTON_DPAD_UP: return "D-up"
		JOY_BUTTON_DPAD_DOWN: return "D-down"
		JOY_BUTTON_DPAD_LEFT: return "D-left"
		JOY_BUTTON_DPAD_RIGHT: return "D-right"
	return "Btn %d" % button


func _rebind(action: String, event: InputEvent) -> void:
	## Replace the action's bindings of the event's kind (keyboard, mouse or
	## gamepad button) with this one, and take it off any other action.
	var fresh: InputEvent
	if event is InputEventKey:
		fresh = InputEventKey.new()
		fresh.physical_keycode = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	elif event is InputEventMouseButton:
		fresh = InputEventMouseButton.new()
		fresh.button_index = event.button_index
	elif event is InputEventJoypadButton:
		fresh = InputEventJoypadButton.new()
		fresh.button_index = event.button_index
	else:
		return
	for entry in REBINDABLE:
		for ev in InputMap.action_get_events(entry[0]):
			if entry[0] == action and ev.get_class() == fresh.get_class():
				InputMap.action_erase_event(entry[0], ev)
			elif entry[0] != action and ev.is_match(fresh, true):
				InputMap.action_erase_event(entry[0], ev)
	InputMap.action_add_event(action, fresh)
	rebinding = ""
	_save_controls()


func _save_controls() -> void:
	var cfg := ConfigFile.new()
	for entry in REBINDABLE:
		var list: Array = []
		for ev in InputMap.action_get_events(entry[0]):
			if ev is InputEventKey:
				list.append({"t": "key", "c": ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode})
			elif ev is InputEventMouseButton:
				list.append({"t": "mouse", "c": ev.button_index})
			elif ev is InputEventJoypadButton:
				list.append({"t": "pad", "c": ev.button_index})
		cfg.set_value("controls", entry[0], list)
	cfg.save(CONTROLS_PATH)


func _load_controls() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONTROLS_PATH) != OK:
		return
	for entry in REBINDABLE:
		if not cfg.has_section_key("controls", entry[0]):
			continue
		for ev in InputMap.action_get_events(entry[0]):
			if ev is InputEventKey or ev is InputEventMouseButton or ev is InputEventJoypadButton:
				InputMap.action_erase_event(entry[0], ev)
		for item in cfg.get_value("controls", entry[0]):
			var ev: InputEvent
			match item.t:
				"key":
					ev = InputEventKey.new()
					ev.physical_keycode = int(item.c)
				"mouse":
					ev = InputEventMouseButton.new()
					ev.button_index = int(item.c)
				"pad":
					ev = InputEventJoypadButton.new()
					ev.button_index = int(item.c)
			if ev:
				InputMap.action_add_event(entry[0], ev)


func _reset_controls() -> void:
	for entry in REBINDABLE:
		if InputMap.has_action(entry[0]):
			InputMap.erase_action(entry[0])
	_setup_input()
	DirAccess.remove_absolute(CONTROLS_PATH)
	rebinding = ""


# --- World -----------------------------------------------------------------

func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	return mat


# Textured materials (ambientCG, CC0). Triplanar mapping means boxes of any
# size tile cleanly without UV work. One tile every 1/scale metres.
func _pbr(prefix: String, scale: float, tint: Color = Color.WHITE) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load("res://assets/textures/%s_color.jpg" % prefix)
	mat.albedo_color = tint
	mat.normal_enabled = true
	mat.normal_texture = load("res://assets/textures/%s_normal.jpg" % prefix)
	mat.roughness = 0.85
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3.ONE * scale
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return mat


func _stone(tint: Color = Color.WHITE, scale: float = 0.22) -> StandardMaterial3D:
	return _pbr("stone", scale, tint)


func _grass() -> StandardMaterial3D:
	return _pbr("grass", 0.28, Color(0.95, 1.0, 0.85))


func _wood(tint: Color = Color.WHITE, scale: float = 0.5) -> StandardMaterial3D:
	return _pbr("wood", scale, tint)


func _dirt() -> StandardMaterial3D:
	## The rutted dirt road texture (tools/make_textures.py).
	return _pbr("dirt", 0.12)


func _prop(name: String, pos: Vector3, scale: float = 1.0, rot_y: float = 0.0) -> Node3D:
	## Places a KayKit model (CC0). `name` is "hex/tree_single_A",
	## "dungeon/banner_green" or "gear/staff" under assets/props.
	var ext := ".glb" if name.begins_with("dungeon/") else ".gltf"
	var scene: PackedScene = load("res://assets/props/%s%s" % [name, ext])
	var inst: Node3D = scene.instantiate()
	inst.position = pos
	inst.scale = Vector3.ONE * scale
	inst.rotation.y = rot_y
	add_child(inst)
	return inst


func _add_collider(pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)
	add_child(body)


func _add_block(pos: Vector3, size: Vector3, color: Color, solid: bool, mat: Material = null) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = mat if mat else _material(color)
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
	mesh.material_override = _stone(color, 0.3)
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
	mesh.mesh = _rock_mesh(absi(int(pos.x * 31 + pos.z * 17)), 1.25)
	mesh.position.y = 0.55
	mesh.rotation.y = pos.x * 0.7
	mesh.scale = Vector3(1.0, 0.85, 1.15)
	mesh.material_override = _stone(Color(0.55, 0.6, 0.7), 0.35)
	body.add_child(mesh)
	# A mossy cap.
	var moss := MeshInstance3D.new()
	moss.mesh = _rock_mesh(absi(int(pos.x * 31 + pos.z * 17)) + 3, 1.0)
	moss.position.y = 1.05
	moss.scale = Vector3(1.0, 0.35, 1.1)
	moss.material_override = _pbr("grass", 0.4, Color(0.55, 0.8, 0.4))
	body.add_child(moss)
	add_child(body)
	# A few pebbles around the base.
	for i in 3:
		var ang := TAU * i / 3.0 + pos.x
		_prop("hex/rock_single_%s" % ["A", "B", "C", "D", "E"][absi(int(pos.x * 7 + pos.z) + i) % 5],
			pos + Vector3(cos(ang) * 1.7, 0, sin(ang) * 1.7), 4.0, ang)


func _add_tree(pos: Vector3, big: bool = false) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.5
	cyl.height = 3.0
	shape.shape = cyl
	shape.position.y = 1.5
	body.add_child(shape)
	add_child(body)
	var seed := absi(int(pos.x * 13 + pos.z * 7))
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var tree := Node3D.new()
	tree.position = pos
	tree.rotation.y = r.randf() * TAU
	add_child(tree)
	# Trunk and roots.
	var trunk_h: float = (3.4 if big else 2.5) * r.randf_range(0.9, 1.15)
	var bark := _pbr("bark", 0.6)
	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.25 if big else 0.2
	trunk_mesh.bottom_radius = 0.55 if big else 0.4
	trunk_mesh.height = trunk_h
	trunk_mesh.radial_segments = 7
	trunk.mesh = trunk_mesh
	trunk.position.y = trunk_h / 2.0
	trunk.material_override = bark
	tree.add_child(trunk)
	for i in 3:
		var root := MeshInstance3D.new()
		var rc := CylinderMesh.new()
		rc.top_radius = 0.12
		rc.bottom_radius = 0.3
		rc.height = 1.1
		rc.radial_segments = 5
		root.mesh = rc
		var ang := TAU * i / 3.0 + r.randf() * 0.6
		root.position = Vector3(cos(ang) * 0.45, 0.25, sin(ang) * 0.45)
		root.rotation = Vector3(sin(ang) * 0.9, 0, -cos(ang) * 0.9)
		root.material_override = bark
		tree.add_child(root)
	# Canopy: a cluster of faceted blobs with a gradient leaf shader.
	var autumn := seed % 7 == 0
	var leaf := _leaf_material(r, autumn)
	var radius: float = (1.9 if big else 1.4) * r.randf_range(0.9, 1.1)
	var blobs := 6 if big else 4
	var base_y: float = trunk_h * 0.8
	for i in blobs:
		var blob := MeshInstance3D.new()
		var rr: float = radius if i == 0 else radius * r.randf_range(0.55, 0.85)
		blob.mesh = _rock_mesh(seed + i * 11, rr, 0.12)
		var ang := TAU * i / blobs + r.randf() * 0.8
		var spread: float = 0.0 if i == 0 else radius * r.randf_range(0.45, 0.75)
		blob.position = Vector3(cos(ang) * spread, base_y + (0.9 if i == 0 else r.randf_range(-0.3, 0.9)) * radius * 0.5, sin(ang) * spread)
		blob.scale = Vector3(1.0, 0.85, 1.0)
		blob.material_override = leaf
		tree.add_child(blob)
	# Glowing wildwood blossoms on every third tree, like the logo's.
	if seed % 3 == 0 and not autumn:
		var glow := StandardMaterial3D.new()
		glow.albedo_color = Color(0.55, 0.85, 1.0)
		glow.emission_enabled = true
		glow.emission = Color(0.35, 0.75, 1.0)
		glow.emission_energy_multiplier = 3.0
		for i in 6:
			var bud := MeshInstance3D.new()
			var sph := SphereMesh.new()
			sph.radius = 0.11
			sph.height = 0.22
			sph.radial_segments = 6
			sph.rings = 3
			bud.mesh = sph
			var ang := r.randf() * TAU
			bud.position = Vector3(cos(ang) * radius * 0.95, base_y + radius * 0.5 + r.randf_range(-0.6, 0.7), sin(ang) * radius * 0.95)
			bud.material_override = glow
			tree.add_child(bud)


func _leaf_material(r: RandomNumberGenerator, autumn: bool) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/leaf.gdshader")
	mat.set_shader_parameter("noise_tex", load("res://assets/textures/water_noise.png"))
	var hue := r.randf_range(-0.03, 0.03)
	if autumn:
		mat.set_shader_parameter("bottom_color", Color(0.45, 0.18, 0.05))
		mat.set_shader_parameter("top_color", Color(0.95, 0.55, 0.15))
	else:
		mat.set_shader_parameter("bottom_color", Color.from_hsv(0.34 + hue, 0.8, 0.22))
		mat.set_shader_parameter("top_color", Color.from_hsv(0.27 + hue, 0.65, r.randf_range(0.5, 0.62)))
	mat.set_shader_parameter("height", 2.0)
	return mat


func _rock_mesh(seed: int, radius: float, jitter: float = 0.22) -> ArrayMesh:
	## A faceted, lumpy sphere: boulders, rubble and leaf blobs.
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 9
	sphere.rings = 5
	var arrays := sphere.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	# Jitter each unique position the same way so the surface stays closed.
	var moved := {}
	for i in verts.size():
		var key := verts[i].snapped(Vector3.ONE * 0.001)
		if not moved.has(key):
			moved[key] = verts[i] * (1.0 + r.randf_range(-jitter, jitter))
		verts[i] = moved[key]
	arrays[Mesh.ARRAY_VERTEX] = verts
	var st := SurfaceTool.new()
	var tmp := ArrayMesh.new()
	tmp.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	st.create_from(tmp, 0)
	st.deindex()
	st.generate_normals()
	return st.commit()


func _add_bush(pos: Vector3, seed: int) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var leaf := _leaf_material(r, false)
	for i in 3:
		var blob := MeshInstance3D.new()
		var rr := r.randf_range(0.45, 0.7)
		blob.mesh = _rock_mesh(seed + i * 7, rr, 0.15)
		blob.position = pos + Vector3(r.randf_range(-0.5, 0.5), rr * 0.5, r.randf_range(-0.5, 0.5))
		blob.scale = Vector3(1.0, 0.7, 1.0)
		blob.material_override = leaf
		add_child(blob)


func _add_fireflies(pos: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.amount = 12
	p.lifetime = 5.0
	p.preprocess = 5.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(4.0, 1.2, 4.0)
	p.direction = Vector3(0, 1, 0)
	p.spread = 180.0
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 0.5
	p.gravity = Vector3.ZERO
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	var sph := SphereMesh.new()
	sph.radius = 0.07
	sph.height = 0.14
	sph.radial_segments = 6
	sph.rings = 3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 1.0, 0.5)
	mat.emission_enabled = true
	mat.emission = Color(0.8, 1.0, 0.3)
	mat.emission_energy_multiplier = 3.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sph.material = mat
	p.mesh = sph
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.add_point(0.3, Color(1, 1, 1, 1))
	fade.add_point(0.7, Color(1, 1, 1, 1))
	fade.set_color(fade.get_point_count() - 1, Color(1, 1, 1, 0))
	p.color_ramp = fade
	add_child(p)
	p.global_position = pos + Vector3(0, 1.5, 0)


func _add_river() -> void:
	## A river down the middle with three bridges. Invisible bank walls keep
	## walkers out (layer 5), while arrows and spells fly straight over.
	var length: float = map_half.y * 2 + 60
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(RIVER_HALF * 2 + 0.6, length)
	plane.subdivide_depth = 60
	plane.subdivide_width = 6
	water.mesh = plane
	var wmat := ShaderMaterial.new()
	wmat.shader = load("res://assets/shaders/water.gdshader")
	wmat.set_shader_parameter("noise_tex", load("res://assets/textures/water_noise.png"))
	water.material_override = wmat
	water.position = Vector3(0, 0.03, 0)
	add_child(water)
	# Banks: a strip of pebbly dirt and a scatter of stones either side.
	for sx in [-1.0, 1.0]:
		_add_block(Vector3(sx * (RIVER_HALF + 0.9), 0.012, 0), Vector3(1.8, 0.01, length), Color(0.6, 0.5, 0.35), false, _pbr("cobble", 0.5, Color(0.62, 0.6, 0.55)))
		var k := 0
		var z := -map_half.y - 2.0
		while z < map_half.y + 2.0:
			if not _near_bridge(z, 2.5):
				_prop("hex/rock_single_%s" % ["A", "B", "C", "D", "E"][k % 5], Vector3(sx * (RIVER_HALF + 0.8 + fmod(z * 7.3, 1.0)), 0, z), 3.5, z)
			k += 1
			z += 2.3
		# Bank walls between the bridges.
		var edges: Array = [-length / 2.0]
		for i in BRIDGES.size():
			edges.append(BRIDGES[i] - BRIDGE_HALF[i] - 0.3)
			edges.append(BRIDGES[i] + BRIDGE_HALF[i] + 0.3)
		edges.append(length / 2.0)
		for i in range(0, edges.size(), 2):
			var z0: float = edges[i]
			var z1: float = edges[i + 1]
			var body := StaticBody3D.new()
			body.collision_layer = BANK_LAYER
			body.collision_mask = 0
			body.position = Vector3(sx * (RIVER_HALF + 0.2), 1.0, (z0 + z1) / 2.0)
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(0.4, 2.0, z1 - z0)
			shape.shape = box
			body.add_child(shape)
			add_child(body)
	# Bridges: a plank deck with rails and posts.
	for i in BRIDGES.size():
		var bz: float = BRIDGES[i]
		var half: float = BRIDGE_HALF[i]
		var deck_len := RIVER_HALF * 2 + 2.4
		_add_block(Vector3(0, 0.06, bz), Vector3(deck_len, 0.08, half * 2), Color(0.6, 0.45, 0.3), false, _wood(Color(0.9, 0.8, 0.65), 0.9))
		for zs in [-1.0, 1.0]:
			var rz: float = bz + zs * (half + 0.15)
			_add_block(Vector3(0, 0.55, rz), Vector3(deck_len, 0.1, 0.12), Color(0.5, 0.35, 0.2), false, _wood(Color(0.85, 0.7, 0.5), 1.2))
			_add_block(Vector3(0, 0.95, rz), Vector3(deck_len, 0.1, 0.12), Color(0.5, 0.35, 0.2), false, _wood(Color(0.85, 0.7, 0.5), 1.2))
			_add_collider(Vector3(0, 0.6, rz), Vector3(deck_len, 1.2, 0.2))
			for xs in [-1.0, 0.0, 1.0]:
				_add_block(Vector3(xs * (deck_len / 2.0 - 0.15), 0.55, rz), Vector3(0.22, 1.1, 0.22), Color(0.45, 0.3, 0.18), false, _wood(Color(0.8, 0.65, 0.45), 1.2))
		# Lanterns on the big bridge.
		if half > 2.5:
			for xs in [-1.0, 1.0]:
				for zs in [-1.0, 1.0]:
					_add_torch(Vector3(xs * (deck_len / 2.0 - 0.15), 0.9, bz + zs * (half + 0.15)))


func _near_bridge(z: float, margin: float) -> bool:
	for i in BRIDGES.size():
		if absf(z - BRIDGES[i]) < BRIDGE_HALF[i] + margin:
			return true
	return false


func _add_cover() -> void:
	## Low barricades and boulders in the contested middle. Shots stop at
	## them, so there is always somewhere to duck. Everything is mirrored.
	var barricades := [[Vector3(6, 0, 4), 3.5], [Vector3(7, 0, -6), 3.5], [Vector3(14, 0, 1), 4.0],
		[Vector3(13, 0, 9), 3.0], [Vector3(21, 0, -4), 3.5], [Vector3(20, 0, 7), 3.0]]
	var crates := ["hex/crate_A_big", "hex/crate_B_big", "hex/barrel", "hex/crate_A_big", "hex/sack"]
	for b in barricades:
		for m in [1.0, -1.0]:
			var c: Vector3 = b[0] * m
			var length: float = b[1]
			_add_collider(Vector3(c.x, 0.6, c.z), Vector3(1.0, 1.2, length))
			var n := int(length / 1.15)
			for i in n:
				var z: float = c.z - length / 2.0 + (i + 0.5) * length / n
				var pick: int = absi(int(c.x * 3 + z * 5 + i)) % crates.size()
				_prop(crates[pick], Vector3(c.x, 0, z), 5.2, float(i) * 0.15)
				if i % 2 == 0:
					_prop("hex/crate_A_big", Vector3(c.x, 1.05, z), 4.2, float(i) * 0.15 + 0.1)
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


func _add_flag(pos: Vector3, team: int, side: float) -> void:
	_prop("hex/flag_%s" % ["green", "blue"][team], pos, 7.0, PI / 2.0 if side < 0.0 else -PI / 2.0)


func _add_torch(pos: Vector3) -> void:
	_add_block(pos + Vector3(0, 0.9, 0), Vector3(0.16, 1.8, 0.16), Color(0.3, 0.2, 0.1), false)
	_prop("dungeon/torch_lit", pos + Vector3(0, 2.1, 0), 1.5)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.7, 0.35)
	light.light_energy = 1.6
	light.omni_range = 7.0
	light.position = pos + Vector3(0, 2.6, 0)
	add_child(light)


func kcx_of(kx: float, bx: float) -> float:
	return (kx + bx) / 2.0


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

	# The class's gear sits on the pad so you can tell what you'll become.
	match role:
		Role.KNIGHT:
			_prop("gear/sword_1handed", pos + Vector3(-0.3, 0.5, 0), 1.6, 0.4).rotation.x = -PI / 2.0 + 0.4
			_prop("gear/shield_badge_color", pos + Vector3(0.4, 0.6, 0), 1.6, 0.6)
		Role.RANGER:
			_prop("gear/quiver", pos + Vector3(-0.2, 0.15, 0), 1.6, 0.8).rotation.x = 0.6
			_prop("gear/arrow_bundle", pos + Vector3(0.5, 0.2, 0.2), 1.6, 0.3).rotation.x = 1.2
		Role.MAGE:
			_prop("gear/staff", pos + Vector3(0, 0.3, 0), 1.6, 1.0).rotation.x = 1.0
		Role.HEALER:
			_prop("gear/spellbook_open", pos + Vector3(0, 0.3, 0), 1.8, 0.4)
			_prop("gear/wand", pos + Vector3(0.6, 0.25, 0.3), 1.6, 1.2).rotation.x = 1.3


func _build_castle(team: int) -> void:
	var side := -1.0 if team == 0 else 1.0
	var color: Color = Stats.FACTIONS[team].color
	var stone := Color(0.45, 0.32, 0.2) if team == 0 else Color(0.6, 0.6, 0.62)
	# Textured masonry: elves build in warm sandstone, humans in grey granite.
	var tint := Color(0.92, 0.8, 0.62) if team == 0 else Color(0.72, 0.76, 0.84)
	var masonry := _stone(tint)
	var masonry_dark := _stone(tint.darkened(0.12))
	var cobbles := _stone(tint.darkened(0.2), 0.7)
	var cx := side * CASTLE_X
	var fx := _front_x(team)                      # outer wall's front, facing the middle
	var bx := side * (CASTLE_X + CASTLE_DEPTH)    # outer wall's back
	var kx := _keep_x(team)                       # the keep's front
	var hz := CASTLE_HALF_Z

	# --- The outer castle wall: a ring around the yard. ---
	_add_block(Vector3(cx, 0.01, 0), Vector3(CASTLE_DEPTH * 2, 0.02, hz * 2), color, false, cobbles)
	_add_block(Vector3(bx, WALL_H / 2.0, 0), Vector3(1, WALL_H, hz * 2 + 1), stone, true, masonry)
	_add_block(Vector3(cx, WALL_H / 2.0, -hz), Vector3(CASTLE_DEPTH * 2 + 1, WALL_H, 1), stone, true, masonry)
	_add_block(Vector3(cx, WALL_H / 2.0, hz), Vector3(CASTLE_DEPTH * 2 + 1, WALL_H, 1), stone, true, masonry)
	# Battlements along the side and back walls.
	for k in 7:
		var zz := -hz + 1.5 + k * (hz * 2 - 3.0) / 6.0
		_add_block(Vector3(bx, WALL_H + 0.3, zz), Vector3(1.2, 0.6, 1.0), stone, false, masonry_dark)
	for k in 6:
		var xx := fx + side * (2.0 + k * (CASTLE_DEPTH * 2 - 4.0) / 5.0)
		_add_block(Vector3(xx, WALL_H + 0.3, -hz), Vector3(1.0, 0.6, 1.2), stone, false, masonry_dark)
		_add_block(Vector3(xx, WALL_H + 0.3, hz), Vector3(1.0, 0.6, 1.2), stone, false, masonry_dark)

	# Front wall either side of the door, with the rampart walkway and parapet on top.
	var seg := hz - Stats.DOOR_HALF
	var zc := Stats.DOOR_HALF + seg / 2.0
	_add_block(Vector3(fx, WALL_H / 2.0, -zc), Vector3(1, WALL_H, seg), stone, true, masonry)
	_add_block(Vector3(fx, WALL_H / 2.0, zc), Vector3(1, WALL_H, seg), stone, true, masonry)
	_add_block(Vector3(fx, WALK_Y - 0.3, 0), Vector3(2.4, 0.6, hz * 2 + 1), stone, true, _wood(tint, 1.3))
	# The parapet is only for looks: step over it to drop down to the field.
	_add_block(Vector3(fx - side * 1.05, WALK_Y + 0.25, 0), Vector3(0.3, 0.5, hz * 2 + 1), stone, false, masonry_dark)
	# Crenellations along the parapet.
	for k in 9:
		var pz := -hz + 1.0 + k * (hz * 2 - 2.0) / 8.0
		if absf(pz) > Stats.DOOR_HALF + 0.6:
			_add_block(Vector3(fx - side * 1.05, WALK_Y + 0.75, pz), Vector3(0.34, 0.5, 0.9), stone, false, masonry_dark)
	for z in [-hz - 0.5, hz + 0.5]:
		_add_block(Vector3(fx, 2.6, z), Vector3(2.4, 5.2, 2.4), stone, true, masonry_dark)
		_add_block(Vector3(bx, 2.6, z), Vector3(2.4, 5.2, 2.4), stone, true, masonry_dark)
		_add_block(Vector3(fx, 5.4, z), Vector3(2.9, 0.4, 2.9), stone, false, masonry)
		_add_block(Vector3(bx, 5.4, z), Vector3(2.9, 0.4, 2.9), stone, false, masonry)

	# Ramps from the yard up to the walkway, one at each end of the front wall.
	ramps.append([])
	for zs in [-1.0, 1.0]:
		var z: float = zs * (hz - 2.5)
		var bottom := Vector3(fx + side * (KEEP_SETBACK - 1.5), 0.0, z)
		var top := Vector3(fx + side * 1.2, WALK_Y, z)
		_add_ramp(bottom + Vector3(0, -0.3, 0), top, 2.2, tint)
		ramps[team].append({"bottom": bottom, "top": top})
	# Archer posts on the walkway, either side of the door.
	wall_posts.append([Vector3(fx, WALK_Y, -(Stats.DOOR_HALF + 2.0)), Vector3(fx, WALK_Y, Stats.DOOR_HALF + 2.0)])

	# Flags on the towers and torches by the door and the keep.
	for z in [-hz - 0.5, hz + 0.5]:
		_add_flag(Vector3(fx, 5.6, z), team, side)
		_add_flag(Vector3(bx, 5.6, z), team, side)
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
	var keep_mat := _stone(tint.lightened(0.1), 0.26)
	_add_block(Vector3(kcx, 0.03, 0), Vector3(kdepth, 0.04, khz * 2), keep_stone, false, _wood(Color(0.85, 0.75, 0.62), 0.9))
	_add_block(Vector3(kcx, KEEP_H / 2.0, -khz), Vector3(kdepth, KEEP_H, 0.8), keep_stone, true, keep_mat)
	_add_block(Vector3(kcx, KEEP_H / 2.0, khz), Vector3(kdepth, KEEP_H, 0.8), keep_stone, true, keep_mat)
	var kseg := khz - KEEP_DOOR_HALF
	var kzc := KEEP_DOOR_HALF + kseg / 2.0
	_add_block(Vector3(kx, KEEP_H / 2.0, -kzc), Vector3(0.8, KEEP_H, kseg), keep_stone, true, keep_mat)
	_add_block(Vector3(kx, KEEP_H / 2.0, kzc), Vector3(0.8, KEEP_H, kseg), keep_stone, true, keep_mat)
	# Arch over the doorway, well above head height.
	_add_block(Vector3(kx, KEEP_H + 0.1, 0), Vector3(1.0, 0.7, KEEP_DOOR_HALF * 2 + 0.8), keep_stone, false, masonry_dark)
	for z in [-khz, khz]:
		_add_block(Vector3(kx, KEEP_H / 2.0 + 0.5, z), Vector3(1.6, KEEP_H + 1.0, 1.6), keep_stone, true, masonry_dark)
		_add_block(Vector3(bx - side * 0.2, KEEP_H / 2.0 + 0.5, z), Vector3(1.6, KEEP_H + 1.0, 1.6), keep_stone, true, masonry_dark)
	# Banners in the team colour either side of the archway.
	for z in [-(KEEP_DOOR_HALF + 1.2), KEEP_DOOR_HALF + 1.2]:
		_prop("dungeon/banner_shield_%s" % ["green", "blue"][team], Vector3(kx - side * 0.55, -0.45, z), 0.85,
			PI / 2.0 if side > 0.0 else -PI / 2.0)
	# Life in the yard: tents, stores and a training corner.
	# The ramps run from x = fx + 7 to the wall at z = ±(hz - 2.5), so the
	# yard's corners are kept clear; camp life sits along the keep's flanks
	# and under the walkway by the door.
	# Tents in the yard between the road and the ramps.
	for zs in [-1.0, 1.0]:
		_prop("hex/tent", Vector3(fx + side * 5.6, 0, zs * 6.4), 3.6, (0.3 if zs < 0.0 else 2.8) - side)
	_prop("hex/weaponrack", Vector3(fx + side * 1.8, 0, -(Stats.DOOR_HALF + 1.6)), 4.0, PI / 2.0 if side > 0.0 else -PI / 2.0)
	_prop("hex/target", Vector3(fx + side * 1.8, 0, Stats.DOOR_HALF + 1.6), 4.0, PI / 2.0 if side < 0.0 else -PI / 2.0)
	_prop("hex/bucket_arrows", Vector3(fx + side * 1.6, 0, Stats.DOOR_HALF + 3.0), 4.0, 0.4)
	# The narrow strips between the keep's side walls and the outer wall hold
	# small stores: barrels, sacks, a long crate and a bit of fence.
	var strip_z := (KEEP_HALF_Z + hz) / 2.0
	for zs in [-1.0, 1.0]:
		_prop("hex/barrel", Vector3(kcx - side * 4.0, 0, zs * strip_z), 4.4)
		_prop("hex/barrel", Vector3(kcx - side * 3.0, 0, zs * (strip_z + 0.4)), 4.4, 1.0)
		_prop("hex/sack", Vector3(kcx - side * 1.6, 0, zs * (strip_z - 0.3)), 4.4, 1.1 * zs)
		_prop("hex/crate_long_A", Vector3(kcx + side * 0.8, 0, zs * strip_z), 4.2, PI / 2.0)
		_prop("hex/fence_wood_straight", Vector3(kcx + side * 3.4, 0, zs * (strip_z + 0.3)), 4.2, PI / 2.0)
		_prop("hex/crate_A_big", Vector3(kcx + side * 5.2, 0, zs * strip_z), 4.0, 0.3 * zs)
	_prop("hex/barrel", Vector3(kx - side * 1.4, 0, 6.6), 4.4)
	_prop("hex/barrel", Vector3(kx - side * 2.3, 0, 6.2), 4.4, 1.0)
	_prop("hex/wheelbarrow", Vector3(kx - side * 1.8, 0, -6.4), 4.2, 1.2 * side)
	_prop("hex/pallet", Vector3(kx - side * 1.6, 0, 5.2), 4.2, 0.2)
	# Inside the keep: stacked stores and columns along the side walls.
	for zs in [-1.0, 1.0]:
		_prop("dungeon/box_stacked", Vector3(kx + side * 10.0, 0, zs * (KEEP_HALF_Z - 1.4)), 0.9, 0.3 * zs)
		_prop("dungeon/column", Vector3(kx + side * 5.5, 0, zs * (KEEP_HALF_Z - 0.9)), 1.0)
		_prop("dungeon/torch_mounted", Vector3(kx + side * 2.0, 1.6, zs * (KEEP_HALF_Z - 0.45)), 1.4, PI if zs > 0.0 else 0.0)
	# A rug from the archway to the throne.
	_add_block(Vector3(kx + side * 4.5, 0.045, 0), Vector3(7.0, 0.02, 2.6), color.darkened(0.35), false)

	# Throne on a dais inside the keep. Carry the enemy monarch here to score.
	var throne := Vector3(kx + side * 6.0, 0, 0)
	thrones.append(throne)
	_add_block(throne + Vector3(side * 1.5, 0.15, 0), Vector3(3, 0.3, 4), Color(0.75, 0.6, 0.25), false, _stone(Color(1.0, 0.85, 0.45), 0.6))
	_add_block(throne + Vector3(side * 2.4, 1.2, 0), Vector3(0.4, 2.0, 1.6), color.darkened(0.2), false)
	_add_block(throne + Vector3(side * 2.4, 2.35, 0), Vector3(0.5, 0.3, 1.8), Color(0.95, 0.78, 0.25), false)
	for z in [-2.6, 2.6]:
		_prop("dungeon/pillar_decorated", throne + Vector3(side * 2.0, 0, z), 1.5)
	_prop("dungeon/chest_gold", throne + Vector3(side * 3.0, 0, -4.6), 0.9, PI / 2.0 if side < 0.0 else -PI / 2.0)

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
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.25, 0.5, 0.9)
	sky_mat.sky_horizon_color = Color(0.85, 0.9, 0.95)
	sky_mat.ground_bottom_color = Color(0.3, 0.4, 0.25)
	sky_mat.ground_horizon_color = Color(0.65, 0.75, 0.6)
	sky_mat.sun_angle_max = 20.0
	sky.sky_material = sky_mat
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.55
	environment.ambient_light_sky_contribution = 0.7
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 0.8
	environment.glow_enabled = true
	environment.glow_intensity = 0.45
	environment.glow_bloom = 0.08
	environment.glow_hdr_threshold = 1.4
	# A touch of distance haze and a warmer, punchier grade.
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.8, 0.88, 0.95)
	environment.fog_density = 0.0012
	environment.fog_sky_affect = 0.2
	environment.adjustment_enabled = true
	environment.adjustment_saturation = 1.15
	environment.adjustment_contrast = 1.1
	environment.adjustment_brightness = 0.95
	env.environment = environment
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -35, 0)
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	sun.shadow_bias = 0.03
	sun.directional_shadow_max_distance = 70.0
	add_child(sun)
	# A cool fill from the other side so shadows are not black.
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-30, 140, 0)
	fill.light_color = Color(0.6, 0.7, 1.0)
	fill.light_energy = 0.15
	add_child(fill)

	# Ground.
	_add_block(Vector3(0, -0.5, 0), Vector3(map_half.x * 2 + 80, 1, map_half.y * 2 + 60), Color(0.42, 0.62, 0.3), true, _grass())
	# A dirt road from door to door, with a worn patch at each door and in the middle.
	# The road: rutted dirt from bridge to door, cobbled aprons at each door,
	# and grass creeping in at the edges.
	var road := _dirt()
	road.uv1_offset = Vector3(0, 0.5, 0)
	_add_block(Vector3(0, 0.005, 0), Vector3((CASTLE_X - CASTLE_DEPTH) * 2, 0.01, 5.2), Color(0.6, 0.5, 0.35), false, road)
	for sx in [-1.0, 1.0]:
		_add_block(Vector3(sx * (CASTLE_X - CASTLE_DEPTH - 2.5), 0.008, 0), Vector3(7, 0.01, 10), Color(0.6, 0.5, 0.35), false, _pbr("cobble", 0.45, Color(0.9, 0.86, 0.78)))
		# Side paths to the flank bridges.
		for zs in [-1.0, 1.0]:
			var path := _dirt()
			path.uv1_offset = Vector3(0, 0.5, 0)
			_add_block(Vector3(sx * 10.0, 0.004, zs * 14.0), Vector3(14, 0.01, 3.2), Color(0.6, 0.5, 0.35), false, path)
	_add_river()

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
		_add_bush(p + Vector3(1.8, 0, 0.6), int(p.x * 3 + p.z))
		_add_bush(-p + Vector3(-1.8, 0, -0.6), int(p.x * 5 + p.z))
	for p in [Vector3(9, 0, 13), Vector3(-9, 0, -13), Vector3(20, 0, 12), Vector3(-20, 0, -12), Vector3(44, 0, 20), Vector3(-44, 0, -20)]:
		_add_fireflies(p)
	# Woods on the castle flanks.
	for p in [Vector3(38, 0, 17), Vector3(46, 0, 19), Vector3(52, 0, 16), Vector3(34, 0, 22)]:
		_add_tree(p, true)
		_add_tree(-p, true)
		_add_tree(Vector3(p.x, 0, -p.z), true)
		_add_tree(Vector3(-p.x, 0, p.z), true)
	# A tree line and hills beyond the playable edge, so the world has a horizon.
	for i in 14:
		var x := -52.0 + i * 8.0
		_prop("hex/trees_%s_medium" % ["A", "B"][i % 2], Vector3(x, 0, 30.0 + (i % 3) * 1.5), 4.0, float(i))
		_prop("hex/trees_%s_medium" % ["B", "A"][i % 2], Vector3(x + 3.0, 0, -30.0 - (i % 3) * 1.5), 4.0, float(i))
	for i in 5:
		_prop("hex/hill_single_A", Vector3(-40.0 + i * 20.0, -0.2, 40.0), 12.0, float(i))
		_prop("hex/hill_single_A", Vector3(-30.0 + i * 20.0, -0.2, -40.0), 12.0, float(i) + 1.0)

	camera = Camera3D.new()
	camera.rotation_degrees = Vector3(-55, 0, 0)
	camera.fov = 40.0
	camera.position = Vector3(0, 40, 26)
	add_child(camera)
	camera.make_current()


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
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
	_add_action("attack", [KEY_J], [JOY_BUTTON_A], JOY_AXIS_TRIGGER_RIGHT, 1.0, [MOUSE_BUTTON_LEFT])
	_add_action("block", [KEY_SHIFT, KEY_K], [JOY_BUTTON_LEFT_SHOULDER], JOY_AXIS_TRIGGER_LEFT, 1.0, [MOUSE_BUTTON_RIGHT])
	_add_action("ability_1", [KEY_Q], [JOY_BUTTON_X])
	_add_action("ability_2", [KEY_E], [JOY_BUTTON_Y])
	_add_action("dodge", [KEY_SPACE, KEY_L], [JOY_BUTTON_B])
	_add_action("interact", [KEY_F], [JOY_BUTTON_RIGHT_SHOULDER])
	_add_action("rank_menu", [KEY_R], [JOY_BUTTON_RIGHT_STICK])
	_add_action("scoreboard", [KEY_TAB], [JOY_BUTTON_BACK])
	_add_action("chat", [KEY_ENTER], [])
	_add_action("options", [KEY_O], [JOY_BUTTON_BACK])
	_add_action("rank_1", [KEY_1], [JOY_BUTTON_DPAD_UP])
	_add_action("rank_2", [KEY_2], [JOY_BUTTON_DPAD_LEFT])
	_add_action("rank_3", [KEY_3], [JOY_BUTTON_DPAD_RIGHT])
	_add_action("rank_4", [KEY_4], [JOY_BUTTON_DPAD_DOWN])
	_add_action("rank_5", [KEY_5], [])
	_add_action("rank_6", [KEY_6], [])
	_add_action("menu", [KEY_ESCAPE], [JOY_BUTTON_START])
	_add_action("menu_left", [KEY_LEFT, KEY_A], [JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_LEFT_SHOULDER])
	_add_action("menu_right", [KEY_RIGHT, KEY_D], [JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_RIGHT_SHOULDER])
	_add_action("quit_match", [KEY_BACKSPACE], [JOY_BUTTON_Y])
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
