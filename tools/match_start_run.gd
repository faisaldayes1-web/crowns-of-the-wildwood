extends SceneTree
## Runs tools/match_start_probe.gd on a source checkout (claude-faisal/stutter):
## the probe node first, then the game, built in the player's order
## (--world-behind). Rendered only: headless builds the world before the title.
##   tools/tests/isolated.sh --path . --script tools/match_start_run.gd -- --world-behind [--probe-press=S] [--probe-shot=PNG]

const Isolated = preload("res://tools/tests/isolated.gd")


func _init() -> void:
	if not Isolated.ok("tools/match_start_run.gd"):   # a match start may write the save
		quit(2)
		return
	var probe := Node.new()
	probe.set_script(load("res://tools/match_start_probe.gd"))
	root.add_child(probe)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
