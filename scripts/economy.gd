extends Node3D
## Wood and ore (Economy group, 2026-10-09). Soldiers chop lumber trees and
## mine ore deposits one unit at a time, carry the load on their back (a few
## units at most) and drop it at the storehouse in their castle yard, where
## it joins the team pool. The pool pays for:
##   - upgrading a class's hat machine (5 wood, 5 ore): a hat picked up from
##     an upgraded machine adds that class's extra move on G for the whole
##     team (Stats.HAT_UPGRADES);
##   - mending or raising the castle door, and buying, raising and patching
##     base turrets on the turret pads.
## Players spend with the interact key at the machine, the door or a pad.
## Bots gather (one per team), and on a team with no human player they also
## spend, door first. Every number is in Stats.ECONOMY.

const Stats = preload("res://scripts/stats.gd")
const ResourceNode = preload("res://scripts/resource_node.gd")
const Role = Stats.Role

# Where the trees and deposits stand on the Elves' half; the Humans' half
# mirrors them through the map centre (-p), like the groves. Spots that
# collide with roads, houses or other trees slide to the nearest clear
# ground (see _place).
const TREE_SPOTS := [Vector3(-34, 0, -9), Vector3(-41, 0, 10), Vector3(-35, 0, -15), Vector3(-31, 0, 12), Vector3(-15, 0, -6)]
const ORE_SPOTS := [Vector3(-35, 0, 5), Vector3(-37, 0, 16), Vector3(-11, 0, -13), Vector3(-12, 0, 11)]

var game
var nodes: Array = []               # every lumber tree and ore deposit
var depots: Array = [Vector3.INF, Vector3.INF]   # each team's storehouse
var depot_piles: Array = [null, null]            # the storehouse's wood and ore heaps, scaled by the pool
var wood := [0, 0]
var ore := [0, 0]
var upgraded := [{}, {}]            # team -> {role: true}: the hat machines that have been upgraded
var cargo := {}                     # unit -> {"wood": n, "ore": n}
var work := {}                      # unit -> {"node", "t", "from", "hearts", "atk", "swing"}
var drops: Array = []               # [{node, wood, ore, life}] loads dropped where a soldier fell
var gatherers := [[], []]           # bots on the gather job, per team
var pads: Array = [[], []]          # turret pads per team: [{pos, label}]
var door_labels: Array = [null, null]
var seal_labels := [{}, {}]
var seal_marks := [{}, {}]          # the gold trim an upgraded machine wears
var spend_timer := 0.0
var hint_given := [false, false]
# Match report (--demo): what each team gathered and bought.
var gathered := [{"wood": 0, "ore": 0}, {"wood": 0, "ore": 0}]
var bought := [{"hat": 0, "repair": 0, "rebuild": 0, "turret": 0, "tend": 0}, {"hat": 0, "repair": 0, "rebuild": 0, "turret": 0, "tend": 0}]


func build(p_game) -> void:
	game = p_game
	for spot in TREE_SPOTS:
		_place_pair("wood", spot)
	for spot in ORE_SPOTS:
		_place_pair("ore", spot)
	for team in 2:
		_build_depot(team)
		_build_pads(team)
		_build_door_label(team)
		for role in game.seals[team]:
			_build_seal_label(team, role)


func _place_pair(kind: String, pos: Vector3) -> void:
	## A node on the Elves' half at `pos` and its twin on the Humans' half at
	## -pos, so both teams walk the same distances. When either spot is taken
	## (a road, a house, a tree) both slide together to the nearest clear pair.
	var spot := Vector3.INF
	if _spot_ok(pos) and _spot_ok(-pos):
		spot = pos
	else:
		for d in [2.0, 3.5, 5.0, 6.5, 8.0]:
			for k in 12:
				var q: Vector3 = pos + Vector3(cos(k * TAU / 12.0), 0, sin(k * TAU / 12.0)) * d
				if _spot_ok(q) and _spot_ok(-q):
					spot = q
					break
			if spot.is_finite():
				break
	if not spot.is_finite():
		push_warning("Economy: no room for a %s node pair near %s" % [kind, pos])
		return
	for q in [spot, -spot]:
		var n = ResourceNode.new()
		add_child(n)
		n.setup(game, kind, q)
		nodes.append(n)
		if "--econ-where" in OS.get_cmdline_user_args():
			print("ECON node %s at %s" % [kind, q.snapped(Vector3.ONE * 0.1)])


func _spot_ok(p: Vector3) -> bool:
	## Clear of the roads and paths (with room to stand and work), the river,
	## other trees and anything built.
	if not game._tree_spot_ok(p, false):
		return false
	if absf(p.x) > game.CASTLE_X - game.CASTLE_DEPTH - 6.0:
		return false   # keep canopies off the castle walls (and the camera's view of the ramparts)
	if game._near_path(p, 2.2):
		return false
	for n in nodes:
		if game._flat_dist(n.position, p) < 5.0:
			return false
	for mark in game.map_marks:
		if game._flat_dist(p, mark[0]) < 4.0:
			return false
	return true


# --- Pool ----------------------------------------------------------------------

func can_afford(team: int, w: int, o: int) -> bool:
	return wood[team] >= w and ore[team] >= o


func _spend(team: int, w: int, o: int) -> bool:
	if not can_afford(team, w, o):
		return false
	wood[team] -= w
	ore[team] -= o
	_refresh_pile(team)
	return true


func _cost_text(w: int, o: int) -> String:
	return "%d wood · %d ore" % [w, o]


func _short(team: int, w: int, o: int) -> String:
	## "Need 2 more wood and 1 more ore" for a toast.
	var parts := []
	if wood[team] < w:
		parts.append("%d more wood" % (w - wood[team]))
	if ore[team] < o:
		parts.append("%d more ore" % (o - ore[team]))
	return "Your team needs " + " and ".join(parts)


func is_upgraded(team: int, role: int) -> bool:
	return upgraded[team].has(role)


func carried(u) -> int:
	var c: Dictionary = cargo.get(u, {})
	return c.get("wood", 0) + c.get("ore", 0)


func cargo_of(u) -> Dictionary:
	return cargo.get(u, {"wood": 0, "ore": 0})


# --- Interact key -----------------------------------------------------------------

func try_interact(u) -> bool:
	## Called first by game.try_interact. True when the key did something
	## here (or explained why it could not), so nothing else takes it.
	if u.dead or u.carrying:
		return false
	# Hat machines: wearing the class, F upgrades the machine, or swaps in the
	# upgraded hat once it is upgraded. Not wearing it, the seal takes over.
	for role in game.seals[u.team]:
		var seal = game.seals[u.team][role]
		if not seal.in_reach(u) or u.role != role or seal.locked:
			continue
		if is_upgraded(u.team, role):
			if u.hat_upgraded:
				return false
			seal.take(u)
			return true
		upgrade_hat(u.team, role, u)
		return true
	# Our door: mend it, or raise it if it is down.
	if _by_door(u) and _door_work(u.team) != "":
		fix_door(u.team, u)
		return true
	# Turret pads: buy a turret, or raise or patch ours.
	var pad := _pad_in_reach(u)
	if not pad.is_empty():
		var t = _turret_on(u.team, pad.pos)
		if t == null or t.needs_work():
			work_pad(u.team, pad.pos, u)
			return true
	# A tree or an ore deposit: start working it.
	for n in nodes:
		if n.in_reach(u):
			start_work(u, n)
			return true
	return false


