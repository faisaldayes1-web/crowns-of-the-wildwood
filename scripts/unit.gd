extends CharacterBody3D
## One soldier on either team, driven by the local player or by a simple bot brain.
## Everyone starts as a plain Elf or Human and transforms by stepping onto a
## class station in their castle. Dying resets you to the plain form and
## wipes the experience you earned this life. All numbers live in stats.gd.

const Stats = preload("res://scripts/stats.gd")
const Turret = preload("res://scripts/turret.gd")
const Monarch = preload("res://scripts/monarch.gd")
const CharacterModel = preload("res://scripts/character_model.gd")
const Fx = preload("res://scripts/fx.gd")
const SkillFx = preload("res://scripts/skill_fx.gd")
const Role = Stats.Role

const GRAVITY := 20.0
const PICKUP_RANGE := 1.8

var game
var team := 0
var role: int = Role.BASE
var is_player := false
var hearts := Stats.MAX_HEARTS
var energy := 100.0
var dead := false
var respawn_timer := 0.0
var respawn_total := 0.0     # what the timer started from this death (the HUD's countdown ring)
var fell_level := 1          # the level you died at (the death screen says what was lost)
# Downed (see stats.gd DOWNED_TIME): on the ground, not dead. Teammates can
# revive; an enemy hit, bleeding out or skipping makes it a real death.
var downed := false
var downed_timer := 0.0       # bleed-out seconds left
var downed_total := 0.0
var downed_by = null          # who knocked us down (kill credit already given)
var skip_hold := 0.0          # seconds interact has been held to skip
var revive_progress := 0.0    # 0..1, filled by whoever is reviving us
var revive_by = null          # the teammate reviving us this frame
var revive_target = null      # (reviver side) the downed teammate we are reviving
var revive_protect := 0.0     # invulnerable while standing back up
var down_snapshot := {}       # levels, xp and ranks before the fall, handed back on a revive
var revives := 0              # teammates this unit revived this match
var times_revived := 0
var bot_down_wait := 0.0      # a downed bot alone: seconds before it skips
var attack_timer := 0.0
var flash_timer := 0.0
const FLASH_TIME := 0.22     # hit flash: white for the first frames, then red, easing back
var hitstop_timer := 0.0
var heartbeat_timer := 0.0
const ATTACK_BUFFER := 0.2         # seconds a tapped attack waits for the swing cooldown
var attack_buffer := 0.0
const INPUT_BUFFER := 0.25         # seconds an early skill / dodge press waits for its cooldown
var input_buffer := [0.0, 0.0, 0.0]  # ability 1, ability 2, dodge
var swing_flip := false     # alternate the slash arc left/right    # hit stop: the model's animation holds for a beat (looks only)
var status_fx := {}         # looping aura emitters by kind (Fx.status_emitter)
var last_hit_dir := Vector3.ZERO   # the push of the last hit that landed (for the HUD's hit direction arc)
var ability_timers := [0.0, 0.0, 0.0]   # Q, E, and G (the upgraded hat's move)
var hat_upgraded := false   # wearing a hat from an upgraded hat machine (economy.gd): a third move on G
var dodge_timer := 0.0      # time left in the current dash
var dodge_cooldown := 0.0   # time until the next dodge is ready
var dodge_dir := Vector3.ZERO
var bash_timer := 0.0       # a Knight's Shield Bash is a dash that hurts
var bash_speed := 0.0
var bash_hit: Array = []
var guard_timer := 0.0      # Shield Wall: no damage gets through
var prep_done := false      # fortify phase: this bot has set its trap or barricade
var bubble_timer := 0.0     # Holy Bubble: the dome shows while this runs
var bubble_mesh: MeshInstance3D
var blocking := false       # shield up (hold right click): blocks hits from the front
var root_timer := 0.0       # snared: can't move
var haste_timer := 0.0      # blessed: faster
var knockback := Vector3.ZERO
var carrying = null
var spawn_point := Vector3.ZERO
var facing := Vector3(1, 0, 0)
var step_timer := 0.0        # footsteps
var turrets: Array = []      # Engineer: the turrets this unit built (oldest first)
var kills := 0
var deaths := 0
var captures := 0
var assists := 0
var recent_hitters := {}   # attacker -> time of their last hit on us
var healing := 0        # hearts healed on teammates
var damage_dealt := 0   # hearts of damage dealt
var display_name := ""
var slow_timer := 0.0       # slowed: half speed
var stealth_timer := 0.0    # smoke bomb: bots lose you
var burn_tick := false      # demo log: the hit being taken is a fire-form burn going off
var fire_form := false      # Ember Pass: our team holds the Fire Objective, so this class fights in FIRE form
var fire_fx: Node3D         # the FIRE form's flames and glow
var burn_timer := 0.0       # set alight by a FIRE attack: a heart goes when it runs out (healing puts it out)
var burn_cd := 0.0          # can't catch fire again until this runs out
var burn_by = null          # who lit us, for the credit
var bash_damage := 1
var bash_root := 0.0
var buff := ""              # Blessing of Light in effect
var buff_timer := 0.0
var regen_tick := 0.0
var highlighted := false     # under the local player's aim
var streak := 0              # kills without dying
var best_streak := 0         # longest streak this match (end-of-match summary)
var peak_level := 1          # highest in-match level reached in any life
var xp_sources := {}         # this match's XP by source: combat, takedowns, crown, siege, support
var giant_kills := 0         # kills on enemies two or more levels above you
var kill_banner := {}        # the HUD's KILL card for a local player: {victim, role, team, streak, time}
var class_banner := 0.0        # seconds the "YOU ARE NOW <class>" banner has left (players only)
const CLASS_BANNER_TIME := 3.0
var spawn_protect := 0.0     # seconds of spawn protection left
var home_defense := false    # inside our own castle: the defender bonus
var home_timer := 0.0
var resist_pool := 0.0
var heal_pool := 0.0
var carry_fx: Node3D
var veteran := 0             # 0 nobody, 1 Veteran, 2 Elite Veteran (bounty)
var bounty_ring: MeshInstance3D
var bounty_ring_mat: StandardMaterial3D
var bounty_beam: MeshInstance3D
var blob_mat: StandardMaterial3D

# Experience this life. Levels give rank points; ranks are kept per class so
# switching class at a station starts that class's ranks fresh.
var xp := 0
var level := 1
var points := 0
var ranks := {}             # role -> [attack, q, e, vigor]
var spent: Array = []       # [role, track] per rank point, oldest first, so a fall takes the newest back
var variants := {}          # role -> chosen variant index, kept for the whole match
var mastery := {}           # role -> rank points spent over the match (total upgrades)
var _stats_cache := {}

# Where attacks go. The player aims with the mouse or the right stick, so
# aiming is independent of walking; bots aim at whatever they are fighting.
var aim := Vector3(1, 0, 0)
var aim_point := Vector3.ZERO
var aim_mode := "move"      # "mouse", "stick", or "move" (aim follows walking)
var last_mouse := Vector2(-1, -1)

# Bots: "attack" raids the enemy castle, "wall" shoots from the ramparts over
# the door, "support" follows a raider (healers), "defend" guards the throne.
var bot_job := "attack"
var base_job := "attack"   # the lineup job the planner falls back to
var job_target := Vector3.INF
var cover_spot := Vector3.INF
var bot_class: int = Role.KNIGHT
var bot_offset := Vector3.ZERO
var cluster := 0   # enemies bunched around the bot's current target
var bot_block_timer := 0.0
var rally_wait := 0.0   # seconds spent holding at the rally point
var last_role := 0            # the class held when we died
var stuck_time := 0.0
var stall_target := Vector3.ZERO   # last _steer_to target (diagnostics)
var player_ring_mat: StandardMaterial3D   # the ground ring under a local player
var side_ring: MeshInstance3D          # the team ring under every unit, and its glow halo
var side_glow: MeshInstance3D
var side_ring_mat: StandardMaterial3D
var side_glow_mat: StandardMaterial3D
var local_index := -1              # which local (couch) player drives this unit, -1 for bots
var _bot_plan: Dictionary = {}     # browsers: the last plan, repeated on alternate ticks
var act_prefix := ""               # input action prefix: "" for player 1, "p2_" ... for couch players
var has_mouse := true              # player 1 aims with the mouse; the others with the right stick
var avoid_dir := Vector3.ZERO      # look-ahead detour we are committed to
var avoid_timer := 0.0
var sidestep_timer := 0.0   # while > 0 the bot commits to walking around an obstacle
var avoid_side := 0.0       # which way round the current obstacle (+1 / -1), kept until the way ahead is clear
var stall_pos := Vector3.ZERO  # demo diagnostics: where the bot last made progress
var stall_clock := 0.0
var sidestep_sign := 1.0

var shape: CollisionShape3D
var build: Node3D
var model                     # character_model.gd: the animated KayKit model
var flash_mats: Array = []    # materials that turn red when hit
var death_timer := 0.0        # the body stays for a moment after dying
var guard_ring: MeshInstance3D
var overhead: Node3D
var label: Label3D
var hp_bar: Node3D                         # overhead health bar (trough + segments)
var hp_fill_mat: StandardMaterial3D
var hp_segs: Array[MeshInstance3D] = []
const HP_BAR_W := 1.1
const HP_BAR_H := 0.13
const HP_BAR_Y := 0.07
const HP_BAR_GAP := 0.025
var aim_marker: MeshInstance3D
var aim_ring: MeshInstance3D


func setup(p_game, p_team: int, p_is_player: bool, p_spawn: Vector3) -> void:
	game = p_game
	team = p_team
	is_player = p_is_player
	spawn_point = p_spawn
	position = p_spawn
	spawn_protect = Stats.SPAWN_PROTECT_TIME
	facing = Vector3(1, 0, 0) if team == 0 else Vector3(-1, 0, 0)
	aim = facing
	rotation.y = atan2(-facing.x, -facing.z)
	bot_offset = Vector3(randf_range(-2.5, 2.5), 0, randf_range(-2.5, 2.5))
	sidestep_sign = 1.0 if bot_offset.x > 0.0 else -1.0
	collision_layer = 2
	# The world, plus the ENEMY door (layer 4 = human door, layer 3 = elf door).
	collision_mask = 1 | 16 | (8 if team == 0 else 4)  # world, river banks, enemy door

	shape = CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.6
	shape.shape = capsule
	shape.position.y = 0.8
	add_child(shape)

	build = Node3D.new()
	add_child(build)

	# A soft shadow blob so everyone reads clearly from above.
	var blob := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.5
	disc.bottom_radius = 0.5
	disc.height = 0.02
	blob.mesh = disc
	blob.position.y = 0.02
	blob_mat = StandardMaterial3D.new()
	blob_mat.albedo_color = Color(0, 0, 0, 0.3)
	blob_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	blob_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	blob.material_override = blob_mat
	add_child(blob)

	# Shield Wall glow, hidden until used.
	guard_ring = MeshInstance3D.new()
	var guard_mesh := SphereMesh.new()
	guard_mesh.radius = 1.15
	guard_mesh.height = 2.3
	guard_mesh.radial_segments = 16
	guard_mesh.rings = 8
	guard_ring.mesh = guard_mesh
	guard_ring.position.y = 1.0
	var guard_mat := StandardMaterial3D.new()
	guard_mat.albedo_color = Color(0.5, 0.75, 1.0, 0.3)
	guard_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	guard_mat.emission_enabled = true
	guard_mat.emission = Color(0.4, 0.6, 1.0)
	guard_mat.emission_energy_multiplier = 0.8
	guard_mat.rim_enabled = true
	guard_mat.rim = 1.0
	guard_mat.rim_tint = 0.2
	guard_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	guard_ring.material_override = guard_mat
	guard_ring.visible = false
	add_child(guard_ring)

	# A ground ring under everyone (Faisal's 2026-10-08 reference): the
	# player's yellow, allies cyan, enemies red, each with a soft glow halo.
	side_ring = MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.58
	ring_mesh.outer_radius = 0.74
	side_ring.mesh = ring_mesh
	side_ring.position.y = 0.05
	side_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	side_ring_mat = StandardMaterial3D.new()
	side_ring_mat.albedo_color = Color(1, 1, 0.3)
	side_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	side_ring.material_override = side_ring_mat
	add_child(side_ring)
	side_glow = MeshInstance3D.new()
	var glow_mesh := TorusMesh.new()
	glow_mesh.inner_radius = 0.42
	glow_mesh.outer_radius = 1.02
	glow_mesh.rings = 6
	side_glow.mesh = glow_mesh
	side_glow.position.y = 0.04
	side_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	side_glow_mat = StandardMaterial3D.new()
	side_glow_mat.albedo_color = Color(1, 1, 0.3, 0.22)
	side_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	side_glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	side_glow_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	side_glow.material_override = side_glow_mat
	add_child(side_glow)
	if is_player:
		player_ring_mat = side_ring_mat

		# A pointer on the ground showing where you aim, and a ring at the cursor.
		aim_marker = MeshInstance3D.new()
		aim_marker.top_level = true
		var bar := BoxMesh.new()
		bar.size = Vector3(0.14, 0.04, 1.0)
		aim_marker.mesh = bar
		var bar_mat := StandardMaterial3D.new()
		bar_mat.albedo_color = Color(1, 1, 0.3)
		bar_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		aim_marker.material_override = bar_mat
		add_child(aim_marker)
		aim_ring = MeshInstance3D.new()
		aim_ring.top_level = true
		var cursor_mesh := TorusMesh.new()
		cursor_mesh.inner_radius = 0.28
		cursor_mesh.outer_radius = 0.4
		aim_ring.mesh = cursor_mesh
		aim_ring.material_override = bar_mat
		add_child(aim_ring)

	# Name and hearts float above the head, tilted to face the camera.
	overhead = Node3D.new()
	overhead.top_level = true
	overhead.rotation_degrees.x = -55.0
	add_child(overhead)
	label = Label3D.new()
	label.no_depth_test = true
	label.font_size = 32
	label.pixel_size = 0.0085
	label.outline_size = 12
	label.outline_modulate = Color(0.08, 0.06, 0.04)
	label.render_priority = 5
	label.outline_render_priority = 4
	label.position.y = 0.33
	overhead.add_child(label)
	# Health bar right under the name: a dark outlined trough, one fill
	# segment per heart (thin gaps keep "1 hit = 1 heart" readable).
	hp_bar = Node3D.new()
	hp_bar.position.y = HP_BAR_Y
	overhead.add_child(hp_bar)
	var frame := MeshInstance3D.new()
	var frame_quad := QuadMesh.new()
	frame_quad.size = Vector2(HP_BAR_W + 0.04, HP_BAR_H + 0.04)
	frame.mesh = frame_quad
	frame.material_override = _overhead_mat(Color(0.05, 0.04, 0.03, 0.95), 1)
	frame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hp_bar.add_child(frame)
	var trough := MeshInstance3D.new()
	var trough_quad := QuadMesh.new()
	trough_quad.size = Vector2(HP_BAR_W, HP_BAR_H)
	trough.mesh = trough_quad
	trough.position.z = 0.002
	trough.material_override = _overhead_mat(Color(0.16, 0.14, 0.13, 0.95), 2)
	trough.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hp_bar.add_child(trough)
	hp_fill_mat = _overhead_mat(Color(0.35, 0.85, 0.3), 3)
	# Veteran marker: a ring over the head, and a beam of light for an Elite so
	# everyone can see where the bounty is.
	bounty_ring = MeshInstance3D.new()
	var ring_mesh2 := TorusMesh.new()
	ring_mesh2.inner_radius = 0.42
	ring_mesh2.outer_radius = 0.52
	bounty_ring.mesh = ring_mesh2
	bounty_ring.rotation.x = PI / 2.0
	bounty_ring.position.y = 0.72
	bounty_ring_mat = StandardMaterial3D.new()
	bounty_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bounty_ring_mat.no_depth_test = true
	bounty_ring_mat.albedo_color = Color(1, 0.3, 0.2)
	bounty_ring.material_override = bounty_ring_mat
	bounty_ring.visible = false
	overhead.add_child(bounty_ring)
	bounty_beam = MeshInstance3D.new()
	var beam := CylinderMesh.new()
	beam.top_radius = 0.12
	beam.bottom_radius = 0.35
	beam.height = 9.0
	bounty_beam.mesh = beam
	bounty_beam.position.y = 6.5
	var beam_mat := StandardMaterial3D.new()
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	beam_mat.albedo_color = Color(1, 0.3, 0.2, 0.35)
	beam_mat.no_depth_test = true
	bounty_beam.material_override = beam_mat
	bounty_beam.visible = false
	add_child(bounty_beam)
	# The crown carrier's glow: a gold light and rising sparks, shown while carrying.
	carry_fx = Node3D.new()
	var cl := OmniLight3D.new()
	cl.light_color = Color(1.0, 0.8, 0.3)
	cl.light_energy = 1.6
	cl.omni_range = 5.0
	cl.position.y = 2.2
	carry_fx.add_child(cl)
	var cp := CPUParticles3D.new()
	cp.amount = 24
	cp.lifetime = 1.2
	cp.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	cp.emission_sphere_radius = 0.7
	cp.direction = Vector3.UP
	cp.initial_velocity_min = 0.8
	cp.initial_velocity_max = 1.6
	cp.gravity = Vector3(0, 0.5, 0)
	cp.scale_amount_min = 0.06
	cp.scale_amount_max = 0.14
	cp.color = Color(1.0, 0.85, 0.35)
	cp.position.y = 0.4
	var cpm := StandardMaterial3D.new()
	cpm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cpm.vertex_color_use_as_albedo = true
	cpm.albedo_color = Color(1.0, 0.85, 0.35)
	var cpq := QuadMesh.new()
	cpq.size = Vector2(1, 1)
	cpq.material = cpm
	cp.mesh = cpq
	carry_fx.add_child(cp)
	carry_fx.visible = false
	add_child(carry_fx)

	set_role(Role.BASE)


