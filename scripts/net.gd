extends Node
## Online play, host-authoritative. An autoload ("Net"), so the connection
## survives the scene reloads between matches. Two transports carry the same
## RPCs: rooms through the WebSocket relay (server/relay.js; works in the
## browser and on the desktop, joined with a 4-letter code) and ENet direct IP
## (desktop and LAN; the smoke test uses both).
##
## The host runs the whole game as offline play does; a joiner's unit is
## driven by the inputs that joiner sends (net_input), and 20 times a second
## the host sends every client a snapshot of the units and the match state.
## Clients simulate nothing: their units are puppets that follow the
## snapshots. See docs/online-plan.md.

const DEFAULT_PORT := 24560
const MAX_CLIENTS := 8
const SNAPSHOT_EVERY := 3      # physics frames between snapshots (60 / 3 = 20 Hz)
const RelayPeer = preload("res://scripts/relay_peer.gd")
# Where the room relay runs. Set online/relay_url in project.godot once it is
# hosted (a browser page served over https needs a wss:// address); --relay=URL
# overrides it for tests.
const DEFAULT_RELAY := "ws://127.0.0.1:8787"

enum Mode { OFFLINE, HOST, CLIENT }

var mode := Mode.OFFLINE
var world_seed := 0            # every instance builds the world from this, so trees and props match
var map_variant := -1          # the host's map, sent to joiners (-1: not set)
var port := DEFAULT_PORT
var host_ip := "127.0.0.1"
var status := ""               # one line for the title screen
var long_links := {}           # peer id -> true while that link waits up to 3 min (_relax_timeout)
var long_since := {}           # peer id -> Time.get_ticks_msec() when that link went long
var _long_gen := {}            # peer id -> bumped each time that link goes long (cancels a pending _normal_soon)
var _soon := {}                # peer id -> the _long_gen a pending _normal_soon waits on
var ready_peers: Array = []    # host: joiners whose world is built and who wait for a slot
var assigned := {}             # host: peer id -> unit index this match
var pending_start := {}        # client: {team, slot, map} from the host, kept until the game is ready
var snapshot := {}             # client: the latest snapshot from the host
var snapshot_count := 0        # client: snapshots received (smoke test)
var welcomed := false          # client: the host's welcome came in (the scene reloads once on it)
const HELD_ACTIONS := ["attack", "block", "interact"]
var input_counts := {"attack": 0, "interact": 0, "ability_1": 0, "ability_2": 0, "ability_3": 0, "dodge": 0}
var game                       # the running game.gd, registered by its _ready
var cli_done := false          # --host / --join from the command line were handled (once per run)
var peer_names := {}           # host: peer id -> the hero name that joiner chose
var peer_looks := {}           # host: peer id -> that joiner's hero colours and hair
var relay_url := DEFAULT_RELAY
var room_code := ""            # the room this game is in (relay rooms only)
var relay: RelayPeer           # while a room is being created or joined
# Host: effects, sounds, animations and messages recorded this frame for the
# joiners (rec), sent reliably at the end of the physics frame.
var depth := 0                 # >0 inside an effect that is already recorded
var mute := 0                  # >0 while building something the joiners build themselves
var _out: Array = []           # [peer id or 0 for everyone, target, method, args]
var events_in := 0             # client: events replayed (smoke test)
var events_by := {}            # client: replayed events by kind (smoke test)
const REPLAY := {
	"fx": ["burst", "flare", "ground_ring", "ground_glow", "rune", "scorch", "beam", "slash", "hit", "blast",
		"heal_on", "cast", "death", "petals", "swirl", "afterimage", "trail_ghosts", "thorns", "dome", "rays"],
	"skill": ["animate", "cast", "land"],
	"model": ["play_once", "attack", "hold", "release", "go_down", "stand_up"],
	"sfx": ["play"],
	"game": ["spawn_popup", "spawn_pillar", "spawn_flash", "shake_at", "announce", "toast", "chat_add",
		"net_shot", "net_spawn", "net_flash", "net_kill_banner", "net_look", "crown_event_note", "on_player_killed"],
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	world_seed = randi()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	relay_url = str(ProjectSettings.get_setting("online/relay_url", DEFAULT_RELAY))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--relay="):
			relay_url = arg.trim_prefix("--relay=")


func _process(_delta: float) -> void:
	# A room being set up: poll the relay link ourselves until the relay
	# answers, then hand it to the multiplayer API.
	if relay and not attached_relay():
		relay.poll()
		if relay.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			multiplayer.multiplayer_peer = relay
			relay.attached = true
			room_code = relay.code
			if is_host():
				status = "Room %s · waiting for players" % room_code
				print("NET room %s created" % room_code)
				for arg in OS.get_cmdline_user_args():
					if arg.begins_with("--room-file="):   # tests: hand the code to the joiner
						var f := FileAccess.open(arg.trim_prefix("--room-file="), FileAccess.WRITE)
						if f:
							f.store_string(room_code)
			else:
				status = "Joined room %s · loading the host's world" % room_code
				print("NET joined room %s" % room_code)
		elif relay.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
			if not status.begins_with("Online:"):
				status = "Could not reach the online server"
			print("NET relay failed: ", status)
			relay = null
			mode = Mode.OFFLINE


func attached_relay() -> bool:
	return relay != null and relay.attached


func create_room(url: String = "") -> void:
	## Host a game in a new relay room; the code shows on the title screen.
	_open_relay(url, "create", Mode.HOST)


func join_room(code: String, url: String = "") -> void:
	_open_relay(url, code.strip_edges().to_upper(), Mode.CLIENT)


func _open_relay(url: String, want: String, as_mode: Mode) -> void:
	leave()
	relay = RelayPeer.new()
	relay.relay_error.connect(func(msg): status = "Online: " + msg)
	var target := url if url != "" else relay_url
	if relay.open(target, want) != OK:
		status = "Could not reach the online server"
		relay = null
		return
	mode = as_mode
	welcomed = false
	host_ip = "room " + want
	status = "Creating a room ..." if want == "create" else "Joining room %s ..." % want
	print("NET relay %s: %s" % [target, want])


func online() -> bool:
	return mode != Mode.OFFLINE


func is_host() -> bool:
	return mode == Mode.HOST


func is_client() -> bool:
	return mode == Mode.CLIENT


func host(p_port: int = DEFAULT_PORT) -> bool:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(p_port, MAX_CLIENTS)
	if err != OK:
		status = "Could not host on port %d (error %d)" % [p_port, err]
		print("NET host failed: ", err)
		return false
	multiplayer.multiplayer_peer = peer
	mode = Mode.HOST
	port = p_port
	status = "Hosting on port %d · waiting for players" % port
	print("NET hosting on port %d" % port)
	return true


func join(ip: String, p_port: int = DEFAULT_PORT) -> bool:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, p_port)
	if err != OK:
		status = "Could not reach %s (error %d)" % [ip, err]
		return false
	multiplayer.multiplayer_peer = peer
	mode = Mode.CLIENT
	host_ip = ip
	port = p_port
	welcomed = false
	status = "Joining %s:%d ..." % [ip, p_port]
	print("NET joining %s:%d" % [ip, p_port])
	return true