func _by_door(u) -> bool:
	var gate = game.gates[u.team]
	var side := -1.0 if u.team == 0 else 1.0
	var inward: float = (u.global_position.x - gate.global_position.x) * side
	return inward > -0.6 and inward < Stats.ECONOMY.door_reach and absf(u.global_position.z) < Stats.DOOR_HALF + 1.0 \
		and u.global_position.y < 1.5


func _door_work(team: int) -> String:
	## "rebuild", "repair" or "" for what the door can take right now.
	var gate = game.gates[team]
	if gate.broken:
		return "" if gate.rebuild_timer == INF else "rebuild"
	return "repair" if gate.hp < Stats.GATE_HITS else ""


func _door_pressed(team: int) -> bool:
	var gate = game.gates[team]
	return game.enemy_inside_castle(team) or game.enemies_near(team, gate.global_position, Stats.GATE_SIEGE_RADIUS) > 0


func _pad_in_reach(u) -> Dictionary:
	for pad in pads[u.team]:
		var off: Vector3 = u.global_position - pad.pos
		if absf(off.y) < 1.2 and Vector2(off.x, off.z).length() < Stats.ECONOMY.pad_reach:
			return pad
	return {}


func _turret_on(team: int, pos: Vector3):
	for t in game.turrets:
		if is_instance_valid(t) and t.team == team and game._flat_dist(t.global_position, pos) < 1.4 \
				and absf(t.global_position.y - pos.y) < 1.0:
			return t
	return null


# --- Spending ---------------------------------------------------------------------

func upgrade_hat(team: int, role: int, by) -> bool:
	var E: Dictionary = Stats.ECONOMY
	if is_upgraded(team, role):
		return false
	if not _spend(team, E.hat_wood, E.hat_ore):
		if by and by.is_player:
			game.toast("Upgrading this hat machine costs %s. %s." % [_cost_text(E.hat_wood, E.hat_ore), _short(team, E.hat_wood, E.hat_ore)], Color(1.0, 0.8, 0.5))
			game.sfx.ui("ui_deny", -6.0)
		return false
	upgraded[team][role] = true
	bought[team].hat += 1
	var seal = game.seals[team][role]
	_mark_seal(team, role)
	var gold := Color(1.0, 0.85, 0.3)
	game.spawn_pillar(seal.global_position, gold, 5.0, 1.0)
	game.spawn_ring(seal.global_position, 2.4, gold, 0.7)
	game.spawn_splash(seal.global_position + Vector3(0, 1.4, 0), gold, 30, 4.0, 0.9, true)
	game.sfx.play("promote", seal.global_position, 0.0)
	var a: Dictionary = Stats.hat_upgrade(team, role)
	var cls: String = Stats.FACTIONS[team].roles[role]
	if by and by.is_player:
		game.announce("%s hat machine upgraded! Take the new hat to learn %s (%s)." % [cls, a.get("name", "?"), game.key_label("ability_3")])
	elif by:
		game.chat_system("%s upgraded the %s %s hat machine." % [by.display_name, Stats.FACTIONS[team].name, cls])
	if game.demo:
		print("ECON t=%d team%d upgrade %s" % [game.match_clock(), team, cls])
	if by and by.role == role and not by.dead:
		seal.take(by)   # standing at it wearing the class: put the new hat straight on
	return true


func fix_door(team: int, by) -> bool:
	var E: Dictionary = Stats.ECONOMY
	var gate = game.gates[team]
	var job := _door_work(team)
	if job == "rebuild":
		if _door_pressed(team):
			if by and by.is_player:
				game.toast("The door can't go up while the enemy holds the breach", Color(1.0, 0.6, 0.5))
				game.sfx.ui("ui_deny", -6.0)
			return false
		if not _spend(team, E.rebuild_wood, E.rebuild_ore):
			if by and by.is_player:
				game.toast("Raising the door costs %s. %s." % [_cost_text(E.rebuild_wood, E.rebuild_ore), _short(team, E.rebuild_wood, E.rebuild_ore)], Color(1.0, 0.8, 0.5))
				game.sfx.ui("ui_deny", -6.0)
			return false
		gate.broken = false
		gate.hp = mini(E.rebuild_hits, Stats.GATE_HITS)
		gate.shape.disabled = false
		gate._refresh()
		bought[team].rebuild += 1
		game.announce("The %s door has been raised again." % Stats.FACTIONS[team].name)
	elif job == "repair":
		if not _spend(team, E.repair_wood, E.repair_ore):
			if by and by.is_player:
				game.toast("Mending the door costs %s. %s." % [_cost_text(E.repair_wood, E.repair_ore), _short(team, E.repair_wood, E.repair_ore)], Color(1.0, 0.8, 0.5))
				game.sfx.ui("ui_deny", -6.0)
			return false
		gate.hp = mini(gate.hp + E.repair_hits, Stats.GATE_HITS)
		gate._refresh()
		bought[team].repair += 1
		if by:
			game.spawn_popup(gate.global_position + Vector3(0, 2.6, 0), "+%d DOOR" % E.repair_hits, Color(1, 0.9, 0.5))
	else:
		return false
	game.spawn_ring(gate.global_position - Vector3(0, gate.global_position.y, 0), 3.0, Color(1.0, 0.85, 0.3), 0.6)
	game.spawn_splash(gate.global_position + Vector3(0, 0.5, 0), Color(0.85, 0.65, 0.4), 30, 4.0, 0.7, true)
	game.sfx.play("door_rebuilt", gate.global_position, -1.0)
	if game.demo:
		print("ECON t=%d team%d door %s hp=%d" % [game.match_clock(), team, job, gate.hp])
	return true


func work_pad(team: int, pos: Vector3, by) -> bool:
	## A turret pad: build a base turret on it, patch a damaged one, or raise it a level.
	var E: Dictionary = Stats.ECONOMY
	var t = _turret_on(team, pos)
	var w := 0
	var o := 0
	var what := ""
	if t == null:
		if game.turrets.filter(func(x): return is_instance_valid(x) and x.team == team).size() >= Stats.TURRET.team_max:
			if by and by.is_player:
				game.toast("Your castle already has %d turrets" % Stats.TURRET.team_max, Color(1.0, 0.8, 0.5))
			return false
		if not game.turret_spot(team, pos, null).is_finite():
			if by and by.is_player:
				game.toast("Something is in the way of the turret pad", Color(1.0, 0.8, 0.5))
			return false
		w = E.turret_wood
		o = E.turret_ore
		what = "turret"
	elif t.hp < t.max_hp():
		w = E.turret_fix_wood
		o = E.turret_fix_ore
		what = "fix"
	elif t.level < Stats.TURRET.max_level:
		w = E.turret_up_wood
		o = E.turret_up_ore
		what = "raise"
	else:
		return false
	if not _spend(team, w, o):
		if by and by.is_player:
			var names := {"turret": "A base turret costs", "fix": "Patching the turret costs", "raise": "Raising the turret costs"}
			game.toast("%s %s. %s." % [names[what], _cost_text(w, o), _short(team, w, o)], Color(1.0, 0.8, 0.5))
			game.sfx.ui("ui_deny", -6.0)
		return false
	match what:
		"turret":
			var spot: Vector3 = game.turret_spot(team, pos, null)
			game.spawn_turret(team, spot, null, {"thorn": team == 0})
			bought[team].turret += 1
		"fix":
			t.hp = t.max_hp()
			t._refresh()
			game.spawn_ring(t.global_position, 1.3, Color(1.0, 0.85, 0.3), 0.5)
			game.sfx.play("turret_upgrade", t.global_position, -2.0)
			bought[team].tend += 1
		"raise":
			t.upgrade()
			bought[team].tend += 1
	if game.demo:
		print("ECON t=%d team%d pad %s" % [game.match_clock(), team, what])
	return true


