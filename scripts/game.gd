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
const Turret = preload("res://scripts/turret.gd")
const Seal = preload("res://scripts/seal.gd")
const Sfx = preload("res://scripts/sfx.gd")
const MainMenu = preload("res://scripts/menu.gd")
const MenuStage = preload("res://scripts/menu_stage.gd")
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
const CELLAR_DEPTH := 14.0    # how far behind the back wall it reaches (x)
const CELLAR_HALF_Z := 9.5
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
var hero_skin := 1              # Stats.HERO_SKINS index
var hero_face := 0              # Stats.HERO_FACES index
var hero_body := 0              # Stats.HERO_BODIES index: the unclassed body's build
var team_size := TEAM_SIZE      # fighters a side (SELECT MAP's TEAM SIZE); bots fill the gaps
var split_screen := false       # SELECT MAP's SPLIT SCREEN: extra pads may join in the lobby
var lobby_sides: Array = []     # READY UP: each local player's side (0 Elves, 1 Humans)
var join_pads: Array = []       # READY UP: pad device of local players 2-4, in join order
var p1_pad_device := -1         # the pad player 1 used in the menus (-1: none or unknown)
var main_menu                   # menu.gd: the title, Select Map, Create Your Character, Ready Up
var menu_stage: Node3D          # menu_stage.gd: their 3D backdrops
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
var cover_boxes: Array = []   # their colliders (AABB), for walkers to go round
var barricades: Array = []
var barricades_left := [0, 0]   # barricade kits each team still has
var kill_feed: Array = []       # recent kills for the HUD's feed: {killer, kteam, krole, victim, vteam, vrole, time}
var prep_left := 0.0            # seconds left in the fortify phase (0 = the battle is on)
var barrier: Node3D
var turrets: Array = []       # every standing Engineer turret, both teams
# Quality of life settings (saved with the controls).
var screen_shake := true
var damage_numbers := true
var show_fps := false
var quit_armed := 0.0          # pause menu: seconds the MAIN MENU button stays armed after a first click
var gfx_quality := 2           # graphics preset: 0 Low, 1 Medium, 2 High, 3 Ultra
var fullscreen := false
const GFX_NAMES := ["LOW", "MEDIUM", "HIGH", "ULTRA"]
var rumble_on := true          # gamepad vibration on hits, deaths and captures
var pad_style := "auto"        # gamepad button names: "auto" (from the pad's name), "xbox" or "ps"
var pad_active := false        # player 1's last press came from a gamepad (labels follow it)
var cursor := Vector2.ZERO      # the gamepad's menu cursor (screen pixels)
var debug_kill := false
var cursor_shown := false      # drawn and used instead of the mouse while a pad drives the menus
var nav_repeat := 0.0          # held D-pad / stick repeat timer
var confirm_block := false     # a lobby pad's A press: not a cursor click until released
var lobby_pad_frame := -1      # frame a lobby pad's press was handled (its B is not "back")
# Quick commands: Z / X / C call the team; bots answer for COMMAND_TIME seconds.
var team_command := ["", ""]
var command_timer := [0.0, 0.0]
var command_pos := [Vector3.ZERO, Vector3.ZERO]
var compass: Node3D          # the gold arrow at the player's feet pointing at the objective
var compass_mesh: MeshInstance3D
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
# Three of the spots ring the Crown Shrine's plinth (never on it: the plinth
# is solid, so a blessing there could not be picked up).
const BLESSING_SPOTS := [Vector3(0, 0.5, 2.4), Vector3(2.4, 0.5, 0), Vector3(-2.4, 0.5, 0), Vector3(12, 0, -24), Vector3(-12, 0, 24), Vector3(26, 0, 4), Vector3(-26, 0, -4),
	Vector3(16, 0, 12), Vector3(-16, 0, -12), Vector3(30, 0, -16), Vector3(-30, 0, 16), Vector3(10, 0, 26), Vector3(-10, 0, -26)]
var time_left := Stats.MATCH_TIME
var player
# Couch play: up to four local players on one screen, each with their own
# pane, camera and HUD. Player 1 keeps the keyboard and mouse; the others
# play on gamepads.
var couch_players := 1          # local players this match (1-4); 2 or more splits the screen
var couch_mode := "versus"      # "versus": odd players on your side, even ones against; "coop": everyone on your side
var couch_active := false       # a split-screen match is running
var locals: Array = []          # the local players' units, index 0 is `player`
var panes: Array = []           # per local player: {unit, view, cam, hud, cam_pos}
var split_layer: CanvasLayer
var rank_player = null          # whose perk menu is open
const COUCH_MAX := 4
const COUCH_ACTIONS := ["move_left", "move_right", "move_up", "move_down", "aim_left", "aim_right", "aim_up", "aim_down",
	"attack", "block", "ability_1", "ability_2", "dodge", "interact", "rank_menu", "rank_1", "rank_2", "rank_3", "rank_4", "rank_5", "rank_6"]

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
	Input.joy_connection_changed.connect(_on_pad_changed)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--debug-pad="):  # testing: draw the HUD as if player 1 held this kind of pad
			pad_style = arg.trim_prefix("--debug-pad=")
			pad_active = true
		if arg == "--debug-kill":  # testing: a KILL banner 4.5 s into the match
			debug_kill = true
		if arg == "--debug-cursor":  # testing: the gamepad pointer on the title screen
			cursor_shown = true
			cursor = Vector2(119, 238)
	if "--debug-night" in OS.get_cmdline_user_args():
		map_variant = 1
	_build_world()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--gfx="):  # testing: render at a given preset (0-3)
			gfx_quality = clampi(int(arg.trim_prefix("--gfx=")), 0, 3)
	apply_graphics()
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
			hero_body = int(parts[3]) if parts.size() > 3 else hero_body
			hero_skin = int(parts[4]) if parts.size() > 4 else hero_skin
			hero_face = int(parts[5]) if parts.size() > 5 else hero_face
	if "--play" in OS.get_cmdline_user_args():
		_start_match(0)  # testing: straight into a match with a (idle) local player
		return
	banner.visible = false
	sfx.play_music(false)
	main_menu = MainMenu.new(self)
	menu_stage = MenuStage.new()
	add_child(menu_stage)
	menu_stage.build(self)
	menu_stage.activate()
	main_menu.stage = menu_stage
	for arg in OS.get_cmdline_user_args():
		# Testing: open a menu screen (title, map, character, lobby) or overlay.
		if arg.begins_with("--debug-screen="):
			var scr := arg.trim_prefix("--debug-screen=")
			if scr in ["credits", "tutorial", "progress"]:
				main_menu.overlay = scr
			else:
				main_menu.go(scr)
		if arg.begins_with("--debug-char-tab="):
			main_menu.char_tab = int(arg.trim_prefix("--debug-char-tab="))
		if arg.begins_with("--debug-lobby="):  # N local players, all ready
			split_screen = true
			couch_players = clampi(int(arg.trim_prefix("--debug-lobby=")), 1, COUCH_MAX)
			main_menu.readied = [true, true, true, true]


func _process(delta: float) -> void:
	if debug_kill and player and not player.kill_banner.is_empty():
		player.kill_banner.time = Time.get_ticks_msec() / 1000.0 - 0.7
		for k in kill_feed:
			k.time = Time.get_ticks_msec() / 1000.0 - 1.0
	_debug_hooks()
	_ui_sounds()
	for t in 2:
		command_timer[t] = maxf(command_timer[t] - delta, 0.0)
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
		if main_menu and main_menu.screen == "lobby" and main_menu.overlay == "":
			# Ready Up: 1 or 2 picks player 1's side and starts.
			if Input.is_action_just_pressed("pick_elves") or Input.is_action_just_pressed("pick_humans"):
				lobby_sides[0] = 0 if Input.is_action_just_pressed("pick_elves") else 1
				main_menu.start()
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
			if arg == "--debug-nohud":  # clean world renders (the menu's map thumbnails)
				hud.get_parent().visible = false
			if arg == "--debug-menu":
				menu_open = true
				menu_tab = 0
			if arg.begins_with("--debug-tab="):
				menu_tab = int(arg.trim_prefix("--debug-tab="))
			if arg == "--debug-stolen":
				stolen_timer = 3.5
				if monarchs[1 - player_team].state == Monarch.State.HOME:
					var thief = units.filter(func(x): return x.team != player_team)[mini(1, team_size - 1)]
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
	rumble(carrier, 0.5, 0.9, 0.5)
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
		rumble(u, 0.4, 0.5, 0.25)
		chat_system("%s grabbed the %s!" % [u.display_name, m.title])
		_banter(1 - u.team, "ours_taken")
		_banter(u.team, "carrying", u)


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
		Vector3(fx + side * 5.5, 0.0, -(dh + 1.5)), Vector3(fx + side * 5.5, 0.0, dh + 1.5)]  # clear of the yard stairs


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
	if spot.length() < 3.0:
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


func quit_to_title() -> void:
	## Leave the match for the main menu (the scene restarts on the title).
	get_tree().paused = false
	get_tree().reload_current_scene()


func toggle_setting(key: String) -> void:
	match key:
		"shake": screen_shake = not screen_shake
		"numbers": damage_numbers = not damage_numbers
		"fps": show_fps = not show_fps
		"chat": chat_visible = not chat_visible
		"rosters": rosters_visible = not rosters_visible
		"rumble":
			rumble_on = not rumble_on
			if rumble_on:
				rumble_pad(local_pad(0), 0.3, 0.6, 0.25)
		"pad_style": pad_style = {"auto": "xbox", "xbox": "ps", "ps": "auto"}[pad_style]
		"gfx":
			gfx_quality = (gfx_quality + 1) % GFX_NAMES.size()
			apply_graphics()
		"fullscreen":
			fullscreen = not fullscreen
			apply_graphics()
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
	## the keep's archway when the keep's walls are, else `to`; and whatever
	## that leg is, round the nearer end of any cover stack lying across it.
	var leg := _route_leg(from, to)
	if from.y < 1.0 and leg.y < 1.0:
		var a := Vector3(from.x, 0.6, from.z)
		var b := Vector3(leg.x, 0.6, leg.z)
		for box in cover_boxes:
			var grown: AABB = box.grow(0.5)
			if grown.has_point(a) or grown.has_point(b) or grown.intersects_segment(a, b) == null:
				continue
			var cz: float = box.position.z + box.size.z / 2.0
			var reach: float = box.size.z / 2.0 + 1.1
			var near_end := Vector3(box.position.x + 0.5, 0, cz - reach)
			var far_end := Vector3(box.position.x + 0.5, 0, cz + reach)
			if _flat_dist(from, far_end) + _flat_dist(far_end, leg) < _flat_dist(from, near_end) + _flat_dist(near_end, leg):
				return far_end
			return near_end
	return leg


