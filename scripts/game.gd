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
const Banner = preload("res://scripts/banner.gd")
const Turret = preload("res://scripts/turret.gd")
const Seal = preload("res://scripts/seal.gd")
const Sfx = preload("res://scripts/sfx.gd")
const Role = Stats.Role

const TEAM_SIZE := 5
const CAPTURES_TO_WIN := Stats.CAPTURES_TO_WIN
# Each bot's class and job, in spawn order. The player takes the first slot.
const LINEUP := [
	[Role.KNIGHT, "attack"], [Role.RANGER, "attack"], [Role.MAGE, "attack"],
	[Role.HEALER, "support"], [Role.ENGINEER, "build"],
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
var cam_zoom := 1.0  # --debug-zoom=N pulls the camera back for overview renders
var sfx: Node        # every sound: see sfx.gd
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
	["move_left", "Move left"], ["move_right", "Move right"], ["cmd_attack", "Call: Attack!"], ["cmd_defend", "Call: Defend!"],
	["cmd_help", "Call: To me!"]]
const MENU_TABS := 6
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
var chat_tab := 0                 # 0 All, 1 Team: the log's filter tabs
var rosters_visible := false      # N shows the side team rosters (off by default; Tab has the teams)
# Hero customizer (title screen): name, hair and trim colour.
var hero_name := ""
var hero_hair := 0
var hero_trim := 0
var title_tab := 0              # main menu tab: 0 Play, 1 Hero, 2 Progress
var banner_bg := 0              # player banner: Stats.BANNER_BACKGROUNDS index
var banner_emblem := 0          # Stats.BANNER_EMBLEMS index
var banner_frame := 0           # Stats.BANNER_FRAMES index
var banner_title := 0           # Stats.BANNER_TITLES index
var killer_card := {}           # who killed the player last: {"unit", "weapon"}; the HUD shows their banner
var killer_timer := 0.0
var hero_look := 0              # Stats.HERO_LOOKS index (1 needs account level 10)
var map_variant := 0            # Stats.MAPS index (1 needs account level 10)
# Account progression (saved): every XP point the player earns in a match,
# plus a match bonus, goes on the account. See Stats.account_level.
var account_xp := 0
var match_xp := 0               # the player's XP earned this match, over every life
var last_match_gain := 0        # what the last match added (end screen)
var level_before := 1           # account level before the last match (end screen)
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
var overtime := false         # tied at full time: doors down, next capture wins
var thrones: Array[Vector3] = []
var monarchs: Array = []
var units: Array = []
var gates: Array = []
var vaults: Array = []
var toasts: Array = []        # [{text, color, time}] small HUD notices
var stolen_timer := 0.0       # the CROWN STOLEN banner
var capture_timer := 0.0      # the CAPTURE! banner
var capture_team := 0
var ramps: Array = []       # ramps[team] = [{bottom, top} at -z, {bottom, top} at +z]
var wall_posts: Array = []  # wall_posts[team] = [post at -z, post at +z]
var cover_points: Array = []  # places a shooter can duck behind
var barricades: Array = []
var barricades_left := [0, 0]   # barricade kits each team still has (fortify phase)
var prep_left := 0.0            # seconds left in the fortify phase (0 = the battle is on)
var barrier: Node3D
var turrets: Array = []       # every standing Engineer turret, both teams
# Quality of life settings (saved with the controls).
var screen_shake := true
var damage_numbers := true
var show_fps := false
# Quick commands: Z / X / C call the team; bots answer for COMMAND_TIME seconds.
var team_command := ["", ""]
var command_timer := [0.0, 0.0]
var command_pos := [Vector3.ZERO, Vector3.ZERO]
var compass: Node3D          # the gold arrow at the player's feet pointing at the objective
var compass_mesh: MeshInstance3D
var banners := [null, null]        # each team's standing war banner, if any
var banner_cooldown := [0.0, 0.0]
var turret_kills := [0, 0]   # demo tally: kills by each team's turrets
var raid_deaths := [0, 0]    # demo tally: each team's deaths inside the enemy castle
var turrets_built := [0, 0]   # per team, for the match report
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
# seals[team] maps a class to its Seal node (the thing you grab to become it).
var seals := [{}, {}]
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
var cam_lock := Vector3.INF     # --debug-cam=x,z parks the camera over a spot for renders
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
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			seed(int(arg.trim_prefix("--seed=")))
	_setup_input()
	sfx = Sfx.new()
	add_child(sfx)
	_load_controls()
	sfx.set_listener(Vector3.ZERO)
	if "--debug-night" in OS.get_cmdline_user_args():
		map_variant = 1
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
	sfx.play_music(false)


func _process(delta: float) -> void:
	_debug_hooks()
	_ui_sounds()
	for t in 2:
		command_timer[t] = maxf(command_timer[t] - delta, 0.0)
		banner_cooldown[t] = maxf(banner_cooldown[t] - delta, 0.0)
	if playing and overtime and not game_over:
		# Sudden death: a team with nobody left standing loses.
		for t in 2:
			if units.filter(func(u): return u.team == t and not u.dead).is_empty():
				announce("The %s are wiped out!" % Stats.FACTIONS[t].name)
				_finish(1 - t)
				break
	_update_compass()
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
			_demo_summary()
			get_tree().quit()
		if Input.is_action_just_pressed("restart"):
			get_tree().reload_current_scene()
		return

	if prep_left > 0.0:
		var before := prep_left
		prep_left -= delta
		if prep_left > 0.0 and prep_left <= 5.0 and ceili(before) != ceili(prep_left):
			sfx.ui("ui_click", 0.0, 1.4)
		if prep_left <= 0.0:
			_begin_battle()
	else:
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
	if prep_left <= 0.0:
		_tick_blessings(delta)
	_tick_tutorial()
	_update_camera(delta)
	if demo and Engine.get_process_frames() % 1800 == 0:
		print("t=%ds  score %d-%d  monarchs %s / %s  doors %d / %d  turrets %d / %d" % [Engine.get_process_frames() / 60,
			score[0], score[1], monarchs[0].state, monarchs[1].state, gates[0].hp, gates[1].hp, turrets_built[0], turrets_built[1]])
		for t in turrets:
			print("   turret team%d L%d hp=%d %s" % [t.team, t.level, t.hp, t.global_position.snapped(Vector3.ONE * 0.1)])
		for u in units:
			print("   team%d %s %s hearts=%d dead=%s job=%s" % [u.team, u.role_name(), u.global_position.snapped(Vector3.ONE * 0.1), u.hearts, u.dead, u.bot_job])
	stolen_timer = maxf(stolen_timer - delta, 0.0)
	killer_timer = maxf(killer_timer - delta, 0.0)
	capture_timer = maxf(capture_timer - delta, 0.0)
	levelup_timer = maxf(levelup_timer - delta, 0.0)
	if message_timer > 0.0:
		message_timer -= delta
		if message_timer <= 0.0:
			message_label.text = ""
	message_label.visible = not (menu_open or rank_open or guide_open)


var _ui_was := [false, false, false, -1]  # menu, rank menu, chat, tab: for the open/close clicks


func _ui_sounds() -> void:
	## Menus click open and shut; tabs click as they change.
	var now := [menu_open, rank_open, chat_open, menu_tab]
	for i in 3:
		if now[i] != _ui_was[i]:
			sfx.ui("ui_open" if now[i] else "ui_close", -4.0)
	if now[3] != _ui_was[3] and menu_open:
		sfx.ui("ui_click", -4.0)
	_ui_was = now


func _debug_hooks() -> void:
	## Testing aids: "--shot=<png>" saves a screenshot at frame --shot-frame
	## (default 900); "--debug-end" ends the match a second before that.
	var frame := Engine.get_process_frames()
	for arg in OS.get_cmdline_user_args():
		if frame == shot_frame - 5:
			if arg.begins_with("--debug-title-tab="):
				title_tab = int(arg.trim_prefix("--debug-title-tab="))
			if arg.begins_with("--debug-xp="):
				account_xp = int(arg.trim_prefix("--debug-xp="))
		if frame == shot_frame - 5 and player:
			if arg == "--debug-banner" and banners[player_team] == null:
				# A war banner planted in the field beside the player (no planting flash).
				player.facing = Vector3(0, 0, 1)
				plant_banner(player, false)
				player.global_position += Vector3(-2.6, 0, -1.8)
			if arg == "--debug-killed":
				# The kill screen: a bot's banner over the player's death.
				player.global_position = Vector3(-20, 0, 3)
				player.spawn_protect = 0.0
				player.home_defense = false
				for u in units:
					if u.team != player_team and not u.dead:
						u.bot_class = Role.KNIGHT
						player.take_damage(player.hearts, u, player.global_position + Vector3(2, 0, 0))
						killer_timer = 5.4
						break
			if arg == "--debug-rogue" and player.role == Role.BASE:
				player.set_role(Role.ROGUE)
			if arg == "--debug-barricade":
				player.facing = Vector3(1.0 if player_team == 0 else -1.0, 0, 0)
				plant_barricade(player)
			if arg == "--debug-bubble":
				# A Holy Bubble over the player and the nearest allies.
				player.bubble_up(4.0)
				var n := 0
				for u in units:
					if u != player and u.team == player.team and not u.dead and n < 2:
						u.global_position = player.global_position + Vector3(1.6 * (n + 1) - 2.4, 0, 1.4)
						u.bubble_up(4.0)
						n += 1
				spawn_ring(player.global_position, 3.0, Color(1.0, 0.95, 0.6), 0.6)
			# Menu screenshots: open the menu a few frames before the shot.
			if arg == "--debug-rank":
				player.level = 3
				player.points = 2
				rank_open = true
			if arg == "--debug-turrets" and player.role == Role.BASE:
				# An Engineer with a turret of each level on the rampart and in the yard.
				player.set_role(Role.ENGINEER)
				player.level = 3
				player.points = 1
				player.xp = 110
				var side := -1.0 if player_team == 0 else 1.0
				var fx := side * (CASTLE_X - CASTLE_DEPTH)
				var spots := [Vector3(fx, WALK_Y, -(Stats.DOOR_HALF + 5.9)), Vector3(fx, WALK_Y, Stats.DOOR_HALF + 5.9), Vector3(fx + side * 3.2, 0.0, Stats.DOOR_HALF + 3.2)]
				for k in 3:
					var t = spawn_turret(player_team, spots[k], player, {})
					player.turrets.append(t)
					for _n in k:
						t.upgrade()
				player.global_position = Vector3(fx + side * 0.6, WALK_Y, -(Stats.DOOR_HALF + 3.2))
				player.facing = Vector3(-side, 0, 0)
				cam_pos = player.global_position + CAMERA_OFFSET * cam_zoom
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
			if arg.begins_with("--debug-zoom="):
				cam_zoom = float(arg.trim_prefix("--debug-zoom="))
			if arg.begins_with("--debug-cam="):
				var c := arg.trim_prefix("--debug-cam=").split(",")
				cam_lock = Vector3(float(c[0]), 0.0, float(c[1]))
				cam_pos = cam_lock + CAMERA_OFFSET * cam_zoom
			if arg.begins_with("--debug-at="):
				var p := arg.trim_prefix("--debug-at=").split(",")
				player.position = Vector3(float(p[0]), float(p[2]) if p.size() > 2 else 0.0, float(p[1]))
				cam_pos = player.position + CAMERA_OFFSET * cam_zoom
			if arg == "--debug-blessing":
				spawn_blessing(Vector3(0, 0, 0), "Regeneration")
				player.apply_blessing("Might")
			if arg == "--debug-chat":
				chat_open = true
				chat_text = "push the middle bridge, I'll take the wall"
				chat_add("Aelith", "anyone got the healer station?", _team_color(0), true, Role.RANGER, 0)
				chat_add("Sylvara", "on it, give me a sec", _team_color(0), true, Role.MAGE, 0)
				chat_add("Garrick", "gg so far", _team_color(1), false, Role.KNIGHT, 1)
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
					sfx.ui("safe", -3.0)
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
	capture_timer = 3.5
	capture_team = carrier.team
	sfx.ui("capture")
	chat_system("%s captured the %s for the %s!" % [carrier.display_name, m.title, team_name])
	_banter(carrier.team, "captured")
	if score[carrier.team] >= CAPTURES_TO_WIN or overtime:
		_finish(carrier.team)
	else:
		announce("The %s captured the %s!" % [team_name, m.title])
	print("Capture: %s  (score %d - %d) t=%d" % [team_name, score[0], score[1], match_clock()])


func match_clock() -> int:
	## Seconds since the match began, overtime included (for the logs).
	if overtime:
		return int(Stats.MATCH_TIME + Stats.OVERTIME - time_left)
	return int(Stats.MATCH_TIME - time_left)


func _demo_summary() -> void:
	## One line per unit at the end of a bot match, for balance tallies.
	var w: String = "Draw" if winner_team < 0 else Stats.FACTIONS[winner_team].name
	print("RESULT winner=%s score=%d-%d t=%d overtime=%s turrets=%d/%d turret_kills=%d/%d raid_deaths=%d/%d" % [w, score[0], score[1], match_clock(), overtime, turrets_built[0], turrets_built[1], turret_kills[0], turret_kills[1], raid_deaths[0], raid_deaths[1]])
	for u in units:
		# The class the bot plays all match (its current role resets on death).
		var cls: String = Stats.FACTIONS[u.team].roles[u.bot_class]
		var vi: int = u.variants.get(u.bot_class, -1)
		if vi >= 0:
			cls = Stats.VARIANTS[u.bot_class][vi].name
		print("STAT team=%d class=%s kills=%d deaths=%d assists=%d dmg=%d heal=%d caps=%d level=%d" % [u.team, cls.replace(" ", ""),
			u.kills, u.deaths, u.assists, u.damage_dealt, u.healing, u.captures, u.level])


func _end_on_time() -> void:
	if score[0] == score[1] and not overtime:
		# Sudden death: both doors come down and stay down, next capture wins.
		overtime = true
		time_left = Stats.OVERTIME
		for g in gates:
			g.collapse()
		announce("OVERTIME! Both doors are down and nobody respawns. Next capture or last team standing wins!")
		chat_system("Overtime: the doors are down, no respawns. Next capture or last team standing wins.")
		for t in 2:
			if is_instance_valid(banners[t]):
				banners[t]._expire()
		sfx.ui("horn", 0.0, 0.8)
		print("Overtime")
		return
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
	_bank_match_xp(winner)
	sfx.play_ambience(false)
	if winner < 0:
		sfx.ui("horn")
	else:
		sfx.ui("victory" if winner == player_team else "defeat")


func try_interact(u) -> void:
	if u.dead:
		return
	if u.carrying:
		drop_monarch(u)
		return
	if u.is_player and guides[u.team] and guides[u.team].in_reach(u):
		guide_toggle()
		return
	for role in seals[u.team]:
		var seal = seals[u.team][role]
		if seal.in_reach(u):
			if u.role == role:
				toast("You already carry the %s's seal" % seal.class_title(), Color(1.0, 0.8, 0.5))
			else:
				seal.take(u)
			return
	if prep_left > 0.0:
		# The fortify phase: F raises a barricade.
		plant_barricade(u)
		return
	var m = monarchs[1 - u.team]
	if m.state == Monarch.State.CARRIED or _flat_dist(u.global_position, m.global_position) >= Unit.PICKUP_RANGE:
		# Nothing to grab here: F plants a war banner instead.
		if plant_banner(u):
			return
	if m.state != Monarch.State.CARRIED and _flat_dist(u.global_position, m.global_position) < Unit.PICKUP_RANGE:
		if m.state == Monarch.State.HOME and vaults[1 - u.team].is_locked():
			if u.is_player:
				toast("The Crown Vault is locked: break the lock first", Color(1.0, 0.8, 0.5))
			return
		m.pick_up(u)
		u.carrying = m
		u.gain_xp(Stats.XP_GRAB)
		stolen_timer = 3.5
		sfx.play("crown_grab", u.global_position)
		if u.team != player_team:
			sfx.ui("stolen", -4.0)
		announce("CROWN STOLEN! The %s has been taken by the %s!" % [m.title, Stats.FACTIONS[u.team].name])
		spawn_pillar(u.global_position, Color(1.0, 0.85, 0.3), 7.0, 1.2)
		spawn_flash(u.global_position + Vector3(0, 1.5, 0), Color(1.0, 0.85, 0.3), 4.0, 0.5)
		shake_at(u.global_position, 0.5)
		chat_system("%s grabbed the %s!" % [u.display_name, m.title])
		_banter(1 - u.team, "ours_taken")
		_banter(u.team, "carrying", u)


# --- War banners --------------------------------------------------------------

func banner_spot_ok(team: int, pos: Vector3) -> String:
	## "" if a banner may stand at `pos` for `team`, else why not.
	if _inside_castle(0, pos) or _inside_castle(1, pos) or pos.y < -0.3:
		return "Banners stand in the open field, not inside a castle"
	if absf(pos.x - _front_x(1 - team)) < Stats.BANNER.enemy_clear and (pos.x - _front_x(1 - team)) * (1.0 if team == 0 else -1.0) > -Stats.BANNER.enemy_clear:
		return "Too close to the enemy walls"
	if absf(pos.x) < RIVER_HALF + 2.0:
		return "Not in the river"
	return ""


func plant_banner(u, fx: bool = true) -> bool:
	## Plant the team's war banner where `u` stands (replacing the old one).
	if u.carrying or u.dead or overtime or prep_left > 0.0:
		return false
	if banner_cooldown[u.team] > 0.0:
		if u.is_player:
			toast("War banner ready in %d s" % ceili(banner_cooldown[u.team]), Color(1.0, 0.8, 0.5))
		return false
	var why := banner_spot_ok(u.team, u.global_position)
	if why != "":
		if u.is_player:
			toast(why, Color(1.0, 0.8, 0.5))
		return false
	var pos: Vector3 = u.global_position + u.facing * 1.2
	pos.y = u.global_position.y
	if is_instance_valid(banners[u.team]):
		banners[u.team]._expire()
	var b = Banner.new()
	add_child(b)
	b.setup(self, u.team, pos, u, {})
	banners[u.team] = b
	banner_cooldown[u.team] = Stats.BANNER.cooldown
	if fx:
		spawn_ring(pos, 2.0, Stats.FACTIONS[u.team].color, 0.6)
		spawn_pillar(pos, Stats.FACTIONS[u.team].color, 5.0, 0.8)
		sfx.play("turret_place", pos, 0.0)
		sfx.play("horn", pos, -8.0)
	announce("%s planted the %s war banner: fallen %s rejoin there." % [u.display_name, Stats.FACTIONS[u.team].name, Stats.FACTIONS[u.team].name])
	chat_system("%s planted a war banner." % u.display_name)
	if demo:
		print("Banner: %s t=%d at (%.0f, %.0f)" % [Stats.FACTIONS[u.team].name, match_clock(), pos.x, pos.z])
	return true


func remove_banner(b) -> void:
	if banners[b.team] == b:
		banners[b.team] = null


func banner_spawn(team: int) -> Vector3:
	## Where a fallen unit of `team` comes back: beside the standing banner,
	## or Vector3.INF for the castle.
	var b = banners[team]
	if b == null or not is_instance_valid(b) or b.hp <= 0 or b.life < 2.0:
		return Vector3.INF
	var a := randf() * TAU
	return b.global_position + Vector3(cos(a), 0, sin(a)) * randf_range(1.0, Stats.BANNER.spread)


