extends SceneTree
## Codex-faisal: run the real game's --net-test with read-only event diagnostics.
## Use tools/tests/isolated.sh; host and each joiner need separate user dirs.

var queued := 0
var peak_queue := 0
var next_report := 0
var stalled := false
var chat_sent_at := -1
var chat_received := false
const Isolated = preload("res://tools/tests/isolated.gd")

func _initialize() -> void:
	call_deferred("_start")

func _start() -> void:
	if not Isolated.ok("tools/net_event_probe.gd"):
		quit(2)
		return
	physics_frame.connect(_observe)
	change_scene_to_file(str(ProjectSettings.get_setting("application/run/main_scene")))

func _observe() -> void:
	var net = root.get_node_or_null("Net")
	if net == null:
		return
	if net.is_client() and is_instance_valid(net.game):
		if net.game.net_test_log.get("chat", false) and chat_sent_at < 0:
			chat_sent_at = Time.get_ticks_msec()
		if chat_sent_at >= 0 and not chat_received and net.game.chat_log.any(func(c): return "hello from the joiner" in str(c.text)):
			chat_received = true
			var latency := Time.get_ticks_msec() - chat_sent_at
			print("EVENT_PROBE chat echo latency_ms=%d" % latency)
			for arg in OS.get_cmdline_user_args():
				if arg.begins_with("--event-latency-limit-ms=") and latency > int(arg.trim_prefix("--event-latency-limit-ms=")):
					print("EVENT_PROBE FAIL chat latency exceeds requested limit")
					net.game.net_test_log.ok = false
	if not stalled and net.is_client() and is_instance_valid(net.game) and net.game.net_test_log.get("t", 0.0) > 10.0:
		stalled = true
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--event-stall-ms="):
				var delay := clampi(int(arg.trim_prefix("--event-stall-ms=")), 0, 30000)
				print("EVENT_PROBE pausing joiner for %d ms after movement checks" % delay)
				OS.delay_msec(delay)
	queued += net._out.size()
	peak_queue = maxi(peak_queue, net._out.size())
	var now := Time.get_ticks_msec()
	if now < next_report:
		return
	next_report = now + 5000
	print("EVENT_PROBE t=%d mode=%d depth=%d mute=%d queued=%d peak=%d received=%d snapshots=%d early=%d peers=%s" % [
		now, net.mode, net.depth, net.mute, queued, peak_queue, net.events_in,
		net.snapshot_count, net._early.size(), net.multiplayer.get_peers()])
	if net.get("_loading_events") != null:
		print("EVENT_PROBE loading backlogs=%s ready=%s" % [net._loading_events.values().map(func(a): return a.size()), net._event_ready.keys()])
	var peer = net.multiplayer.multiplayer_peer
	if peer is ENetMultiplayerPeer:
		for id in net.multiplayer.get_peers():
			var link: ENetPacketPeer = peer.get_peer(id)
			print("EVENT_PROBE peer=%d rtt_ms=%.1f loss=%.4f" % [id,
				link.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME),
				link.get_statistic(ENetPacketPeer.PEER_PACKET_LOSS) / ENetPacketPeer.PACKET_LOSS_SCALE])
