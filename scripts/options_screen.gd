extends Control
## Dedicated options surface. Agent: Codex-faisal3, cf-crowns-settings-1105e.
## The existing HUD/pause pages stay owned by their respective agents.

const GOLD := Color("d5ad53")
const CREAM := Color("f7ebcf")
const INK := Color("30281f")
const TABS := ["Gameplay", "Video", "Audio", "Controls", "Accessibility"]
const VIDEO_KEYS := ["window_mode", "window_size", "gfx_quality", "gfx_picked", "vsync_on", "fps_cap", "render_scale"]
const VIDEO_DEFAULTS := {"window_mode": "windowed", "window_size": Vector2i(1280, 720), "gfx_quality": 2,
	"gfx_picked": false, "vsync_on": true, "fps_cap": 0, "render_scale": 1.0}

var game
var category := 0
var draft: Dictionary = {}
var confirmed: Dictionary = {}
var preview_left := 0.0
var binding_action := ""
var binding_device := ""
var binding_frame := -1
var binding_button: Button
var controls_group := 0
var rows: VBoxContainer
var scroll: ScrollContainer
var description: Label
var status: Label
var apply_button: Button
var revert_button: Button
var keep_button: Button
var tabs: Array[Button] = []
var focus_order: Array[Control] = []
var row_controls: Dictionary = {}
var selectors: Dictionary = {}
var stick_dir := Vector2.ZERO
var stick_repeat := 0.0
var active := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	hide()


