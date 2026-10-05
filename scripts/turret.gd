extends StaticBody3D
## A bolt turret an Engineer builds on their castle walls or grounds. It
## shoots the nearest enemy in range, can be raised to level 3 with Tune Up
## and breaks after enough hits. Enemies collide with it and can shoot it;
## its own team walks through it.

const Stats = preload("res://scripts/stats.gd")

var game
var team := 0
var builder            # the unit that built it: kills and hits earn them XP
var level := 1
var hp := 0
var rapid := false     # Artificer turrets: fire faster
var ballista := false  # Siegewright turrets: slow, splashing bolts, longer reach
var thorn := false     # Elven thorn totems: living wood, slowing thorns
var overclock := 0.0   # seconds of double fire rate left
var fire_timer := 1.0
var head: Node3D
var shape: CollisionShape3D
var label: Label3D
var level_parts: Array = []
var glow: OmniLight3D
var sway := 0.0


func setup(p_game, p_team: int, pos: Vector3, p_builder, opts: Dictionary) -> void:
	game = p_game
	team = p_team
	builder = p_builder
	rapid = opts.get("rapid", false)
	ballista = opts.get("ballista", false)
	thorn = opts.get("thorn", false)
	position = pos
	scale = Vector3.ONE * 1.2  # reads better from the high camera
	collision_layer = 4 if team == 0 else 8   # the enemy's "door" layer: they bump into it and shoot it
	collision_mask = 0
	shape = CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.55
	cyl.height = 1.6
	shape.shape = cyl
	shape.position = Vector3(0, 0.8, 0)
	add_child(shape)
	hp = max_hp()
	_build_visual()
	label = Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 40
	label.pixel_size = 0.004
	label.outline_size = 10
	label.no_depth_test = true
	label.position = Vector3(0, 2.1, 0)
	add_child(label)
	_refresh()


func max_hp() -> int:
	return Stats.TURRET.hits[level - 1]


func fire_range() -> float:
	return Stats.TURRET.range[level - 1] + (3.0 if ballista else 0.0)


func interval() -> float:
	var t: float = Stats.TURRET.interval[level - 1]
	if rapid:
		t *= 0.7
	if ballista:
		t *= 1.6
	if overclock > 0.0:
		t *= 0.5
	return t


func kind_name() -> String:
	if thorn:
		return "Thorn totem"
	return "Ballista" if ballista else ("Rapid turret" if rapid else "Turret")


