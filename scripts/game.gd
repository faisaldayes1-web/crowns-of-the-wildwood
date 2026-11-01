extends Node3D
## One match: builds the valley map, spawns both teams and runs the
## capture-the-monarch rules. Everything is built in code from simple shapes,
## so it can be swapped for real art later without changing the rules.

const Stats = preload("res://scripts/stats.gd")
const SaveFile = preload("res://scripts/save_file.gd")
const Unit = preload("res://scripts/unit.gd")
const Monarch = preload("res://scripts/monarch.gd")
const Projectile = preload("res://scripts/projectile.gd")
const Fx = preload("res://scripts/fx.gd")
const SkillFx = preload("res://scripts/skill_fx.gd")
const Gate = preload("res://scripts/gate.gd")
const Hud = preload("res://scripts/hud.gd")
const Store = preload("res://scripts/store.gd")
const Touch = preload("res://scripts/touch.gd")
const HealOrb = preload("res://scripts/heal_orb.gd")
const Trap = preload("res://scripts/trap.gd")
const Blessing = preload("res://scripts/blessing.gd")
const Vault = preload("res://scripts/vault.gd")
const Guide = preload("res://scripts/guide.gd")
const Barricade = preload("res://scripts/barricade.gd")
const MatchSummary = preload("res://scripts/match_summary.gd")
const Turret = preload("res://scripts/turret.gd")
const Seal = preload("res://scripts/seal.gd")
const Sfx = preload("res://scripts/sfx.gd")
const Volcano = preload("res://scripts/volcano.gd")
const Lanes = preload("res://scripts/lanes.gd")
const StaticBatch = preload("res://scripts/static_batch.gd")
const Season = preload("res://scripts/visual/season.gd")
const CharacterModel = preload("res://scripts/character_model.gd")
const MainMenu = preload("res://scripts/menu.gd")
const Legend = preload("res://scripts/legend.gd")
const MenuStage = preload("res://scripts/menu_stage.gd")
const Economy = preload("res://scripts/economy.gd")
const StyleProfile = preload("res://scripts/visual/style_profile.gd")
const CastleKit = preload("res://scripts/visual/castle_kit.gd")
const ForestKit = preload("res://scripts/visual/forest_kit.gd")
const Role = Stats.Role

const TEST_TEAM_MAX := 6     # --team-size=N cap for balance batches only
const TEAM_SIZE := 4          # strictly 4v4 for now (Faisal 2026-10-09): players and bots together
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
const CELLAR_DEPTH := 18.0    # how far behind the back wall it reaches (x)
const CELLAR_HALF_Z := 11.0
const CELLAR_Y := -2.4        # its floor
const ISLAND_R := 6.0         # the Crown Shrine island in the river
const STATION_RADIUS := 1.3
const CAMERA_OFFSET := Vector3(0, 19.0, 16.0)  # a long lens, pitched like a tabletop diorama (50 degrees)
var cam_zoom := 1.0  # --debug-zoom=N pulls the camera back for overview renders
var sfx: Node        # every sound: see sfx.gd
# The river runs north to south through the middle; three bridges cross it.
const RIVER_HALF := 3.0
const BRIDGES := [-20.0, 0.0, 20.0]      # the middle crossing is the shrine island
const BRIDGE_HALF := [2.2, 6.3, 3.0]
const BANK_LAYER := 16        # river banks block walkers, not shots
const MONARCH_TITLES := ["Elven Crown", "Human Crown"]
const CONTROLS_PATH := "user://controls.cfg"
const PROFILE_DIR := "user://profiles"   # one save per named player (save_file.gd)
# Actions the player can rebind in the Controls menu (and what to call them).
const REBINDABLE := [["move_interact", "Move / interact"], ["force_move", "Force move"], ["force_hold", "Force hold / stand still"], ["attack", "Base attack"], ["block", "Block"], ["ability_1", "Ability Q"], ["ability_2", "Ability E"], ["ability_3", "Upgraded hat move"],
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
	"ours_taken": ["They've taken our crown! Get it back!", "Stop the carrier!", "Don't let them cross the river!"],
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
var hero_hair_style := 0         # Stats.HERO_HAIR_STYLES index
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
static var reopen_screen := ""  # a menu screen to reopen after select_map() reloads the scene
var season := ""               # "winter" (Stonekeep Fortress), "twilight" (Twilight Grove) or "" (scripts/visual/season.gd)
var vmap = null                 # Ember Pass (the volcano map): its layout, bot routes and Fire Objective; null on the Wildwood
var lmap = null                 # Stonekeep Fortress / Twilight Grove: their own lanes, terrain and bot routes (scripts/lanes.gd); null elsewhere
var hero_skin := 1              # Stats.HERO_SKINS index
var hero_face := 0              # Stats.HERO_FACES index
var hero_eye := -1              # Stats.HERO_EYES index (-1: the side's own colour)
var hero_mark := 0              # Stats.HERO_MARKS index
var hero_body := 0              # Stats.HERO_BODIES index: the unclassed body's build
var team_size := TEAM_SIZE      # fighters a side; fixed at TEAM_SIZE for now, bots fill the gaps
var split_screen := false       # SELECT MAP's SPLIT SCREEN: extra pads may join in the lobby
var split_layout := "vertical"  # two-player split: "vertical" (side by side) or "horizontal" (top and bottom)
var lobby_sides: Array = []     # READY UP: each local player's side (0 Elves, 1 Humans)
var join_pads: Array = []       # READY UP: pad device of local players 2-4, in join order
var p1_pad_device := -1         # the pad player 1 used in the menus (-1: none or unknown)
var main_menu                   # menu.gd: the title, Select Map, Create Your Character, Ready Up
var menu_stage: Node3D          # menu_stage.gd: their 3D backdrops
# Account progression (saved): every XP point the player earns in a match,
# plus a match bonus, goes on the account. See Stats.account_level.
var account_xp := 0
var profile_id := ""          # the player playing now: user://profiles/<id>.cfg
var needs_name := false       # a first launch: the title asks who is playing
var saved_at := -1.0          # when the save was last written (seconds since start)
var account_gold := 0           # match rewards (Stats.MATCH_GOLD / MATCH_SHARDS), spent in the STORE (store.gd)
var account_shards := 0
var account_chests := 0         # unopened Match Chests (opened in the STORE)
var legend_seen := false        # the LEGEND OF THE WILDWOOD ending has played for this player (legend.gd)
var legend_sides: Array = [0, 0]                 # matches played as Elves / Humans (the legend names the side)
var legend_classes: Array = [0, 0, 0, 0, 0, 0, 0]   # matches by main class (Stats.Role): its favourite class
var legend = null               # legend.gd while the ending or the credits roll is on screen
var owned_items: Array = []     # STORE items bought or found in chests: "kind:index" keys (Store.key)
var hero_hat := 0               # Stats.HERO_HATS index (worn with no class hat on)
var hero_cape := 0              # Stats.HERO_CAPES index
var hero_outfit := 0            # Stats.HERO_OUTFITS index: armour tint
var hero_weapon := 0            # Stats.WEAPON_SKINS index
var match_xp := 0               # the player's XP earned this match, over every life
var summary = null              # the end-of-match screen (match_summary.gd), made when the match ends
var last_match_gain := 0        # what the last match added (end screen)
var match_played := 0.0         # seconds this match has run (GP-06: no result bonus for a match ended at once)
var level_before := 1           # account level before the last match (end screen)
var name_editing := false
var levelup_timer := 0.0
var levelup_level := 1
var levelup_text := ""         # set for a class promotion: the flourish says PROMOTED! and this name
var pine_tiers := {}   # cached pine tier meshes
var leaf_clusters := {}  # cached small crown clusters (visual pass 2026-10-30), by seed bucket and size
var map_trees: Array[Vector3] = []  # for the minimap: y > 0.5 means a big tree
var forest_kit = null  # scripts/visual/forest_kit.gd: the match world's tree and ground-dressing look (_kit())
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
var crown_event := ""         # "taken" / "dropped": the crown ribbon the HUD shows everyone else
var crown_event_team := -1    # the team of whoever took or dropped the crown
var crown_event_timer := 0.0  # counts down from the ribbon's time on screen
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
var economy = null            # wood, ore and what they buy (economy.gd)
# Quality of life settings (saved with the controls).
var screen_shake := true
var damage_numbers := true
var show_fps := false
var quit_armed := 0.0          # pause menu: seconds the MAIN MENU button stays armed after a first click
var gfx_quality := 2           # graphics preset: 0 Low, 1 Medium, 2 High, 3 Ultra
var howto_seen := false        # the HOW TO PLAY cards were shown once (menu.gd)
var fps_intro_done := false    # the FPS counter was switched on once for the alpha testers
var lamp_shadows: Array = []   # lamps that cast shadows (off on Low)
var gfx_picked := false        # the player chose a preset in Settings (no automatic changes after that)
var _fps_frames := 0           # automatic quality: frames counted in the current window...
var _fps_since := 0            # ...since this time (msec), 0 = not counting
var _fps_last := 0             # the previous frame's time (msec): a long stall restarts the window
var fullscreen := false
var window_mode := "windowed"   # Settings > Display: "windowed", "borderless" (fullscreen window) or "exclusive"
const WINDOW_MODES := ["windowed", "borderless", "exclusive"]
var vsync_on := true          # Settings: wait for the display refresh (no tearing)
var fps_cap := 0              # Settings: frame-rate limit, 0 = none
const FPS_CAPS := [0, 30, 60, 120, 144, 240]
var render_scale := 1.0        # Settings: 3D resolution scale (1.0 = native; the UI always stays sharp)
const RENDER_SCALES := [1.0, 0.85, 0.75, 0.5]
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
var split_fill: ColorRect
const SPLIT_TALL_ZOOM := 1.3    # camera pull-back in a side-by-side (half-width, full-height) pane
const SPLIT_HUD_SHARE := 0.26   # most of a pane's height the HUD's top bar + bottom row may cover
const SPLIT_HUD_ROWS := 260.0   # those two rows' height in HUD units
const SPLIT_HUD_WIDTH := 1240.0 # HUD units the bottom row needs across
var rank_player = null          # whose perk menu is open
var rank_from_pad := false      # the perk menu was opened by stepping on the Upgrade Station (it lets you walk off)
const COUCH_MAX := 4
const NO_PAD := 99              # a pad device id nothing uses: binds an action to no gamepad
const COUCH_ACTIONS := ["move_left", "move_right", "move_up", "move_down", "aim_left", "aim_right", "aim_up", "aim_down",
	"attack", "block", "ability_1", "ability_2", "ability_3", "dodge", "interact", "rank_menu", "rank_1", "rank_2", "rank_3", "rank_4", "rank_5", "rank_6"]

var camera: Camera3D
var hud
var touch                      # on-screen touch controls (touch.gd), for the web build on tablets
var touch_active := false      # a finger has touched the screen: aim follows the move stick, not the mouse
var control_layout := "auto"   # Controls tab (Faisal 2026-10-14: a touch-screen laptop got the iPad layout): "auto", "keyboard", "controller", "touch"
const CONTROL_LAYOUTS := ["auto", "keyboard", "controller", "touch"]
var move_mode := "screen"         # keyboard + mouse: "aim" (W walks toward the cursor) or "screen" (W walks up the screen)
var pc_movement := "click"  # click-to-move by default; "wasd" adds directional keyboard movement
var combine_move_attack := false  # walking past an enemy must not silently attack it
var wheel_zoom := false  # off: wheel bindings force-move; on: wheel zooms instead
var movement_primary_blocked := false
var movement_consumed_tap_frame := -1
var movement_force_pulse := false
var touch_tap := Vector2(-1, -1)  # where a finger tapped a menu this frame (the click polling below would miss a short tap)
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
var perf_log := false   # "--perf": print frame-time monitors every 5 s
var perf_clock := 0.0
var perf_counted := false
var no_downed := false   # --no-downed: losing your last heart kills outright (balance comparisons)
var shot_frame := 900
# Menus. The game menu (Esc) pauses; the rank menu (Tab) is an overlay.
var menu_open := false
var rank_open := false
var menu_tab := 0
var shake_amount := 0.0
var cam_kick := Vector3.ZERO     # directional jolt (kick_cam), springs back to zero
var cam_pos := Vector3.ZERO
var cam_lock := Vector3.INF     # --debug-cam=x,z parks the camera over a spot for renders
var cam_top := 0.0              # --debug-topdown=H: renders look straight down from height H (map layout shots)
var click_was := false
var slider_drag := -1        # the volume slider the held press started on
var menus_warming := false   # _warm_up_menus is flipping screens: no clicks
var click_latched := false   # a left press seen by _input since the last menu tick
var scoreboard_open := false   # held: the match scoreboard overlay
var debug_score := false
var chat_open := false
var chat_text := ""
var chat_log: Array = []       # {who, text, color, time, team}
var rebinding := ""            # action waiting for a new key in the Controls menu
var swallow_frame := -1        # frame on which a key was eaten by chat / rebinding
var bot_chat_timer := 18.0
# Online play (scripts/net.gd, the "Net" autoload): the host runs the match,
# a client's units are puppets that follow the host's snapshots.
var net: Node                   # the Net autoload (null if the project runs without it)
var net_client := false         # this instance joined someone else's game
var net_ready := false          # client: the host's world is built, waiting for a slot
var ip_editing := false         # the title screen's host address field has the keyboard
var net_ip := "127.0.0.1"
var net_test := false           # --net-test: the headless two-instance smoke test
var net_test_log := {}
var net_slot := Vector2i(-1, -1)  # client: the (team, lineup slot) the host gave us


var _preserve_menu_art_on_reload := false


func _set_min_window() -> void:
	## A desktop window can't be dragged smaller than the 1280x720 layout
	## (UI-14: it went down to 64x64 and shrank every menu), or than the screen
	## it is on. Tests that ask for a size (--resolution, user args) keep it.
	if DisplayServer.get_name() == "headless" or OS.has_feature("web") or OS.has_feature("mobile"):
		return
	if "--resolution" in OS.get_cmdline_args() or not OS.get_cmdline_user_args().is_empty():
		return
	var screen := DisplayServer.window_get_current_screen()
	var usable := DisplayServer.screen_get_usable_rect(screen)
	get_window().min_size = Vector2i(mini(1280, usable.size.x), mini(720, usable.size.y))
	# The project opens 1920x1080: on a smaller desktop (the Steam Deck's
	# 1280x800) that window ran off the screen. Fit it and centre it.
	var win := get_window()
	if win.mode == Window.MODE_WINDOWED and (win.size.x > usable.size.x or win.size.y > usable.size.y):
		win.size = Vector2i(mini(win.size.x, usable.size.x), mini(win.size.y, usable.size.y))
		win.position = usable.position + (usable.size - win.size) / 2


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		var mesh_guard := preload("res://scripts/headless_mesh_lifetime.gd").watch
		if not get_tree().node_added.is_connected(mesh_guard):
			get_tree().node_added.connect(mesh_guard)
		for mesh_node in find_children("*", "MeshInstance3D", true, false):
			mesh_guard.call(mesh_node)
	randomize()
	var fixed_seed := false
	_set_min_window()
	_show_loading(1.2)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			seed(int(arg.trim_prefix("--seed=")))
			fixed_seed = true
	net = get_node_or_null("/root/Net")
	if net:
		net.game = self
		net_client = net.is_client()
		net_test = "--net-test" in OS.get_cmdline_user_args()
	_setup_input()
	sfx = Sfx.new()
	add_child(sfx)
	if OS.has_feature("web"):
		# A first visit in a browser (the iPad) starts on Medium: sun shadows,
		# glow and a full-resolution 3D view (Faisal 2026-10-10: the website
		# looked much worse than the PC). _auto_quality drops to Low if the
		# device cannot hold the frame rate. The frame counter starts on so
		# a slow iPad shows its number (Settings: FPS).
		gfx_quality = 1
		show_fps = true
	_load_controls()
	_ensure_profile()
	# A button still held from the click that reloaded the scene (CONTINUE
	# on the summary, a map card) is not a new press on the next screen.
	click_was = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if OS.has_feature("web"):
		# Browsers (and tablets) run Medium at most; Settings can raise
		# it. (Here, not in _load_controls: a fresh browser has no settings
		# file and that returns early.)
		gfx_quality = mini(gfx_quality, 1)
		# Tablets are 4:3: letterbox the 16:9 canvas rather than let the
		# menus run off the sides.
		get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	_pick_graphics()
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
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--map="):  # testing: play a given Stats.MAPS index (2 = Ember Pass)
			map_variant = clampi(int(arg.trim_prefix("--map=")), 0, Stats.MAPS.size() - 1)
	# Cartoon shading on everything that enters the scene, props and units alike.
	get_tree().node_added.connect(func(n): _toonify.call_deferred(n))
	if net_client and net.map_variant >= 0:
		map_variant = net.map_variant   # the host's map
	# Every instance in an online game builds the same world from the host's
	# seed (trees, rocks and props carry colliders). --seed keeps its old meaning.
	if net and not fixed_seed:
		seed(net.world_seed)
	# Building the world and starting a match take seconds in one go, and
	# Windows greys a window out as "Not Responding" when it hears nothing
	# for 5 s: keep answering it while nodes pour in.
	get_tree().node_added.connect(func(_n): _keep_window_alive())
	season = Season.kind_of(map_variant)
	if season != "":
		tex_swap = Season.tex_swaps(season)   # snow or dusk meadow under everything
		swap_dim = Color.WHITE
	# Cold boot and scene transitions build incrementally.
	# Hold the existing loading art until construction and menu warm-up finish.
	_stream_world = DisplayServer.get_name() != "headless" and is_instance_valid(loading_layer)
	if _stream_world:
		menus_warming = true
		process_mode = Node.PROCESS_MODE_DISABLED
		_suspend_loading_3d()
		if loading_tween and loading_tween.is_valid():
			loading_tween.pause()
		await _world_build_frame()
	world_style = true   # the match world follows the style profile; the menus built below do not
	if _world_can_wait():
		_build_world_sky()
		world_ready = false
	else:
		await _build_world()
	world_style = false
	if net and not fixed_seed:
		randomize()
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
	perf_log = "--perf" in OS.get_cmdline_user_args()
	no_downed = "--no-downed" in OS.get_cmdline_user_args()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot-frame="):
			shot_frame = int(arg.trim_prefix("--shot-frame="))
	if demo:
		_start_match(0)
		if "--selftest" in OS.get_cmdline_user_args():  # headless combat checks (tests/combat_test.gd)
			var t: Node = load("res://tests/combat_test.gd").new()
			t.game = self
			add_child(t)
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
			hero_eye = int(parts[6]) if parts.size() > 6 else hero_eye
			hero_hair_style = int(parts[7]) if parts.size() > 7 else hero_hair_style
			hero_mark = int(parts[7]) if parts.size() > 7 else hero_mark
	for arg in OS.get_cmdline_user_args():
		# Testing the STORE: --debug-gold=N, --debug-chests=N, --debug-own=kind:i,kind:i
		# (owned and worn). Run renders with their own XDG_DATA_HOME: these save.
		if arg.begins_with("--debug-gold="):
			account_gold = int(arg.trim_prefix("--debug-gold="))
		if arg.begins_with("--debug-chests="):
			account_chests = int(arg.trim_prefix("--debug-chests="))
		if arg.begins_with("--debug-own="):
			for pair in arg.trim_prefix("--debug-own=").split(","):
				var kv := pair.split(":")
				owned_items.append(Store.key(kv[0], int(kv[1])))
				Store.equip(self, kv[0], int(kv[1]))
	if "--play" in OS.get_cmdline_user_args():
		# This route skips menu_stage.build and its construction-gate cleanup.
		# The world is complete; let the match process and its loading tween run.
		_restore_loading_3d()
		_stream_world = false
		process_mode = Node.PROCESS_MODE_INHERIT
		menus_warming = false
		_start_match(0)  # testing: straight into a match with a (idle) local player
		if "--fxshow" in OS.get_cmdline_user_args():  # combat effects showcase (tests/fx_showcase.gd)
			var show: Node = load("res://tests/fx_showcase.gd").new()
			show.game = self
			add_child(show)
		return
	banner.visible = false
	sfx.play_music(false)
	main_menu = MainMenu.new(self)
	menu_stage = MenuStage.new()
	add_child(menu_stage)
	await menu_stage.build(self)
	_stream_world = false
	process_mode = Node.PROCESS_MODE_INHERIT
	menu_stage.activate()
	main_menu.stage = menu_stage
	# Position the menu camera before enabling 3D, then keep every existing
	# menu/model/world shader warm-up enabled. Only construction was hidden.
	menu_stage.show_screen(main_menu.screen)
	_restore_loading_3d()
	# The warm-up flips through the screens, so it is told where to land:
	# picking Ember Pass reloads the scene and must come back to SELECT MAP,
	# not the title (Faisal 2026-10-15: "switch maps to ember and hit play
	# it kicks you off to the main menu").
	_warm_up_menus(reopen_screen if reopen_screen != "" else "title")   # (a coroutine: runs over the next frames, under the loading art)
	if reopen_screen != "":
		main_menu.go(reopen_screen)
		reopen_screen = ""
	if net and (net.is_client() or net.status.begins_with("The host left")):
		main_menu.go("online")   # a joiner waits for the host here (or reads why the room closed)
	if net and net.is_host():
		net.rewelcome()   # the host rebuilt its world (a new map): joiners rebuild theirs
	if net:
		print("NET ready")   # the title is up (tools/web_net_test.js waits for this)
	for arg in OS.get_cmdline_user_args():
		# Testing: open a menu screen (title, map, character, lobby) or overlay.
		if arg.begins_with("--debug-screen="):
			var scr := arg.trim_prefix("--debug-screen=")
			if scr in ["credits", "tutorial", "progress"]:
				main_menu.overlay = scr
			else:
				main_menu.go(scr)
		if arg == "--debug-legend" or arg.begins_with("--debug-legend="):
			# Testing: the ending straight away (=roll: just the credits roll).
			# Renders: --debug-legend-part=<n> --debug-legend-at=<seconds into
			# it>, --debug-legend-hold (stop the clock there), --debug-legend-ff.
			for a2 in OS.get_cmdline_user_args():
				if a2.begins_with("--debug-legend-hero="):   # renders: side,class (as if most played)
					var sc := a2.get_slice("=", 1).split(",")
					legend_sides[clampi(int(sc[0]), 0, 1)] += 1
					legend_classes[clampi(int(sc[1]) if sc.size() > 1 else 0, 0, legend_classes.size() - 1)] += 1
			start_legend("roll" if arg == "--debug-legend=roll" else "full")
			var part := 0
			var into := 0.0
			for a2 in OS.get_cmdline_user_args():
				if a2.begins_with("--debug-legend-part="):
					part = int(a2.get_slice("=", 1))
				if a2.begins_with("--debug-legend-at="):
					into = float(a2.get_slice("=", 1))
				if a2 == "--debug-legend-hold":
					legend.hold = true
				if a2 == "--debug-legend-ff":
					legend.press_skip()
				if a2.begins_with("--debug-legend-tour="):
					legend.tour_dir = a2.get_slice("=", 1)
			legend.t = legend.seg_start(part) + into
		if arg.begins_with("--debug-preview-team="):  # renders: the hero's side on the character screen
			main_menu.preview_team = int(arg.trim_prefix("--debug-preview-team="))
		if arg.begins_with("--debug-hair-style="):  # renders: a hair style without saving it
			hero_hair_style = clampi(int(arg.trim_prefix("--debug-hair-style=")), 0, Stats.HERO_HAIR_STYLES.size() - 1)
		if arg.begins_with("--debug-preview-role="):  # renders: the hero in a class's gear
			main_menu.preview_role = int(arg.trim_prefix("--debug-preview-role="))
		if arg.begins_with("--debug-char-tab="):
			main_menu.char_tab = int(arg.trim_prefix("--debug-char-tab="))
		# Testing the STORE (with the wallet flags above): --debug-store=kind:i
		# (open on an item), --debug-store-buy, --debug-store-chest.
		if arg.begins_with("--debug-store="):
			var kv := arg.trim_prefix("--debug-store=").split(":")
			main_menu.open_store(kv[0], int(kv[1]) if kv.size() > 1 else -1)
		if arg == "--debug-store-buy":
			main_menu.store.press("store_buy", null)
		if arg == "--debug-store-chest":
			main_menu.store.press("store_chest", null)
		if arg.begins_with("--debug-lobby="):  # N local players, all ready
			split_screen = true
			couch_players = clampi(int(arg.trim_prefix("--debug-lobby=")), 1, COUCH_MAX)
			main_menu.readied = [true, true, true, true]
	if net:
		_net_ready_hooks()
	if not world_ready:
		_build_world_behind()


func _world_can_wait() -> bool:
	## Whether the title may come up before the match world is built. Online
	## games, test routes and renders keep the world-first order.
	if not _stream_world or net_client or (net and net.online()):
		return false
	# Tools run with --script (audits, censuses, probes) look at the built
	# world from the title on; only the ones asking with --world-behind
	# (tools/world_behind_test.gd) see the player's order.
	if get_tree().get_script() != null and not "--world-behind" in OS.get_cmdline_user_args():
		return false
	for arg in OS.get_cmdline_user_args():
		if arg in ["--demo", "--play", "--audit", "--selftest"] or arg.begins_with("--shot") or arg.begins_with("--debug-"):
			return false
	return true


func _build_world_behind() -> void:
	## The match world, built a slice a frame behind the live menus.
	_world_behind = true
	StaticBatch.load_baked()   # the batch's saved mesh arrays, read on a thread meanwhile
	_preload_world()
	while menus_warming and not _world_rush:   # the menu warm-up first, under the loading art
		await _world_slice
	# A half-built world must not run (the economy's labels, the volcano):
	# each piece is held still until the whole world is there.
	get_tree().node_added.connect(_hold_world_piece)
	world_style = true
	_world_measure(true)
	_world_slice_start = Time.get_ticks_usec()
	_world_frame_deadline = _world_slice_start + WORLD_SLICE_USEC
	await _build_world_land()
	if not "--no-batch" in OS.get_cmdline_user_args():
		# The scenery batching (static_batch.gd, ~1 s) waited for the match
		# start; the world is finished here, so it is done now, in slices.
		await StaticBatch.run(self)
		await StaticBatch.particles_to_gpu(self)
		_world_batched = true
	world_style = false
	_world_behind = false
	_world_measure(false)
	_preloads_done()
	get_tree().node_added.disconnect(_hold_world_piece)
	for held in _world_held:
		if is_instance_valid(held[0]):
			held[0].process_mode = held[1]
	_world_held = []
	apply_graphics()   # the world's lamps take the quality setting
	world_ready = true
	world_finished.emit()


const WORLD_PRELOAD := "res://assets/world_preload.res"   # per map, from tools/bake_batch_cache.gd
var _world_preloads := PackedStringArray()   # requested on worker threads
var _world_preload_scenes := PackedStringArray()   # waiting for the textures and materials they share


func _preload_world() -> void:
	## claude-faisal/stutter 2026-10-30: the scenes, textures and shaders the
	## match world loads as it builds start loading on worker threads now, so
	## each load() in the build finds them ready instead of reading and
	## uploading them between two title frames (most of the 30-90 ms frames
	## behind the title were a prop, a texture set or a character loading).
	## The scenes wait for the files first: two threads loading scenes that
	## share a texture each made their own copy (Godot 4.3), and the batch
	## merges materials only when their textures are the same one.
	if not ResourceLoader.exists(WORLD_PRELOAD):
		return
	var pre = load(WORLD_PRELOAD)
	var key := StringName("map_%d" % map_variant)
	if pre == null or not pre.has_meta(key):
		return
	for f in pre.get_meta(key):
		# (Not the shaders: small to read, and one loaded on a thread was
		# never freed at exit, Godot 4.3.)
		if ResourceLoader.has_cached(f) or f.get_extension() == "gdshader":
			continue
		if f.get_extension() in ["tscn", "scn", "gltf", "glb", "blend", "fbx", "obj"]:
			_world_preload_scenes.append(f)
		elif ResourceLoader.load_threaded_request(f) == OK:
			_world_preloads.append(f)


func _preload_scenes_when_ready() -> void:
	## (Each slice: once every file is in, the scenes go.)
	if _world_preload_scenes.is_empty():
		return
	for f in _world_preloads:
		if ResourceLoader.load_threaded_get_status(f) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			return
	for f in _world_preload_scenes:
		if not ResourceLoader.has_cached(f) and ResourceLoader.load_threaded_request(f) == OK:
			_world_preloads.append(f)
	_world_preload_scenes.clear()


func _preloads_done() -> void:
	## The world holds what it uses; the loader lets go of the rest.
	_world_preload_scenes.clear()
	for f in _world_preloads:
		ResourceLoader.load_threaded_get(f)
	_world_preloads.clear()


func _hold_world_piece(n: Node) -> void:
	if world_style and n.get_parent() == self:   # (world_style: a world slice, not the menus)
		_world_held.append([n, n.process_mode])
		n.process_mode = Node.PROCESS_MODE_DISABLED


func finish_world_now() -> void:
	## Before this scene goes (a reload, a map switch, quitting): a world
	## still building behind the menus is finished at once. Its paused steps
	## would otherwise outlive the scene holding renderer resources, and
	## Godot 4.3 crashed on exit freeing them.
	if not _world_behind:
		return
	var t0 := Time.get_ticks_msec()
	_world_rush = true
	_world_slice.emit()
	print("WORLD finished at once in %d ms" % (Time.get_ticks_msec() - t0))


func _reload_scene() -> void:
	finish_world_now()
	# Retain immutable UI artwork only across an intentional scene replacement.
	_preserve_menu_art_on_reload = true
	if get_tree().reload_current_scene() != OK:
		_preserve_menu_art_on_reload = false


func _exit_tree() -> void:
	_restore_loading_3d()  # an interrupted build must not change its caller's viewport
	if not _preserve_menu_art_on_reload:
		# Retire the last worker task before its captured script/resources unload.
		_flush_save()
		_release_menu_art()
	if net and net.game == self:
		net.game = null
	# Menu and Store are RefCounted and point at each other. Break that
	# cycle on reload so repeated map switches do not retain every old UI.
	if main_menu and main_menu.store:
		main_menu.store.menu = null
		main_menu.store.game = null


static func _release_menu_art() -> void:
	MainMenu.tex.clear()
	Hud.icons.clear()
	Hud.clean_icons.clear()
	Hud.strips.clear()
	Hud.cards.clear()
	Hud.skill_art.clear()
	Hud.menu_tex.clear()
	Hud._banner_textures.clear()
	Hud.topbar_tex = null
	Hud.logo = null
	Hud.bar_font = null
	Hud.title_font = null


func _net_ready_hooks() -> void:
	## Online start-up: a client that has the host's world tells the host it
	## is ready; --host / --join start a connection from the command line.
	if net_client:
		net_ready = true
		net.client_ready()
		if not net.pending_start.is_empty():
			net_start_client(net.pending_start)
		return
	if net.online() or net.cli_done:
		return  # the host came back to the title after a match: keep hosting
	net.cli_done = true
	for arg in OS.get_cmdline_user_args():
		if arg == "--host" or arg.begins_with("--host="):
			net.host(int(arg.trim_prefix("--host=")) if "=" in arg else net.DEFAULT_PORT)
		elif arg.begins_with("--join="):
			var parts := arg.trim_prefix("--join=").split(":")
			net.join(parts[0], int(parts[1]) if parts.size() > 1 else net.DEFAULT_PORT)
		elif arg == "--room-create":
			net.create_room()
		elif arg.begins_with("--room-join="):
			var code := arg.trim_prefix("--room-join=")
			if code.begins_with("@"):   # tests: wait for the host to write its code to this file
				var path := code.substr(1)
				for i in 600:
					if FileAccess.file_exists(path) and FileAccess.get_file_as_string(path).strip_edges() != "":
						break
					await get_tree().create_timer(0.1).timeout
				code = FileAccess.get_file_as_string(path).strip_edges()
			net.join_room(code)


func _process(delta: float) -> void:
	if _world_behind:
		_world_slice.emit()
	if _match_waiting:
		return   # a match is waiting for the world under the loading art
	if debug_kill and player and not player.kill_banner.is_empty():
		player.kill_banner.time = Time.get_ticks_msec() / 1000.0 - 0.7
		for k in kill_feed:
			k.time = Time.get_ticks_msec() / 1000.0 - 1.0
	_debug_hooks()
	_ui_sounds()
	_auto_quality()
	for t in 2:
		command_timer[t] = maxf(command_timer[t] - delta, 0.0)
	if playing and overtime and not game_over and not net_client:
		# Sudden death: a team with nobody left standing loses.
		for t in 2:
			if units.filter(func(u): return u.team == t and not u.dead).is_empty():
				announce("The %s are wiped out!" % Stats.FACTIONS[t].name)
				_finish(1 - t)
				break
	_update_compass()
	if net_test:
		_net_test_tick(delta)
	if vmap and world_ready:
		vmap.tick(delta)
	if lmap and world_ready and demo and playing and not game_over:
		lmap.sample(delta)   # bot matches: where the fighting happens (LANESTAT in the demo report)
	if legend or Engine.get_process_frames() == swallow_frame and game_over:
		return   # the ending is on screen (legend.gd takes the input) or just closed
	if not playing and not game_over:
		if name_editing or ip_editing or menu_open or net_client:
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
		if Input.is_action_just_pressed("scoreboard") and summary:
			summary.show_board = not summary.show_board
		if touch_tap.x >= 0.0 and summary and hud:
			# A finger on the summary's buttons (a mouse click goes through hud._input).
			hud._click_end(touch_tap)
			touch_tap = Vector2(-1, -1)
		if Input.is_action_just_pressed("restart") or Input.is_action_just_pressed("ui_back") \
				or (Input.is_action_just_pressed("ui_confirm") and summary and summary.elapsed() > 1.0):   # A too, not an attack mashed into the end
			# The first press skips the tally; once it has played, go on.
			# (B too: a pad player reaches for it to leave a screen, UI-22.)
			if summary and not summary.done():
				summary.skip()
			else:
				continue_after_summary()
		return

	match_played += delta
	if net_client:
		# The host runs the match: only the camera, the HUD timers and the
		# fortify horn (when the snapshot's clock says so) run here.
		if prep_left <= 0.0 and is_instance_valid(barrier):
			_begin_battle()
		_update_camera(delta)
		_tick_ui_timers(delta)
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
	perf_clock += delta
	if perf_log and perf_clock >= 5.0:
		perf_clock = 0.0
		if not perf_counted:
			perf_counted = true
			var kinds := {}
			var casters := 0
			var blended := 0
			for n in find_children("*", "", true, false):
				kinds[n.get_class()] = kinds.get(n.get_class(), 0) + 1
				if n is GeometryInstance3D and n.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
					casters += 1
				if n is MeshInstance3D:
					var mat: Material = n.material_override if n.material_override else (n.get_active_material(0) if n.mesh and n.mesh.get_surface_count() > 0 else null)
					if mat is BaseMaterial3D and (mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or mat.blend_mode != BaseMaterial3D.BLEND_MODE_MIX):
						blended += 1
			var top := kinds.keys()
			top.sort_custom(func(a, b): return kinds[a] > kinds[b])
			var line := "PERF nodes by class:"
			for k in top.slice(0, 14):
				line += " %s=%d" % [k, kinds[k]]
			print(line)
			print("PERF shadow casters=%d, transparent/blended mesh instances=%d" % [casters, blended])
		print("PERF fps=%d process=%.1fms physics=%.1fms draws=%d objects=%d prims=%d nodes=%d" % [
			Performance.get_monitor(Performance.TIME_FPS), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
	_tick_ui_timers(delta)


func _tick_ui_timers(delta: float) -> void:
	stolen_timer = maxf(stolen_timer - delta, 0.0)
	crown_event_timer = maxf(crown_event_timer - delta, 0.0)
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
	_debug_downed_hooks(frame)
	for arg in OS.get_cmdline_user_args():
		if frame == shot_frame - 5:
			if arg.begins_with("--debug-title-tab="):
				title_tab = int(arg.trim_prefix("--debug-title-tab="))
			if arg.begins_with("--debug-xp="):
				account_xp = int(arg.trim_prefix("--debug-xp="))
		if frame == shot_frame - 50 and player and arg == "--debug-carry" and monarchs[1 - player_team].state != Monarch.State.CARRIED:
			# Renders: the player holding the enemy crown, picked up 50 frames
			# before the shot so the pickup banner has popped in.
			monarchs[1 - player_team].pick_up(player)
			player.carrying = monarchs[1 - player_team]
		if frame == shot_frame - 45 and player:
			if arg == "--debug-killed" or arg == "--debug-killed-finish":
				# The kill screen: a bot's banner over the player's death
				# (45 frames early so the death screen has faded fully in).
				player.global_position = Vector3(-20, 0, 3)
				player.spawn_protect = 0.0
				player.home_defense = false
				for u in units:
					if u.team != player_team and not u.dead:
						u.bot_class = Role.KNIGHT
						player.take_damage(player.hearts, u, player.global_position + Vector3(2, 0, 0))
						if player.downed:
							# Downed first: "--debug-killed-finish" has the bot
							# finish the player off, else they bleed out.
							player._die(u if "--debug-killed-finish" in OS.get_cmdline_user_args() else null)
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
			if arg.begins_with("--debug-map-zoom="):
				hud.map_zoom = float(arg.trim_prefix("--debug-map-zoom="))
			if arg.begins_with("--debug-tab="):
				menu_tab = int(arg.trim_prefix("--debug-tab="))
			if arg == "--debug-stolen":
				stolen_timer = 3.5
				if monarchs[player_team].state == Monarch.State.HOME:
					var thief = units.filter(func(x): return x.team != player_team)[mini(1, team_size - 1)]
					monarchs[player_team].pick_up(thief)
					thief.carrying = monarchs[player_team]
					crown_event_note("taken", thief.team)
			if arg == "--debug-crown-lost":  # renders: an ally dropping the enemy crown
				var ally = units.filter(func(x): return x.team == player_team and not x.is_player)[0]
				monarchs[1 - player_team].pick_up(ally)
				ally.carrying = monarchs[1 - player_team]
				drop_monarch(ally)
			if arg.begins_with("--debug-points="):   # renders: points to spend (the LEVEL UP strip)
				player.points = int(arg.trim_prefix("--debug-points="))
			if arg == "--debug-levelup":
				levelup_timer = 3.0
				levelup_level = 2
				levelup_text = ""
			if arg.begins_with("--debug-role="):  # renders: play a class from the start
				player.set_role(int(arg.trim_prefix("--debug-role=")))
				player.ranks[player.role] = [1, 2, 0, 1]
				player.mastery[player.role] = 2
			if arg == "--debug-class":
				# Renders: the class pick-up banner, as if the Knight's hat was just taken.
				player.set_role(Role.KNIGHT)
				player.class_banner = player.CLASS_BANNER_TIME - 0.5
			if arg == "--debug-promote":
				player.set_role(Role.KNIGHT)
				player.mastery[Role.KNIGHT] = 3
				player.choose_variant(Role.KNIGHT, 0)
				levelup_timer = 2.8
			if arg == "--debug-guide":
				guide_open = true
				guide_page = 1
			if arg.begins_with("--debug-guide-topic="):   # renders: an answer with its picture
				guide_open = true
				guide_page = -1
				guide_topic = int(arg.trim_prefix("--debug-guide-topic="))
			if arg == "--debug-guide-menu":
				guide_open = true
				guide_page = -1
				guide_topic = -1
			if arg == "--debug-score":
				debug_score = true
			if arg.begins_with("--debug-zoom="):
				cam_zoom = float(arg.trim_prefix("--debug-zoom="))
			if arg.begins_with("--debug-topdown="):
				cam_top = float(arg.trim_prefix("--debug-topdown="))
			if arg.begins_with("--debug-cam="):
				var c := arg.trim_prefix("--debug-cam=").split(",")
				cam_lock = Vector3(float(c[0]), 0.0, float(c[1]))
				cam_pos = cam_lock + CAMERA_OFFSET * cam_zoom
			if arg.begins_with("--debug-at="):
				var p := arg.trim_prefix("--debug-at=").split(",")
				player.position = Vector3(float(p[0]), float(p[2]) if p.size() > 2 else 0.0, float(p[1]))
				cam_pos = player.position + CAMERA_OFFSET * cam_zoom
			if arg.begins_with("--debug-fire=") and vmap and not "--debug-fire-early" in OS.get_cmdline_user_args():
				# Ember Pass: hand the Fire Objective to a team (and give the
				# player a class so the FIRE form shows).
				var ft := int(arg.trim_prefix("--debug-fire="))
				if player.role == Role.BASE:
					player.set_role(Role.KNIGHT)
				vmap.fire_progress = -1.0 if ft == 0 else 1.0
				vmap._set_owner(ft)
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
		if arg.begins_with("--debug-fire=") and vmap and player and frame == 30 and "--debug-fire-early" in OS.get_cmdline_user_args():
			# The same, early, so the capture's flash has faded by the shot.
			if player.role == Role.BASE:
				player.set_role(Role.KNIGHT)
			vmap.fire_progress = -1.0 if arg.ends_with("0") else 1.0
			vmap._set_owner(0 if arg.ends_with("0") else 1)
		if arg == "--debug-options" and frame == shot_frame - 5 and not playing:
			menu_open = true
			menu_tab = 5
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
	carrier.gain_xp(Stats.XP_CAPTURE, "crown")
	steam_unlock("FIRST_CAPTURE", carrier)
	spawn_splash(thrones[carrier.team] + Vector3(0, 1, 0), Color(1.0, 0.85, 0.3), 50, 6.0, 1.2, true)
	spawn_pillar(thrones[carrier.team], Color(1.0, 0.85, 0.3), 7.0, 1.4)
	spawn_ring(thrones[carrier.team], 6.0, Color(1.0, 0.9, 0.5), 0.8)
	shake(0.3)
	rumble(carrier, 0.5, 0.9, 0.5)
	var team_name: String = Stats.FACTIONS[carrier.team].name
	carrier.captures += 1
	capture_timer = 3.5
	capture_team = carrier.team
	sfx.sting("crown_captured" if carrier.team == player_team else "crown_lost", "capture")
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
	if vmap:
		print("FIRESTAT held=%d/%d captures=%d/%d" % [int(vmap.fire_held[0]), int(vmap.fire_held[1]), vmap.fire_captures[0], vmap.fire_captures[1]])
	if lmap:
		print("LANESTAT " + lmap.sample_report())
	for u in units:
		# The class the bot plays all match (its current role resets on death).
		var cls: String = Stats.FACTIONS[u.team].roles[u.bot_class]
		var vi: int = u.variants.get(u.bot_class, -1)
		if vi >= 0:
			cls = Stats.VARIANTS[u.bot_class][vi].name
		print("STAT team=%d class=%s kills=%d deaths=%d assists=%d dmg=%d heal=%d caps=%d level=%d revives=%d revived=%d" % [u.team, cls.replace(" ", ""),
			u.kills, u.deaths, u.assists, u.damage_dealt, u.healing, u.captures, u.level, u.revives, u.times_revived])
	if economy:
		economy.print_summary()


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
	chat_system(line)   # the summary screen carries the result; no banner over it
	_steam_match_end(winner)
	if message_label:
		message_label.text = ""
	_bank_match_xp(winner)
	sfx.play_ambience(false)
	if winner < 0:
		sfx.ui("horn")
		sfx.stop_music()
	else:
		sfx.sting("victory" if winner == player_team else "defeat", "victory" if winner == player_team else "defeat", true)


func _steam_match_end(winner: int) -> void:
	## Steam achievements for the finished match (scripts/steam.gd; no-op off Steam).
	var steam = get_node_or_null("/root/SteamHub")
	if steam == null or demo:
		return
	if net and net.online():
		steam.unlock("ONLINE_MATCH")
	if winner >= 0 and winner == player_team:
		steam.unlock("FIRST_WIN")
		steam.unlock("WIN_ELVES" if Stats.FACTIONS[winner].name == "Elves" else "WIN_HUMANS")


func steam_unlock(id: String, u = null) -> void:
	## One achievement, only for the local player (u) when one is given.
	if u != null and not u.is_player:
		return
	var steam = get_node_or_null("/root/SteamHub")
	if steam and not demo:
		steam.unlock(id)


func pointer_descriptor(u, selected) -> Array:
	# Only public, stable identities. Never send instance IDs or method names.
	if not is_instance_valid(selected) or not selected.is_inside_tree() or selected.is_queued_for_deletion():
		return []
	if guides[u.team] == selected:
		return ["guide", 0]
	for role in seals[u.team]:
		if seals[u.team][role] == selected:
			return ["seal", int(role)]
	if monarchs.size() > 1 and monarchs[1 - u.team] == selected:
		return ["crown", 0]
	if economy != null:
		var index: int = economy.nodes.find(selected)
		if index >= 0:
			return ["resource", index]
	return []


func pointer_node(u, descriptor: Array):
	if descriptor.size() != 2 or not descriptor[0] is String or not descriptor[1] is int:
		return null
	var index: int = descriptor[1]
	match descriptor[0]:
		"guide":
			return guides[u.team] if index == 0 else null
		"seal":
			return seals[u.team].get(index)
		"crown":
			return monarchs[1 - u.team] if index == 0 and monarchs.size() > 1 else null
		"resource":
			if economy != null and index >= 0 and index < economy.nodes.size():
				return economy.nodes[index]
	return null


func pointer_reach(u, selected) -> float:
	var descriptor := pointer_descriptor(u, selected)
	if descriptor.is_empty():
		return 0.0
	match descriptor[0]:
		"guide": return Guide.TALK_RANGE - 0.1
		"seal": return Stats.SEAL_REACH - 0.1
		"crown": return Unit.PICKUP_RANGE - 0.1
		"resource": return float(Stats.ECONOMY.reach) - 0.1
	return 0.0


func try_pointer_interact(u, selected) -> bool:
	if u.dead or u.downed or u.carrying != null or pointer_descriptor(u, selected).is_empty():
		return false
	var offset: Vector3 = selected.global_position - u.global_position
	if absf(offset.y) > 0.6 or Vector2(offset.x, offset.z).length() > pointer_reach(u, selected):
		return false
	if economy != null and selected in economy.nodes:
		if selected.in_reach(u):
			economy.start_work(u, selected)
			return true
		return false
	try_interact(u, selected)
	return true


func try_interact(u, selected = null) -> void:
	if u.dead or u.downed:
		return
	# Every press reaches out; the result below answers it with a pop
	# (SkillFx.grab_hit) or a whiff (SkillFx.grab_miss). Looks only.
	SkillFx.grab(u)
	if u.carrying and selected == null:
		drop_monarch(u)
		return
	if u.is_player and guides[u.team] and guides[u.team].in_reach(u) and (selected == null or selected == guides[u.team]):
		if u == player:
			guide_toggle()
		SkillFx.grab_hit(u, guides[u.team].global_position + Vector3(0, 1.6, 0), Color(0.6, 1.0, 0.6))
		return
	if selected == null and economy and economy.try_interact(u):
		return   # gathering, hat machine upgrades, door repairs, turret pads
	for role in seals[u.team]:
		var seal = seals[u.team][role]
		if seal.in_reach(u) and (selected == null or selected == seal):
			if u.role == role:
				if selected != null and economy != null and u == player and not seal.locked and economy._training_listed(u):
					economy.training_open = true
					sfx.ui("ui_open", -6.0)
					return
				toast("You already carry the %s's seal" % seal.class_title(), Color(1.0, 0.8, 0.5))
				SkillFx.grab_miss(u)
			else:
				seal.take(u)
				SkillFx.grab_hit(u, seal.global_position + Vector3(0, 1.2, 0))
			return
	if prep_left > 0.0 and selected == null:
		# The fortify phase: F raises a barricade.
		if plant_barricade(u):
			SkillFx.grab_hit(u, SkillFx.grab_point(u), Color(0.85, 0.65, 0.4))
		else:
			SkillFx.grab_miss(u)
		return
	var m = monarchs[1 - u.team]
	if selected != null and (selected != m or prep_left > 0.0 or u.carrying != null):
		return
	if m.state != Monarch.State.CARRIED and _flat_dist(u.global_position, m.global_position) < Unit.PICKUP_RANGE:
		if m.state == Monarch.State.HOME and vaults[1 - u.team].is_locked():
			if u.is_player:
				toast("The Crown Vault is locked: break the lock first", Color(1.0, 0.8, 0.5))
			SkillFx.grab_miss(u)
			return
		SkillFx.grab_hit(u, m.global_position + Vector3(0, 1.0, 0), Color(1.0, 0.85, 0.3), true)
		m.pick_up(u)
		u.carrying = m
		u.gain_xp(Stats.XP_GRAB, "crown")
		stolen_timer = 3.5
		crown_event_note("taken", u.team)
		sfx.play("crown_grab", u.global_position)
		if u.team != player_team:
			sfx.ui("stolen", -4.0)
		# The crown ribbon (hud._draw_crown_event) is the only on-screen notice;
		# the centre caption repeated it (Faisal 09:26 2026-10-09). The chat log
		# keeps a line.
		chat_system("CROWN STOLEN! The %s has been taken by the %s!" % [m.title, Stats.FACTIONS[u.team].name])
		spawn_pillar(u.global_position, Color(1.0, 0.85, 0.3), 7.0, 1.2)
		spawn_flash(u.global_position + Vector3(0, 1.5, 0), Color(1.0, 0.85, 0.3), 4.0, 0.5)
		shake_at(u.global_position, 0.5)
		rumble(u, 0.4, 0.5, 0.25)
		chat_system("%s grabbed the %s!" % [u.display_name, m.title])
		_banter(1 - u.team, "ours_taken")
		_banter(u.team, "carrying", u)
		return
	SkillFx.grab_miss(u)


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
	if vmap and not vmap.walkable(pos, 0.5):
		return Vector3.INF  # not out over the lava
	if lmap and not lmap.walkable(pos, 0.5):
		return Vector3.INF  # not up on the ridges or in the trees
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
	var nid := _net_spawn_begin("turret", [team, pos, builder, opts])
	var t = Turret.new()
	add_child(t)
	t.setup(self, team, pos, builder, opts)
	turrets.append(t)
	turrets_built[team] += 1
	spawn_splash(pos + Vector3(0, 0.6, 0), Color(0.8, 0.7, 0.5), 16, 3.0, 0.6)
	spawn_ring(pos, 1.3, Stats.FACTIONS[team].color, 0.5)
	sfx.play("turret_place", pos, 0.0)
	_net_spawn_end(t, nid)
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
	if net:
		net.rec("game", "net_shot", [team, from, dir, s, color, true])
		net.mute += 1
	var shot = Projectile.new()
	shot.owner_unit = owner_unit
	shot.from_turret = true
	add_child(shot)
	shot.setup(self, team, from - Vector3(0, Projectile.FLIGHT_HEIGHT, 0), dir, s, color)
	if net:
		net.mute -= 1


func drop_monarch(u) -> void:
	var m = u.carrying
	if m == null:
		return
	u.carrying = null
	m.drop_at(u.global_position)
	sfx.play("crown_drop", u.global_position)
	crown_event_note("dropped", u.team)


func crown_event_note(kind: String, team: int) -> void:
	## Raise the crown ribbon (hud._draw_crown_event) for everyone but the
	## unit it happened to: "taken" when a crown is picked up, "dropped" when
	## its carrier lets it go or falls.
	if net:
		net.rec("game", "crown_event_note", [kind, team])
	crown_event = kind
	crown_event_team = team
	crown_event_timer = 3.6
	if net_client and kind == "taken":
		stolen_timer = 3.5


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
			var new_hat: bool = u.role == role and economy != null and economy.bot_wants_new_hat(u)   # an upgraded machine's hat
			if (u.role != role or new_hat) and _flat_dist(u.global_position, stations[u.team][role]) < STATION_RADIUS:
				u.set_role(role)
				sfx.play("station", u.global_position)
				if u == player:
					chat_system("You are now a %s." % u.role_name())   # the class banner says it on screen
				elif u.remote_peer > 0:
					announce("You are now a %s." % u.role_name(), u)


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
	var spots: Array = vmap.blessing_spots() if vmap else (lmap.blessing_spots() if lmap else BLESSING_SPOTS)
	var spot: Vector3 = spots[randi() % spots.size()]
	var kinds: Array = Stats.BLESSING_KINDS.keys()
	spawn_blessing(spot, kinds[randi() % kinds.size()])


func spawn_blessing(spot: Vector3, kind: String) -> Node3D:
	var nid := _net_spawn_begin("blessing", [spot, kind])
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
		where = "on the %s' side" % (Stats.FACTIONS[0].name if spot.x < 0.0 else Stats.FACTIONS[1].name)
	announce("A Blessing of %s has appeared %s!" % [kind, where])
	_net_spawn_end(b, nid)
	return b


func bot_tuning() -> Dictionary:
	return Stats.BOT_TUNING[bot_difficulty]


func announce_veteran(u, tier: int) -> void:
	sfx.ui("horn", -6.0, 0.9 if tier == 1 else 0.75)
	var side_name: String = Stats.FACTIONS[u.team].name
	if tier == 2:
		announce("%s of the %s is an ELITE VETERAN: %d kills without dying! Bounty on their head, location revealed." % [u.display_name, side_name, u.streak])
		chat_system("Bounty: %s (%s) is an Elite Veteran. Bring them down for a team reward!" % [u.display_name, side_name])
	else:
		announce("%s of the %s is a Veteran: %d kills without dying." % [u.display_name, side_name, u.streak])


func bounty_claimed(killer, victim) -> void:
	sfx.ui("horn", -2.0, 1.2)
	## An Elite Veteran fell: the killer's whole team is blessed and the killer paid.
	announce("BOUNTY CLAIMED! %s slew the Elite Veteran %s: the %s gain %s!" % [killer.display_name, victim.display_name, Stats.FACTIONS[killer.team].name, Stats.BOUNTY_BUFF])
	chat_system("%s claimed the bounty on %s (+%d XP, %s for the team)." % [killer.display_name, victim.display_name, Stats.BOUNTY_XP, Stats.BOUNTY_BUFF])
	killer.gain_xp(Stats.BOUNTY_XP, "takedowns")
	spawn_pillar(victim.global_position, Color(1.0, 0.85, 0.3), 9.0, 1.6)
	spawn_ring(victim.global_position, 5.0, Color(1.0, 0.85, 0.3), 1.0)
	for u in units:
		if u.team == killer.team and not u.dead:
			u.apply_blessing(Stats.BOUNTY_BUFF)


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
	# The HUD's death screen (hud._draw_death_screen) carries the countdown
	# now; the plain label stays off so the two do not stack.
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


func cellar_floor(team: int) -> float:
	## The spawn courtyard's floor height. The Wildwood Elves' courtyard is an
	## open garden at ground level (Faisal's 2026-10-09 courtyard brief); the
	## Humans' and both Ember Pass courtyards are still sunken cellars.
	return 0.0 if team == 0 and vmap == null else CELLAR_Y


func _in_cellar(team: int, p: Vector3) -> bool:
	var side := -1.0 if team == 0 else 1.0
	var bx := side * (CASTLE_X + CASTLE_DEPTH)
	var depth: float = (p.x - bx) * side
	return depth > -0.8 and depth < CELLAR_DEPTH + 1.0 and absf(p.z) < CELLAR_HALF_Z + 0.5 and p.y < cellar_floor(team) + 2.0


func cellar_stairs(team: int) -> Array:
	## [bottom, top] of the stairs from the cellar up into the keep.
	var side := -1.0 if team == 0 else 1.0
	var bx := side * (CASTLE_X + CASTLE_DEPTH)
	return [Vector3(bx + side * 8.6, cellar_floor(team), 0), Vector3(bx - side * 1.6, 0.0, 0)]


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


func toast(text: String, color: Color = Color.WHITE, to = null) -> void:
	## A short notice: queued and shown one at a time as a small scroll under
	## the clock (hud.gd _draw_toasts), never stacked or under a big banner.
	## Toasts are personal: online, only `to`'s player sees one sent to a joiner.
	if to != null and not to.is_player:
		if net:
			net.rec("game", "toast", [text, color], to)
		return
	for t in toasts:
		if t.text == text:
			return   # already showing or waiting
	toasts.append({"text": text, "color": color, "time": Time.get_ticks_msec() / 1000.0, "shown": 0.0})
	while toasts.size() > 3:
		toasts.remove_at(1)   # keep the one on screen, drop the oldest waiting


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
		if u.team == team and not u.dead and not u.is_player and u.remote_peer == 0:
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
	# Ember Pass: win the Fire Objective, then keep a guard on it.
	if vmap and cmd != "defend":
		_assign_nearest(bots, vmap.FIRE_POS, vmap.bots_wanted(team), "fire")
	if economy:
		economy.plan_gatherers(team, bots)


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
	if net:
		net.leave()
	_reload_scene()


func apply_control_layout() -> void:
	## The Controls tab's layout pick. Auto: the touch layout appears only on
	## a phone or tablet, or after a real finger touches the screen, and goes
	## away when the mouse or keyboard is used (touch.gd). The others pin it.
	pad_active = control_layout == "controller" or (pad_active and control_layout == "auto")
	if touch == null:
		return
	if control_layout == "touch":
		touch.set_active(true)
	elif control_layout != "auto":
		touch.set_active(false)
	elif not touch.active and touch.mobile_device():
		touch.set_active(true)


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
		"move_aim", "move_screen":
			move_mode = "screen"
		"pc_click", "pc_wasd":
			pc_movement = key.trim_prefix("pc_")
		"combine_move_attack": combine_move_attack = not combine_move_attack
		"wheel_zoom": wheel_zoom = not wheel_zoom
		"layout_auto", "layout_keyboard", "layout_controller", "layout_touch":
			control_layout = key.trim_prefix("layout_")
			apply_control_layout()
		"pad_style_prev": pad_style = {"auto": "ps", "ps": "xbox", "xbox": "auto"}[pad_style]
		"split_vertical", "split_horizontal": set_split_layout(key.trim_prefix("split_"))
		"test_sound":
			sfx.ui("ui_open", 0.0)   # (there is no ui_confirm clip: the button was silent, AUD-01)
			return
		"gfx":
			gfx_quality = (gfx_quality + 1) % GFX_NAMES.size()
			gfx_picked = true
			apply_graphics()
		"gfx_0", "gfx_1", "gfx_2", "gfx_3":
			gfx_quality = int(key.trim_prefix("gfx_"))
			gfx_picked = true
			apply_graphics()
		"fullscreen":
			# Display: Windowed -> Borderless -> Fullscreen (exclusive) -> Windowed.
			window_mode = WINDOW_MODES[(WINDOW_MODES.find(window_mode) + 1) % WINDOW_MODES.size()]
			fullscreen = window_mode != "windowed"
			apply_graphics()
		"vsync":
			vsync_on = not vsync_on
			apply_graphics()
		"render_scale":
			render_scale = RENDER_SCALES[(RENDER_SCALES.find(render_scale) + 1) % RENDER_SCALES.size()]
			apply_graphics()
		"fps_cap":
			fps_cap = FPS_CAPS[(FPS_CAPS.find(fps_cap) + 1) % FPS_CAPS.size()]
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
		return {"pos": thrones[player_team], "step": 2, "label": "Carry it to your throne"}
	if mine.state == Monarch.State.CARRIED:
		return {"pos": mine.carrier.global_position, "step": -1, "label": "Stop the thief carrying our crown"}
	if mine.state == Monarch.State.DROPPED:
		return {"pos": mine.global_position, "step": -1, "label": "Bring our crown home"}
	if theirs.state == Monarch.State.CARRIED:
		return {"pos": theirs.carrier.global_position, "step": 2, "label": "Escort our carrier"}
	if theirs.state == Monarch.State.DROPPED:
		return {"pos": theirs.global_position, "step": 2, "label": "Grab their crown"}
	var gate = gates[1 - player_team]
	if not gate.broken and not _inside_castle(1 - player_team, player.global_position):
		return {"pos": gate.global_position, "step": 0, "label": "Break the enemy castle door"}
	if vaults[1 - player_team].is_locked():
		return {"pos": theirs.global_position, "step": 1, "label": "Break the lock on their Crown Vault"}
	return {"pos": theirs.global_position, "step": 2, "label": "Grab their crown"}


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
		if u.team != team and not u.dead and not u.downed and _flat_dist(u.global_position, pos) < radius:
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
		if u.team == team and not u.dead and not u.downed and _flat_dist(u.global_position, pos) < radius:
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
				return Vector3(st[0].x + side * 0.3, cellar_floor(c), from.z)  # walk straight back to the foot first
			# Up by the hats, ahead of the foot: the low walls flanking the
			# stairs end short of the foot, so get out past their ends before
			# stepping across, or the end post catches the diagonal.
			return Vector3(st[0].x + side * 0.3, cellar_floor(c), signf(from.z) * 3.2)
		# Crossing the cellar from one row of hats to the other: the low walls
		# along the stairs are in the way, so go round behind their foot first.
		if _in_cellar(c, from) and _in_cellar(c, to) and from.z * to.z < 0.0 and absf(from.z) > 1.0 and absf(to.z) > 1.0:
			var st := cellar_stairs(c)
			var side := -1.0 if c == 0 else 1.0
			if (from.x - st[0].x) * side < -1.2:
				return Vector3(st[0].x + side * 0.3, cellar_floor(c), from.z)
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
				return Vector3(st[0].x + side * 0.3, cellar_floor(c), signf(to.z) * 3.2)
	if to.y > 2.0 and from.y < WALK_Y - 0.2:
		var c := 0 if to.x < 0.0 else 1
		var ramp: Dictionary = ramps[c][0] if to.z < 0.0 else ramps[c][1]
		if from.y < 0.5 and _flat_dist(from, ramp.bottom) > 1.2:
			target = ramp.bottom
		else:
			return ramp.top
	# Ember Pass: over the plazas and bridges to the leg that matters; the
	# castle doors and keeps below still apply.
	if vmap:
		target = vmap.route(from, target)
	# Stonekeep Fortress / Twilight Grove: over their own plazas and lanes.
	if lmap:
		target = lmap.route(from, target)
	# The shrine plinth is solid: a goal on it (or right beside it) means
	# standing at its foot, on the side we come from.
	if vmap == null and lmap == null and _flat_dist(target, Vector3.ZERO) < 1.6:
		var away := Vector3(from.x - target.x, 0, from.z - target.z)
		if away.length() < 0.1:
			away = Vector3(0, 0, 1)
		target = target + away.normalized() * 1.8
		target.y = 0.5
	# Up on the shrine island and leaving it: the steps are at z 0 on each
	# side (stone rims close the north and south edges), and the plinth sits
	# in the middle, so go round it on the side we are already on first.
	var on_island: bool = vmap == null and lmap == null and from.y > 0.3 and _flat_dist(from, Vector3.ZERO) < ISLAND_R + 0.3
	if on_island and _flat_dist(target, Vector3.ZERO) > ISLAND_R + 0.3:
		var exit_side := 1.0 if target.x > 0.0 else -1.0
		if from.x * exit_side < -1.2 and absf(from.z) < 1.6:
			return Vector3(0.0, 0.5, (1.0 if from.z >= 0.0 else -1.0) * 2.0)
		if from.x * exit_side < 1.2 and absf(from.z) < 1.6:
			return Vector3(exit_side * 2.4, 0.5, (1.0 if from.z >= 0.0 else -1.0) * 1.8)
		return Vector3(exit_side * (ISLAND_R + 3.6), 0.0, 0.0)
	# The river: cross at the bridge closest to the way, entering it square on.
	if vmap == null and lmap == null and ((from.x < -RIVER_HALF and target.x > RIVER_HALF) or (from.x > RIVER_HALF and target.x < -RIVER_HALF)):
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
	if net:
		net.rec("game", "net_shot", [u.team, u.global_position, dir, s, color, false])
		net.mute += 1
	var shot = Projectile.new()
	shot.owner_unit = u
	add_child(shot)
	shot.setup(self, u.team, u.global_position, dir, s, color)
	if net:
		net.mute -= 1


func net_shot(team: int, from: Vector3, dir: Vector3, s: Dictionary, color: Color, turret: bool) -> void:
	## Client: the host's arrow or spell, flying for the look of it (the
	## host decides what it hits; its impact arrives as effects).
	var shot = Projectile.new()
	shot.inert = true
	shot.from_turret = turret
	add_child(shot)
	shot.setup(self, team, from - (Vector3(0, Projectile.FLIGHT_HEIGHT, 0) if turret else Vector3.ZERO), dir, s, color)


# Turrets, traps and blessings the host creates in a match get a net id; the
# joiners build the same thing from the same arguments and drop it when it
# leaves the host's snapshot. (Planted barricades are matched by list index.)
var net_next_id := 1
var net_ents := {}   # net id -> node
var _net_pending: Array = []


func _net_spawn_begin(kind: String, args: Array) -> int:
	if not net or not net.is_host():
		return 0
	var nid := net_next_id
	net_next_id += 1
	net.rec("game", "net_spawn", [kind, nid, args])
	net.mute += 1   # its own effects are made again on the joiners' side
	_net_pending = [kind, args]
	return nid


func _net_spawn_end(node: Node, nid: int) -> void:
	if nid <= 0:
		return
	net.mute -= 1
	node.set_meta("nid", nid)
	node.set_meta("nkind", _net_pending[0])
	node.set_meta("nspawn", _net_pending[1])
	net_ents[nid] = node


func net_spawn(kind: String, nid: int, args: Array) -> void:
	## Client: build what the host built.
	if nid > 0 and net_ents.has(nid):
		return
	var node: Node = null
	match kind:
		"turret": node = spawn_turret(args[0], args[1], args[2], args[3])
		"trap": node = place_trap(args[0], args[1], args[2])
		"blessing": node = spawn_blessing(args[0], args[1])
		"barricade":
			_add_barricade(args[0], args[1], args[2], args[3])
			return
	if node and nid > 0:
		node.set_meta("nid", nid)
		net_ents[nid] = node


func net_entity_list() -> Array:
	## Host: what a joiner arriving mid-match must build: [kind, nid, args].
	var out: Array = []
	for nid in net_ents:
		var n = net_ents[nid]
		if is_instance_valid(n) and n.has_meta("nkind"):
			out.append([n.get_meta("nkind"), nid, n.get_meta("nspawn")])
	return out


func net_kill_banner(b: Dictionary) -> void:
	## Client: our KILL! card.
	if player:
		b["time"] = Time.get_ticks_msec() / 1000.0
		player.kill_banner = b
		sfx.ui("rank_up", -2.0, 1.15)


func net_look(u, role: int, variant_name: String, rank: int, custom: Dictionary) -> void:
	## Client: how a fighter looks (class variant, gear rank, a player's
	## hero colours). Kept on the unit so a class change can put it back.
	if u == null:
		return
	u.net_look = {"role": role, "variant": variant_name, "rank": rank, "custom": custom}
	u.net_wear_look()


func net_flash(u) -> void:
	## Client: a unit took a hit (the red flash).
	if u:
		u.flash_timer = u.FLASH_TIME


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
	place_trap(u.team, Vector3(to.x, u.global_position.y, to.z), a)


func place_trap(team: int, pos: Vector3, a: Dictionary) -> Node3D:
	var nid := _net_spawn_begin("trap", [team, pos, a])
	var trap = Trap.new()
	add_child(trap)
	trap.setup(self, team, pos, a)
	_net_spawn_end(trap, nid)
	return trap


func spawn_burst(where: Vector3, radius: float, color: Color) -> void:
	## A soft flash of colour on the ground (scripts/fx.gd).
	Fx.of(self).ground_glow(where, radius, color, 0.35)


func spawn_splash(where: Vector3, color: Color, count: int, speed: float, life: float, rise: bool = false) -> void:
	## A one-shot spray of little bits: sparks, splinters, motes, smoke.
	## Drawn by scripts/fx.gd: rising sprays are soft glowing motes (grey
	## ones are smoke), the rest tumbling chips.
	var fx: Node = Fx.of(self)
	if rise:
		var grey := color.s < 0.2 and color.v < 0.7
		fx.burst(where, color, count if not grey else maxi(count / 3, 4), speed, life, fx.STYLE_SMOKE if grey else fx.STYLE_MOTE, Vector3.UP, 50.0)
	else:
		fx.burst(where, color, count, speed, life, fx.STYLE_SHARD)


func spawn_popup(where: Vector3, text: String, color: Color) -> void:
	## A number or word that floats up and fades, like damage numbers.
	if net:
		net.rec("game", "spawn_popup", [where, text, color])
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
	## A ring that races outward and fades: shockwaves, heals, blessings.
	Fx.of(self).ground_ring(where, radius, color, duration)


func spawn_pillar(where: Vector3, color: Color, height: float = 4.0, duration: float = 0.9) -> void:
	## A column of light that narrows and fades: level ups, rank ups, captures.
	if net:
		net.rec("game", "spawn_pillar", [where, color, height, duration])
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
	if Fx.of(self).daylight():
		# Day maps: a pale additive column vanished against cream stone;
		# the level-up, revive and blessing columns are a normally blended
		# column of their saturated colour (visual pass 2026-10-30).
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
		mat.albedo_color = Color(Fx.vivid(color).lightened(0.1), 0.36)
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
	if net:
		net.rec("game", "spawn_flash", [where, color, energy, duration])
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
	Fx.of(self).slash(u.global_position, aim, Color(1, 1, 1))


func announce(text: String, to = null) -> void:
	## News for the notice scroll, also logged in the chat. Online,
	## `to` (a unit) makes it personal: only that unit's player sees it;
	## without it every joiner sees it too.
	if net and net.online():
		net.rec("game", "announce", [text], to)
		if to != null and not to.is_player:
			return   # a joiner's own message: shown on their screen only
		net.depth += 1
	_announce_here(text)
	if net and net.online():
		net.depth -= 1


func _announce_here(text: String) -> void:
	## News goes to the notice scroll and the chat log (the old floating
	## centre line overlapped the banners: Faisal 2026-10-10 08:35). The
	## FORTIFY! call-out repeats the objective banner word for word, so it
	## stays in the chat log only.
	if not text.begins_with("FORTIFY!"):
		toast(text, Color(1.0, 0.85, 0.4))
	chat_system(text)


func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# --- Loading screens ---------------------------------------------------------

const LOADING_SCREENS := ["res://assets/ui/loading_1.jpg", "res://assets/ui/loading_2.jpg"]
var loading_layer: CanvasLayer
var loading_label: Label
var loading_tween: Tween   # its hold-then-fade; _warm_up_world holds it while it sweeps
var _stream_world := false
var _world_frame_deadline := 0
var _world_slice_start := 0   # when the running behind-the-title slice began
var world_slice_usec := PackedInt32Array()   # each behind-the-title slice's CPU time (tools/title_stutter_probe.gd)
# claude-faisal3 2026-10-29 (PERF-05): the title no longer waits for the
# match world. It is built behind the menus in slices of WORLD_SLICE_USEC a
# frame; a match started before it is done waits under the loading art.
signal world_finished
signal _world_slice   # each frame while the world builds behind the menus
const WORLD_SLICE_USEC := 10000   # the first slice; then _world_slice_budget()
# claude-faisal/stutter 2026-10-30: a fixed 10 ms slice plus the menus and
# drawing did not fit a 60 fps frame on an integrated GPU's laptop (the
# title ran 40-56 fps while the world built). Each slice now takes what the
# last frames left of WORLD_FRAME_CPU_USEC, between the two limits below
# (with 8 ms of extra menu load the title held 60-65 fps instead of 29-48).
const WORLD_FRAME_CPU_USEC := 14500   # a title frame's CPU in all: 60 fps (16.7 ms) with room
const WORLD_SLICE_MIN_USEC := 3000
const WORLD_SLICE_MAX_USEC := 12000
var _world_rest_usec := 4000.0   # running average: a frame's CPU besides the slice (menus, drawing)
var _world_main_usec := 0   # last frame's main-thread CPU, from the draw before it to its own
var _world_post_draw := 0
var world_ready := true
var _world_behind := false
var _match_waiting := false
var _world_rush := false   # finish_world_now: no more slices, build the rest at once
var _world_batched := false   # the world built behind the title is batched there, not at match start
var _world_held := []   # [node, its process mode]: world pieces kept still until the world is whole
var _loading_viewport: Viewport
var _loading_previous_disable_3d := false


func _suspend_loading_3d() -> void:
	# The opaque CanvasLayer still draws. Do not render/compile the unbatched
	# world as construction yields; the actual warm-ups run after restoration.
	if is_instance_valid(_loading_viewport):
		return
	_loading_viewport = get_viewport()
	if is_instance_valid(_loading_viewport):
		_loading_previous_disable_3d = _loading_viewport.disable_3d
		_loading_viewport.disable_3d = true


func _restore_loading_3d() -> void:
	if is_instance_valid(_loading_viewport):
		_loading_viewport.disable_3d = _loading_previous_disable_3d
	_loading_viewport = null


func _world_build_frame() -> void:
	if _world_behind:
		if not _world_rush and Time.get_ticks_usec() >= _world_frame_deadline:
			# Menus built between slices (the hero, store previews) keep
			# their own look. (Nothing may leave this scene with the world
			# half built: finish_world_now.)
			world_style = false
			world_slice_usec.append(Time.get_ticks_usec() - _world_slice_start)
			await _world_slice
			world_style = true
			_world_slice_start = Time.get_ticks_usec()
			_world_frame_deadline = _world_slice_start + (32000 if _match_waiting else _world_slice_budget())
			_preload_scenes_when_ready()
		return
	# All scene-tree mutations stay on the main thread. A completed chunk
	# yields real frames, rather than dropping OS input in a blocking build.
	if _stream_world and Time.get_ticks_usec() >= _world_frame_deadline:
		if is_instance_valid(loading_label):
			loading_label.text = "LOADING" + ".".repeat(1 + (Time.get_ticks_msec() / 300) % 3)
		await get_tree().process_frame
		# A 32 ms work budget keeps loading responsive without spending a
		# full extra rendered frame after each tiny construction operation.
		_world_frame_deadline = Time.get_ticks_usec() + 32000


func _world_slice_budget() -> int:
	## How long this frame's slice may run: the frame's CPU target less what
	## the rest of the last frames cost (their main thread outside the slice,
	## and drawing's CPU; the wait for the screen is not counted).
	if _world_main_usec > 0 and not world_slice_usec.is_empty():
		var vp := get_viewport().get_viewport_rid()
		var draw_usec := RenderingServer.viewport_get_measured_render_time_cpu(vp) * 1000.0
		var rest := clampf(_world_main_usec - world_slice_usec[world_slice_usec.size() - 1] + draw_usec, 0.0, 12000.0)
		_world_rest_usec = lerpf(_world_rest_usec, rest, 0.15)
		_world_main_usec = 0
	return clampi(WORLD_FRAME_CPU_USEC - int(_world_rest_usec), WORLD_SLICE_MIN_USEC, WORLD_SLICE_MAX_USEC)


func _world_pre_draw() -> void:
	## (RenderingServer.frame_pre_draw while the world builds.)
	if _world_post_draw > 0:
		_world_main_usec = Time.get_ticks_usec() - _world_post_draw


func _world_after_draw() -> void:
	_world_post_draw = Time.get_ticks_usec()


func _world_measure(on: bool) -> void:
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), on)
	if on and not RenderingServer.frame_pre_draw.is_connected(_world_pre_draw):
		RenderingServer.frame_pre_draw.connect(_world_pre_draw)
		RenderingServer.frame_post_draw.connect(_world_after_draw)
	elif not on and RenderingServer.frame_pre_draw.is_connected(_world_pre_draw):
		RenderingServer.frame_pre_draw.disconnect(_world_pre_draw)
		RenderingServer.frame_post_draw.disconnect(_world_after_draw)


var _alive_ms := 0   # last time _keep_window_alive answered the OS
var _alive_frame := -1   # the frame _keep_window_alive last saw, and when it began
var _alive_frame_start := 0


func _show_loading(hold: float) -> void:
	## Faisal's key art (2026-10-07) over everything while the world builds
	## or a match starts: one of the two, picked at random, then a fade.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot") or arg == "--demo" or arg == "--audit":
			return   # screenshots and headless tests see the game itself
	if loading_tween and loading_tween.is_valid():
		loading_tween.kill()   # a replaced layer must not keep a fade callback
	if is_instance_valid(loading_layer):   # the last one frees itself after its fade
		loading_layer.queue_free()
	loading_layer = CanvasLayer.new()
	loading_layer.layer = 100
	add_child(loading_layer)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.07, 0.05)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	loading_layer.add_child(bg)
	var art := TextureRect.new()
	art.texture = load(LOADING_SCREENS[randi() % LOADING_SCREENS.size()])
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.add_child(art)
	var label := Label.new()
	label.text = "LOADING..."
	loading_label = label
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.65))
	label.add_theme_color_override("font_outline_color", Color(0.12, 0.08, 0.04))
	label.add_theme_constant_override("outline_size", 10)
	label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	label.position = Vector2(-220, -64)
	bg.add_child(label)
	var layer := loading_layer
	var tw := create_tween()
	loading_tween = tw
	tw.tween_interval(hold)
	tw.tween_property(bg, "modulate:a", 0.0, 0.6)
	tw.tween_callback(func() -> void:
		if is_instance_valid(layer):
			layer.queue_free())


func _fade_loading_now() -> void:
	## A build or warm-up has already held the loading art for seconds: fade
	## it now. Resuming the paused tween ran its whole minimum hold (1-1.2 s)
	## after everything was ready, then a 0.6 s fade: 1.6-1.8 s of waiting on
	## a finished title or match (claude-faisal3 2026-10-29).
	if not is_instance_valid(loading_layer):
		return
	if loading_tween and loading_tween.is_valid():
		loading_tween.kill()
	var layer := loading_layer
	var bg := layer.get_child(0) as CanvasItem
	var tw := create_tween()
	loading_tween = tw
	if bg:
		tw.tween_property(bg, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func() -> void:
		if is_instance_valid(layer):
			layer.queue_free())


# --- Match setup -----------------------------------------------------------

func _start_match(team: int) -> void:
	if not world_ready:
		# Started before the world finished building behind the menus: the
		# loading art covers the rest of the build, then the match starts.
		if _match_waiting:
			return
		_match_waiting = true
		_show_loading(1.0)
		if loading_tween and loading_tween.is_valid():
			loading_tween.pause()
		_suspend_loading_3d()   # only the art draws while the rest is built
		await world_finished
		_restore_loading_3d()
		_match_waiting = false
		if playing:
			return
	_show_loading(1.0)
	# The match is built within this frame (seconds, with the batching): draw
	# the loading art now, or the title just clicked sits frozen until it is
	# all done (claude-faisal3 2026-10-29, PERF-04; tools/match_start_art_test.gd).
	if is_instance_valid(loading_layer) and DisplayServer.get_name() != "headless":
		RenderingServer.force_draw()
	if net and net.online():
		# Building the match can take long on a slow or busy machine: the
		# online links wait for it, each until input flows on it again.
		net.long_timeouts()
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--debug-slow-build="):   # testing: a slow machine's match start (online timeouts)
				OS.delay_msec(int(float(arg.trim_prefix("--debug-slow-build=")) * 1000.0))
	player_team = team
	if net and net.online():
		couch_players = 1   # couch and online together come later (docs/online-plan.md, N4)
	for m in monarchs:
		# Only our own crown is labelled (Faisal 2026-10-07: no "steal" text).
		m.label.text = ""   # no crown captions (Faisal 2026-10-07 21:14)
	winner_team = -1
	banner.visible = false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--couch="):
			couch_players = clampi(int(arg.trim_prefix("--couch=")), 1, COUCH_MAX)  # testing: split-screen renders
		if arg.begins_with("--couch-mode="):
			couch_mode = arg.trim_prefix("--couch-mode=")
		if arg.begins_with("--split="):
			split_layout = "horizontal" if arg.trim_prefix("--split=") == "horizontal" else "vertical"  # testing: --split=vertical|horizontal
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--team-size="):
			team_size = clampi(int(arg.trim_prefix("--team-size=")), 1, TEST_TEAM_MAX)  # testing only (batches): 3v3 / 5v5; the live game stays TEAM_SIZE
	if menu_stage:
		# Leave the menus: their hall and models go, the match camera takes over.
		# Freed now, not queued: a camera left in the viewport would become
		# current again and render the whole world behind the split panes.
		menu_stage.free()
		menu_stage = null
		if main_menu:
			main_menu.stage = null
		camera.make_current()
	# The match world's light grade (style_profile.gd), now the menus' own
	# light is gone.
	style_live = true
	# Anything built from now on (economy drops, turrets, barricades) is part
	# of the match world: it takes the style textures, which are already
	# loaded, instead of loading the menu originals from disk mid-fight (a
	# 40 ms hitch, and those props came out in the wrong texture set).
	world_style = true
	_apply_map_variant()
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
		# Strictly team_size a side (4v4): local players take seats, bots
		# fill the rest. More locals on one side than seats can't happen
		# (COUCH_MAX is 4), but never field more than team_size.
		var count: int = team_size
		for i in count:
			var u = Unit.new()
			add_child(u)
			var spawn := Vector3(side * (CASTLE_X + CASTLE_DEPTH + 14.5), cellar_floor(t), -4.0 + i * 2.0)
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
				u._apply_side_colors()   # couch colours need local_index, set just now
				u._refresh_overhead()
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
	match_played = 0.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--debug-time="):
			time_left = float(arg.trim_prefix("--debug-time="))  # testing: a short clock
		if arg == "--no-prep":
			prep_left = -1.0
	barricades_left = [Stats.BARRICADE_TEAM, Stats.BARRICADE_TEAM]
	kill_feed = []
	# Merge the scenery that never moves into a few hundred meshes
	# (scripts/static_batch.gd): ~9,800 draw calls a frame became ~1,500.
	if not "--no-batch" in OS.get_cmdline_user_args() and not _world_batched:
		await StaticBatch.run(self)   # (never waits here, the match builds in this frame: only behind the title does it slice)
		await StaticBatch.particles_to_gpu(self)
	_warm_up_world()   # (a coroutine: a few frames under the loading art)
	if prep_left >= 0.0:
		prep_left = Stats.PREP_TIME
		_build_barrier()
	else:
		prep_left = 0.0
	_warm_up_effects()
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
	if net and net.is_host():
		net.on_match_started()


func in_prep() -> bool:
	return prep_left > 0.0


func _build_barrier() -> void:
	## The fortify barrier: a wall of light down the middle of the field that
	## nothing crosses until the battle begins.
	barrier = Node3D.new()
	barrier.set_meta("no_batch", true)   # falls when the fight starts
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
	sfx.sting("match_start", "match_start")
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
	elif _in_cellar(team, u.global_position):
		why = "Not in the cellar"
	elif u.global_position.x * side < RIVER_HALF + 3.0:
		why = "Only on your own half" if lmap else "Only on your own side of the river"
	elif absf(u.global_position.z) < 3.0 and absf(u.global_position.x - _front_x(team)) < 9.0:
		why = "Not in the door lane"
	elif _inside_castle(team, u.global_position) or absf(u.global_position.x) > CASTLE_X - CASTLE_DEPTH - 1.6:
		why = "Only outside the walls"
	elif vmap and not vmap.walkable(u.global_position + u.facing * 1.6, 0.4):
		why = "Not over the lava"
	elif lmap and not lmap.walkable(u.global_position + u.facing * 1.6, 0.4):
		why = "No room to raise it here"
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
	if u.is_player or u.remote_peer > 0:
		announce("Barricade raised. %d kit%s left." % [barricades_left[team], "" if barricades_left[team] == 1 else "s"], u)
	return true


func _update_camera(delta: float) -> void:
	if player == null:
		return
	sfx.set_listener(player.global_position)
	shake_amount = move_toward(shake_amount, 0.0, delta * 1.6)
	var jolt := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * shake_amount * 0.35
	cam_kick = cam_kick.lerp(Vector3.ZERO, clampf(delta * 10.0, 0.0, 1.0))
	jolt += cam_kick
	if couch_active:
		# One camera a pane, each on its own player.
		for pane in panes:
			var u = pane.unit
			var t: Vector3 = (cam_lock if cam_lock != Vector3.INF and u == player else u.global_position) + CAMERA_OFFSET * cam_zoom * pane.zoom
			pane.cam_pos = pane.cam_pos.lerp(t, clampf(delta * 5.0, 0.0, 1.0))
			pane.cam.global_position = pane.cam_pos + jolt
		return
	var target: Vector3 = (cam_lock if cam_lock != Vector3.INF else player.global_position) + CAMERA_OFFSET * cam_zoom
	cam_pos = cam_pos.lerp(target, clampf(delta * 5.0, 0.0, 1.0))
	if cam_top > 0.0:
		var over: Vector3 = cam_lock if cam_lock != Vector3.INF else player.global_position
		camera.rotation_degrees = Vector3(-90, 0, 0)
		camera.far = maxf(camera.far, cam_top + 50.0)
		camera.global_position = Vector3(over.x, cam_top, over.z)
		if world_environment:
			world_environment.fog_enabled = false
			world_environment.volumetric_fog_enabled = false
		if cam_attrs:
			cam_attrs.dof_blur_far_enabled = false
		return
	camera.global_position = cam_pos + jolt


func mouse_for(u) -> Vector2:
	## The mouse in the viewport of the camera looking at u. In couch play
	## the mouse belongs to player 1 (keyboard and mouse) while the others use
	## pads: it is read from the whole window and mapped into player 1's pane,
	## held to its edges, so the cursor over another pane never aims there.
	if couch_active:
		for pane in panes:
			if pane.unit == u:
				var r: Rect2 = pane.rect
				if r.size.x <= 0.0 or r.size.y <= 0.0:
					break
				var local: Vector2 = (get_viewport().get_mouse_position() - r.position) / r.size
				local = local.clamp(Vector2.ZERO, Vector2.ONE)
				return local * Vector2(pane.view.size)
	return camera_for(u).get_viewport().get_mouse_position()


func camera_for(u) -> Camera3D:
	## The camera looking at this local player (their pane's in couch play).
	if couch_active:
		for pane in panes:
			if pane.unit == u:
				return pane.cam
	return camera


func menu_mouse() -> Vector2:
	## Where menu clicks land: the gamepad cursor while it is in use, else the mouse.
	if touch_tap.x >= 0.0:
		return touch_tap
	return cursor if cursor_shown else get_viewport().get_mouse_position()


func end_name_entry() -> void:
	## A pad player's name is done (DONE, Start, or B on an empty name). An
	## empty name becomes "Hero" so the first-run prompt doesn't return.
	name_editing = false
	hero_name = hero_name.strip_edges()
	if hero_name == "":
		hero_name = "Hero"
	_save_settings()
	swallow_frame = Engine.get_process_frames()
	confirm_block = true   # the same A press must not also click the button under the cursor


func in_menus() -> bool:
	## Whether a screen of buttons is up (title, pause menu, guide, end screen).
	return (not playing or menu_open or game_over or guide_open) and not rank_open and rebinding == "" and not chat_open \
		and (not name_editing or main_menu != null and main_menu.pad_keys_on())   # a pad names its hero on the letter pad


func _pad_nav() -> void:
	## Move the gamepad cursor: the D-pad (or a stick flick) jumps to the next
	## button in that direction, the stick held steers it freely, and the
	## Circle / B button backs out of the pause menu or the guide.
	if hud != null and rebinding != "" and menu_open:
		return   # waiting for a key: the cursor stays on the row, ready for the next one
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
	if pressed.y == 0.0 and pressed.x != 0.0 and _nudge_slider(pressed.x):
		nav_repeat = 0.4   # left / right on a volume slider turns it, like a console menu
	elif pressed != Vector2.ZERO:
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
	if Input.is_action_just_pressed("ui_back") and Engine.get_process_frames() != lobby_pad_frame and not name_editing \
			and Engine.get_process_frames() != swallow_frame:   # B on the letter pad rubs out a letter (or ends the name), not the screen
		if not playing and not menu_open and main_menu:
			main_menu.back()
		elif menu_open:
			menu_open = false
			get_tree().paused = false
			sfx.ui("ui_click", -4.0)
		elif guide_open:
			guide_close()


func _nudge_slider(dir: float) -> bool:
	## The pad cursor on a volume slider: a tenth of the way left or right.
	for sl in hud.volume_sliders:
		if sl[0].grow(6).has_point(cursor):
			var v := clampf(snappedf((sfx.sound_volume if sl[1] == "sound" else sfx.music_volume) + 0.1 * signf(dir), 0.1), 0.0, 1.0)
			if sl[1] == "sound":
				sfx.sound_volume = v
			else:
				sfx.music_volume = v
			sfx.apply_volumes()
			sfx.ui("ui_click", -4.0)
			_save_settings()
			# Keep the cursor on the bar, over the new value.
			cursor.x = sl[0].position.x + 2.0 + v * (sl[0].size.x - 4.0)
			return true
	return false


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


# --- Online play -------------------------------------------------------------

func net_free_slot() -> int:
	## Host: the unit index a joiner takes: a bot's slot, first on the other
	## side from the host, then alternating sides (versus by default).
	var counts := [0, 0]
	for u in units:
		if u.is_player or u.remote_peer > 0:
			counts[u.team] += 1
	var order: Array = [1 - player_team, player_team] if counts[1 - player_team] <= counts[player_team] else [player_team, 1 - player_team]
	for t in order:
		for i in team_size:
			var u = units[t * team_size + i]
			if not u.is_player and u.remote_peer == 0:
				return t * team_size + i
	return -1


func net_claim_unit(idx: int, peer_id: int, peer_name: String, custom: Dictionary = {}) -> void:
	## Host: a joiner takes over a bot. It keeps its place, hearts and class.
	var u = units[idx]
	u.remote_peer = peer_id
	u.net_input = {}
	u.net_seen = {}
	u.net_custom = custom
	u.redress()
	u.display_name = peer_name if peer_name != "" else "Player %d" % (idx + 1)
	u._refresh_overhead()
	chat_system("%s joined the %s." % [u.display_name, Stats.FACTIONS[u.team].name])


func net_release_unit(idx: int) -> void:
	## Host: a joiner left; a bot takes their unit back.
	if idx < 0 or idx >= units.size():
		return
	var u = units[idx]
	chat_system("%s left the game; a bot takes over." % u.display_name)
	u.remote_peer = 0
	u.net_input = {}
	u.display_name = Stats.BOT_NAMES[u.team][(idx % team_size) % Stats.BOT_NAMES[u.team].size()]
	u._refresh_overhead()


func net_start_client(start: Dictionary) -> void:
	## Client: the host gave us a slot; build the match around it.
	if playing:
		return
	if not world_ready:
		await world_finished
	net_slot = Vector2i(start.team, start.slot)
	if start.map != map_variant:
		map_variant = start.map
		_apply_map_variant()
	_start_match(start.team)
	var names: Array = start.names
	for i in mini(names.size(), units.size()):
		if units[i] != player:
			units[i].display_name = names[i]
			units[i]._refresh_overhead()
	net.pending_start = {}
	net.replay_early()


func net_build_snapshot() -> Dictionary:
	## Host: everything a client draws, 20 times a second.
	var us: Array = []
	for u in units:
		us.append([u.global_position, u.rotation.y, u.hearts, u.energy, u.dead, u.role, u.respawn_timer,
			u.level, u.kills, u.deaths, u.carrying != null, u.xp, u.points, u.display_name,
			u.downed, u.downed_timer, u.downed_total, u.revive_progress, u.being_revived()])
		# How it looks changes rarely: sent as an event when it does.
		if Engine.get_physics_frames() % 15 == 0:
			var look: Array = u.net_look_now()
			if look != u.net_look_sent:
				u.net_look_sent = look
				net.rec("game", "net_look", [u] + look)
	var ms: Array = []
	for m in monarchs:
		ms.append([m.state, m.global_position, m.rotation.y, units.find(m.carrier) if m.carrier else -1])
	var gs: Array = []
	for g in gates:
		gs.append([g.hp, g.broken])
	var vs: Array = []
	for v in vaults:
		vs.append([v.hp, v.open])
	var now := Time.get_ticks_msec() / 1000.0
	var feed: Array = []
	for k in kill_feed:
		var e: Dictionary = k.duplicate()
		e["age"] = now - float(k.time)
		e.erase("time")
		feed.append(e)
	var ents := {}
	for nid in net_ents.keys():
		var n = net_ents[nid]
		if not is_instance_valid(n) or n.is_queued_for_deletion():
			net_ents.erase(nid)
			continue
		ents[nid] = [n.get("hp"), n.get("level")]
	var econ := {}
	if economy:
		var cargo: Array = []
		for u in units:
			var c: Dictionary = economy.cargo.get(u, {})
			cargo.append([c.get("wood", 0), c.get("ore", 0)])
		econ = {"wood": economy.wood, "ore": economy.ore, "up": economy.upgraded, "cargo": cargo,
			"stock": economy.nodes.map(func(n): return n.stock)}
	return {"units": us, "monarchs": ms, "gates": gs, "vaults": vs, "score": score, "time": time_left,
		"prep": prep_left, "overtime": overtime, "over": game_over, "winner": winner_team, "feed": feed,
		"ents": ents, "barr": barricades.map(func(b): return b.hp), "orbs": heal_orbs.map(func(o): return o.active),
		"econ": econ, "fire": [vmap.fire_owner, vmap.fire_progress] if vmap else []}


func net_apply_snapshot(d: Dictionary) -> void:
	## Client: take the host's state. Units glide to their new spots in
	## unit.gd (_net_puppet); everything else is set as it comes.
	var us: Array = d.units
	for i in mini(us.size(), units.size()):
		units[i].net_apply(us[i])
	var ms: Array = d.monarchs
	for i in mini(ms.size(), monarchs.size()):
		var m = monarchs[i]
		m.state = ms[i][0]
		m.carrier = units[ms[i][3]] if ms[i][3] >= 0 else null
		if m.carrier == null:
			m.global_position = ms[i][1]
			m.rotation.y = ms[i][2]
	var gs: Array = d.gates
	for i in mini(gs.size(), gates.size()):
		if gates[i].hp != gs[i][0] or gates[i].broken != gs[i][1]:
			gates[i].hp = gs[i][0]
			gates[i].broken = gs[i][1]
			gates[i].shape.disabled = gates[i].broken
			gates[i]._refresh()
	var vs: Array = d.vaults
	for i in mini(vs.size(), vaults.size()):
		if vaults[i].hp != vs[i][0] or vaults[i].open != vs[i][1]:
			vaults[i].hp = vs[i][0]
			vaults[i].open = vs[i][1]
			vaults[i]._refresh()
	for t in 2:
		if d.score[t] > score[t]:
			capture_team = t
			capture_timer = 3.0
	var now := Time.get_ticks_msec() / 1000.0
	kill_feed = []
	for e in d.feed:
		var k: Dictionary = e.duplicate()
		k["time"] = now - float(e.age)
		k.erase("age")
		kill_feed.append(k)
	_net_apply_entities(d)
	score = d.score.duplicate()
	time_left = d.time
	prep_left = d.prep
	overtime = d.overtime
	if d.over and not game_over:
		_finish(d.winner)


func _net_apply_entities(d: Dictionary) -> void:
	var ents: Dictionary = d.ents
	for nid in net_ents.keys():
		var n = net_ents[nid]
		if not ents.has(nid):
			if is_instance_valid(n):
				if n in turrets:
					turrets.erase(n)
				blessings.erase(n)
				n.queue_free()
			net_ents.erase(nid)
		elif is_instance_valid(n) and n.get("hp") != null:
			var e: Array = ents[nid]
			if n.hp != e[0] or (e[1] != null and n.level != e[1]):
				n.hp = e[0]
				if e[1] != null:
					n.level = e[1]
				if n.has_method("_refresh"):
					n._refresh()
	var barr: Array = d.barr
	for i in mini(barr.size(), barricades.size()):
		var b = barricades[i]
		if b.hp != barr[i]:
			var was_up: bool = b.hp > 0
			b.hp = barr[i]
			b.shape.disabled = b.hp <= 0
			b.visual.visible = b.hp > 0
			if was_up != (b.hp > 0) and b.hp > 0:
				b.visual.rotation = Vector3.ZERO
				b.visual.position = Vector3.ZERO
	var orbs: Array = d.orbs
	for i in mini(orbs.size(), heal_orbs.size()):
		var o = heal_orbs[i]
		if o.active != orbs[i]:
			o.active = orbs[i]
			o.orb.visible = o.active
			o.light.visible = o.active
			o.sparks.emitting = o.active
			o.respawn_timer = Stats.HEAL_ORB_RESPAWN if not o.active else 0.0
	var econ: Dictionary = d.econ
	if economy and not econ.is_empty():
		for t in 2:
			var changed: bool = economy.wood[t] != econ.wood[t] or economy.ore[t] != econ.ore[t]
			economy.wood[t] = econ.wood[t]
			economy.ore[t] = econ.ore[t]
			if changed:
				economy._refresh_pile(t)
			for r in econ.up[t]:
				if not economy.upgraded[t].has(r):
					economy.upgraded[t][r] = true
					economy._mark_seal(t, int(r))
		for i in mini(econ.cargo.size(), units.size()):
			var c: Array = econ.cargo[i]
			var u = units[i]
			var have: Dictionary = economy.cargo.get(u, {"wood": 0, "ore": 0})
			if have.get("wood", 0) != c[0] or have.get("ore", 0) != c[1]:
				if c[0] == 0 and c[1] == 0:
					economy.cargo.erase(u)
				else:
					economy.cargo[u] = {"wood": c[0], "ore": c[1]}
				economy._refresh_cargo(u)
		for i in mini(econ.stock.size(), economy.nodes.size()):
			var n = economy.nodes[i]
			if n.stock != econ.stock[i]:
				n.stock = econ.stock[i]
				n._refresh()
	if vmap and d.fire.size() == 2 and vmap.fire_owner != d.fire[0]:
		vmap.fire_owner = d.fire[0]
		for u in units:
			u.refresh_fire(false)
	if vmap and d.fire.size() == 2:
		vmap.fire_progress = d.fire[1]


func net_button(what: String) -> void:
	## Title screen ONLINE row: HOST / STOP, JOIN / LEAVE and the address field.
	sfx.ui("ui_click")
	match what:
		"host":
			if net.is_host():
				net.leave()
			else:
				net.host()
		"join":
			if net.is_client():
				net.leave()
				_reload_scene()   # back to our own world
			else:
				var parts := net_ip.strip_edges().split(":")
				net.join(parts[0], int(parts[1]) if parts.size() > 1 else net.DEFAULT_PORT)
		"ip":
			ip_editing = true
			swallow_frame = Engine.get_process_frames()
var local_sides: Array = []     # each local player's side this match (see _start_match)
var bound_pads: Array = []      # the pad device each local player holds this match (see _bind_couch_input)


func _local_slot(team: int, slot: int) -> int:
	## Which local player (0-based) takes lineup slot `slot` of `team`, or -1
	## for a bot. Local players fill a side's first slots in player order.
	if net_client:
		return 0 if team == net_slot.x and slot == net_slot.y else -1
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
	# Every device drives exactly one player (Faisal 2026-10-15). Device -1
	# means "any pad" to Godot, so a player 1 with no pad of their own gets
	# a device no pad has (NO_PAD); otherwise player 2's controller would
	# move and aim player 1 too. Alone, player 1 answers to any pad again.
	var p1_device: int = p1_pad if p1_pad >= 0 or couch_players <= 1 else NO_PAD
	# Agent: Codex-faisal3/bugtest. Shared pause belongs to player1, matching their assigned pad.
	for ev in InputMap.action_get_events("menu"):
		if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
			ev.device = p1_device
	for action in COUCH_ACTIONS:
		for ev in InputMap.action_get_events(action):
			if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
				ev.device = p1_device
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
	## Split the window: one SubViewport a local player, sharing the world
	## with its own camera and HUD. _layout_panes places them.
	couch_active = true
	camera.current = false
	split_layer = CanvasLayer.new()
	split_layer.layer = 0
	add_child(split_layer)
	for k in couch_players:
		var u = locals[k]
		var box := SubViewportContainer.new()
		box.stretch = true
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
		Season.attach_weather(cam, air_kind())
		var h = Hud.new()
		h.game = self
		h.local_unit = u
		h.pane = true
		h.process_mode = Node.PROCESS_MODE_ALWAYS
		view.add_child(h)
		var pane := {"unit": u, "box": box, "view": view, "cam": cam, "hud": h, "hud_scale": 1.0, "zoom": 1.0, "cam_pos": u.global_position, "rect": Rect2()}
		panes.append(pane)
		view.size_changed.connect(func(): h.size = Vector2(view.size) / pane.hud_scale)
	if couch_players == 3:
		# The spare quarter: a dark plate so it is not raw clear colour.
		split_fill = ColorRect.new()
		split_fill.color = Color(0.05, 0.06, 0.09)
		split_fill.anchor_left = 0.5
		split_fill.anchor_top = 0.5
		split_fill.anchor_right = 1.0
		split_fill.anchor_bottom = 1.0
		split_layer.add_child(split_fill)
	_layout_panes()
	get_viewport().size_changed.connect(_on_window_resized)   # window resized or fullscreen
	for pane in panes:
		pane.cam_pos = pane.unit.global_position + CAMERA_OFFSET * cam_zoom * pane.zoom
		pane.cam.global_position = pane.cam_pos
	apply_graphics()   # the panes' shadow budget (see apply_graphics)


func pane_rects(n: int, layout: String) -> Array:
	## Where each local player's pane sits, as fractions of the window. Two
	## players split vertically (side by side) or horizontally (top and
	## bottom), per the Split Screen setting; three or four take the quarters.
	if n == 2:
		if layout == "horizontal":
			return [Rect2(0, 0, 1, 0.5), Rect2(0, 0.5, 1, 0.5)]
		return [Rect2(0, 0, 0.5, 1), Rect2(0.5, 0, 0.5, 1)]
	return [Rect2(0, 0, 0.5, 0.5), Rect2(0.5, 0, 0.5, 0.5), Rect2(0, 0.5, 0.5, 0.5), Rect2(0.5, 0.5, 0.5, 0.5)]


func _layout_panes() -> void:
	## Size every pane for the current layout: its HUD scale (so the HUD fits
	## the pane) and its camera pull-back (a tall half-width pane sees less of
	## the lanes left to right, so its camera rises to keep the same reach).
	var n := panes.size()
	var rects := pane_rects(n, split_layout)
	for k in n:
		var pane: Dictionary = panes[k]
		var r: Rect2 = rects[k]
		var box: SubViewportContainer = pane.box
		# The pane in canvas units, with a 2-unit seam between panes.
		var canvas := get_viewport().get_visible_rect().size
		var area := Rect2(r.position * canvas, r.size * canvas)
		area.position.x += 2.0 if r.position.x > 0.0 else 0.0
		area.position.y += 2.0 if r.position.y > 0.0 else 0.0
		area.end = Vector2(area.end.x - (2.0 if r.end.x < 1.0 else 0.0), area.end.y - (2.0 if r.end.y < 1.0 else 0.0))
		pane.rect = area
		# Render at the window's own pixels (Faisal 2026-10-15: "the visual
		# downgrade when going to split screen is too much"). The canvas is
		# 1280x720 stretched to the window, and a stretched SubViewport took
		# that canvas size, so a 1080p pane drew 1.5x fewer pixels each way
		# (2x at 1440p) and was blown up blurry. The box is now sized in
		# window pixels and scaled back down by the same factor.
		var px_scale := _pane_pixel_scale()
		box.set_anchors_preset(Control.PRESET_TOP_LEFT)
		box.scale = Vector2.ONE / px_scale
		box.position = area.position
		box.size = area.size * px_scale
		pane.view.scaling_3d_scale = get_viewport().scaling_3d_scale
		pane.view.scaling_3d_mode = get_viewport().scaling_3d_mode
		var tall := r.size.y > r.size.x * 1.2
		# Keep the game view in charge (Faisal 2026-10-10: the split-screen
		# HUD must not take up most of the screen): the top bar and the
		# bottom row together stay near a quarter of the pane's height, and
		# the bottom row still fits the pane's width.
		var px: Vector2 = get_viewport().get_visible_rect().size * r.size
		pane.hud_scale = clampf(minf(px.y * SPLIT_HUD_SHARE / SPLIT_HUD_ROWS, px.x / SPLIT_HUD_WIDTH), 0.4, 0.72)
		pane.zoom = SPLIT_TALL_ZOOM if tall else 1.0
		pane.hud_scale *= px_scale   # the pane's pixels are px_scale finer than canvas units
		pane.hud.scale = Vector2.ONE * pane.hud_scale
		pane.hud.size = Vector2(pane.view.size) / pane.hud_scale


func _on_window_resized() -> void:
	if couch_active:
		_layout_panes()


func _pane_pixel_scale() -> float:
	## Window pixels per canvas unit (1.5 for a 1080p window on the 1280x720
	## canvas); 1 when there is no real window (headless tests).
	var canvas := get_viewport().get_visible_rect().size
	var win := Vector2(get_window().size)
	if DisplayServer.get_name() == "headless" or canvas.x <= 0.0 or win.x <= 0.0:
		return 1.0
	return clampf(minf(win.x / canvas.x, win.y / canvas.y), 0.5, 4.0)


func set_split_layout(layout: String) -> void:
	## The Split Screen setting (Options and READY UP): live in a match too.
	split_layout = "horizontal" if layout == "horizontal" else "vertical"
	if couch_active:
		_layout_panes()
	_save_settings()


func shake(amount: float) -> void:
	## Camera recoil for the local player's view.
	if not screen_shake:
		return
	shake_amount = maxf(shake_amount, amount)


func kick_cam(dir: Vector3, amount: float) -> void:
	## A directional camera jolt (getting hit, landing a blow) that springs
	## back, on top of the random shake. Honours the screen shake setting.
	if not screen_shake:
		return
	dir.y = 0.0
	if dir.length() < 0.01:
		return
	cam_kick = (cam_kick + dir.normalized() * amount).limit_length(0.5)


func shake_at(where: Vector3, amount: float) -> void:
	## A shake that fades with distance from the player.
	if net:
		net.rec("game", "shake_at", [where, amount])
	if player == null:
		return
	var d := _flat_dist(where, player.global_position)
	if d < 16.0:
		shake(amount * (1.0 - d / 16.0))


func hero_custom() -> Dictionary:
	## The player's chosen hair and trim colours for the character skin.
	var c := {"hair": Stats.HERO_HAIR[hero_hair][1], "skin": Stats.HERO_SKINS[hero_skin][1], "body": Stats.HERO_BODIES[hero_body][1], "face": hero_face, "mark": hero_mark,
		"hair_style": hero_hair_style}
	if hero_eye >= 0:
		c.eye = hero_eye
	if hero_trim > 0:
		c.trim = Stats.HERO_TRIM[hero_trim][1]
	if hero_look > 0 and unlocked():
		c.look = Stats.HERO_LOOKS[hero_look][1]
	# STORE cosmetics (looks only, no stats).
	if hero_hat > 0:
		c.hat = Stats.HERO_HATS[hero_hat][1]
	if hero_cape > 0:
		c.cape = Stats.HERO_CAPES[hero_cape][1]
	if hero_outfit > 0:
		c.outfit = hero_outfit
	if hero_weapon > 0:
		c.weapon = hero_weapon
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


func on_player_killed(killer, weapon: String, finished: bool = false) -> void:
	## The player died: show the killer's banner for a while ("FINISHED BY"
	## when they were finished off while downed).
	if killer == null or killer == player:
		killer_card = {}
		return
	killer_card = {"unit": killer, "weapon": weapon, "finished": finished}
	killer_timer = 6.0


func unlocked() -> bool:
	## The level-10 unlocks (Rogue, Shadowborn look, Moonlit map).
	return account_level() >= Stats.UNLOCK_LEVEL or "--debug-unlock" in OS.get_cmdline_user_args()


func night() -> bool:
	return map_variant == 1 and (unlocked() or "--debug-night" in OS.get_cmdline_user_args())


func _bank_match_xp(winner: int) -> void:
	## The match is over: the player's XP, the result bonus and any accolades
	## go on the account. The summary screen plays the bar filling up.
	summary = MatchSummary.new()
	summary.capture(self, player, winner)
	if demo:
		return
	var bonus: int = Stats.MATCH_BONUS.draw if winner < 0 else (Stats.MATCH_BONUS.win if winner == player_team else Stats.MATCH_BONUS.loss)
	if not result_bonus_earned():
		bonus = 0
	level_before = account_level()
	var xp_was := account_xp
	last_match_gain = match_xp + bonus + summary.bonus_xp()
	account_xp += last_match_gain
	account_gold += summary.reward_gold
	account_shards += summary.reward_shards
	account_chests += 1
	if player:   # the legend's tallies: the side and main class of each match
		legend_sides[clampi(summary.team, 0, 1)] += 1
		legend_classes[clampi(summary.main_role, 0, legend_classes.size() - 1)] += 1
	summary.set_account(xp_was, account_xp)
	_save_settings()
	toast("Progress saved", Color(0.6, 1.0, 0.55))
	var now := account_level()
	var steam = get_node_or_null("/root/SteamHub")
	if steam:
		steam.level_reached(now)
	if now > level_before:
		if now >= Stats.UNLOCK_LEVEL and level_before < Stats.UNLOCK_LEVEL:
			chat_system("Account level %d: the Rogue, the Shadowborn look and the Moonlit Wildwood are unlocked!" % now)


static func _counts(v, n: int) -> Array:
	## A saved tally list, n whole numbers long whatever was saved.
	var out: Array = []
	for i in n:
		out.append(maxi(int(v[i]), 0) if (v is Array or v is PackedInt32Array) and i < v.size() and (v[i] is int or v[i] is float) else 0)
	return out


func legend_due() -> bool:
	## The ending plays once per player: the first time their account stands
	## at Legend.LEGEND_LEVEL or above after a match.
	return not demo and not legend_seen and account_level() >= Legend.LEGEND_LEVEL


func legend_level() -> int:
	return Legend.LEGEND_LEVEL


func legend_unlocked() -> bool:
	## PROGRESS offers WATCH THE LEGEND from this level on.
	return account_level() >= Legend.LEGEND_LEVEL or "--debug-unlock" in OS.get_cmdline_user_args()


func continue_after_summary() -> void:
	## CONTINUE on the match summary: the ending if it is due, else the title.
	if legend_due():
		start_legend("full")
	else:
		_reload_scene()


func start_legend(mode: String = "full") -> void:
	## "full": LEGEND OF THE WILDWOOD (after the level-20 match, or WATCH THE
	## LEGEND in PROGRESS); "roll": just the credits roll (ROLL CREDITS).
	if mode == "full" and not legend_seen:
		legend_seen = true   # once per player, even if skipped: PROGRESS replays it
		_save_settings()
	legend = Legend.new(self, mode)
	menu_open = false
	sfx.play_music(false)
	print("LEGEND start mode=%s level=%d" % [mode, account_level()])


func legend_tour_done(dir: String) -> void:
	## Renders (--debug-legend-tour): after the ending's shots, the title's
	## CREDITS (with ROLL CREDITS) and PROGRESS (WATCH THE LEGEND), then quit.
	legend.finish()
	var size := get_viewport().get_visible_rect().size
	for ov in ["credits", "progress"]:
		main_menu.overlay = ov
		for i in 20:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("%s/overlay_%s.png" % [dir, ov])
	print("LEGEND tour done %dx%d" % [size.x, size.y])
	_save_settings()
	_flush_save()
	finish_world_now()
	get_tree().quit()


func legend_finished() -> void:
	## The ending is over (or skipped): after a match, on to the title; from
	## the title's overlays, back to where it was opened.
	legend = null
	swallow_frame = Engine.get_process_frames()   # the closing press must not reach the menu behind
	confirm_block = true
	print("LEGEND done")
	if game_over:
		_reload_scene()


func result_bonus_earned() -> bool:
	## The Victory / Draw / Played-to-the-end XP needs a real match (GP-06):
	## one that ended in its first minute pays only what was earned in it.
	return match_played >= Stats.RESULT_BONUS_MIN_TIME or "--debug-end" in OS.get_cmdline_user_args()


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
				rank_from_pad = true
	if not on_pad and on_upgrade_pad and rank_open:
		rank_open = false
	on_upgrade_pad = on_pad


func menu_blocks_input(u = null) -> bool:
	## True while a menu has this player's controls (the perk menu only
	## blocks the player who opened it).
	if u != null and u.remote_peer > 0:
		return false   # a joiner's menus live on their own screen
	return menu_open or chat_open or guide_open or (rank_open and (u == null or rank_player == null or rank_player == u))


func menu_blocks_movement(u = null) -> bool:
	## Like menu_blocks_input, but the perk menu the Upgrade Station opens
	## leaves you free to walk: it closes when you step off (GP-05: it held
	## the player still on the pad until R or the right stick closed it).
	if rank_open and rank_from_pad and not (menu_open or chat_open or guide_open):
		return false
	return menu_blocks_input(u)


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
				rank_from_pad = false   # opened on purpose: it holds the controls until closed
			return true
	return false


func _quick_upgrades() -> void:
	## Spend a point in the field without opening UPGRADES: 1-4 (or the
	## D-pad, or the HUD's level-up tiles) buy that skill's next rank once
	## you have been out of the fight for Stats.QUICK_UPGRADE_CALM seconds.
	if Input.is_action_pressed("scoreboard"):
		return   # scoreboard + D-pad are the team calls
	for u in locals:
		if u == null or u.dead or u.downed or u.points <= 0:
			continue
		for i in 4:
			if Input.is_action_just_pressed(u.act_prefix + "rank_%d" % (i + 1)):
				quick_buy(u, i)


func quick_buy(u, track: int) -> bool:
	## One quick upgrade: refused (with a shake and IN COMBAT) mid-fight.
	if u.calm_left() > 0.0:
		sfx.ui("ui_deny", -4.0)
		spawn_popup(u.global_position + Vector3(0, 2.2, 0), "IN COMBAT", Color(1.0, 0.5, 0.4))
		if hud:
			hud.quick_deny = Time.get_ticks_msec() / 1000.0
		return false
	if not u.spend_point(track):
		sfx.ui("ui_deny", -4.0)
		return false
	return true


func _rank_pad(u) -> void:
	## UPGRADES on a gamepad (Faisal 06:00 2026-10-10 "make the upgrades feel
	## better with controller controls"): the D-pad moves a highlight over the
	## four skills and the two promotions, A / Cross buys or picks the one
	## lit, LB / RB flip through the classes and B / Circle closes. (On a pad
	## the D-pad used to buy a rank outright, with nothing lit to show which.)
	var pre: String = u.act_prefix
	var f: int = hud.rank_focus
	var promos: bool = Stats.VARIANTS.has(u.role if hud.rank_view < 0 else hud.rank_view)
	var moved := f
	if Input.is_action_just_pressed(pre + "rank_1"):   # D-pad up
		f = 3 if f >= 4 else maxi(f - 1, 0)
	if Input.is_action_just_pressed(pre + "rank_4"):   # D-pad down
		f = (4 if promos else 3) if f >= 3 else f + 1
	if Input.is_action_just_pressed(pre + "rank_2") and f >= 4:   # D-pad left
		f = 4
	if Input.is_action_just_pressed(pre + "rank_3") and f >= 4:   # D-pad right
		f = 5
	for k in 2:
		if Input.is_action_just_pressed(pre + "rank_%d" % (k + 5)):   # LB / RB: the class tabs
			var order: Array = [Role.KNIGHT, Role.RANGER, Role.MAGE, Role.HEALER, Role.ENGINEER, Role.ROGUE]
			if not u.role in order:
				order.push_front(u.role)   # a base soldier sees their own page first
			var at := order.find(u.role if hud.rank_view < 0 else hud.rank_view)
			var next: int = order[posmod(at + (1 if k == 1 else -1), order.size())]
			hud.rank_view = -1 if next == u.role else next
			sfx.ui("ui_click", -6.0)
	if f != moved:
		hud.rank_focus = f
		sfx.ui("ui_click", -8.0)
	if Input.is_action_just_pressed(pre + "attack"):   # A / Cross
		var own: bool = hud.rank_view < 0 or hud.rank_view == u.role
		var ok := false
		if own and f < 4:
			ok = u.spend_point(f)
		elif own:
			ok = u.choose_variant(u.role, f - 4)
		if not ok:
			sfx.ui("ui_deny", -4.0)
			hud.rank_deny = Time.get_ticks_msec() / 1000.0
	if Input.is_action_just_pressed(pre + "dodge"):   # B / Circle
		rank_open = false
		sfx.ui("ui_close", -4.0)


func menu_tabs() -> Array:
	## Which menu tabs make sense now: at the title only Classes and Controls.
	return [5, 4, 1, 6] if not playing else [0, 3, 1, 2, 4, 5]


func menu_tick() -> void:
	## Called every frame by the HUD, which keeps running while paused.
	if _stream_world:
		click_latched = false
		click_was = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		return
	if legend:
		# The ending takes every press (legend.input); the menus behind wait.
		click_latched = false
		click_was = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		legend.tick(get_process_delta_time())
		return
	quit_armed = maxf(quit_armed - get_process_delta_time(), 0.0) if menu_open else 0.0
	if game_over:
		return
	var eaten: bool = Engine.get_process_frames() == swallow_frame
	if not playing:
		# Title screen: the options menu (controls, classes), bot difficulty.
		if not eaten and rebinding == "" and not ip_editing:
			if Input.is_action_just_pressed("options") and not menu_open:
				menu_open = true
				menu_tab = 5
			elif Input.is_action_just_pressed("menu") and menu_open:
				menu_open = false
			elif Input.is_action_just_pressed("menu") and main_menu and not name_editing:
				main_menu.back()
			elif not menu_open and main_menu and main_menu.overlay == "howto":
				if Input.is_action_just_pressed("menu_left"):
					main_menu.howto_next(-1)
				if Input.is_action_just_pressed("menu_right"):
					main_menu.howto_next(1)
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
			get_tree().paused = menu_open and not (net and net.online())  # an online match never pauses
		scoreboard_open = (Input.is_action_pressed("scoreboard") or debug_score) and not menu_open and not rank_open
		if menu_open:
			if Input.is_action_just_pressed("quit_match") and rebinding == "":
				# Two presses, like the LEAVE MATCH button: one stray pad Y (or
				# Backspace) used to throw the match and its rewards away.
				if quit_armed > 0.0:
					quit_to_title()
					return   # the scene reloads: nothing below may touch this node's tree
				else:
					quit_armed = 3.0
					sfx.ui("ui_click", -4.0)
		elif guide_open and not eaten:
			if Input.is_action_just_pressed("menu"):
				guide_close()
			# The number keys pick a topic. Not on a pad: rank_1-4 are also its
			# D-pad, which moves the cursor here (a press down opened topic 4).
			for i in Guide.TOPICS.size():
				if Input.is_action_just_pressed("rank_%d" % (i + 1)) and not pad_active:
					guide_pick(i)
		elif _rank_pressed() and not demo:
			pass  # handled in _rank_pressed
		elif Input.is_action_just_pressed("chat") and player and not demo and not eaten:
			chat_open = true
			chat_text = ""
			rank_open = false
		elif not rank_open and not eaten and not demo:
			_quick_upgrades()
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
			# A pad has no free buttons for the calls: hold the scoreboard
			# (Back / Create) and press the D-pad: up Attack, left Defend, right To me.
			if Input.is_action_pressed("scoreboard"):
				for pair in [["rank_1", "attack"], ["rank_2", "defend"], ["rank_3", "help"]]:
					if Input.is_action_just_pressed(pair[0]):
						call_command(pair[1])
		if rank_open and rank_player == null:
			rank_player = player
		if rank_open and rank_player:
			if rank_player.dead:
				rank_open = false
			if on_pad(rank_player) and hud:
				_rank_pad(rank_player)
			else:
				for i in 4:
					if Input.is_action_just_pressed(rank_player.act_prefix + "rank_%d" % (i + 1)):
						rank_player.spend_point(i)
				for i in 2:
					if Input.is_action_just_pressed(rank_player.act_prefix + "rank_%d" % (i + 5)):
						rank_player.choose_variant(rank_player.role, i)
	if menu_open and rebinding == "" and not chat_open and not eaten:
		# Not on a press a rebind just took: binding Move up to A (or a pad
		# button to LB / RB) switched the tab as well (#85).
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
	if eaten:
		confirm_block = true   # a pad A a rebind or name entry just took is not also a click
	if confirm_block and not Input.is_action_pressed("ui_confirm"):
		confirm_block = false
	var click := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or touch_tap.x >= 0.0 or (cursor_shown and Input.is_action_pressed("ui_confirm") and not confirm_block)
	if not click:
		if slider_drag >= 0:
			_save_settings()   # once, on release: it rewrote the save every frame of a drag (AUD-02)
		slider_drag = -1
	if click and hud and menu_open and not menus_warming:
		# Volume sliders follow the mouse while the button is held, but only
		# a press that started on a slider drags it. A press still held from
		# the match summary's CONTINUE landed on the Settings tab the menu
		# warm-up shows for two frames after the reload, and dragged the
		# volume to full (Faisal 2026-10-15: "when you finish a game it
		# sends you to the main menu with the volume maxed").
		var mp := menu_mouse()
		for si in hud.volume_sliders.size():
			var sl: Array = hud.volume_sliders[si]
			if not click_was and sl[0].grow(6).has_point(mp):
				slider_drag = si
			if slider_drag == si:
				var v := clampf((mp.x - sl[0].position.x - 2.0) / (sl[0].size.x - 4.0), 0.0, 1.0)
				if sl[1] == "sound":
					sfx.sound_volume = v
				else:
					sfx.music_volume = v
				sfx.apply_volumes()
				if not click_was:
					sfx.ui("ui_click", -4.0)
	# A press that came and went between two frames (a quick click or tap
	# while a slow browser frame was drawing) is caught by _input below;
	# polling the button alone missed it (Faisal 2026-10-14: menus "still
	# unresponsive at times" on the web).
	var pressed_now := click and not click_was
	if click_latched:
		pressed_now = true
		click = true
		click_latched = false
	if menus_warming:
		pressed_now = false
	if pressed_now and hud and rebinding == "" and not eaten and name_editing and main_menu and main_menu.pad_keys_on():
		main_menu.tick(true, menu_mouse())   # the pad's letter pad: only its keys answer
	elif pressed_now and hud and rebinding == "" and not eaten:
		var mouse := menu_mouse()
		if not playing and not menu_open and main_menu and not name_editing:
			main_menu.tick(true, mouse)
		for i in hud.rank_buttons.size():
			if hud.rank_buttons[i].has_point(mouse) and player:
				player.spend_point(i)
		for b in hud.variant_buttons:
			if b[0].has_point(mouse) and player:
				player.choose_variant(b[1], b[2])
		for b in hud.rank_tab_buttons:
			if b[0].has_point(mouse):
				hud.rank_view = -1 if player and b[1] == player.role else b[1]
		for i in hud.tab_buttons.size():
			if hud.tab_buttons[i].has_point(mouse):
				menu_tab = hud.tab_ids[i]
		if hud.quick_close.has_point(mouse) and playing and not menu_open and not rank_open and player:
			hud.hide_quick()
		for b in hud.quick_buttons:
			if b[0].has_point(mouse) and playing and not menu_open and not rank_open and player:
				if b[1] is Callable:
					if b[1].is_valid() and not b[1].call():   # an Economy tile: it says why (toast) when it can't
						sfx.ui("ui_deny", -4.0)
				else:
					quick_buy(player, b[1])
		for b in hud.corner_buttons:
			if b[0].has_point(mouse) and playing and not menu_open and not rank_open:
				menu_open = true
				menu_tab = 0 if b[1] == "menu" else 3
				get_tree().paused = not (net and net.online())   # an online match never pauses (this froze every joiner)
				sfx.ui("ui_click", -4.0)
		for b in hud.group_buttons:
			if b[0].has_point(mouse):
				hud.controls_group = b[1]
				sfx.ui("ui_click", -6.0)
		for b in hud.class_buttons:
			if b[0].has_point(mouse) and player and seals[player.team].has(b[1]):
				seals[player.team][b[1]].take(player)
				menu_open = false
				get_tree().paused = false
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
			menu_tab = 5
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
						"hair", "trim", "banner_bg", "banner_emblem", "banner_frame" when not Store.owns(self, b[1], b[2]):
							Store.locked_toast(self, b[1], b[2])
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
							if b[2] != 1 or unlocked():
								select_map(b[2])
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
			ip_editing = false
			for b in hud.couch_buttons:
				if b[0].has_point(mouse):
					if b[1] in ["host", "join", "ip"]:
						net_button(b[1])
					else:
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
		if hud.resume_button.has_point(mouse) and menu_open:
			menu_open = false
			get_tree().paused = false
		for b in hud.zoom_buttons:
			if b[0].has_point(mouse) and menu_open:
				hud.map_zoom = clampf(hud.map_zoom + 0.5 * b[1], 1.0, 3.0)
				sfx.ui("ui_click", -6.0)
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
	touch_tap = Vector2(-1, -1)



func movement_ui_hit() -> bool:
	if hud == null:
		return false
	var pointer := menu_mouse()
	if hud.quick_close.has_point(pointer):
		return true
	for group in [hud.quick_buttons, hud.corner_buttons, hud.chat_buttons]:
		for button in group:
			if button[0].has_point(pointer):
				return true
	if rank_open:
		# The perk menu's rows and class tabs: a click there buys, not walks.
		for r in hud.rank_buttons:
			if r is Rect2 and r.has_point(pointer):
				return true
		for b in hud.rank_tab_buttons:
			if b[0].has_point(pointer):
				return true
	return economy != null and economy.mouse_on_button()


func mouse_in_player_pane(u) -> bool:
	if not couch_active:
		return true
	var pointer := get_viewport().get_mouse_position()
	for pane in panes:
		if pane.unit == u:
			return pane.rect.has_point(pointer)
	return false


func movement_ground_point(u) -> Vector3:
	if not mouse_in_player_pane(u):
		return Vector3.INF
	var cam: Camera3D = camera_for(u)
	if cam == null:
		return Vector3.INF
	var pointer: Vector2 = mouse_for(u)
	var origin := cam.project_ray_origin(pointer)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + cam.project_ray_normal(pointer) * 500.0, 1)
	query.exclude = [u.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.normal.dot(Vector3.UP) < 0.55:
		return Vector3.INF
	var point: Vector3 = hit.position
	if vmap != null and not vmap.walkable(point, 0.4):
		return Vector3.INF
	if lmap != null and not lmap.walkable(point, 0.4):
		return Vector3.INF
	return point


func mouse_movement_choice(u, point: Vector3) -> Dictionary:
	if not point.is_finite():
		return {}
	# Selection is explicit. Ordinary ground clicks never drop the crown or
	# trigger the generic prep-stage barricade fallback in try_interact.
	var candidates: Array = []
	if guides[u.team] != null:
		candidates.append(guides[u.team])
	for seal in seals[u.team].values():
		candidates.append(seal)
	if monarchs.size() > 1:
		var crown = monarchs[1 - u.team]
		if crown != null and crown.state != Monarch.State.CARRIED and u.carrying == null:
			candidates.append(crown)
	if economy != null and u.carrying == null:
		candidates.append_array(economy.nodes)
	var best = null
	var nearest := 1.3
	for node in candidates:
		if not is_instance_valid(node) or not node.is_inside_tree():
			continue
		var distance := Vector2(node.global_position.x - point.x, node.global_position.z - point.z).length()
		if distance < nearest and absf(node.global_position.y - point.y) <= 0.6:
			nearest = distance
			best = node
	if best != null and u.carrying == null:
		return {"kind": "interact", "position": best.global_position, "node": best}
	if combine_move_attack:
		for enemy in units:
			if enemy == u or enemy.team == u.team or enemy.dead:
				continue
			var distance := Vector2(enemy.global_position.x - point.x, enemy.global_position.z - point.z).length()
			if distance < 1.3:
				return {"kind": "attack", "position": enemy.global_position, "node": enemy}
	return {}


func non_primary_attack_held(u) -> bool:
	return mapped_action_held(u._a("attack"), [MOUSE_BUTTON_LEFT])


func mapped_action_held(action: StringName, excluded_mouse: Array) -> bool:
	# Saved/custom LMB attack mappings cannot make a move-only click attack.
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			if (event.physical_keycode != 0 and Input.is_physical_key_pressed(event.physical_keycode)) or (event.keycode != 0 and Input.is_key_pressed(event.keycode)):
				return true
		elif event is InputEventMouseButton and not event.button_index in excluded_mouse:
			if Input.is_mouse_button_pressed(event.button_index):
				return true
		elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
			for device in Input.get_connected_joypads():
				if event.device >= 0 and event.device != device:
					continue
				if event is InputEventJoypadButton and Input.is_joy_button_pressed(device, event.button_index):
					return true
				if event is InputEventJoypadMotion and Input.get_joy_axis(device, event.axis) * signf(event.axis_value) > 0.25:
					return true
	return false


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		click_latched = true
	if event.is_action_released("move_interact"):
		movement_primary_blocked = false
	if event.is_action_pressed("move_interact") and (menu_blocks_movement(player) or movement_ui_hit() or not playing or not mouse_in_player_pane(player)):
		movement_primary_blocked = true
		movement_consumed_tap_frame = Engine.get_physics_frames() + 1
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		if playing and not menu_blocks_movement(player) and not movement_ui_hit():
			if wheel_zoom:
				cam_zoom = clampf(cam_zoom + (-0.08 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 0.08), 0.7, 1.6)
			elif event.is_action_pressed("force_move"):
				movement_force_pulse = true


func menu_input(event: InputEvent) -> void:
	## Raw key events from the HUD: typing in chat and rebinding controls.
	if _stream_world:
		return
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
		if event.device != InputEvent.DEVICE_ID_EMULATION and couch_players == 1:
			pad_active = false   # back on the mouse: the hints switch to keys at once
	if control_layout == "controller":
		pad_active = true    # picked in Controls: the hints stay on the pad's buttons
	elif control_layout in ["keyboard", "touch"]:
		pad_active = false
	if rebinding != "":
		if event is InputEventScreenTouch and event.pressed and Engine.get_process_frames() != swallow_frame:
			rebinding = ""   # a finger can't press a key: a tap cancels (iPad, 2026-10-14)
			swallow_frame = Engine.get_process_frames()
			return
		if event is InputEventMouseButton and event.device == InputEvent.DEVICE_ID_EMULATION:
			return   # a finger's emulated click is not a mouse button to bind
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
		elif event is InputEventJoypadMotion and _is_trigger(event) and absf(event.axis_value) > 0.5:
			# LT / RT are axes, not buttons: they could not be picked before.
			_rebind(rebinding, event)
			swallow_frame = Engine.get_process_frames()
		return
	if name_editing and event is InputEventJoypadButton and event.pressed and main_menu and main_menu.pad_keys_on() and not playing:
		# The pad's letter pad (menu.gd): A presses the key under the cursor
		# (a click, below), B rubs out a letter, Start keeps the name.
		if event.button_index == JOY_BUTTON_B and hero_name != "":
			hero_name = hero_name.left(hero_name.length() - 1)
			swallow_frame = Engine.get_process_frames()
			return
		if event.button_index in [JOY_BUTTON_B, JOY_BUTTON_START]:
			end_name_entry()
			return
		if event.button_index == JOY_BUTTON_A:
			return
	if name_editing and event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_START]:
		# A pad has no letters: its confirm/back/start ends the name entry
		# instead of leaving a pad-only player stuck on the prompt (RT-01).
		# An empty name becomes "Hero" so the first-run prompt doesn't return;
		# it can be changed any time on PLAYERS or Customize.
		name_editing = false
		hero_name = hero_name.strip_edges()
		if hero_name == "":
			hero_name = "Hero"
		_save_settings()
		swallow_frame = Engine.get_process_frames()
		confirm_block = true   # the same A press must not also click the button under the cursor
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
	if main_menu and not playing and main_menu.screen == "online" and main_menu.overlay == "" and event is InputEventKey and event.pressed and not (net and net.online()):
		# Typing the JOIN code on a keyboard (the letter pad does the same by touch).
		if event.keycode == KEY_BACKSPACE:
			main_menu.code_key("<")
			return
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER] and main_menu.room_entry.length() == main_menu.CODE_LEN:
			net.join_room(main_menu.room_entry)
			return
		if event.unicode >= 32:
			main_menu.code_key(char(event.unicode))
			return
	if ip_editing and event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE:
				ip_editing = false
				swallow_frame = Engine.get_process_frames()
			KEY_BACKSPACE:
				net_ip = net_ip.left(maxi(net_ip.length() - 1, 0))
			_:
				var ch := char(event.unicode)
				if event.unicode >= 32 and net_ip.length() < 40 and (ch.is_valid_int() or ch in [".", ":"] or ch.to_lower() in "abcdefghijklmnopqrstuvwxyz-"):
					net_ip += ch
		return
	if chat_open and event is InputEventScreenTouch and event.pressed:
		# Chat closes with Enter or Esc; a finger closes it with a tap
		# anywhere but its All / Team tabs (iPad, 2026-10-14).
		var on_tab := false
		for b in hud.chat_buttons:
			if b[0].has_point(event.position):
				on_tab = true
		if not on_tab:
			chat_open = false
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

func chat_add(who: String, text: String, color: Color, team_only: bool = false, role: int = -1, pteam: int = -1) -> void:
	## `role`/`pteam` give the speaker's portrait; `clock` stamps the match time.
	if net:
		net.rec("game", "chat_add", [who, text, color, team_only, role, pteam], null, pteam if team_only else -1)
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
	if net_client:
		net.send_chat(text, team_only)   # the host posts it for everyone it is meant for
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
		+ u.damage_dealt * Stats.SCORE_DAMAGE + u.total_upgrades() * Stats.SCORE_UPGRADE + u.revives * Stats.SCORE_REVIVE


# --- Control bindings --------------------------------------------------------

var _key_labels := {}   # key_label results for half a second (the HUD asks ~20 times a frame)


func key_label(action: String, unit = null) -> String:
	## A short keycap label for the action's binding on whatever the player
	## holds: the mouse or keyboard for player 1 at the keys, the gamepad
	## (in Xbox or PlayStation names) for a pad player. Remembered for half a
	## second, so a rebind or a pad picked up shows within 0.5 s.
	var ck := "%s|%d|%s" % [action, unit.local_index if unit != null else -1, pad_active]
	var now := Time.get_ticks_msec()
	var hit: Array = _key_labels.get(ck, [])
	if not hit.is_empty() and now - int(hit[1]) < 500:
		return hit[0]
	var label := _key_label(action, unit)
	_key_labels[ck] = [label, now]
	return label


func _key_label(action: String, unit = null) -> String:
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

const PLAYER_COLORS := [Color(0.3, 0.85, 1.0), Color(1.0, 1.0, 0.3),   # P1 cyan like the 2026-10-08 target art
		 Color(1.0, 0.45, 0.8), Color(0.6, 1.0, 0.3)]


func player_color(local_index: int) -> Color:
	## Each couch player's colour: their ground ring, outline, name and map arrow.
	return PLAYER_COLORS[clampi(local_index, 0, PLAYER_COLORS.size() - 1)]


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
	if ev.physical_keycode != 0 and not OS.has_feature("web"):   # the web display server cannot map physical keys
		code = DisplayServer.keyboard_get_keycode_from_physical(code)
	return OS.get_keycode_string(code)


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
	# Long key names got cut to six letters ("PAGEDO", "BACKSL", NUM-07).
	var long_names := {"pageup": "PG UP", "pagedown": "PG DN", "backslash": "\\", "capslock": "CAPS",
		"insert": "INS", "delete": "DEL", "numlock": "NUM", "scrolllock": "SCRL", "print": "PRT"}
	if long_names.has(name.to_lower()):
		return long_names[name.to_lower()]
	return name.to_upper().left(6)


func _mouse_name(button: int) -> String:
	match button:
		MOUSE_BUTTON_LEFT: return "LMB"
		MOUSE_BUTTON_RIGHT: return "RMB"
		MOUSE_BUTTON_MIDDLE: return "MMB"
		MOUSE_BUTTON_WHEEL_UP: return "Wheel↑"
		MOUSE_BUTTON_WHEEL_DOWN: return "Wheel↓"
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
	if (action == "attack" and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT) or (action == "block" and event is InputEventKey and (event.physical_keycode == KEY_SHIFT or event.keycode == KEY_SHIFT)):
		rebinding = ""
		toast("Left click is Move/Interact; use Combine or Shift to attack. Shift is Force Hold.", Color(1.0, 0.8, 0.5))
		return
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
	elif event is InputEventJoypadMotion and _is_trigger(event):
		fresh = InputEventJoypadMotion.new()
		fresh.axis = event.axis
		fresh.axis_value = 1.0
	else:
		return
	# The binding this one replaces (same kind: keyboard, mouse, or the pad,
	# where buttons and triggers count as one kind).
	var old: InputEvent = null
	for ev in InputMap.action_get_events(action):
		if _bind_kind(ev) == _bind_kind(fresh):
			if old == null:
				old = ev
			InputMap.action_erase_event(action, ev)
	# Another action on the same key swaps to the replaced one instead of
	# silently losing its binding (a pad Y on Ability Q left Ability E with none).
	for entry in REBINDABLE:
		if entry[0] == action:
			continue
		for ev in InputMap.action_get_events(entry[0]):
			if ev.is_match(fresh, true):
				InputMap.action_erase_event(entry[0], ev)
				var label := _action_label(entry[0])
				if old != null and not old.is_match(fresh, true):
					InputMap.action_add_event(entry[0], old)
					toast("%s swapped to %s" % [label, binding_text(entry[0], "pad" if _bind_kind(old) == "pad" else "key")], Color(1.0, 0.85, 0.5))
				else:
					toast("%s is now unbound: give it a new key" % label, Color(1.0, 0.65, 0.5))
	InputMap.action_add_event(action, fresh)
	rebinding = ""
	_save_controls()


static func _is_trigger(ev: InputEvent) -> bool:
	return ev is InputEventJoypadMotion and ev.axis in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]


static func _bind_kind(ev: InputEvent) -> String:
	## Which column of the Controls tab an event belongs to.
	if ev is InputEventKey:
		return "key"
	if ev is InputEventMouseButton:
		return "mouse"
	if ev is InputEventJoypadButton or _is_trigger(ev):
		return "pad"
	return "other"


func pad_binding_hint(action: String, kind: String = "") -> String:
	## The Controls tab's gamepad column: the binding, or how to reach the
	## action without one (team calls are a scoreboard + D-pad chord).
	var t := binding_text(action, "pad", kind)
	if t != "-":
		return t
	var k := kind if kind != "" else pad_kind(local_pad(0))
	match action:
		"cmd_attack": return "%s + %s" % [pad_label("scoreboard", k), _pad_name(JOY_BUTTON_DPAD_UP, k)]
		"cmd_defend": return "%s + %s" % [pad_label("scoreboard", k), _pad_name(JOY_BUTTON_DPAD_LEFT, k)]
		"cmd_help": return "%s + %s" % [pad_label("scoreboard", k), _pad_name(JOY_BUTTON_DPAD_RIGHT, k)]
		"move_interact", "force_move", "force_hold": return "MOUSE ONLY"
		"chat", "chat_toggle", "roster_toggle": return "KEYBOARD ONLY"
	return t


func _action_label(action: String) -> String:
	for entry in REBINDABLE:
		if entry[0] == action:
			return str(entry[1])
	return action


func cycle_difficulty(step: int) -> void:
	var i: int = Stats.BOT_DIFFICULTIES.find(bot_difficulty)
	bot_difficulty = Stats.BOT_DIFFICULTIES[posmod(i + step, Stats.BOT_DIFFICULTIES.size())]
	_save_settings()


func select_map(index: int) -> void:
	## Pick a map on the title screen. The Moonlit Wildwood only changes the
	## light; a map with other ground (Ember Pass) rebuilds the world, so the
	## scene restarts on the title with the new map saved.
	# Day and night share one world; Ember Pass and the two seasons each
	# build their own.
	var built: String = "volcano" if vmap else (season if season != "" else "wildwood")
	var kind: String = Stats.MAPS[index][1]
	var want: String = kind if kind in ["volcano", "winter", "twilight"] else "wildwood"
	map_variant = index
	if want != built:
		_save_settings()
		if main_menu:
			reopen_screen = main_menu.screen
		_reload_scene()
		return
	_apply_map_variant()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		movement_force_pulse = false
		movement_primary_blocked = true
		for unit in locals:
			if is_instance_valid(unit) and unit.has_method("cancel_click_movement"):
				unit.cancel_click_movement()
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		finish_world_now()
	if what == NOTIFICATION_WM_CLOSE_REQUEST and not demo:
		_save_settings()   # closing the window keeps everything
		_flush_save()


func export_progress() -> String:
	## The account as a code to carry to another device (see save_file.gd).
	## On the web it also downloads as a text file and is shown to copy; on
	## desktop it goes on the clipboard.
	_save_settings()
	var cfg := ConfigFile.new()
	_read_save(cfg)
	var code := SaveFile.export_code(cfg)
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(code.to_utf8_buffer(), "crowns-progress.txt", "text/plain")
		JavaScriptBridge.eval("window.prompt('Your progress code (also downloaded as crowns-progress.txt). Copy it, then IMPORT it on the other device:', %s)" % JSON.stringify(code), true)
	elif DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		DisplayServer.clipboard_set(code)
	toast("Progress code copied" if not OS.has_feature("web") else "Progress code ready", Color(0.6, 1.0, 0.55))
	return code


func import_progress(code: String = "") -> bool:
	## Restores an exported code (asks for it when none is given). The save
	## it replaces is kept as controls.cfg.before-import.
	if code == "":
		if OS.has_feature("web"):
			var got = JavaScriptBridge.eval("window.prompt('Paste your progress code:', '') || ''", true)
			code = str(got) if got != null else ""
		elif DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
			code = DisplayServer.clipboard_get()
	if code.strip_edges() == "":
		toast("Copy a progress code first, then press IMPORT", Color(1.0, 0.75, 0.5))
		return false
	var data := SaveFile.parse_code(code)
	if data.is_empty():
		toast("That is not a whole progress code", Color(1.0, 0.6, 0.5))
		return false
	# The code comes in as its own player, next to the ones already here.
	var pc := ConfigFile.new()
	SaveFile.apply_code(pc, data)
	_save_settings()
	_flush_save()
	var id := _new_profile_id()
	DirAccess.make_dir_recursive_absolute(PROFILE_DIR)
	SaveFile.write(pc, profile_path(id))
	switch_profile(id, false)
	toast("Imported %s: level %d, %d gold" % [player_name(), account_level(), account_gold], Color(0.6, 1.0, 0.55))
	return true


# --- Player profiles (save_file.gd) ---------------------------------------------

func profile_path(id: String) -> String:
	return "%s/%s.cfg" % [PROFILE_DIR, id]


func player_name() -> String:
	return hero_name if hero_name.strip_edges() != "" else "Unnamed Hero"


func _new_profile_id() -> String:
	var n := 1
	while FileAccess.file_exists(profile_path("p%d" % n)):
		n += 1
	return "p%d" % n


func _ensure_profile() -> void:
	## Every save belongs to a named player. A device with no player yet
	## makes one from what it has (an older save keeps its progress); a first
	## launch then asks for a name on the title.
	if profile_id == "" or not FileAccess.file_exists(profile_path(profile_id)):
		profile_id = _new_profile_id() if profile_id == "" else profile_id
		_save_settings()
		_flush_save()
	# Only on a plain launch: renders and tests start with their own flags.
	needs_name = hero_name.strip_edges() == "" and OS.get_cmdline_user_args().is_empty() and DisplayServer.get_name() != "headless"


func list_profiles() -> Array:
	## Every player on this device: [{id, name, xp, gold}], oldest first.
	_flush_save()
	var out: Array = []
	var d := DirAccess.open(PROFILE_DIR)
	if d == null:
		return out
	for f in d.get_files():
		if not f.ends_with(".cfg"):
			continue
		var id := f.trim_suffix(".cfg")
		var pc := ConfigFile.new()
		if SaveFile.read(pc, profile_path(id)) == OK:
			out.append({"id": id, "name": str(pc.get_value("settings", "hero_name", "")),
				"xp": int(pc.get_value("profile", "account_xp", 0)), "gold": int(pc.get_value("profile", "account_gold", 0))})
	out.sort_custom(func(a, b): return a.id.naturalnocasecmp_to(b.id) < 0)
	return out


func switch_profile(id: String, announce := true) -> void:
	## Saves the player playing now, then loads `id`'s level, gold, items and look.
	if id == profile_id or not FileAccess.file_exists(profile_path(id)):
		return
	_save_settings()
	_flush_save()
	profile_id = id
	var cfg := ConfigFile.new()
	_read_save(cfg)
	cfg.set_value("profiles", "current", id)
	SaveFile.write(cfg, CONTROLS_PATH)
	_load_controls()
	_save_settings()
	if announce:
		toast("Playing as %s" % player_name(), Color(0.6, 1.0, 0.55))


func new_profile(name: String) -> String:
	## A new player starting from nothing (level 1, no gold or items, the
	## default look); they become the one playing.
	_save_settings()
	_flush_save()
	var id := _new_profile_id()
	var pc := ConfigFile.new()
	pc.set_value("settings", "hero_name", name.strip_edges().left(Stats.HERO_NAME_MAX))
	for k in ["account_xp", "account_gold", "account_shards", "account_chests"]:
		pc.set_value("profile", k, 0)
	pc.set_value("profile", "owned_items", [])
	DirAccess.make_dir_recursive_absolute(PROFILE_DIR)
	SaveFile.write(pc, profile_path(id))
	switch_profile(id, false)
	return id


func delete_profile(id: String) -> bool:
	## Removes another player from this device (never the one playing).
	if id == profile_id or not FileAccess.file_exists(profile_path(id)):
		return false
	for p in [profile_path(id), profile_path(id) + ".bak"]:
		DirAccess.remove_absolute(p)
	return true


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	_read_save(cfg)
	_write_control_bindings(cfg)  # migration and schema are one save transaction
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
	cfg.set_value("settings", "vsync", vsync_on)
	cfg.set_value("settings", "fps_cap", fps_cap)
	cfg.set_value("settings", "render_scale", render_scale)
	cfg.set_value("settings", "gfx_quality", gfx_quality)
	cfg.set_value("settings", "gfx_picked", gfx_picked)
	cfg.set_value("settings", "fps_intro_done", fps_intro_done)
	cfg.set_value("settings", "howto_seen", howto_seen)
	cfg.set_value("settings", "fullscreen", fullscreen)
	cfg.set_value("settings", "window_mode", window_mode)
	cfg.set_value("settings", "rumble", rumble_on)
	cfg.set_value("settings", "pad_style", pad_style)
	cfg.set_value("settings", "control_layout", control_layout)
	cfg.set_value("settings", "move_mode", "screen")
	cfg.set_value("settings", "movement_schema", 1)
	cfg.set_value("settings", "pc_movement", pc_movement)
	cfg.set_value("settings", "combine_move_attack", combine_move_attack)
	cfg.set_value("settings", "wheel_zoom", wheel_zoom)
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
	cfg.set_value("settings", "hero_hair_style", hero_hair_style)
	cfg.set_value("settings", "hero_eye", hero_eye)
	cfg.set_value("settings", "hero_mark", hero_mark)
	cfg.set_value("settings", "hero_body", hero_body)
	cfg.set_value("settings", "team_size", team_size)
	cfg.set_value("settings", "split_screen", split_screen)
	cfg.set_value("settings", "split_layout", split_layout)
	cfg.set_value("profile", "account_xp", account_xp)
	cfg.set_value("profile", "account_gold", account_gold)
	cfg.set_value("profile", "account_shards", account_shards)
	cfg.set_value("profile", "account_chests", account_chests)
	cfg.set_value("profile", "owned_items", owned_items)
	cfg.set_value("profile", "legend_seen", legend_seen)
	cfg.set_value("profile", "legend_sides", legend_sides)
	cfg.set_value("profile", "legend_classes", legend_classes)
	cfg.set_value("settings", "hero_hat", hero_hat)
	cfg.set_value("settings", "hero_cape", hero_cape)
	cfg.set_value("settings", "hero_outfit", hero_outfit)
	cfg.set_value("settings", "hero_weapon", hero_weapon)
	if profile_id != "":
		cfg.set_value("profiles", "current", profile_id)
	if hero_name.strip_edges() != "":
		needs_name = false
	if _write_save(cfg) == OK:
		saved_at = Time.get_ticks_msec() / 1000.0


# The save is written on a worker thread: the menus save on every click,
# and the write (a temp file, read back, a backup copy, a rename) stalled
# the frame on Windows (Faisal 2026-10-10: "stuttering ... doing simple
# things"). Reads wait for a write in flight. Static, so a scene reload
# (after a match) still waits for the old scene's write.
static var _save_task := -1


static func _flush_save() -> void:
	if _save_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_save_task)
		_save_task = -1


func _read_save(cfg: ConfigFile) -> Error:
	_flush_save()
	return SaveFile.read(cfg, CONTROLS_PATH)


func _write_save(cfg: ConfigFile) -> Error:
	## Writes controls.cfg and the current player's profile file.
	_flush_save()
	var files := [[cfg, CONTROLS_PATH]]
	if profile_id != "":
		DirAccess.make_dir_recursive_absolute(PROFILE_DIR)
		files.append([SaveFile.profile_of(cfg), profile_path(profile_id)])
	if DisplayServer.get_name() == "headless" or OS.has_feature("web"):
		# Tests read the file straight back; a browser build has no worker
		# threads (and writes to its own storage, fast).
		var err := OK
		for f in files:
			var e: Error = SaveFile.write(f[0], f[1])
			if e != OK:
				err = e
		return err
	var texts := []
	for f in files:
		texts.append([f[0].encode_to_text(), f[1]])
	_save_task = WorkerThreadPool.add_task(func():
		for t in texts:
			var c := ConfigFile.new()
			if c.parse(t[0]) == OK:
				SaveFile.write(c, t[1]))
	return OK


func _save_controls() -> void:
	var cfg := ConfigFile.new()
	_read_save(cfg)
	_write_control_bindings(cfg)
	cfg.set_value("settings", "movement_schema", 1)
	_write_save(cfg)


func _write_control_bindings(cfg: ConfigFile) -> void:
	for entry in REBINDABLE:
		var list: Array = []
		for ev in InputMap.action_get_events(entry[0]):
			if ev is InputEventKey:
				list.append({"t": "key", "c": ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode})
			elif ev is InputEventMouseButton:
				list.append({"t": "mouse", "c": ev.button_index})
			elif ev is InputEventJoypadButton:
				list.append({"t": "pad", "c": ev.button_index})
			elif _is_trigger(ev):
				list.append({"t": "axis", "c": ev.axis})
		cfg.set_value("controls", entry[0], list)
	cfg.set_value("settings", "bindings_axes", 1)   # this save lists the triggers too
func _load_controls() -> void:
	var cfg := ConfigFile.new()
	if _read_save(cfg) != OK:
		return
	# The player playing now: their own file holds their progress and looks.
	profile_id = str(cfg.get_value("profiles", "current", ""))
	if profile_id != "":
		var pc := ConfigFile.new()
		if SaveFile.read(pc, profile_path(profile_id)) == OK:
			SaveFile.use_profile(cfg, pc)
	var diff: String = cfg.get_value("settings", "bot_difficulty", "Normal")
	if diff in Stats.BOT_DIFFICULTIES:
		bot_difficulty = diff
	chat_visible = cfg.get_value("settings", "chat_visible", true)
	rosters_visible = cfg.get_value("settings", "rosters_shown", false)
	couch_players = 1  # extra players join each session in the Ready Up lobby
	couch_mode = "coop" if cfg.get_value("settings", "couch_mode", "versus") == "coop" else "versus"
	screen_shake = cfg.get_value("settings", "screen_shake", true)
	damage_numbers = cfg.get_value("settings", "damage_numbers", true)
	show_fps = cfg.get_value("settings", "show_fps", OS.has_feature("web"))
	vsync_on = cfg.get_value("settings", "vsync", true)
	fps_cap = int(cfg.get_value("settings", "fps_cap", 0))
	render_scale = float(cfg.get_value("settings", "render_scale", 1.0))
	if not RENDER_SCALES.has(render_scale):
		render_scale = 1.0
	if fps_cap not in FPS_CAPS:
		fps_cap = 0
	fps_intro_done = cfg.get_value("settings", "fps_intro_done", false)
	howto_seen = cfg.get_value("settings", "howto_seen", false)
	gfx_quality = clampi(int(cfg.get_value("settings", "gfx_quality", 2)), 0, GFX_NAMES.size() - 1)
	gfx_picked = cfg.get_value("settings", "gfx_picked", false)
	if OS.has_feature("web"):
		# Browsers (and tablets) start on Medium unless the player picked a
		# preset (older visits saved the old Low default).
		gfx_quality = mini(gfx_quality, 1) if gfx_picked else 1
	fullscreen = cfg.get_value("settings", "fullscreen", false)
	window_mode = str(cfg.get_value("settings", "window_mode", "borderless" if fullscreen else "windowed"))
	if window_mode not in WINDOW_MODES:
		window_mode = "borderless" if fullscreen else "windowed"
	fullscreen = window_mode != "windowed"
	rumble_on = cfg.get_value("settings", "rumble", true)
	pad_style = cfg.get_value("settings", "pad_style", "auto")
	control_layout = cfg.get_value("settings", "control_layout", "auto")
	move_mode = "screen"  # owner-confirmed camera-relative axes supersede the old aim-relative default
	pc_movement = str(cfg.get_value("settings", "pc_movement", "click"))
	if pc_movement not in ["click", "wasd"]:
		pc_movement = "click"
	combine_move_attack = bool(cfg.get_value("settings", "combine_move_attack", false))
	wheel_zoom = bool(cfg.get_value("settings", "wheel_zoom", false))
	if control_layout not in CONTROL_LAYOUTS:
		control_layout = "auto"
	apply_control_layout()
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
	hero_hair_style = clampi(cfg.get_value("settings", "hero_hair_style", 0), 0, Stats.HERO_HAIR_STYLES.size() - 1)
	hero_eye = clampi(cfg.get_value("settings", "hero_eye", -1), -1, Stats.HERO_EYES.size() - 1)
	hero_mark = clampi(cfg.get_value("settings", "hero_mark", 0), 0, Stats.HERO_MARKS.size() - 1)
	hero_body = clampi(cfg.get_value("settings", "hero_body", 0), 0, Stats.HERO_BODIES.size() - 1)
	team_size = TEAM_SIZE   # 4v4 only for now: an older saved team size is ignored
	split_screen = cfg.get_value("settings", "split_screen", false)
	split_layout = "horizontal" if cfg.get_value("settings", "split_layout", "vertical") == "horizontal" else "vertical"
	account_xp = maxi(int(cfg.get_value("profile", "account_xp", 0)), 0)
	account_gold = maxi(int(cfg.get_value("profile", "account_gold", 0)), 0)
	account_shards = maxi(int(cfg.get_value("profile", "account_shards", 0)), 0)
	account_chests = maxi(int(cfg.get_value("profile", "account_chests", 0)), 0)
	var owned = cfg.get_value("profile", "owned_items", [])
	owned_items = Array(owned) if owned is Array or owned is PackedStringArray else []
	legend_seen = bool(cfg.get_value("profile", "legend_seen", false))
	legend_sides = _counts(cfg.get_value("profile", "legend_sides", []), 2)
	legend_classes = _counts(cfg.get_value("profile", "legend_classes", []), 7)
	hero_hat = clampi(int(cfg.get_value("settings", "hero_hat", 0)), 0, Stats.HERO_HATS.size() - 1)
	hero_cape = clampi(int(cfg.get_value("settings", "hero_cape", 0)), 0, Stats.HERO_CAPES.size() - 1)
	hero_outfit = clampi(int(cfg.get_value("settings", "hero_outfit", 0)), 0, Stats.HERO_OUTFITS.size() - 1)
	hero_weapon = clampi(int(cfg.get_value("settings", "hero_weapon", 0)), 0, Stats.WEAPON_SKINS.size() - 1)
	Store.drop_unowned(self)   # a save edited by hand cannot wear what was never bought
	var axes_saved: bool = int(cfg.get_value("settings", "bindings_axes", 0)) >= 1
	for entry in REBINDABLE:
		if not cfg.has_section_key("controls", entry[0]):
			continue
		for ev in InputMap.action_get_events(entry[0]):
			# Saves from before triggers were written keep the default triggers.
			if ev is InputEventKey or ev is InputEventMouseButton or ev is InputEventJoypadButton or (axes_saved and _is_trigger(ev)):
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
				"axis":
					ev = InputEventJoypadMotion.new()
					ev.axis = int(item.c)
					ev.axis_value = 1.0
			if ev:
				InputMap.action_add_event(entry[0], ev)


	# Migrate only conflicting legacy defaults in memory; never erase the account
	# or unrelated remaps. Saving remains the existing explicit settings path.
	if int(cfg.get_value("settings", "movement_schema", 0)) < 1:
		for ev in InputMap.action_get_events("attack"):
			if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
				InputMap.action_erase_event("attack", ev)
		for ev in InputMap.action_get_events("block"):
			if ev is InputEventKey and ev.physical_keycode == KEY_SHIFT:
				InputMap.action_erase_event("block", ev)


func _reset_controls() -> void:
	for entry in REBINDABLE:
		if InputMap.has_action(entry[0]):
			InputMap.erase_action(entry[0])
	_setup_input()
	# Only the key bindings go back to default: the file also holds the
	# settings and the account's progress (this used to delete it all).
	var cfg := ConfigFile.new()
	if _read_save(cfg) == OK and cfg.has_section("controls"):
		cfg.erase_section("controls")
		SaveFile.write(cfg, CONTROLS_PATH)
	rebinding = ""


# --- World -----------------------------------------------------------------

func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	return mat


# Textured materials (ambientCG, CC0). Triplanar mapping means boxes of any
# size tile cleanly without UV work. One tile every 1/scale metres.
func _pbr(prefix: String, scale: float, tint: Color = Color.WHITE, ext: String = "jpg") -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	# A swapped texture is already dark and cool, so it takes only a light soot.
	var dim: Color = swap_dim if tex_swap.has(prefix) else soot
	# The match world's style copy of the texture (scripts/visual/style_profile.gd);
	# the menus, built with world_style off, keep the originals.
	var style: Dictionary = StyleProfile.TEX.get(prefix, {}) if world_style and not tex_swap.has(prefix) and ext == "jpg" else {}
	prefix = tex_swap.get(prefix, prefix)
	var dir := StyleProfile.TEX_DIR if not style.is_empty() else "res://assets/textures/"
	mat.albedo_texture = load("%s%s_color.%s" % [dir, prefix, ext])
	mat.albedo_color = tint * dim
	mat.normal_enabled = true
	mat.normal_texture = load("%s%s_normal.jpg" % [dir, prefix])
	mat.roughness = 0.85
	if not style.is_empty():
		mat.normal_scale = style.normal
		mat.roughness = style.rough
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3.ONE * scale
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return mat


func _stone(tint: Color = Color.WHITE, scale: float = 0.26) -> StandardMaterial3D:
	return _pbr("stone", scale, tint)


func _grass() -> StandardMaterial3D:
	# The match meadow is lighter and warmer (StyleProfile.GRASS_TINT); a
	# swapped texture (Stonekeep's snow) and the menus keep their own.
	return _pbr("grass", 0.11, StyleProfile.GRASS_TINT if world_style and not tex_swap.has("grass") else Color.WHITE)


const PATH_SHADER := """
shader_type spatial;
// Cobbles in dirt, projected straight down in world space. With fray on, the
// edge of the path frays into the meadow a whole stone at a time: the stones
// map (tools/make_textures.py) gives each pixel the way to its stone's centre
// and that stone's own random value, so a stone is kept or dropped by where
// its centre lies across the path, and the dirt only fills joints between
// the inner stones; everywhere else the grass below shows through.
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D stones_tex : filter_nearest, repeat_enable;
uniform float scale = 0.2;
uniform bool fray = false;
uniform float half_w = 2.0;   // per material: the Compatibility renderer (web) has no instance uniforms
uniform float end_x = 0.0;     // >0: the road ends here (local x): its last stones fray out one at a time past it
uniform bool radial = false;  // a round plaza: the distance is the radius, not the way across a strip
varying vec3 wpos;
varying float lz;
varying vec2 lxz;
varying vec3 side;
varying vec3 axis_x;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	axis_x = normalize(MODEL_MATRIX[0].xyz);
	lz = VERTEX.z;
	lxz = VERTEX.xz;
	side = normalize(MODEL_MATRIX[2].xyz);
}

void fragment() {
	vec2 uv = wpos.xz * scale;
	if (fray || end_x > 0.0) {
		vec4 s = texture(stones_tex, uv);
		// The stone's centre texel (found from this pixel's way-to-centre, then snapped to
		// the texture's own grid), so every pixel of a stone reaches the same distance d:
		// per-pixel rounding of the stored vector put pixels of edge stones either side of
		// the cut, which punched dotted holes in them.
		vec2 uvc = uv + (s.rg - 0.5) * 0.5;
		vec2 tc = (floor(uvc * 1024.0) + 0.5) / 1024.0;
		vec4 sc = texture(stones_tex, tc);
		tc = (floor((tc + (sc.rg - 0.5) * 0.5) * 1024.0) + 0.5) / 1024.0;   // (a second step settles on the centre texel)
		sc = texture(stones_tex, tc);
		vec2 to_c = (tc - uv) / scale;
		float d = abs(lz + dot(vec3(to_c.x, 0.0, to_c.y), side));
		if (radial) {
			d = length(lxz + to_c);
		}
		float inner = half_w - 0.5;
		bool kept = sc.a > 0.5 ? d < inner + 0.2 * sc.b : d < inner;
		if (!fray) {
			kept = true;
		}
		if (end_x > 0.0) {
			float lxc = lxz.x + dot(vec2(to_c.x, to_c.y), axis_x.xz);
			kept = kept && lxc < end_x - 0.3 + 1.3 * sc.b;
		}
		if (!kept) {
			discard;
		}
	}
	ALBEDO = texture(albedo_tex, uv).rgb;
	vec3 n = texture(normal_tex, uv).rgb * 2.0 - 1.0;
	NORMAL = normalize((VIEW_MATRIX * vec4(n.x, n.z, -n.y, 0.0)).xyz);
	ROUGHNESS = 0.85;
}
"""

# The soft verge under a cobbled road (claude-faisal/crowns-grass 2026-11-01):
# the meadow's own grass and tint, faded out toward the rim of the strip with
# a noise-broken edge, so no rectangle shows on the ground beside the road.
const VERGE_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, specular_disabled;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec2 half_ext = vec2(4.0, 2.0);
uniform float scale = 0.11;
varying vec3 wpos;
varying vec2 lxz;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	lxz = VERTEX.xz;
}

void fragment() {
	vec2 q = half_ext - abs(lxz);
	float e = min(q.x, q.y);
	float n = texture(noise_tex, wpos.xz * 0.23).r - 0.5;
	float a = smoothstep(0.0, 1.7, e + n * 1.6);
	ALBEDO = texture(albedo_tex, wpos.xz * scale).rgb * tint.rgb;
	ALPHA = a * 0.55;
	ROUGHNESS = 0.9;
}
"""

# The Stonekeep ruin's courtyard floor (claude-faisal/crowns-grass 2026-11-01): the
# flagstone texture's own heavy joints drew a flat square grid with crossed cracks, so
# the floor is the texture's average colour laid as irregular slabs instead: a jittered
# cell pattern in world space (no repeating grid), each slab its own tone, with soft
# low-contrast joints and slow worn patches.
const UNEVEN_FLAGS_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, diffuse_lambert_wrap, specular_disabled;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform vec4 base : source_color = vec4(0.5);
uniform float cell = 0.42;
uniform vec2 center = vec2(0.0);
uniform vec2 half_ext = vec2(1000.0);   // the slab's half size: its rim frays into the snow instead of a straight cut
varying vec3 wpos;
varying vec2 lxz;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 hash2(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	lxz = wpos.xz - center;   // (world space: the static batch bakes the box into world coordinates)
}

void fragment() {
	vec2 q = half_ext - abs(lxz);
	float rim = min(q.x, q.y) + (texture(noise_tex, wpos.xz * 0.31).r - 0.5) * 1.6;
	ALPHA = smoothstep(0.0, 1.1, rim);
	vec2 p = wpos.xz * cell + 0.7 * (texture(noise_tex, wpos.xz * 0.05).rg - 0.5);
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	vec2 id = vec2(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = 0.5 + 0.26 * (hash2(i + g) * 2.0 - 1.0);
			vec2 r = g + o - f;
			float d = dot(r, r);
			if (d < d1) {
				d2 = d1;
				d1 = d;
				id = i + g;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	float edge = sqrt(d2) - sqrt(d1);
	float joint = smoothstep(0.02, 0.16, edge);
	float tone = 0.86 + 0.28 * hash(id);
	float worn = texture(noise_tex, wpos.xz * 0.043 + 0.2).r;
	float mott = texture(noise_tex, wpos.xz * 0.21).r;
	vec3 c = base.rgb * tone * (0.9 + 0.2 * smoothstep(0.3, 0.7, worn)) * (0.94 + 0.12 * mott);
	c *= mix(0.74, 1.0, joint);
	ALBEDO = c;
	ROUGHNESS = 0.9;
}
"""

var path_shader: Shader
var verge_shader: Shader
var flags_shader: Shader
var world_style := false   # while the match world is built: builders use scripts/visual/style_profile.gd
var style_live := false    # the match is on: the style's light grade replaces the menus' light
var style_cache := {}      # shared, never-mutated world materials (bark, glow buds), by key


func _stones(loose: bool = false, fray: bool = false) -> ShaderMaterial:
	## Warm tan cobbles set in dark brown dirt (the paths). Without fray the
	## material is opaque, dirt and all: the middle of a path. The frayed one
	## (see PATH_SHADER) is carried on the middle one as meta "fray", and
	## _add_path lays it in a wider strip underneath so the edges break up
	## into single stones in the grass.
	if path_shader == null:
		path_shader = Shader.new()
		path_shader.code = PATH_SHADER
	var name := "path_loose" if loose else "path"
	# The style copy: stones half the size (about 0.6 m), turf in the joints.
	var dir := StyleProfile.TEX_DIR if world_style else "res://assets/textures/"
	var mat := ShaderMaterial.new()
	mat.shader = path_shader
	mat.set_shader_parameter("albedo_tex", load("%s%s_color.png" % [dir, name]))
	mat.set_shader_parameter("normal_tex", load("%s%s_normal.jpg" % [dir, name]))
	mat.set_shader_parameter("stones_tex", load("%s%s_stones.png" % [dir, name]))
	mat.set_shader_parameter("scale", 0.26 if loose else 0.2)
	mat.set_shader_parameter("fray", fray)
	if not fray:
		mat.set_meta("fray", _stones(loose, true))
	return mat


var verge_mat: StandardMaterial3D


func _soft_verge(half_ext: Vector2) -> ShaderMaterial:
	## The meadow's own grass, faded out toward the strip's rim (VERGE_SHADER).
	if verge_shader == null:
		verge_shader = Shader.new()
		verge_shader.code = VERGE_SHADER
	var g := _grass()
	var m := ShaderMaterial.new()
	m.shader = verge_shader
	m.set_shader_parameter("albedo_tex", g.albedo_texture)
	m.set_shader_parameter("noise_tex", load("res://assets/textures/water_noise.png"))
	m.set_shader_parameter("tint", g.albedo_color * Color(0.96, 0.92, 0.8))
	m.set_shader_parameter("half_ext", half_ext)
	m.set_shader_parameter("scale", 0.11)
	return m


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


# Retain PackedScenes during one build, so repeated props do not reopen the
# scene file. Keep this per world: Season.grade mutates shared mesh materials.
var prop_scenes := {}


func _prop(name: String, pos: Vector3, scale: float = 1.0, rot_y: float = 0.0) -> Node3D:
	## Places a KayKit model (CC0). `name` is "hex/tree_single_A",
	## "dungeon/banner_green" or "gear/staff" under assets/props.
	var ext := ".glb" if name.begins_with("dungeon/") else ".gltf"
	var path := "res://assets/props/%s%s" % [name, ext]
	if not prop_scenes.has(path):
		prop_scenes[path] = load(path)
	var scene: PackedScene = prop_scenes[path]
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


func _add_path(from: Vector3, to: Vector3, width: float, mat: Material, verge: float = 1.6, frayed_end: bool = false) -> void:
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
		v.material_override = _soft_verge(Vector2(vbox.size.x, vbox.size.z) * 0.5)
		v.position = (from + to) / 2.0 + Vector3(0, 0.003, 0)
		v.rotation.y = atan2(-d.z, d.x)
		add_child(v)
	var length := d.length() + width * 0.6
	var mid := (from + to) / 2.0
	var rot := atan2(-d.z, d.x)
	var core_w := width
	if mat.has_meta("fray"):
		# Cobbled paths fray into the meadow: an opaque middle (stones in
		# dirt) over a wider strip that keeps fewer stones the further out
		# their centres lie (PATH_SHADER). The wide strip sits a hair lower,
		# so the middle hides it and, where paths cross, a middle wins.
		core_w = maxf(width - 2.3, 0.6)
		var e := MeshInstance3D.new()
		var ebox := BoxMesh.new()
		ebox.size = Vector3(length, 0.01, width + 2.6)
		e.mesh = ebox
		var fm: ShaderMaterial = mat.get_meta("fray").duplicate()
		fm.set_shader_parameter("half_w", width / 2.0)
		if frayed_end:
			fm.set_shader_parameter("end_x", d.length() / 2.0)
		e.material_override = fm
		# Each path sits a millimetre above the one before (four steps), so
		# where two paths' frayed strips overlap they don't z-fight into a
		# green speckle (Faisal 2026-10-09 08:16, "what is this texture bug?").
		e.position = mid + Vector3(0, 0.003 + 0.002 * float(map_paths.size() % 4), 0)   # (2 mm steps: 1 mm z-fought into hatched stones where two roads' rims overlap)
		e.rotation.y = rot
		add_child(e)
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(length, 0.012, core_w)
	m.mesh = box
	if frayed_end:
		var cm2: ShaderMaterial = mat.duplicate()
		cm2.set_shader_parameter("end_x", d.length() / 2.0)
		cm2.set_shader_parameter("half_w", width / 2.0)
		m.material_override = cm2
	else:
		m.material_override = mat
	m.position = mid + Vector3(0, 0.012 + 0.002 * float(map_paths.size() % 4), 0)   # every core above every frayed strip   # every core above every frayed strip
	m.rotation.y = rot
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
	_fill_under_ramp(from, to, width)


func _fill_under_ramp(from: Vector3, to: Vector3, width: float) -> void:
	## The slab is thin: the wedge of space under a flight of stairs was open,
	## too low to stand in near the foot, and anyone who walked or was shoved
	## in there wedged under the sloping underside (Faisal 2026-10-15: "fix
	## the getting stuck indoors"). A solid wedge (collision only, nothing
	## drawn) fills it; its top is the slab's own walking surface.
	var low := from if from.y <= to.y else to
	var high := to if from.y <= to.y else from
	var flat := Vector3(high.x - low.x, 0, high.z - low.z)
	if flat.length() < 0.1 or high.y - low.y < 0.3:
		return
	var perp := flat.normalized().cross(Vector3.UP) * (width / 2.0)
	var base := Vector3(high.x, low.y, high.z)
	var pts := PackedVector3Array()
	for s in [-1.0, 1.0]:
		pts.append(low + perp * s)
		pts.append(high + perp * s)
		pts.append(base + perp * s)
	var wedge := ConvexPolygonShape3D.new()
	wedge.points = pts
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = wedge
	body.add_child(shape)
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
	# (No mossy cap: it poked through the rock as flat green patches, Faisal 08:20.)
	add_child(body)
	# A few pebbles around the base.
	for i in 3:
		var ang := TAU * i / 3.0 + pos.x
		var pp := pos + Vector3(cos(ang) * 1.7, 0, sin(ang) * 1.7)
		var reserved := false
		for rp in RESERVED_GROUND:
			if _flat_dist(pp, rp) < 6.0:
				reserved = true   # the barrow's fence and the mills stand there later
		if reserved:
			continue
		_prop("hex/rock_single_%s" % ["A", "B", "C", "D", "E"][absi(int(pos.x * 7 + pos.z) + i) % 5], pp, 4.0, ang)


func _add_ground_detail() -> void:
	## Life on the ground, kept off the lanes: flowers, grass tufts, small
	## stones, mushrooms under the trees and fallen leaves. Elven ground
	## (west) gets glowing blooms and mushrooms; human ground (east) gets
	## stones, leaf litter and plain wildflowers. All MultiMeshes.
	## Style pass (2026-10-14): flowers and tufts grow in patches with open
	## lawn between them (a noise field picks where), tufts sit a shade under
	## the meadow instead of reading as dark blades, and every set is cut
	## into DETAIL_CHUNK cells so the renderer culls what the camera (each
	## split-screen camera on its own) cannot see. Purely decorative: no
	## colliders, its own random generator.
	var r := RandomNumberGenerator.new()
	r.seed = 1234
	var patch := FastNoiseLite.new()
	patch.seed = 77
	patch.frequency = StyleProfile.PATCH_FREQ
	var flower := _petal_mesh()
	var tuft := _tuft_mesh()
	var stone := _rock_mesh(77, 0.26, 0.25)
	var cap := CylinderMesh.new()
	cap.top_radius = 0.08
	cap.bottom_radius = 0.17
	cap.height = 0.12
	cap.radial_segments = 7
	var leaf := PlaneMesh.new()
	leaf.size = Vector2(0.34, 0.26)
	var sets := [
		["flower", flower, StyleProfile.FLOWERS if season != "winter" else 0, 0.4], ["tuft", tuft, StyleProfile.TUFTS, 0.0], ["stone", stone, 50, 0.0],
		["cap", cap, 80 if season != "twilight" else 240, 0.26], ["leaf", leaf, 140 if season != "winter" else 0, 0.02]]
	for s in sets:
		await _world_build_frame()   # (built behind the menus: no long frame)
		var placed: Array = []
		var tries := 0
		while placed.size() < s[2] and tries < s[2] * 12:
			tries += 1
			if tries % 32 == 0:
				# (A whole set's tries in one slice was a 290 ms title hitch:
				# _open_ground walks every path, mark and tree.)
				await _world_build_frame()
			var p: Vector3
			if s[0] == "leaf" or s[0] == "cap":
				var t: Vector3 = map_trees[r.randi() % map_trees.size()]
				var a := r.randf() * TAU
				var d := r.randf_range(0.8, 3.2)
				p = Vector3(t.x + cos(a) * d, 0, t.z + sin(a) * d)
			else:
				p = Vector3(r.randf_range(-map_half.x + 4.0, map_half.x - 4.0), 0, r.randf_range(-map_half.y + 2.0, map_half.y - 2.0))
				var n := patch.get_noise_2d(p.x, p.z)
				if s[0] == "flower" and n < StyleProfile.FLOWER_PATCH:
					continue
				if s[0] == "tuft" and n < StyleProfile.TUFT_PATCH and r.randf() < 0.75:
					continue
			if not _open_ground(p):
				continue
			placed.append(p)
		var xforms: Array = []
		var cols: Array = []
		for i in placed.size():
			var p: Vector3 = placed[i]
			var elf_side: bool = p.x < 0.0
			var sc := r.randf_range(0.7, 1.3)
			var basis := Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3(sc, sc * r.randf_range(0.8, 1.2), sc))
			var col: Color
			match s[0]:
				"flower":
					# Cartoon blooms: flat five-petal heads tipped towards the camera.
					basis = Basis(Vector3.RIGHT, deg_to_rad(35.0)) * Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3.ONE * sc)
					# The style guide's meadow: warm yellows, pinks and violets
					# among white daisies and cornflowers, each patch mixed.
					col = [Color(1.0, 0.98, 0.92), Color(1.0, 0.98, 0.92), Color(1.0, 0.86, 0.25), Color(1.0, 0.86, 0.25), Color(0.36, 0.52, 1.0),
						Color(0.36, 0.52, 1.0), Color(1.0, 0.56, 0.78), Color(1.0, 0.56, 0.78), Color(0.72, 0.5, 1.0), Color(0.98, 0.36, 0.3)][r.randi() % 10]
					if (elf_side and r.randf() < 0.12) or (season == "twilight" and r.randf() < 0.35):
						col = Color(0.45, 0.95, 1.0)  # glowing wildwood bloom (Twilight Grove: everywhere)
				"tuft":
					# A shade under the meadow, so the turf reads lush, not spiky.
					basis = basis.scaled(Vector3(1.4, 1.0, 1.4))
					var th := StyleProfile.TUFT_HSV
					col = Color.from_hsv(th.x + r.randf_range(-0.015, 0.015), th.y, th.z * r.randf_range(0.92, 1.08))
				"stone":
					col = Color(0.62, 0.61, 0.6).lerp(Color(0.5, 0.5, 0.5), r.randf())
					if elf_side and r.randf() < 0.3:
						col = Color(0.55, 0.62, 0.5)
				"cap":
					col = Color(0.85, 0.25, 0.2) if r.randf() < 0.6 else Color(0.8, 0.65, 0.45)
					if (elf_side and r.randf() < 0.4) or season == "twilight":
						col = Color(0.45, 0.85, 0.95)
				"leaf":
					col = [Color(0.8, 0.45, 0.15), Color(0.65, 0.3, 0.1), Color(0.85, 0.65, 0.2), Color(0.4, 0.55, 0.2)][r.randi() % 4]
			xforms.append(Transform3D(basis, p + Vector3(0, s[3], 0)))
			cols.append(col)
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.roughness = 0.9
		if s[0] == "flower" or s[0] == "tuft":
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		if s[0] == "flower" or s[0] == "cap":
			# A faint neutral lift so blooms stay bright in shade; the old
			# teal emission turned the white daisies blue.
			mat.emission_enabled = true
			mat.emission = Color(0.5, 0.5, 0.45)
			mat.emission_energy_multiplier = 0.18
		var parts := [[s[1], mat, xforms, cols]]
		if s[0] == "flower":
			# A golden eye on each bloom and a green stem under it.
			var eye := SphereMesh.new()
			eye.radius = 0.075
			eye.height = 0.07
			eye.radial_segments = 6
			eye.rings = 2
			var stem := CylinderMesh.new()
			stem.top_radius = 0.02
			stem.bottom_radius = 0.025
			stem.height = 0.4
			stem.radial_segments = 4
			stem.rings = 1
			var ex: Array = []
			var sx: Array = []
			for i in placed.size():
				var t: Transform3D = xforms[i]
				ex.append(Transform3D(t.basis, t.origin + t.basis.y * 0.02))
				sx.append(Transform3D(Basis.IDENTITY, placed[i] + Vector3(0, 0.2, 0)))
			parts.append([eye, _material(Color(1.0, 0.85, 0.25)), ex, []])
			parts.append([stem, _material(Color(0.3, 0.6, 0.18)), sx, []])
		if s[0] == "cap":
			# Stems under the caps.
			var stem := CylinderMesh.new()
			stem.top_radius = 0.05
			stem.bottom_radius = 0.06
			stem.height = 0.26
			stem.radial_segments = 5
			var sx: Array = []
			for i in placed.size():
				sx.append(Transform3D(Basis.IDENTITY, placed[i] + Vector3(0, 0.13, 0)))
			parts.append([stem, _material(Color(0.9, 0.86, 0.75)), sx, []])
		for part in parts:
			_add_detail_chunks(part[0], part[1], part[2], part[3])


func _add_detail_chunks(mesh: Mesh, mat: Material, xforms: Array, cols: Array) -> void:
	## One MultiMeshInstance per DETAIL_CHUNK cell (instances keep their
	## generation order inside each cell), so off-screen ground detail is
	## culled per cell instead of drawing the whole map's every frame. The
	## cell's bounds come from its instances; a margin covers their size.
	var cells := {}
	for i in xforms.size():
		var o: Vector3 = xforms[i].origin
		var key := Vector2i(floori(o.x / StyleProfile.DETAIL_CHUNK), floori(o.z / StyleProfile.DETAIL_CHUNK))
		if not cells.has(key):
			cells[key] = []
		cells[key].append(i)
	for key in cells:
		var idx: Array = cells[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = not cols.is_empty()
		mm.mesh = mesh
		mm.instance_count = idx.size()
		for k in idx.size():
			mm.set_instance_transform(k, xforms[idx[k]])
			if not cols.is_empty():
				mm.set_instance_color(k, cols[idx[k]])
		var inst := MultiMeshInstance3D.new()
		inst.multimesh = mm
		inst.material_override = mat
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(inst)


func _petal_mesh() -> ArrayMesh:
	## Five round, flat petals in a ring (one bloom head, tinted per instance).
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 5:
		var a := TAU * k / 5.0
		var c := Vector3(cos(a), 0, sin(a)) * 0.13
		var segs := 8
		for j in segs:
			var a0 := TAU * j / segs
			var a1 := TAU * (j + 1) / segs
			st.set_normal(Vector3.UP)
			st.add_vertex(c + Vector3(0, 0.01, 0))
			st.set_normal(Vector3.UP)
			st.add_vertex(c + Vector3(cos(a1), 0, sin(a1)) * 0.105)
			st.set_normal(Vector3.UP)
			st.add_vertex(c + Vector3(cos(a0), 0, sin(a0)) * 0.105)
	return StaticBatch.kept_mesh(st)


func _tuft_mesh() -> ArrayMesh:
	## A lush clump of seven tapering grass blades leaning outwards.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 7:
		var a := TAU * k / 7.0 + 0.4
		var out := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-out.z, 0, out.x) * 0.07
		var tip := out * (0.2 + 0.05 * (k % 3)) + Vector3(0, 0.55 - 0.07 * (k % 4), 0)
		var n := (out + Vector3.UP * 0.6).normalized()
		for v in [-side, tip, side, side, tip, -side]:
			st.set_normal(n)
			st.add_vertex(v)
	return StaticBatch.kept_mesh(st)


func _open_ground(p: Vector3) -> bool:
	## Grass that is not a lane: off the roads and paths, out of the river,
	## the island, the castles and their yards, and not inside a tree trunk.
	if lmap:
		if not lmap.walkable(p, 0.6) or lmap.in_flat(p):
			return false   # the layout's ridges and banks cover the rest (and the ruin's courtyard stays swept)
	elif absf(p.x) < RIVER_HALF + 1.4 or _flat_dist(p, Vector3.ZERO) < ISLAND_R + 1.5:
		return false
	if absf(p.x) > CASTLE_X - CASTLE_DEPTH - 8.0:
		return false   # a clear band of lawn before each castle (no flower litter up to the gate)
	for bz in BRIDGES:
		if lmap == null and absf(p.z - bz) < 4.5 and absf(p.x) < RIVER_HALF + 4.0:
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


func _near_path(p: Vector3, margin: float) -> bool:
	## True when p is within margin of the edge of any path or road.
	for path in map_paths:
		var a: Vector3 = path[0]
		var b: Vector3 = path[1]
		var ab := Vector2(b.x - a.x, b.z - a.z)
		var t := clampf(Vector2(p.x - a.x, p.z - a.z).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		var q := Vector2(a.x, a.z) + ab * t
		if Vector2(p.x, p.z).distance_to(q) < path[2] / 2.0 + margin:
			return true
	return false


func _tree_spot_ok(pos: Vector3, big: bool) -> bool:
	## Trees keep clear of each other's crowns, the roads and tracks, the
	## paved courts before the castle doors, and anything built (walls,
	## houses, fences), so no canopy pokes through a roof or blocks a way in.
	var crown := 2.6 if big else 2.1
	if lmap == null and (absf(pos.x) < RIVER_HALF + crown or _flat_dist(pos, Vector3.ZERO) < ISLAND_R + crown):
		return false
	for rp in RESERVED_GROUND:
		if lmap == null and _flat_dist(pos, rp) < 5.5:
			return false
	for t in map_trees:
		if _flat_dist(pos, t) < (5.4 if (big or t.y > 0.5) else 3.6):
			return false
	for ap in audit_props:
		var q: Vector3 = ap[1].position
		if absf(q.z) < 38.0 and Vector2(q.x - pos.x, q.z - pos.z).length() < crown + 0.9:
			return false
	if _near_path(pos, 1.2):
		return false
	var fxr := CASTLE_X - CASTLE_DEPTH
	for sx in [-1.0, 1.0]:
		if _flat_dist(pos, Vector3(sx * (fxr - 4.0), 0, 0)) < 4.4 + crown + 1.0:
			return false
	for blk in audit_blocks:
		var box: AABB = blk[1]
		if box.size.y < 0.3 or box.end.y < 0.3:
			continue  # floors, decals and the ground slabs
		if pos.x > box.position.x - crown and pos.x < box.end.x + crown and pos.z > box.position.z - crown and pos.z < box.end.z + crown:
			return false
	return true


func _add_tree(pos: Vector3, big: bool = false) -> void:
	if not _tree_spot_ok(pos, big):
		# Slide it a few metres to the nearest clear spot, or leave it out.
		var moved := false
		for d in [2.5, 4.0]:
			for k in 8:
				var q: Vector3 = pos + Vector3(cos(k * TAU / 8.0), 0, sin(k * TAU / 8.0)) * d
				if absf(q.z) < map_half.y - 1.0 and _tree_spot_ok(q, big):
					pos = q
					moved = true
					break
			if moved:
				break
		if not moved:
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
		var autumn_prop := _prop("halloween/tree_pine_%s_%s" % [["orange", "yellow"][tree_seed % 2], "large" if big else "medium"], pos + Vector3(0, 0.3, 0), 0.8 if big else 0.95, float(tree_seed))
		if _kit():
			autumn_prop.visible = false   # (kept, hidden, as below: later trees' spacing checks count it)
			_kit().tree_at(pos, big, "autumn")
		elif world_style:
			# The pack's flat-shaded cone read as another game's tree: in its
			# place (same spot, same collider, still counted for the spacing
			# checks) a layered pine like the rest of the wood, in autumn
			# orange or gold, from its own seed.
			autumn_prop.visible = false
			var ar := RandomNumberGenerator.new()
			ar.seed = tree_seed
			var atree := Node3D.new()
			atree.position = pos
			atree.rotation.y = ar.randf() * TAU
			add_child(atree)
			_add_pine(atree, ar, _tree_bark(), big, tree_seed % 2)
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
		# Deep green layered pines: the pack's pale cone and blob read flat
		# next to the 2026-10-08 target art.
		if _kit():
			_kit().tree_at(pos, big, "pine")
			return
		var r := RandomNumberGenerator.new()
		r.seed = tree_seed
		var tree := Node3D.new()
		tree.position = pos
		tree.rotation.y = r.randf() * TAU
		add_child(tree)
		_add_pine(tree, r, _tree_bark(), big)
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
	if _kit():
		# The forest kit draws the tree (same spot and collider); the
		# Wildwood's mushrooms and fireflies stay with it.
		var kit_pine: bool = pos.x < -8.0 and seed % 4 == 1
		_kit().tree_at(pos, big, "pine" if kit_pine else "broad")
		if pos.x < -8.0 and not kit_pine:
			if seed % 3 == 0:
				_add_mushrooms(pos + Vector3(0.9, 0, 0.4), seed)
		return
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var tree := Node3D.new()
	tree.position = pos
	tree.rotation.y = r.randf() * TAU
	add_child(tree)
	var bark := _tree_bark()
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
		var lavender: bool = seed % 8 == 0   # one blossom tree in eight, like the courtyard target
		# (The sun and the crown highlight brighten tops a lot, so these stay dark.)
		# Pink blossom (the courtyard target's cherry) or deep wildwood green.
		leaf.set_shader_parameter("top_color", Color.from_hsv(0.9, 0.5, 0.78) if lavender else Color.from_hsv(0.38, 0.75, 0.5))
		leaf.set_shader_parameter("bottom_color", Color.from_hsv(0.88, 0.7, 0.32) if lavender else Color.from_hsv(0.42, 0.85, 0.18))
		if world_style:   # the same crown ramp as every other tree, in the Wildwood's own hue
			var top: Vector3 = StyleProfile.BLOSSOM_TOP if lavender else StyleProfile.WILD_TOP
			var bottom: Vector3 = StyleProfile.BLOSSOM_BOTTOM if lavender else StyleProfile.WILD_BOTTOM
			leaf.set_shader_parameter("top_color", Color.from_hsv(top.x, top.y, top.z))
			leaf.set_shader_parameter("bottom_color", Color.from_hsv(bottom.x, bottom.y, bottom.z))
	var radius: float = (1.9 if big else 1.4) * r.randf_range(0.9, 1.1) * (1.25 if wild else 1.0)
	var base_y: float = trunk_h * 0.8
	# The crown: a dome of leaf clumps (a skirt of low clumps, a smaller ring
	# above and a top knot) on short boughs, shaded as one crown from dark
	# underneath to a sunlit top. It was four to six big blobs, each with its
	# own dark underside, which read as a pile of green balls.
	leaf.set_shader_parameter("world_gradient", true)
	leaf.set_shader_parameter("crown_base", pos.y + base_y - radius * 0.55)
	leaf.set_shader_parameter("height", radius * 1.9)
	var low := 6 if big else 5
	var mid := 4 if big else 3
	var spin := r.randf() * TAU
	var clumps := []   # [offset, size]
	for i in low:
		var a := spin + TAU * i / low + r.randf_range(-0.2, 0.2)
		clumps.append([Vector3(cos(a), 0, sin(a)) * radius * r.randf_range(0.6, 0.72) + Vector3(0, r.randf_range(-0.12, 0.1) * radius, 0), radius * r.randf_range(0.5, 0.6)])
	for i in mid:
		var a := spin + TAU * (i + 0.5) / mid + r.randf_range(-0.25, 0.25)
		clumps.append([Vector3(cos(a), 0, sin(a)) * radius * r.randf_range(0.3, 0.4) + Vector3(0, radius * r.randf_range(0.42, 0.52), 0), radius * r.randf_range(0.5, 0.58)])
	clumps.append([Vector3(r.randf_range(-0.1, 0.1), 0.85, r.randf_range(-0.1, 0.1)) * radius, radius * 0.5])
	for i in clumps.size():
		var blob := MeshInstance3D.new()
		blob.mesh = _rock_mesh(seed + i * 11, clumps[i][1], 0.14)
		blob.position = Vector3(0, base_y, 0) + clumps[i][0]
		blob.scale = Vector3(1.0, 0.82, 1.0)
		blob.material_override = leaf
		tree.add_child(blob)
	if world_style:
		_add_crown_clusters(tree, r, leaf, Vector3(0, base_y, 0), radius, 9 if big else 7)
	# Boughs from the trunk top out into the lower clumps.
	for i in 3:
		var off: Vector3 = clumps[i * low / 3][0] * 0.75
		var bough := MeshInstance3D.new()
		var bm := CylinderMesh.new()
		bm.top_radius = 0.06 if not big else 0.08
		bm.bottom_radius = 0.14 if not big else 0.18
		var reach := Vector3(off.x, maxf(off.y, 0.0) + radius * 0.25, off.z)
		bm.height = reach.length()
		bm.radial_segments = 5
		bough.mesh = bm
		bough.material_override = bark
		var mid_pt := Vector3(0, base_y - radius * 0.3, 0) + reach / 2.0
		bough.transform = Transform3D(Basis(Quaternion(Vector3.UP, reach.normalized())), mid_pt)
		tree.add_child(bough)
	if wild and seed % 3 == 0:
		_add_mushrooms(pos + Vector3(0.9, 0, 0.4), seed)
	if wild and seed % 4 == 1:
		_add_fireflies(pos + Vector3(0, 1.0, 0))
	# Glowing wildwood blossoms on every third tree, like the logo's.
	if (seed % 3 == 0 or pos.x < -8.0) and not autumn:
		var glow: StandardMaterial3D = style_cache.get("bud") if world_style else null
		if glow == null:
			glow = StandardMaterial3D.new()
			glow.albedo_color = Color(0.55, 0.85, 1.0)
			glow.emission_enabled = true
			glow.emission = Color(0.35, 0.75, 1.0)
			glow.emission_energy_multiplier = 3.0
			if world_style:
				# Decoration glows softly; the brighter glows are kept for crowns,
				# pickups and spells (style_profile.gd's emission budget).
				glow.emission_energy_multiplier = StyleProfile.DECOR_GLOW_MAX
				style_cache["bud"] = glow
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


func _add_crown_clusters(tree: Node3D, r: RandomNumberGenerator, leaf: Material, centre: Vector3, radius: float, count: int) -> void:
	## Picks Battle A / Spawn D (visual pass 2026-10-30): small leaf
	## clusters bulging out of a crown's surface, mostly round its shoulders
	## and top, so the silhouette breaks into many lobes instead of a few big
	## smooth blobs. The meshes are shared between trees (a dozen shapes per
	## size step) and merge into the crown's batch, so this adds geometry but
	## no draw calls. (It draws from its own generator: the trees' shapes and
	## places stay as they were.)
	var q := RandomNumberGenerator.new()
	q.seed = r.seed + 4099
	for i in count:
		var a := q.randf() * TAU
		var up := q.randf_range(0.05, 0.95)
		var dir := Vector3(cos(a) * (1.0 - up * 0.7), up, sin(a) * (1.0 - up * 0.7)).normalized()
		var cr := snappedf(radius * q.randf_range(0.26, 0.36), 0.05)
		var key := "%d|%.2f" % [q.randi() % 12, cr]
		if not leaf_clusters.has(key):
			leaf_clusters[key] = _rock_mesh(9100 + leaf_clusters.size() * 7, cr, 0.2)
		var blob := MeshInstance3D.new()
		blob.mesh = leaf_clusters[key]
		blob.position = centre + Vector3(dir.x * radius * 0.92, radius * 0.25 + dir.y * radius * 0.78, dir.z * radius * 0.92)
		blob.scale = Vector3(1.0, 0.8, 1.0)
		blob.material_override = leaf
		tree.add_child(blob)


func _add_pine(tree: Node3D, r: RandomNumberGenerator, bark: Material, big: bool, autumn: int = -1) -> void:
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
	leaf.shader = load("res://assets/shaders/leaf_soft.gdshader" if world_style else "res://assets/shaders/leaf.gdshader")
	leaf.set_shader_parameter("noise_tex", load("res://assets/textures/water_noise.png"))
	var hue := r.randf_range(-0.02, 0.02)
	# Deep forest green with lighter tips (the 2026-10-08 target art).
	# (Lifted a little with the one-piece gradient: the jagged tiers read
	# near black otherwise.)
	leaf.set_shader_parameter("bottom_color", Color.from_hsv(0.41 + hue, 0.85, 0.15))
	leaf.set_shader_parameter("top_color", Color.from_hsv(0.36 + hue, 0.68, 0.44))
	if world_style:   # the broadleaf crown ramp, a step cooler and darker
		var pb := StyleProfile.PINE_BOTTOM
		var pt := StyleProfile.PINE_TOP
		leaf.set_shader_parameter("bottom_color", Color.from_hsv(pb.x + hue, pb.y, pb.z))
		leaf.set_shader_parameter("top_color", Color.from_hsv(pt.x + hue, pt.y, pt.z))
		leaf.set_shader_parameter("rim_strength", StyleProfile.LEAF_RIM)
		leaf.set_shader_parameter("clump", StyleProfile.LEAF_CLUMP * 0.6)
		if autumn >= 0:   # the Kingdom's autumn pines: orange (0) or gold (1)
			leaf.set_shader_parameter("bottom_color", StyleProfile.AUTUMN_BOTTOM if autumn == 0 else StyleProfile.GOLD_BOTTOM)
			leaf.set_shader_parameter("top_color", StyleProfile.AUTUMN_TOP if autumn == 0 else StyleProfile.GOLD_TOP)
	leaf.set_shader_parameter("height", 1.6)
	leaf.set_shader_parameter("sway", 0.03)
	var base_r: float = (1.9 if big else 1.5) * r.randf_range(0.9, 1.1)
	# One gradient over the whole tree (dark skirts, light tip), not per tier.
	leaf.set_shader_parameter("world_gradient", true)
	leaf.set_shader_parameter("crown_base", tree.position.y + trunk_h * 0.2)
	leaf.set_shader_parameter("height", trunk_h * 1.0)
	for i in 4:
		var cone := MeshInstance3D.new()
		cone.mesh = _pine_tier_mesh(r.randi(), base_r * (1.05 - 0.22 * i), trunk_h * 0.36)
		cone.position.y = trunk_h * (0.36 + 0.17 * i)
		cone.rotation.y = r.randf() * TAU
		cone.material_override = leaf
		tree.add_child(cone)


func _pine_tier_mesh(seed: int, radius: float, height: float) -> ArrayMesh:
	## One tier of a conifer: a faceted cone whose rim is a ring of drooping
	## needle points (the old smooth cones read as plain stacked lampshades).
	var key := "%d|%.2f|%.2f" % [seed % 6, radius, height]
	if pine_tiers.has(key):
		return pine_tiers[key]
	var r := RandomNumberGenerator.new()
	r.seed = seed % 6
	var n := 11
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var apex := Vector3(0, height / 2.0, 0)
	var rim := []
	for k in n * 2:
		var a := TAU * k / (n * 2)
		var tip := k % 2 == 0
		var rr := radius * (1.0 if tip else 0.72) * r.randf_range(0.94, 1.06)
		# Points droop below the notches; notches tuck up under the tier above.
		var y := -height / 2.0 - (0.12 * height if tip else -0.08 * height)
		rim.append(Vector3(cos(a) * rr, y, sin(a) * rr))
	var under := Vector3(0, -height * 0.3, 0)
	for k in n * 2:
		var p0: Vector3 = rim[k]
		var p1: Vector3 = rim[(k + 1) % (n * 2)]
		st.add_vertex(apex)
		st.add_vertex(p1)
		st.add_vertex(p0)
		st.add_vertex(under)
		st.add_vertex(p0)
		st.add_vertex(p1)
	st.generate_normals()
	var m := StaticBatch.kept_mesh(st)
	pine_tiers[key] = m
	return m


func _leaf_material(r: RandomNumberGenerator, autumn: bool) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/leaf_soft.gdshader" if world_style else "res://assets/shaders/leaf.gdshader")
	mat.set_shader_parameter("noise_tex", load("res://assets/textures/water_noise.png"))
	var hue := r.randf_range(-0.03, 0.03)
	if autumn:
		mat.set_shader_parameter("bottom_color", Color(0.45, 0.18, 0.05))
		mat.set_shader_parameter("top_color", Color(0.95, 0.55, 0.15))
		if world_style:
			mat.set_shader_parameter("bottom_color", StyleProfile.AUTUMN_BOTTOM)
			mat.set_shader_parameter("top_color", StyleProfile.AUTUMN_TOP)
	else:
		# Rich mid greens (Faisal's 2026-10-09 brief): the old lime tops read
		# yellow next to the reference's foliage.
		var top_v := r.randf_range(0.52, 0.62)   # (drawn in the same order as before: tree shapes stay put)
		mat.set_shader_parameter("bottom_color", Color.from_hsv(0.35 + hue, 0.8, 0.28))
		mat.set_shader_parameter("top_color", Color.from_hsv(0.31 + hue, 0.74, top_v))
		if world_style:   # style_profile.gd's one foliage ramp
			var j := hue / 0.03 * StyleProfile.LEAF_HUE_JITTER
			var lb := StyleProfile.LEAF_BOTTOM
			var lt := StyleProfile.LEAF_TOP
			mat.set_shader_parameter("bottom_color", Color.from_hsv(lb.x + j, lb.y, lb.z))
			mat.set_shader_parameter("top_color", Color.from_hsv(lt.x + j, lt.y, lt.z + (top_v - 0.57) * 0.6))
	mat.set_shader_parameter("height", 2.0)
	if world_style:
		mat.set_shader_parameter("rim_strength", StyleProfile.LEAF_RIM)
		mat.set_shader_parameter("clump", StyleProfile.LEAF_CLUMP)
	return mat


func _kit():
	## The forest kit (scripts/visual/forest_kit.gd) while the match world is
	## built, or null (menus, Ember Pass, "--no-forest-kit").
	if forest_kit == null and ForestKit.enabled(self):
		forest_kit = ForestKit.new(self)
	return forest_kit if forest_kit != null and world_style else null


func _tree_bark() -> StandardMaterial3D:
	## Trunks, roots and boughs. In the match world every tree shares one
	## bark material (it is never changed after): hundreds fewer materials.
	if not world_style:
		return _pbr("bark", 0.5, Color(0.95, 0.9, 0.85))
	var key := "bark|%s" % soot.to_html()
	if not style_cache.has(key):
		style_cache[key] = _pbr("bark", 0.5, Color(0.95, 0.9, 0.85))
	return style_cache[key]


func _rock_mesh(seed: int, radius: float, jitter: float = 0.22) -> ArrayMesh:
	## A faceted, lumpy sphere: boulders, rubble and leaf blobs.
	## (claude-faisal3 2026-10-29 loading pass: the world makes ~2,700 of
	## these, 3 s of every world build. The sphere and its seams are now
	## worked out once, and the mesh is built from arrays: the old route went
	## through a temporary ArrayMesh, a GPU upload and read-back per blob.
	## Same rocks for the same seeds: tools/rock_mesh_test.gd.)
	var r := RandomNumberGenerator.new()
	r.seed = seed
	if _rock_unit.is_empty():
		_build_rock_unit()
	var unit: PackedVector3Array = _rock_unit[0]
	var first: PackedInt32Array = _rock_unit[1]
	# Jitter each unique position the same way so the surface stays closed
	# (in first-seen order, as before, so a seed keeps its rock).
	var verts := PackedVector3Array()
	verts.resize(unit.size())
	for i in unit.size():
		var f := first[i]
		verts[i] = unit[i] * (radius * (1.0 + r.randf_range(-jitter, jitter))) if f == i else verts[f]
	var arrays: Array = _rock_unit[2].duplicate()
	arrays[Mesh.ARRAY_VERTEX] = verts
	var st := SurfaceTool.new()
	st.create_from_arrays(arrays)
	st.deindex()
	st.generate_normals()
	return StaticBatch.kept_mesh(st)


static var _rock_unit := []   # [unit sphere vertices, first vertex at each place, its arrays]


static func _build_rock_unit() -> void:
	## The 9 x 5 sphere every rock starts from, at radius 1 (a rock is it
	## scaled), and for each vertex the first vertex at the same place.
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 9
	sphere.rings = 5
	var arrays := sphere.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var first := PackedInt32Array()
	var seen := {}
	for i in verts.size():
		var key := verts[i].snapped(Vector3.ONE * 0.001)
		if not seen.has(key):
			seen[key] = i
		first.append(seen[key])
	_rock_unit = [verts, first, arrays]


func _add_bush(pos: Vector3, seed: int) -> void:
	# Bushes sit beside trees, never inside them: push out past the crown,
	# then drop any that would land on a path or a building.
	for pass_i in 2:
		for t in map_trees:
			var away := Vector2(pos.x - t.x, pos.z - t.z)
			var need := (2.6 if t.y > 0.5 else 2.1) + 1.3
			if away.length() < need:
				if away.length() < 0.01:
					away = Vector2(1, 0)
				away = away.normalized() * need
				pos = Vector3(t.x + away.x, 0, t.z + away.y)
	for t in map_trees:
		if _flat_dist(pos, t) < 3.0:
			return
	if _near_path(pos, 0.9):
		return
	for blk in audit_blocks:
		var box: AABB = blk[1]
		if box.size.y >= 0.3 and box.end.y >= 0.3 and pos.x > box.position.x - 1.2 and pos.x < box.end.x + 1.2 and pos.z > box.position.z - 1.2 and pos.z < box.end.z + 1.2:
			return
	if _kit():
		_kit().bush_at(pos, seed)
		return
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
	if world_style:   # the style guide's saturated blue river
		wmat.set_shader_parameter("shallow", StyleProfile.WATER_SHALLOW)
		wmat.set_shader_parameter("deep", StyleProfile.WATER_DEEP)
		wmat.set_shader_parameter("open_foam", StyleProfile.WATER_OPEN_FOAM)
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
	# Clusters of notched pads (the 2026-10-08 target art) hug the banks,
	# two shades of green, some with a pink or white water lily.
	var pad_mats := [pad_mat, _material(Color(0.28, 0.56, 0.26)), _material(Color(0.44, 0.72, 0.34))]
	var white_mat := _material(Color(0.98, 0.95, 0.88))
	white_mat.emission_enabled = true
	white_mat.emission = Color(0.4, 0.38, 0.32)
	white_mat.emission_energy_multiplier = 0.3
	var placed := 0
	var tries := 0
	while placed < LILY_CLUSTERS and tries < 200:
		await _world_build_frame()   # (built behind the menus: no long frame)
		tries += 1
		var cz := lr.randf_range(-map_half.y + 1.0, map_half.y - 1.0)
		if _near_bridge(cz, 2.0):
			continue
		var bank := -1.0 if lr.randf() < 0.5 else 1.0
		var cx := bank * lr.randf_range(RIVER_HALF - 1.5, RIVER_HALF - 0.75)
		placed += 1
		for j in lr.randi_range(2, 4):
			var pr := lr.randf_range(0.42, 0.78) * (1.0 if j == 0 else 0.8)
			var off := Vector3(lr.randf_range(-0.9, 0.9), 0, lr.randf_range(-1.1, 1.1)) if j > 0 else Vector3.ZERO
			var pp := Vector3(cx, 0.07 + j * 0.004, cz) + off
			pp.x = clampf(pp.x, -RIVER_HALF + 0.35 + pr * 0.6, RIVER_HALF - 0.35 - pr * 0.6)
			var pad := MeshInstance3D.new()
			pad.mesh = _lily_pad_mesh(pr)
			pad.position = pp
			pad.rotation.y = lr.randf() * TAU
			pad.material_override = pad_mats[(placed + j) % 3]
			add_child(pad)
			if j == 0 and placed % 2 == 0:
				_add_water_lily(pp + Vector3(0, 0.03, 0), bud_mat if placed % 4 == 0 else white_mat, lr.randf() * TAU)
	# Banks: a stone kerb of warm grey blocks along the water's edge (like the
	# render's stacked-block banks), a pebbly strip behind it and a few boulders.
	var kerb := _pbr("rock", 0.45, Color(0.92, 0.9, 0.86))
	for sx in [-1.0, 1.0]:
		await _world_build_frame()   # (built behind the menus: no long frame)
		_add_block(Vector3(sx * (RIVER_HALF + 1.0), 0.012, 0), Vector3(1.6, 0.01, length), Color(0.6, 0.5, 0.35), false, _pbr("cobble", 0.6, Color(0.92, 0.86, 0.74)))
		var k := 0
		var z := -map_half.y - 2.0
		while z < map_half.y + 2.0:
			if not _near_bridge(z, 0.5):
				var kh: float = 0.32 + 0.14 * fmod(absf(z) * 3.7, 1.0)
				_add_block(Vector3(sx * (RIVER_HALF + 0.38), kh / 2.0 - 0.06, z + 0.55), Vector3(0.76, kh, 1.0), Color.WHITE, false, kerb)
			if k % 4 == 1 and not _near_bridge(z, 2.5) and absf(absf(z) - 30.0) > 5.5 and absf(z) < 34.0:
				_prop("hex/rock_single_%s" % ["A", "B", "C", "D", "E"][k % 5], Vector3(sx * (RIVER_HALF + 2.0 + fmod(z * 7.3, 1.0) * 0.4), 0, z), 2.5, z)
			k += 1
			z += 1.2
			if k % 8 == 0:
				await _world_build_frame()   # (claude-faisal/stutter: each bank was one 30-50 ms step behind the title)
		# Bank walls between the bridges.
		var edges: Array = [-length / 2.0]
		for i in BRIDGES.size():
			edges.append(BRIDGES[i] - BRIDGE_HALF[i] - 0.3)
			edges.append(BRIDGES[i] + BRIDGE_HALF[i] + 0.3)
		edges.append(length / 2.0)
		for i in range(0, edges.size(), 2):
			var z0: float = edges[i]
			var z1: float = edges[i + 1]
			await _world_build_frame()
			_add_bank_wall(sx, z0, z1, 1.0, 2.0)
		# Along the island the bank wall stays below the plateau top: it keeps
		# walkers on the bank out of the water, but anyone up on the shrine
		# walks straight over it.
		await _world_build_frame()
		_add_bank_wall(sx, -ISLAND_R - 0.4, ISLAND_R + 0.4, -0.05, 1.0)
	await _world_build_frame()
	_add_island()
	# Low stone rims on the island's north and south edges so nobody walks
	# off the shrine into the river channel (there is no way back up).
	# They follow the plateau's curve in short stones of the plaza's own
	# flagstone (Faisal 11:30: the straight walls across the round plaza
	# "look off put").
	var rim_mat := _flagstone(Color(0.93, 0.89, 0.82))
	var rim_r := ISLAND_R - 0.25
	for zs in [-1.0, 1.0]:
		await _world_build_frame()   # (built behind the menus: no long frame)
		for k in 10:
			var phi := deg_to_rad(-40.5 + 9.0 * k)
			var c := Vector3(rim_r * sin(phi), 0.75, zs * rim_r * cos(phi))
			var seg := StaticBody3D.new()
			seg.position = c
			seg.rotation.y = zs * phi
			var cs := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = Vector3(0.96, 0.5, 0.45)
			cs.shape = bs
			seg.add_child(cs)
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.96, 0.5, 0.45)
			mi.mesh = bm
			mi.material_override = rim_mat
			seg.add_child(mi)
			add_child(seg)
	# Bridges: a plank deck with rails and posts.
	for i in BRIDGES.size():
		await _world_build_frame()   # (built behind the menus: no long frame)
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
			_add_block(Vector3(0, -0.09, bz + zs * (half - 0.3)), Vector3(deck_len, 0.26, 0.3), Color.WHITE, false, _timber(Color(0.72, 0.58, 0.44)))
		var planks := int(deck_len / 0.5)
		for k in planks:
			var px: float = -deck_len / 2.0 + (k + 0.5) * deck_len / planks
			var tint := Color(0.9, 0.78, 0.6) if k % 2 == 0 else Color(0.84, 0.7, 0.52)
			_add_block(Vector3(px, 0.06, bz), Vector3(deck_len / planks - 0.05, 0.1, half * 2), Color.WHITE, false, _plank_dark(tint))
		for zs in [-1.0, 1.0]:
			var rz: float = bz + zs * (half + 0.12)
			_add_railing(Vector3(-deck_len / 2.0 + 0.2, 0.1, rz), Vector3(deck_len / 2.0 - 0.2, 0.1, rz))
			_add_collider(Vector3(0, 0.6, rz), Vector3(deck_len, 1.2, 0.2))
		# Stone pier pillars with fire bowls at all four corners (the target art);
		# they replace the big bridge's torch stands. They stand on the bank
		# just outside the railings, clear of the deck.
		for xs in [-1.0, 1.0]:
			for zs in [-1.0, 1.0]:
				_add_stone_brazier(Vector3(xs * (deck_len / 2.0 + 0.6), 0.0, bz + zs * (half + 0.75)), zs > 0.0)


const LILY_CLUSTERS := 22   # pad clusters on the Wildwood river (was 34 single small discs)


func _lily_pad_mesh(radius: float) -> ArrayMesh:
	## A flat lily pad: a disc with the classic wedge notch cut out, and a
	## slightly raised rim so the ink outline reads.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 14
	var notch := 0.55   # radians missing
	var a0 := notch / 2.0
	var span := TAU - notch
	for k in segs:
		var t0 := a0 + span * k / segs
		var t1 := a0 + span * (k + 1) / segs
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3(0, 0.02, 0))
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3(cos(t1), 0.0, sin(t1)) * radius + Vector3(0, 0.025, 0))
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3(cos(t0), 0.0, sin(t0)) * radius + Vector3(0, 0.025, 0))
	return StaticBatch.kept_mesh(st)


func _add_water_lily(pos: Vector3, petal: Material, rot: float) -> void:
	## A small cup of pointed petals with a golden heart, sitting on a pad.
	var flower := Node3D.new()
	flower.position = pos
	flower.rotation.y = rot
	add_child(flower)
	for k in 6:
		var leaf := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(0.12, 0.22, 0.03)
		leaf.mesh = pm
		var a := TAU * k / 6.0
		leaf.position = Vector3(cos(a) * 0.07, 0.09, sin(a) * 0.07)
		leaf.rotation = Vector3(0, -a + PI / 2.0, 0)
		leaf.rotate_object_local(Vector3.RIGHT, -0.5)
		leaf.material_override = petal
		flower.add_child(leaf)
	var heart := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.05
	sm.height = 0.08
	sm.radial_segments = 6
	sm.rings = 3
	heart.mesh = sm
	heart.position = Vector3(0, 0.08, 0)
	heart.material_override = _gold()
	flower.add_child(heart)


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
		_add_rosette(Vector3(0, tier[3] + tier[2] / 2.0 + 0.004, 0), tier[0])
	_add_rosette(Vector3(0, 0.504, 0), ISLAND_R - 0.05)
	_add_collider(Vector3(0, 1.3, 0), Vector3(1.6, 1.6, 1.6))
	_add_block(Vector3(0, 1.42, 0), Vector3(1.2, 0.9, 1.2), Color.WHITE, false, _ashlar(Color(0.95, 0.92, 0.86)))
	_add_block(Vector3(0, 1.9, 0), Vector3(1.4, 0.1, 1.4), Color.WHITE, false, _ashlar(Color(0.9, 0.86, 0.78)))
	# The shrine fire: an iron brazier on the plinth, burning bright.
	var bowl := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.62
	bm.bottom_radius = 0.34
	bm.height = 0.4
	bm.radial_segments = 16
	bowl.mesh = bm
	bowl.position = Vector3(0, 2.15, 0)
	bowl.material_override = _iron()
	add_child(bowl)
	var bowl_rim := MeshInstance3D.new()
	var brm := TorusMesh.new()
	brm.inner_radius = 0.56
	brm.outer_radius = 0.68
	bowl_rim.mesh = brm
	bowl_rim.position = Vector3(0, 2.35, 0)
	bowl_rim.material_override = _gold()
	add_child(bowl_rim)
	_add_fire(Vector3(0, 2.25, 0), 3.0)
	var shrine_light := OmniLight3D.new()
	shrine_light.light_color = Color(1.0, 0.8, 0.4)
	shrine_light.light_energy = 2.0
	shrine_light.omni_range = 9.0
	shrine_light.position = Vector3(0, 3.0, 0)
	add_child(shrine_light)
	for i in 4:
		var a := TAU * i / 4.0 + PI / 4.0
		_add_torch_stand(Vector3(cos(a) * 4.2, 0.5, sin(a) * 4.2), 1.7)
		# Rustic timber rails round the plaza's rim between the torches.
		var c := Vector3(cos(a) * 5.4, 0.5, sin(a) * 5.4)
		var t := Vector3(-sin(a), 0, cos(a))
		for k in [-1.0, 0.0, 1.0]:
			_add_block(c + t * k * 1.1 + Vector3(0, 0.45, 0), Vector3(0.16, 0.9, 0.16), Color.WHITE, false, _timber(Color(0.62, 0.46, 0.32)))
		for h in [0.4, 0.75]:
			var rail := MeshInstance3D.new()
			var rm := BoxMesh.new()
			rm.size = Vector3(2.5, 0.1, 0.08)
			rail.mesh = rm
			rail.position = c + Vector3(0, h, 0)
			# Along the rim's tangent, so the rails follow the circle instead of
			# cutting across it (Faisal 08:19: "fences are the wrong way").
			rail.rotation.y = -(a + PI / 2.0)
			rail.material_override = _timber(Color(0.66, 0.5, 0.35))
			add_child(rail)
	map_marks.append([Vector3.ZERO, "shrine"])
	# Steps up from each bank, and a short pier of planks over the water's edge.
	for sx in [-1.0, 1.0]:
		var foot := Vector3(sx * (ISLAND_R + 3.2), 0.0, 0)
		var head := Vector3(sx * (ISLAND_R - 0.4), 0.5, 0)
		# The plaza's flagstone, not small ashlar bricks, so road, steps and
		# plaza read as one surface (Faisal 11:30: "all over the place").
		_add_stairs(foot, head, 4.0, _flagstone(Color(0.96, 0.93, 0.88)), 1.0)
		_add_railing(foot + Vector3(0, 0, -1.92), head + Vector3(0, 0, -1.92))
		_add_torch(Vector3(sx * (ISLAND_R + 3.6), 0, -2.6))
		_add_torch(Vector3(sx * (ISLAND_R + 3.6), 0, 2.6))


func in_channel(p: Vector3) -> bool:
	## In the river itself: between the banks, off every bridge deck and off
	## the shrine island. Nothing should ever stand there. On Ember Pass:
	## anywhere off the plateaus, plazas and bridges (the lava).
	if vmap:
		return not vmap.walkable(p)
	if lmap:
		return not lmap.walkable(p)   # up on the ridges or in the trees: nobody lands there either
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


const COVER_BARRICADES := [[Vector3(11, 0, 5), 3.5], [Vector3(12, 0, -7), 3.5], [Vector3(20, 0, 1), 4.0],
	[Vector3(18, 0, 12), 3.0], [Vector3(30, 0, -5), 3.5], [Vector3(28, 0, 8), 3.0], [Vector3(31, 0, 19), 3.0], [Vector3(17, 0, -20), 3.0]]
const COVER_BOULDERS := [Vector3(9, 0, -13), Vector3(13, 0, -18), Vector3(22, 0, 14), Vector3(33, 0, -10.5), Vector3(38, 0, 10),
	Vector3(8, 0, 28), Vector3(17, 0, 25), Vector3(14, 0, -36), Vector3(26, 0, -27), Vector3(40, 0, -22), Vector3(40, 0, 24)]


func _add_cover(barricades: Array = COVER_BARRICADES, boulders: Array = COVER_BOULDERS, ruins: bool = true) -> void:
	## Low barricades and boulders in the contested middle. Shots stop at
	## them, so there is always somewhere to duck. Everything is mirrored.
	## (Stonekeep Fortress and Twilight Grove pass their own, scripts/lanes.gd.)
	# Three cover designs cycle across the field: supply stacks, timber
	# palisades and broken ashlar walls, so the middle reads as a battlefield.
	# Timber crates and casks (dungeon pack: dark planks like the 2026-10-08 target art).
	var crates := ["dungeon/box_large", "dungeon/box_large", "dungeon/barrel_large", "dungeon/box_large", "dungeon/barrel_large"]
	var crate_scale := {"dungeon/box_large": 0.72, "dungeon/barrel_large": 0.56}
	for bi in barricades.size():
		await _world_build_frame()   # (built behind the menus: no long frame)
		var b: Array = barricades[bi]
		for m in [1.0, -1.0]:
			var c: Vector3 = b[0] * m
			var length: float = b[1]
			var kind: int = 0 if absf(c.z) < 3.0 else 2
			# Wall stubs stand beside the road, not on it (the one at x -31
			# sat across the Forest Path like a post): step them away from
			# the paths, cover point and collider with them.
			var k := 0
			while kind == 2 and _near_path(c, length / 2.0 + 0.4) and k < 8:
				c.z += 1.0 if c.z >= 0.0 else -1.0
				k += 1
			_add_collider(Vector3(c.x, 0.6, c.z), Vector3(1.0, 1.2, length))
			cover_points.append(Vector3(c.x, 0, c.z))
			cover_boxes.append(AABB(Vector3(c.x - 0.5, 0, c.z - length / 2.0), Vector3(1.0, 1.2, length)))
			# Supply stacks on the road itself (an abandoned caravan); broken
			# ashlar walls across the field. (No timber palisades: they read
			# as stray fences, Faisal 11:27 "did you fix the random fence
			# issues". The cover and its collider are unchanged.)
			await _world_build_frame()   # (claude-faisal/stutter: the cover was one 61 ms step behind the title)
			match kind:
				0:
					var n := int(length / 1.15)
					for i in n:
						var z: float = c.z - length / 2.0 + (i + 0.5) * length / n
						var pick: int = absi(int(c.x * 3 + z * 5 + i)) % crates.size()
						_prop(crates[pick], Vector3(c.x, 0, z), crate_scale[crates[pick]], float(i) * 0.4)
						if i % 2 == 0:
							_prop("dungeon/box_small", Vector3(c.x, 1.1, z), 0.75, 0.5)
				1:
					_add_palisade(c, length)
				2:
					_add_wall_stub(c, length)
	for p0 in boulders:
		await _world_build_frame()   # (built behind the menus: no long frame)
		# Off the cobbled paths (Faisal 11:29: "move this rock out of the
		# road", the boulder on the Forest Path by the Elf gate): step it
		# away from the road until it clears every path.
		var p: Vector3 = p0
		var k := 0
		while _near_path(p, 2.4) and k < 12:
			p.z += 1.0 if p.z >= 0.0 else -1.0
			k += 1
		if _near_path(p, 2.4) or absf(p.z - p0.z) > 6.0:
			continue   # no clear spot near its own: leave it out
		_add_boulder(p)
		_add_boulder(-p)
		cover_points.append(p)
		cover_points.append(-p)
		if lmap:
			# On the narrower lanes walkers must know to step round them
			# (route_point goes round anything in cover_boxes).
			for q in [p, -p]:
				cover_boxes.append(AABB(Vector3(q.x - 1.2, 0, q.z - 1.2), Vector3(2.4, 1.6, 2.4)))
	if not ruins:
		return
	# The Northern Ruins: broken columns and rubble by the north bridge, and
	# a smaller ruin on the south river path. Mirrored.
	await _world_build_frame()
	_add_ruins(Vector3(11, 0, -27))
	await _world_build_frame()
	_add_ruins(Vector3(-11, 0, 27))
	await _world_build_frame()
	_add_ruins(Vector3(-24, 0, -29), true)
	await _world_build_frame()
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
	## with rubble spilling off the low end. Stone on both sides: the elven
	## "ashlar" is bark, which made the Elf-side stubs read as wooden posts.
	audit_label = "wall"
	var tall_len: float = length * 0.55
	var low_len: float = length - tall_len
	_add_block(Vector3(c.x, 0.65, c.z - low_len / 2.0), Vector3(0.6, 1.3, tall_len), Color.WHITE, false, _ashlar())
	_add_block(Vector3(c.x, 1.38, c.z - low_len / 2.0), Vector3(0.8, 0.16, tall_len + 0.2), Color.WHITE, false, _ashlar(Color(0.92, 0.88, 0.8)))
	_add_block(Vector3(c.x, 0.4, c.z + tall_len / 2.0), Vector3(0.6, 0.8, low_len), Color.WHITE, false, _ashlar(Color(0.9, 0.87, 0.8)))
	_add_block(Vector3(c.x, 0.9, c.z + tall_len / 2.0 - low_len / 4.0), Vector3(0.6, 0.2, low_len / 2.0), Color.WHITE, false, _ashlar(Color(0.88, 0.85, 0.78)))
	audit_label = ""
	_prop("dungeon/rubble_large", Vector3(c.x + 0.4 * signf(c.x), 0, c.z + length / 2.0 + 0.7), 0.22, 0.4)


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
	_add_torch_stand(pos, 1.9)


func kcx_of(kx: float, bx: float) -> float:
	return (kx + bx) / 2.0


func _add_elf_class_stall(team: int, role: int, pos: Vector3, wall_z: float, top: float, sign_y: float) -> void:
	## The Elves' class station as in Faisal's base interior reference: a
	## timber frame with a dark hanging name board, a green banner with the
	## class icon under it, a hedge behind and a hexagonal timber platform on
	## the floor under the pedestal.
	var wood := _timber(Color(0.5, 0.36, 0.24))
	var dark := _timber(Color(0.3, 0.2, 0.12))
	var team_color: Color = Stats.FACTIONS[team].color
	_add_hedge_run(Vector3(pos.x - 1.0, pos.y, wall_z + 0.5), Vector3(pos.x + 1.0, pos.y, wall_z + 0.5), 0.5, int(absf(pos.x) * 7.0) + role)
	for xs in [-1.0, 1.0]:
		audit_label = "pole"
		_add_block(Vector3(pos.x + xs * 1.1, (pos.y + top) / 2.0, wall_z + 1.0), Vector3(0.32, top - pos.y, 0.32), Color.WHITE, false, wood)
		audit_label = ""
		_add_block(Vector3(pos.x + xs * 1.1, pos.y + 0.1, wall_z + 1.0), Vector3(0.54, 0.2, 0.54), Color.WHITE, false, _ashlar(Color(0.9, 0.88, 0.84)))
	_add_block(Vector3(pos.x, top + 0.08, wall_z + 1.0), Vector3(2.7, 0.26, 0.36), Color.WHITE, false, wood)
	# The name board on two short chains.
	for xs in [-0.7, 0.7]:
		_add_block(Vector3(pos.x + xs, top - 0.12, wall_z + 1.0), Vector3(0.04, 0.16, 0.04), Color.WHITE, false, _iron())
	_add_block(Vector3(pos.x, sign_y, wall_z + 1.0), Vector3(2.2, 0.62, 0.1), Color.WHITE, false, dark)
	_add_block(Vector3(pos.x, sign_y, wall_z + 1.05), Vector3(2.1, 0.54, 0.02), Color.WHITE, false, _timber(Color(0.36, 0.26, 0.16)))
	# The banner: team cloth with a gold hem, the class icon on it.
	var accent: Color = Stats.ROLES[role].color
	_add_block(Vector3(pos.x, sign_y - 0.9, wall_z + 1.0), Vector3(1.4, 1.2, 0.05), Color.WHITE, false, _cloth(accent.darkened(0.1)))
	_add_block(Vector3(pos.x, sign_y - 0.33, wall_z + 1.0), Vector3(1.5, 0.07, 0.07), Color.WHITE, false, _gold())
	var em := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2.ONE * 0.8
	em.mesh = q
	em.material_override = _icon_mat(_class_icon_name(role))
	em.position = Vector3(pos.x, sign_y - 0.9, wall_z + 1.04)
	add_child(em)
	# The hex platform under the pedestal.
	var hexp := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 1.35
	hm.bottom_radius = 1.4
	hm.height = 0.06
	hm.radial_segments = 6
	hexp.mesh = hm
	hexp.position = pos + Vector3(0, 0.03, 0.1)
	hexp.rotation.y = PI / 6.0
	hexp.material_override = _timber(Color(0.66, 0.48, 0.3))
	add_child(hexp)
	var rim := MeshInstance3D.new()
	var rmm := CylinderMesh.new()
	rmm.top_radius = 1.42
	rmm.bottom_radius = 1.42
	rmm.height = 0.03
	rmm.radial_segments = 6
	rim.mesh = rmm
	rim.position = pos + Vector3(0, 0.015, 0.1)
	rim.rotation.y = PI / 6.0
	rim.material_override = dark
	add_child(rim)


var icon_mats := {}


func _icon_mat(name: String) -> StandardMaterial3D:
	## A HUD icon (assets/ui/icons) as a cut-out decal on a banner or sign.
	if not icon_mats.has(name):
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = load("res://assets/ui/icons/%s.png" % name)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.alpha_scissor_threshold = 0.4
		mat.roughness = 0.7
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		icon_mats[name] = mat
	return icon_mats[name]


func _class_icon_name(role: int) -> String:
	match role:
		Role.KNIGHT: return "class_knight"
		Role.RANGER: return "class_ranger"
		Role.MAGE: return "class_mage"
		Role.HEALER: return "class_healer"
		Role.ENGINEER: return "class_engineer"
		Role.ROGUE: return "class_rogue"
	return "class_elf"


func _add_emblem_decal(pos: Vector3, size: float, team: int) -> void:
	## The faction's beast laid flat on a rug or floor (the reference's stag runners).
	var m := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2.ONE * size
	m.mesh = q
	m.material_override = _emblem_mat(_faction_emblem(team))
	m.position = pos
	m.rotation_degrees = Vector3(-90, 0, 0)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)


func _add_class_alcove(team: int, role: int, pos: Vector3) -> void:
	## A stone (or bark) alcove against the wall behind a class station, with
	## a hanging sign naming the class, a drape in its colour and its runes.
	var color: Color = Stats.ROLES[role].color
	var wall_z := pos.z - 1.6          # the wall's inner face (north)
	var top := pos.y + 2.9
	var sign_y := top - 0.4   # hung from the lintel, in front of the drape
	if team == 0 and cellar_floor(team) >= 0.0:
		# The open courtyard (Wildwood): designed stations under the pavilion,
		# their name boards on its posts; the hat's own ring is the only glow.
		# The class name is on the station's sign (Faisal 09:06 2026-10-09:
		# the light floor label read poorly; "it should have been above it in
		# the sign").
		_add_elf_class_station(team, role, pos)
		return
	if team == 0:
		_add_elf_class_stall(team, role, pos, wall_z, top, sign_y)
	else:
		var stone := _ashlar(Color(0.92, 0.9, 0.86))
		_add_block(Vector3(pos.x, (pos.y + top) / 2.0, wall_z + 0.15), Vector3(1.8, top - pos.y, 0.3), Color.WHITE, true, _ashlar(Color(0.78, 0.76, 0.74)))
		for xs in [-1.0, 1.0]:
			_add_block(Vector3(pos.x + xs * 1.0, (pos.y + top) / 2.0, wall_z + 0.4), Vector3(0.36, top - pos.y, 0.8), Color.WHITE, true, stone)
			_add_block(Vector3(pos.x + xs * 1.0, pos.y + 0.12, wall_z + 0.42), Vector3(0.5, 0.24, 0.9), Color.WHITE, false, stone)
		_add_block(Vector3(pos.x, top + 0.15, wall_z + 0.4), Vector3(2.5, 0.34, 0.86), Color.WHITE, false, stone)
		# A drape in the class colour at the back of the alcove.
		_add_block(Vector3(pos.x, pos.y + 1.55, wall_z + 0.33), Vector3(1.2, 1.9, 0.04), color, false, _cloth(color.darkened(0.15)))
		_add_block(Vector3(pos.x, pos.y + 2.5, wall_z + 0.35), Vector3(1.3, 0.08, 0.06), Color.WHITE, false, _gold())
		# The sign: a bright board in the class colour with a gold frame (Faisal's 12:55 target).
		_add_block(Vector3(pos.x, sign_y, wall_z + 0.88), Vector3(1.95, 0.52, 0.08), Color.WHITE, false, _gold())
		var board := _material(color.darkened(0.05))
		board.emission_enabled = true
		board.emission = color
		board.emission_energy_multiplier = 0.25
		_add_block(Vector3(pos.x, sign_y, wall_z + 0.94), Vector3(1.8, 0.42, 0.08), Color.WHITE, false, board)
		for xs in [-1.0, 1.0]:
			_add_block(Vector3(pos.x + xs * 0.98, sign_y, wall_z + 0.96), Vector3(0.08, 0.54, 0.1), Color.WHITE, false, _gold())
	var label := Label3D.new()
	label.text = str(Stats.FACTIONS[team].roles[role]).to_upper()
	label.font_size = 64
	label.pixel_size = 0.0056
	label.outline_size = 14
	label.outline_modulate = color.darkened(0.7)
	label.modulate = Color(1.0, 0.98, 0.92)
	label.position = Vector3(pos.x, sign_y, wall_z + 1.0)
	if team == 0:
		# In front of the Elves' timber board and turned to the camera, so
		# the name reads from the top-down view (it hid inside the board).
		label.position = Vector3(pos.x, sign_y + 0.05, wall_z + 1.08)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 72
	label.shaded = false
	add_child(label)
	if team != 0:
		# The class icon on a gold roundel over the drape (the brief's "clear symbols").
		var disc := MeshInstance3D.new()
		var dmesh := CylinderMesh.new()
		dmesh.top_radius = 0.42
		dmesh.bottom_radius = 0.42
		dmesh.height = 0.05
		dmesh.radial_segments = 20
		disc.mesh = dmesh
		disc.rotation.x = PI / 2.0
		disc.position = Vector3(pos.x, pos.y + 1.62, wall_z + 0.36)
		disc.material_override = _gold()
		add_child(disc)
		var icon := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.62, 0.62)
		icon.mesh = q
		icon.material_override = _icon_mat(_class_icon_name(role))
		icon.position = Vector3(pos.x, pos.y + 1.62, wall_z + 0.4)
		icon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(icon)
	_add_runes(pos + Vector3(0, 0.0, 0.1), 1.15, color)
	# A glowing ring in the class colour around the pad.
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 1.12
	tm.outer_radius = 1.24
	tm.rings = 40
	tm.ring_segments = 6
	ring.mesh = tm
	ring.scale = Vector3(1, 0.4, 1)
	ring.position = pos + Vector3(0, 0.1, 0.1)
	var glow := _material(color.lightened(0.2))
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(color.lightened(0.35), 1.0) * 1.6
	ring.material_override = glow
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	_add_light(pos + Vector3(0, 1.8, 0.8), color.lightened(0.4), 0.9, 3.4)


func _add_station(team: int, role: int, pos: Vector3) -> void:
	## A class seal on its pedestal (see seal.gd). The floor pad under it
	## matches the castle: flagstone for Humans, mossy flagstone for Elves.
	stations[team][role] = pos
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
var elf_castle := false  # while the Elf castle itself is built: warm living wood + moonstone, not moss
# The Elf keep's palette (World & Maps, 2026-10-08): it read as a flat green
# wash, so the castle is now warm heartwood with pale moonstone trim and
# moon-blue crystal light; green stays for the team cloth and the canopies.
const ELF_BARK := Color(0.8, 0.62, 0.47)       # was Color(0.72, 0.7, 0.58), olive
const ELF_MOONSTONE := Color(0.84, 0.87, 0.95)  # pale blue-white stone
const ELF_GLOW := Color(0.6, 1.0, 0.72)        # crystal light: the reference's green crystals (was moon-blue 0.62, 0.8, 1.0)
var soot := Color.WHITE   # while Ember Pass's castles are built: darkens every textured surface
var swap_dim := Color(0.9, 0.86, 0.84)   # the tint a swapped texture takes (Ember Pass's soot; white for the seasons)
var tex_swap := {}        # ...and swaps textures that clash with the lava light (the Elves' bark and sandstone)
var grey := false    # while the Humans' castle is being built: grey stone


func _hedge(bright: bool = false) -> StandardMaterial3D:
	## Trimmed box hedge (tools/make_textures.py make_hedge): the elven
	## castle's walls are living hedges, like Faisal's Elf base target.
	var m := _pbr("hedge", 0.4, Color(1.08, 1.08, 1.0) if bright else Color.WHITE)
	m.roughness = 0.95
	return m


func _ashlar(tint: Color = Color.WHITE) -> StandardMaterial3D:
	## Castle stone; the elven castle is grown, so its "stone" is living bark,
	## and the Humans build in cool grey blocks.
	if elf_castle:
		# Faisal's Elf base reference (2026-10-08): the walls are trimmed
		# hedge, every trim piece (cornices, stairs, caps, posts) cream
		# sandstone like the Humans' but warmer.
		# Walls are broad cream sandstone (Faisal's overhaul brief, 2026-10-09:
		# foliage textures only on actual vegetation); hedges run along the
		# wall tops as leaf blobs instead.
		if tint != Color.WHITE:
			return _pbr("stone", 0.42, tint * Color(1.0, 0.97, 0.9))
		return _pbr("stone", 0.42, Color(0.98, 0.96, 0.9))
	if mossy:
		# Plain (untinted) elven "stone" is a trimmed hedge: keep walls, the
		# throne room and pillars; tinted pieces (caps, stairs, posts) stay bark.
		if tint == Color.WHITE:
			return _hedge()
		return _pbr("bark", 0.55, tint * Color(0.72, 0.7, 0.58))
	if grey:
		return _pbr("greystone", 0.42, Color(0.74, 0.76, 0.82).lerp(tint * Color(0.74, 0.76, 0.82), 0.35))
	return _pbr("stone", 0.42, tint)


func _moonstone(tint: Color = Color.WHITE) -> StandardMaterial3D:
	## Pale, faintly lustrous elven moonstone: the cream marble cooled to blue-white.
	# (Since 2026-10-09 this is cream sandstone marble, the reference's pale
	# warm stone, not blue-white; the name stays for the callers.)
	var lum := clampf((tint.r + tint.g + tint.b) / 3.0, 0.5, 1.0)
	var m := _pbr("marble", 0.35, Color(0.96, 0.93, 0.86) * lum)
	m.roughness = 0.45
	return m


func _moon_silver() -> StandardMaterial3D:
	## Elven inlay (dais rings, pedestal bands): gold, as in the reference's
	## gold-trimmed altar (was silver with a moon glow).
	return _gold()


var hedge_tops := false   # while the Elf courtyard is built: its walls are topped with hedge, not merlons


func _hedge_mat(seed: int) -> Material:
	## Trimmed hedge: the leaf shader (on Ember Pass too: the Elves' base is a
	## green oasis on the ash, Faisal's 23:55 target).
	var r := RandomNumberGenerator.new()
	r.seed = seed
	return _leaf_material(r, false)


func _add_hedge_blob(pos: Vector3, radius: float, seed: int, mat: Material = null) -> void:
	var blob := MeshInstance3D.new()
	blob.mesh = _rock_mesh(seed, radius, 0.14)
	blob.position = pos + Vector3(0, radius * 0.62, 0)
	blob.scale = Vector3(1.0, 0.78, 1.0)
	blob.material_override = mat if mat else _hedge_mat(seed)
	add_child(blob)


func _add_hedge_run(from: Vector3, to: Vector3, radius: float, seed: int) -> void:
	## A trimmed hedge along a line: overlapping leaf blobs (decor, nothing solid).
	var d := to - from
	var n := maxi(int(d.length() / (radius * 1.25)), 1)
	var mat := _hedge_mat(seed)
	for k in n + 1:
		var p := from + d * (float(k) / n)
		_add_hedge_blob(p + Vector3(0, 0, 0), radius * (0.9 + 0.2 * float((k * 7 + seed) % 3) / 2.0), seed + k, mat)


func _add_hedge_ring(center: Vector3, radius: float, gap_dir: Vector3, gap_deg: float, blob_r: float, seed: int) -> void:
	## A ring of hedge round a dais with an opening towards `gap_dir`.
	var n := maxi(int(TAU * radius / (blob_r * 1.3)), 6)
	var mat := _hedge_mat(seed)
	var gap_a := atan2(gap_dir.z, gap_dir.x)
	for k in n:
		var a := TAU * k / n
		var da := absf(angle_difference(a, gap_a))
		if da < deg_to_rad(gap_deg):
			continue
		var p := center + Vector3(cos(a) * radius, 0, sin(a) * radius)
		_add_hedge_blob(p, blob_r * (0.9 + 0.2 * float(k % 3) / 2.0), seed + k, mat)
		if k % 4 == 1 and not vmap:
			# A few blooms on the hedge.
			var bud := MeshInstance3D.new()
			var bm := SphereMesh.new()
			bm.radius = 0.09
			bm.height = 0.18
			bm.radial_segments = 6
			bm.rings = 3
			bud.mesh = bm
			bud.position = p + Vector3(0, blob_r * 1.15, 0)
			bud.material_override = _material([Color(0.98, 0.6, 0.75), Color(1.0, 0.95, 0.85), Color(0.6, 0.75, 1.0)][k % 3])
			add_child(bud)


func _add_flower_bed(pos: Vector3, size: Vector2, seed: int) -> void:
	## A raised bed of dark soil with a hedge border and bright blooms (the
	## courtyard reference). On Ember Pass the bed holds glowing embers.
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var soil := _pbr("dirt", 0.3, Color(0.55, 0.42, 0.3)) if not vmap else _pbr("rock", 0.4, Color(0.3, 0.22, 0.22))
	_add_block(pos + Vector3(0, 0.1, 0), Vector3(size.x, 0.2, size.y), Color.WHITE, false, soil)
	var kerb := _ashlar(Color(0.9, 0.88, 0.84))
	for zs in [-1.0, 1.0]:
		_add_block(pos + Vector3(0, 0.13, zs * (size.y / 2.0 + 0.08)), Vector3(size.x + 0.32, 0.26, 0.16), Color.WHITE, false, kerb)
	for xs in [-1.0, 1.0]:
		_add_block(pos + Vector3(xs * (size.x / 2.0 + 0.08), 0.13, 0), Vector3(0.16, 0.26, size.y), Color.WHITE, false, kerb)
	var n := int(size.x * size.y * 3.0)
	var stem := _material(Color(0.3, 0.6, 0.2))
	for k in n:
		var q := pos + Vector3(r.randf_range(-size.x / 2.0 + 0.2, size.x / 2.0 - 0.2), 0.2, r.randf_range(-size.y / 2.0 + 0.2, size.y / 2.0 - 0.2))
		if vmap:
			var ember := MeshInstance3D.new()
			var em := SphereMesh.new()
			em.radius = 0.07
			em.height = 0.14
			em.radial_segments = 6
			em.rings = 3
			ember.mesh = em
			ember.position = q + Vector3(0, 0.05, 0)
			var mm := _material(Color(1.0, 0.45, 0.15))
			mm.emission_enabled = true
			mm.emission = Color(1.0, 0.3, 0.05)
			mm.emission_energy_multiplier = 2.0
			ember.material_override = mm
			add_child(ember)
			continue
		var leaf := MeshInstance3D.new()
		leaf.mesh = _rock_mesh(seed + k, 0.16, 0.2)
		leaf.position = q + Vector3(0, 0.08, 0)
		leaf.material_override = stem
		add_child(leaf)
		var head := MeshInstance3D.new()
		head.mesh = _petal_mesh()
		head.position = q + Vector3(0, 0.3, 0)
		head.rotation.x = deg_to_rad(35.0)
		head.rotation.y = r.randf() * TAU
		var fc: Color = [Color(0.25, 0.45, 1.0), Color(1.0, 1.0, 1.0), Color(0.95, 0.22, 0.2), Color(1.0, 0.82, 0.2), Color(1.0, 0.55, 0.75)][r.randi() % 5]
		var fm := _material(fc)
		fm.cull_mode = BaseMaterial3D.CULL_DISABLED
		fm.emission_enabled = true
		fm.emission = fc * 0.25
		head.material_override = fm
		head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(head)


func _add_antler(base: Vector3, out: Vector3, mat: Material, length: float = 1.1) -> void:
	## A gold antler: a beam curving up and outwards with two tines.
	var up := Vector3.UP
	var a := base
	var dir := (up * 1.0 + out * 0.25).normalized()
	for seg in 4:
		var l := length * 0.3 * (1.0 - seg * 0.12)
		var b := a + dir * l
		var cyl := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.055 - seg * 0.008
		cm.bottom_radius = 0.07 - seg * 0.008
		cm.height = l + 0.04
		cm.radial_segments = 6
		cyl.mesh = cm
		cyl.position = (a + b) / 2.0
		cyl.look_at_from_position(cyl.position, b, Vector3.FORWARD if absf(dir.z) < 0.9 else Vector3.RIGHT)
		cyl.rotate_object_local(Vector3.RIGHT, PI / 2.0)
		cyl.material_override = mat
		add_child(cyl)
		if seg in [1, 2]:
			# A tine leaning further out.
			var tdir := (up * 0.6 + out * 0.9).normalized()
			var t := b + tdir * length * 0.3
			var tine := MeshInstance3D.new()
			var tm := CylinderMesh.new()
			tm.top_radius = 0.02
			tm.bottom_radius = 0.05
			tm.height = length * 0.3
			tm.radial_segments = 5
			tine.mesh = tm
			tine.position = (b + t) / 2.0
			tine.look_at_from_position(tine.position, t, Vector3.FORWARD if absf(tdir.z) < 0.9 else Vector3.RIGHT)
			tine.rotate_object_local(Vector3.RIGHT, PI / 2.0)
			tine.material_override = mat
			add_child(tine)
		a = b
		dir = (dir + out * 0.35 + up * 0.1).normalized()


func _add_crown_altar(team: int, throne: Vector3, side: float) -> void:
	## What the crown rests on. Elves: a green crystal cluster on a moonstone
	## plinth, flanked by gold antlers (the Wildbloom reference). Humans: the
	## carved pedestal with gold bands, lion crests and a velvet cushion.
	var color: Color = Stats.FACTIONS[team].color
	if team == 0:
		# A round, layered sandstone pedestal with gold bands (Faisal's
		# 2026-10-09 brief: a substantial rounded pedestal, not a block).
		for layer in [[0.78, 0.44, 0.16], [0.62, 0.64, 0.24], [0.5, 0.78, 0.04]]:
			var cyl := MeshInstance3D.new()
			var cm0 := CylinderMesh.new()
			cm0.top_radius = layer[0]
			cm0.bottom_radius = layer[0] + 0.04
			cm0.height = layer[2]
			cm0.radial_segments = 36
			cyl.mesh = cm0
			cyl.position = throne + Vector3(0, layer[1] + layer[2] / 2.0, 0)
			cyl.material_override = _gold() if layer[2] < 0.1 else _ashlar(Color(0.96, 0.93, 0.86))
			add_child(cyl)
		for ry in [0.48, 0.78]:
			var band := MeshInstance3D.new()
			var tm0 := TorusMesh.new()
			tm0.inner_radius = (0.78 if ry < 0.5 else 0.62) - 0.02
			tm0.outer_radius = (0.78 if ry < 0.5 else 0.62) + 0.05
			tm0.rings = 36
			tm0.ring_segments = 6
			band.mesh = tm0
			band.scale = Vector3(1, 0.5, 1)
			band.position = throne + Vector3(0, ry, 0)
			band.material_override = _gold()
			add_child(band)
		var r := RandomNumberGenerator.new()
		r.seed = 909
		for i in 5:
			var c := MeshInstance3D.new()
			var pm := PrismMesh.new()
			var h: float = 1.35 if i == 0 else r.randf_range(0.55, 0.85)
			pm.size = Vector3(0.34 if i == 0 else 0.22, h, 0.34 if i == 0 else 0.22)
			c.mesh = pm
			var a := TAU * i / 5.0
			var sp: float = 0.0 if i == 0 else 0.3
			c.position = throne + Vector3(cos(a) * sp, 0.78 + h / 2.0 - 0.05, sin(a) * sp)
			c.rotation = Vector3.ZERO if i == 0 else Vector3(cos(a) * 0.35, a, -sin(a) * 0.35)
			var cm := StandardMaterial3D.new()
			cm.albedo_color = Color(0.55, 1.0, 0.7, 0.85)
			cm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			cm.emission_enabled = true
			cm.emission = Color(0.25, 0.95, 0.5)
			cm.emission_energy_multiplier = 1.1   # (was 1.6: a restrained emerald glow, the brief)
			cm.roughness = 0.25
			c.material_override = cm
			add_child(c)
		for zs in [-1.0, 1.0]:
			_add_antler(throne + Vector3(0, 0.78, zs * 0.42), Vector3(0, 0, zs), _gold(), 1.15)
		var light := OmniLight3D.new()
		light.light_color = Color(0.45, 1.0, 0.6)
		light.light_energy = 0.9   # was 1.4: with the crown's own light it washed the altar out
		light.omni_range = 6.0
		light.position = throne + Vector3(0, 1.6, 0)
		add_child(light)
		return
	# The pedestal: a carved block with gold bands, the team crest on each
	# face and a velvet cushion on top.
	var trim := _gold()
	_add_block(throne + Vector3(0, 0.62, 0), Vector3(1.1, 0.62, 1.1), Color.WHITE, false, _ashlar(Color(0.98, 0.96, 0.9)))
	_add_block(throne + Vector3(0, 0.36, 0), Vector3(1.24, 0.1, 1.24), Color.WHITE, false, trim)
	_add_block(throne + Vector3(0, 0.95, 0), Vector3(1.24, 0.08, 1.24), Color.WHITE, false, trim)
	for d in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
		_add_crest(team, throne + d * 0.56 + Vector3(0, 0.66, 0), d, 0.42, true)
	_add_block(throne + Vector3(0, 1.08, 0), Vector3(0.95, 0.18, 0.95), Color.WHITE, false, _cloth(color))
	for zs in [-1.0, 1.0]:
		for xs in [-1.0, 1.0]:
			# Gold tassels at the cushion's corners.
			_add_block(throne + Vector3(xs * 0.46, 1.0, zs * 0.46), Vector3(0.08, 0.16, 0.08), Color.WHITE, false, _gold())


func _add_dais_ring(team: int, throne: Vector3, side: float) -> void:
	## Round the crown's dais: a trimmed hedge with blooms (Elves) or a ring of
	## short stone pillars with gold caps and blue pennants (Humans), open
	## towards the doors so the capture circle stays clear.
	var hz := ROOM_HALF_Z
	if team == 0:
		_add_hedge_ring(throne + Vector3(0, 0.0, 0), 2.85, Vector3(-side, 0, 0), 52.0, 0.42, 4242)
		return
	var n := 10
	var gap_a := atan2(0.0, -side)
	for k in n:
		var a := TAU * k / n
		if absf(angle_difference(a, gap_a)) < deg_to_rad(50.0):
			continue
		var p := throne + Vector3(cos(a) * 2.9, 0, sin(a) * 2.9)
		_add_block(p + Vector3(0, 0.5, 0), Vector3(0.34, 1.0, 0.34), Color.WHITE, false, _ashlar(Color(0.9, 0.88, 0.84)))
		_add_block(p + Vector3(0, 1.06, 0), Vector3(0.42, 0.12, 0.42), Color.WHITE, false, _gold())
		if k % 2 == 0:
			var out := Vector3(cos(a), 0, sin(a))
			_add_pennant(team, p + Vector3(0, 0.98, 0) - out * 0.22, -out, 0.5, 0.9, k % 4 == 0)


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
	var gm := _material(Color(0.82, 0.9, 1.0))
	gm.emission_enabled = true
	gm.emission = ELF_GLOW
	gm.emission_energy_multiplier = 2.2
	globe.material_override = gm
	globe.position = pos + Vector3(0, height + 0.2, 0)
	add_child(globe)
	_add_block(pos + Vector3(0, height + 0.5, 0), Vector3(0.22, 0.08, 0.22), Color.WHITE, false, _gold())
	var light := OmniLight3D.new()
	# Warm lamplight: the old pale green lit the whole yard green (2026-10-08 target).
	light.light_color = Color(1.0, 0.85, 0.6)
	light.light_energy = 0.8
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
	trunk.material_override = _pbr("bark", 0.6, ELF_BARK * 1.05)
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


var rosette_mats := {}


func _add_rosette(center: Vector3, radius: float, tint: Color = Color.WHITE) -> void:
	## A round paved disc (rings of flags inside a brick kerb) laid flat on
	## the ground as a decal: door courts and the shrine.
	var key := [tint, world_style]
	if not rosette_mats.has(key):
		# The match world's courts use the style copy (warm grey-tan flags, soft joints).
		var dir := StyleProfile.TEX_DIR if world_style else "res://assets/textures/"
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = load(dir + "rosette_color.png")
		mat.albedo_color = tint
		mat.normal_enabled = true
		mat.normal_texture = load(dir + "rosette_normal.jpg")
		mat.roughness = 0.85
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.alpha_scissor_threshold = 0.5
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		rosette_mats[key] = mat
	var m := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * radius * 2.0
	m.mesh = plane
	m.material_override = rosette_mats[key]
	m.position = center
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)



var emblem_mats := {}


func _emblem_mat(emblem: String, glow: Color = Color.BLACK) -> StandardMaterial3D:
	## An inked heraldic emblem (tools/make_emblems.py) as a cut-out decal.
	var key := emblem + str(glow)
	if not emblem_mats.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = load("res://assets/textures/emblems/%s.png" % emblem)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.alpha_scissor_threshold = 0.4
		mat.roughness = 0.6
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		if glow != Color.BLACK:
			mat.emission_enabled = true
			mat.emission = glow
			mat.emission_energy_multiplier = 0.6
		emblem_mats[key] = mat
	return emblem_mats[key]


func _add_emblem(emblem: String, pos: Vector3, out: Vector3, size: float, glow: Color = Color.BLACK) -> void:
	## An emblem decal standing on a surface that faces `out`.
	var m := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	m.mesh = q
	m.material_override = _emblem_mat(emblem, glow)
	m.position = pos
	m.rotation.y = atan2(out.x, out.z)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)


func _faction_emblem(team: int, alt: bool = false) -> String:
	if team == 0:
		# The stag (the top bar's shield) on the main banners, the great tree
		# on the alternates (Faisal's base target, 2026-10-08).
		return "tree" if alt else "stag"
	return "crown" if alt else "lion"


func _add_pennant(team: int, pos: Vector3, out: Vector3, width: float = 1.1, height: float = 1.9, alt: bool = false) -> void:
	## A tall heraldic banner on a wall: a gold rod, team cloth with a gold
	## hem and a pointed tail, and the faction's beast (or crown) on it.
	## `pos` is the top centre on the wall face; it hangs out along `out`.
	var color: Color = Stats.FACTIONS[team].color
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = atan2(out.x, out.z)
	add_child(n)
	var rod := MeshInstance3D.new()
	var rm := CylinderMesh.new()
	rm.top_radius = 0.045
	rm.bottom_radius = 0.045
	rm.height = width + 0.35
	rod.mesh = rm
	rod.rotation.z = PI / 2.0
	rod.position = Vector3(0, 0, 0.12)
	rod.material_override = _gold()
	n.add_child(rod)
	for xs in [-1.0, 1.0]:
		var knob := MeshInstance3D.new()
		var km := SphereMesh.new()
		km.radius = 0.08
		km.height = 0.16
		knob.mesh = km
		knob.position = Vector3(xs * (width / 2.0 + 0.18), 0, 0.12)
		knob.material_override = _gold()
		n.add_child(knob)
	var cloth_mat := _cloth(color.darkened(0.05))
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(width, height * 0.8, 0.04)
	body.mesh = bm
	body.position = Vector3(0, -height * 0.4, 0.1)
	body.material_override = cloth_mat
	n.add_child(body)
	# The pointed tail.
	var tail := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(width, height * 0.2, 0.04)
	tail.mesh = pm
	tail.rotation.z = PI
	tail.position = Vector3(0, -height * 0.9, 0.1)
	tail.material_override = cloth_mat
	n.add_child(tail)
	# Gold hems down the sides and across the top.
	for xs in [-1.0, 1.0]:
		var hem := MeshInstance3D.new()
		var hm := BoxMesh.new()
		hm.size = Vector3(0.07, height * 0.8, 0.05)
		hem.mesh = hm
		hem.position = Vector3(xs * (width / 2.0 - 0.06), -height * 0.4, 0.11)
		hem.material_override = _gold()
		n.add_child(hem)
	var top := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(width, 0.08, 0.05)
	top.mesh = tm
	top.position = Vector3(0, -0.06, 0.11)
	top.material_override = _gold()
	n.add_child(top)
	var em := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2.ONE * width * 0.82
	em.mesh = q
	em.material_override = _emblem_mat(_faction_emblem(team, alt))
	em.position = Vector3(0, -height * 0.42, 0.125)
	n.add_child(em)


func _add_crest(team: int, pos: Vector3, out: Vector3, size: float = 0.8, alt: bool = false) -> void:
	## A heater shield hung on a wall: team colour, gold rim, emblem.
	var color: Color = Stats.FACTIONS[team].color
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = atan2(out.x, out.z)
	add_child(n)
	var rim := MeshInstance3D.new()
	var rb := BoxMesh.new()
	rb.size = Vector3(size, size * 0.62, 0.06)
	rim.mesh = rb
	rim.position = Vector3(0, size * 0.18, 0.04)
	rim.material_override = _gold()
	n.add_child(rim)
	var tip := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(size, size * 0.5, 0.06)
	tip.mesh = pm
	tip.rotation.z = PI
	tip.position = Vector3(0, -size * 0.38, 0.04)
	tip.material_override = _gold()
	n.add_child(tip)
	var face := MeshInstance3D.new()
	var fb := BoxMesh.new()
	fb.size = Vector3(size * 0.86, size * 0.56, 0.06)
	face.mesh = fb
	face.position = Vector3(0, size * 0.19, 0.06)
	face.material_override = _cloth(color)
	n.add_child(face)
	var ftip := MeshInstance3D.new()
	var fp := PrismMesh.new()
	fp.size = Vector3(size * 0.86, size * 0.42, 0.06)
	ftip.mesh = fp
	ftip.rotation.z = PI
	ftip.position = Vector3(0, -size * 0.3, 0.06)
	ftip.material_override = _cloth(color)
	n.add_child(ftip)
	var em := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2.ONE * size * 0.62
	em.mesh = q
	em.material_override = _emblem_mat(_faction_emblem(team, alt))
	em.position = Vector3(0, 0.0, 0.1)
	n.add_child(em)


var rune_mats := {}


func _add_runes(center: Vector3, radius: float, color: Color) -> MeshInstance3D:
	## A glowing rune circle on the floor (class pads, the spawn circle).
	if not rune_mats.has(color):
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = load("res://assets/textures/emblems/runes.png")
		mat.albedo_color = color.lightened(0.25)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		rune_mats[color] = mat
	# A dark stone disc under the runes so they read on any floor.
	var disc := MeshInstance3D.new()
	var dm := CylinderMesh.new()
	dm.top_radius = radius * 0.98
	dm.bottom_radius = radius
	dm.height = 0.08
	dm.radial_segments = 32
	disc.mesh = dm
	disc.position = center + Vector3(0, 0.04, 0)
	disc.material_override = _pbr("greystone", 0.5, Color(0.55, 0.55, 0.62))
	add_child(disc)
	var m := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * radius * 2.0
	m.mesh = plane
	m.material_override = rune_mats[color]
	m.position = center + Vector3(0, 0.09, 0)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	return m


func _add_fire(pos: Vector3, size: float = 1.0) -> void:
	## A cartoon flame: an orange teardrop (a ball with a cone on top) round a
	## yellow one, plus two small licks either side. Unshaded, glowing.
	var parts := [[0.0, 0.0, 0.15, Color(1.0, 0.45, 0.1)], [0.0, 0.02, 0.09, Color(1.0, 0.9, 0.4)],
		[0.09, -0.02, 0.07, Color(1.0, 0.55, 0.12)], [-0.08, -0.03, 0.06, Color(1.0, 0.6, 0.15)]]
	for p in parts:
		var r: float = p[2] * size
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = p[3]
		mat.emission_enabled = true    # (unshaded ignores it; kept for the toon pass)
		mat.emission = p[3]
		mat.albedo_color = Color(p[3].r * 1.6, p[3].g * 1.6, p[3].b * 1.6)   # HDR: blooms
		var base := pos + Vector3(p[0] * size, p[1] * size + r, 0.0 if p[2] != 0.09 else 0.1 * size)
		var ball := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = r
		sm.height = r * 2.0
		sm.radial_segments = 10
		sm.rings = 6
		ball.mesh = sm
		ball.position = base
		ball.material_override = mat
		ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ball)
		var tip := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = r * 0.98
		cm.height = r * 2.2
		cm.radial_segments = 10
		tip.mesh = cm
		tip.position = base + Vector3(0, r * 1.1, 0)
		tip.material_override = mat
		tip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(tip)



func _add_banner_pole(team: int, pos: Vector3, yaw: float = 0.0) -> void:
	## A timber pole with a crossbar and the faction's banner hanging from it,
	## facing the camera: they flank each castle door (the target art).
	## `yaw` turns the whole frame about its foot (0 = facing +z).
	var c0 := get_child_count()
	var a0 := audit_blocks.size()
	# A two-post timber frame (Faisal's 2026-10-08 target art).
	var wood := _timber(Color(0.5, 0.36, 0.24))
	for xs in [-0.8, 0.8]:
		audit_label = "pole"
		_add_block(pos + Vector3(xs, 1.75, 0), Vector3(0.2, 3.5, 0.2), Color.WHITE, false, wood)
		audit_label = ""
		_add_block(pos + Vector3(xs, 0.1, 0), Vector3(0.45, 0.2, 0.45), Color.WHITE, false, _pbr("greystone", 0.5, Color(0.8, 0.8, 0.85)))
		_add_block(pos + Vector3(xs, 3.6, 0), Vector3(0.26, 0.12, 0.26), Color.WHITE, false, wood)
	_add_block(pos + Vector3(0, 3.35, 0.0), Vector3(2.0, 0.18, 0.18), Color.WHITE, false, wood)
	for xs in [-0.55, 0.55]:   # corner braces
		var brace := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.1, 0.6, 0.1)
		brace.mesh = bm
		brace.material_override = wood
		brace.position = pos + Vector3(xs, 3.05, 0)
		brace.rotation.z = 0.8 if xs > 0.0 else -0.8
		add_child(brace)
	_add_pennant(team, pos + Vector3(0, 3.28, 0.06), Vector3(0, 0, 1), 1.1, 2.2)
	if yaw != 0.0:
		_turn_since(c0, a0, pos, yaw)


func _turn_since(c0: int, a0: int, pivot: Vector3, yaw: float) -> void:
	## Turns every child added since index `c0` (and the audit boxes since
	## `a0`) by `yaw` about `pivot`, so an axis-aligned build can face any way.
	var t := Transform3D(Basis(Vector3.UP, yaw), pivot) * Transform3D(Basis.IDENTITY, -pivot)
	for i in range(c0, get_child_count()):
		var n := get_child(i)
		if n is Node3D:
			n.transform = t * n.transform
	for i in range(a0, audit_blocks.size()):
		audit_blocks[i][1] = t * (audit_blocks[i][1] as AABB)


func _add_torch_stand(pos: Vector3, height: float = 1.9) -> void:
	## A tall iron torch stand with a burning bowl (Humans' halls and courts).
	audit_label = "pole"
	_add_block(pos + Vector3(0, height / 2.0, 0), Vector3(0.14, height, 0.14), Color.WHITE, false, _iron())
	audit_label = ""
	_add_block(pos + Vector3(0, 0.06, 0), Vector3(0.5, 0.12, 0.5), Color.WHITE, false, _iron())
	var bowl := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.26
	bm.bottom_radius = 0.12
	bm.height = 0.22
	bowl.mesh = bm
	bowl.position = pos + Vector3(0, height + 0.1, 0)
	bowl.material_override = _iron()
	add_child(bowl)
	_add_fire(pos + Vector3(0, height + 0.12, 0), 2.0)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.26)
	light.light_energy = 1.3
	light.omni_range = 6.5
	light.omni_attenuation = 1.4
	light.position = pos + Vector3(0, height + 0.6, 0)
	add_child(light)

func _flagstone(tint: Color = Color.WHITE) -> StandardMaterial3D:
	if grey:   # the Humans' halls: cooler, darker flags
		return _pbr("flagstone_grey", 0.25, tint * Color(0.9, 0.9, 0.92))
	if elf_castle:   # cream sandstone squares (the reference's base floor)
		return _pbr("flagstone", 0.25, Color(0.97, 0.96, 0.9) * tint)
	return _pbr("flagstone_moss" if mossy else "flagstone", 0.25, tint)


func _uneven_flagstone(tint: Color = Color.WHITE) -> ShaderMaterial:
	## _flagstone() as irregular slabs with no flat repeating grid (UNEVEN_FLAGS_SHADER).
	if flags_shader == null:
		flags_shader = Shader.new()
		flags_shader.code = UNEVEN_FLAGS_SHADER
	var f := _flagstone(tint)
	var avg := Color(0.5, 0.5, 0.5)
	if f.albedo_texture != null:
		var img: Image = f.albedo_texture.get_image()
		if img != null:
			if img.is_compressed():
				img.decompress()
			img.resize(1, 1, Image.INTERPOLATE_BILINEAR)
			avg = img.get_pixel(0, 0)
	var m := ShaderMaterial.new()
	m.shader = flags_shader
	m.set_shader_parameter("noise_tex", load("res://assets/textures/water_noise.png"))
	m.set_shader_parameter("base", avg * f.albedo_color)
	return m


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
	var m := _material(StyleProfile.GOLD)
	m.metallic = 0.7
	m.roughness = 0.35
	return m


func _castle_kit() -> bool:
	## The 2026-10-31 castle kit (scripts/visual/castle_kit.gd): match world
	## castles only (the menus keep the old pieces; the mid-field ruins too).
	return world_style and (elf_castle or grey)


func _audit_ghost(pos: Vector3, size: Vector3) -> void:
	## The audit footprint of a pre-kit trim block the castle kit replaced.
	## Tree, resource and dressing placement read audit_blocks, so the kit
	## records exactly what the old pieces did and the world's layout (and
	## its gameplay fingerprint) stays the same.
	audit_blocks.append([audit_label if audit_label != "" else "block", AABB(pos - size / 2.0, size)])


func _add_wall(center: Vector3, size: Vector3, merlons: bool = true) -> void:
	## A solid ashlar wall with a cornice and merlons along its long axis.
	## The elven castle's walls are trimmed hedges instead (2026-10-08 target).
	# Walls along x stop 1 cm short at each end, tucking their end faces just
	# inside the cross walls: flush, the end and the cross wall's face shared
	# a plane at every corner and flickered.
	var body := size - Vector3(0.02, 0, 0) if size.x > size.z else size
	if _castle_kit():
		# Castle pass 2026-10-31 (picks Spawn D / Battle A): the same solid
		# body in big bevelled blocks, with a modelled coping, merlons and a
		# plinth course, and ivy on the Elves' walls instead of hedge tops.
		_add_block(center, body, Color.WHITE, true, CastleKit.wall_mat(self, grey))
		CastleKit.castle_wall_top(self, center, size, grey, merlons, elf_castle)
		# (The old trim's audit footprint, as below.)
		var gl := 0.008 if size.x >= size.z else 0.0
		var gtop := center.y + size.y / 2.0
		if grey and size.y >= WALL_H - 0.01:
			_audit_ghost(Vector3(center.x, center.y - size.y / 2.0 + 0.2 + gl, center.z), Vector3(size.x + 0.36, 0.4, size.z + 0.36))
		if hedge_tops or mossy:
			return
		if grey:
			_audit_ghost(Vector3(center.x, gtop + 0.15 + gl, center.z), size * Vector3(1, 0, 1) + Vector3(0.24, 0.3, 0.24))
			_audit_ghost(Vector3(center.x, gtop - 0.08 + gl, center.z), size * Vector3(1, 0, 1) + Vector3(0.12, 0.12, 0.12))
		else:
			_audit_ghost(Vector3(center.x, gtop + 0.1 + gl, center.z), size * Vector3(1, 0, 1) + Vector3(0.2, 0.2, 0.2))
		if merlons:
			var glen := maxf(size.x, size.z)
			var gn := maxi(int(glen / 1.3), 1)
			for k in gn:
				var t := -glen / 2.0 + (k + 0.5) * glen / gn
				var gp := Vector3(center.x + t, gtop + 0.5 + gl, center.z) if size.x >= size.z else Vector3(center.x, gtop + 0.5 + gl, center.z + t)
				_audit_ghost(gp, Vector3(0.6, 0.6, size.z) if size.x >= size.z else Vector3(size.x, 0.6, 0.6))
		return
	_add_block(center, body, Color.WHITE, true, _ashlar())
	var top := center.y + size.y / 2.0
	var along_x := size.x >= size.z
	var length := size.x if along_x else size.z
	var thick := size.z if along_x else size.x
	# Walls along x carry their trim 8 mm higher than walls along z, so the
	# cornices, string courses and plinths that cross at every corner never
	# share a plane (coplanar overlaps flicker as the camera pans).
	var lift := 0.008 if along_x else 0.0
	if grey and size.y >= WALL_H - 0.01:
		# The Humans' walls (Faisal's 03:34 brief: chunky stonework, not plain
		# boxes): a darker plinth course round the foot of the outer and
		# courtyard walls (the keep's walls have furniture against them)...
		var foot := center.y - size.y / 2.0
		_add_block(Vector3(center.x, foot + 0.2 + lift, center.z), Vector3(size.x + 0.36, 0.4, size.z + 0.36), Color.WHITE, false, _ashlar(Color(0.74, 0.74, 0.8)))
	if hedge_tops or mossy:
		# The Elves' hedge walls are topped with a run of trimmed hedge
		# (the reference's rounded, bushy wall tops; was a flat cap with a
		# few tufts on the castle walls until the 2026-10-09 graphics pass).
		var hn := maxi(int(length / 0.75), 1)
		var hmat := _hedge_mat(int(center.x * 3 + center.z * 7))
		for k in hn + 1:
			var t := -length / 2.0 + k * length / hn
			var hp := Vector3(center.x + t, top - 0.1, center.z) if along_x else Vector3(center.x, top - 0.1, center.z + t)
			_add_hedge_blob(hp, 0.5 + 0.08 * float(k % 3), int(hp.x * 5 + hp.z * 11) + k, hmat)
		return
	if mossy:
		# Hedge walls: a lighter clipped top and leaf tufts instead of merlons.
		_add_block(Vector3(center.x, top + 0.1 + lift, center.z), Vector3(size.x + 0.2, 0.2, size.z + 0.2), Color.WHITE, false, _hedge(true))
	elif grey:
		# ...and a thick, pale cornice with a bevel line under it.
		_add_block(Vector3(center.x, top + 0.15 + lift, center.z), Vector3(size.x + 0.24, 0.3, size.z + 0.24), Color.WHITE, false, _ashlar(Color(0.9, 0.9, 0.94)))
		_add_block(Vector3(center.x, top - 0.08 + lift, center.z), Vector3(size.x + 0.12, 0.12, size.z + 0.12), Color.WHITE, false, _ashlar(Color(0.66, 0.66, 0.72)))
	else:
		_add_block(Vector3(center.x, top + 0.1 + lift, center.z), Vector3(size.x + 0.2, 0.2, size.z + 0.2), Color.WHITE, false, _ashlar(Color(0.92, 0.88, 0.8)))
	if not merlons:
		return
	var n := maxi(int(length / 1.3), 1)
	for k in n:
		var t := -length / 2.0 + (k + 0.5) * length / n
		var p := Vector3(center.x + t, top + 0.5 + lift, center.z) if along_x else Vector3(center.x, top + 0.5 + lift, center.z + t)
		var ms := Vector3(0.6, 0.6, thick) if along_x else Vector3(thick, 0.6, 0.6)
		if mossy:
			# Leaf tufts along the hedge top (the cream moonstone caps read
			# as white balls from above, 2026-10-09 render).
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
	if _castle_kit():
		# Castle pass 2026-10-31 (pick Spawn D's towers): block body, plinth,
		# corbelled parapet with merlons, a tall team-tiled roof and long
		# banners on the faces nothing is built against (corner towers: the
		# outer x face, toward the field or the spawn courtyard, and the
		# camera-side z face). Same solid footprint.
		_add_block(pos + Vector3(0, height / 2.0, 0), Vector3(width, height, width), Color.WHITE, true, CastleKit.wall_mat(self, grey))
		var outs: Array = []
		if flag:
			outs.append(Vector3(signf(pos.x - side * CASTLE_X), 0, 0))
			if pos.z > 0.0:
				outs.append(Vector3(0, 0, 1))
		CastleKit.tower_dress(self, pos, team, width, height, grey, outs)
		CastleKit.tower_roof(self, pos, team, width, height)
		if mossy:
			CastleKit.lantern(self, pos + Vector3(-side * width / 2.0, height - 1.5, 0), Vector3(-side, 0, 0), false)
		# (The old trim's audit footprint and flag marker, so placement around
		# the castle stays the same.)
		_audit_ghost(pos + Vector3(0, height + 0.15, 0), Vector3(width + 0.5, 0.3, width + 0.5))
		if grey:
			_audit_ghost(pos + Vector3(0, 0.262, 0), Vector3(width + 0.5, 0.5, width + 0.5))
			_audit_ghost(pos + Vector3(0, height * 0.55 + 0.016, 0), Vector3(width + 0.2, 0.16, width + 0.2))
		if not mossy:
			for xs in [-1.0, 1.0]:
				for zs in [-1.0, 1.0]:
					_audit_ghost(pos + Vector3(xs * (width / 2.0), height + 0.6, zs * (width / 2.0)), Vector3(0.5, 0.6, 0.5))
		_audit_ghost(pos + Vector3(0, height + 0.38, 0), Vector3(width * 0.95, 0.16, width * 0.95))
		if flag:
			var marker := Node3D.new()
			marker.position = pos + Vector3(0, height + 2.25, 0)
			add_child(marker)
			audit_props.append(["hex/flag_%s" % ["green", "blue"][team], marker])
		return
	_add_block(pos + Vector3(0, height / 2.0, 0), Vector3(width, height, width), Color.WHITE, true, _ashlar())
	_add_block(pos + Vector3(0, height + 0.15, 0), Vector3(width + 0.5, 0.3, width + 0.5), Color.WHITE, false, _ashlar(Color(0.92, 0.88, 0.8)))
	if grey:
		# The Humans' towers stand on a chunky plinth with a string course.
		_add_block(pos + Vector3(0, 0.262, 0), Vector3(width + 0.5, 0.5, width + 0.5), Color.WHITE, false, _ashlar(Color(0.74, 0.74, 0.8)))
		_add_block(pos + Vector3(0, height * 0.55 + 0.016, 0), Vector3(width + 0.2, 0.16, width + 0.2), Color.WHITE, false, _ashlar(Color(0.66, 0.66, 0.72)))
	if mossy:
		# An elven tower: a lantern hung under a green shingle roof. (The leafy
		# canopy blobs it wore read as "giant blobs inside the building" from
		# the camera, Faisal 08:21.)
		var globe := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = 0.22
		sph.height = 0.44
		globe.mesh = sph
		var gm := _material(Color(0.82, 0.9, 1.0))
		gm.emission_enabled = true
		gm.emission = ELF_GLOW
		gm.emission_energy_multiplier = 2.0
		globe.material_override = gm
		globe.position = pos + Vector3(-side * (width / 2.0 + 0.4), height - 0.6, 0)
		add_child(globe)
		var light := OmniLight3D.new()
		light.light_color = Color(0.7, 1.0, 0.85)
		light.light_energy = 0.7
		light.omni_range = 6.0
		light.position = globe.position
		add_child(light)
	for xs in [-1.0, 1.0]:
		for zs in [-1.0, 1.0]:
			if mossy:
				continue
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
		cl.light_color = Color(0.7, 1.0, 0.85)
		cl.light_energy = 0.6
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
	_add_block(Vector3(center.x, y + 0.015, center.z), Vector3(size.x, 0.03, size.y), color, false, _carpet(color.darkened(0.05)))
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
	# Browsers: no lamp shadows (each is two more depth passes a frame).
	light.shadow_enabled = shadows and not OS.has_feature("web") and gfx_quality >= 1
	if shadows:
		lamp_shadows.append(light)
	light.shadow_bias = 0.08
	if elven:
		# Warm lantern light with a hint of green: pure green washed the
		# elven keep out (2026-10-07 render).
		light.light_color = Color(0.96, 0.92, 0.86)   # was Color(0.95, 0.92, 0.7): warm lamp, no green cast
		light.light_energy = 1.3
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
const ROOM_RAISE := 0.9     # the Elves' crown room floor sits this far up on a terrace (the sheet's upstairs)

func _room_wall_h(team: int, zs: float) -> float:
	## The throne room's wall height on the z side `zs`: the Humans' camera-
	## facing (+z) wall is a waist-high balustrade (Faisal's 03:34 brief:
	## open up the crown room), every other wall is full height.
	return 1.1 if (team == 1 and zs > 0.0) else ROOM_H


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
	var fy := throne.y   # the Elves' crown room is a storey up: a terrace with stairs to its doors
	audit_label = "vault"
	if fy > 0.0:
		_add_block(Vector3(cx, fy / 2.0, 0), Vector3(depth + 0.5, fy, hz * 2 + 0.5), Color.WHITE, true, _ashlar(Color(0.9, 0.86, 0.78)))
		# The flight up from the keep hall to the doors, between timber cheeks.
		_add_stairs(Vector3(front_x - side * 2.55, 0, 0), Vector3(front_x - side * 0.2, fy, 0), 3.6, _ashlar(Color(0.95, 0.92, 0.86)), 0.0)
		for zs in [-1.0, 1.0]:
			_add_block(Vector3(front_x - side * 1.35, fy / 2.0 + 0.15, zs * 1.95), Vector3(2.4, fy + 0.3, 0.3), Color.WHITE, true, _timber(Color(0.5, 0.36, 0.24)))
			_add_block(Vector3(front_x - side * 2.55, fy / 2.0 + 0.3, zs * 1.95), Vector3(0.4, fy + 0.6, 0.4), Color.WHITE, true, _timber(Color(0.5, 0.36, 0.24)))
			_add_block(Vector3(front_x - side * 2.55, fy + 0.65, zs * 1.95), Vector3(0.5, 0.1, 0.5), Color.WHITE, false, _gold())
	# Floor: dark marble with a pale border (Humans) or a mossy glade floor (Elves).
	if elven:
		# Cream sandstone squares with a hedge-green border strip (the
		# reference's altar court), rug arms added below.
		_add_block(Vector3(cx, fy + 0.05, 0), Vector3(depth, 0.04, hz * 2), Color.WHITE, false, _pbr("moss", 0.5, Color(0.7, 0.85, 0.55)))
		_add_block(Vector3(cx, fy + 0.06, 0), Vector3(depth - 1.2, 0.04, hz * 2 - 1.2), Color.WHITE, false, _pavers() if elven else _flagstone())
	else:
		_add_block(Vector3(cx, fy + 0.05, 0), Vector3(depth, 0.04, hz * 2), Color.WHITE, false, _marble(Color(0.55, 0.5, 0.52)))
		_add_block(Vector3(cx, fy + 0.06, 0), Vector3(depth - 1.2, 0.04, hz * 2 - 1.2), Color.WHITE, false, _pbr("flagstone_grey", 0.9, Color(1.0, 0.96, 0.9)))
	# Walls: side walls, the back wall, and the front wall either side of the doors.
	var wall_mat := _ashlar()
	# The Elves' crown room is an open court: its side and back walls are a
	# chunky waist-high sandstone parapet with hedge on top (the reference;
	# Faisal's 2026-10-09 brief), tall enough to stop sight lines and shots
	# (1.3 m: the eye ray is at 1.0, shots fly at 1.1). The front wall stays
	# full height for the vault doors. Footprint and collision are unchanged.
	var wall_h: float = 1.3 if elven else ROOM_H
	var wall_t: float = 0.7 if elven else 0.5
	for zs in [-1.0, 1.0]:
		await _world_build_frame()   # (built behind the menus: no long frame)
		# The Humans' camera-facing wall is a waist-high balustrade (the Elves'
		# are a parapet on both sides): the crown, its dais and anyone in the
		# room stay visible from the game camera.
		var wh: float = (wall_h if elven else _room_wall_h(team, zs)) + fy
		_add_block(Vector3(cx, wh / 2.0, zs * hz), Vector3(depth + 0.5, wh, wall_t), Color.WHITE, true, wall_mat)
		var seg := hz - ROOM_DOOR_HALF - 0.3
		_add_block(Vector3(front_x, (ROOM_H + fy) / 2.0, zs * (ROOM_DOOR_HALF + 0.3 + seg / 2.0)), Vector3(0.5, ROOM_H + fy, seg), Color.WHITE, true, wall_mat)
		# Door posts and the lintel over the doors (timber for the Elves).
		_add_block(Vector3(front_x, (ROOM_H + 0.3 + fy) / 2.0, zs * (ROOM_DOOR_HALF + 0.15)), Vector3(0.72, ROOM_H + 0.3 + fy, 0.3), Color.WHITE, true, _ashlar(Color(0.9, 0.86, 0.78)) if not elven else _timber(Color(0.5, 0.36, 0.24)))   # 0.72 not 0.7: its faces were flush with the raised floor's end and flickered
		# (The Elves' timber corner posts went on Faisal's 08:17 2026-10-09
		# note: they clipped into the walls and read as random.)
	_add_block(Vector3(back_x, (wall_h + fy) / 2.0, 0), Vector3(wall_t, wall_h + fy, hz * 2 + 0.5), Color.WHITE, true, wall_mat)
	_add_block(Vector3(front_x, ROOM_H - 0.2 + fy, 0), Vector3(0.7, 0.4, ROOM_DOOR_HALF * 2 + 0.6), Color.WHITE, false, _timber(Color(0.7, 0.6, 0.5)))
	# A cornice along every wall top (Humans), or a run of rounded hedge
	# along the hedge walls (Elves; the reference's bushy crown-room walls).
	var cap := _ashlar(Color(0.92, 0.88, 0.8))
	var wtop := wall_h + fy - 0.1
	# The Elves' walls take a plain sandstone cap like the Humans' (the hedge
	# runs on top read as "random greenery", Faisal 08:17 2026-10-09).
	var ecap := _ashlar(Color(0.96, 0.94, 0.9))
	for zs in [-1.0, 1.0]:
		await _world_build_frame()   # (built behind the menus: no long frame)
		if elven:
			_add_block(Vector3(cx, wall_h + 0.08 + fy, zs * hz), Vector3(depth + wall_t, 0.16, wall_t + 0.14), Color.WHITE, false, ecap)
		else:
			_add_block(Vector3(cx, _room_wall_h(team, zs) + 0.08 + fy, zs * hz), Vector3(depth + 0.7, 0.16, 0.7), Color.WHITE, false, cap)
	if elven:
		_add_block(Vector3(back_x, wall_h + 0.08 + fy, 0), Vector3(wall_t + 0.14, 0.16, hz * 2 + wall_t), Color.WHITE, false, ecap)
	else:
		_add_block(Vector3(back_x, ROOM_H + 0.08 + fy, 0), Vector3(0.7, 0.16, hz * 2 + 0.7), Color.WHITE, false, cap)
	for zs in [-1.0, 1.0]:
		await _world_build_frame()   # (built behind the menus: no long frame)
		_add_block(Vector3(front_x, ROOM_H + 0.08 + fy, zs * (hz / 2.0 + ROOM_DOOR_HALF / 2.0)), Vector3(0.7, 0.16, hz - ROOM_DOOR_HALF), Color.WHITE, false, ecap if elven else cap)
	audit_label = ""
	# A carpet runner from the doors to a round, three-tier dais in the middle
	# of the room; the crown sits on a cushioned pedestal on top (the
	# reference renders), with the empty throne against the back wall.
	_add_rug(Vector3((front_x + throne.x - side * 2.0) / 2.0, fy + 0.07, 0), Vector2(absf(throne.x - side * 2.0 - front_x), 1.9), color)
	if elven:
		# Rug arms out to the side walls and the back, each with the stag,
		# like the green stag runners round the reference's altar.
		for zs in [-1.0, 1.0]:
			_add_rug(Vector3(throne.x, fy + 0.07, zs * (hz / 2.0 + 1.5)), Vector2(1.6, hz - 3.0), color)
			_add_emblem_decal(Vector3(throne.x, fy + 0.15, zs * (hz / 2.0 + 1.5)), 1.1, team)
		_add_emblem_decal(Vector3((front_x + throne.x - side * 2.0) / 2.0, fy + 0.15, 0), 1.3, team)
	var tier_mat := _ashlar(Color(0.95, 0.92, 0.86))
	var trim := _gold() if not elven else _moon_silver()
	for t in 3:
		await _world_build_frame()   # (built behind the menus: no long frame)
		var r := 2.2 - t * 0.55
		var step := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = r
		cm.bottom_radius = r + 0.06
		cm.height = 0.14
		cm.radial_segments = 40
		step.mesh = cm
		step.position = throne + Vector3(0, 0.07 + t * 0.14, 0)
		step.material_override = tier_mat
		add_child(step)
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = r - 0.05
		tm.outer_radius = r + 0.02
		tm.rings = 40
		tm.ring_segments = 6
		ring.mesh = tm
		ring.scale = Vector3(1, 0.35, 1)
		ring.position = throne + Vector3(0, 0.14 + t * 0.14, 0)
		ring.material_override = trim
		add_child(ring)
	var top := MeshInstance3D.new()
	var topm := CylinderMesh.new()
	topm.top_radius = 1.0
	topm.bottom_radius = 1.0
	topm.height = 0.02
	topm.radial_segments = 32
	top.mesh = topm
	top.position = throne + Vector3(0, 0.43, 0)
	top.material_override = _carpet(color.darkened(0.15)) if not elven else _moonstone()
	add_child(top)
	_add_crown_altar(team, throne, side)
	_add_dais_ring(team, throne, side)
	# The empty throne against the back wall (Humans; the Elves' shrine has
	# the crystal altar as its focus and a stag crest on the back wall).
	var seat := throne + Vector3(side * 2.85, 0, 0)
	if not elven:
		_add_block(seat + Vector3(0, 0.3, 0), Vector3(1.0, 0.6, 1.2), Color.WHITE, false, _timber(Color(0.6, 0.45, 0.3)))
		_add_block(seat + Vector3(0, 0.66, 0), Vector3(0.9, 0.12, 1.0), Color.WHITE, false, _cloth(color))
		_add_block(seat + Vector3(side * 0.42, 1.3, 0), Vector3(0.2, 2.0, 1.2), Color.WHITE, false, _timber(Color(0.6, 0.45, 0.3)))
		_add_block(seat + Vector3(side * 0.3, 1.3, 0), Vector3(0.06, 1.6, 0.9), Color.WHITE, false, _cloth(color.darkened(0.15)))
		_add_block(seat + Vector3(side * 0.42, 2.35, 0), Vector3(0.26, 0.2, 1.3), Color.WHITE, false, _gold())
		for zs in [-1.0, 1.0]:
			_add_block(seat + Vector3(0, 0.82, zs * 0.56), Vector3(0.9, 0.14, 0.14), Color.WHITE, false, _gold())
			_add_block(seat + Vector3(side * 0.42, 2.55, zs * 0.5), Vector3(0.16, 0.24, 0.16), Color.WHITE, false, _gold())
	# (The Elves' low walls carry no crest or pennant: the stag hangs on the
	# banner poles round the dais instead.)
	# Banners, crests, torches and the treasury.
	for zs in [-1.0, 1.0]:
		await _world_build_frame()   # (built behind the menus: no long frame)
		if not elven:
			if _room_wall_h(team, zs) == ROOM_H:
				_add_pennant(team, Vector3(cx - side * 0.2, ROOM_H - 0.05 + fy, zs * (hz - 0.25)), Vector3(0, 0, -zs), 1.0, 1.8)
			_add_crest(team, Vector3(back_x - side * 0.27, 1.75 + fy, zs * 3.3), Vector3(-side, 0, 0), 0.6, zs > 0.0)
		if elven:
			_add_crystal(Vector3(back_x - side * 0.9, fy, zs * (hz - 0.9)), 0.9)
		# (The Humans' torch stands in the room's corners went (Faisal 2026-10-09 08:14, circled as clipping or out of place).)
		_add_banner(team, Vector3(front_x - side * 0.4, fy, zs * (ROOM_DOOR_HALF + 1.6)), Vector3(-side, 0, 0), 0.6, true)
	_add_light(Vector3(back_x - side * 0.8, 1.6 + fy, 0), color.lightened(0.4), 1.0, 6.0)
	_add_light(throne + Vector3(0, 2.2, 0), Color(1.0, 0.85, 0.5), 1.2 if not elven else 0.3, 4.5)
	if elven:   # (the Humans' chests and cask against the walls went (Faisal 2026-10-09 08:14, circled as clipping or out of place))
		_prop("dungeon/chest_gold", Vector3(back_x - side * 0.9, fy, -(hz - 0.8)), 0.7, PI / 2.0 if side < 0.0 else -PI / 2.0)
		_prop("dungeon/chest", Vector3(back_x - side * 1.0, fy, hz - 0.9), 0.6, PI / 2.0 if side < 0.0 else -PI / 2.0)
		_prop("dungeon/barrel_small", Vector3(back_x - side * 0.7, fy, -(hz - 2.0)), 0.8)
	if elven:
		_add_fireflies(throne + Vector3(0, 0.8, 0))
		# (No stag banner frames at the court's back corners: "random sign",
		# Faisal 08:17 2026-10-09.)


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
	var planks := _pbr("wood", 0.55, Color(0.46, 0.38, 0.34)) if not elven else _pbr("wood_dark", 0.5, Color(0.92, 0.78, 0.64))
	var wainscot := _pbr("wood_dark", 0.5, Color(0.85, 0.75, 0.62)) if not elven else _pbr("wood_dark", 0.5, Color(0.78, 0.62, 0.5))
	# --- Floors -------------------------------------------------------------
	# Entrance hall: fine flags; great hall: planks; chapel: a dark carpet on
	# stone (or a mossy glade); chambers: planks under big rugs.
	# (The keep's floor strips overlap, so each sits at its own height: they
	# were all at 0.045 and their shared tops flickered.)
	_add_block(Vector3(kx + side * 1.8, 0.052, 0), Vector3(2.8, 0.03, wz * 2), Color.WHITE, false, _pbr("flagstone" if elven else "flagstone_grey", 0.9, ELF_MOONSTONE * 0.88 if elven else Color(0.95, 0.95, 0.97)))
	_add_block(Vector3((room_f + room_b) / 2.0, 0.045, -g_z), Vector3(ROOM_FRONT + ROOM_BACK + 0.7, 0.03, g_w), Color.WHITE, false, _pavers() if elven else planks)
	if elven:
		_add_block(Vector3((room_f + room_b) / 2.0, 0.045, g_z), Vector3(ROOM_FRONT + ROOM_BACK + 0.7, 0.03, g_w), Color.WHITE, false, _pavers() if elven else _flagstone())
	else:
		_add_block(Vector3((room_f + room_b) / 2.0, 0.045, g_z), Vector3(ROOM_FRONT + ROOM_BACK + 0.7, 0.03, g_w), Color.WHITE, false, _pbr("carpet", 1.1, Color(0.3, 0.3, 0.5)))
	_add_block(Vector3(back_c, 0.038, 0), Vector3(back_d, 0.03, wz * 2), Color.WHITE, false, planks)
	# --- Panelled walls: a wainscot along every inner face, with a ledge. ---
	for zs in [-1.0, 1.0]:
		var depth := absf(bx - kx) - 1.2
		_add_block(Vector3((kx + bx) / 2.0, 0.5, zs * (wz - 0.05)), Vector3(depth, 1.0, 0.1), Color.WHITE, false, wainscot)
		_add_block(Vector3((kx + bx) / 2.0, 1.03, zs * (wz - 0.09)), Vector3(depth, 0.06, 0.18), Color.WHITE, false, _timber(Color(0.6, 0.5, 0.4)) if not elven else _moonstone())
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
	_add_flame(hearth + Vector3(0, 0.35, 0.3), 0.22, Color(1.0, 0.6, 0.2) if not elven else ELF_GLOW)
	_add_light(hearth + Vector3(0, 0.9, 1.0), Color(1.0, 0.7, 0.4) if not elven else ELF_GLOW, 1.4, 7.0)
	if elven:   # (the Humans' keg and cheese crate in the crown room's corner went (Faisal 2026-10-09 08:14, circled as clipping or out of place))
		_prop("dungeon/keg", Vector3(room_f + side * 0.4, 0, -(wz - 0.5)), 0.55, 0.3)
		_prop("kitchen/crate_carrots", Vector3(room_f - side * 1.0, 0, -(wz - 0.55)), BITS_SCALE * 0.9, 0.4)
	# --- The chapel (Humans) or the moon shrine (Elves) (z > 0). ---
	if elven:
		# A still pool of moonlight ringed with stones, a shrine stone and crystals.
		var pool := Vector3((room_f + room_b) / 2.0, 0, wz - 1.05)
		var water := _material(Color(0.6, 0.78, 1.0))
		water.emission_enabled = true
		water.emission = Color(0.45, 0.65, 1.0)
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
		# (The glowing window hung on the camera-facing wall, which is now a
		# low balustrade for the Humans: the glass is a lit panel on the altar's
		# back instead.)
		_add_block(Vector3(altar.x, 0.72, wz - 0.42), Vector3(1.0, 0.5, 0.05), Color.WHITE, false, glass)
		_add_block(Vector3(altar.x, 0.72, wz - 0.4), Vector3(1.15, 0.62, 0.04), Color.WHITE, false, _gold())
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
	else:
		_prop("furniture/shelf_B_large_decorated", Vector3(bw - side * 0.1, 0, -4.1), BITS_SCALE, PI / 2.0 if side > 0.0 else -PI / 2.0)
		# (Its cabinet by the crown room's back corner went (Faisal 2026-10-09 08:14, circled as clipping or out of place).)
		_prop("furniture/pictureframe_large_A", Vector3(bx - side * 0.62, 1.6, -2.6), BITS_SCALE, PI / 2.0 if side > 0.0 else -PI / 2.0)
	if not elven:   # (the Elves' loose study and armoury rugs went 08:17 2026-10-09)
		_add_rug(Vector3(back_c, 0.06, -4.0), Vector2(minf(back_d - 1.8, 4.6), 2.8), color)
	# The armoury.
	_prop("hex/weaponrack", Vector3(bw + side * 0.15, 0, 5.2), 4.0, PI / 2.0 if side > 0.0 else -PI / 2.0)
	_prop("dungeon/sword_shield_gold" if not elven else "dungeon/sword_shield", Vector3(bx - side * 0.62, 1.4, 3.2 if elven else 3.75), 0.9, PI / 2.0 if side > 0.0 else -PI / 2.0)
	if elven:   # (the Humans' camera-facing keep wall is waist high: nothing hangs on it)
		_prop("dungeon/sword_shield", Vector3(room_b + side * 1.6, 1.5, wz - 0.1), 0.9, 0.0)
	if not elven:
		_add_rug(Vector3(back_c, 0.06, 4.0), Vector2(minf(back_d - 1.8, 4.6), 2.8), color.darkened(0.2))
	# Tapestries and torches along the galleries, braziers for the Humans.
	for zs in [-1.0, 1.0]:
		var ins := Vector3(0, 0, -zs)
		if elven or zs < 0.0:   # (the Humans' camera-facing keep wall is waist high: nothing hangs on it)
			# The Elves' keep walls are waist high under a hedge, so no
			# tapestry hangs there (it stood up through the hedge, with the
			# carrot crate and crystal torch in front: Faisal 2026-10-15).
			# The Humans' first one hangs between the two wall torches, the
			# second above the long table (both cut into them before).
			if not elven:
				_add_tapestry(team, Vector3(kx + side * 2.1, 0.5, zs * wz), ins, 0.9, 1.9)   # between the two wall torches
				_add_tapestry(team, Vector3((room_f + room_b) / 2.0 - side * 1.2, 1.25, zs * wz), ins, 1.2, 1.15)
			_add_wall_torch(Vector3(room_f - side * 0.2, 0.9 if elven else 1.6, zs * (wz - 0.05)), ins)
			_add_wall_torch(Vector3(room_b + side * 1.5, 1.6, zs * (wz - 0.05)), ins)
	if elven:
		_add_fireflies(Vector3(kx + side * 2.0, 0.5, 5.5))


func _polish_keep(team: int, kx: float, side: float, throne: Vector3) -> void:
	## The finishing pass on the keep from Faisal's 12:55 target art: chunky
	## cap stones on the throne room's walls, banners on every face, torches
	## at its corners, a round royal carpet under the dais and an EXIT sign.
	var color: Color = Stats.FACTIONS[team].color
	var elven := team == 0
	var front_x := throne.x - side * ROOM_FRONT
	var back_x := throne.x + side * ROOM_BACK
	var cx := (front_x + back_x) / 2.0
	var depth := ROOM_FRONT + ROOM_BACK
	var hz := ROOM_HALF_Z
	# Chunky, slightly uneven cap stones along the wall tops (Humans); the
	# Elves' grown walls keep their leaf tufts.
	if not elven:
		var r := RandomNumberGenerator.new()
		r.seed = 4242 + team
		var runs := []   # [start, end, fixed, along_x, z sign, wall top]
		for zs in [-1.0, 1.0]:
			runs.append([cx - depth / 2.0 - 0.3, cx + depth / 2.0 + 0.3, zs * hz, true, 1.0, _room_wall_h(team, zs)])
			runs.append([ROOM_DOOR_HALF + 0.3, hz + 0.3, front_x, false, zs, ROOM_H])
		runs.append([-hz - 0.3, hz + 0.3, back_x, false, 1.0, ROOM_H])
		for run in runs:
			var a: float = minf(run[0], run[1])
			var b: float = maxf(run[0], run[1])
			var t := a
			var k := 0
			while t < b - 0.2:
				var l := minf(r.randf_range(0.8, 1.2), b - t)
				var h := r.randf_range(0.26, 0.38)
				var tint := Color(0.86, 0.88, 0.95) if k % 2 == 0 else Color(0.72, 0.74, 0.82)
				var mid := t + l / 2.0
				var p: Vector3
				var s: Vector3
				var top_y: float = run[5] + 0.16 + throne.y
				if run[3]:
					p = Vector3(mid, top_y + h / 2.0, run[2])
					s = Vector3(l - 0.06, h, 0.78)
				else:
					var zz: float = mid * run[4]
					p = Vector3(run[2], top_y + h / 2.0, zz)
					s = Vector3(0.78, h, l - 0.06)
				_add_block(p, s, Color.WHITE, false, _ashlar(tint))
				t += l
				k += 1
	# Banners: two either side of the throne on the back wall, two on the
	# outside of each side wall (they face the galleries and the camera).
	for zs in [-1.0, 1.0]:
		if elven:
			continue   # the Elves' crown-room walls are waist high: nothing hangs on them
		_add_pennant(team, Vector3(back_x - side * 0.27, ROOM_H - 0.1 + throne.y, zs * 1.7), Vector3(-side, 0, 0), 0.9, 1.6, zs > 0.0)
		for xs in [-1.0, 1.0]:
			if _room_wall_h(team, zs) == ROOM_H:
				_add_pennant(team, Vector3(cx + xs * 1.6, ROOM_H - 0.1 + throne.y, zs * (hz + 0.27)), Vector3(0, 0, zs), 1.0, 1.7, xs > 0.0)
	# Fire pillars by the keep's archway and against its back wall (Elves;
	# UI & Art), plain torches at the room's outer corners (Humans: their iron
	# braziers, weapon rack and shelf already hold those wall spots). Both
	# teams used to have solid stone pillars at the room's outer corners,
	# which closed the gap between the wall and the gallery: raiders leaving
	# the stairs slid along the room's back wall into that corner and never
	# got out (both keeps, 0-0 matches).
	for zs in [-1.0, 1.0]:
		if elven:
			_add_stone_brazier(Vector3(kx + side * 1.0, 0, zs * (KEEP_DOOR_HALF + 2.4)))
			_add_stone_brazier(Vector3(side * (CASTLE_X + CASTLE_DEPTH) - side * 1.0, 0, zs * (hz + 0.85)))
		# (The Humans' four torches at the room's outer corners went with the
		# declutter of 2026-10-09 06:00: the room's own stands light it.)
		# (The Humans' back torch stands and the candle stands by the dais
		# went (Faisal 2026-10-09 08:14, circled as clipping or out of place): the crown and its dais stand alone.)
	# The royal carpet: a round rug in the team colour with two gold rings,
	# under the dais (it stops short of the doors).
	var rug_r := 2.6
	var disc := MeshInstance3D.new()
	var dm := CylinderMesh.new()
	dm.top_radius = rug_r
	dm.bottom_radius = rug_r
	dm.height = 0.012
	dm.radial_segments = 48
	disc.mesh = dm
	disc.position = throne + Vector3(0, 0.09, 0)
	disc.material_override = _carpet(color.darkened(0.1)) if not elven else _carpet(color.darkened(0.45))
	add_child(disc)
	for rr in [rug_r - 0.08, rug_r - 0.45]:
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = rr - 0.06
		tm.outer_radius = rr
		tm.rings = 48
		tm.ring_segments = 4
		ring.mesh = tm
		ring.scale = Vector3(1, 0.25, 1)
		ring.position = throne + Vector3(0, 0.1, 0)
		ring.material_override = _gold() if not elven else _moon_silver()
		add_child(ring)
	# An EXIT sign by the keep's archway: a board on a post with an arrow
	# pointing out to the yard.
	var sp := Vector3(kx + side * 1.6, 0, KEEP_DOOR_HALF + 1.4)
	_add_block(sp + Vector3(0, 0.9, 0), Vector3(0.1, 1.8, 0.1), Color.WHITE, false, _timber(Color(0.55, 0.42, 0.3)))
	_add_block(sp + Vector3(0, 1.75, 0.08), Vector3(1.5, 0.5, 0.08), Color.WHITE, false, _material(Color(0.13, 0.1, 0.08)))
	_add_block(sp + Vector3(0, 1.75, 0.05), Vector3(1.6, 0.6, 0.06), Color.WHITE, false, _gold())
	var arrow := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(0.3, 0.26, 0.04)
	arrow.mesh = pm
	arrow.rotation.z = PI / 2.0 if side > 0.0 else -PI / 2.0
	arrow.position = sp + Vector3(-side * 0.5, 1.75, 0.14)
	var amat := _material(Color(1.0, 0.85, 0.4))
	amat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	arrow.material_override = amat
	add_child(arrow)
	_add_block(sp + Vector3(-side * 0.32, 1.75, 0.13), Vector3(0.2, 0.08, 0.02), Color.WHITE, false, amat)
	var lab := Label3D.new()
	lab.text = "EXIT"
	lab.font_size = 64
	lab.pixel_size = 0.005
	lab.outline_size = 10
	lab.outline_modulate = Color(0.05, 0.04, 0.03)
	lab.modulate = Color(1.0, 0.95, 0.85)
	lab.shaded = false
	lab.position = sp + Vector3(side * 0.18, 1.75, 0.14)
	add_child(lab)


func _furnish_cellar(team: int, bx: float, side: float) -> void:
	## Room lights, shelves and candles in the spawn cellar (no bunks: Faisal 2026-10-07).
	var color: Color = Stats.FACTIONS[team].color
	var elven := team == 0
	var hz := CELLAR_HALF_Z
	var fy := cellar_floor(team)
	# Three warm room lights down the hall (no hanging fixtures: it is open to the sky).
	for k in 3:
		var x: float = bx + side * (3.5 + k * 5.5)
		_add_chandelier(Vector3(x, fy + 2.5, 0), elven)
	if fy >= 0.0:
		return   # the open courtyard's stores are grouped by its workshop
	# A shelf of supplies by the stairs and candles along the side walls.
	for zs in [1.0]:   # the north wall holds the class alcoves
		if elven:
			_prop("dungeon/shelves", Vector3(bx + side * 1.4, CELLAR_Y, zs * (hz - 0.5)), 0.7, PI if zs > 0.0 else 0.0)
			_prop("dungeon/bottle_A_labeled_green", Vector3(bx + side * 1.4, CELLAR_Y + 0.95, zs * (hz - 0.75)), 0.5)
		else:
			_prop("dungeon/shelves", Vector3(bx + side * 1.4, CELLAR_Y, zs * (hz - 0.5)), 0.7, PI if zs > 0.0 else 0.0)
			_prop("dungeon/bottle_A_labeled_brown", Vector3(bx + side * 1.4, CELLAR_Y + 0.95, zs * (hz - 0.75)), 0.5)
		if elven:
			_add_mushrooms(Vector3(bx + side * 4.9, CELLAR_Y, zs * (hz - 0.6)), 51 + int(zs))
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
	light.shadow_enabled = shadows and not OS.has_feature("web") and gfx_quality >= 1
	if shadows:
		lamp_shadows.append(light)
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
		await _world_build_frame()
		await _build_hamlet(team, sx)
		await _world_build_frame()
		_build_farm(team, sx)
		await _world_build_frame()
		await _build_works(team, sx)
	if lmap == null:   # (the field's own dressing; Stonekeep and Twilight dress their lanes in scripts/lanes.gd)
		await _world_build_frame()
		_add_road_lanterns()
		await _world_build_frame()
		_add_road_dressing()
		await _world_build_frame()
		_add_river_plants()
		await _world_build_frame()
		_add_barrow(Vector3(-30, 0, 22))
		# (No watermills: Faisal 08:20, "random useless building".)
		await _world_build_frame()
		_add_field_rocks()
	await _world_build_frame()
	_add_clouds()
	await _world_build_frame()
	await _add_ground_patches()
	await _world_build_frame()
	_add_ambient_life()


func _add_ground_patches() -> void:
	## Sandy strips along the river banks and moss beds under the Wildwood trees.
	var sand := _sand()
	for sx in [-1.0, 1.0]:
		var z := -map_half.y - 2.0
		while z < map_half.y + 2.0:
			var blocked := lmap != null or absf(z) < ISLAND_R + 1.5   # (no river on Stonekeep / Twilight)
			for b in BRIDGES:
				if absf(z - b) < 3.2:
					blocked = true
			if not blocked:
				_add_block(Vector3(sx * (RIVER_HALF + 0.9), 0.004, z + 2.0), Vector3(1.6, 0.008, 4.0), Color.WHITE, false, sand)
			z += 4.0
			await _world_build_frame()   # (claude-faisal/stutter: one 31 ms step behind the title before)
	var moss := _moss()
	var r := RandomNumberGenerator.new()
	r.seed = 606
	for t in map_trees:
		await _world_build_frame()
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
			await _world_build_frame()
			_add_treehouse(Vector3(ox + sx * b[1], 0, oz - 0.5), int(b[1] * 7.0) + 11, b[2])
		else:
			await _world_build_frame()
			_add_house(b[0], team, Vector3(ox + sx * b[1], 0, oz), b[2], face)
	for b in back:
		if b[0] == "treehouse":
			await _world_build_frame()
			_add_treehouse(Vector3(ox + sx * b[1], 0, oz - 6.5), int(b[1] * 5.0) + 23, b[2])
		else:
			await _world_build_frame()
			_add_house(b[0], team, Vector3(ox + sx * b[1], 0, oz - 5.5), b[2], face, b[0] == "blacksmith")
	if team == 0:
		for k in 4:
			await _world_build_frame()
			_add_mushrooms(Vector3(ox + sx * (-12.0 + k * 7.0), 0, oz + 1.6 + (k % 2) * 0.8), 500 + k)
		await _world_build_frame()
		_add_fireflies(Vector3(ox, 0, oz - 3.0))
	# Chickens scratching about the lane.
	for k in 4:
		await _world_build_frame()
		_add_critter("chicken", Vector3(ox - 7.0 + k * 4.0, 0, oz + 2.4), Rect2(ox - 9.0, oz + 1.9, 18.0, 1.1), 700 + k)
	# Market clutter, a cart, fences along the lane, lanterns at the corners.
	await _world_build_frame()
	_prop("hex/crate_A_big", Vector3(ox + sx * -7.2, 0, oz - 2.9), 4.0, 0.3)
	await _world_build_frame()
	_prop("hex/sack", Vector3(ox + sx * -6.3, 0, oz - 2.7), 4.0, 1.0)
	await _world_build_frame()
	_prop("hex/barrel", Vector3(ox + sx * -4.0, 0, oz - 3.0), 4.0)
	await _world_build_frame()
	_prop("hex/wheelbarrow", Vector3(ox + sx * 1.2, 0, oz - 2.6), 4.0, 0.6)
	await _world_build_frame()
	_prop("hex/crate_open", Vector3(ox + sx * 12.3, 0, oz - 1.6), 4.0, 0.2)
	await _world_build_frame()
	_prop("hex/resource_lumber" if team == 0 else "hex/resource_stone", Vector3(ox + sx * 12.6, 0, oz - 3.8), 4.0, 0.0)
	for x in [ox - 13.2, ox + 13.2]:
		if team == 0:
			await _world_build_frame()
			_add_lantern(Vector3(x, 0, oz + 3.0), 2.4)
		else:
			await _world_build_frame()
			_prop("halloween/post_lantern", Vector3(x, 0, oz + 3.0), 0.75)
			await _world_build_frame()
			_add_light(Vector3(x, 2.4, oz + 3.0), Color(1.0, 0.75, 0.4), 1.1, 7.0)
	# Trees hugging the village.
	for k in 6:
		var tx: float = ox - 14.0 + k * 5.8
		await _world_build_frame()
		_prop("hex/trees_%s_medium" % ["A", "B"][k % 2], Vector3(tx + (k % 2) * 1.5, 0, oz - 9.5), 4.2, float(k))
	for x in [ox - 15.5, ox + 15.5]:
		await _world_build_frame()
		_prop("hex/tree_single_A", Vector3(x, 0, oz - 2.0), 4.6, x)
		await _world_build_frame()
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
	# Wheat never casts shadows: thousands of stalks in every shadow pass for
	# fields that sit off-screen in play.
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
	hinst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(hinst)


func _build_works(team: int, sx: float) -> void:
	## Behind the cellar: the Kingdom's mine, the Forest's lumber camp, and
	## mountains on the horizon.
	var c := _hex_color(team)
	var x := sx * 100.0   # clear of the (bigger) spawn cellar
	_add_house("mine" if team == 1 else "lumbermill", team, Vector3(x, 0, 14.0), 4.0, -PI / 2.0 * sx, team == 1)
	await _world_build_frame()   # (claude-faisal/stutter: one 55 ms step behind the title before)
	if team == 1:
		_add_house("barracks", team, Vector3(x, 0, -14.0), 3.6, -PI / 2.0 * sx)
	else:
		_add_treehouse(Vector3(x, 0, -14.0), 53, 1.08)
	await _world_build_frame()
	for k in 3:
		_prop("hex/resource_%s" % ["stone" if team == 1 else "lumber"], Vector3(x - sx * 5.0, 0, 9.5 + k * 2.4), 4.0, float(k) * 0.7)
	# (The tent and flag gave way to the trees.)
	_prop("hex/trees_%s_large" % ["A" if team == 0 else "B"], Vector3(x - sx * 2.0, 0, 22.0), 4.4, 1.0)
	_prop("hex/trees_%s_large" % ["B" if team == 0 else "A"], Vector3(x + sx * 4.0, 0, -22.0), 4.4, 2.0)
	for zs in [-1.0, 1.0]:
		_prop("hex/mountain_%s_grass_trees" % ["A", "B", "C"][int(zs + 1.0 + (0.0 if sx < 0.0 else 1.0)) % 3], Vector3(sx * 112.0, -0.3, zs * 26.0), 10.0, sx * zs)
	_prop("hex/mountain_B_grass", Vector3(sx * 116.0, -0.3, 0.0), 10.0, sx)
	# Behind each spawn courtyard: a stand of trees where the camp was, so
	# the ground beyond the wall reads as woodland, not a busy yard (Faisal
	# 2026-10-09 08:13 Humans, 08:18 Elves: "flush this area out with trees").
	for tp in [Vector3(92.5, 0, -9.0), Vector3(94.0, 0, -3.5), Vector3(92.5, 0, 2.0), Vector3(94.0, 0, 7.5), Vector3(97.5, 0, -6.0), Vector3(97.5, 0, 0.5), Vector3(97.0, 0, 6.0), Vector3(92.0, 0, 11.5)]:
		await _world_build_frame()
		_add_tree(Vector3(sx * tp.x, 0, tp.z), int(tp.z) % 2 == 0)
	await _world_build_frame()
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
		var pos := Vector3(sx * (RIVER_HALF + 3.8), 0, z)
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
	hub.set_meta("no_batch", true)   # turns
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
		if absf(x) < RIVER_HALF + 4.0 or absf(z) < 7.5:
			continue
		if Vector2(x, z).distance_to(Vector2(-30.0, 22.0)) < 9.0:
			continue
		# Clear of anything already standing (ruins, crates, fences, benches)
		# and of the landmarks.
		var crowded := false
		for ap in audit_props:
			var q: Vector3 = ap[1].position
			if Vector2(q.x - x, q.z - z).length() < 3.0:
				crowded = true
				break
		for mark in map_marks:
			if Vector2(mark[0].x - x, mark[0].z - z).length() < 6.0:
				crowded = true
		if crowded:
			continue
		if absf(absf(z) - 30.0) < 6.0 and absf(x) < RIVER_HALF + 8.0:
			continue   # the watermills
		var near_tree := false
		for t in map_trees:
			if Vector2(t.x, t.z).distance_to(Vector2(x, z)) < (3.8 if t.y > 0.5 else 2.8):
				near_tree = true
				break
		if near_tree:
			continue
		# Off the cobbled paths and the potions too (Faisal 08:16: a rock
		# clipped the Forest Path by the Humans' gate).
		if _near_path(Vector3(x, 0, z), 2.2):
			continue
		var near_orb := false
		for orb in heal_orbs:
			if _flat_dist(Vector3(x, 0, z), orb.global_position) < 3.0:
				near_orb = true
		if near_orb:
			continue
		_prop("hex/rock_single_%s" % ["A", "B", "C", "D", "E"][r.randi() % 5], Vector3(x, 0, z), r.randf_range(2.2, 3.4), r.randf() * TAU)
		if r.randf() < 0.4:
			_prop("hex/rock_single_%s" % ["A", "B"][r.randi() % 2], Vector3(x + 1.7, 0, z + 1.0), 1.8, r.randf() * TAU)
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
		n.set_meta("no_batch", true)   # drifts (scripts/static_batch.gd leaves it alone)
		var tw := create_tween().set_loops()
		var drift := Vector3(7.0 if i % 2 == 0 else -7.0, 0, 0)
		tw.tween_property(n, "position", sp[0] + drift, 36.0 + i * 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(n, "position", sp[0], 36.0 + i * 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _add_stone_brazier(pos: Vector3, lit: bool = true) -> void:
	## A square grey-stone pillar with a fire bowl on top (the 2026-10-08 target art).
	var stone := _pbr("greystone", 0.45, Color(0.82, 0.82, 0.88))
	audit_label = "pole"
	_add_block(pos + Vector3(0, 0.15, 0), Vector3(0.95, 0.3, 0.95), Color.WHITE, true, stone)
	_add_block(pos + Vector3(0, 0.75, 0), Vector3(0.7, 0.9, 0.7), Color.WHITE, true, stone)
	audit_label = ""
	_add_block(pos + Vector3(0, 1.26, 0), Vector3(0.9, 0.14, 0.9), Color.WHITE, false, stone)
	var bowl := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.36
	bm.bottom_radius = 0.2
	bm.height = 0.26
	bowl.mesh = bm
	bowl.position = pos + Vector3(0, 1.46, 0)
	bowl.material_override = _iron()
	add_child(bowl)
	_add_fire(pos + Vector3(0, 1.52, 0), 2.3)
	if lit:
		_add_light(pos + Vector3(0, 2.1, 0), Color(1.0, 0.62, 0.28), 1.3, 6.5)


func _add_crates(pos: Vector3, rot: float) -> void:
	## A stack of crates with a barrel beside it, by the road.
	_prop("dungeon/crates_stacked", pos, 0.7, rot)
	_add_blocker(pos, 0.7, 1.5)
	_prop("dungeon/barrel_large", pos + Vector3(-signf(pos.x) * 1.75, 0, signf(pos.z) * 0.3), 0.6, rot)   # towards the shrine, off the road


func _add_picket_fence(from: Vector3, to: Vector3) -> void:
	## A run of pointed timber stakes on two rails (decor beside the verges).
	## Stakes stop short of any tree, so a run that meets a trunk breaks into
	## pieces either side of it instead of passing through the trunk and
	## branches.
	var wood := _timber(Color(0.55, 0.38, 0.24))
	var d := to - from
	var n := int(d.length() / 0.32)
	var ang := atan2(d.x, d.z)
	var runs: Array = []   # [first stake, last stake] of each unbroken piece
	for k in n + 1:
		var p := from + d * (float(k) / maxf(n, 1))
		var clear := true
		for t in map_trees:
			if _flat_dist(p, t) < 2.4:
				clear = false
				break
		if not clear:
			continue
		if runs.is_empty() or runs[-1][1] != k - 1:
			runs.append([k, k])
		else:
			runs[-1][1] = k
		var h := 0.95 + 0.12 * sin(k * 2.3)
		var stake := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(0.2, h, 0.08)
		stake.mesh = sm
		stake.material_override = wood
		stake.position = p + Vector3(0, h / 2.0, 0)
		stake.rotation.y = ang + PI / 2.0
		add_child(stake)
		var tip := MeshInstance3D.new()
		var tm := PrismMesh.new()
		tm.size = Vector3(0.2, 0.18, 0.08)
		tip.mesh = tm
		tip.material_override = wood
		tip.position = p + Vector3(0, h + 0.09, 0)
		tip.rotation.y = ang + PI / 2.0
		add_child(tip)
	for run in runs:
		if run[1] <= run[0]:
			continue
		var a := from + d * (float(run[0]) / maxf(n, 1))
		var b := from + d * (float(run[1]) / maxf(n, 1))
		for y in [0.3, 0.7]:
			var rail := MeshInstance3D.new()
			var rm := BoxMesh.new()
			rm.size = Vector3(0.06, 0.08, (b - a).length())
			rail.mesh = rm
			rail.material_override = wood
			rail.position = (a + b) / 2.0 + Vector3(0, y, 0) - Vector3(sin(ang + PI / 2.0), 0, cos(ang + PI / 2.0)) * 0.06
			rail.rotation.y = ang
			add_child(rail)


func _add_road_dressing() -> void:
	## The main road's furniture from the 2026-10-08 target art: stone pillar
	## braziers in pairs, crates and barrels, picket fences behind the verges
	## and a banner frame on each side's half. All clear of the road itself.
	for sx in [-1.0, 1.0]:
		var team := 0 if sx < 0.0 else 1
		for x in [18.0, 34.0]:
			for zs in [-1.0, 1.0]:
				_add_stone_brazier(Vector3(sx * x, 0, zs * 3.7), zs > 0.0)
		# (No crate-and-barrel piles by the road: Faisal 11:27, "did you fix the
		# random fence issues", the pile by the Human gate read as a stray fence.)
		# (The two picket fences by the road went: Faisal 08:16, "random fence
		# not even on road".)
		_add_banner_pole(team, Vector3(sx * 24.0, 0, -5.4))


func _add_road_lanterns() -> void:
	## Lantern posts along the main road, lit day and night.
	for sx in [-1.0, 1.0]:
		for k in 2:   # (the third post, by the gates, stood with a stray fence: Faisal 08:16)
			var x: float = sx * (10.0 + k * 16.0)
			var z: float = (3.9 if k % 2 == 1 else -3.9) * sx   # point-mirrored like the cover, so no post meets a wall stub
			_prop("halloween/post_lantern", Vector3(x, 0, z), 0.75, PI / 2.0 if z > 0.0 else -PI / 2.0)
			_add_light(Vector3(x, 2.4, z), Color(1.0, 0.75, 0.4), 1.0, 6.5)
	# Benches to sit on by the shrine island's bridges.
	for sx in [-1.0, 1.0]:
		_prop("halloween/bench", Vector3(sx * (ISLAND_R + 3.2), 0, 4.6), BITS_SCALE, PI if sx > 0.0 else 0.0)


func _add_river_plants() -> void:
	## Lilies in the shallows and reeds on the banks, clear of the bridges and the island.
	var r := RandomNumberGenerator.new()
	r.seed = 404
	var z := -map_half.y + 3.0
	while z < map_half.y - 3.0:
		var blocked := absf(z) < ISLAND_R + 2.5 or absf(absf(z) - 30.0) < 5.0   # the island, the mills
		for b in BRIDGES:
			if absf(z - b) < 3.8:
				blocked = true
		if not blocked:
			for sx in [-1.0, 1.0]:
				if r.randf() < 0.7:
					_prop("hex/waterlily_%s" % ["A", "B"][r.randi() % 2], Vector3(sx * (RIVER_HALF - 1.0) + r.randf_range(-0.4, 0.4), 0.04, z + r.randf_range(-1.0, 1.0)), 4.0, r.randf() * TAU)
				if r.randf() < 0.6:
					_prop("hex/waterplant_%s" % ["A", "B", "C"][r.randi() % 3], Vector3(sx * (RIVER_HALF + 1.3), 0.0, z + r.randf_range(-1.2, 1.2)), 4.0, r.randf() * TAU)
		z += 4.5


func _add_barrow(pos: Vector3) -> void:
	## The old barrow in the Wildwood: a crypt, leaning stones, a dead tree
	## and candles that never go out.
	map_marks.append([pos, "barrow"])
	_prop("halloween/crypt", pos, 0.55, PI * 0.9)
	_add_blocker(pos, 1.7)
	_prop("halloween/floor_dirt", pos + Vector3(0, 0.01, 2.6), 1.0, 0.0)
	var stones := [["gravestone", Vector3(-3.6, 0, 1.6), 0.4], ["grave_A", Vector3(3.5, 0, 1.2), -0.5], ["gravemarker_A", Vector3(-1.6, 0, 3.4), 0.2],
		["gravemarker_B", Vector3(1.8, 0, 3.6), -0.3], ["grave_B", Vector3(-3.8, 0, -1.2), 1.2], ["bone_A", Vector3(0.6, 0, 3.2), 0.9]]
	for st in stones:
		_prop("halloween/%s" % st[0], pos + st[1], 0.7, st[2])
	_prop("halloween/tree_dead_large_decorated", pos + Vector3(3.8, 0, -2.4), 0.9, 0.7)
	_add_blocker(pos + Vector3(3.8, 0, -2.4), 0.5)
	_prop("halloween/lantern_standing", pos + Vector3(-1.4, 0, 3.0), 0.8)
	_add_light(pos + Vector3(-1.4, 1.0, 3.0), Color(0.55, 1.0, 0.8), 1.1, 6.0)
	_prop("halloween/candle_triple", pos + Vector3(1.6, 0, 2.9), 0.6)
	_add_light(pos + Vector3(1.6, 0.6, 2.9), Color(1.0, 0.7, 0.35), 0.7, 3.5)
	_prop("halloween/fence_broken", pos + Vector3(-2.6, 0, 4.2), 0.7, 0.0)
	_prop("halloween/fence", pos + Vector3(2.6, 0, 4.2), 0.7, 0.0)
	_add_fireflies(pos + Vector3(0, 0.6, 1.5))
	_add_mushrooms(pos + Vector3(-2.8, 0, 2.8), 77)


func _add_barricade(team: int, pos: Vector3, length: float, rot_y: float) -> void:
	if playing and net:
		net.rec("game", "net_spawn", ["barricade", 0, [team, pos, length, rot_y]])   # planted in a match
	var b := Barricade.new()
	add_child(b)
	b.setup(self, team, pos, length, rot_y)
	barricades.append(b)
	var along_x := absf(cos(rot_y)) > 0.5
	var fs := Vector3(length, 1.1, 0.4) if along_x else Vector3(0.4, 1.1, length)
	audit_blocks.append(["fence", AABB(pos - Vector3(fs.x / 2.0, 0, fs.z / 2.0), fs)])


func _add_upgrade_pad(team: int, pos: Vector3, yaw: float = 0.0, small_anvil: bool = false) -> void:
	## `yaw` turns the station and its workshop about the pad (0 = the anvil
	## and board facing +z). `small_anvil` drops the gold pad, its flagstone
	## and the block anvil for a small modelled anvil with a hammer on it.
	upgrade_pads[team] = pos
	var c0 := get_child_count()
	var a0 := audit_blocks.size()
	var iron := _material(Color(0.3, 0.31, 0.35))
	iron.metallic = 0.6
	iron.roughness = 0.5
	if small_anvil:
		_add_small_anvil(pos)
	else:
		var color := Color(0.75, 0.55, 0.2)
		_add_block(pos + Vector3(0, 0.05, 0), Vector3(2.2, 0.1, 2.2), color.darkened(0.45), false, _flagstone(Color(0.7, 0.62, 0.5)))
		var pad := MeshInstance3D.new()
		var pad_mesh := CylinderMesh.new()
		pad_mesh.top_radius = STATION_RADIUS
		pad_mesh.bottom_radius = STATION_RADIUS
		pad_mesh.height = 0.06
		pad.mesh = pad_mesh
		var pad_mat := _material(color)
		pad_mat.emission_enabled = true
		pad_mat.emission = color * 0.15
		pad.material_override = pad_mat
		pad.position = pos + Vector3(0, 0.12, 0)
		add_child(pad)
		# An anvil on a timber block, like the upgrade station in the renders.
		_add_block(pos + Vector3(0, 0.4, 0), Vector3(0.7, 0.5, 0.7), Color.WHITE, false, _timber(Color(0.75, 0.65, 0.55)))
		_add_block(pos + Vector3(0, 0.8, 0), Vector3(1.0, 0.3, 0.42), Color.WHITE, false, iron)
		_add_block(pos + Vector3(0.45, 0.82, 0), Vector3(0.3, 0.2, 0.3), Color.WHITE, false, iron)

	# The workshop behind it (Faisal's 12:55 target): a timber board with
	# the station's name, a hammer and an axe hung on it, a workbench and casks.
	var sd := -1.0 if team == 0 else 1.0   # away from the cellar's back wall
	var back := pos + Vector3(sd * 0.35, 0, -1.5)
	var wood := _timber(Color(0.66, 0.5, 0.34))
	for xs in [-1.0, 1.0]:
		_add_block(back + Vector3(xs * 1.05, 1.0, 0), Vector3(0.14, 2.0, 0.14), Color.WHITE, false, wood)
	_add_block(back + Vector3(0, 1.25, 0), Vector3(2.0, 1.1, 0.08), Color.WHITE, false, _timber(Color(0.5, 0.36, 0.24)))
	_add_block(back + Vector3(0, 2.0, 0.02), Vector3(2.3, 0.42, 0.12), Color.WHITE, false, wood)
	_add_block(back + Vector3(0, 2.0, 0.04), Vector3(2.4, 0.5, 0.06), Color.WHITE, false, _gold())
	var l := Label3D.new()
	l.text = "UPGRADE STATION"
	l.font_size = 64
	l.pixel_size = 0.0034
	l.outline_size = 10
	l.outline_modulate = Color(0.12, 0.07, 0.03)
	l.modulate = Color(1.0, 0.86, 0.4)
	l.shaded = false
	l.position = back + Vector3(0, 2.0, 0.1)
	add_child(l)
	# Tools on the board: a hammer (handle + head) and an axe.
	_add_block(back + Vector3(-0.45, 1.2, 0.07), Vector3(0.07, 0.7, 0.04), Color.WHITE, false, wood)
	_add_block(back + Vector3(-0.45, 1.52, 0.08), Vector3(0.3, 0.14, 0.08), Color.WHITE, false, iron)
	_add_block(back + Vector3(0.45, 1.2, 0.07), Vector3(0.07, 0.7, 0.04), Color.WHITE, false, wood)
	_add_block(back + Vector3(0.55, 1.45, 0.08), Vector3(0.22, 0.26, 0.05), Color.WHITE, false, iron)
	_add_block(back + Vector3(0, 1.25, 0.08), Vector3(0.36, 0.36, 0.04), Color.WHITE, false, _gold())
	_add_block(back + Vector3(sd * 1.75, 0.42, 0.35), Vector3(1.0, 0.08, 0.6), Color.WHITE, false, wood)
	_add_block(back + Vector3(sd * 1.75, 0.2, 0.35), Vector3(0.9, 0.4, 0.5), Color.WHITE, false, _timber(Color(0.5, 0.36, 0.24)))
	_prop("dungeon/barrel_small", back + Vector3(sd * 2.7, 0, 0.3), 0.75)
	_prop("dungeon/barrel_small", back + Vector3(sd * (2.85 if yaw != 0.0 else 2.8), 0, 1.3 if yaw != 0.0 else 1.05), 0.7, 0.6)
	if yaw != 0.0:
		_turn_since(c0, a0, pos, yaw)


func _add_small_anvil(pos: Vector3) -> void:
	## A small smith's anvil standing on the paving (stepped foot, waist,
	## face, heel and a pointed horn toward +x) with a hammer laid on its
	## face, handle toward +z (Faisal 09:03 2026-10-09).
	var iron := _material(Color(0.24, 0.25, 0.28))
	iron.metallic = 0.7
	iron.roughness = 0.42
	var s := 1.25
	_add_block(pos + Vector3(0, 0.06, 0) * s, Vector3(0.56, 0.12, 0.4) * s, Color.WHITE, false, iron)
	_add_block(pos + Vector3(0, 0.15, 0) * s, Vector3(0.42, 0.06, 0.3) * s, Color.WHITE, false, iron)
	_add_block(pos + Vector3(0, 0.26, 0) * s, Vector3(0.26, 0.16, 0.2) * s, Color.WHITE, false, iron)
	_add_block(pos + Vector3(0, 0.4, 0) * s, Vector3(0.6, 0.13, 0.28) * s, Color.WHITE, false, iron)
	_add_block(pos + Vector3(-0.36, 0.42, 0) * s, Vector3(0.12, 0.09, 0.2) * s, Color.WHITE, false, iron)
	var horn := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 0.0
	hm.bottom_radius = 0.08 * s
	hm.height = 0.3 * s
	hm.radial_segments = 8
	horn.mesh = hm
	horn.material_override = iron
	horn.position = pos + Vector3(0.44, 0.41, 0) * s
	horn.rotation.z = -PI / 2.0   # tip toward +x
	add_child(horn)
	# The hammer: an iron head on the face, its timber handle running forward.
	var steel := _material(Color(0.5, 0.52, 0.56))
	steel.metallic = 0.8
	steel.roughness = 0.35
	_add_block(pos + Vector3(-0.08, 0.515, -0.02) * s, Vector3(0.2, 0.09, 0.1) * s, Color.WHITE, false, steel)
	_add_block(pos + Vector3(-0.08, 0.5, 0.16) * s, Vector3(0.045, 0.045, 0.34) * s, Color.WHITE, false, _timber(Color(0.55, 0.38, 0.24)))


func _box_at(pos: Vector3, size: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO) -> void:
	## A plain box mesh with a rotation (no collider; `_add_block` is axis-aligned).
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	m.position = pos
	m.rotation = rot
	m.material_override = mat
	add_child(m)


func _add_stone_lion(pos: Vector3, face: Vector3, scale: float = 1.0) -> void:
	## The Humans' heraldry in the round: a chunky stone lion sitting on a
	## plinth, facing `face` (+-x or +-z), with a gold collar. Blocks only, so
	## it reads as carved stone from the camera; a round blocker keeps feet out.
	var fx := signf(face.x)
	var fz := signf(face.z)
	var along_x := absf(face.x) >= absf(face.z)
	# Cream stone with a gold mane and collar: from the game camera (steep,
	# from the south) a grey block lion read as rubble; the gold disc of the
	# mane is what says "lion" from above.
	var stone := _ashlar(Color(0.95, 0.92, 0.84))
	var dark := _ashlar(Color(0.72, 0.72, 0.78))
	var parts := [
		# [along, y, lateral, length (along), height, width (lateral), mat]
		[0.0, 0.17, 0.0, 1.5, 0.34, 0.95, dark],      # plinth
		[-0.3, 0.7, 0.0, 0.8, 0.7, 0.6, stone],       # hind quarters
		[0.22, 0.9, 0.0, 0.55, 1.1, 0.6, stone],      # chest
		[0.42, 0.64, 0.19, 0.26, 0.6, 0.22, stone],   # front legs
		[0.42, 0.64, -0.19, 0.26, 0.6, 0.22, stone],
		[0.36, 1.56, 0.0, 0.5, 0.46, 0.46, stone],    # head
		[0.64, 1.46, 0.0, 0.16, 0.22, 0.26, stone],   # muzzle
		[0.3, 1.86, 0.18, 0.14, 0.14, 0.12, stone],   # ears
		[0.3, 1.86, -0.18, 0.14, 0.14, 0.12, stone],
		[-0.72, 0.78, 0.0, 0.12, 0.55, 0.12, stone],  # tail
		[0.24, 1.25, 0.0, 0.62, 0.1, 0.66, _gold()],  # collar
	]
	for q in parts:
		var a: float = q[0] * scale
		var l: float = q[2] * scale
		var wp: Vector3
		var ws: Vector3
		if along_x:
			wp = pos + Vector3(a * fx, q[1] * scale, l)
			ws = Vector3(q[3], q[4], q[5]) * scale
		else:
			wp = pos + Vector3(l, q[1] * scale, a * fz)
			ws = Vector3(q[5], q[4], q[3]) * scale
		_add_block(wp, ws, Color.WHITE, false, q[6])
	# The mane: a gold disc round the head, its axis along the facing.
	var mane := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.46 * scale
	cm.bottom_radius = 0.46 * scale
	cm.height = 0.34 * scale
	cm.radial_segments = 14
	mane.mesh = cm
	mane.position = pos + (Vector3(0.15 * scale * fx, 1.55 * scale, 0) if along_x else Vector3(0, 1.55 * scale, 0.15 * scale * fz))
	mane.rotation = Vector3(0, 0, PI / 2.0) if along_x else Vector3(PI / 2.0, 0, 0)
	mane.material_override = _gold()
	add_child(mane)
	_add_blocker(pos, 0.55 * scale, 2.0 * scale)


func _add_ballista(pos: Vector3, face: Vector3) -> void:
	## A timber ballista on a tower top (the Wildbloom sheet's outer-defense
	## turrets, the Humans' way): a swivel post, a tilted stock, bow arms and
	## a loaded bolt. Decorative.
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = atan2(face.x, face.z)   # +z in local space points along `face`
	add_child(n)
	var wood := _timber(Color(0.58, 0.44, 0.3))
	var dark := _timber(Color(0.42, 0.3, 0.2))
	var bits := [
		# [local pos, size, mat, rot]
		[Vector3(0, 0.12, 0), Vector3(0.9, 0.24, 0.9), _ashlar(Color(0.8, 0.8, 0.84)), Vector3.ZERO],
		[Vector3(0, 0.55, 0), Vector3(0.2, 0.62, 0.2), dark, Vector3.ZERO],
		[Vector3(0, 1.02, 0.25), Vector3(0.2, 0.14, 1.9), wood, Vector3(-0.22, 0, 0)],
		[Vector3(0, 1.28, 1.05), Vector3(1.7, 0.14, 0.14), dark, Vector3.ZERO],
		[Vector3(0.95, 1.28, 0.85), Vector3(0.1, 0.1, 0.9), wood, Vector3(0, -0.45, 0)],
		[Vector3(-0.95, 1.28, 0.85), Vector3(0.1, 0.1, 0.9), wood, Vector3(0, 0.45, 0)],
		[Vector3(0, 1.36, 0.1), Vector3(1.6, 0.03, 0.03), _iron(), Vector3.ZERO],
		[Vector3(0, 1.14, 0.35), Vector3(0.07, 0.07, 1.4), _iron(), Vector3(-0.22, 0, 0)],
		[Vector3(0, 0.66, -0.55), Vector3(0.5, 0.3, 0.3), dark, Vector3.ZERO],
	]
	for b in bits:
		var m := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = b[1]
		m.mesh = bm
		m.position = b[0]
		m.rotation = b[3]
		m.material_override = b[2]
		n.add_child(m)


func _add_training_dummy(pos: Vector3, rot_y: float = 0.0) -> void:
	## A straw-stuffed sparring dummy on a post (the Humans' drill yard).
	var wood := _timber(Color(0.55, 0.42, 0.3))
	_box_at(pos + Vector3(0, 0.75, 0), Vector3(0.14, 1.5, 0.14), wood, Vector3(0, rot_y, 0))
	_box_at(pos + Vector3(0, 1.22, 0), Vector3(1.0, 0.1, 0.1), wood, Vector3(0, rot_y, 0))
	_box_at(pos + Vector3(0, 0.95, 0), Vector3(0.44, 0.62, 0.3), _cloth(Color(0.76, 0.64, 0.46)), Vector3(0, rot_y, 0))
	_box_at(pos + Vector3(0, 1.26, 0), Vector3(0.5, 0.08, 0.34), _timber(Color(0.4, 0.3, 0.2)), Vector3(0, rot_y, 0))
	var head := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.2
	sm.height = 0.4
	sm.radial_segments = 10
	sm.rings = 5
	head.mesh = sm
	head.position = pos + Vector3(0, 1.58, 0)
	head.material_override = _cloth(Color(0.8, 0.7, 0.5))
	add_child(head)
	_add_blocker(pos, 0.32, 1.7)


func _build_castle(team: int) -> void:
	var side := -1.0 if team == 0 else 1.0
	var color: Color = Stats.FACTIONS[team].color
	mossy = team == 0
	elf_castle = team == 0
	grey = team == 1
	prop_solid = true
	var cx := side * CASTLE_X
	var fx := _front_x(team)                      # outer wall's front, facing the middle
	var bx := side * (CASTLE_X + CASTLE_DEPTH)    # outer wall's back
	var kx := _keep_x(team)                       # the keep's front
	var hz := CASTLE_HALF_Z
	var dh := Stats.DOOR_HALF
	var in_x := fx + side * 0.5                   # the front wall's inner face

	# --- The yard: sandstone flags inside the walls. ---
	# Both bases are paved in one stone from the gate to the crown room
	# (Faisal 06:00 2026-10-09, "the front textures are not even uniform"):
	# the Elves' cream pavers, the same slabs cool-tinted for the Humans.
	# (Its top at 0.024 clears the road cores that run in under the gate.)
	await _world_build_frame()
	_add_block(Vector3(cx, 0.014, 0), Vector3(CASTLE_DEPTH * 2, 0.02, hz * 2), color, false, _pavers() if mossy else _pbr("pavers", 0.16 if world_style else 0.22, Color(0.9, 0.9, 0.9)))

	# --- The outer wall ring: front wall with the gatehouse, side and back walls, corner towers. ---
	var seg := hz - (dh + 2.2)                    # front wall from the gatehouse tower to the corner
	for zs in [-1.0, 1.0]:
		await _world_build_frame()
		_add_wall(Vector3(fx, WALL_H / 2.0, zs * (dh + 2.2 + seg / 2.0)), Vector3(1, WALL_H, seg), false)
		# The Humans' camera-facing side wall is a low parapet, so the yard
		# reads as an open courtyard from the game camera (Faisal's 03:34 brief).
		var wh: float = 1.5 if (team == 1 and zs > 0.0) else WALL_H
		await _world_build_frame()
		_add_wall(Vector3(cx, wh / 2.0, zs * hz), Vector3(CASTLE_DEPTH * 2 + 1, wh, 1))
		# The gatehouse: a tower either side of the door.
		await _world_build_frame()
		_add_tower(Vector3(fx, 0, zs * (dh + 1.1)), team, side, 2.2, 5.0, false)
		await _world_build_frame()
		_add_pennant(team, Vector3(fx - side * 1.12, 4.4, zs * (dh + 1.1)), Vector3(-side, 0, 0), 1.3, 2.8, zs > 0.0)
		await _world_build_frame()
		_add_torch(Vector3(fx - side * 2.0, 0, zs * (dh + 0.6)))
		if team == 0:   # (the Humans' gate keeps its lions and tower pennants only: Faisal 06:00, "cluttered")
			# Against the wall beside the gatehouse, off the road and the
			# path mouths (Faisal 08:19: "not middle of ground blocking road").
			# Out from the wall (clear of the gatehouse towers and lamps) and
			# turned to face the road (Faisal 11:29: "facing towards the road
			# and not clipping into the building").
			var bp := Vector3(fx - side * 3.4, 0, zs * (dh + 3.6))
			await _world_build_frame()
			_add_banner_pole(team, bp, PI if zs > 0.0 else 0.0)
		# Corner towers.
		await _world_build_frame()
		_add_tower(Vector3(fx, 0, zs * hz), team, side)
		await _world_build_frame()
		_add_tower(Vector3(bx, 0, zs * hz), team, side)
	# The back wall has an opening at the middle for the stairs up from the cellar.
	var seg_b := hz - 1.8
	for zs in [-1.0, 1.0]:
		await _world_build_frame()
		_add_wall(Vector3(bx, WALL_H / 2.0, zs * (1.8 + seg_b / 2.0)), Vector3(1, WALL_H, seg_b))
	await _world_build_frame()
	_add_block(Vector3(bx, WALL_H - 0.35, 0), Vector3(1, 0.7, 3.6), Color.WHITE, false, _ashlar(Color(0.9, 0.86, 0.78)))
	# The rampart: a timber deck along the front wall, a stone parapet with
	# crenellations on the outside and a railing on the yard side.
	await _world_build_frame()
	_add_block(Vector3(fx, WALK_Y - 0.3, 0), Vector3(2.4, 0.6, hz * 2 - 2.0), Color.WHITE, true, _timber())
	await _world_build_frame()
	_add_block(Vector3(fx - side * 1.05, WALK_Y + 0.25, 0), Vector3(0.3, 0.5, hz * 2 - 2.0), Color.WHITE, false, _ashlar(Color(0.9, 0.86, 0.78)))
	for k in 9:
		var pz := -hz + 1.0 + k * (hz * 2 - 2.0) / 8.0
		if absf(pz) > dh + 2.4 and absf(pz) < hz - 1.4:
			await _world_build_frame()
			_add_block(Vector3(fx - side * 1.05, WALK_Y + 0.75, pz), Vector3(0.34, 0.5, 0.9), Color.WHITE, false, _ashlar(Color(0.9, 0.86, 0.78)))
	# The door's lintel: a timber beam and the team crest over the gate.
	await _world_build_frame()
	_add_block(Vector3(fx, WALK_Y - 0.7, 0), Vector3(1.4, 0.3, dh * 2 + 0.6), Color.WHITE, false, _timber(Color(0.7, 0.6, 0.5)))
	# (No railing along the rampart's inner edge: nothing fence-like inside the walls.)

	# Stairs from the yard up to the rampart, along each side wall.
	ramps.append([])
	for zs in [-1.0, 1.0]:
		var z: float = zs * (hz - 2.5)
		var bottom := Vector3(fx + side * (KEEP_SETBACK - 1.5), 0.0, z)
		var top := Vector3(fx + side * 1.2, WALK_Y, z)
		await _world_build_frame()
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
	await _world_build_frame()
	_add_block(Vector3(kcx, 0.03, 0), Vector3(kdepth, 0.04, khz * 2), Color.WHITE, false, _pavers() if mossy else _pbr("flagstone_grey", 0.7, Color(0.9, 0.9, 0.94)))
	# Side walls, each with a side door near the back (a second way out of the keep).
	# The Elves' keep is an open court (Faisal's 2026-10-09 brief): its side
	# walls are a waist-high sandstone parapet with hedge on top, so the
	# galleries and the crown room read from the camera; the Humans' keep
	# keeps its full walls. Same footprint and collision.
	var kh: float = 1.4 if team == 0 else KEEP_H
	for zs in [-1.0, 1.0]:
		var khs: float = 1.3 if (team == 1 and zs > 0.0) else kh   # the Humans' camera-facing wall is a low one
		await _world_build_frame()
		_add_wall(Vector3(kx + side * (kdepth - 4.5) / 2.0, khs / 2.0, zs * khz), Vector3(kdepth - 4.5, khs, 0.8))
		await _world_build_frame()
		_add_wall(Vector3(bx - side * 0.75, khs / 2.0, zs * khz), Vector3(1.5, khs, 0.8), false)
		if khs == kh:
			_add_block(Vector3(bx - side * 3.0, kh - 0.3, zs * khz), Vector3(3.0, 0.6, 0.9), Color.WHITE, false, _timber(Color(0.7, 0.6, 0.5)))  # lintel
	var kseg := khz - KEEP_DOOR_HALF
	var kzc := KEEP_DOOR_HALF + kseg / 2.0
	for zs in [-1.0, 1.0]:
		await _world_build_frame()
		_add_wall(Vector3(kx, KEEP_H / 2.0, zs * kzc), Vector3(0.8, KEEP_H, kseg))
		# Corner pillars of the keep.
		# (1.42 wide: a hair proud of the walls they cap, whose faces they shared.)
		await _world_build_frame()
		_add_block(Vector3(kx, KEEP_H / 2.0 + 0.4, zs * khz), Vector3(1.42, KEEP_H + 0.8, 1.42), Color.WHITE, true, _ashlar())
		await _world_build_frame()
		_add_block(Vector3(bx - side * 0.2, kh / 2.0 + 0.4, zs * khz), Vector3(1.42, kh + 0.8, 1.42), Color.WHITE, true, _ashlar())
		# Banners either side of the archway and torches on the arch pillars.
		await _world_build_frame()
		_add_banner(team, Vector3(kx - side * 0.4, -0.2, zs * (KEEP_DOOR_HALF + 1.6)), Vector3(-side, 0, 0), 0.75, true)
		await _world_build_frame()
		_add_wall_torch(Vector3(kx - side * 0.4, 1.5, zs * (KEEP_DOOR_HALF + 0.3)), Vector3(-side, 0, 0))
	# Arch over the doorway, well above head height: stone, so from above the
	# keep's front reads as one wall line, with a timber beam underneath.
	await _world_build_frame()
	_add_block(Vector3(kx, KEEP_H - 0.05, 0), Vector3(0.8, 0.5, KEEP_DOOR_HALF * 2 + 0.8), Color.WHITE, false, _ashlar())
	await _world_build_frame()
	_add_block(Vector3(kx, KEEP_H - 0.42, 0), Vector3(0.9, 0.24, KEEP_DOOR_HALF * 2 + 0.8), Color.WHITE, false, _timber(Color(0.7, 0.6, 0.5)))
	await _world_build_frame()
	_add_block(Vector3(kx, KEEP_H + 0.3, 0), Vector3(1.0, 0.2, KEEP_DOOR_HALF * 2 + 1.0), Color.WHITE, false, _ashlar(Color(0.92, 0.88, 0.8)))
	for k in 7:
		await _world_build_frame()
		_add_block(Vector3(kx, KEEP_H + 0.7, -KEEP_DOOR_HALF + 0.75 + k * 1.25), Vector3(0.8, 0.6, 0.6), Color.WHITE, false, _ashlar(Color(0.9, 0.86, 0.78)))
	# A rug up the yard's lane to the archway, and one from the archway to the throne.
	# One runner from the gate to the archway on both sides: the route reads
	# at a glance and nothing else lies on the yard (the Elves had a cobble
	# lane, lawns and beds here until Faisal's 06:00 2026-10-09 "cluttered").
	await _world_build_frame()
	_add_rug(Vector3((in_x + kx) / 2.0, 0.025, 0), Vector2(absf(kx - in_x) - 0.5, 3.4), color)
	await _world_build_frame()
	_add_emblem_decal(Vector3((in_x + kx) / 2.0, 0.072, 0), 2.2, team)
	if team != 0:   # (the Elves' stairs up to the crown room take its place)
		# (Laid 1 cm above the keep floor: at 0.05 its top was the floor's top.)
		await _world_build_frame()
		_add_rug(Vector3(kx + side * 3.0, 0.06, 0), Vector2(5.0, 2.8), color)
		await _world_build_frame()
		_add_emblem_decal(Vector3(kx + side * 1.6, 0.107, 0), 1.7, team)

	# The yard stays open: lanterns (Elves) or nothing but the gatehouse
	# banners (Humans). Faisal: the base was too busy.
	if team == 0:
		await _world_build_frame()
		_dress_elf_yard(team, fx, kx, side, hz)
	# Banners on the yard side of the gatehouse towers.
	for zs in [-1.0, 1.0]:
		await _world_build_frame()
		_add_banner(team, Vector3(fx + side * 1.1, 0.2, zs * (dh + 1.1)), Vector3(side, 0, 0), 0.6)
	# Inside the keep: columns along the side walls, torches, stacked stores at the back.
	for zs in [-1.0, 1.0]:
		if team == 0 or zs < 0.0:
			await _world_build_frame()
			_add_wall_torch(Vector3(kx + side * 1.2, kh - 0.5 if team == 0 else 1.6, zs * (khz - 0.4)), Vector3(0, 0, -zs))
	# Faction flavour: the Humans post iron braziers (the Elves' walls stay
	# clean: no bushes against them since 06:00 2026-10-09).
	if team == 0:
		pass
	else:
		# (The two standing torches by the archway went: it has its wall
		# torches and banners already.)
		await _world_build_frame()
		_dress_human_castle(team, fx, kx, side, dh)

	# The throne room: a walled hall at the heart of the keep with the
	# monarch's throne on a dais. Its doors (the Crown Vault lock) only hold
	# the enemy. Carry the enemy monarch here to score.
	var throne := Vector3(kx + side * 6.0, ROOM_RAISE if team == 0 else 0.0, 0)
	thrones.append(throne)
	await _world_build_frame()
	await _build_throne_room(team, throne, side, color)
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
	await _world_build_frame()
	_furnish_keep(team, kx, bx, side, throne)
	await _world_build_frame()
	_polish_keep(team, kx, side, throne)

	await _world_build_frame()
	await _build_cellar(team, bx, side)
	await _world_build_frame()

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
	elf_castle = false
	grey = false
	prop_solid = false


func _dress_elf_yard(team: int, fx: float, kx: float, side: float, hz: float) -> void:
	## The Elf yard between the gate and the keep: one runner up the middle
	## (laid by `_build_castle`), a wildwood tree in each back corner, stone
	## fire pillars at the keep's arch and the marked turret spots. Nothing
	## else: the cobble lane, lawns, flower beds, bushes, lanterns, rampart
	## fire pillars and the hedge along the front wall were cut on Faisal's
	## 06:00 2026-10-09 "both sides equally cluttered". Only the trees are
	## solid, off the lane and the stair routes.
	# (The two corner trees went too, 08:23 2026-10-09: their round crowns
	# read as "giant blobs inside the building", one of them pink.)
	for zs in [-1.0, 1.0]:
		_add_stone_brazier(Vector3(kx - side * 1.9, 0, zs * 3.4))
	# Turret pads where the Engineers build (the sheet's outer-defence turrets).
	for spot in turret_spots(team):
		_add_turret_pad(spot)


func _add_turret_pad(pos: Vector3) -> void:
	## A round sandstone pad with a gold ring: a marked turret spot.
	var pad := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.95
	cm.bottom_radius = 1.0
	cm.height = 0.05
	cm.radial_segments = 32
	pad.mesh = cm
	# (5 cm high, so the Economy's smaller build pad laid on the same spot
	# stands 1 cm proud of it instead of sharing its top and flickering.)
	pad.position = pos + Vector3(0, 0.025, 0)
	pad.material_override = _ashlar(Color(0.95, 0.92, 0.86))
	add_child(pad)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.72
	tm.outer_radius = 0.84
	tm.rings = 32
	tm.ring_segments = 4
	ring.mesh = tm
	ring.scale = Vector3(1, 0.3, 1)
	ring.position = pos + Vector3(0, 0.065, 0)
	ring.material_override = _gold()
	add_child(ring)


func _dress_human_castle(team: int, fx: float, kx: float, side: float, dh: float) -> void:
	## The Humans' identity on the castle (World & Maps, 2026-10-09): stone
	## lions at the gate, a lion crest over it, ballistae on the gatehouse
	## towers (the Wildbloom sheet's outer-defense turrets) and crested
	## pillar banners down the parade ground. All of it keeps off the lanes
	## (gate to archway, yard to the rampart stairs).
	# (The ballistae on the gatehouse and the four crested parade pillars
	# went: Faisal 2026-10-09 06:00, "both sides equally cluttered". The yard
	# is the runner, the gatehouse banners and nothing else.)
	for zs in [-1.0, 1.0]:
		_add_stone_lion(Vector3(fx - side * 2.6, 0, zs * (dh + 3.3)), Vector3(-side, 0, 0), 1.3)
	_add_crest(team, Vector3(fx - side * 1.21, WALK_Y + 0.3, 0), Vector3(-side, 0, 0), 1.0)


func _dress_elf_courtyard(team: int, bx: float, side: float) -> void:
	## The Elves' courtyard dressing from Faisal's base interior reference
	## (2026-10-08): green stag runners from the spawn circle to the stairs and
	## along the class row, a planning table and a stocked shelf by the south
	## wall, and a wildwood tree growing in the corner. Nothing here is solid
	## except the tree's trunk, so every lane stays open.
	var color: Color = Stats.FACTIONS[team].color
	var hz := CELLAR_HALF_Z
	# The runner from the spawn circle to the foot of the stairs, stag in the middle.
	_add_rug(Vector3(bx + side * 9.7, CELLAR_Y + 0.03, 0), Vector2(5.0, 2.6), color)
	_add_emblem_decal(Vector3(bx + side * 9.7, CELLAR_Y + 0.11, 0), 1.6, team)
	# A long runner in front of the class row.
	_add_rug(Vector3(bx + side * 9.25, CELLAR_Y + 0.03, -(hz - 3.95)), Vector2(15.4, 1.5), color.darkened(0.1))
	for k in 3:
		_add_emblem_decal(Vector3(bx + side * (3.5 + k * 5.75), CELLAR_Y + 0.11, -(hz - 3.95)), 1.0, team)
	# Stores by the south wall: a shelf of potions and a map table.
	_prop("furniture/shelf_B_large_decorated", Vector3(bx + side * 8.6, CELLAR_Y, hz - 0.7), BITS_SCALE, PI)
	_prop("dungeon/bottle_A_labeled_green", Vector3(bx + side * 8.3, CELLAR_Y + 0.95, hz - 0.85), 0.5)
	_prop("kitchen/table_round_A_decorated", Vector3(bx + side * 10.4, CELLAR_Y, hz - 3.6), BITS_SCALE, 0.3)
	# Grass with blooms beside the spawn circle (the reference's lawn).
	var grass := _pbr("grass", 0.35, Color(0.92, 1.0, 0.86))
	grass.roughness = 1.0
	_add_block(Vector3(bx + side * 14.3, CELLAR_Y + 0.006, 7.3), Vector3(5.6, 0.012, 2.4), Color.WHITE, false, grass)
	_add_flower_bed(Vector3(bx + side * 14.3, CELLAR_Y, 7.3), Vector2(1.6, 0.9), 430)
	# A wildwood tree in the south-east corner, its canopy over the hedge.
	_add_tree_grown(Vector3(bx + side * 6.6, CELLAR_Y, hz - 1.7))
	_add_bush(Vector3(bx + side * 0.9, CELLAR_Y, -(hz - 0.9)), 73)
	_add_bush(Vector3(bx + side * 17.6, CELLAR_Y, hz - 0.9), 74)


func _pavers() -> StandardMaterial3D:
	## The open courtyard's floor: big cream sandstone slabs, softly bevelled
	## (tools/make_textures.py make_pavers), one tile every 4.5 m. The match
	## world's style copy (tools/make_style_textures.py make_pavers) lays
	## mixed 1-2 m flags, one tile every 6.25 m (picks Spawn D / Battle A).
	if world_style:
		# Castle pass 2026-10-31: larger warm-cream flags with a darker joint
		# and a painted bevel light (tools/make_castle_textures.py).
		# Pass 2 (2026-10-31): a touch less green, toward the picks' cream-peach.
		return _pbr("castle_flags", 0.16, Color(1.0, 0.95, 0.99))
	return _pbr("pavers", 0.22, Color(1.0, 0.98, 0.94))


func _add_invisible_wall(pos: Vector3, size: Vector3) -> void:
	## A collider with no mesh: keeps units (and shots, which fly at 1.1 m)
	## out where the visible edge is only a low fence.
	var body := StaticBody3D.new()
	body.position = pos
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	add_child(body)


func _add_elf_courtyard_fence(bx: float, side: float, hz: float) -> void:
	## The open courtyard's edge (Faisal's 2026-10-09 brief: low stone borders
	## and timber fencing, not walls): a sandstone kerb with a picket fence on
	## it round three sides, the castle's back wall being the fourth, and an
	## unseen wall above the fence so nothing walks or shoots in. The kerb
	## hides only a hand's width of floor from the camera, where the old
	## 3.3 m hedge wall hid the first 2.5 m.
	var ox := bx + side * (CELLAR_DEPTH + 0.5)
	var kerb := _ashlar(Color(0.93, 0.9, 0.84))
	var carved_stone := _material(StyleProfile.STONE)
	carved_stone.roughness = 0.94
	var cap_stone := _material(StyleProfile.STONE.lightened(0.12))
	cap_stone.roughness = 0.94
	var lines := [
		[Vector3(bx + side * 0.5, 0, -(hz + 0.5)), Vector3(ox, 0, -(hz + 0.5))],
		[Vector3(bx + side * 0.5, 0, hz + 0.5), Vector3(ox, 0, hz + 0.5)],
		[Vector3(ox, 0, -(hz + 0.5)), Vector3(ox, 0, hz + 0.5)]]
	var kit := world_style
	for li in lines.size():
		var ln: Array = lines[li]
		var a: Vector3 = ln[0]
		var b: Vector3 = ln[1]
		var c := (a + b) / 2.0
		var along_x := absf(b.x - a.x) > absf(b.z - a.z)
		var length := absf(b.x - a.x) if along_x else absf(b.z - a.z)
		var size := Vector3(length + 0.5, 0.3, 0.5) if along_x else Vector3(0.5, 0.3, length + 0.5)
		_add_block(Vector3(c.x, 0.15, c.z), size, Color.WHITE, true, kerb)
		_add_invisible_wall(Vector3(c.x, 1.0, c.z), Vector3(size.x, 1.4, size.z))
		if kit:
			# Castle pass 2026-10-31 (picks Spawn D / Battle A), on the same
			# kerb line and inside the same invisible wall: a timber palisade
			# with the team crest between the class signs along the north
			# side, a chunky crenellated block wall with timber posts on the
			# west and south (lower merlons on the south, the camera's side).
			if li == 0:
				var crests: Array = []
				for k in 5:
					crests.append(Vector3(bx + side * (9.0 + (k - 2.0) * 2.85), 0, a.z))
				# Pass 3 (2026-10-31): the tall crenellated block wall with
				# timber posts and crests (was the timber palisade).
				CastleKit.station_wall(self, a, b, 0, crests, false, 811)
			else:
				# Pass 2 (2026-10-31): the west wall, which the camera looks
				# along, is built tall and thick (outward, away from the yard);
				# the south wall between the camera and the yard stays low.
				CastleKit.courtyard_wall(self, a, b, false, 821 + li * 10, 0.3 if li == 1 else 0.44, 4.6,
					Vector3(side, 0, 0) if li == 2 else Vector3.ZERO)
			continue
		_add_picket_fence(a + Vector3(0, 0.3, 0), b + Vector3(0, 0.3, 0))
		# Pick D: modular low masonry under the timber, inside the existing
		# invisible boundary. Raised visual detail does not alter collision.
		var stones := maxi(1, int(length / 0.9))
		for k in stones:
			var p: Vector3 = a.lerp(b, (k + 0.5) / stones)
			for course in 2:
				var block_size := Vector3(length / stones - 0.035, 0.38, 0.55) if along_x else Vector3(0.55, 0.38, length / stones - 0.035)
				_picked_carved_block(p + Vector3(0, 0.49 + course * 0.4, 0), block_size, carved_stone if (k + course) % 3 else cap_stone)
			if k % 4 == 0:
				_picked_carved_block(p + Vector3(0, 1.17, 0), Vector3(0.76, 0.28, 0.76), cap_stone)
			else:
				var cap_size := Vector3(length / stones - 0.02, 0.1, 0.64) if along_x else Vector3(0.64, 0.1, length / stones - 0.02)
				_picked_carved_block(p + Vector3(0, 1.1, 0), cap_size, cap_stone)
	# Kerb posts at the three outer corners.
	for p in [Vector3(ox, 0, -(hz + 0.5)), Vector3(ox, 0, hz + 0.5)]:
		if kit:   # a chunky stone pier where the walls meet
			var fm: Array = CastleKit.face_mats(self, false)
			CastleKit.block(self, p + Vector3(0, 0.95, 0), Vector3(1.05, 1.9, 1.05), fm[0])
			CastleKit.block(self, p + Vector3(0, 1.98, 0), Vector3(1.25, 0.18, 1.25), fm[2])
			CastleKit.block(self, p + Vector3(0, 2.2, 0), Vector3(0.7, 0.26, 0.7), fm[1])
			_audit_ghost(p + Vector3(0, 0.35, 0), Vector3(0.7, 0.7, 0.7))
			_audit_ghost(p + Vector3(0, 0.76, 0), Vector3(0.8, 0.12, 0.8))
			continue
		_add_block(p + Vector3(0, 0.35, 0), Vector3(0.7, 0.7, 0.7), Color.WHITE, false, kerb)
		_add_block(p + Vector3(0, 0.76, 0), Vector3(0.8, 0.12, 0.8), Color.WHITE, false, _ashlar(Color(0.96, 0.94, 0.9)))


func _picked_carved_block(pos: Vector3, size: Vector3, mat: Material) -> void:
	# Agent: Codex-faisal/world. Visual only; gameplay anchors stay intact.
	var block := MeshInstance3D.new()
	block.mesh = preload("res://scripts/visual/carved_block.gd").mesh(size)
	block.material_override = mat
	block.position = pos
	add_child(block)


func _add_elf_class_station(team: int, role: int, pos: Vector3) -> void:
	## One class station of the open courtyard (Faisal's 2026-10-09 brief): an
	## octagonal sandstone slab, a bevelled second tier and a bronze band under
	## the hat's pedestal (seal.gd adds the pedestal, ring and hat), and behind
	## it a sign on two timber posts: an emerald panel with the class emblem in
	## a soft glow of its colour and the class name in gold below it.
	var accent: Color = Stats.ROLES[role].color
	var sand := _ashlar(Color(0.95, 0.92, 0.86))
	var sand2 := _ashlar(Color(0.9, 0.86, 0.78))
	var bronze := _material(Color(0.7, 0.5, 0.26))
	bronze.metallic = 0.6
	bronze.roughness = 0.4
	# Pick D: layered square, softly carved masonry under the original hat.
	_picked_carved_block(pos + Vector3(0, 0.07, 0), Vector3(2.24, 0.14, 2.24), sand2)
	_picked_carved_block(pos + Vector3(0, 0.19, 0), Vector3(1.6, 0.1, 1.6), sand)
	var band := MeshInstance3D.new()
	var bm := TorusMesh.new()
	bm.inner_radius = 0.44
	bm.outer_radius = 0.56
	bm.rings = 24
	band.mesh = bm
	band.position = pos + Vector3(0, 0.26, 0)
	band.material_override = bronze
	add_child(band)
	# The board and panel on the post line behind the station.
	var zb := pos.z - 1.8
	var dark := _timber(Color(0.26, 0.17, 0.1))
	var mid := _timber(Color(0.4, 0.27, 0.16))
	# The sign stands on two timber posts of its own: emerald cloth in a dark
	# frame, the class emblem above and the class NAME below it in bold gold
	# on dark (Faisal 09:06 2026-10-09).
	for xs in [-0.86, 0.86]:
		_add_block(Vector3(pos.x + xs, pos.y + 1.3, zb - 0.04), Vector3(0.24, 2.6, 0.24), Color.WHITE, false, mid)
		_add_block(Vector3(pos.x + xs, pos.y + 2.64, zb - 0.04), Vector3(0.32, 0.08, 0.32), Color.WHITE, false, _gold())
	_add_block(Vector3(pos.x, pos.y + 1.95, zb - 0.02), Vector3(1.62, 1.07, 0.04), Color.WHITE, false, _gold() if world_style else dark)
	# Pass 2 (2026-10-31, the picks' station banners): in the match world the
	# sign's cloth is a deep shade of the class's own awning colour.
	# Pass 3: the sign reads as the class's square banner (class colour; its
	# frame in gold, the banner's hem, in the match world).
	var sign_cloth: Color = CastleKit.awning_color(role).darkened(0.12) if world_style else StyleProfile.ELF_CLOTH
	_add_block(Vector3(pos.x, pos.y + 1.95, zb), Vector3(1.5, 0.95, 0.06), Color.WHITE, false, _cloth(sign_cloth))
	for yy in [1.5, 2.4]:
		_add_block(Vector3(pos.x, pos.y + yy, zb + 0.01), Vector3(1.56, 0.07, 0.08), Color.WHITE, false, _gold())
	# Modular crossbeam and layered cloth hem behind the station.
	_picked_carved_block(Vector3(pos.x, pos.y + 2.55, zb - 0.04), Vector3(2.08, 0.18, 0.3), mid)
	_add_block(Vector3(pos.x, pos.y + 1.34, zb), Vector3(1.5, 0.1, 0.06), Color.WHITE, false, _cloth(sign_cloth.darkened(0.12)))
	if world_style:
		# Pass 3 (2026-10-31, picks Spawn D / Battle A): a square class banner
		# hung from a rod over the station (was pass 2's striped awning).
		CastleKit.station_banner(self, pos, role, zb)
	# The name plate: a dark strip across the panel's lower third.
	# Pass 4 (2026-10-31): the Mage's tall hat reaches the lower third at the
	# match camera and hid "GE", so its name plate takes the panel's top and
	# the crest drops under it (the hat and the station stay as they are).
	var name_y := 2.22 if world_style and role == 3 else 1.68
	var crest_y := 1.8 if world_style and role == 3 else 2.08
	_add_block(Vector3(pos.x, pos.y + name_y, zb + 0.04), Vector3(1.44, 0.3, 0.03), Color.WHITE, false, dark)
	var name := Label3D.new()
	name.text = str(Stats.FACTIONS[team].roles[role]).to_upper()
	name.font_size = 64
	name.pixel_size = 0.0036
	name.outline_size = 10
	name.outline_modulate = Color(0.08, 0.05, 0.02)
	name.modulate = Color(1.0, 0.82, 0.32)
	name.position = Vector3(pos.x, pos.y + name_y, zb + 0.065)
	name.shaded = false
	add_child(name)
	var disc := MeshInstance3D.new()
	var dm := CylinderMesh.new()
	dm.top_radius = 0.3
	dm.bottom_radius = 0.3
	dm.height = 0.02
	dm.radial_segments = 24
	disc.mesh = dm
	disc.position = Vector3(pos.x, pos.y + crest_y, zb + 0.045)
	disc.rotation.x = PI / 2.0
	var glow := _material(accent.darkened(0.25))
	glow.emission_enabled = true
	glow.emission = accent
	glow.emission_energy_multiplier = 0.55
	disc.material_override = glow
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(disc)
	var em := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2.ONE * 0.54
	em.mesh = q
	em.material_override = _icon_mat(_class_icon_name(role))
	em.position = Vector3(pos.x, pos.y + crest_y, zb + 0.07)
	add_child(em)


func _add_canopy_tree(pos: Vector3, seed: int, k: float = 1.0) -> void:
	## A garden tree with a layered crown (the courtyard reference's round,
	## clustered canopies): a thick tapered trunk and three tiers of leaf
	## clumps stepping in as they rise, cool deep green below, warm on top.
	var body := StaticBody3D.new()
	body.position = pos
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.45
	cyl.height = 3.0
	shape.shape = cyl
	shape.position.y = 1.5
	body.add_child(shape)
	add_child(body)
	if _kit():   # the forest kit's round broadleaf, no taller than this crown was
		_kit().tree_at(pos, false, "canopy", 4.6 * k)
		return
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var tree := Node3D.new()
	tree.position = pos
	tree.rotation.y = r.randf() * TAU
	add_child(tree)
	var trunk := MeshInstance3D.new()
	var tmesh := CylinderMesh.new()
	tmesh.top_radius = 0.22 * k
	tmesh.bottom_radius = 0.44 * k
	tmesh.height = 2.3 * k
	tmesh.radial_segments = 8
	trunk.mesh = tmesh
	trunk.position.y = 1.15 * k
	trunk.material_override = _pbr("bark", 0.5, Color(0.85, 0.74, 0.62))
	tree.add_child(trunk)
	var hue := r.randf_range(-0.02, 0.02)
	var leaf := _leaf_material(r, false)
	leaf.set_shader_parameter("bottom_color", Color.from_hsv(0.45 + hue, 0.85, 0.16))
	leaf.set_shader_parameter("top_color", Color.from_hsv(0.33 + hue, 0.74, 0.42))
	leaf.set_shader_parameter("height", 2.2 * k)
	if world_style:
		# One world-space gradient over the whole crown (as the wild trees):
		# the crown then merges into the static batch instead of drawing
		# each of its ~20 clumps on its own (visual pass 2026-10-30).
		leaf.set_shader_parameter("world_gradient", true)
		leaf.set_shader_parameter("crown_base", pos.y + 1.0 * k)
		leaf.set_shader_parameter("height", 3.0 * k)
	var tiers := [[1.85, 1.7, 5], [2.75, 1.3, 4], [3.5, 0.9, 1]]   # tier height, radius, clumps
	var n_i := 0
	for tier in tiers:
		var ty: float = tier[0] * k
		var tr: float = tier[1] * k
		var n: int = tier[2]
		for i in n:
			var ang := TAU * i / n + r.randf() * 0.5
			var spread: float = 0.0 if n == 1 else tr * 0.55
			var rr: float = tr * (0.72 if n > 1 else 1.0) * r.randf_range(0.9, 1.1)
			var blob := MeshInstance3D.new()
			blob.mesh = _rock_mesh(seed + n_i * 13, rr, 0.1)
			blob.position = Vector3(cos(ang) * spread, ty + r.randf_range(-0.1, 0.1) * k, sin(ang) * spread)
			blob.scale = Vector3(1.0, 0.8, 1.0)
			blob.material_override = leaf
			tree.add_child(blob)
			n_i += 1
	if world_style:   # lobes round each tier's rim (picks Spawn D / Battle A)
		_add_crown_clusters(tree, r, leaf, Vector3(0, 1.75 * k, 0), 1.45 * k, 6)
		_add_crown_clusters(tree, r, leaf, Vector3(0, 2.75 * k, 0), 1.05 * k, 4)


func _add_planting_bed(pos: Vector3, size: Vector2, seed: int) -> void:
	## A kerbed bed of dark soil with a few rounded leaf clusters and blooms
	## (the courtyard reference's planting), nothing loose around it.
	_add_flower_bed(pos, size, seed)
	var r := RandomNumberGenerator.new()
	r.seed = seed + 99
	var leaf := _leaf_material(r, false)
	leaf.set_shader_parameter("bottom_color", Color.from_hsv(0.42, 0.8, 0.22))
	leaf.set_shader_parameter("top_color", Color.from_hsv(0.32, 0.7, 0.48))
	leaf.set_shader_parameter("height", 0.8)
	for i in 3:
		var q := pos + Vector3(r.randf_range(-size.x / 2.0 + 0.45, size.x / 2.0 - 0.45), 0.2, r.randf_range(-size.y / 2.0 + 0.3, size.y / 2.0 - 0.3))
		var blob := MeshInstance3D.new()
		var rr := r.randf_range(0.26, 0.38)
		blob.mesh = _rock_mesh(seed + i * 5, rr, 0.18)
		blob.position = q + Vector3(0, rr * 0.5, 0)
		blob.scale = Vector3(1.0, 0.75, 1.0)
		blob.material_override = leaf
		add_child(blob)


func _dress_elf_open_courtyard(team: int, bx: float, side: float) -> void:
	## The open courtyard's garden (Faisal's 2026-10-09 brief, after the
	## courtyard reference): one runner from the spawn circle to the castle
	## passage and one along the class row, lawn and planting beds along the
	## south fence, the workshop grouped by the Upgrade Station, trees with
	## layered crowns and clipped bushes framing the fence from outside, and
	## nothing loose in the middle.
	var color: Color = Stats.FACTIONS[team].color
	var hz := CELLAR_HALF_Z
	# Runners: spawn circle to the passage, and the length of the class row.
	_add_rug(Vector3(bx + side * 7.0, 0.03, 0), Vector2(10.4, 2.6), color)
	_add_emblem_decal(Vector3(bx + side * 7.0, 0.11, 0), 1.7, team)
	_add_rug(Vector3(bx + side * 10.6, 0.03, -(hz - 4.6)), Vector2(13.0, 1.6), color.darkened(0.08))
	for k in 3:
		_add_emblem_decal(Vector3(bx + side * (6.0 + k * 4.6), 0.11, -(hz - 4.6)), 1.1, team)
	# (No lawn, planting beds or loose stores along the south fence: "random
	# green texture box?", Faisal 08:18 2026-10-09. The Upgrade Station
	# carries its own bench and casks.)
	# Trees with layered crowns outside the fence, bushes between them.
	for k in 4:
		_add_canopy_tree(Vector3(bx + side * (2.6 + k * 4.9), 0, hz + 2.7), 700 + k, 1.0 + 0.12 * (k % 2))
	for k in 3:
		_add_canopy_tree(Vector3(bx + side * (4.2 + k * 5.4), 0, -(hz + 3.6)), 710 + k, 0.95)
	for zs in [-1.0, 1.0]:
		_add_canopy_tree(Vector3(bx + side * (CELLAR_DEPTH + 2.8), 0, zs * 8.6), 720 + int(zs), 1.05)
	for k in 3:
		_add_hedge_blob(Vector3(bx + side * (5.1 + k * 4.9), 0, hz + 1.5), 0.62, 730 + k)
		_add_hedge_blob(Vector3(bx + side * (5.7 + k * 4.9), 0, hz + 2.1), 0.45, 740 + k)
	for zs in [-1.0, 1.0]:
		_add_hedge_blob(Vector3(bx + side * (CELLAR_DEPTH + 1.6), 0, zs * 3.6), 0.6, 750 + int(zs))
		_add_hedge_blob(Vector3(bx + side * (CELLAR_DEPTH + 2.2), 0, zs * 4.6), 0.42, 760 + int(zs))


func _build_cellar(team: int, bx: float, side: float) -> void:
	## The spawn cellar: a sunken stone hall behind the keep with the class
	## stations in it (Fat Princess hat machines, our way) and a flight of
	## stairs up through the back wall into the keep. Its parapet keeps the
	## field out, so the only way in from outside is still the front door.
	## The Wildwood Elves' courtyard is the exception (Faisal's 2026-10-09
	## courtyard brief): an open garden at ground level (`cellar_floor`)
	## fenced on three sides, its class stations in a row under a pavilion.
	var color: Color = Stats.FACTIONS[team].color
	var cx := bx + side * (CELLAR_DEPTH / 2.0)
	var hz := CELLAR_HALF_Z
	var fy := cellar_floor(team)
	var open := fy >= 0.0
	var top := 0.9
	var wall_h := top - CELLAR_Y
	var wall_y := CELLAR_Y + wall_h / 2.0
	if open:
		await _world_build_frame()
		_add_block(Vector3(cx, fy - 0.05, 0), Vector3(CELLAR_DEPTH + 1.0, 0.1, hz * 2 + 1), Color.WHITE, true, _pavers())
		await _world_build_frame()
		_add_elf_courtyard_fence(bx, side, hz)
	else:
		await _world_build_frame()
		# (Castle pass 2026-10-31: the match world's sunken spawn halls take
		# the courtyard's big flags, grey for the Humans.)
		var cellar_mat: Material = _pbr("castle_flags_grey" if grey else "castle_flags", 0.16, Color(0.95, 0.93, 0.9)) if world_style else _flagstone(Color(0.9, 0.86, 0.8))
		_add_block(Vector3(cx, CELLAR_Y - 0.05, 0), Vector3(CELLAR_DEPTH + 1.0, 0.1, hz * 2 + 1), Color.WHITE, true, cellar_mat)
		# The Elves' courtyard is walled in trimmed hedge (the Wildbloom reference).
		hedge_tops = team == 0
		await _world_build_frame()
		_add_wall(Vector3(bx + side * (CELLAR_DEPTH + 0.5), wall_y, 0), Vector3(1, wall_h, hz * 2 + 1))
		for zs in [-1.0, 1.0]:
			await _world_build_frame()
			_add_wall(Vector3(cx, wall_y, zs * (hz + 0.5)), Vector3(CELLAR_DEPTH + 2.0, wall_h, 1))
		hedge_tops = false
	# A cobbled lane from the spawn circle to the foot of the stairs (Elves);
	# the Humans roll out a royal runner. The open courtyard's runner is laid
	# with the rest of its garden.
	if open:
		pass
	elif team == 0:
		await _world_build_frame()
		_add_block(Vector3(bx + side * 10.4, CELLAR_Y + 0.012, 0), Vector3(3.8, 0.024, 3.2), Color.WHITE, false, _pbr("cobble", 0.55, Color(0.9, 0.86, 0.78)))
	else:
		await _world_build_frame()
		_add_rug(Vector3(bx + side * 10.6, CELLAR_Y + 0.012, 0), Vector2(4.2, 2.6), color)
		await _world_build_frame()
		_add_emblem_decal(Vector3(bx + side * 10.6, CELLAR_Y + 0.06, 0), 1.7, team)
	for zs in [-1.0, 1.0]:
		if open:
			break   # no walls to hang anything on
		# Under the castle's back wall: solid below ground except at the stairs.
		var seg := hz + 0.5 - 1.8
		await _world_build_frame()
		_add_block(Vector3(bx, CELLAR_Y / 2.0, zs * (1.8 + seg / 2.0)), Vector3(1, -CELLAR_Y, seg), Color.WHITE, true, _ashlar())
		# Torches and banners along the south wall; the north wall holds the
		# class alcoves.
		if zs > 0.0:
			for k in range(1, 5):   # (k = 0 sat right over the shelves)
				var tx := bx + side * (1.5 + k * 3.8)
				await _world_build_frame()
				_add_wall_torch(Vector3(tx, CELLAR_Y + 1.6, zs * (hz - 0.05)), Vector3(0, 0, -zs))
			for px in [7.2, 11.0, 14.8]:   # between the torches (they burned through the cloth at 5.3, 9.0, 12.9)
				await _world_build_frame()
				_add_pennant(team, Vector3(bx + side * px, CELLAR_Y + 3.0, zs * (hz - 0.05)), Vector3(0, 0, -zs), 1.1, 2.0, px == 11.0)
			# Flower beds and stores along the south wall (the courtyard reference);
			# the Humans drill here instead: an armoury rack, targets and dummies.
			if team == 0:
				# One bed, 2.9 m off the south wall: the game camera looks over
				# that wall and its top hides the first ~2.5 m of floor behind it
				# (World & Maps' finding), so the beds that hugged it at hz-1.4
				# were never seen in play; the lawn and table further along
				# already dress the visible strip.
				await _world_build_frame()
				_add_flower_bed(Vector3(bx + side * 3.4, CELLAR_Y, zs * (hz - 2.9)), Vector2(2.0, 1.1), 303)
			# (The Humans' drill corner, rack and dummy, went (Faisal 2026-10-09 08:14, circled as clipping or out of place).)
			if team == 0:
				await _world_build_frame()
				_prop("dungeon/crates_stacked", Vector3(bx + side * 17.0, CELLAR_Y, zs * (hz - 1.8)), 0.7, 0.3 * side)
				await _world_build_frame()
				_add_blocker(Vector3(bx + side * 17.0, CELLAR_Y, zs * (hz - 1.8)), 0.7, 1.5)
				await _world_build_frame()
				_prop("dungeon/barrel_large", Vector3(bx + side * 17.2, CELLAR_Y, zs * (hz - 4.6)), 0.8)
	# Stone fire pillars round the spawn circle (both factions: the reference's
	# torches on stone pillars) and the faction's banners on poles behind it.
	# (The Humans' spawn hall keeps none of them (Faisal 2026-10-09 08:14, circled as clipping or out of place).)
	if team == 0:
		for zs in [-1.0, 1.0]:
			for pxo in [12.0, 17.0]:
				await _world_build_frame()
				_add_stone_brazier(Vector3(bx + side * pxo, fy, zs * 3.6))
			# Open courtyard: back to the west fence, facing across the yard to
			# the castle wall (Faisal 08:35 2026-10-09).
			await _world_build_frame()
			_add_banner_pole(team, Vector3(bx + side * 17.2, fy, zs * 6.2), atan2(-side, 0.0) if open else 0.0)
	# The stairs: a straight flight up the middle into the keep. The open
	# courtyard is level with the keep, so a threshold strip marks the way in.
	var st := cellar_stairs(team)
	if open:
		# The ground has a gap under the old stairs' top (x 69..70.5 on the
		# lane): a solid paved sill fills it, with the threshold strip on top.
		await _world_build_frame()
		_add_block(Vector3(bx - side * 0.9, -0.044, 0), Vector3(3.4, 0.1, 3.8), Color.WHITE, true, _pavers())
		await _world_build_frame()
		_add_block(Vector3(bx + side * 1.0, 0.02, 0), Vector3(1.8, 0.04, 3.6), Color.WHITE, false, _ashlar(Color(0.9, 0.86, 0.78)))
	else:
		await _world_build_frame()
		_add_stairs(st[0], st[1], 3.2, _ashlar(Color(0.9, 0.86, 0.78)), 0.0)
		# (The low walls along the stairs went (Faisal 2026-10-09 08:14, circled as clipping or out of place): from the camera they
		# read as loose slabs cutting through the steps.)
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
		await _world_build_frame()
		_add_crystal(Vector3(bx - side * 0.2, 0, -2.3), 0.7)
		await _world_build_frame()
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
		# Two stone lions guard the way down instead of torches: tight against
		# the back wall either side of the opening, clear of the diagonal from
		# the stairs' top to the galleries' back corners and of the wall art.
		for zs in [-1.0, 1.0]:
			await _world_build_frame()
			_add_stone_lion(Vector3(bx - side * 0.7, 0, zs * 2.4), Vector3(-side, 0, 0), 0.8)
	# The spawn circle at the far end: a glowing team-coloured ring on the floor.
	var spawn := Vector3(bx + side * 14.5, fy, 0)
	await _world_build_frame()
	_add_runes(spawn, 2.1, color)
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
	await _world_build_frame()
	_furnish_cellar(team, bx, side)
	if open:
		await _world_build_frame()
		_dress_elf_open_courtyard(team, bx, side)
		if world_style:
			await _world_build_frame()
			CastleKit.courtyard_castle_face(self, team, bx, side)
	elif team == 0:
		await _world_build_frame()
		_dress_elf_courtyard(team, bx, side)
	# The class room: six alcoves in a row along the north wall, facing the
	# camera, each with its class's name on a sign, its hat on a pedestal and
	# a glowing rune circle (the Rogue's is locked until account level 10).
	# In the open courtyard the row stands under a pavilion along the north
	# fence, the stations centred on the courtyard and a clear stride apart.
	var order := [Role.KNIGHT, Role.ENGINEER, Role.RANGER, Role.MAGE, Role.ROGUE, Role.HEALER]
	if open:
		var xs: Array = []
		for k in order.size():
			xs.append(bx + side * (9.0 + (k - 2.5) * 2.85))
		# (No pavilion canopy: from the game camera its canvas showed only as
		# green slivers under the top bar, "this is bugged what is this green
		# stuff", Faisal 09:06 2026-10-09. Each sign stands on its own posts.)
		for k in order.size():
			var p := Vector3(xs[k], fy, -(hz - 2.0))
			await _world_build_frame()
			_add_class_alcove(team, order[k], p)
			await _world_build_frame()
			_add_station(team, order[k], p)
	else:
		for k in order.size():
			var p := Vector3(bx + side * (2.0 + k * 2.9), CELLAR_Y, -(hz - 1.6))
			await _world_build_frame()
			_add_class_alcove(team, order[k], p)
			await _world_build_frame()
			_add_station(team, order[k], p)
	# The Upgrade Station (perk menu) and the Wildwood Guide by the back wall;
	# in the open courtyard the station and its workshop take the south-east
	# corner by the castle wall and the Guide stands by the passage. (The
	# Humans' station and workshop corner are in their own branch below.)
	if open:
		# By the class row's near end, its board backing onto the row and the
		# anvil facing the room ("wrong way", Faisal 08:18 2026-10-09: it sat
		# in the far corner by the exit).
		# Turned to face the spawn circle, its board backing onto the castle
		# wall (Faisal 08:35 2026-10-09: "make it face toward the players
		# spawning in").
		var up := Vector3(bx + side * 2.8, fy, -3.4)
		var to_spawn := Vector3(bx + side * 14.5, fy, 0) - up
		await _world_build_frame()
		_add_upgrade_pad(team, up, atan2(to_spawn.x, to_spawn.z), true)
	elif team == 0:
		await _world_build_frame()
		_add_upgrade_pad(team, Vector3(bx + side * 1.1, CELLAR_Y, -5.0))
	if team == 0 and not open:
		# The workshop corner round the Upgrade Station: shelves of supplies
		# against the west wall, crates and a barrel (the brief's grouped
		# workshop props; off the stairs lane and the class row).
		await _world_build_frame()
		_prop("dungeon/shelves", Vector3(bx + side * 0.9, CELLAR_Y, -7.7), 0.7, PI / 2.0 if side < 0.0 else -PI / 2.0)
		await _world_build_frame()
		_prop("dungeon/bottle_A_labeled_green", Vector3(bx + side * 0.9, CELLAR_Y + 0.95, -7.5), 0.5)
		await _world_build_frame()
		_prop("dungeon/bottle_B_green", Vector3(bx + side * 0.9, CELLAR_Y + 0.95, -7.95), 0.5)
		await _world_build_frame()
		_prop("dungeon/crates_stacked", Vector3(bx + side * 1.0, CELLAR_Y, -2.9), 0.6, 0.2)
		await _world_build_frame()
		_prop("dungeon/barrel_large", Vector3(bx + side * 2.7, CELLAR_Y, -7.6), 0.7)
	elif team != 0:
		# The Humans' station stands like the Elves' did: its board backs onto
		# the class row and faces the room, the anvil in front of it (Faisal
		# 08:13: in the south-west corner it faced the wrong way, its back to
		# the room). Its own workbench and casks dress it; nothing else added.
		# Off the side wall and turned to face the spawn circle, with the small
		# anvil instead of the gold pad, like the Elves' (Faisal 11:28: "this
		# is clipped into the wall and also face it the other way and take out
		# the orange circle with it").
		var hup := Vector3(bx + side * 3.2, CELLAR_Y, -4.6)
		var h_to_spawn := Vector3(bx + side * 14.5, CELLAR_Y, 0) - hup
		await _world_build_frame()
		_add_upgrade_pad(team, hup, atan2(h_to_spawn.x, h_to_spawn.z), true)
	await _world_build_frame()   # (claude-faisal/stutter: the guide and the castle's rest were one 74 ms step)
	var g := Guide.new()
	add_child(g)
	if open:
		g.setup(self, team, Vector3(bx + side * 1.3, fy, 5.2), PI / 2.0 if side < 0.0 else -PI / 2.0)
	else:
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
			if items[i][0].contains("bottle") or items[j][0].contains("bottle"):
				continue  # bottles stand on shelves by design
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
			var pc: Vector3 = items[i][1].get_center()
			if b[0] == "building" and Vector2(pc.x - bb.get_center().x, pc.z - bb.get_center().z).length() < 1.2:
				continue  # a prop's own walk-around blocker
			if b[0] == "vault" and bb.grow(0.4).encloses(items[i][1]):
				continue  # furniture standing inside the throne room
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
		cm.albedo_color = Color(0.66, 0.8, 1.0, 0.85)   # moonstone blue (was teal-green 0.5, 0.95, 0.85)
		cm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		cm.emission_enabled = true
		cm.emission = Color(0.4, 0.62, 1.0)
		cm.emission_energy_multiplier = 1.4
		c.material_override = cm
		add_child(c)
	var light := OmniLight3D.new()
	light.light_color = ELF_GLOW
	light.light_energy = 0.6
	light.omni_range = 4.0 * scale
	light.position = pos + Vector3(0, 0.8, 0)
	add_child(light)


var world_env: WorldEnvironment
var world_environment: Environment
var sky_material: ProceduralSkyMaterial
var sun_light: DirectionalLight3D
var fill_light: DirectionalLight3D
var cam_attrs: CameraAttributesPractical


func _pick_graphics() -> void:
	## Until the player picks a preset in Settings, the game picks one for
	## the graphics card: Low on built-in (laptop) graphics, High on a
	## graphics card, and _auto_quality steps a slow card down. The FPS
	## counter starts on so a number can
	## be reported back.
	# (Tests and renders, which pass their own flags, keep the preset.)
	if gfx_picked or OS.has_feature("web") or DisplayServer.get_name() == "headless" or not OS.get_cmdline_user_args().is_empty():
		return
	match RenderingServer.get_video_adapter_type():
		RenderingDevice.DEVICE_TYPE_DISCRETE_GPU:
			gfx_quality = 2   # High; a weak card steps itself down (_auto_quality)
		_:
			gfx_quality = 0
	if not fps_intro_done:
		fps_intro_done = true   # once: the player can switch it off in Settings
		show_fps = true


func _auto_quality() -> void:
	## Until the player picks a preset, one step down whenever the game runs
	## under 40 frames a second for four seconds (a toast says so). Never
	## steps up. Long stalls (loading, a shader built the first time) do not
	## count: they restart the window.
	if gfx_picked or gfx_quality == 0 or (OS.has_feature("web") and not playing) or DisplayServer.get_name() == "headless" or not OS.get_cmdline_user_args().is_empty():
		return
	var now := Time.get_ticks_msec()
	if is_instance_valid(loading_layer) or now - _fps_last > 250:
		_fps_since = 0
	_fps_last = now
	if _fps_since == 0:
		_fps_since = now
		_fps_frames = 0
		return
	_fps_frames += 1
	if now - _fps_since < 4000:
		return
	var fps := _fps_frames * 1000.0 / float(now - _fps_since)
	_fps_since = 0
	if OS.has_feature("web") and Engine.max_fps == 0 and fps < 52.0:
		# A browser that cannot hold 60 runs 0, 1 or 2 physics steps a frame
		# at random, so units jump (Faisal 2026-10-10 "frame skipping and
		# jumping" on the iPad). A steady 30 gives every frame exactly two
		# steps: smooth motion, and slack for the slow frames.
		Engine.max_fps = 30
		return
	if fps < (26.0 if OS.has_feature("web") else 40.0):
		gfx_quality -= 1
		apply_graphics()
		_save_settings()
		toast("Graphics set to %s for smoother play (Settings to change)" % GFX_NAMES[gfx_quality].capitalize(), Color(1.0, 0.9, 0.6))


func apply_graphics() -> void:
	## The graphics preset and display mode, applied live. Low suits older
	## laptops and the Compatibility renderer; Ultra adds volumetric light
	## shafts and 8x MSAA.
	var q := gfx_quality
	var vp := get_viewport()
	vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X, Viewport.MSAA_8X][q]
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if q == 0 else Viewport.SCREEN_SPACE_AA_DISABLED
	if ink_on:
		# The ink lines read the depth buffer, which multisampling blurs
		# away on some drivers: FXAA smooths the lines instead.
		vp.msaa_3d = Viewport.MSAA_DISABLED
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	vp.scaling_3d_scale = 0.8 if q == 0 else 1.0
	# (FSR needs Forward+; the Compatibility renderer scales bilinear.)
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if q == 0 and RenderingServer.get_rendering_device() != null else Viewport.SCALING_3D_MODE_BILINEAR
	if render_scale < 1.0:
		# Settings > 3D Res: the world renders smaller and FSR (Forward+) scales
		# it up, for weaker PCs and the Steam Deck; the HUD stays full-size.
		vp.scaling_3d_scale = minf(vp.scaling_3d_scale, render_scale)
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if RenderingServer.get_rendering_device() != null else Viewport.SCALING_3D_MODE_BILINEAR
	vp.positional_shadow_atlas_size = [1024, 2048, 4096, 8192][q]
	# High takes the 4096 sun map (four 2048 cascades): from the match camera it
	# looks the same as 8192 and costs ~3.6 ms less GPU a frame, the step that
	# kept High under 60 fps (PERF-03). Ultra keeps 8192.
	RenderingServer.directional_shadow_atlas_set_size([2048, 4096, 4096, 8192][q], true)
	RenderingServer.directional_soft_shadow_filter_set_quality([RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW, RenderingServer.SHADOW_QUALITY_SOFT_LOW, RenderingServer.SHADOW_QUALITY_SOFT_HIGH, RenderingServer.SHADOW_QUALITY_SOFT_ULTRA][q])
	RenderingServer.positional_soft_shadow_filter_set_quality([RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW, RenderingServer.SHADOW_QUALITY_SOFT_LOW, RenderingServer.SHADOW_QUALITY_SOFT_HIGH, RenderingServer.SHADOW_QUALITY_SOFT_ULTRA][q])
	# Clean, smooth edges at every preset: the low soft-shadow filters
	# dither (a field of dots round each shadow), so Low and Medium take the
	# medium filter; FXAA runs on top of multisampling, and Medium gets 4x.
	RenderingServer.directional_soft_shadow_filter_set_quality([RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM, RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM, RenderingServer.SHADOW_QUALITY_SOFT_HIGH, RenderingServer.SHADOW_QUALITY_SOFT_ULTRA][q])
	RenderingServer.positional_soft_shadow_filter_set_quality([RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM, RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM, RenderingServer.SHADOW_QUALITY_SOFT_HIGH, RenderingServer.SHADOW_QUALITY_SOFT_ULTRA][q])
	if vp.msaa_3d == Viewport.MSAA_2X and q >= 2:
		vp.msaa_3d = Viewport.MSAA_4X
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	if OS.has_feature("web"):
		# Browsers (an iPad at 2x pixel density): no multisampling; the 3D
		# view renders at three quarters of the canvas size (half looked
		# blurry on the iPad: Faisal 2026-10-09 "low textures") and FXAA
		# smooths it, while the HUD stays at full density.
		vp.msaa_3d = Viewport.MSAA_DISABLED
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
		vp.scaling_3d_scale = 1.0 if q >= 1 else 0.75
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		# One 2048 shadow map covers the single cascade the web sun uses, read
		# with one tap (the soft filters cost a kernel per pixel).
		RenderingServer.directional_shadow_atlas_set_size(2048, true)
		RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)
		vp.positional_shadow_atlas_size = 1024
		# Low in a browser drops the sun's shadow: the shadow map redraws
		# every caster (about 1,150 WebGL draws) and the sun lights each
		# object in a second pass. Medium brings both back.
		if sun_light:
			sun_light.shadow_enabled = q >= 1
	# Low and Medium: low-quality contact shadows, and two
	# sun shadow cascades on Low (High keeps the project's Ultra AO and four).
	RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_LOW if q <= 1 else RenderingServer.ENV_SSAO_QUALITY_ULTRA, true, 0.5, 2, 50.0, 300.0)
	for l in lamp_shadows:
		if is_instance_valid(l):
			l.shadow_enabled = q >= 1 and not OS.has_feature("web")   # each is six more depth passes a frame
	if sun_light and not OS.has_feature("web"):
		sun_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if q == 0 else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	if world_environment:
		world_environment.ssao_enabled = q >= 1
		world_environment.ssil_enabled = q >= 2
		world_environment.glow_enabled = q >= 1
		world_environment.volumetric_fog_enabled = q >= 3
	if cam_attrs:
		cam_attrs.dof_blur_far_enabled = q >= 2 and not style_live   # the match keeps its woods sharp (_match_grade)
	for pane in panes:
		pane.view.msaa_3d = vp.msaa_3d
		pane.view.screen_space_aa = vp.screen_space_aa
		pane.view.scaling_3d_scale = vp.scaling_3d_scale
		pane.view.scaling_3d_mode = vp.scaling_3d_mode
		# Every pane renders its own shadow maps: the lamps' cube shadows
		# (six passes each) were redrawn per pane. Two players keep them at a
		# smaller size; three and four drop them (lamps still light).
		pane.view.positional_shadow_atlas_size = 0 if panes.size() >= 3 else mini(vp.positional_shadow_atlas_size, 2048)
	if sun_light and panes.size() >= 3 and not OS.has_feature("web"):
		# Three or four panes: two sun cascades instead of four (each cascade
		# redraws every shadow caster once per pane, and a quarter-screen
		# pane cannot show the extra detail).
		sun_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		# ...and only out to 45 m: a quarter-screen pane sees less ground, and
		# the casters past it were ~2,000 draws a frame across four panes.
		sun_light.directional_shadow_max_distance = 45.0
	if DisplayServer.get_name() != "headless":
		# Only switch when the setting disagrees with the window: a maximized
		# window is not "windowed", and forcing WINDOWED on every call (match
		# start, the lobby, after a match) shrank it back to 1920x1080
		# (Faisal 2026-10-10: "goes into smaller window").
		var mode := DisplayServer.window_get_mode()
		var is_full := mode in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
		# Code that only flips `fullscreen` (older saves, tests) still works.
		if not fullscreen:
			window_mode = "windowed"
		elif window_mode == "windowed":
			window_mode = "borderless"
		if window_mode == "borderless" and mode != DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		elif window_mode == "exclusive" and mode != DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		elif window_mode == "windowed" and is_full:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		# VSync and the frame cap (Settings > DISPLAY), saved like the rest.
		if not OS.has_feature("web"):
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync_on else DisplayServer.VSYNC_DISABLED)
			Engine.max_fps = fps_cap


func _apply_map_variant() -> void:
	## Day or the Moonlit Wildwood: sky, sun (or moon), ambient, fog and glow.
	if world_environment == null:
		return
	if vmap:
		vmap.apply_light()
		if style_live:
			_style_light()
		return
	var dark := night()
	if season != "":
		_season_light()
	elif dark:
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
		# Late-afternoon storybook light (Faisal's target art, 2026-10-07): a
		# low warm sun throwing long shadows, cool blue ambient so the shade
		# reads coloured, and torches and braziers that bloom.
		# Graphics pass 2026-10-09 (to the Elf base renders): a little more
		# ambient so the shade is coloured, not black; a slightly higher,
		# softer sun with blurred shadow edges; less neon saturation.
		# Courtyard pass (2026-10-09, Faisal): less ambient so shaded faces
		# stay visibly darker than lit ones, a slightly stronger sun and
		# firmer shadow edges, so posts, beds and stations sit on the ground.
		world_environment.ambient_light_energy = 0.21
		world_environment.ambient_light_sky_contribution = 0.3
		world_environment.ambient_light_color = Color(0.5, 0.6, 0.85)
		world_environment.fog_light_color = Color(0.95, 0.85, 0.7)
		world_environment.fog_density = 0.0012
		world_environment.glow_intensity = 0.6
		world_environment.glow_hdr_threshold = 1.05
		world_environment.adjustment_saturation = 1.08
		world_environment.adjustment_brightness = 1.0
		world_environment.adjustment_contrast = 1.08
		sun_light.light_color = Color(1.0, 0.92, 0.78)
		sun_light.light_energy = 1.42
		sun_light.rotation_degrees = Vector3(-46, -32, 0)
		sun_light.shadow_opacity = 0.92
		sun_light.light_angular_distance = 0.8
		sun_light.shadow_blur = 0.8
		if fill_light:
			fill_light.light_energy = 0.07
	if style_live:
		_style_light()
	if camera:
		Season.attach_weather(camera, air_kind())


func air_kind() -> String:
	## What drifts through the air (Season.AIR): the map's kind, with the
	## Moonlit Wildwood only once it is unlocked.
	var k: String = Stats.MAPS[map_variant][1]
	return "day" if k == "night" and not night() else k


func _season_light() -> void:
	## Stonekeep Fortress: a low, cold winter sun over bright snow, blue
	## shade and a pale haze. Twilight Grove: the sun just above the
	## horizon, magenta sky, violet shade, and the glows doing the work.
	if season == "winter":
		sky_material.sky_top_color = Color(0.52, 0.66, 0.86)
		sky_material.sky_horizon_color = Color(0.88, 0.92, 0.97)
		sky_material.ground_bottom_color = Color(0.74, 0.8, 0.88)
		sky_material.ground_horizon_color = Color(0.86, 0.9, 0.95)
		world_environment.ambient_light_energy = 0.34
		world_environment.ambient_light_sky_contribution = 0.4
		world_environment.ambient_light_color = Color(0.66, 0.78, 1.0)
		world_environment.fog_light_color = Color(0.84, 0.9, 0.98)
		world_environment.fog_density = 0.0034
		world_environment.glow_intensity = 0.5
		world_environment.glow_hdr_threshold = 1.15
		world_environment.adjustment_saturation = 1.0
		world_environment.adjustment_contrast = 1.08
		world_environment.adjustment_brightness = 0.98
		world_environment.tonemap_exposure = 0.88   # snow is bright: keep it off white-out
		sun_light.light_color = Color(1.0, 0.92, 0.82)
		sun_light.light_energy = 1.3
		sun_light.rotation_degrees = Vector3(-34, -40, 0)
		sun_light.shadow_opacity = 0.85
		sun_light.light_angular_distance = 0.8
		sun_light.shadow_blur = 0.9
		if fill_light:
			fill_light.light_color = Color(0.55, 0.68, 1.0)
			fill_light.light_energy = 0.16
	elif season == "twilight":
		sky_material.sky_top_color = Color(0.2, 0.12, 0.4)
		sky_material.sky_horizon_color = Color(1.0, 0.55, 0.55)
		sky_material.ground_bottom_color = Color(0.14, 0.1, 0.22)
		sky_material.ground_horizon_color = Color(0.6, 0.36, 0.5)
		world_environment.ambient_light_energy = 0.58
		world_environment.ambient_light_sky_contribution = 0.35
		world_environment.ambient_light_color = Color(0.66, 0.58, 1.0)
		world_environment.fog_light_color = Color(0.9, 0.5, 0.7)
		world_environment.fog_density = 0.0024
		world_environment.glow_intensity = 0.9
		world_environment.glow_hdr_threshold = 0.95
		world_environment.adjustment_saturation = 1.06
		world_environment.adjustment_contrast = 1.06
		world_environment.adjustment_brightness = 1.04
		sun_light.light_color = Color(1.0, 0.66, 0.52)
		sun_light.light_energy = 1.35
		sun_light.rotation_degrees = Vector3(-34, -62, 0)
		sun_light.shadow_opacity = 0.8
		sun_light.light_angular_distance = 1.0
		sun_light.shadow_blur = 1.0
		if fill_light:
			fill_light.light_color = Color(0.56, 0.6, 1.0)
			fill_light.light_energy = 0.24


func _style_light() -> void:
	## The style guide's light on top of the map's own: a warm golden sun,
	## coloured (not black) shade that still reads with ambient occlusion,
	## bloom and the ink lines off (Low, Compatibility, the web), and a
	## touch more colour. Day, the Moonlit Wildwood and Ember Pass each keep
	## their mood; only the match world gets it (style_live, set at the
	## match start), so the menus' lighting is untouched.
	# Worlds are reused between matches: restore the original occlusion on
	# non-day variants, rather than leaking the day grade into night/Ember.
	var daylight: bool = not vmap and season == "" and not night()
	_match_grade()
	world_environment.ssao_radius = StyleProfile.DAY.ao_radius if daylight else 1.1
	world_environment.ssao_intensity = StyleProfile.DAY.ao_intensity if daylight else 3.2
	world_environment.ssao_power = StyleProfile.DAY.ao_power if daylight else 1.2
	if vmap:
		world_environment.ambient_light_energy = StyleProfile.EMBER.ambient_energy
		return
	if season != "":
		return   # the season's own light (_season_light)
	if night():
		world_environment.ambient_light_energy = StyleProfile.NIGHT.ambient_energy
		sun_light.light_energy = StyleProfile.NIGHT.sun_energy
		if fill_light:
			fill_light.light_energy = StyleProfile.NIGHT.fill_energy
		return
	var d: Dictionary = StyleProfile.DAY
	sun_light.light_color = d.sun_color
	sun_light.light_energy = d.sun_energy
	sun_light.shadow_blur = d.shadow_blur
	sun_light.light_angular_distance = d.sun_angle
	world_environment.ambient_light_energy = d.ambient_energy
	world_environment.ambient_light_color = d.ambient_color
	world_environment.ambient_light_sky_contribution = d.ambient_sky
	world_environment.adjustment_saturation = d.saturation
	world_environment.adjustment_contrast = d.contrast
	world_environment.adjustment_brightness = d.brightness
	world_environment.fog_light_color = d.fog_color
	if fill_light:
		fill_light.light_energy = d.fill_energy


func _match_grade() -> void:
	## The match camera's post grade (StyleProfile.GRADE): crisp and
	## saturated, without the haze, wide bloom and edge blur that washed the
	## frame out. Glow and bounce light stay switched by the graphics preset
	## (apply_graphics); this sets how strong they are.
	var mood := "ember" if vmap else (season if season in ["winter", "twilight"] else ("night" if night() else "day"))
	var g: Dictionary = StyleProfile.GRADE[mood]
	world_environment.tonemap_white = g.white
	world_environment.tonemap_exposure = g.exposure
	world_environment.glow_intensity = g.glow
	world_environment.glow_hdr_threshold = g.glow_threshold
	world_environment.fog_enabled = g.fog > 0.0
	world_environment.fog_density = g.fog
	world_environment.ssil_intensity = g.ssil
	if g.has("contrast"):
		world_environment.adjustment_contrast = g.contrast
		world_environment.adjustment_saturation = g.saturation
	if g.has("ambient"):
		world_environment.ambient_light_energy = g.ambient
	if cam_attrs:
		cam_attrs.dof_blur_far_enabled = false   # the woods at the frame edge stay sharp
	if ink_mat:
		ink_mat.set_shader_parameter("strength", g.ink)
		ink_mat.set_shader_parameter("vignette", g.vignette)


func _build_world() -> void:
	_build_world_sky()
	await _build_world_land()


func _build_world_sky() -> void:
	## The sky, fog and sun: the menus are lit by them too, so they come
	## first even when the land waits (_build_world_behind).
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
	environment.ambient_light_energy = 0.75
	environment.ambient_light_sky_contribution = 0.5
	environment.ambient_light_color = Color(0.75, 0.85, 0.8)
	# Soft contact shadows under props and in corners (Forward+ only).
	environment.ssao_enabled = true
	environment.ssao_radius = 1.1
	environment.ssao_intensity = 3.2
	environment.ssao_power = 1.2
	# Light bouncing off lit surfaces into shade (grass green on the walls,
	# torchlight on the floors): Forward+ only, High and Ultra.
	environment.ssil_enabled = true
	environment.ssil_radius = 4.0
	environment.ssil_intensity = 0.7
	environment.ssil_normal_rejection = 1.0
	# Filmic keeps the cartoon colours bright and saturated where ACES
	# darkened and greyed them.
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 0.95
	environment.tonemap_white = 6.0
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
	environment.adjustment_saturation = 1.25
	environment.adjustment_contrast = 1.1
	environment.adjustment_brightness = 1.0
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
	sun.light_angular_distance = 1.2   # soft shadow edges (graphics pass 2026-10-09; was 0 = crisp)
	sun.light_volumetric_fog_energy = 1.4
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_split_1 = 0.12
	sun.directional_shadow_split_2 = 0.3
	sun.directional_shadow_max_distance = 70.0
	if OS.has_feature("web"):
		# Browsers: one shadow map over the visible ground instead of four
		# cascades (each cascade redraws every caster: thousands of WebGL
		# draw calls a frame on the iPad). The camera sees about 45 m.
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		sun.directional_shadow_max_distance = 50.0
	add_child(sun)
	# A cool fill from the other side so shadows are not black.
	var fill := DirectionalLight3D.new()
	fill_light = fill
	fill.rotation_degrees = Vector3(-30, 140, 0)
	fill.light_color = Color(0.6, 0.7, 1.0)
	fill.light_energy = 0.15
	add_child(fill)


func _build_world_land() -> void:
	if Stats.MAPS[map_variant][1] == "volcano":
		await _world_build_frame()
		await _build_volcano()
		return
	# Ground, in pieces so each castle's spawn cellar can be sunk behind it.
	var gx := map_half.x + 40.0
	var gz := map_half.y + 30.0
	var h0 := CASTLE_X + CASTLE_DEPTH - 0.5          # cellar hole from here...
	var h1 := CASTLE_X + CASTLE_DEPTH + CELLAR_DEPTH + 0.5   # ...to here (x), mirrored
	var hz := CELLAR_HALF_Z + 0.5
	var grass := Color(0.42, 0.62, 0.3)
	var lane := CASTLE_X + CASTLE_DEPTH - 2.0  # the stairs' top reaches in this far
	await _world_build_frame()
	_add_block(Vector3(0, -0.5, 0), Vector3(lane * 2, 1, gz * 2), grass, true, _grass())
	for sx in [-1.0, 1.0]:
		for zs in [-1.0, 1.0]:
			await _world_build_frame()
			_add_block(Vector3(sx * (lane + h0) / 2.0, -0.5, zs * (1.9 + gz) / 2.0), Vector3(h0 - lane, 1, gz - 1.9), grass, true, _grass())
	for sx in [-1.0, 1.0]:
		await _world_build_frame()
		_add_block(Vector3(sx * (h1 + gx) / 2.0, -0.5, 0), Vector3(gx - h1, 1, gz * 2), grass, true, _grass())
		for zs in [-1.0, 1.0]:
			await _world_build_frame()
			_add_block(Vector3(sx * (h0 + h1) / 2.0, -0.5, zs * (hz + gz) / 2.0), Vector3(h1 - h0, 1, gz - hz), grass, true, _grass())
	if season != "":
		# Stonekeep Fortress and Twilight Grove: their own layouts on the same
		# ground, castles and outskirts (scripts/lanes.gd).
		lmap = Lanes.new(self, season)
		await _build_lanes_land()
		return
	# A dirt road from door to door, with a worn patch at each door and in the middle.
	# The road: rutted dirt from bridge to door, cobbled aprons at each door,
	# and grass creeping in at the edges.
	var fxr := CASTLE_X - CASTLE_DEPTH
	var road := _stones()
	# The main road: a cobbled path door to door through the shrine, with
	# paved aprons at the doors.
	await _world_build_frame()
	_add_path(Vector3(-fxr, 0, 0), Vector3(-ISLAND_R - 2.0, 0, 0), 5.4, road, 0.0)
	await _world_build_frame()
	_add_path(Vector3(ISLAND_R + 2.0, 0, 0), Vector3(fxr, 0, 0), 5.4, road, 0.0)
	for sx in [-1.0, 1.0]:
		# (The flagstone apron over the cobbles at each door went: one paving
		# from the bridge to the gate; Faisal 2026-10-09 06:00, "the front
		# textures are not even uniform".)
		# The Forest Path (north) and the River Path (south): from the road by
		# the castle door out to the flank bridges, cobbled like the main road
		# (they were loose stones in dirt: one cobble style map-wide, the
		# courtyard reference).
		var dirt := _stones()
		var nb: float = BRIDGES[0]
		var sb: float = BRIDGES[2]
		await _world_build_frame()
		_add_path(Vector3(sx * (fxr - 4.0), 0, -3.0), Vector3(sx * 30.0, 0, nb - 3.0), 3.4, dirt, 0.0)
		await _world_build_frame()
		_add_path(Vector3(sx * 30.0, 0, nb - 3.0), Vector3(sx * (RIVER_HALF + 1.5), 0, nb), 3.4, dirt, 0.0)
		await _world_build_frame()
		_add_path(Vector3(sx * (fxr - 4.0), 0, 3.0), Vector3(sx * 26.0, 0, sb + 2.0), 3.4, dirt, 0.0)
		await _world_build_frame()
		_add_path(Vector3(sx * 26.0, 0, sb + 2.0), Vector3(sx * (RIVER_HALF + 1.5), 0, sb), 3.4, dirt, 0.0)
		# Road dressing: milestones on the verge, signposts at the path
		# bends and an abandoned cart by the roadside.
		# (Two milestones a side; the roadside caravan pile was clutter and went.)
		# (The milestones gave way to the stone braziers in _add_road_dressing.)
		await _world_build_frame()
		_add_signpost(Vector3(sx * 31.5, 0, nb - 5.2), -sx)
		await _world_build_frame()
		_add_signpost(Vector3(sx * 27.5, 0, sb + 4.3), sx)
	await _world_build_frame()
	await _add_river()

	await _world_build_frame()
	await _build_castle(0)
	await _world_build_frame()
	await _build_castle(1)
	await _world_build_frame()
	await _add_cover()
	await _world_build_frame()
	_add_heal_orbs()

	# Mirrored groves in the contested middle, leaving the roads clear, and
	# thick forest along the north edge where the Forest Path runs.
	var grove := [Vector3(8, 0, 8), Vector3(14, 0, 13), Vector3(22, 0, 6), Vector3(10, 0, 18),
		Vector3(26, 0, 16), Vector3(32, 0, 11), Vector3(5, 0, 14), Vector3(18, 0, 20), Vector3(38, 0, 15), Vector3(42, 0, 5),
		Vector3(4, 0, -32), Vector3(10, 0, -34), Vector3(18, 0, -31), Vector3(24, 0, -34), Vector3(32, 0, -30), Vector3(40, 0, -33), Vector3(46, 0, -28),
		Vector3(3, 0, -16), Vector3(16, 0, -11), Vector3(36, 0, -14), Vector3(8, 0, 32), Vector3(30, 0, 33), Vector3(44, 0, 30), Vector3(34, 0, 24)]
	for p in grove:
		await _world_build_frame()
		_add_tree(p)
		await _world_build_frame()
		_add_tree(-p)
		await _world_build_frame()
		_add_bush(p + Vector3(1.8, 0, 0.6), int(p.x * 3 + p.z))
		await _world_build_frame()
		_add_bush(-p + Vector3(-1.8, 0, -0.6), int(p.x * 5 + p.z))
	for p in [Vector3(12, 0, 14), Vector3(-12, 0, -14), Vector3(26, 0, 14), Vector3(-26, 0, -14), Vector3(58, 0, 22), Vector3(-58, 0, -22), Vector3(9, 0, -25), Vector3(-9, 0, 25)]:
		await _world_build_frame()
		_add_fireflies(p)
	# The Wildwood half glows: more fireflies and mushroom rings on the elven side.
	for p in [Vector3(-50, 0, 12), Vector3(-50, 0, -12), Vector3(-38, 0, 5), Vector3(-30, 0, -20), Vector3(-42, 0, 26), Vector3(-20, 0, 18)]:
		await _world_build_frame()
		_add_fireflies(p)
	for i in 8:
		var mp := Vector3(-16.0 - i * 6.0, 0, (7.5 + float(i % 3) * 5.0) * (1.0 if i % 2 == 0 else -1.0))
		await _world_build_frame()
		_add_mushrooms(mp, 100 + i)
	# Woods on the castle flanks.
	for p in [Vector3(52, 0, 19), Vector3(60, 0, 22), Vector3(68, 0, 18), Vector3(46, 0, 24), Vector3(56, 0, 30)]:
		await _world_build_frame()
		_add_tree(p, true)
		await _world_build_frame()
		_add_tree(-p, true)
		await _world_build_frame()
		_add_tree(Vector3(p.x, 0, -p.z), true)
		await _world_build_frame()
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
				await _world_build_frame()
				_add_tree(p, i % 4 == 0)
	await _world_build_frame()
	await _add_ground_detail()
	# A tree line and hills beyond the playable edge, so the world has a
	# horizon; the hamlets and farms sit in gaps in it.
	for i in 22:
		var x := -84.0 + i * 8.0
		if absf(x) < 42.0:
			await _world_build_frame()
			_prop("hex/trees_%s_medium" % ["A", "B"][i % 2], Vector3(x, 0, 40.0 + (i % 3) * 1.5), 4.0, float(i))
			await _world_build_frame()
			_prop("hex/trees_%s_medium" % ["B", "A"][i % 2], Vector3(x + 3.0, 0, -40.0 - (i % 3) * 1.5), 4.0, float(i))
	for i in 7:
		# Hills beyond the far edges, but not behind the farms and villages.
		var hx := -60.0 + i * 20.0
		if absf(hx) < 42.0:
			await _world_build_frame()
			_prop("hex/hill_single_%s" % ["A", "B", "C"][i % 3], Vector3(hx, -0.2, 60.0), 12.0, float(i))
		if absf(hx + 10.0) < 42.0:
			await _world_build_frame()
			_prop("hex/hill_single_%s" % ["B", "C", "A"][i % 3], Vector3(hx + 10.0, -0.2, -60.0), 12.0, float(i) + 1.0)
	await _world_build_frame()
	await _build_outskirts()
	await _world_build_frame()
	await _add_back_forest()
	if not "--no-economy" in OS.get_cmdline_user_args():   # testing: a match without wood and ore (balance baselines)
		economy = Economy.new()
		add_child(economy)
		await economy.build(self)
	await _world_build_frame()
	await _finish_world()


func _build_lanes_land() -> void:
	## Stonekeep Fortress / Twilight Grove: the layout's lanes, terrain and set
	## pieces (scripts/lanes.gd) in place of the Wildwood's river, field paths
	## and groves; the castles, outskirts, economy and season art are shared.
	await _world_build_frame()
	await lmap.build()
	await _world_build_frame()
	await _build_castle(0)
	await _world_build_frame()
	await _build_castle(1)
	await _world_build_frame()
	var cover: Dictionary = lmap.cover()
	await _add_cover(cover.barricades, cover.boulders, false)
	for p in lmap.heal_orb_spots():
		var orb = HealOrb.new()
		add_child(orb)
		orb.setup(self, p)
		heal_orbs.append(orb)
	# Woods on the castle flanks, as on the Wildwood.
	for p in [Vector3(52, 0, 19), Vector3(60, 0, 22), Vector3(68, 0, 18), Vector3(46, 0, 24), Vector3(56, 0, 30)]:
		for q in [p, -p, Vector3(p.x, 0, -p.z), Vector3(-p.x, 0, p.z)]:
			if lmap.height(q.x, q.z) > 0.0:
				continue   # the ridges / grove wrap the castle's flank there
			await _world_build_frame()
			_add_tree(q, true)
	await _world_build_frame()
	await _add_ground_detail()
	for i in 7:
		# Hills beyond the far edges.
		var hx := -60.0 + i * 20.0
		if absf(hx) < 42.0:
			await _world_build_frame()
			_prop("hex/hill_single_%s" % ["A", "B", "C"][i % 3], Vector3(hx, -0.2, 60.0), 12.0, float(i))
		if absf(hx + 10.0) < 42.0:
			await _world_build_frame()
			_prop("hex/hill_single_%s" % ["B", "C", "A"][i % 3], Vector3(hx + 10.0, -0.2, -60.0), 12.0, float(i) + 1.0)
	await _world_build_frame()
	await _build_outskirts()
	await _world_build_frame()
	await _add_back_forest()
	if not "--no-economy" in OS.get_cmdline_user_args():
		economy = Economy.new()
		add_child(economy)
		await economy.build(self)
	await _world_build_frame()
	await _finish_world()


func _build_volcano() -> void:
	## Ember Pass: the same two castles on basalt plateaus over a lava sea,
	## joined by bridges (scripts/volcano.gd builds everything else).
	vmap = Volcano.new(self)
	await vmap.build()
	# Soot-dark castles: the lava's red light turns pale stone, bark and
	# moss glaring yellow and green.
	soot = Color(0.52, 0.46, 0.44)
	tex_swap = {"bark": "elfbark", "flagstone_moss": "flagstone_elf"}
	await _world_build_frame()
	await _build_castle(0)
	await _world_build_frame()
	await _build_castle(1)
	soot = Color.WHITE
	tex_swap = {}
	for p in vmap.heal_orb_spots():
		var orb = HealOrb.new()
		add_child(orb)
		orb.setup(self, p)
		heal_orbs.append(orb)
	await _world_build_frame()
	await _finish_world()


func _finish_world() -> void:
	if season != "":
		# Stonekeep Fortress / Twilight Grove: the season's grade over the
		# finished world, then its own scenery.
		Season.grade(self, season)
		Season.decorate(self, season, {"half": RIVER_HALF if lmap == null else 0.0, "y": 0.03, "bridges": BRIDGES, "island": ISLAND_R})
	if forest_kit:
		# The kit's trees and dressing, after the grade (it has its own
		# palette per map) and once everything they keep clear of is built.
		await _world_build_frame()
		forest_kit.finish()
	await _world_build_frame()
	_apply_map_variant()
	camera = Camera3D.new()
	camera.rotation_degrees = Vector3(-50, 0, 0)
	camera.fov = 40.0
	camera.position = Vector3(0, 40, 26)
	add_child(camera)
	# (Built behind the title, the menus keep their camera: the match one took
	# over and drew the whole battlefield behind the opaque title art, 2,600
	# objects a frame, and its first frame stalled ~180 ms drawing it.
	# _start_match makes it current when the menus go.)
	if not _world_behind:
		camera.make_current()
	Season.attach_weather(camera, air_kind())
	await _world_build_frame()
	_add_ink()
	if OS.has_feature("web"):
		await _world_build_frame()
		_trim_web_shadows()
	elif world_style:
		# Desktop too, at a smaller size (style pass 2026-10-14): buds,
		# candles, pebbles and bolts under 0.3 m throw shadows no one sees
		# from the gameplay camera, and each is a draw in every sun cascade.
		await _world_build_frame()
		_trim_web_shadows(0.3)
	await _world_build_frame()
	await _unfight_coplanar()


func _unfight_coplanar() -> void:
	## Z-fighting pass (beta feedback 2026-10-15: "green flag texture error",
	## flashing textures): two visible faces of different materials in the
	## same plane flicker as the camera moves. The same check as
	## tools/zfight_audit.gd, on the built world; for each such pair the
	## piece with the smaller face moves: a cloth, trim or rug (no more than
	## 8 cm through the shared face) steps 6 mm out in front of what it lies
	## on; anything deeper pulls just that face 6 mm back, its other faces
	## staying put, so no new pair appears at its far side. Only meshes
	## move, never their colliders (a block's StaticBody3D and shape stay
	## where they were built). A move can land a piece on a third face, so
	## the check runs again on the moved world, up to four rounds.
	var total := 0
	for _pass in 4:
		var n := await _unfight_round()
		total += n
		if n == 0:
			break
	if "--audit" in OS.get_cmdline_user_args():
		print("UNFIGHT moved %d faces" % total)


func _unfight_round() -> int:
	var moved := {}
	var faces := {}
	for mi in find_children("*", "MeshInstance3D", true, false):
		await _world_build_frame()
		if not mi.is_visible_in_tree() or not (mi.mesh is BoxMesh or mi.mesh is QuadMesh or mi.mesh is PlaneMesh or mi.mesh is CylinderMesh):
			continue
		var mat: Material = mi.material_override
		if mat is BaseMaterial3D and mat.no_depth_test:
			continue   # health bars and labels draw on top by design
		var t: Transform3D = mi.global_transform
		var half: Vector3
		var normals: Array
		if mi.mesh is BoxMesh:
			half = mi.mesh.size / 2.0
			normals = [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.BACK, Vector3.FORWARD]   # undersides never show
		elif mi.mesh is QuadMesh:
			half = Vector3(mi.mesh.size.x / 2.0, mi.mesh.size.y / 2.0, 0.0)
			normals = [Vector3.BACK]
		elif mi.mesh is PlaneMesh:
			half = Vector3(mi.mesh.size.x / 2.0, 0.0, mi.mesh.size.y / 2.0)
			normals = [Vector3.UP]
		else:
			# A cylinder's top cap, as the square inside it (like the audit).
			var r: float = mi.mesh.top_radius * 0.7
			half = Vector3(r, mi.mesh.height / 2.0, r)
			normals = [Vector3.UP]
		for nl in normals:
			var depth: float = (nl.abs() * half * 2.0 * t.basis.get_scale()).length()   # through the face
			var wn: Vector3 = (t.basis * nl).normalized()
			var axis := -1
			for a in 3:
				if absf(wn[a]) > 0.999:
					axis = a
			if axis < 0:
				continue
			var lo := Vector3(INF, INF, INF)
			var hi := -lo
			for sx in [-1.0, 1.0]:
				for sy in [-1.0, 1.0]:
					for sz in [-1.0, 1.0]:
						var c := Vector3(sx * half.x, sy * half.y, sz * half.z)
						for k in 3:
							if nl[k] != 0.0:
								c[k] = nl[k] * half[k]
						var wp: Vector3 = t * c
						lo = lo.min(wp)
						hi = hi.max(wp)
			var plane: float = (lo[axis] + hi[axis]) / 2.0
			var u := (axis + 1) % 3
			var w := (axis + 2) % 3
			var key := "%d|%d|%d" % [axis, signi(int(signf(wn[axis]))), floori(plane / 0.01)]
			if not faces.has(key):
				faces[key] = []
			faces[key].append([plane, Rect2(Vector2(lo[u], lo[w]), Vector2(hi[u] - lo[u], hi[w] - lo[w])), mi, wn, depth, nl])
	for key in faces:
		await _world_build_frame()
		var list: Array = faces[key]
		var parts: PackedStringArray = key.split("|")
		var other: Array = faces.get("%s|%s|%d" % [parts[0], parts[1], int(parts[2]) + 1], [])
		# Broad phase: only faces sharing a spatial cell can overlap. Keep
		# the original pair order: earlier repairs affect later moved checks.
		var combined := list + other
		var cells := {}
		for j in combined.size():
			var rect: Rect2 = combined[j][1]
			for x in range(floori(rect.position.x / 4.0), floori(rect.end.x / 4.0) + 1):
				for y in range(floori(rect.position.y / 4.0), floori(rect.end.y / 4.0) + 1):
					var cell := Vector2i(x, y)
					if not cells.has(cell):
						cells[cell] = []
					cells[cell].append(j)
		for i in list.size():
			await _world_build_frame()
			var nearby := {}
			var rect: Rect2 = list[i][1]
			for x in range(floori(rect.position.x / 4.0), floori(rect.end.x / 4.0) + 1):
				for y in range(floori(rect.position.y / 4.0), floori(rect.end.y / 4.0) + 1):
					for j in cells[Vector2i(x, y)]:
						if j > i:
							nearby[j] = true
			var candidates := nearby.keys()
			candidates.sort()
			for j in candidates:
				var a: Array = list[i]
				var b: Array = list[j] if j < list.size() else other[j - list.size()]
				var ka := "%d|%s|%s" % [a[2].get_instance_id(), parts[0], parts[1]]
				var kb := "%d|%s|%s" % [b[2].get_instance_id(), parts[0], parts[1]]
				if a[2] == b[2] or absf(a[0] - b[0]) > 0.003 or moved.has(ka) or moved.has(kb):
					continue
				if a[1].intersection(b[1]).get_area() < 0.0004 or _same_look(a[2].material_override, b[2].material_override):
					continue
				var thin: Array = a if a[1].get_area() <= b[1].get_area() else b
				var mi: MeshInstance3D = thin[2]
				if thin[4] <= 0.08:
					mi.global_position += thin[3] * 0.006
				elif not mi.mesh is BoxMesh:
					continue
				else:
					# 6 mm off the shared face only: shrink 6 mm along that
					# local axis and slide 3 mm back, so the far face holds.
					var nl: Vector3 = thin[5].abs()
					mi.scale *= Vector3.ONE - nl * (0.006 / nl.dot(mi.mesh.size))
					mi.global_position -= thin[3] * 0.003
				moved[ka if thin == a else kb] = true
	return moved.size()


func _same_look(a: Material, b: Material) -> bool:
	if a == b:
		return true
	if a is BaseMaterial3D and b is BaseMaterial3D:
		return a.albedo_color.is_equal_approx(b.albedo_color) and a.albedo_texture == b.albedo_texture
	return false


func _trim_web_shadows(limit: float = 0.8) -> void:
	## Browsers: small clutter (candles, buds, mushrooms, plates, bricks under
	## 0.8 m) stops casting shadows. Each caster is a WebGL draw call in the
	## sun's shadow pass every frame, and a shadow that small hides under its
	## own prop from the 50-degree camera. Units, trees, walls and furniture
	## keep theirs.
	var trimmed := 0
	for n in find_children("*", "MeshInstance3D", true, false):
		if n.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF or n.mesh == null:
			continue
		var ext: Vector3 = n.mesh.get_aabb().size * n.global_transform.basis.get_scale()
		if maxf(ext.x, maxf(ext.y, ext.z)) < limit:
			n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			trimmed += 1
	if perf_log:
		print("PERF web shadow trim: %d small casters off" % trimmed)



func _add_back_forest() -> void:
	## Thick woods behind each castle and out to the map's ends (Faisal
	## 2026-10-07: "a surplus of trees"), on a jittered grid. Every spot goes
	## through the usual tree checks, so roads, buildings, the hamlets,
	## farms and works stay clear; the spawn cellars are kept open too.
	var r := RandomNumberGenerator.new()
	r.seed = 2027
	var cellar_x1 := CASTLE_X + CASTLE_DEPTH + CELLAR_DEPTH + 3.0
	for sx in [-1.0, 1.0]:
		var gx := 46.0
		while gx < 118.0:
			var gz := -46.0
			while gz <= 46.0:
				var p := Vector3(sx * (gx + r.randf_range(-1.4, 1.4)), 0, gz + r.randf_range(-1.4, 1.4))
				gz += 4.4
				var ax := absf(p.x)
				var az := absf(p.z)
				if ax < CASTLE_X + CASTLE_DEPTH + 2.0 and az < CASTLE_HALF_Z + 6.0:
					continue   # the castle and its flanks' lanes
				if ax < cellar_x1 and az < CELLAR_HALF_Z + 3.0:
					continue   # the spawn cellar
				if ax < 70.0 and az < 18.0:
					continue
				if ax > 108.0 and az < 34.0:
					continue   # the mountains
				await _world_build_frame()
				_add_tree(p, r.randf() < 0.3)
			gx += 4.4


var ink_on := false
var ink_mat: ShaderMaterial = null   # the ink pass (_add_ink): _match_grade sets its strength


func _add_ink() -> void:
	## Cartoon ink lines: one full-screen pass drawn by every camera (the
	## shader ignores the quad's place in the world), so split-screen panes
	## get them too. Needs the depth buffer, so not on the Compatibility
	## renderer.
	if RenderingServer.get_rendering_device() == null:
		return
	var q := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	q.mesh = quad
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/ink_outline.gdshader")
	mat.render_priority = 100
	q.material_override = mat
	ink_mat = mat
	q.extra_cull_margin = 16384.0
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(q)
	ink_on = true


func _drawn_frame() -> void:
	## Wait for the next drawn frame, but never forever: a minimized or
	## not-presenting window (alt-tab, a window bigger than the screen)
	## stops frame_post_draw, and the warm-ups then held the loading art
	## and menus_warming up for minutes. Give up after 30 undrawn frames.
	var drawn := [false]
	var mark := func() -> void: drawn[0] = true
	RenderingServer.frame_post_draw.connect(mark, CONNECT_ONE_SHOT)
	var tree := get_tree()
	for i in 30:
		await tree.process_frame
		if drawn[0] or not is_inside_tree():
			break
	if RenderingServer.frame_post_draw.is_connected(mark):
		RenderingServer.frame_post_draw.disconnect(mark)


func _warm_up_menus(land_on: String = "title") -> void:
	## The first visit to a menu screen loaded its art, built the hero and
	## compiled its shaders on the spot: a visible stutter on each first
	## click (Faisal 2026-10-10, on an RTX 4090). Show each screen for a
	## frame while the loading art still covers the window, then go back.
	if not is_instance_valid(loading_layer) or main_menu == null or DisplayServer.get_name() == "headless":
		return
	var m = main_menu
	menus_warming = true
	# Keep first-use model/shader work behind the loading art. Ready Up
	# builds four fighters and pedestals and must be included in this pass.
	var warm_tween := loading_tween
	if warm_tween and warm_tween.is_valid():
		warm_tween.pause()
	var tree := get_tree()
	for scr in ["character", "store", "map", "lobby"]:
		await tree.process_frame
		# An online joiner's scene reloads when the host welcomes it: this
		# game node is then gone (get_tree() was null: a script error).
		if not is_inside_tree() or not is_instance_valid(loading_layer) or main_menu != m or playing:
			menus_warming = false
			if warm_tween and warm_tween.is_valid():
				warm_tween.play()
			return
		var saved_sides := lobby_sides.duplicate()
		var saved_players := couch_players
		var saved_ready: Array = m.readied.duplicate()
		if scr == "lobby":
			m._enter_lobby()
		m.screen = scr
		# A process frame alone does not establish that the new screen drew.
		await _drawn_frame()
		if scr == "character" and is_inside_tree() and main_menu == m:
			var saved_tab: int = m.char_tab
			for tab in m.CHAR_TABS.size():
				if not is_inside_tree() or main_menu != m or playing:
					break
				m.char_tab = tab
				await tree.process_frame
				await _drawn_frame()
			if is_inside_tree() and main_menu == m:
				m.char_tab = saved_tab
		if scr == "store" and is_inside_tree() and main_menu == m:
			var saved_tab: int = m.store.tab
			var saved_page: int = m.store.page
			var saved_pick: Array = m.store.pick.duplicate()
			for tab in m.store.TABS.size():
				if not is_inside_tree() or main_menu != m or playing:
					break
				m.store.press("store_tab", tab)
				await tree.process_frame
				await _drawn_frame()
			if is_inside_tree() and main_menu == m:
				m.store.tab = saved_tab
				m.store.page = saved_page
				m.store.pick = saved_pick
		if scr == "lobby" and is_inside_tree() and main_menu == m:
			m.screen = "map"
			lobby_sides = saved_sides
			couch_players = saved_players
			m.readied = saved_ready
	await tree.process_frame
	if not is_inside_tree():
		return
	if main_menu == m and not playing:
		menu_open = true
		menu_tab = 5   # SETTINGS
	for i in 2:
		await tree.process_frame
	if not is_inside_tree():
		return
	if main_menu == m and not playing:
		menu_open = false
		menu_tab = 0
		m.screen = land_on
	menus_warming = false
	if warm_tween and warm_tween.is_valid() and warm_tween == loading_tween:
		_fade_loading_now()
	elif warm_tween and warm_tween.is_valid():
		warm_tween.play()


func _warm_up_world() -> void:
	## Under the loading art, point the camera at every part of the map for a
	## couple of frames, so each material's shaders (and their shadow-pass
	## versions) compile now and not mid-fight. On a fresh install, or after
	## an update changes a shader, the first match stalled half a second a
	## dozen times in its first 15 s while new scenery came into view
	## (claude-faisallaptop 2026-10-16). With the shader cache warm this
	## takes a dozen quick frames.
	if not is_instance_valid(loading_layer) or DisplayServer.get_name() == "headless" or player == null:
		return
	if loading_tween:
		loading_tween.pause()
	await _warm_up_models()
	if hud:
		hud.prewarm_pins()
	var keep := cam_lock
	var spots := []
	for x in [-100.0, -66.0, -33.0, 0.0, 33.0, 66.0, 100.0]:
		for z in [-28.0, 0.0, 28.0]:
			spots.append(Vector3(x, 0, z))
	for spot in spots:
		if not is_instance_valid(loading_layer) or not playing:
			break
		cam_lock = spot
		cam_pos = spot + CAMERA_OFFSET * cam_zoom
		for pane in panes:
			pane.cam_pos = cam_pos
		await _drawn_frame()
		await _drawn_frame()
	cam_lock = keep
	if player:
		cam_pos = player.global_position + CAMERA_OFFSET * cam_zoom
		for pane in panes:
			if is_instance_valid(pane.unit):
				pane.cam_pos = pane.unit.global_position + CAMERA_OFFSET * cam_zoom * pane.zoom
	if loading_tween and loading_tween.is_valid():
		_fade_loading_now()


const WARM_MODEL_SLICE_USEC := 30000


func _warm_up_models() -> void:
	## Every class (and every promotion) once per team, built in front of the
	## camera under the loading art: the first build of each model loads its
	## scene, skins and faces and compiles their shaders (55-65 ms, a visible
	## hitch when the first bot of the match picked that class up); later
	## builds reuse all of it (~7 ms).
	var rack := Node3D.new()
	add_child(rack)
	rack.global_position = cam_pos - CAMERA_OFFSET * cam_zoom
	var looks := []
	for team in 2:
		for role in Stats.Role.values():
			looks.append([team, role, "", 1])
			looks.append([team, role, "", 3])
			if Stats.VARIANTS.has(role):
				for v in Stats.VARIANTS[role]:
					looks.append([team, role, v.name, 1])
	# A few at a time, each lot drawn (and its shaders compiled) before the
	# next: all ~50 in the Play click's own frame held the loading art
	# frozen ~1.7 s (claude-faisal3 2026-10-29, PERF-04 rest).
	var slice_end := Time.get_ticks_usec() + WARM_MODEL_SLICE_USEC
	for i in looks.size():
		if i > 0 and Time.get_ticks_usec() >= slice_end:
			await _drawn_frame()
			if not is_inside_tree() or not is_instance_valid(rack):
				return
			slice_end = Time.get_ticks_usec() + WARM_MODEL_SLICE_USEC
		var m = CharacterModel.new()
		rack.add_child(m)
		m.position = Vector3((i % 8) * 1.2 - 4.2, 0, (i / 8) * 1.2 - 3.0)
		var l: Array = looks[i]
		m.setup(l[0], l[1], l[2], {}, l[3])
	await _drawn_frame()
	await _drawn_frame()
	if is_instance_valid(rack):
		rack.queue_free()


func _warm_up_effects() -> void:
	## One of every combat effect under the match's loading art, so the
	## first punch, spell and death of the match do not stall while their
	## shaders compile.
	if not is_instance_valid(loading_layer) or DisplayServer.get_name() == "headless":
		return
	var fx = Fx.of(self)
	var p: Vector3 = (player.global_position if player else camera.global_position + Vector3(0, -40, -26)) + Vector3(0, 0.1, 0)
	var w := Color.WHITE
	for style in 4:
		fx.burst(p, w, 3, 1.0, 0.25, style)
	fx.flare(p, w)
	fx.ground_ring(p, 1.0, w)
	fx.ground_glow(p, 1.0, w)
	fx.rune(p, 1.0, w)
	fx.scorch(p, 1.0, Color(0.1, 0.1, 0.1, 0.5), 0.3)
	fx.beam(p + Vector3.UP, p + Vector3(2, 1, 0), w)
	fx.slash(p + Vector3.UP, Vector3.FORWARD, w)
	fx.slash(p + Vector3.UP, Vector3.FORWARD, w, 1.0, true)
	for kind in Fx.KINDS:
		fx.hit(p + Vector3.UP, Vector3.FORWARD, kind)
		fx.blast(p, 1.2, kind)
	fx.death(p, w)
	fx.petals(p, w, 3)
	fx.thorns(p, 1.0, w, 3, 0.3)
	fx.rays(p, w, 3, 1.0, 0.2)


func _keep_window_alive() -> void:
	## Long builds (the world, a match start) block the main thread for
	## seconds. Every quarter second, let the OS know the window is alive
	## (input that arrives meanwhile is dropped, so no half-built scene
	## sees a click). Faisal 2026-10-10: the Windows .exe went "Not
	## Responding" while it loaded.
	## Only inside a frame that has already run a quarter second: in normal
	## play (projectiles, effects and numbers add nodes all the time) it
	## must never run, or it ate the player's clicks (2026-10-10).
	var now := Time.get_ticks_msec()
	var frame := Engine.get_process_frames()
	if frame != _alive_frame:
		_alive_frame = frame
		_alive_frame_start = now
		return
	if now - _alive_frame_start < 250 or now - _alive_ms < 250:
		return
	_alive_ms = now
	if DisplayServer.get_name() != "headless" and not OS.has_feature("web"):   # (a browser tab never goes "Not Responding")
		DisplayServer.force_process_and_drop_events()


func _toonify(node) -> void:
	## Cel shading: hard-edged light and shadow on every standard material.
	_keep_window_alive()
	if not is_instance_valid(node) or not node is GeometryInstance3D:
		return
	_toon_mat(node.material_override)
	if node is MeshInstance3D:
		for i in node.get_surface_override_material_count():
			_toon_mat(node.get_surface_override_material(i))
		if node.mesh:
			for i in node.mesh.get_surface_count():
				_toon_mat(node.mesh.surface_get_material(i))
	elif node is MultiMeshInstance3D and node.multimesh and node.multimesh.mesh:
		for i in node.multimesh.mesh.get_surface_count():
			_toon_mat(node.multimesh.mesh.surface_get_material(i))


func _toon_mat(m) -> void:
	if not m is BaseMaterial3D or m.diffuse_mode == BaseMaterial3D.DIFFUSE_LAMBERT_WRAP:
		return
	if m.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
		return
	# Soft wrapped shading (graphics pass 2026-10-09): the reference renders
	# are painterly, with gentle light-to-shade gradients on every clump and
	# block; the two-band toon diffuse read flat and plastic next to them.
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	# Shiny things (gold, glass, water) keep a crisp toon highlight; matte
	# ones none, so the ground and walls do not get blotchy sun spots.
	m.specular_mode = BaseMaterial3D.SPECULAR_TOON if m.roughness < 0.6 else BaseMaterial3D.SPECULAR_DISABLED


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)

	hud = Hud.new()
	hud.game = self
	layer.add_child(hud)
	touch = Touch.new()
	touch.game = self
	layer.add_child(touch)

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
	_add_action("move_interact", [], [], -1, 0.0, [MOUSE_BUTTON_LEFT])
	_add_action("force_move", [], [], -1, 0.0, [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_XBUTTON1])
	_add_action("force_hold", [KEY_SHIFT], [])
	_add_action("attack", [KEY_J], [JOY_BUTTON_A], JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_add_action("block", [KEY_K], [JOY_BUTTON_LEFT_SHOULDER], JOY_AXIS_TRIGGER_LEFT, 1.0, [MOUSE_BUTTON_RIGHT])
	_add_action("ability_1", [KEY_Q], [JOY_BUTTON_X])
	_add_action("ability_2", [KEY_E], [JOY_BUTTON_Y])
	_add_action("ability_3", [KEY_G], [JOY_BUTTON_LEFT_STICK])   # the upgraded hat's move (economy.gd)
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


# --- Online smoke test (tools/net_smoke.sh) -----------------------------------

func _net_test_tick(delta: float) -> void:
	## --net-test: the host starts a match as soon as a joiner is ready.
	## Both walk their player for 1.5 s and check that everyone moved on both
	## screens; the joiner swings and chats; then the match runs on and the
	## joiner checks that the host's effects, animations, sounds, shots,
	## class looks and its own chat line all reached it. Prints NETTEST PASS
	## / FAIL and quits.
	var L := net_test_log
	if L.get("done", false):
		return
	L.clock = L.get("clock", 0.0) + delta
	var cap := 200.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--net-test-hold="):   # (a held host waits for its late joiner too)
			cap = maxf(cap, float(arg.trim_prefix("--net-test-hold=")) + 120.0)
	if L.clock > cap:
		_net_test_end(false, "timed out (connected=%s playing=%s snapshots=%d)" % [net.online(), playing, net.snapshot_count])
		return
	if not playing:
		if net.is_host() and net.ready_peers.size() >= 1:
			_start_match(0)
		return
	if net_client and net.snapshot_count == 0:
		return
	var who := "client" if net_client else "host"
	L.t = L.get("t", 0.0) + delta
	var t: float = L.t
	if not L.has("start"):
		L.start = units.map(func(u): return u.global_position)
		L.remote = units.map(func(u): return u.remote_peer > 0).find(true)
		L.ok = true
		print("NETTEST %s: match running, my unit is team %d slot %d" % [who, player.team, units.find(player) % team_size])
	if t > 1.0 and not L.has("pressed"):
		L.pressed = true
		Input.action_press("move_down")
	if t > 2.5 and not L.has("released"):
		L.released = true
		Input.action_release("move_down")
	if net_client and t > 3.0 and not L.has("chat"):
		L.chat = true
		_send_chat("/all hello from the joiner")
		Input.action_press("attack")
	if net_client and t > 3.6 and not L.has("swung"):
		L.swung = true
		Input.action_release("attack")
	if not net_client and t > 4.0 and not L.has("shot") and player:
		# The host fires one harmless arrow, so the joiner's "shots arrived"
		# check does not hang on whether a bot happened to shoot in time.
		L.shot = true
		var dir: Vector3 = player.facing if player.facing.length() > 0.1 else Vector3(0, 0, -1)
		spawn_shot(player, dir.normalized(), {"damage": 0, "gate_damage": 0, "range": 6.0}, Color(1, 1, 1))
	# A deliberately slow-loading joiner cannot move seven seconds after
	# the host starts. Measure its movement only after input actually arrives;
	# still fail at the deadline if it never becomes playable.
	if not net_client and int(L.remote) >= 0 and not L.has("remote_running"):
		if not units[int(L.remote)].net_input.is_empty():
			L.remote_running = t
	var movement_due := t > 9.0 if net_client else (L.has("remote_running") and t - float(L.remote_running) > 7.0)
	if movement_due and not L.has("moved"):
		L.moved = true
		var moved := func(i: int) -> float:
			var a: Vector3 = L.start[i]
			var b: Vector3 = units[i].global_position
			return Vector2(b.x - a.x, b.z - a.z).length()
		var checks := {}
		checks["own unit moved"] = moved.call(units.find(player))
		var bot_best := 0.0
		for i in units.size():
			if not units[i].is_player and units[i].remote_peer == 0 and i != 0:
				bot_best = maxf(bot_best, moved.call(i))
		checks["a bot moved"] = bot_best
		if net_client:
			checks["host player moved"] = moved.call(0)   # the host plays team 0 slot 0
		else:
			var remote: int = L.remote
			checks["joiner's unit moved"] = moved.call(remote) if remote >= 0 else 0.0
		for k in checks:
			print("NETTEST %s: %s %.2f m" % [who, k, checks[k]])
			if checks[k] < 2.0:
				L.ok = false
	var finish_at := 40.0 if net_client else 44.0   # the host stays on while the joiner checks
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--net-test-hold=") and not net_client:   # testing: the host stays N s (a later joiner can join mid-match)
			finish_at = float(arg.trim_prefix("--net-test-hold="))
	if t > finish_at:
		var ok: bool = L.ok and L.get("moved", false)
		var said := chat_log.any(func(c): return "hello from the joiner" in str(c.text))
		print("NETTEST %s: joiner's chat line %s" % [who, "arrived" if said else "MISSING"])
		ok = ok and said
		if net_client:
			var by: Dictionary = net.events_by
			var shots: int = by.get("game.net_shot", 0)
			var looks: int = by.get("game.net_look", 0)
			print("NETTEST client: events %d (effects %d, animations %d, sounds %d, shots %d, looks %d, skill casts %d)" % [
				net.events_in, by.get("fx", 0), by.get("model", 0), by.get("sfx", 0), shots, looks, by.get("skill", 0)])
			print("NETTEST client: kill feed %d, entities %d, chat lines %d" % [kill_feed.size(), net_ents.size(), chat_log.size()])
			for need in [["effects", by.get("fx", 0)], ["animations", by.get("model", 0)], ["sounds", by.get("sfx", 0)],
					["shots", shots], ["looks", looks]]:
				if need[1] <= 0:
					print("NETTEST client: no %s arrived" % need[0])
					ok = false
		_net_test_end(ok, ("snapshots=%d" % net.snapshot_count) if net_client else ("peers=%d" % net.peer_count()))


func _net_test_end(ok: bool, info: String) -> void:
	if net_test_log.get("done", false):
		return
	net_test_log.done = true
	print("NETTEST %s %s: %s" % ["client" if net_client else "host", "PASS" if ok else "FAIL", info])
	if net.is_host():
		# Keep hosting until the joiner has finished its own checks and left.
		var waited := 0.0
		while net.peer_count() > 0 and waited < 20.0:
			await get_tree().create_timer(0.25).timeout
			waited += 0.25
	get_tree().quit(0 if ok else 1)


func _debug_downed_hooks(frame: int) -> void:
	## Renders for the downed state: "--debug-downed" (the player down, a
	## teammate on the way), "--debug-revive" (a teammate reviving the
	## player), "--debug-healer-revive" (the player, a Healer, reviving a
	## downed teammate).
	var args := OS.get_cmdline_user_args()
	if frame == 5 and "--debug-downed-touch" in args and touch:
		touch.active = true   # renders: the iPad's touch layout over the downed / death screens
		touch_active = true
	var which := ""
	var strike := "--debug-finish-strike" in args
	for k in ["--debug-downed", "--debug-revive", "--debug-healer-revive", "--debug-finish"]:
		if k in args:
			which = k
	if strike:
		which = "--debug-finish"   # the same set-up, held long enough that the blow lands on the shot
	if which == "" or player == null:
		return
	var spot := Vector3(-14, 0, 0) if player_team == 0 else Vector3(14, 0, 0)
	var ally = null
	var foe = null
	for u in units:
		if u != player and u.team == player_team and ally == null:
			ally = u
		if u.team != player_team and foe == null:
			foe = u
	if ally == null or foe == null:
		return
	var away := Vector3(0, 0, -40)
	var lead := 220 if strike else 150   # the strike shot needs the grace, the hold and the swing to play out
	if frame == shot_frame - lead:
		player.global_position = spot
		player.spawn_protect = 0.0
		player.home_defense = false
		if which == "--debug-finish":
			# The player (a Knight) standing over a downed enemy, finishing them.
			player.set_role(Unit.Role.KNIGHT)
			foe.set_role(Unit.Role.RANGER)
			foe.global_position = spot + Vector3(1.4, 0, 0.4)
			foe.spawn_protect = 0.0
			foe.home_defense = false
			foe.take_damage(foe.hearts, player, player.global_position)
			return
		if which == "--debug-healer-revive":
			player.set_role(Unit.Role.HEALER)
			ally.global_position = spot + Vector3(1.6, 0, 0.6)
			ally.set_role(Unit.Role.RANGER)
			ally.spawn_protect = 0.0
			ally.home_defense = false
			ally.take_damage(ally.hearts, foe, ally.global_position + Vector3(2, 0, 0))
		else:
			player.set_role(Unit.Role.RANGER)
			player.take_damage(player.hearts, foe, player.global_position + Vector3(2, 0, 0))
			player.downed_timer = 9.4
			ally.set_role(Unit.Role.KNIGHT)
			ally.global_position = spot + (Vector3(1.2, 0, 0.5) if which == "--debug-revive" else Vector3(10.0, 0, -12.0))
		foe.global_position = away
	if frame == shot_frame - 70 and which == "--debug-healer-revive":
		Input.action_press("interact")
	if which == "--debug-finish":
		if frame == shot_frame - (100 if strike else 28):
			Input.action_press("interact")
		return
	if frame > shot_frame - lead and frame < shot_frame:
		foe.global_position = away   # keep the enemy that downed them out of the shot