func _box(fill: Color, border: Color, width := 1, padding := 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(6)
	s.content_margin_left = padding
	s.content_margin_right = padding
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s


func _label(text_value: String, color := CREAM, font_size := 16) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _wood_texture(path: String, edge: int, inset: int) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = load(path)
	style.texture_margin_left = edge
	style.texture_margin_right = edge
	style.texture_margin_top = edge
	style.texture_margin_bottom = edge
	style.content_margin_left = inset
	style.content_margin_right = inset
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


func _button(text_value: String, callback: Callable, hint: String) -> Button:
	var b := Button.new()
	b.text = text_value
	b.custom_minimum_size.y = 36
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", CREAM)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color("908775"))
	b.add_theme_stylebox_override("normal", _wood_texture("res://assets/ui/menu/btn_wood.png", 8, 16))
	b.add_theme_stylebox_override("hover", _wood_texture("res://assets/ui/menu/btn_wood_hi.png", 8, 16))
	b.add_theme_stylebox_override("pressed", _box(Color("62502c"), GOLD, 2))
	b.add_theme_stylebox_override("disabled", _box(Color("252620"), Color("544b39")))
	b.add_theme_stylebox_override("focus", _box(Color(0, 0, 0, 0), Color("ffe395"), 3))
	if callback.is_valid():
		b.pressed.connect(callback)
	b.focus_entered.connect(func(): _describe(hint, b))
	b.mouse_entered.connect(func(): _describe(hint, b, false))
	return b


func _build() -> void:
	var background := ColorRect.new()
	background.color = Color("141d19")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var frame := PanelContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.offset_left = 40
	frame.offset_right = -40
	frame.offset_top = 18
	frame.offset_bottom = -18
	var frame_style := _wood_texture("res://assets/ui/menu/frame_big.png", 32, 28)
	frame_style.content_margin_top = 22
	frame_style.content_margin_bottom = 22
	frame.add_theme_stylebox_override("panel", frame_style)
	add_child(frame)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	frame.add_child(stack)
	var heading := HBoxContainer.new()
	stack.add_child(heading)
	var title_plaque := PanelContainer.new()
	title_plaque.custom_minimum_size = Vector2(300, 50)
	var plaque_style := _wood_texture("res://assets/ui/menu/plaque.png", 70, 64)
	plaque_style.texture_margin_top = 16
	plaque_style.texture_margin_bottom = 16
	title_plaque.add_theme_stylebox_override("panel", plaque_style)
	heading.add_child(title_plaque)
	var title := _label("OPTIONS", CREAM, 32)
	title.add_theme_font_override("font", preload("res://assets/ui/fonts/LilitaOne-Regular.ttf"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_plaque.add_child(title)
	var heading_spacer := Control.new()
	heading_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(heading_spacer)
	heading.add_child(_label("CROWNS OF THE WILDWOOD", GOLD, 13))
	var tab_bar := HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 8)
	stack.add_child(tab_bar)
	for i in TABS.size():
		var b := _button(TABS[i], select_tab.bind(i), "Open %s options. LB / RB or Q / E changes tabs." % TABS[i])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab_bar.add_child(b)
		tabs.append(b)
	var paper := PanelContainer.new()
	paper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	paper.add_theme_stylebox_override("panel", _box(Color("e4d3ad"), Color("9d8050"), 1, 14))
	stack.add_child(paper)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	paper.add_child(scroll)
	rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 6)
	scroll.add_child(rows)
	var desc_frame := PanelContainer.new()
	desc_frame.custom_minimum_size.y = 62
	desc_frame.add_theme_stylebox_override("panel", _box(Color("211f19"), Color("79623d")))
	stack.add_child(desc_frame)
	description = _label("", CREAM, 15)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_frame.add_child(description)
	status = _label("", GOLD, 14)
	status.custom_minimum_size.y = 20
	stack.add_child(status)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	stack.add_child(footer)
	var reset := _button("Reset to defaults", reset_category, "Restore defaults for this tab. Video defaults wait for Apply; account progress is preserved.")
	reset.custom_minimum_size.x = 194
	footer.add_child(reset)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	revert_button = _button("Revert", revert_video, "Discard pending video edits, or restore the last confirmed display during a preview.")
	revert_button.custom_minimum_size.x = 130
	footer.add_child(revert_button)
	apply_button = _button("Apply", apply_video, "Preview video changes for 15 seconds. Keep them to save, or Revert to restore the previous display.")
	apply_button.custom_minimum_size.x = 130
	footer.add_child(apply_button)
	keep_button = _button("Keep changes", keep_video, "Keep and save the previewed video settings.")
	keep_button.custom_minimum_size.x = 160
	footer.add_child(keep_button)
	var close := _button("Back", close_screen, "Return to the previous screen. Unapplied video changes are discarded.")
	close.custom_minimum_size.x = 130
	footer.add_child(close)
	var hint := _label("Arrow keys / D-pad: navigate     Enter / A: select     Esc / B: back     Q E / LB RB: tabs", Color("c9ba98"), 13)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(hint)
	# Footer controls remain in the focus loop after each page's controls.
	for b in [reset, revert_button, apply_button, keep_button, close]:
		b.set_meta("footer", true)
		focus_order.append(b)


func open_screen(initial := 0) -> void:
	active = true
	confirmed = video_snapshot()
	draft = confirmed.duplicate()
	show()
	select_tab(initial)


func close_screen(return_to_pause := true) -> void:
	if preview_left > 0.0:
		revert_video()
	binding_action = ""
	game.rebinding = ""
	active = false
	hide()
	if return_to_pause:
		game.menu_open = game.playing
		if game.playing:
			game.menu_tab = 0
		else:
			game.get_tree().paused = false
	game.swallow_frame = Engine.get_process_frames()
	game.confirm_block = true
	game.click_latched = false
	game.click_was = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)


func video_snapshot() -> Dictionary:
	var data := {}
	for key in VIDEO_KEYS:
		data[key] = game.get(key)
	# Zero means "leave the window alone" in legacy saves. A rollback needs
	# its actual pre-preview size, including a window resized by dragging.
	if data.window_size == Vector2i.ZERO:
		data.window_size = DisplayServer.window_get_size()
		if data.window_size.x < 960 or data.window_size.y < 540:
			data.window_size = Vector2i(1280, 720)
	return data


