# Crowns of the Wildwood on Steam

Steam first, Roblox later (Faisal, 2026-10-13). This page says what is built,
what only Faisal can do, and how a build reaches Steam.

## What is in the game

- **GodotSteam 4.15** (GDExtension for Godot 4.1 to 4.3, Steamworks SDK 1.62,
  MIT licence) is in `tools/steam/godotsteam/`, with 64-bit Windows and Linux
  libraries only. It goes into the **Steam build only** (`tools/steam/build_steam.sh`).
  The standalone zip and the iPad web build are unchanged.
  - Why it is not in `addons/`: a fresh `godot --headless --import` of a
    project that carries a GDExtension stalls (checked 2026-10-14: no files
    imported after 10 minutes, the same project without it imports normally),
    and every group thread imports fresh checkouts.
- **`scripts/steam.gd`** (autoload `SteamHub`): starts Steam when the game
  runs from the Steam client. Without Steam (standalone zip, web, headless,
  tests) it does nothing.
  - `steam/app_id` in project.godot (0 until the App ID exists), or
    `build_steam.sh --app-id=N`.
  - `steam/require_steam` is on only in the Steam export (feature `steam`):
    an exe started outside the client asks Steam to relaunch it, which makes
    the Steam overlay and achievements work.
  - The Steam overlay (Shift+Tab) pauses an offline match like Esc.
  - `-- --steam-app=480` tries Valve's test app, Spacewar.
- **Achievements**, unlocked only for the local player and never in bot
  demos. Create them in Steamworks with exactly these API names:

| API name | Name | Description |
| --- | --- | --- |
| FIRST_WIN | First Crown | Win a match. |
| WIN_ELVES | Heart of the Wildwood | Win a match as the Elves. |
| WIN_HUMANS | For the Realm | Win a match as the Humans. |
| FIRST_CAPTURE | Crown Thief | Carry the enemy crown home. |
| FIRST_REVIVE | Not Today | Revive a downed ally. |
| FIRST_FINISHER | No Mercy | Finish off a downed enemy. |
| ONLINE_MATCH | Better Together | Finish an online match. |
| LEVEL_5 | Seasoned | Reach account level 5. |
| LEVEL_10 | Veteran | Reach account level 10. |
| LEVEL_20 | Legend of the Wildwood | Reach account level 20. |

  Each needs two icons (achieved and locked). The Steamworks Achievements
  page gives the exact size, so check it before making them.
  In an online match the host's game runs the match, so a joiner may miss
  the capture, revive and finisher achievements. Not yet checked with a real
  Steam client.

## Building and uploading

1. Build: `tools/steam/build_steam.sh --app-id=<APP_ID>` writes
   `build/steam/windows/` (the exe with the game data inside, plus
   `libgodotsteam…dll` and `steam_api64.dll`). Add `--dev` to also write
   `steam_appid.txt` for running the exe outside the Steam client while
   testing. The upload never ships that file.
2. Upload, from Faisal's PC (steamcmd asks for his password and Steam Guard code):
   - Windows: `tools\steam\upload.bat <steam login> <APP_ID> [DEPOT_ID]`, with
     `steamcmd.exe` from the Steamworks SDK (`sdk/tools/ContentBuilder/builder/`).
   - Linux or Mac: `STEAM_USER=<login> tools/steam/upload.sh <APP_ID> [DEPOT_ID]`.
   - The depot ID defaults to App ID + 1, which is Steamworks' first depot.
3. In Steamworks: SteamPipe > Builds, set the uploaded build live on the
   `default` branch (or a beta branch for testers).

Steam Deck runs the Windows build through Proton. Controllers and the
on-screen keyboard prompts are already handled by the game's pad support.

## Steam Cloud saves (Auto-Cloud, no code needed)

Steamworks > Cloud: enable it, set a quota (1 MB and 100 files is plenty),
then add one Auto-Cloud root:

- Root: `WinAppDataRoaming`
- Subdirectory: `Godot/app_userdata/Crowns of the Wildwood`
- Pattern: `*.cfg`, recursive (covers `controls.cfg` and `profiles/*.cfg`)
- OS: Windows

## Store page assets

These sizes are from the Steamworks graphical assets rules. The upload pages
list the exact current sizes, so check there before making the art.

| Asset | Size (px) | Notes |
| --- | --- | --- |
| Header capsule | 920 × 430 | logo plus key art, top of the store page |
| Small capsule | 462 × 174 | lists and search; the logo must read at this size |
| Main capsule | 1232 × 706 | front-page carousel |
| Vertical capsule | 748 × 896 | seasonal sales |
| Screenshots | 1920 × 1080 | at least 5, gameplay only, no text overlays |
| Page background | 1438 × 810 | optional |
| Library capsule | 600 × 900 | Steam library grid |
| Library header | 920 × 430 | |
| Library hero | 3840 × 1240 | no logo or text on it |
| Library logo | 1280 × 720 max | transparent PNG, placed over the hero |
| Community icon | 184 × 184 | JPG |
| Client icon | .ico | the game's icon in the Steam client |
| Achievement icons | see the Achievements page | two per achievement (achieved, locked) |
| Trailer | 1920 × 1080 | optional but strongly recommended |

## Only Faisal can do these

1. Sign up at partner.steamgames.com (Steamworks), accept the Steam
   Distribution Agreement, and pass identity verification.
2. Pay the Steam Direct app fee (US$100 per game, paid back after the game
   earns US$1,000), then complete the tax interview and bank details.
3. Create the app. Send the **App ID** (and the depot ID if it is not App ID + 1).
4. Fill in the store page: description, tags, price (or free), the content
   survey (age rating), system requirements, and the art above.
5. Create the achievements in the table above and publish them.
6. Turn on Steam Cloud with the Auto-Cloud root above.
7. Run the upload script (it needs his Steam login), then set the build live.
8. Submit the store page and the build for Valve's review (a few business
   days each). The store page must show as "Coming Soon" for at least two
   weeks, and release is possible no sooner than 30 days after paying the fee.