# --- Gathering ---------------------------------------------------------------------

func start_work(u, n) -> void:
	var E: Dictionary = Stats.ECONOMY
	if carried(u) >= E.carry_max:
		if u.is_player:
			game.toast("You can't carry more: take it to the storehouse in your castle yard", Color(1.0, 0.8, 0.5))
			game.sfx.ui("ui_deny", -6.0)
		return
	if not n.available():
		if u.is_player:
			game.toast("%s grows back in %d s" % ["The tree" if n.kind == "wood" else "The ore", ceili(n.regrow_left)], Color(1.0, 0.8, 0.5))
		return
	work[u] = {"node": n, "t": 0.0, "from": u.global_position, "hearts": u.hearts, "atk": u.attack_timer, "swing": 0.0}


func _tick_work(delta: float) -> void:
	var E: Dictionary = Stats.ECONOMY
	for u in work.keys():
		var w: Dictionary = work[u]
		var n = w.node
		var moved: float = game._flat_dist(u.global_position, w.from) if is_instance_valid(u) else 99.0
		if not is_instance_valid(u) or u.dead or u.carrying or moved > 0.6 or u.hearts < w.hearts \
				or u.attack_timer > w.atk + 0.01 or not n.available() or carried(u) >= E.carry_max:
			n.set_progress(0.0)
			work.erase(u)
			continue
		w.atk = u.attack_timer
		w.t += delta
		w.swing -= delta
		var to: Vector3 = n.global_position - u.global_position
		to.y = 0.0
		if to.length() > 0.1:
			u.facing = to.normalized()
			u.rotation.y = atan2(-u.facing.x, -u.facing.z)
		if w.swing <= 0.0:
			w.swing = 0.65
			u.model.play_once("1H_Melee_Attack_Chop", 1.3)
			var hit: Vector3 = n.global_position + Vector3(0, 0.9 if n.kind == "wood" else 0.6, 0) - to.normalized() * 0.4
			if n.kind == "wood":
				game.spawn_splash(hit, Color(0.86, 0.68, 0.42), 6, 2.5, 0.4)
				game.sfx.play("door_hit", hit, -9.0, 0.2)
			else:
				game.spawn_splash(hit, Color(1.0, 0.8, 0.4), 6, 3.0, 0.3)
				game.sfx.play("hit_shield", hit, -10.0, 0.25)
			n.shake = 0.2
		n.set_progress(w.t / E.gather_time)
		if w.t >= E.gather_time:
			w.t = 0.0
			if n.take_one():
				var c: Dictionary = cargo.get(u, {"wood": 0, "ore": 0})
				c[n.kind] += 1
				cargo[u] = c
				gathered[u.team][n.kind] += 1
				_refresh_cargo(u)
				game.spawn_popup(u.global_position + Vector3(0, 2.3, 0), "+1 %s" % n.kind.to_upper(),
					Color(0.75, 0.95, 0.5) if n.kind == "wood" else Color(1.0, 0.8, 0.4))
				if u.is_player:
					game.sfx.ui("xp", -8.0, 1.2)
			if not n.available() or carried(u) >= E.carry_max:
				n.set_progress(0.0)
				work.erase(u)
				if u.is_player and carried(u) >= E.carry_max:
					game.toast("Full load: bring it to the storehouse in your castle yard", Color(0.9, 0.95, 0.7))


func _tick_cargo() -> void:
	var E: Dictionary = Stats.ECONOMY
	for u in cargo.keys():
		if not is_instance_valid(u):
			cargo.erase(u)
			continue
		var c: Dictionary = cargo[u]
		if c.wood + c.ore <= 0:
			continue
		if u.dead:
			_drop_load(u)
			continue
		var d: Vector3 = depots[u.team]
		if game._flat_dist(u.global_position, d) < E.depot_radius and absf(u.global_position.y - d.y) < 1.5:
			wood[u.team] += c.wood
			ore[u.team] += c.ore
			var parts := []
			if c.wood > 0:
				parts.append("+%d WOOD" % c.wood)
			if c.ore > 0:
				parts.append("+%d ORE" % c.ore)
			game.spawn_popup(u.global_position + Vector3(0, 2.4, 0), "  ".join(parts), Color(1.0, 0.92, 0.6))
			game.spawn_ring(d, E.depot_radius, Color(1.0, 0.85, 0.3), 0.5)
			game.sfx.play("station", d, -6.0)
			cargo[u] = {"wood": 0, "ore": 0}
			_refresh_cargo(u)
			_refresh_pile(u.team)
			if game.demo:
				print("ECON t=%d team%d deposit by %s pool %d wood %d ore" % [game.match_clock(), u.team, u.display_name, wood[u.team], ore[u.team]])


func _drop_load(u) -> void:
	## A fallen soldier's load spills on the ground: anyone can pick it up.
	var c: Dictionary = cargo[u]
	var bundle := Node3D.new()
	add_child(bundle)
	bundle.global_position = Vector3(u.global_position.x, maxf(u.global_position.y, -3.0), u.global_position.z)
	_fill_load(bundle, c.wood, c.ore, true)
	drops.append({"node": bundle, "wood": c.wood, "ore": c.ore, "life": Stats.ECONOMY.drop_life})
	cargo[u] = {"wood": 0, "ore": 0}
	_refresh_cargo(u)


func _tick_drops(delta: float) -> void:
	var E: Dictionary = Stats.ECONOMY
	for d in drops.duplicate():
		d.life -= delta
		var node: Node3D = d.node
		if d.life <= 0.0:
			node.queue_free()
			drops.erase(d)
			continue
		node.rotation.y += delta * 0.8
		for u in game.units:
			if u.dead or u.carrying:
				continue
			if game._flat_dist(u.global_position, node.global_position) > 1.3 or absf(u.global_position.y - node.global_position.y) > 1.2:
				continue
			var room: int = E.carry_max - carried(u)
			if room <= 0:
				continue
			var c: Dictionary = cargo.get(u, {"wood": 0, "ore": 0})
			var tw: int = mini(d.wood, room)
			c.wood += tw
			d.wood -= tw
			room -= tw
			var to: int = mini(d.ore, room)
			c.ore += to
			d.ore -= to
			cargo[u] = c
			_refresh_cargo(u)
			game.sfx.play("crown_grab", node.global_position, -12.0)
			if d.wood + d.ore <= 0:
				node.queue_free()
				drops.erase(d)
				break


