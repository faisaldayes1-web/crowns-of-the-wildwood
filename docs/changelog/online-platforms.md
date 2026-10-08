# Online & Platforms changelog

Every commit from the Online & Platforms group, newest last. Each entry says what changed, the files
it touched, any tunable that moved (old → new), and the exact line that undoes it.

A commit cannot contain its own hash, so each entry is written in the commit it describes and its
hash is filled in by the group's next commit (a hash-only edit to this file, which needs no revert
of its own). To undo a change, run its revert line on the branch, then re-run `tools/net_smoke.sh`.

---

## 2026-10-08 22:35 UTC · `ad2abae` · iPad web build: world visible, letterbox on first visit

- **What:** the browser build (played in Safari on an iPad) showed only the sky and the HUD once a
  match started, and on a first visit the menus ran off the sides of the screen. Three fixes:
  the engine's threaded scene culling never runs on a no-threads web build, so every mesh was
  culled; culling now stays on the main thread (`threaded_cull_minimum_instances` raised so the
  threaded path is never taken). The 4:3 letterbox and the Medium graphics cap for the web are now
  applied before the saved-settings file is read, so a first visit with no saved file gets them
  too. On the web the 3D view uses FXAA with no multisampling and no 3D scaling (the iPad draws at
  2x pixel density). Also a crash-log fix: `_show_loading` no longer calls `queue_free` on a
  loading screen that was already freed.
- **Published:** the build is on the `gh-pages` branch, served at
  https://faisaldayes1-web.github.io/crowns-of-the-wildwood/ (re-export with
  `godot --headless --export-release "Web" out/index.html` and push the files to `gh-pages`
  with a `.nojekyll` file to update it). A zip of the same files is in the project files under
  `game/web-build/`.
- **Files:** `project.godot`, `scripts/game.gd`
- **Tunables:** `rendering/limits/spatial_indexer/threaded_cull_minimum_instances` 1000 (default) → 1000000; web only: `msaa_3d` 4x → off, `scaling_3d_scale` 1.0 (unchanged)
- **Tested:** Chromium with an iPad user agent, touch emulation and a 1180x820 landscape viewport
  on the exported build: title taps, Select Map, Ready Up, a match with the Elf spawn cellar and
  class stations drawn, the move stick and the attack pad.
- **Revert:** `git revert ad2abae`

## 2026-10-08 23:05 UTC · `a270b18` · Web: no spot-light shadow in the menu hall

- **What:** the menu hall's key light cast a shadow that WebGL rejects on the Compatibility
  renderer (hundreds of "textures can not be used with multiple targets" console warnings and no
  shadow anyway). The shadow is now off in the browser build only; desktop keeps it.
- **Files:** `scripts/menu_stage.gd`
- **Tunables:** none
- **Revert:** `git revert a270b18`