func _set_video(data: Dictionary) -> void:
	for key in VIDEO_KEYS:
		game.set(key, data[key])
	game.fullscreen = game.window_mode != "windowed"
	game._window_size_dirty = game.window_size != Vector2i.ZERO
	game.apply_graphics()


func apply_video() -> void:
	if draft == confirmed or preview_left > 0.0:
		return
	_set_video(draft)
	preview_left = 15.0
	_update_footer()
	keep_button.grab_focus()


func keep_video() -> void:
	if preview_left <= 0.0:
		return
	confirmed = draft.duplicate()
	preview_left = 0.0
	game._save_settings()
	_update_footer()
	if category == 1:
		tabs[1].grab_focus()


func revert_video() -> void:
	if preview_left > 0.0:
		_set_video(confirmed)
	preview_left = 0.0
	draft = confirmed.duplicate()
	select_tab(category)


func _process(delta: float) -> void:
	if not active:
		return
	if preview_left > 0.0:
		preview_left -= delta
		if preview_left <= 0.0:
			# Use a positive sentinel so Revert applies the confirmed state.
			preview_left = 0.001
			revert_video()
		_update_footer()
	stick_repeat -= delta
	if stick_dir != Vector2.ZERO and stick_repeat <= 0.0 and binding_action == "":
		_navigate(stick_dir)
		stick_repeat = 0.22


func _update_footer() -> void:
	var video := category == 1
	apply_button.visible = video and preview_left <= 0.0
	apply_button.disabled = draft == confirmed
	revert_button.visible = video or preview_left > 0.0
	revert_button.disabled = draft == confirmed and preview_left <= 0.0
	keep_button.visible = preview_left > 0.0
	if preview_left > 0.0:
		status.text = "Keep this display? Reverting in %d seconds." % ceili(preview_left)
	elif draft != confirmed:
		status.text = "Video changes pending - Apply to preview, or Revert to discard."
	else:
		status.text = "Video changes use Apply. Other options save automatically."


func select_tab(index: int) -> void:
	if preview_left > 0.0 and index != 1:
		description.text = "Keep or Revert the video preview before changing tabs."
		return
	if binding_action != "":
		_cancel_binding()
	category = posmod(index, TABS.size())
	for node in rows.get_children():
		rows.remove_child(node)
		node.queue_free()
	row_controls.clear()
	selectors.clear()
	focus_order = focus_order.filter(func(c): return is_instance_valid(c) and c.has_meta("footer"))
	for i in tabs.size():
		tabs[i].add_theme_stylebox_override("normal", _wood_texture("res://assets/ui/menu/btn_wood_hi.png" if category == i else "res://assets/ui/menu/btn_wood.png", 8, 16))
	match category:
		0: _gameplay()
		1: _video()
		2: _audio()
		3: _controls()
		4: _accessibility()
	scroll.scroll_vertical = 0
	_update_footer()
	if not row_controls.is_empty():
		var first: Control = row_controls.values()[0]
		first.call_deferred("grab_focus")


func _describe(hint: String, control: Control, ensure := true) -> void:
	description.text = hint
	if ensure and control.is_inside_tree() and rows.is_ancestor_of(control):
		scroll.ensure_control_visible(control)


func _row(key: String, title: String, control: Control, hint: String) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 44
	panel.add_theme_stylebox_override("panel", _box(Color("f0e2c2"), Color("c8b38a"), 1))
	rows.add_child(panel)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 24)
	panel.add_child(line)
	var label := _label(title, INK, 17)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(label)
	control.custom_minimum_size.x = 340
	line.add_child(control)
	panel.mouse_entered.connect(func(): _describe(hint, control, false))
	row_controls[key] = control
	_mark_row_focus(panel, control)
	if control.focus_mode != Control.FOCUS_NONE:
		focus_order.insert(focus_order.size() - 5, control)
		control.focus_entered.connect(func(): _describe(hint, control))


