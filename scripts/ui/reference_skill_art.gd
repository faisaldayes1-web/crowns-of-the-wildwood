# Agent: Codex-faisal/build_delivery. EXTERNAL proposal, not native-qualified.
# Artwork only: never reads Input, changes a Unit, consumes energy or dispatches actions.
# The existing HUD remains the owner of timers, local seat, labels, hit rects and baking.
extends RefCounted

const ORB_PATH := "res://assets/ui/skill_reference/orb-border.png"
const FACES_PATH := "res://assets/ui/skill_reference/owner-six-orbs.jpg"
const LEAVES_PATH := "res://assets/ui/skill_reference/owner-six-frame-original.png"
const FRAME_SHADER_PATH := "res://scripts/ui/skill_frame_key.gdshader"
# The supplied JPEG's circles only. Keycaps/names/background are outside these disks.
const FACE_CENTERS := [Vector2(127, 327), Vector2(333, 327), Vector2(538, 327),
	Vector2(742, 327), Vector2(949, 327), Vector2(1155, 327)]
const FACE_RADIUS := 62.0
# Registration for the supplied unmodified transparent 1024x1024 orb-border.png.
const ORB_CENTER := Vector2(508, 486)
const ORB_HOLE_RADIUS := 320.0
const STRIP_CENTERS := [Vector2(200, 204), Vector2(532, 200), Vector2(866, 198),
	Vector2(1194, 198), Vector2(1530, 202), Vector2(1850, 206)]
static var _textures: Dictionary = {}


static func _texture(path: String) -> Texture2D:
	if not _textures.has(path):
		_textures[path] = load(path) if ResourceLoader.exists(path) else null
	return _textures[path] as Texture2D


static func circle_points(center: Vector2, radius: float, count: int = 64) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in count:
		var angle := -PI / 2.0 + TAU * float(i) / float(count)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points


static func _disk(hud, texture: Texture2D, source_center: Vector2, source_radius: float,
		center: Vector2, radius: float, modulation: Color) -> void:
	var points := circle_points(center, radius)
	var uv := PackedVector2Array()
	for point in points:
		uv.append((source_center + (point - center) * source_radius / radius) / texture.get_size())
	hud.draw_colored_polygon(points, modulation, uv, texture)


static func hide_frame(hud) -> void:
	if is_instance_valid(hud._reference_frame_node):
		hud._reference_frame_node.visible = false


static func draw_strip(hud, strip: Rect2) -> bool:
	# Exact original owner PNG. Key material belongs ONLY to this child, never the HUD.
	var texture := _texture(LEAVES_PATH)
	if texture == null or texture.get_size() != Vector2(2048, 460):
		return false
	if not is_instance_valid(hud._reference_frame_node):
		var shader := load(FRAME_SHADER_PATH) as Shader
		if shader == null:
			return false
		# One material owned solely by this child, never a static lifetime root.
		var material := ShaderMaterial.new()
		material.shader = shader
		var child := TextureRect.new()
		child.name = "Owner reference skill frame"
		child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		child.show_behind_parent = true
		child.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		child.stretch_mode = TextureRect.STRETCH_SCALE
		child.texture = texture
		child.material = material
		hud.add_child(child)
		hud._reference_frame_node = child
	var frame: TextureRect = hud._reference_frame_node
	# draw_set_transform applies to CanvasItem commands, not child Control positions.
	frame.position = strip.position * hud.hud_scale
	frame.size = Vector2(strip.size.x, strip.size.x * 460.0 / 2048.0) * hud.hud_scale
	frame.visible = true
	return true


static func row_origins(strip: Rect2, size_px: float) -> Array:
	var origins := []
	for center in STRIP_CENTERS:
		origins.append(strip.position + center * (strip.size.x / 2048.0) - Vector2.ONE * size_px * 0.5)
	return origins


static func draw_face(hud, rect: Rect2, icon: String, color: Color, frame: Color,
		locked: bool, ready: bool, connected_frame: bool) -> void:
	var center := rect.get_center()
	var radius := rect.size.x * 0.5
	hud.draw_circle(center + Vector2(0, 3), radius + 4.0, Color(0, 0, 0, 0.45))
	var tint := Color.WHITE if (ready or locked) else Color(0.45, 0.45, 0.5)
	var face_index := -1
	if locked:
		face_index = 2
	elif icon == "fist":
		face_index = 0
	elif icon == "dodge":
		face_index = 1
	elif icon == "vigor":
		face_index = 4
	elif icon == "crown":
		face_index = 5
	var faces := _texture(FACES_PATH)
	if faces != null and face_index >= 0:
		_disk(hud, faces, FACE_CENTERS[face_index], FACE_RADIUS, center, radius, tint)
	else:
		# Real unlocked class moves keep their actual existing icon, never a painted lock.
		hud.draw_circle(center, radius, color if ready else color.darkened(0.4))
		hud.draw_circle(center + Vector2(0, -radius * 0.18), radius * 0.78, Color(1, 1, 1, 0.09))
		if locked:
			hud._padlock(center, radius * 0.55, Color(0.72, 0.7, 0.78))
		elif hud.clean_icons.has(icon):
			var texture: Texture2D = hud.clean_icons[icon]
			_disk(hud, texture, texture.get_size() * 0.5, minf(texture.get_width(), texture.get_height()) * 0.5,
				center, radius * 0.82, tint)
		else:
			hud._icon(icon, center, rect.size.x * 0.3, Color.WHITE, not ready)
	if not connected_frame:
		var orb := _texture(ORB_PATH)
		if orb != null:
			var scale := radius / ORB_HOLE_RADIUS
			hud.draw_texture_rect(orb, Rect2(center - ORB_CENTER * scale, orb.get_size() * scale), false)
		else:
			# Missing art remains visibly provisional; this is not the exact-design acceptance path.
			hud.draw_arc(center, radius + 2.0, 0, TAU, 64, frame, 4.0, true)
	# Preserve the existing block-active/upgrade/lock frame state over the supplied gold art.
	hud.draw_arc(center, radius - 0.7, 0, TAU, 64, frame, 1.4, true)


static func draw_cooldown(hud, center: Vector2, radius: float, remaining_fraction: float) -> void:
	# Clockwise radial sweep from12 o'clock. This is live Unit state, not painted numbers.
	var fraction := clampf(remaining_fraction, 0.0, 1.0)
	if fraction <= 0.0:
		return
	if fraction >= 0.999999:
		hud.draw_circle(center, radius, Color(0, 0, 0, 0.65))
		return
	var pieces := maxi(1, ceili(64.0 * fraction))
	# One simple (possibly concave) sector polygon, not64 separate draw commands.
	var points := PackedVector2Array([center])
	for i in range(pieces + 1):
		var angle := -PI / 2.0 + TAU * fraction * float(i) / float(pieces)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	hud.draw_colored_polygon(points, Color(0, 0, 0, 0.65))