func _route_leg(from: Vector3, to: Vector3) -> Vector3:
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
			if behind > -1.0 and behind < 1.3:
				return st[0]  # near the foot of the stairs: step across to the lane
			if behind >= 1.3:
				return Vector3(st[0].x + side * 0.3, CELLAR_Y, from.z)  # walk straight back to the foot first
			# Up by the hats, ahead of the foot: the low walls flanking the
			# stairs end short of the foot, so get out past their ends before
			# stepping across, or the end post catches the diagonal.
			return Vector3(st[0].x + side * 0.3, CELLAR_Y, signf(from.z) * 3.2)
		# Crossing the cellar from one row of hats to the other: the low walls
		# along the stairs are in the way, so go round behind their foot first.
		if _in_cellar(c, from) and _in_cellar(c, to) and from.z * to.z < 0.0 and absf(from.z) > 1.0 and absf(to.z) > 1.0:
			var st := cellar_stairs(c)
			var side := -1.0 if c == 0 else 1.0
			if (from.x - st[0].x) * side < -1.2:
				return Vector3(st[0].x + side * 0.3, CELLAR_Y, from.z)
		# On the stairs lane (between its low walls, or just off their foot)
		# and heading for a hat beside it: clear the walls' end first, well
		# out to the hat's side, or the end post catches the diagonal.
		if _in_cellar(c, from) and _in_cellar(c, to) and absf(from.z) < 2.3 and absf(to.z) > 2.4:
			var st := cellar_stairs(c)
			var side := -1.0 if c == 0 else 1.0
			var bx := side * (CASTLE_X + CASTLE_DEPTH)
			var lane_lo: float = minf(bx + side * 8.4, bx - side * 0.8)
			var lane_hi: float = maxf(bx + side * 8.4, bx - side * 0.8)
			if from.x > lane_lo and from.x < lane_hi:
				return Vector3(st[0].x + side * 0.3, CELLAR_Y, signf(to.z) * 3.2)
	if to.y > 2.0 and from.y < WALK_Y - 0.2:
		var c := 0 if to.x < 0.0 else 1
		var ramp: Dictionary = ramps[c][0] if to.z < 0.0 else ramps[c][1]
		if from.y < 0.5 and _flat_dist(from, ramp.bottom) > 1.2:
			target = ramp.bottom
		else:
			return ramp.top
	# The shrine plinth is solid: a goal on it (or right beside it) means
	# standing at its foot, on the side we come from.
	if _flat_dist(target, Vector3.ZERO) < 1.6:
		var away := Vector3(from.x - target.x, 0, from.z - target.z)
		if away.length() < 0.1:
			away = Vector3(0, 0, 1)
		target = target + away.normalized() * 1.8
		target.y = 0.5
	# Up on the shrine island and leaving it: the steps are at z 0 on each
	# side (stone rims close the north and south edges), and the plinth sits
	# in the middle, so go round it on the side we are already on first.
	var on_island: bool = from.y > 0.3 and _flat_dist(from, Vector3.ZERO) < ISLAND_R + 0.3
	if on_island and _flat_dist(target, Vector3.ZERO) > ISLAND_R + 0.3:
		var exit_side := 1.0 if target.x > 0.0 else -1.0
		if from.x * exit_side < -1.2 and absf(from.z) < 1.6:
			return Vector3(0.0, 0.5, (1.0 if from.z >= 0.0 else -1.0) * 2.0)
		if from.x * exit_side < 1.2 and absf(from.z) < 1.6:
			return Vector3(exit_side * 2.4, 0.5, (1.0 if from.z >= 0.0 else -1.0) * 1.8)
		return Vector3(exit_side * (ISLAND_R + 3.6), 0.0, 0.0)
	# The river: cross at the bridge closest to the way, entering it square on.
	if (from.x < -RIVER_HALF and target.x > RIVER_HALF) or (from.x > RIVER_HALF and target.x < -RIVER_HALF):
		var bi := 0
		var best := 1e9
		for i in BRIDGES.size():
			var d: float = absf(from.z - BRIDGES[i]) + absf(target.z - BRIDGES[i])
			if d < best:
				best = d
				bi = i
		var bz: float = BRIDGES[bi]
		var side := signf(from.x)
		if bi == 1:
			# The island: its steps' foot on our bank, straight over, down the
			# far steps (the island rules above take over once we are up).
			if absf(from.z) > 1.2 or absf(from.x) > ISLAND_R + 4.6:
				return Vector3(side * (ISLAND_R + 3.6), 0.0, 0.0)
			return Vector3(-side * (ISLAND_R + 3.6), 0.0, 0.0)
		# Off the deck and not lined up with it: our end of the bridge first,
		# or the rails and the bank walls catch the diagonal.
		var on_deck: bool = absf(from.x) < RIVER_HALF + 1.0 and absf(from.z - bz) < BRIDGE_HALF[bi] - 0.4
		if absf(from.z - bz) > 1.2 and not on_deck:
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
		# Inside the keep, the throne room's walls are in the way of anyone
		# crossing between the entrance hall and the back: go round through a
		# gallery, corner to corner. Going into the room (or out of it) means
		# the doors, which face the hall.
		if _inside_keep(c, from) != _inside_keep(c, target):
			var kx := _keep_x(c)
			var arch := Vector3(kx + (1.5 if target.x > from.x else -1.5), 0.0, 0.0)
			if _inside_keep(c, from):
				var way := _around_throne_room(c, from, arch)
				if way != Vector3.INF:
					return way
			return arch
		if _inside_keep(c, from) and _inside_keep(c, target):
			var way := _around_throne_room(c, from, target)
			if way != Vector3.INF:
				return way
	return target


func _around_throne_room(team: int, from: Vector3, to: Vector3) -> Vector3:
	## A waypoint past the throne room when the straight line would cross it,
	## or INF when the way is clear.
	var side := -1.0 if team == 0 else 1.0
	var throne: Vector3 = thrones[team]
	var fx := throne.x - side * (ROOM_FRONT + 0.45)   # just outside the front wall
	var bx := throne.x + side * (ROOM_BACK + 0.45)
	var hz := ROOM_HALF_Z + 0.5
	var box := AABB(Vector3(minf(fx, bx), -1.0, -hz), Vector3(absf(bx - fx), 4.0, hz * 2.0))
	var from_in := box.has_point(from)
	var to_in := box.has_point(to)
	if to_in:
		return Vector3.INF   # heading into the room: straight at the doors
	if from_in:
		return Vector3(fx - side * 0.4, 0.0, 0.0)  # leaving: out through the doors first
	if box.intersects_segment(from, to) == null:
		return Vector3.INF
	var gz: float = hz + 1.1   # the galleries' clear lane (furniture hugs the outer walls)
	var zs: float = signf(from.z) if absf(from.z) > 0.3 else (signf(to.z) if absf(to.z) > 0.3 else 1.0)
	var front_corner := Vector3(fx - side * 0.8, 0.0, zs * gz)
	var back_corner := Vector3(bx + side * 0.8, 0.0, zs * gz)
	var rel_from := (from.x - throne.x) * side
	var in_gallery := absf(from.z) > hz
	if rel_from < -(ROOM_FRONT + 0.45):      # in front of the room
		return back_corner if in_gallery else front_corner
	if rel_from > ROOM_BACK + 0.45:          # behind it
		return front_corner if in_gallery else back_corner
	return front_corner if (to.x - throne.x) * side < 0.0 else back_corner


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
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--couch="):
			couch_players = clampi(int(arg.trim_prefix("--couch=")), 1, COUCH_MAX)  # testing: split-screen renders
		if arg.begins_with("--couch-mode="):
			couch_mode = arg.trim_prefix("--couch-mode=")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--team-size="):
			team_size = clampi(int(arg.trim_prefix("--team-size=")), 1, TEAM_SIZE)  # testing: smaller sides
	if menu_stage:
		# Leave the menus: their hall and models go, the match camera takes over.
		# Freed now, not queued: a camera left in the viewport would become
		# current again and render the whole world behind the split panes.
		menu_stage.free()
		menu_stage = null
		if main_menu:
			main_menu.stage = null
		camera.make_current()
	# Each local player's side: from the lobby, else player 1's pick with
	# the couch rule (versus: 2 and 4 against, co-op: all together).
	local_sides = []
	for k in couch_players:
		if k < lobby_sides.size() and lobby_sides[k] != null and main_menu:
			local_sides.append(int(lobby_sides[k]))
		else:
			local_sides.append(team if (couch_mode == "coop" or k % 2 == 0) else 1 - team)
	local_sides[0] = team
	locals = []
	locals.resize(couch_players)
	for t in 2:
		var side := -1.0 if t == 0 else 1.0
		# A side is team_size strong, or bigger if more local players chose it.
		var count: int = maxi(team_size, local_sides.count(t))
		for i in count:
			var u = Unit.new()
			add_child(u)
			var spawn := Vector3(side * (CASTLE_X + CASTLE_DEPTH + 11.6), CELLAR_Y, -4.0 + i * 2.0)
			var local_k := _local_slot(t, i)
			var is_player := local_k >= 0 and not demo
			u.setup(self, t, is_player, spawn)
			u.bot_class = LINEUP[i % LINEUP.size()][0]
			u.bot_job = LINEUP[i % LINEUP.size()][1]
			u.base_job = LINEUP[i % LINEUP.size()][1]
			if is_player:
				u.local_index = local_k
				u.act_prefix = "" if local_k == 0 else "p%d_" % (local_k + 1)
				u.has_mouse = local_k == 0
				u.display_name = (hero_name if hero_name.strip_edges() != "" else "You") if local_k == 0 else "Player %d" % (local_k + 1)
				locals[local_k] = u
			else:
				u.display_name = Stats.BOT_NAMES[t][i % Stats.BOT_NAMES[t].size()]
			units.append(u)
			if (is_player and local_k == 0) or (demo and player == null):
				player = u
	cam_pos = player.global_position + CAMERA_OFFSET * cam_zoom
	camera.global_position = cam_pos
	_bind_couch_input()
	if couch_players > 1 and not demo:
		_build_panes()
	playing = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--debug-time="):
			time_left = float(arg.trim_prefix("--debug-time="))  # testing: a short clock
		if arg == "--no-prep":
			prep_left = -1.0
	barricades_left = [Stats.BARRICADE_TEAM, Stats.BARRICADE_TEAM]
	kill_feed = []
	if prep_left >= 0.0:
		prep_left = Stats.PREP_TIME
		_build_barrier()
	else:
		prep_left = 0.0
	sfx.ui("match_start")
	sfx.play_music(true)
	sfx.play_ambience(true)
	if debug_kill and player:
		player.kill_banner = {"victim": "Sir Aldric", "role": "Knight", "team": 1 - player_team, "role_id": Stats.Role.KNIGHT,
			"streak": 2, "time": Time.get_ticks_msec() / 1000.0}
		var t0: float = Time.get_ticks_msec() / 1000.0
		kill_feed = [{"killer": "Sir Aldric", "kteam": 1, "krole": Stats.Role.KNIGHT, "victim": "Thistle", "vteam": 0, "vrole": Stats.Role.RANGER, "time": t0},
			{"killer": player.display_name, "kteam": player_team, "krole": Stats.Role.KNIGHT, "victim": "Sir Aldric", "vteam": 1 - player_team, "vrole": Stats.Role.KNIGHT, "time": t0},
			{"killer": "Wren", "kteam": 0, "krole": Stats.Role.MAGE, "victim": "Brother Odo", "vteam": 1, "vrole": Stats.Role.HEALER, "time": t0}]
	if pad_active:
		var k := pad_kind(local_pad(0))
		chat_system("%s attacks, %s and %s for abilities, %s dodges, %s grabs, %s for perks, hold %s for the scoreboard." % [
			pad_label("attack", k), pad_label("ability_1", k), pad_label("ability_2", k), pad_label("dodge", k), pad_label("interact", k), pad_label("rank_menu", k), pad_label("scoreboard", k)])
	else:
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
	for l in locals:
		rumble(l, 0.6, 0.3, 0.4)


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
	sfx.set_listener(player.global_position)
	shake_amount = move_toward(shake_amount, 0.0, delta * 1.6)
	var jolt := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * shake_amount * 0.35
	if couch_active:
		# One camera a pane, each on its own player.
		for pane in panes:
			var u = pane.unit
			var t: Vector3 = (cam_lock if cam_lock != Vector3.INF and u == player else u.global_position) + CAMERA_OFFSET * cam_zoom
			pane.cam_pos = pane.cam_pos.lerp(t, clampf(delta * 5.0, 0.0, 1.0))
			pane.cam.global_position = pane.cam_pos + jolt
		return
	var target: Vector3 = (cam_lock if cam_lock != Vector3.INF else player.global_position) + CAMERA_OFFSET * cam_zoom
	cam_pos = cam_pos.lerp(target, clampf(delta * 5.0, 0.0, 1.0))
	camera.global_position = cam_pos + jolt