# --- Turrets ------------------------------------------------------------------

func turret_spot(team: int, pos: Vector3, builder) -> Vector3:
	## Where a turret may stand for `pos`, or Vector3.INF. Castle walls and
	## yard, or the grounds just outside the front wall; never the door lane,
	## the cellar, inside a wall, or on top of another turret.
	var side := -1.0 if team == 0 else 1.0
	var fx := side * (CASTLE_X - CASTLE_DEPTH)
	var grounds: bool = (fx - pos.x) * side >= 0.0 and (fx - pos.x) * side < Stats.TURRET.grounds and absf(pos.z) < CASTLE_HALF_Z + 6.0
	if not (_inside_castle(team, pos) or grounds):
		return Vector3.INF
	if absf(pos.z) < Stats.DOOR_HALF + 1.3 and absf(pos.x - fx) < 5.0:
		return Vector3.INF  # keep the door lane clear
	if pos.y < -0.3:
		return Vector3.INF
	for t in turrets:
		if _flat_dist(t.global_position, pos) < 2.4:
			return Vector3.INF
	# The floor under the spot must be at the builder's height (not off a wall edge).
	var space := get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(pos + Vector3(0, 1.5, 0), pos + Vector3(0, -2.0, 0), 1)
	var hit := space.intersect_ray(ray)
	if hit.is_empty():
		return Vector3.INF
	var floor_y: float = hit.position.y
	if builder and absf(floor_y - builder.global_position.y) > 0.6:
		return Vector3.INF
	# Nothing solid where the turret body goes.
	var probe := PhysicsShapeQueryParameters3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.45
	probe.shape = sph
	probe.transform = Transform3D(Basis(), Vector3(pos.x, floor_y + 0.9, pos.z))
	probe.collision_mask = 1 | 4 | 8
	if not space.intersect_shape(probe, 1).is_empty():
		return Vector3.INF
	return Vector3(pos.x, floor_y, pos.z)


func spawn_turret(team: int, pos: Vector3, builder, opts: Dictionary) -> Node3D:
	var t = Turret.new()
	add_child(t)
	t.setup(self, team, pos, builder, opts)
	turrets.append(t)
	turrets_built[team] += 1
	spawn_splash(pos + Vector3(0, 0.6, 0), Color(0.8, 0.7, 0.5), 16, 3.0, 0.6)
	spawn_ring(pos, 1.3, Stats.FACTIONS[team].color, 0.5)
	sfx.play("turret_place", pos, 0.0)
	return t


func remove_turret(t) -> void:
	turrets.erase(t)
	if is_instance_valid(t.builder):
		t.builder.turrets.erase(t)


func turret_spots(team: int) -> Array:
	## Where bot Engineers build: the rampart either side of the gatehouse,
	## then the yard just inside the door, flanking the lane.
	var side := -1.0 if team == 0 else 1.0
	var fx := side * (CASTLE_X - CASTLE_DEPTH)
	var dh := Stats.DOOR_HALF
	return [Vector3(fx, WALK_Y, -(dh + 5.9)), Vector3(fx, WALK_Y, dh + 5.9),
		Vector3(fx + side * 3.2, 0.0, -(dh + 3.2)), Vector3(fx + side * 3.2, 0.0, dh + 3.2)]


func spawn_bolt(team: int, from: Vector3, dir: Vector3, s: Dictionary, color: Color, owner_unit) -> void:
	## A shot from something that is not a unit (turrets).
	var shot = Projectile.new()
	shot.owner_unit = owner_unit
	shot.from_turret = true
	add_child(shot)
	shot.setup(self, team, from - Vector3(0, Projectile.FLIGHT_HEIGHT, 0), dir, s, color)


func drop_monarch(u) -> void:
	var m = u.carrying
	if m == null:
		return
	u.carrying = null
	m.drop_at(u.global_position)
	sfx.play("crown_drop", u.global_position)


func _check_stations() -> void:
	# Bots stepping onto a class seal take it. Players grab theirs with the
	# interact key (see try_interact), so a stroll past a seal changes nothing.
	for u in units:
		if u.dead or u.carrying or u.is_player:
			continue
		for role in stations[u.team]:
			# Bots only use the seal for the class they were assigned.
			if role != u.bot_class:
				continue
			if u.role != role and _flat_dist(u.global_position, stations[u.team][role]) < STATION_RADIUS:
				u.set_role(role)
				sfx.play("station", u.global_position)
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
	sfx.ui("horn", -6.0, 0.9 if tier == 1 else 0.75)
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
	sfx.ui("horn", -2.0, 1.2)
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
	if prep_left > 0.0:
		# The fortify phase: everyone but the Engineer digs in (traps,
		# barricades, the walls); the Engineer keeps building.
		for u in bots:
			if u.base_job != "build":
				u.bot_job = "prep"
		return
	var side := -1.0 if team == 0 else 1.0
	if mine.state == Monarch.State.CARRIED:
		_assign_nearest(bots, mine.carrier.global_position, 3, "recover")
	elif mine.state == Monarch.State.DROPPED:
		_assign_nearest(bots, mine.global_position, 2, "recover")
	if theirs.state == Monarch.State.CARRIED and theirs.carrier.team == team:
		_assign_nearest(bots, theirs.carrier.global_position, 2, "escort")
	# A quick command from the player steers the free bots for a while:
	# Defend! pulls three home, To me! brings two to where it was called,
	# Attack! keeps everyone on the raid (and skips the rally wait).
	var cmd: String = team_command[team] if command_timer[team] > 0.0 else ""
	if cmd == "defend":
		_assign_nearest(bots, Vector3(side * CASTLE_X, 0, 0), 3, "defend")
	elif cmd == "help":
		_assign_nearest(bots, command_pos[team], 2, "rally_to")
	# In overtime the doors are down for good, so nobody guards a door: the
	# way to win is the other castle. Only a breach pulls people home.
	var gate_hurt: bool = gates[team].hp < Stats.GATE_HITS * 0.4 and not overtime and cmd != "attack"
	if enemy_inside_keep(team):
		_assign_nearest(bots, thrones[team], 2 if overtime else 3, "defend")
	elif enemy_inside_castle(team) and cmd != "attack":
		_assign_nearest(bots, Vector3(side * CASTLE_X, 0, 0), 1 if overtime else 2, "defend")
	elif gate_hurt:
		_assign_nearest(bots, Vector3(side * CASTLE_X, 0, 0), 1, "defend")


func command_active(team: int, kind: String) -> bool:
	return command_timer[team] > 0.0 and team_command[team] == kind


func call_command(kind: String) -> void:
	## The player calls the team: a chat line, a ring at their feet, a horn,
	## and the squad planner follows it for a while.
	if player == null or player.dead:
		return
	var team := player_team
	team_command[team] = kind
	command_timer[team] = Stats.COMMAND_TIME
	command_pos[team] = player.global_position
	var words := {"attack": "Attack! Push the gate!", "defend": "Defend the castle!", "help": "To me! I need help here!"}
	var titles := {"attack": "ATTACK!", "defend": "DEFEND!", "help": "TO ME!"}
	chat_add(player.display_name, words[kind], _team_color(team), true, player.role, team)
	toast("You called: %s  (bots answer for %d s)" % [titles[kind], int(Stats.COMMAND_TIME)], Color(1.0, 0.85, 0.4))
	spawn_ring(player.global_position, 2.6, _team_color(team), 0.7)
	sfx.ui("horn", -10.0)
	_banter(team, "reply")


func toggle_setting(key: String) -> void:
	match key:
		"shake": screen_shake = not screen_shake
		"numbers": damage_numbers = not damage_numbers
		"fps": show_fps = not show_fps
		"chat": chat_visible = not chat_visible
		"rosters": rosters_visible = not rosters_visible
	sfx.ui("ui_click", -4.0)
	_save_settings()


func objective_target() -> Dictionary:
	## What the player should be doing right now: where it is and which step
	## of the objective list it is (-1 means recover our own crown).
	if player == null:
		return {}
	var mine = monarchs[player_team]
	var theirs = monarchs[1 - player_team]
	if prep_left > 0.0:
		return {"pos": player.global_position, "step": 0, "label": "Fortify: turrets, traps, barricades (%s)" % key_label("interact")}
	if player.carrying:
		return {"pos": thrones[player_team], "step": 2, "label": "Carry them to your throne"}
	if mine.state == Monarch.State.CARRIED:
		return {"pos": mine.carrier.global_position, "step": -1, "label": "Stop the thief carrying our monarch"}
	if mine.state == Monarch.State.DROPPED:
		return {"pos": mine.global_position, "step": -1, "label": "Bring our monarch home"}
	if theirs.state == Monarch.State.CARRIED:
		return {"pos": theirs.carrier.global_position, "step": 2, "label": "Escort our carrier"}
	if theirs.state == Monarch.State.DROPPED:
		return {"pos": theirs.global_position, "step": 2, "label": "Grab their monarch"}
	var gate = gates[1 - player_team]
	if not gate.broken and not _inside_castle(1 - player_team, player.global_position):
		return {"pos": gate.global_position, "step": 0, "label": "Break the enemy castle door"}
	if vaults[1 - player_team].is_locked():
		return {"pos": theirs.global_position, "step": 1, "label": "Break the lock on their Crown Vault"}
	return {"pos": theirs.global_position, "step": 2, "label": "Grab their monarch"}


func _update_compass() -> void:
	## A gold arrow on the ground at the player's feet pointing at the
	## current objective; hidden when it is close or nothing applies.
	if compass == null:
		compass = Node3D.new()
		add_child(compass)
		compass_mesh = MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(0.62, 0.8, 0.1)
		compass_mesh.mesh = prism
		compass_mesh.rotation.x = -PI / 2.0
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.82, 0.3)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.75, 0.2)
		mat.emission_energy_multiplier = 0.8
		compass_mesh.material_override = mat
		compass_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		compass.add_child(compass_mesh)
		var tail := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.18, 0.08, 0.5)
		tail.mesh = box
		tail.position = Vector3(0, 0, 0.6)
		tail.material_override = mat
		tail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		compass.add_child(tail)
	if not playing or player == null or player.dead or demo or menu_open:
		compass.visible = false
		return
	var obj := objective_target()
	if obj.is_empty():
		compass.visible = false
		return
	var to: Vector3 = obj.pos - player.global_position
	to.y = 0.0
	if to.length() < 6.0:
		compass.visible = false
		return
	compass.visible = true
	var dir := to.normalized()
	var pulse := 1.0 + 0.08 * sin(Time.get_ticks_msec() / 180.0)
	compass.global_position = player.global_position + dir * 1.7 + Vector3(0, 0.1, 0)
	compass.look_at(compass.global_position + dir, Vector3.UP)
	compass.scale = Vector3.ONE * pulse


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


func rally_point(team: int) -> Vector3:
	## Where a team's raid gathers: on the road outside the enemy door, past
	## the reach of rampart turrets.
	var toward_home := -1.0 if team == 0 else 1.0
	return Vector3(_front_x(1 - team) + toward_home * Stats.RALLY.dist, 0, 0)


func raiders_near(team: int, pos: Vector3, radius: float) -> int:
	## Living teammates on the raid (attackers, escorts, Engineers done
	## building) within `radius` of `pos`; healers tag along and do not count.
	var n := 0
	for u in units:
		if u.team == team and not u.dead and u.role != Unit.Role.HEALER and u.role != Unit.Role.BASE \
				and (u.is_player or u.bot_job == "attack" or u.bot_job == "build" or u.bot_job == "escort") \
				and _flat_dist(u.global_position, pos) < radius:
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
			# The thresholds step down (1.3 m back to the foot line, 0.8 m to
			# count as on the lane) and sit above the 0.6 m arrival radius, so
			# no spot in the cellar is "arrived" without a next point to go to.
			var behind: float = (from.x - st[0].x) * side
			var on_lane: bool = absf(from.z) < 1.3 and behind < 0.8
			if on_lane:
				return st[1]
			if behind < 1.3:
				return st[0]  # near the foot of the stairs: step across to the lane
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
			# Off the door lane and close to the front wall (either side): line
			# up with the door first, or the gatehouse towers and the stairs
			# corner would hold a walker that heads for the door diagonally.
			var here := signf(from.x - fx)
			if here != 0.0 and absf(from.z) > Stats.DOOR_HALF - 0.6 and absf(from.x - fx) < 6.0:
				return Vector3(fx + here * 4.5, 0.0, 0.0)
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
	if not damage_numbers and (text.begins_with("-") or text.begins_with("+")):
		return
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
	cam_pos = player.global_position + CAMERA_OFFSET * cam_zoom
	camera.global_position = cam_pos
	playing = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--debug-time="):
			time_left = float(arg.trim_prefix("--debug-time="))  # testing: a short clock
		if arg == "--no-prep":
			prep_left = -1.0
	if prep_left >= 0.0:
		prep_left = Stats.PREP_TIME
		barricades_left = [Stats.BARRICADE_TEAM, Stats.BARRICADE_TEAM]
		_build_barrier()
	else:
		prep_left = 0.0
	sfx.ui("match_start")
	sfx.play_music(true)
	sfx.play_ambience(true)
	chat_system("Click to attack, Q and E for abilities, Space to dodge, %s for perks, hold %s for the scoreboard, %s to chat." % [
		key_label("rank_menu"), key_label("scoreboard"), key_label("chat")])
	if prep_left > 0.0:
		announce("FORTIFY! Build turrets, set traps and raise barricades (%s) before the barrier falls." % key_label("interact"))


func in_prep() -> bool:
	return prep_left > 0.0


func _build_barrier() -> void:
	## The fortify barrier: a wall of light down the middle of the field that
	## nothing crosses until the battle begins.
	barrier = Node3D.new()
	add_child(barrier)
	var length: float = map_half.y * 2.0 + 12.0
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.8, 10.0, length)
	shape.shape = box
	shape.position = Vector3(0, 5.0, 0)
	body.add_child(shape)
	barrier.add_child(body)
	var wall := MeshInstance3D.new()
	var wm := BoxMesh.new()
	wm.size = Vector3(0.3, 6.0, length)
	wall.mesh = wm
	wall.position = Vector3(0, 3.0, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.9, 0.55, 0.22)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	wall.material_override = mat
	wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	barrier.add_child(wall)
	# Rune posts along it so it reads from the ground.
	var n := int(length / 6.0)
	for i in n + 1:
		var z: float = -length / 2.0 + i * (length / n)
		var post := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 0.12
		pm.bottom_radius = 0.18
		pm.height = 2.2
		post.mesh = pm
		post.position = Vector3(0, 1.1, z)
		var pmat := _material(Color(1.0, 0.85, 0.4))
		pmat.emission_enabled = true
		pmat.emission = Color(1.0, 0.8, 0.35)
		pmat.emission_energy_multiplier = 2.0
		post.material_override = pmat
		barrier.add_child(post)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.85, 0.5)
	light.light_energy = 1.5
	light.omni_range = 12.0
	light.position = Vector3(0, 3.0, 0)
	barrier.add_child(light)


func _begin_battle() -> void:
	## The fortify phase ends: the barrier falls and the clock starts.
	prep_left = 0.0
	if is_instance_valid(barrier):
		barrier.queue_free()
		barrier = null
	if demo:
		print("Battle begins: barricades %d/%d, traps %d, turrets %d/%d" % [Stats.BARRICADE_TEAM - barricades_left[0], Stats.BARRICADE_TEAM - barricades_left[1], get_children().filter(func(c): return c is Trap).size(), turrets_built[0], turrets_built[1]])
	announce("FIGHT! The barrier is down. Capture the crown!")
	chat_system("The barrier is down. Fight!")
	sfx.ui("horn", 0.0, 1.0)
	sfx.ui("match_start")
	spawn_flash(Vector3(0, 3.0, 0), Color(1.0, 0.9, 0.6), 8.0, 0.8)
	spawn_ring(Vector3(0, 0.2, 0), 14.0, Color(1.0, 0.9, 0.6), 1.0)
	shake_at(Vector3.ZERO, 0.3)


func plant_barricade(u) -> bool:
	## Raise a timber barricade across where `u` faces, on your own half of
	## the field, during the fortify phase. Each team has a few kits.
	if u.dead or u.carrying:
		return false
	var team: int = u.team
	var side := -1.0 if team == 0 else 1.0
	var why := ""
	if barricades_left[team] <= 0:
		why = "No barricade kits left"
	elif u.global_position.y < -0.3:
		why = "Not in the cellar"
	elif u.global_position.x * side < RIVER_HALF + 3.0:
		why = "Only on your own side of the river"
	elif absf(u.global_position.z) < 3.0 and absf(u.global_position.x - _front_x(team)) < 9.0:
		why = "Not in the door lane"
	elif _inside_castle(team, u.global_position) or absf(u.global_position.x) > CASTLE_X - CASTLE_DEPTH - 1.6:
		why = "Only outside the walls"
	if why != "":
		if u.is_player:
			toast(why, Color(1.0, 0.8, 0.5))
		return false
	var f: Vector3 = u.facing
	f.y = 0.0
	if f.length() < 0.1:
		f = Vector3(-side, 0, 0)
	f = f.normalized()
	var pos: Vector3 = u.global_position + f * 1.6
	pos.y = maxf(u.global_position.y, 0.0)
	_add_barricade(team, pos, Stats.BARRICADE_LENGTH, atan2(f.x, f.z))
	barricades_left[team] -= 1
	sfx.play("station", pos)
	spawn_ring(pos, 2.0, Color(0.9, 0.75, 0.45), 0.5)
	spawn_splash(pos + Vector3(0, 0.6, 0), Color(0.75, 0.55, 0.3), 14, 3.0, 0.5)
	if u.is_player:
		announce("Barricade raised. %d kit%s left." % [barricades_left[team], "" if barricades_left[team] == 1 else "s"])
	return true


func _update_camera(delta: float) -> void:
	if player == null:
		return
	var target: Vector3 = (cam_lock if cam_lock != Vector3.INF else player.global_position) + CAMERA_OFFSET * cam_zoom
	cam_pos = cam_pos.lerp(target, clampf(delta * 5.0, 0.0, 1.0))
	sfx.set_listener(player.global_position)
	shake_amount = move_toward(shake_amount, 0.0, delta * 1.6)
	var jolt := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * shake_amount * 0.35
	camera.global_position = cam_pos + jolt


func shake(amount: float) -> void:
	## Camera recoil for the local player's view.
	if not screen_shake:
		return
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
	if hero_look > 0 and unlocked():
		c.look = Stats.HERO_LOOKS[hero_look][1]
	return c


func account_level() -> int:
	return Stats.account_level(account_xp)


func banner_for(u) -> Dictionary:
	## The calling card a unit shows on the kill screen: the player's is the
	## one they edited; a bot's is dealt from its name and class.
	if u == null:
		return {}
	if u.is_player:
		return {"name": u.display_name, "bg": banner_bg, "emblem": banner_emblem, "frame": banner_frame,
			"title": Stats.BANNER_TITLES[banner_title][1], "level": account_level(), "team": u.team}
	var h: int = absi(hash(u.display_name))
	var emblem: int = Stats.BANNER_EMBLEMS.find(hud._class_icon(u.bot_class)) if hud else 0
	var level: int = 1 + h % 14
	return {"name": u.display_name, "bg": (h / 7) % (Stats.BANNER_BACKGROUNDS.size() - 1), "emblem": maxi(emblem, 0),
		"frame": (h / 3) % 4, "title": Stats.rank_title(level), "level": level, "team": u.team}