func stats() -> Dictionary:
	## The class table entry with the chosen variant's attack overrides and
	## abilities folded in.
	if _stats_cache.is_empty():
		_stats_cache = Stats.kit(team, role)
		var v := variant()
		if not v.is_empty():
			_stats_cache.merge(v.attack, true)
			_stats_cache.abilities = v.abilities
		if fire_form:
			# FIRE form: the base attack sets enemies alight, the abilities
			# come cheaper and quicker.
			_stats_cache.burn = true
			if _stats_cache.attack == "arrow" or _stats_cache.attack == "spell":
				_stats_cache.fire = true   # flaming arrows and fire bolts
			var fired := []
			for a in _stats_cache.abilities:
				var b: Dictionary = a.duplicate(true)
				b.cost = b.cost * Stats.FIRE_FORM.cost_mult
				b.cooldown = b.cooldown * Stats.FIRE_FORM.cooldown_mult
				fired.append(b)
			_stats_cache.abilities = fired
		if hat_upgraded and not Stats.hat_upgrade(team, role).is_empty():
			_stats_cache.abilities = _stats_cache.abilities + [Stats.hat_upgrade(team, role)]
	return _stats_cache


func variant() -> Dictionary:
	## The chosen variant of the current class, or {} for the plain class.
	if variants.has(role) and Stats.VARIANTS.has(role):
		return Stats.VARIANTS[role][variants[role]]
	return {}


func variant_unlocked(for_role: int = role) -> bool:
	return Stats.VARIANTS.has(for_role) and mastery.get(for_role, 0) >= Stats.VARIANT_UNLOCK


func gear_rank(for_role: int = role) -> int:
	## 1-4: the class's armour and weapon tier, stepped by its total upgrades.
	return 1 + mini(3, mastery.get(for_role, 0))


func total_upgrades() -> int:
	var n := 0
	for r in mastery:
		n += mastery[r]
	return n


func choose_variant(for_role: int, index: int) -> bool:
	## Promote a class to one of its two variants (or switch). Kept for the match.
	if dead or not variant_unlocked(for_role) or index < 0 or index >= Stats.VARIANTS[for_role].size():
		return false
	if variants.get(for_role, -1) == index:
		return false
	variants[for_role] = index
	game.sfx.play("promote", global_position, 0.0 if is_player else -6.0)
	if for_role == role:
		_stats_cache = {}
		ability_timers = [0.0, 0.0, 0.0]
		blocking = false
		model.setup(team, role, variant().name, game.hero_custom() if is_player else {}, gear_rank())
		flash_mats = model.flash_mats
		_apply_side_colors()
		_refresh_overhead()
		var gold := Color(1.0, 0.85, 0.3)
		game.spawn_pillar(global_position, gold, 5.0, 1.0)
		game.spawn_ring(global_position, 2.4, gold, 0.7)
		game.spawn_splash(global_position + Vector3(0, 0.6, 0), gold, 30, 5.0, 1.0, true)
		game.spawn_flash(global_position, gold, 4.0, 0.5)
		game.spawn_popup(global_position + Vector3(0, 2.4, 0), role_name().to_upper(), gold)
		if is_player:
			# (The rank-up flourish says PROMOTED! with the variant name; the
			# chat log keeps the line.)
			game.chat_system("You are now a %s!" % role_name())
			# The rank-up flourish, saying PROMOTED! with the new name.
			game.levelup_timer = 3.2
			game.levelup_level = level
			game.levelup_text = role_name()
		else:
			game.chat_system("%s became a %s." % [display_name, role_name()])
	return true


func role_name() -> String:
	var v := variant()
	var n: String = v.name if not v.is_empty() else Stats.FACTIONS[team].roles[role]
	return "%s %s" % [Stats.FIRE_FORM.prefix, n] if fire_form else n


func refresh_fire(announce: bool = true) -> void:
	## Into (or out of) FIRE form as our team takes (or loses) the Fire
	## Objective; plain soldiers without a class stay as they are.
	var want: bool = game.vmap != null and game.vmap.holds_fire(team) and role != Role.BASE and not dead
	if want == fire_form:
		return
	fire_form = want
	_stats_cache = {}
	_fire_look()
	_refresh_overhead()
	if not announce:
		return
	var flame: Color = Stats.FIRE_FORM.flame[team]
	if fire_form:
		game.spawn_pillar(global_position, flame, 4.0, 0.8)
		game.spawn_ring(global_position, 2.0, flame, 0.6)
		game.spawn_popup(global_position + Vector3(0, 2.4, 0), role_name().to_upper(), flame)
		if is_player:
			game.announce("FIRE FORM! You are a %s: your attacks set enemies alight." % role_name())
	elif is_player:
		game.toast("Your fire fades: the Fire Objective is lost", Color(1.0, 0.6, 0.35))


func _fire_look() -> void:
	## Flames licking up round a FIRE form fighter, and a warm glow.
	if fire_fx == null and fire_form:
		fire_fx = Node3D.new()
		add_child(fire_fx)
		var flame: Color = Stats.FIRE_FORM.flame[team]
		var p := CPUParticles3D.new()
		p.amount = 22
		p.lifetime = 0.7
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
		p.emission_ring_radius = 0.45
		p.emission_ring_inner_radius = 0.2
		p.emission_ring_height = 0.1
		p.emission_ring_axis = Vector3.UP
		p.direction = Vector3.UP
		p.spread = 12.0
		p.initial_velocity_min = 1.2
		p.initial_velocity_max = 2.2
		p.gravity = Vector3.ZERO
		p.scale_amount_min = 0.6
		p.scale_amount_max = 1.0
		var c := Curve.new()
		c.add_point(Vector2(0, 1))
		c.add_point(Vector2(1, 0))
		p.scale_amount_curve = c
		var sph := SphereMesh.new()
		sph.radius = 0.11
		sph.height = 0.22
		sph.radial_segments = 6
		sph.rings = 3
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(flame.r * 1.8, flame.g * 1.6, flame.b * 1.4)
		sph.material = m
		p.mesh = sph
		p.position = Vector3(0, 0.15, 0)
		fire_fx.add_child(p)
		var light := OmniLight3D.new()
		light.light_color = flame
		light.light_energy = 0.5
		light.omni_range = 2.6
		light.position = Vector3(0, 1.0, 0)
		fire_fx.add_child(light)
	if fire_fx:
		fire_fx.visible = fire_form


func class_name_plain() -> String:
	return Stats.FACTIONS[team].roles[role]


func energy_kind() -> String:
	return stats().energy


func energy_max() -> float:
	var base := Stats.MANA_MAX if energy_kind() == "mana" else Stats.STAMINA_MAX
	return base + Stats.VIGOR_ENERGY * rank(3)


func can_block() -> bool:
	return stats().get("block", false)


func abilities() -> Array:
	return stats().abilities


func set_role(new_role: int) -> void:
	role = new_role
	# A hat from an upgraded machine carries the class's extra move (economy.gd).
	hat_upgraded = new_role != Role.BASE and game.economy != null and game.economy.is_upgraded(team, new_role)
	hearts = max_hearts()
	energy = energy_max()
	ability_timers = [0.0, 0.0, 0.0]
	blocking = false
	_stats_cache = {}
	if model == null:
		model = CharacterModel.new()
		build.add_child(model)
	model.setup(team, role, variant().get("name", ""), game.hero_custom() if is_player else {}, gear_rank())
	flash_mats = model.flash_mats
	_apply_side_colors()
	refresh_fire(role != Role.BASE)
	_refresh_overhead()


func is_protected() -> bool:
	## Spawn protection, or standing in our own cellar (the sanctuary).
	return spawn_protect > 0.0 or game._in_cellar(team, global_position)


func max_hearts() -> int:
	return Stats.MAX_HEARTS + (Stats.ELITE_HEARTS_BONUS if veteran >= 2 else 0)


func _check_veteran() -> void:
	## Called after a kill: streaks make Veterans, long ones Elite Veterans.
	if streak >= Stats.ELITE_STREAK and veteran < 2:
		veteran = 2
		hearts = mini(hearts + Stats.ELITE_HEARTS_BONUS, max_hearts())
		game.announce_veteran(self, 2)
		game.spawn_pillar(global_position, Color(1.0, 0.5, 0.2), 8.0, 1.5)
	elif streak >= Stats.VETERAN_STREAK and veteran < 1:
		veteran = 1
		game.announce_veteran(self, 1)
		game.spawn_ring(global_position, 2.5, Color(1.0, 0.8, 0.3), 0.8)
	_refresh_overhead()


func is_enemy_of_player() -> bool:
	return team != game.player_team


func _apply_side_colors() -> void:
	## Friend or foe at a glance: enemies get a dark red outline and a red
	## shadow, allies dark green. Under the player's aim the outline glows.
	if model == null or model.outline == null:
		return
	var enemy := is_enemy_of_player()
	if carrying != null:
		# The crown carrier shines gold for everyone (Faisal 2026-10-08).
		model.outline.albedo_color = Color(1.0, 0.78, 0.2)
		model.outline.grow_amount = 0.05
		for m in flash_mats:
			m.emission_enabled = true
			m.emission = Color(1.0, 0.75, 0.25)
			m.emission_energy_multiplier = 0.1   # a warm sheen; the outline and rays do the shouting
		if blob_mat:
			blob_mat.albedo_color = Color(1.0, 0.75, 0.1, 0.5)
		_refresh_side_ring(enemy)
		return
	if is_player:
		for m in flash_mats:
			m.emission_enabled = false
	if is_player and game.couch_players > 1:
		# Couch play: every local player wears their own colour (outline,
		# ground ring, name over walls) so partners spot each other.
		model.outline.albedo_color = game.player_color(local_index)
		model.outline.grow_amount = 0.04
	elif is_player:
		model.outline.albedo_color = Color(0.09, 0.07, 0.1)
		model.outline.grow_amount = 0.028
	elif highlighted:
		model.outline.albedo_color = Color(1.0, 0.18, 0.12) if enemy else Color(0.25, 1.0, 0.4)
		model.outline.grow_amount = 0.045
	else:
		model.outline.albedo_color = Color(0.34, 0.05, 0.05) if enemy else Color(0.04, 0.24, 0.09)
		model.outline.grow_amount = 0.03
	if blob_mat:
		blob_mat.albedo_color = Color(0, 0, 0, 0.3) if is_player else (Color(0.7, 0.0, 0.0, 0.4) if enemy else Color(0.0, 0.5, 0.1, 0.35))
	_refresh_side_ring(enemy)
	# A faint glow over the whole body (Faisal 2026-10-07): green for
	# teammates, an even slighter red for enemies. The player stays as is.
	if not is_player:
		for m in flash_mats:
			m.emission_enabled = true
			m.emission = Color(1.0, 0.18, 0.12) if enemy else Color(0.25, 1.0, 0.4)
			m.emission_energy_multiplier = (0.1 if enemy else 0.12) * (2.0 if highlighted else 1.0)


func _refresh_side_ring(enemy: bool) -> void:
	## The ring and halo on the ground: a local player's own colour (yellow
	## for a lone player), cyan for allies, red for enemies; gold while
	## carrying the crown.
	if side_ring_mat == null:
		return
	var col := Color(1.0, 0.95, 0.3)
	if carrying != null:
		col = Color(1.0, 0.8, 0.2)
	elif is_player:
		col = game.player_color(local_index) if game.couch_players > 1 else Color(1.0, 0.95, 0.3)
	else:
		col = Color(1.0, 0.3, 0.2) if enemy else Color(0.35, 0.85, 1.0)
	side_ring_mat.albedo_color = col
	side_glow_mat.albedo_color = Color(col.r, col.g, col.b, 0.3 if (is_player or highlighted) else 0.2)


func set_highlight(on: bool) -> void:
	if on == highlighted:
		return
	highlighted = on
	_apply_side_colors()


func apply_blessing(kind: String) -> void:
	buff = kind
	buff_timer = Stats.BLESSING_DURATION
	regen_tick = Stats.BLESSING_REGEN_TICK
	var c: Color = Stats.BLESSING_KINDS[kind].color
	game.spawn_popup(global_position + Vector3(0, 2.4, 0), kind.to_upper(), c)
	if is_player:
		game.announce("Blessing of Light: %s! (%s for %d seconds)" % [kind, Stats.BLESSING_KINDS[kind].desc, int(Stats.BLESSING_DURATION)])
	else:
		game.chat_system("%s took the Blessing of %s." % [display_name, kind])


func _refresh_overhead() -> void:
	var tag := ("YOU · " if local_index <= 0 else "P%d · " % (local_index + 1)) if is_player else ""
	var lvl := ("  ★%d" % level) if level > 1 else ""
	var vet := ""
	if veteran == 2:
		vet = "BOUNTY · "
	elif veteran == 1:
		vet = "VETERAN · "
	# Every unit wears a tag: the player its own name, everyone else their
	# faction and class ("ELF HEALER", "HUMAN KNIGHT"), friend or foe alike
	# (Faisal 09:13 2026-10-09: "DONT JUST SAY HOSTILE"); the label's colour
	# still tells the teams apart.
	if is_player:
		label.text = vet + tag + role_name() + lvl
	else:
		label.text = vet + ally_tag()
	if is_player and game.couch_players > 1:
		label.modulate = game.player_color(local_index).lightened(0.3)
		label.no_depth_test = true   # visible through walls to the other panes
		if player_ring_mat:
			player_ring_mat.albedo_color = game.player_color(local_index)
	elif is_player:
		label.modulate = Color(1, 1, 0.6)
		if player_ring_mat:
			player_ring_mat.albedo_color = game.player_color(maxi(local_index, 0))
	else:
		label.modulate = Color(1.0, 0.7, 0.65) if is_enemy_of_player() else Color(0.7, 1.0, 0.75)
	if veteran == 2:
		label.modulate = Color(1.0, 0.45, 0.3) if is_enemy_of_player() else Color(1.0, 0.85, 0.4)
	if bounty_ring:
		bounty_ring.visible = veteran >= 1 and not dead
		bounty_ring_mat.albedo_color = (Color(1, 0.3, 0.2) if is_enemy_of_player() else Color(1, 0.85, 0.3)) if veteran == 2 else Color(0.95, 0.75, 0.3)
		bounty_beam.visible = veteran == 2 and not dead
		bounty_beam.material_override.albedo_color = Color(1, 0.3, 0.2, 0.3) if is_enemy_of_player() else Color(1, 0.85, 0.3, 0.25)
	label.visible = not dead and not downed   # the downed body carries the swirl and the revive bar instead
	if side_ring:
		side_ring.visible = not dead
		side_glow.visible = not dead
	_refresh_hp_bar()


func ally_tag() -> String:
	## "ELF KNIGHT", "HUMAN WARDEN"; a unit with no class yet is "ELF SOLDIER".
	var faction: String = Stats.FACTIONS[team].roles[Role.BASE].to_upper()
	return faction + " " + ("SOLDIER" if role == Role.BASE else role_name().to_upper())


func _overhead_mat(color: Color, priority: int) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA   # so render_priority orders the layers
	mat.no_depth_test = true   # same as the label: never hidden in a crowd
	mat.render_priority = priority
	mat.albedo_color = color
	return mat


func _refresh_hp_bar() -> void:
	if hp_bar == null:
		return
	hp_bar.visible = not dead and not downed
	var total := maxi(max_hearts(), 1)
	if hp_segs.size() != total:
		for seg in hp_segs:
			seg.queue_free()
		hp_segs.clear()
		var seg_w := (HP_BAR_W - HP_BAR_GAP * (total + 1)) / total
		for i in total:
			var seg := MeshInstance3D.new()
			var quad := QuadMesh.new()
			quad.size = Vector2(seg_w, HP_BAR_H - HP_BAR_GAP * 2.0)
			seg.mesh = quad
			seg.position = Vector3(-HP_BAR_W / 2.0 + HP_BAR_GAP + seg_w / 2.0 + i * (seg_w + HP_BAR_GAP), 0, 0.004)
			seg.material_override = hp_fill_mat
			seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			hp_bar.add_child(seg)
			hp_segs.append(seg)
	hp_fill_mat.albedo_color = Color(0.9, 0.2, 0.17) if (is_enemy_of_player() and not is_player) else Color(0.35, 0.85, 0.3)
	for i in hp_segs.size():
		hp_segs[i].visible = i < hearts


# --- Experience and ranks ----------------------------------------------------

func rank(track: int) -> int:
	## 0 = attack, 1 = Q, 2 = E, 3 = vigor.
	if not ranks.has(role):
		return 0
	return ranks[role][track]


func track_available(track: int) -> bool:
	return track == 0 or track == 3 or track - 1 < abilities().size()


func spend_point(track: int) -> bool:
	if points <= 0 or dead or not track_available(track) or rank(track) >= Stats.MAX_RANK:
		return false
	if not ranks.has(role):
		ranks[role] = [0, 0, 0, 0]
	ranks[role][track] += 1
	points -= 1
	spent.append([role, track])
	var old_rank := gear_rank()
	mastery[role] = mastery.get(role, 0) + 1
	if gear_rank() != old_rank:
		# New armour tier: redress the model.
		model.setup(team, role, variant().get("name", ""), game.hero_custom() if is_player else {}, gear_rank())
		flash_mats = model.flash_mats
		_apply_side_colors()
		_refresh_overhead()
		if is_player:
			game.toast("%s rank %d gear" % [class_name_plain(), gear_rank()], Color(1.0, 0.9, 0.5))
	if track == 3:
		energy = minf(energy + Stats.VIGOR_ENERGY, energy_max())
	game.spawn_ring(global_position, 1.6, Color(1.0, 0.85, 0.3), 0.5)
	game.spawn_splash(global_position + Vector3(0, 1.0, 0), Color(1.0, 0.85, 0.3), 14, 3.0, 0.5)
	game.spawn_flash(global_position, Color(1.0, 0.85, 0.3), 2.0, 0.3)
	if is_player:
		game.sfx.ui("rank_up", -3.0)
		game.spawn_popup(global_position + Vector3(0, 2.2, 0), "%s rank %d" % [track_name(track), rank(track)], Color(1, 0.9, 0.5))
		if mastery[role] == Stats.VARIANT_UNLOCK and not variants.has(role):
			game.announce("Promotion unlocked! Press %s and pick a %s variant." % [game.key_label("rank_menu"), class_name_plain()])
	elif variant_unlocked() and not variants.has(role):
		choose_variant(role, randi() % 2)
	return true


func track_name(track: int) -> String:
	match track:
		0: return stats().attack_name
		1, 2: return abilities()[track - 1].name if track - 1 < abilities().size() else "-"
	return "Vigor"


