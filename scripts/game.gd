extends Node3D
## Milestone 1 match: builds the valley map, spawns both teams and runs the
## capture-the-monarch rules. Everything is built in code from simple shapes,
## so it can be swapped for real art later without changing the rules.

const Unit = preload("res://scripts/unit.gd")
const Monarch = preload("res://scripts/monarch.gd")
const Arrow = preload("res://scripts/arrow.gd")

const TEAM_SIZE := 4
const CAPTURES_TO_WIN := 2
const CASTLE_X := 32.0
const CAPTURE_RADIUS := 3.0
const CLASS_SWITCH_RADIUS := 10.0
const CAMERA_OFFSET := Vector3(0, 17, 12)
const MONARCH_TITLES := ["Elf Queen", "Human King"]

var map_half := Vector2(44, 22)
var playing := false
var game_over := false
var player_team := 0
var score := [0, 0]
var thrones: Array[Vector3] = []
var monarchs: Array = []
var units: Array = []
var player

var camera: Camera3D
var score_label: Label
var message_label: Label
var banner: Label
var message_timer := 0.0
# Run with "-- --demo" to watch bots play each other (used for testing).
var demo := false


func _ready() -> void:
	randomize()
	_setup_input()
	_build_world()
	_build_hud()
	demo = "--demo" in OS.get_cmdline_user_args()
	if demo:
		_start_match(0)
		return
	banner.text = "CROWNS OF THE WILDWOOD\n\nPress 1 to play the Elves (fast, fragile)\nPress 2 to play the Humans (slow, tough)\n\nSteal the enemy monarch and carry them to your throne.\nFirst to %d captures wins." % CAPTURES_TO_WIN


func _process(delta: float) -> void:
	if not playing and not game_over:
		if Input.is_action_just_pressed("class_1"):
			_start_match(0)
		elif Input.is_action_just_pressed("class_2"):
			_start_match(1)
		return
	if game_over:
		if demo:
			print("Match over: Elves %d, Humans %d" % [score[0], score[1]])
			get_tree().quit()
		if Input.is_action_just_pressed("restart"):
			get_tree().reload_current_scene()
		return

	_check_rules()
	_update_camera(delta)
	if demo and Engine.get_process_frames() == 900:
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--shot="):
				get_viewport().get_texture().get_image().save_png(arg.trim_prefix("--shot="))
	if demo and Engine.get_process_frames() % 1800 == 0:
		print("t=%ds  score %d-%d  monarchs %s / %s" % [Engine.get_process_frames() / 60, score[0], score[1], monarchs[0].state, monarchs[1].state])
		for u in units:
			print("   team%d %s %s hp=%d dead=%s" % [u.team, u.role_name(), u.global_position.snapped(Vector3.ONE * 0.1), u.hp, u.dead])
	if message_timer > 0.0:
		message_timer -= delta
		if message_timer <= 0.0:
			message_label.text = ""


# --- Rules -----------------------------------------------------------------

func _check_rules() -> void:
	for m in monarchs:
		if m.state == Monarch.State.CARRIED:
			var carrier = m.carrier
			var to_throne: Vector3 = thrones[carrier.team] - carrier.global_position
			to_throne.y = 0.0
			if to_throne.length() < CAPTURE_RADIUS:
				_score_capture(carrier, m)
		elif m.state == Monarch.State.DROPPED:
			# A teammate touching a dropped monarch sends them straight home.
			for u in units:
				if u.team == m.team and not u.dead and _flat_dist(u.global_position, m.global_position) < 1.5:
					m.go_home()
					announce("The %s is safe again." % m.title)
					break


func _score_capture(carrier, m) -> void:
	carrier.carrying = null
	m.go_home()
	score[carrier.team] += 1
	_update_score()
	var team_name: String = Unit.FACTIONS[carrier.team].name
	if score[carrier.team] >= CAPTURES_TO_WIN:
		playing = false
		game_over = true
		var outcome := "VICTORY!" if carrier.team == player_team else "DEFEAT"
		banner.text = "%s\n\nThe %s win %d to %d.\n\nPress R or Enter to play again." % [outcome, team_name, score[carrier.team], score[1 - carrier.team]]
		banner.visible = true
	else:
		announce("The %s captured the %s!" % [team_name, m.title])
	print("Capture: %s  (score %d - %d)" % [team_name, score[0], score[1]])


func try_interact(u) -> void:
	if u.dead:
		return
	if u.carrying:
		drop_monarch(u)
		return
	var m = monarchs[1 - u.team]
	if m.state != Monarch.State.CARRIED and _flat_dist(u.global_position, m.global_position) < Unit.PICKUP_RANGE:
		m.pick_up(u)
		u.carrying = m
		announce("The %s has been taken by the %s!" % [m.title, Unit.FACTIONS[u.team].name])


func drop_monarch(u) -> void:
	var m = u.carrying
	if m == null:
		return
	u.carrying = null
	m.drop_at(u.global_position)


func try_switch_class(u, role: int) -> void:
	if u.carrying:
		return
	if _flat_dist(u.global_position, thrones[u.team]) > CLASS_SWITCH_RADIUS:
		announce("Switch class inside your own castle.")
		return
	u.set_role(role)
	announce("You are now a %s." % u.role_name())


