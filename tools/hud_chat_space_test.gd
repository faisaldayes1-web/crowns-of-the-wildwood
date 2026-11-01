extends SceneTree
## Agent: Codex-faisal. Busy chat must not cover the map/cargo warning.

class Fixture extends RefCounted:
	var rosters_visible := false
	var couch_active := false
	var economy = true
	var player = true

func _initialize() -> void:
	var hud = load("res://scripts/hud.gd").new()
	hud.game = Fixture.new()
	var failures := 0
	# Width, height, expected lower edge of the actual full-cargo ink.
	for fixture in [[1280, 720, 301], [1152, 720, 385], [960, 720, 235], [1280, 800, 301]]:
		hud.size = Vector2(fixture[0], fixture[1])
		for touch in [false, true]:
			hud.touch_ui = touch
			var area: Rect2 = hud._chat_rect()
			if area.position.y <= fixture[2] or area.end.y > hud.size.y - 166 or area.size.y < 100:
				push_error("Chat intrudes on reserved HUD space: %s %s" % [fixture, area])
				failures += 1
	hud.size = Vector2(1280, 720)
	hud.game.rosters_visible = true
	if hud._chat_rect().position.y < 382:
		failures += 1
	hud.game.rosters_visible = false
	hud.game.couch_active = true
	if hud._chat_rect().position.y != 130:
		failures += 1
	hud.free()
	print("HUD chat space test: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)
