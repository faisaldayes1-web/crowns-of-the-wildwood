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
const Vault = preload("res://scripts/vault.gd")
const Guide = preload("res://scripts/guide.gd")
const Barricade = preload("res://scripts/barricade.gd")
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
const CASTLE_X := 60.0        # centre of the walled area (x), mirrored for the two teams
const CASTLE_DEPTH := 11.0    # half-depth of the walled area (x)
const CASTLE_HALF_Z := 12.0   # half-width of the walled area (z)
const WALL_H := 3.0
const WALK_Y := 3.6           # height of the walkway floor
const KEEP_SETBACK := 8.5     # yard depth between the front wall and the keep
const KEEP_HALF_Z := 8.5
const KEEP_H := 2.6
const KEEP_DOOR_HALF := 4.5   # the keep's open archway
const CAPTURE_RADIUS := 3.0
# The spawn cellar: a sunken stone hall behind each keep. Everyone spawns
# there, picks a class at the stations, and climbs the stairs into the keep.
const CELLAR_DEPTH := 10.0    # how far behind the back wall it reaches (x)
const CELLAR_HALF_Z := 7.0
const CELLAR_Y := -2.4        # its floor
const ISLAND_R := 6.0         # the Crown Shrine island in the river
const STATION_RADIUS := 1.3
const CAMERA_OFFSET := Vector3(0, 21.0, 15.0)  # a long lens: less edge distortion
# The river runs north to south through the middle; three bridges cross it.
const RIVER_HALF := 3.0
const BRIDGES := [-20.0, 0.0, 20.0]      # the middle crossing is the shrine island
const BRIDGE_HALF := [2.2, 6.3, 3.0]
const BANK_LAYER := 16        # river banks block walkers, not shots
const MONARCH_TITLES := ["Elf Queen", "Human King"]
const CONTROLS_PATH := "user://controls.cfg"
# Actions the player can rebind in the Controls menu (and what to call them).
const REBINDABLE := [["attack", "Base attack"], ["block", "Block"], ["ability_1", "Ability Q"], ["ability_2", "Ability E"],
	["dodge", "Dodge"], ["interact", "Grab / drop"], ["rank_menu", "Perks & ranks"], ["scoreboard", "Scoreboard (hold)"],
	["chat", "Chat"], ["chat_toggle", "Show / hide chat"], ["roster_toggle", "Show / hide team rosters"], ["menu", "Pause menu"], ["move_up", "Move up"], ["move_down", "Move down"],
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

var map_half := Vector2(84, 36)
var bot_difficulty := "Normal"   # Easy / Normal / Hard, saved with the controls
var chat_visible := true          # H hides the chat log
var rosters_visible := true       # N hides the side team rosters
# Hero customizer (title screen): name, hair and trim colour.
var hero_name := ""
var hero_hair := 0
var hero_trim := 0
var name_editing := false
var levelup_timer := 0.0
var levelup_level := 1
var map_trees: Array[Vector3] = []  # for the minimap: y > 0.5 means a big tree
var map_paths: Array = []           # [from, to, width] of every path for the minimap
var map_marks: Array = []           # [position, kind] ruins and such
var playing := false
var game_over := false
var player_team := 0
var score := [0, 0]
var winner_team := -1
var thrones: Array[Vector3] = []
var monarchs: Array = []
var units: Array = []
var gates: Array = []
var vaults: Array = []
var toasts: Array = []        # [{text, color, time}] small HUD notices
var stolen_timer := 0.0       # the CROWN STOLEN banner
var ramps: Array = []       # ramps[team] = [{bottom, top} at -z, {bottom, top} at +z]
var wall_posts: Array = []  # wall_posts[team] = [post at -z, post at +z]
var cover_points: Array = []  # places a shooter can duck behind
var barricades: Array = []
var audit_props: Array = []   # [name, Node3D] every placed KayKit prop (for --audit)
var audit_blocks: Array = []  # [label, AABB] every block, ramp, fence, gate and vault
var audit_label := ""
var guides: Array = [null, null]   # the Wildwood Guide in each courtyard
var guide_open := false
var guide_page := 0       # intro page, or -1 for the topic menu
var guide_topic := -1     # which topic's answer is showing
var guide_seen := false   # the intro has been read once this match
var upgrade_pads: Array = [Vector3.INF, Vector3.INF]
var on_upgrade_pad := false
# HOW TO WIN checklist for new players: step -> done.
var tutorial: Array = [false, false, false, false, false, false, false, false]
var tutorial_shown := true
var plan_timer := 0.0
var heal_orbs: Array = []
var blessings: Array = []
var blessing_timer := 30.0
# Where a Blessing of Light can appear: the field, never inside a castle. Mirrored.
const BLESSING_SPOTS := [Vector3(0, 0.5, 0), Vector3(0, 0.5, 0), Vector3(0, 0.5, 0), Vector3(12, 0, -24), Vector3(-12, 0, 24), Vector3(26, 0, 4), Vector3(-26, 0, -4),
	Vector3(16, 0, 12), Vector3(-16, 0, -12), Vector3(30, 0, -16), Vector3(-30, 0, 16), Vector3(10, 0, 26), Vector3(-10, 0, -26)]
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
	if "--audit" in OS.get_cmdline_user_args():
		_audit_clipping()
		get_tree().quit()
		return
	demo = "--demo" in OS.get_cmdline_user_args()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot-frame="):
			shot_frame = int(arg.trim_prefix("--shot-frame="))
	if demo:
		_start_match(0)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hero="):
			var parts := arg.trim_prefix("--hero=").split(",")
			hero_name = parts[0]
			hero_hair = int(parts[1]) if parts.size() > 1 else 0
			hero_trim = int(parts[2]) if parts.size() > 2 else 0
	if "--play" in OS.get_cmdline_user_args():
		_start_match(0)  # testing: straight into a match with a (idle) local player
		return
	banner.visible = false


func _process(delta: float) -> void:
	_debug_hooks()
	if not playing and not game_over:
		if name_editing or menu_open:
			return
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
	plan_timer -= delta
	if plan_timer <= 0.0:
		plan_timer = 1.0
		for t in 2:
			_plan_bots(t)
	_tick_blessings(delta)
	_tick_tutorial()
	_update_camera(delta)
	if demo and Engine.get_process_frames() % 1800 == 0:
		print("t=%ds  score %d-%d  monarchs %s / %s  doors %d / %d" % [Engine.get_process_frames() / 60,
			score[0], score[1], monarchs[0].state, monarchs[1].state, gates[0].hp, gates[1].hp])
		for u in units:
			print("   team%d %s %s hearts=%d dead=%s" % [u.team, u.role_name(), u.global_position.snapped(Vector3.ONE * 0.1), u.hearts, u.dead])
	stolen_timer = maxf(stolen_timer - delta, 0.0)
	levelup_timer = maxf(levelup_timer - delta, 0.0)
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
			if arg == "--debug-stolen":
				stolen_timer = 3.5
				if monarchs[1 - player_team].state == Monarch.State.HOME:
					var thief = units[TEAM_SIZE - 1] if player_team == 1 else units[TEAM_SIZE + 1]
					monarchs[1 - player_team].pick_up(thief)
					thief.carrying = monarchs[1 - player_team]
			if arg == "--debug-levelup":
				levelup_timer = 3.0
				levelup_level = 2
			if arg == "--debug-guide":
				guide_open = true
				guide_page = 1
			if arg == "--debug-guide-menu":
				guide_open = true
				guide_page = -1
				guide_topic = -1
			if arg == "--debug-score":
				debug_score = true
			if arg.begins_with("--debug-at="):
				var p := arg.trim_prefix("--debug-at=").split(",")
				player.position = Vector3(float(p[0]), float(p[2]) if p.size() > 2 else 0.0, float(p[1]))
				cam_pos = player.position + CAMERA_OFFSET
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
	if u.is_player and guides[u.team] and guides[u.team].in_reach(u):
		guide_toggle()
		return
	var m = monarchs[1 - u.team]
	if m.state != Monarch.State.CARRIED and _flat_dist(u.global_position, m.global_position) < Unit.PICKUP_RANGE:
		if m.state == Monarch.State.HOME and vaults[1 - u.team].is_locked():
			if u.is_player:
				toast("The Crown Vault is locked: break the lock first", Color(1.0, 0.8, 0.5))
			return
		m.pick_up(u)
		u.carrying = m
		u.gain_xp(Stats.XP_GRAB)
		stolen_timer = 3.5
		announce("CROWN STOLEN! The %s has been taken by the %s!" % [m.title, Stats.FACTIONS[u.team].name])
		spawn_pillar(u.global_position, Color(1.0, 0.85, 0.3), 7.0, 1.2)
		spawn_flash(u.global_position + Vector3(0, 1.5, 0), Color(1.0, 0.85, 0.3), 4.0, 0.5)
		shake_at(u.global_position, 0.5)
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
	if spot.length() < 1.0:
		where = "at the Crown Shrine"
	elif absf(spot.x) > 12.0:
		where = "on the %s side" % (Stats.FACTIONS[0].realm if spot.x < 0.0 else Stats.FACTIONS[1].realm)
	announce("A Blessing of %s has appeared %s!" % [kind, where])


func bot_tuning() -> Dictionary:
	return Stats.BOT_TUNING[bot_difficulty]


func announce_veteran(u, tier: int) -> void:
	var side_name: String = Stats.FACTIONS[u.team].name
	if tier == 2:
		announce("%s of the %s is an ELITE VETERAN: %d kills without dying! Bounty on their head, location revealed." % [u.display_name, side_name, u.streak])
		chat_system("Bounty: %s (%s) is an Elite Veteran. Bring them down for a team reward!" % [u.display_name, side_name])
		if u.is_player:
			spawn_popup(u.global_position + Vector3(0, 2.8, 0), "ELITE VETERAN", Color(1.0, 0.6, 0.2))
	else:
		announce("%s of the %s is a Veteran: %d kills without dying." % [u.display_name, side_name, u.streak])
		if u.is_player:
			spawn_popup(u.global_position + Vector3(0, 2.8, 0), "VETERAN", Color(1.0, 0.85, 0.3))


func bounty_claimed(killer, victim) -> void:
	## An Elite Veteran fell: the killer's whole team is blessed and the killer paid.
	announce("BOUNTY CLAIMED! %s slew the Elite Veteran %s: the %s gain %s!" % [killer.display_name, victim.display_name, Stats.FACTIONS[killer.team].name, Stats.BOUNTY_BUFF])
	chat_system("%s claimed the bounty on %s (+%d XP, %s for the team)." % [killer.display_name, victim.display_name, Stats.BOUNTY_XP, Stats.BOUNTY_BUFF])
	killer.gain_xp(Stats.BOUNTY_XP)
	spawn_pillar(victim.global_position, Color(1.0, 0.85, 0.3), 9.0, 1.6)
	spawn_ring(victim.global_position, 5.0, Color(1.0, 0.85, 0.3), 1.0)
	for u in units:
		if u.team == killer.team and not u.dead:
			u.apply_blessing(Stats.BOUNTY_BUFF)
	if killer.is_player:
		spawn_popup(killer.global_position + Vector3(0, 3.0, 0), "BOUNTY  +%d XP" % Stats.BOUNTY_XP, Color(1.0, 0.85, 0.3))


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


func _in_cellar(team: int, p: Vector3) -> bool:
	var side := -1.0 if team == 0 else 1.0
	var bx := side * (CASTLE_X + CASTLE_DEPTH)
	return (p.x - bx) * side > -0.8 and absf(p.z) < CELLAR_HALF_Z + 0.5 and p.y < -0.3


func cellar_stairs(team: int) -> Array:
	## [bottom, top] of the stairs from the cellar up into the keep.
	var side := -1.0 if team == 0 else 1.0
	var bx := side * (CASTLE_X + CASTLE_DEPTH)
	return [Vector3(bx + side * 8.6, CELLAR_Y, 0), Vector3(bx - side * 1.6, 0.0, 0)]


func _inside_castle(team: int, p: Vector3) -> bool:
	var side := -1.0 if team == 0 else 1.0
	var fx := side * (CASTLE_X - CASTLE_DEPTH)
	var bx := side * (CASTLE_X + CASTLE_DEPTH)
	return (p.x - fx) * side > 0.0 and (bx - p.x) * side > 0.0 and absf(p.z) < CASTLE_HALF_Z + 0.5


func enemy_inside_keep(team: int) -> bool:
	for u in units:
		if u.team != team and not u.dead and _inside_keep(team, u.global_position):
			return true
	return false


func defender_near(team: int, pos: Vector3, radius: float) -> bool:
	for u in units:
		if u.team == team and not u.dead and _flat_dist(u.global_position, pos) < radius:
			return true
	return false


func toast(text: String, color: Color = Color.WHITE) -> void:
	## A small, short notice under the clock (not the big announcement).
	toasts.append({"text": text, "color": color, "time": Time.get_ticks_msec() / 1000.0})
	if toasts.size() > 4:
		toasts.pop_front()


func enemy_inside_castle(team: int) -> bool:
	var fx := _front_x(team)
	for u in units:
		if u.team == team or u.dead:
			continue
		if _inside_castle(team, u.global_position) \
				or (absf(u.global_position.x - fx) < 1.5 and absf(u.global_position.z) < Stats.DOOR_HALF + 0.5):
			return true
	return false


func _plan_bots(team: int) -> void:
	## Lightweight squad planner, once a second per team: every bot starts from
	## its lineup job, then the match state pulls the nearest few onto the
	## thing that matters most (recover our crown, escort our carrier, defend
	## the castle). Everyone else keeps attacking.
	var mine = monarchs[team]
	var theirs = monarchs[1 - team]
	var bots := []
	for u in units:
		if u.team == team and not u.dead and not u.is_player:
			u.bot_job = u.base_job
			u.job_target = Vector3.INF
			bots.append(u)
	if bots.is_empty():
		return
	var side := -1.0 if team == 0 else 1.0
	if mine.state == Monarch.State.CARRIED:
		_assign_nearest(bots, mine.carrier.global_position, 3, "recover")
	elif mine.state == Monarch.State.DROPPED:
		_assign_nearest(bots, mine.global_position, 2, "recover")
	if theirs.state == Monarch.State.CARRIED and theirs.carrier.team == team:
		_assign_nearest(bots, theirs.carrier.global_position, 2, "escort")
	var gate_hurt: bool = gates[team].hp < Stats.GATE_HITS * 0.4
	if enemy_inside_keep(team):
		_assign_nearest(bots, thrones[team], 3, "defend")
	elif enemy_inside_castle(team) or gate_hurt:
		_assign_nearest(bots, Vector3(side * CASTLE_X, 0, 0), 2, "defend")


func _assign_nearest(bots: Array, pos: Vector3, count: int, job: String) -> void:
	## Give `job` to the `count` bots closest to `pos` that still hold their
	## lineup job. Healers stay on support: they follow the group instead.
	var free := []
	for u in bots:
		if u.bot_job == u.base_job and u.role != Unit.Role.HEALER:
			free.append(u)
	free.sort_custom(func(a, b): return _flat_dist(a.global_position, pos) < _flat_dist(b.global_position, pos))
	for i in mini(count, free.size()):
		free[i].bot_job = job
		free[i].job_target = pos


func defense_post(team: int, z_side: float) -> Vector3:
	## Where a defender stands: by the vault barricades when the enemy is in
	## the keep, else inside the yard just behind the door.
	var side := -1.0 if team == 0 else 1.0
	var z := -4.5 if z_side < 0.0 else 4.5
	if enemy_inside_keep(team):
		return thrones[team] + Vector3(-side * 5.5, 0, z)
	return Vector3(gates[team].position.x + side * 4.5, 0, z)


func nearest_cover(pos: Vector3, radius: float) -> Vector3:
	var best := Vector3.INF
	var best_d := radius
	for c in cover_points:
		var d := _flat_dist(c, pos)
		if d < best_d:
			best_d = d
			best = c
	return best


func enemies_near(team: int, pos: Vector3, radius: float) -> int:
	var n := 0
	for u in units:
		if u.team != team and not u.dead and _flat_dist(u.global_position, pos) < radius:
			n += 1
	return n


func allies_near(team: int, pos: Vector3, radius: float) -> int:
	var n := 0
	for u in units:
		if u.team == team and not u.dead and _flat_dist(u.global_position, pos) < radius:
			n += 1
	return n


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
	# Out of the spawn cellar: line up with the stairs, then climb them.
	for c in 2:
		if _in_cellar(c, from) and not _in_cellar(c, to):
			var st := cellar_stairs(c)
			var side := -1.0 if c == 0 else 1.0
			# On the lane: lined up with the stairs and not behind their foot.
			var on_lane: bool = absf(from.z) < 1.3 and (from.x - st[0].x) * side < 0.4
			if on_lane:
				return st[1]
			if (from.x - st[0].x) * side < 0.6:
				return st[0]  # behind the foot of the stairs: step across to the lane
			return Vector3(st[0].x + side * 0.3, CELLAR_Y, from.z)  # walk straight back to the foot first
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
			var spawn := Vector3(side * (CASTLE_X + CASTLE_DEPTH + 8.6), CELLAR_Y, -4.0 + i * 2.0)
			var is_player := t == player_team and i == 0 and not demo
			u.setup(self, t, is_player, spawn)
			u.bot_class = LINEUP[i][0]
			u.bot_job = LINEUP[i][1]
			u.base_job = LINEUP[i][1]
			u.display_name = (hero_name if hero_name.strip_edges() != "" else "You") if is_player else Stats.BOT_NAMES[t][i % Stats.BOT_NAMES[t].size()]
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


func hero_custom() -> Dictionary:
	## The player's chosen hair and trim colours for the character skin.
	var c := {"hair": Stats.HERO_HAIR[hero_hair][1]}
	if hero_trim > 0:
		c.trim = Stats.HERO_TRIM[hero_trim][1]
	return c


func academy_pick(role: int) -> void:
	## Choose a class from the Academy panel (only inside your own courtyard).
	if player == null or player.dead or player.carrying or not _in_cellar(player_team, player.global_position):
		return
	if player.role != role:
		player.set_role(role)
		spawn_pillar(player.global_position, Stats.ROLES[role].color, 3.0, 0.8)
		announce("You are now a %s." % player.role_name())


func in_academy() -> bool:
	return player != null and playing and not player.dead and _in_cellar(player_team, player.global_position)


func guide_toggle() -> void:
	if guide_open:
		guide_advance()
		return
	guide_open = true
	guide_topic = -1
	guide_page = -1 if guide_seen else 0


func guide_advance() -> void:
	## Interact while talking: next intro page, or back to the topic menu.
	if guide_topic >= 0:
		guide_topic = -1
		guide_page = -1
	elif guide_page >= 0:
		guide_page += 1
		if guide_page >= Guide.INTRO.size():
			guide_page = -1
			guide_seen = true


func guide_pick(i: int) -> void:
	if guide_open and guide_page < 0 and i >= 0 and i < Guide.TOPICS.size():
		guide_topic = i


func guide_close() -> void:
	guide_open = false
	guide_seen = true


func guide_answer(i: int) -> String:
	## A topic's answer with the current key labels filled in.
	var text: String = Guide.TOPICS[i][1]
	match i:
		1:
			return text % [key_label("attack"), key_label("ability_1"), key_label("ability_2"), key_label("dodge"), key_label("block")]
		3:
			return text % key_label("rank_menu")
		4:
			return text % key_label("interact")
	return text


func _tick_tutorial() -> void:
	## Tick off the HOW TO WIN steps as the player does them; the list folds
	## away once the Crown has been carried home.
	if player == null or demo:
		return
	var p: Vector3 = player.global_position
	var e := 1 - player_team
	if not _inside_castle(player_team, p) and not _in_cellar(player_team, p):
		tutorial[0] = true
	if absf(p.x) < 18.0:
		tutorial[1] = true
	if not gates[e].is_intact():
		tutorial[2] = true
	if _inside_keep(e, p):
		tutorial[3] = true
	if _inside_keep(e, p) and not vaults[e].is_locked():
		tutorial[4] = true
	if player.carrying:
		tutorial[5] = true
	if score[player_team] >= 1:
		tutorial[6] = true
	if score[player_team] >= 2:
		tutorial[7] = true
	tutorial_shown = not tutorial[6]
	# The Upgrade Station: standing on it opens the perk menu.
	var pad: Vector3 = upgrade_pads[player_team]
	var on_pad: bool = pad != Vector3.INF and _flat_dist(p, pad) < STATION_RADIUS and not player.dead
	if on_pad and not on_upgrade_pad and not menu_open and not chat_open:
		rank_open = true
	elif not on_pad and on_upgrade_pad and rank_open:
		rank_open = false
	on_upgrade_pad = on_pad


func menu_blocks_input() -> bool:
	return menu_open or rank_open or chat_open or guide_open


func menu_tabs() -> Array:
	## Which menu tabs make sense now: at the title only Classes and Controls.
	return [1, 4] if not playing else [0, 3, 1, 2, 4]


func menu_tick() -> void:
	## Called every frame by the HUD, which keeps running while paused.
	if game_over:
		return
	var eaten: bool = Engine.get_process_frames() == swallow_frame
	if not playing:
		# Title screen: the options menu (controls, classes), bot difficulty.
		if not eaten and rebinding == "":
			if Input.is_action_just_pressed("options") and not menu_open:
				menu_open = true
				menu_tab = 4
			elif Input.is_action_just_pressed("menu") and menu_open:
				menu_open = false
			elif not menu_open:
				if Input.is_action_just_pressed("menu_left"):
					cycle_difficulty(-1)
				if Input.is_action_just_pressed("menu_right"):
					cycle_difficulty(1)
	elif chat_open:
		pass  # typing: keys go to menu_input
	else:
		if Input.is_action_just_pressed("menu") and not eaten and rebinding == "" and not guide_open:
			menu_open = not menu_open
			rank_open = false
			get_tree().paused = menu_open
		scoreboard_open = (Input.is_action_pressed("scoreboard") or debug_score) and not menu_open and not rank_open
		if menu_open:
			if Input.is_action_just_pressed("quit_match") and rebinding == "":
				get_tree().paused = false
				get_tree().reload_current_scene()
		elif guide_open and not eaten:
			if Input.is_action_just_pressed("menu"):
				guide_close()
			for i in Guide.TOPICS.size():
				if Input.is_action_just_pressed("rank_%d" % (i + 1)):
					guide_pick(i)
		elif Input.is_action_just_pressed("rank_menu") and player and not demo:
			rank_open = not rank_open
		elif Input.is_action_just_pressed("chat") and player and not demo and not eaten:
			chat_open = true
			chat_text = ""
			rank_open = false
		if Input.is_action_just_pressed("chat_toggle") and not menu_open and not eaten:
			chat_visible = not chat_visible
			_save_settings()
		if Input.is_action_just_pressed("roster_toggle") and not menu_open and not eaten:
			rosters_visible = not rosters_visible
			_save_settings()
		# The Academy: in your own courtyard, 1-4 pick a class outright.
		if player and not rank_open and not guide_open and not player.dead and player.carrying == null and _in_cellar(player_team, player.global_position):
			for i in 4:
				if Input.is_action_just_pressed("rank_%d" % (i + 1)):
					academy_pick(i + 1)
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
		for b in hud.difficulty_buttons:
			if b[0].has_point(mouse):
				bot_difficulty = b[1]
				_save_settings()
		if hud.options_button.has_point(mouse) and not playing:
			menu_open = true
			menu_tab = 4
		if not playing and not menu_open:
			var was_editing := name_editing
			name_editing = false
			for b in hud.hero_buttons:
				if b[0].has_point(mouse):
					match b[1]:
						"hair": hero_hair = b[2]
						"trim": hero_trim = b[2]
						"name": name_editing = true
					if not name_editing:
						_save_settings()
			if was_editing and not name_editing:
				hero_name = hero_name.strip_edges()
				_save_settings()
			for b in hud.faction_buttons:
				if b[0].has_point(mouse) and not was_editing:
					_start_match(b[1])
		for b in hud.academy_buttons:
			if b[0].has_point(mouse):
				academy_pick(b[1])
		for b in hud.guide_buttons:
			if b[0].has_point(mouse):
				if b[1] == "next":
					guide_advance()
				elif b[1] == "close":
					guide_close()
				else:
					guide_pick(int(b[1]))
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
	if name_editing and event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE:
				name_editing = false
				hero_name = hero_name.strip_edges()
				_save_settings()
				swallow_frame = Engine.get_process_frames()
			KEY_BACKSPACE:
				hero_name = hero_name.left(maxi(hero_name.length() - 1, 0))
			_:
				var ch := char(event.unicode)
				if event.unicode >= 32 and hero_name.length() < Stats.HERO_NAME_MAX and ch.strip_edges() != "" or ch == " ":
					hero_name += ch
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
	return u.kills * Stats.SCORE_KILL + u.assists * Stats.SCORE_ASSIST + u.captures * Stats.SCORE_CAPTURE + u.healing * Stats.SCORE_HEAL \
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


func cycle_difficulty(step: int) -> void:
	var i: int = Stats.BOT_DIFFICULTIES.find(bot_difficulty)
	bot_difficulty = Stats.BOT_DIFFICULTIES[posmod(i + step, Stats.BOT_DIFFICULTIES.size())]
	_save_settings()


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(CONTROLS_PATH)
	cfg.set_value("settings", "bot_difficulty", bot_difficulty)
	cfg.set_value("settings", "chat_visible", chat_visible)
	cfg.set_value("settings", "rosters_visible", rosters_visible)
	cfg.set_value("settings", "hero_name", hero_name)
	cfg.set_value("settings", "hero_hair", hero_hair)
	cfg.set_value("settings", "hero_trim", hero_trim)
	cfg.save(CONTROLS_PATH)


func _save_controls() -> void:
	var cfg := ConfigFile.new()
	cfg.load(CONTROLS_PATH)
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
	var diff: String = cfg.get_value("settings", "bot_difficulty", "Normal")
	if diff in Stats.BOT_DIFFICULTIES:
		bot_difficulty = diff
	chat_visible = cfg.get_value("settings", "chat_visible", true)
	rosters_visible = cfg.get_value("settings", "rosters_visible", true)
	hero_name = cfg.get_value("settings", "hero_name", "")
	hero_hair = clampi(cfg.get_value("settings", "hero_hair", 0), 0, Stats.HERO_HAIR.size() - 1)
	hero_trim = clampi(cfg.get_value("settings", "hero_trim", 0), 0, Stats.HERO_TRIM.size() - 1)
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


func _stone(tint: Color = Color.WHITE, scale: float = 0.26) -> StandardMaterial3D:
	return _pbr("stone", scale, tint)


func _grass() -> StandardMaterial3D:
	return _pbr("grass", 0.16, Color(0.95, 1.0, 0.88))


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
	audit_props.append([name, inst])
	return inst


func _add_path(from: Vector3, to: Vector3, width: float, mat: Material) -> void:
	## A flat strip of road or dirt from one point to another (any angle).
	var d := to - from
	d.y = 0.0
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(d.length() + width * 0.6, 0.012, width)
	m.mesh = box
	m.material_override = mat
	m.position = (from + to) / 2.0 + Vector3(0, 0.006, 0)
	m.rotation.y = atan2(-d.z, d.x)
	add_child(m)
	map_paths.append([from, to, width])


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
	audit_blocks.append([audit_label if audit_label != "" else ("wall" if solid else "block"), AABB(pos - size / 2.0, size)])
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


func _add_ramp(from: Vector3, to: Vector3, width: float, color: Color, mat: Material = null) -> void:
	## A solid slab whose top surface runs from `from` up to `to`.
	var dir := to - from
	var wx := 0.0 if absf(dir.x) >= absf(dir.z) else width / 2.0
	var wz := width / 2.0 if absf(dir.x) >= absf(dir.z) else 0.0
	var lo := Vector3(minf(from.x, to.x) - wx, minf(from.y, to.y) - 0.4, minf(from.z, to.z) - wz)
	var hi := Vector3(maxf(from.x, to.x) + wx, maxf(from.y, to.y), maxf(from.z, to.z) + wz)
	audit_blocks.append(["ramp", AABB(lo, hi - lo)])
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
	mesh.material_override = mat if mat else _stone(color, 0.3)
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


func _add_ground_detail() -> void:
	## Life on the ground, kept off the lanes: flowers, grass tufts, small
	## stones, mushrooms under the trees and fallen leaves. Elven ground
	## (west) gets glowing blooms and mushrooms; human ground (east) gets
	## stones, leaf litter and plain wildflowers. All MultiMeshes.
	var r := RandomNumberGenerator.new()
	r.seed = 1234
	var flower := SphereMesh.new()
	flower.radius = 0.1
	flower.height = 0.16
	flower.radial_segments = 6
	flower.rings = 3
	var tuft := CylinderMesh.new()
	tuft.top_radius = 0.0
	tuft.bottom_radius = 0.2
	tuft.height = 0.42
	tuft.radial_segments = 5
	var stone := _rock_mesh(77, 0.26, 0.25)
	var cap := CylinderMesh.new()
	cap.top_radius = 0.08
	cap.bottom_radius = 0.17
	cap.height = 0.12
	cap.radial_segments = 7
	var leaf := PlaneMesh.new()
	leaf.size = Vector2(0.34, 0.26)
	var sets := [
		["flower", flower, 650, 0.14], ["tuft", tuft, 900, 0.18], ["stone", stone, 220, 0.0], ["cap", cap, 140, 0.26], ["leaf", leaf, 520, 0.02]]
	for s in sets:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = s[1]
		var placed: Array = []
		var tries := 0
		while placed.size() < s[2] and tries < s[2] * 12:
			tries += 1
			var p: Vector3
			if s[0] == "leaf" or s[0] == "cap":
				var t: Vector3 = map_trees[r.randi() % map_trees.size()]
				var a := r.randf() * TAU
				var d := r.randf_range(0.8, 3.2)
				p = Vector3(t.x + cos(a) * d, 0, t.z + sin(a) * d)
			else:
				p = Vector3(r.randf_range(-map_half.x + 4.0, map_half.x - 4.0), 0, r.randf_range(-map_half.y + 2.0, map_half.y - 2.0))
			if not _open_ground(p):
				continue
			placed.append(p)
		mm.instance_count = placed.size()
		for i in placed.size():
			var p: Vector3 = placed[i]
			var elf_side: bool = p.x < 0.0
			var sc := r.randf_range(0.7, 1.3)
			var basis := Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3(sc, sc * r.randf_range(0.8, 1.2), sc))
			var col: Color
			match s[0]:
				"flower":
					col = [Color(0.98, 0.9, 0.45), Color(0.98, 0.98, 1.0), Color(0.95, 0.55, 0.65), Color(0.6, 0.8, 1.0), Color(0.95, 0.55, 0.25)][r.randi() % 5]
					if elf_side and r.randf() < 0.35:
						col = Color(0.5, 0.95, 1.0)  # glowing wildwood bloom
				"tuft":
					col = Color.from_hsv(0.26 + r.randf_range(-0.03, 0.03), 0.7, r.randf_range(0.45, 0.7))
				"stone":
					col = Color(0.6, 0.6, 0.58).lerp(Color(0.5, 0.52, 0.5), r.randf())
					if elf_side and r.randf() < 0.3:
						col = Color(0.55, 0.62, 0.5)
				"cap":
					col = Color(0.85, 0.25, 0.2) if r.randf() < 0.6 else Color(0.8, 0.65, 0.45)
					if elf_side and r.randf() < 0.4:
						col = Color(0.45, 0.85, 0.95)
				"leaf":
					col = [Color(0.8, 0.45, 0.15), Color(0.65, 0.3, 0.1), Color(0.85, 0.65, 0.2), Color(0.4, 0.55, 0.2)][r.randi() % 4]
			mm.set_instance_transform(i, Transform3D(basis, p + Vector3(0, s[3], 0)))
			mm.set_instance_color(i, col)
		var inst := MultiMeshInstance3D.new()
		inst.multimesh = mm
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.roughness = 0.9
		if s[0] == "flower" or s[0] == "cap":
			mat.emission_enabled = true
			mat.emission = Color(0.3, 0.6, 0.7)
			mat.emission_energy_multiplier = 0.25
		inst.material_override = mat
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(inst)
		if s[0] == "cap":
			# Stems under the caps.
			var stems := MultiMesh.new()
			stems.transform_format = MultiMesh.TRANSFORM_3D
			var stem := CylinderMesh.new()
			stem.top_radius = 0.05
			stem.bottom_radius = 0.06
			stem.height = 0.26
			stem.radial_segments = 5
			stems.mesh = stem
			stems.instance_count = placed.size()
			for i in placed.size():
				stems.set_instance_transform(i, Transform3D(Basis.IDENTITY, placed[i] + Vector3(0, 0.13, 0)))
			var si := MultiMeshInstance3D.new()
			si.multimesh = stems
			si.material_override = _material(Color(0.9, 0.86, 0.75))
			si.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(si)