func _mark_row_focus(panel: PanelContainer, control: Control) -> void:
	if control.focus_mode != Control.FOCUS_NONE:
		control.focus_entered.connect(func(): panel.add_theme_stylebox_override("panel", _box(Color("fff0c9"), Color("8c6425"), 2)))
		control.focus_exited.connect(func(): panel.add_theme_stylebox_override("panel", _box(Color("f0e2c2"), Color("c8b38a"), 1)))
	for child in control.get_children():
		if child is Control:
			_mark_row_focus(panel, child)


func _choice(key: String, title: String, values: Array, labels: Array, current, changed: Callable, hint: String) -> void:
	var b := _button("", func():
		var direction: int = selectors[key].button.get_meta("step_direction", 1)
		selectors[key].button.set_meta("step_direction", 1)
		_step_choice(key, direction), hint)
	selectors[key] = {"button": b, "values": values, "labels": labels, "index": maxi(values.find(current), 0), "changed": changed}
	b.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			b.set_meta("step_direction", -1 if event.position.x < 44.0 else 1))
	b.text = "<   %s   >" % labels[selectors[key].index]
	_row(key, title, b, hint)


func _step_choice(key: String, direction: int) -> void:
	if preview_left > 0.0 and category == 1:
		return
	var data: Dictionary = selectors[key]
	data.index = posmod(data.index + direction, data.values.size())
	data.button.text = "<   %s   >" % data.labels[data.index]
	data.changed.call(data.values[data.index])
	_update_footer()


func _toggle(key: String, title: String, property: String, hint: String) -> void:
	_choice(key, title, [false, true], ["Off", "On"], game.get(property), func(v):
		if game.get(property) != v:
			game.toggle_setting(key), hint)


func _gameplay() -> void:
	_choice("difficulty", "Bot difficulty", ["Easy", "Normal", "Hard"], ["Easy", "Normal", "Hard"], game.bot_difficulty, func(v):
		game.bot_difficulty = v
		game._save_settings(), "Bot difficulty: Easy is forgiving; Normal is a fair fight; Hard uses stronger tactics.")
	_toggle("tips", "Gameplay tips", "tips_on", "Show contextual tips while learning the game.")
	_toggle("chat", "Chat log", "chat_visible", "Show the match chat log. Team calls can be rebound on the Controls tab.")
	_toggle("rosters", "Player rosters", "rosters_visible", "Show your team's player roster during a match.")
	_choice("split", "Split-screen layout", ["vertical", "horizontal"], ["Side by side", "Top and bottom"], game.split_layout, func(v):
		game.set_split_layout(v)
		game._save_settings(), "Choose how two local players share the screen. Each player keeps their own camera.")


func _video() -> void:
	_choice("window_mode", "Display mode", ["windowed", "borderless", "exclusive"], ["Windowed", "Borderless", "Fullscreen"], draft.window_mode, func(v): draft.window_mode = v,
		"Windowed uses the selected size. Borderless and Fullscreen use your display's native resolution.")
	var sizes: Array = game._window_sizes()
	var current: Vector2i = draft.window_size if draft.window_size != Vector2i.ZERO else DisplayServer.window_get_size()
	if current not in sizes:
		sizes.append(current)
	var names: Array = []
	for s in sizes:
		names.append("%d x %d" % [s.x, s.y])
	_choice("window_size", "Window resolution", sizes, names, current, func(v): draft.window_size = v,
		"Windowed mode only. Choose a size that fits this display; the interface stays sharp at every size.")
	_choice("gfx_quality", "Quality preset", [-1, 0, 1, 2, 3], ["Auto-detect", "Low", "Medium", "High", "Ultra"], draft.gfx_quality if draft.gfx_picked else -1, func(v):
		draft.gfx_picked = v >= 0
		draft.gfx_quality = maxi(v, 0) if v >= 0 else (2 if RenderingServer.get_video_adapter_type() == RenderingDevice.DEVICE_TYPE_DISCRETE_GPU else 0),
		"Auto-detect adapts to your graphics hardware. Low favours speed; Ultra favours lighting and shadows.")
	_choice("vsync_on", "Vertical sync", [false, true], ["Off", "On"], draft.vsync_on, func(v): draft.vsync_on = v,
		"Synchronize frames with the display to prevent screen tearing.")
	_choice("fps_cap", "Frame-rate limit", [0, 30, 60, 120, 144, 240], ["Unlimited", "30 FPS", "60 FPS", "120 FPS", "144 FPS", "240 FPS"], draft.fps_cap, func(v): draft.fps_cap = v,
		"Limit the frame rate to reduce heat and power use. Vertical sync may impose a lower limit.")
	_choice("render_scale", "3D render scale", [1.0, 0.85, 0.75, 0.5], ["100%", "85%", "75%", "50%"], draft.render_scale, func(v): draft.render_scale = v,
		"Lower the 3D rendering resolution for better performance. Menus and text remain full resolution.")


