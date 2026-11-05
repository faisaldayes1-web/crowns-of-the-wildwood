# Map audit pass 3 captures (claude-faisallaptop, cf-crowns-mapaudit-1105l, 2026-11-05)

Source: code branch `claude-faisallaptop/crowns-mapaudit-1105n`, commit `a2ecd90d16449cc25753a9fd49317176c998fd33` (main 98c294b + pass 3).
Engine laptop2 godot-fg, Godot 4.3, NVIDIA GeForce RTX 5080 Laptop GPU / forward_plus, 1920x1080, day/normal lighting (Moonlit with `--debug-night`), seed = the game's fixed map seeds.

## Read this first: pass 1 and pass 2 frames had a capture artefact
`tools/map_qa_grid_capture.gd` froze the world 30 frames after the battle start. The battle-start shockwave is a tween, so it hung mid-ring as a **30 m translucent gold disc** over the middle of every map (the yellow haze round the Stonekeep courtyard, the yellow wash over the Wildwood bridges and dais). It is not in the game. Pass 3 waits 300 frames; the disc is gone from every frame in this folder. Compare pass 3 `after` against pass 2 `after` with that in mind (cameras are identical: g1..g8, x1..x8, overhead r0..r3 x c0..c3, hud).

## Layout
- `<map>/after/` the 33 grid shots + `manifest-<map>.json` (source_sha, renderer, camera positions). `<map>-overhead.jpg` and `<map>-ground.jpg` are contact sheets of the 16 overhead and 16 ground shots.
- `faisal-reference/` Faisal's two screenshots (the "before" for his exact spots).
- `spots/before`, `spots/after`: same-camera crops from `tools/map_spot_capture.gd` (game camera angle, fov 50). `before` is main 98c294b.
  - Wildwood (map 0) Faisal's spot west of the cobble path: `map0-fence` (the tree standing), `map0-fence-felled` (the felled stump cluster as in his screenshot; camera `-37.5,-9.5` 9 up 7 back), `map0-stub` (wall pillar and bushes). Before shows the tan cobble pad under the stumps; after has none.
  - Wildwood Heart-Tree island: `map0-heart` (overhead), `map0-heartG` (game angle), `map0-bridgeE`.
  - Wildwood hill: `map0-hill`; boulders: `map0-crates` (boulder pebbles now grey, after only).
  - Stonekeep (map 3) Faisal's pillars/rubble: `map3-court` (before/after same camera), `map3-pillar` (after). The `before/map3-court.jpg` still has the frozen gold disc.
- `boot-logs/` release-export boot logs, see below.

## Release-export boot (fresh profile)
Windows Desktop release export of a2ecd90 booted with `--play --map=N --quit-after 2400`, fresh APPDATA per map (0-4): 0 SCRIPT ERROR, 0 exceptions, exit 0 on all five. The only ERROR lines are Godot 4.3's `Attempt to disconnect a nonexistent connection ... skeleton_updated` (about 900 per boot, engine noise) and the exit-time shader/RID leak notices.