func _open_ground(p: Vector3) -> bool:
	## Grass that is not a lane: off the roads and paths, out of the river,
	## the island, the castles and their yards, and not inside a tree trunk.
	if absf(p.x) < RIVER_HALF + 1.4 or _flat_dist(p, Vector3.ZERO) < ISLAND_R + 1.5:
		return false
	if absf(p.x) > CASTLE_X - CASTLE_DEPTH - 2.0:
		return false
	for bz in BRIDGES:
		if absf(p.z - bz) < 4.5 and absf(p.x) < RIVER_HALF + 4.0:
			return false
	for path in map_paths:
		var a: Vector3 = path[0]
		var b: Vector3 = path[1]
		var ab := Vector2(b.x - a.x, b.z - a.z)
		var t := clampf(Vector2(p.x - a.x, p.z - a.z).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		var q := Vector2(a.x, a.z) + ab * t
		if Vector2(p.x, p.z).distance_to(q) < path[2] / 2.0 + 0.7:
			return false
	for mark in map_marks:
		if _flat_dist(p, mark[0]) < 5.0:
			return false
	for t in map_trees:
		if _flat_dist(p, t) < 0.7:
			return false
	for c in cover_points:
		if _flat_dist(p, c) < 1.6:
			return false
	for orb in heal_orbs:
		if _flat_dist(p, orb.global_position) < 1.5:
			return false
	return true


func _add_tree(pos: Vector3, big: bool = false) -> void:
	map_trees.append(Vector3(pos.x, 1.0 if big else 0.0, pos.z))
	# Human woodland (east) mixes in KayKit oaks and pines so the two sides
	# read differently; the elven Wildwood keeps its grown, glowing trees.
	var tree_seed := absi(int(pos.x * 13 + pos.z * 7))
	if pos.x > 8.0 and tree_seed % 3 != 0:
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
		var kind := "hex/tree_single_%s" % ["A", "B"][tree_seed % 2]
		_prop(kind, pos, (5.2 if big else 4.2) * (0.9 + 0.2 * float(tree_seed % 5) / 4.0), float(tree_seed))
		return
	_add_tree_grown(pos, big)


func _add_tree_grown(pos: Vector3, big: bool = false) -> void:
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
	var radius: float = (1.9 if big else 1.4) * r.randf_range(0.9, 1.1) * (1.15 if pos.x < -8.0 else 1.0)
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
	if (seed % 3 == 0 or pos.x < -8.0) and not autumn:
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
			if not _near_bridge(z, 2.5) and absf(absf(z) - 25.5) > 5.5 and absf(z) < 34.0:
				_prop("hex/rock_single_%s" % ["A", "B", "C", "D", "E"][k % 5], Vector3(sx * (RIVER_HALF + 0.8 + fmod(z * 7.3, 1.0)), 0, z), 2.5, z)
			k += 1
			z += 2.6
		# Bank walls between the bridges.
		var edges: Array = [-length / 2.0]
		for i in BRIDGES.size():
			edges.append(BRIDGES[i] - BRIDGE_HALF[i] - 0.3)
			edges.append(BRIDGES[i] + BRIDGE_HALF[i] + 0.3)
		edges.append(length / 2.0)
		for i in range(0, edges.size(), 2):
			var z0: float = edges[i]
			var z1: float = edges[i + 1]
			_add_bank_wall(sx, z0, z1, 1.0, 2.0)
		# Along the island the bank wall stays below the plateau top: it keeps
		# walkers on the bank out of the water, but anyone up on the shrine
		# walks straight over it.
		_add_bank_wall(sx, -ISLAND_R - 0.4, ISLAND_R + 0.4, -0.05, 1.0)
	_add_island()
	# Low stone rims on the island's north and south edges so nobody walks
	# off the shrine into the river channel (there is no way back up).
	for zs in [-1.0, 1.0]:
		var rz: float = zs * (ISLAND_R - 0.3)
		_add_block(Vector3(0, 0.75, rz), Vector3(RIVER_HALF * 2 + 1.6, 0.5, 0.5), Color(0.6, 0.58, 0.52), true, _pbr("stone", 0.5, Color(0.7, 0.68, 0.62)))
	# Bridges: a plank deck with rails and posts.
	for i in BRIDGES.size():
		if i == 1:
			continue  # the shrine island is the middle crossing
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


func _add_bank_wall(sx: float, z0: float, z1: float, y: float, h: float) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = BANK_LAYER
	body.collision_mask = 0
	body.position = Vector3(sx * (RIVER_HALF + 0.2), y, (z0 + z1) / 2.0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.4, h, z1 - z0)
	shape.shape = box
	body.add_child(shape)
	add_child(body)


func _add_island() -> void:
	## The Crown Shrine: a round stone plateau in the middle of the river,
	## reached by a flight of steps from each bank. Blessings favour it.
	var plateau := StaticBody3D.new()
	plateau.position = Vector3(0, 0.25, 0)
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = ISLAND_R
	cyl.height = 0.5
	shape.shape = cyl
	plateau.add_child(shape)
	var mesh := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = ISLAND_R
	cm.bottom_radius = ISLAND_R + 0.6
	cm.height = 0.5
	cm.radial_segments = 24
	mesh.mesh = cm
	mesh.material_override = _pbr("cobble", 0.4, Color(0.85, 0.82, 0.75))
	plateau.add_child(mesh)
	add_child(plateau)
	# A paved ring and the shrine: a stepped dais, a gold crown on a plinth, four braziers.
	var dais := MeshInstance3D.new()
	var dm := CylinderMesh.new()
	dm.top_radius = 2.2
	dm.bottom_radius = 2.6
	dm.height = 0.3
	dais.mesh = dm
	dais.position = Vector3(0, 0.65, 0)
	dais.material_override = _stone(Color(0.9, 0.88, 0.8), 0.3)
	add_child(dais)
	_add_collider(Vector3(0, 1.2, 0), Vector3(1.6, 1.6, 1.6))
	_add_block(Vector3(0, 1.2, 0), Vector3(1.2, 0.9, 1.2), Color(0.8, 0.78, 0.7), false, _stone(Color(0.95, 0.9, 0.8), 0.3))
	var crown := MeshInstance3D.new()
	var crown_mesh := CylinderMesh.new()
	crown_mesh.top_radius = 0.55
	crown_mesh.bottom_radius = 0.42
	crown_mesh.height = 0.5
	crown_mesh.radial_segments = 8
	crown.mesh = crown_mesh
	crown.position = Vector3(0, 1.95, 0)
	var gold := _material(Color(1.0, 0.8, 0.25))
	gold.metallic = 0.9
	gold.roughness = 0.25
	gold.emission_enabled = true
	gold.emission = Color(1.0, 0.7, 0.2)
	gold.emission_energy_multiplier = 0.6
	crown.material_override = gold
	add_child(crown)
	for i in 8:
		var a := TAU * i / 8.0
		var spike := MeshInstance3D.new()
		var sm := CylinderMesh.new()
		sm.top_radius = 0.0
		sm.bottom_radius = 0.1
		sm.height = 0.35
		spike.mesh = sm
		spike.position = Vector3(cos(a) * 0.5, 2.35, sin(a) * 0.5)
		spike.material_override = gold
		add_child(spike)
	var shrine_light := OmniLight3D.new()
	shrine_light.light_color = Color(1.0, 0.8, 0.4)
	shrine_light.light_energy = 2.0
	shrine_light.omni_range = 9.0
	shrine_light.position = Vector3(0, 3.0, 0)
	add_child(shrine_light)
	for i in 4:
		var a := TAU * i / 4.0 + PI / 4.0
		_add_torch(Vector3(cos(a) * 4.2, 0.5, sin(a) * 4.2))
		_prop("dungeon/column", Vector3(cos(a) * 5.0, 0.5, sin(a) * 5.0), 0.9)
	map_marks.append([Vector3.ZERO, "shrine"])
	# Steps up from each bank, and a short pier of planks over the water's edge.
	for sx in [-1.0, 1.0]:
		_add_ramp(Vector3(sx * (ISLAND_R + 3.2), 0.0, 0), Vector3(sx * (ISLAND_R - 0.4), 0.5, 0), 4.0, Color(0.85, 0.82, 0.75))
		_add_torch(Vector3(sx * (ISLAND_R + 3.4), 0, -2.4))
		_add_torch(Vector3(sx * (ISLAND_R + 3.4), 0, 2.4))


func _near_bridge(z: float, margin: float) -> bool:
	for i in BRIDGES.size():
		if absf(z - BRIDGES[i]) < BRIDGE_HALF[i] + margin:
			return true
	return false


func _add_cover() -> void:
	## Low barricades and boulders in the contested middle. Shots stop at
	## them, so there is always somewhere to duck. Everything is mirrored.
	var barricades := [[Vector3(11, 0, 5), 3.5], [Vector3(12, 0, -7), 3.5], [Vector3(20, 0, 1), 4.0],
		[Vector3(18, 0, 12), 3.0], [Vector3(30, 0, -5), 3.5], [Vector3(28, 0, 8), 3.0], [Vector3(31, 0, 19), 3.0], [Vector3(17, 0, -20), 3.0]]
	var crates := ["hex/crate_A_big", "hex/crate_B_big", "hex/barrel", "hex/crate_A_big", "hex/sack"]
	for b in barricades:
		for m in [1.0, -1.0]:
			var c: Vector3 = b[0] * m
			var length: float = b[1]
			_add_collider(Vector3(c.x, 0.6, c.z), Vector3(1.0, 1.2, length))
			cover_points.append(Vector3(c.x, 0, c.z))
			var n := int(length / 1.15)
			for i in n:
				var z: float = c.z - length / 2.0 + (i + 0.5) * length / n
				var pick: int = absi(int(c.x * 3 + z * 5 + i)) % crates.size()
				_prop(crates[pick], Vector3(c.x, 0, z), 5.2, float(i) * 0.15)
				if i % 2 == 0:
					_prop("hex/crate_A_big", Vector3(c.x, 1.05, z), 4.2, float(i) * 0.15 + 0.1)
	var boulders := [Vector3(7, 0, -13), Vector3(13, 0, -18), Vector3(22, 0, 14), Vector3(33, 0, -8), Vector3(38, 0, 10),
		Vector3(8, 0, 28), Vector3(17, 0, 25), Vector3(14, 0, -36), Vector3(26, 0, -27), Vector3(40, 0, -22), Vector3(40, 0, 24)]
	for p in boulders:
		_add_boulder(p)
		_add_boulder(-p)
		cover_points.append(p)
		cover_points.append(-p)
	# The Northern Ruins: broken columns and rubble by the north bridge, and
	# a smaller ruin on the south river path. Mirrored.
	_add_ruins(Vector3(11, 0, -25))
	_add_ruins(Vector3(-11, 0, 25))
	_add_ruins(Vector3(-24, 0, -29), true)
	_add_ruins(Vector3(24, 0, 29), true)


func _add_ruins(c: Vector3, small: bool = false) -> void:
	map_marks.append([c, "ruin"])
	var n := 3 if small else 6
	for i in n:
		var a := TAU * i / n + c.x * 0.1
		var p := c + Vector3(cos(a) * 3.6, 0, sin(a) * 3.0)
		if i % 2 == 0:
			_prop("dungeon/column", p, 1.3 + 0.2 * (i % 3), a)
			_add_collider(p + Vector3(0, 1.0, 0), Vector3(0.9, 2.0, 0.9))
		else:
			_prop("dungeon/rubble_large", p, 0.4, a)
			_add_collider(p + Vector3(0, 0.5, 0), Vector3(1.6, 1.0, 1.6))
	_add_block(c + Vector3(0, 0.02, 0), Vector3(8.0 if not small else 5.0, 0.03, 6.5 if not small else 4.0), Color.WHITE, false, _flagstone(Color(0.9, 0.88, 0.84)))
	if not small:
		_prop("dungeon/barrier", c + Vector3(0, 0, 0.2), 0.8, 0.3)
		_add_collider(c + Vector3(0, 0.6, 0.2), Vector3(2.2, 1.2, 0.6))
		_add_bush(c + Vector3(3.8, 0, 2.2), int(c.x))
		_add_bush(c + Vector3(-3.6, 0, -2.4), int(c.z))


func _add_heal_orbs() -> void:
	## Healing orbs at fixed spots: the road's centre, the field's flanks, and
	## one in each castle yard. Mirrored for fairness.
	var spots := [Vector3(9, 0, -22), Vector3(22, 0, 9), Vector3(30, 0, -14), Vector3(CASTLE_X - CASTLE_DEPTH + 4.5, 0, 0), Vector3(16, 0, 27)]
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
	audit_label = "pole"
	_add_block(pos + Vector3(0, 0.9, 0), Vector3(0.2, 1.8, 0.2), Color.WHITE, false, _timber(Color(0.6, 0.5, 0.4)))
	audit_label = ""
	_add_block(pos + Vector3(0, 0.08, 0), Vector3(0.5, 0.16, 0.5), Color.WHITE, false, _ashlar(Color(0.85, 0.8, 0.72)))
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
	# The second piece lies towards the stairs (-s), clear of the wall stores.
	var s := 1.0 if team == 0 else -1.0
	match role:
		Role.KNIGHT:
			_prop("gear/sword_1handed", pos + Vector3(-s * 0.35, 0.5, -0.25), 1.2, 0.4).rotation.x = -PI / 2.0 + 0.4
			_prop("gear/shield_badge_color", pos + Vector3(s * 0.75, 0.55, 0.3), 1.0, 0.6)
		Role.RANGER:
			_prop("gear/quiver", pos + Vector3(-s * 0.2, 0.15, 0), 1.6, 0.8).rotation.x = 0.6
			_prop("gear/arrow_bundle", pos + Vector3(s * 0.85, 0.2, 0.45), 1.6, 0.3).rotation.x = 1.2
		Role.MAGE:
			_prop("gear/staff", pos + Vector3(0, 0.3, 0), 1.6, 1.0).rotation.x = 1.0
		Role.HEALER:
			_prop("gear/spellbook_open", pos + Vector3(0, 0.3, 0), 1.8, 0.4)
			_prop("gear/wand", pos + Vector3(s * 1.1, 0.25, 0.8), 1.6, 1.2).rotation.x = 1.3


# --- The castle kit -----------------------------------------------------------
# Every castle piece is built from the same three materials so both bases read
# as one art style (the reference renders): cream ashlar stone, warm timber and
# the team colour on roofs, rugs and banners. Props are placed with clearance
# from every wall; `--audit` lists anything that still overlaps.

func _ashlar(tint: Color = Color.WHITE) -> StandardMaterial3D:
	return _pbr("stone", 0.42, tint * Color(0.93, 0.9, 0.84))


func _flagstone(tint: Color = Color.WHITE) -> StandardMaterial3D:
	return _pbr("flagstone", 0.42, tint * Color(0.95, 0.92, 0.86))


func _timber(tint: Color = Color.WHITE) -> StandardMaterial3D:
	return _pbr("wood", 0.8, tint)


func _cloth(color: Color) -> StandardMaterial3D:
	var m := _material(color)
	m.roughness = 1.0
	return m


func _gold() -> StandardMaterial3D:
	var m := _material(Color(0.95, 0.78, 0.3))
	m.metallic = 0.7
	m.roughness = 0.35
	return m


func _add_wall(center: Vector3, size: Vector3, merlons: bool = true) -> void:
	## A solid ashlar wall with a cornice and merlons along its long axis.
	_add_block(center, size, Color.WHITE, true, _ashlar())
	var top := center.y + size.y / 2.0
	var along_x := size.x >= size.z
	var length := size.x if along_x else size.z
	var thick := size.z if along_x else size.x
	_add_block(Vector3(center.x, top + 0.1, center.z), Vector3(size.x + 0.2, 0.2, size.z + 0.2), Color.WHITE, false, _ashlar(Color(0.92, 0.88, 0.8)))
	if not merlons:
		return
	var n := maxi(int(length / 1.3), 1)
	for k in n:
		var t := -length / 2.0 + (k + 0.5) * length / n
		var p := Vector3(center.x + t, top + 0.5, center.z) if along_x else Vector3(center.x, top + 0.5, center.z + t)
		var ms := Vector3(0.6, 0.6, thick) if along_x else Vector3(thick, 0.6, 0.6)
		_add_block(p, ms, Color.WHITE, false, _ashlar(Color(0.9, 0.86, 0.78)))


func _add_tower(pos: Vector3, team: int, side: float, width: float = 2.6, height: float = 5.4, flag: bool = true) -> void:
	## A square corner tower with a crenellated top and a team-coloured roof.
	var color: Color = Stats.FACTIONS[team].color
	_add_block(pos + Vector3(0, height / 2.0, 0), Vector3(width, height, width), Color.WHITE, true, _ashlar())
	_add_block(pos + Vector3(0, height + 0.15, 0), Vector3(width + 0.5, 0.3, width + 0.5), Color.WHITE, false, _ashlar(Color(0.92, 0.88, 0.8)))
	for xs in [-1.0, 1.0]:
		for zs in [-1.0, 1.0]:
			_add_block(pos + Vector3(xs * (width / 2.0), height + 0.6, zs * (width / 2.0)), Vector3(0.5, 0.6, 0.5), Color.WHITE, false, _ashlar(Color(0.9, 0.86, 0.78)))
	# The roof: a pyramid in the team colour with a gold cap.
	var roof := MeshInstance3D.new()
	var rm := CylinderMesh.new()
	rm.top_radius = 0.0
	rm.bottom_radius = width * 0.62
	rm.height = 2.0
	rm.radial_segments = 4
	roof.mesh = rm
	roof.rotation.y = PI / 4.0
	roof.position = pos + Vector3(0, height + 1.3, 0)
	var roof_mat := _material(color.lightened(0.05))
	roof_mat.roughness = 0.7
	roof.material_override = roof_mat
	add_child(roof)
	_add_block(pos + Vector3(0, height + 0.38, 0), Vector3(width * 0.95, 0.16, width * 0.95), Color.WHITE, false, _timber(Color(0.8, 0.72, 0.62)))
	if flag:
		_add_flag(pos + Vector3(0, height + 2.25, 0), team, side)


func _add_railing(from: Vector3, to: Vector3, skip: Array = []) -> void:
	## A timber railing: posts every 1.4 m and two rails, following the line
	## (and slope) from `from` to `to`. `skip` lists [z_min, z_max] gaps.
	var d := to - from
	var n := maxi(int(d.length() / 1.4), 1)
	var wood := _timber()
	var dark := _timber(Color(0.7, 0.6, 0.5))
	for k in n + 1:
		var p := from + d * (float(k) / n)
		var skipped := false
		for s in skip:
			if p.z >= s[0] and p.z <= s[1]:
				skipped = true
		if skipped:
			continue
		_add_block(p + Vector3(0, 0.5, 0), Vector3(0.14, 1.0, 0.14), Color.WHITE, false, dark)
	var flat := Vector3(d.x, 0, d.z)
	var count := 0
	for s in skip:
		count += 1
	if skip.is_empty():
		for y in [0.55, 0.9]:
			var rail := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(d.length(), 0.08, 0.1)
			rail.mesh = bm
			rail.position = (from + to) / 2.0 + Vector3(0, y, 0)
			rail.rotation.y = atan2(-flat.z, flat.x)
			rail.rotation.z = atan2(d.y, flat.length())
			rail.material_override = wood
			add_child(rail)
	else:
		# Rails in pieces around the gaps (straight railings only).
		var gaps := skip.duplicate()
		gaps.sort_custom(func(a, b): return a[0] < b[0])
		var zs: Array = [minf(from.z, to.z)]
		for s in gaps:
			zs.append(s[0])
			zs.append(s[1])
		zs.append(maxf(from.z, to.z))
		var k := 0
		while k + 1 < zs.size():
			var z0: float = zs[k]
			var z1: float = zs[k + 1]
			if absf(z1 - z0) > 0.3:
				for y in [0.55, 0.9]:
					_add_block(Vector3(from.x, from.y + y, (z0 + z1) / 2.0), Vector3(0.1, 0.08, absf(z1 - z0)), Color.WHITE, false, wood)
			k += 2


func _add_stairs(bottom: Vector3, top: Vector3, width: float, mat: Material, rail_side: float) -> void:
	## A solid ramp dressed as a flight of steps: treads across the slope and
	## a railing on `rail_side` (-1/+1 in z).
	_add_ramp(bottom, top, width, Color.WHITE, mat)
	var d := top - bottom
	var flat := Vector3(d.x, 0, d.z)
	var n := maxi(int(flat.length() / 0.5), 1)
	var edge := _timber(Color(0.62, 0.52, 0.42)) if mat is StandardMaterial3D and (mat as StandardMaterial3D).albedo_texture and (mat as StandardMaterial3D).albedo_texture.resource_path.contains("wood") else _ashlar(Color(0.82, 0.76, 0.66))
	for k in n:
		var p := bottom + d * ((k + 0.5) / float(n))
		var tread := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.08, 0.08, width)
		tread.mesh = bm
		tread.position = p + Vector3(0, 0.03, 0)
		tread.rotation.y = atan2(-flat.z, flat.x)
		tread.material_override = edge
		add_child(tread)
	var off := Vector3(0, 0, rail_side * (width / 2.0 - 0.08))
	_add_railing(bottom + off, top + off)


