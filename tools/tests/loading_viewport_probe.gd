extends "res://scripts/game.gd"
## Agent: Codex-faisal3. Test the real viewport lifecycle without building a world.


func _ready() -> void:
	# The inherited per-frame game loop creates a compass mesh even without
	# a world. Keep this lifecycle-only probe from running that unrelated loop.
	process_mode = Node.PROCESS_MODE_DISABLED
