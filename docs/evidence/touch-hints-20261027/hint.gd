extends RefCounted
var touch_ui := false
func _chat_display_text(message: Dictionary) -> String:
	# Only adapt system onboarding; never rewrite another player's chat.
	var text: String = message.text
	if not touch_ui or message.get("who", "") != "":
		return text
	if text.begins_with("Click to attack, Q and E for abilities, Space to dodge,"):
		return "Drag left to move. Tap actions to fight."
	if text.begins_with("FORTIFY! Build turrets, set traps and raise barricades ("):
		return "Fortify your base before the barrier falls."
	return text
