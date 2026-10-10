# Split Screen group changelog

Branch `group/splitscreen-*`. Newest entry at the top. See [README.md](README.md) for the format.

### 2026-10-10 07:25 UTC · `81cc320` · Compact split-screen HUD

- **What:** Faisal (05:58): the split-screen HUD must not take up most of the screen. Each pane's HUD is now sized from the pane itself: the top bar and the bottom row together cover about a quarter of the pane's height or less (two players stacked: 29%, was about half; side by side: 19%; quarters: 29%), while the bottom row still fits the pane's width. The PLAYER N tag moves under the BASE STOCK card, which it used to overlap.
- **Files:** scripts/game.gd (`_layout_panes`), scripts/hud.gd (PLAYER N position)
- **Tunables:** new `SPLIT_HUD_SHARE` 0.26, `SPLIT_HUD_ROWS` 260, `SPLIT_HUD_WIDTH` 1240; pane HUD scale clamped 0.4-0.72 (was a fixed 0.72 for two players, 0.56 for quarters).
- **Tested:** options_menu_test and menu_flow_test (0 failures); 1080p screenshots of 2 players side by side and stacked and 3 players.
- **Revert:** `git revert 81cc320`

### 2026-10-10 06:20 UTC · `ee38509` · Vertical and horizontal split screen for two players

- **What:** Two couch players can now split the window **vertically** (side by side, the new default) or **horizontally** (top and bottom, the old layout). The choice is a Split Screen picker on the Options board's Settings tab (GAMEPAD row, also in the in-match PAUSED board, where it switches the panes live), under SPLIT SCREEN on SELECT MAP when split screen is ON, and on READY UP when two players are in. Three and four players keep the four quarters. A side-by-side pane is tall, so its HUD is laid out for a tall pane and its camera rises a little to keep the same reach along the lanes. Player 1 stays on keyboard and mouse (players 2-4 on pads); player 1's mouse aim is now read from the whole window and held inside their own pane, so the cursor over player 2's pane no longer aims there. The menu tests now also delete the settings backup (`controls.cfg.bak`) they leave behind, which made a second run of menu_flow_test fail.
- **Files:** scripts/game.gd (`split_layout`, `pane_rects`, `_layout_panes`, `set_split_layout`, `mouse_for`, `--split=` test flag), scripts/unit.gd (aim reads `game.mouse_for`), scripts/hud.gd (Split Screen picker, `_split_glyph`), scripts/menu.gd (`_layout_picker` on SELECT MAP and READY UP), tools/options_menu_test.gd, tools/menu_flow_test.gd, tools/store_menu_test.gd
- **Tunables:** new: `split_layout` setting "vertical" (saved as settings/split_layout); `SPLIT_TALL_ZOOM` 1.3 (camera pull-back in a side-by-side pane); side-by-side pane HUD scale 0.6. Unchanged: stacked two-player HUD scale 0.72, quarter panes 0.56.
- **Tested:** tools/options_menu_test.gd (0 failures; new: both layout buttons picked and saved in OPTIONS and PAUSED), tools/menu_flow_test.gd (0 failures; new: READY UP picks horizontal, panes stack, switching to vertical mid-match puts them side by side with tall HUDs, P1 keyboard/mouse + P2 pad, mouse over P2's pane stays in P1's pane); Vulkan screenshots of 2-player vertical and horizontal and 3/4-player matches.
- **Revert:** `git revert ee38509`
