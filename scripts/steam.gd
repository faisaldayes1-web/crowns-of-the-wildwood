extends Node
## Steam hookup (autoload "SteamHub"), through the GodotSteam GDExtension in
## addons/godotsteam. Everything here is optional: with no Steam client, on
## the web, headless, or in a build without the extension, `active` stays
## false and every call is a no-op, so the standalone zip and the iPad link
## play exactly as before. See docs/steam.md.
##
## Settings (project.godot, [steam] section):
##   steam/app_id        the game's Steam App ID (0 until Faisal has one)
##   steam/require_steam true: a copy started outside Steam asks Steam to
##                       relaunch it (only for the Steam depot build)
## Command line: `-- --steam-app=480` tries Valve's test app (Spacewar).

const ACHIEVEMENTS := {
	# id (as created in Steamworks): [name, description]. docs/steam.md lists
	# them for the Steamworks Achievements page.
	"FIRST_WIN": ["First Crown", "Win a match."],
	"WIN_ELVES": ["Heart of the Wildwood", "Win a match as the Elves."],
	"WIN_HUMANS": ["For the Realm", "Win a match as the Humans."],
	"FIRST_CAPTURE": ["Crown Thief", "Carry the enemy crown home."],
	"FIRST_REVIVE": ["Not Today", "Revive a downed ally."],
	"FIRST_FINISHER": ["No Mercy", "Finish off a downed enemy."],
	"ONLINE_MATCH": ["Better Together", "Finish an online match."],
	"LEVEL_5": ["Seasoned", "Reach account level 5."],
	"LEVEL_10": ["Veteran", "Reach account level 10."],
	"LEVEL_20": ["Legend of the Wildwood", "Reach account level 20."],
}

var active := false        # Steam is running and initialised
var app_id := 0
var persona := ""          # the player's Steam name
var status := "off"        # why it is (not) active, for the log and docs
var _steam: Object = null
var _dirty := false        # achievements changed since the last storeStats


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # callbacks keep flowing while paused
	app_id = int(ProjectSettings.get_setting("steam/app_id", 0))
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--steam-app="):
			app_id = int(a.get_slice("=", 1))
	if OS.has_feature("web") or DisplayServer.get_name() == "headless":
		status = "skipped (web or headless)"
		return
	if not Engine.has_singleton("Steam"):
		status = "no GodotSteam extension in this build"
		return
	_steam = Engine.get_singleton("Steam")
	if app_id > 0 and ProjectSettings.get_setting("steam/require_steam", false):
		# Started from the exe directly: Steam relaunches it through the client.
		if _steam.restartAppIfNecessary(app_id):
			status = "relaunching through Steam"
			get_tree().quit()
			return
	var r = _steam.steamInitEx(false, app_id)
	if typeof(r) != TYPE_DICTIONARY or int(r.get("status", 1)) != 0:
		status = "Steam not running (%s)" % (r.get("verbal", "?") if typeof(r) == TYPE_DICTIONARY else str(r))
		_steam = null
		print("Steam: ", status)
		return
	active = true
	persona = str(_steam.getPersonaName())
	status = "on (app %d, %s)" % [app_id, persona]
	if _steam.has_signal("overlay_toggled"):
		_steam.overlay_toggled.connect(_on_overlay)
	print("Steam: ", status)


func _process(_delta: float) -> void:
	if not active:
		return
	_steam.run_callbacks()
	if _dirty:
		_dirty = false
		_steam.storeStats()


func unlock(id: String) -> void:
	## Unlocks one achievement (once; Steam ignores repeats).
	if not active or not ACHIEVEMENTS.has(id):
		return
	var have = _steam.getAchievement(id)
	if typeof(have) == TYPE_DICTIONARY and have.get("achieved", false):
		return
	_steam.setAchievement(id)
	_dirty = true


func level_reached(level: int) -> void:
	for step in [5, 10, 20]:
		if level >= step:
			unlock("LEVEL_%d" % step)


func _on_overlay(open: bool, _user_initiated := false, _app := 0) -> void:
	## The Steam overlay (Shift+Tab) pauses an offline match, like Esc.
	if not open:
		return
	var game = get_tree().current_scene
	if game == null or not ("playing" in game) or not game.playing or game.menu_open:
		return
	game.menu_open = true
	game.menu_tab = 0
	var net = get_node_or_null("/root/Net")
	get_tree().paused = not (net and net.online())