func spawn_arrow(u, aim: Vector3) -> void:
	var arrow = Arrow.new()
	add_child(arrow)
	var stats: Dictionary = Unit.ROLE_STATS[u.role]
	arrow.setup(self, u.team, u.global_position, aim, stats.damage, stats.range)


func spawn_swing(u, aim: Vector3) -> void:
	var swing := MeshInstance3D.new()
	var slab := BoxMesh.new()
	slab.size = Vector3(1.6, 0.05, 0.7)
	swing.mesh = slab
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 1, 1, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	swing.material_override = mat
	add_child(swing)
	swing.global_position = u.global_position + aim * 1.1 + Vector3(0, 1.0, 0)
	swing.rotation.y = atan2(-aim.x, -aim.z)
	get_tree().create_timer(0.12).timeout.connect(swing.queue_free)


func announce(text: String) -> void:
	if message_label:
		message_label.text = text
		message_timer = 3.0


func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# --- Match setup -----------------------------------------------------------

func _start_match(team: int) -> void:
	player_team = team
	banner.visible = false
	var roles := [Unit.Role.MELEE, Unit.Role.RANGED, Unit.Role.WORKER, Unit.Role.MELEE]
	for t in 2:
		var side := -1.0 if t == 0 else 1.0
		for i in TEAM_SIZE:
			var u = Unit.new()
			add_child(u)
			var spawn := Vector3(side * (CASTLE_X + 4.0), 0.0, -4.5 + i * 3.0)
			var is_player := t == player_team and i == 0 and not demo
			u.setup(self, t, roles[i], is_player, spawn)
			u.bot_job = "defend" if i == 2 else "attack"
			units.append(u)
			if is_player or (demo and player == null):
				player = u
	camera.global_position = player.global_position + CAMERA_OFFSET
	playing = true
	_update_score()
	announce("WASD or left stick to move, Space to attack, E to grab or drop the monarch.")


func _update_camera(delta: float) -> void:
	if player == null:
		return
	var target: Vector3 = player.global_position + CAMERA_OFFSET
	camera.global_position = camera.global_position.lerp(target, clampf(delta * 5.0, 0.0, 1.0))


# --- World -----------------------------------------------------------------

func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	return mat


func _add_block(pos: Vector3, size: Vector3, color: Color, solid: bool) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _material(color)
	if solid:
		var body := StaticBody3D.new()
		body.position = pos
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		shape.shape = box_shape
		body.add_child(shape)
		body.add_child(mesh)
		add_child(body)
	else:
		mesh.position = pos
		add_child(mesh)