func gain_xp(amount: int, source: String = "combat") -> void:
	if dead or downed or amount <= 0:
		return
	xp += amount
	xp_sources[source] = xp_sources.get(source, 0) + amount
	if is_player:
		game.match_xp += amount
	var new_level := Stats.level_for_xp(xp)
	if new_level > level:
		points += new_level - level
		level = new_level
		peak_level = maxi(peak_level, level)
		_refresh_overhead()
		game.spawn_pillar(global_position, Color(1.0, 0.9, 0.4), 4.5, 1.0)
		game.spawn_ring(global_position, 2.2, Color(1.0, 0.9, 0.4), 0.6)
		game.spawn_splash(global_position + Vector3(0, 0.6, 0), Color(1.0, 0.9, 0.4), 24, 4.5, 0.9, true)
		game.spawn_popup(global_position + Vector3(0, 2.4, 0), "LEVEL %d" % level, Color(1, 0.9, 0.4))
		if is_player:
			game.sfx.ui("level_up", -2.0)
			# A brighter burst at your feet to go with the RANK UP! flourish.
			game.spawn_flash(global_position + Vector3(0, 1.0, 0), Color(1.0, 0.9, 0.4), 5.0, 0.5)
			game.levelup_timer = 3.2
			game.levelup_level = level
			game.levelup_text = ""
		else:
			_bot_spend()


func _lose_levels(n: int) -> void:
	## A fall: drop n levels, and the rank points they gave (unspent ones
	## first, then the most recently bought ranks). Class mastery and
	## promotions are kept.
	var to := maxi(level - n, 1)
	var lost := level - to
	level = to
	xp = Stats.xp_span(level)[0]
	var from_pool := mini(points, lost)
	points -= from_pool
	lost -= from_pool
	while lost > 0 and not spent.is_empty():
		var last: Array = spent.pop_back()
		if ranks.has(last[0]) and ranks[last[0]][last[1]] > 0:
			ranks[last[0]][last[1]] -= 1
		lost -= 1


func _bot_spend() -> void:
	# Bots like their attack first, then Q, E, then Vigor, and keep going round.
	var order := [0, 1, 2, 3]
	var guard := 0
	while points > 0 and guard < 16:
		guard += 1
		for t in order:
			if points > 0 and track_available(t) and rank(t) < Stats.MAX_RANK:
				spend_point(t)
				break
		var any_left := false
		for t in order:
			any_left = any_left or (track_available(t) and rank(t) < Stats.MAX_RANK)
		if not any_left:
			break


func ranked(a: Dictionary, track: int) -> Dictionary:
	## A copy of an attack or ability with this unit's rank applied.
	return ranked_at(a, track, rank(track))


func ranked_at(a: Dictionary, track: int, r: int) -> Dictionary:
	## The same at any rank r (the Upgrades page compares now and next).
	if r == 0:
		return a
	var out := a.duplicate()
	out.cooldown = a.cooldown * (1.0 - Stats.RANK_COOLDOWN_CUT * r)
	out.cost = a.cost * (1.0 - Stats.RANK_COST_CUT * r)
	# The base attack's reach stays put at every rank (it made ranked bows
	# out-range everyone); ranks make it quicker and cheaper instead.
	var grows: Array = ["distance", "radius", "duration", "haste", "splash", "heal_radius", "root"]
	if track != 0:
		grows.append("range")
	if r >= 2:
		for key in grows:
			if a.has(key):
				out[key] = a[key] * (1.0 + Stats.RANK_EFFECT_BOOST)
		if a.has("arrows"):
			out.arrows = a.arrows + 2
	if r >= 3:
		# Rank 3 widens the effect a little more and heals a heart more; it no
		# longer adds a heart of damage, so a maxed fighter is not twice a fresh one.
		if a.has("heal"):
			out.heal = a.heal + 1
		if a.has("gate_damage"):
			out.gate_damage = a.gate_damage + 1
		for key in ["distance", "radius", "splash", "heal_radius", "range"]:
			if a.has(key) and key in grows:
				out[key] = a[key] * (1.0 + Stats.RANK_EFFECT_BOOST * 1.5)
	return out


func attack_stats() -> Dictionary:
	var s := ranked(stats(), 0).duplicate()
	s.cost = Stats.BASE_ATTACK_COST   # basic attacks are free; cooldowns pace them
	if s.attack == "arrow" or s.attack == "spell":
		s = s.duplicate()
		s.cooldown = s.cooldown * Stats.RANGED_ATTACK_SLOW
	if buff == "Might" and buff_timer > 0.0:
		s = s.duplicate()
		s.damage = s.damage + 1
	return s


func ability(i: int) -> Dictionary:
	# The hat move (i == 2) has no rank track of its own.
	return ranked(abilities()[i], i + 1) if i < 2 else abilities()[i]


func vigor_speed() -> float:
	return 1.0 + Stats.VIGOR_SPEED * rank(3)


# --- Damage ------------------------------------------------------------------