func on_player_killed(killer, weapon: String) -> void:
	## The player died: show the killer's banner for a while.
	if killer == null or killer == player:
		killer_card = {}
		return
	killer_card = {"unit": killer, "weapon": weapon}
	killer_timer = 6.0


func unlocked() -> bool:
	## The level-10 unlocks (Rogue, Shadowborn look, Moonlit map).
	return account_level() >= Stats.UNLOCK_LEVEL or "--debug-unlock" in OS.get_cmdline_user_args()


func night() -> bool:
	return map_variant == 1 and (unlocked() or "--debug-night" in OS.get_cmdline_user_args())


func _bank_match_xp(winner: int) -> void:
	## The match is over: the player's XP goes on the account.
	if demo:
		return
	var bonus: int = Stats.MATCH_BONUS.draw if winner < 0 else (Stats.MATCH_BONUS.win if winner == player_team else Stats.MATCH_BONUS.loss)
	level_before = account_level()
	last_match_gain = match_xp + bonus
	account_xp += last_match_gain
	_save_settings()
	var now := account_level()
	if now > level_before:
		sfx.ui("level_up")
		if now >= Stats.UNLOCK_LEVEL and level_before < Stats.UNLOCK_LEVEL:
			chat_system("Account level %d: the Rogue, the Shadowborn look and the Moonlit Wildwood are unlocked!" % now)


func guide_toggle() -> void:
	if guide_open:
		guide_advance()
		return
	guide_open = true
	sfx.ui("ui_open")
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
	sfx.ui("ui_close")
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
		5:
			return text % [key_label("cmd_attack"), key_label("cmd_defend"), key_label("cmd_help"), key_label("interact")]
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
	return [1, 4, 5] if not playing else [0, 3, 1, 2, 4, 5]


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
		# Quick commands to the team.
		if player and not menu_open and not eaten and not demo and not player.dead and not rank_open and not guide_open:
			for kind in ["attack", "defend", "help"]:
				if Input.is_action_just_pressed("cmd_" + kind):
					call_command(kind)
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
	if click and hud and menu_open:
		# Volume sliders follow the mouse while the button is held.
		var mp := get_viewport().get_mouse_position()
		for sl in hud.volume_sliders:
			if sl[0].grow(6).has_point(mp):
				var v := clampf((mp.x - sl[0].position.x - 2.0) / (sl[0].size.x - 4.0), 0.0, 1.0)
				if sl[1] == "sound":
					sfx.sound_volume = v
				else:
					sfx.music_volume = v
				sfx.apply_volumes()
				if not click_was:
					sfx.ui("ui_click", -4.0)
				_save_settings()
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
				sfx.ui("ui_click", -4.0)
				_save_settings()
		for b in hud.toggle_buttons:
			if b[0].has_point(mouse):
				toggle_setting(b[1])
		if hud.options_button.has_point(mouse) and not playing:
			menu_open = true
			menu_tab = 4
		if not playing and not menu_open:
			for b in hud.title_buttons:
				if b[0].has_point(mouse) and b[1] < 3:
					title_tab = b[1]
		if not playing and not menu_open:
			var was_editing := name_editing
			name_editing = false
			for b in hud.hero_buttons:
				if b[0].has_point(mouse):
					match b[1]:
						"hair": hero_hair = b[2]
						"trim": hero_trim = b[2]
						"banner_bg": banner_bg = b[2]
						"banner_emblem":
							if Stats.BANNER_EMBLEMS[b[2]] != "class_rogue" or unlocked():
								banner_emblem = b[2]
							else:
								toast("That emblem unlocks at account level %d" % Stats.UNLOCK_LEVEL, Color(1.0, 0.8, 0.5))
						"banner_frame":
							if Stats.BANNER_FRAMES[b[2]][0] != "Royal" or unlocked():
								banner_frame = b[2]
							else:
								toast("That frame unlocks at account level %d" % Stats.UNLOCK_LEVEL, Color(1.0, 0.8, 0.5))
						"banner_title":
							if Stats.BANNER_TITLES[b[2]][0] <= account_level() or "--debug-unlock" in OS.get_cmdline_user_args():
								banner_title = b[2]
							else:
								toast("That title unlocks at account level %d" % Stats.BANNER_TITLES[b[2]][0], Color(1.0, 0.8, 0.5))
						"look":
							if b[2] == 0 or unlocked():
								hero_look = b[2]
							else:
								toast("The Shadowborn look unlocks at account level %d" % Stats.UNLOCK_LEVEL, Color(1.0, 0.8, 0.5))
						"map":
							if b[2] == 0 or unlocked():
								map_variant = b[2]
								_apply_map_variant()
							else:
								toast("The Moonlit Wildwood unlocks at account level %d" % Stats.UNLOCK_LEVEL, Color(1.0, 0.8, 0.5))
						"name": name_editing = true
					if not name_editing:
						_save_settings()
			if was_editing and not name_editing:
				hero_name = hero_name.strip_edges()
				_save_settings()
			for b in hud.faction_buttons:
				if b[0].has_point(mouse) and not was_editing:
					_start_match(b[1])
		for b in hud.guide_buttons:
			if b[0].has_point(mouse):
				if b[1] == "next":
					guide_advance()
				elif b[1] == "close":
					guide_close()
				else:
					guide_pick(int(b[1]))
		for b in hud.chat_buttons:
			if b[0].has_point(mouse):
				chat_tab = int(b[1])
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

func chat_add(who: String, text: String, color: Color, team_only: bool = false, role: int = -1, pteam: int = -1) -> void:
	## `role`/`pteam` give the speaker's portrait; `clock` stamps the match time.
	chat_log.append({"who": who, "text": text, "color": color, "time": Time.get_ticks_msec() / 1000.0, "team": team_only,
		"role": role, "pteam": pteam, "clock": maxf(time_left, 0.0)})
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
	chat_add(player.display_name, text, _team_color(player.team), team_only, player.role, player.team)
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
	var role: int = speaker.role
	get_tree().create_timer(delay).timeout.connect(func(): chat_add(who, line, _team_color(team), true, role, team))


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
	cfg.set_value("settings", "sound_volume", sfx.sound_volume)
	cfg.set_value("settings", "music_volume", sfx.music_volume)
	cfg.set_value("settings", "chat_visible", chat_visible)
	cfg.set_value("settings", "rosters_shown", rosters_visible)
	cfg.set_value("settings", "screen_shake", screen_shake)
	cfg.set_value("settings", "damage_numbers", damage_numbers)
	cfg.set_value("settings", "show_fps", show_fps)
	cfg.set_value("settings", "hero_name", hero_name)
	cfg.set_value("settings", "hero_hair", hero_hair)
	cfg.set_value("settings", "hero_trim", hero_trim)
	cfg.set_value("settings", "hero_look", hero_look)
	cfg.set_value("settings", "banner_bg", banner_bg)
	cfg.set_value("settings", "banner_emblem", banner_emblem)
	cfg.set_value("settings", "banner_frame", banner_frame)
	cfg.set_value("settings", "banner_title", banner_title)
	cfg.set_value("settings", "map_variant", map_variant)
	cfg.set_value("profile", "account_xp", account_xp)
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
	rosters_visible = cfg.get_value("settings", "rosters_shown", false)
	screen_shake = cfg.get_value("settings", "screen_shake", true)
	damage_numbers = cfg.get_value("settings", "damage_numbers", true)
	show_fps = cfg.get_value("settings", "show_fps", false)
	sfx.sound_volume = clampf(cfg.get_value("settings", "sound_volume", 0.8), 0.0, 1.0)
	sfx.music_volume = clampf(cfg.get_value("settings", "music_volume", 0.6), 0.0, 1.0)
	hero_name = cfg.get_value("settings", "hero_name", "")
	hero_hair = clampi(cfg.get_value("settings", "hero_hair", 0), 0, Stats.HERO_HAIR.size() - 1)
	hero_trim = clampi(cfg.get_value("settings", "hero_trim", 0), 0, Stats.HERO_TRIM.size() - 1)
	hero_look = clampi(cfg.get_value("settings", "hero_look", 0), 0, Stats.HERO_LOOKS.size() - 1)
	banner_bg = clampi(cfg.get_value("settings", "banner_bg", 0), 0, Stats.BANNER_BACKGROUNDS.size() - 1)
	banner_emblem = clampi(cfg.get_value("settings", "banner_emblem", 0), 0, Stats.BANNER_EMBLEMS.size() - 1)
	banner_frame = clampi(cfg.get_value("settings", "banner_frame", 0), 0, Stats.BANNER_FRAMES.size() - 1)
	banner_title = clampi(cfg.get_value("settings", "banner_title", 0), 0, Stats.BANNER_TITLES.size() - 1)
	map_variant = clampi(cfg.get_value("settings", "map_variant", 0), 0, Stats.MAPS.size() - 1)
	account_xp = maxi(int(cfg.get_value("profile", "account_xp", 0)), 0)
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
	return _pbr("grass", 0.11, Color(0.84, 0.93, 0.74))


func _wood(tint: Color = Color.WHITE, scale: float = 0.5) -> StandardMaterial3D:
	return _pbr("wood", scale, tint)


func _dirt() -> StandardMaterial3D:
	## The rutted dirt road texture (tools/make_textures.py).
	return _pbr("dirt", 0.17)


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
	if prop_solid:
		_solidify_prop(inst, pos)
	return inst


var prop_solid := false   # while a castle is being built: clutter gets colliders


func _solidify_prop(inst: Node3D, pos: Vector3) -> void:
	## A box collider the size of the prop, so nobody walks through crates,
	## barrels, racks and furniture. Rugs, coins and anything hung high stay
	## walkable.
	var aabb := AABB()
	var first := true
	for m in inst.find_children("*", "MeshInstance3D", true, false):
		var a: AABB = m.global_transform * m.get_aabb()
		if first:
			aabb = a
			first = false
		else:
			aabb = aabb.merge(a)
	if first:
		return
	var floor_y: float = CELLAR_Y if pos.y < -1.0 else (WALK_Y if pos.y > 2.5 else 0.0)
	if aabb.position.y - floor_y > 1.0 or aabb.size.y < 0.35 or aabb.size.x > 6.0 or aabb.size.z > 6.0:
		return
	if "--audit" in OS.get_cmdline_user_args():
		print("SOLID %s at %s size %s" % [inst.scene_file_path.get_file(), aabb.get_center().snapped(Vector3(0.1, 0.1, 0.1)), aabb.size.snapped(Vector3(0.1, 0.1, 0.1))])
	var body := StaticBody3D.new()
	body.position = aabb.get_center()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(maxf(aabb.size.x, 0.3), aabb.size.y, maxf(aabb.size.z, 0.3))
	shape.shape = box
	body.add_child(shape)
	add_child(body)


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
	mesh.material_override = _pbr("rock", 0.45)
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
		["flower", flower, 520, 0.14], ["tuft", tuft, 1500, 0.18], ["stone", stone, 90, 0.0], ["cap", cap, 120, 0.26], ["leaf", leaf, 260, 0.02]]
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


## Ground kept clear of trees for the outskirts built later: the two
## watermills and the barrow.
const RESERVED_GROUND := [Vector3(-6.2, 0, -30), Vector3(6.2, 0, 30), Vector3(-30, 0, 22)]


func _add_tree(pos: Vector3, big: bool = false) -> void:
	for rp in RESERVED_GROUND:
		if _flat_dist(pos, rp) < 5.5:
			return
	map_trees.append(Vector3(pos.x, 1.0 if big else 0.0, pos.z))
	# Human woodland (east) mixes in KayKit oaks and pines so the two sides
	# read differently; the elven Wildwood keeps its grown, glowing trees.
	var tree_seed := absi(int(pos.x * 13 + pos.z * 7))
	if pos.x > 8.0 and tree_seed % 5 == 0:
		# Autumn pines: the Kingdom's woods turn orange and gold.
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
		_prop("halloween/tree_pine_%s_%s" % [["orange", "yellow"][tree_seed % 2], "large" if big else "medium"], pos + Vector3(0, 0.3, 0), 0.8 if big else 0.95, float(tree_seed))
		return
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
	var bark := _pbr("bark", 0.5, Color(0.95, 0.9, 0.85))
	if pos.x < -8.0 and seed % 4 == 1:
		_add_pine(tree, r, bark, big)
		return
	# Trunk and roots.
	var trunk_h: float = (3.4 if big else 2.5) * r.randf_range(0.9, 1.15)
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
	var autumn := seed % 7 == 0 and pos.x > -8.0
	var leaf := _leaf_material(r, autumn)
	var wild: bool = pos.x < -8.0
	if wild and seed % 2 == 0:
		# Wildwood palette: pale mint and lavender canopies that glow faintly.
		var lavender: bool = seed % 4 == 0
		# (The sun and the crown highlight brighten tops a lot, so these stay dark.)
		leaf.set_shader_parameter("top_color", Color.from_hsv(0.75, 0.6, 0.45) if lavender else Color.from_hsv(0.42, 0.75, 0.42))
		leaf.set_shader_parameter("bottom_color", Color.from_hsv(0.75, 0.75, 0.15) if lavender else Color.from_hsv(0.45, 0.85, 0.14))
	var radius: float = (1.9 if big else 1.4) * r.randf_range(0.9, 1.1) * (1.25 if wild else 1.0)
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
	if wild and seed % 3 == 0:
		_add_mushrooms(pos + Vector3(0.9, 0, 0.4), seed)
	if wild and seed % 4 == 1:
		_add_fireflies(pos + Vector3(0, 1.0, 0))
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


func _add_pine(tree: Node3D, r: RandomNumberGenerator, bark: Material, big: bool) -> void:
	## A conifer: a slim trunk and three stacked cones of dark needles.
	var trunk_h: float = (4.2 if big else 3.2) * r.randf_range(0.9, 1.1)
	var trunk := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.12
	tm.bottom_radius = 0.32
	tm.height = trunk_h
	tm.radial_segments = 7
	trunk.mesh = tm
	trunk.position.y = trunk_h / 2.0
	trunk.material_override = bark
	tree.add_child(trunk)
	var leaf := ShaderMaterial.new()
	leaf.shader = load("res://assets/shaders/leaf.gdshader")
	leaf.set_shader_parameter("noise_tex", load("res://assets/textures/water_noise.png"))
	var hue := r.randf_range(-0.02, 0.02)
	leaf.set_shader_parameter("bottom_color", Color.from_hsv(0.38 + hue, 0.75, 0.18))
	leaf.set_shader_parameter("top_color", Color.from_hsv(0.32 + hue, 0.7, 0.5))
	leaf.set_shader_parameter("height", 1.6)
	leaf.set_shader_parameter("sway", 0.03)
	var base_r: float = (1.9 if big else 1.5) * r.randf_range(0.9, 1.1)
	for i in 3:
		var cone := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = base_r * (1.0 - 0.25 * i)
		cm.height = trunk_h * 0.42
		cm.radial_segments = 8
		cm.rings = 2
		cone.mesh = cm
		cone.position.y = trunk_h * (0.42 + 0.22 * i)
		cone.rotation.y = r.randf() * TAU
		cone.material_override = leaf
		tree.add_child(cone)


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
	# Lily pads drift on the water away from the crossings.
	var lr := RandomNumberGenerator.new()
	lr.seed = 1917
	var pad_mat := _material(Color(0.36, 0.66, 0.30))
	pad_mat.roughness = 0.9
	var bud_mat := _material(Color(0.98, 0.62, 0.78))
	bud_mat.emission_enabled = true
	bud_mat.emission = Color(0.6, 0.25, 0.4)
	bud_mat.emission_energy_multiplier = 0.4
	for i in 34:
		var pz := lr.randf_range(-map_half.y + 1.0, map_half.y - 1.0)
		if _near_bridge(pz, 1.2):
			continue
		var pad := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = lr.randf_range(0.3, 0.48)
		pm.bottom_radius = pm.top_radius
		pm.height = 0.05
		pm.radial_segments = 9
		pad.mesh = pm
		pad.position = Vector3(lr.randf_range(-RIVER_HALF + 0.6, RIVER_HALF - 0.6), 0.075, pz)
		pad.rotation.y = lr.randf() * TAU
		pad.material_override = pad_mat
		add_child(pad)
		if i % 3 == 0:
			var bud := MeshInstance3D.new()
			var bm := SphereMesh.new()
			bm.radius = 0.11
			bm.height = 0.2
			bm.radial_segments = 6
			bm.rings = 3
			bud.mesh = bm
			bud.position = Vector3(0, 0.1, 0)
			bud.material_override = bud_mat
			pad.add_child(bud)
	# Banks: a stone kerb of warm grey blocks along the water's edge (like the
	# render's stacked-block banks), a pebbly strip behind it and a few boulders.
	var kerb := _pbr("rock", 0.45, Color(0.92, 0.9, 0.86))
	for sx in [-1.0, 1.0]:
		_add_block(Vector3(sx * (RIVER_HALF + 1.0), 0.012, 0), Vector3(1.6, 0.01, length), Color(0.6, 0.5, 0.35), false, _pbr("cobble", 0.6, Color(0.92, 0.86, 0.74)))
		var k := 0
		var z := -map_half.y - 2.0
		while z < map_half.y + 2.0:
			if not _near_bridge(z, 0.5):
				var kh: float = 0.32 + 0.14 * fmod(absf(z) * 3.7, 1.0)
				_add_block(Vector3(sx * (RIVER_HALF + 0.38), kh / 2.0 - 0.06, z + 0.55), Vector3(0.76, kh, 1.0), Color.WHITE, false, kerb)
			if k % 4 == 1 and not _near_bridge(z, 2.5) and absf(absf(z) - 25.5) > 5.5 and absf(z) < 34.0:
				_prop("hex/rock_single_%s" % ["A", "B", "C", "D", "E"][k % 5], Vector3(sx * (RIVER_HALF + 2.0 + fmod(z * 7.3, 1.0) * 0.4), 0, z), 2.5, z)
			k += 1
			z += 1.2
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
		_add_wall(Vector3(0, 0.75, rz), Vector3(RIVER_HALF * 2 + 1.6, 0.5, 0.5), false)
	# Bridges: a plank deck with rails and posts.
	for i in BRIDGES.size():
		if i == 1:
			continue  # the shrine island is the middle crossing
		var bz: float = BRIDGES[i]
		var half: float = BRIDGE_HALF[i]
		var deck_len := RIVER_HALF * 2 + 2.4
		# Ashlar abutments on each bank carry the timber stringers and planks.
		for xs in [-1.0, 1.0]:
			_add_block(Vector3(xs * (deck_len / 2.0 + 0.35), 0.17, bz), Vector3(1.1, 0.34, half * 2 + 1.0), Color.WHITE, false, _ashlar(Color(0.9, 0.86, 0.78)))
			_add_block(Vector3(xs * (deck_len / 2.0 + 0.35), 0.38, bz), Vector3(1.3, 0.08, half * 2 + 1.2), Color.WHITE, false, _ashlar(Color(0.94, 0.9, 0.82)))
		for zs in [-1.0, 1.0]:
			_add_block(Vector3(0, -0.1, bz + zs * (half - 0.3)), Vector3(deck_len, 0.26, 0.3), Color.WHITE, false, _timber(Color(0.72, 0.58, 0.44)))
		var planks := int(deck_len / 0.5)
		for k in planks:
			var px: float = -deck_len / 2.0 + (k + 0.5) * deck_len / planks
			var tint := Color(0.9, 0.78, 0.6) if k % 2 == 0 else Color(0.84, 0.7, 0.52)
			_add_block(Vector3(px, 0.06, bz), Vector3(deck_len / planks - 0.05, 0.1, half * 2), Color.WHITE, false, _plank_dark(tint))
		for zs in [-1.0, 1.0]:
			var rz: float = bz + zs * (half + 0.12)
			_add_railing(Vector3(-deck_len / 2.0 + 0.2, 0.1, rz), Vector3(deck_len / 2.0 - 0.2, 0.1, rz))
			_add_collider(Vector3(0, 0.6, rz), Vector3(deck_len, 1.2, 0.2))
		# Lanterns on the big bridge's abutments.
		if half > 2.5:
			for xs in [-1.0, 1.0]:
				for zs in [-1.0, 1.0]:
					_add_torch(Vector3(xs * (deck_len / 2.0 + 0.35), 0.42, bz + zs * (half + 0.3)))


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
	mesh.material_override = _flagstone(Color(0.96, 0.93, 0.88))
	plateau.add_child(mesh)
	add_child(plateau)
	# A paved ring and the shrine: a stepped dais, a gold crown on a plinth, four braziers.
	var inlay := MeshInstance3D.new()
	var im := TorusMesh.new()
	im.inner_radius = 3.5
	im.outer_radius = 3.75
	im.rings = 48
	im.ring_segments = 6
	inlay.mesh = im
	inlay.scale.y = 0.12
	inlay.position = Vector3(0, 0.5, 0)
	inlay.material_override = _gold()
	add_child(inlay)
	for tier in [[3.0, 3.3, 0.2, 0.6, Color(0.9, 0.86, 0.78)], [2.2, 2.5, 0.3, 0.85, Color(0.95, 0.92, 0.86)]]:
		var dais := MeshInstance3D.new()
		var dm := CylinderMesh.new()
		dm.top_radius = tier[0]
		dm.bottom_radius = tier[1]
		dm.height = tier[2]
		dm.radial_segments = 24
		dais.mesh = dm
		dais.position = Vector3(0, tier[3], 0)
		dais.material_override = _ashlar(tier[4])
		add_child(dais)
	_add_collider(Vector3(0, 1.3, 0), Vector3(1.6, 1.6, 1.6))
	_add_block(Vector3(0, 1.42, 0), Vector3(1.2, 0.9, 1.2), Color.WHITE, false, _ashlar(Color(0.95, 0.92, 0.86)))
	_add_block(Vector3(0, 1.9, 0), Vector3(1.4, 0.1, 1.4), Color.WHITE, false, _ashlar(Color(0.9, 0.86, 0.78)))
	var crown := MeshInstance3D.new()
	var crown_mesh := CylinderMesh.new()
	crown_mesh.top_radius = 0.55
	crown_mesh.bottom_radius = 0.42
	crown_mesh.height = 0.5
	crown_mesh.radial_segments = 8
	crown.mesh = crown_mesh
	crown.position = Vector3(0, 2.2, 0)
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
		spike.position = Vector3(cos(a) * 0.5, 2.6, sin(a) * 0.5)
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
		var foot := Vector3(sx * (ISLAND_R + 3.2), 0.0, 0)
		var head := Vector3(sx * (ISLAND_R - 0.4), 0.5, 0)
		_add_stairs(foot, head, 4.0, _ashlar(Color(0.95, 0.92, 0.86)), 1.0)
		_add_railing(foot + Vector3(0, 0, -1.92), head + Vector3(0, 0, -1.92))
		_add_torch(Vector3(sx * (ISLAND_R + 3.6), 0, -2.6))
		_add_torch(Vector3(sx * (ISLAND_R + 3.6), 0, 2.6))


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
	# Three cover designs cycle across the field: supply stacks, timber
	# palisades and broken ashlar walls, so the middle reads as a battlefield.
	var crates := ["hex/crate_A_big", "hex/crate_B_big", "hex/barrel", "hex/crate_A_big", "hex/barrel"]
	for bi in barricades.size():
		var b: Array = barricades[bi]
		for m in [1.0, -1.0]:
			var c: Vector3 = b[0] * m
			var length: float = b[1]
			_add_collider(Vector3(c.x, 0.6, c.z), Vector3(1.0, 1.2, length))
			cover_points.append(Vector3(c.x, 0, c.z))
			# Supply stacks on the road itself (an abandoned caravan); palisades
			# and broken walls alternate across the field.
			var kind: int = 0 if absf(c.z) < 3.0 else 1 + (bi % 2)
			match kind:
				0:
					var n := int(length / 1.15)
					for i in n:
						var z: float = c.z - length / 2.0 + (i + 0.5) * length / n
						var pick: int = absi(int(c.x * 3 + z * 5 + i)) % crates.size()
						_prop(crates[pick], Vector3(c.x, 0, z), 5.2, 0.0)
						if i % 2 == 0:
							_prop("hex/crate_A_big", Vector3(c.x, 1.05, z), 4.2, 0.0)
				1:
					_add_palisade(c, length)
				2:
					_add_wall_stub(c, length)
	var boulders := [Vector3(9, 0, -13), Vector3(13, 0, -18), Vector3(22, 0, 14), Vector3(33, 0, -8), Vector3(38, 0, 10),
		Vector3(8, 0, 28), Vector3(17, 0, 25), Vector3(14, 0, -36), Vector3(26, 0, -27), Vector3(40, 0, -22), Vector3(40, 0, 24)]
	for p in boulders:
		_add_boulder(p)
		_add_boulder(-p)
		cover_points.append(p)
		cover_points.append(-p)
	# The Northern Ruins: broken columns and rubble by the north bridge, and
	# a smaller ruin on the south river path. Mirrored.
	_add_ruins(Vector3(11, 0, -27))
	_add_ruins(Vector3(-11, 0, 27))
	_add_ruins(Vector3(-24, 0, -29), true)
	_add_ruins(Vector3(24, 0, 29), true)