func _audio() -> void:
	_volume("master", "Master volume", "master_volume", "Overall volume for music, effects and ambience. Default: 80%.")
	_volume("music", "Music volume", "music_volume", "Music volume relative to Master. Default: 60%.")
	_volume("sound", "Sound effects volume", "sound_volume", "Sound effects and ambience relative to Master. Default: 80%.")
	_row("test", "Preview sound", _button("Play test sound", func(): game.sfx.ui("ui_open", 0.0), "Play a sound at the current Master and Sound Effects levels."), "Play a sound at the current Master and Sound Effects levels.")


func _volume(key: String, title: String, property: String, hint: String) -> void:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 16)
	var slider := HSlider.new()
	slider.custom_minimum_size = Vector2(258, 34)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.value = roundi(game.sfx.get(property) * 100.0)
	slider.add_theme_stylebox_override("slider", _box(Color("746445"), Color("746445"), 0, 0))
	slider.add_theme_stylebox_override("grabber_area", _box(Color("ad822f"), GOLD, 0, 0))
	slider.add_theme_stylebox_override("grabber_area_highlight", _box(Color("c99630"), GOLD, 0, 0))
	slider.add_theme_stylebox_override("focus", _box(Color(0, 0, 0, 0), Color("755018"), 3, 0))
	line.add_child(slider)
	var value := _label("%d%%" % slider.value, INK, 17)
	value.custom_minimum_size.x = 64
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	line.add_child(value)
	slider.set_meta("dragging", false)
	slider.drag_started.connect(func(): slider.set_meta("dragging", true))
	slider.value_changed.connect(func(v):
		game.sfx.set(property, float(v) / 100.0)
		game.sfx.apply_volumes()
		value.text = "%d%%" % roundi(v)
		# Mouse drags save on release, key/pad increments save immediately.
		if not slider.get_meta("dragging", false):
			game._save_settings())
	slider.drag_ended.connect(func(_changed):
		slider.set_meta("dragging", false)
		game._save_settings())
	slider.focus_entered.connect(func(): _describe(hint, slider))
	_row(key, title, line, hint)
	row_controls[key] = slider
	focus_order.insert(focus_order.size() - 5, slider)


