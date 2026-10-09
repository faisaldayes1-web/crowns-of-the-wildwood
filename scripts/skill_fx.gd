extends RefCounted
## How each ability looks when it is cast: its own body animation and its
## own particles, on top of what the ability itself draws (projectiles,
## rings, domes). Looks only: nothing here touches damage, timing or reach.
##
## Elves are nature and fae magic (leaf green, violet, moonlight silver);
## Humans are steel and holy light (silver sparks, gold, white). Shared
## promotions take their side's colours.
##   cast(u, a, dir)       as the ability goes off (animation + wind-up)
##   land(u, a, dir, from) after it resolved (dashes and blinks: from -> here)
##   shot(u, a)            projectile colour and look for the ability's shots

const Fx = preload("res://scripts/fx.gd")
const Stats = preload("res://scripts/stats.gd")

const LEAF := Color(0.45, 0.95, 0.4)
const BARK := Color(0.55, 0.4, 0.22)
const FAE := Color(0.74, 0.42, 1.0)
const MOON := Color(0.78, 0.88, 1.0)
const BLOOM := Color(1.0, 0.6, 0.85)
const GOLD := Color(1.0, 0.84, 0.35)
const HOLY := Color(1.0, 0.96, 0.72)
const STEEL := Color(0.85, 0.9, 1.0)
const FIRE := Color(1.0, 0.55, 0.15)
const FROST := Color(0.6, 0.85, 1.0)
const SHADOW := Color(0.42, 0.3, 0.62)
const ARCANE := Color(0.62, 0.55, 1.0)
const DARK := Color(0.6, 0.25, 0.85)
const DUST := Color(0.62, 0.55, 0.45)

## Body animation (and speed) per ability; anything missing falls back on
## its kind below.
const ANIMS := {
	"Shield Bash": ["Block_Attack", 1.9],
	"Charge": ["2H_Melee_Attack_Stab", 1.5],
	"Shield Slam": ["1H_Melee_Attack_Chop", 1.7],
	"Wind Dash": ["Dodge_Forward", 1.8],
	"Shadow Dash": ["Dualwield_Melee_Attack_Stab", 1.8],
	"Backstab": ["Dualwield_Melee_Attack_Chop", 1.8],
	"Barkskin": ["Block", 1.4],
	"Cleave": ["2H_Melee_Attack_Spin", 1.4],
	"Flame Wave": ["Spellcast_Shoot", 1.3],
	"Volley": ["2H_Ranged_Shoot", 1.2],
	"Starfall": ["Spellcast_Raise", 2.0],
	"Piercing Shot": ["2H_Ranged_Shoot", 1.0],
	"Snipe": ["2H_Ranged_Shoot", 0.9],
	"Heavy Bolt": ["2H_Ranged_Shoot", 1.0],
	"Snare Trap": ["PickUp", 1.8],
	"Trap Line": ["Throw", 1.6],
	"Caltrops": ["Throw", 1.7],
	"Vine Snare": ["Spellcast_Raise", 1.9],
	"Fireball": ["Spellcast_Long", 1.4],
	"Inferno": ["Spellcast_Raise", 1.4],
	"Ice Burst": ["Spellcast_Shoot", 1.5],
	"Bramble Burst": ["Spellcast_Shoot", 1.4],
	"Blink": ["Spellcast_Raise", 2.0],
	"Fae Step": ["Dodge_Forward", 1.6],
	"Shadow Step": ["Dodge_Forward", 2.0],
	"Smoke Bomb": ["Throw", 1.8],
	"Vanish": ["Spellcast_Raise", 2.2],
	"Blessing": ["Spellcast_Long", 1.2],
	"Sanctuary": ["Spellcast_Raise", 1.2],
	"Spirit Bloom": ["Spellcasting", 1.4],
	"Smite": ["Spellcast_Shoot", 1.6],
	"Radiance": ["Spellcast_Raise", 1.8],
	"Lunar Lance": ["Spellcast_Shoot", 1.8],
	"Curse": ["Spellcast_Raise", 1.5],
	"Holy Bubble": ["Spellcast_Raise", 1.6],
	"Build Turret": ["1H_Melee_Attack_Chop", 1.6],
	"Rapid Turret": ["1H_Melee_Attack_Chop", 1.9],
	"Ballista": ["2H_Melee_Attack_Chop", 1.5],
	"Thorn Totem": ["Spellcast_Raise", 1.6],
	"Tune Up": ["1H_Melee_Attack_Chop", 1.8],
	"Fortify": ["2H_Melee_Attack_Chop", 1.6],
	"Tend": ["Interact", 1.4],
	"Overclock": ["Use_Item", 1.6],
}