func _build_visual() -> void:
	for c in get_children():
		if c != shape and c != label:
			c.queue_free()
	level_parts = []
	var team_col: Color = Stats.FACTIONS[team].color
	var stone: StandardMaterial3D = game._ashlar(Color(0.85, 0.82, 0.76))
	var wood: StandardMaterial3D = game._timber(Color(0.8, 0.7, 0.55))
	var iron: StandardMaterial3D = game._material(Color(0.35, 0.36, 0.4))
	iron.metallic = 0.6
	iron.roughness = 0.4
	var gold: StandardMaterial3D = game._material(Color(0.98, 0.8, 0.25))
	gold.metallic = 0.7
	gold.roughness = 0.3
	var cloth: StandardMaterial3D = game._material(team_col)
	# Base: a stone drum with a timber post.
	var base := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.48
	bm.bottom_radius = 0.56
	bm.height = 0.32
	base.mesh = bm
	base.position = Vector3(0, 0.16, 0)
	base.material_override = stone
	add_child(base)
	_box(self, Vector3(0.2, 0.9, 0.2), Vector3(0, 0.75, 0), wood)
	for i in 4:
		var a := TAU * i / 4.0 + PI / 4.0
		var brace := _box(self, Vector3(0.07, 0.6, 0.07), Vector3(cos(a) * 0.3, 0.5, sin(a) * 0.3), wood)
		brace.rotation = Vector3(-sin(a) * 0.5, 0, cos(a) * 0.5)
	# Head: a crossbow body on a swivel; it turns to track targets.
	head = Node3D.new()
	head.position = Vector3(0, 1.25, 0)
	add_child(head)
	_box(head, Vector3(0.22, 0.16, 0.9), Vector3(0, 0, 0.1), wood)             # stock
	_box(head, Vector3(0.14, 0.08, 0.5), Vector3(0, 0.1, 0.25), iron)           # rail
	var bow_w := 1.1 if ballista else 0.9
	var limb_mat: StandardMaterial3D = gold if level >= 3 else (iron if level >= 2 else wood)
	if thorn:
		# A living totem: leaf-green limbs and bark, no iron.
		var leaf := StandardMaterial3D.new()
		leaf.albedo_color = Color(0.35, 0.7, 0.3)
		leaf.roughness = 0.9
		limb_mat = leaf if level < 3 else gold
	for s in [-1.0, 1.0]:
		var limb := _box(head, Vector3(bow_w / 2.0, 0.06, 0.08), Vector3(s * bow_w / 4.0, 0.0, 0.45), limb_mat)
		limb.rotation.y = -s * 0.25
	_box(head, Vector3(bow_w * 0.95, 0.012, 0.012), Vector3(0, 0.0, 0.3), iron)  # string
	_box(head, Vector3(0.05, 0.05, 0.6), Vector3(0, 0.09, 0.3), iron)          # loaded bolt
	# Team pennant on a pole.
	_box(self, Vector3(0.04, 0.8, 0.04), Vector3(-0.3, 1.6, -0.3), wood)
	var flag := _box(self, Vector3(0.02, 0.22, 0.34), Vector3(-0.3, 1.9, -0.13), cloth)
	flag.rotation.y = 0.0
	if level >= 2:
		# Iron bands on the post and a second brace ring.
		for y in [0.45, 0.95]:
			var band := MeshInstance3D.new()
			var rm := TorusMesh.new()
			rm.inner_radius = 0.12
			rm.outer_radius = 0.17
			band.mesh = rm
			band.position = Vector3(0, y, 0)
			band.material_override = iron
			add_child(band)
			level_parts.append(band)
		var plate := _box(head, Vector3(0.3, 0.2, 0.08), Vector3(0, 0.02, -0.25), iron)
		level_parts.append(plate)
	if level >= 3:
		# A gold cap and a runed glow.
		var cap := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 0.16
		cm.height = 0.24
		cap.mesh = cm
		cap.position = Vector3(-0.3, 2.08, -0.3)
		cap.material_override = gold
		add_child(cap)
		var gem := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.09
		sm.height = 0.18
		gem.mesh = sm
		var gm: StandardMaterial3D = game._material(team_col.lightened(0.4))
		gm.emission_enabled = true
		gm.emission = team_col * 1.5
		gem.material_override = gm
		gem.position = Vector3(0, 0.2, -0.3)
		head.add_child(gem)
		glow = OmniLight3D.new()
		glow.light_color = team_col.lightened(0.3)
		glow.light_energy = 1.2
		glow.omni_range = 3.5
		glow.position = Vector3(0, 1.6, 0)
		add_child(glow)
	if ballista:
		_box(head, Vector3(0.1, 0.1, 0.3), Vector3(0, 0.0, -0.55), iron)


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	m.position = pos
	m.material_override = mat
	parent.add_child(m)
	return m


func _refresh() -> void:
	label.text = "%s L%d  %d / %d" % [kind_name(), level, hp, max_hp()]
	label.modulate = Stats.FACTIONS[team].color.lightened(0.5) if hp > max_hp() / 2 else Color(1, 0.6, 0.4)


func take_hit(amount: int, attacker = null) -> void:
	if hp <= 0:
		return
	hp = maxi(hp - amount, 0)
	if attacker and attacker.team != team:
		attacker.gain_xp(Stats.XP_GATE * amount)
	game.spawn_splash(global_position + Vector3(0, 1.2, 0), Color(0.75, 0.6, 0.4), 8, 3.0, 0.4)
	game.sfx.play("barricade", global_position, -2.0, 0.15)
	if hp == 0:
		_destroyed(attacker)
	else:
		_refresh()