# --- Bots --------------------------------------------------------------------------

func plan_gatherers(team: int, bots: Array) -> void:
	## Called by game._plan_bots after the squad planner: keep one bot (two
	## while the pool is empty) on wood and ore, never while the castle is
	## breached or in overtime.
	if game.overtime or game.enemy_inside_castle(team) or game.in_prep():
		gatherers[team] = []
		return
	var E: Dictionary = Stats.ECONOMY
	var want: int = E.bot_gatherers + (1 if wood[team] + ore[team] < 3 and _human_on(team) == false else 0)
	var keep := []
	for u in gatherers[team]:
		if is_instance_valid(u) and not u.dead and u in bots and u.bot_job == u.base_job and keep.size() < want:
			keep.append(u)
	if keep.size() < want:
		var free := bots.filter(func(b): return b.bot_job == b.base_job and b.base_job == "attack" and not b in keep \
			and b.role != Role.BASE)
		var d: Vector3 = depots[team]
		free.sort_custom(func(a, b): return game._flat_dist(a.global_position, d) < game._flat_dist(b.global_position, d))
		for b in free:
			if keep.size() >= want:
				break
			keep.append(b)
	gatherers[team] = keep
	for u in keep:
		u.bot_job = "gather"


func bot_goal(u, plan: Dictionary) -> Vector3:
	## Where a gathering bot goes: the storehouse with a full load (or when
	## nothing is left to work), else the best tree or deposit on its half.
	var E: Dictionary = Stats.ECONOMY
	var have := carried(u)
	if work.has(u):
		return u.global_position
	var best = null
	if have < E.carry_max:
		var side := -1.0 if u.team == 0 else 1.0
		var d: Vector3 = depots[u.team]
		var c: Dictionary = cargo_of(u)
		var need_ore: bool = ore[u.team] + c.ore < wood[u.team] + c.wood
		var best_score := INF
		for n in nodes:
			if not n.available() or n.position.x * side < 0.0:
				continue
			var score: float = game._flat_dist(u.global_position, n.position) + 0.6 * game._flat_dist(n.position, d)
			if (n.kind == "ore") != need_ore:
				score += 35.0   # keep wood and ore level: every purchase takes both
			if score < best_score:
				best_score = score
				best = n
	if best == null or (have > 0 and game._flat_dist(u.global_position, depots[u.team]) < 12.0 and have >= 2):
		if have == 0:
			return game.thrones[u.team]   # nothing to work right now: wait at home
		return depots[u.team]
	if best.in_reach(u):
		start_work(u, best)
		return u.global_position
	# Stand on the side of the node facing home, at arm's length.
	var home: Vector3 = depots[u.team] - best.position
	home.y = 0.0
	return best.position + home.normalized() * 1.5


func bot_wants_new_hat(u) -> bool:
	## A bot wearing a class whose machine was upgraded since it put the hat
	## on swaps hats when it is down in the cellar anyway.
	return not u.is_player and u.role != Role.BASE and u.role == u.bot_class and is_upgraded(u.team, u.role) \
		and not u.hat_upgraded and not u.carrying and game._in_cellar(u.team, u.global_position)


func bot_hat_pick(u, dist: float) -> bool:
	## Whether a bot fires its hat move (ability 2) on an enemy this far away.
	if u.abilities().size() < 3 or not u.ability_ready(2):
		return false
	var a: Dictionary = u.abilities()[2]
	match a.kind:
		"cleave", "curse":
			return dist < a.radius * 0.9 and u._roll(0.04)
		"shot", "smite":
			return dist <= a.range * 0.8 and u._roll(0.03)
		"volley":
			return dist <= a.range * 0.8 and u._roll(0.03)
		"bash":
			return dist < a.distance and u._roll(0.03)
		"bubble":
			return (u.hearts <= 2 or u._injured_allies_near(3.0).size() >= 2) and dist < 6.0 and u._roll(0.05)
		"trap":
			return dist < 6.0 and u._roll(0.03)
		"blink":
			return u.hearts <= 1 and dist < 4.0 and u._roll(0.05)
	return false


func _human_on(team: int) -> bool:
	for u in game.units:
		if u.team == team and u.is_player:
			return true
	return false


func _bot_spend(team: int) -> void:
	## An all-bot team's steward: door first, then hat machines in lineup
	## order, then turrets on empty pads, keeping a door repair in reserve.
	var E: Dictionary = Stats.ECONOMY
	var steward = null
	for u in game.units:
		if u.team == team and not u.dead:
			steward = u
			if u in gatherers[team]:
				break
	var job := _door_work(team)
	var gate = game.gates[team]
	if job == "rebuild" and not _door_pressed(team) and gate.rebuild_timer > 8.0 and fix_door(team, steward):
		return
	if job == "repair" and gate.hp <= Stats.GATE_HITS - E.repair_hits and fix_door(team, steward):
		return
	var reserve_w: int = E.bot_reserve_wood if not upgraded[team].is_empty() else 0
	var reserve_o: int = E.bot_reserve_ore if not upgraded[team].is_empty() else 0
	for entry in game.LINEUP:
		var role: int = entry[0]
		if not is_upgraded(team, role) and game.seals[team].has(role):
			if can_afford(team, E.hat_wood + reserve_w, E.hat_ore + reserve_o):
				upgrade_hat(team, role, steward)
			return   # save up for this one first
	for pad in pads[team]:
		var t = _turret_on(team, pad.pos)
		if t == null and can_afford(team, E.turret_wood + reserve_w, E.turret_ore + reserve_o):
			if work_pad(team, pad.pos, steward):
				return
		elif t != null and t.needs_work() and can_afford(team, E.turret_up_wood + reserve_w, E.turret_up_ore + reserve_o):
			if work_pad(team, pad.pos, steward):
				return


# --- Every frame -------------------------------------------------------------------

func print_summary() -> void:
	## The match's economy for balance tallies (game._demo_summary).
	for team in 2:
		print("ECONSUM team=%d wood_gathered=%d ore_gathered=%d hats=%d repairs=%d rebuilds=%d turrets=%d tends=%d pool=%d/%d" % [team,
			gathered[team].wood, gathered[team].ore, bought[team].hat, bought[team].repair, bought[team].rebuild,
			bought[team].turret, bought[team].tend, wood[team], ore[team]])


func _physics_process(delta: float) -> void:
	if game == null or not game.playing or game.game_over:
		return
	if "--econ-test" in OS.get_cmdline_user_args():
		_test_tick()
	_shot_tick()
	_tick_work(delta)
	_tick_cargo()
	_tick_drops(delta)
	spend_timer -= delta
	if spend_timer <= 0.0:
		spend_timer = 2.0
		for team in 2:
			if not _human_on(team) and not game.in_prep():
				_bot_spend(team)
			elif _human_on(team) and not hint_given[team] and can_afford(team, Stats.ECONOMY.hat_wood, Stats.ECONOMY.hat_ore) \
					and upgraded[team].size() < 5:
				hint_given[team] = true
				game.toast("Your team has %d wood and %d ore: upgrade a hat machine in the cellar (wear the hat, press %s)" % [
					wood[team], ore[team], game.key_label("interact")], Color(1.0, 0.9, 0.5))
	if game.demo and Engine.get_process_frames() % 1800 == 0:
		for team in 2:
			print("   econ team%d pool %d wood %d ore  gathered %s  bought %s  hats %s" % [team, wood[team], ore[team],
				gathered[team], bought[team], upgraded[team].keys()])