func _add_signpost(pos: Vector3, lean: float) -> void:
	## A timber post with two arrow boards pointing along the paths.
	audit_label = "pole"
	_add_block(pos + Vector3(0, 1.0, 0), Vector3(0.16, 2.0, 0.16), Color.WHITE, false, _timber(Color(0.6, 0.5, 0.4)))
	audit_label = ""
	_add_block(pos + Vector3(0, 0.06, 0), Vector3(0.4, 0.12, 0.4), Color.WHITE, false, _ashlar(Color(0.85, 0.8, 0.72)))
	var board := _timber(Color(0.85, 0.72, 0.55))
	for k in 2:
		var b := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.95, 0.22, 0.06)
		b.mesh = bm
		b.position = pos + Vector3(0.25 * lean, 1.75 - 0.3 * k, 0)
		b.rotation.y = (0.55 if k == 0 else -0.6) * lean
		b.material_override = board
		add_child(b)
		var tip := MeshInstance3D.new()
		var tm := PrismMesh.new()
		tm.size = Vector3(0.22, 0.22, 0.06)
		tip.mesh = tm
		tip.position = Vector3(0.58, 0, 0)
		tip.rotation.z = -PI / 2.0
		tip.material_override = board
		b.add_child(tip)


func _add_palisade(c: Vector3, length: float) -> void:
	## Sharpened timber stakes in a row with a rail, like a camp's edge.
	audit_label = "fence"
	var post := _timber(Color(0.72, 0.6, 0.48))
	var dark := _timber(Color(0.55, 0.45, 0.35))
	var n := maxi(int(length / 0.42), 2)
	for i in n:
		var z: float = c.z - length / 2.0 + (i + 0.5) * length / n
		var h: float = 1.25 if i % 2 == 0 else 1.05
		_add_block(Vector3(c.x, h / 2.0, z), Vector3(0.22, h, 0.22), Color.WHITE, false, post if i % 2 == 0 else dark)
		var tip := MeshInstance3D.new()
		var tm := CylinderMesh.new()
		tm.top_radius = 0.0
		tm.bottom_radius = 0.16
		tm.height = 0.28
		tm.radial_segments = 4
		tip.mesh = tm
		tip.position = Vector3(c.x, h + 0.14, z)
		tip.rotation.y = PI / 4.0
		tip.material_override = dark
		add_child(tip)
	_add_block(Vector3(c.x, 0.72, c.z), Vector3(0.1, 0.1, length + 0.2), Color.WHITE, false, dark)
	audit_label = ""


func _add_wall_stub(c: Vector3, length: float) -> void:
	## A broken length of ashlar wall: tall at one end, crumbled at the other,
	## with rubble spilling off the low end. Mossy on the elven side.
	mossy = c.x < 0.0
	audit_label = "wall"
	var tall_len: float = length * 0.55
	var low_len: float = length - tall_len
	_add_block(Vector3(c.x, 0.65, c.z - low_len / 2.0), Vector3(0.6, 1.3, tall_len), Color.WHITE, false, _ashlar())
	_add_block(Vector3(c.x, 1.38, c.z - low_len / 2.0), Vector3(0.8, 0.16, tall_len + 0.2), Color.WHITE, false, _ashlar(Color(0.92, 0.88, 0.8)))
	_add_block(Vector3(c.x, 0.4, c.z + tall_len / 2.0), Vector3(0.6, 0.8, low_len), Color.WHITE, false, _ashlar(Color(0.9, 0.87, 0.8)))
	_add_block(Vector3(c.x, 0.9, c.z + tall_len / 2.0 - low_len / 4.0), Vector3(0.6, 0.2, low_len / 2.0), Color.WHITE, false, _ashlar(Color(0.88, 0.85, 0.78)))
	audit_label = ""
	_prop("dungeon/rubble_large", Vector3(c.x + 0.4, 0, c.z + length / 2.0 + 0.7), 0.22, 0.4)
	mossy = false


func _add_ruins(c: Vector3, small: bool = false) -> void:
	## A ruined hall: a flagstone floor, broken ashlar walls with their
	## merlons, standing and fallen columns, rubble and ivy. Mirrored by x.
	map_marks.append([c, "ruin"])
	mossy = true
	var m: float = -1.0 if c.x < 0.0 else 1.0
	_add_block(c + Vector3(0, 0.02, 0), Vector3(8.0 if not small else 5.0, 0.03, 6.5 if not small else 4.0), Color.WHITE, false, _flagstone(Color(0.9, 0.88, 0.84)))
	if small:
		_add_wall(c + Vector3(-1.8 * m, 0.55, 0), Vector3(0.6, 1.1, 2.6), false)
		for z in [-1.2, 1.2]:
			var p := c + Vector3(1.6 * m, 0, z)
			_prop("dungeon/column", p, 1.2, 0.0)
			_add_collider(p + Vector3(0, 1.0, 0), Vector3(0.9, 2.0, 0.9))
		_prop("dungeon/rubble_large", c + Vector3(-0.3 * m, 0, -1.4), 0.3, 0.2)
		_add_collider(c + Vector3(-0.3 * m, 0.4, -1.4), Vector3(2.2, 0.8, 0.9))
		_add_bush(c + Vector3(-2.4 * m, 0, 1.6), int(c.z))
		mossy = false
		return
	_add_wall(c + Vector3(-3.6 * m, 0.7, -0.6), Vector3(0.6, 1.4, 3.6), true)
	_add_wall(c + Vector3(-2.0 * m, 0.45, -3.0), Vector3(3.2, 0.9, 0.6), false)
	for col in [[Vector3(2.6, 0, -1.8), 1.3], [Vector3(2.6, 0, 1.8), 1.5], [Vector3(-0.6, 0, 1.9), 1.2]]:
		var p: Vector3 = c + Vector3(col[0].x * m, 0, col[0].z)
		_prop("dungeon/column", p, col[1], 0.0)
		_add_collider(p + Vector3(0, 1.0, 0), Vector3(0.9, 2.0, 0.9))
	# A fallen column lying across the floor.
	var fallen := MeshInstance3D.new()
	var fm := CylinderMesh.new()
	fm.top_radius = 0.32
	fm.bottom_radius = 0.36
	fm.height = 2.6
	fm.radial_segments = 8
	fallen.mesh = fm
	fallen.position = c + Vector3(0.5 * m, 0.36, -1.5)
	fallen.rotation.z = PI / 2.0
	fallen.material_override = _ashlar(Color(0.9, 0.87, 0.8))
	add_child(fallen)
	audit_blocks.append(["wall", AABB(fallen.position - Vector3(1.3, 0.36, 0.36), Vector3(2.6, 0.72, 0.72))])
	_add_collider(c + Vector3(0.5 * m, 0.35, -1.5), Vector3(2.6, 0.7, 0.7))
	_prop("dungeon/rubble_large", c + Vector3(3.6 * m, 0, -0.5), 0.4, 0.0)
	_add_collider(c + Vector3(3.6 * m, 0.5, -0.5), Vector3(1.6, 1.0, 1.2))
	_prop("dungeon/barrier", c + Vector3(0, 0, 0.4), 0.8, 0.0)
	_add_collider(c + Vector3(0, 0.6, 0.4), Vector3(2.2, 1.2, 0.6))
	_add_bush(c + Vector3(3.8 * m, 0, 2.4), int(c.x))
	_add_bush(c + Vector3(-3.0 * m, 0, 1.6), int(c.z))
	mossy = false


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
	if mossy:
		_add_lantern(pos)
		return
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
	## A class seal on its pedestal (see seal.gd). The floor pad under it
	## matches the castle: flagstone for Humans, mossy flagstone for Elves.
	stations[team][role] = pos
	var color: Color = Stats.ROLES[role].color
	_add_block(pos + Vector3(0, 0.05, 0), Vector3(2.2, 0.1, 2.2), color.darkened(0.3), false, _flagstone(Color(0.6, 0.68, 0.55) if team == 0 else Color(0.7, 0.62, 0.5)))
	var seal := Seal.new()
	add_child(seal)
	seal.setup(self, team, role, pos)
	seals[team][role] = seal


# --- The castle kit -----------------------------------------------------------
# Every castle piece is built from the same three materials so both bases read
# as one art style (the reference renders): cream ashlar stone, warm timber and
# the team colour on roofs, rugs and banners. Props are placed with clearance
# from every wall; `--audit` lists anything that still overlaps.

var mossy := false   # while an elven castle is being built: ivy and moss on its stone


func _ashlar(tint: Color = Color.WHITE) -> StandardMaterial3D:
	## Castle stone; the elven castle is grown, so its "stone" is living bark.
	if mossy:
		return _pbr("bark", 0.55, tint * Color(0.72, 0.7, 0.58))
	return _pbr("stone", 0.42, tint * Color(0.93, 0.9, 0.84))


func _elf_leaf(bright: bool = false) -> StandardMaterial3D:
	## Pale, faintly glowing wildwood foliage for the elven castle's canopies and tufts.
	# Kept saturated and mid-value: pale greens blow out to white in the sun.
	var m := _material(Color.from_hsv(0.41, 0.6, 0.4) if bright else Color.from_hsv(0.4, 0.75, 0.3))
	m.roughness = 0.9
	return m


func _add_lantern(pos: Vector3, height: float = 2.2) -> void:
	## An elven lantern: a slim pole with a glowing teal globe.
	audit_label = "pole"
	_add_block(pos + Vector3(0, height / 2.0, 0), Vector3(0.14, height, 0.14), Color.WHITE, false, _ashlar(Color(0.7, 0.65, 0.5)))
	audit_label = ""
	var globe := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.26
	sph.height = 0.52
	globe.mesh = sph
	var gm := _material(Color(0.7, 1.0, 0.9))
	gm.emission_enabled = true
	gm.emission = Color(0.45, 0.95, 0.8)
	gm.emission_energy_multiplier = 2.2
	globe.material_override = gm
	globe.position = pos + Vector3(0, height + 0.2, 0)
	add_child(globe)
	_add_block(pos + Vector3(0, height + 0.5, 0), Vector3(0.22, 0.08, 0.22), Color.WHITE, false, _gold())
	var light := OmniLight3D.new()
	light.light_color = Color(0.55, 1.0, 0.85)
	light.light_energy = 1.4
	light.omni_range = 7.0
	light.position = pos + Vector3(0, height + 0.4, 0)
	add_child(light)


func _add_trunk_pillar(pos: Vector3, height: float) -> void:
	## A living trunk holding up the elven keep, tufted with leaves at the top.
	var trunk := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.42
	cyl.bottom_radius = 0.62
	cyl.height = height
	trunk.mesh = cyl
	trunk.position = pos + Vector3(0, height / 2.0, 0)
	trunk.material_override = _pbr("bark", 0.6, Color(0.8, 0.76, 0.62))
	add_child(trunk)
	for i in 3:
		var tuft := MeshInstance3D.new()
		tuft.mesh = _rock_mesh(int(pos.x * 7 + pos.z * 3) + i, 0.7, 0.15)
		var a := TAU * i / 3.0
		tuft.position = pos + Vector3(cos(a) * 0.5, height + 0.2, sin(a) * 0.5)
		tuft.material_override = _elf_leaf(i == 0)
		add_child(tuft)


func _add_mushrooms(pos: Vector3, seed: int) -> void:
	## A cluster of glowing wildwood mushrooms.
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var cap_mat := _material(Color(0.55, 0.8, 1.0) if seed % 2 == 0 else Color(0.8, 0.6, 1.0))
	cap_mat.emission_enabled = true
	cap_mat.emission = cap_mat.albedo_color
	cap_mat.emission_energy_multiplier = 1.6
	var stem_mat := _material(Color(0.92, 0.9, 0.8))
	for i in 3:
		var h: float = r.randf_range(0.25, 0.55)
		var p := pos + Vector3(r.randf_range(-0.6, 0.6), 0, r.randf_range(-0.6, 0.6))
		var stem := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.06
		cyl.bottom_radius = 0.09
		cyl.height = h
		stem.mesh = cyl
		stem.position = p + Vector3(0, h / 2.0, 0)
		stem.material_override = stem_mat
		add_child(stem)
		var cap := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = h * 0.55
		sph.height = h * 0.6
		cap.mesh = sph
		cap.position = p + Vector3(0, h, 0)
		cap.material_override = cap_mat
		add_child(cap)


func _flagstone(tint: Color = Color.WHITE) -> StandardMaterial3D:
	return _pbr("flagstone_moss" if mossy else "flagstone", 0.42, tint * Color(0.95, 0.92, 0.86))


func _timber(tint: Color = Color.WHITE) -> StandardMaterial3D:
	return _pbr("wood", 0.8, tint)


func _marble(tint: Color = Color.WHITE) -> StandardMaterial3D:
	## Polished cream marble (tools/make_textures.py) for the human keep's floor.
	var m := _pbr("marble", 0.3, tint)
	m.roughness = 0.35
	return m


func _carpet(color: Color) -> StandardMaterial3D:
	## A woven rug texture tinted to the team colour.
	var m := _pbr("carpet", 0.5, color.lightened(0.1))
	m.roughness = 1.0
	return m


func _sand() -> StandardMaterial3D:
	return _pbr("sand", 0.3)


func _moss() -> StandardMaterial3D:
	return _pbr("moss", 0.25)