func leave() -> void:
	if multiplayer.multiplayer_peer and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		multiplayer.multiplayer_peer.close()
	if relay and not relay.attached:
		relay.close()
	relay = null
	room_code = ""
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	mode = Mode.OFFLINE
	ready_peers = []
	long_links = {}
	long_since = {}
	_soon = {}
	assigned = {}
	pending_start = {}
	_early = []
	snapshot = {}
	welcomed = false
	map_variant = -1
	status = ""


func peer_count() -> int:
	return multiplayer.get_peers().size() if online() else 0


# --- Connection events --------------------------------------------------------

func _on_peer_connected(id: int) -> void:
	if not is_host():
		return
	print("NET peer %d connected" % id)
	_relax_timeout(id, true)   # it builds our world now
	status = _host_line()
	_welcome.rpc_id(id, world_seed, game.map_variant if game else 0)


func _on_peer_disconnected(id: int) -> void:
	if not is_host():
		return
	print("NET peer %d left" % id)
	ready_peers.erase(id)
	long_links.erase(id)
	long_since.erase(id)
	_soon.erase(id)
	if assigned.has(id) and game:
		game.net_release_unit(assigned[id])
	assigned.erase(id)
	status = _host_line()


func _host_line() -> String:
	var where := ("Room %s" % room_code) if room_code != "" else ("Hosting on port %d" % port)
	return "%s · %d joined" % [where, peer_count()]


