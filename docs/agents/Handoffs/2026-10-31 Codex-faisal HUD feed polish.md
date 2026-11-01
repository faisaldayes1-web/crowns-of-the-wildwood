# HUD feed polish

Agent: Codex-faisal. Branch: `Codex-faisal/crowns-hud-feed-polish`, base `3585cc8`.

Busy chat could grow upward across the minimap, stock count and full-cargo warning. `_chat_rect()` now reserves their space in desktop, compact and corner-score layouts. The roster lower bound and shared couch chat placement remain intact. Cargo changes do not move the panel. The chat history, input and kill feed are preserved.

## Validation

- Official Godot 4.3 headless import passed with no script/import errors using a short isolated profile. Initial import crashed with signal 11; retained log, no proven cause. Retry also selected Compatibility; no project renderer setting changed.
- `tools/hud_chat_space_test.gd`: zero failures across desktop, compact, corner-score, taller aspect, touch and shared couch/roster layouts.
- `tools/hud_chat_capture.gd`: parser check passed; stages busy chat and full cargo in the actual game for matched captures.
- Full seed-7 bot match passed, exit 0: Elves 2-1 at t=582, overtime=false; no script/parse/compile errors.
- Before/after rendered evidence: pending hub renderer slot. Requests sent through ORY notify (`1793501322-651953`, `1793501526-2ede0e`). No windowed engine started.

Local raw logs: `C:/Games/ORY-Candidates/Crowns/hud-feed-polish/`. Visual inspection: [look.md](../../evidence/codex-faisal-hud-feed/look.md).

## November 1 continuation

Agent: Codex-faisal · T-2fc4d3bca959. Direct Faisal numbered list, item 1.

- Kept the busy-chat reservation, moved the kill feed below the full scoreboard strip, and removed only the BLOCKED popup. Shield sparks, recoil, sound, stamina cost and knockback remain unchanged.
- Fresh layout test: zero failures. Combat self-test: `TESTS DONE failures=0`. Full seed-7 bot match: exit 0, Humans 2–0 at t=330, no script errors. Results are retained as `*-final.log` in the evidence directory.
- Matched native Forward+ captures at 1280x720 use the same staged full-cargo, twelve-chat-message and five-kill state. Baseline HUD is main `3585cc8`; candidate source was restored and hash-checked after the pair. Both capture processes exited 0. Viewed all final candidate images and baseline busy-chat image: chat now clears minimap/defense/stock/full cargo; kill feed clears the scoreboard. These are staged in-game frames, not an input playtest.
- The first idle capture expired under slow rendering and is excluded from final evidence. The fixture now refreshes event timestamps while staging. Final capture directories: [before](../../evidence/codex-faisal-hud-feed/before-final/) and [after](../../evidence/codex-faisal-hud-feed/after-final/).
- Limits: candidate renderer shutdown logs three shader/RID leaks; baseline final capture logs none. No performance or clean-renderer-shutdown claim. Initial fresh import also logged file-hash diagnostics, retained in `import-final.log`; no script/parse/compile errors. No protected art, maps, networking or combat rules changed.
- Hub booked desktop Godot on the existing task, queue commit `2b9a28ab`. Peer engines were never stopped. Hub merges; no build publication or paid API use. Credits spent: 0.

Next: GitHub CI and hub merge review, then separate selected-target visual pass 5. Duplicate text in chat history is retained; this fix addresses overlap and the stray BLOCKED word.

Codex-faisal final import verification: official 4.3 headless editor import with Compatibility explicitly selected exited 0 with no diagnostics (import-verify.log). Runtime captures used native Forward+, not Compatibility. PR154 undrafted; CI run139 on101b086 pending.