func camera_for(u) -> Camera3D:
	## The camera looking at this local player (their pane's in couch play).
	if couch_active:
		for pane in panes:
			if pane.unit == u:
				return pane.cam
	return camera


func menu_mouse() -> Vector2:
	## Where menu clicks land: the gamepad cursor while it is in use, else the mouse.
	return cursor if cursor_shown else get_viewport().get_mouse_position()


func in_menus() -> bool:
	## Whether a screen of buttons is up (title, pause menu, guide, end screen).
	return (not playing or menu_open or game_over or guide_open) and not rank_open and rebinding == "" and not chat_open and not name_editing


func _pad_nav() -> void:
	## Move the gamepad cursor: the D-pad (or a stick flick) jumps to the next
	## button in that direction, the stick held steers it freely, and the
	## Circle / B button backs out of the pause menu or the guide.
	if hud == null or not in_menus():
		cursor_shown = false
		return
	var dt := get_process_delta_time()
	var stick := Vector2.ZERO
	for d in Input.get_connected_joypads():
		var v := Vector2(Input.get_joy_axis(d, JOY_AXIS_LEFT_X), Input.get_joy_axis(d, JOY_AXIS_LEFT_Y))
		if v.length() > stick.length():
			stick = v
	var pressed := Vector2.ZERO
	for dir in [["nav_left", Vector2.LEFT], ["nav_right", Vector2.RIGHT], ["nav_up", Vector2.UP], ["nav_down", Vector2.DOWN]]:
		if Input.is_action_just_pressed(dir[0]):
			pressed += dir[1]
	var any_nav: bool = pressed != Vector2.ZERO or stick.length() > 0.3 or Input.is_action_just_pressed("ui_confirm") or Input.is_action_just_pressed("ui_back")
	if any_nav and not cursor_shown:
		cursor_shown = true
		pad_active = true
		var rects: Array = hud.nav_rects()
		cursor = rects[0].get_center() if not rects.is_empty() else get_viewport().get_visible_rect().size / 2.0
		if pressed != Vector2.ZERO:
			return  # the first press only shows the cursor
	if not cursor_shown:
		return
	if pressed != Vector2.ZERO:
		_snap_cursor(pressed.normalized())
		nav_repeat = 0.4
	elif stick.length() > 0.3:
		# Holding the stick: steer freely (slow) and keep snapping at a steady beat.
		nav_repeat -= dt
		if nav_repeat <= 0.0 and stick.length() > 0.75:
			_snap_cursor(stick.normalized())
			nav_repeat = 0.28
		elif stick.length() <= 0.75:
			cursor += stick * dt * 700.0
	else:
		nav_repeat = 0.0
	cursor = cursor.clamp(Vector2.ZERO, get_viewport().get_visible_rect().size)
	if Input.is_action_just_pressed("ui_back") and Engine.get_process_frames() != lobby_pad_frame:
		if not playing and not menu_open and main_menu:
			main_menu.back()
		elif menu_open:
			menu_open = false
			get_tree().paused = false
			sfx.ui("ui_click", -4.0)
		elif guide_open:
			guide_close()


func _snap_cursor(dir: Vector2) -> void:
	## Jump to the nearest button centre that lies in this direction.
	var best := Rect2()
	var best_score := INF
	for r in hud.nav_rects():
		var to: Vector2 = r.get_center() - cursor
		var along := to.dot(dir)
		if along < 6.0 or r.has_point(cursor):
			continue
		var perp := absf(to.dot(Vector2(-dir.y, dir.x)))
		if perp > along * 1.6 + 30.0:
			continue
		var score := along + perp * 2.0
		if score < best_score:
			best_score = score
			best = r
	if best.size != Vector2.ZERO:
		cursor = best.get_center()
		sfx.ui("ui_click", -10.0)


# --- Couch play --------------------------------------------------------------

func set_couch(what: String) -> void:
	## Title-screen controls: how many local players, and whether the extra
	## players join your side or fight it.
	match what:
		"more":
			couch_players = mini(couch_players + 1, COUCH_MAX)
		"less":
			couch_players = maxi(couch_players - 1, 1)
		"mode":
			couch_mode = "coop" if couch_mode == "versus" else "versus"
	sfx.ui("ui_click")
	_save_settings()


var local_sides: Array = []     # each local player's side this match (see _start_match)
var bound_pads: Array = []      # the pad device each local player holds this match (see _bind_couch_input)


func _local_slot(team: int, slot: int) -> int:
	## Which local player (0-based) takes lineup slot `slot` of `team`, or -1
	## for a bot. Local players fill a side's first slots in player order.
	var ks := 0
	for k in couch_players:
		if local_sides[k] == team:
			if ks == slot:
				return k
			ks += 1
	return -1


func _bind_couch_input() -> void:
	## Give every local player their own controls. Player 1 keeps the keyboard
	## and mouse (and the first gamepad nobody else has); players 2-4 each
	## get a gamepad, in order, through copies of the base actions prefixed
	## p2_, p3_, p4_ that only answer to that pad.
	var pads: Array = []
	for k in range(1, couch_players):
		pads.append(k - 1)
	var p1_pad: int = couch_players - 1 if couch_players > 1 else -1
	if join_pads.size() == couch_players - 1 and couch_players > 1:
		# Players who joined in the lobby keep the pad they joined with;
		# player 1 keeps theirs (or the first pad nobody took).
		pads = join_pads.duplicate()
		p1_pad = p1_pad_device
		if p1_pad < 0 or p1_pad in pads:
			p1_pad = -1
			for d in Input.get_connected_joypads():
				if not d in pads:
					p1_pad = d
					break
	bound_pads = [p1_pad] + pads
	for action in COUCH_ACTIONS:
		for ev in InputMap.action_get_events(action):
			if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
				ev.device = p1_pad
		for k in range(2, COUCH_MAX + 1):
			var pa := StringName("p%d_%s" % [k, action])
			if InputMap.has_action(pa):
				InputMap.erase_action(pa)
			if k > couch_players:
				continue
			InputMap.add_action(pa, 0.25)
			for ev in InputMap.action_get_events(action):
				if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
					var copy: InputEvent = ev.duplicate()
					copy.device = pads[k - 2]
					InputMap.action_add_event(pa, copy)


func _build_panes() -> void:
	## Split the window: two players stack top and bottom, three or four
	## take the quarters. Each pane is a SubViewport sharing the world with
	## its own camera and HUD.
	couch_active = true
	camera.current = false
	split_layer = CanvasLayer.new()
	split_layer.layer = 0
	add_child(split_layer)
	var n := couch_players
	var rects: Array = []
	if n == 2:
		rects = [Rect2(0, 0, 1, 0.5), Rect2(0, 0.5, 1, 0.5)]
	else:
		rects = [Rect2(0, 0, 0.5, 0.5), Rect2(0.5, 0, 0.5, 0.5), Rect2(0, 0.5, 0.5, 0.5), Rect2(0.5, 0.5, 0.5, 0.5)]
	var hud_scale := 0.72 if n == 2 else 0.56
	for k in n:
		var u = locals[k]
		var r: Rect2 = rects[k]
		var box := SubViewportContainer.new()
		box.stretch = true
		box.anchor_left = r.position.x
		box.anchor_top = r.position.y
		box.anchor_right = r.end.x
		box.anchor_bottom = r.end.y
		box.offset_left = 2 if r.position.x > 0.0 else 0
		box.offset_top = 2 if r.position.y > 0.0 else 0
		box.offset_right = -2 if r.end.x < 1.0 else 0
		box.offset_bottom = -2 if r.end.y < 1.0 else 0
		split_layer.add_child(box)
		var view := SubViewport.new()
		view.handle_input_locally = false
		view.audio_listener_enable_3d = false
		view.msaa_3d = get_viewport().msaa_3d
		view.screen_space_aa = get_viewport().screen_space_aa
		box.add_child(view)
		var cam := Camera3D.new()
		cam.rotation_degrees = camera.rotation_degrees
		cam.fov = camera.fov
		view.add_child(cam)
		cam.make_current()
		var h = Hud.new()
		h.game = self
		h.local_unit = u
		h.pane = true
		h.scale = Vector2.ONE * hud_scale
		h.process_mode = Node.PROCESS_MODE_ALWAYS
		view.add_child(h)
		var pane := {"unit": u, "view": view, "cam": cam, "hud": h, "cam_pos": u.global_position + CAMERA_OFFSET * cam_zoom}
		cam.global_position = pane.cam_pos
		panes.append(pane)
		view.size_changed.connect(func(): h.size = Vector2(view.size) / hud_scale)
		h.size = Vector2(view.size) / hud_scale
	if n == 3:
		# The spare quarter: a dark plate so it is not raw clear colour.
		var fill := ColorRect.new()
		fill.color = Color(0.05, 0.06, 0.09)
		fill.anchor_left = 0.5
		fill.anchor_top = 0.5
		fill.anchor_right = 1.0
		fill.anchor_bottom = 1.0
		split_layer.add_child(fill)


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
	var c := {"hair": Stats.HERO_HAIR[hero_hair][1], "skin": Stats.HERO_SKINS[hero_skin][1], "body": Stats.HERO_BODIES[hero_body][1], "face": hero_face}
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
	# (Any local player: stepping on their team's pad opens their perks,
	# stepping off closes them.)
	var on_pad := false
	for u in locals:
		if u == null or u.dead:
			continue
		var pad: Vector3 = upgrade_pads[u.team]
		if pad != Vector3.INF and _flat_dist(u.global_position, pad) < STATION_RADIUS:
			on_pad = true
			if not on_upgrade_pad and not menu_open and not chat_open:
				rank_open = true
				rank_player = u
	if not on_pad and on_upgrade_pad and rank_open:
		rank_open = false
	on_upgrade_pad = on_pad


func menu_blocks_input(u = null) -> bool:
	## True while a menu has this player's controls (the perk menu only
	## blocks the player who opened it).
	return menu_open or chat_open or guide_open or (rank_open and (u == null or rank_player == null or rank_player == u))