func take_damage(amount: int, attacker = null, from: Vector3 = Vector3.INF, knock: float = 0.0, effect: Dictionary = {}) -> bool:
	## Returns true if the hit landed. `from` is where the hit came from, for
	## knockback and for the shield: a raised shield stops hits from the front.
	## `effect` can carry slow / root seconds.
	if dead:
		return false
	if downed:
		return _hit_while_downed(attacker)
	if dodge_timer > 0.0 or guard_timer > 0.0 or revive_protect > 0.0:
		return false  # mid-dodge, behind the shield wall or standing up from a revive: untouchable
	if is_protected():
		if attacker and attacker.is_player:
			game.spawn_popup(global_position + Vector3(0, 2.0, 0), "PROTECTED", Color(0.7, 0.9, 1.0))
		return false
	var push := Vector3.ZERO
	if from.is_finite():
		push = global_position - from
		push.y = 0.0
		push = push.normalized() if push.length() > 0.05 else facing
	if blocking and from.is_finite() and facing.dot(-push) > 0.1:
		# Blocked: no damage, but it costs stamina and shoves you a little.
		energy -= Stats.BLOCK_COST
		knockback = push * knock * 0.5
		game.spawn_splash(global_position + facing * 0.6 + Vector3(0, 1.0, 0), Color(0.9, 0.95, 1.0), 10, 4.0, 0.3)
		game.spawn_popup(global_position + Vector3(0, 2.0, 0), "BLOCKED", Color(0.75, 0.85, 1.0))
		Fx.of(game).hit(global_position + facing * 0.6 + Vector3(0, 1.0, 0), -push + Vector3(0, 0.2, 0), "frost")
		_hitstop(0.05)
		game.sfx.play("hit_shield", global_position, -1.0, 0.1)
		if energy <= 0.0:
			energy = 0.0
			blocking = false
			model.release()
		return false
	if stats().get("armour", 0.0) > 0.0:
		# Knights wear plate: every third hit (by default) glances off.
		resist_pool += stats().armour * amount
		if resist_pool >= 1.0:
			resist_pool -= 1.0
			game.spawn_popup(global_position + Vector3(0, 2.0, 0), "ARMOUR", Color(0.85, 0.85, 0.9))
			Fx.of(game).flare(global_position + Vector3(0, 1.1, 0) - push * 0.3, Color(0.9, 0.92, 1.0), 1.0)
			game.spawn_splash(global_position + Vector3(0, 1.0, 0), Color(0.85, 0.85, 0.9), 8, 3.0, 0.3)
			game.sfx.play("hit_shield", global_position, -4.0, 0.1)
			return false
	if home_defense:
		# Defending home: every tenth hit (by default) is shrugged off.
		resist_pool += Stats.DEFENDER.resist * amount
		if resist_pool >= 1.0:
			resist_pool -= 1.0
			game.spawn_popup(global_position + Vector3(0, 2.0, 0), "FORTIFIED", Color(0.7, 0.85, 1.0))
			game.spawn_splash(global_position + Vector3(0, 1.0, 0), Color(0.7, 0.85, 1.0), 8, 3.0, 0.3)
			return false
	hearts -= amount
	flash_timer = FLASH_TIME
	_hitstop(0.07 if amount < 2 else 0.11)
	if model:
		# A squash on the hit: wider and shorter, springing back.
		model.scale = Vector3(1.14, 0.88, 1.14)
		model.create_tween().tween_property(model, "scale", Vector3.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Fx.of(game).hit(global_position + Vector3(0, 1.0, 0) - push * 0.25, push, _hit_kind(attacker, effect), amount)
	last_hit_dir = push
	knockback = push * knock
	if effect.has("slow"):
		if slow_timer <= 0.0:   # say it once, not on every cut that refreshes it
			game.spawn_popup(global_position + Vector3(0, 1.6, 0), "SLOWED", Color(0.6, 0.85, 1.0))
		slow_timer = maxf(slow_timer, effect.slow)
	if effect.has("root"):
		root_timer = maxf(root_timer, effect.root)
		game.spawn_ring(global_position, 0.9, Color(0.6, 0.85, 1.0), 0.4, 0.15)
	if effect.get("burn", false) and burn_cd <= 0.0 and hearts > 0:
		burn_timer = Stats.FIRE_FORM.burn_delay
		burn_cd = Stats.FIRE_FORM.burn_cooldown
		burn_by = attacker
		game.spawn_popup(global_position + Vector3(0, 1.6, 0), "BURNING", Color(1.0, 0.55, 0.2))
	if attacker and attacker != self:
		attacker.gain_xp(Stats.XP_HIT * amount)
		attacker.damage_dealt += amount
		recent_hitters[attacker] = Time.get_ticks_msec() / 1000.0
	game.spawn_popup(global_position + Vector3(0, 2.0, 0), "-%d" % amount, Color(1, 0.35, 0.3))
	game.sfx.play("hurt", global_position, -4.0 if not is_player else 0.0, 0.15)
	# Weight in the sound too: a crunch under heavy blows, a crackle under spells.
	var hk := _hit_kind(attacker, effect)
	if amount >= 2 or hk == "heavy":
		game.sfx.play("hit_heavy", global_position, -2.0 if amount >= 2 else -7.0, 0.1)
	elif hk in ["arcane", "frost", "holy", "dark", "nature", "fire"]:
		game.sfx.play("hit_magic", global_position, -6.0, 0.12)
	if is_player:
		game.shake(0.35)
		game.rumble(self, 0.3, 0.8 if hearts <= 1 else 0.6, 0.22)
	if hearts <= 0:
		if game.demo and attacker and attacker != self:
			# Balance log: who killed whom, at what in-match level and role.
			print("KILL t=%d kteam=%d krole=%d klevel=%d kmastery=%d vteam=%d vrole=%d vlevel=%d vmastery=%d kfire=%d burn=%d" % [game.match_clock(),
				attacker.team, attacker.role, attacker.level, attacker.total_upgrades(), team, role, level, total_upgrades(),
				int(attacker.fire_form), int(burn_tick)])
		if is_player:
			var weapon: String = attacker.attack_stats().attack_name if (attacker and attacker != self and attacker.has_method("attack_stats")) else ""
			game.on_player_killed(attacker if attacker != self else null, weapon)
		if attacker and attacker != self:
			if attacker.is_player:
				game.shake(0.28)
				game.kick_cam(global_position - attacker.global_position, 0.22)
				game.sfx.ui("kill", -4.0)
				attacker._hitstop(0.1)
			if level - attacker.level >= 2:
				attacker.giant_kills += 1
			attacker.gain_xp(Stats.XP_KILL + Stats.XP_UPSET * maxi(level - attacker.level, 0), "takedowns")
			attacker.kills += 1
			attacker.streak += 1
			attacker.best_streak = maxi(attacker.best_streak, attacker.streak)
			# Assists for everyone else who hit us recently.
			var now_s := Time.get_ticks_msec() / 1000.0
			for h in recent_hitters:
				if is_instance_valid(h) and h != attacker and h.team == attacker.team and now_s - recent_hitters[h] < Stats.ASSIST_WINDOW:
					h.assists += 1
					h.gain_xp(Stats.XP_ASSIST, "takedowns")
			recent_hitters = {}
			# A kill feeds the next move: energy back and every cooldown cut.
			attacker.energy = minf(attacker.energy + Stats.KILL_ENERGY, attacker.energy_max())
			for i in attacker.ability_timers.size():
				attacker.ability_timers[i] = maxf(attacker.ability_timers[i] - Stats.KILL_COOLDOWN_CUT, 0.0)
			game.kill_feed.append({"killer": attacker.display_name, "kteam": attacker.team, "krole": attacker.role,
				"victim": display_name, "vteam": team, "vrole": role, "time": Time.get_ticks_msec() / 1000.0})
			if game.kill_feed.size() > 6:
				game.kill_feed.pop_front()
			if attacker.is_player:
				attacker.kill_banner = {"victim": display_name, "role": role_name(), "team": team, "role_id": role,
					"streak": attacker.streak, "time": Time.get_ticks_msec() / 1000.0}
				game.sfx.ui("rank_up", -2.0, 1.15 if attacker.streak < 2 else 1.0 + 0.1 * mini(attacker.streak, 5))
				game.rumble(attacker, 0.4, 0.7, 0.3)
				game.spawn_ring(attacker.global_position, 2.2, Color(1.0, 0.85, 0.3), 0.5)
			if veteran == 2 and attacker.team != team:
				game.bounty_claimed(attacker, self)
			attacker._check_veteran()
		game.chat_kill(attacker, self)
		if downed_enabled():
			_go_down(attacker)   # the kill is credited; a revive can still undo the fall
		else:
			_die()
		return true
	_refresh_overhead()
	if model and (model._now() >= model.busy_until or amount >= 2) and dodge_timer <= 0.0:
		# A flinch, from whichever side the blow came; a heavy blow cuts into
		# whatever the body was doing and lifts it off its feet a little.
		var side: float = facing.cross(Vector3.UP).dot(push)
		model.play_once("Hit_B" if side > 0.0 else "Hit_A", 1.5 if amount < 2 else 1.8, 0.5)
		if amount >= 2:
			var tw: Tween = model.create_tween()
			tw.tween_property(model, "position:y", 0.3, 0.09).set_ease(Tween.EASE_OUT)
			tw.tween_property(model, "position:y", 0.0, 0.14).set_ease(Tween.EASE_IN)
	if is_player:
		game.kick_cam(push, 0.18 if amount < 2 else 0.3)   # the view jolts the way the blow pushed
	# Bots roll sideways away from whatever just hit them, half the time.
	if not is_player and dodge_ready() and randf() < 0.5 * game.bot_tuning().react:
		try_dodge(facing.cross(Vector3.UP) * (1.0 if randf() < 0.5 else -1.0))
	return true


func heal(amount: int, healer = null) -> int:
	if dead or downed:
		return 0
	var before := hearts
	if burn_timer > 0.0 and amount > 0:
		burn_timer = 0.0   # mended: the fire goes out
	hearts = mini(hearts + amount, max_hearts())
	var healed := hearts - before
	if healed > 0 and home_defense:
		heal_pool += Stats.DEFENDER.heal * healed
		if heal_pool >= 1.0 and hearts < max_hearts():
			heal_pool -= 1.0
			hearts += 1
			healed += 1
	if healed > 0:
		_refresh_overhead()
		Fx.of(game).heal_on(self, healed, healer)
		game.spawn_popup(global_position + Vector3(0, 2.0, 0), "+%d" % healed, Color(0.4, 1.0, 0.5))
		if healer and healer != self:
			healer.gain_xp(Stats.XP_HEAL * healed, "support")
			healer.healing += healed
	return healed


func dodge_ready() -> bool:
	return dodge_cooldown <= 0.0 and not dead and carrying == null and root_timer <= 0.0 \
		and energy >= Stats.DODGE_COST


func try_dodge(dir: Vector3) -> void:
	if not dodge_ready():
		return
	dir.y = 0.0
	dodge_dir = dir.normalized() if dir.length() > 0.05 else facing
	facing = dodge_dir
	rotation.y = atan2(-facing.x, -facing.z)
	dodge_timer = Stats.DODGE_TIME
	dodge_cooldown = Stats.DODGE_COOLDOWN
	energy -= Stats.DODGE_COST
	blocking = false
	model.play_once("Dodge_Forward", 2.2)
	game.sfx.play("dodge", global_position, -4.0, 0.12)
	game.spawn_splash(global_position + Vector3(0, 0.2, 0), Color(0.9, 0.85, 0.7), 10, 2.5, 0.5)
	game.spawn_ring(global_position, 1.0, Color(1, 1, 1), 0.3, 0.2)


func ability_ready(i: int) -> bool:
	return i < abilities().size() and ability_timers[i] <= 0.0 and not dead and carrying == null \
		and energy >= ability(i).cost


func use_ability(i: int, dir: Vector3) -> void:
	if not ability_ready(i):
		return
	var a: Dictionary = ability(i)
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.05 else facing
	# Building needs a legal spot and tuning needs something to tune: check
	# before anything is spent.
	var turret_pos := Vector3.INF
	var tune_target = null
	if a.kind == "turret":
		turret_pos = game.turret_spot(team, global_position + dir * Stats.TURRET.place_dist, self)
		if not turret_pos.is_finite():
			if is_player:
				game.toast("Turrets go on your castle walls or grounds, clear of the door lane", Color(1.0, 0.8, 0.5))
				game.sfx.ui("ui_deny", -6.0)
			return
	elif a.kind == "upgrade":
		tune_target = _tune_target(a)
		if tune_target == null:
			if is_player:
				game.toast("Nothing to tune up here: stand by one of your turrets or your door", Color(1.0, 0.8, 0.5))
				game.sfx.ui("ui_deny", -6.0)
			return
	energy -= a.cost
	ability_timers[i] = a.cooldown
	facing = dir
	blocking = false
	var ability_sound := {"bash": "swing_heavy", "guard": "block_up", "volley": "volley", "trap": "trap_set",
		"fireball": "frost" if a.get("frost", false) else "fireball", "blink": "blink", "blessing": "blessing", "smite": "smite",
		"shot": "bow", "cleave": "fireball" if a.get("fire", false) else "swing_heavy", "smoke": "blink", "curse": "curse", "bubble": "blessing"}
	if ability_sound.has(a.kind):
		game.sfx.play(ability_sound[a.kind], global_position, -1.0, 0.08)
	rotation.y = atan2(-facing.x, -facing.z)
	# A rune circle under every spell as it leaves the hands.
	var cast_color := {"fireball": Color(0.6, 0.85, 1.0) if a.get("frost", false) else (Color(0.5, 0.9, 0.35) if a.get("nature", false) else Color(1.0, 0.55, 0.15)),
		"smite": Color(0.6, 0.3, 0.9) if stats().get("drain", false) else Color(1.0, 0.92, 0.5), "blessing": Color(1.0, 0.95, 0.55),
		"curse": Color(0.6, 0.25, 0.85), "bubble": Color(1.0, 0.95, 0.65), "blink": Color(0.7, 0.45, 1.0), "guard": Color(0.55, 0.8, 1.0)}
	if cast_color.has(a.kind):
		Fx.of(game).cast(self, cast_color[a.kind], 1.0 if a.kind != "blessing" else 1.6)
	# Each skill's own body animation and particles (scripts/skill_fx.gd).
	SkillFx.cast(self, a, dir)
	var cast_from := global_position
	_ability_effect(a, dir, turret_pos, tune_target)
	SkillFx.land(self, a, dir, cast_from)


func _ability_effect(a: Dictionary, dir: Vector3, turret_pos: Vector3, tune_target) -> void:
	match a.kind:
		"turret":
			_prune_turrets()
			while turrets.size() >= int(a.get("turrets", 2)):
				var old = turrets.pop_front()
				if is_instance_valid(old):
					game.spawn_splash(old.global_position + Vector3(0, 1.0, 0), Color(0.6, 0.5, 0.4), 14, 3.0, 0.6)
					game.remove_turret(old)
					old.queue_free()
			var t = game.spawn_turret(team, turret_pos, self, {"rapid": a.get("rapid", false), "ballista": a.get("ballista", false), "thorn": a.get("thorn", false)})
			turrets.append(t)
			if is_player:
				game.spawn_popup(global_position + Vector3(0, 2.2, 0), "%s built  (%d / %d)" % [t.kind_name(), turrets.size(), int(a.get("turrets", 2))], Color(1, 0.9, 0.5))
		"upgrade":
			if tune_target is Turret:
				tune_target.upgrade()
				if is_player:
					game.spawn_popup(tune_target.global_position + Vector3(0, 2.4, 0), "LEVEL %d" % tune_target.level, Color(1, 0.9, 0.5))
			else:
				# Our door: mend it, or hurry the rebuild.
				var gate = tune_target
				if gate.broken:
					gate.rebuild_timer = maxf(gate.rebuild_timer - Stats.TURRET.door_repair, 0.5)
				else:
					gate.hp = mini(gate.hp + int(a.get("door", 0)), Stats.GATE_HITS)
					gate._refresh()
				game.spawn_ring(gate.global_position, 2.5, Color(1.0, 0.85, 0.3), 0.5)
				game.spawn_splash(gate.global_position + Vector3(0, 1.5, 0), Color(1.0, 0.85, 0.3), 20, 4.0, 0.6, true)
				game.sfx.play("door_rebuilt", gate.global_position, -2.0)
				if is_player:
					game.spawn_popup(global_position + Vector3(0, 2.2, 0), "DOOR REPAIRED" if not gate.broken else "REBUILD HURRIED", Color(1, 0.9, 0.5))
		"overclock":
			_prune_turrets()
			for t in turrets:
				t.overclock = a.duration
				game.spawn_ring(t.global_position, 1.2, Color(0.7, 0.9, 1.0), 0.5)
			game.spawn_flash(global_position, Color(0.7, 0.9, 1.0), 3.0, 0.4)
			game.sfx.play("turret_upgrade", global_position, 0.0, 0.0)
		"bash":
			# A short dash that hits and shoves everyone in its path.
			dodge_dir = dir
			bash_timer = 0.2 if a.distance <= 4.5 else 0.3
			bash_speed = a.distance / bash_timer
			bash_hit = []
			bash_damage = a.damage
			bash_root = a.get("root", 0.0)
			game.spawn_splash(global_position + Vector3(0, 0.3, 0), Color(0.8, 0.85, 1.0), 12, 3.0, 0.4)
			game.spawn_ring(global_position, 1.8, Color(0.7, 0.8, 1.0), 0.35)
			Fx.of(game).burst(global_position + Vector3(0, 0.9, 0), Color(0.9, 0.95, 1.0), 10, 7.0, 0.3, Fx.STYLE_SPARK, -dir, 25.0)
			Fx.of(game).slash(global_position, dir, Color(0.85, 0.92, 1.0), 1.2, true)
		"guard":
			guard_timer = a.duration
			guard_ring.visible = true
			if a.has("share"):
				for ally in game.units:
					if ally != self and ally.team == team and not ally.dead and _flat_to(ally.global_position).length() <= a.share:
						ally.guard_timer = maxf(ally.guard_timer, a.duration * 0.5)
						ally.guard_ring.visible = true
			game.spawn_ring(global_position, 2.0, Color(0.5, 0.75, 1.0), 0.4)
			game.spawn_flash(global_position, Color(0.5, 0.75, 1.0), 2.0, 0.3)
		"bubble":
			# A dome of light over you and the teammates inside it: untouchable.
			bubble_up(a.duration)
			for ally in game.units:
				if ally != self and ally.team == team and not ally.dead and _flat_to(ally.global_position).length() <= a.radius:
					ally.bubble_up(a.duration)
			game.spawn_ring(global_position, a.radius, Color(1.0, 0.95, 0.6), 0.6)
			game.spawn_flash(global_position + Vector3(0, 1, 0), Color(1.0, 0.95, 0.6), 3.0, 0.4)
			game.spawn_splash(global_position + Vector3(0, 1.2, 0), Color(1.0, 0.95, 0.7), 24, 4.0, 0.8, true)
		"volley":
			var look: Array = SkillFx.shot(self, a, Color(0.95, 0.9, 0.7))
			for k in a.arrows:
				var ang: float = deg_to_rad(a.spread) * (float(k) / (a.arrows - 1) - 0.5)
				game.spawn_shot(self, dir.rotated(Vector3.UP, ang),
					{"damage": a.damage, "gate_damage": 1, "range": a.range, "shot_speed": a.shot_speed, "look": look[1]}, look[0])
			game.spawn_splash(global_position + dir * 0.8 + Vector3(0, 1.1, 0), Color(0.95, 0.9, 0.7), 8, 3.0, 0.25)
			_recoil(dir, 3.0)
		"trap":
			for k in a.get("count", 1):
				game.spawn_trap(self, global_position + dir * (1.5 + k * 1.5), a)
		"fireball":
			var frost: bool = a.get("frost", false)
			var nature: bool = a.get("nature", false)
			var ball := {"damage": a.damage, "gate_damage": 4, "range": a.range, "splash": a.splash, "shot_speed": a.shot_speed,
				"fire": not frost and not nature, "frost": frost, "nature": nature, "look": "thorn" if nature else ""}
			if a.has("root"):
				ball.root = a.root
			var ball_color := Color(0.6, 0.85, 1.0) if frost else (SkillFx.LEAF if nature else Color(1.0, 0.5, 0.1))
			game.spawn_shot(self, dir, ball, ball_color)
			game.spawn_flash(global_position + dir, ball_color, 3.0, 0.3)
			_recoil(dir, 3.5)
		"blink":
			var from := global_position + Vector3(0, 0.9, 0)
			var to: Vector3 = from + dir * a.distance
			var ray := PhysicsRayQueryParameters3D.create(from, to, collision_mask)
			var hit := get_world_3d().direct_space_state.intersect_ray(ray)
			if hit:
				to = hit.position - dir * 0.8
			# Never land in the river (the ray clears the island's rims and
			# the bank walls when cast from up on the shrine): stop short.
			var steps := 0
			while game.in_channel(Vector3(to.x, 0, to.z)) and steps < 12:
				to -= dir * 0.5
				steps += 1
			if steps >= 12:
				to = from
			game.spawn_splash(global_position + Vector3(0, 1.0, 0), Color(0.7, 0.45, 1.0), 16, 3.0, 0.5)
			game.spawn_ring(global_position, 1.5, Color(0.7, 0.45, 1.0), 0.4)
			game.spawn_flash(global_position, Color(0.7, 0.45, 1.0), 2.5, 0.3)
			global_position = Vector3(to.x, global_position.y, to.z)
			game.spawn_splash(global_position + Vector3(0, 1.0, 0), Color(0.7, 0.45, 1.0), 16, 3.0, 0.5)
			game.spawn_ring(global_position, 1.5, Color(0.7, 0.45, 1.0), 0.4)
			game.spawn_flash(global_position, Color(0.7, 0.45, 1.0), 2.5, 0.3)
		"blessing":
			for ally in game.units:
				if ally.team == team and not ally.dead and _flat_to(ally.global_position).length() <= a.radius:
					ally.heal(a.heal, self)
					ally.haste_timer = a.haste
					if a.has("shield"):
						ally.guard_timer = maxf(ally.guard_timer, a.shield)
						ally.guard_ring.visible = true
			game.spawn_ring(global_position, a.radius, Color(1.0, 0.95, 0.5), 0.7)
			game.spawn_pillar(global_position, Color(1.0, 0.95, 0.6), 4.0, 0.8)
			game.spawn_flash(global_position, Color(1.0, 0.95, 0.5), 4.0, 0.5)
			game.spawn_splash(global_position + Vector3(0, 0.5, 0), Color(1.0, 0.95, 0.5), 30, 5.0, 1.0, true)
		"smite":
			var dark: bool = stats().get("drain", false)
			var bolt_color := Color(0.6, 0.3, 0.9) if dark else (Color(0.75, 0.9, 1.0) if a.has("slow") else Color(1.0, 0.95, 0.5))
			var bolt := {"damage": a.damage, "gate_damage": 1, "range": a.range,
				"shot_speed": a.shot_speed, "holy": true, "splash": a.get("splash", 0.0)}
			if a.has("slow"):
				bolt["slow"] = a.slow
			var look: Array = SkillFx.shot(self, a, bolt_color)
			bolt["look"] = look[1]
			bolt_color = look[0] if not dark else bolt_color
			game.spawn_shot(self, dir, bolt, bolt_color)
			game.spawn_flash(global_position + dir, bolt_color, 2.0, 0.25)
			_recoil(dir, 2.0)
		"shot":
			game.spawn_shot(self, dir, {"damage": a.damage, "gate_damage": a.get("gate_damage", 1), "range": a.range,
				"shot_speed": a.shot_speed, "pierce": a.get("pierce", false)}, SkillFx.shot(self, a, Color(0.95, 0.9, 0.7))[0])
			game.spawn_splash(global_position + dir * 0.8 + Vector3(0, 1.1, 0), Color(0.95, 0.9, 0.7), 8, 3.0, 0.25)
			_recoil(dir, 3.0 if a.damage < 2 else 5.0)
		"cleave":
			# A spin (or a fan of fire) that hits everyone around (or in front).
			var fire: bool = a.get("fire", false)
			var c: Color = Color(1.0, 0.55, 0.15) if fire else a.get("color", Color(0.85, 0.9, 1.0))
			var landed := false
			for other in game.units:
				if other.team == team or other.dead:
					continue
				var to := _flat_to(other.global_position)
				var dist := to.length()
				if dist > a.radius or absf(other.global_position.y - global_position.y) > 1.5:
					continue
				if a.get("cone", false) and dist > 0.8 and dir.dot(to / dist) < 0.35:
					continue
				landed = other.take_damage(a.damage, self, global_position, 9.0, {"fx": "fire" if fire else "heavy"}) or landed
			if a.get("cone", false):
				for k in 7:
					var ang: float = deg_to_rad(70.0) * (float(k) / 6.0 - 0.5)
					var p: Vector3 = global_position + dir.rotated(Vector3.UP, ang) * a.radius * 0.6
					game.spawn_splash(p + Vector3(0, 0.6, 0), c, 10, 4.0, 0.5, true)
				game.spawn_flash(global_position + dir * 2.0, c, 4.0, 0.35)
			else:
				game.spawn_ring(global_position, a.radius, c, 0.4, 0.25)
				game.spawn_splash(global_position + Vector3(0, 1.0, 0), c, 24, 6.0, 0.45)
				for k in 2:
					Fx.of(game).slash(global_position, dir.rotated(Vector3.UP, PI * k), c, a.radius / 1.75, true, k == 1)
				game.spawn_flash(global_position, c, 3.0, 0.3)
			if landed and is_player:
				game.shake(0.2)
				game.rumble(self, 0.5, 0.2, 0.12)
		"smoke":
			stealth_timer = a.duration
			haste_timer = maxf(haste_timer, a.haste)
			game.spawn_splash(global_position + Vector3(0, 0.8, 0), Color(0.5, 0.5, 0.55), 40, 3.0, 1.6, true)
			game.spawn_ring(global_position, 2.0, Color(0.6, 0.6, 0.65), 0.5, 0.3)
		"curse":
			var purple: Color = a.get("color", Color(0.6, 0.25, 0.85))
			for other in game.units:
				if other.team != team and not other.dead and _flat_to(other.global_position).length() <= a.radius:
					other.take_damage(a.damage, self, global_position, 3.0, {"slow": a.slow, "fx": "dark"})
					game.spawn_pillar(other.global_position, purple, 2.5, 0.6)
			game.spawn_ring(global_position, a.radius, purple, 0.7, 0.2)
			game.spawn_splash(global_position + Vector3(0, 0.5, 0), purple, 30, 4.0, 0.9, true)
			game.spawn_flash(global_position, purple, 4.0, 0.5)


func _hitstop(t: float) -> void:
	## Freeze the model's animation for a beat so blows land with weight.
	## Looks only: movement, timers and the bot brain carry on.
	if model == null or model.anim == null:
		return
	hitstop_timer = maxf(hitstop_timer, t)
	model.anim.speed_scale = 0.0


func _flash_look() -> void:
	## Hit flash: a white-hot rim for the first frames, then a red tint that
	## eases back to the normal skin.
	var k := flash_timer / FLASH_TIME
	var white := k > 0.7
	for m in flash_mats:
		m.albedo_color = model.tint.lerp(Color(1.0, 0.3, 0.28), clampf(k * 1.4, 0.0, 1.0)) if not white else Color(1.0, 0.85, 0.8)
		m.rim = 1.0 if white else 0.35
		m.rim_tint = 0.0 if white else 0.6


func _swing_kind(s: Dictionary) -> String:
	## Which hit effect a melee swing makes.
	if s.get("burn", false):
		return "fire"
	if s.has("slow"):
		return "venom"
	if role == Role.BASE:
		return "fist"
	return "heavy" if s.range > 2.5 else "melee"


func _hit_kind(attacker, effect: Dictionary) -> String:
	## Which hit effect a landed blow makes: the caller's word, else a guess
	## from the attacker's base attack.
	if effect.has("fx"):
		return effect.fx
	if attacker == null or not is_instance_valid(attacker) or not attacker.has_method("attack_stats"):
		return "arrow"   # turrets, traps
	if effect.get("burn", false):
		return "fire"
	var s: Dictionary = attacker.stats()
	if s.attack == "arrow":
		return "arrow"
	if s.attack == "spell" or s.attack == "heal":
		if s.get("fire", false):
			return "fire"
		if s.get("frost", false):
			return "frost"
		if s.get("nature", false):
			return "nature"
		return "dark" if s.get("drain", false) else "arcane"
	return attacker._swing_kind(s)


func _status_auras() -> void:
	## Looping auras while a status lasts: venom slow, root, haste, guard.
	if game == null or dead:
		for e in status_fx.values():
			e.emitting = false
		return
	var want := {"slow": slow_timer > 0.0, "root": root_timer > 0.0, "haste": haste_timer > 0.0 and stealth_timer <= 0.0,
		"guard": guard_timer > 0.0}
	for k in want:
		if want[k] and not status_fx.has(k):
			status_fx[k] = Fx.of(game).status_emitter(self, k)
		if status_fx.has(k) and status_fx[k].emitting != want[k]:
			status_fx[k].emitting = want[k]


func _recoil(dir: Vector3, amount: float) -> void:
	knockback -= dir * amount
	if is_player:
		game.shake(amount * 0.05)
		game.rumble(self, clampf(amount * 0.08, 0.1, 0.5), 0.0, 0.08)


func _die() -> void:
	# A downed unit dying (finished off, bled out, skipped) already paid for
	# the fall when it went down: only the body and the timer are left.
	var was_down := downed
	var timer_level: int = down_snapshot.get("level", level) if was_down else level
	if was_down:
		_end_downed()
	executed_by = null
	dead = true
	burn_timer = 0.0
	hearts = 0
	shape.disabled = true
	death_timer = 1.6 if was_down else 1.1
	if not was_down:
		model.die()   # a finished body is already on the ground: it just stays down
	respawn_timer = minf(Stats.RESPAWN_TIME + Stats.RESPAWN_PER_LEVEL * (timer_level - 1), Stats.RESPAWN_MAX)
	respawn_total = respawn_timer
	fell_level = timer_level
	var fell_from := level
	if not was_down:
		_fall()
	velocity = Vector3.ZERO
	if is_player and fell_from > 1 and not was_down:
		# (The HUD death screen carries this; the chat log keeps the line.)
		game.chat_system("You fell at level %d: down to level %d, back in %d seconds." % [fell_from, level, int(respawn_timer)])
	_death_fling()
	Fx.of(game).death(global_position, Stats.FACTIONS[team].color)
	game.sfx.play("death", global_position, 0.0, 0.1)
	if aim_marker:
		aim_marker.visible = false
		aim_ring.visible = false
	_refresh_overhead()   # hide the name tag and health bar while down


func _fall() -> void:
	## What losing your last heart costs, whether you die or go down: the
	## crown drops, streaks end, the death counts and levels are lost.
	last_role = role
	if carrying:
		game.drop_monarch(self)
	if veteran > 0:
		game.chat_system("%s's streak of %d ends." % [display_name, streak])
	streak = 0
	veteran = 0
	buff = ""
	buff_timer = 0.0
	guard_timer = 0.0
	blocking = false
	guard_ring.visible = false
	deaths += 1
	if game._inside_castle(1 - team, global_position):
		game.raid_deaths[team] += 1
	stealth_timer = 0.0
	slow_timer = 0.0
	overhead.visible = true
	_lose_levels(Stats.DEATH_LEVEL_LOSS)


# --- Downed and revive -------------------------------------------------------
# Losing your last heart knocks you down (stats.gd DOWNED_TIME). The fall is
# paid at once (_fall: kill credit, crown dropped, levels lost); a revive
# hands the levels back, and anything else ends in the usual _die().

var down_fx: Node3D           # ground ring under a downed unit
var down_ring: MeshInstance3D
var down_ring_mat: StandardMaterial3D
var down_cross: Node3D        # green cross over the body (on the overhead)
var down_cross_mat: StandardMaterial3D
var down_bar: Node3D          # bleed-out (red, draining) / revive (gold, filling)
var down_bar_fill: MeshInstance3D
var down_bar_mat: StandardMaterial3D
var revive_frame := -10       # physics frame a teammate last worked on us


func downed_enabled() -> bool:
	## Overtime is sudden death; --no-downed turns the feature off for
	## before/after balance batches.
	return Stats.DOWNED_TIME > 0.0 and not game.overtime and not game.no_downed


func _go_down(attacker) -> void:
	down_snapshot = {"level": level, "xp": xp, "points": points, "ranks": ranks.duplicate(true), "spent": spent.duplicate(true)}
	_fall()
	downed = true
	hearts = 0
	downed_total = Stats.DOWNED_TIME
	downed_timer = downed_total
	downed_by = attacker
	skip_hold = 0.0
	revive_progress = 0.0
	revive_by = null
	revive_target = null
	bot_down_wait = 0.0
	velocity = Vector3.ZERO
	knockback = Vector3.ZERO
	dodge_timer = 0.0
	bash_timer = 0.0
	model.go_down()
	_build_down_fx()
	down_fx.visible = true
	game.spawn_splash(global_position + Vector3(0, 0.6, 0), Color(0.3, 0.3, 0.35), 14, 2.5, 0.7)
	game.spawn_ring(global_position, 1.2, Color(0.9, 0.3, 0.25), 0.45)
	game.sfx.play("death", global_position, -4.0, 0.1)
	if aim_marker:
		aim_marker.visible = false
		aim_ring.visible = false
	if game.demo:
		var mate = _nearest_standing_ally()
		print("DOWN t=%d team%d %s ally=%.0f foes=%d" % [game.match_clock(), team, role_name(), _flat_to(mate.global_position).length() if mate else 99.0, game.enemies_near(team, global_position, 6.0)])
	_refresh_overhead()


func _end_downed() -> void:
	downed = false
	downed_timer = 0.0
	downed_by = null
	skip_hold = 0.0
	revive_progress = 0.0
	revive_by = null
	down_snapshot = {}
	if down_fx:
		down_fx.visible = false
	if down_cross:
		down_cross.visible = false
		down_bar.visible = false


func _hit_while_downed(attacker, finisher: bool = false) -> bool:
	## Any enemy hit (or a trap) finishes a downed unit off; `finisher` is
	## the deliberate move landing (no grace check: the hold already waited).
	if attacker != null and (attacker == self or attacker.team == team):
		return false
	if not finisher and downed_total - downed_timer < Stats.DOWNED_GRACE:
		return false
	if executed_by and is_instance_valid(executed_by) and executed_by != attacker:
		return false   # someone else's finisher is already coming down
	_finish_fx(attacker)
	if is_player:
		game.killer_card = {"unit": attacker, "weapon": "a finisher", "finished": true} if attacker else {}
		game.killer_timer = 6.0
	if attacker:
		attacker.gain_xp(Stats.XP_FINISH, "takedowns")
		if attacker.is_player:
			attacker.kill_banner = {"victim": display_name, "role": role_name(), "team": team, "role_id": role,
				"streak": 0, "time": Time.get_ticks_msec() / 1000.0, "finish": true}
		# The finisher shows in the kill feed too (the down already counted
		# as the kill for whoever knocked us down).
		game.kill_feed.append({"killer": attacker.display_name, "kteam": attacker.team, "krole": attacker.role,
			"victim": display_name, "vteam": team, "vrole": role, "time": Time.get_ticks_msec() / 1000.0, "finish": true})
		if game.kill_feed.size() > 6:
			game.kill_feed.pop_front()
	if game.demo:
		print("FINISH t=%d team%d %s by=%s" % [game.match_clock(), team, role_name(), attacker.role_name() if attacker else "trap"])
	_die()
	return true


func revive_time() -> float:
	return Stats.HEALER_REVIVE_TIME if role == Role.HEALER else Stats.REVIVE_TIME


func revive_reach() -> float:
	return Stats.HEALER_REVIVE_RANGE if role == Role.HEALER else Stats.REVIVE_RANGE


func finished_by():
	## The enemy finishing us right now (holding over us, or mid-move), or null.
	if executed_by and is_instance_valid(executed_by):
		return executed_by
	for other in game.units:
		if other.team != team and other.finish_target == self and other.finish_progress > 0.0 \
				and Engine.get_physics_frames() - other.finish_frame <= 2:
			return other
	return null


func being_revived() -> bool:
	return downed and revive_by != null and Engine.get_physics_frames() - revive_frame <= 2


func revive_candidate():
	## The downed teammate this unit could revive right now, or null.
	if dead or downed or carrying:
		return null
	var best = null
	var best_d := revive_reach()
	for other in game.units:
		if other == self or other.team != team or not other.downed or other.executed_by != null:
			continue
		var d := _flat_to(other.global_position).length()
		if d <= best_d:
			best_d = d
			best = other
	return best


func _tick_revive(t, delta: float) -> void:
	## Hold interact over a downed teammate: fill their revive bar.
	revive_target = t
	t.revive_by = self
	t.revive_frame = Engine.get_physics_frames()
	t.revive_progress += delta / revive_time()
	facing = _flat_to(t.global_position).normalized() if _flat_to(t.global_position).length() > 0.1 else facing
	rotation.y = atan2(-facing.x, -facing.z)
	if model and model._now() >= model.busy_until:
		model.play_once("Spellcast_Long" if role == Role.HEALER else "Interact", 1.0)
	if Engine.get_physics_frames() % 10 == 0:
		game.spawn_splash(t.global_position + Vector3(0, 0.5, 0), Color(0.5, 1.0, 0.55) if role == Role.HEALER else Color(1.0, 0.85, 0.4), 3, 1.2, 0.6, true)
	if t.revive_progress >= 1.0:
		t._revive(self)
		revive_target = null


var finish_target = null      # (enemy side) the downed enemy we are finishing with a hold
var finish_progress := 0.0
var finish_frame := -10


func finish_candidate():
	## A downed enemy close enough to finish with a hold of interact, or null.
	if dead or downed or carrying:
		return null
	var best = null
	var best_d := Stats.REVIVE_RANGE
	for other in game.units:
		if other.team == team or not other.downed or other.executed_by != null:
			continue
		var d := _flat_to(other.global_position).length()
		if d <= best_d:
			best_d = d
			best = other
	return best


func can_finish(t) -> bool:
	return t.downed and t.downed_total - t.downed_timer >= Stats.DOWNED_GRACE


func _tick_finish(t, delta: float) -> void:
	## Hold interact over a downed enemy: a deliberate finisher.
	if finish_target != t:
		finish_progress = 0.0
	finish_target = t
	finish_frame = Engine.get_physics_frames()
	if not can_finish(t):
		return
	finish_progress += delta / Stats.FINISH_HOLD
	facing = _flat_to(t.global_position).normalized() if _flat_to(t.global_position).length() > 0.1 else facing
	rotation.y = atan2(-facing.x, -facing.z)
	# Wind-up: weapon raised over the body while the hold fills.
	if model and model._now() >= model.busy_until:
		model.play_once(_finisher_anims()[0], 0.9)
	if Engine.get_physics_frames() % 8 == 0:
		game.spawn_splash(t.global_position + Vector3(0, 0.4, 0), Color(0.9, 0.2, 0.15), 2, 1.0, 0.5, true)
	if finish_progress >= 1.0:
		finish_progress = 0.0
		finish_target = null
		_start_finisher(t)


# --- Finishers ----------------------------------------------------------------
# A finisher is a short locked move: the finisher steps in and strikes with
# a class-specific heavy blow (FINISH_ANIM seconds), the blow lands at
# FINISH_IMPACT, and the downed body is finished with a burst. While it plays
# the body can't be revived or crawl away.

var finishing := 0.0          # seconds left in our finisher move
var finish_victim = null
var finish_struck := false
var executed_by = null        # (victim side) the enemy finishing us


func _finisher_anims() -> Array:
	## [wind-up, strike] for this class.
	match role:
		Role.RANGER:
			return ["2H_Ranged_Aiming", "2H_Ranged_Shoot"]
		Role.MAGE:
			return ["Spellcast_Raise", "Spellcast_Shoot"]
		Role.HEALER:
			return ["Spellcast_Raise", "Spellcast_Long"]
		Role.ROGUE:
			return ["Dualwield_Melee_Attack_Chop", "Dualwield_Melee_Attack_Stab"]
		_:
			return ["2H_Melee_Idle", "2H_Melee_Attack_Chop"]


func _start_finisher(t) -> void:
	finishing = Stats.FINISH_ANIM
	finish_victim = t
	finish_struck = false
	t.executed_by = self
	t.revive_progress = 0.0
	velocity = Vector3.ZERO
	if model:
		model.play_once(_finisher_anims()[1], 1.15)
	game.sfx.play("swing_heavy", global_position, -2.0, 0.1)
	game.spawn_swing(self, _flat_to(t.global_position).normalized())
	if is_player:
		game.rumble(self, 0.2, 0.4, 0.15)


func _finisher_process(delta: float) -> void:
	## Locked in the finisher: face the body, lunge a little, strike on cue.
	var t = finish_victim
	finishing -= delta
	if t and is_instance_valid(t) and t.downed:
		var to := _flat_to(t.global_position)
		if to.length() > 0.1:
			facing = to.normalized()
			rotation.y = atan2(-facing.x, -facing.z)
		var lunge: float = 3.0 if (Stats.FINISH_ANIM - finishing) < Stats.FINISH_IMPACT and to.length() > 1.0 else 0.0
		velocity = Vector3(facing.x * lunge, 0.0 if is_on_floor() else velocity.y - GRAVITY * delta, facing.z * lunge)
		move_and_slide()
		if not finish_struck and Stats.FINISH_ANIM - finishing >= Stats.FINISH_IMPACT:
			finish_struck = true
			t._hit_while_downed(self, true)
	elif not finish_struck:
		finishing = 0.0   # the body was revived or is gone: the move is wasted
	if finishing <= 0.0:
		finishing = 0.0
		if t and is_instance_valid(t) and t.executed_by == self:
			t.executed_by = null
		finish_victim = null


func _finish_fx(attacker) -> void:
	## The blow lands: a red burst, a shock ring, a dark pillar, a shake.
	var p := global_position
	game.spawn_burst(p + Vector3(0, 0.05, 0), 2.2, Color(0.85, 0.12, 0.1))
	game.spawn_ring(p, 2.6, Color(1.0, 0.35, 0.2), 0.45, 0.1)
	game.spawn_splash(p + Vector3(0, 0.5, 0), Color(0.95, 0.2, 0.15), 26, 5.0, 0.6)
	game.spawn_splash(p + Vector3(0, 0.7, 0), Color(1.0, 0.85, 0.4), 12, 4.0, 0.5, true)
	game.spawn_pillar(p, Color(0.6, 0.08, 0.08), 3.0, 0.6)
	game.spawn_popup(p + Vector3(0, 2.0, 0), "FINISHED!", Color(1.0, 0.35, 0.25))
	game.sfx.play("smite", p, 0.0, 0.1)
	game.sfx.play("hit_flesh", p, -2.0, 0.1)
	game.shake_at(p, 0.55)
	if attacker:
		game.rumble(attacker, 0.5, 0.9, 0.25)
	game.rumble(self, 0.6, 1.0, 0.35)


func _revive(by) -> void:
	var snap := down_snapshot
	_end_downed()
	if not snap.is_empty():
		# The fall is undone: levels, XP and ranks come back.
		level = snap.level
		xp = snap.xp
		points = snap.points
		ranks = snap.ranks
		spent = snap.spent
	hearts = mini(Stats.REVIVE_HEARTS, max_hearts())
	energy = maxf(energy, energy_max() * 0.5)
	revive_protect = Stats.REVIVE_PROTECT
	times_revived += 1
	model.stand_up()
	if aim_marker:
		aim_marker.visible = true
	var healer: bool = by and by.role == Role.HEALER
	if by:
		by.revives += 1
		by.gain_xp(Stats.XP_REVIVE, "support")
	var col := Color(0.45, 1.0, 0.55) if healer else Color(1.0, 0.85, 0.4)
	game.spawn_pillar(global_position, col, 3.5, 0.8)
	game.spawn_ring(global_position, 1.8, col, 0.5)
	game.spawn_splash(global_position + Vector3(0, 0.6, 0), col, 20, 3.0, 0.8, true)
	game.spawn_popup(global_position + Vector3(0, 2.2, 0), "REVIVED", col)
	game.sfx.play("respawn", global_position, -4.0)
	if is_player:
		game.toast("REVIVED BY %s" % (by.display_name.to_upper() if by else "A TEAMMATE"), col)
	if by and by.is_player:
		game.toast("YOU REVIVED %s" % display_name.to_upper(), col)
	if game.demo:
		print("REVIVE t=%d team%d %s by=%s healer=%s" % [game.match_clock(), team, role_name(), by.role_name() if by else "?", healer])
	_refresh_overhead()


func _downed_process(delta: float) -> void:
	## A downed unit's frame: bleed out (paused while a teammate works on
	## us), skip, crawl.
	if executed_by and is_instance_valid(executed_by) and executed_by.finishing > 0.0:
		return   # a finisher is landing: no crawling, skipping or reviving now
	executed_by = null
	var helped := being_revived()
	if not helped:
		revive_by = null
		revive_progress = maxf(revive_progress - delta / Stats.REVIVE_TIME, 0.0)
		downed_timer -= delta
	if downed_timer <= 0.0:
		if game.demo:
			print("BLEEDOUT t=%d team%d %s" % [game.match_clock(), team, role_name()])
		_die()
		return
	var move := Vector3.ZERO
	if is_player:
		if not game.menu_blocks_input(self):
			var stick := Input.get_vector(_a("move_left"), _a("move_right"), _a("move_up"), _a("move_down"))
			move = Vector3(stick.x, 0, stick.y)
			# Hold interact to give up and respawn (not from a press held
			# over from before the fall).
			if Input.is_action_pressed(_a("interact")) and downed_total - downed_timer > 0.4:
				skip_hold += delta
			else:
				skip_hold = 0.0
			if skip_hold >= Stats.DOWNED_SKIP_HOLD:
				if game.demo:
					print("SKIP t=%d team%d %s" % [game.match_clock(), team, role_name()])
				_die()
				return
	else:
		# A bot waits for help while a teammate is near enough to come;
		# alone, it skips to the respawn.
		var ally = _nearest_standing_ally()
		if ally == null or _flat_to(ally.global_position).length() > Stats.BOT_HEALER_REVIVE_SEEK:
			bot_down_wait += delta
			if bot_down_wait >= Stats.BOT_DOWNED_GIVE_UP:
				if game.demo:
					print("SKIP t=%d team%d %s" % [game.match_clock(), team, role_name()])
				_die()
				return
		else:
			bot_down_wait = 0.0
	if helped:
		move = Vector3.ZERO
	var speed: float = Stats.FACTIONS[team].speed * stats().speed * Stats.DOWNED_CRAWL
	if move.length() > 0.05:
		facing = move.normalized()
		rotation.y = atan2(-facing.x, -facing.z)
	velocity.x = move.x * speed
	velocity.z = move.z * speed
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()
	_clamp_to_map()
	if game.in_channel(global_position):
		var bank := 1.0 if global_position.x >= 0.0 else -1.0
		global_position.x = bank * (game.RIVER_HALF + 0.9)


func _nearest_standing_ally():
	var best = null
	var best_d := 1e9
	for other in game.units:
		if other == self or other.team != team or other.dead or other.downed:
			continue
		var d := _flat_to(other.global_position).length()
		if d < best_d:
			best_d = d
			best = other
	return best


func _bot_revive_goal(mine):
	## The downed teammate this bot should go and revive, or null: close
	## enough (Healers look further), safe enough, and nothing more urgent.
	if carrying:
		return null
	if mine.state != Monarch.State.HOME and bot_job == "recover":
		return null
	var seek: float = Stats.BOT_HEALER_REVIVE_SEEK if role == Role.HEALER else Stats.BOT_REVIVE_SEEK
	var best = null
	var best_d := seek
	for other in game.units:
		if other == self or other.team != team or not other.downed:
			continue
		var d := _flat_to(other.global_position).length()
		if d >= best_d:
			continue
		# Safe: not more enemies than friends round the body (Healers and
		# whoever is already reviving keep going).
		var foes: int = game.enemies_near(team, other.global_position, 6.0)
		if foes > 0 and role != Role.HEALER and other.revive_by != self:
			continue
		if foes > game.allies_near(team, other.global_position, 6.0):
			continue
		# One reviver per body, unless this one is a Healer.
		if other.revive_by != null and other.revive_by != self and other.being_revived() and role != Role.HEALER:
			continue
		best_d = d
		best = other
	return best


func _build_down_fx() -> void:
	if down_fx:
		return
	down_fx = Node3D.new()
	down_fx.top_level = true
	add_child(down_fx)
	down_ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.95
	tm.outer_radius = 1.08
	tm.rings = 32
	down_ring.mesh = tm
	down_ring_mat = StandardMaterial3D.new()
	down_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	down_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	down_ring_mat.albedo_color = Color(0.95, 0.3, 0.25, 0.8)
	down_ring.material_override = down_ring_mat
	down_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	down_fx.add_child(down_ring)
	# A green cross over the body, on the camera-facing overhead.
	down_cross = Node3D.new()
	down_cross.position.y = 0.62
	overhead.add_child(down_cross)
	var plate := MeshInstance3D.new()
	var disc := QuadMesh.new()
	disc.size = Vector2(0.5, 0.5)
	plate.mesh = disc
	plate.material_override = _overhead_mat(Color(0.06, 0.08, 0.05, 0.9), 6)
	down_cross.add_child(plate)
	down_cross_mat = _overhead_mat(Color(0.4, 1.0, 0.45), 7)
	for sz in [Vector2(0.36, 0.11), Vector2(0.11, 0.36)]:
		var bar := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = sz
		bar.mesh = q
		bar.position.z = 0.003
		bar.material_override = down_cross_mat
		down_cross.add_child(bar)
	# The bar under it: red draining while bleeding out, gold filling while
	# a teammate revives.
	down_bar = Node3D.new()
	down_bar.position.y = HP_BAR_Y
	overhead.add_child(down_bar)
	var trough := MeshInstance3D.new()
	var tq := QuadMesh.new()
	tq.size = Vector2(HP_BAR_W + 0.04, HP_BAR_H + 0.04)
	trough.mesh = tq
	trough.material_override = _overhead_mat(Color(0.05, 0.04, 0.03, 0.95), 6)
	down_bar.add_child(trough)
	down_bar_fill = MeshInstance3D.new()
	var fq := QuadMesh.new()
	fq.size = Vector2(HP_BAR_W, HP_BAR_H)
	down_bar_fill.mesh = fq
	down_bar_fill.position.z = 0.003
	down_bar_mat = _overhead_mat(Color(0.9, 0.2, 0.17), 7)
	down_bar_fill.material_override = down_bar_mat
	down_bar.add_child(down_bar_fill)


func _update_down_fx() -> void:
	if down_fx == null:
		return
	down_cross.visible = false   # the HUD's dizzy swirl and stars mark the body (Faisal's downed render)
	down_bar.visible = downed
	if not downed:
		return
	var now := Time.get_ticks_msec() / 1000.0
	var reviving := being_revived()
	var frac: float = revive_progress if reviving or revive_progress > 0.02 else clampf(downed_timer / maxf(downed_total, 0.1), 0.0, 1.0)
	var col := Color(1.0, 0.82, 0.3) if (reviving or revive_progress > 0.02) else Color(0.92, 0.22, 0.18)
	if reviving and revive_by and revive_by.role == Role.HEALER:
		col = Color(0.45, 1.0, 0.55)
	down_bar_mat.albedo_color = col
	down_bar_fill.scale.x = maxf(frac, 0.001)
	down_bar_fill.position.x = -HP_BAR_W * (1.0 - frac) / 2.0
	down_fx.global_position = global_position + Vector3(0, 0.06, 0)
	var pulse := 0.5 + 0.5 * sin(now * (9.0 if reviving else 5.0))
	down_ring.scale = Vector3.ONE * (0.55 + 0.45 * (revive_progress if reviving else frac))
	down_ring_mat.albedo_color = Color(col.r, col.g, col.b, 0.5 + 0.35 * pulse)
	down_cross_mat.albedo_color = Color(0.4, 1.0, 0.45).lerp(Color(1, 1, 1), 0.35 * pulse)
	down_cross.scale = Vector3.ONE * (1.0 + 0.08 * pulse)



func _death_fling() -> void:
	## The killing blow throws the body back: a short arc the way it was hit,
	## landing as the fall plays. Looks only (the unit itself stays put);
	## the model is reset on revive.
	if model == null:
		return
	var push := last_hit_dir
	push.y = 0.0
	if push.length() < 0.05:
		return
	var local: Vector3 = global_transform.basis.inverse() * (push.normalized() * 1.1)
	local.y = 0.0
	var tw: Tween = model.create_tween()
	tw.set_parallel(true)
	tw.tween_property(model, "position:x", local.x, 0.32).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(model, "position:z", local.z, 0.32).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(model, "position:y", 0.45, 0.14).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(model, "position:y", 0.0, 0.16).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func():
		if is_instance_valid(game):
			Fx.of(game).burst(model.global_position + Vector3(0, 0.15, 0), Color(0.6, 0.55, 0.45), 8, 2.0, 0.7, Fx.STYLE_SMOKE, Vector3.UP, 70.0, 0.8))