func _add_banner(team: int, pos: Vector3, out: Vector3, scale: float = 0.7, shield: bool = false) -> void:
	## A team banner hung on a wall. `pos` is on the wall's face, `out` the
	## direction away from the wall; the cloth hangs in front of it.
	var name := "dungeon/banner_%s%s" % ["shield_" if shield else "", ["green", "blue"][team]]
	_prop(name, pos, scale, atan2(out.x, out.z))


func _add_wall_torch(pos: Vector3, out: Vector3) -> void:
	## A torch in an iron bracket on a wall face.
	_prop("dungeon/torch_mounted", pos, 1.3, atan2(out.x, out.z))
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.72, 0.4)
	light.light_energy = 1.3
	light.omni_range = 6.0
	light.position = pos + out * 0.8 + Vector3(0, 0.7, 0)
	add_child(light)


func _add_rug(center: Vector3, size: Vector2, color: Color) -> void:
	## A team-coloured rug with a gold border.
	_add_block(center + Vector3(0, 0.015, 0), Vector3(size.x, 0.03, size.y), color, false, _cloth(color.darkened(0.15)))
	for xs in [-1.0, 1.0]:
		_add_block(center + Vector3(xs * (size.x / 2.0 - 0.12), 0.032, 0), Vector3(0.16, 0.01, size.y), color, false, _gold())
	for zs in [-1.0, 1.0]:
		_add_block(center + Vector3(0, 0.032, zs * (size.y / 2.0 - 0.12)), Vector3(size.x, 0.01, 0.16), color, false, _gold())


