extends Node3D
## The main menu's 3D backdrop. The title looks at a battle scene built
## after the game's key art (title_diorama.gd); the other screens (Select Map, Create Your Character, Ready Up) are shot in a
## torch-lit castle hall built off the edge of the map, with the hero and
## the lobby's fighters standing in it on glowing pedestals.
##
## Characters are placed from screen positions (see `_floor_at`), so they
## line up with the 2D menu whatever the window size.

const Stats = preload("res://scripts/stats.gd")
const CharacterModel = preload("res://scripts/character_model.gd")
const TitleDiorama = preload("res://scripts/title_diorama.gd")
const Role = Stats.Role

const HALL := Vector3(0, 0, 420)   # far past the map's south edge
# Player colours for the lobby's P1-P4 tags and pedestal glows.
const SLOT_COLORS := [Color(0.2, 0.45, 1.0), Color(0.95, 0.22, 0.2), Color(0.25, 0.85, 0.3), Color(1.0, 0.8, 0.15)]

var game
var cam: Camera3D
var hall: Node3D
var title_cast: Node3D       # the battle scene behind the title (title_diorama.gd)
var hero: Node3D             # the character creator's model
var hero_key := ""
var lobby_models: Array = [null, null, null, null]
var lobby_keys: Array = ["", "", "", ""]
var pedestals: Array = []    # [node, ring material, light] per lobby slot
var screen := ""
var t := 0.0
var hidden_labels: Array = []


func _exit_tree() -> void:
	for l in hidden_labels:
		if is_instance_valid(l):
			l.visible = true


func _flame(pos: Vector3, out: Vector3) -> void:
	## A lit flame over a wall torch: a bright core in a soft orange glow.
	var top := pos + out * 0.5 + Vector3(0, 0.98, 0)
	game._add_flame(top, 0.17, Color(1.0, 0.5, 0.12))
	game._add_flame(top + Vector3(0, 0.1, 0), 0.09, Color(1.0, 0.92, 0.55))


func build(g) -> void:
	game = g
	cam = Camera3D.new()
	cam.fov = 40.0
	add_child(cam)
	hall = Node3D.new()
	add_child(hall)
	_build_hall()
	title_cast = TitleDiorama.new()
	add_child(title_cast)
	title_cast.build(game)


func activate() -> void:
	cam.make_current()


func _process(delta: float) -> void:
	t += delta
	if screen == "lobby":
		for i in pedestals.size():
			# A slow pulse in each pedestal's ring.
			var p: Array = pedestals[i]
			p[1].emission_energy_multiplier = 1.6 + sin(t * 2.4 + i) * 0.4


# --- Camera shots ----------------------------------------------------------------

func show_screen(name: String) -> void:
	if name == screen:
		return
	screen = name
	title_cast.visible = name == "title"
	match name:
		"title":
			# Across the stream at the castle and its crown, the two armies either side.
			cam.fov = TitleDiorama.CAM_FOV
			var from: Vector3 = TitleDiorama.ORIGIN + TitleDiorama.CAM_FROM
			var to: Vector3 = TitleDiorama.ORIGIN + TitleDiorama.CAM_AT
			for arg in OS.get_cmdline_user_args():
				if arg.begins_with("--debug-title-cam="):  # testing: x,y,z,look x,y,z (relative to the scene)
					var v := arg.trim_prefix("--debug-title-cam=").split(",")
					from = TitleDiorama.ORIGIN + Vector3(float(v[0]), float(v[1]), float(v[2]))
					to = TitleDiorama.ORIGIN + Vector3(float(v[3]), float(v[4]), float(v[5]))
				if arg.begins_with("--debug-title-fov="):
					cam.fov = float(arg.trim_prefix("--debug-title-fov="))
			cam.global_position = from
			cam.look_at(to)
		"map":
			cam.fov = 50.0
			cam.global_position = HALL + Vector3(0, 2.4, 8.5)
			cam.look_at(HALL + Vector3(0, 2.6, -6.0))
		"character":
			cam.fov = 40.0
			cam.global_position = HALL + Vector3(0.6, 1.55, 6.2)
			cam.look_at(HALL + Vector3(0.6, 1.25, 0.0))
		"lobby":
			cam.fov = 40.0
			cam.global_position = HALL + Vector3(0, 2.2, 11.2)
			cam.look_at(HALL + Vector3(0, 1.35, 0.0))
	if hero:
		hero.visible = name == "character"
	for i in 4:
		if lobby_models[i]:
			lobby_models[i].visible = name == "lobby"
		if i < pedestals.size():
			pedestals[i][0].visible = name == "lobby"