func _respawn() -> void:
	dead = false
	set_role(Role.BASE)
	hearts = max_hearts()
	energy = energy_max()
	position = spawn_point + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5))
	spawn_protect = Stats.SPAWN_PROTECT_TIME
	resist_pool = 0.0
	rally_wait = 0.0
	heal_pool = 0.0
	visible = true
	shape.disabled = false
	model.revive()
	game.sfx.play("respawn", global_position, -6.0)
	if aim_marker:
		aim_marker.visible = true


func bubble_up(duration: float) -> void:
	## Holy Bubble: untouchable under a dome of light for `duration` seconds.
	guard_timer = maxf(guard_timer, duration)
	bubble_timer = maxf(bubble_timer, duration)
	guard_ring.visible = false   # the dome is the visual; the blue shell on top blew out to white
	if bubble_mesh == null:
		bubble_mesh = MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = 1.5
		sph.height = 3.0
		sph.radial_segments = 24
		sph.rings = 12
		bubble_mesh.mesh = sph
		var bm := StandardMaterial3D.new()
		# Faint and see-through, so the people inside stay readable; a thin
		# gold ring at the equator marks the dome's edge.
		bm.albedo_color = Color(1.0, 0.95, 0.7, 0.16)
		bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		bm.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
		bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bm.cull_mode = BaseMaterial3D.CULL_BACK
		bubble_mesh.material_override = bm
		var ring := MeshInstance3D.new()
		var tor := TorusMesh.new()
		tor.inner_radius = 1.46
		tor.outer_radius = 1.54
		ring.mesh = tor
		var rm := StandardMaterial3D.new()
		rm.albedo_color = Color(1.0, 0.9, 0.5)
		rm.emission_enabled = true
		rm.emission = Color(1.0, 0.85, 0.4)
		rm.emission_energy_multiplier = 1.5
		rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ring.material_override = rm
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bubble_mesh.add_child(ring)
		bubble_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bubble_mesh.position = Vector3(0, 1.1, 0)
		add_child(bubble_mesh)
	bubble_mesh.visible = true