func _add_barricade(team: int, pos: Vector3, length: float, rot_y: float) -> void:
	var b := Barricade.new()
	add_child(b)
	b.setup(self, team, pos, length, rot_y)
	barricades.append(b)
	var along_x := absf(cos(rot_y)) > 0.5
	var fs := Vector3(length, 1.1, 0.4) if along_x else Vector3(0.4, 1.1, length)
	audit_blocks.append(["fence", AABB(pos - Vector3(fs.x / 2.0, 0, fs.z / 2.0), fs)])


func _add_upgrade_pad(team: int, pos: Vector3) -> void:
	upgrade_pads[team] = pos
	var color := Color(1.0, 0.8, 0.25)
	_add_block(pos + Vector3(0, 0.05, 0), Vector3(2.2, 0.1, 2.2), color.darkened(0.45), false, _flagstone(Color(0.7, 0.62, 0.5)))
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
	# An anvil on a timber block, like the upgrade station in the renders.
	_add_block(pos + Vector3(0, 0.4, 0), Vector3(0.7, 0.5, 0.7), Color.WHITE, false, _timber(Color(0.75, 0.65, 0.55)))
	var iron := _material(Color(0.3, 0.31, 0.35))
	iron.metallic = 0.6
	iron.roughness = 0.5
	_add_block(pos + Vector3(0, 0.8, 0), Vector3(1.0, 0.3, 0.42), Color.WHITE, false, iron)
	_add_block(pos + Vector3(0.45, 0.82, 0), Vector3(0.3, 0.2, 0.3), Color.WHITE, false, iron)
	var l := Label3D.new()
	l.text = "UPGRADE STATION"
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font_size = 22
	l.pixel_size = 0.012
	l.outline_size = 8
	l.modulate = color
	l.position = pos + Vector3(0, 1.6, 0)
	add_child(l)


