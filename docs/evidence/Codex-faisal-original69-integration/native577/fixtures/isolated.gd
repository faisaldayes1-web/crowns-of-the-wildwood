extends RefCounted
## Tests that play matches and change settings (tools/map_switch_test.gd,
## tools/pad_split_test.gd) write the game's save: controls.cfg, its .bak and
## profiles/<id>.cfg (account XP, gold, store items). They must never do that
## to a real player's save, so they only run inside a throwaway user dir made
## by tools/tests/isolated.sh, and refuse otherwise. They never back up,
## restore, overwrite or delete anything outside that dir.
## claude-faisallaptop 2026-10-18 (review of #47: a killed run's backup and
## restore could overwrite newer progress or delete a real save).


const MARKER := ".crowns-throwaway-user-dir"   # written by tools/tests/isolated.sh


static func ok(test_name: String) -> bool:
	## True when this process's user dir sits inside the directory that
	## tools/tests/isolated.sh created (CROWNS_TEST_USER_BASE). Otherwise
	## prints why and how to run the test, and returns false.
	var base := OS.get_environment("CROWNS_TEST_USER_BASE").replace("\\", "/").trim_suffix("/")
	var user := OS.get_user_data_dir().replace("\\", "/")
	# The base must be the dir the wrapper made (it leaves MARKER in it), not
	# just any parent of the user dir: CROWNS_TEST_USER_BASE pointing at the
	# real APPDATA would otherwise pass (review of #57).
	var marked := base != "" and FileAccess.file_exists(base + "/" + MARKER)
	if marked and user.to_lower().begins_with(base.to_lower() + "/"):
		print("%s: user dir %s (throwaway)" % [test_name, user])
		return true
	print("%s: REFUSED: this test writes the save and would change the real one at %s." % [test_name, user])
	print("    Run it through tools/tests/isolated.sh, which gives it a throwaway user dir, e.g.:")
	print("    tools/tests/isolated.sh --headless --path . --script %s" % test_name)
	return false