var _was_carrying := false


func _process(_delta: float) -> void:
	_animate()
	class_banner = maxf(class_banner - _delta, 0.0)
	if (carrying != null) != _was_carrying:
		_was_carrying = carrying != null
		_apply_side_colors()
	if bubble_mesh and bubble_mesh.visible:
		bubble_timer -= _delta
		var k: float = clampf(bubble_timer / 0.3, 0.0, 1.0)
		bubble_mesh.scale = Vector3.ONE * (0.6 + 0.4 * k + 0.03 * sin(Time.get_ticks_msec() / 90.0))
		if bubble_timer <= 0.0 or dead:
			bubble_mesh.visible = false
	if overhead:
		overhead.global_position = global_position + Vector3(0, (model.height if model else 1.8) + (1.25 if carrying else 0.35), 0)   # above a worn crown
		if downed:
			overhead.global_position.y = global_position.y + 1.3   # over the body on the ground
	_update_down_fx()
	if aim_marker and not dead:
		aim_marker.global_position = global_position + aim * 1.1 + Vector3(0, 0.08, 0)
		aim_marker.rotation.y = atan2(-aim.x, -aim.z)
		aim_ring.visible = aim_mode == "mouse"
		aim_ring.global_position = Vector3(aim_point.x, global_position.y + 0.08, aim_point.z)


func _animate() -> void:
	if model == null or dead or downed:
		return
	var planar := Vector2(velocity.x, velocity.z).length()
	model.update_locomotion(planar > 0.6)


func _a(action: String) -> StringName:
	## This local player's version of an input action.
	return StringName(act_prefix + action)


func _update_player_aim(move: Vector3) -> void:
	var cam: Camera3D = game.camera_for(self)
	var mouse: Vector2 = cam.get_viewport().get_mouse_position() if has_mouse else last_mouse
	var stick := Input.get_vector(_a("aim_left"), _a("aim_right"), _a("aim_up"), _a("aim_down"))
	if stick.length() > 0.3 or game.touch_active:
		aim_mode = "stick"
	elif has_mouse and mouse != last_mouse:
		aim_mode = "mouse"
	last_mouse = mouse
	match aim_mode:
		"stick":
			if stick.length() > 0.3:
				aim = Vector3(stick.x, 0, stick.y).normalized()
			else:
				# Touch play: with no aim drag, face the nearest enemy in reach.
				var auto := _auto_aim() if game.touch_active else Vector3.ZERO
				if auto != Vector3.ZERO:
					aim = auto
				elif move.length() > 0.05:
					aim = move.normalized()
			aim_point = global_position + aim * 6.0
		"mouse":
			var plane := Plane(Vector3.UP, global_position.y + 1.0)
			var hit = plane.intersects_ray(cam.project_ray_origin(mouse), cam.project_ray_normal(mouse))
			if hit != null:
				aim_point = hit
				var to: Vector3 = hit - global_position
				to.y = 0.0
				if to.length() > 0.3:
					aim = to.normalized()
		_:
			if move.length() > 0.05:
				aim = move.normalized()
			aim_point = global_position + aim * 6.0


func _auto_aim() -> Vector3:
	## The direction to the nearest living enemy within a few metres, or zero.
	var best := 7.0
	var dir := Vector3.ZERO
	for u in game.units:
		if u == self or u.team == team or u.dead:
			continue
		var to: Vector3 = u.global_position - global_position
		to.y = 0.0
		var d := to.length()
		if d < best and d > 0.1:
			best = d
			dir = to / d
	return dir


func _physics_process(delta: float) -> void:
	if game == null or not game.playing:
		return
	if dead:
		if death_timer > 0.0:
			death_timer -= delta
			if death_timer <= 0.0:
				visible = false
		if game.overtime:
			return  # sudden death: nobody comes back
		respawn_timer -= delta
		if respawn_timer <= 0.0:
			_respawn()
		return
	revive_protect = maxf(revive_protect - delta, 0.0)
	revive_target = null
	if finish_target and Engine.get_physics_frames() - finish_frame > 2:
		finish_target = null
		finish_progress = 0.0
	if downed:
		_downed_process(delta)
		return
	if finishing > 0.0:
		_finisher_process(delta)
		return

	# Nobody stands in the river: anyone shoved or blown into the channel
	# (a knockback over the shrine's rim) is set back on the nearer bank.
	if game.vmap == null and game.in_channel(global_position):
		var bank := 1.0 if global_position.x >= 0.0 else -1.0
		if game.demo:
			print("RIVER t=%d team%d %s at %s" % [game.match_clock(), team, role_name(), global_position.snapped(Vector3.ONE * 0.1)])
		global_position.x = bank * (game.RIVER_HALF + 0.9)
		knockback = Vector3.ZERO
	# Spawn protection ends on its timer or the moment you leave the cellar.
	if spawn_protect > 0.0:
		spawn_protect -= delta
		if not game._in_cellar(team, global_position):
			spawn_protect = 0.0
	# Defending home: a short hysteresis so the door doesn't flicker it.
	var home_now: bool = game._inside_castle(team, global_position) or game._in_cellar(team, global_position)
	if home_now != home_defense:
		home_timer += delta
		if home_timer > 0.6:
			home_defense = home_now
			home_timer = 0.0
			if is_player:
				game.toast("HOME DEFENSE ACTIVE" if home_now else "HOME DEFENSE LOST", Color(0.7, 0.85, 1.0) if home_now else Color(0.9, 0.7, 0.6))
	else:
		home_timer = 0.0
	if carry_fx:
		carry_fx.visible = carrying != null
	var regen := Stats.MANA_REGEN if energy_kind() == "mana" else Stats.STAMINA_REGEN
	if veteran >= 2:
		regen *= Stats.ELITE_REGEN_MULT
	if home_defense:
		regen *= 1.0 + Stats.DEFENDER.regen
	regen *= Stats.FACTIONS[team].regen_mult * (1.0 + Stats.VIGOR_REGEN * rank(3))
	if blocking:
		energy -= Stats.BLOCK_DRAIN * delta
	else:
		energy = minf(energy + regen * delta, energy_max())
	energy = maxf(energy, 0.0)
	attack_timer = maxf(attack_timer - delta, 0.0)
	dodge_cooldown = maxf(dodge_cooldown - delta, 0.0)
	for i in ability_timers.size():
		ability_timers[i] = maxf(ability_timers[i] - delta, 0.0)
	root_timer = maxf(root_timer - delta, 0.0)
	haste_timer = maxf(haste_timer - delta, 0.0)
	slow_timer = maxf(slow_timer - delta, 0.0)
	burn_cd = maxf(burn_cd - delta, 0.0)
	if burn_timer > 0.0:
		burn_timer -= delta
		if Engine.get_physics_frames() % 5 == 0:
			game.spawn_splash(global_position + Vector3(0, 0.9, 0), Color(1.0, 0.5, 0.15), 3, 1.6, 0.4, true)
		if burn_timer <= 0.0:
			var by = burn_by if is_instance_valid(burn_by) and burn_by.team != team else null
			burn_by = null
			burn_tick = true
			take_damage(Stats.FIRE_FORM.burn_damage, by, Vector3.INF, 0.0, {"fx": "fire"})
			burn_tick = false
			if dead:
				return
	if buff_timer > 0.0:
		buff_timer -= delta
		if buff == "Regeneration":
			regen_tick -= delta
			if regen_tick <= 0.0:
				regen_tick = Stats.BLESSING_REGEN_TICK
				heal(1, self)
		if Engine.get_physics_frames() % 8 == 0:
			game.spawn_splash(global_position + Vector3(0, 0.3, 0), Stats.BLESSING_KINDS[buff].color, 3, 1.5, 0.7, true)
		if buff_timer <= 0.0:
			buff = ""
	if stealth_timer > 0.0:
		stealth_timer = maxf(stealth_timer - delta, 0.0)
		if Engine.get_physics_frames() % 6 == 0:
			game.spawn_splash(global_position + Vector3(0, 0.9, 0), Color(0.55, 0.55, 0.6), 4, 1.2, 0.9, true)
		overhead.visible = stealth_timer <= 0.0 or is_player
	bot_block_timer = maxf(bot_block_timer - delta, 0.0)
	if is_player and hearts == 1:
		# Your last heart: a heartbeat you can hear, quickening nothing else.
		heartbeat_timer -= delta
		if heartbeat_timer <= 0.0:
			heartbeat_timer = 0.95
			game.sfx.ui("heartbeat", -9.0)
	else:
		heartbeat_timer = 0.0
	if guard_timer > 0.0:
		guard_timer -= delta
		if guard_timer <= 0.0:
			guard_ring.visible = false
			model.release()
	if flash_timer > 0.0:
		flash_timer = maxf(flash_timer - delta, 0.0)
		_flash_look()
	if hitstop_timer > 0.0:
		hitstop_timer -= delta
		if hitstop_timer <= 0.0 and model and model.anim:
			model.anim.speed_scale = 1.0
	_status_auras()

	var speed: float = Stats.FACTIONS[team].speed * stats().speed * vigor_speed()
	if carrying:
		speed *= Stats.CARRY_SPEED_MULT
	if haste_timer > 0.0:
		speed *= 1.3
	if buff == "Swiftness" and buff_timer > 0.0:
		speed *= Stats.BLESSING_SWIFT_MULT
	if slow_timer > 0.0:
		speed *= 0.55
	if guard_timer > 0.0:
		speed *= 0.5
	elif blocking:
		speed *= Stats.BLOCK_SPEED_MULT

	# Mid-dash (dodge or Shield Bash): fly in the dash direction and ignore the rest.
	if dodge_timer > 0.0 or bash_timer > 0.0:
		var dash_speed := speed * Stats.DODGE_SPEED_MULT
		if bash_timer > 0.0:
			bash_timer -= delta
			dash_speed = bash_speed
			for other in game.units:
				if other.team != team and not other.dead and not other in bash_hit \
						and _flat_to(other.global_position).length() < 1.3 \
						and absf(other.global_position.y - global_position.y) < 1.5:
					bash_hit.append(other)
					other.take_damage(bash_damage, self, global_position, 10.0, {"root": bash_root, "fx": "heavy"} if bash_root > 0.0 else {"fx": "heavy"})
		else:
			dodge_timer -= delta
		velocity.x = dodge_dir.x * dash_speed
		velocity.z = dodge_dir.z * dash_speed
		velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
		move_and_slide()
		_clamp_to_map()
		return

	var move := Vector3.ZERO
	var wants_attack := false
	var wants_block := false
	var plan := {}
	if is_player:
		var stick := Input.get_vector(_a("move_left"), _a("move_right"), _a("move_up"), _a("move_down"))
		move = Vector3(stick.x, 0, stick.y)
		_update_player_aim(move)
		_update_highlights()
		if not game.menu_blocks_input(self):
			# Held attack keeps swinging; a tap during the cooldown is kept for
			# a moment and swings as soon as it can (no lost clicks).
			if Input.is_action_just_pressed(_a("attack")):
				attack_buffer = ATTACK_BUFFER
			wants_attack = Input.is_action_pressed(_a("attack")) or attack_buffer > 0.0
			if game.economy and game.economy.mouse_on_button():
				wants_attack = false   # a click on the economy card's button buys, it does not swing
				attack_buffer = 0.0
			wants_block = Input.is_action_pressed(_a("block"))
			# Hold interact over a downed teammate to revive them; otherwise
			# interact grabs, drops and talks as before.
			var rv = revive_candidate()
			var fv = finish_candidate() if rv == null else null
			if rv and Input.is_action_pressed(_a("interact")):
				_tick_revive(rv, delta)
				move = Vector3.ZERO
				wants_attack = false
			elif fv and Input.is_action_pressed(_a("interact")):
				_tick_finish(fv, delta)
				move = Vector3.ZERO
				wants_attack = false
			elif Input.is_action_just_pressed(_a("interact")):
				game.try_interact(self)
			# A press just before a skill or the dodge is ready still counts:
			# it waits up to INPUT_BUFFER seconds and fires the moment it can.
			if Input.is_action_just_pressed(_a("ability_1")):
				input_buffer[0] = INPUT_BUFFER
			if Input.is_action_just_pressed(_a("ability_2")):
				input_buffer[1] = INPUT_BUFFER
			if Input.is_action_just_pressed(_a("ability_3")):
				use_ability(2, aim)
			if Input.is_action_just_pressed(_a("dodge")):
				input_buffer[2] = INPUT_BUFFER
		for i in 2:
			if input_buffer[i] > 0.0:
				input_buffer[i] -= delta
				if ability_ready(i):
					input_buffer[i] = 0.0
					use_ability(i, aim)
		if input_buffer[2] > 0.0:
			input_buffer[2] -= delta
			if dodge_ready():
				input_buffer[2] = 0.0
				try_dodge(move)
		if dodge_timer > 0.0 or bash_timer > 0.0:
			return
	else:
		if OS.has_feature("web") and not _bot_plan.is_empty() and (Engine.get_physics_frames() + get_index()) % 2 == 1:
			# Browsers run on one slow thread: bots think every other physics
			# tick and repeat the last plan's move and attack in between (not a
			# one-off ability). Half the bot AI cost; a 16 ms slower reaction.
			plan = _bot_plan
			_bot_plan = {}
		else:
			plan = _bot_think(delta)
			_bot_plan = plan.duplicate()
			_bot_plan.erase("ability")
		move = plan.move
		wants_attack = plan.attack
		wants_block = plan.get("block", false)
		aim = plan.aim
		if plan.has("finish") and is_instance_valid(plan.finish) and plan.finish.downed:
			_tick_finish(plan.finish, delta)
			if finishing > 0.0:
				return
			move = Vector3.ZERO
			wants_attack = false
		if plan.has("revive") and is_instance_valid(plan.revive) and plan.revive.downed:
			_tick_revive(plan.revive, delta)
			move = Vector3.ZERO
			wants_attack = false
		if game.demo:
			# Diagnostics: a bot that wants to move but has not for 12 s.
			stall_clock += delta
			if global_position.distance_to(stall_pos) > 0.5 or carrying or dead:
				stall_pos = global_position
				stall_clock = 0.0
			elif stall_clock > 20.0:
				stall_clock = 0.0
				var e = _nearest_enemy(30.0)
				print("STALL t=%d team%d %s at %s job=%s move=%s attack=%s enemy=%s d=%.1f" % [game.match_clock(), team, role_name(), global_position.snapped(Vector3.ONE * 0.1), bot_job, move.snapped(Vector3.ONE * 0.01), wants_attack, (e.role_name() + str(e.global_position.snapped(Vector3.ONE * 0.1))) if e else "none", _flat_to(e.global_position).length() if e else 0.0])
				var hits := []
				for ci in get_slide_collision_count():
					var col := get_slide_collision(ci).get_collider()
					hits.append("%s@%s" % [col.name if col else "?", (col.global_position.snapped(Vector3.ONE * 0.1)) if col is Node3D else ""])
				print("STALLINFO target=%s hits=%s" % [stall_target.snapped(Vector3.ONE * 0.1), hits])

	# Shield up: hold to block. It drains stamina, slows you and stops attacks.
	var block_now: bool = wants_block and can_block() and energy > 0.0 and carrying == null and guard_timer <= 0.0
	if block_now and not blocking:
		game.sfx.play("block_up", global_position, -6.0)
	if block_now != blocking:
		blocking = block_now
		if blocking:
			model.hold("Blocking")
		else:
			model.release()

	if root_timer > 0.0:
		move = Vector3.ZERO

	# The player always faces where they aim; bots face where they walk, or
	# whatever they are attacking.
	if is_player:
		facing = aim
	elif (wants_attack or blocking) and aim.length() > 0.05:
		facing = aim.normalized()
	elif move.length() > 0.05:
		facing = move.normalized()
	rotation.y = atan2(-facing.x, -facing.z)

	velocity.x = move.x * speed + knockback.x
	velocity.z = move.z * speed + knockback.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()
	_clamp_to_map()
	knockback = knockback.move_toward(Vector3.ZERO, 40.0 * delta)
	# Footsteps: soft on grass, a tap on stone (walls, bridges, castle floors).
	if move.length() > 0.05 and is_on_floor():
		step_timer -= delta * speed / 6.0
		if step_timer <= 0.0:
			step_timer = 0.34
			var stone: bool = global_position.y > 0.5 or absf(global_position.x) > game.CASTLE_X - game.CASTLE_DEPTH - 1.0 or absf(global_position.x) < 7.0
			game.sfx.play("step_stone" if stone else "step", global_position, -14.0 if is_player else -20.0, 0.2)

	# Bots that bump into a tree or wall sidestep around it.
	sidestep_timer = maxf(sidestep_timer - delta, 0.0)
	avoid_timer = maxf(avoid_timer - delta, 0.0)
	if not is_player and move.length() > 0.1:
		var real := get_real_velocity()
		real.y = 0.0
		stuck_time = stuck_time + delta if real.length() < speed * 0.3 else 0.0

	attack_buffer = maxf(attack_buffer - delta, 0.0)
	if wants_attack and not blocking and carrying == null and attack_timer <= 0.0:
		attack_buffer = 0.0
		_attack(aim)
	if plan.has("ability"):
		use_ability(plan.ability, plan.aim)


