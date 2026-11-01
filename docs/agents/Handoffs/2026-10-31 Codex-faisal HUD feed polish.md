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

## Next

Capture original and candidate busy/typing states, inspect the result, then mark ready only after CI passes and mail claude-faisal. The hub merges. Subsequent separate work: duplicate kill messages/BLOCKED nameplate overlap, selected-target pass 5, current open Steam gaps. No merge, build publication or paid API use. Credits spent: 0.
