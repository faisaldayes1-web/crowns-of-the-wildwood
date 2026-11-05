extends RefCounted
## The Moonlit Wildwood's graveyard (Faisal 2026-11-04: "moonlit wildwood
## should have something different, like a graveyard that summons zombies
## from the ground every 1 minute and if you hold something on the map the
## zombies are friendly to you"). claude-faisal/crowns-graveyard.
##
## Two fenced plots of crooked headstones face each other across the river at
## the north end of the field, the same distance from both castles. Between
## them the Cursed Bell hangs in its frame on a stone pier in the water; its
## ring reaches both banks, so each team captures it from its own side (like
## Ember Pass's Fire Objective, Stats.GRAVEYARD). Every minute of battle the
## bell tolls and zombies claw up out of the graves (scripts/zombie.gd). The
## team holding the bell owns them: they march on the enemy's door, attack
## only the enemy and glow in the holder's colour. Nobody holding it, they
## stay in the graveyard and attack everyone who comes near.
##
## Built only when the Moonlit Wildwood is (game.night()): day and night no
## longer share one world.

const Stats = preload("res://scripts/stats.gd")
const Zombie = preload("res://scripts/zombie.gd")

const CENTER := Vector3(0, 0, -31)        # the bell, and the middle of its ring
const PLOT_X := [5.6, 10.0]               # each plot spans |x| from..to
const PLOT_Z := [-37.4, -25.8]            # and z
const GRAVE_X := [6.7, 8.9]               # two columns of graves a side
const GRAVE_Z := [-27.4, -30.0, -32.6, -35.2]
const NEUTRAL := Color(0.78, 0.45, 1.0)   # nobody holds the bell: a ghostly violet (the lanterns burn green)
const FOG_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 tint : source_color = vec4(0.62, 0.8, 0.7, 1.0);
uniform float density = 0.4;
uniform float speed = 1.0;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1.0, 0.0)), f.x), mix(h(i + vec2(0.0, 1.0)), h(i + vec2(1.0, 1.0)), f.x), f.y);
}
void fragment() {
	vec2 w = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xz;
	float t = TIME * speed;
	float v = n(w * 0.3 + vec2(t * 0.06, t * 0.035)) * 0.6 + n(w * 0.85 - vec2(t * 0.09, -t * 0.02)) * 0.4;
	float edge = 1.0 - smoothstep(0.55, 1.0, length(UV - 0.5) * 2.0);
	ALBEDO = tint.rgb;
	ALPHA = clamp((v - 0.32) * 1.7, 0.0, 1.0) * density * edge;
}
"""

var game
var graves: Array = []        # [position, yaw] of every grave a zombie can rise from
var zombies: Array = []
var next_id := 1
# The Cursed Bell: progress runs from -1 (the Elves hold it) to +1 (the
# Humans); the owner changes at the ends and goes neutral at 0.
var bell_owner := -1
var bell_progress := 0.0
var bell_counts := [0, 0]
var bell_contested := false
var bell_held := [0.0, 0.0]
var bell_captures := [0, 0]
var rise_left := 0.0          # seconds to the next rising
var risings := 0
var risen := 0
var kills := [0, 0, 0]        # zombies put down by Elves, Humans, (other)
var bites := [0, 0]           # hearts zombies took from Elves, Humans
var warned := false
var started := false
var _debug_owner := -2
var _debug_rise := -1.0

var bell: Node3D
var bell_mat: StandardMaterial3D
var ring_mat: StandardMaterial3D
var bell_light: OmniLight3D
var plot_lights: Array = []
var swing := 0.0
var _tree_grid := {}
var _box_grid := {}       # cover stacks and wall stubs (game.cover_boxes) by 4 m cell
var _grid_built := false


func _init(p_game) -> void:
	game = p_game
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--debug-bell="):     # testing: hand the bell to a team (0 / 1) as the battle starts
			_debug_owner = int(arg.trim_prefix("--debug-bell="))
		if arg.begins_with("--debug-rise="):     # testing: the first rising after this many seconds
			_debug_rise = float(arg.trim_prefix("--debug-rise="))
	for sx in [-1.0, 1.0]:
		for gx in GRAVE_X:
			for gz in GRAVE_Z:
				graves.append([Vector3(sx * gx, 0, gz), PI / 2.0 if sx < 0.0 else -PI / 2.0])


static func _flat(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()


static func in_zone(p: Vector3, margin: float = 0.0) -> bool:
	## Inside the graveyard's footprint (the plots, the river between them):
	## the groves keep out of it.
	return absf(p.x) < PLOT_X[1] + 1.2 + margin and p.z > PLOT_Z[0] - 1.5 - margin and p.z < PLOT_Z[1] + 1.2 + margin


# --- Building --------------------------------------------------------------------

func _mat(c: Color, rough: float = 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


func _glow(c: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m


func _mesh(parent: Node3D, mesh: Mesh, at: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = at
	mi.rotation = rot
	mi.material_override = mat
	parent.add_child(mi)
	return mi


func _crooked(name: String, at: Vector3, s: float, yaw: float, seed: int) -> Node3D:
	var n: Node3D = game._prop("halloween/" + name, at, s, yaw)
	if n:
		# Crooked: every stone leans a little its own way.
		n.rotation.z = (fmod(float(seed) * 0.618, 1.0) - 0.5) * 0.3
		n.rotation.x = (fmod(float(seed) * 0.377, 1.0) - 0.5) * 0.16
	return n


func build() -> void:
	var root := Node3D.new()
	root.name = "Graveyard"
	game.add_child(root)
	var k := 0
	for sx in [-1.0, 1.0]:
		var cx: float = sx * (PLOT_X[0] + PLOT_X[1]) / 2.0
		var cz: float = (PLOT_Z[0] + PLOT_Z[1]) / 2.0
		for mz in [-35.0, -31.0, -27.5]:
			game.map_marks.append([Vector3(cx, 0, mz), "graveyard"])
		await game._world_build_frame()
		# The graves: mounds with headstones, plain stones and markers.
		var kinds := ["grave_A", "gravestone", "grave_B", "gravemarker_A", "grave_A", "gravemarker_B", "grave_B", "gravestone"]
		for gx in GRAVE_X:
			for gz in GRAVE_Z:
				var name: String = kinds[k % kinds.size()]
				var yaw: float = PI / 2.0 if sx < 0.0 else -PI / 2.0
				var at := Vector3(sx * gx, 0, gz)
				var sc := 0.42 if name.begins_with("grave_") else 0.75
				_crooked(name, at, sc, yaw + (fmod(k * 0.41, 1.0) - 0.5) * 0.3, k + 3)
				game._add_blocker(at, 0.45, 1.4)
				k += 1
		await game._world_build_frame()
		# Candles and bones among the graves.
		game._prop("halloween/candle_triple", Vector3(sx * 7.8, 0, -28.7), 0.6, 0.4)
		game._prop("halloween/candle_melted", Vector3(sx * 7.8, 0, -33.9), 0.7, 1.1)
		game._prop("halloween/bone_A", Vector3(sx * 6.2, 0, -31.3), 0.7, 0.9 * sx)
		game._prop("halloween/skull", Vector3(sx * 9.4, 0, -31.3), 0.4, -0.6 * sx)
		# A lantern at each end, burning a sickly green.
		for lz in [-26.4, -36.8]:
			game._prop("halloween/lantern_standing", Vector3(sx * 6.0, 0, lz), 0.8, 0.0)
			plot_lights.append(game._add_light(Vector3(sx * 6.0, 0.9, lz), Color(0.55, 1.0, 0.6), 1.2, 6.5))
		# A dead tree in the far corner and a broken fence along the back.
		game._prop("halloween/tree_dead_large_decorated", Vector3(sx * 9.6, 0, -38.0), 0.75, 0.6 * sx)
		game._add_blocker(Vector3(sx * 9.6, 0, -38.0), 0.5)
		game._prop("halloween/fence_broken" if sx < 0.0 else "halloween/fence", Vector3(sx * 7.1, 0, -38.3), 0.7, 0.0)
		game._prop("halloween/fence_pillar", Vector3(sx * 5.4, 0, -38.3), 0.7, 0.0)
		game._prop("halloween/fence", Vector3(sx * 10.5, 0, -35.4), 0.7, PI / 2.0)
		game._prop("halloween/fence_pillar_broken", Vector3(sx * 10.5, 0, -33.3), 0.7, 0.0)
		game._add_fireflies(Vector3(cx, 0.4, cz))
		await game._world_build_frame()
	_build_bell(root)
	await game._world_build_frame()
	_build_fog(root)


func _build_bell(root: Node3D) -> void:
	## The Cursed Bell: a mossy stone pier in the river, a black timber frame
	## and a verdigris bell, with a glow that takes the holder's colour.
	var stone := _mat(Color(0.34, 0.36, 0.38))
	var timber := _mat(Color(0.16, 0.12, 0.1))
	var pier := CylinderMesh.new()
	pier.top_radius = 1.05
	pier.bottom_radius = 1.25
	pier.height = 1.6
	_mesh(root, pier, CENTER + Vector3(0, -0.4, 0), stone)
	var cap := CylinderMesh.new()
	cap.top_radius = 1.12
	cap.bottom_radius = 1.12
	cap.height = 0.14
	_mesh(root, cap, CENTER + Vector3(0, 0.46, 0), _mat(Color(0.28, 0.3, 0.31)))
	for s in [-1.0, 1.0]:
		var post := BoxMesh.new()
		post.size = Vector3(0.22, 4.0, 0.22)
		_mesh(root, post, CENTER + Vector3(s * 0.75, 2.5, 0), timber, Vector3(0, 0, s * 0.06))
	var beam := BoxMesh.new()
	beam.size = Vector3(2.1, 0.24, 0.3)
	_mesh(root, beam, CENTER + Vector3(0, 4.45, 0), timber)
	var roof := PrismMesh.new()
	roof.size = Vector3(2.4, 0.7, 0.9)
	_mesh(root, roof, CENTER + Vector3(0, 4.9, 0), _mat(Color(0.14, 0.16, 0.18)))
	bell = Node3D.new()
	bell.position = CENTER + Vector3(0, 4.3, 0)
	root.add_child(bell)
	bell_mat = _glow(Color(0.28, 0.48, 0.38), 0.25)
	bell_mat.metallic = 0.6
	bell_mat.roughness = 0.45
	var cup := CylinderMesh.new()
	cup.top_radius = 0.32
	cup.bottom_radius = 0.72
	cup.height = 1.05
	_mesh(bell, cup, Vector3(0, -0.62, 0), bell_mat)
	var crown := SphereMesh.new()
	crown.radius = 0.34
	crown.height = 0.4
	_mesh(bell, crown, Vector3(0, -0.12, 0), bell_mat)
	var lip := TorusMesh.new()
	lip.inner_radius = 0.66
	lip.outer_radius = 0.78
	_mesh(bell, lip, Vector3(0, -1.13, 0), bell_mat)
	var clapper := SphereMesh.new()
	clapper.radius = 0.13
	clapper.height = 0.26
	_mesh(bell, clapper, Vector3(0, -1.2, 0), _mat(Color(0.1, 0.1, 0.1)))
	bell_light = OmniLight3D.new()
	bell_light.position = CENTER + Vector3(0, 3.2, 0)
	bell_light.light_color = NEUTRAL
	bell_light.light_energy = 2.0
	bell_light.omni_range = 11.0
	root.add_child(bell_light)
	# The capture ring, reaching both banks.
	ring_mat = StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.emission_enabled = true
	ring_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var tor := TorusMesh.new()
	tor.inner_radius = Stats.GRAVEYARD.radius - 0.14
	tor.outer_radius = Stats.GRAVEYARD.radius + 0.1
	tor.rings = 96
	tor.ring_segments = 4
	var ring := _mesh(root, tor, CENTER + Vector3(0, 0.06, 0), ring_mat)
	ring.scale = Vector3(1, 0.12, 1)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_fog(root: Node3D) -> void:
	## Low ground fog drifting over the graves and the water between them.
	var sh := Shader.new()
	sh.code = FOG_SHADER
	for layer in [[0.35, 0.42, Vector2(26, 17), 1.0], [0.8, 0.26, Vector2(22, 14), 0.7]]:
		var m := ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("density", layer[1])
		m.set_shader_parameter("speed", layer[3])
		var pl := PlaneMesh.new()
		pl.size = layer[2]
		var fog := _mesh(root, pl, Vector3(0, layer[0], (PLOT_Z[0] + PLOT_Z[1]) / 2.0), m)
		fog.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# --- The match ---------------------------------------------------------------------

func reset() -> void:
	for z in zombies.duplicate():
		if is_instance_valid(z):
			z.queue_free()
	zombies.clear()
	bell_owner = -1
	bell_progress = 0.0
	bell_counts = [0, 0]
	bell_contested = false
	started = false
	warned = false
	rise_left = Stats.GRAVEYARD.interval


func tick(delta: float) -> void:
	_animate(delta)
	if not game.playing and not game.game_over:
		if started or not zombies.is_empty():
			reset()
		return
	for z in zombies.duplicate():
		if is_instance_valid(z):
			z.step(delta)
	if game.game_over or game.in_prep() or game.net_client:
		return
	if not started:
		started = true
		rise_left = _debug_rise if _debug_rise >= 0.0 else Stats.GRAVEYARD.interval
		if _debug_owner >= 0:
			bell_progress = -1.0 if _debug_owner == 0 else 1.0
			_set_owner(_debug_owner)
	_capture(delta)
	rise_left -= delta
	if rise_left <= 5.0 and not warned:
		warned = true
		game.sfx.play("bell_toll", CENTER + Vector3(0, 3, 0), -2.0, 0.0)
		swing = 1.0
		for g in graves:
			game.spawn_splash(g[0] + Vector3(0, 0.2, 0), NEUTRAL, 3, 0.8, 1.2, true)
	if rise_left <= 0.0:
		rise_left += Stats.GRAVEYARD.interval
		warned = false
		_rise_wave()


func _capture(delta: float) -> void:
	var s: Dictionary = Stats.GRAVEYARD
	bell_counts = [0, 0]
	for u in game.units:
		if not u.dead and not u.downed and u.global_position.y > -1.0 and _flat(u.global_position - CENTER) < s.radius:
			bell_counts[u.team] += 1
	bell_contested = bell_counts[0] > 0 and bell_counts[1] > 0
	var rate: float = 1.0 / s.capture_time
	if bell_contested:
		pass
	elif bell_counts[0] > 0 or bell_counts[1] > 0:
		var t := 0 if bell_counts[0] > 0 else 1
		var n: int = mini(bell_counts[t], s.max_count)
		var step: float = rate * (1.0 + s.extra_rate * (n - 1)) * delta
		bell_progress = clampf(bell_progress + (-step if t == 0 else step), -1.0, 1.0)
	else:
		var rest := 0.0 if bell_owner < 0 else (-1.0 if bell_owner == 0 else 1.0)
		bell_progress = move_toward(bell_progress, rest, rate * s.settle * delta)
	if bell_owner == 0 and bell_progress >= 0.0 or bell_owner == 1 and bell_progress <= 0.0:
		_set_owner(-1)
	if bell_progress <= -1.0 and bell_owner != 0:
		_set_owner(0)
	elif bell_progress >= 1.0 and bell_owner != 1:
		_set_owner(1)
	if bell_owner >= 0:
		bell_held[bell_owner] += delta


func _set_owner(team: int) -> void:
	var was := bell_owner
	bell_owner = team
	if game.demo:
		print("BELL t=%d owner=%s" % [game.match_clock(), ["Elves", "Humans"][team] if team >= 0 else "none"])
	for z in zombies:
		if is_instance_valid(z) and z.alive():
			z.set_team(team)
			z.target = null
	swing = 1.0
	game.sfx.play("bell_toll", CENTER + Vector3(0, 3, 0), 0.0, 0.0)
	if team >= 0:
		bell_captures[team] += 1
		var name: String = Stats.FACTIONS[team].name
		game.announce("%s RING THE CURSED BELL! The dead fight for them." % name.to_upper())
		game.chat_system("The %s captured the Cursed Bell: the graveyard's zombies are theirs." % name)
		game.spawn_pillar(CENTER, game._team_color(team).lightened(0.2), 9.0, 1.4)
		game.spawn_ring(CENTER, Stats.GRAVEYARD.radius, game._team_color(team), 0.9)
		game.shake_at(CENTER, 0.2)
	elif was >= 0:
		game.toast("The %s lost the Cursed Bell" % Stats.FACTIONS[was].name, Color(0.6, 1.0, 0.6))
		game.chat_system("The Cursed Bell is silent: the dead attack everyone again.")


func _rise_wave() -> void:
	## The bell tolls and zombies claw up out of free graves.
	var s: Dictionary = Stats.GRAVEYARD
	var alive := 0
	for z in zombies:
		if is_instance_valid(z) and z.alive():
			alive += 1
	var count: int = mini(s.wave, s.max_alive - alive)
	risings += 1
	game.sfx.play("bell_toll", CENTER + Vector3(0, 3, 0), 1.0, 0.0)
	swing = 1.0
	if count <= 0:
		return
	var free := graves.duplicate()
	var r := RandomNumberGenerator.new()
	r.seed = 4411 + risings * 31
	# Rise from both plots in turn, so no side gets them all.
	var picked: Array = []
	var side := r.randi() % 2
	for i in count:
		var want := -1.0 if (side + i) % 2 == 0 else 1.0
		var pool := free.filter(func(g): return signf(g[0].x) == want and not _grave_busy(g[0]))
		if pool.is_empty():
			pool = free.filter(func(g): return not _grave_busy(g[0]))
		if pool.is_empty():
			break
		var g = pool[r.randi() % pool.size()]
		free.erase(g)
		picked.append(g)
	for g in picked:
		# In front of the headstone, toward the river.
		var at: Vector3 = g[0] + Vector3(-signf(g[0].x) * 0.9, 0, 0)
		var z = Zombie.new()
		game.add_child(z)
		z.setup(game, self, next_id, at, bell_owner)
		next_id += 1
		zombies.append(z)
		risen += 1
		game.spawn_splash(at + Vector3(0, 0.2, 0), Color(0.3, 0.22, 0.15), 18, 4.0, 0.7)
		game.spawn_ring(at, 1.2, NEUTRAL if bell_owner < 0 else game._team_color(bell_owner), 0.8)
		game.spawn_flash(at + Vector3(0, 0.6, 0), NEUTRAL, 2.5, 0.5)
		game.sfx.play("zombie_rise", at, 0.0, 0.1)
	game.sfx.play("zombie_groan", CENTER, -2.0, 0.15)
	if game.demo:
		print("RISE t=%d count=%d owner=%d alive=%d" % [game.match_clock(), picked.size(), bell_owner, alive + picked.size()])
	if bell_owner >= 0:
		game.toast("The dead rise for the %s!" % Stats.FACTIONS[bell_owner].name, game._team_color(bell_owner).lightened(0.3))
	else:
		game.toast("The dead rise in the graveyard!", Color(0.6, 1.0, 0.55))


func _grave_busy(p: Vector3) -> bool:
	for z in zombies:
		if is_instance_valid(z) and z.alive() and _flat(z.position - p) < 1.6:
			return true
	return false


func forget(z) -> void:
	zombies.erase(z)


func alive_zombies() -> Array:
	return zombies.filter(func(z): return is_instance_valid(z) and z.alive())


func _animate(delta: float) -> void:
	if bell == null:
		return
	var tint := NEUTRAL
	if bell_owner >= 0:
		tint = game._team_color(bell_owner).lightened(0.25)
	elif absf(bell_progress) > 0.01:
		tint = NEUTRAL.lerp(game._team_color(0 if bell_progress < 0.0 else 1).lightened(0.25), absf(bell_progress) * 0.6)
	var now := Time.get_ticks_msec() / 1000.0
	var pulse := 1.0 + (0.6 * sin(now * 10.0) if bell_contested else 0.15 * sin(now * 1.7))
	swing = maxf(0.0, swing - delta * 0.35)
	bell.rotation.z = sin(now * 4.2) * 0.35 * swing
	bell_mat.emission = tint
	bell_mat.emission_energy_multiplier = 0.25 + 0.9 * swing + (0.3 if bell_owner >= 0 else 0.0)
	bell_light.light_color = tint
	bell_light.light_energy = 1.8 * pulse + 2.0 * swing
	ring_mat.albedo_color = Color(tint.r, tint.g, tint.b, 0.7)
	ring_mat.emission = tint
	ring_mat.emission_energy_multiplier = 1.4 * pulse
	for i in plot_lights.size():
		plot_lights[i].light_energy = 1.1 + 0.25 * sin(now * 2.3 + i * 1.9)


# --- Ground, routes and steering for the zombies -------------------------------------

func walkable_for(p: Vector3) -> bool:
	## Ground a zombie can stand on: the open field, the flank bridges, not a
	## castle, the river or the shrine island.
	if absf(p.x) > game.CASTLE_X - game.CASTLE_DEPTH - 0.5 or absf(p.z) > game.map_half.y - 0.5:
		return false
	if absf(p.x) < game.RIVER_HALF + 0.4:
		return _on_bridge(p)
	return true


func _on_bridge(p: Vector3) -> bool:
	for i in [0, 2]:
		if absf(p.z - game.BRIDGES[i]) < game.BRIDGE_HALF[i] - 0.5:
			return true
	return false


func clamp_walk(before: Vector3, p: Vector3) -> Vector3:
	var lim: float = game.CASTLE_X - game.CASTLE_DEPTH - 1.5
	p.x = clampf(p.x, -lim, lim)
	p.z = clampf(p.z, -game.map_half.y + 1.0, game.map_half.y - 1.0)
	if absf(p.x) < game.RIVER_HALF + 0.4 and not _on_bridge(p):
		# The river: slide along the bank instead of stepping in.
		var q := Vector3(before.x, p.y, p.z)
		if absf(q.x) < game.RIVER_HALF + 0.4 and not _on_bridge(q):
			return before
		return q
	return p


func ground_y(p: Vector3) -> float:
	return 0.18 if absf(p.x) < game.RIVER_HALF + 1.0 and _on_bridge(p) else 0.0


func route(from: Vector3, to: Vector3) -> Vector3:
	## The next point toward `to`: over the nearer flank bridge when the
	## river is between, else the game's own routing round cover.
	var a := signf(from.x)
	var b := signf(to.x)
	if a != b and absf(from.x) > 0.01 and absf(to.x) > game.RIVER_HALF:
		var bi := 0 if from.z < 0.0 else 2
		var bz: float = game.BRIDGES[bi]
		if absf(from.x) < game.RIVER_HALF + 0.6:
			return Vector3(-a * (game.RIVER_HALF + 2.5), 0, bz)   # on the deck: straight over
		if absf(from.z - bz) > 1.0 or absf(from.x) > game.RIVER_HALF + 3.0:
			return Vector3(a * (game.RIVER_HALF + 2.0), 0, bz)
		return Vector3(-a * (game.RIVER_HALF + 2.5), 0, bz)
	if absf(from.x) < game.RIVER_HALF + 0.6:
		return Vector3(signf(to.x) * (game.RIVER_HALF + 2.5), 0, from.z)   # off the deck first
	return game.route_point(from, to)


func _index_trees() -> void:
	_grid_built = true
	for t in game.map_trees:
		var key := Vector2i(floori(t.x / 4.0), floori(t.z / 4.0))
		if not _tree_grid.has(key):
			_tree_grid[key] = []
		_tree_grid[key].append(t)
	for c in game.cover_points:
		var key := Vector2i(floori(c.x / 4.0), floori(c.z / 4.0))
		if not _tree_grid.has(key):
			_tree_grid[key] = []
		_tree_grid[key].append(Vector3(c.x, 0.3, c.z))
	for b in game.cover_boxes:
		var lo := Vector2i(floori(b.position.x / 4.0) - 1, floori(b.position.z / 4.0) - 1)
		var hi := Vector2i(floori(b.end.x / 4.0) + 1, floori(b.end.z / 4.0) + 1)
		for cx in range(lo.x, hi.x + 1):
			for cz in range(lo.y, hi.y + 1):
				var bk := Vector2i(cx, cz)
				if not _box_grid.has(bk):
					_box_grid[bk] = []
				_box_grid[bk].append(b)
	for g in graves:
		var key := Vector2i(floori(g[0].x / 4.0), floori(g[0].z / 4.0))
		if not _tree_grid.has(key):
			_tree_grid[key] = []
		_tree_grid[key].append(Vector3(g[0].x, 0.2, g[0].z))


func avoid(me) -> Vector3:
	## A push away from trunks, cover, graves and other zombies close by.
	if not _grid_built:
		_index_trees()
	var p: Vector3 = me.position
	var push := Vector3.ZERO
	var c := Vector2i(floori(p.x / 4.0), floori(p.z / 4.0))
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			for t in _tree_grid.get(c + Vector2i(dx, dz), []):
				var r: float = 1.5 if t.y > 0.5 else 1.1
				var off := Vector3(p.x - t.x, 0, p.z - t.z)
				var d := off.length()
				if d < r and d > 0.01:
					push += off / d * (r - d) / r
	for b in _box_grid.get(c, []):
		var q := Vector3(clampf(p.x, b.position.x, b.end.x), 0, clampf(p.z, b.position.z, b.end.z))
		var off := Vector3(p.x - q.x, 0, p.z - q.z)
		var d := off.length()
		if d < 0.7:
			if d < 0.01:
				off = Vector3(p.x - (b.position.x + b.end.x) / 2.0, 0, p.z - (b.position.z + b.end.z) / 2.0)
				d = maxf(off.length(), 0.01)
			push += off / d * (0.7 - d) * 2.0
	for z in zombies:
		if z == me or not is_instance_valid(z):
			continue
		var off: Vector3 = p - z.position
		off.y = 0.0
		var d := off.length()
		if d < 0.9 and d > 0.01:
			push += off / d * (0.9 - d)
	return push


func wander_point(home: Vector3, seed: int) -> Vector3:
	## Somewhere among the graves on the zombie's own side.
	var r := RandomNumberGenerator.new()
	r.seed = seed * 7919 + 13
	var sx := signf(home.x)
	return Vector3(sx * r.randf_range(PLOT_X[0], PLOT_X[1] + 2.0), 0, r.randf_range(PLOT_Z[0] + 0.5, PLOT_Z[1] + 3.0))


func march_goal(team: int, pos: Vector3) -> Vector3:
	## A friendly zombie's way: the enemy's door, by the open road.
	var side := 1.0 if team == 0 else -1.0
	var gx: float = side * (game.CASTLE_X - game.CASTLE_DEPTH - 4.0)
	return Vector3(gx, 0, clampf(pos.z * 0.2, -3.0, 3.0))


# --- What the units and bots see ------------------------------------------------------

func hostile(team: int) -> Array:
	return zombies.filter(func(z): return is_instance_valid(z) and z.hostile_to(team))


func melee(unit, dir: Vector3, reach: float, damage: int) -> bool:
	## A unit's swing: every hostile zombie in front within reach.
	var landed := false
	for z in hostile(unit.team):
		var to: Vector3 = z.position - unit.global_position
		to.y = 0.0
		var d := to.length()
		if d <= reach + 0.3 and (d < 0.8 or dir.dot(to / d) > 0.3):
			landed = z.take_hit(damage, unit) or landed
	return landed


func shot_hit(team: int, pos: Vector3, radius: float):
	## The hostile zombie a shot at `pos` passes through, or null.
	for z in hostile(team):
		if _flat(z.position - pos) < radius and pos.y > z.position.y + 0.2 and pos.y < z.position.y + 2.2:
			return z
	return null


func splash(team: int, pos: Vector3, radius: float, damage: int, owner_unit) -> void:
	for z in hostile(team):
		if _flat(z.position - pos) < radius + 0.4:
			z.take_hit(damage, owner_unit)


func threat_for(team: int, pos: Vector3, radius: float):
	## The nearest zombie hostile to `team` within `radius` of `pos`.
	var best = null
	var best_d := radius
	for z in hostile(team):
		var d := _flat(z.position - pos)
		if d < best_d:
			best_d = d
			best = z
	return best


func bots_wanted(team: int) -> int:
	## How many bots a team sends to the Cursed Bell.
	var s: Dictionary = Stats.GRAVEYARD
	var enemies_on: bool = bell_counts[1 - team] > 0
	if bell_owner != team:
		return s.bots_take + (1 if enemies_on else 0) + (1 if rise_left < s.rise_soon else 0)
	return s.bots_hold + (1 if enemies_on else 0)


func bell_spot(team: int, offset: Vector3) -> Vector3:
	## Where a bot stands to ring the bell: its own bank, in the ring.
	var side := -1.0 if team == 0 else 1.0
	return Vector3(side * (game.RIVER_HALF + 1.7 + absf(fmod(offset.x, 0.8))), 0, CENTER.z + clampf(offset.z, -3.0, 3.0))


func status(my_team: int) -> Dictionary:
	## The HUD's line about the bell (the same shape as the Fire Objective's).
	var p := absf(bell_progress)
	var lead := -1 if p < 0.001 else (0 if bell_progress < 0.0 else 1)
	var secs := maxi(int(ceil(rise_left)), 0)
	var text := ""
	var color := Color(0.1, 0.3, 0.12)
	if bell_contested:
		text = "The Cursed Bell is contested.  The dead rise in %ds" % secs
	elif bell_owner >= 0 and p >= 0.999 or (bell_owner >= 0 and bell_counts[0] + bell_counts[1] == 0):
		text = "%s hold the Cursed Bell: the dead fight for them.  Rising in %ds" % [Stats.FACTIONS[bell_owner].name, secs]
		color = game._team_color(bell_owner).darkened(0.45)
	elif bell_counts[0] + bell_counts[1] > 0 and lead >= 0:
		text = "%s are ringing the Cursed Bell: %d%%" % [Stats.FACTIONS[lead].name, int(p * 100.0)]
		color = game._team_color(lead).darkened(0.45)
	else:
		text = "Ring the Cursed Bell to command the dead.  Rising in %ds" % secs
	return {"text": text, "color": color, "progress": bell_progress, "owner": bell_owner, "contested": bell_contested, "icon": "bell"}


func report() -> String:
	return "GRAVESTAT risings=%d risen=%d held=%d/%d captures=%d/%d zombie_kills=%d/%d bites=%d/%d" % [risings, risen,
		int(bell_held[0]), int(bell_held[1]), bell_captures[0], bell_captures[1], kills[0], kills[1], bites[0], bites[1]]


# --- Online --------------------------------------------------------------------

func net_state() -> Array:
	var zs: Array = []
	for z in zombies:
		if is_instance_valid(z):
			zs.append([z.id, snappedf(z.position.x, 0.01), snappedf(z.position.z, 0.01), snappedf(z.rotation.y, 0.01), z.state, z.team])
	return [bell_owner, bell_progress, rise_left, zs]


func net_apply(d: Array) -> void:
	## Client: the host's bell and zombies (puppets placed from the snapshot).
	if d.size() < 4:
		return
	if bell_owner != d[0]:
		bell_owner = d[0]
		swing = 1.0
	bell_progress = d[1]
	rise_left = d[2]
	var seen := {}
	for row in d[3]:
		seen[row[0]] = true
		var z = null
		for q in zombies:
			if is_instance_valid(q) and q.id == row[0]:
				z = q
				break
		if z == null:
			z = Zombie.new()
			game.add_child(z)
			z.setup(game, self, row[0], Vector3(row[1], 0, row[2]), row[5], true)
			zombies.append(z)
		z.net_to = Vector3(row[1], 0, row[2])
		z.rotation.y = row[3]
		if z.state != row[4] and row[4] == Zombie.State.DIE:
			z.crumble(false)
		elif z.state != Zombie.State.RISE and z.state != Zombie.State.DIE:
			z.state = row[4]
		if z.team != row[5]:
			z.set_team(row[5])
	for z in zombies.duplicate():
		if is_instance_valid(z) and not seen.has(z.id) and z.state != Zombie.State.DIE:
			z.crumble(false)