const KIND_ANIMS := {
	"bash": ["1H_Melee_Attack_Stab", 1.6], "bubble": ["Spellcast_Raise", 1.6], "volley": ["2H_Ranged_Shoot", 1.2],
	"trap": ["Interact", 1.5], "fireball": ["Spellcast_Long", 1.4], "blink": ["Spellcast_Raise", 2.0],
	"blessing": ["Spellcast_Long", 1.2], "smite": ["Spellcast_Shoot", 1.6], "shot": ["2H_Ranged_Shoot", 1.2],
	"smoke": ["Interact", 1.8], "curse": ["Spellcast_Raise", 1.5], "turret": ["Interact", 1.6],
	"upgrade": ["Interact", 1.6], "overclock": ["Interact", 1.6],
}


static func _elf(u) -> bool:
	return u.team == 0


static func _at(u, up: float = 0.0, fwd: float = 0.0, dir: Vector3 = Vector3.ZERO) -> Vector3:
	return u.global_position + Vector3(0, up, 0) + dir * fwd


static func animate(u, a: Dictionary) -> void:
	var n = _net_open("skill", "animate", [u, a])
	_x_animate(u, a)
	_net_close(n)


static func _x_animate(u, a: Dictionary) -> void:
	var m = u.model
	if m == null:
		return
	if a.kind == "guard":
		m.hold("Blocking")
		if a.name == "Barkskin" or a.name == "Bulwark":
			m.play_once("Block", 1.4)   # brace first; the held block follows
		return
	var pick: Array = ANIMS.get(a.name, [])
	if a.kind == "cleave" and a.name != "Flame Wave" and u.role != Stats.Role.KNIGHT:
		pick = ["Spellcast_Long", 1.4]
	if pick.is_empty() or m.anim == null or not m.anim.has_animation(pick[0]):
		pick = KIND_ANIMS.get(a.kind, [])
	if not pick.is_empty():
		m.play_once(pick[0], pick[1])



# --- Body motion (on the model only; the unit's own transform is untouched) ---

static func _lunge(u, lean: float = 0.28, t: float = 0.12) -> void:
	var m = u.model
	if m == null:
		return
	var tw: Tween = m.create_tween()
	tw.tween_property(m, "rotation:x", -lean, t).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "rotation:x", 0.0, t * 2.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func _hop(u, h: float = 0.45, t: float = 0.32) -> void:
	var m = u.model
	if m == null:
		return
	var tw: Tween = m.create_tween()
	tw.tween_property(m, "position:y", h, t * 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(m, "position:y", 0.0, t * 0.55).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)


static func _spin(u, turns: float = 1.0, t: float = 0.35) -> void:
	var m = u.model
	if m == null:
		return
	m.rotation.y = 0.0
	var tw: Tween = m.create_tween()
	tw.tween_property(m, "rotation:y", TAU * turns, t).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_callback(func(): m.rotation.y = 0.0)


static func _pop(u, from: Vector3 = Vector3(0.35, 1.45, 0.35), t: float = 0.28) -> void:
	## Squeezed thin, then springing back to shape (arriving from a blink).
	var m = u.model
	if m == null:
		return
	m.scale = from
	m.create_tween().tween_property(m, "scale", Vector3.ONE, t).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func _swell(u, k: float = 1.12, t: float = 0.3) -> void:
	## Drawing power in: a breath in and out.
	var m = u.model
	if m == null:
		return
	var tw: Tween = m.create_tween()
	tw.tween_property(m, "scale", Vector3(k, k, k), t * 0.4).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "scale", Vector3.ONE, t * 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func _streaks(fx, from: Vector3, to: Vector3, color: Color, count: int = 5, life: float = 0.35) -> void:
	## Speed lines along a dash, at several heights.
	var side := (to - from).cross(Vector3.UP).normalized()
	for i in count:
		var off := side * randf_range(-0.45, 0.45) + Vector3(0, randf_range(0.3, 1.6), 0)
		var cut := randf_range(0.0, 0.35)
		fx.beam(from.lerp(to, cut) + off, to + off - (to - from).normalized() * randf_range(0.2, 1.0), color, life, randf_range(0.05, 0.11))


