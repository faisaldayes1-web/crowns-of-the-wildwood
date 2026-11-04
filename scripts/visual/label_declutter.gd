extends RefCounted
## Combat label declutter (claude-faisal/crowns-polish 2026-11-01; reviewers,
## Ember frame-020 / Twilight frame-014: unit names and status words overlap
## into unreadable piles). Once a frame, before the HUD draws, every unit's
## overhead tag (name and health bar) is laid out on screen: the player's
## own tag first, then the rest nearest the player first. A tag that would
## land on one already placed is lifted a step (up to two steps), and one
## with no free spot is dimmed, so a pile of fighters reads as a neat stack.
## Look only: the tags' text, colours and the fight are unchanged. In couch
## split screen every pane runs it with its own camera; a unit's tag (shared
## by the panes) takes the highest lift any pane asked for this frame and
## dims if any pane had no free spot (visual pass 2026-11-04: split-screen
## tags piled up because the panes skipped it).

const STEP := 0.7        # metres a lifted tag rises per step
const CHAR_W := 0.15     # the tag font's mean glyph width at its pixel size (m)
const TAG_H := 0.5       # name plus health bar (m)


static func run(game, cam: Camera3D, xf: Transform2D, delta: float, blocked: Array[Rect2] = []) -> Array[Rect2]:
	var placed: Array[Rect2] = []
	if cam == null:
		return placed
	var couch: bool = game.couch_active
	var frame := Engine.get_process_frames()
	if couch and int(game.get_meta(&"declutter_frame", -1)) != frame:
		game.set_meta(&"declutter_frame", frame)
		game.set_meta(&"declutter_want", {})
	var wants: Dictionary = game.get_meta(&"declutter_want", {}) if couch else {}
	if couch:
		blocked = []   # (one pane's HUD panels must not hide a tag in the other)
	var me = game.player
	if couch:
		for pn in game.panes:
			if pn.cam == cam:
				me = pn.unit
	var list := []
	for u in game.units:
		if u.label == null or u.overhead == null:
			continue
		if u.dead or u.downed or not u.label.visible or (not u.overhead.visible and not u.has_meta(&"hud_hid")):
			if u.overhead_lift != 0.0:
				u.overhead_lift = 0.0
				u.label.transparency = 0.0
			continue
		var base: Vector3 = u.overhead.global_position - Vector3(0, u.overhead_lift, 0)
		if cam.is_position_behind(base):
			continue
		var pri: float = -1.0 if u == me else (u.global_position.distance_to(me.global_position) if me else 0.0)
		list.append([pri, u, base])
	list.sort_custom(func(a, b): return a[0] < b[0])
	var k := clampf(delta * 10.0, 0.0, 1.0)
	for it in list:
		var u = it[1]
		var base: Vector3 = it[2]
		var c: Vector2 = xf * cam.unproject_position(base)
		var px_m: float = (xf * cam.unproject_position(base + cam.global_basis.x)).distance_to(c)
		var w: float = maxf(u.label.text.length() * CHAR_W, 1.1) * px_m
		var h: float = TAG_H * px_m
		# A world-up lift shows foreshortened on screen (the camera looks down).
		var step_px: float = c.y - (xf * cam.unproject_position(base + Vector3(0, STEP, 0))).y
		var want := -1
		for step in 3:
			var r := Rect2(c.x - w / 2.0, c.y - h * 0.8 - step * step_px, w, h)
			var free := true
			for q in placed:
				if r.intersects(q):
					free = false
					break
			if free:
				want = step
				placed.append(r)
				break
		var dim := want < 0
		if couch:
			var prev: Array = wants.get(u, [0, false])
			want = maxi(want, int(prev[0]))
			dim = dim or bool(prev[1])
			wants[u] = [want, dim]
		var lift := STEP * maxi(want, 0)
		u.overhead_lift = lerpf(u.overhead_lift, lift, k) if absf(u.overhead_lift - lift) > 0.01 else lift
		u.label.transparency = 0.6 if dim else 0.0
		# (Round 7: a tag under a fixed HUD panel is hidden, bar and all.)
		var tag := Rect2(c.x - w / 2.0, c.y - h * 0.8 - lift / STEP * step_px, w, h)
		var hidden := false
		for b in blocked:
			if b.intersects(tag):
				hidden = true
				break
		var show: bool = not hidden and (u.stealth_timer <= 0.0 or u.is_player)
		u.overhead.visible = show
		if show:
			u.remove_meta(&"hud_hid")
		else:
			u.set_meta(&"hud_hid", true)
	return placed