func _update_highlights() -> void:
	## Glow the unit under the cursor (or in the aim cone with a stick).
	for other in game.units:
		if other == self or other.dead:
			other.set_highlight(false)
			continue
		var on := false
		if aim_mode == "mouse":
			on = Vector2(other.global_position.x - aim_point.x, other.global_position.z - aim_point.z).length() < 1.3
		else:
			var to := _flat_to(other.global_position)
			on = to.length() < 4.0 and to.length() > 0.1 and aim.dot(to.normalized()) > 0.9
		other.set_highlight(on)


func _clamp_to_map() -> void:
	# The spawn cellars reach past the field's edge (the Healer hat sits at x 87.5).
	var hx: float = maxf(game.map_half.x, game.CASTLE_X + game.CASTLE_DEPTH + game.CELLAR_DEPTH)
	position.x = clampf(position.x, -hx, hx)
	position.z = clampf(position.z, -game.map_half.y, game.map_half.y)
	if game.vmap:
		position = game.vmap.clamp_walk(position)  # Ember Pass: nobody steps into the lava


# --- Combat ----------------------------------------------------------------

func _injured_allies_near(radius: float = -1.0) -> Array:
	var hurt := []
	var reach: float = attack_stats().get("heal_radius", 0.0) if radius < 0.0 else radius
	for other in game.units:
		if other.team == team and not other.dead and not other.downed and other.hearts < other.max_hearts() \
				and _flat_to(other.global_position).length() <= reach:
			hurt.append(other)
	return hurt


func _attack(dir: Vector3) -> void:
	var s := attack_stats()
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.05 else facing
	var kind: String = s.attack
	if energy < s.cost:
		return  # out of stamina or mana
	if kind == "heal":
		# Mend: heal everyone hurt around you, including yourself. With nobody
		# to heal, the same mana fires a holy bolt at whatever you aim at.
		var hurt := _injured_allies_near()
		energy -= s.cost
		attack_timer = s.cooldown
		if not hurt.is_empty():
			for ally in hurt:
				ally.heal(s.heal, self)
			model.play_once("Spellcast_Raise", 1.6)
			game.sfx.play("heal", global_position, -2.0)
			game.spawn_ring(global_position, s.heal_radius, Color(0.3, 1.0, 0.5), 0.6)
			game.spawn_flash(global_position, Color(0.3, 1.0, 0.5), 2.0, 0.4)
			return
		model.play_once("Spellcast_Shoot", 1.6)
		var drain: bool = s.get("drain", false)
		game.sfx.play("curse" if drain else "bolt", global_position, -6.0 if drain else -3.0, 0.12)
		game.spawn_shot(self, dir, {"damage": s.damage, "gate_damage": s.gate_damage, "range": s.range,
			"shot_speed": s.shot_speed, "holy": true, "drain": drain, "burn": s.get("burn", false)}, Color(0.6, 0.3, 0.9) if drain else Color(1.0, 0.95, 0.6))
		_recoil(dir, 1.5)
		return
	energy -= s.cost
	attack_timer = s.cooldown
	model.attack()

	if kind == "arrow":
		game.sfx.play("bow", global_position, -2.0, 0.1)
		game.spawn_shot(self, dir, s, Color(0.6, 0.9, 0.5) if s.has("slow") else Color(0.95, 0.9, 0.7))
		_recoil(dir, 1.5)
		return
	if kind == "spell":
		var spell_color := Color(0.7, 0.45, 1.0)
		if s.get("fire", false):
			spell_color = Color(1.0, 0.5, 0.1)
		elif s.get("frost", false):
			spell_color = Color(0.6, 0.85, 1.0)
		elif s.get("nature", false):
			spell_color = SkillFx.LEAF
		game.spawn_shot(self, dir, s, spell_color)
		game.sfx.play("bolt", global_position, -2.0, 0.12)
		_recoil(dir, 2.0)
		return
	# Melee: a short lunge into the swing.
	knockback += dir * 2.5
	game.sfx.play("punch" if role == Role.BASE else ("swing_heavy" if s.range > 2.5 else "swing"), global_position, -3.0, 0.12)
	var swing_kind := _swing_kind(s)
	var swing_col: Color = Fx.KINDS[swing_kind].spark.lerp(Color.WHITE, 0.45)
	swing_flip = not swing_flip
	Fx.of(game).slash(global_position, dir, swing_col, clampf(s.range / 1.9, 0.75, 1.5), s.range > 2.5, swing_flip)
	var landed := false
	# On-hit effects of the swing: Venom Fang slows, fire form burns.
	var effect := {}
	if s.has("slow"):
		effect["slow"] = s.slow
	if s.get("burn", false):
		effect["burn"] = true
	effect["fx"] = swing_kind
	for other in game.units:
		if other.team == team or other.dead:
			continue
		var to := _flat_to(other.global_position)
		var dist := to.length()
		# Swings reach people at your own height, not someone up on a wall.
		if dist <= s.range and absf(other.global_position.y - global_position.y) < 1.5 \
				and (dist < 0.8 or dir.dot(to / dist) > 0.3):
			landed = other.take_damage(s.damage, self, global_position, Stats.KNOCK_MELEE, effect) or landed
	if landed:
		_hitstop(0.06)
		game.sfx.play("hit_flesh", global_position, 0.0, 0.15)
		if is_player:
			game.shake(0.12)
			game.kick_cam(dir, 0.12)   # the view leans into the blow
			game.rumble(self, 0.35, 0.15, 0.1)
	# Swings from the ground also chip away at the enemy door.
	var vault = game.vaults[1 - team]
	if vault.is_locked() and global_position.y < 1.0 and _flat_to(vault.lock_pos).length() < s.range + 0.6 \
			and dir.dot(_flat_to(vault.lock_pos).normalized()) > 0.3:
		vault.take_hit(s.gate_damage, self)
	for b in game.barricades:
		if b.team != team and b.is_intact() and absf(global_position.y - b.global_position.y) < 1.5 \
				and _flat_to(b.global_position).length() < s.range + 1.0 and dir.dot(_flat_to(b.global_position).normalized()) > 0.3:
			b.take_hit(s.gate_damage, self)
	for t in game.turrets.duplicate():
		if t.team != team and absf(global_position.y - t.global_position.y) < 1.5 \
				and _flat_to(t.global_position).length() < s.range + 0.8 and dir.dot(_flat_to(t.global_position).normalized()) > 0.3:
			t.take_hit(maxi(s.gate_damage, 1), self)
	var gate = game.gates[1 - team]
	var gx: float = gate.position.x
	if gate.is_intact() and global_position.y < 1.0 and absf(global_position.x - gx) < s.range + 0.4 \
			and absf(global_position.z) < Stats.DOOR_HALF + 0.5 and dir.x * signf(gx - global_position.x) > 0.3:
		gate.take_hit(s.gate_damage, self)


# --- Bot brain -------------------------------------------------------------

func _flat_to(target: Vector3) -> Vector3:
	var to := target - global_position
	to.y = 0.0
	return to


func _probe(dir: Vector3, reach: float) -> Dictionary:
	## The first world collider (layer 1) within `reach` metres along `dir` at
	## knee height, or an empty dictionary. Walkable slopes (stairs, ramps)
	## do not count.
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3(0, 0.6, 0)
	var probe := PhysicsRayQueryParameters3D.create(from, from + dir * reach, 1)
	probe.exclude = [get_rid()]
	var hit := space.intersect_ray(probe)
	if hit.is_empty():
		return hit
	var n: Vector3 = hit.get("normal", Vector3.UP)
	return hit if n.y < 0.45 else {}


func _steer_to(target: Vector3) -> Vector3:
	stall_target = target
	var to := _flat_to(target)
	if to.length() < 0.6:
		return Vector3.ZERO
	var dir := to.normalized()
	if stuck_time > 0.3:
		# Blocked: commit to walking around the obstacle for a moment, and try
		# the other side next time so a corner can't hold us for good.
		stuck_time = 0.0
		if game.demo:
			# Diagnostics: every time a bot has to shove off something.
			var hits := []
			for ci in get_slide_collision_count():
				var col := get_slide_collision(ci).get_collider()
				if col is Node3D and not (col is CharacterBody3D):
					var what: String = col.name
					if col.get_parent() != game:
						what = "%s/%s" % [col.get_parent().name, col.name]
					for ch in col.get_children():
						if ch is CollisionShape3D and ch.shape is BoxShape3D:
							what += "[%s]" % [ch.shape.size.snapped(Vector3.ONE * 0.1)]
					hits.append("%s@%s" % [what, get_slide_collision(ci).get_position().snapped(Vector3.ONE * 0.1)])
			if not hits.is_empty():
				print("BUMP t=%d team%d %s at %s job=%s target=%s hits=%s" % [game.match_clock(), team, role_name(), global_position.snapped(Vector3.ONE * 0.1), bot_job, target.snapped(Vector3.ONE * 0.1), hits])
		sidestep_timer = 1.2
		sidestep_sign = -sidestep_sign
	if sidestep_timer > 0.0:
		dir = (dir * 0.4 + dir.cross(Vector3.UP) * sidestep_sign).normalized()
		return dir
	# Look ahead: if something solid (a tree, a crate, a wall) is square in
	# front of us within two metres, walk along it now rather than push into
	# it and wait to count as stuck. A shallow approach is left alone, since
	# sliding along the wall already takes us where we are going. The probe
	# stops short of the target so the thing we are walking up to (a turret,
	# a door, a hat) never counts.
	if to.length() > 1.5:
		# Once we have picked a detour, hold it for half a second so we do not
		# flip between the detour and the blocked line every frame.
		if avoid_timer > 0.0:
			return avoid_dir
		var reach := minf(2.0, to.length() - 0.6)
		var hit := _probe(dir, reach)
		if hit.is_empty():
			avoid_side = 0.0   # the way ahead is clear: the next obstacle picks its own side
		else:
			var n: Vector3 = hit.normal
			n.y = 0.0
			n = n.normalized()
			if -n.dot(dir) > 0.7:
				# Along the obstacle's face. The side is chosen once per
				# obstacle (the way our heading already leans) and kept until
				# the line ahead is clear: re-choosing every half second made
				# a bot on a long wall walk back and forth across the target
				# line without ever reaching the wall's end.
				var tangent := Vector3(-n.z, 0, n.x)
				if avoid_side == 0.0:
					var lean := tangent.dot(dir)
					avoid_side = signf(lean) if absf(lean) > 0.001 else sidestep_sign
				tangent *= avoid_side
				for d2: Vector3 in [(dir * 0.5 + tangent).normalized(), tangent, (dir * 0.5 - tangent).normalized(), -tangent]:
					if _probe(d2, reach * 0.9).is_empty():
						avoid_dir = d2
						avoid_timer = 0.5
						return d2
				# Boxed in on this side: try the other side next time.
				avoid_side = -avoid_side
				sidestep_sign = -sidestep_sign
	return dir


func _nearest_enemy(radius: float):
	## The closest living enemy within `radius` that we can actually see:
	## walls and doors hide people, so nobody stands shooting at stone.
	## Anyone still standing comes first: a downed enemy ranks as if it lay
	## BOT_DOWNED_TARGET_PENALTY further away, so bots finish it afterwards.
	var best = null
	var best_score := INF
	for other in game.units:
		if other.team == team or other.dead or other.stealth_timer > 0.0:
			continue
		var d := _flat_to(other.global_position).length()
		if other.downed and d > Stats.BOT_FINISH_RANGE:
			continue   # nobody snipes a body from across the field: walk up to finish it
		var sc: float = d + (Stats.BOT_DOWNED_TARGET_PENALTY if other.downed else 0.0)
		if d < radius and sc < best_score and _can_see(other):
			best_score = sc
			best = other
	return best


func _can_see(other) -> bool:
	var from := global_position + Vector3(0, 1.0, 0)
	var to: Vector3 = other.global_position + Vector3(0, 1.0, 0)
	var ray := PhysicsRayQueryParameters3D.create(from, to, 1 | (8 if team == 0 else 4))
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()


func _nearest_ally(job: String):
	var best = null
	var best_dist := 1e9
	for other in game.units:
		if other == self or other.team != team or other.dead or other.bot_job != job:
			continue
		var d := _flat_to(other.global_position).length()
		if d < best_dist:
			best_dist = d
			best = other
	return best


func _nearest_ally_any(min_dist: float):
	var best = null
	var best_dist := 1e9
	for other in game.units:
		if other == self or other.team != team or other.dead:
			continue
		var d := _flat_to(other.global_position).length()
		if d > min_dist and d < best_dist:
			best_dist = d
			best = other
	return best


func _heal_focus():
	## Who a healer sticks with: our crown carrier, then anyone on their last
	## heart, then a knight in a fight, then the nearest hurt teammate, then
	## whoever is attacking.
	var theirs = game.monarchs[1 - team]
	if theirs.state == Monarch.State.CARRIED and theirs.carrier.team == team:
		return theirs.carrier
	var best = null
	var best_score := -1.0
	for other in game.units:
		if other == self or other.team != team or other.dead or other.downed:
			continue
		var d := _flat_to(other.global_position).length()
		var sc := 0.0
		if other.hearts <= 1:
			sc = 300.0
		elif other.role == Role.KNIGHT and other._nearest_enemy(6.0) != null:
			sc = 200.0
		elif other.hearts < other.max_hearts():
			sc = 100.0
		elif other.bot_job == "attack" or other.bot_job == "escort" or other.bot_job == "recover":
			sc = 50.0
		sc -= d * 0.5
		if sc > best_score:
			best_score = sc
			best = other
	return best


