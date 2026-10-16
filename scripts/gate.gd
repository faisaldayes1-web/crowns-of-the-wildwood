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
# An overhead health bar instead of a number (Faisal 08:21): a dark frame,
# a dark track and a fill that shrinks from the right, green to red.
var bar_fill: MeshInstance3D
var bar_fill_mesh: QuadMesh
var bar_fill_mat: StandardMaterial3D
var bar_nodes: Array = []
const BAR_W := 2.6
const BAR_H := 0.26
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

	# A double door of vertical planks with iron bands and a centre seam.
	var plank_mat := StandardMaterial3D.new()
	plank_mat.albedo_texture = load("res://assets/textures/wood_color.jpg")
	plank_mat.normal_enabled = true
	plank_mat.normal_texture = load("res://assets/textures/wood_normal.jpg")
	plank_mat.albedo_color = Color(0.95, 0.85, 0.72)
	plank_mat.uv1_triplanar = true
	plank_mat.uv1_world_triplanar = true
	plank_mat.uv1_scale = Vector3.ONE * 0.5
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.24, 0.25, 0.28)
	iron.metallic = 0.6
	iron.roughness = 0.5
	var n := 10
	for i in n:
		var plank := MeshInstance3D.new()
		var plank_mesh := BoxMesh.new()
		plank_mesh.size = Vector3(size.x + 0.1, size.y - 0.1, size.z / n - 0.06)
		plank.mesh = plank_mesh
		plank.position.z = -size.z / 2.0 + (i + 0.5) * size.z / n
		plank.material_override = plank_mat
		wall.add_child(plank)
	for y in [-0.9, 0.0, 0.9]:
		var band := MeshInstance3D.new()
		var band_mesh := BoxMesh.new()
		band_mesh.size = Vector3(size.x + 0.18, 0.16, size.z - 0.1)
		band.mesh = band_mesh
		band.position.y = y
		band.material_override = iron
		wall.add_child(band)
	var seam := MeshInstance3D.new()
	var seam_mesh := BoxMesh.new()
	seam_mesh.size = Vector3(size.x + 0.12, size.y, 0.06)
	seam.mesh = seam_mesh
	seam.material_override = iron
	wall.add_child(seam)

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
	label.pixel_size = 0.0095
	label.outline_size = 12
	label.outline_modulate = Color(0.08, 0.06, 0.04)
	label.position.y = size.y / 2.0 + 1.8
	add_child(label)
	var bar_y: float = size.y / 2.0 + 1.8
	_bar_quad(Vector2(BAR_W + 0.12, BAR_H + 0.12), Color(0.08, 0.06, 0.04), 10, bar_y)
	_bar_quad(Vector2(BAR_W, BAR_H), Color(0.22, 0.12, 0.1), 11, bar_y)
	bar_fill = _bar_quad(Vector2(BAR_W, BAR_H), Color(0.3, 0.85, 0.3), 12, bar_y)
	bar_fill_mesh = bar_fill.mesh
	bar_fill_mat = bar_fill.material_override
	_refresh()


func is_intact() -> bool:
	return not broken


func take_hit(amount: int, attacker = null) -> void:
	if broken:
		return
	hp = maxi(hp - amount, 0)
	if attacker:
		attacker.gain_xp(Stats.XP_GATE * amount, "siege")
	var hit_side := 1.0 if team == 0 else -1.0
	var where := global_position + Vector3(hit_side * 0.6, 0, randf_range(-size.z * 0.4, size.z * 0.4))
	game.spawn_splash(where, Color(0.75, 0.55, 0.3), 8, 3.0, 0.5)
	game.sfx.play("door_hit", where, -3.0, 0.15)
	if hp == 0:
		broken = true
		game.sfx.play("door_break", global_position, 4.0)
		rebuild_timer = Stats.GATE_REBUILD_TIME
		shape.disabled = true
		game.announce("The %s door has been broken!" % Stats.FACTIONS[team].name)
		if game.demo:
			print("Door broken: %s t=%d" % [Stats.FACTIONS[team].name, game.match_clock()])
		game._banter(1 - team, "gate_down")
		game.spawn_splash(global_position, Color(0.7, 0.5, 0.28), 60, 7.0, 1.0)
		game.spawn_splash(global_position + Vector3(0, 1, 0), Color(0.5, 0.45, 0.4), 30, 3.0, 1.4, true)
		game.shake_at(global_position, 0.8)
	_refresh()


func collapse() -> void:
	## Overtime: the door comes down for good.
	if not broken:
		take_hit(hp)
	rebuild_timer = INF
	_refresh()


func _bar_quad(sz: Vector2, col: Color, prio: int, y: float) -> MeshInstance3D:
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = sz
	q.mesh = qm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.no_depth_test = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.render_priority = prio
	m.albedo_color = col
	q.material_override = m
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	q.position.y = y
	add_child(q)
	bar_nodes.append(q)
	return q


func _refresh() -> void:
	wall.visible = not broken
	for q in bar_nodes:
		q.visible = not broken
	rubble.visible = broken
	if broken and rebuild_timer == INF:
		label.text = "Door down for overtime"
		label.modulate = Color(1, 0.5, 0.4)
	elif broken:
		var pressed: bool = game.enemy_inside_castle(team) or game.enemies_near(team, global_position, Stats.GATE_SIEGE_RADIUS) > 0
		label.text = ("Door broken: under siege (%d)" if pressed else "Door broken: rebuilding in %d") % ceili(rebuild_timer)
		label.modulate = Color(1, 0.35, 0.3) if pressed else Color(1, 0.5, 0.4)
	else:
		label.text = ""
		var f: float = clampf(float(hp) / Stats.GATE_HITS, 0.0, 1.0)
		bar_fill_mesh.size.x = maxf(BAR_W * f, 0.001)
		bar_fill_mesh.center_offset.x = -BAR_W * (1.0 - f) / 2.0
		bar_fill_mat.albedo_color = Color(0.9, 0.25, 0.2).lerp(Color(0.3, 0.85, 0.3), f)
		wall_mat.albedo_color = base_color.darkened(0.5 * (1.0 - float(hp) / Stats.GATE_HITS))


func _process(delta: float) -> void:
	if game.net_client:
		return   # online: the host rebuilds doors
	if not broken:
		return
	# A siege holds the breach: the rebuild only counts down while no enemy is
	# inside the castle or pressing the doorway. A defender standing by the
	# door speeds it (the interact bonus).
	var pressed: bool = game.enemy_inside_castle(team) or game.enemies_near(team, global_position, Stats.GATE_SIEGE_RADIUS) > 0
	if not pressed:
		rebuild_timer -= delta * (1.0 + Stats.DEFENDER.interact if game.defender_near(team, global_position, 4.0) else 1.0)
	if rebuild_timer <= 0.0 and not game.enemy_inside_castle(team):
		broken = false
		hp = Stats.GATE_HITS
		shape.disabled = false
		game.sfx.play("door_rebuilt", global_position, 0.0)
		game.announce("The %s door has been rebuilt." % Stats.FACTIONS[team].name)
	_refresh()
