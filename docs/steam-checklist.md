# Steam release checklist: the game itself

Agent: claude-faisal3, task `cf-crowns-steam-1104n` item 2, 2026-11-04, on main dcebd5c.
Companion to `docs/steam.md` (what is built, how to upload) and `docs/steam-readiness.md` (candidate build gates). This page covers the **player-facing game**: what a Steam player sees from the title to quitting, what was checked, and what is still open.

Status words: **DONE** (checked, how), **CODE** (in the code, not exercised in a real Steam client), **OPEN** (not done), **FAISAL** (only Faisal can decide or supply it).

## Title and menu
- **DONE** Title: PLAY, CUSTOMIZE, SETTINGS, TUTORIAL, CREDITS, EXIT, STORE, ONLINE, profile and gold readouts. Screenshot at 1280x720: `docs/evidence/claude-faisal3-steam-ready-1104/title.png`. `tools/menu_flow_test.gd` clicks the flow.
- **DONE** Version string `v0.9.0-rc` bottom-right of the title and in the credits.
- **OPEN** The title has no CONTINUE button: PLAY goes to map select and the account (level, gold, store items, looks) loads by itself. That fits 10-minute matches; say so on the store page if reviewers ask.

## Credits (in game: title > CREDITS)
- **DONE** "A GAME BY: Faisal, solo developer".
- **DONE** Every third-party licence line kept: Godot (MIT), KayKit packs (CC0), Lilita One (SIL OFL), Luckiest Guy (Apache 2.0), VSCO 2 CE (CC0), GodotSteam (MIT), Steamworks SDK (Valve), pointer to `THIRD-PARTY-NOTICES.txt`. `tools/steam_ready_test.gd` fails if any is dropped.
- **DONE** The audio line now says sound effects and music are ElevenLabs-generated (it said "made by generator scripts", which `assets/CREDITS.md` contradicts).
- **CODE** `THIRD-PARTY-NOTICES.txt` is written by `tools/steam/build_steam.sh` into the build folder. It is not in the repo; `docs/steam-readiness.md` already has the review step.

## Settings (title: SETTINGS; match: Esc > SETTINGS)
- **DONE** Audio: sound and music sliders (also the AUDIO tab).
- **DONE** Display: Window / Borderless / Fullscreen, **window size** (new: 1280x720, 1600x900, 1920x1080, 2560x1440, only sizes that fit the screen, windowed mode only), VSync, frame cap, 3D resolution scale, damage numbers, screen shake, FPS counter, chat, rosters.
- **DONE** Quality presets Low / Medium / High / Ultra, with **auto-detect**: first run picks High on a discrete GPU, Low otherwise, then steps down one preset if the game stays under 40 fps for 4 s, until the player picks a preset. New **AUTO** button returns to that mode (detection and step-down are skipped when the game is started with any launch option, which includes Steam launch options).
- **DONE** Controls: rebindable keys, controller button names (auto / Xbox / PlayStation), control layout, rumble, split-screen layout.
- **DONE** Everything saves and survives a restart: `tools/settings_restart_test.gd` (now includes window size, in CI).
- **Limit** Window size and AUTO are on the title's Settings only. The paused page has no room for a third Display row under the LEAVE/RESUME bar (it overlapped the Gamepad row when I tried); change them from the title.
- **OPEN** Auto-detect on first run is by GPU type only. An integrated GPU on a fast CPU gets Low until the step-down logic or the player moves it.

## Save and continue
- **DONE** Account progress saved with backup and recovery: `save_write_test`, `save_recovery_test`, `save_test` (CI).
- **By design** No mid-match save: closing mid-match keeps settings and account, not the match.
- **FAISAL** Steam Cloud: not configured. Decide which files sync (`controls.cfg` and `profiles/`) and the conflict rule; see `docs/steam-readiness.md`.

## Quit flow
- **CODE** Title EXIT needs a second press ("AGAIN"), then saves settings and the account and quits. Closing the window saves too (`NOTIFICATION_WM_CLOSE_REQUEST`).
- **CODE** In a match: LEAVE MATCH asks again before leaving.
- **OPEN** Neither was run against a real Steam client (overlay open, Alt+F4, Steam "Stop").

