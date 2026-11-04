extends SceneTree
## claude-faisal3: the six override clips load, differ from the synthesized
## originals, are mono 16-bit and sit within 3 dB of the original's loudness.
##     godot --headless --path . --script tools/sfx_override_test.gd
const NAMES := ["swing_heavy", "hit_heavy", "hit_shield", "hurt", "death", "crown_grab"]


func _rms(s: AudioStreamWAV) -> float:
	var d := s.data
	var acc := 0.0
	var n := 0
	for i in range(0, d.size() - 1, 2):
		var v := float(d.decode_s16(i)) / 32768.0
		if absf(v) > 0.01:
			acc += v * v
			n += 1
	return sqrt(acc / maxf(n, 1.0))


func _init() -> void:
	var sound = load("res://scripts/sfx.gd").new()
	root.add_child(sound)
	await process_frame
	var fails := 0
	for n in NAMES:
		var orig: AudioStreamWAV = load("res://assets/sfx/%s.wav" % n)
		var got = sound.streams.get(n)
		var ok: bool = got is AudioStreamWAV and got != orig and not got.stereo and got.format == AudioStreamWAV.FORMAT_16_BITS
		var d_db := 20.0 * log(_rms(got) / _rms(orig)) / log(10.0) if got is AudioStreamWAV else 99.0
		ok = ok and absf(d_db) < 3.0 and orig != null
		print("SFXTEST %s %s override_len=%.2fs orig_len=%.2fs rms_delta=%.1f dB" % ["PASS" if ok else "FAIL", n, got.get_length(), orig.get_length(), d_db])
		if not ok:
			fails += 1
	print("SFXTEST %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(fails)
