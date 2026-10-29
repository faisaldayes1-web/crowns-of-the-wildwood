extends RefCounted
## Per-seat movement intent. No InputMap, saves, attacks, teleports or renderer calls.
## Agent: Codex-faisal

var target := Vector3.INF
var target_kind := "move"
var target_ref: WeakRef
var consumed_primary := false
var previous_position := Vector3.INF
var stalled_seconds := 0.0
var force_goal := false
var interaction_sequence := 0


static func camera_motion(keys: Vector2, camera_basis: Basis) -> Vector2:
	if not keys.is_finite() or keys.length_squared() < 0.000001:
		return Vector2.ZERO
	var right := camera_basis.x
	right.y = 0.0
	if right.length_squared() < 0.000001:
		right = Vector3.RIGHT
	right = right.normalized()
	var forward := -camera_basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.000001:
		forward = camera_basis.y
		forward.y = 0.0
	forward -= right * forward.dot(right)
	if forward.length_squared() < 0.000001:
		forward = Vector3(right.z, 0.0, -right.x)
	forward = forward.normalized()
	var world := right * keys.x - forward * keys.y
	if not world.is_finite() or world.length_squared() < 0.000001:
		return Vector2.ZERO
	world = world.normalized() * minf(keys.length(), 1.0)
	return Vector2(world.x, world.z)


func cancel() -> void:
	target = Vector3.INF
	target_ref = null
	target_kind = "move"
	previous_position = Vector3.INF
	stalled_seconds = 0.0
	force_goal = false


func _select(point: Vector3, kind: String = "move", node = null) -> void:
	if not point.is_finite():
		cancel()
		return
	if target == Vector3.INF or target.distance_to(point) > 0.5:
		stalled_seconds = 0.0
	target = point
	target_kind = kind
	target_ref = weakref(node) if is_instance_valid(node) else null


func resolve(frame: Dictionary, route: Callable = Callable()) -> Dictionary:
	var result := {"move": Vector2.ZERO, "attack": false, "attack_tap": false,
		"interact": false, "interact_tap": false, "pointer_target": null,
		"pointer_sequence": interaction_sequence, "force_move": false, "force_hold": false}
	var primary: bool = frame.get("primary", false)
	if not primary:
		consumed_primary = false
	if frame.get("blocked", false):
		cancel()
		consumed_primary = primary
		return result
	result.attack = frame.get("attack", false)
	result.attack_tap = frame.get("attack_tap", false)
	result.interact = frame.get("interact", false)
	result.interact_tap = frame.get("interact_tap", false)
	var keys: Vector2 = frame.get("keys", Vector2.ZERO)
	var keyboard := camera_motion(keys, frame.get("basis", Basis.IDENTITY))
	# Force-hold is separate from block and never starts a move or interaction.
	if frame.get("hold", false):
		cancel()
		consumed_primary = primary
		result.force_hold = true
		result.interact = false
		result.interact_tap = false
		result.attack = result.attack or primary
		result.attack_tap = result.attack_tap or frame.get("primary_tap", false)
		return result
	var force: bool = frame.get("force", false) or frame.get("force_pulse", false)
	if not frame.get("mouse", false):
		cancel()
		if force:
			result.force_move = true
			result.attack = false
			result.attack_tap = false
			result.interact = false
			result.interact_tap = false
		else:
			result.move = keyboard
		return result
	var point: Vector3 = frame.get("ground", Vector3.INF)
	if force:
		_select(point)
		force_goal = true
	elif frame.get("primary_tap", false) and not consumed_primary:
		force_goal = false
		var choice: Dictionary = frame.get("choice", {})
		if not choice.is_empty():
			_select(choice.position, choice.kind, choice.get("node"))
		else:
			_select(point)
	elif primary and not consumed_primary and target_kind == "move":
		_select(point)
	# Explicit directional input immediately cancels a click goal.
	if frame.get("keyboard", false) and keys.length() > 0.001 and not force:
		cancel()
		result.move = keyboard
		return result
	if force_goal:
		result.force_move = true
		result.attack = false
		result.attack_tap = false
		result.interact = false
		result.interact_tap = false
	if target == Vector3.INF:
		return result
	if target_ref != null:
		var node = target_ref.get_ref()
		if not is_instance_valid(node) or not node.is_inside_tree() or node.is_queued_for_deletion():
			cancel()
			return result
		if target_kind == "attack" and node.get("dead") == true:
			cancel()
			return result
		target = node.global_position
	var position: Vector3 = frame.position
	var offset := target - position
	var level_compatible := absf(offset.y) <= 0.6
	offset.y = 0.0
	var reach := 0.22
	if target_kind == "interact":
		reach = float(frame.get("interaction_reach", 1.1))
	elif target_kind == "attack":
		reach = maxf(0.3, float(frame.get("attack_reach", 1.0)))
	if offset.length() <= reach and level_compatible:
		if target_kind == "interact":
			# Never translate a selected click into generic F. The adapter must
			# revalidate and dispatch this exact object, locally or on the host.
			result.pointer_target = target_ref.get_ref() if target_ref != null else null
			interaction_sequence += 1
			result.pointer_sequence = interaction_sequence
			consumed_primary = primary
		elif target_kind == "attack":
			result.attack = true
			result.attack_tap = frame.get("primary_tap", false)
			return result
		cancel()
		return result
	var next: Vector3 = route.call(position, target) if route.is_valid() else target
	var leg := next - position
	leg.y = 0.0
	if not leg.is_finite() or leg.length_squared() < 0.000001:
		cancel()
		return result
	var delta := maxf(float(frame.get("delta", 0.016667)), 0.000001)
	if previous_position != Vector3.INF and position.distance_to(previous_position) < 0.002:
		stalled_seconds += delta
	else:
		stalled_seconds = 0.0
	previous_position = position
	if stalled_seconds > 1.0:
		cancel()  # a blocked click never tunnels through walls or walks forever
		return result
	var distance_left := maxf(0.0, offset.length() - reach) if level_compatible else leg.length()
	var strength := minf(1.0, distance_left / maxf(0.001, float(frame.get("speed", 1.0)) * delta))
	var wish := leg.normalized() * strength
	result.move = Vector2(wish.x, wish.z)
	return result