func _rank_pressed() -> bool:
	## Any local player pressing their perk key opens (or closes) their menu.
	for u in locals:
		if u == null or demo:
			continue
		if Input.is_action_just_pressed(u.act_prefix + "rank_menu"):
			if rank_open and rank_player == u:
				rank_open = false
			else:
				rank_open = true
				rank_player = u
			return true
	return false


func menu_tabs() -> Array:
	## Which menu tabs make sense now: at the title only Classes and Controls.
	return [1, 4, 5] if not playing else [0, 3, 1, 2, 4, 5]


func menu_tick() -> void:
	## Called every frame by the HUD, which keeps running while paused.
	quit_armed = maxf(quit_armed - get_process_delta_time(), 0.0) if menu_open else 0.0
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
			elif Input.is_action_just_pressed("menu") and main_menu and not name_editing:
				main_menu.back()
			elif not menu_open:
				if Input.is_action_just_pressed("menu_left"):
					cycle_difficulty(-1)
				if Input.is_action_just_pressed("menu_right"):
					cycle_difficulty(1)
				if Input.is_action_just_pressed("couch_more"):
					set_couch("more")
				if Input.is_action_just_pressed("couch_less"):
					set_couch("less")
				if Input.is_action_just_pressed("couch_mode"):
					set_couch("mode")
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
				quit_to_title()
		elif guide_open and not eaten:
			if Input.is_action_just_pressed("menu"):
				guide_close()
			for i in Guide.TOPICS.size():
				if Input.is_action_just_pressed("rank_%d" % (i + 1)):
					guide_pick(i)
		elif _rank_pressed() and not demo:
			pass  # handled in _rank_pressed
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
		if rank_open and rank_player == null:
			rank_player = player
		if rank_open and rank_player:
			if rank_player.dead:
				rank_open = false
			for i in 4:
				if Input.is_action_just_pressed(rank_player.act_prefix + "rank_%d" % (i + 1)):
					rank_player.spend_point(i)
			for i in 2:
				if Input.is_action_just_pressed(rank_player.act_prefix + "rank_%d" % (i + 5)):
					rank_player.choose_variant(rank_player.role, i)
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
	# Mouse clicks on menu buttons (the HUD records where it drew them). A
	# gamepad drives the same buttons through its cursor.
	_pad_nav()
	if confirm_block and not Input.is_action_pressed("ui_confirm"):
		confirm_block = false
	var click := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or (cursor_shown and Input.is_action_pressed("ui_confirm") and not confirm_block)
	if click and hud and menu_open:
		# Volume sliders follow the mouse while the button is held.
		var mp := menu_mouse()
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
		var mouse := menu_mouse()
		if not playing and not menu_open and main_menu and not name_editing:
			main_menu.tick(true, mouse)
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
			for b in hud.couch_buttons:
				if b[0].has_point(mouse):
					set_couch(b[1])
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
		if hud.quit_button.has_point(mouse) and menu_open:
			if quit_armed > 0.0:
				quit_to_title()
				return
			quit_armed = 3.0
			sfx.ui("ui_click", -4.0)
		if hud.close_button.has_point(mouse):
			if menu_open:
				menu_open = false
				get_tree().paused = false
			rank_open = false
	click_was = click


func menu_input(event: InputEvent) -> void:
	## Raw key events from the HUD: typing in chat and rebinding controls.
	# Remember whether player 1 is on the keyboard or a pad, so keycaps and
	# hints show the right names.
	if main_menu and not playing and main_menu.pad_event(event):
		confirm_block = true   # a joining pad's press is theirs, not a click for player 1
		lobby_pad_frame = Engine.get_process_frames()
		return
	if (event is InputEventJoypadButton or event is InputEventJoypadMotion) and (couch_players == 1 or event.device == local_pad(0)):
		if event is InputEventJoypadButton and event.pressed or event is InputEventJoypadMotion and absf(event.axis_value) > 0.6:
			pad_active = true
	elif (event is InputEventKey or event is InputEventMouseButton) and event.pressed:
		pad_active = false
		cursor_shown = false
	elif event is InputEventMouseMotion and event.relative.length() > 2.0:
		cursor_shown = false
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

func key_label(action: String, unit = null) -> String:
	## A short keycap label for the action's binding on whatever the player
	## holds: the mouse or keyboard for player 1 at the keys, the gamepad
	## (in Xbox or PlayStation names) for a pad player.
	if on_pad(unit):
		return pad_label(action, pad_kind(local_pad(unit.local_index if unit != null else 0)))
	if DisplayServer.get_name() == "headless":
		return action.to_upper()
	for ev in InputMap.action_get_events(action):
		if ev is InputEventMouseButton:
			return _mouse_name(ev.button_index)
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			return _short_key(_key_name(ev))
	return "-"


func on_pad(unit) -> bool:
	## Whether this local player (null = player 1) is holding a gamepad.
	return unit != null and unit.local_index > 0 or (unit == null or unit.local_index <= 0) and pad_active


func pad_label(action: String, kind: String) -> String:
	## The action's first gamepad binding, named for the kind of pad.
	for ev in InputMap.action_get_events(action):
		if ev is InputEventJoypadButton:
			return _pad_name(ev.button_index, kind)
	for ev in InputMap.action_get_events(action):
		if ev is InputEventJoypadMotion:
			return _axis_name(ev.axis, kind)
	return "-"


func binding_text(action: String, device: String, kind: String = "") -> String:
	## Every binding on one device ("key" = keyboard + mouse, "pad" = gamepad,
	## named for the given kind of pad or the one player 1 holds).
	if kind == "":
		kind = pad_kind(local_pad(0))
	var names: Array = []
	for ev in InputMap.action_get_events(action):
		if device == "key":
			if ev is InputEventKey:
				names.append(_key_name(ev))
			elif ev is InputEventMouseButton:
				names.append(_mouse_name(ev.button_index))
		else:
			if ev is InputEventJoypadButton:
				names.append(_pad_name(ev.button_index, kind))
			elif ev is InputEventJoypadMotion:
				names.append(_axis_name(ev.axis, kind))
	return " / ".join(names) if not names.is_empty() else "-"


func _axis_name(axis: int, kind: String) -> String:
	match axis:
		JOY_AXIS_TRIGGER_RIGHT: return "R2" if kind == "ps" else "RT"
		JOY_AXIS_TRIGGER_LEFT: return "L2" if kind == "ps" else "LT"
		JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y: return "Left stick"
		JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y: return "Right stick"
	return "Axis %d" % axis


# --- Gamepads ----------------------------------------------------------------

func local_pad(local_index: int) -> int:
	## The gamepad device a local player uses: in couch play players 2-4 hold
	## pads 0-2 and player 1 the next one; alone, player 1 holds whichever
	## pad is plugged in first.
	if couch_players > 1:
		if bound_pads.size() == couch_players:
			return bound_pads[maxi(local_index, 0)]
		return couch_players - 1 if local_index <= 0 else local_index - 1
	var pads: Array = Input.get_connected_joypads()
	return pads[0] if not pads.is_empty() else -1


func pad_kind(device: int) -> String:
	## "ps" for a DualSense / DualShock, "xbox" for everything else, unless
	## the Settings tab forces one.
	if pad_style != "auto":
		return pad_style
	if device < 0:
		return "xbox"
	return "ps" if _is_playstation(Input.get_joy_name(device), Input.get_joy_guid(device)) else "xbox"


func _is_playstation(joy_name: String, guid: String) -> bool:
	var n := joy_name.to_lower()
	for word in ["dualsense", "dualshock", "ps5", "ps4", "ps3", "playstation", "sony", "wireless controller"]:
		if word in n:
			return true
	# SDL GUIDs carry the USB vendor id little-endian at offset 8: Sony is 054c.
	return guid.length() >= 12 and guid.substr(8, 4) == "4c05"


func pad_title(device: int) -> String:
	## What to call a pad in toasts and the Settings tab.
	if device < 0 or not Input.get_connected_joypads().has(device):
		return "No gamepad"
	var n := Input.get_joy_name(device)
	if pad_kind(device) == "ps":
		var l := n.to_lower()
		return "DualSense (PS5)" if "dualsense" in l or "ps5" in l else ("DualShock (PS4)" if "dualshock" in l or "ps4" in l else "PlayStation controller")
	return n if n != "" else "Gamepad"


func _on_pad_changed(device: int, connected: bool) -> void:
	var who := ""
	if couch_players > 1:
		for k in couch_players:
			if local_pad(k) == device:
				who = " · player %d" % (k + 1)
	if connected:
		toast("%s connected%s" % [pad_title(device), who], Color(0.7, 0.9, 1.0))
		if not Input.is_joy_known(device):
			toast("Unknown gamepad layout: buttons may need rebinding in Controls", Color(1.0, 0.8, 0.5))
	else:
		toast("Gamepad disconnected%s" % who, Color(1.0, 0.8, 0.5))
		pad_active = false


func rumble(u, weak: float, strong: float, duration: float) -> void:
	## Shake the pad of the local player driving this unit.
	if u == null or not u.is_player or not rumble_on:
		return
	if couch_players == 1 and not pad_active:
		return  # player 1 is on the keyboard; no surprise buzzing from a pad on the desk
	rumble_pad(local_pad(u.local_index), weak, strong, duration)


func rumble_pad(device: int, weak: float, strong: float, duration: float) -> void:
	if not rumble_on or device < 0 or not Input.get_connected_joypads().has(device):
		return
	Input.start_joy_vibration(device, clampf(weak, 0.0, 1.0), clampf(strong, 0.0, 1.0), duration)


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


