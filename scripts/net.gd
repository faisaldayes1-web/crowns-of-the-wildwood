extends Node
## Online play over ENet (direct IP), host-authoritative. An autoload
## ("Net"), so the connection survives the scene reloads between matches.
##
## The host runs the whole game as offline play does; a joiner's unit is
## driven by the inputs that joiner sends (net_input), and 20 times a second
## the host sends every client a snapshot of the units and the match state.
## Clients simulate nothing: their units are puppets that follow the
## snapshots. See docs/online-plan.md.

const DEFAULT_PORT := 24560
const MAX_CLIENTS := 8
const SNAPSHOT_EVERY := 3      # physics frames between snapshots (60 / 3 = 20 Hz)

enum Mode { OFFLINE, HOST, CLIENT }

var mode := Mode.OFFLINE
var world_seed := 0            # every instance builds the world from this, so trees and props match
var map_variant := -1          # the host's map, sent to joiners (-1: not set)
var port := DEFAULT_PORT
var host_ip := "127.0.0.1"
var status := ""               # one line for the title screen
var ready_peers: Array = []    # host: joiners whose world is built and who wait for a slot
var assigned := {}             # host: peer id -> unit index this match
var pending_start := {}        # client: {team, slot, map} from the host, kept until the game is ready
var snapshot := {}             # client: the latest snapshot from the host
var snapshot_count := 0        # client: snapshots received (smoke test)
var welcomed := false          # client: the host's welcome came in (the scene reloads once on it)
var input_counts := {"interact": 0, "ability_1": 0, "ability_2": 0, "dodge": 0}
var game                       # the running game.gd, registered by its _ready
var cli_done := false          # --host / --join from the command line were handled (once per run)
var peer_names := {}           # host: peer id -> the hero name that joiner chose


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	world_seed = randi()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


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
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	mode = Mode.OFFLINE
	ready_peers = []
	assigned = {}
	pending_start = {}
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
	_relax_timeout(id)
	status = "Hosting on port %d · %d joined" % [port, peer_count()]
	_welcome.rpc_id(id, world_seed, game.map_variant if game else 0)


func _on_peer_disconnected(id: int) -> void:
	if not is_host():
		return
	print("NET peer %d left" % id)
	ready_peers.erase(id)
	if assigned.has(id) and game:
		game.net_release_unit(assigned[id])
	assigned.erase(id)
	status = "Hosting on port %d · %d joined" % [port, peer_count()]


func _relax_timeout(id: int) -> void:
	## Starting a match builds a lot in one frame (seconds on a slow machine
	## or a tablet); ENet's default 5 s timeout would drop the link meanwhile.
	var mp = multiplayer.multiplayer_peer
	if mp is ENetMultiplayerPeer:
		var p: ENetPacketPeer = mp.get_peer(id)
		if p:
			p.set_timeout(64, 20000, 60000)


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
	get_tree().reload_current_scene()


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
func _client_ready(hero_name: String) -> void:
	var id := multiplayer.get_remote_sender_id()
	peer_names[id] = hero_name.strip_edges().left(16)
	if not ready_peers.has(id):
		ready_peers.append(id)
	print("NET peer %d ready" % id)
	if game and game.playing:
		_seat(id)   # joined mid-match: take a bot's place now


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _input_state(move: Vector2, aim: Vector3, attack: bool, block: bool, counts: Dictionary) -> void:
	var id := multiplayer.get_remote_sender_id()
	if not is_host() or not game or not assigned.has(id):
		return
	var u = game.units[assigned[id]]
	u.net_input = {"move": move.limit_length(1.0), "aim": aim, "attack": attack, "block": block, "counts": counts}


func client_ready() -> void:
	## The client's game has built the host's world.
	if is_client() and welcomed:
		_client_ready.rpc_id(1, game.hero_name if game else "")


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
		return
	assigned[id] = idx
	game.net_claim_unit(idx, id, peer_names.get(id, ""))
	var names: Array = game.units.map(func(u): return u.display_name)
	_match_start.rpc_id(id, idx / game.TEAM_SIZE, idx % game.TEAM_SIZE, game.map_variant, names)


func _physics_process(_delta: float) -> void:
	if not game or not game.playing and not game.game_over:
		return
	if is_host() and not assigned.is_empty() and Engine.get_physics_frames() % SNAPSHOT_EVERY == 0:
		var data: Dictionary = game.net_build_snapshot()
		for id in assigned:
			_snapshot.rpc_id(id, data)
	elif is_client() and game.player and game.playing:
		_send_input()


func _send_input() -> void:
	var p = game.player
	var move := Vector2.ZERO
	var attack := false
	var block := false
	if not game.menu_blocks_input(p):
		move = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		attack = Input.is_action_pressed("attack")
		block = Input.is_action_pressed("block")
		for k in input_counts:
			if Input.is_action_just_pressed(k):
				input_counts[k] += 1
	_input_state.rpc_id(1, move, p.aim, attack, block, input_counts.duplicate())
