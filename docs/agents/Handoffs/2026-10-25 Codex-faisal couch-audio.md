# Couch positional sound repair
Agent: Codex-faisal

In a two-player versus match the local players spawn 171m apart. Player 2 effects were discarded by the 48 m distance gate around player 1. A second defect silenced all split-screen positional effects: the root camera was disabled and every pane viewport disabled its audio listener. Native SFX-bus capture confirmed this even after the first voice-allocation fix, so PR70 returned to draft for correction.

The shared speaker mix now translates each event relative to the nearest active local pane and routes it through one active pane viewport. Its listener follows the primary listener's full transform; original viewport audio flags are restored on transitions and teardown. Each event still uses one voice with distance attenuation and direction; effects far from every seat remain silent. Solo playback, network event positions, mute and shared duplicate throttling are preserved. No art, music, UI or game rules changed.

## Verification
- Godot 4.3 clean headless import: exit 0, no script errors.
- Focused four-seat and listener-lifecycle regression:30 checks pass with no diagnostics. Earlier baseline fixture against main87df448 reproduces three secondary-seat failures; its log predates added lifecycle tests.
- Exact exported before/after combat self-tests:41 passes each, failures0, no engine diagnostics (combat-pack-results.json). The editor-based final combat run also passed41 but emitted eight resources still in use at shutdown; its raw log is retained rather than called clean.
- Complete final seed7 bot match: exit0, Humans2-0 at simulated330s, RESULT retained, no script errors.
- Final Windows pack hashes in signal-audio-builds.json. Native two-seat SFX-bus captures at171.0168m separation: baseline both seats0, fixed both seats0.501703 peak. Far/muted0; solo0.501703 both; return-to-couch fixed0.501703 versus baseline0. UI control0.410389 both. All assertion gates pass. Existing anchor warnings retained; no Skeleton3D diagnostics in these debug-template runs.
- Final fixture pack_audio_signal_control.gd starts through the real menu, captures the mixer, and asserts baseline/fixed expectations. This verifies digital mixer output, not physical-speaker listening. Earlier voice-only captures/build hashes are explicitly superseded in comparison.md.

## Remaining
Rendered before/after screenshots completed; see docs/evidence/wave5-couch-audio/comparison.md. Physical speaker/controller listening remains pending. Independent Codex-faisal/crowns_bugtest review found no blocking issue; longer effects retain emission-time remapping as a limitation. No mobile performance or store-readiness claim. The independent #68 official optimized-template defect remains open and is not fixed by this sound change.

Source implementation is scripts/sfx.gd; focused regression tools/couch_audio_test.gd. No shared source reset or other agent claim changed. Paid spend 0.
