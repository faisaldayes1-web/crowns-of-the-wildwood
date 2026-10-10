extends Node
## All sound in the game. Every clip is synthesized by tools/make_sounds.py
## (nothing sampled), loaded from assets/sfx/. play() is positional: it fades
## with distance from the listener, which sits on the local player. ui() is
## for menus, fanfares and anything the player should always hear.
##
## Music (tools/make_music.py, assets/music/) plays on its own "Music" bus,
## which ducks under the "SFX" bus. The match loop is three synced stems:
## the drums come in while your door is under attack, the tension layer
## while your crown is out of its vault. Menu and match music crossfade.

const DIR := "res://assets/sfx/"
const POOL_3D := 28
const POOL_UI := 8
const HEAR_RANGE := 48.0     # metres: beyond this a positional sound is skipped
const MUSIC_MATCH_DB := -11.0
const MUSIC_TITLE_DB := -5.0
const AMBIENCE_DB := -9.0
const MUSIC_DIR := "res://assets/music/"
const BATTLE_STEMS := ["battle_base", "battle_drums", "battle_tension"]
const STINGS := ["match_start", "crown_captured", "crown_lost", "victory", "defeat"]
const STING_DB := -4.0
const CROSSFADE := 1.6       # seconds for menu <-> match
const LAYER_FADE := 1.2      # seconds for a battle stem to come in or out
const DOOR_ALARM := 6.0      # seconds the drums stay after your door takes a hit
const Monarch = preload("res://scripts/monarch.gd")

var streams := {}
var pool_3d: Array = []
var pool_ui: Array = []
var listener: AudioListener3D
var music: AudioStreamPlayer          # title / menus theme
var battle: AudioStreamPlayer         # the synced battle stems
var sting_player: AudioStreamPlayer
var battle_stream: AudioStreamSynchronized
var music_mode := ""                  # "menu", "match" or "" (silent)
var _fade := {"menu": 0.0, "match": 0.0}
var _layers := [1.0, 0.0, 0.0]        # current gain of each battle stem
var _duck := 1.0                      # dips while a stinger plays
var _sting_until := 0.0
var _gate_hp := -1
var _door_alarm_until := 0.0
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
			# Exported builds list the imported clips as "name.wav.import".
			if f.ends_with(".wav") or f.ends_with(".wav.import"):
				var clip := f.trim_suffix(".import")
				streams[clip.trim_suffix(".wav")] = load(DIR + clip)
			f = d.get_next()
	for i in POOL_3D:
		var p := AudioStreamPlayer3D.new()
		p.unit_size = 14.0
		p.max_distance = HEAR_RANGE
		p.max_db = 3.0
		p.attenuation_filter_cutoff_hz = 9000
		p.bus = "SFX"
		add_child(p)
		pool_3d.append(p)
	for i in POOL_UI:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		pool_ui.append(p)
	_setup_buses()
	music = _music_player("menu")
	if music.stream:
		music.stream.loop = true
	battle_stream = AudioStreamSynchronized.new()
	battle_stream.stream_count = BATTLE_STEMS.size()
	for i in BATTLE_STEMS.size():
		var st = _music_stream(BATTLE_STEMS[i])
		if st:
			st.loop = true
		battle_stream.set_sync_stream(i, st)
		battle_stream.set_sync_stream_volume(i, 0.0 if i == 0 else -60.0)
	battle = _music_player("")
	battle.stream = battle_stream
	sting_player = _music_player("")
	ambience = AudioStreamPlayer.new()
	ambience.bus = "SFX"
	add_child(ambience)
	listener = AudioListener3D.new()
	add_child(listener)
	listener.make_current()
	for name in ["ambience"]:
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


func _setup_buses() -> void:
	## "SFX" and "Music" buses under Master; music ducks when effects are loud.
	for name in ["SFX", "Music"]:
		if AudioServer.get_bus_index(name) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, name)
			AudioServer.set_bus_send(i, "Master")
	var mi := AudioServer.get_bus_index("Music")
	if AudioServer.get_bus_effect_count(mi) == 0:
		var duck := AudioEffectCompressor.new()
		duck.sidechain = "SFX"
		duck.threshold = -22.0
		duck.ratio = 3.0
		duck.attack_us = 8000.0
		duck.release_ms = 350.0
		AudioServer.add_bus_effect(mi, duck)


