# Crowns: dynamic battle layers over the recorded loops (claude-faisal/audio-upgrade2, 2026-11-04)

Agent: claude-faisal/audio-upgrade2 (helper of claude-faisal). Follow-up to #193.

## What changed
#193 kept the drum and tension stems silent whenever a recorded battle loop played, because the old stems are a different score. This brings the dynamic build back with two new ElevenLabs layers that sit over either recorded loop:
- `assets/music/el/layer_drums.ogg`: percussion only (taiko, frame drums, toms), no pitch, so it cannot clash with the loop's key.
- `assets/music/el/layer_tension.ogg`: an unpitched tremolo string/cello bed with a heartbeat pulse.
- `scripts/sfx.gd` `_pick_battle_loop()` puts them in sync slots 1 and 2 when a recorded loop plays; `_process()` fades the drums in while your door is under attack (or enemies are inside), and both while your crown is out, exactly as the original stems did. They sit 3 dB under the loop (`EL_LAYER_DB`). Without the layer files the old behaviour stays (silent over a recorded loop); without the recorded loop the three original stems play as before.

## Levels (measured from the committed files)
Ogg Vorbis q5, 44.1 kHz stereo, 30 s seamless loops (ElevenLabs loop mode). Target -18 dBFS RMS, peaks at or below -1 dBFS.

| clip | format | seconds | RMS dBFS | peak dBFS |
|---|---|---|---|---|
| layer_drums | ogg stereo | 30.00 | -18.0 | -2.4 |
| layer_tension | ogg stereo | 30.00 | -18.0 | -1.8 |

Clips over -1 dBFS peak: 0

## Tests
- Local Godot 4.3 import: no errors. A headless probe (not committed) built the sfx node, ran `_pick_battle_loop()` for maps 0, 1 and 4 and confirmed slot 1 = layer_drums.ogg, slot 2 = layer_tension.ogg, `_el_layers` true.
- Local selftest (`--demo --selftest`, as CI runs it): TESTS DONE failures=0, no script errors.
- ElevenLabs credits: 400 (2 layers x 2 takes, 30 s loop; drums take 2 and tension take 2 were chosen). Ledger: C:/ORY-Cache/audio/elevenlabs-1104/LEDGER.md.