static func _ghost_path(fx, u, from: Vector3, to: Vector3, color: Color, count: int, life: float) -> void:
	## Afterimages standing along the path the caster took, oldest faintest.
	var m = u.model
	if m == null:
		return
	var here: Vector3 = m.global_position
	for i in count:
		var k := float(i) / float(count)
		var g_at: Vector3 = from.lerp(to, k) + (here - u.global_position)
		var keep: Transform3D = m.global_transform
		m.global_position = g_at
		fx.afterimage(m, Color(color, 0.35 + 0.5 * k), life * (0.6 + 0.6 * k))
		m.global_transform = keep


# --- Cast --------------------------------------------------------------------

static func cast(u, a: Dictionary, dir: Vector3) -> void:
	var n = _net_open("skill", "cast", [u, a, dir])
	_x_cast(u, a, dir)
	_net_close(n)


static func _x_cast(u, a: Dictionary, dir: Vector3) -> void:
	animate(u, a)
	var fx = Fx.of(u.game)
	var elf := _elf(u)
	var p: Vector3 = u.global_position
	match a.name:
		# Knights ------------------------------------------------------------
		"Shield Bash", "Shield Slam":
			_lunge(u, 0.32)
			fx.burst(_at(u, 1.0, 0.7, dir), STEEL, 12, 7.0, 0.3, Fx.STYLE_SPARK, dir, 35.0)
			fx.burst(_at(u, 0.2), DUST, 6, 2.0, 0.7, Fx.STYLE_SMOKE, -dir, 40.0, 0.8)
			if a.name == "Shield Slam":
				_hop(u, 0.35, 0.25)
				fx.ground_ring(_at(u, 0.05, 1.2, dir), 2.2, STEEL, 0.35)
		"Charge":
			_lunge(u, 0.4, 0.1)
			fx.trail_ghosts(u.model, Color(0.6, 0.7, 0.95), 3, 0.06, 0.3)
			fx.burst(_at(u, 0.2), DUST, 10, 3.0, 0.8, Fx.STYLE_SMOKE, -dir, 50.0, 1.0)
		"Wind Dash":
			_lunge(u, 0.35, 0.08)
			fx.trail_ghosts(u.model, Color(0.35, 0.9, 0.5), 4, 0.045, 0.3)
			fx.petals(_at(u, 0.6), LEAF, 14, 4.0, 1.2, 0.8)
			fx.burst(_at(u, 1.0), Color(0.85, 1.0, 0.9), 10, 6.0, 0.35, Fx.STYLE_SPARK, -dir, 25.0)
		"Shadow Dash", "Backstab":
			_lunge(u, 0.3, 0.1)
			fx.trail_ghosts(u.model, SHADOW, 4, 0.05, 0.35)
			fx.burst(_at(u, 0.5), Color(0.2, 0.15, 0.3), 8, 1.5, 0.8, Fx.STYLE_SMOKE, Vector3.UP, 70.0, 0.9)
			if a.name == "Backstab":
				fx.burst(_at(u, 1.1, 0.8, dir), Color(1.0, 0.3, 0.3), 8, 6.0, 0.3, Fx.STYLE_SPARK, dir, 30.0)
		"Shield Wall":
			fx.dome(u, 1.5, STEEL, 0.45)
			fx.burst(_at(u, 1.0, 0.6, dir), STEEL, 10, 5.0, 0.3, Fx.STYLE_SPARK, dir, 60.0)
		"Bulwark":
			fx.dome(u, 2.2, GOLD, 0.6)
			fx.rays(_at(u, 1.0), GOLD, 6, 2.2, 0.35)
			fx.ground_ring(p, 2.6, GOLD, 0.45)
		"Barkskin":
			_swell(u, 1.1, 0.35)
			fx.dome(u, 1.5, Color(0.4, 0.7, 0.2), 0.55)
			fx.burst(_at(u, 1.0), BARK, 14, 3.5, 0.8, Fx.STYLE_SHARD)
			fx.petals(_at(u, 1.2), LEAF, 10, 2.5, 1.2)
			fx.swirl(u, LEAF, 18, 0.8, 2.0, 0.7)
		"Cleave":
			_spin(u, 1.0, 0.35)
			fx.burst(_at(u, 1.0), STEEL, 16, 8.0, 0.3, Fx.STYLE_SPARK, Vector3.UP, 90.0)
		"Flame Wave":
			_lunge(u, 0.25)
			fx.swirl(u, FIRE, 16, 0.6, 2.5, 0.5)
			for k in 5:
				var ang := deg_to_rad(70.0) * (float(k) / 4.0 - 0.5)
				fx.burst(_at(u, 0.8, 0.8, dir), FIRE, 8, 9.0, 0.45, Fx.STYLE_SPARK, dir.rotated(Vector3.UP, ang), 12.0)
		# Rangers ------------------------------------------------------------
		"Volley":
			fx.petals(_at(u, 1.3, 0.6, dir), Color(0.95, 0.93, 0.85), 8, 3.0, 1.0)   # feathers
			fx.burst(_at(u, 1.2, 0.8, dir), Color(1.0, 0.95, 0.75), 10, 7.0, 0.25, Fx.STYLE_SPARK, dir, 30.0)
		"Starfall":
			# Arms raised to the sky; stars wheel round the archer, then fly.
			fx.swirl(u, MOON, 26, 1.0, 3.5, 0.8)
			fx.burst(_at(u, 2.2), MOON, 14, 4.0, 0.7, Fx.STYLE_MOTE)
			fx.flare(_at(u, 2.4), Color(0.9, 0.95, 1.0), 0.9, 0.25)
			fx.rune(p, 1.3, MOON, 0.6)
		"Piercing Shot", "Snipe", "Heavy Bolt":
			_lunge(u, -0.18, 0.08)   # rocked back by the shot
			var c := GOLD if a.name == "Snipe" else STEEL
			fx.burst(_at(u, 1.2, 0.9, dir), c, 12, 9.0, 0.25, Fx.STYLE_SPARK, dir, 15.0)
			fx.burst(_at(u, 1.1, 0.7, dir), Color(0.6, 0.6, 0.62), 4, 1.0, 0.7, Fx.STYLE_SMOKE, Vector3.UP, 60.0, 0.6)
			fx.beam(_at(u, 1.2, 0.8, dir), _at(u, 1.2, 0.8 + (6.0 if a.name == "Snipe" else 3.5), dir), Color(c, 0.6), 0.18, 0.07)
		"Snare Trap", "Trap Line":
			fx.burst(_at(u, 0.4, 1.2, dir), DUST, 8, 2.5, 0.6, Fx.STYLE_SHARD)
		"Caltrops":
			fx.burst(_at(u, 1.0, 0.8, dir), STEEL, 14, 6.0, 0.5, Fx.STYLE_SHARD, dir + Vector3.UP * 0.5, 35.0)
		"Vine Snare":
			fx.swirl(u, LEAF, 16, 0.7, 2.0, 0.6)
			fx.petals(_at(u, 0.5, 1.5, dir), LEAF, 10, 2.5, 1.0)
		# Mages --------------------------------------------------------------
		"Fireball":
			fx.swirl(u, FIRE, 22, 0.7, 2.2, 0.6)
			fx.burst(_at(u, 1.3, 0.5, dir), FIRE, 10, 3.0, 0.6, Fx.STYLE_MOTE)
		"Inferno":
			_swell(u, 1.15, 0.35)
			fx.swirl(u, FIRE, 34, 1.1, 3.5, 0.8)
			fx.rays(_at(u, 1.0), FIRE, 8, 2.5, 0.35)
			fx.burst(_at(u, 0.4), Color(0.25, 0.2, 0.18), 6, 1.5, 1.0, Fx.STYLE_SMOKE, Vector3.UP, 60.0, 1.0)
		"Ice Burst":
			fx.swirl(u, FROST, 22, 0.8, 2.0, 0.6)
			fx.burst(_at(u, 1.2, 0.6, dir), Color(0.85, 0.95, 1.0), 12, 4.0, 0.6, Fx.STYLE_SHARD)
		"Bramble Burst":
			fx.swirl(u, LEAF, 22, 0.8, 2.2, 0.6)
			fx.petals(_at(u, 1.0), LEAF, 10, 3.0, 1.1)
			fx.thorns(p, 1.1, Color(0.3, 0.55, 0.2), 7, 0.6, 0.7)
		"Blink", "Fae Step", "Shadow Step":
			pass   # drawn on landing, along the path
		# Rogues -------------------------------------------------------------
		"Smoke Bomb":
			fx.burst(_at(u, 0.3), Color(0.3, 0.3, 0.32), 10, 5.0, 0.4, Fx.STYLE_SHARD)
		"Vanish":
			fx.afterimage(u.model, SHADOW, 0.6)
			fx.swirl(u, SHADOW, 20, 0.6, 2.0, 0.6, false)
		"Curse":
			_swell(u, 1.1, 0.4)
			fx.swirl(u, DARK, 26, 1.2, -1.5, 0.8)   # spiralling down into the ground
			fx.rune(p, a.get("radius", 4.0) * 0.6, DARK, 0.8)
		# Healers ------------------------------------------------------------
		"Blessing", "Sanctuary":
			fx.swirl(u, GOLD, 28, 1.0, 3.0, 0.9)
			fx.rays(_at(u, 1.2), HOLY, 10, 3.0, 0.45)
			fx.petals(_at(u, 2.6), Color(1.0, 0.98, 0.9), 12, 2.0, 1.6, 0.6)   # feathers drifting down
			if a.name == "Sanctuary":
				fx.dome(u, a.get("radius", 8.0) * 0.5, GOLD, 0.7)
		"Spirit Bloom":
			# Flowers open on the ground round the healer and petals lift away.
			fx.swirl(u, LEAF, 26, 1.2, 2.5, 1.0)
			var r: float = a.get("radius", 8.0)
			for i in 10:
				var ang := TAU * i / 10.0
				var at := p + Vector3(cos(ang), 0.1, sin(ang)) * r * randf_range(0.3, 0.75)
				fx.petals(at, BLOOM if i % 2 == 0 else Color(1.0, 0.95, 0.6), 5, 2.5, 1.4, 1.2)
				fx.ground_glow(at, 0.6, LEAF, 0.8)
		"Smite", "Radiance":
			fx.rays(_at(u, 1.3, 0.6, dir), HOLY if a.name == "Smite" else Color(1, 1, 1), 6 if a.name == "Smite" else 10, 1.8, 0.3)
			fx.swirl(u, GOLD, 14, 0.6, 2.0, 0.45)
		"Lunar Lance":
			fx.swirl(u, MOON, 18, 0.6, 2.4, 0.5)
			fx.burst(_at(u, 1.3, 0.7, dir), MOON, 10, 5.0, 0.35, Fx.STYLE_SPARK, dir, 25.0)
			fx.flare(_at(u, 1.3, 0.7, dir), Color(0.85, 0.92, 1.0), 0.8, 0.2)
		"Holy Bubble":
			fx.rays(_at(u, 1.0), HOLY, 10, 2.6, 0.4)
			fx.swirl(u, GOLD, 22, 1.4, 2.0, 0.7)
		# Engineers ----------------------------------------------------------
		"Build Turret", "Rapid Turret", "Ballista", "Tune Up", "Fortify":
			var at := _at(u, 0.3, 1.0, dir)
			for k in 3:
				u.get_tree().create_timer(0.12 * k).timeout.connect(func():
					if is_instance_valid(u):
						fx.burst(at, Color(1.0, 0.8, 0.4), 8, 5.0, 0.3, Fx.STYLE_SPARK, Vector3.UP, 60.0))
			fx.burst(at, DUST, 6, 1.5, 0.8, Fx.STYLE_SMOKE, Vector3.UP, 60.0, 0.8)
		"Thorn Totem":
			fx.swirl(u, LEAF, 18, 0.7, 2.2, 0.6)
			fx.thorns(_at(u, 0.0, 1.6, dir), 0.6, Color(0.35, 0.6, 0.22), 6, 0.7, 0.8)
			fx.petals(_at(u, 0.4, 1.6, dir), LEAF, 10, 3.0, 1.0)
		"Tend":
			fx.swirl(u, LEAF, 20, 0.8, 2.0, 0.7)
			fx.petals(_at(u, 1.0, 0.8, dir), BLOOM, 8, 2.0, 1.2)
		"Overclock":
			fx.rays(_at(u, 1.2), Color(0.7, 0.9, 1.0), 7, 2.0, 0.25)
			fx.burst(_at(u, 1.2), Color(0.7, 0.9, 1.0), 14, 6.0, 0.3, Fx.STYLE_SPARK)
		_:
			# Anything new: a rune and a swirl in the caster's side colours.
			fx.swirl(u, LEAF if elf else GOLD, 16, 0.7, 2.0, 0.6)