func _plank_dark(tint: Color = Color.WHITE) -> StandardMaterial3D:
	return _pbr("wood_dark", 0.8, tint)


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
	if mossy:
		# Grown walls: a vine ledge along the top and leaf tufts instead of merlons.
		_add_block(Vector3(center.x, top + 0.1, center.z), Vector3(size.x + 0.2, 0.2, size.z + 0.2), Color.WHITE, false, _elf_leaf())
	else:
		_add_block(Vector3(center.x, top + 0.1, center.z), Vector3(size.x + 0.2, 0.2, size.z + 0.2), Color.WHITE, false, _ashlar(Color(0.92, 0.88, 0.8)))
	if not merlons:
		return
	var n := maxi(int(length / 1.3), 1)
	for k in n:
		var t := -length / 2.0 + (k + 0.5) * length / n
		var p := Vector3(center.x + t, top + 0.5, center.z) if along_x else Vector3(center.x, top + 0.5, center.z + t)
		var ms := Vector3(0.6, 0.6, thick) if along_x else Vector3(thick, 0.6, 0.6)
		if mossy:
			var tuft := MeshInstance3D.new()
			tuft.mesh = _rock_mesh(int(p.x * 5 + p.z * 11), 0.45, 0.15)
			tuft.position = p - Vector3(0, 0.1, 0)
			tuft.material_override = _elf_leaf(k % 3 == 0)
			add_child(tuft)
		else:
			_add_block(p, ms, Color.WHITE, false, _ashlar(Color(0.9, 0.86, 0.78)))


func _add_tower(pos: Vector3, team: int, side: float, width: float = 2.6, height: float = 5.4, flag: bool = true) -> void:
	## A square corner tower with a crenellated top and a team-coloured roof.
	var color: Color = Stats.FACTIONS[team].color
	_add_block(pos + Vector3(0, height / 2.0, 0), Vector3(width, height, width), Color.WHITE, true, _ashlar())
	_add_block(pos + Vector3(0, height + 0.15, 0), Vector3(width + 0.5, 0.3, width + 0.5), Color.WHITE, false, _ashlar(Color(0.92, 0.88, 0.8)))
	if mossy:
		# An elven tree-tower: the trunk carries a glowing canopy instead of a roof,
		# with a lantern hung beneath it.
		var r := RandomNumberGenerator.new()
		r.seed = int(pos.x * 3 + pos.z * 17)
		var canopy := _leaf_material(r, false)
		canopy.set_shader_parameter("top_color", Color.from_hsv(0.42, 0.7, 0.4))
		canopy.set_shader_parameter("bottom_color", Color.from_hsv(0.45, 0.85, 0.14))
		for i in 4:
			var blob := MeshInstance3D.new()
			var rr: float = width * (0.8 if i == 0 else r.randf_range(0.45, 0.6))
			blob.mesh = _rock_mesh(r.randi(), rr, 0.12)
			var a := TAU * i / 4.0 + 0.6
			var spread: float = 0.0 if i == 0 else width * 0.45
			blob.position = pos + Vector3(cos(a) * spread, height + 0.9 + (0.5 if i == 0 else r.randf_range(-0.2, 0.5)), sin(a) * spread)
			blob.scale = Vector3(1.0, 0.8, 1.0)
			blob.material_override = canopy
			add_child(blob)
		var globe := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = 0.22
		sph.height = 0.44
		globe.mesh = sph
		var gm := _material(Color(0.7, 1.0, 0.9))
		gm.emission_enabled = true
		gm.emission = Color(0.45, 0.95, 0.8)
		gm.emission_energy_multiplier = 2.0
		globe.material_override = gm
		globe.position = pos + Vector3(-side * (width / 2.0 + 0.4), height - 0.6, 0)
		add_child(globe)
		var light := OmniLight3D.new()
		light.light_color = Color(0.55, 1.0, 0.85)
		light.light_energy = 1.2
		light.omni_range = 7.0
		light.position = globe.position
		add_child(light)
		if flag:
			_add_flag(pos + Vector3(0, height + 2.6, 0), team, side)
		return
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
	roof.material_override = _pbr("shingle", 1.1, color.lightened(0.1))
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
	## A torch in an iron bracket on a wall face (a glowing crystal for the elves).
	if mossy:
		_add_crystal(pos + out * 0.35 - Vector3(0, 1.0, 0), 0.55)
		var cl := OmniLight3D.new()
		cl.light_color = Color(0.55, 1.0, 0.85)
		cl.light_energy = 1.1
		cl.omni_range = 6.0
		cl.position = pos + out * 0.8 + Vector3(0, 0.4, 0)
		add_child(cl)
		return
	_prop("dungeon/torch_mounted", pos, 1.3, atan2(out.x, out.z))
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.72, 0.4)
	light.light_energy = 1.3
	light.omni_range = 6.0
	light.position = pos + out * 0.8 + Vector3(0, 0.7, 0)
	add_child(light)


func _add_rug(center: Vector3, size: Vector2, color: Color) -> void:
	## A team-coloured rug with a gold border.
	_add_block(center + Vector3(0, 0.015, 0), Vector3(size.x, 0.03, size.y), color, false, _carpet(color))
	for xs in [-1.0, 1.0]:
		_add_block(center + Vector3(xs * (size.x / 2.0 - 0.12), 0.032, 0), Vector3(0.16, 0.01, size.y), color, false, _gold())
	for zs in [-1.0, 1.0]:
		_add_block(center + Vector3(0, 0.032, zs * (size.y / 2.0 - 0.12)), Vector3(size.x, 0.01, 0.16), color, false, _gold())


# ---------------------------------------------------------------------------
# Furniture: what fills the keeps and cellars (lit by chandeliers that cast
# shadows). Nothing here is solid, so bots never snag on a bench.
# ---------------------------------------------------------------------------

func _iron() -> StandardMaterial3D:
	var m := _material(Color(0.28, 0.29, 0.33))
	m.metallic = 0.6
	m.roughness = 0.5
	return m


func _add_flame(pos: Vector3, radius: float, color: Color) -> void:
	var f := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = radius
	sph.height = radius * 2.4
	f.mesh = sph
	var fm := _material(color.darkened(0.25))
	fm.emission_enabled = true
	fm.emission = color
	fm.emission_energy_multiplier = 0.9
	f.material_override = fm
	f.position = pos
	add_child(f)


func _add_chandelier(pos: Vector3, elven: bool, shadows: bool = true) -> void:
	## A ring of candles (Humans) or a crown of crystals (Elves) hanging on a
	## chain, with the room's main light under it. `pos` is the ring's centre.
	var chain_top := pos + Vector3(0, 2.2, 0)
	_add_block((pos + chain_top) / 2.0, Vector3(0.06, 2.2, 0.06), Color.WHITE, false, _iron() if not elven else _ashlar(Color(0.5, 0.42, 0.3)))
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.62
	tm.outer_radius = 0.78
	tm.rings = 24
	ring.mesh = tm
	ring.material_override = _iron() if not elven else _timber(Color(0.5, 0.42, 0.3))
	ring.position = pos
	add_child(ring)
	var light := OmniLight3D.new()
	light.position = pos - Vector3(0, 0.15, 0)
	light.shadow_enabled = shadows
	light.shadow_bias = 0.08
	if elven:
		for k in 6:
			var a: float = k * TAU / 6.0
			_add_crystal(pos + Vector3(cos(a) * 0.68, -0.55, sin(a) * 0.68), 0.22)
		_add_crystal(pos + Vector3(0, -0.75, 0), 0.3)
		light.light_color = Color(0.6, 1.0, 0.88)
		light.light_energy = 1.7
		light.omni_range = 11.0
	else:
		for k in 8:
			var a: float = k * TAU / 8.0
			var c := pos + Vector3(cos(a) * 0.7, 0.16, sin(a) * 0.7)
			_add_block(c, Vector3(0.09, 0.26, 0.09), Color.WHITE, false, _material(Color(0.95, 0.9, 0.78)))
			_add_flame(c + Vector3(0, 0.2, 0), 0.06, Color(1.0, 0.6, 0.15))
		light.light_color = Color(1.0, 0.76, 0.42)
		light.light_energy = 1.9
		light.omni_range = 11.0
	add_child(light)


func _add_candle_stand(pos: Vector3) -> void:
	_add_block(pos + Vector3(0, 0.05, 0), Vector3(0.34, 0.1, 0.34), Color.WHITE, false, _iron())
	_add_block(pos + Vector3(0, 0.65, 0), Vector3(0.06, 1.2, 0.06), Color.WHITE, false, _iron())
	_add_block(pos + Vector3(0, 1.3, 0), Vector3(0.1, 0.22, 0.1), Color.WHITE, false, _material(Color(0.95, 0.9, 0.78)))
	_add_flame(pos + Vector3(0, 1.48, 0), 0.06, Color(1.0, 0.6, 0.15))
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.72, 0.4)
	light.light_energy = 0.7
	light.omni_range = 4.0
	light.position = pos + Vector3(0, 1.6, 0)
	add_child(light)


func _add_brazier(pos: Vector3) -> void:
	## An iron fire bowl on three legs.
	for k in 3:
		var a: float = k * TAU / 3.0
		_add_block(pos + Vector3(cos(a) * 0.25, 0.35, sin(a) * 0.25), Vector3(0.07, 0.7, 0.07), Color.WHITE, false, _iron())
	var bowl := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.45
	cm.bottom_radius = 0.25
	cm.height = 0.3
	bowl.mesh = cm
	bowl.material_override = _iron()
	bowl.position = pos + Vector3(0, 0.8, 0)
	add_child(bowl)
	_add_flame(pos + Vector3(0, 1.05, 0), 0.2, Color(1.0, 0.45, 0.08))
	_add_flame(pos + Vector3(0.08, 1.22, 0.04), 0.1, Color(1.0, 0.7, 0.2))
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.3)
	light.light_energy = 1.3
	light.omni_range = 6.0
	light.position = pos + Vector3(0, 1.5, 0)
	add_child(light)


func _add_table(pos: Vector3, size: Vector2, rot_y: float, elven: bool, laid: bool = true) -> void:
	## A trestle table with its top at 0.85 m, laid with plates, goblets and a candle.
	var top_mat := _timber(Color(0.68, 0.56, 0.42)) if not elven else _ashlar(Color(0.55, 0.48, 0.34))
	var t := Node3D.new()
	t.position = pos
	t.rotation.y = rot_y
	add_child(t)
	var top := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(size.x, 0.1, size.y)
	top.mesh = bm
	top.material_override = top_mat
	top.position = Vector3(0, 0.8, 0)
	t.add_child(top)
	for xs in [-1.0, 1.0]:
		for zs in [-1.0, 1.0]:
			var leg := MeshInstance3D.new()
			var lm := BoxMesh.new()
			lm.size = Vector3(0.12, 0.78, 0.12)
			leg.mesh = lm
			leg.material_override = top_mat
			leg.position = Vector3(xs * (size.x / 2.0 - 0.2), 0.39, zs * (size.y / 2.0 - 0.2))
			t.add_child(leg)
		# Benches along the long sides.
		var bench := MeshInstance3D.new()
		var bmm := BoxMesh.new()
		bmm.size = Vector3(size.x - 0.4, 0.08, 0.34)
		bench.mesh = bmm
		bench.material_override = top_mat
		bench.position = Vector3(0, 0.45, xs * (size.y / 2.0 + 0.35))
		t.add_child(bench)
	if not laid:
		return
	var n := int(size.x / 1.0)
	for k in n:
		var x: float = -size.x / 2.0 + 0.6 + k * ((size.x - 1.2) / maxf(n - 1, 1))
		for zs in [-1.0, 1.0]:
			var plate := MeshInstance3D.new()
			var pm := CylinderMesh.new()
			pm.top_radius = 0.17
			pm.bottom_radius = 0.15
			pm.height = 0.03
			plate.mesh = pm
			plate.material_override = _material(Color(0.85, 0.82, 0.74)) if not elven else _elf_leaf(true)
			plate.position = Vector3(x, 0.87, zs * 0.22)
			t.add_child(plate)
			var cup := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.06
			cm.bottom_radius = 0.045
			cm.height = 0.14
			cup.mesh = cm
			cup.material_override = _gold()
			cup.position = Vector3(x + 0.28, 0.92, zs * 0.12)
			t.add_child(cup)
	var mid := t.to_global(Vector3(0, 0.85, 0))
	if elven:
		_add_mushrooms(mid, 31)
	else:
		_add_block(mid + Vector3(0, 0.12, 0), Vector3(0.09, 0.24, 0.09), Color.WHITE, false, _material(Color(0.95, 0.9, 0.78)))
		_add_flame(mid + Vector3(0, 0.3, 0), 0.05, Color(1.0, 0.6, 0.15))
		_prop("hex/sack", t.to_global(Vector3(size.x / 2.0 - 0.5, 0.86, 0)), 1.6, 0.4)


func _add_bookshelf(pos: Vector3, out: Vector3, elven: bool) -> void:
	## A case of books (scrolls and jars for the elves) against a wall; `out` faces the room.
	var rot := atan2(out.x, out.z)
	var case_mat := _timber(Color(0.6, 0.48, 0.36)) if not elven else _ashlar(Color(0.5, 0.42, 0.3))
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = rot
	add_child(n)
	var back := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.8, 2.1, 0.08)
	back.mesh = bm
	back.material_override = case_mat
	back.position = Vector3(0, 1.05, -0.26)
	n.add_child(back)
	for xs in [-1.0, 1.0]:
		var sidep := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(0.08, 2.1, 0.6)
		sidep.mesh = sm
		sidep.material_override = case_mat
		sidep.position = Vector3(xs * 0.86, 1.05, 0)
		n.add_child(sidep)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pos.x * 7 + pos.z * 13)
	for shelf in 4:
		var y: float = 0.1 + shelf * 0.52
		var plank := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(1.72, 0.06, 0.6)
		plank.mesh = pm
		plank.material_override = case_mat
		plank.position = Vector3(0, y, 0)
		n.add_child(plank)
		var x := -0.76
		while x < 0.7:
			var w := rng.randf_range(0.08, 0.16)
			var book := MeshInstance3D.new()
			var km := BoxMesh.new()
			var h := rng.randf_range(0.28, 0.42)
			km.size = Vector3(w, h, 0.4) if not elven else Vector3(w * 1.3, w * 1.3, 0.4)
			book.mesh = km
			var hue := rng.randf()
			book.material_override = _material(Color.from_hsv(hue, 0.55, 0.55) if not elven else Color.from_hsv(0.35 + hue * 0.2, 0.5, 0.7))
			book.position = Vector3(x + w / 2.0, y + (h / 2.0 if not elven else w * 0.65) + 0.03, 0.02)
			n.add_child(book)
			x += w + rng.randf_range(0.0, 0.06)
			if elven:
				x += 0.12


func _add_tapestry(team: int, pos: Vector3, out: Vector3, width: float = 1.6, height: float = 2.0) -> void:
	## A hanging cloth on a wall: team colour with a gold rod and crest stripe.
	var color: Color = Stats.FACTIONS[team].color
	var rot := atan2(out.x, out.z)
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = rot
	add_child(n)
	var rod := MeshInstance3D.new()
	var rm := CylinderMesh.new()
	rm.top_radius = 0.04
	rm.bottom_radius = 0.04
	rm.height = width + 0.3
	rod.mesh = rm
	rod.rotation.z = PI / 2.0
	rod.material_override = _gold()
	rod.position = Vector3(0, height, 0.1)
	n.add_child(rod)
	var cloth := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(width, height - 0.1, 0.04)
	cloth.mesh = cm
	cloth.material_override = _cloth(color.darkened(0.1))
	cloth.position = Vector3(0, height / 2.0 - 0.05, 0.08)
	n.add_child(cloth)
	var stripe := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(width * 0.7, 0.12, 0.05)
	stripe.mesh = sm
	stripe.material_override = _gold()
	stripe.position = Vector3(0, height * 0.72, 0.1)
	n.add_child(stripe)
	var crest := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(width * 0.5, width * 0.5)
	crest.mesh = qm
	var qmat := StandardMaterial3D.new()
	qmat.albedo_texture = load("res://assets/ui/icons/%s.png" % ("crest_forest" if team == 0 else "crest_kingdom"))
	qmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	crest.material_override = qmat
	crest.position = Vector3(0, height * 0.42, 0.11)
	n.add_child(crest)


func _add_bedroll(pos: Vector3, rot_y: float, color: Color) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = rot_y
	add_child(n)
	var roll := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.9, 0.12, 2.0)
	roll.mesh = bm
	roll.material_override = _cloth(color.darkened(0.35))
	roll.position = Vector3(0, 0.06, 0)
	n.add_child(roll)
	var pillow := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.6, 0.14, 0.4)
	pillow.mesh = pm
	pillow.material_override = _material(Color(0.9, 0.86, 0.78))
	pillow.position = Vector3(0, 0.17, -0.7)
	n.add_child(pillow)


func _furnish_keep(team: int, kx: float, bx: float, side: float, throne: Vector3) -> void:
	## Rugs, chandeliers, a feasting table, shelves and clutter in the keep,
	## kept to the strips beside the throne so the lanes stay clear.
	var color: Color = Stats.FACTIONS[team].color
	var elven := team == 0
	var khz := KEEP_HALF_Z
	# Side rugs between the columns and a round-cornered one on the dais.
	for zs in [-1.0, 1.0]:
		_add_rug(Vector3(kx + side * 6.0, 0.04, zs * 5.8), Vector2(6.0, 1.9), color.darkened(0.15))
	# Chandeliers: one over the archway hall, one over the throne.
	_add_chandelier(Vector3(kx + side * 2.6, 2.1, 0), elven)
	_add_chandelier(Vector3(kx + side * 9.8, 2.1, 0), elven)
	for zs in [-1.0, 1.0]:
		var wz: float = zs * (khz - 0.45)   # the inner face of a side wall
		var ins := Vector3(0, 0, -zs)
		# The feasting table along the wall between the two columns (KayKit
		# dungeon and furniture models), laid with food and candles.
		var tpos := Vector3(kx + side * 6.0, 0, zs * 6.6)
		if elven:
			_prop("furniture/table_medium_long", tpos, BITS_SCALE, 0.0)
			for k in 3:
				var fx: float = tpos.x - 0.6 + k * 0.6
				_prop("kitchen/%s" % ["bowl", "jar_B_medium", "food_stew"][k], Vector3(fx, 0.6, tpos.z + 0.1 * (k - 1)), BITS_SCALE * 0.8, float(k))
			_prop("dungeon/candle_triple", Vector3(tpos.x + 0.9, 0.6, tpos.z - 0.2), 0.45)
			for k in 2:
				_prop("dungeon/stool", tpos + Vector3(-0.5 + k * 1.0, 0, -zs * 0.95), BITS_SCALE, 0.0)
		else:
			_prop("dungeon/table_long_tablecloth_decorated_A", tpos, 0.62, PI / 2.0)
			for k in 3:
				_prop("dungeon/chair", tpos + Vector3(-0.9 + k * 0.9, 0, -zs * 0.95), BITS_SCALE, PI if zs > 0.0 else 0.0)
		# Tapestries on the side walls, shelves in the back corners.
		_add_tapestry(team, Vector3(kx + side * 2.2, 0.5, wz), ins, 1.5, 1.9)
		_add_tapestry(team, Vector3(kx + side * 10.0, 0.5, wz), ins, 1.5, 1.9)
		var shelf_pos := Vector3(bx - side * 1.1, 0, zs * (khz - 2.6))
		if elven:
			_prop("dungeon/shelves", shelf_pos, 0.7, -PI / 2.0 * side)
			_prop("kitchen/jar_A_large", shelf_pos + Vector3(-side * 0.2, 1.3, -0.4), BITS_SCALE * 0.7)
			_prop("kitchen/jar_C_medium", shelf_pos + Vector3(-side * 0.2, 1.3, 0.3), BITS_SCALE * 0.7)
			_prop("dungeon/bottle_A_green", shelf_pos + Vector3(-side * 0.2, 0.95, 0.0), 0.5)
		else:
			_prop("dungeon/shelves", shelf_pos, 0.7, -PI / 2.0 * side)
			_prop("dungeon/plate_stack", shelf_pos + Vector3(-side * 0.2, 1.3, -0.35), 0.5)
			_prop("dungeon/bottle_B_brown", shelf_pos + Vector3(-side * 0.2, 1.3, 0.3), 0.5)
			_prop("dungeon/coin_stack_small", shelf_pos + Vector3(-side * 0.2, 0.95, 0.0), 0.4)
		if elven:
			_add_mushrooms(Vector3(kx + side * 10.6, 0, zs * (khz - 1.0)), 41 + int(zs))
			_add_mushrooms(Vector3(kx + side * 4.0, 0, zs * (khz - 2.1)), 45 + int(zs))
			_prop("dungeon/trunk_large_A", Vector3(kx + side * 12.0, 0, zs * 4.6), 0.7, 0.3 * zs)
		else:
			_add_brazier(Vector3(kx + side * 4.0, 0, zs * (khz - 2.1)))
			_add_candle_stand(Vector3(kx + side * 8.3, 0, zs * 5.0))
			_prop("dungeon/keg", Vector3(kx + side * 12.0, 0, zs * 4.6), 0.6, 0.3 * zs)
			_prop("dungeon/barrel_small_stack", Vector3(kx + side * 12.3, 0, zs * 3.2), 0.6, 0.8 * zs)
	# A map table near the archway (humans) or a shrine stone (elves), off the lane.
	if elven:
		_add_fireflies(Vector3(kx + side * 3.0, 0.5, 5.5))
	else:
		_add_candle_stand(Vector3(kx + side * 1.4, 0, 6.4))
		_add_candle_stand(Vector3(kx + side * 1.4, 0, -6.4))


