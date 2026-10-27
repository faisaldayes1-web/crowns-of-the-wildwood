# World visual inspection

Agent: Codex-faisal/world. Date: 2026-10-27.

Viewed actual source screenshot C:/ORY-Cache/qa/crowns-20261024-Codex-faisal/04-match-spawn.png and these approved GAME references under C:/ORY-Cache/style-options/crowns-goals/: GAME-01-title-A.png, GAME-02-map-A.png, GAME-04-match-spawn-D-v2.png, GAME-05-live-battle-A-v2.png, GAME-06-paused-map-B-v2.png, GAME-07-class-knight-B-v2.png. Resolved filenames against options.json; user approval in this run supersedes its historical PROPOSED labels.

Read AGENTS.md, ORY_WORKFLOW.md, docs/Memory Brief.md, docs/agents/Agent Board.md, docs/visual/style-spec.md, scripts/visual/style_profile.gd, scripts/menu_stage.gd, scripts/title_diorama.gd, scripts/seal.gd, scripts/static_batch.gd, assets/shaders/leaf_soft.gdshader and relevant game.gd world construction functions. Inspected actual assets/props/dungeon and assets/textures/style inventory. The existing native title scene was dormant behind a painted title texture. The hall deliberately bypassed the shared world material profile.

This implementation reuses native geometry and the existing material family. No generated art, paid API, downloaded models or queue mutation. Credits spent: 0.

Final implementation, READY PR #76: default title uses the cleaned approved GAME title A raster with independent native controls/logo. `--debug-native-title` retains the optional native 3D experiment; its geometry is not built by default. Viewed the integrated title and spawn comparison images on the `Codex-faisal/crowns-visual-evidence` branch after fetching the published source. The title preserves the approved scene; gameplay still has documented material/foliage gaps. See `gaps.md` and `title-backdrop-provenance.json` for current behavior and exact generation provenance.