func _floor_at(frac: Vector2, y: float = 0.0) -> Vector3:
	## The point on the floor (height y) seen at this fraction of the screen.
	var vp := get_viewport().get_visible_rect().size
	var p := frac * vp
	var o := cam.project_ray_origin(p)
	var d := cam.project_ray_normal(p)
	if absf(d.y) < 0.001:
		return o + d * 6.0
	var k := (y - o.y) / d.y
	return o + d * k


# --- The hero (character creator) --------------------------------------------------

func show_hero(team: int, role: int, custom: Dictionary, rank: int) -> void:
	## Rebuild the creator's model when a choice changes.
	var key := "%d|%d|%s|%d" % [team, role, str(custom), rank]
	if key != hero_key:
		hero_key = key
		if hero:
			hero.queue_free()
		hero = CharacterModel.new()
		add_child(hero)
		hero.setup(team, role, "", custom, rank)
		hero.scale = Vector3.ONE * 1.0
	hero.visible = screen == "character"
	hero.global_position = _floor_at(Vector2(0.39, 0.86))
	hero.rotation.y = PI + 0.32 + sin(t * 0.6) * 0.05  # turned a little toward the panel


# --- The lobby ------------------------------------------------------------------------

func show_lobby(slots: Array) -> void:
	## slots: up to four {team, role, custom, rank, empty, color} entries.
	if pedestals.is_empty():
		for i in 4:
			pedestals.append(_make_pedestal(SLOT_COLORS[i]))
	for i in 4:
		var s: Dictionary = slots[i] if i < slots.size() else {"empty": true}
		var frac := Vector2(0.15 + i * 0.233, 0.672)
		var pos := _floor_at(frac)
		var ped: Array = pedestals[i]
		ped[0].global_position = pos
		ped[0].visible = screen == "lobby"
		var col: Color = s.get("color", SLOT_COLORS[i])
		var empty: bool = s.get("empty", false)
		ped[1].albedo_color = (col if not empty else Color(0.4, 0.4, 0.45)).darkened(0.2)
		ped[1].emission = col if not empty else Color(0.3, 0.3, 0.35)
		ped[2].light_color = col
		ped[2].light_energy = 0.0 if empty else 1.6
		var key := "" if empty else "%d|%d|%s|%d" % [s.team, s.role, str(s.get("custom", {})), s.get("rank", 1)]
		if key != lobby_keys[i]:
			lobby_keys[i] = key
			if lobby_models[i]:
				lobby_models[i].queue_free()
				lobby_models[i] = null
			if key != "":
				var m = CharacterModel.new()
				add_child(m)
				m.setup(s.team, s.role, "", s.get("custom", {}), s.get("rank", 1))
				lobby_models[i] = m
				if s.get("cheer", false):
					m.play_once("Cheer")
		if lobby_models[i]:
			lobby_models[i].visible = screen == "lobby"
			lobby_models[i].global_position = pos + Vector3(0, 0.22, 0)
			lobby_models[i].rotation.y = PI + (pos.x - cam.global_position.x) * -0.05


func cheer(i: int) -> void:
	if i < lobby_models.size() and lobby_models[i]:
		lobby_models[i].play_once("Cheer")


