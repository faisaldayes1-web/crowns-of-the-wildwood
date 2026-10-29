# Camera-relative controls and deliberate mouse movement

Agent: Codex-faisal. Owner request in Workflow Hub, October 29, 2026; explicit clarification: forward is screen-up and right is screen-right independently of character facing. Source branch `Codex-faisal/crowns-pc-camera-movement`, base `4055075edcdf35f2902276ef538bd7ce2f3dfe99`.

## Behavior

- Default PC left click sets a ground destination or approaches an explicitly selected guide, class seal, resource or enemy crown. Ground clicks never become generic F, so they cannot drop a carried crown or plant a prep barricade. Existing F remains available.
- Move/interact is separate from basic attack by default. Optional Combine enables selected-enemy approach/attack. Shift holds position and attacks with primary click; J remains the basic attack key. Block keeps K/right mouse and controller bindings.
- Force Move uses both wheel directions or the first thumb button by default, suppressing attack/interact and buffered attack while moving. The second thumb button can be rebound. Wheel zoom can be enabled separately.
- Optional WASD and gamepad/touch movement project through each seat's camera; analog magnitude is retained. Right-stick aim uses the same projection. No gameplay speed changes.
- Menu/focus/death cancels pending goals. UI taps and presses originating outside the first player's pane cannot turn into world moves. Existing saves migrate conflicting LMB/Shift mappings while retaining progress and other remaps; sanitized bindings and schema are saved together.
- Online pointer requests retain a small allowlisted target identity, are bound to the authenticated sender's assigned unit, reject stale/rate-limited sequences, and revalidate target state/reach. Existing `_input_state` signature and raw F input remain intact.

## Completed evidence

Root audit evidence is in `hub-status-audit-20261027/reviews/` beside the central queue:

- `Crowns-movement-pure-tests/actual-result.json`: installed Godot 4.3, 61 passed / 0 failed, exit 0, stderr empty. Camera yaw/cardinals, analog magnitude, persistent goals, cancellation, force modes and vertical separation.
- `Crowns-movement-native-adapters/actual-parser-result.json`: actual game, unit, net and HUD scripts each pass Godot parser checks, exit 0, stderr empty; exact staged hashes retained.
- `Crowns-movement-native-adapters/actual-adapter-result.json`: actual save transaction and second load, remapping, progression preservation and exact selected-object dispatch; 27 passed / 0 failed, exit 0, raw errors absent. Fixture uses Game without its world-building `_ready`, so this is not a full game run.
- Independent source reviews found and drove fixes for generic-F dispatch, UI tap leakage, through-floor arrival, save migration and ore's collision/reach mismatch. Ore now uses the existing gathering reach, with an interior margin.

## Remaining qualification

Actual ore-collider approach, real network peers, rendered controls/ordinary player journey and controller hardware feel are separate from the checks above. Do not call this a completed visual pass or final build yet. Do not replay unchanged original 969 checks as new evidence.

The pre-existing main renderer/material failure is independently tracked under original PR 69. Two bounded real Forward+/Vulkan character-lifetime probes completed without native errors; they do not reproduce or fix the full-match failure at 105 seconds. No character art/material/shader/cache/backend modification is included here, and no performance improvement is claimed.

Claude 1 received exact scope and confirmed Root owns the subsequent reference art/environment/UI-art pass; Claude 3 owns bug testing/loading/readability, with one main PR integrated at a time. Notify both with the actual movement merge SHA before their rebase. Use the owner's picked Crowns reference, not an unapproved generated target. Root's scheduled checks remain paused.
