extends Node
## Cold-launch head start (autoload "BootLoader", listed first so it runs
## before main.tscn and game.gd's preload graph compile).
##
## A release export's cold boot spent ~0.6 s of the main thread decoding the
## HUD's ~213 lossless PNGs (hud.gd _ready) and 0.4-0.7 s single frames on
## the title hall's first prop, texture and character loads (claude-faisal3
## 2026-10-29, Steam push item 4: export-17c3a30 boot breakdown). Here they
## are queued on worker threads at engine start, so they decode while the
## main thread compiles scripts. The callers keep their plain load(): Godot
## 4.3's load() joins a threaded load of the same path already in flight, or
## finds it finished in the cache.
##
## `held` keeps every finished resource referenced for the session, so the
## cache cannot drop one before its caller asks; the HUD, prop and character
## caches hold them all for the session anyway.

const HUD_DIRS := ["res://assets/ui/icons", "res://assets/ui/icons_clean", "res://assets/ui/strips",
	"res://assets/ui/cards", "res://assets/ui/skills"]
const FILES := ["res://assets/ui/logo.png", "res://assets/ui/topbar/topbar.png",
	"res://assets/fonts/LuckiestGuy-Regular.ttf", "res://assets/fonts/LilitaOne-Regular.ttf",
	"res://assets/ui/menu/banner_crown_red.png", "res://assets/ui/menu/banner_crown_blue.png"]
# The title hall's materials (menu_stage.gd _build_hall), in both texture sets.
const TEXTURES := ["greystone", "wood_dark", "wood", "carpet", "stone"]
const TEXTURE_DIRS := ["res://assets/textures/", "res://assets/textures/style/"]
# The hall's clutter, armour stands and title cast, then every class model.
const PROPS := ["barrel_large", "barrel_small_stack", "crates_stacked", "barrel_large_decorated", "chest",
	"keg_decorated", "box_stacked", "barrel_small"]
const CHARACTERS := ["Knight", "Rogue", "Rogue_Hooded", "Mage", "Barbarian"]

var pending: Array[String] = []
var held: Array[Resource] = []


func _ready() -> void:
	# Web builds may have no worker threads (the request would decode on the
	# main thread up front), and headless runs draw nothing.
	if OS.has_feature("web") or DisplayServer.get_name() == "headless":
		set_process(false)
		return
	var paths: Array[String] = []
	for dir in HUD_DIRS:
		paths.append_array(_pngs(dir))
	paths.append_array(FILES)
	for dir in TEXTURE_DIRS:
		for t in TEXTURES:
			paths.append("%s%s_color.jpg" % [dir, t])
			paths.append("%s%s_normal.jpg" % [dir, t])
	for p in PROPS:
		paths.append("res://assets/props/dungeon/%s.glb" % p)
	for c in CHARACTERS:
		paths.append("res://assets/characters/%s.glb" % c)
	paths.append_array(_pngs("res://assets/characters/skins"))
	for path in paths:
		if ResourceLoader.exists(path) and ResourceLoader.load_threaded_request(path) == OK:
			pending.append(path)
	set_process(not pending.is_empty())


func _process(_delta: float) -> void:
	# Collect finished loads: load_threaded_get frees the request. A finished
	# load is only handed over here, never waited on.
	var i := 0
	while i < pending.size():
		var status := ResourceLoader.load_threaded_get_status(pending[i])
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			i += 1
			continue
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var r := ResourceLoader.load_threaded_get(pending[i])
			if r:
				held.append(r)
		pending.remove_at(i)
	if pending.is_empty():
		set_process(false)


static func _pngs(dir: String) -> Array[String]:
	## The PNGs in `dir`. An export lists only "x.png.import" (or ".remap")
	## files, the editor both.
	var out: Array[String] = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for file in d.get_files():
		var png := file.trim_suffix(".import").trim_suffix(".remap")
		if png.ends_with(".png") and not out.has(dir + "/" + png):
			out.append(dir + "/" + png)
	return out
