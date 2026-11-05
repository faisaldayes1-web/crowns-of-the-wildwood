extends SceneTree
## Controller glyph kinds: Xbox, PlayStation and Nintendo Switch pads are told
## apart by name and by USB vendor id, a Switch pad names its face buttons by
## the label printed on it (the bottom button is B), the Settings picker cycles
## through all four styles and a saved style survives a restart.
##     tools/tests/isolated.sh --headless --path . --script tools/pad_kind_test.gd
## Runs only in a throwaway user dir. Agent: claude-faisal3 2026-11-04.

const Isolated = preload("res://tools/tests/isolated.gd")

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _init() -> void:
	if not Isolated.ok("tools/pad_kind_test.gd"):
		quit(2)
		return
	var g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	current_scene = g
	for i in 400:
		if g.main_menu and not g.get("menus_warming"):
			break
		await process_frame
	check(g._is_playstation("DualSense Wireless Controller", ""), "DualSense is a PlayStation pad")
	check(not g._is_nintendo("DualSense Wireless Controller", ""), "DualSense is not a Nintendo pad")
	check(g._is_nintendo("Nintendo Switch Pro Controller", ""), "Switch Pro Controller is a Nintendo pad")
	check(g._is_nintendo("Joy-Con (L)", ""), "Joy-Con is a Nintendo pad")
	check(g._is_nintendo("Pro Controller", "030000007e0500000920000000000000"), "Nintendo vendor id 057e in the GUID")
	check(not g._is_nintendo("Xbox Wireless Controller", "030000005e040000e002000000000000"), "Xbox pad is not Nintendo")
	check(not g._is_nintendo("Steam Deck", "03000000de280000ff11000000000000"), "Steam Deck keeps Xbox names")
	check(g._pad_name(JOY_BUTTON_A, "switch") == "B" and g._pad_name(JOY_BUTTON_B, "switch") == "A", "Switch: bottom is B, right is A")
	check(g._pad_name(JOY_BUTTON_X, "switch") == "Y" and g._pad_name(JOY_BUTTON_Y, "switch") == "X", "Switch: left is Y, top is X")
	check(g._pad_name(JOY_BUTTON_START, "switch") == "+" and g._pad_name(JOY_BUTTON_BACK, "switch") == "-", "Switch: + and -")
	check(g._axis_name(JOY_AXIS_TRIGGER_RIGHT, "switch") == "ZR" and g._axis_name(JOY_AXIS_TRIGGER_LEFT, "switch") == "ZL", "Switch: ZL / ZR triggers")
	check(g._pad_name(JOY_BUTTON_A, "ps") == "Cross" and g._pad_name(JOY_BUTTON_A, "xbox") == "A", "PlayStation and Xbox names unchanged")
	g.pad_style = "auto"
	var seen := []
	for i in 4:
		g.toggle_setting("pad_style")
		seen.append(g.pad_style)
	check(seen == ["xbox", "ps", "switch", "auto"], "the picker cycles auto, xbox, ps, switch (%s)" % str(seen))
	g.toggle_setting("pad_style_prev")
	check(g.pad_style == "switch", "the picker's left arrow goes back one")
	g.pad_style = "switch"
	check(g.pad_kind(-1) == "switch", "a forced Switch style wins over the detected pad")
	g._save_controls()
	g.pad_style = "auto"
	g._load_controls()
	check(g.pad_style == "switch", "a saved Switch style survives a restart")
	print("pad kind test: %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)