func _build_castle(team: int) -> void:
	var side := -1.0 if team == 0 else 1.0
	var color: Color = Stats.FACTIONS[team].color
	var cx := side * CASTLE_X
	var fx := _front_x(team)                      # outer wall's front, facing the middle
	var bx := side * (CASTLE_X + CASTLE_DEPTH)    # outer wall's back
	var kx := _keep_x(team)                       # the keep's front
	var hz := CASTLE_HALF_Z
	var dh := Stats.DOOR_HALF
	var in_x := fx + side * 0.5                   # the front wall's inner face

	# --- The yard: sandstone flags inside the walls. ---
	_add_block(Vector3(cx, 0.01, 0), Vector3(CASTLE_DEPTH * 2, 0.02, hz * 2), color, false, _flagstone())

	# --- The outer wall ring: front wall with the gatehouse, side and back walls, corner towers. ---
	var seg := hz - (dh + 2.2)                    # front wall from the gatehouse tower to the corner
	for zs in [-1.0, 1.0]:
		_add_wall(Vector3(fx, WALL_H / 2.0, zs * (dh + 2.2 + seg / 2.0)), Vector3(1, WALL_H, seg), false)
		_add_wall(Vector3(cx, WALL_H / 2.0, zs * hz), Vector3(CASTLE_DEPTH * 2 + 1, WALL_H, 1))
		# The gatehouse: a tower either side of the door.
		_add_tower(Vector3(fx, 0, zs * (dh + 1.1)), team, side, 2.2, 5.0, false)
		_add_banner(team, Vector3(fx - side * 1.1, 1.0, zs * (dh + 1.1)), Vector3(-side, 0, 0), 0.6)
		_add_torch(Vector3(fx - side * 2.0, 0, zs * (dh + 0.6)))
		# Corner towers.
		_add_tower(Vector3(fx, 0, zs * hz), team, side)
		_add_tower(Vector3(bx, 0, zs * hz), team, side)
	# The back wall has an opening at the middle for the stairs up from the cellar.
	var seg_b := hz - 1.8
	for zs in [-1.0, 1.0]:
		_add_wall(Vector3(bx, WALL_H / 2.0, zs * (1.8 + seg_b / 2.0)), Vector3(1, WALL_H, seg_b))
	_add_block(Vector3(bx, WALL_H - 0.35, 0), Vector3(1, 0.7, 3.6), Color.WHITE, false, _ashlar(Color(0.9, 0.86, 0.78)))
	# The rampart: a timber deck along the front wall, a stone parapet with
	# crenellations on the outside and a railing on the yard side.
	_add_block(Vector3(fx, WALK_Y - 0.3, 0), Vector3(2.4, 0.6, hz * 2 - 2.0), Color.WHITE, true, _timber())
	_add_block(Vector3(fx - side * 1.05, WALK_Y + 0.25, 0), Vector3(0.3, 0.5, hz * 2 - 2.0), Color.WHITE, false, _ashlar(Color(0.9, 0.86, 0.78)))
	for k in 9:
		var pz := -hz + 1.0 + k * (hz * 2 - 2.0) / 8.0
		if absf(pz) > dh + 2.4 and absf(pz) < hz - 1.4:
			_add_block(Vector3(fx - side * 1.05, WALK_Y + 0.75, pz), Vector3(0.34, 0.5, 0.9), Color.WHITE, false, _ashlar(Color(0.9, 0.86, 0.78)))
	# The door's lintel: a timber beam and the team crest over the gate.
	_add_block(Vector3(fx, WALK_Y - 0.7, 0), Vector3(1.4, 0.3, dh * 2 + 0.6), Color.WHITE, false, _timber(Color(0.7, 0.6, 0.5)))
	var ramp_gap := [[hz - 3.7, hz - 1.3], [-(hz - 1.3), -(hz - 3.7)]]
	_add_railing(Vector3(fx + side * 1.12, WALK_Y, -(hz - 1.3)), Vector3(fx + side * 1.12, WALK_Y, hz - 1.3),
		[[-(dh + 2.3), dh + 2.3], ramp_gap[1], ramp_gap[0]])

	# Stairs from the yard up to the rampart, along each side wall.
	ramps.append([])
	for zs in [-1.0, 1.0]:
		var z: float = zs * (hz - 2.5)
		var bottom := Vector3(fx + side * (KEEP_SETBACK - 1.5), 0.0, z)
		var top := Vector3(fx + side * 1.2, WALK_Y, z)
		_add_stairs(bottom + Vector3(0, -0.3, 0), top, 2.2, _timber(), -zs)
		ramps[team].append({"bottom": bottom, "top": top})
	# Archer posts on the rampart, either side of the gatehouse.
	wall_posts.append([Vector3(fx, WALK_Y, -(dh + 3.4)), Vector3(fx, WALK_Y, dh + 3.4)])

	# The breakable door.
	var gate = Gate.new()
	add_child(gate)
	gate.setup(self, team, fx)
	gates.append(gate)
	audit_blocks.append(["gate", AABB(Vector3(fx - 0.4, 0, -dh), Vector3(0.8, 3.0, dh * 2))])

	# --- The keep: the hall inside the wall, open to the sky, with a wide archway. ---
	var khz := KEEP_HALF_Z
	var kdepth := absf(bx - kx)
	var kcx := (kx + bx) / 2.0
	_add_block(Vector3(kcx, 0.03, 0), Vector3(kdepth, 0.04, khz * 2), Color.WHITE, false, _flagstone(Color(0.96, 0.94, 0.9)))
	# Side walls, each with a side door near the back (a second way out of the keep).
	for zs in [-1.0, 1.0]:
		_add_wall(Vector3(kx + side * (kdepth - 4.5) / 2.0, KEEP_H / 2.0, zs * khz), Vector3(kdepth - 4.5, KEEP_H, 0.8))
		_add_wall(Vector3(bx - side * 0.75, KEEP_H / 2.0, zs * khz), Vector3(1.5, KEEP_H, 0.8), false)
		_add_block(Vector3(bx - side * 3.0, KEEP_H - 0.3, zs * khz), Vector3(3.0, 0.6, 0.9), Color.WHITE, false, _timber(Color(0.7, 0.6, 0.5)))  # lintel
	var kseg := khz - KEEP_DOOR_HALF
	var kzc := KEEP_DOOR_HALF + kseg / 2.0
	for zs in [-1.0, 1.0]:
		_add_wall(Vector3(kx, KEEP_H / 2.0, zs * kzc), Vector3(0.8, KEEP_H, kseg))
		# Corner pillars of the keep.
		_add_block(Vector3(kx, KEEP_H / 2.0 + 0.4, zs * khz), Vector3(1.4, KEEP_H + 0.8, 1.4), Color.WHITE, true, _ashlar())
		_add_block(Vector3(bx - side * 0.2, KEEP_H / 2.0 + 0.4, zs * khz), Vector3(1.4, KEEP_H + 0.8, 1.4), Color.WHITE, true, _ashlar())
		# Banners either side of the archway and torches on the arch pillars.
		_add_banner(team, Vector3(kx - side * 0.4, -0.2, zs * (KEEP_DOOR_HALF + 1.6)), Vector3(-side, 0, 0), 0.75, true)
		_add_wall_torch(Vector3(kx - side * 0.4, 1.5, zs * (KEEP_DOOR_HALF + 0.3)), Vector3(-side, 0, 0))
	# Arch over the doorway, well above head height: stone, so from above the
	# keep's front reads as one wall line, with a timber beam underneath.
	_add_block(Vector3(kx, KEEP_H - 0.05, 0), Vector3(0.8, 0.5, KEEP_DOOR_HALF * 2 + 0.8), Color.WHITE, false, _ashlar())
	_add_block(Vector3(kx, KEEP_H - 0.42, 0), Vector3(0.9, 0.24, KEEP_DOOR_HALF * 2 + 0.8), Color.WHITE, false, _timber(Color(0.7, 0.6, 0.5)))
	_add_block(Vector3(kx, KEEP_H + 0.3, 0), Vector3(1.0, 0.2, KEEP_DOOR_HALF * 2 + 1.0), Color.WHITE, false, _ashlar(Color(0.92, 0.88, 0.8)))
	for k in 7:
		_add_block(Vector3(kx, KEEP_H + 0.7, -KEEP_DOOR_HALF + 0.75 + k * 1.25), Vector3(0.8, 0.6, 0.6), Color.WHITE, false, _ashlar(Color(0.9, 0.86, 0.78)))
	# A rug up the yard's lane to the archway, and one from the archway to the throne.
	_add_rug(Vector3(kx - side * 2.4, 0.02, 0), Vector2(3.6, 5.0), color)
	_add_rug(Vector3(kx + side * 3.0, 0.05, 0), Vector2(5.0, 2.8), color)

	# --- Life in the yard: a training corner north of the gate, stores south of it. ---
	# Training corner (z < 0): rack against the wall, a target across from it.
	_prop("hex/weaponrack", Vector3(in_x + side * 0.4, 0, -(dh + 3.0)), 4.0, PI / 2.0 if side > 0.0 else -PI / 2.0)
	_prop("hex/target", Vector3(in_x + side * 3.0, 0, -(dh + 3.0)), 4.0, PI / 2.0 if side < 0.0 else -PI / 2.0)
	_prop("hex/bucket_arrows", Vector3(in_x + side * 3.0, 0, -(dh + 1.9)), 4.0, 0.4)
	# Stores (z > 0): barrels and crates stacked against the wall.
	_prop("hex/barrel", Vector3(in_x + side * 0.5, 0, 6.45), 4.0)
	_prop("hex/barrel", Vector3(in_x + side * 0.5, 0, 7.45), 4.0, PI / 2.0)
	_prop("hex/barrel", Vector3(in_x + side * 1.4, 0, 6.95), 4.0, PI)
	_prop("hex/crate_A_big", Vector3(in_x + side * 2.1, 0, 7.7), 4.0, 0.0)
	_prop("hex/crate_B_big", Vector3(in_x + side * 2.1, 0.84, 7.7), 3.4, 0.2)
	_prop("hex/crate_long_A", Vector3(in_x + side * 3.2, 0, 7.7), 4.0, 0.0)
	_prop("hex/sack", Vector3(in_x + side * 2.5, 0, 6.5), 4.0, 0.5)
	# The strips between the keep's flanks and the side walls: more stores.
	for zs in [-1.0, 1.0]:
		var sz: float = zs * (hz - 1.0)
		_prop("hex/barrel", Vector3(kcx - side * 5.0, 0, sz), 4.0)
		_prop("hex/barrel", Vector3(kcx - side * 4.0, 0, sz), 4.0, PI / 2.0)
		_prop("hex/crate_A_big", Vector3(kcx - side * 2.6, 0, sz), 4.0, 0.3 * zs)
		_prop("hex/sack", Vector3(kcx - side * 1.6, 0, sz), 4.0, 1.1 * zs)
		_prop("hex/wheelbarrow", Vector3(kcx - side * 6.8, 0, zs * (hz - 1.2)), 4.0, PI / 2.0)
	# Banners on the yard side of the gatehouse towers.
	for zs in [-1.0, 1.0]:
		_add_banner(team, Vector3(fx + side * 1.1, 0.2, zs * (dh + 1.1)), Vector3(side, 0, 0), 0.6)
	# Inside the keep: columns along the side walls, torches, stacked stores at the back.
	for zs in [-1.0, 1.0]:
		_prop("dungeon/column", Vector3(kx + side * 4.0, 0, zs * (khz - 1.0)), 1.6)
		_prop("dungeon/column", Vector3(kx + side * 8.0, 0, zs * (khz - 1.0)), 1.6)
		_add_wall_torch(Vector3(kx + side * 2.0, 1.6, zs * (khz - 0.4)), Vector3(0, 0, -zs))
		_add_wall_torch(Vector3(kx + side * 6.0, 1.6, zs * (khz - 0.4)), Vector3(0, 0, -zs))
		_prop("dungeon/box_stacked", Vector3(kx + side * 11.2, 0, zs * (khz - 1.6)), 0.55, 0.0)
	# Faction flavour: elves grow greenery against their walls, humans post iron braziers.
	if team == 0:
		for zs in [-1.0, 1.0]:
			_add_bush(Vector3(fx - side * 1.9, 0, zs * (hz - 3.5)), int(zs) + 7)
			_add_bush(Vector3(fx - side * 2.3, 0, zs * (hz + 1.4)), int(zs) + 9)
			_add_bush(Vector3(kx - side * 1.2, 0, zs * (khz + 1.5)), int(zs) + 11)
	else:
		for zs in [-1.0, 1.0]:
			_add_torch(Vector3(kx - side * 1.3, 0, zs * (khz - 0.6)))

	# Throne on a dais inside the keep. Carry the enemy monarch here to score.
	var throne := Vector3(kx + side * 6.0, 0, 0)
	thrones.append(throne)
	_add_block(throne + Vector3(side * 1.5, 0.15, 0), Vector3(3, 0.3, 4), Color.WHITE, false, _ashlar(Color(0.95, 0.9, 0.8)))
	_add_block(throne + Vector3(side * 2.4, 1.2, 0), Vector3(0.4, 2.0, 1.6), color, false, _cloth(color.darkened(0.2)))
	_add_block(throne + Vector3(side * 2.4, 2.35, 0), Vector3(0.5, 0.3, 1.8), Color.WHITE, false, _gold())
	for z in [-4.6, 4.6]:
		_prop("dungeon/column", throne + Vector3(side * 2.0, 0, z), 1.6)
	_prop("dungeon/chest_gold", throne + Vector3(side * 1.0, 0, -5.6), 0.8, PI / 2.0 if side < 0.0 else -PI / 2.0)
	# The Crown Vault: a cage around the throne whose lock the enemy must break.
	var vault = Vault.new()
	add_child(vault)
	vault.setup(self, team, throne, side)
	vaults.append(vault)
	audit_blocks.append(["vault", AABB(throne + Vector3(-3.0, 0, -3.7), Vector3(6.0, 2.8, 7.4))])
	# Vault decor: elves grow crystals and fireflies, humans post guard shields and banners.
	if team == 0:
		for z in [-3.0, 3.0]:
			_add_crystal(throne + Vector3(side * 4.2, 0, z * 1.6), 1.0)
		_add_fireflies(throne)
	else:
		for z in [-1.0, 1.0]:
			_prop("dungeon/sword_shield", throne + Vector3(side * 5.0, 1.4, z * 4.6), 1.0, PI / 2.0 if side > 0.0 else -PI / 2.0)
	# Predefined defensive positions: low fences flanking the vault's front.
	for z in [-5.6, 5.6]:
		_add_barricade(team, throne + Vector3(-side * 4.0, 0, z), 2.4, 0.0)
		cover_points.append(throne + Vector3(-side * 4.0, 0, z))
	# Outer defense: a breakable fence line across the yard behind the door,
	# with the centre lane and the flanks left open.
	for z in [-6.0, 6.0]:
		_add_barricade(team, Vector3(fx + side * 5.2, 0, z), 3.5, PI / 2.0)
		cover_points.append(Vector3(fx + side * 5.2, 0, z))

	_build_cellar(team, bx, side)

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