func _roll(p: float) -> bool:
	## A chance scaled by the bot difficulty's ability rate.
	return randf() < p * game.bot_tuning().ability


func _bot_aim(to: Vector3) -> Vector3:
	## Aim with the wobble the difficulty allows.
	var e: float = game.bot_tuning().aim_error
	return to.normalized().rotated(Vector3.UP, randf_range(-e, e))


func _bot_pick_ability(dist: float) -> int:
	## Which ability (0 or 1) a bot wants to use on an enemy this far away, or -1.
	if game.economy and game.economy.bot_hat_pick(self, dist):
		return 2   # the upgraded hat's move (economy.gd)
	for i in 2:
		if i < abilities().size() and ability_ready(i):
			var a: Dictionary = abilities()[i]
			match a.kind:
				"cleave", "curse":
					if dist < a.radius * 0.9 and _roll(0.04):
						return i
				"shot":
					if dist <= 14.0 and _roll(0.06 if cluster >= 2 else 0.015):
						return i
				"smoke":
					if hearts <= 2 and dist < 5.0 and _roll(0.05):
						return i
				"bubble":
					if (hearts <= 2 or _injured_allies_near(3.0).size() >= 2) and dist < 6.0 and _roll(0.05):
						return i
	match role:
		Role.KNIGHT:
			if dist < 4.0 and ability_ready(0) and _roll(0.03):
				return 0
			if hearts <= 2 and dist < 3.0 and ability_ready(1) and _roll(0.05):
				return 1
		Role.RANGER:
			if dist <= 12.0 and ability_ready(0) and _roll(0.02):
				return 0
			if dist < 6.0 and ability_ready(1) and _roll(0.03):
				return 1
		Role.MAGE:
			if dist <= 10.0 and ability_ready(0) and _roll(0.06 if cluster >= 2 else 0.015):
				return 0
			if hearts <= 1 and dist < 5.0 and ability_ready(1):
				return 1
		Role.HEALER:
			if _injured_allies_near().is_empty() and dist <= 10.0 and ability_ready(1) and _roll(0.03):
				return 1
	return -1


func _prune_turrets() -> void:
	turrets = turrets.filter(func(t): return is_instance_valid(t))


func _tune_target(a: Dictionary):
	## For Tune Up: the nearest of our own turrets within reach that can take
	## work, else our door if we stand by it and it needs mending.
	_prune_turrets()
	var best = null
	var best_d := 4.5
	for t in turrets:
		var d: float = _flat_to(t.global_position).length()
		if d < best_d and t.needs_work() and absf(t.global_position.y - global_position.y) < 1.5:
			best_d = d
			best = t
	if best:
		return best
	var gate = game.gates[team]
	if _flat_to(gate.global_position).length() < 5.0 and (gate.broken or (a.get("door", 0) > 0 and gate.hp < Stats.GATE_HITS)):
		return gate
	return null


func _engineer_goal(plan: Dictionary) -> Vector3:
	## A bot Engineer's job: build on the team's spots, tune what it built,
	## then hold the yard like a defender. Sets plan.ability when standing
	## in place for a build or a tune-up.
	_prune_turrets()
	var side := -1.0 if team == 0 else 1.0
	var behind := Vector3(side, 0, 0)   # toward our own keep
	var a0: Dictionary = ability(0)
	if turrets.size() < int(a0.get("turrets", 2)) and game.turrets.size() < Stats.TURRET.team_max:
		for spot in game.turret_spots(team):
			var taken := false
			for t in game.turrets:
				if game._flat_dist(t.global_position, spot) < 2.4:
					taken = true
					break
			if taken:
				continue
			var stand: Vector3 = spot + behind * Stats.TURRET.place_dist
			if _flat_to(stand).length() < 0.7 and absf(global_position.y - spot.y) < 0.6:
				if ability_ready(0):
					plan.aim = -behind
					plan.ability = 0
			return stand
	for t in turrets:
		if t.needs_work() and ability_ready(1):
			var stand: Vector3 = t.global_position + behind * 1.5
			if _flat_to(t.global_position).length() < 3.5 and absf(global_position.y - t.global_position.y) < 1.5:
				plan.ability = 1
			return stand
	# Works done: take the hammer to the enemy door with the raiders (the
	# squad planner still pulls us home to defend when the castle is breached).
	return _raid_goal(0.0)


func _prep_goal(plan: Dictionary) -> Vector3:
	## The fortify phase: Rangers set a trap on the road outside our door,
	## Knights and Mages raise a barricade on the flanks, then everyone takes
	## a post (walls for the ranged, the yard for the rest).
	var out := 1.0 if team == 0 else -1.0   # toward the enemy
	var fx: float = game._front_x(team)
	var zs := -1.0 if bot_offset.z < 0.0 else 1.0
	var spot: Vector3
	match role:
		Role.RANGER:
			spot = Vector3(fx + out * 7.0, 0, zs * 1.5)
			if not prep_done:
				if _flat_to(spot).length() < 1.0 and global_position.y < 1.0:
					plan.aim = Vector3(out, 0, 0)
					if ability_ready(1) and ability(1).kind == "trap":
						plan.ability = 1
					prep_done = true
				return spot
			return game.wall_post(team, bot_offset.z)
		Role.KNIGHT, Role.MAGE:
			# (On Ember Pass both stay on the plateau: 9 m out is over the lava.)
			spot = Vector3(fx + out * (9.0 if role == Role.KNIGHT and game.vmap == null else 6.5), 0, zs * (5.0 if role == Role.KNIGHT else 7.5))
			if not prep_done:
				if _flat_to(spot).length() < 0.8 and global_position.y < 1.0:
					facing = Vector3(out, 0, 0)
					game.plant_barricade(self)
					prep_done = true
				return spot
			return game.wall_post(team, bot_offset.z) if role == Role.MAGE else game.defense_post(team, bot_offset.z)
		_:
			return game.defense_post(team, bot_offset.z) + _post_spread()


func _post_spread() -> Vector3:
	## How far off the defence post this bot stands: a little along the
	## wall, never out into the yard clutter.
	return Vector3(bot_offset.x * 0.3, 0, clampf(bot_offset.z * 0.3, -1.2, 1.2))


func _raid_goal(delta: float) -> Vector3:
	## Where a raider walks: the enemy monarch, but by way of a rally point
	## outside the enemy door, where the raid waits for company. One raider at
	## a time just feeds the turrets; two or three together break in.
	var theirs = game.monarchs[1 - team]
	var rally: Vector3 = game.rally_point(team)
	var toward_enemy := 1.0 if team == 0 else -1.0
	var past_rally: bool = (global_position.x - rally.x) * toward_enemy > 1.0
	if game.gates[1 - team].broken or game.overtime or past_rally or game.command_active(team, "attack"):
		rally_wait = 0.0
		return theirs.global_position
	if _flat_to(rally).length() > Stats.RALLY.radius * 0.6:
		return rally + bot_offset * 0.5
	rally_wait += delta
	if game.raiders_near(team, rally, Stats.RALLY.radius) >= Stats.RALLY.group or rally_wait > Stats.RALLY.wait:
		return theirs.global_position
	return rally + bot_offset * 0.5


func _bot_think(delta: float) -> Dictionary:
	var plan := {"move": Vector3.ZERO, "attack": false, "aim": facing}
	var s := attack_stats()
	var mine = game.monarchs[team]
	var theirs = game.monarchs[1 - team]
	var ranged: bool = s.attack == "arrow" or s.attack == "spell"
	var on_ground: bool = global_position.y < 1.0

	# Grab the enemy monarch whenever it's within reach.
	if not carrying and theirs.state != Monarch.State.CARRIED \
			and _flat_to(theirs.global_position).length() < PICKUP_RANGE:
		game.try_interact(self)

	# A downed teammate close by and safe enough: go and pick them up.
	var downed_mate = _bot_revive_goal(mine)
	if downed_mate:
		var to_mate := _flat_to(downed_mate.global_position)
		if to_mate.length() <= revive_reach() * 0.85:
			plan.revive = downed_mate
			plan.aim = to_mate.normalized() if to_mate.length() > 0.05 else facing
		else:
			plan.move = _steer_to(game.route_point(global_position, downed_mate.global_position))
		return plan

	# Choose where to go.
	var goal: Vector3
	var priority_target = null
	var holding_wall := false
	# Fresh spawns always grab their class first; the stations sit by the spawn.
	var gearing_up: bool = (role == Role.BASE and bot_class != Role.BASE) or (game.economy != null and game.economy.bot_wants_new_hat(self))
	var orb = game.nearest_orb(global_position, 14.0) if hearts <= 2 and not carrying else null
	var bless = game.nearest_blessing(global_position, 16.0) if not carrying and buff == "" else null
	if carrying:
		goal = game.thrones[team]
	elif gearing_up:
		goal = game.station_position(team, bot_class)
	elif orb:
		goal = orb.global_position
	elif bot_job == "prep":
		goal = _prep_goal(plan)
	elif mine.state == Monarch.State.CARRIED and (bot_job == "recover" or _flat_to(mine.carrier.global_position).length() < 16.0):
		# Our crown is being carried off: the recovery group, and anyone who
		# can see the thief, hunts the carrier.
		priority_target = mine.carrier
		goal = mine.carrier.global_position
	elif mine.state == Monarch.State.DROPPED and (bot_job == "recover" or _flat_to(mine.global_position).length() < 16.0):
		goal = mine.global_position
	elif theirs.state == Monarch.State.CARRIED and (bot_job == "escort" or bot_job == "support" or _flat_to(theirs.carrier.global_position).length() < 10.0):
		goal = theirs.carrier.global_position + bot_offset  # escort our carrier
	elif bot_job == "rally_to":
		goal = job_target + bot_offset * 0.5  # the player called "To me!"
	elif bot_job == "defend":
		# Spread a little along the wall, not out into the yard clutter.
		goal = game.defense_post(team, bot_offset.z) + _post_spread()
	elif bot_job == "fire" and game.vmap:
		goal = game.vmap.fire_spot(bot_offset)   # Ember Pass: take and hold the Fire Objective
	elif bot_job == "gather" and game.economy:
		goal = game.economy.bot_goal(self, plan)   # wood and ore (economy.gd)
	elif bless:
		goal = bless.global_position
	elif bot_job == "wall":
		goal = game.wall_post(team, bot_offset.z)
		holding_wall = true
	elif bot_job == "build" and role == Role.ENGINEER:
		goal = _engineer_goal(plan)
	elif bot_job == "support":
		var buddy = _heal_focus()
		goal = (buddy.global_position if buddy else game.thrones[team]) + bot_offset * 0.6
	elif bot_job == "attack":
		goal = _raid_goal(delta)
	else:
		goal = game.thrones[team] + Vector3(6.0 if team == 0 else -6.0, 0, 0) + bot_offset
	# Outnumbered and hurt: fall back toward the nearest teammate instead of
	# feeding. Never while carrying or recovering the crown.
	if not carrying and bot_job != "recover" and hearts <= 2 \
			and game.enemies_near(team, global_position, 12.0) > game.allies_near(team, global_position, 12.0) + 1:
		var buddy = _nearest_ally_any(6.0)
		goal = buddy.global_position if buddy else Vector3(game.gates[team].position.x + (-1.0 if team == 0 else 1.0) * 4.0, 0, 0)
	# Doors and ramps: the next point to walk toward on the way to the goal.
	var next: Vector3 = game.route_point(global_position, goal)

	# Healers patch up anyone hurt nearby before doing anything else, and
	# bless the group when several are hurt.
	if s.attack == "heal" and energy >= s.cost and not _injured_allies_near().is_empty():
		plan.attack = true
	if role == Role.HEALER and ability_ready(0) and _injured_allies_near(ability(0).radius).size() >= 2 \
			and randf() < 0.05:
		plan.ability = 0

	# The enemy door stands between us and the goal: break it down.
	var gate = game.gate_blocking(team, global_position, goal)
	if gate and not carrying:
		var side := signf(global_position.x - gate.position.x)
		var standoff := 7.0 if ranged else 1.3
		var spot := Vector3(gate.position.x + side * standoff, 0, clampf(global_position.z, -2.5, 2.5))
		if _nearest_enemy(3.0) == null:
			if _flat_to(spot).length() < 1.0:
				plan.aim = Vector3(-side, 0, 0)
				plan.attack = true
				if role == Role.MAGE and ability_ready(0) and randf() < 0.02:
					plan.ability = 0  # fireballs wreck doors
			else:
				plan.move = _steer_to(game.route_point(global_position, spot))
			return plan

	if carrying:
		plan.move = _steer_to(next)
		return plan

	# The Crown Vault lock stands between us and their monarch: break it.
	var vault = game.vaults[1 - team]
	if vault.is_locked() and theirs.state == Monarch.State.HOME and game._inside_keep(1 - team, global_position):
		var vside := signf(global_position.x - vault.lock_pos.x)
		var vstandoff := 5.0 if ranged else 1.2
		var vspot := Vector3(vault.lock_pos.x + vside * vstandoff, 0, clampf(global_position.z, -2.0, 2.0))
		if _nearest_enemy(2.5) == null:
			if _flat_to(vspot).length() < 0.9:
				plan.aim = Vector3(-vside, 0, 0)
				plan.attack = true
				if role == Role.MAGE and ability_ready(0) and _roll(0.03):
					plan.ability = 0
			else:
				plan.move = _steer_to(vspot)
			return plan


	# Fight anyone nearby, the enemy carrier first.
	var sight: float = (13.0 if ranged else 7.0) * game.bot_tuning().sight
	# Hunters go after an enemy Elite Veteran's bounty when it is close enough.
	if priority_target == null and bot_job == "attack" and not gearing_up:
		var chase: float = game.bot_tuning().chase
		for e in game.units:
			if e.team != team and not e.dead and e.veteran == 2 and _flat_to(e.global_position).length() < chase:
				priority_target = e
				next = game.route_point(global_position, e.global_position)
	# Knights cover a healer who is being jumped.
	if priority_target == null and role == Role.KNIGHT:
		for h in game.units:
			if h.team == team and not h.dead and h.role == Role.HEALER and _flat_to(h.global_position).length() < 12.0:
				var bully = h._nearest_enemy(3.5)
				if bully:
					priority_target = bully
	var enemy = priority_target if priority_target and _flat_to(priority_target.global_position).length() < maxf(sight, game.bot_tuning().chase) else _nearest_enemy(sight)
	# Healers do not chase: they keep to their group and back off from anyone
	# who gets close, unless cornered.
	if enemy and role == Role.HEALER and bot_job != "recover":
		var threat_d := _flat_to(enemy.global_position).length()
		if threat_d < 4.0:
			var away := -_flat_to(enemy.global_position).normalized()
			var focus = _heal_focus()
			var toward := _flat_to(focus.global_position).normalized() if focus and focus != self else Vector3.ZERO
			plan.move = (away + toward * 0.7).normalized()
			plan.aim = -away
			plan.attack = plan.attack or energy >= s.cost
			return plan
	if enemy and enemy.downed:
		# Bots don't leave a post or a crown run to finish a body: wall and
		# door guards only finish one at their feet, raiders one in their path.
		var body_d := _flat_to(enemy.global_position).length()
		var running: bool = gearing_up or (bot_job == "attack" and mine.state == Monarch.State.HOME)
		if (holding_wall or bot_job == "defend") and body_d > Stats.REVIVE_RANGE:
			enemy = null
		elif running and body_d > 3.0:
			enemy = null
	if enemy and enemy.downed:
		# A downed enemy: walk up and do the finisher instead of swinging.
		var to_body := _flat_to(enemy.global_position)
		plan.aim = to_body.normalized() if to_body.length() > 0.05 else facing
		if to_body.length() <= Stats.REVIVE_RANGE * 0.8:
			plan.finish = enemy
		else:
			plan.move = _steer_to(game.route_point(global_position, enemy.global_position))
		return plan
	if enemy:
		var to := _flat_to(enemy.global_position)
		var in_range: bool = to.length() <= s.range * 0.9
		cluster = game.enemies_near(team, enemy.global_position, 3.0)
		if not plan.attack:
			plan.aim = _bot_aim(to)
			plan.attack = in_range
		if not plan.has("ability"):
			var pick := _bot_pick_ability(to.length())
			if pick >= 0:
				plan.ability = pick
				# A Mage's Blink is an escape: away from the enemy.
				plan.aim = -to.normalized() if (role == Role.MAGE and pick == 1) else to.normalized()
		# Knights raise the shield while closing in on an archer or mage.
		if can_block() and not in_range:
			var their_attack: String = enemy.stats().attack
			if (their_attack == "arrow" or their_attack == "spell") and to.length() < 10.0 and randf() < 0.03 * game.bot_tuning().react:
				bot_block_timer = 1.0
		if bot_block_timer > 0.0 and not in_range:
			plan.block = true
			plan.aim = to.normalized()
		# Wall archers hold their post: shoot what they can reach, chase nobody.
		if holding_wall:
			plan.move = _steer_to(next)
			return plan
		# Raiders keep running for the monarch, hitting whoever is in reach,
		# and only stop to fight someone right on top of them.
		var raiding: bool = gearing_up or (bot_job == "attack" and mine.state == Monarch.State.HOME)
		if raiding and to.length() > 3.0:
			plan.move = _steer_to(next)
			return plan
		if in_range:
			# Shooters on the ground keep a little distance, and rangers tuck
			# in behind the nearest barricade or boulder when one is handy.
			if ranged and on_ground and to.length() < 5.0:
				plan.move = -to.normalized() * 0.6
			elif role == Role.RANGER and on_ground and not raiding:
				var c: Vector3 = game.nearest_cover(global_position, 7.0)
				if c != Vector3.INF and _flat_to(c).length() < to.length():
					var spot: Vector3 = c + (c - enemy.global_position).normalized() * 1.5
					spot.y = 0.0
					if _flat_to(spot).length() > 0.8:
						plan.move = _steer_to(spot)
			return plan
		plan.move = _steer_to(game.route_point(global_position, enemy.global_position))
		return plan

	plan.move = _steer_to(next)
	return plan
