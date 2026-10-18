---
agent: claude-faisallaptop
task: RC1 build for CW-4 (day queue 2026-10-16, after PR #31 merged)
source: main ce6abfc (Merge pull request #31)
---
# Handoff: RC1 build (claude-faisallaptop, 2026-10-16)

## What
- **Windows release build** of main `ce6abfc`, made with Godot 4.3-stable and its official export templates, using the "Windows Desktop" preset (pck embedded, x86_64). It is at `C:\Users\faisa\Projects\crowns-of-the-wildwood\build\rc1\CrownsOfTheWildwood.exe` on the laptop (186 MB; `build/` is git-ignored). **Not published or uploaded anywhere.** The export ran after a clean re-import, with 0 errors in the log.
- **Screenshots from the exe itself**, every map at the shrine and both castles: `docs/screenshots/rc1/`, plus `contact-sheet.jpg` (rows: Wildwood, Moonlit, Ember Pass, Stonekeep Fortress, Twilight Grove).

## Tested (on the exported .exe, not the editor)
- A 6-minute headless bot match on each map (seed 11). 0 script errors on all five. Moonlit ended with Elves winning 2-0 at t=192; the other four played the full 6 minutes. Static batching ran on every map (Wildwood 8,278 meshes → 1,285; Ember Pass 2,950 → 635; Stonekeep 8,348 → 1,321).
- Rendered at 1920x1080, High, vsync off, 5-second averages from the game's own `--perf` log, with Silverglade and Roblox Studio still running:
  - Wildwood bot match: 75–127 fps.
  - Stonekeep bot match: 107–154 fps.
  - 4-player split: 45–101 fps (median ~68).

## Not tested
- The Steam preset, the web export, an install on another machine, real gamepads, online host/join.
- #4's 3 Ember Pass castle commits are still outside main (Faisal's call, see #32).

## CW-4 notes
- This is a local candidate for Codex-faisal's release checklist. Nothing gets published without Faisal's go.
- If Faisal wants the exe for a playtest, it can be copied from the path above; it can be rebuilt with `godot --headless --path . --export-release "Windows Desktop" build/rc1/CrownsOfTheWildwood.exe`.

## Spend
- Meshy / PixelLab: none. Installs: none.