func _pad_name(button: int, kind: String = "xbox") -> String:
	if kind == "ps":
		match button:
			JOY_BUTTON_A: return "Cross"
			JOY_BUTTON_B: return "Circle"
			JOY_BUTTON_X: return "Square"
			JOY_BUTTON_Y: return "Triangle"
			JOY_BUTTON_LEFT_SHOULDER: return "L1"
			JOY_BUTTON_RIGHT_SHOULDER: return "R1"
			JOY_BUTTON_BACK: return "Create"
			JOY_BUTTON_START: return "Options"
			JOY_BUTTON_LEFT_STICK: return "L3"
			JOY_BUTTON_RIGHT_STICK: return "R3"
			JOY_BUTTON_GUIDE: return "PS"
			JOY_BUTTON_MISC1: return "Mute"
	match button:
		JOY_BUTTON_A: return "A"
		JOY_BUTTON_B: return "B"
		JOY_BUTTON_X: return "X"
		JOY_BUTTON_Y: return "Y"
		JOY_BUTTON_LEFT_SHOULDER: return "LB"
		JOY_BUTTON_RIGHT_SHOULDER: return "RB"
		JOY_BUTTON_BACK: return "View"
		JOY_BUTTON_START: return "Menu"
		JOY_BUTTON_LEFT_STICK: return "LS"
		JOY_BUTTON_RIGHT_STICK: return "RS"
		JOY_BUTTON_GUIDE: return "Guide"
		JOY_BUTTON_MISC1: return "Share"
		JOY_BUTTON_TOUCHPAD: return "Touchpad"
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
	cfg.set_value("settings", "couch_players", couch_players)
	cfg.set_value("settings", "couch_mode", couch_mode)
	cfg.set_value("settings", "screen_shake", screen_shake)
	cfg.set_value("settings", "damage_numbers", damage_numbers)
	cfg.set_value("settings", "show_fps", show_fps)
	cfg.set_value("settings", "gfx_quality", gfx_quality)
	cfg.set_value("settings", "fullscreen", fullscreen)
	cfg.set_value("settings", "rumble", rumble_on)
	cfg.set_value("settings", "pad_style", pad_style)
	cfg.set_value("settings", "hero_name", hero_name)
	cfg.set_value("settings", "hero_hair", hero_hair)
	cfg.set_value("settings", "hero_trim", hero_trim)
	cfg.set_value("settings", "hero_look", hero_look)
	cfg.set_value("settings", "banner_bg", banner_bg)
	cfg.set_value("settings", "banner_emblem", banner_emblem)
	cfg.set_value("settings", "banner_frame", banner_frame)
	cfg.set_value("settings", "banner_title", banner_title)
	cfg.set_value("settings", "map_variant", map_variant)
	cfg.set_value("settings", "hero_skin", hero_skin)
	cfg.set_value("settings", "hero_face", hero_face)
	cfg.set_value("settings", "hero_body", hero_body)
	cfg.set_value("settings", "team_size", team_size)
	cfg.set_value("settings", "split_screen", split_screen)
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
	couch_players = 1  # extra players join each session in the Ready Up lobby
	couch_mode = "coop" if cfg.get_value("settings", "couch_mode", "versus") == "coop" else "versus"
	screen_shake = cfg.get_value("settings", "screen_shake", true)
	damage_numbers = cfg.get_value("settings", "damage_numbers", true)
	show_fps = cfg.get_value("settings", "show_fps", false)
	gfx_quality = clampi(int(cfg.get_value("settings", "gfx_quality", 2)), 0, GFX_NAMES.size() - 1)
	fullscreen = cfg.get_value("settings", "fullscreen", false)
	rumble_on = cfg.get_value("settings", "rumble", true)
	pad_style = cfg.get_value("settings", "pad_style", "auto")
	if pad_style not in ["auto", "xbox", "ps"]:
		pad_style = "auto"
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
	hero_skin = clampi(cfg.get_value("settings", "hero_skin", 1), 0, Stats.HERO_SKINS.size() - 1)
	hero_face = clampi(cfg.get_value("settings", "hero_face", 0), 0, Stats.HERO_FACES.size() - 1)
	hero_body = clampi(cfg.get_value("settings", "hero_body", 0), 0, Stats.HERO_BODIES.size() - 1)
	team_size = clampi(cfg.get_value("settings", "team_size", TEAM_SIZE), 1, TEAM_SIZE)
	split_screen = cfg.get_value("settings", "split_screen", false)
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
	return _pbr("grass", 0.11, Color(0.96, 1.0, 0.9))


var verge_mat: StandardMaterial3D


func _verge() -> StandardMaterial3D:
	## Trampled, yellowed grass along the edge of a road.
	if verge_mat == null:
		verge_mat = _pbr("grass", 0.11, Color(0.9, 0.86, 0.62))
	return verge_mat


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
	# Things hung on walls (banners, shields, torches, frames) stay walkable:
	# their colliders stuck out of the wall and caught anyone hugging it.
	var file := inst.scene_file_path.get_file()
	for hung in ["banner", "sword_shield", "torch", "pictureframe", "wall_shelves"]:
		if hung in file:
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


func _add_path(from: Vector3, to: Vector3, width: float, mat: Material, verge: float = 1.6) -> void:
	## A flat strip of road or dirt from one point to another (any angle),
	## with a band of trampled grass either side so the edge is not a hard
	## line.
	var d := to - from
	d.y = 0.0
	if verge > 0.0:
		var v := MeshInstance3D.new()
		var vbox := BoxMesh.new()
		vbox.size = Vector3(d.length() + width * 0.6 + verge, 0.008, width + verge)
		v.mesh = vbox
		v.material_override = _verge()
		v.position = (from + to) / 2.0 + Vector3(0, 0.003, 0)
		v.rotation.y = atan2(-d.z, d.x)
		add_child(v)
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
		["flower", flower, 520, 0.14], ["tuft", tuft, 900, 0.18], ["stone", stone, 50, 0.0], ["cap", cap, 80, 0.26], ["leaf", leaf, 140, 0.02]]
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
					col = Color.from_hsv(0.27 + r.randf_range(-0.03, 0.03), 0.8, r.randf_range(0.28, 0.42))
				"stone":
					col = Color(0.46, 0.46, 0.44).lerp(Color(0.36, 0.38, 0.36), r.randf())
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


func in_channel(p: Vector3) -> bool:
	## In the river itself: between the banks, off every bridge deck and off
	## the shrine island. Nothing should ever stand there.
	if absf(p.x) >= RIVER_HALF - 0.1 or p.y > 0.3:
		return false
	if _flat_dist(p, Vector3.ZERO) < ISLAND_R + 0.4:
		return false
	return not _near_bridge(p.z, 0.3)


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
			cover_boxes.append(AABB(Vector3(c.x - 0.5, 0, c.z - length / 2.0), Vector3(1.0, 1.2, length)))
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
	if rail_side != 0.0:
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
	## A woven rug: a dark field with a gold border, an inner band and a pale
	## medallion in the middle, so it reads as a rug and not a coloured tile.
	var y := center.y
	_add_block(Vector3(center.x, y + 0.015, center.z), Vector3(size.x, 0.03, size.y), color, false, _carpet(color.darkened(0.25)))
	for xs in [-1.0, 1.0]:
		_add_block(Vector3(center.x + xs * (size.x / 2.0 - 0.1), y + 0.032, center.z), Vector3(0.12, 0.01, size.y), color, false, _gold())
		_add_block(Vector3(center.x + xs * (size.x / 2.0 - 0.36), y + 0.032, center.z), Vector3(0.06, 0.01, size.y - 0.6), color, false, _cloth(color.lightened(0.35)))
	# (The end bands sit a hair higher than the side bands: where they cross
	# at the corners, coplanar tops flicker.)
	for zs in [-1.0, 1.0]:
		_add_block(Vector3(center.x, y + 0.0335, center.z + zs * (size.y / 2.0 - 0.1)), Vector3(size.x, 0.01, 0.12), color, false, _gold())
		_add_block(Vector3(center.x, y + 0.0335, center.z + zs * (size.y / 2.0 - 0.36)), Vector3(size.x - 0.6, 0.01, 0.06), color, false, _cloth(color.lightened(0.35)))
	# The medallion: a diamond of lighter cloth with a gold centre.
	var med := minf(size.x, size.y) * 0.42
	var d := MeshInstance3D.new()
	var dm := BoxMesh.new()
	dm.size = Vector3(med, 0.01, med)
	d.mesh = dm
	d.rotation.y = PI / 4.0
	d.position = Vector3(center.x, y + 0.034, center.z)
	d.material_override = _cloth(color.lightened(0.2))
	add_child(d)
	_add_block(Vector3(center.x, y + 0.036, center.z), Vector3(med * 0.3, 0.01, med * 0.3), color, false, _gold())


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
	## A room's main light. The keeps and cellars are open to the sky (the
	## camera looks down into them), so nothing hangs from a ceiling: the
	## light is warm candlelight (Humans) or cool crystal light (Elves) with
	## no fixture, and the visible sources are the wall torches, candle
	## stands, braziers and crystals around the room.
	var light := OmniLight3D.new()
	light.position = pos
	light.shadow_enabled = shadows
	light.shadow_bias = 0.08
	if elven:
		light.light_color = Color(0.6, 1.0, 0.88)
		light.light_energy = 1.5
	else:
		light.light_color = Color(1.0, 0.76, 0.42)
		light.light_energy = 1.7
	light.omni_range = 10.0
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


const ROOM_FRONT := 2.8    # throne room: doors this far in front of the throne
const ROOM_BACK := 3.6     # back wall this far behind it
const ROOM_HALF_Z := 4.2
const ROOM_H := 2.3
const ROOM_DOOR_HALF := 1.2

