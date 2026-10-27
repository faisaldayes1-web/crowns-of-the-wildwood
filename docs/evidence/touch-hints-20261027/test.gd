extends SceneTree
var checks := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		push_error(label)
		quit(1)
	else:
		print("PASS ", label)
func _initialize() -> void:
	var hud = preload("res://hint.gd").new()
	var keyboard := {"who": "", "text": "Click to attack, Q and E for abilities, Space to dodge, F for perks, hold TAB for the scoreboard, T to chat."}
	var fortify := {"who": "", "text": "FORTIFY! Build turrets, set traps and raise barricades (F) before the barrier falls."}
	var original := keyboard.duplicate()
	check(hud._chat_display_text(keyboard) == keyboard.text, "desktop keyboard instructions preserved")
	check(hud._chat_display_text(fortify) == fortify.text, "desktop fortify preserved")
	hud.touch_ui = true
	check(hud._chat_display_text(keyboard) == "Drag left to move.\nTap actions to fight.", "touch fight onboarding")
	check(hud._chat_display_text(fortify) == "Fortify your base\nbefore the barrier falls.", "touch fortify onboarding")
	check(keyboard == original, "stored history not rewritten")
	var player := keyboard.duplicate()
	player.who = "Player 2"
	check(hud._chat_display_text(player) == player.text, "matching player chat untouched")
	var event := {"who": "", "text": "Elves captured the crown!"}
	check(hud._chat_display_text(event) == event.text, "other system messages untouched")
	hud.touch_ui = false
	check(hud._chat_display_text(keyboard) == original.text, "switch back restores desktop instructions")
	print("CHECKS ", checks)
	quit()