func _build_cellar(team: int, bx: float, side: float) -> void:
	## The spawn cellar: a sunken stone hall behind the keep with the class
	## stations in it (Fat Princess hat machines, our way) and a flight of
	## stairs up through the back wall into the keep. Its parapet keeps the
	## field out, so the only way in from outside is still the front door.
	var color: Color = Stats.FACTIONS[team].color
	var cx := bx + side * (CELLAR_DEPTH / 2.0)
	var hz := CELLAR_HALF_Z
	var top := 0.9
	var wall_h := top - CELLAR_Y
	var wall_y := CELLAR_Y + wall_h / 2.0
	_add_block(Vector3(cx, CELLAR_Y - 0.05, 0), Vector3(CELLAR_DEPTH + 1.0, 0.1, hz * 2 + 1), Color.WHITE, true, _flagstone(Color(0.9, 0.86, 0.8)))
	_add_wall(Vector3(bx + side * (CELLAR_DEPTH + 0.5), wall_y, 0), Vector3(1, wall_h, hz * 2 + 1))
	for zs in [-1.0, 1.0]:
		_add_wall(Vector3(cx, wall_y, zs * (hz + 0.5)), Vector3(CELLAR_DEPTH + 2.0, wall_h, 1))
		# Under the castle's back wall: solid below ground except at the stairs.
		var seg := hz + 0.5 - 1.8
		_add_block(Vector3(bx, CELLAR_Y / 2.0, zs * (1.8 + seg / 2.0)), Vector3(1, -CELLAR_Y, seg), Color.WHITE, true, _ashlar())
		# Torches in brackets and banners along the side walls.
		for k in 2:
			var tx := bx + side * (1.5 + k * 3.0)
			_add_wall_torch(Vector3(tx, CELLAR_Y + 1.6, zs * (hz - 0.05)), Vector3(0, 0, -zs))
		_add_banner(team, Vector3(bx + side * 7.0, CELLAR_Y - 0.1, zs * (hz - 0.05)), Vector3(0, 0, -zs), 0.7)
		_prop("dungeon/box_stacked", Vector3(bx + side * 8.9, CELLAR_Y, zs * 6.1), 0.45, 0.0)
	# The stairs: a straight flight up the middle into the keep.
	var st := cellar_stairs(team)
	_add_stairs(st[0], st[1], 3.2, _ashlar(Color(0.9, 0.86, 0.78)), 0.0)
	for zs in [-1.0, 1.0]:
		# Low walls along the raised part of the stairs (the foot is open).
		_add_block(Vector3(bx + side * 3.0, CELLAR_Y + 0.6, zs * 1.9), Vector3(7.6, 1.2, 0.3), Color.WHITE, true, _ashlar(Color(0.9, 0.86, 0.78)))
	# The sanctuary barrier at the top of the stairs: the enemy team can't pass
	# it and nothing they fire gets through. Elves raise a wall of light,
	# Humans drop an iron portcullis.
	var barrier := StaticBody3D.new()
	barrier.collision_layer = 4 if team == 0 else 8
	barrier.collision_mask = 0
	barrier.position = Vector3(bx, 1.4, 0)
	var bshape := CollisionShape3D.new()
	var bbox := BoxShape3D.new()
	bbox.size = Vector3(0.6, 3.2, 3.6)
	bshape.shape = bbox
	barrier.add_child(bshape)
	add_child(barrier)
	if team == 0:
		var field := MeshInstance3D.new()
		var fq := BoxMesh.new()
		fq.size = Vector3(0.12, 2.9, 3.5)
		field.mesh = fq
		var fm := StandardMaterial3D.new()
		fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fm.albedo_color = Color(0.35, 1.0, 0.7, 0.35)
		field.material_override = fm
		field.position = Vector3(bx, 1.45, 0)
		add_child(field)
		_add_crystal(Vector3(bx - side * 0.2, 0, -2.3), 0.7)
		_add_crystal(Vector3(bx - side * 0.2, 0, 2.3), 0.7)
	else:
		var iron := StandardMaterial3D.new()
		iron.albedo_color = Color(0.25, 0.26, 0.3)
		iron.metallic = 0.9
		iron.roughness = 0.4
		for k in 7:
			var bar := MeshInstance3D.new()
			var bm := CylinderMesh.new()
			bm.top_radius = 0.06
			bm.bottom_radius = 0.06
			bm.height = 2.9
			bm.radial_segments = 6
			bar.mesh = bm
			bar.position = Vector3(bx, 1.45, -1.65 + k * 0.55)
			bar.material_override = iron
			add_child(bar)
		for yy in [0.9, 2.1]:
			var rail := MeshInstance3D.new()
			var rm := BoxMesh.new()
			rm.size = Vector3(0.14, 0.12, 3.5)
			rail.mesh = rm
			rail.position = Vector3(bx, yy, 0)
			rail.material_override = iron
			add_child(rail)
		var field := MeshInstance3D.new()
		var fq := BoxMesh.new()
		fq.size = Vector3(0.06, 2.9, 3.5)
		field.mesh = fq
		var fm := StandardMaterial3D.new()
		fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fm.albedo_color = Color(0.4, 0.6, 1.0, 0.18)
		field.material_override = fm
		field.position = Vector3(bx, 1.45, 0)
		add_child(field)
	# The spawn circle at the far end: a glowing team-coloured ring on the floor.
	var spawn := Vector3(bx + side * 8.6, CELLAR_Y, 0)
	_add_rug(spawn + Vector3(-side * 2.0, 0, 0), Vector2(1.4, 9.0), color)
	var ring := MeshInstance3D.new()
	var rm2 := TorusMesh.new()
	rm2.inner_radius = 4.2
	rm2.outer_radius = 4.45
	rm2.rings = 48
	ring.mesh = rm2
	ring.position = spawn + Vector3(-side * 0.8, 0.04, 0)
	var ring_mat := _material(color.lightened(0.3))
	ring_mat.emission_enabled = true
	ring_mat.emission = color.lightened(0.2)
	ring_mat.emission_energy_multiplier = 1.2
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = ring_mat
	add_child(ring)
	# A warm light so the hall reads from above.
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.8, 0.55)
	lamp.light_energy = 1.6
	lamp.omni_range = 14.0
	lamp.position = Vector3(cx, CELLAR_Y + 3.5, 0)
	add_child(lamp)
	# Class stations either side of the stairs.
	_add_station(team, Role.KNIGHT, Vector3(bx + side * 3.5, CELLAR_Y, -4.4))
	_add_station(team, Role.RANGER, Vector3(bx + side * 7.0, CELLAR_Y, -4.4))
	_add_station(team, Role.MAGE, Vector3(bx + side * 3.5, CELLAR_Y, 4.4))
	_add_station(team, Role.HEALER, Vector3(bx + side * 7.0, CELLAR_Y, 4.4))
	# The Upgrade Station (perk menu) and the Wildwood Guide by the back wall.
	_add_upgrade_pad(team, Vector3(bx + side * 1.6, CELLAR_Y, -4.6))
	var g := Guide.new()
	add_child(g)
	g.setup(self, team, Vector3(bx + side * 1.6, CELLAR_Y, 4.6), PI / 2.0 if side < 0.0 else -PI / 2.0)
	guides[team] = g