func _build_throne_room(team: int, throne: Vector3, side: float, color: Color) -> void:
	## Walls, floor, dais and finery of the throne room. Stone and velvet for
	## the Humans; living bark, moss and crystal for the Elves. The doorway
	## in the front wall is the Crown Vault's lock (scripts/vault.gd).
	var elven := team == 0
	var front_x := throne.x - side * ROOM_FRONT
	var back_x := throne.x + side * ROOM_BACK
	var cx := (front_x + back_x) / 2.0
	var depth := ROOM_FRONT + ROOM_BACK
	var hz := ROOM_HALF_Z
	audit_label = "vault"
	# Floor: dark marble with a pale border (Humans) or a mossy glade floor (Elves).
	if elven:
		_add_block(Vector3(cx, 0.05, 0), Vector3(depth, 0.04, hz * 2), Color.WHITE, false, _pbr("bark", 0.5, Color(0.7, 0.66, 0.55)))
		_add_block(Vector3(cx, 0.06, 0), Vector3(depth - 1.2, 0.04, hz * 2 - 1.2), Color.WHITE, false, _pbr("flagstone_moss", 0.8, Color(0.95, 0.95, 0.88)))
	else:
		_add_block(Vector3(cx, 0.05, 0), Vector3(depth, 0.04, hz * 2), Color.WHITE, false, _marble(Color(0.55, 0.5, 0.52)))
		_add_block(Vector3(cx, 0.06, 0), Vector3(depth - 1.2, 0.04, hz * 2 - 1.2), Color.WHITE, false, _marble())
	# Walls: side walls, the back wall, and the front wall either side of the doors.
	var wall_mat := _ashlar()
	for zs in [-1.0, 1.0]:
		_add_block(Vector3(cx, ROOM_H / 2.0, zs * hz), Vector3(depth + 0.5, ROOM_H, 0.5), Color.WHITE, true, wall_mat)
		var seg := hz - ROOM_DOOR_HALF - 0.3
		_add_block(Vector3(front_x, ROOM_H / 2.0, zs * (ROOM_DOOR_HALF + 0.3 + seg / 2.0)), Vector3(0.5, ROOM_H, seg), Color.WHITE, true, wall_mat)
		# Door posts and the lintel over the doors.
		_add_block(Vector3(front_x, (ROOM_H + 0.3) / 2.0, zs * (ROOM_DOOR_HALF + 0.15)), Vector3(0.7, ROOM_H + 0.3, 0.3), Color.WHITE, true, _ashlar(Color(0.9, 0.86, 0.78)))
	_add_block(Vector3(back_x, ROOM_H / 2.0, 0), Vector3(0.5, ROOM_H, hz * 2 + 0.5), Color.WHITE, true, wall_mat)
	_add_block(Vector3(front_x, ROOM_H - 0.2, 0), Vector3(0.7, 0.4, ROOM_DOOR_HALF * 2 + 0.6), Color.WHITE, false, _timber(Color(0.7, 0.6, 0.5)) if not elven else _elf_leaf())
	# A cornice (or vine ledge) along every wall top.
	var cap := _ashlar(Color(0.92, 0.88, 0.8))
	for zs in [-1.0, 1.0]:
		_add_block(Vector3(cx, ROOM_H + 0.08, zs * hz), Vector3(depth + 0.7, 0.16, 0.7), Color.WHITE, false, cap)
	_add_block(Vector3(back_x, ROOM_H + 0.08, 0), Vector3(0.7, 0.16, hz * 2 + 0.7), Color.WHITE, false, cap)
	for zs in [-1.0, 1.0]:
		_add_block(Vector3(front_x, ROOM_H + 0.08, zs * (hz / 2.0 + ROOM_DOOR_HALF / 2.0)), Vector3(0.7, 0.16, hz - ROOM_DOOR_HALF), Color.WHITE, false, cap)
	if elven:
		# Leaf tufts along the grown walls' tops instead of a solid green slab.
		for k in 7:
			var t: float = -hz + 0.6 + k * (hz * 2 - 1.2) / 6.0
			_add_block(Vector3(back_x, ROOM_H + 0.3, t), Vector3(0.9, 0.3, 0.7), Color.WHITE, false, _elf_leaf(k % 2 == 0))
		for k in 6:
			var t: float = front_x + side * (0.5 + k * (depth - 1.0) / 5.0)
			for zs in [-1.0, 1.0]:
				_add_block(Vector3(t, ROOM_H + 0.3, zs * hz), Vector3(0.7, 0.3, 0.9), Color.WHITE, false, _elf_leaf(k % 2 == 1))
	audit_label = ""
	# Carpet from the doors to the dais, and the dais itself: two steps.
	_add_rug(Vector3(throne.x - side * 1.0, 0.07, 0), Vector2(2.6, 2.4), color)
	_add_block(throne + Vector3(side * 1.5, 0.14, 0), Vector3(3.0, 0.16, 4.8), Color.WHITE, false, _ashlar(Color(0.95, 0.9, 0.8)))
	_add_block(throne + Vector3(side * 1.8, 0.3, 0), Vector3(2.2, 0.16, 3.8), Color.WHITE, false, _ashlar(Color(0.98, 0.94, 0.86)))
	_add_block(throne + Vector3(side * 1.8, 0.39, 0), Vector3(1.8, 0.03, 3.0), Color.WHITE, false, _carpet(color))
	# The throne: a tall velvet-backed seat under a canopy on two posts.
	_add_block(throne + Vector3(side * 2.1, 0.68, 0), Vector3(1.0, 0.6, 1.3), Color.WHITE, false, _timber(Color(0.55, 0.42, 0.3)) if not elven else _ashlar(Color(0.6, 0.52, 0.4)))
	_add_block(throne + Vector3(side * 2.5, 1.5, 0), Vector3(0.4, 2.3, 1.6), color, false, _cloth(color.darkened(0.2)))
	_add_block(throne + Vector3(side * 2.5, 2.7, 0), Vector3(0.5, 0.3, 1.8), Color.WHITE, false, _gold())
	for zs in [-1.0, 1.0]:
		_add_block(throne + Vector3(side * 2.2, 0.65, zs * 0.75), Vector3(1.0, 0.5, 0.14), Color.WHITE, false, _gold())
		_add_block(throne + Vector3(side * 2.9, 1.6, zs * 1.3), Vector3(0.14, 3.2, 0.14), Color.WHITE, false, _gold() if not elven else _ashlar(Color(0.6, 0.52, 0.4)))
	_add_block(throne + Vector3(side * 2.3, 3.2, 0), Vector3(1.8, 0.08, 2.9), color, false, _cloth(color.darkened(0.1)) if not elven else _elf_leaf(true))
	_add_block(throne + Vector3(side * 1.45, 3.05, 0), Vector3(0.14, 0.3, 2.9), Color.WHITE, false, _gold())
	# A glowing window in the back wall, tapestries, torches and guards' finery.
	var glass := _material(color.lightened(0.5))
	glass.emission_enabled = true
	glass.emission = color.lightened(0.3)
	glass.emission_energy_multiplier = 1.6
	for zs in [-1.0, 1.0]:
		_add_block(Vector3(back_x - side * 0.3, 1.5, zs * 2.6), Vector3(0.06, 1.5, 0.9), Color.WHITE, false, glass)
		_add_block(Vector3(back_x - side * 0.34, 1.5, zs * 2.6), Vector3(0.04, 1.7, 1.1), Color.WHITE, false, _gold())
		_add_tapestry(team, Vector3(cx - side * 0.6, 0.4, zs * (hz - 0.3)), Vector3(0, 0, -zs), 1.4, 1.7)
		_add_wall_torch(Vector3(front_x + side * 1.2, 1.5, zs * (hz - 0.3)), Vector3(0, 0, -zs))
		_add_banner(team, Vector3(front_x - side * 0.4, 0.0, zs * (ROOM_DOOR_HALF + 1.6)), Vector3(-side, 0, 0), 0.6, true)
		if elven:
			_add_crystal(Vector3(back_x - side * 0.9, 0, zs * (hz - 0.9)), 0.9)
			_add_mushrooms(Vector3(front_x + side * 0.9, 0, zs * (hz - 0.8)), 61 + int(zs))
		else:
			_add_candle_stand(throne + Vector3(-side * 0.4, 0, zs * 2.2))
			_prop("dungeon/sword_shield", Vector3(back_x - side * 0.3, 1.4, zs * 1.2), 0.9, PI / 2.0 if side > 0.0 else -PI / 2.0)
	_add_light(Vector3(back_x - side * 0.8, 1.6, 0), color.lightened(0.4), 1.0, 6.0)
	# The treasury heaped in the back corners.
	_prop("dungeon/chest_gold", Vector3(back_x - side * 0.9, 0, -(hz - 0.8)), 0.7, PI / 2.0 if side < 0.0 else -PI / 2.0)
	_prop("dungeon/chest", Vector3(back_x - side * 1.0, 0, hz - 0.9), 0.6, PI / 2.0 if side < 0.0 else -PI / 2.0)
	if elven:
		_add_fireflies(throne + Vector3(0, 0.8, 0))


