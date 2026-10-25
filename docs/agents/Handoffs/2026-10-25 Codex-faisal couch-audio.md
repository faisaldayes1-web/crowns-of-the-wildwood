# Couch positional sound repair
Agent: Codex-faisal

In a two-player versus match the local players spawn 171m apart. The sole audio listener follows player 1, so player 2 impact effects were discarded by the 48 m distance gate. The exported baseline starts zero arrow-hit voices at player 2; the corrected exported pack starts one.

The shared speaker mix now translates each event relative to the nearest active local pane. Each event still uses one voice with distance attenuation and direction; effects far from every seat remain silent. Solo playback, network event positions, mute and shared duplicate throttling are preserved. No assets, music, UI or game rules changed.

## Verification
- Godot 4.3 clean headless import: exit 0, no script errors.
- Focused four-seat regression:16 checks pass. Exact baseline sfx.gd from main 87df448 fails secondary seats2,3,4 (13 checks,3 failures; directional assertions only run when a voice exists).
- Combat self-test:41 passes, failures 0.
- Complete seed 7 bot match: exit 0, Humans 2-0 at simulated 244 s, RESULT retained.
- Before/after Windows packs exported successfully. Full hashes in audio-builds.json. Matching debug-template full-scene two-seat runs: same171.0168m separation, before0 impact voices, after1. Retained existing anchor warnings; no Skeleton3D diagnostics in these debug-template runs.
- Packaged capture fixture is retained in pack_audio_test.gd; it starts through the real menu and inspects actual voice allocation. This is not a physical-speaker listening test.

## Remaining
Rendered before/after screenshots completed; see docs/evidence/wave5-couch-audio/comparison.md. Physical speaker/controller listening remains pending. Independent Codex-faisal/crowns_bugtest review found no blocking issue; longer effects retain emission-time remapping as a limitation. No mobile performance or store-readiness claim. The independent #68 official optimized-template defect remains open and is not fixed by this sound change.

Source implementation is scripts/sfx.gd; focused regression tools/couch_audio_test.gd. No shared source reset or other agent claim changed. Paid spend 0.