func _audit_clipping() -> void:
	## Testing aid (--audit): lists props that overlap a wall, another prop,
	## a fence, the gate or the vault by more than 15 cm, then quits.
	var items: Array = []
	for p in audit_props:
		var n: Node3D = p[1]
		var aabb := AABB()
		var first := true
		for m in n.find_children("*", "MeshInstance3D", true, false):
			var a: AABB = m.global_transform * m.get_aabb()
			if first:
				aabb = a
				first = false
			else:
				aabb = aabb.merge(a)
		var c := aabb.get_center()
		if not first and absf(c.z) < 38.0 and absf(c.x) < 90.0:  # the horizon forest and hills are backdrop
			items.append([p[0], aabb])
	var count := 0
	for i in items.size():
		for j in range(i + 1, items.size()):
			var pen := _penetration(items[i][1], items[j][1])
			if pen > 0.15:
				print("CLIP prop/prop %s <-> %s : %.2f at %s" % [items[i][0], items[j][0], pen, items[i][1].get_center().snapped(Vector3(0.1, 0.1, 0.1))])
				count += 1
		for b in audit_blocks:
			var bb: AABB = b[1]
			if bb.position.y + bb.size.y <= 0.02 and bb.size.y >= 0.9:
				continue  # the ground
			if b[0] == "pole":
				continue  # torch handles sit inside their posts by design
			var pen := _penetration(items[i][1], bb)
			if pen > 0.15:
				print("CLIP prop/%s %s : %.2f at %s (block %s %s)" % [b[0], items[i][0], pen, items[i][1].get_center().snapped(Vector3(0.1, 0.1, 0.1)), bb.position.snapped(Vector3(0.1, 0.1, 0.1)), bb.size.snapped(Vector3(0.1, 0.1, 0.1))])
				count += 1
	print("AUDIT done: %d overlaps in %d props" % [count, items.size()])