func _furnish_keep(team: int, kx: float, bx: float, side: float, throne: Vector3) -> void:
	## The keep's rooms around the throne room: an entrance hall, the great
	## hall (feasting) down one side, the chapel (Humans) or moon shrine
	## (Elves) down the other, and the royal chambers and armoury at the
	## back. Each room has its own floor, panelled walls and furniture; the
	## lanes between them stay clear for the bots.
	var color: Color = Stats.FACTIONS[team].color
	var elven := team == 0
	var khz := KEEP_HALF_Z
	var wz := khz - 0.45                     # inner face of the keep's side walls
	var room_f: float = kx + side * ROOM_FRONT  # the throne room's front wall... (throne is kx + 6)
	room_f = throne.x - side * ROOM_FRONT
	var room_b: float = throne.x + side * ROOM_BACK
	var g_z := (ROOM_HALF_Z + 0.35 + wz) / 2.0   # gallery centre line (z)
	var g_w := wz - (ROOM_HALF_Z + 0.35)          # gallery width
	var back_c := (room_b + side * 0.35 + bx - side * 0.5) / 2.0
	var back_d := absf((bx - side * 0.5) - (room_b + side * 0.35))
	var planks := _pbr("wood", 0.55, Color(0.9, 0.82, 0.7)) if not elven else _pbr("wood_dark", 0.5, Color(0.8, 0.85, 0.7))
	var wainscot := _pbr("wood_dark", 0.5, Color(0.85, 0.75, 0.62)) if not elven else _moss()
	# --- Floors -------------------------------------------------------------
	# Entrance hall: fine flags; great hall: planks; chapel: a dark carpet on
	# stone (or a mossy glade); chambers: planks under big rugs.
	_add_block(Vector3(kx + side * 1.8, 0.045, 0), Vector3(2.8, 0.03, wz * 2), Color.WHITE, false, _pbr("flagstone_moss" if elven else "flagstone", 0.9, Color(0.92, 0.9, 0.86)))
	_add_block(Vector3((room_f + room_b) / 2.0, 0.045, -g_z), Vector3(ROOM_FRONT + ROOM_BACK + 0.7, 0.03, g_w), Color.WHITE, false, planks)
	if elven:
		_add_block(Vector3((room_f + room_b) / 2.0, 0.045, g_z), Vector3(ROOM_FRONT + ROOM_BACK + 0.7, 0.03, g_w), Color.WHITE, false, _moss())
	else:
		_add_block(Vector3((room_f + room_b) / 2.0, 0.045, g_z), Vector3(ROOM_FRONT + ROOM_BACK + 0.7, 0.03, g_w), Color.WHITE, false, _pbr("carpet", 1.1, Color(0.3, 0.3, 0.5)))
	_add_block(Vector3(back_c, 0.045, 0), Vector3(back_d, 0.03, wz * 2), Color.WHITE, false, planks)
	# --- Panelled walls: a wainscot along every inner face, with a ledge. ---
	for zs in [-1.0, 1.0]:
		var depth := absf(bx - kx) - 1.2
		_add_block(Vector3((kx + bx) / 2.0, 0.5, zs * (wz - 0.05)), Vector3(depth, 1.0, 0.1), Color.WHITE, false, wainscot)
		_add_block(Vector3((kx + bx) / 2.0, 1.03, zs * (wz - 0.09)), Vector3(depth, 0.06, 0.18), Color.WHITE, false, _timber(Color(0.6, 0.5, 0.4)) if not elven else _elf_leaf())
	_add_block(Vector3(bx - side * 0.55, 0.5, 0), Vector3(0.1, 1.0, wz * 2), Color.WHITE, false, wainscot)
	# --- Lighting: warm room lights (no hanging fixtures under the open sky). ---
	_add_chandelier(Vector3(kx + side * 2.0, 2.1, 0), elven)
	_add_chandelier(Vector3(kx + side * 6.4, 2.1, 0), elven)
	_add_chandelier(Vector3((room_f + room_b) / 2.0, 2.1, -g_z), elven, false)
	_add_chandelier(Vector3((room_f + room_b) / 2.0, 2.1, g_z), elven, false)
	_add_chandelier(Vector3(back_c, 2.1, 0), elven, false)
	# --- The great hall (z < 0): the feasting table along the wall, the hearth, casks. ---
	# Everything hugs the outer wall; the lane nearest the throne room stays clear.
	var tpos := Vector3((room_f + room_b) / 2.0 - side * 1.0, 0, -(wz - 0.55))
	if elven:
		_prop("furniture/table_medium_long", tpos, BITS_SCALE, 0.0)
		for k in 3:
			var fx: float = tpos.x - 0.6 + k * 0.6
		_prop("dungeon/candle_triple", Vector3(tpos.x + 0.9, 0.6, tpos.z - 0.2), 0.45)
		for k in 2:
			_prop("dungeon/stool", tpos + Vector3(-0.5 + k * 1.0, 0, 0.9), BITS_SCALE, 0.0)
	else:
		_prop("dungeon/table_long_tablecloth_decorated_A", tpos, 0.62, PI / 2.0)
		for k in 3:
			_prop("dungeon/chair", tpos + Vector3(-0.9 + k * 0.9, 0, 0.9), BITS_SCALE, PI)
	var hearth := Vector3(room_b - side * 1.1, 0, -(wz - 0.3))
	audit_label = "hearth"
	_add_block(hearth + Vector3(0, 0.75, 0), Vector3(1.8, 1.5, 0.5), Color.WHITE, true, _ashlar(Color(0.8, 0.76, 0.7)))
	_add_block(hearth + Vector3(0, 1.58, 0), Vector3(2.0, 0.16, 0.7), Color.WHITE, false, _timber(Color(0.55, 0.45, 0.35)))
	_add_block(hearth + Vector3(0, 0.5, 0.26), Vector3(1.1, 1.0, 0.04), Color.WHITE, false, _material(Color(0.08, 0.06, 0.05)))
	audit_label = ""
	_add_flame(hearth + Vector3(0, 0.35, 0.3), 0.22, Color(1.0, 0.6, 0.2) if not elven else Color(0.5, 1.0, 0.7))
	_add_light(hearth + Vector3(0, 0.9, 1.0), Color(1.0, 0.7, 0.4) if not elven else Color(0.5, 1.0, 0.8), 1.4, 7.0)
	_prop("dungeon/keg", Vector3(room_f + side * 0.4, 0, -(wz - 0.5)), 0.55, 0.3)
	_prop("kitchen/crate_cheese" if not elven else "kitchen/crate_carrots", Vector3(room_f - side * 1.0, 0, -(wz - 0.55)), BITS_SCALE * 0.9, 0.4)
	# --- The chapel (Humans) or the moon shrine (Elves) (z > 0). ---
	if elven:
		# A still pool of moonlight ringed with stones, a shrine stone and crystals.
		var pool := Vector3((room_f + room_b) / 2.0, 0, wz - 1.05)
		var water := _material(Color(0.5, 0.9, 0.95))
		water.emission_enabled = true
		water.emission = Color(0.4, 0.9, 0.9)
		water.emission_energy_multiplier = 0.7
		var disc := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.8
		cm.bottom_radius = 0.8
		cm.height = 0.04
		disc.mesh = cm
		disc.material_override = water
		disc.position = pool + Vector3(0, 0.07, 0)
		add_child(disc)
		for k in 9:
			var a: float = k * TAU / 9.0
			_add_block(pool + Vector3(cos(a) * 0.95, 0.12, sin(a) * 0.95), Vector3(0.28, 0.2, 0.28), Color.WHITE, false, _ashlar(Color(0.8, 0.8, 0.75)))
		_add_light(pool + Vector3(0, 1.0, 0), Color(0.5, 0.9, 1.0), 1.2, 6.0)
		_add_fireflies(pool + Vector3(0, 0.6, 0))
		_add_block(Vector3(room_b - side * 0.9, 0.6, wz - 0.7), Vector3(0.8, 1.2, 0.8), Color.WHITE, true, _ashlar(Color(0.75, 0.72, 0.62)))
		_add_crystal(Vector3(room_b - side * 0.9, 1.2, wz - 0.7), 0.8)
		_add_mushrooms(Vector3(room_f + side * 0.6, 0, wz - 0.8), 71)
	else:
		# An altar against the wall under a glowing window, candle stands and a kneeling cloth.
		var altar := Vector3((room_f + room_b) / 2.0, 0, wz - 0.8)
		_add_block(altar + Vector3(0, 0.08, 0), Vector3(2.6, 0.16, 1.5), Color.WHITE, false, _ashlar(Color(0.95, 0.92, 0.86)))
		_add_block(altar + Vector3(0, 0.6, 0.1), Vector3(1.6, 0.9, 0.6), Color.WHITE, true, _ashlar(Color(0.9, 0.88, 0.82)))
		_add_block(altar + Vector3(0, 1.07, 0.1), Vector3(1.7, 0.04, 0.7), Color.WHITE, false, _cloth(color.lightened(0.3)))
		_prop("dungeon/candle_triple", altar + Vector3(-0.5, 1.1, 0.1), 0.5)
		_prop("dungeon/candle_triple", altar + Vector3(0.5, 1.1, 0.1), 0.5)
		var glass := _material(Color(0.95, 0.85, 0.5))
		glass.emission_enabled = true
		glass.emission = Color(1.0, 0.85, 0.4)
		glass.emission_energy_multiplier = 1.5
		_add_block(Vector3(altar.x, 1.7, wz - 0.12), Vector3(1.0, 1.2, 0.06), Color.WHITE, false, glass)
		_add_block(Vector3(altar.x, 1.7, wz - 0.14), Vector3(1.2, 1.4, 0.04), Color.WHITE, false, _gold())
		_add_light(altar + Vector3(0, 1.6, -0.6), Color(1.0, 0.85, 0.5), 1.0, 6.0)
		_add_block(altar + Vector3(0, 0.02, -1.4), Vector3(1.8, 0.02, 0.8), Color.WHITE, false, _cloth(color.darkened(0.2)))
		_add_candle_stand(Vector3(room_b - side * 0.6, 0, wz - 0.6))
		_add_candle_stand(Vector3(room_f + side * 0.5, 0, wz - 0.6))
	# --- Behind the throne room: the royal study (z < 0) and the armoury (z > 0). ---
	# Furniture keeps to the back wall and the side strips: the lanes from the
	# cellar stairs to the galleries' corners run through the middle.
	var bw: float = bx - side * 1.05    # just off the back wall
	if elven:
		_prop("furniture/shelf_B_large_decorated", Vector3(bw - side * 0.1, 0, -4.1), BITS_SCALE, PI / 2.0 if side > 0.0 else -PI / 2.0)
		_prop("furniture/cabinet_small_decorated", Vector3(room_b + side * 0.8, 0, -(wz - 0.45)), BITS_SCALE, PI)
		_add_mushrooms(Vector3(bw, 0, -2.9), 75)
	else:
		_prop("furniture/shelf_B_large_decorated", Vector3(bw - side * 0.1, 0, -4.1), BITS_SCALE, PI / 2.0 if side > 0.0 else -PI / 2.0)
		_prop("furniture/cabinet_medium_decorated", Vector3(room_b + side * 0.9, 0, -(wz - 0.45)), BITS_SCALE, PI)
		_prop("furniture/pictureframe_large_A", Vector3(bx - side * 0.62, 1.6, -2.6), BITS_SCALE, PI / 2.0 if side > 0.0 else -PI / 2.0)
	_add_rug(Vector3(back_c, 0.06, -4.0), Vector2(minf(back_d - 1.8, 4.6), 2.8), color)
	# The armoury.
	_prop("hex/weaponrack", Vector3(bw + side * 0.15, 0, 5.2), 4.0, PI / 2.0 if side > 0.0 else -PI / 2.0)
	_prop("dungeon/sword_shield_gold" if not elven else "dungeon/sword_shield", Vector3(bx - side * 0.62, 1.4, 3.2), 0.9, PI / 2.0 if side > 0.0 else -PI / 2.0)
	_prop("dungeon/sword_shield", Vector3(room_b + side * 1.6, 1.5, wz - 0.1), 0.9, 0.0)
	_add_rug(Vector3(back_c, 0.06, 4.0), Vector2(minf(back_d - 1.8, 4.6), 2.8), color.darkened(0.2))
	# Tapestries and torches along the galleries, braziers for the Humans.
	for zs in [-1.0, 1.0]:
		var ins := Vector3(0, 0, -zs)
		_add_tapestry(team, Vector3(kx + side * 1.6, 0.5, zs * wz), ins, 1.5, 1.9)
		_add_tapestry(team, Vector3((room_f + room_b) / 2.0 - side * 1.2, 0.5, zs * wz), ins, 1.2, 1.7)
		_add_wall_torch(Vector3(room_f - side * 0.2, 1.6, zs * (wz - 0.05)), ins)
		_add_wall_torch(Vector3(room_b + side * 1.5, 1.6, zs * (wz - 0.05)), ins)
		if not elven:
			_add_brazier(Vector3(kx + side * 0.9, 0, zs * (wz - 0.8)))
	if elven:
		_add_fireflies(Vector3(kx + side * 2.0, 0.5, 5.5))


