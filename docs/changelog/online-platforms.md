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

## 2026-10-09 03:31 UTC · `7efb455` · Merged the showcase thread's web fixes

- **What:** the "Current build showcase" thread fixed the same two web problems on its own branch
  (culling override as a web-only setting, letterbox in `_ready`); merged so both branches agree.
  Kept its `_ready` block and web-only override, dropped this branch's duplicates, kept the
  post-load graphics cap, FXAA-only web view and the menu hall shadow fix. `9291713` then merged
  `main` (docs only).
- **Files:** `project.godot`, `scripts/game.gd`
- **Tunables:** `threaded_cull_minimum_instances` 1000000 → (web only) 100000000
- **Revert:** `git revert -m 1 7efb455`

## 2026-10-09 04:50 UTC · `HASH-PENDING` · iPad web build runs faster: a quarter of the draw calls, baked HUD art

- **What:** Faisal: "it feels very laggy still" on the iPad. Measured in an iPad-emulating Chromium,
  a match frame issued ~10,200 WebGL draw calls, two thirds of them shadow passes (the sun's four
  cascades and five cube-map lamp shadows redrew every caster each frame) and ~1,400 of them the
  HUD, which rebuilt ~900 polygons of minimap art every frame. Now ~2,700 draw calls a frame, and
  the per-frame script time of the HUD is down by about half.
  - Browser only (`OS.has_feature("web")`): the sun uses one orthogonal shadow map over 50 m
    instead of four cascades over 70 m, read with a hard (one-tap) filter from a 2048 atlas;
    room lights and camp fires cast no shadow (WebGL never rendered them anyway); mesh instances
    under 0.8 m stop casting shadows after the world is built (`_trim_web_shadows`, 8,530 → 5,858
    casters); the 3D view renders at half the canvas size (`scaling_3d_scale` 0.5, the iPad's
    2x pixel density becomes one 3D pixel per screen point; the HUD stays full density); a first
    visit starts on the Low preset (no glow, small atlases; Settings can raise it to Medium); bots
    think every other physics tick and repeat their last move in between; the touch overlay
    redraws on finger events, not every frame; anisotropic filtering 8 → 4.
  - All platforms: the minimap's painted chart and its bronze ring, and the screen frame with
    its ivy, are drawn once into textures by a copy of the HUD inside a `SubViewport`
    (`_bake` / `_layer` in `scripts/hud.gd`) and re-drawn only when their key changes (Ember
    Pass's lava chart four times a second); the live HUD draws the textures and only what moves
    (units, potions, doors, the shrine pulse). The frame's texture carries premultiplied alpha,
    so it is shown by a `TextureRect` with that blend mode. Wheat fields never cast shadows.
  - New test aid: `-- --perf` prints frame-time monitors every five seconds (process and physics
    time, draw calls, objects, primitives, node count) and, once, a census of nodes by class,
    shadow casters and blended mesh instances. Useful in the browser console too.
- **Files:** `project.godot`, `scripts/game.gd`, `scripts/hud.gd`, `scripts/touch.gd`,
  `scripts/unit.gd`
- **Tunables (web only):** `directional_shadow_mode` 4 splits → orthogonal;
  `directional_shadow_max_distance` 70 → 50; directional atlas 4096 → 2048, filter soft medium →
  hard; positional atlas 2048 → 1024 and lamp shadows off; `scaling_3d_scale` 1.0 → 0.5; default
  preset Medium → Low (cap stays Medium); `anisotropic_filtering_level` 8 → 4; bot think 60 → 30 Hz.
  Desktop: unchanged apart from the baked HUD layers and the wheat.
- **Tested:** `--check-only` on every changed script; a headless `--play --perf` match; the
  exported build in Chromium with an iPad user agent and touch emulation: draw calls per frame
  10,249 → ~2,750 (shadow pass 6,500 → 1,150, HUD 1,400 → 345, 3D ~1,000 → ~650), the software
  renderer's frame time 3.4 s → 0.7 s, screenshots of the minimap, frame and panel unchanged to
  the eye, no new console errors. Not yet measured on a real iPad.
- **Revert:** `git revert HASH-PENDING` (restores the old shadows, per-frame HUD drawing and
  full-density 3D on the web)
