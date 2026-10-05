extends StaticBody3D
## A castle's breakable door. Blocks the enemy team only (your own team walks
## through), breaks after enough hits, and rebuilds itself a while later once
## no enemy is left inside the castle.

const Stats = preload("res://scripts/stats.gd")

var game
var team := 0
var hp := Stats.GATE_HITS
var broken := false
var rebuild_timer := 0.0
var size := Vector3(0.8, 3.0, Stats.DOOR_HALF * 2.0)

var shape: CollisionShape3D
var wall: MeshInstance3D
var wall_mat: StandardMaterial3D
var rubble: MeshInstance3D
var label: Label3D
var base_color := Color(0.45, 0.3, 0.18)


func setup(p_game, p_team: int, x: float) -> void:
	game = p_game
	team = p_team
	position = Vector3(x, size.y / 2.0, 0)
	# Layer 3 is the elf door, layer 4 the human door. Units and shots only
	# collide with the enemy team's door.
	collision_layer = 4 if team == 0 else 8
	collision_mask = 0

	shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	add_child(shape)

	wall = MeshInstance3D.new()
	var wall_mesh := BoxMesh.new()
	wall_mesh.size = size
	wall.mesh = wall_mesh
	wall_mat = StandardMaterial3D.new()
	wall_mat.albedo_color = base_color
	wall.material_override = wall_mat
	add_child(wall)

	# Vertical planks so it reads as a wooden door.
	for i in 4:
		var plank := MeshInstance3D.new()
		var plank_mesh := BoxMesh.new()
		plank_mesh.size = Vector3(size.x + 0.1, size.y, 0.15)
		plank.mesh = plank_mesh
		plank.position.z = -size.z / 2.0 + (i + 0.5) * size.z / 4.0
		var plank_mat := StandardMaterial3D.new()
		plank_mat.albedo_texture = load("res://assets/textures/wood_color.jpg")
		plank_mat.normal_enabled = true
		plank_mat.normal_texture = load("res://assets/textures/wood_normal.jpg")
		plank_mat.albedo_color = Color(0.9, 0.75, 0.55)
		plank_mat.uv1_triplanar = true
		plank_mat.uv1_world_triplanar = true
		plank_mat.uv1_scale = Vector3.ONE * 0.6
		plank.material_override = plank_mat
		wall.add_child(plank)

	rubble = MeshInstance3D.new()
	var rubble_mesh := BoxMesh.new()
	rubble_mesh.size = Vector3(1.4, 0.3, size.z)
	rubble.mesh = rubble_mesh
	rubble.position.y = -size.y / 2.0 + 0.15
	var rubble_mat := StandardMaterial3D.new()
	rubble_mat.albedo_color = base_color.darkened(0.5)
	rubble.material_override = rubble_mat
	rubble.visible = false
	add_child(rubble)

	label = Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 32
	label.pixel_size = 0.012
	label.outline_size = 8
	label.position.y = size.y / 2.0 + 1.8
	add_child(label)
	_refresh()


func is_intact() -> bool:
	return not broken


func take_hit(amount: int, attacker = null) -> void:
	if broken:
		return
	hp = maxi(hp - amount, 0)
	if attacker:
		attacker.gain_xp(Stats.XP_GATE * amount)
	var hit_side := 1.0 if team == 0 else -1.0
	var where := global_position + Vector3(hit_side * 0.6, 0, randf_range(-size.z * 0.4, size.z * 0.4))
	game.spawn_splash(where, Color(0.75, 0.55, 0.3), 8, 3.0, 0.5)
	if hp == 0:
		broken = true
		rebuild_timer = Stats.GATE_REBUILD_TIME
		shape.disabled = true
		game.announce("The %s door has been broken!" % Stats.FACTIONS[team].name)
		game._banter(1 - team, "gate_down")
		game.spawn_splash(global_position, Color(0.7, 0.5, 0.28), 60, 7.0, 1.0)
		game.spawn_splash(global_position + Vector3(0, 1, 0), Color(0.5, 0.45, 0.4), 30, 3.0, 1.4, true)
		game.shake_at(global_position, 0.8)
	_refresh()


func _refresh() -> void:
	wall.visible = not broken
	rubble.visible = broken
	if broken:
		label.text = "Door broken: rebuilding in %d" % ceili(rebuild_timer)
		label.modulate = Color(1, 0.5, 0.4)
	else:
		label.text = "Door %d / %d" % [hp, Stats.GATE_HITS]
		label.modulate = Color(1, 1, 1)
		wall_mat.albedo_color = base_color.darkened(0.5 * (1.0 - float(hp) / Stats.GATE_HITS))


func _process(delta: float) -> void:
	if not broken:
		return
	# A defender standing by the door speeds the rebuild (the interact bonus).
	rebuild_timer -= delta * (1.0 + Stats.DEFENDER.interact if game.defender_near(team, global_position, 4.0) else 1.0)
	if rebuild_timer <= 0.0 and not game.enemy_inside_castle(team):
		broken = false
		hp = Stats.GATE_HITS
		shape.disabled = false
		game.announce("The %s door has been rebuilt." % Stats.FACTIONS[team].name)
	_refresh()