static func land(u, a: Dictionary, dir: Vector3, from: Vector3) -> void:
	var n = _net_open("skill", "land", [u, a, dir, from])
	_x_land(u, a, dir, from)
	_net_close(n)


static func _x_land(u, a: Dictionary, dir: Vector3, from: Vector3) -> void:
	## After the ability resolved: where a dash or blink carried the caster.
	var fx = Fx.of(u.game)
	var to: Vector3 = u.global_position
	match a.name:
		"Fae Step":
			# A violet dash along the fae paths: running afterimages left all
			# along the way, violet streaks, and the body springing back into
			# shape where it lands.
			_ghost_path(fx, u, from, to, FAE, 5, 0.55)
			_streaks(fx, from, to, Color(0.8, 0.5, 1.0, 0.9), 7, 0.4)
			fx.burst(from + Vector3(0, 1.0, 0), FAE, 14, 3.0, 0.7, Fx.STYLE_MOTE)
			fx.petals(from + Vector3(0, 0.8, 0), Color(0.85, 0.65, 1.0), 10, 2.5, 1.2)
			fx.burst(to + Vector3(0, 0.9, 0), Color(0.9, 0.75, 1.0), 16, 6.0, 0.35, Fx.STYLE_SPARK, dir, 60.0)
			fx.rune(to, 1.2, FAE, 0.5)
			fx.swirl(u, FAE, 18, 0.7, 2.5, 0.5)
			_pop(u, Vector3(0.55, 1.3, 0.55), 0.3)
		"Blink":
			_ghost_path(fx, u, from, to, ARCANE, 2, 0.4)
			fx.burst(to + Vector3(0, 1.0, 0), ARCANE, 12, 4.0, 0.4, Fx.STYLE_SPARK)
			_pop(u)
		"Shadow Step":
			_ghost_path(fx, u, from, to, SHADOW, 3, 0.45)
			fx.burst(from + Vector3(0, 0.6, 0), Color(0.15, 0.12, 0.2), 8, 1.5, 1.0, Fx.STYLE_SMOKE, Vector3.UP, 70.0, 1.0)
			fx.burst(to + Vector3(0, 0.6, 0), Color(0.15, 0.12, 0.2), 8, 1.5, 1.0, Fx.STYLE_SMOKE, Vector3.UP, 70.0, 1.0)
			_pop(u, Vector3(0.6, 1.2, 0.6))
		"Wind Dash", "Charge", "Shadow Dash", "Backstab", "Shield Bash", "Shield Slam":
			pass   # the dash itself moves over the next frames; ghosts trail it from cast()
		_:
			if a.kind == "blink":
				_ghost_path(fx, u, from, to, FAE if _elf(u) else ARCANE, 3, 0.45)
				_pop(u)


static func shot(u, a: Dictionary, color: Color) -> Array:
	## [colour, look] for an ability's projectiles (scripts/projectile.gd).
	match a.name:
		"Starfall":
			return [MOON, "star"]
		"Lunar Lance":
			return [MOON, "moon"]
		"Bramble Burst":
			return [LEAF, "thorn"]
		"Snipe":
			return [GOLD, ""]
	return [color, ""]


# --- Online: mirror every skill animation to the joiners (scripts/net.gd) ----

static func _net_open(target: String, method: String, args: Array):
	var tree := Engine.get_main_loop() as SceneTree
	var n = tree.root.get_node_or_null("Net") if tree else null
	if n:
		n.rec(target, method, args)
		n.depth += 1
	return n


static func _net_close(n) -> void:
	if n:
		n.depth -= 1