func _furnish_cellar(team: int, bx: float, side: float) -> void:
	## Beam, chandeliers and bunks in the spawn cellar.
	var color: Color = Stats.FACTIONS[team].color
	var elven := team == 0
	var hz := CELLAR_HALF_Z
	# Two chandeliers over the hall.
	for k in 2:
		var x: float = bx + side * (3.5 + k * 4.5)
		_add_chandelier(Vector3(x, CELLAR_Y + 2.5, 0), elven)
	# Bunks along the far wall either side of the spawn ring, a shelf of
	# supplies and candles.
	for zs in [-1.0, 1.0]:
		for k in 2:
			# Two bunks end to end against the side wall, clear of the seal pads
			# (and with no gap between them for anyone to get wedged in).
			var bpos := Vector3(bx + side * (9.3 - k * 1.9), CELLAR_Y, zs * (hz - 0.6))
			if elven:
				_prop("dungeon/bed_floor", bpos, 0.65, PI / 2.0)
			else:
				_prop("furniture/bed_single_%s" % ["A", "B"][k], bpos, BITS_SCALE, PI / 2.0)
		if elven:
			_prop("dungeon/shelves", Vector3(bx + side * 1.4, CELLAR_Y, zs * (hz - 0.5)), 0.7, PI if zs > 0.0 else 0.0)
			_prop("dungeon/bottle_A_labeled_green", Vector3(bx + side * 1.4, CELLAR_Y + 0.95, zs * (hz - 0.75)), 0.5)
		else:
			_prop("dungeon/shelves", Vector3(bx + side * 1.4, CELLAR_Y, zs * (hz - 0.5)), 0.7, PI if zs > 0.0 else 0.0)
			_prop("dungeon/bottle_A_labeled_brown", Vector3(bx + side * 1.4, CELLAR_Y + 0.95, zs * (hz - 0.75)), 0.5)
		if elven:
			_add_mushrooms(Vector3(bx + side * 5.0, CELLAR_Y, zs * (hz - 0.6)), 51 + int(zs))
		else:
			_add_candle_stand(Vector3(bx + side * 5.0, CELLAR_Y, zs * (hz - 0.6)))
	_add_rug(Vector3(bx + side * 5.5, CELLAR_Y, 0), Vector2(5.0, 3.0), color.darkened(0.15))


# ---------------------------------------------------------------------------
# The outskirts: everything beyond the walls that makes the world a place.
# Hamlets on the castles' north flanks, farms on the south, a lumber camp
# and a mine behind the cellars, lantern posts along the road, water plants
# in the river, the old barrow in the Wildwood. All decor: outside the lanes.
# ---------------------------------------------------------------------------

const HOUSE_SCALE := 3.8   # hex pack buildings (the pack's hex tile is ~2 units across)
const BITS_SCALE := 0.6    # KayKit "bits" packs (furniture, kitchen, halloween): 1 unit is about 60 cm here
# Roof heights of the hex buildings (pack units) so chimney smoke sits on top.
const HOUSE_HEIGHT := {"home_A": 0.93, "home_B": 0.93, "tavern": 1.4, "church": 1.65, "lumbermill": 1.3, "blacksmith": 0.99,
	"barracks": 1.64, "mine": 1.14, "windmill": 1.19, "market": 0.98, "well": 0.83, "archeryrange": 1.79}


func _add_hex_fence(pos: Vector3, along_x: bool) -> void:
	## A hex-pack fence piece (its mesh sits 1.05 units off its origin in x), centred on `pos`.
	if along_x:
		_prop("hex/fence_wood_straight", pos + Vector3(0, 0, -1.05 * 4.0), 4.0, PI / 2.0)
	else:
		_prop("hex/fence_wood_straight", pos + Vector3(1.05 * 4.0, 0, 0), 4.0, 0.0)


func _add_house(kind: String, team: int, pos: Vector3, scale: float, rot_y: float, smoke: bool = true) -> void:
	## A hex-pack building in the team's colour, with a collider and chimney smoke.
	var lift: float = 0.24 * scale if kind == "lumbermill" else (0.5 * scale if kind == "windmill" else 0.0)
	_prop("hex/building_%s_%s" % [kind, _hex_color(team)], pos + Vector3(0, lift, 0), scale, rot_y)
	_add_blocker(pos, 0.55 * scale)
	if smoke:
		_add_smoke(pos + Vector3(0.1 * scale, (HOUSE_HEIGHT.get(kind, 1.0) * 0.95) * scale, -0.05 * scale), 10, scale / 3.8)


func _add_light(pos: Vector3, color: Color, energy: float, range_m: float, shadows: bool = false) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = range_m
	light.shadow_enabled = shadows
	light.position = pos
	add_child(light)
	return light


func _add_smoke(pos: Vector3, amount: int = 10, scale: float = 1.0) -> void:
	## Chimney smoke: grey puffs drifting up and leeward.
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = 3.2
	p.preprocess = 3.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.12 * scale
	p.direction = Vector3(0.25, 1, 0.1)
	p.spread = 12.0
	p.gravity = Vector3(0.15, 0.35, 0)
	p.initial_velocity_min = 0.5 * scale
	p.initial_velocity_max = 0.8 * scale
	p.scale_amount_min = 0.4 * scale
	p.scale_amount_max = 0.7 * scale
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.5))
	curve.add_point(Vector2(0.6, 1.0))
	curve.add_point(Vector2(1, 1.4))
	p.scale_amount_curve = curve
	var grad := Gradient.new()
	grad.set_color(0, Color(0.9, 0.9, 0.92, 0.8))
	grad.set_color(1, Color(0.75, 0.75, 0.8, 0.0))
	p.color_ramp = grad
	var sph := SphereMesh.new()
	sph.radius = 0.5
	sph.height = 1.0
	sph.radial_segments = 6
	sph.rings = 3
	p.mesh = sph
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	p.material_override = m
	p.position = pos
	add_child(p)


func _add_blocker(pos: Vector3, radius: float, height: float = 3.0) -> void:
	## An invisible round collider so nobody walks through a building.
	var body := StaticBody3D.new()
	body.position = pos
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = height
	shape.shape = cyl
	shape.position.y = height / 2.0
	body.add_child(shape)
	add_child(body)
	audit_blocks.append(["building", AABB(pos - Vector3(radius, 0, radius), Vector3(radius * 2, height, radius * 2))])


func _build_outskirts() -> void:
	for sx in [-1.0, 1.0]:
		var team := 0 if sx < 0.0 else 1
		_build_hamlet(team, sx)
		_build_farm(team, sx)
		_build_works(team, sx)
	_add_road_lanterns()
	_add_river_plants()
	_add_barrow(Vector3(-30, 0, 22))
	_add_watermills()
	_add_field_rocks()
	_add_clouds()
	_add_ground_patches()
	_add_ambient_life()


func _add_ground_patches() -> void:
	## Sandy strips along the river banks and moss beds under the Wildwood trees.
	var sand := _sand()
	for sx in [-1.0, 1.0]:
		var z := -map_half.y - 2.0
		while z < map_half.y + 2.0:
			var blocked := absf(z) < ISLAND_R + 1.5
			for b in BRIDGES:
				if absf(z - b) < 3.2:
					blocked = true
			if not blocked:
				_add_block(Vector3(sx * (RIVER_HALF + 0.9), 0.004, z + 2.0), Vector3(1.6, 0.008, 4.0), Color.WHITE, false, sand)
			z += 4.0
	var moss := _moss()
	var r := RandomNumberGenerator.new()
	r.seed = 606
	for t in map_trees:
		if t.x < -8.0 and r.randf() < 0.6:
			var size := r.randf_range(2.4, 4.2)
			_add_block(Vector3(t.x + r.randf_range(-0.6, 0.6), 0.003, t.z + r.randf_range(-0.6, 0.6)), Vector3(size, 0.006, size * r.randf_range(0.7, 1.0)), Color.WHITE, false, moss)


func _hex_color(team: int) -> String:
	return "green" if team == 0 else "blue"


func _build_hamlet(team: int, sx: float) -> void:
	## A village on the castle's north flank, its lane facing the field.
	var c := _hex_color(team)
	var ox := sx * 62.0
	var oz := -45.0
	var face := 0.0 if sx > 0.0 else PI      # doors toward the field (-z is "up" on screen)
	var row := [["home_A", -9.0, 3.8], ["tavern", -2.5, 3.8], ["home_B", 3.5, 3.8], ["church" if team == 1 else "lumbermill", 9.5, 3.6]]
	var back := [["market", -5.5, 3.2], ["well", 0.5, 3.4], ["blacksmith" if team == 1 else "archeryrange", 6.0, 3.6]]
	if team == 0:
		# The Forest lives in the trees: tree-houses in place of cottages and the tavern.
		row = [["treehouse", -9.5, 1.0], ["market", -2.5, 3.2], ["treehouse", 3.5, 0.92], ["lumbermill", 9.5, 3.6]]
		back = [["treehouse", -5.0, 1.1], ["well", 0.5, 3.4], ["archeryrange", 6.5, 3.6]]
	for b in row:
		if b[0] == "treehouse":
			_add_treehouse(Vector3(ox + sx * b[1], 0, oz - 0.5), int(b[1] * 7.0) + 11, b[2])
		else:
			_add_house(b[0], team, Vector3(ox + sx * b[1], 0, oz), b[2], face)
	for b in back:
		if b[0] == "treehouse":
			_add_treehouse(Vector3(ox + sx * b[1], 0, oz - 6.5), int(b[1] * 5.0) + 23, b[2])
		else:
			_add_house(b[0], team, Vector3(ox + sx * b[1], 0, oz - 5.5), b[2], face, b[0] == "blacksmith")
	if team == 0:
		for k in 4:
			_add_mushrooms(Vector3(ox + sx * (-12.0 + k * 7.0), 0, oz + 1.6 + (k % 2) * 0.8), 500 + k)
		_add_fireflies(Vector3(ox, 0, oz - 3.0))
	# Chickens scratching about the lane.
	for k in 4:
		_add_critter("chicken", Vector3(ox - 7.0 + k * 4.0, 0, oz + 2.4), Rect2(ox - 9.0, oz + 1.9, 18.0, 1.1), 700 + k)
	# Market clutter, a cart, fences along the lane, lanterns at the corners.
	_prop("hex/crate_A_big", Vector3(ox + sx * -7.2, 0, oz - 2.9), 4.0, 0.3)
	_prop("hex/sack", Vector3(ox + sx * -6.3, 0, oz - 2.7), 4.0, 1.0)
	_prop("hex/barrel", Vector3(ox + sx * -4.0, 0, oz - 3.0), 4.0)
	_prop("hex/wheelbarrow", Vector3(ox + sx * 1.2, 0, oz - 2.6), 4.0, 0.6)
	_prop("hex/crate_open", Vector3(ox + sx * 12.3, 0, oz - 1.6), 4.0, 0.2)
	_prop("hex/resource_lumber" if team == 0 else "hex/resource_stone", Vector3(ox + sx * 12.6, 0, oz - 3.8), 4.0, 0.0)
	for x in [ox - 13.2, ox + 13.2]:
		if team == 0:
			_add_lantern(Vector3(x, 0, oz + 3.0), 2.4)
		else:
			_prop("halloween/post_lantern", Vector3(x, 0, oz + 3.0), 0.75)
			_add_light(Vector3(x, 2.4, oz + 3.0), Color(1.0, 0.75, 0.4), 1.1, 7.0)
	# Trees hugging the village.
	for k in 6:
		var tx: float = ox - 14.0 + k * 5.8
		_prop("hex/trees_%s_medium" % ["A", "B"][k % 2], Vector3(tx + (k % 2) * 1.5, 0, oz - 9.5), 4.2, float(k))
	for x in [ox - 15.5, ox + 15.5]:
		_prop("hex/tree_single_A", Vector3(x, 0, oz - 2.0), 4.6, x)
		_prop("hex/tree_single_B", Vector3(x, 0, oz - 6.5), 4.2, x * 0.7)


func _build_farm(team: int, sx: float) -> void:
	## Fields and a windmill on the castle's south flank.
	var c := _hex_color(team)
	var ox := sx * 60.0
	var oz := 44.0
	for j in 2:
		_add_wheat(Vector3(ox - 1.0, 0, oz + 2.6 + j * 4.6), Vector2(17.0, 3.6), 300 + j)
	_add_house("windmill", team, Vector3(ox + 12.5, 0, oz + 3.0), 4.4, PI if sx > 0.0 else 0.0, false)
	if team == 0:
		_add_treehouse(Vector3(ox - 13.0, 0, oz + 4.5), 37, 1.0)
	else:
		_add_house("home_A", team, Vector3(ox - 13.0, 0, oz + 4.0), 3.6, PI)
	_add_sheep_pen(Vector3(ox - 1.0, 0, oz + 14.6), team)
	_prop("hex/wheelbarrow", Vector3(ox - 10.0, 0, oz - 1.0), 4.0, 2.4)
	_prop("hex/sack", Vector3(ox + 9.0, 0, oz - 1.2), 4.0, 0.3)
	_prop("hex/sack", Vector3(ox + 9.8, 0, oz - 0.6), 4.0, 1.9)
	_prop("hex/bucket_water", Vector3(ox + 10.6, 0, oz - 1.4), 4.0)
	# Pumpkins ripening at the field's edge (orange for the Kingdom, yellow for the Forest).
	var pk := "orange" if team == 1 else "yellow"
	for k in 5:
		_prop("halloween/pumpkin_%s%s" % [pk, "_small" if k % 2 == 1 else ""], Vector3(ox - 9.0 + k * 2.1, 0, oz + 10.5 + (k % 2) * 0.8), BITS_SCALE, float(k) * 1.3)


func _add_wheat(center: Vector3, size: Vector2, seed: int) -> void:
	## A plot of ripe wheat: a dirt bed under a MultiMesh of gold stalks.
	var soil := _material(Color(0.38, 0.26, 0.15))
	soil.roughness = 1.0
	_add_block(center + Vector3(0, 0.005, 0), Vector3(size.x + 0.6, 0.01, size.y + 0.6), Color.WHITE, false, soil)
	# Furrows: darker ridges running the long way across the plot.
	var furrow := _material(Color(0.3, 0.2, 0.11))
	furrow.roughness = 1.0
	var nf := int(size.y / 0.9)
	for f in nf:
		var fz: float = center.z - size.y / 2.0 + 0.45 + f * 0.9
		_add_block(Vector3(center.x, 0.012, fz), Vector3(size.x + 0.2, 0.012, 0.3), Color.WHITE, false, furrow)
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var stalk := CylinderMesh.new()
	stalk.top_radius = 0.09
	stalk.bottom_radius = 0.02
	stalk.height = 1.0
	stalk.radial_segments = 4
	stalk.rings = 1
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = stalk
	var count := int(size.x * size.y * 9.0)
	mm.instance_count = count
	for i in count:
		var pos := center + Vector3(r.randf_range(-size.x / 2.0, size.x / 2.0), 0.5, r.randf_range(-size.y / 2.0, size.y / 2.0))
		var t := Transform3D(Basis.from_euler(Vector3(r.randf_range(-0.12, 0.12), r.randf() * TAU, r.randf_range(-0.12, 0.12))).scaled(Vector3(1, r.randf_range(0.8, 1.15), 1)), pos)
		mm.set_instance_transform(i, t)
		mm.set_instance_color(i, Color.from_hsv(0.12 + r.randf() * 0.03, 0.6, 0.75 + r.randf() * 0.2))
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	var m := _material(Color.WHITE)
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.9
	inst.material_override = m
	add_child(inst)
	# Heads of grain: a second, shorter mesh of fat gold tips.
	var head := CapsuleMesh.new()
	head.radius = 0.06
	head.height = 0.3
	head.radial_segments = 4
	head.rings = 1
	var hm := MultiMesh.new()
	hm.transform_format = MultiMesh.TRANSFORM_3D
	hm.use_colors = true
	hm.mesh = head
	hm.instance_count = count
	for i in count:
		var t := mm.get_instance_transform(i)
		hm.set_instance_transform(i, Transform3D(t.basis, t.origin + t.basis.y * 0.55))
		hm.set_instance_color(i, Color.from_hsv(0.11, 0.7, 0.85))
	var hinst := MultiMeshInstance3D.new()
	hinst.multimesh = hm
	hinst.material_override = m
	add_child(hinst)


