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


func setup(p_game, p_team: int, pos: Vector3, length: float, rot_y: float) -> void:
	game = p_game
	team = p_team
	position = pos
	rotation.y = rot_y
	base_rot = rot_y
	collision_layer = 1
	collision_mask = 0
	shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(length, 1.1, 0.4)
	shape.shape = box
	shape.position = Vector3(0, 0.55, 0)
	add_child(shape)
	visual = Node3D.new()
	add_child(visual)
	build_fence(visual, length, game._timber(), game._timber(Color(0.7, 0.6, 0.5)))


static func build_fence(parent: Node3D, length: float, wood: Material, dark: Material) -> void:
	## A timber fence along local x: square posts with two rails, the same
	## piece everywhere in the game so fences always match the castles.
	var n := maxi(int(round(length / 1.2)), 1)
	for i in n + 1:
		var post := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.16, 1.1, 0.16)
		post.mesh = pm
		post.position = Vector3(-length / 2.0 + i * (length / n), 0.55, 0)
		post.material_override = dark
		parent.add_child(post)
		var cap := MeshInstance3D.new()
		var cm := BoxMesh.new()
		cm.size = Vector3(0.22, 0.08, 0.22)
		cap.mesh = cm
		cap.position = post.position + Vector3(0, 0.57, 0)
		cap.material_override = dark
		parent.add_child(cap)
	for y in [0.45, 0.85]:
		var rail := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(length, 0.1, 0.08)
		rail.mesh = rm
		rail.position = Vector3(0, y, 0)
		rail.material_override = wood
		parent.add_child(rail)


func is_intact() -> bool:
	return hp > 0


func take_hit(amount: int, attacker = null) -> void:
	if hp <= 0:
		return
	hp = maxi(hp - amount, 0)
	game.spawn_splash(global_position + Vector3(0, 0.8, 0), Color(0.75, 0.55, 0.3), 8, 3.0, 0.4)
	# Each hit knocks it a little more askew.
	visual.rotation.z = (1.0 - float(hp) / Stats.BARRICADE_HITS) * 0.18
	game.sfx.play("barricade", global_position, -3.0, 0.15)
	if hp == 0:
		game.sfx.play("door_break", global_position, -8.0, 0.2)
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
	if hp > 0 or game.net_client:
		return
	rebuild_timer -= delta
	if rebuild_timer <= 0.0 and not game.enemy_inside_castle(team):
		hp = Stats.BARRICADE_HITS
		shape.disabled = false
		visual.rotation = Vector3.ZERO
		visual.position = Vector3.ZERO
		game.spawn_ring(global_position, 1.5, Color(0.9, 0.8, 0.5), 0.5)
