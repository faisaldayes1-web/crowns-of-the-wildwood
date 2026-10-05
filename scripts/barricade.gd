class_name Barricade
extends StaticBody3D
## A breakable wooden fence or barrier: cover that attackers can smash
## through. It takes a few hits, splinters and falls, and the defenders'
## castle rebuilds it a while later. Shots and swings from both sides stop
## at it; only the enemy team can break it.

const Stats = preload("res://scripts/stats.gd")

var game
var team := 0
var hp := Stats.BARRICADE_HITS
var rebuild_timer := 0.0
var visual: Node3D
var shape: CollisionShape3D
var base_rot := 0.0


func setup(p_game, p_team: int, pos: Vector3, length: float, rot_y: float, prop: String) -> void:
	game = p_game
	team = p_team
	position = pos
	rotation.y = rot_y
	base_rot = rot_y
	collision_layer = 1
	collision_mask = 0
	shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(length, 1.2, 0.5)
	shape.shape = box
	shape.position = Vector3(0, 0.6, 0)
	add_child(shape)
	visual = Node3D.new()
	add_child(visual)
	var scene: PackedScene = load("res://assets/props/%s.gltf" % prop)
	var n := maxi(int(length / 1.75), 1)
	for i in n:
		var inst: Node3D = scene.instantiate()
		inst.position = Vector3(-length / 2.0 + (i + 0.5) * (length / n), 0, 0)
		inst.scale = Vector3.ONE * 3.5
		visual.add_child(inst)


func is_intact() -> bool:
	return hp > 0


func take_hit(amount: int, attacker = null) -> void:
	if hp <= 0:
		return
	hp = maxi(hp - amount, 0)
	game.spawn_splash(global_position + Vector3(0, 0.8, 0), Color(0.75, 0.55, 0.3), 8, 3.0, 0.4)
	# Each hit knocks it a little more askew.
	visual.rotation.z = (1.0 - float(hp) / Stats.BARRICADE_HITS) * 0.18
	if hp == 0:
		shape.disabled = true
		rebuild_timer = Stats.BARRICADE_REBUILD
		game.spawn_splash(global_position + Vector3(0, 0.6, 0), Color(0.6, 0.42, 0.22), 18, 4.0, 0.7)
		game.shake_at(global_position, 0.25)
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(visual, "rotation:x", 1.35, 0.5).set_ease(Tween.EASE_IN)
		tw.tween_property(visual, "position:y", -0.1, 0.5)
		if attacker and attacker.is_player:
			game.toast("Fence smashed", Color(1.0, 0.8, 0.5))


func _process(delta: float) -> void:
	if hp > 0:
		return
	rebuild_timer -= delta
	if rebuild_timer <= 0.0 and not game.enemy_inside_castle(team):
		hp = Stats.BARRICADE_HITS
		shape.disabled = false
		visual.rotation = Vector3.ZERO
		visual.position = Vector3.ZERO
		game.spawn_ring(global_position, 1.5, Color(0.9, 0.8, 0.5), 0.5)