func _destroyed(attacker) -> void:
	game.spawn_splash(global_position + Vector3(0, 1.0, 0), Color(0.6, 0.45, 0.3), 30, 5.0, 0.9)
	game.spawn_splash(global_position + Vector3(0, 1.4, 0), Color(0.4, 0.4, 0.45), 16, 2.5, 1.2, true)
	game.spawn_ring(global_position, 1.6, Color(1.0, 0.6, 0.3), 0.5)
	game.shake_at(global_position, 0.4)
	game.sfx.play("turret_break", global_position, 2.0)
	if attacker and attacker.team != team:
		attacker.gain_xp(Stats.XP_TURRET)
		if attacker.is_player:
			game.spawn_popup(attacker.global_position + Vector3(0, 2.4, 0), "TURRET DOWN  +%d XP" % Stats.XP_TURRET, Color(1.0, 0.8, 0.4))
	if is_instance_valid(builder) and builder.is_player:
		game.toast("Your %s was destroyed" % kind_name().to_lower(), Color(1.0, 0.6, 0.5))
	game.remove_turret(self)
	queue_free()


func upgrade() -> bool:
	## Tune Up: full repair, and a level up to the cap. Returns false if
	## nothing changed.
	var changed := false
	if level < Stats.TURRET.max_level:
		level += 1
		_build_visual()
		changed = true
	if hp < max_hp():
		hp = max_hp()
		changed = true
	if changed:
		game.spawn_ring(global_position, 1.4, Color(1.0, 0.85, 0.3), 0.5)
		game.spawn_splash(global_position + Vector3(0, 1.0, 0), Color(1.0, 0.85, 0.3), 14, 3.0, 0.5, true)
		game.sfx.play("turret_upgrade", global_position, 0.0)
		_refresh()
	return changed


func needs_work() -> bool:
	return level < Stats.TURRET.max_level or hp < max_hp()


func _target():
	## The enemy carrier first, else the nearest enemy in range at a height
	## bolts can reach.
	var best = null
	var best_d := fire_range()
	for u in game.units:
		if u.team == team or u.dead or u.is_protected() or u.stealth_timer > 0.0:
			continue
		var d: float = game._flat_dist(u.global_position, global_position)
		if d > fire_range():
			continue
		if u.carrying != null:
			return u
		if d < best_d:
			best_d = d
			best = u
	return best


func _physics_process(delta: float) -> void:
	overclock = maxf(overclock - delta, 0.0)
	fire_timer -= delta
	var target = _target()
	if target:
		var to: Vector3 = target.global_position - global_position
		to.y = 0.0
		if to.length() > 0.1:
			head.rotation.y = lerp_angle(head.rotation.y, atan2(to.x, to.z), minf(delta * 8.0, 1.0))
		if fire_timer <= 0.0:
			fire_timer = interval()
			_fire(to.normalized())
	else:
		sway += delta
		head.rotation.y = lerp_angle(head.rotation.y, sin(sway * 0.5) * 0.6 + (PI / 2.0 if team == 0 else -PI / 2.0), minf(delta * 2.0, 1.0))
	if glow:
		glow.light_energy = 1.0 + 0.3 * sin(Time.get_ticks_msec() / 180.0) + (0.8 if overclock > 0.0 else 0.0)


func _fire(dir: Vector3) -> void:
	var s := {"damage": Stats.TURRET.damage, "gate_damage": 0, "range": fire_range() + 2.0,
		"shot_speed": Stats.TURRET.shot_speed}
	if ballista:
		s["splash"] = 2.0
		s["shot_speed"] = 26.0
	if thorn:
		s["slow"] = 1.0
		s["shot_speed"] = 30.0
	var muzzle: Vector3 = global_position + Vector3(0, 1.25, 0) + dir * 0.6
	var owner_unit = builder if is_instance_valid(builder) else null
	game.spawn_bolt(team, muzzle, dir, s, Stats.FACTIONS[team].color.lightened(0.5), owner_unit)
	game.sfx.play("turret_fire", global_position, -6.0, 0.15)
	# Recoil kick on the head.
	head.position.z = -0.08
	var tw := create_tween()
	tw.tween_property(head, "position:z", 0.0, 0.15)