func _build_works(team: int, sx: float) -> void:
	## Behind the cellar: the Kingdom's mine, the Forest's lumber camp, and
	## mountains on the horizon.
	var c := _hex_color(team)
	var x := sx * 93.0
	_add_house("mine" if team == 1 else "lumbermill", team, Vector3(x, 0, 14.0), 4.0, -PI / 2.0 * sx, team == 1)
	if team == 1:
		_add_house("barracks", team, Vector3(x, 0, -14.0), 3.6, -PI / 2.0 * sx)
	else:
		_add_treehouse(Vector3(x, 0, -14.0), 53, 1.08)
	for k in 3:
		_prop("hex/resource_%s" % ["stone" if team == 1 else "lumber"], Vector3(x - sx * 5.0, 0, 9.5 + k * 2.4), 4.0, float(k) * 0.7)
	_prop("hex/tent", Vector3(x - sx * 4.0, 0, -8.5), 4.0, 0.4 * sx)
	_prop("hex/flag_%s" % c, Vector3(x - sx * 6.0, 0, -11.5), 4.0)
	_prop("hex/trees_%s_large" % ["A" if team == 0 else "B"], Vector3(x - sx * 2.0, 0, 22.0), 4.4, 1.0)
	_prop("hex/trees_%s_large" % ["B" if team == 0 else "A"], Vector3(x + sx * 4.0, 0, -22.0), 4.4, 2.0)
	for zs in [-1.0, 1.0]:
		_prop("hex/mountain_%s_grass_trees" % ["A", "B", "C"][int(zs + 1.0 + (0.0 if sx < 0.0 else 1.0)) % 3], Vector3(sx * 112.0, -0.3, zs * 26.0), 10.0, sx * zs)
	_prop("hex/mountain_B_grass", Vector3(sx * 116.0, -0.3, 0.0), 10.0, sx)
	# The camp between the two buildings: a fire, a second tent, stores.
	_add_campfire(Vector3(x - sx * 6.5, 0, -3.0))
	_prop("hex/crate_long_A", Vector3(x - sx * 8.5, 0, -6.0), 4.0, 0.3)
	_prop("hex/pallet", Vector3(x - sx * 8.0, 0, 3.5), 4.0)
	_prop("hex/sack", Vector3(x - sx * 8.2, 0, 3.6), 3.6, 0.5)
	_prop("hex/bucket_water", Vector3(x - sx * 5.0, 0, -0.6), 4.0)
	_prop("hex/wheelbarrow", Vector3(x - sx * 3.0, 0, 6.5), 4.0, 2.2 * sx)
	if team == 1:
		# Kingdom: drill yard by the barracks and a half-built wall.
		_prop("hex/weaponrack", Vector3(x + sx * 4.5, 0, -9.0), 4.0, PI / 2.0)
		_prop("hex/target", Vector3(x + sx * 5.5, 0, -17.5), 4.0, PI)
		_prop("hex/target", Vector3(x + sx * 7.0, 0, -16.5), 4.0, PI + 0.4)
		_prop("hex/bucket_arrows", Vector3(x + sx * 4.0, 0, -11.0), 4.0)
		_prop("hex/building_scaffolding", Vector3(x + sx * 5.0, 0, 2.0), 2.8, PI / 2.0)
		_add_blocker(Vector3(x + sx * 5.0, 0, 2.0), 2.4, 3.0)
		for k in 4:
			_prop("hex/rock_single_%s" % ["C", "E", "D", "B"][k], Vector3(x + sx * (1.5 + k * 1.3), 0, 10.0 + (k % 2) * 1.4), 3.6, float(k) * 1.3)
	else:
		# Forest: a clearing of fresh stumps, logs and a saw-horse of planks.
		_prop("hex/trees_A_cut", Vector3(x + sx * 4.0, 0, 2.0), 4.0, 0.7)
		for k in 3:
			_prop("hex/tree_single_%s_cut" % ["A", "B", "A"][k], Vector3(x + sx * (2.0 + k * 2.2), 0, 7.5 + (k % 2) * 1.2), 4.0, float(k))
		_prop("hex/resource_lumber", Vector3(x + sx * 5.0, 0, 11.0), 4.0, PI / 2.0)
		_prop("hex/crate_long_B", Vector3(x + sx * 3.5, 0, -9.5), 4.0, 0.6)
	# Trodden earth where the carts turn.
	_add_soil_patch(Vector3(x - sx * 5.0, 0, 0.5), 1.7, Color(0.3, 0.21, 0.12))


func _add_treehouse(pos: Vector3, seed: int, k: float = 1.0) -> void:
	## An elven home up a living tree: a round plank platform with a rope rail,
	## a bark-walled hut under a leaf cone, a spiral of steps round the trunk,
	## a hanging lantern and the tree's own glowing crown around the roof.
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var body := StaticBody3D.new()
	body.position = pos
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.8 * k
	cyl.height = 4.0
	shape.shape = cyl
	shape.position.y = 2.0
	body.add_child(shape)
	add_child(body)
	var root := Node3D.new()
	root.position = pos
	root.scale = Vector3.ONE * k
	root.rotation.y = r.randf() * TAU
	add_child(root)
	var bark := _pbr("bark", 0.5, Color(0.9, 0.86, 0.78))
	var pale_bark := _pbr("bark", 0.45, Color(1.0, 0.96, 0.84))
	var planks := _plank_dark(Color(0.85, 0.8, 0.7))
	var rope := _material(Color(0.55, 0.45, 0.3))
	# Trunk and roots.
	var trunk := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.5
	tm.bottom_radius = 0.85
	tm.height = 5.6
	tm.radial_segments = 8
	trunk.mesh = tm
	trunk.position.y = 2.8
	trunk.material_override = bark
	root.add_child(trunk)
	for i in 5:
		var rt := MeshInstance3D.new()
		var rm := CylinderMesh.new()
		rm.top_radius = 0.12
		rm.bottom_radius = 0.3
		rm.height = 1.4
		rm.radial_segments = 5
		rt.mesh = rm
		var a := TAU * i / 5.0 + 0.3
		rt.position = Vector3(cos(a) * 0.9, 0.3, sin(a) * 0.9)
		rt.rotation = Vector3(0, -a, 0)
		rt.rotate_z(-1.15)
		rt.material_override = bark
		root.add_child(rt)
	# Spiral steps up the trunk.
	for i in 9:
		var st := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(0.9, 0.1, 0.42)
		st.mesh = sm
		var a := -0.4 + float(i) * 0.42
		st.position = Vector3(cos(a) * 1.05, 0.35 + float(i) * 0.34, sin(a) * 1.05)
		st.rotation.y = -a
		st.material_override = planks
		root.add_child(st)
	# Platform, braces and rope rail.
	var plat := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 2.5
	pm.bottom_radius = 2.3
	pm.height = 0.22
	pm.radial_segments = 14
	plat.mesh = pm
	plat.position.y = 3.3
	plat.material_override = planks
	root.add_child(plat)
	for i in 6:
		var br := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.14, 1.9, 0.14)
		br.mesh = bm
		var a := TAU * i / 6.0
		br.position = Vector3(cos(a) * 1.3, 2.5, sin(a) * 1.3)
		br.rotation = Vector3(0, -a, 0)
		br.rotate_z(0.75)
		br.material_override = bark
		root.add_child(br)
	for i in 12:
		var post := MeshInstance3D.new()
		var pbm := BoxMesh.new()
		pbm.size = Vector3(0.1, 0.8, 0.1)
		post.mesh = pbm
		var a := TAU * i / 12.0
		post.position = Vector3(cos(a) * 2.3, 3.8, sin(a) * 2.3)
		post.material_override = planks
		root.add_child(post)
	var rail := MeshInstance3D.new()
	var rlm := TorusMesh.new()
	rlm.inner_radius = 2.26
	rlm.outer_radius = 2.34
	rlm.rings = 28
	rlm.ring_segments = 5
	rail.mesh = rlm
	rail.position.y = 4.15
	rail.material_override = rope
	root.add_child(rail)
	# The hut: bark walls, a dark door, a lit window, a cone of leaves.
	var hut := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 1.45
	hm.bottom_radius = 1.55
	hm.height = 2.1
	hm.radial_segments = 10
	hut.mesh = hm
	hut.position.y = 4.45
	hut.material_override = pale_bark
	root.add_child(hut)
	var door := MeshInstance3D.new()
	var dm := BoxMesh.new()
	dm.size = Vector3(0.7, 1.3, 0.12)
	door.mesh = dm
	door.position = Vector3(0, 4.05, 1.52)
	door.material_override = _plank_dark(Color(0.5, 0.42, 0.32))
	root.add_child(door)
	var win := MeshInstance3D.new()
	var wm := BoxMesh.new()
	wm.size = Vector3(0.12, 0.5, 0.5)
	win.mesh = wm
	win.position = Vector3(1.52, 4.7, 0)
	var glow := _material(Color(0.9, 0.95, 0.7))
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.85, 0.45)
	glow.emission_energy_multiplier = 1.0
	win.material_override = glow
	root.add_child(win)
	var roof := MeshInstance3D.new()
	var rfm := CylinderMesh.new()
	rfm.top_radius = 0.0
	rfm.bottom_radius = 2.0
	rfm.height = 1.6
	rfm.radial_segments = 10
	roof.mesh = rfm
	roof.position.y = 6.3
	var thatch := _material(Color(0.5, 0.62, 0.3))
	thatch.roughness = 1.0
	roof.material_override = thatch
	root.add_child(roof)
	var finial := MeshInstance3D.new()
	var fm := SphereMesh.new()
	fm.radius = 0.16
	fm.height = 0.32
	finial.mesh = fm
	finial.position.y = 7.15
	finial.material_override = _gold()
	root.add_child(finial)
	# The crown: glowing wildwood canopy blobs in a ring round the platform,
	# below the roof line so the hut stays in view from above.
	var canopy := _leaf_material(r, false)
	canopy.set_shader_parameter("top_color", Color.from_hsv(0.43, 0.65, 0.42))
	canopy.set_shader_parameter("bottom_color", Color.from_hsv(0.46, 0.85, 0.16))
	for i in 6:
		var blob := MeshInstance3D.new()
		var rr: float = r.randf_range(0.85, 1.15)
		blob.mesh = _rock_mesh(r.randi(), rr, 0.12)
		var a := TAU * i / 6.0 + 0.4
		blob.position = Vector3(cos(a) * 2.9, 5.0 + r.randf_range(-0.3, 0.5), sin(a) * 2.9)
		blob.material_override = canopy
		root.add_child(blob)
	# A lantern hung under the platform's edge.
	var globe := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.22
	sph.height = 0.44
	globe.mesh = sph
	var gm := _material(Color(0.7, 1.0, 0.9))
	gm.emission_enabled = true
	gm.emission = Color(0.45, 0.95, 0.8)
	gm.emission_energy_multiplier = 2.0
	globe.material_override = gm
	globe.position = Vector3(1.9, 2.75, 1.0)
	root.add_child(globe)
	var chain := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(0.04, 0.4, 0.04)
	chain.mesh = cm
	chain.position = Vector3(1.9, 3.05, 1.0)
	chain.material_override = rope
	root.add_child(chain)
	var light := OmniLight3D.new()
	light.light_color = Color(0.55, 1.0, 0.85)
	light.light_energy = 1.2
	light.omni_range = 7.0
	light.position = Vector3(1.9, 2.6, 1.0)
	root.add_child(light)


func _add_critter(kind: String, pos: Vector3, pen: Rect2, seed: int = 0) -> void:
	var c := Node3D.new()
	c.set_script(load("res://scripts/critter.gd"))
	add_child(c)
	c.setup(kind, pos, pen, seed)


func _add_sheep_pen(center: Vector3, team: int) -> void:
	## A fenced paddock with a small flock, below the wheat.
	var hw := 7.0
	var hd := 2.2
	for k in 3:
		var fx: float = center.x - 4.4 + k * 4.4
		_add_hex_fence(Vector3(fx, 0, center.z - hd), true)
		_add_hex_fence(Vector3(fx, 0, center.z + hd), true)
	_add_hex_fence(Vector3(center.x - hw, 0, center.z), false)
	_add_hex_fence(Vector3(center.x + hw, 0, center.z), false)
	_prop("hex/bucket_water", center + Vector3(hw - 1.0, 0, hd - 0.8), 4.0)
	_prop("hex/sack", center + Vector3(-hw + 1.2, 0, -hd + 0.7), 3.4, 0.4)
	for k in 4 if team == 1 else 3:
		_add_critter("sheep", center + Vector3(-4.0 + k * 2.6, 0, (k % 2) * 1.2 - 0.6), Rect2(center.x - hw + 1.0, center.z - hd + 0.8, hw * 2.0 - 2.0, hd * 2.0 - 1.6), 800 + k)


func _add_ambient_life() -> void:
	## Leaves on the wind, butterflies over the flowers and birds overhead.
	for spot: Vector3 in [Vector3(-45.0, 7.0, -8.0), Vector3(45.0, 7.0, 8.0)]:
		var p := CPUParticles3D.new()
		var elven: bool = spot.x < 0.0
		p.amount = 140 if elven else 90
		p.lifetime = 9.0
		p.preprocess = 9.0
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		p.emission_box_extents = Vector3(34.0, 1.0, 40.0)
		p.direction = Vector3(0.3, -1.0, 0.1)
		p.spread = 30.0
		p.initial_velocity_min = 0.3
		p.initial_velocity_max = 0.7
		p.gravity = Vector3(0, -0.55, 0)
		p.angular_velocity_min = -120.0
		p.angular_velocity_max = 120.0
		p.scale_amount_min = 0.7
		p.scale_amount_max = 1.2
		var quad := QuadMesh.new()
		quad.size = Vector2(0.2, 0.14)
		p.mesh = quad
		var m := StandardMaterial3D.new()
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.vertex_color_use_as_albedo = true
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color.WHITE
		p.material_override = m
		var ramp := Gradient.new()
		if elven:
			ramp.set_color(0, Color(0.6, 0.95, 0.8))
			ramp.set_color(1, Color(0.75, 0.6, 0.95, 0.0))
		else:
			ramp.set_color(0, Color(0.95, 0.55, 0.15))
			ramp.set_color(1, Color(0.8, 0.3, 0.1, 0.0))
		p.color_ramp = ramp
		p.position = spot
		add_child(p)
	var spots := [Vector3(-20, 0, 12), Vector3(-34, 0, -9), Vector3(-14, 0, -24), Vector3(20, 0, -12), Vector3(34, 0, 9), Vector3(14, 0, 24), Vector3(-26, 0, 26), Vector3(28, 0, -27)]
	for i in spots.size():
		var sp: Vector3 = spots[i]
		for k in 2:
			_add_critter("butterfly", sp + Vector3(k * 1.5, 0, k * 0.8), Rect2(sp.x - 4.0, sp.z - 4.0, 8.0, 8.0), 900 + i * 2 + k)
	for i in 4:
		var b := Node3D.new()
		b.set_script(load("res://scripts/critter.gd"))
		add_child(b)
		b.setup("bird", Vector3(0, 12, 0), Rect2(), 950 + i)
		b.orbit(Vector3(float(i - 1.5) * 6.0, 0, -8.0 + float(i % 2) * 14.0), 24.0 + float(i) * 2.5, 11.0 + float(i) * 0.6)
		b.orbit_phase = float(i) * 0.35


func _add_soil_patch(pos: Vector3, radius: float, color: Color = Color(0.4, 0.28, 0.17)) -> void:
	## A flat disc of bare earth.
	var d := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = 0.02
	cm.radial_segments = 14
	d.mesh = cm
	var m := _material(color)
	m.roughness = 1.0
	d.material_override = m
	d.position = pos + Vector3(0, 0.01, 0)
	add_child(d)


func _add_campfire(pos: Vector3) -> void:
	## A ring of stones round burning logs, with a warm light and a thread of smoke.
	var stone := _material(Color(0.42, 0.4, 0.37))
	stone.roughness = 1.0
	for k in 8:
		var a := float(k) * TAU / 8.0
		var rock := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.24
		sm.height = 0.3
		sm.radial_segments = 6
		sm.rings = 3
		rock.mesh = sm
		rock.material_override = stone
		rock.position = pos + Vector3(cos(a) * 0.9, 0.1, sin(a) * 0.9)
		rock.rotation.y = a
		add_child(rock)
	_add_soil_patch(pos, 0.8, Color(0.2, 0.16, 0.12))
	var wood := _material(Color(0.3, 0.2, 0.12))
	for k in 3:
		var log := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.09
		cm.bottom_radius = 0.09
		cm.height = 1.1
		cm.radial_segments = 6
		log.mesh = cm
		log.material_override = wood
		log.position = pos + Vector3(0, 0.2, 0)
		log.rotation = Vector3(0, float(k) * TAU / 3.0, PI / 2.0 - 0.35)
		add_child(log)
	_add_flame(pos + Vector3(0, 0.45, 0), 0.3, Color(1.0, 0.42, 0.08))
	_add_flame(pos + Vector3(0.1, 0.7, -0.08), 0.16, Color(1.0, 0.7, 0.2))
	_add_light(pos + Vector3(0, 1.6, 0), Color(1.0, 0.62, 0.3), 1.4, 9.0, true)
	_add_smoke(pos + Vector3(0, 1.1, 0), 8, 0.7)
	_add_blocker(pos, 1.0, 1.5)


func _add_watermills() -> void:
	## A mill wheel on each team's bank, well away from the bridges.
	for sx in [-1.0, 1.0]:
		var team := 0 if sx < 0.0 else 1
		var z: float = sx * 30.0
		var pos := Vector3(sx * (RIVER_HALF + 3.2), 0, z)
		var mill := _prop("hex/building_watermill_%s" % _hex_color(team), pos, 3.4, -PI / 2.0 if sx > 0.0 else PI / 2.0)
		if mill != null:
			# The pack's wheel hides under the floor; ours turns in the river.
			for w in mill.find_children("*wheel*", "", true, false):
				w.visible = false
		_add_waterwheel(Vector3(sx * (RIVER_HALF - 0.4), 0.35, z), sx)
		_add_blocker(pos, 2.0, 4.0)
		map_marks.append([pos, "mill"])
		_add_light(pos + Vector3(sx * 1.5, 2.2, 0), Color(1.0, 0.8, 0.5), 0.8, 5.0)
		_prop("hex/sack", pos + Vector3(sx * 2.6, 0, 1.6), 3.6, 0.9)
		_prop("hex/sack", pos + Vector3(sx * 3.1, 0, 0.9), 3.6, 2.1)
		_prop("hex/crate_B_small", pos + Vector3(sx * 2.9, 0, -1.8), 4.0, 0.4)


func _add_waterwheel(pos: Vector3, sx: float) -> void:
	## A turning paddle wheel on an axle into the mill, its bottom in the water.
	var hub := Node3D.new()
	hub.position = pos
	add_child(hub)
	var wood := _material(Color(0.36, 0.24, 0.13))
	wood.roughness = 0.9
	var dark := _material(Color(0.26, 0.17, 0.09))
	for side in [-0.32, 0.32]:
		var rim := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 1.05
		tm.outer_radius = 1.2
		tm.rings = 24
		tm.ring_segments = 8
		rim.mesh = tm
		rim.material_override = wood
		rim.rotation.z = PI / 2.0
		rim.position.x = side
		hub.add_child(rim)
	for k in 8:
		var a := float(k) * TAU / 8.0
		var spoke := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.7, 2.2, 0.1)
		spoke.mesh = bm
		spoke.material_override = dark
		spoke.rotation.x = a
		hub.add_child(spoke)
		var paddle := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.8, 0.36, 0.08)
		paddle.mesh = pm
		paddle.material_override = wood
		paddle.position = Vector3(0, cos(a) * 1.12, sin(a) * 1.12)
		paddle.rotation.x = a
		hub.add_child(paddle)
	var axle := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.1
	cm.bottom_radius = 0.1
	cm.height = 3.2
	axle.mesh = cm
	axle.material_override = dark
	axle.rotation.z = PI / 2.0
	axle.position.x = sx * 1.5
	hub.add_child(axle)
	var tw := create_tween().set_loops()
	tw.tween_property(hub, "rotation:x", TAU * sx, 7.0).from(0.0)


