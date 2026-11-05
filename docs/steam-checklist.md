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