func _make_pedestal(color: Color) -> Array:
	## A round stone dais with a glowing ring in the player's colour.
	var root := Node3D.new()
	add_child(root)
	var base := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.95
	cyl.bottom_radius = 1.05
	cyl.height = 0.22
	base.mesh = cyl
	base.material_override = game._stone(Color(0.8, 0.78, 0.74), 0.5)
	base.position.y = 0.11
	root.add_child(base)
	var ring := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.82
	tor.outer_radius = 0.95
	ring.mesh = tor
	var rm := StandardMaterial3D.new()
	rm.albedo_color = color.darkened(0.2)
	rm.emission_enabled = true
	rm.emission = color
	rm.emission_energy_multiplier = 1.8
	ring.material_override = rm
	ring.position.y = 0.2
	ring.scale = Vector3(1, 0.4, 1)
	root.add_child(ring)
	# A soft disc of light on the dais top.
	var disc := MeshInstance3D.new()
	var dm := CylinderMesh.new()
	dm.top_radius = 0.8
	dm.bottom_radius = 0.8
	dm.height = 0.01
	disc.mesh = dm
	disc.material_override = rm
	disc.position.y = 0.225
	disc.transparency = 0.55
	root.add_child(disc)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 1.6
	light.omni_range = 3.2
	light.position.y = 0.7
	root.add_child(light)
	root.visible = false
	return [root, rm, light]


# --- The title's battle scene ------------------------------------------------------

func place_title_cast() -> void:
	if title_cast.visible:
		title_cast.place_heroes(cam, get_viewport().get_visible_rect().size)


# --- The hall ----------------------------------------------------------------------------