func _relax_timeout(id: int, loading: bool = false) -> void:
	## Starting a match builds a lot in one frame (seconds on a slow machine
	## or a tablet); ENet's default 5 s timeout would drop the link meanwhile.
	## While a joiner builds the host's world (after a welcome) neither side
	## answers for that long: building the Wildwood took 8 s on a quiet
	## RTX 5080 laptop and 85 s on a busy one, and the 20 s floor dropped
	## the joiner mid-load (claude-faisallaptop 2026-10-17). So the link
	## waits up to 3 minutes until the joiner reports its world built.
	## A long-waiting link goes back to the usual timeout when the other end
	## shows it is running frames again: the host on the first input it gets
	## from that joiner, the joiner on the first input it sends (both only
	## once a match is playing). (A fixed 15 s timer after the match start
	## put a joiner still building its world back on 20 s: review of #45.)
	if loading:
		if not long_links.has(id):
			long_since[id] = Time.get_ticks_msec()
		long_links[id] = true
		_long_gen[id] = int(_long_gen.get(id, 0)) + 1
	else:
		long_links.erase(id)
		long_since.erase(id)
	var mp = multiplayer.multiplayer_peer
	if mp is ENetMultiplayerPeer:
		var p: ENetPacketPeer = mp.get_peer(id)
		if p:
			if loading:
				p.set_timeout(64, 180000, 180000)
			else:
				p.set_timeout(64, 20000, 60000)


const SETTLE_S := 30.0       # a link stays patient this long after it comes back,
const SETTLE_MAX_S := 300.0  # plus as long as it waited, up to this in all


func _normal_soon(id: int) -> void:
	## Back to the usual timeout later, not at once. While one end stalled
	## (a slow world build or match start; tested with --debug-slow-build),
	## the other kept resending its reliable packets, doubling the wait
	## between tries each time. So after the stall a packet can still come
	## due up to about as long as the stall lasted, and ENet then counts its
	## age from its last try, made during the stall: on the 20 s timeout by
	## then, the link drops. (A fixed 30 s settle dropped a mid-match joiner
	## 30 s after its 100 s stall.) So the link stays patient for SETTLE_S
	## plus the time it waited. If the link goes long again meanwhile (a
	## match start right after the world build), this one is cancelled and
	## the next call starts over (claude-faisallaptop 2026-10-18).
	var gen: int = int(_long_gen.get(id, 0))
	if int(_soon.get(id, -1)) == gen:
		return   # already on its way back
	_soon[id] = gen
	var waited := (Time.get_ticks_msec() - int(long_since.get(id, Time.get_ticks_msec()))) / 1000.0
	await get_tree().create_timer(minf(SETTLE_S + waited, SETTLE_MAX_S)).timeout
	if int(_soon.get(id, -1)) != gen:
		return   # cancelled (the link left) or replaced
	_soon.erase(id)
	if online() and long_links.has(id) and int(_long_gen.get(id, 0)) == gen:
		_relax_timeout(id)


func long_timeouts() -> void:
	## A match starts (the batching, units and effects all build in one go):
	## the links that will play it wait up to 3 minutes, each until input
	## flows on it again. On the host that is the joiners being seated (ready
	## ones); a joiner still building our world already waits, and one left
	## without a seat stays on the usual timeout.
	if not online():
		return
	if is_client():
		_relax_timeout(1, true)
		return
	for id in multiplayer.get_peers():
		if id in ready_peers:
			_relax_timeout(id, true)


func _on_connected() -> void:
	_relax_timeout(1)
	status = "Connected to %s · loading the host's world" % host_ip
	print("NET connected to host")


func _on_connection_failed() -> void:
	print("NET connection failed")
	leave()
	status = "Could not connect to %s" % host_ip


func _on_server_disconnected() -> void:
	print("NET host closed the game")
	leave()
	status = "The host left the game"
	if game:
		get_tree().paused = false
		get_tree().reload_current_scene()


# --- Host -> client -----------------------------------------------------------

@rpc("authority", "call_remote", "reliable")
func _welcome(seed_value: int, map: int) -> void:
	## The host's world seed: rebuild the scene with it so trees, props and
	## colliders match the host's.
	world_seed = seed_value
	map_variant = map
	welcomed = true
	status = "Connected to %s · waiting for the host to start" % host_ip
	print("NET welcomed: seed %d map %d" % [seed_value, map])
	_relax_timeout(1, true)   # the rebuild below can take long
	get_tree().reload_current_scene()


