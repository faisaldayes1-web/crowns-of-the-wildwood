# Native four-player full-match evidence

Agent: Codex-faisal3/bugtest.

**Overall FAIL: 908 engine errors.** All 53 input/lifecycle assertions passed on current main `d2f72a4920b253aed0b239ec16bd68fe301e2550`: 907 Skeleton3D disconnect errors and one ten-resource shutdown leak remain the signatures already recorded in issue #68. No runtime fix, art/asset change, binary upload, PR or merge is included here.

The existing exact Windows package was checked against its recorded executable SHA256 before launch. A separate headless process proved actual `user://` resolved below this run's disposable APPDATA prefix before any input. Ordinary Godot userdata hashes remained unchanged.

The external SceneTree bot boots the configured production main scene, then uses real mouse hit regions to select split screen. Pads7/0/1/2 join and ready through normal native InputEventJoypadButton/Motion events. Fixed60 engine simulation retains ordinary AI, 20s fortify, rules, timers, physics, deaths and rewards; read-only `route_point`/positions drive left/right sticks, attacks, class/crown interaction and abilities. No gameplay positions, health, roles, resources, time, rewards or outcomes are assigned by the bot.

Observed: all four players take Knight hats, move through the collision world and recover after natural deaths. P1-P3 damage enemies. This coop strategy loses naturally 0-2 at about160 simulation seconds. **No player crown pickup/capture or P4 enemy-damage acceptance** is claimed. Cumulative distance also includes normal respawn displacements; predeath snapshots independently record each player's travel above100m. No bot weakness is classified as a game defect.

Primary-account earnings are XP196, gold200, shards15 and one chest, matching the configured loss rewards. Native R skips the actual tally and returns to a newly loaded title scene; the exact wallet survives. A normal four-pad rejoin starts a fresh fortify/0-0 second round and grants no duplicate reward. Only the start of that second round is qualified.

Reproduce using the included external bot and runner against an isolated tester clone at `d2f72a4920b253aed0b239ec16bd68fe301e2550`, official Godot4.3 Windows export, and the same recorded package hash. The runner verifies package/current source and actual disposable user path first; then runs `crowns.exe --headless --script <crowns-four-full.gd> --fixed-fps 60`. It retains raw engine errors and separate input assertions. Source/package and bot hashes, actual path receipt, exact input checks and natural-outcome/wallet records are in `receipt.json` and the original logs.

Known shared-pause #71 is not exercised or cleared by this run. No physical controller/connection/disconnection, rendered screenshots/full-style/animation, measured performance, second full outcome or clean-release acceptance. Headless logs are not rendered evidence.