func _process(_delta: float) -> void:
	if game == null:
		return
	for u in game.units:
		_update_hat_glow(u)
	var p = game.player
	var live: bool = game.playing and p != null and is_instance_valid(p) and p.is_player and not p.dead
	for team in 2:
		for role in seal_labels[team]:
			var l: Label3D = seal_labels[team][role]
			var seal = game.seals[team][role]
			var text := ""
			if live and p.team == team and seal.in_reach(p) and not seal.locked:
				text = _seal_prompt(team, role, p)
			l.text = text
			l.visible = text != ""
		var dl: Label3D = door_labels[team]
		var dtext := ""
		if live and p.team == team and _by_door(p):
			dtext = _door_prompt(team)
		dl.text = dtext
		dl.visible = dtext != ""
		for pad in pads[team]:
			var pl: Label3D = pad.label
			var ptext := ""
			if live and p.team == team:
				var off: Vector3 = p.global_position - pad.pos
				if absf(off.y) < 1.2 and Vector2(off.x, off.z).length() < Stats.ECONOMY.pad_reach:
					ptext = _pad_prompt(team, pad.pos)
			pl.text = ptext
			pl.visible = ptext != ""
			pad.mark.visible = _turret_on(team, pad.pos) == null


# --- Prompts -----------------------------------------------------------------------

func _k() -> String:
	return game.key_label("interact")


func node_prompt(n, u) -> String:
	var E: Dictionary = Stats.ECONOMY
	var w = work.get(u, {})
	if not w.is_empty() and w.node == n:
		return "CHOPPING..." if n.kind == "wood" else "MINING..."
	if not n.available():
		return "%s IN %d s" % ["REGROWS" if n.kind == "wood" else "REFILLS", ceili(n.regrow_left)]
	if carried(u) >= E.carry_max:
		return "FULL LOAD · TAKE IT HOME"
	return "[%s]  %s  (%d left)" % [_k(), "CHOP WOOD" if n.kind == "wood" else "MINE ORE", n.stock]


func _seal_prompt(team: int, role: int, p) -> String:
	var E: Dictionary = Stats.ECONOMY
	var a: Dictionary = Stats.hat_upgrade(team, role)
	if is_upgraded(team, role):
		if p.role == role and not p.hat_upgraded:
			return "[%s]  TAKE THE UPGRADED HAT  (+ %s)" % [_k(), a.get("name", "")]
		if p.role == role:
			return ""
		return "UPGRADED  · + %s" % a.get("name", "")
	if p.role == role:
		return "[%s]  UPGRADE THE MACHINE  %s  (team: %d · %d)" % [_k(), _cost_text(E.hat_wood, E.hat_ore), wood[team], ore[team]]
	return "Upgrade: %s  · + %s" % [_cost_text(E.hat_wood, E.hat_ore), a.get("name", "")]


func _door_prompt(team: int) -> String:
	var E: Dictionary = Stats.ECONOMY
	match _door_work(team):
		"rebuild":
			if _door_pressed(team):
				return "UNDER SIEGE: THE DOOR CAN'T GO UP"
			return "[%s]  RAISE THE DOOR  %s" % [_k(), _cost_text(E.rebuild_wood, E.rebuild_ore)]
		"repair":
			return "[%s]  MEND THE DOOR +%d  %s" % [_k(), E.repair_hits, _cost_text(E.repair_wood, E.repair_ore)]
	return ""


func _pad_prompt(team: int, pos: Vector3) -> String:
	var E: Dictionary = Stats.ECONOMY
	var t = _turret_on(team, pos)
	if t == null:
		return "[%s]  BUILD A TURRET  %s" % [_k(), _cost_text(E.turret_wood, E.turret_ore)]
	if t.hp < t.max_hp():
		return "[%s]  PATCH THE TURRET  %s" % [_k(), _cost_text(E.turret_fix_wood, E.turret_fix_ore)]
	if t.level < Stats.TURRET.max_level:
		return "[%s]  RAISE TO LEVEL %d  %s" % [_k(), t.level + 1, _cost_text(E.turret_up_wood, E.turret_up_ore)]
	return ""


func _prompt_label(pos: Vector3, size: int = 30) -> Label3D:
	var l := Label3D.new()
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font_size = size
	l.pixel_size = 0.0105
	l.outline_size = 9
	l.modulate = Color(1.0, 0.92, 0.65)
	l.visible = false
	add_child(l)
	l.global_position = pos
	return l


# --- Looks -------------------------------------------------------------------------

func _mat(color: Color, rough: float = 0.8, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	return m


func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func _cyl(top: float, bottom: float, height: float, sides: int = 8) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = height
	c.radial_segments = sides
	c.rings = 1
	return c


func _log_mats() -> Array:
	return [game._pbr("bark", 0.5, Color(0.95, 0.88, 0.8)), _mat(Color(0.86, 0.68, 0.42), 0.9)]


func _ore_mat() -> StandardMaterial3D:
	var m := _mat(Color(1.0, 0.7, 0.3), 0.3, 0.75)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.65, 0.25)
	m.emission_energy_multiplier = 0.35
	return m


func _fill_load(parent: Node3D, w: int, o: int, on_ground: bool) -> void:
	## Logs and ore chunks: on a soldier's back (a bundle across the
	## shoulders) or spilled on the ground.
	for c in parent.get_children():
		c.queue_free()
	var lm := _log_mats()
	for k in w:
		var y := 0.12 + (k % 2) * 0.2 + (k / 2) * 0.2
		var z := 0.0 if on_ground else -0.02 * k
		var log := _mesh(parent, _cyl(0.1, 0.1, 0.75, 7), Vector3(0, y if on_ground else k * 0.19, z + (k % 2) * 0.05), lm[0], Vector3(0, 0, PI / 2.0))
		_mesh(log, _cyl(0.092, 0.092, 0.77, 7), Vector3.ZERO, lm[1])
	var om := _ore_mat()
	for k in o:
		var at := Vector3(-0.25 + k * 0.25, 0.12, 0.35) if on_ground else Vector3(-0.18 + k * 0.18, w * 0.19 + 0.12, 0.02)
		var chunk := _mesh(parent, _cyl(0.03, 0.11, 0.22, 5), at, om, Vector3(0.3, k * 1.3, 0.2))
		chunk.set_meta("ore", true)
	if on_ground:
		# A small glow so a spilled load is easy to spot.
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.55
		tm.outer_radius = 0.65
		ring.mesh = tm
		var rm := StandardMaterial3D.new()
		rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		rm.albedo_color = Color(1.0, 0.85, 0.4, 0.7)
		rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ring.material_override = rm
		ring.position.y = 0.05
		parent.add_child(ring)