func _controls() -> void:
	var groups := ["Movement", "Combat", "Team and menus"]
	_choice("group", "Bindings group", [0, 1, 2], groups, controls_group, func(v):
		controls_group = v
		select_tab(3), "Choose a binding group. Each action has separate Keyboard / Mouse and Gamepad buttons.")
	if controls_group == 0:
		_choice("pc", "PC movement", ["click", "wasd"], ["Click to move", "WASD"], game.pc_movement, func(v):
			game.pc_movement = v
			game._save_settings(), "Click moves or interacts; WASD follows the camera. Shift holds position for attacks.")
		_toggle("combine", "Combine movement and attack", "combine_move_attack", "Allow move / interact clicks to use basic attacks. Off keeps those actions separate.")
		_toggle("wheel", "Mouse-wheel zoom", "wheel_zoom", "Use the mouse wheel to zoom. Turn off to use wheel bindings for Force Move.")
	elif controls_group == 2:
		_choice("pad_style", "Controller button names", ["auto", "xbox", "ps", "switch"], ["Auto", "Xbox", "PlayStation", "Nintendo"], game.pad_style, func(v):
			game.pad_style = v
			game._save_settings()
			select_tab(3)
			row_controls.pad_style.call_deferred("grab_focus"), "Choose the button labels shown in prompts; Auto follows the connected controller.")
		_choice("layout", "Control layout", ["auto", "keyboard", "controller", "touch"], ["Auto", "Keyboard and mouse", "Controller", "Touch"], game.control_layout, func(v):
			game.control_layout = v
			game.apply_control_layout()
			game._save_settings(), "Auto follows the last input used. A fixed layout keeps its prompts visible.")
	var movement := ["move_interact", "force_move", "force_hold", "move_up", "move_down", "move_left", "move_right"]
	var combat := ["attack", "block", "ability_1", "ability_2", "ability_3", "dodge", "interact"]
	for entry in game.REBINDABLE:
		var group := 0 if entry[0] in movement else (1 if entry[0] in combat else 2)
		if group != controls_group:
			continue
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 8)
		for device in ["key", "pad"]:
			var hint := "Rebind %s for %s. Press a new key, mouse button, pad button or trigger. Escape cancels; conflicts swap bindings." % [entry[1], "Keyboard / Mouse" if device == "key" else "Gamepad"]
			var text_value: String = game.binding_text(entry[0], device)
			var b := _button(("Key: " if device == "key" else "Pad: ") + ("Unbound" if text_value == "-" else text_value), Callable(), hint)
			b.custom_minimum_size.x = 166
			b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			b.add_theme_font_size_override("font_size", 14)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.pressed.connect(_begin_binding.bind(entry[0], device, b))
			line.add_child(b)
			focus_order.insert(focus_order.size() - 5, b)
		_row(entry[0], entry[1], line, "Choose Key or Pad to rebind this action. Unbound actions can be assigned here; left and right sticks retain camera-relative movement and aim.")
		row_controls[entry[0]] = line.get_child(0)


func _accessibility() -> void:
	_toggle("shake", "Screen shake", "screen_shake", "Turn off camera shake from hits and explosions for a steadier view.")
	_toggle("numbers", "Damage numbers", "damage_numbers", "Show floating damage numbers during combat.")
	_toggle("rumble", "Controller vibration", "rumble_on", "Enable controller vibration for hits, deaths and captures.")
	_toggle("fps", "FPS counter", "show_fps", "Show the frame-rate counter to help tune performance.")


func reset_category() -> void:
	match category:
		0:
			game.bot_difficulty = "Normal"
			game.tips_on = true
			game.tips_done = false
			game.chat_visible = true
			game.rosters_visible = false
			game.set_split_layout("vertical")
		1:
			if preview_left > 0.0:
				revert_video()
			draft = VIDEO_DEFAULTS.duplicate()
			draft.gfx_quality = 2 if RenderingServer.get_video_adapter_type() == RenderingDevice.DEVICE_TYPE_DISCRETE_GPU else 0
		2:
			game.sfx.master_volume = 0.8
			game.sfx.music_volume = 0.6
			game.sfx.sound_volume = 0.8
			game.sfx.apply_volumes()
		3:
			game._reset_controls()
			game.pc_movement = "click"
			game.combine_move_attack = false
			game.wheel_zoom = false
			game.pad_style = "auto"
			game.control_layout = "auto"
			game.apply_control_layout()
		4:
			game.screen_shake = true
			game.damage_numbers = true
			game.rumble_on = true
			game.show_fps = false
	if category != 1:
		game._save_settings()
	select_tab(category)


func _begin_binding(action: String, device: String, button: Button) -> void:
	binding_action = action
	binding_device = device
	binding_button = button
	binding_frame = Engine.get_process_frames()
	game.rebinding = action
	button.text = "Press input..."
	description.text = "Rebinding %s: %s. Escape cancels. A binding in use swaps with this action's previous binding." % [game._action_label(action), "press a key or mouse button" if device == "key" else "press a pad button or trigger"]