func rewelcome() -> void:
	## The host's scene reloaded (back from a match, or a map with other
	## ground): send every joiner the world again so theirs matches.
	for id in multiplayer.get_peers():
		_relax_timeout(id, true)   # each rebuilds our world now
		_welcome.rpc_id(id, world_seed, game.map_variant if game else 0)


@rpc("authority", "call_remote", "reliable")
func _match_start(team: int, slot: int, map: int, names: Array) -> void:
	print("NET slot: team %d slot %d" % [team, slot])
	pending_start = {"team": team, "slot": slot, "map": map, "names": names}
	if game and game.net_ready:
		game.net_start_client(pending_start)


@rpc("authority", "call_remote", "unreliable_ordered")
func _snapshot(data: Dictionary) -> void:
	snapshot = data
	snapshot_count += 1
	if game and game.playing:
		game.net_apply_snapshot(data)


# --- Client -> host -----------------------------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func _client_ready(hero_name: String, look: Dictionary) -> void:
	var id := multiplayer.get_remote_sender_id()
	peer_names[id] = hero_name.strip_edges().left(16)
	peer_looks[id] = look
	if not ready_peers.has(id):
		ready_peers.append(id)
	# Built: back to the usual timeout, unless it is seated straight into a
	# running match and now builds that (review of #57: the host dropped a
	# mid-match joiner 60 s into a slow match start).
	if game != null and game.playing:
		_relax_timeout(id, true)   # it builds the match next
	else:
		_normal_soon(id)
	print("NET peer %d ready" % id)
	if game and game.playing:
		_seat(id)   # joined mid-match: take a bot's place now


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _input_state(move: Vector2, aim: Vector3, held: Array, counts: Dictionary) -> void:
	var id := multiplayer.get_remote_sender_id()
	if long_links.has(id):
		_normal_soon(id)   # the joiner is playing: its link is live again
	if not is_host() or not game or not assigned.has(id):
		return
	var u = game.units[assigned[id]]
	u.net_input = {"move": move.limit_length(1.0), "aim": aim, "held": held, "counts": counts}


func send_chat(text: String, team_only: bool) -> void:
	_chat.rpc_id(1, text.left(90), team_only)


@rpc("any_peer", "call_remote", "reliable")
func _chat(text: String, team_only: bool) -> void:
	var id := multiplayer.get_remote_sender_id()
	if not is_host() or not game or not assigned.has(id):
		return
	var u = game.units[assigned[id]]
	game.chat_add(u.display_name, text.strip_edges().left(90), game._team_color(u.team), team_only, u.role, u.team)


func client_ready() -> void:
	## The client's game has built the host's world.
	if is_client() and welcomed:
		_normal_soon(1)
		_client_ready.rpc_id(1, game.hero_name if game else "", game.hero_custom() if game else {})


# --- Host -> client: events ----------------------------------------------------

func rec(target: String, method: String, args: Array, to_unit = null, to_team: int = -1) -> void:
	## Host: queue one effect / sound / animation / message for the joiners.
	## `to_unit` makes it personal: only that unit's player sees it (nobody
	## online when it is the host's own unit or a bot).
	if mode != Mode.HOST or assigned.is_empty() or depth > 0 or mute > 0 or not game:
		return
	var to := 0
	if to_unit != null:
		if not is_instance_valid(to_unit) or to_unit.get("remote_peer") == null or to_unit.remote_peer <= 0:
			return
		to = to_unit.remote_peer
	var enc: Array = []
	for a in args:
		var e = _enc(a)
		if e is Dictionary and e.has("?"):
			return   # refers to something the joiners cannot find: skip the effect
		enc.append(e)
	if target == "model" and not (enc[0] is Dictionary and enc[0].has("m")):
		return
	_out.append([to, target, method, enc, to_team])


func _enc(v):
	if v is Object:
		if not is_instance_valid(v):
			return {"?": 1}
		var i: int = game.units.find(v)
		if i >= 0:
			return {"u": i}
		i = game.monarchs.find(v)
		if i >= 0:
			return {"k": i}
		# A unit's character model, or a node on a unit.
		var n: Node = v if v is Node else null
		while n:
			i = game.units.find(n)
			if i >= 0:
				return {"m": i} if v != n else {"u": i}
			n = n.get_parent()
		return {"?": 1}
	if v is Callable or v is Signal or v is RID:
		return null
	if v is Dictionary:
		var d := {}
		for k in v:
			var e = _enc(v[k])
			if not (e is Dictionary and e.has("?")):
				d[k] = e
		return d
	if v is Array:
		var a: Array = []
		for x in v:
			a.append(_enc(x))
		return a
	return v