func _refresh_cargo(u) -> void:
	var c: Dictionary = cargo.get(u, {"wood": 0, "ore": 0})
	var holder: Node3D = u.get_node_or_null("EconomyLoad")
	if holder == null:
		holder = Node3D.new()
		holder.name = "EconomyLoad"
		# On the back, across the shoulders (the model faces -z).
		holder.position = Vector3(0, 1.0, 0.36)
		u.add_child(holder)
	_fill_load(holder, c.wood, c.ore, false)
	holder.visible = c.wood + c.ore > 0


func _update_hat_glow(u) -> void:
	## A gold glint over anyone wearing an upgraded hat.
	var glow: Node3D = u.get_node_or_null("HatGlow")
	var want: bool = u.hat_upgraded and not u.dead
	if glow == null:
		if not want:
			return
		var cp := CPUParticles3D.new()
		cp.name = "HatGlow"
		cp.amount = 8
		cp.lifetime = 1.0
		cp.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		cp.emission_sphere_radius = 0.3
		cp.direction = Vector3.UP
		cp.spread = 25.0
		cp.initial_velocity_min = 0.3
		cp.initial_velocity_max = 0.7
		cp.gravity = Vector3.ZERO
		cp.scale_amount_min = 0.04
		cp.scale_amount_max = 0.08
		var sm := SphereMesh.new()
		sm.radius = 0.5
		sm.height = 1.0
		sm.radial_segments = 6
		sm.rings = 3
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(1.0, 0.85, 0.35)
		sm.material = m
		cp.mesh = sm
		cp.position.y = 2.05
		u.add_child(cp)
		glow = cp
	glow.visible = want
	(glow as CPUParticles3D).emitting = want


func _build_depot(team: int) -> void:
	## The storehouse: a timber lean-to in the castle yard beside the
	## gatehouse, a woodpile on one side and an ore cart on the other. The
	## heaps grow with the team pool. Nothing in it is solid (the yard's bot
	## lanes stay clear).
	var side := -1.0 if team == 0 else 1.0
	var fx: float = game._front_x(team)
	var pos := Vector3(fx + side * 3.4, 0, -7.4)
	depots[team] = pos
	var root := Node3D.new()
	add_child(root)
	root.position = pos
	var lm := _log_mats()
	var timber: StandardMaterial3D = game._timber(Color(0.85, 0.75, 0.6))
	var roof: StandardMaterial3D = _mat(Stats.FACTIONS[team].color.darkened(0.25), 0.85)
	# The lean-to: four posts and a sloped roof against the side wall's way.
	for px in [-1.1, 1.1]:
		for pz in [-0.9, 0.7]:
			_mesh(root, _cyl(0.08, 0.09, 1.9 if pz < 0.0 else 1.5, 6), Vector3(px, 0.95 if pz < 0.0 else 0.75, pz), timber)
	var roof_mesh := BoxMesh.new()
	roof_mesh.size = Vector3(2.7, 0.08, 2.1)
	_mesh(root, roof_mesh, Vector3(0, 1.75, -0.1), roof, Vector3(-0.22, 0, 0))
	var beam := BoxMesh.new()
	beam.size = Vector3(2.6, 0.12, 0.12)
	_mesh(root, beam, Vector3(0, 1.9, -0.9), timber)
	# A floor of planks.
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(2.5, 0.06, 1.9)
	_mesh(root, floor_mesh, Vector3(0, 0.03, -0.1), timber)
	# Heaps that grow: logs under the roof, ore in a cart beside it.
	var piles := Node3D.new()
	root.add_child(piles)
	var wood_heap := Node3D.new()
	wood_heap.position = Vector3(-0.5, 0.06, -0.35)
	piles.add_child(wood_heap)
	for k in 10:
		var row: int = k / 4
		var col: int = k % 4
		var log := _mesh(wood_heap, _cyl(0.11, 0.11, 1.0, 7), Vector3(0, 0.11 + row * 0.2, -0.33 + col * 0.22 + row * 0.11), lm[0], Vector3(0, 0, PI / 2.0))
		_mesh(log, _cyl(0.1, 0.1, 1.02, 7), Vector3.ZERO, lm[1])
		log.visible = false
	var cart := Node3D.new()
	cart.position = Vector3(0.75, 0, 0.0)
	piles.add_child(cart)
	var bed := BoxMesh.new()
	bed.size = Vector3(0.75, 0.32, 1.0)
	_mesh(cart, bed, Vector3(0, 0.42, 0), timber)
	for wz in [-0.32, 0.32]:
		for wx in [-0.42, 0.42]:
			_mesh(cart, _cyl(0.2, 0.2, 0.06, 10), Vector3(wx, 0.2, wz), _mat(Color(0.3, 0.22, 0.15)), Vector3(0, 0, PI / 2.0))
	var ore_heap := Node3D.new()
	ore_heap.position = Vector3(0, 0.6, 0)
	cart.add_child(ore_heap)
	var om := _ore_mat()
	for k in 10:
		var c := _mesh(ore_heap, _cyl(0.03, 0.1, 0.22, 5), Vector3(-0.22 + (k % 3) * 0.22, (k / 5) * 0.12, -0.36 + (k % 5) * 0.18), om, Vector3(0.4, k * 1.7, 0.3))
		c.visible = false
	depot_piles[team] = [wood_heap, ore_heap]
	# The drop zone: a soft gold ring on the flags.
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = Stats.ECONOMY.depot_radius - 0.12
	tm.outer_radius = Stats.ECONOMY.depot_radius
	tm.rings = 48
	ring.mesh = tm
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.albedo_color = Color(1.0, 0.85, 0.4, 0.55)
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = rm
	ring.position = Vector3(0, 0.04, 0)
	root.add_child(ring)
	# A sign.
	var sign := Label3D.new()
	sign.text = "STOREHOUSE"
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.font_size = 26
	sign.pixel_size = 0.01
	sign.outline_size = 8
	sign.modulate = Color(1.0, 0.92, 0.7)
	sign.position = Vector3(0, 2.5, 0)
	root.add_child(sign)
	_refresh_pile(team)


func _refresh_pile(team: int) -> void:
	var piles: Array = depot_piles[team] if depot_piles[team] else []
	if piles.is_empty():
		return
	var k := 0
	for c in piles[0].get_children():
		c.visible = k < wood[team]
		k += 1
	k = 0
	for c in piles[1].get_children():
		c.visible = k < ore[team]
		k += 1


func _build_pads(team: int) -> void:
	## A turret pad on each of the team's turret spots: a ring of stone with
	## a bronze bolt-mark, visible while no turret stands on it.
	for spot in game.turret_spots(team):
		var mark := Node3D.new()
		add_child(mark)
		mark.position = spot + Vector3(0, 0.03, 0)
		var disc := MeshInstance3D.new()
		disc.mesh = _cyl(0.75, 0.8, 0.06, 16)
		disc.material_override = game._ashlar(Color(0.8, 0.78, 0.72))
		mark.add_child(disc)
		var inner := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.45
		tm.outer_radius = 0.56
		inner.mesh = tm
		inner.position.y = 0.04
		inner.material_override = _mat(Color(0.75, 0.55, 0.25), 0.4, 0.7)
		mark.add_child(inner)
		var label := _prompt_label(spot + Vector3(0, 2.4, 0), 28)
		pads[team].append({"pos": spot, "label": label, "mark": mark})


