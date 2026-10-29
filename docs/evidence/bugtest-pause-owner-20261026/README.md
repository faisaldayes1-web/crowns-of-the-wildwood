# Player1 shared pause ownership

Agent: Codex-faisal3/bugtest.

README couch rules (main lines42-43) assign pause/chat/scoreboard to player1. Current main d2f72 normal menu flow: PLAY, SPLIT SCREEN ON, READY UP; pads0/1/2 join with A, select allied sides via Dpad, ready with A, normal START MATCH. Player1 keeps keyboard/mouse, or first uses pad7 in map menus to own it. Native queued events only; no forced game properties or menu/start/prep/outcome APIs.

Main keyboard-owner route29checks/28pass/1fail: secondary pad0 Start opens shared pause, although that pad belongs to player2. Pad1/2 do not. Main pad7-owner route31checks/29pass/2fail: same secondary pad0 takes pause, while actual player1 pad7 Start is ignored. Logs show bound_pads[-1,0,1,2] or[7,0,1,2] alongside menu Joypad event still hard-coded to device0. All joins/ready/panes/movement/keyboard/unused-pad/keyboard pause recovery passed. Main runtime199engine ERRORs per route are retained separately.

Four added source lines rebind the existing menu Joypad event to the already computed p1_device in _bind_couch_input. No keyboard, per-player gameplay, UI layout, assets, rules, resources, save or outcome changes.

Fresh independent candidate import49.44s and Windows export11.41s PASS, no import/export errors. Exact new package, actual isolated user path before each native route, ordinary Godot userdata hashes unchanged. Candidate keyboard-only player1:28/28 assertions; owned-pad7 player1:31/31 assertions. Secondary0/1/2 cannot take pause; player1 keyboard and owned pad7 can open and resume. Movement routing and natural20s fortify simulation (fixed60 engine run) retained. Candidate input scenarios PASS; each runtime still198engine ERRORs, so overall FAIL. Existing lifecycle issue68 remains unresolved. No fabricated clean acceptance or screenshots.

Headless DisplayServer has no rendered capture here. Native queued virtual gamepad/keyboard and live menu mouse hit regions are software routing coverage, not physical controllers, unplug/replug, UI/style/animation/performance/full-match acceptance. Package binary is NOT published; hashes/provenance and exact external bots/logs are. New source changes only scripts/game.gd. Initial two-player test's final two pause expectations contradicted README and first four-player tester inferred-bool parse error are preserved locally, not reported as game defects. Those tester errors were corrected before the main29/31 baseline above.