func _penetration(a: AABB, b: AABB) -> float:
	var i := a.intersection(b)
	if i.size.x <= 0.0 or i.size.y <= 0.0 or i.size.z <= 0.0:
		return 0.0
	return minf(i.size.x, minf(i.size.y, i.size.z))


func _add_crystal(pos: Vector3, scale: float) -> void:
	## A cluster of glowing elven crystals.
	for i in 3:
		var c := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(0.35, 1.4, 0.35) * scale * (1.0 - i * 0.22)
		c.mesh = pm
		c.position = pos + Vector3(cos(i * 2.1) * 0.25 * scale, pm.size.y / 2.0, sin(i * 2.1) * 0.25 * scale)
		c.rotation = Vector3(sin(i * 1.3) * 0.25, i * 1.1, cos(i * 0.7) * 0.25)
		var cm := StandardMaterial3D.new()
		cm.albedo_color = Color(0.5, 0.95, 0.85, 0.85)
		cm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		cm.emission_enabled = true
		cm.emission = Color(0.3, 0.9, 0.7)
		cm.emission_energy_multiplier = 1.4
		c.material_override = cm
		add_child(c)
	var light := OmniLight3D.new()
	light.light_color = Color(0.4, 1.0, 0.8)
	light.light_energy = 0.9
	light.omni_range = 4.0 * scale
	light.position = pos + Vector3(0, 0.8, 0)
	add_child(light)


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
	environment.ambient_light_energy = 0.6
	environment.ambient_light_sky_contribution = 0.6
	environment.ambient_light_color = Color(0.75, 0.85, 0.8)
	# Soft contact shadows under props and in corners (Forward+ only).
	environment.ssao_enabled = true
	environment.ssao_radius = 1.2
	environment.ssao_intensity = 1.6
	environment.ssao_power = 1.3
	environment.ssil_enabled = false
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
	sun.light_color = Color(1.0, 0.94, 0.82)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 1.5
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_split_1 = 0.12
	sun.directional_shadow_split_2 = 0.3
	sun.directional_shadow_max_distance = 70.0
	add_child(sun)
	# A cool fill from the other side so shadows are not black.
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-30, 140, 0)
	fill.light_color = Color(0.6, 0.7, 1.0)
	fill.light_energy = 0.15
	add_child(fill)

	# Ground, in pieces so each castle's spawn cellar can be sunk behind it.
	var gx := map_half.x + 40.0
	var gz := map_half.y + 30.0
	var h0 := CASTLE_X + CASTLE_DEPTH - 0.5          # cellar hole from here...
	var h1 := CASTLE_X + CASTLE_DEPTH + CELLAR_DEPTH + 0.5   # ...to here (x), mirrored
	var hz := CELLAR_HALF_Z + 0.5
	var grass := Color(0.42, 0.62, 0.3)
	var lane := CASTLE_X + CASTLE_DEPTH - 2.0  # the stairs' top reaches in this far
	_add_block(Vector3(0, -0.5, 0), Vector3(lane * 2, 1, gz * 2), grass, true, _grass())
	for sx in [-1.0, 1.0]:
		for zs in [-1.0, 1.0]:
			_add_block(Vector3(sx * (lane + h0) / 2.0, -0.5, zs * (1.9 + gz) / 2.0), Vector3(h0 - lane, 1, gz - 1.9), grass, true, _grass())
	for sx in [-1.0, 1.0]:
		_add_block(Vector3(sx * (h1 + gx) / 2.0, -0.5, 0), Vector3(gx - h1, 1, gz * 2), grass, true, _grass())
		for zs in [-1.0, 1.0]:
			_add_block(Vector3(sx * (h0 + h1) / 2.0, -0.5, zs * (hz + gz) / 2.0), Vector3(h1 - h0, 1, gz - hz), grass, true, _grass())
	# A dirt road from door to door, with a worn patch at each door and in the middle.
	# The road: rutted dirt from bridge to door, cobbled aprons at each door,
	# and grass creeping in at the edges.
	var fxr := CASTLE_X - CASTLE_DEPTH
	var road := _pbr("road", 0.55)
	# The main road: door to door through the shrine, with cobbled aprons.
	_add_path(Vector3(-fxr, 0, 0), Vector3(-ISLAND_R - 2.0, 0, 0), 5.4, road)
	_add_path(Vector3(ISLAND_R + 2.0, 0, 0), Vector3(fxr, 0, 0), 5.4, road)
	for sx in [-1.0, 1.0]:
		_add_block(Vector3(sx * (fxr - 2.5), 0.008, 0), Vector3(7, 0.01, 10), Color(0.6, 0.5, 0.35), false, _pbr("cobble", 0.45, Color(0.9, 0.86, 0.78)))
		# The Forest Path (north) and the River Path (south): from the road by
		# the castle door out to the flank bridges, as worn dirt tracks.
		var dirt := _dirt()
		var nb: float = BRIDGES[0]
		var sb: float = BRIDGES[2]
		_add_path(Vector3(sx * (fxr - 4.0), 0, -3.0), Vector3(sx * 30.0, 0, nb - 3.0), 3.4, dirt)
		_add_path(Vector3(sx * 30.0, 0, nb - 3.0), Vector3(sx * (RIVER_HALF + 1.5), 0, nb), 3.4, dirt)
		_add_path(Vector3(sx * (fxr - 4.0), 0, 3.0), Vector3(sx * 26.0, 0, sb + 2.0), 3.4, dirt)
		_add_path(Vector3(sx * 26.0, 0, sb + 2.0), Vector3(sx * (RIVER_HALF + 1.5), 0, sb), 3.4, dirt)
	_add_river()

	_build_castle(0)
	_build_castle(1)
	_add_cover()
	_add_heal_orbs()

	# Mirrored groves in the contested middle, leaving the roads clear, and
	# thick forest along the north edge where the Forest Path runs.
	var grove := [Vector3(8, 0, 8), Vector3(14, 0, 13), Vector3(22, 0, 6), Vector3(10, 0, 18),
		Vector3(26, 0, 16), Vector3(32, 0, 11), Vector3(5, 0, 14), Vector3(18, 0, 20), Vector3(38, 0, 15), Vector3(42, 0, 5),
		Vector3(4, 0, -32), Vector3(10, 0, -34), Vector3(18, 0, -31), Vector3(24, 0, -34), Vector3(32, 0, -30), Vector3(40, 0, -33), Vector3(46, 0, -28),
		Vector3(3, 0, -16), Vector3(16, 0, -11), Vector3(36, 0, -14), Vector3(8, 0, 32), Vector3(30, 0, 33), Vector3(44, 0, 30), Vector3(34, 0, 24)]
	for p in grove:
		_add_tree(p)
		_add_tree(-p)
		_add_bush(p + Vector3(1.8, 0, 0.6), int(p.x * 3 + p.z))
		_add_bush(-p + Vector3(-1.8, 0, -0.6), int(p.x * 5 + p.z))
	for p in [Vector3(12, 0, 14), Vector3(-12, 0, -14), Vector3(26, 0, 14), Vector3(-26, 0, -14), Vector3(58, 0, 22), Vector3(-58, 0, -22), Vector3(9, 0, -25), Vector3(-9, 0, 25)]:
		_add_fireflies(p)
	# Woods on the castle flanks.
	for p in [Vector3(52, 0, 19), Vector3(60, 0, 22), Vector3(68, 0, 18), Vector3(46, 0, 24), Vector3(56, 0, 30)]:
		_add_tree(p, true)
		_add_tree(-p, true)
		_add_tree(Vector3(p.x, 0, -p.z), true)
		_add_tree(Vector3(-p.x, 0, p.z), true)
	_add_ground_detail()
	# A tree line and hills beyond the playable edge, so the world has a horizon.
	for i in 22:
		var x := -84.0 + i * 8.0
		_prop("hex/trees_%s_medium" % ["A", "B"][i % 2], Vector3(x, 0, 40.0 + (i % 3) * 1.5), 4.0, float(i))
		_prop("hex/trees_%s_medium" % ["B", "A"][i % 2], Vector3(x + 3.0, 0, -40.0 - (i % 3) * 1.5), 4.0, float(i))
	for i in 7:
		_prop("hex/hill_single_A", Vector3(-60.0 + i * 20.0, -0.2, 52.0), 12.0, float(i))
		_prop("hex/hill_single_A", Vector3(-50.0 + i * 20.0, -0.2, -52.0), 12.0, float(i) + 1.0)
	# Hills along the east and west edges behind the castles.
	for zs in [-1.0, 1.0]:
		for sx in [-1.0, 1.0]:
			_prop("hex/hill_single_A", Vector3(sx * 100.0, -0.2, zs * 20.0), 12.0, sx + zs)

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
	_add_action("chat_toggle", [KEY_H], [])
	_add_action("roster_toggle", [KEY_N], [])
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