func _build_door_label(team: int) -> void:
	var side := -1.0 if team == 0 else 1.0
	var gate = game.gates[team]
	door_labels[team] = _prompt_label(Vector3(gate.global_position.x + side * 1.6, 2.2, 0), 30)


func _build_seal_label(team: int, role: int) -> void:
	var seal = game.seals[team][role]
	seal_labels[team][role] = _prompt_label(seal.global_position + Vector3(0, 3.25, 0), 26)


func _mark_seal(team: int, role: int) -> void:
	## An upgraded hat machine: a gold band round the pedestal, a gold star
	## turning over the hat and a warmer light.
	var seal = game.seals[team][role]
	if seal_marks[team].has(role):
		return
	var mark := Node3D.new()
	seal.add_child(mark)
	seal_marks[team][role] = mark
	var gold := _mat(Color(1.0, 0.82, 0.3), 0.3, 0.8)
	gold.emission_enabled = true
	gold.emission = Color(1.0, 0.75, 0.25)
	gold.emission_energy_multiplier = 0.4
	var band := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.46
	tm.outer_radius = 0.56
	band.mesh = tm
	band.position.y = 0.55
	band.material_override = gold
	mark.add_child(band)
	var crown := Node3D.new()
	crown.name = "Star"
	crown.position.y = 2.3
	mark.add_child(crown)
	for k in 5:
		var a := TAU * k / 5.0
		var spike := MeshInstance3D.new()
		spike.mesh = _cyl(0.0, 0.05, 0.16, 4)
		spike.material_override = gold
		spike.position = Vector3(cos(a) * 0.17, 0.05, sin(a) * 0.17)
		crown.add_child(spike)
	var circlet := MeshInstance3D.new()
	var ct := TorusMesh.new()
	ct.inner_radius = 0.14
	ct.outer_radius = 0.19
	circlet.mesh = ct
	circlet.material_override = gold
	crown.add_child(circlet)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.8, 0.4)
	light.light_energy = 0.8
	light.omni_range = 3.0
	light.position.y = 1.8
	mark.add_child(light)
	var tw := create_tween().set_loops()
	tw.tween_property(crown, "rotation:y", TAU, 3.0).from(0.0)


# --- HUD (called from hud.gd while it draws) ---------------------------------------

func draw_counter(hud, me) -> void:
	## The team's wood and ore under the minimap, and what you carry.
	if me == null:
		return
	var team: int = me.team
	var narrow: bool = hud._narrow()
	var at := Vector2(30, 182) if narrow else Vector2(44, 238)
	var rect := Rect2(at, Vector2(160, 30))
	hud._plate(rect, Color(0.07, 0.05, 0.03, 0.88), Color(0.62, 0.46, 0.2), 8, 2)
	# Wood: a log end. Ore: a gold nugget.
	var lc := rect.position + Vector2(18, 15)
	hud.draw_circle(lc, 9.0, Color(0.45, 0.3, 0.16))
	hud.draw_circle(lc, 6.5, Color(0.86, 0.68, 0.42))
	hud.draw_arc(lc, 3.5, 0, TAU, 12, Color(0.6, 0.42, 0.22), 1.2)
	hud._text(rect.position + Vector2(32, 21), str(wood[team]), 16, Color(1.0, 0.95, 0.85), HORIZONTAL_ALIGNMENT_LEFT, -1, 3)
	var oc := rect.position + Vector2(92, 15)
	var nug := PackedVector2Array([oc + Vector2(-8, 3), oc + Vector2(-4, -7), oc + Vector2(5, -8), oc + Vector2(9, 1), oc + Vector2(3, 8), oc + Vector2(-5, 7)])
	hud.draw_colored_polygon(nug, Color(0.95, 0.68, 0.25))
	hud.draw_polyline(nug + PackedVector2Array([nug[0]]), Color(0.45, 0.28, 0.08), 1.5)
	hud.draw_line(oc + Vector2(-3, -3), oc + Vector2(3, -5), Color(1.0, 0.95, 0.7), 2.0)
	hud._text(rect.position + Vector2(106, 21), str(ore[team]), 16, Color(1.0, 0.95, 0.85), HORIZONTAL_ALIGNMENT_LEFT, -1, 3)
	var c: Dictionary = cargo_of(me)
	if c.wood + c.ore > 0 and not me.dead:
		var bits := []
		if c.wood > 0:
			bits.append("%d wood" % c.wood)
		if c.ore > 0:
			bits.append("%d ore" % c.ore)
		hud._text(rect.position + Vector2(4, 46), "CARRYING %s  (%d / %d)" % [" + ".join(bits).to_upper(), c.wood + c.ore, Stats.ECONOMY.carry_max],
			11, Color(1.0, 0.88, 0.55), HORIZONTAL_ALIGNMENT_LEFT, -1, 3)


func draw_hat_slot(hud, p, strip: Rect2) -> void:
	## The upgraded hat's extra move, in its own slot left of the ability board.
	if p == null or p.dead or p.abilities().size() < 3:
		return
	var a: Dictionary = p.abilities()[2]
	var slot := 48.0
	var at := Vector2(strip.position.x - slot - 18.0, strip.position.y + 22.0)
	var cost_c: Color = hud.STAMINA if p.energy_kind() == "stamina" else hud.MANA
	hud._slot(at, slot, a.get("icon", a.kind), Color(0.9, 0.7, 0.2), hud._k("ability_3"), a.name,
		p.ability_timers[2], a.cooldown, p.energy >= a.cost and p.carrying == null, 0, false, a.cost, cost_c, false)


# --- Self-test (--play -- --econ-test) -----------------------------------------------
# Drives the player through every economy action and prints PASS / FAIL lines:
# godot --headless --path . --fixed-fps 60 -- --play --no-prep --econ-test

var test_step := 0
var test_wait := 0
var test_fails := 0
var test_node = null


