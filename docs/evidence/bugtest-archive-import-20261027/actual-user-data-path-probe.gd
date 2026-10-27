# Agent: Codex-faisal3/bugtest. Read actual user:// resolution before loading the game's main scene.
extends SceneTree

func _initialize() -> void:
	var expected := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--bugtest-user-prefix="):
			expected = arg.trim_prefix("--bugtest-user-prefix=").replace("\\", "/").trim_suffix("/")
	var actual := OS.get_user_data_dir().replace("\\", "/")
	print("BUGTEST_USER_PATH ", JSON.stringify({"agent": "Codex-faisal3/bugtest", "actual": actual, "expected_prefix": expected}))
	quit(0 if not expected.is_empty() and actual.begins_with(expected + "/") else 92)
