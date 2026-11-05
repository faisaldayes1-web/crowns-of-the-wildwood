# Split-screen HUD at 720p

Agent: claude-faisal3. Task `cf-crowns-steam-1104n` item 3, branch `claude-faisal3/crowns-split-hud-720-1104` from main dcebd5c.

- **Two players side by side (the default split):** the bottom row is stacked, the ability strip above the status panel, so it needs 620 HUD units across instead of 1280. The pane HUD scale goes from 0.50 to 0.83 at 1280x720 (1.66x): ability labels and the 11-unit text go from about 5.5 px to 9.1 px, hearts, bars and icons grow the same. The chat log and the LEVEL UP board move up to clear the taller bottom block. 1080p checked too.
- **Not changed:** four players and the top-and-bottom two-player layout keep the single row, and stay small (scale 0.40 at 720p, text about 4.5 px). Their panes are 360 px tall, so the same row cannot grow without covering the view; they need a compact HUD (drop xp text and ability names, keep hearts, energy and icons), which is a design call. Screenshot `unchanged_4p_720p.png`.
- Code: `scripts/game.gd` (`pane_stacked`, `SPLIT_HUD_*_STACKED`, `_layout_panes`), `scripts/hud.gd` (`_stacked`, `_draw_player_panel`, `_draw_quick_upgrade`, `_chat_rect`). New `tools/split_hud_test.gd` (CI).
- Evidence: `docs/evidence/claude-faisal3-split-hud-720-1104/` (before/after 720p, after 1080p, 4P unchanged).
- Tested: split_hud_test 0 failures; pad_split_test 0 failures (4 pads, headless). `tools/hud_chat_space_test.gd` already fails on main (its fixture lacks `chat_open`, error at hud.gd `_chat_rect`; not in CI), unchanged by this PR. Not tested: LEVEL UP board in the stacked layout by screenshot (code moved, not seen), touch screens, a physical pad.