## No debug text in release
- **DONE** The FPS counter no longer switches itself on at first run in a release export (it still does in a debug build, for testers). Players can turn it on in Settings.
- **DONE** `--debug-gold`, `--debug-chests`, `--debug-own`, `--debug-xp` and `--debug-unlock` write or unlock account progress; they are now ignored unless the build is a debug build. Steam launch options can no longer cheat the account (`--debug-unlock` is gated in all four places it is read, `--debug-end-xp` too).
- **OPEN** The rendering-only `--debug-*` and test flags (camera, banners, forced end screens, about 60 of them) still work in release; they change what is drawn, not the save. Gate them if Faisal wants a strict build.
- **CHECK** Export with `--export-release` (what `build_steam.sh` does). A debug export reopens the gates above. `print()` output goes to the log, not the screen.

## Version
- **DONE** One version: `application/config/version` in `project.godot` (read by `Game.version_text()`), equal to `version/name` in `export_presets.cfg`. `tools/steam_ready_test.gd` fails if they differ. To bump, change both.

## Still needed before upload (none done by this PR)
- **FAISAL** App ID (`steam/app_id=0`), depot IDs, store page text, capsule/header art in Steam's sizes, screenshots, trailer, price, age-rating questionnaire.
- **FAISAL** AI-content disclosure: the Steam questionnaire asks about generated content. The game uses ElevenLabs-generated sound effects and music (`assets/CREDITS.md`); answer it accordingly.
- **OPEN** App icon: `project.godot` has no `config/icon`, so the window and taskbar show Godot's icon. It needs Faisal's art.
- **OPEN** Windows exe metadata: both Windows presets have `application/modify_resources=false`, so the exe has no icon, company, version or copyright. Needs rcedit configured in the build machine's editor settings.
- **OPEN** Code signing is off (`codesign/enable=false`); Windows SmartScreen will warn on a fresh, unsigned exe.
- **OPEN** Real Steam client run of the exact candidate, Steam Deck / controller configuration, achievements icons: the gates in `docs/steam-readiness.md`.
- **OPEN** Split-screen at 720p HUD legibility: separate PR from this task.

## Fresh-start bug test (2026-11-04, claude-faisal3, task `cf-crowns-ship-1104t`, main cec9938)
Every run on a new throwaway profile (`tools/tests/isolated.sh`), headless Godot 4.3, 5 maps: Wildwood, Moonlit Wildwood, Ember Pass, Stonekeep Fortress, Twilight Grove.
- **DONE** 40 runs, all exit 0, no `SCRIPT ERROR`: per map one full all-bot match (`--demo`), one solo `--play` run, and split-screen 2, 3 and 4 players in VERSUS and CO-OP. All-bot results: Wildwood Elves 2-0, Moonlit Humans 2-0, Ember Pass Humans 2-1, Stonekeep Elves 1-0 in overtime, Twilight Grove 0-0 draw after overtime.
- **Limit** These are scripted runs with no one watching. They prove no crash, no script error and a match that ends; they do not replace a person playing each map with a pad in hand.
- **DONE** Fixed: a split-screen player's pad unplugging mid-match only toasted, so that player stood still. The match now pauses; replug keeps the same player on the same device (`tools/pad_unplug_test.gd`, PR #210; not yet in the CI gate list, which the CI owner maintains). Player 2's pad dropping also no longer flips player 1's button hints to keys.
- **OPEN** Wildwood and Moonlit Wildwood place 8 of 9 wood node pairs (`WARNING: Economy: no room for a wood node pair near (-34, 0, -9)`). Widening the search in `scripts/economy.gd` only moves the failure to other spots, so it needs a new spot in `TREE_SPOTS`, a design call. Both teams lose the same pair, so it is fair.
- **OPEN** Twilight Grove: of 3 all-bot seeds that finished, 2 were decided in regulation and 1 was a 0-0 draw after overtime (7 raid deaths each). Too few runs to call it a balance bug; run a six-seed batch before tuning.
- **Note** `tools/map_switch_test.gd` needs `-- --debug-unlock` (Moonlit and later maps are locked on a fresh profile; that is the store working, not a bug).
- **Note** `tools/controls_live_test.gd` warps the real mouse cursor, so it fails when run unattended (2 checks, differing headless and windowed) and passed at 0 failures when written. It is not in CI. Run it with the window focused and the mouse untouched.
- **DONE** Settings, save, relaunch: `settings_restart_test`, `save_write_test`, `save_recovery_test` (87 checks), `save_test`, `options_menu_test`, `menu_flow_test`, `store_menu_test`, `reload_menu_test`, `pad_nav_test`, `steam_ready_test` all 0 failures.
- **CODE** Pad hot-plug is simulated (`Input.joy_connection_changed`), not done with real controllers.

