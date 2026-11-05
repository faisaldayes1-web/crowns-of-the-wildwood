extends SceneTree

const Isolated = preload("res://tools/tests/isolated.gd")
## Two players side by side get the stacked split-screen HUD (ability strip above
## the status panel, drawn about 1.6x larger at 720p); top-and-bottom and four
## players keep the single row. Run through the wrapper (it starts a match):
##     tools/tests/isolated.sh --headless --path . --script tools/split_hud_test.gd -- --play --couch=2 --seed=7
## Agent: claude-faisal3 (2026-11-04, task cf-crowns-steam-1104n item 3).

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _init() -> void:
	if not Isolated.ok("tools/split_hud_test.gd"):
		quit(2)
		return
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	var deadline := Time.get_ticks_msec() + 120000
	while game.panes.size() != 2 or is_instance_valid(game.loading_layer):
		if Time.get_ticks_msec() > deadline:
			break
		await process_frame
	for i in 10:
		await process_frame
	check(game.panes.size() == 2, "a two-player match has two panes")
	game.set_split_layout("vertical")
	check(game.pane_stacked(), "side by side panes use the stacked HUD")
	var canvas: Vector2 = game.get_viewport().get_visible_rect().size
	var px_scale: float = game._pane_pixel_scale()
	var px := Vector2(canvas.x * 0.5, canvas.y)
	var want := clampf(minf(px.y * game.SPLIT_HUD_SHARE_STACKED / game.SPLIT_HUD_ROWS_STACKED, px.x / game.SPLIT_HUD_WIDTH_STACKED), 0.4, 0.9) * px_scale
	for pane in game.panes:
		check(is_equal_approx(pane.hud_scale, want), "stacked pane HUD scale %.2f (wanted %.2f)" % [pane.hud_scale, want])
		check(pane.hud._stacked(), "the pane's HUD knows it is stacked")
		var old := clampf(minf(px.y * game.SPLIT_HUD_SHARE / game.SPLIT_HUD_ROWS, px.x / game.SPLIT_HUD_WIDTH), 0.4, 0.9) * px_scale
		# Effective drawing scale of the bottom row: it used to be capped by the 1280-unit width.
		check(pane.hud_scale > minf(old, px.x / 1280.0 * px_scale) * 1.3, "bottom row draws at least 1.3x larger than before (%.2f vs %.2f)" % [pane.hud_scale, minf(old, px.x / 1280.0 * px_scale)])
	game.set_split_layout("horizontal")
	check(not game.pane_stacked(), "top and bottom panes keep the single-row HUD")
	for pane in game.panes:
		check(not pane.hud._stacked(), "the pane's HUD is not stacked in the horizontal layout")
	game.set_split_layout("vertical")
	game.free()
	print("split hud test: %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)