func _build_hall() -> void:
	## Stone walls, a flagstone floor, timber beams, blue lion banners, torches,
	## barrels and crates. Built with the world's own helpers, then moved here.
	var before: int = game.get_child_count()
	var was_mossy: bool = game.mossy
	game.mossy = false
	var c := HALL
	# Grey castle stone (the greystone texture where the art pass has made it).
	var stone: Material = game._pbr("greystone", 0.3, Color(0.95, 0.92, 0.9)) if ResourceLoader.exists("res://assets/textures/greystone_color.jpg") \
		else game._stone(Color(0.7, 0.7, 0.78), 0.3)
	var floor_mat: Material = game._flagstone(Color(0.95, 0.88, 0.78))
	game._add_block(c + Vector3(0, -0.1, 0), Vector3(30, 0.2, 24), Color.GRAY, false, floor_mat)
	# Back wall, side walls angled in a little, and a dark ceiling to keep the sky out.
	game._add_block(c + Vector3(0, 4.5, -6.5), Vector3(30, 9, 1.0), Color.GRAY, false, stone)
	for s in [-1.0, 1.0]:
		game._add_block(c + Vector3(s * 11.0, 4.5, 2.0), Vector3(1.0, 9, 18), Color.GRAY, false, stone)
	game._add_block(c + Vector3(0, 9.2, 0), Vector3(30, 0.4, 24), Color.GRAY, false, game._plank_dark())
	# Timber posts and a beam along the back wall.
	var timber: Material = game._timber(Color(0.75, 0.6, 0.45))
	for x in [-8.5, -3.2, 3.2, 8.5]:
		game._add_block(c + Vector3(x, 3.5, -5.8), Vector3(0.5, 7.0, 0.5), Color.GRAY, false, timber)
	game._add_block(c + Vector3(0, 6.9, -5.8), Vector3(22, 0.5, 0.6), Color.GRAY, false, timber)
	for s in [-1.0, 1.0]:
		game._add_block(c + Vector3(s * 10.3, 6.9, 1.0), Vector3(0.6, 0.5, 15), Color.GRAY, false, timber)
	# Blue banners with the kingdom crest between the posts, one on each side wall.
	for x in [-5.85, 0.0, 5.85]:
		game._add_tapestry(1, c + Vector3(x, 2.2, -6.0), Vector3(0, 0, 1), 1.7, 3.6)
	for s in [-1.0, 1.0]:
		game._add_tapestry(1, c + Vector3(s * 10.5, 2.0, -1.0), Vector3(-s, 0, 0), 1.5, 3.2)
		game._add_tapestry(1, c + Vector3(s * 10.5, 2.0, 4.0), Vector3(-s, 0, 0), 1.5, 3.2)
	# Torches on the posts.
	for x in [-8.5, -3.2, 3.2, 8.5]:
		game._add_wall_torch(c + Vector3(x, 2.4, -5.5), Vector3(0, 0, 1))
		_flame(c + Vector3(x, 2.4, -5.5), Vector3(0, 0, 1))
	for s in [-1.0, 1.0]:
		game._add_wall_torch(c + Vector3(s * 10.45, 2.4, 1.5), Vector3(-s, 0, 0))
		_flame(c + Vector3(s * 10.45, 2.4, 1.5), Vector3(-s, 0, 0))
	# Fire bowls either side of the middle (they flank the SELECT MAP panel).
	for s in [-1.0, 1.0]:
		game._add_brazier(c + Vector3(s * 6.4, 0, 1.2))
	# Warm fill so the hall reads bright and friendly, not a dungeon.
	game._add_light(c + Vector3(0, 5.5, 3.0), Color(1.0, 0.82, 0.62), 2.2, 18.0)
	game._add_light(c + Vector3(-6, 3.0, -3.0), Color(1.0, 0.7, 0.45), 1.2, 9.0)
	game._add_light(c + Vector3(6, 3.0, -3.0), Color(1.0, 0.7, 0.45), 1.2, 9.0)
	# Clutter in the corners: barrels, crates, a weapon rack, chests.
	game.prop_solid = false
	for p in [["dungeon/barrel_large", Vector3(-9.2, 0, -4.6), 1.3, 0.3], ["dungeon/barrel_small_stack", Vector3(-7.4, 0, -4.9), 1.2, 0.0],
			["dungeon/crates_stacked", Vector3(8.8, 0, -4.4), 1.2, -0.4], ["dungeon/barrel_large_decorated", Vector3(7.0, 0, -4.9), 1.2, 0.8],
			["dungeon/sword_shield", Vector3(-1.6, 1.9, -5.95), 1.4, 0.0], ["dungeon/sword_shield_gold", Vector3(1.6, 1.9, -5.95), 1.4, 0.0],
			["dungeon/chest", Vector3(-9.6, 0, 0.0), 1.3, PI / 2.0], ["dungeon/keg_decorated", Vector3(9.6, 0, -1.6), 1.2, -PI / 2.0],
			["dungeon/box_stacked", Vector3(9.4, 0, 2.8), 1.2, -0.3], ["dungeon/barrel_small", Vector3(-9.4, 0, 3.4), 1.2, 0.0],
			["dungeon/barrel_large", Vector3(-9.0, 0, 6.2), 1.3, 0.6], ["dungeon/crates_stacked", Vector3(9.0, 0, 6.0), 1.2, 0.2]]:
		game._prop(p[0], c + p[1], p[2], p[3])
	# A blue runner with gold edges down the middle (the lobby's walkway).
	game._add_block(c + Vector3(0, 0.015, 1.5), Vector3(4.2, 0.03, 13.0), Color.GRAY, false, game._carpet(Color(0.16, 0.26, 0.62)))
	for s in [-1.0, 1.0]:
		game._add_block(c + Vector3(s * 1.95, 0.032, 1.5), Vector3(0.14, 0.01, 13.0), Color.GRAY, false, game._gold())
	game.mossy = was_mossy
	# The world's name tags (door health, the monarchs) stay hidden behind the menu.
	for l in game.find_children("*", "Label3D", true, false):
		if l.visible:
			l.visible = false
			hidden_labels.append(l)
	var made: Array = []
	for i in range(before, game.get_child_count()):
		made.append(game.get_child(i))
	for n in made:
		n.reparent(hall, true)
