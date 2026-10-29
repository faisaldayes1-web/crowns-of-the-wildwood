extends SceneTree
## Agent: Codex-faisal. Adapter regressions, NOT a full player journey.
var passed := 0
var failed := 0
var game_script: Script
var g
var world: Node3D
var isolated := false

class Actor extends Node3D:
	var team := 0
	var dead := false
	var downed := false
	var carrying = null
	var role := 0
	var is_player := true
	var hearts := 4
	var attack_timer := 0.0

class SelectedResource extends Node3D:
	func in_reach(u) -> bool:
		return global_position.distance_to(u.global_position) < 2.2
	func available() -> bool:
		return true

func _init() -> void:
	var expected := "c:/temp/cm3/roam/godot/app_userdata/crowns of the wildwood"
	if OS.get_user_data_dir().replace("\\", "/").to_lower() != expected:
		push_error("Isolated cm3 test profile required")
		quit(3)
		return
	isolated = true

func _initialize() -> void:
	if isolated:
		call_deferred("_run")

func check(ok: bool, name: String) -> void:
	if ok:
		passed += 1
		print("PASS ", name)
	else:
		failed += 1
		print("FAIL ", name)

func has_mouse(action: String, button: int) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventMouseButton and event.button_index == button:
			return true
	return false

func has_key(action: String, key: int) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and (event.physical_keycode == key or event.keycode == key):
			return true
	return false

func _run() -> void:
	if not isolated:
		return
	game_script = load("res://scripts/game.gd")
	g = game_script.new()
	g.sfx = load("res://scripts/sfx.gd").new()
	g._setup_input()
	check(has_mouse("move_interact", MOUSE_BUTTON_LEFT), "default LMB moves/interacts")
	check(not has_mouse("attack", MOUSE_BUTTON_LEFT), "default LMB cannot basic attack")
	check(has_key("force_hold", KEY_SHIFT) and not has_key("block", KEY_SHIFT), "Shift force-hold separate from block")
	check(has_mouse("force_move", MOUSE_BUTTON_WHEEL_UP) and has_mouse("force_move", MOUSE_BUTTON_WHEEL_DOWN), "both wheel directions force move")
	check(has_mouse("force_move", MOUSE_BUTTON_XBUTTON1), "thumb button force move")
	check(g.pc_movement == "click" and not g.combine_move_attack and not g.wheel_zoom, "safe click preset defaults")
	var cfg := ConfigFile.new()
	cfg.set_value("controls", "attack", [{"t": "mouse", "c": MOUSE_BUTTON_LEFT}, {"t":"key", "c":KEY_J}])
	cfg.set_value("controls", "block", [{"t":"key", "c":KEY_SHIFT}, {"t":"key", "c":KEY_K}])
	cfg.set_value("controls", "dodge", [{"t":"key", "c":KEY_Z}])
	cfg.set_value("profile", "account_gold", 481)
	cfg.set_value("settings", "move_mode", "aim")
	check(g._write_save(cfg) == OK, "legacy test save written to isolated profile")
	g._load_controls()
	check(not has_mouse("attack", MOUSE_BUTTON_LEFT) and has_key("attack", KEY_J), "legacy LMB removed without losing attack key")
	check(not has_key("block", KEY_SHIFT) and has_key("block", KEY_K), "legacy Shift block removed without losing block key")
	check(has_key("dodge", KEY_Z) and g.account_gold == 481, "migration preserves remap and progression")
	check(g.move_mode == "screen", "legacy aim-relative preference upgrades to screen directions")
	g.pc_movement = "wasd"
	g._save_settings()
	var saved := ConfigFile.new()
	check(g._read_save(saved) == OK and saved.get_value("settings", "movement_schema", 0) == 1, "settings transaction persists movement schema")
	for entry in g.REBINDABLE:
		InputMap.erase_action(entry[0])
	g._setup_input()
	g._load_controls()
	check(not has_mouse("attack", MOUSE_BUTTON_LEFT) and not has_key("block", KEY_SHIFT), "second load cannot restore old LMB/Shift conflicts")
	check(g.pc_movement == "wasd" and has_key("dodge", KEY_Z) and g.account_gold == 481, "second load preserves selected mode/custom key/progression")
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	g._rebind("attack", event)
	check(not has_mouse("attack", MOUSE_BUTTON_LEFT) and has_mouse("move_interact", MOUSE_BUTTON_LEFT), "forbidden LMB attack rebind is explicit and non-destructive")
	event.button_index = MOUSE_BUTTON_XBUTTON2
	g._rebind("force_move", event)
	check(has_mouse("force_move", MOUSE_BUTTON_XBUTTON2), "force move can rebind to second thumb button")
	world = Node3D.new()
	root.add_child(world)
	var u := Actor.new()
	world.add_child(u)
	var ore := SelectedResource.new()
	world.add_child(ore)
	ore.position = Vector3(2.0, 0, 0)
	g.guides = [null, null]
	g.seals = [{}, {}]
	g.monarchs = [null, null]
	g.economy = load("res://scripts/economy.gd").new()
	g.economy.game = g
	g.economy.nodes = [ore]
	check(g.pointer_descriptor(u, ore) == ["resource", 0], "pointer descriptor binds exact known resource")
	check(g.pointer_node(u, ["resource", 0]) == ore, "descriptor resolves same resource")
	check(g.pointer_node(u, ["resource", -1]) == null and g.pointer_node(u, ["resource", "0"]) == null and g.pointer_node(u, ["execute", 0]) == null, "pointer descriptor rejects negative/typed/method injection")
	check(is_equal_approx(g.pointer_reach(u, ore), 2.1), "ore uses existing gathering reach outside solid collider")
	check(g.try_pointer_interact(u, ore) and g.economy.work[u].node == ore, "click dispatch works exact resource at legal reach")
	g.economy.work.clear()
	u.carrying = Node3D.new()
	check(not g.try_pointer_interact(u, ore) and u.carrying != null and g.economy.work.is_empty(), "selected click cannot drop a carried crown")
	u.carrying.free()
	u.carrying = null
	ore.position.y = 3.0
	check(not g.try_pointer_interact(u, ore), "click cannot interact through another floor")
	ore.position = Vector3(4, 0, 0)
	check(not g.try_pointer_interact(u, ore), "out-of-range target rejected again at dispatch")
	ore.position = Vector3(2, 0, 0)
	u.dead = true
	check(not g.try_pointer_interact(u, ore), "dead actor cannot interact")
	u.dead = false
	g.prep_left = 20.0
	check(g.try_pointer_interact(u, ore) and g.economy.work[u].node == ore, "selected prep interaction stays resource work, never generic barricade")
	var outside := SelectedResource.new()
	world.add_child(outside)
	check(not g.try_pointer_interact(u, outside), "unknown object cannot dispatch a command")
	print("C1_MOVEMENT_ADAPTER_RESULT ", JSON.stringify({"agent":"Codex-faisal", "passed":passed, "failed":failed, "limits":"headless adapter/save/exact-dispatch checks, not natural playthrough/controller hardware/network peers"}))
	g._flush_save()
	g.sfx.free()
	g.economy.free()
	g.free()
	world.free()
	quit(0 if failed == 0 else 1)