## Steam hooks pass (2026-11-04, claude-faisal3, task `cf-crowns-ship2-1104v`)
- **DONE** Achievements: all 10 in `scripts/steam.gd` are called from the game (`FIRST_WIN`, `WIN_ELVES`, `WIN_HUMANS`, `ONLINE_MATCH` at match end; `FIRST_CAPTURE`, `FIRST_REVIVE`, `FIRST_FINISHER` for the local player only; `LEVEL_5/10/20` after each match). They are no-ops without Steam, in demo matches and headless. **CODE**: never run against a real Steam client or App ID (`steam/app_id=0`).
- **DONE** Cloud-save paths: every save is under `user://` (`controls.cfg`, `profiles/<id>.cfg`, `.bak` and `.tmp` siblings), the user dir is `Godot/app_userdata/Crowns of the Wildwood` (no custom user dir), and `docs/steam.md` names that Auto-Cloud subdirectory. `tools/cloud_paths_test.gd` fails if any of that drifts. **FAISAL** still decides which files sync and the conflict rule.
- **DONE** Controller glyphs per pad type: Xbox, PlayStation and now **Nintendo Switch** (bottom button prints B, ZL/ZR, + and -, plain letters instead of Xbox colours), auto-detected by name or USB vendor id 057e, and a SWITCH choice in Settings > Button Names. Steam Deck and other pads keep Xbox names. `tools/pad_kind_test.gd`. **CODE**: no real Switch pad was connected; detection is by name and vendor id.
- **DONE** 16:10 and ultrawide: `stretch/aspect=expand` and an edge-anchored HUD already work. Captured the title, map select and a live match at 16:10 (1920x1170), 2.34:1 (about 21:9) and 3.5:1 (about 32:9); nothing is cropped or overlapping (`docs/evidence/claude-faisal3-aspect-1104/`). **Limit** this screen cannot open a window wider than itself, so the wide shots are short windows of the same ratio, not a 3440x1440 monitor. **Note** the wider the screen the more of the map is visible; that matters if online matches are ever competitive.
- **DONE** `cloud_paths_test`, `pad_kind_test`, `pad_unplug_test`, `pad_nav_test`, `options_menu_test`, `menu_flow_test` and `store_menu_test` are now in the CI gate list (day pass below).

## Day pass (2026-11-05, claude-faisal3, task `cf-crowns-day-1105e`, main 9578950)
- **DONE** Split-screen HUD at 720p merged (#200). Old drafts #222, #142, #84/#69 folded in (#236): couch XP tally now covers every banked player; unit dictionary copies; balance report. #215 (lava knock-off) left open, do-not-merge.
- **DONE** Fresh-start run on a throwaway profile on every map, headless Godot 4.3, seed 7, one full all-bot match each: Wildwood Humans 2-0, Moonlit Elves 2-0, Ember Pass Elves 2-0, Stonekeep Elves 1-0, Twilight Grove 1-1. 0 `SCRIPT ERROR`, all exit 0. **Limit** scripted bots, nobody watching; not a person with a pad.
- **Note** Twilight Grove logged `ObjectDB instances leaked at exit` once (exit-time notice, not a crash; cause not investigated). Moonlit still logs the known wood-node-pair warning.
- **DONE** Settings, rebinding, controller glyphs, achievements hooks: re-run `settings_restart_test`, `options_menu_test`, `menu_flow_test`, `pad_kind_test`, `pad_nav_test`, `pad_unplug_test`, `store_menu_test`, `cloud_paths_test`, `steam_ready_test`: all 0 failures. A sweep for hardcoded key names in player-facing text found none that ignore bindings or pad type (the keyboard onboarding chat line is rewritten from current bindings in `hud.gd _chat_display_text`).
- **OPEN** Nobody has hand-played each map with a real pad and a real Steam client; achievements stay **CODE** until there is an App ID.
