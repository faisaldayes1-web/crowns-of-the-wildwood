extends SceneTree
## Agent: Codex-faisal3. Actual Viewport state/scene-exit regression.
## tools/tests/isolated.sh --headless --path . --script tools/loading_viewport_test.gd

const Isolated = preload("res://tools/tests/isolated.gd")
const Probe = preload("res://tools/tests/loading_viewport_probe.gd")
var failures := 0


func check(ok: bool, message: String) -> void:
	print(("PASS " if ok else "FAIL ") + message)
	if not ok:
		failures += 1


func _init() -> void:
	if not Isolated.ok("tools/loading_viewport_test.gd"):
		quit(2)
		return
	_run.call_deferred()


func _run() -> void:
	var original: bool = root.disable_3d
	for caller_disabled in [false, true]:
		root.disable_3d = caller_disabled
		var probe = Probe.new()
		root.add_child(probe)
		probe._suspend_loading_3d()
		check(root.disable_3d, "construction suspends 3D (caller %s)" % caller_disabled)
		probe._suspend_loading_3d()
		probe._restore_loading_3d()
		check(root.disable_3d == caller_disabled, "nested suspend preserves caller state %s" % caller_disabled)
		probe._restore_loading_3d()
		check(root.disable_3d == caller_disabled, "repeated restore is idempotent %s" % caller_disabled)
		probe.queue_free()
		await process_frame
		await process_frame
		check(root.disable_3d == caller_disabled, "ordinary scene exit preserves restored caller state %s" % caller_disabled)
		probe = Probe.new()
		root.add_child(probe)
		probe._suspend_loading_3d()
		probe.queue_free()  # interrupt construction before its normal completion
		await process_frame
		await process_frame
		check(root.disable_3d == caller_disabled, "interrupted scene exit restores caller state %s" % caller_disabled)
	root.disable_3d = original
	print("loading viewport test: %d failure(s)" % failures)
	quit(1 if failures else 0)
