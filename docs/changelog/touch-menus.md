# Touch menus (iPad) changelog

Branch `claude/mobile-closable-menus-0ytogk`, cut from the Steam beta head `b0e261f` (group/integration-release-g9m95g).

### 2026-10-15 03:05 UTC · `ca0699e` · Movement follows the mouse aim; hints follow the device

- **What:** Faisal 2026-10-15: "when you aim with your mouse, your movement should also go that way" and "controls should update if switched inputs". On keyboard + mouse, W now walks toward the cursor, S backs off, and A/D circle it (`unit.aim_relative`, also used for online joiners). With the cursor within 0.9 m of the player, keys keep screen directions. Pads and touch are unchanged. Controls > MOVEMENT has a "Keyboard movement" pick (TOWARD THE CURSOR default / UP THE SCREEN), saved as `settings/move_mode`. Moving the mouse after using a pad now switches the hints back to keys at once (before, it took a click or key). On Auto, a pad stick push also leaves the touch layout.
- **Files:** scripts/unit.gd, scripts/net.gd, scripts/game.gd, scripts/hud.gd, scripts/touch.gd, tools/kbm_move_test.gd
- **Tunables:** none
- **Tested:** kbm_move_test 10/10, touch_close_test 0 failed, options_menu_test, menu_flow_test, tools/tests/run.sh 0 failures; Wildwood demo had no script errors.
- **Revert:** `git revert ca0699e`

### 2026-10-14 21:05 UTC · `dbd74a0` · Every panel closes with a finger; control layout pick

- **What:** Faisal: "for ipad users, the wood upgrade meter cant close out, make sure all menus can be closable on mobile" and "make sure to have an option to change the controls ... i was on my laptop but it implemented touch screen ui".
  - Veteran Training panel: a brass X on its corner (tap or click). The TRAINING slot toggled twice per tap (touch action plus the finger's emulated mouse click), so a tap never opened or closed it; economy now ignores emulated clicks while the touch layout is on. Same double press made the action card's + and TRAIN buy twice.
  - LEVEL UP strip (with the Training tile): an X at its left end puts it away until a new point or tile appears; keys 1-4 still buy. Its rank tiles bought two ranks per tap; now one.
  - Action card (door / turret / hat machine): an X hides it until you step off that spot.
  - Chat closes with a tap outside its tabs; a Controls rebind started by a tap is cancelled by the next tap (it used to bind the left mouse button); the match summary's SCOREBOARD / SKIP no longer fire twice; the guide's Close is finger-sized.
  - Controls tab: CONTROL LAYOUT (Auto, Keyboard & Mouse, Controller, Touch), saved as `settings/control_layout`. Auto now starts on the touch layout only on phones and tablets (`mobile`, `web_ios`, `web_android`) or after a real touch, and goes back to the keyboard layout when the mouse or a key is used. Keyboard & Controller pin the layout (a finger still clicks menus).
- **Files:** scripts/touch.gd, scripts/economy.gd, scripts/hud.gd, scripts/game.gd, tools/touch_close_test.gd
- **Tunables:** none
- **Tested:** tools/touch_close_test.gd (real ScreenTouch events with mouse emulation) 21/21 pass; economy self-test 0 failed.
- **Revert:** `git revert dbd74a0` (and the X commit `1ebbaf7`)