func _add_field_rocks() -> void:
	## Low stones scattered over the open field, kept off the lanes and bridges.
	var r := RandomNumberGenerator.new()
	r.seed = 909
	var placed := 0
	var tries := 0
	while placed < 18 and tries < 200:
		tries += 1
		var x := r.randf_range(-40.0, 40.0)
		var z := r.randf_range(-33.0, 33.0)
		if absf(x) < RIVER_HALF + 4.0 or absf(z) < 6.0:
			continue
		if Vector2(x, z).distance_to(Vector2(-30.0, 22.0)) < 9.0:
			continue
		if absf(absf(z) - 30.0) < 6.0 and absf(x) < RIVER_HALF + 8.0:
			continue   # the watermills
		var near_tree := false
		for t in map_trees:
			if Vector2(t.x, t.z).distance_to(Vector2(x, z)) < 2.5:
				near_tree = true
				break
		if near_tree:
			continue
		_prop("hex/rock_single_%s" % ["A", "B", "C", "D", "E"][r.randi() % 5], Vector3(x, 0, z), r.randf_range(2.2, 3.4), r.randf() * TAU)
		if r.randf() < 0.4:
			_prop("hex/rock_single_%s" % ["A", "B"][r.randi() % 2], Vector3(x + 0.9, 0, z + 0.5), 1.8, r.randf() * TAU)
		placed += 1


func _add_clouds() -> void:
	## Slow clouds over the mountains and the far hills, never over the field.
	var spots := [
		[Vector3(-106.0, 14.0, -20.0), "cloud_big", 3.4], [Vector3(108.0, 15.0, 18.0), "cloud_big", 3.2],
		[Vector3(-102.0, 13.0, 24.0), "cloud_small", 3.0], [Vector3(104.0, 13.5, -26.0), "cloud_small", 3.2],
		[Vector3(-34.0, 13.0, -64.0), "cloud_small", 2.8], [Vector3(38.0, 14.0, 66.0), "cloud_big", 2.6],
		[Vector3(0.0, 15.0, -70.0), "cloud_big", 3.0], [Vector3(-6.0, 14.0, 70.0), "cloud_small", 3.0],
	]
	for i in spots.size():
		var sp: Array = spots[i]
		var n := _prop("hex/" + sp[1], sp[0], sp[2], float(i) * 0.9)
		if n == null:
			continue
		var tw := create_tween().set_loops()
		var drift := Vector3(7.0 if i % 2 == 0 else -7.0, 0, 0)
		tw.tween_property(n, "position", sp[0] + drift, 36.0 + i * 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(n, "position", sp[0], 36.0 + i * 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _add_road_lanterns() -> void:
	## Lantern posts along the main road, lit day and night.
	for sx in [-1.0, 1.0]:
		for k in 3:
			var x: float = sx * (10.0 + k * 16.0)
			var z: float = 3.9 if k % 2 == 1 else -3.9
			_prop("halloween/post_lantern", Vector3(x, 0, z), 0.75, PI / 2.0 if z > 0.0 else -PI / 2.0)
			_add_light(Vector3(x, 2.4, z), Color(1.0, 0.75, 0.4), 1.0, 6.5)
	# Benches to sit on by the shrine island's bridges.
	for sx in [-1.0, 1.0]:
		_prop("halloween/bench", Vector3(sx * (ISLAND_R + 4.5), 0, 4.2), BITS_SCALE, PI if sx > 0.0 else 0.0)


func _add_river_plants() -> void:
	## Lilies in the shallows and reeds on the banks, clear of the bridges and the island.
	var r := RandomNumberGenerator.new()
	r.seed = 404
	var z := -map_half.y + 3.0
	while z < map_half.y - 3.0:
		var blocked := absf(z) < ISLAND_R + 2.5
		for b in BRIDGES:
			if absf(z - b) < 3.8:
				blocked = true
		if not blocked:
			for sx in [-1.0, 1.0]:
				if r.randf() < 0.7:
					_prop("hex/waterlily_%s" % ["A", "B"][r.randi() % 2], Vector3(sx * (RIVER_HALF - 1.0) + r.randf_range(-0.4, 0.4), 0.04, z + r.randf_range(-1.0, 1.0)), 4.0, r.randf() * TAU)
				if r.randf() < 0.6:
					_prop("hex/waterplant_%s" % ["A", "B", "C"][r.randi() % 3], Vector3(sx * (RIVER_HALF + 0.5), 0.0, z + r.randf_range(-1.2, 1.2)), 4.0, r.randf() * TAU)
		z += 4.5


func _add_barrow(pos: Vector3) -> void:
	## The old barrow in the Wildwood: a crypt, leaning stones, a dead tree
	## and candles that never go out.
	map_marks.append([pos, "barrow"])
	_prop("halloween/crypt", pos, 0.55, PI * 0.9)
	_add_blocker(pos, 1.7)
	_prop("halloween/floor_dirt", pos + Vector3(0, 0.01, 2.6), 1.0, 0.0)
	var stones := [["gravestone", Vector3(-2.6, 0, 1.4), 0.4], ["grave_A", Vector3(2.4, 0, 1.0), -0.5], ["gravemarker_A", Vector3(-1.6, 0, 3.2), 0.2],
		["gravemarker_B", Vector3(1.8, 0, 3.4), -0.3], ["grave_B", Vector3(-3.4, 0, -1.2), 1.2], ["bone_A", Vector3(0.6, 0, 3.0), 0.9]]
	for st in stones:
		_prop("halloween/%s" % st[0], pos + st[1], 0.7, st[2])
	_prop("halloween/tree_dead_large_decorated", pos + Vector3(3.8, 0, -2.4), 0.9, 0.7)
	_add_blocker(pos + Vector3(3.8, 0, -2.4), 0.5)
	_prop("halloween/lantern_standing", pos + Vector3(-1.2, 0, 2.2), 0.8)
	_add_light(pos + Vector3(-1.2, 1.0, 2.2), Color(0.55, 1.0, 0.8), 1.1, 6.0)
	_prop("halloween/candle_triple", pos + Vector3(1.4, 0, 2.0), 0.6)
	_add_light(pos + Vector3(1.4, 0.6, 2.0), Color(1.0, 0.7, 0.35), 0.7, 3.5)
	_prop("halloween/fence_broken", pos + Vector3(-2.6, 0, 4.2), 0.7, 0.0)
	_prop("halloween/fence", pos + Vector3(2.6, 0, 4.2), 0.7, 0.0)
	_add_fireflies(pos + Vector3(0, 0.6, 1.5))
	_add_mushrooms(pos + Vector3(-2.8, 0, 2.8), 77)


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
	mossy = team == 0
	prop_solid = true
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
	# (No railing along the rampart's inner edge: nothing fence-like inside the walls.)

	# Stairs from the yard up to the rampart, along each side wall.
	ramps.append([])
	for zs in [-1.0, 1.0]:
		var z: float = zs * (hz - 2.5)
		var bottom := Vector3(fx + side * (KEEP_SETBACK - 1.5), 0.0, z)
		var top := Vector3(fx + side * 1.2, WALK_Y, z)
		_add_stairs(bottom + Vector3(0, -0.3, 0), top, 2.2, _timber(), 0.0)
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
	_add_block(Vector3(kcx, 0.03, 0), Vector3(kdepth, 0.04, khz * 2), Color.WHITE, false, _flagstone(Color(0.96, 0.94, 0.9)) if mossy else _marble())
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
	# (The target stands past the bots' turret spot just inside the door.)
	_prop("hex/target", Vector3(in_x + side * 3.0, 0, -(dh + 6.2)), 4.0, PI / 2.0 if side < 0.0 else -PI / 2.0)
	_prop("hex/bucket_arrows", Vector3(in_x + side * 1.6, 0, -(dh + 5.0)), 4.0, 0.4)
	if team == 0:
		# The elven yard keeps clear: glowing mushrooms along the walls instead of stores.
		_add_mushrooms(Vector3(in_x + side * 1.2, 0, 7.0), 21)
		_add_mushrooms(Vector3(kcx - side * 4.0, 0, hz - 1.2), 22)
		_add_mushrooms(Vector3(kcx - side * 4.0, 0, -(hz - 1.2)), 23)
		_add_lantern(Vector3(kcx - side * 6.5, 0, hz - 1.4))
		_add_lantern(Vector3(kcx - side * 6.5, 0, -(hz - 1.4)))
	else:
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
		if team == 0:
			_add_trunk_pillar(Vector3(kx + side * 4.0, 0, zs * (khz - 1.0)), KEEP_H - 0.2)
			_add_trunk_pillar(Vector3(kx + side * 8.0, 0, zs * (khz - 1.0)), KEEP_H - 0.2)
		else:
			_prop("dungeon/column", Vector3(kx + side * 4.0, 0, zs * (khz - 1.0)), 1.6)
			_prop("dungeon/column", Vector3(kx + side * 8.0, 0, zs * (khz - 1.0)), 1.6)
		_add_wall_torch(Vector3(kx + side * 2.0, 1.6, zs * (khz - 0.4)), Vector3(0, 0, -zs))
		_add_wall_torch(Vector3(kx + side * 6.0, 1.6, zs * (khz - 0.4)), Vector3(0, 0, -zs))
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
		if mossy:
			_add_trunk_pillar(throne + Vector3(side * 2.0, 0, z), KEEP_H - 0.2)
		else:
			_prop("dungeon/column", throne + Vector3(side * 2.0, 0, z), 1.6)
	_prop("dungeon/chest_gold", throne + Vector3(side * 1.0, 0, -5.6), 0.8, PI / 2.0 if side < 0.0 else -PI / 2.0)
	# The treasury: coin stacks and a chest heaped behind the throne.
	_prop("dungeon/coin_stack_large", throne + Vector3(side * 2.6, 0, 2.6), 0.55, 0.4)
	_prop("dungeon/coin_stack_medium", throne + Vector3(side * 1.8, 0, -2.7), 0.55, 1.2)
	_prop("dungeon/coin_stack_small", throne + Vector3(side * 2.7, 0, -2.0), 0.55, 2.0)
	_prop("dungeon/chest", throne + Vector3(side * 2.6, 0, 3.4), 0.7, PI / 2.0 if side < 0.0 else -PI / 2.0)
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
	# Defensive positions for the bots: the keep's archway pillars and the
	# gatehouse's inner corners (no fences inside the base).
	for z in [-5.6, 5.6]:
		cover_points.append(throne + Vector3(-side * 4.0, 0, z))
	for z in [-(dh + 2.6), dh + 2.6]:
		cover_points.append(Vector3(fx + side * 1.6, 0, z))
	_furnish_keep(team, kx, bx, side, throne)

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
	mossy = false
	prop_solid = false


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
	_furnish_cellar(team, bx, side)
	# Class stations either side of the stairs.
	# Three seals a side, the Rogue's (locked until account level 10) between
	# the Mage and the Healer.
	_add_station(team, Role.KNIGHT, Vector3(bx + side * 3.3, CELLAR_Y, -4.8))
	_add_station(team, Role.ENGINEER, Vector3(bx + side * 5.5, CELLAR_Y, -4.8))
	_add_station(team, Role.RANGER, Vector3(bx + side * 7.7, CELLAR_Y, -4.8))
	_add_station(team, Role.MAGE, Vector3(bx + side * 3.3, CELLAR_Y, 4.8))
	_add_station(team, Role.ROGUE, Vector3(bx + side * 5.5, CELLAR_Y, 4.8))
	_add_station(team, Role.HEALER, Vector3(bx + side * 7.7, CELLAR_Y, 4.8))
	# The Upgrade Station (perk menu) and the Wildwood Guide by the back wall.
	_add_upgrade_pad(team, Vector3(bx + side * 1.1, CELLAR_Y, -5.0))
	var g := Guide.new()
	add_child(g)
	g.setup(self, team, Vector3(bx + side * 1.3, CELLAR_Y, 5.2), PI / 2.0 if side < 0.0 else -PI / 2.0)
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


var world_env: WorldEnvironment
var world_environment: Environment
var sky_material: ProceduralSkyMaterial
var sun_light: DirectionalLight3D
var fill_light: DirectionalLight3D


func _apply_map_variant() -> void:
	## Day or the Moonlit Wildwood: sky, sun (or moon), ambient, fog and glow.
	if world_environment == null:
		return
	var dark := night()
	if dark:
		sky_material.sky_top_color = Color(0.02, 0.04, 0.1)
		sky_material.sky_horizon_color = Color(0.1, 0.14, 0.28)
		sky_material.ground_bottom_color = Color(0.03, 0.05, 0.06)
		sky_material.ground_horizon_color = Color(0.08, 0.12, 0.16)
		world_environment.ambient_light_energy = 0.42
		world_environment.ambient_light_color = Color(0.45, 0.55, 0.85)
		world_environment.fog_light_color = Color(0.25, 0.3, 0.5)
		world_environment.fog_density = 0.0024
		world_environment.glow_intensity = 0.8
		world_environment.glow_hdr_threshold = 1.0
		world_environment.adjustment_saturation = 1.05
		world_environment.adjustment_brightness = 0.92
		sun_light.light_color = Color(0.62, 0.72, 1.0)
		sun_light.light_energy = 0.5
		if fill_light:
			fill_light.light_energy = 0.1
	else:
		sky_material.sky_top_color = Color(0.25, 0.5, 0.9)
		sky_material.sky_horizon_color = Color(0.85, 0.9, 0.95)
		sky_material.ground_bottom_color = Color(0.3, 0.4, 0.25)
		sky_material.ground_horizon_color = Color(0.65, 0.75, 0.6)
		world_environment.ambient_light_energy = 0.6
		world_environment.ambient_light_color = Color(0.75, 0.85, 0.8)
		world_environment.fog_light_color = Color(0.8, 0.88, 0.95)
		world_environment.fog_density = 0.0012
		world_environment.glow_intensity = 0.45
		world_environment.glow_hdr_threshold = 1.4
		world_environment.adjustment_saturation = 1.15
		world_environment.adjustment_brightness = 0.95
		sun_light.light_color = Color(1.0, 0.94, 0.82)
		sun_light.light_energy = 1.15
		if fill_light:
			fill_light.light_energy = 0.15


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
	world_env = env
	sky_material = sky_mat
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
	world_environment = environment
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun_light = sun
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
	fill_light = fill
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
	var road := _pbr("road", 0.2, Color(0.92, 0.88, 0.8))
	# The main road: door to door through the shrine, with cobbled aprons.
	_add_path(Vector3(-fxr, 0, 0), Vector3(-ISLAND_R - 2.0, 0, 0), 5.4, road)
	_add_path(Vector3(ISLAND_R + 2.0, 0, 0), Vector3(fxr, 0, 0), 5.4, road)
	for sx in [-1.0, 1.0]:
		_add_block(Vector3(sx * (fxr - 2.5), 0.008, 0), Vector3(7, 0.01, 10), Color.WHITE, false, _flagstone(Color(0.96, 0.93, 0.88)))
		# The Forest Path (north) and the River Path (south): from the road by
		# the castle door out to the flank bridges, as worn dirt tracks.
		var dirt := _dirt()
		var nb: float = BRIDGES[0]
		var sb: float = BRIDGES[2]
		_add_path(Vector3(sx * (fxr - 4.0), 0, -3.0), Vector3(sx * 30.0, 0, nb - 3.0), 3.4, dirt)
		_add_path(Vector3(sx * 30.0, 0, nb - 3.0), Vector3(sx * (RIVER_HALF + 1.5), 0, nb), 3.4, dirt)
		_add_path(Vector3(sx * (fxr - 4.0), 0, 3.0), Vector3(sx * 26.0, 0, sb + 2.0), 3.4, dirt)
		_add_path(Vector3(sx * 26.0, 0, sb + 2.0), Vector3(sx * (RIVER_HALF + 1.5), 0, sb), 3.4, dirt)
		# Road dressing: milestones on the verge, signposts at the path
		# bends and an abandoned cart by the roadside.
		# (Two milestones a side; the roadside caravan pile was clutter and went.)
		for k in 2:
			var mx: float = 18.0 + 16.0 * k
			_add_block(Vector3(sx * mx, 0.3, 3.4 if k % 2 == 0 else -3.4), Vector3(0.35, 0.6, 0.35), Color.WHITE, false, _ashlar(Color(0.9, 0.87, 0.8)))
			_add_block(Vector3(sx * mx, 0.62, 3.4 if k % 2 == 0 else -3.4), Vector3(0.45, 0.06, 0.45), Color.WHITE, false, _ashlar(Color(0.86, 0.82, 0.74)))
		_add_signpost(Vector3(sx * 31.5, 0, nb - 5.2), -sx)
		_add_signpost(Vector3(sx * 27.5, 0, sb + 4.3), sx)
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
	# The Wildwood half glows: more fireflies and mushroom rings on the elven side.
	for p in [Vector3(-50, 0, 12), Vector3(-50, 0, -12), Vector3(-38, 0, 5), Vector3(-30, 0, -20), Vector3(-42, 0, 26), Vector3(-20, 0, 18)]:
		_add_fireflies(p)
	for i in 8:
		var mp := Vector3(-16.0 - i * 6.0, 0, (7.5 + float(i % 3) * 5.0) * (1.0 if i % 2 == 0 else -1.0))
		_add_mushrooms(mp, 100 + i)
	# Woods on the castle flanks.
	for p in [Vector3(52, 0, 19), Vector3(60, 0, 22), Vector3(68, 0, 18), Vector3(46, 0, 24), Vector3(56, 0, 30)]:
		_add_tree(p, true)
		_add_tree(-p, true)
		_add_tree(Vector3(p.x, 0, -p.z), true)
		_add_tree(Vector3(-p.x, 0, p.z), true)
	# A staggered inner tree line along the north and south edges thickens
	# the forest without touching the lanes (clear of the river and the ruins).
	for i in 26:
		var x := -78.0 + i * 6.2
		if absf(x) < 9.0 or (absf(absf(x) - 11.0) < 6.0):
			continue
		for zs in [-1.0, 1.0]:
			var p := Vector3(x + zs * 2.0, 0, zs * (35.0 - float(i % 3) * 1.2))
			var crowded := false
			for t in map_trees:
				if Vector2(t.x - p.x, t.z - p.z).length() < 5.0:
					crowded = true
			if not crowded:
				_add_tree(p, i % 4 == 0)
	_add_ground_detail()
	# A tree line and hills beyond the playable edge, so the world has a
	# horizon; the hamlets and farms sit in gaps in it.
	for i in 22:
		var x := -84.0 + i * 8.0
		if absf(x) < 42.0:
			_prop("hex/trees_%s_medium" % ["A", "B"][i % 2], Vector3(x, 0, 40.0 + (i % 3) * 1.5), 4.0, float(i))
			_prop("hex/trees_%s_medium" % ["B", "A"][i % 2], Vector3(x + 3.0, 0, -40.0 - (i % 3) * 1.5), 4.0, float(i))
	for i in 7:
		# Hills beyond the far edges, but not behind the farms and villages.
		var hx := -60.0 + i * 20.0
		if absf(hx) < 42.0:
			_prop("hex/hill_single_%s" % ["A", "B", "C"][i % 3], Vector3(hx, -0.2, 60.0), 12.0, float(i))
		if absf(hx + 10.0) < 42.0:
			_prop("hex/hill_single_%s" % ["B", "C", "A"][i % 3], Vector3(hx + 10.0, -0.2, -60.0), 12.0, float(i) + 1.0)
	_build_outskirts()

	_apply_map_variant()
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
	_add_action("cmd_attack", [KEY_Z], [])
	_add_action("cmd_defend", [KEY_X], [])
	_add_action("cmd_help", [KEY_C], [])


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