func _add_tree(pos: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.5
	cyl.height = 3.0
	shape.shape = cyl
	shape.position.y = 1.5
	body.add_child(shape)

	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.3
	trunk_mesh.bottom_radius = 0.4
	trunk_mesh.height = 1.6
	trunk.mesh = trunk_mesh
	trunk.position.y = 0.8
	trunk.material_override = _material(Color(0.4, 0.27, 0.15))
	body.add_child(trunk)

	var crown := MeshInstance3D.new()
	var crown_mesh := CylinderMesh.new()
	crown_mesh.top_radius = 0.0
	crown_mesh.bottom_radius = 1.4
	crown_mesh.height = 2.8
	crown.mesh = crown_mesh
	crown.position.y = 2.8
	crown.material_override = _material(Color(0.15, 0.45, 0.2))
	body.add_child(crown)
	add_child(body)


func _build_castle(team: int) -> void:
	var side := -1.0 if team == 0 else 1.0
	var color: Color = Unit.FACTIONS[team].color
	var wall_color := Color(0.45, 0.32, 0.2) if team == 0 else Color(0.6, 0.6, 0.62)
	var cx := side * CASTLE_X

	# Castle floor, back wall and two side walls. The open side faces the middle.
	_add_block(Vector3(cx + side * 1.0, 0.01, 0), Vector3(18, 0.02, 16), color.darkened(0.5), false)
	_add_block(Vector3(cx + side * 9.5, 1.5, 0), Vector3(1, 3, 18), wall_color, true)
	_add_block(Vector3(cx + side * 2.0, 1.5, -8.5), Vector3(16, 3, 1), wall_color, true)
	_add_block(Vector3(cx + side * 2.0, 1.5, 8.5), Vector3(16, 3, 1), wall_color, true)
	# Gate towers either side of the opening.
	_add_block(Vector3(cx - side * 6.5, 2.0, -7.5), Vector3(2, 4, 2), wall_color.darkened(0.2), true)
	_add_block(Vector3(cx - side * 6.5, 2.0, 7.5), Vector3(2, 4, 2), wall_color.darkened(0.2), true)

	# Throne on a dais. Carry the enemy monarch here to score.
	var throne := Vector3(cx, 0, 0)
	thrones.append(throne)
	_add_block(throne + Vector3(side * 1.5, 0.15, 0), Vector3(3, 0.3, 4), Color(0.75, 0.6, 0.25), false)
	_add_block(throne + Vector3(side * 2.4, 1.2, 0), Vector3(0.4, 2.0, 1.6), color.darkened(0.2), false)

	var ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = CAPTURE_RADIUS - 0.15
	ring_mesh.outer_radius = CAPTURE_RADIUS
	ring.mesh = ring_mesh
	ring.position = throne + Vector3(0, 0.05, 0)
	var ring_mat := _material(Color(1.0, 0.85, 0.3))
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = ring_mat
	add_child(ring)

	var m = Monarch.new()
	add_child(m)
	m.setup(team, throne, color, MONARCH_TITLES[team])
	monarchs.append(m)


func _build_world() -> void:
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.5, 0.7, 0.9)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.75, 0.78, 0.85)
	environment.ambient_light_energy = 0.6
	env.environment = environment
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.shadow_enabled = true
	add_child(sun)

	# Ground.
	_add_block(Vector3(0, -0.5, 0), Vector3(map_half.x * 2 + 80, 1, map_half.y * 2 + 60), Color(0.42, 0.62, 0.3), true)
	# A dirt road down the middle.
	_add_block(Vector3(0, 0.005, 0), Vector3(48, 0.01, 4), Color(0.6, 0.5, 0.35), false)

	_build_castle(0)
	_build_castle(1)

	# Mirrored groves in the contested middle, leaving the road clear.
	var grove := [Vector3(4, 0, 6), Vector3(9, 0, 10), Vector3(14, 0, 5), Vector3(6, 0, 15),
		Vector3(17, 0, 13), Vector3(20, 0, 7), Vector3(2, 0, 11), Vector3(12, 0, 17)]
	for p in grove:
		_add_tree(p)
		_add_tree(Vector3(-p.x, 0, -p.z))

	camera = Camera3D.new()
	camera.rotation_degrees = Vector3(-55, 0, 0)
	camera.fov = 55.0
	camera.position = Vector3(0, 40, 26)
	add_child(camera)
	camera.make_current()


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	score_label = Label.new()
	score_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.add_theme_font_size_override("font_size", 30)
	score_label.add_theme_constant_override("outline_size", 8)
	score_label.add_theme_color_override("font_outline_color", Color.BLACK)
	score_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	score_label.position.y = 12
	layer.add_child(score_label)

	message_label = Label.new()
	message_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	message_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	message_label.add_theme_font_size_override("font_size", 22)
	message_label.add_theme_constant_override("outline_size", 6)
	message_label.add_theme_color_override("font_outline_color", Color.BLACK)
	message_label.position.y -= 70
	layer.add_child(message_label)

	var help := Label.new()
	help.text = "Move: WASD / stick   Attack: Space / A   Grab or drop monarch: E / X   Class in castle: 1 Worker  2 Melee  3 Ranged"
	help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	help.grow_vertical = Control.GROW_DIRECTION_BEGIN
	help.position += Vector2(12, -10)
	help.add_theme_font_size_override("font_size", 15)
	help.add_theme_constant_override("outline_size", 4)
	help.add_theme_color_override("font_outline_color", Color.BLACK)
	layer.add_child(help)

	banner = Label.new()
	banner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size", 30)
	banner.add_theme_constant_override("outline_size", 10)
	banner.add_theme_color_override("font_outline_color", Color.BLACK)
	layer.add_child(banner)


func _update_score() -> void:
	score_label.text = "Elves  %d   —   %d  Humans" % [score[0], score[1]]


# --- Input -----------------------------------------------------------------

func _setup_input() -> void:
	_add_action("move_left", [KEY_A, KEY_LEFT], [], JOY_AXIS_LEFT_X, -1.0)
	_add_action("move_right", [KEY_D, KEY_RIGHT], [], JOY_AXIS_LEFT_X, 1.0)
	_add_action("move_up", [KEY_W, KEY_UP], [], JOY_AXIS_LEFT_Y, -1.0)
	_add_action("move_down", [KEY_S, KEY_DOWN], [], JOY_AXIS_LEFT_Y, 1.0)
	_add_action("attack", [KEY_SPACE, KEY_J], [JOY_BUTTON_A])
	_add_action("interact", [KEY_E, KEY_K], [JOY_BUTTON_X])
	_add_action("class_1", [KEY_1], [JOY_BUTTON_DPAD_LEFT])
	_add_action("class_2", [KEY_2], [JOY_BUTTON_DPAD_UP])
	_add_action("class_3", [KEY_3], [JOY_BUTTON_DPAD_RIGHT])
	_add_action("restart", [KEY_R, KEY_ENTER], [JOY_BUTTON_START])


func _add_action(action: StringName, keys: Array, buttons: Array, axis: int = -1, axis_value: float = 0.0) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, 0.25)
	for key in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		InputMap.action_add_event(action, ev)
	for button in buttons:
		var jb := InputEventJoypadButton.new()
		jb.button_index = button
		InputMap.action_add_event(action, jb)
	if axis >= 0:
		var jm := InputEventJoypadMotion.new()
		jm.axis = axis
		jm.axis_value = axis_value
		InputMap.action_add_event(action, jm)
