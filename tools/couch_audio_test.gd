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
	print("COUCH AUDIO: %d checks, %d failures" % [checks, failures])
	seats.free()
	quit(1 if failures else 0)
