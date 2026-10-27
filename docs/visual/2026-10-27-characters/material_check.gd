extends SceneTree
## Agent: Codex-faisal/characters. Actual model material/customization acceptance.
const Model = preload("res://scripts/character_model.gd")
const Stats = preload("res://scripts/stats.gd")
var failures := 0
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _init() -> void:
	node_added.connect(preload("res://scripts/headless_mesh_lifetime.gd").watch)
	call_deferred("run")

func mesh_part(model: Node3D, name: String) -> MeshInstance3D:
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		if mesh.name == name or (mesh.get_parent() != null and mesh.get_parent().name == name):
			return mesh
	return null

func run() -> void:
	for team in 2:
		var model = Model.new()
		root.add_child(model)
		model.setup(team, Stats.Role.KNIGHT)
		var helmet: MeshInstance3D = mesh_part(model.model_root, "Knight_Helmet")
		var head: MeshInstance3D = mesh_part(model.model_root, "Knight_Head")
		var cape: MeshInstance3D = mesh_part(model.model_root, "Knight_Cape")
		var steel: StandardMaterial3D = helmet.get_active_material(0)
		var skin: StandardMaterial3D = head.get_active_material(0)
		var cloth: StandardMaterial3D = cape.get_active_material(0)
		check(steel.roughness < cloth.roughness, "Armour must differ from cloth")
		check(skin.metallic == 0.0 and cloth.metallic == 0.0, "Skin and cloth must stay nonmetallic")
		check(steel.albedo_texture != null and skin.albedo_texture != null, "Team palette must survive")
		check(model.flash_mats.has(steel) and model.flash_mats.has(skin), "Hit flash materials must survive")
		check(steel.next_pass == model.outline, "Single existing outline pass must survive")
		check(model.anim.has_animation("Idle"), "Existing animation library must survive")
		model.free()
	# An actual non-default store finish must retain its own roughness and colour.
	var weapon_index := -1
	for i in Stats.WEAPON_SKINS.size():
		if Stats.WEAPON_SKINS[i][1].a > 0.0:
			weapon_index = i
			break
	check(weapon_index >= 0, "Need an existing coloured weapon finish fixture")
	if weapon_index >= 0:
		var model = Model.new()
		root.add_child(model)
		var custom := {"weapon": weapon_index, "hair": Color("9b613c"), "trim": Color("315b9c")}
		model.setup(0, Stats.Role.KNIGHT, "", custom)
		var sword: MeshInstance3D = mesh_part(model.model_root, "1H_Sword")
		var mat: StandardMaterial3D = sword.get_active_material(0)
		check(is_equal_approx(mat.roughness, 0.4), "Store weapon finish must not be overwritten")
		check(is_equal_approx(mat.metallic, 0.45), "Store weapon metallic must survive")
		check(mat.albedo_color != Color.WHITE, "Store weapon colour must survive")
		model.free()
	print("CHARACTER MATERIAL CHECK: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

