extends StaticBody3D
## A castle's breakable gate. Blocks the enemy team only (your own team walks
## through), breaks after enough gate damage, and rebuilds itself a while later.

const Stats = preload("res://scripts/stats.gd")
const SIZE := Vector3(0.8, 3.0, 13.0)
const HALF_OPENING := 6.5

var game
var team := 0
var hp := Stats.GATE_HITS
var broken := false
var rebuild_timer := 0.0

var shape: CollisionShape3D
var wall: MeshInstance3D
var wall_mat: StandardMaterial3D
var rubble: MeshInstance3D
var label: Label3D
var base_color := Color(0.45, 0.3, 0.18)


func setup(p_game, p_team: int, x: float) -> void:
	game = p_game
	team = p_team
	position = Vector3(x, SIZE.y / 2.0, 0)
	# Layer 3 is the elf gate, layer 4 the human gate. Units only collide with
	# the enemy team's gate.
	collision_layer = 4 if team == 0 else 8
	collision_mask = 0

	shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = SIZE
	shape.shape = box
	add_child(shape)

	wall = MeshInstance3D.new()
	var wall_mesh := BoxMesh.new()
	wall_mesh.size = SIZE
	wall.mesh = wall_mesh
	wall_mat = StandardMaterial3D.new()
	wall_mat.albedo_color = base_color
	wall.material_override = wall_mat
	add_child(wall)

	# Vertical planks so it reads as a wooden gate.
	for i in 7:
		var plank := MeshInstance3D.new()
		var plank_mesh := BoxMesh.new()
		plank_mesh.size = Vector3(SIZE.x + 0.1, SIZE.y, 0.15)
		plank.mesh = plank_mesh
		plank.position.z = -5.4 + i * 1.8
		var plank_mat := StandardMaterial3D.new()
		plank_mat.albedo_color = base_color.darkened(0.35)
		plank.material_override = plank_mat
		wall.add_child(plank)

	rubble = MeshInstance3D.new()
	var rubble_mesh := BoxMesh.new()
	rubble_mesh.size = Vector3(1.4, 0.3, SIZE.z)
	rubble.mesh = rubble_mesh
	rubble.position.y = -SIZE.y / 2.0 + 0.15
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
	label.position.y = SIZE.y / 2.0 + 0.8
	add_child(label)
	_refresh()


func is_intact() -> bool:
	return not broken


func take_hit(amount: int) -> void:
	if broken:
		return
	hp = maxi(hp - amount, 0)
	if hp == 0:
		broken = true
		rebuild_timer = Stats.GATE_REBUILD_TIME
		shape.disabled = true
		game.announce("The %s gate has been broken!" % Stats.FACTIONS[team].name)
	_refresh()


func _refresh() -> void:
	wall.visible = not broken
	rubble.visible = broken
	if broken:
		label.text = "Gate broken: rebuilding in %d" % ceili(rebuild_timer)
		label.modulate = Color(1, 0.5, 0.4)
	else:
		label.text = "Gate %d / %d" % [hp, Stats.GATE_HITS]
		label.modulate = Color(1, 1, 1)
		wall_mat.albedo_color = base_color.darkened(0.5 * (1.0 - float(hp) / Stats.GATE_HITS))


func _blocked_by_enemy() -> bool:
	for u in game.units:
		if u.team != team and not u.dead and absf(u.global_position.x - position.x) < 1.2 \
				and absf(u.global_position.z) < HALF_OPENING + 0.5:
			return true
	return false


func _process(delta: float) -> void:
	if not broken:
		return
	rebuild_timer -= delta
	if rebuild_timer <= 0.0 and not _blocked_by_enemy():
		broken = false
		hp = Stats.GATE_HITS
		shape.disabled = false
		game.announce("The %s gate has been rebuilt." % Stats.FACTIONS[team].name)
	_refresh()