func _dec(v):
	if v is Dictionary:
		if v.size() == 1:
			if v.has("u"):
				return game.units[v.u] if v.u < game.units.size() else null
			if v.has("m"):
				return game.units[v.m].model if v.m < game.units.size() else null
			if v.has("k"):
				return game.monarchs[v.k] if v.k < game.monarchs.size() else null
		var d := {}
		for k in v:
			d[k] = _dec(v[k])
		return d
	if v is Array:
		return v.map(func(x): return _dec(x))
	return v


func _flush_events() -> void:
	if _out.is_empty():
		return
	for id in assigned:
		var batch: Array = []
		var team: int = game.units[assigned[id]].team
		for e in _out:
			if (e[0] == 0 or e[0] == id) and (e[4] < 0 or e[4] == team):
				batch.append([e[1], e[2], e[3]])
		# In slices: a slow frame (a tablet building the match) can gather
		# hundreds of events, and one packet must stay small for the relay.
		for i in range(0, batch.size(), EVENT_SLICE):
			_events.rpc_id(id, batch.slice(i, i + EVENT_SLICE))
	_out = []


var _early: Array = []         # client: events that came before our match began
const EVENT_SLICE := 96        # events per packet


func replay_early() -> void:
	var held := _early
	_early = []
	for b in held:
		_events(b)


@rpc("authority", "call_remote", "reliable")
func _events(batch: Array) -> void:
	if not game or not game.playing and not game.game_over:
		if _early.size() < 200:
			_early.append(batch)   # e.g. the turrets already standing when we join mid-match
		return
	for e in batch:
		var target: String = e[0]
		var method: String = e[1]
		if not REPLAY.has(target) or not method in REPLAY[target]:
			continue
		var args: Array = _dec(e[2])
		if args.has(null) and target != "game":
			continue
		events_in += 1
		var key := (target + "." + method) if target == "game" else target
		events_by[key] = events_by.get(key, 0) + 1
		match target:
			"fx": game.Fx.of(game).callv(method, args)
			"skill": game.SkillFx.callv(method, args)
			"sfx": game.sfx.callv(method, args)
			"game": game.callv(method, args)
			"model":
				var m = args.pop_front()
				if m:
					m.callv(method, args)


# --- Host: seats and snapshots ------------------------------------------------

func on_match_started() -> void:
	## Host: the match began; seat everyone who is waiting.
	assigned = {}
	for id in ready_peers:
		_seat(id)


func _seat(id: int) -> void:
	var idx: int = game.net_free_slot()
	if idx < 0:
		print("NET no free slot for peer %d" % id)
		_normal_soon(id)   # nothing to build: the usual timeout
		return
	assigned[id] = idx
	game.net_claim_unit(idx, id, peer_names.get(id, ""), peer_looks.get(id, {}))
	var names: Array = game.units.map(func(u): return u.display_name)
	_match_start.rpc_id(id, idx / game.team_size, idx % game.team_size, game.map_variant, names)
	# Everything already in the match: looks (sent again to everyone) and
	# the turrets, traps and blessings standing now (joiners skip repeats).
	for u in game.units:
		u.net_look_sent = []
	for e in game.net_entity_list():
		rec("game", "net_spawn", e)


func _physics_process(_delta: float) -> void:
	if not game or not game.playing and not game.game_over:
		return
	if is_host() and not assigned.is_empty() and Engine.get_physics_frames() % SNAPSHOT_EVERY == 0:
		var data: Dictionary = game.net_build_snapshot()
		for id in assigned:
			_snapshot.rpc_id(id, data)
	if is_host():
		_flush_events()
	elif is_client() and game.player and game.playing:
		_send_input()


func _send_input() -> void:
	var p = game.player
	var move := Vector2.ZERO
	var held: Array = []
	if not game.menu_blocks_input(p):
		move = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if p and p.has_method("aim_relative"):
			move = p.aim_relative(move)   # W toward the cursor (unit.gd), as offline
		for k in HELD_ACTIONS:
			if Input.is_action_pressed(k):
				held.append(k)
		for k in input_counts:
			if Input.is_action_just_pressed(k):
				input_counts[k] += 1
	_input_state.rpc_id(1, move, p.aim, held, input_counts.duplicate())
	if long_links.has(1):
		_normal_soon(1)   # we are playing: the host link is live again