func _music_stream(name: String) -> AudioStream:
	var path := MUSIC_DIR + name + ".ogg"
	return load(path) if ResourceLoader.exists(path) else null


func _music_player(name: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	if OS.has_feature("web"):
		# Web defaults to sample playback, which cannot play the layered battle
		# stream (AudioStreamSynchronized): it stayed silent in Safari and Chrome.
		p.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	p.bus = "Music"
	if name != "":
		p.stream = _music_stream(name)
	add_child(p)
	return p


func play_music(in_match: bool) -> void:
	## Crossfades to the match loop or the menu theme (_process does the fade).
	var mode := "match" if in_match else "menu"
	if mode == music_mode:
		return
	music_mode = mode
	if in_match:
		_layers = [1.0, 0.0, 0.0]
		_gate_hp = -1
		_door_alarm_until = 0.0
		if battle_stream.get_sync_stream(0):
			battle.stream_paused = false
			battle.play()
	elif music.stream:
		music.stream_paused = false
		music.play()


func stop_music() -> void:
	## Fades whatever music is playing out.
	music_mode = ""


func sting(name: String, fallback: String = "", final: bool = false) -> void:
	## A short music cue (match start, crown captured or lost, victory,
	## defeat). The loop dips under it; a final sting ends the match music.
	## With music muted the old effect clip plays instead.
	var st := _music_stream("sting_" + name)
	if st == null or music_volume <= 0.001 or not enabled:
		if fallback != "":
			ui(fallback)
		return
	if final:
		music_mode = ""
	sting_player.stream = st
	sting_player.volume_db = STING_DB + _db(music_volume)
	sting_player.play()
	_sting_until = _now() + st.get_length()


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _danger() -> int:
	## 2 while the player's crown is out of its vault, 1 while their door is
	## under attack or enemies are inside their castle, else 0.
	var game = get_parent()
	if not ("monarchs" in game) or game.monarchs.size() < 2 or game.gates.size() < 2:
		return 0
	var team: int = game.player_team
	if game.monarchs[team].state != Monarch.State.HOME:
		return 2
	var gate = game.gates[team]
	if _gate_hp >= 0 and gate.hp < _gate_hp:
		_door_alarm_until = _now() + DOOR_ALARM
	_gate_hp = gate.hp
	if _now() < _door_alarm_until or game.enemy_inside_castle(team):
		return 1
	return 0


func _process(delta: float) -> void:
	var game = get_parent()
	var in_match: bool = music_mode == "match" and game.get("playing") == true
	var danger := _danger() if in_match else 0
	var step := delta / CROSSFADE
	for mode in _fade:
		_fade[mode] = move_toward(_fade[mode], 1.0 if music_mode == mode else 0.0, step)
	for i in 3:
		var want := 1.0 if i == 0 or danger >= i else 0.0
		_layers[i] = move_toward(_layers[i], want, delta / LAYER_FADE)
		battle_stream.set_sync_stream_volume(i, _db(_layers[i]))
	var ducking := _now() < _sting_until - 0.4
	_duck = move_toward(_duck, 0.3 if ducking else 1.0, delta / (0.15 if ducking else 1.0))
	var muted := music_volume <= 0.001
	_drive(music, _fade["menu"], MUSIC_TITLE_DB, muted)
	_drive(battle, _fade["match"], MUSIC_MATCH_DB, muted)
	if sting_player.playing:
		sting_player.volume_db = STING_DB + _db(music_volume)


func _drive(p: AudioStreamPlayer, fade: float, base_db: float, muted: bool) -> void:
	## Sets a music player's level; parks it once faded out or muted.
	p.volume_db = base_db + _db(fade * _duck * music_volume)
	var silent := muted or fade <= 0.0
	if p.stream_paused != silent:
		p.stream_paused = silent


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
	## After the sliders move. Music levels follow music_volume every frame
	## (_process), so only the ambience needs setting here.
	if ambience.playing:
		ambience.volume_db = AMBIENCE_DB + _db(sound_volume)