func _furnish_cellar(team: int, bx: float, side: float) -> void:
	## Room lights, shelves and candles in the spawn cellar (no bunks: Faisal 2026-10-07).
	var color: Color = Stats.FACTIONS[team].color
	var elven := team == 0
	var hz := CELLAR_HALF_Z
	# Three warm room lights down the hall (no hanging fixtures: it is open to the sky).
	for k in 3:
		var x: float = bx + side * (3.0 + k * 4.2)
		_add_chandelier(Vector3(x, CELLAR_Y + 2.5, 0), elven)
	# A shelf of supplies by the stairs and candles along the side walls.
	for zs in [-1.0, 1.0]:
		if elven:
			_prop("dungeon/shelves", Vector3(bx + side * 1.4, CELLAR_Y, zs * (hz - 0.5)), 0.7, PI if zs > 0.0 else 0.0)
			_prop("dungeon/bottle_A_labeled_green", Vector3(bx + side * 1.4, CELLAR_Y + 0.95, zs * (hz - 0.75)), 0.5)
		else:
			_prop("dungeon/shelves", Vector3(bx + side * 1.4, CELLAR_Y, zs * (hz - 0.5)), 0.7, PI if zs > 0.0 else 0.0)
			_prop("dungeon/bottle_A_labeled_brown", Vector3(bx + side * 1.4, CELLAR_Y + 0.95, zs * (hz - 0.75)), 0.5)
		if elven:
			_add_mushrooms(Vector3(bx + side * 6.6, CELLAR_Y, zs * (hz - 0.6)), 51 + int(zs))
		else:
			_add_candle_stand(Vector3(bx + side * 6.6, CELLAR_Y, zs * (hz - 0.6)))


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
	_add_block(Vector3(kcx, 0.03, 0), Vector3(kdepth, 0.04, khz * 2), Color.WHITE, false, _pbr("flagstone_moss", 0.75, Color(0.9, 0.9, 0.84)) if mossy else _pbr("stone", 0.7, Color(0.86, 0.84, 0.8)))
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
	_add_rug(Vector3(kx - side * 2.4, 0.025, 0), Vector2(3.6, 5.0), color)  # its top clears the keep floor's (0.05): coplanar tops flicker
	_add_rug(Vector3(kx + side * 3.0, 0.05, 0), Vector2(5.0, 2.8), color)

	# The yard stays open: lanterns (Elves) or nothing but the gatehouse
	# banners (Humans). Faisal: the base was too busy.
	if team == 0:
		_add_lantern(Vector3(kcx - side * 6.5, 0, hz - 1.4))
		_add_lantern(Vector3(kcx - side * 6.5, 0, -(hz - 1.4)))
	# Banners on the yard side of the gatehouse towers.
	for zs in [-1.0, 1.0]:
		_add_banner(team, Vector3(fx + side * 1.1, 0.2, zs * (dh + 1.1)), Vector3(side, 0, 0), 0.6)
	# Inside the keep: columns along the side walls, torches, stacked stores at the back.
	for zs in [-1.0, 1.0]:
		_add_wall_torch(Vector3(kx + side * 1.2, 1.6, zs * (khz - 0.4)), Vector3(0, 0, -zs))
	# Faction flavour: elves grow greenery against their walls, humans post iron braziers.
	if team == 0:
		for zs in [-1.0, 1.0]:
			_add_bush(Vector3(fx - side * 1.9, 0, zs * (hz - 3.5)), int(zs) + 7)
			_add_bush(Vector3(fx - side * 2.3, 0, zs * (hz + 1.4)), int(zs) + 9)
			_add_bush(Vector3(kx - side * 1.2, 0, zs * (khz + 1.5)), int(zs) + 11)
	else:
		for zs in [-1.0, 1.0]:
			_add_torch(Vector3(kx - side * 1.3, 0, zs * (khz - 0.6)))

	# The throne room: a walled hall at the heart of the keep with the
	# monarch's throne on a dais. Its doors (the Crown Vault lock) only hold
	# the enemy. Carry the enemy monarch here to score.
	var throne := Vector3(kx + side * 6.0, 0, 0)
	thrones.append(throne)
	_build_throne_room(team, throne, side, color)
	var vault = Vault.new()
	add_child(vault)
	vault.setup(self, team, throne, side)
	vaults.append(vault)
	audit_blocks.append(["vault", AABB(throne + Vector3(minf(-side * 2.8, side * 3.6), 0, -4.4), Vector3(6.4, 2.8, 8.8))])
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
		for k in 4:
			var tx := bx + side * (1.5 + k * 3.4)
			_add_wall_torch(Vector3(tx, CELLAR_Y + 1.6, zs * (hz - 0.05)), Vector3(0, 0, -zs))
		_add_banner(team, Vector3(bx + side * 8.2, CELLAR_Y - 0.1, zs * (hz - 0.05)), Vector3(0, 0, -zs), 0.7)
	# The stairs: a straight flight up the middle into the keep.
	var st := cellar_stairs(team)
	_add_stairs(st[0], st[1], 3.2, _ashlar(Color(0.9, 0.86, 0.78)), 0.0)
	for zs in [-1.0, 1.0]:
		# Low walls along the raised part of the stairs (the foot is open).
		_add_block(Vector3(bx + side * 3.0, CELLAR_Y + 0.6, zs * 1.9), Vector3(7.6, 1.2, 0.3), Color.WHITE, true, _ashlar(Color(0.9, 0.86, 0.78)))
	# The sanctuary barrier at the top of the stairs: the enemy team can't pass
	# it and nothing they fire gets through. Elves raise a wall of green
	# light, Humans a ward of blue light.
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
		# The Humans' ward: a sheet of blue light (no portcullis, nothing
		# gate-like inside the castle) with a brazier either side.
		var field := MeshInstance3D.new()
		var fq := BoxMesh.new()
		fq.size = Vector3(0.12, 2.9, 3.5)
		field.mesh = fq
		var fm := StandardMaterial3D.new()
		fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fm.albedo_color = Color(0.4, 0.6, 1.0, 0.3)
		field.material_override = fm
		field.position = Vector3(bx, 1.45, 0)
		add_child(field)
		_add_torch(Vector3(bx - side * 0.2, 0, -2.3))
		_add_torch(Vector3(bx - side * 0.2, 0, 2.3))
	# The spawn circle at the far end: a glowing team-coloured ring on the floor.
	var spawn := Vector3(bx + side * 11.6, CELLAR_Y, 0)
	_add_rug(spawn, Vector2(3.4, 7.2), color.darkened(0.15))
	var ring := MeshInstance3D.new()
	var rm2 := TorusMesh.new()
	rm2.inner_radius = 2.0
	rm2.outer_radius = 2.25
	rm2.rings = 48
	ring.mesh = rm2
	ring.position = spawn + Vector3(0, 0.045, 0)
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
	_add_station(team, Role.KNIGHT, Vector3(bx + side * 3.4, CELLAR_Y, -6.8))
	_add_station(team, Role.ENGINEER, Vector3(bx + side * 6.6, CELLAR_Y, -6.8))
	_add_station(team, Role.RANGER, Vector3(bx + side * 9.8, CELLAR_Y, -6.8))
	_add_station(team, Role.MAGE, Vector3(bx + side * 3.4, CELLAR_Y, 6.8))
	_add_station(team, Role.ROGUE, Vector3(bx + side * 6.6, CELLAR_Y, 6.8))
	_add_station(team, Role.HEALER, Vector3(bx + side * 9.8, CELLAR_Y, 6.8))
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
var cam_attrs: CameraAttributesPractical


func apply_graphics() -> void:
	## The graphics preset and display mode, applied live. Low suits older
	## laptops and the Compatibility renderer; Ultra adds volumetric light
	## shafts and 8x MSAA.
	var q := gfx_quality
	var vp := get_viewport()
	vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X, Viewport.MSAA_8X][q]
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if q == 0 else Viewport.SCREEN_SPACE_AA_DISABLED
	vp.scaling_3d_scale = 0.8 if q == 0 else 1.0
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if q == 0 else Viewport.SCALING_3D_MODE_BILINEAR
	vp.positional_shadow_atlas_size = [1024, 2048, 4096, 8192][q]
	RenderingServer.directional_shadow_atlas_set_size([2048, 4096, 8192, 8192][q], true)
	RenderingServer.directional_soft_shadow_filter_set_quality([RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW, RenderingServer.SHADOW_QUALITY_SOFT_LOW, RenderingServer.SHADOW_QUALITY_SOFT_HIGH, RenderingServer.SHADOW_QUALITY_SOFT_ULTRA][q])
	RenderingServer.positional_soft_shadow_filter_set_quality([RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW, RenderingServer.SHADOW_QUALITY_SOFT_LOW, RenderingServer.SHADOW_QUALITY_SOFT_HIGH, RenderingServer.SHADOW_QUALITY_SOFT_ULTRA][q])
	if world_environment:
		world_environment.ssao_enabled = q >= 1
		world_environment.ssil_enabled = q >= 2
		world_environment.glow_enabled = q >= 1
		world_environment.volumetric_fog_enabled = q >= 3
	if cam_attrs:
		cam_attrs.dof_blur_far_enabled = q >= 2
	for pane in panes:
		pane.view.msaa_3d = vp.msaa_3d
		pane.view.screen_space_aa = vp.screen_space_aa
	if DisplayServer.get_name() != "headless":
		var want := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != want:
			DisplayServer.window_set_mode(want)


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
	environment.ambient_light_energy = 0.5
	environment.ambient_light_sky_contribution = 0.6
	environment.ambient_light_color = Color(0.75, 0.85, 0.8)
	# Soft contact shadows under props and in corners (Forward+ only).
	environment.ssao_enabled = true
	environment.ssao_radius = 1.2
	environment.ssao_intensity = 1.6
	environment.ssao_power = 1.3
	# Light bouncing off lit surfaces into shade (grass green on the walls,
	# torchlight on the floors): Forward+ only, High and Ultra.
	environment.ssil_enabled = true
	environment.ssil_radius = 4.0
	environment.ssil_intensity = 0.7
	environment.ssil_normal_rejection = 1.0
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 0.8
	environment.glow_enabled = true
	environment.glow_intensity = 0.45
	environment.glow_bloom = 0.08
	environment.glow_hdr_threshold = 1.4
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	for lv in 7:
		environment.set_glow_level(lv, 1.0 if lv in [2, 3, 4] else (0.5 if lv == 5 else 0.0))
	# A tilt-shift diorama: the far edge of the view softens a little, the
	# fight in the middle stays sharp (High and Ultra).
	environment.volumetric_fog_density = 0.006
	environment.volumetric_fog_albedo = Color(0.95, 0.93, 0.88)
	environment.volumetric_fog_anisotropy = 0.6
	environment.volumetric_fog_length = 80.0
	environment.volumetric_fog_sky_affect = 0.0
	# A touch of distance haze and a warmer, punchier grade.
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.8, 0.88, 0.95)
	environment.fog_density = 0.0012
	environment.fog_sky_affect = 0.2
	environment.adjustment_enabled = true
	environment.adjustment_saturation = 1.2
	environment.adjustment_contrast = 1.15
	environment.adjustment_brightness = 0.94
	env.environment = environment
	world_environment = environment
	add_child(env)
	# Camera attributes for the tilt-shift softening of the far edge.
	cam_attrs = CameraAttributesPractical.new()
	cam_attrs.dof_blur_far_distance = 38.0
	cam_attrs.dof_blur_far_transition = 18.0
	cam_attrs.dof_blur_amount = 0.05
	env.camera_attributes = cam_attrs

	var sun := DirectionalLight3D.new()
	sun_light = sun
	sun.rotation_degrees = Vector3(-52, -35, 0)
	sun.light_color = Color(1.0, 0.94, 0.82)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 1.5
	sun.shadow_blur = 1.2
	sun.light_angular_distance = 0.6   # soft, widening contact shadows (PCSS)
	sun.light_volumetric_fog_energy = 1.4
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
	var road := _pbr("road", 0.2)
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
	_add_action("scoreboard", [KEY_TAB], [JOY_BUTTON_BACK, JOY_BUTTON_TOUCHPAD])
	_add_action("chat", [KEY_ENTER], [])
	_add_action("chat_toggle", [KEY_H], [])
	_add_action("roster_toggle", [KEY_N], [])
	_add_action("options", [KEY_O], [JOY_BUTTON_BACK])
	_add_action("rank_1", [KEY_1], [JOY_BUTTON_DPAD_UP])
	_add_action("rank_2", [KEY_2], [JOY_BUTTON_DPAD_LEFT])
	_add_action("rank_3", [KEY_3], [JOY_BUTTON_DPAD_RIGHT])
	_add_action("rank_4", [KEY_4], [JOY_BUTTON_DPAD_DOWN])
	_add_action("rank_5", [KEY_5], [JOY_BUTTON_LEFT_SHOULDER])
	_add_action("rank_6", [KEY_6], [JOY_BUTTON_RIGHT_SHOULDER])
	_add_action("menu", [KEY_ESCAPE], [JOY_BUTTON_START])
	_add_action("menu_left", [KEY_LEFT, KEY_A], [JOY_BUTTON_LEFT_SHOULDER])
	_add_action("menu_right", [KEY_RIGHT, KEY_D], [JOY_BUTTON_RIGHT_SHOULDER])
	_add_action("quit_match", [KEY_BACKSPACE], [JOY_BUTTON_Y])
	_add_action("pick_elves", [KEY_1], [])
	_add_action("pick_humans", [KEY_2], [])
	# Gamepad menu cursor: the D-pad and left stick move it between buttons,
	# Cross / A picks, Circle / B backs out.
	_add_action("nav_left", [], [JOY_BUTTON_DPAD_LEFT], JOY_AXIS_LEFT_X, -1.0)
	_add_action("nav_right", [], [JOY_BUTTON_DPAD_RIGHT], JOY_AXIS_LEFT_X, 1.0)
	_add_action("nav_up", [], [JOY_BUTTON_DPAD_UP], JOY_AXIS_LEFT_Y, -1.0)
	_add_action("nav_down", [], [JOY_BUTTON_DPAD_DOWN], JOY_AXIS_LEFT_Y, 1.0)
	_add_action("ui_confirm", [], [JOY_BUTTON_A])
	_add_action("ui_back", [], [JOY_BUTTON_B])
	_add_action("restart", [KEY_R, KEY_ENTER], [JOY_BUTTON_START])
	_add_action("cmd_attack", [KEY_Z], [])
	_add_action("cmd_defend", [KEY_X], [])
	_add_action("cmd_help", [KEY_C], [])
	_add_action("couch_more", [KEY_EQUAL, KEY_KP_ADD, KEY_BRACKETRIGHT], [])
	_add_action("couch_less", [KEY_MINUS, KEY_KP_SUBTRACT, KEY_BRACKETLEFT], [])
	_add_action("couch_mode", [KEY_M], [])


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