func _check(ok: bool, what: String) -> void:
	print("ECONTEST %s: %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		test_fails += 1


func _put(u, pos: Vector3) -> void:
	u.global_position = pos
	u.velocity = Vector3.ZERO


func _test_tick() -> void:
	var p = game.player
	if p == null or not game.playing:
		return
	if test_wait > 0:
		test_wait -= 1
		return
	var team: int = p.team
	var side := -1.0 if team == 0 else 1.0
	match test_step:
		0:
			p.spawn_protect = 0.0
			for n in nodes:
				if n.kind == "wood" and n.position.x * side > 0.0:
					test_node = n
					break
			test_node.stock = test_node.max_stock()
			test_node._refresh()
			_put(p, test_node.global_position + Vector3(1.4, 0.1, 0))
			test_wait = 10
		1:
			game.try_interact(p)
			_check(work.has(p), "F at a lumber tree starts chopping")
			test_wait = int(60 * Stats.ECONOMY.gather_time * 3.5)
		2:
			_check(carried(p) == Stats.ECONOMY.carry_max, "chopping fills the carry limit (%d / %d)" % [carried(p), Stats.ECONOMY.carry_max])
			_check(p.get_node_or_null("EconomyLoad") != null and p.get_node("EconomyLoad").visible, "the load shows on the soldier's back")
			_put(p, depots[team] + Vector3(0, 0.1, 0))
			test_wait = 20
		3:
			_check(carried(p) == 0 and wood[team] >= Stats.ECONOMY.carry_max, "the storehouse takes the load (pool %d wood)" % wood[team])
			wood[team] = 20
			ore[team] = 20
			p.set_role(Role.KNIGHT)
			_check(not p.hat_upgraded and p.abilities().size() == 2, "a plain Knight hat has two moves")
			var seal = game.seals[team][Role.KNIGHT]
			_put(p, seal.global_position + Vector3(0, 0.2, 1.2))
			test_wait = 10
		4:
			game.try_interact(p)
			_check(is_upgraded(team, Role.KNIGHT) and wood[team] == 15 and ore[team] == 15, "F at the hat machine upgrades it for 5 wood and 5 ore")
			_check(p.hat_upgraded and p.abilities().size() == 3, "the upgraded hat adds a third move (%s)" % (p.abilities()[2].name if p.abilities().size() > 2 else "none"))
			p.energy = p.energy_max()
			p.use_ability(2, Vector3(side * -1.0, 0, 0))
			_check(p.ability_timers[2] > 0.0, "the hat move fires on G")
			var other = null
			for u in game.units:
				if u.team == team and not u.is_player:
					other = u
					break
			other.set_role(Role.KNIGHT)
			_check(other.hat_upgraded, "a teammate's Knight hat is upgraded too")
			other.set_role(Role.BASE)
			var gate = game.gates[team]
			gate.hp = 120
			_put(p, gate.global_position * Vector3(1, 0, 1) + Vector3(side * 1.5, 0.1, 0.5))
			test_wait = 10
		5:
			game.try_interact(p)
			var gate = game.gates[team]
			_check(gate.hp == 120 + Stats.ECONOMY.repair_hits and wood[team] == 13 and ore[team] == 14, "F by the door mends it (+%d, hp %d)" % [Stats.ECONOMY.repair_hits, gate.hp])
			gate.take_hit(gate.hp)
			_check(gate.broken, "door broken for the rebuild test")
			test_wait = 5
		6:
			game.try_interact(p)
			var gate = game.gates[team]
			_check(not gate.broken and gate.hp == Stats.ECONOMY.rebuild_hits, "F by a broken door raises it (hp %d)" % gate.hp)
			var pad: Dictionary = pads[team][2]
			_put(p, pad.pos + Vector3(0, 0.1, 0.6 * side))
			test_wait = 10
		7:
			var pad: Dictionary = pads[team][2]
			var before: int = wood[team]
			game.try_interact(p)
			var t = _turret_on(team, pad.pos)
			_check(t != null and wood[team] == before - Stats.ECONOMY.turret_wood, "F on a turret pad builds a base turret")
			if t:
				t.hp = 1
				game.try_interact(p)
				_check(t.hp == t.max_hp(), "F on a damaged turret patches it")
				game.try_interact(p)
				_check(t.level == 2, "F on a whole turret raises it a level")
			var c := {"wood": 2, "ore": 1}
			cargo[p] = c
			_refresh_cargo(p)
			_put(p, Vector3(side * 30.0, 0.1, 14.0))
			test_wait = 10
		8:
			p.set_role(Role.BASE)   # no Knight plate to turn the blow
			p.spawn_protect = 0.0
			p.home_defense = false
			p.take_damage(p.hearts + 2)
			test_wait = 5
		9:
			_check(p.dead and carried(p) == 0 and drops.size() == 1, "a fallen soldier drops the load")
			if drops.is_empty():
				print("ECONTEST DONE: %d failed" % test_fails)
				get_tree().quit()
				return
			var picker = null
			for u in game.units:
				if u.team != team and not u.dead:
					picker = u
					break
			cargo.erase(picker)
			work.erase(picker)
			picker.bot_job = "idle"
			_put(picker, drops[0].node.global_position + Vector3(0.2, 0.2, 0))
			test_wait = 3
		10:
			_check(drops.is_empty(), "anyone can pick a dropped load up")
			print("ECONTEST DONE: %d failed" % test_fails)
			get_tree().quit()
			return
	test_step += 1


# --- Render staging (--play -- --econ-shot=gather|depot|hat|repair --shot=... --shot-frame=N) ---

func _shot_tick() -> void:
	var scene := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--econ-shot="):
			scene = arg.trim_prefix("--econ-shot=")
	if scene == "" or game.player == null:
		return
	var p = game.player
	var team: int = p.team
	var side := -1.0 if team == 0 else 1.0
	var left: int = game.shot_frame - Engine.get_process_frames()
	match scene:
		"gather":
			if left == 150:
				var best = null
				for n in nodes:
					if n.kind == "wood" and n.position.x * side > 0.0 and (best == null or n.position.distance_to(Vector3(side * 29, 0, 12)) < best.position.distance_to(Vector3(side * 29, 0, 12))):
						best = n
				p.set_role(Role.KNIGHT)
				p.spawn_protect = 0.0
				_put(p, best.global_position + Vector3(-1.35, 0.1, 0.55))
				game.cam_pos = p.global_position + game.CAMERA_OFFSET * game.cam_zoom
				cargo[p] = {"wood": 1, "ore": 1}
				_refresh_cargo(p)
				wood[team] = 4
				ore[team] = 3
				_refresh_pile(team)
			if left == 140:
				for n in nodes:
					if n.in_reach(p):
						start_work(p, n)
						break
		"depot":
			if left == 200:
				wood[team] = 6
				ore[team] = 4
				_refresh_pile(team)
				p.set_role(Role.RANGER)
				p.spawn_protect = 0.0
				cargo[p] = {"wood": 2, "ore": 1}
				_refresh_cargo(p)
				_put(p, depots[team] + Vector3(-side * 4.5, 0.1, 1.5))
				game.cam_lock = depots[team] + Vector3(-side * 2.0, 0, 2.5)
			if left == 25:
				_put(p, depots[team] + Vector3(-side * 1.6, 0.1, 1.0))
		"hat":
			if left == 200:
				wood[team] = 12
				ore[team] = 9
				p.set_role(Role.KNIGHT)
				var seal = game.seals[team][Role.KNIGHT]
				_put(p, seal.global_position + Vector3(0.4, 0.1, 1.5))
				game.cam_pos = p.global_position + game.CAMERA_OFFSET * game.cam_zoom
				upgrade_hat(team, Role.RANGER, p)
			if left == 45:
				game.try_interact(p)
		"repair":
			if left == 200:
				wood[team] = 9
				ore[team] = 7
				p.set_role(Role.ENGINEER)
				game.gates[team].hp = 92
				game.gates[team]._refresh()
				_put(p, game.gates[team].global_position * Vector3(1, 0, 1) + Vector3(side * 2.2, 0.1, 1.2))
				game.cam_pos = p.global_position + Vector3(-side * 1.5, 0, 0) + game.CAMERA_OFFSET * game.cam_zoom
				work_pad(team, pads[team][2].pos, p)
			if left == 30:
				game.try_interact(p)
