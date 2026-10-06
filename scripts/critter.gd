extends Node3D
## Small living things that wander about the map and never touch the fight:
## sheep and chickens in their pens, butterflies over the flowers and birds
## circling high over the field. Built from primitives so nothing is licensed.

var kind := "sheep"
var pen := Rect2()          # x/z bounds the critter wanders inside
var speed := 0.8
var target := Vector3.ZERO
var idle := 0.0
var t := 0.0
var r := RandomNumberGenerator.new()
var body: Node3D
var wings: Array = []
var legs: Array = []
var orbit_center := Vector3.ZERO
var orbit_radius := 20.0
var orbit_phase := 0.0
var orbit_height := 11.0


func setup(what: String, at: Vector3, bounds: Rect2, seed: int = 0) -> void:
	kind = what
	pen = bounds
	position = at
	r.seed = seed if seed != 0 else int(at.x * 31 + at.z * 7)
	t = r.randf() * 10.0
	body = Node3D.new()
	add_child(body)
	match kind:
		"sheep":
			speed = 0.7
			_build_sheep()
			scale = Vector3.ONE * 1.25
		"chicken":
			speed = 1.1
			_build_chicken()
			scale = Vector3.ONE * 1.5
		"butterfly":
			speed = 1.6
			_build_butterfly()
		"bird":
			speed = 6.0
			_build_bird()
	_pick_target()


func _mat(color: Color, rough: float = 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	return m


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _ball(parent: Node3D, radius: float, pos: Vector3, mat: Material, squash: float = 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0 * squash
	sm.radial_segments = 10
	sm.rings = 5
	mi.mesh = sm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _build_sheep() -> void:
	var wool := _mat(Color(0.93, 0.91, 0.86))
	var dark := _mat(Color(0.2, 0.17, 0.15))
	_ball(body, 0.42, Vector3(0, 0.55, 0), wool, 0.85)
	_ball(body, 0.3, Vector3(0, 0.6, -0.25), wool, 0.9)
	_ball(body, 0.3, Vector3(0, 0.6, 0.25), wool, 0.9)
	_ball(body, 0.17, Vector3(0, 0.72, 0.5), dark, 1.0)   # head
	_box(body, Vector3(0.08, 0.04, 0.12), Vector3(-0.14, 0.8, 0.48), dark)
	_box(body, Vector3(0.08, 0.04, 0.12), Vector3(0.14, 0.8, 0.48), dark)
	for lx in [-0.16, 0.16]:
		for lz in [-0.22, 0.22]:
			legs.append(_box(body, Vector3(0.09, 0.32, 0.09), Vector3(lx, 0.16, lz), dark))


func _build_chicken() -> void:
	var feather := _mat(Color(0.95, 0.93, 0.88) if r.randf() < 0.6 else Color(0.6, 0.38, 0.2))
	var red := _mat(Color(0.85, 0.15, 0.12))
	var orange := _mat(Color(0.95, 0.6, 0.15))
	_ball(body, 0.17, Vector3(0, 0.3, 0), feather, 0.9)
	_ball(body, 0.11, Vector3(0, 0.5, 0.14), feather)
	_box(body, Vector3(0.03, 0.08, 0.1), Vector3(0, 0.6, 0.14), red)      # comb
	_box(body, Vector3(0.05, 0.04, 0.08), Vector3(0, 0.49, 0.26), orange)  # beak
	_box(body, Vector3(0.03, 0.06, 0.03), Vector3(0, 0.45, 0.2), red)      # wattle
	_box(body, Vector3(0.06, 0.05, 0.14), Vector3(0, 0.33, -0.16), feather)  # tail
	for lx in [-0.06, 0.06]:
		legs.append(_box(body, Vector3(0.03, 0.16, 0.03), Vector3(lx, 0.08, 0.0), orange))


func _build_butterfly() -> void:
	var hues := [0.08, 0.12, 0.55, 0.75, 0.9]
	var hue: float = hues[r.randi() % hues.size()]
	var wing := _mat(Color.from_hsv(hue, 0.65, 0.95), 1.0)
	wing.cull_mode = BaseMaterial3D.CULL_DISABLED
	var dark := _mat(Color(0.15, 0.12, 0.1))
	_box(body, Vector3(0.03, 0.03, 0.12), Vector3.ZERO, dark)
	for sx in [-1.0, 1.0]:
		var w := Node3D.new()
		body.add_child(w)
		var q := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(0.16, 0.14)
		q.mesh = pm
		q.material_override = wing
		q.position = Vector3(sx * 0.09, 0, 0)
		w.add_child(q)
		w.set_meta("side", sx)
		wings.append(w)
	position.y = 0.9


func _build_bird() -> void:
	var dark := _mat(Color(0.12, 0.1, 0.1), 1.0)
	_box(body, Vector3(0.12, 0.08, 0.45), Vector3.ZERO, dark)
	for sx in [-1.0, 1.0]:
		var w := Node3D.new()
		body.add_child(w)
		_box(w, Vector3(0.8, 0.03, 0.18), Vector3(sx * 0.45, 0, 0), dark)
		w.set_meta("side", sx)
		wings.append(w)
	orbit_phase = r.randf() * TAU


func orbit(center: Vector3, radius: float, height: float) -> void:
	orbit_center = center
	orbit_radius = radius
	orbit_height = height


func _pick_target() -> void:
	target = Vector3(pen.position.x + r.randf() * pen.size.x, position.y, pen.position.y + r.randf() * pen.size.y)
	idle = 0.0


func _process(delta: float) -> void:
	t += delta
	if kind == "bird":
		orbit_phase += delta * speed / orbit_radius
		var p := orbit_center + Vector3(cos(orbit_phase) * orbit_radius, orbit_height + sin(t * 0.7) * 0.8, sin(orbit_phase) * orbit_radius)
		var dir := p - position
		position = p
		if dir.length() > 0.001:
			look_at(p + dir, Vector3.UP)
		for w in wings:
			w.rotation.z = sin(t * 5.0) * 0.5 * w.get_meta("side")
		return
	if idle > 0.0:
		idle -= delta
		if kind == "sheep" or kind == "chicken":
			body.position.y = 0.0
		if idle <= 0.0:
			_pick_target()
		return
	var to := target - position
	to.y = 0.0
	if to.length() < 0.15:
		idle = r.randf_range(1.5, 5.0) if kind != "butterfly" else 0.3
		return
	var step := to.normalized() * speed * delta
	position += step
	var face := atan2(to.x, to.z)
	rotation.y = lerp_angle(rotation.y, face, 6.0 * delta)
	match kind:
		"sheep":
			body.position.y = absf(sin(t * 6.0)) * 0.04
			for i in legs.size():
				legs[i].rotation.x = sin(t * 6.0 + (PI if i % 3 == 0 else 0.0)) * 0.5
		"chicken":
			body.position.y = absf(sin(t * 12.0)) * 0.05
			body.rotation.x = sin(t * 12.0) * 0.08
			for i in legs.size():
				legs[i].rotation.x = sin(t * 12.0 + float(i) * PI) * 0.7
		"butterfly":
			position.y = 0.7 + sin(t * 2.3) * 0.25 + sin(t * 5.1) * 0.08
			for w in wings:
				w.rotation.z = sin(t * 18.0) * 0.9 * w.get_meta("side")
