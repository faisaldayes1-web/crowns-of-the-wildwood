extends MultiplayerPeerExtension
## A MultiplayerPeer that talks to server/relay.js over one WebSocket, so
## online play works in a browser (the iPad web build) as well as on the
## desktop, through a short room code instead of an IP address. Godot's RPCs
## run on it exactly as on ENet: the room's creator is peer 1 (the host),
## joiners get the ids the relay hands out. Every packet is reliable and in
## order (it is TCP underneath).

signal room_created(code: String)
signal room_joined(code: String)
signal relay_error(msg: String)

var ws := WebSocketPeer.new()
var url := ""
var want := ""               # "create", or the room code to join
var code := ""
var my_id := 0
var status := CONNECTION_DISCONNECTED
var target := 0
var _mode := TRANSFER_MODE_RELIABLE
var _channel := 0
var refusing := false
var inbox: Array = []        # [sender id, PackedByteArray]
var current_peer := 0
var peers: Array = []
var _opened := false
var attached := false        # set once Net hands this peer to the multiplayer API
var _pending: Array = []     # peer joins seen before then


func open(p_url: String, p_want: String) -> Error:
	## p_want: "create" for a new room, else the room code to join.
	url = p_url
	want = p_want
	ws.inbound_buffer_size = 1 << 20
	ws.outbound_buffer_size = 1 << 20
	ws.max_queued_packets = 4096
	var err := ws.connect_to_url(url)
	if err != OK:
		return err
	status = CONNECTION_CONNECTING
	return OK


func _poll() -> void:
	if attached and not _pending.is_empty():
		for id in _pending:
			peer_connected.emit(id)
		_pending = []
	ws.poll()
	var st := ws.get_ready_state()
	if st == WebSocketPeer.STATE_OPEN and not _opened:
		_opened = true
		if want == "create":
			ws.send_text(JSON.stringify({"op": "create"}))
		else:
			ws.send_text(JSON.stringify({"op": "join", "code": want}))
	while ws.get_available_packet_count() > 0:
		var pkt := ws.get_packet()
		if ws.was_string_packet():
			_on_control(pkt.get_string_from_utf8())
		elif pkt.size() >= 4 and status == CONNECTION_CONNECTED:
			inbox.append([pkt.decode_s32(0), pkt.slice(4)])
	if st == WebSocketPeer.STATE_CLOSED and status != CONNECTION_DISCONNECTED:
		_drop_all()


func _on_control(text: String) -> void:
	var msg = JSON.parse_string(text)
	if typeof(msg) != TYPE_DICTIONARY:
		return
	match str(msg.get("op", "")):
		"created":
			code = msg.code
			my_id = int(msg.id)
			status = CONNECTION_CONNECTED
			room_created.emit(code)
		"joined":
			code = msg.code
			my_id = int(msg.id)
			status = CONNECTION_CONNECTED
			room_joined.emit(code)
		"peer":
			var id := int(msg.id)
			if not peers.has(id):
				peers.append(id)
				if attached:
					peer_connected.emit(id)
				else:
					_pending.append(id)
		"left":
			var id := int(msg.id)
			if peers.has(id):
				peers.erase(id)
				peer_disconnected.emit(id)
		"closed":
			_drop_all()
		"error":
			relay_error.emit(str(msg.get("msg", "relay error")))
			if status != CONNECTION_CONNECTED:
				ws.close()
				status = CONNECTION_DISCONNECTED


func _drop_all() -> void:
	for id in peers.duplicate():
		peers.erase(id)
		peer_disconnected.emit(id)
	status = CONNECTION_DISCONNECTED
	if ws.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		ws.close()


# --- MultiplayerPeer -----------------------------------------------------------

func _get_available_packet_count() -> int:
	return inbox.size()


func _get_packet_script() -> PackedByteArray:
	if inbox.is_empty():
		return PackedByteArray()
	var p: Array = inbox.pop_front()
	current_peer = p[0]
	return p[1]


func _put_packet_script(buffer: PackedByteArray) -> Error:
	if status != CONNECTION_CONNECTED:
		return ERR_UNCONFIGURED
	var out := PackedByteArray()
	out.resize(4)
	out.encode_s32(0, target)
	out.append_array(buffer)
	return ws.put_packet(out)


func _get_packet_peer() -> int:
	return current_peer


func _get_packet_mode() -> TransferMode:
	return TRANSFER_MODE_RELIABLE


func _get_packet_channel() -> int:
	return 0


func _get_max_packet_size() -> int:
	return 1000000   # the relay takes up to 1 MB per packet


func _set_transfer_mode(mode: TransferMode) -> void:
	_mode = mode


func _get_transfer_mode() -> TransferMode:
	return _mode


func _set_transfer_channel(channel: int) -> void:
	_channel = channel


func _get_transfer_channel() -> int:
	return _channel


func _set_target_peer(peer: int) -> void:
	target = peer


func _get_unique_id() -> int:
	return my_id


func _is_server() -> bool:
	return my_id == 1


func _is_server_relay_supported() -> bool:
	return false


func _set_refuse_new_connections(enable: bool) -> void:
	refusing = enable


func _is_refusing_new_connections() -> bool:
	return refusing


func _get_connection_status() -> ConnectionStatus:
	return status


func _disconnect_peer(_peer: int, _force: bool) -> void:
	pass   # the relay has no kick yet


func _close() -> void:
	ws.close()
	_drop_all()
