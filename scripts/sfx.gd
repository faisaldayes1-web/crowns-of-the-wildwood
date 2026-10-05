extends Node
## All sound in the game. Every clip is synthesized by tools/make_sounds.py
## (nothing sampled), loaded from assets/sfx/. play() is positional: it fades
## with distance from the listener, which sits on the local player. ui() is
## for menus, fanfares and anything the player should always hear.

const DIR := "res://assets/sfx/"
const POOL_3D := 28
const POOL_UI := 8
const HEAR_RANGE := 48.0     # metres: beyond this a positional sound is skipped
const MUSIC_MATCH_DB := -11.0
const MUSIC_TITLE_DB := -5.0
const AMBIENCE_DB := -9.0

var streams := {}
var pool_3d: Array = []
var pool_ui: Array = []
var listener: AudioListener3D
var music: AudioStreamPlayer
var ambience: AudioStreamPlayer
var sound_volume := 0.8      # 0..1, saved with the settings
var music_volume := 0.6
var enabled := true
var _last: Dictionary = {}   # name -> last play time (ms), to stop stacks of the same clip


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # menus pause the tree; sound carries on
	var d := DirAccess.open(DIR)
	if d:
		d.list_dir_begin()
		var f := d.get_next()
		while f != "":
			if f.ends_with(".wav"):
				streams[f.trim_suffix(".wav")] = load(DIR + f)
			f = d.get_next()
	for i in POOL_3D:
		var p := AudioStreamPlayer3D.new()
		p.unit_size = 14.0
		p.max_distance = HEAR_RANGE
		p.max_db = 3.0
		p.attenuation_filter_cutoff_hz = 9000
		p.bus = "Master"
		add_child(p)
		pool_3d.append(p)
	for i in POOL_UI:
		var p := AudioStreamPlayer.new()
		add_child(p)
		pool_ui.append(p)
	music = AudioStreamPlayer.new()
	add_child(music)
	ambience = AudioStreamPlayer.new()
	add_child(ambience)
	listener = AudioListener3D.new()
	add_child(listener)
	listener.make_current()
	for name in ["ambience", "theme"]:
		if streams.has(name) and streams[name] is AudioStreamWAV:
			streams[name].loop_mode = AudioStreamWAV.LOOP_FORWARD
			streams[name].loop_end = streams[name].data.size() / 2


func set_listener(pos: Vector3) -> void:
	listener.global_position = pos + Vector3(0, 1.0, 0)


func _db(volume: float) -> float:
	return linear_to_db(maxf(volume, 0.0001))


func play(name: String, pos: Vector3, db: float = 0.0, jitter: float = 0.08) -> void:
	## A sound at a place in the world. Repeats of the same clip within 40 ms
	## merge into one so a volley of hits is not a wall of noise.
	if not enabled or not streams.has(name):
		return
	if listener and listener.global_position.distance_to(pos) > HEAR_RANGE:
		return
	var now := Time.get_ticks_msec()
	if _last.get(name, -1000) > now - 40:
		return
	_last[name] = now
	for p in pool_3d:
		if not p.playing:
			p.stream = streams[name]
			p.global_position = pos
			p.volume_db = db + _db(sound_volume)
			p.pitch_scale = randf_range(1.0 - jitter, 1.0 + jitter)
			p.play()
			return


func ui(name: String, db: float = 0.0, pitch: float = 1.0) -> void:
	if not enabled or not streams.has(name):
		return
	for p in pool_ui:
		if not p.playing:
			p.stream = streams[name]
			p.volume_db = db + _db(sound_volume)
			p.pitch_scale = pitch
			p.play()
			return


func play_music(in_match: bool) -> void:
	if not streams.has("theme"):
		return
	var db := (MUSIC_MATCH_DB if in_match else MUSIC_TITLE_DB) + _db(music_volume)
	if not music.playing or music.stream != streams["theme"]:
		music.stream = streams["theme"]
		music.play()
	music.volume_db = db


func stop_music() -> void:
	music.stop()


func play_ambience(on: bool) -> void:
	if not streams.has("ambience"):
		return
	if on and not ambience.playing:
		ambience.stream = streams["ambience"]
		ambience.play()
	elif not on:
		ambience.stop()
	ambience.volume_db = AMBIENCE_DB + _db(sound_volume)


func apply_volumes() -> void:
	## After the sliders move: music and ambience are already playing.
	if music.playing:
		music.volume_db = (MUSIC_MATCH_DB if get_parent().playing else MUSIC_TITLE_DB) + _db(music_volume)
	if ambience.playing:
		ambience.volume_db = AMBIENCE_DB + _db(sound_volume)
	if music_volume <= 0.001:
		music.stop()
	elif not music.playing and streams.has("theme"):
		play_music(get_parent().playing)
