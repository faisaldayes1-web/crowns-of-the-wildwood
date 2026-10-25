extends SceneTree
## Agent: Codex-faisal. Regression for shared couch positional audio.

class Seats extends Node3D:
	var couch_active := true
	var panes: Array = []

var failures := 0
var checks := 0

func _init() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("PASS " if ok else "FAIL ") + label)

func event(sound, pos: Vector3) -> Array:
	for voice in sound.pool_3d:
		voice.stop()
	sound._last.clear()
	sound.play("arrow_hit", pos, 0.0, 0.0)
	return sound.pool_3d.filter(func(voice): return voice.playing)

func _run() -> void:
	var seats := Seats.new()
	root.add_child(seats)
	var sound = load("res://scripts/sfx.gd").new()
	seats.add_child(sound)
	sound.set_process(false)
	sound.set_listener(Vector3.ZERO)
	for pos in [Vector3.ZERO, Vector3(80, 0, 0), Vector3(-80, 0, 0), Vector3(0, 0, 80)]:
		var unit := Node3D.new()
		seats.add_child(unit)
		unit.position = pos
		seats.panes.append({"unit": unit})
	check(sound.streams.has("arrow_hit"), "real impact clip loaded")
	for i in range(4):
		var pos: Vector3 = seats.panes[i].unit.position + Vector3(2, 0, 0)
		var voices := event(sound, pos)
		check(voices.size() == 1, "seat %d nearby impact starts exactly once" % (i + 1))
		if voices.size() == 1:
			check(voices[0].global_position.is_equal_approx(Vector3(2, 0, 0)), "seat %d preserves relative direction and distance" % (i + 1))
	check(event(sound, Vector3(200, 0, 200)).is_empty(), "far from every seat remains culled")
	seats.panes[1].unit.position = Vector3(5, 0, 0)
	check(event(sound, Vector3(3, 0, 0)).size() == 1, "overlapping listeners do not double the sound")
	seats.panes[1].unit.position = Vector3(80, 0, 0)
	seats.couch_active = false
	check(event(sound, Vector3(82, 0, 0)).is_empty(), "solo ignores inactive couch seats")
	check(event(sound, Vector3(2, 0, 0)).size() == 1, "solo near impact unchanged")
	seats.couch_active = true
	seats.panes[1].unit.free()
	check(event(sound, Vector3(82, 0, 0)).is_empty(), "removed seat safely ignored")
	seats.panes.clear()
	check(event(sound, Vector3(2, 0, 0)).size() == 1, "empty panes fall back to primary listener")
	sound.enabled = false
	check(event(sound, Vector3(2, 0, 0)).is_empty(), "disabled sound remains muted")
	await lifecycle(seats, sound)
	check(checks == 29, "all positional and lifecycle checks completed")
	print("COUCH AUDIO: %d checks, %d failures" % [checks, failures])
	seats.free()
	quit(1 if failures else 0)


func pane_view(seats, audio_enabled: bool = false) -> SubViewport:
	var view := SubViewport.new()
	view.audio_listener_enable_3d = audio_enabled
	seats.add_child(view)
	var camera := Camera3D.new()
	view.add_child(camera)
	camera.make_current()
	return view


func lifecycle(seats, sound) -> void:
	# Agent: Codex-faisal/crowns_bugtest. These are lifecycle checks; actual
	# audible output is qualified separately by the exported SFX-bus capture.
	var first := pane_view(seats)
	var second := pane_view(seats)
	seats.panes = [{"view": first}, {"view": second}]
	seats.couch_active = true
	sound.set_listener(Vector3(12, 3, -5))
	var proxy = current_listener(first)
	check(is_instance_valid(proxy) and proxy.get_parent() == first, "proxy belongs to first active pane viewport")
	check(first.audio_listener_enable_3d and not second.audio_listener_enable_3d, "only selected pane gains audio")
	check(is_instance_valid(proxy) and proxy.global_transform.is_equal_approx(sound.listener.global_transform), "proxy starts at primary listener transform")
	sound.listener.rotation = Vector3(0.1, 0.4, 0.0)
	sound.set_listener(Vector3(-9, 2, 7))
	check(is_instance_valid(proxy) and proxy.global_transform.is_equal_approx(sound.listener.global_transform), "proxy synchronizes moved and rotated listener")
	seats.couch_active = false
	sound.set_listener(Vector3.ZERO)
	check(not first.audio_listener_enable_3d and not second.audio_listener_enable_3d, "couch to solo restores original disabled flags")
	check(sound.listener.is_current(), "root listener remains current for solo")
	await process_frame
	check(not is_instance_valid(proxy), "solo transition disposes pane proxy")
	seats.couch_active = true
	sound.set_listener(Vector3.ZERO)
	first.free()
	sound.set_listener(Vector3.ZERO)
	check(second.audio_listener_enable_3d and is_instance_valid(current_listener(second)), "deleted viewport falls back to next valid pane")
	var replacement := pane_view(seats, true)
	seats.panes = [{"view": replacement}, {"view": second}]
	sound.set_listener(Vector3.ZERO)
	check(not second.audio_listener_enable_3d and replacement.audio_listener_enable_3d, "replacement restores old pane and enables new pane")
	proxy = current_listener(replacement)
	seats.couch_active = false
	sound.set_listener(Vector3.ZERO)
	check(replacement.audio_listener_enable_3d, "cleanup preserves originally enabled audio flag")
	await process_frame
	check(not is_instance_valid(proxy), "replacement proxy is disposed after leaving couch")
	seats.couch_active = true
	seats.panes = [{"view": second}]
	sound.set_listener(Vector3.ZERO)
	proxy = current_listener(second)
	sound.free()
	check(not second.audio_listener_enable_3d, "SFX exit restores surviving pane audio flag")
	await process_frame
	check(not is_instance_valid(proxy), "SFX exit disposes proxy outside its own subtree")


func current_listener(view: SubViewport):
	for child in view.get_children():
		if child is AudioListener3D and child.is_current() and not child.is_queued_for_deletion():
			return child
	return null
