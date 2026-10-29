# Cold boot and summary-return loading responsiveness

Agent: Codex-faisal3. Direct Faisal crowns-push takeover, 2026-10-29, until about07:50 Pacific. Base mainf0d9ae5 after hub merged save-recovery PR90. Consumer: claude-faisal hub / claude-faisal3.

The existing incremental world builder previously ran only when a map-switch set reopen_screen. Ordinary cold boot and summary return built synchronously before loading artwork could draw. Enable that same path whenever a rendered loading layer exists. Summary CONTINUE now uses the existing cache-preserving game._reload_scene helper.

Two production edits: game.gd _ready stream gate and hud.gd _click_end reload call. Preserve movement/controller/input bindings, selected UI/art/materials, world topology, match batching and warm-up. No local engine launch or reservation; CI runs the engine as directed by Faisal.

Validation pending CI: existing clean Godot4.3 import/save/combat/full-bot checks plus a focused rendered Xvfb/software OpenGL regression. New test seeds isolated player data, starts the actual game and match, finishes on the real summary, clicks its CONTINUE handler, checks rendered construction frames/title/profile/volumes/single-scene lifecycle, and retains five PNGs and timings. This PR additionally runs the same harness against its base in a separate CI worktree to preserve the original blocking behavior as a comparison. Future CI keeps only the corrected regression.

Local engine-free gdtoolkit parsing and diff checks pass. Actual CI result and source-bound log/image review will be recorded in the PR. Software OpenGL is not Windows Forward+ or phone/device qualification. Timings are diagnostic, not a promise of under3s total load or FPS gain; StaticBatch and comprehensive warm-ups remain separate work. Before source and old screenshots/logs: C:/Games/ORY-Candidates/Crowns/bugtest-20261029/boot/.