func _cancel_binding() -> void:
	binding_action = ""
	game.rebinding = ""


func handle_input(event: InputEvent) -> bool:
	if not active:
		return false
	if binding_action != "":
		if Engine.get_process_frames() == binding_frame:
			return true
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			_cancel_binding()
			select_tab(3)
			return true
		var accepted := (binding_device == "key" and (event is InputEventKey or event is InputEventMouseButton) and event.pressed) \
			or (binding_device == "pad" and (event is InputEventJoypadButton and event.pressed or game._is_trigger(event) and event.axis_value > 0.6))
		if accepted and not (event is InputEventKey and event.echo):
			var action := binding_action
			var device := binding_device
			game._rebind(action, event)
			_cancel_binding()
			select_tab(3)
			if row_controls.has(action):
				var target: Control = row_controls[action]
				if device == "pad":
					target = target.get_parent().get_child(1)
				target.call_deferred("grab_focus")
		return true
	if event is InputEventJoypadMotion and event.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		if event.axis == JOY_AXIS_LEFT_X:
			stick_dir.x = signf(event.axis_value) if absf(event.axis_value) > 0.65 else 0.0
		else:
			stick_dir.y = signf(event.axis_value) if absf(event.axis_value) > 0.65 else 0.0
		return true
	var code := 0
	if event is InputEventKey and event.pressed:
		code = event.keycode
	elif event is InputEventJoypadButton and event.pressed:
		code = {JOY_BUTTON_DPAD_UP: KEY_UP, JOY_BUTTON_DPAD_DOWN: KEY_DOWN, JOY_BUTTON_DPAD_LEFT: KEY_LEFT, JOY_BUTTON_DPAD_RIGHT: KEY_RIGHT,
			JOY_BUTTON_A: KEY_ENTER, JOY_BUTTON_B: KEY_ESCAPE, JOY_BUTTON_LEFT_SHOULDER: KEY_Q, JOY_BUTTON_RIGHT_SHOULDER: KEY_E}.get(event.button_index, 0)
	match code:
		KEY_ESCAPE:
			if preview_left > 0.0:
				revert_video()
			else:
				close_screen()
		KEY_Q: select_tab(category - 1)
		KEY_E: select_tab(category + 1)
		KEY_UP: _navigate(Vector2.UP)
		KEY_DOWN: _navigate(Vector2.DOWN)
		KEY_LEFT: _navigate(Vector2.LEFT)
		KEY_RIGHT: _navigate(Vector2.RIGHT)
		KEY_TAB: _focus_step(-1 if event is InputEventKey and event.shift_pressed else 1, true)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			var focused := get_viewport().gui_get_focus_owner()
			if focused is Button:
				focused.pressed.emit()
		_: return event is InputEventJoypadButton or event is InputEventKey
	return true


func _focus_step(direction: int, include_tabs := false) -> void:
	var available: Array[Control] = []
	if include_tabs:
		available.append_array(tabs)
	for c in focus_order:
		if is_instance_valid(c) and c.is_visible_in_tree() and not (c is BaseButton and c.disabled):
			available.append(c)
	if available.is_empty():
		return
	var focused := get_viewport().gui_get_focus_owner()
	var index := available.find(focused)
	available[posmod(index + direction, available.size())].grab_focus()


func _navigate(direction: Vector2) -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if absf(direction.y) > 0.0:
		_focus_step(int(signf(direction.y)))
	elif focused is HSlider:
		focused.value = clampf(focused.value + 1.0 * direction.x, 0.0, 100.0)
	else:
		for key in selectors:
			if selectors[key].button == focused:
				_step_choice(key, int(direction.x))
				return
		if focused in tabs:
			select_tab(category + int(direction.x))
		else:
			# In binding rows, Left / Right chooses Key / Pad.
			_focus_step(int(direction.x))
