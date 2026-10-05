extends "res://scripts/turret.gd"
## A war banner: a team flag planted in the field that stands for a while
## and brings fallen teammates back beside it instead of in their castle.
## Enemies can hack it down. It shares the turret's body (so shots and
## blows land on it the same way) but never fires.

var life := 0.0


func setup(p_game, p_team: int, pos: Vector3, p_builder, _opts: Dictionary) -> void:
	game = p_game
	team = p_team
	builder = p_builder
	position = pos
	life = Stats.BANNER.life
	collision_layer = 4 if team == 0 else 8
	collision_mask = 0
	shape = CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.35
	cyl.height = 2.4
	shape.shape = cyl
	shape.position = Vector3(0, 1.2, 0)
	add_child(shape)
	hp = max_hp()
	_build_visual()
	label = Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 40
	label.pixel_size = 0.004
	label.outline_size = 10
	label.no_depth_test = true
	label.position = Vector3(0, 3.4, 0)
	add_child(label)
	_refresh()


func max_hp() -> int:
	return Stats.BANNER.hits


func kind_name() -> String:
	return "War banner"


func needs_work() -> bool:
	return false


func upgrade() -> bool:
	return false


func _build_visual() -> void:
	for c in get_children():
		if c is MeshInstance3D or c is Node3D and c != shape and c != label and c.name.begins_with("vis"):
			c.queue_free()
	var vis := Node3D.new()
	vis.name = "vis"
	add_child(vis)
	var tcol: Color = Stats.FACTIONS[team].color
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.42, 0.28, 0.16)
	var stone: StandardMaterial3D = game._ashlar(Color(0.78, 0.74, 0.66)) if game.has_method("_ashlar") else wood
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = tcol.lightened(0.1)
	cloth.roughness = 0.9
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(1.0, 0.82, 0.3)
	gold.metallic = 0.7
	gold.roughness = 0.35
	# A stone footing, the pole, a crossbar and the hanging flag with a gold finial.
	_box(vis, Vector3(0.9, 0.25, 0.9), Vector3(0, 0.125, 0), stone)
	_box(vis, Vector3(0.14, 3.0, 0.14), Vector3(0, 1.6, 0), wood)
	_box(vis, Vector3(0.1, 0.1, 1.3), Vector3(0, 3.0, 0), wood)
	_box(vis, Vector3(0.06, 1.5, 1.1), Vector3(0, 2.25, 0.08), cloth)
	_box(vis, Vector3(0.07, 0.3, 0.5), Vector3(0, 1.45, -0.2), cloth)
	_box(vis, Vector3(0.07, 0.3, 0.5), Vector3(0, 1.45, 0.36), cloth)
	var finial := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.13
	sph.height = 0.26
	finial.mesh = sph
	finial.position = Vector3(0, 3.2, 0)
	finial.material_override = gold
	vis.add_child(finial)
	head = vis   # the turret code sways `head`; here the whole flag ripples a little


func _refresh() -> void:
	label.text = "%s  %d / %d  ·  %ds" % [kind_name(), hp, max_hp(), ceili(life)]
	label.modulate = Stats.FACTIONS[team].color.lightened(0.5) if hp > max_hp() / 2 else Color(1, 0.6, 0.4)


func take_hit(amount: int, attacker = null) -> void:
	if hp <= 0:
		return
	hp = maxi(hp - amount, 0)
	if attacker and attacker.team != team:
		attacker.gain_xp(Stats.XP_GATE * amount)
	game.spawn_splash(global_position + Vector3(0, 1.6, 0), Stats.FACTIONS[team].color, 8, 3.0, 0.4)
	game.sfx.play("barricade", global_position, -2.0, 0.15)
	if hp == 0:
		_destroyed(attacker)
	else:
		_refresh()


func _destroyed(attacker) -> void:
	game.spawn_splash(global_position + Vector3(0, 1.5, 0), Stats.FACTIONS[team].color, 30, 5.0, 0.9)
	game.spawn_splash(global_position + Vector3(0, 1.0, 0), Color(0.45, 0.35, 0.25), 16, 2.5, 1.2, true)
	game.spawn_ring(global_position, 1.6, Color(1.0, 0.6, 0.3), 0.5)
	game.shake_at(global_position, 0.3)
	game.sfx.play("turret_break", global_position, 1.0)
	if attacker and attacker.team != team:
		attacker.gain_xp(Stats.XP_TURRET)
		if attacker.is_player:
			game.spawn_popup(attacker.global_position + Vector3(0, 2.4, 0), "BANNER DOWN  +%d XP" % Stats.XP_TURRET, Color(1.0, 0.8, 0.4))
	game.announce("The %s war banner has fallen!" % Stats.FACTIONS[team].name)
	game.remove_banner(self)
	queue_free()


func _expire() -> void:
	game.spawn_splash(global_position + Vector3(0, 1.5, 0), Stats.FACTIONS[team].color, 16, 3.0, 0.8)
	game.remove_banner(self)
	queue_free()


func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		_expire()
		return
	sway += delta
	if head:
		head.rotation.y = sin(sway * 1.7) * 0.12
	if int(life * 2.0) != int((life + delta) * 2.0):
		_refresh()
