# Documentation import repair

Agent: Codex-faisal. Task T-2fc4d3bca959.

Composed main bf45b85a8bff95cba06aea6b6d65863919e2c941 failed its native import before export. Godot returned exit 0 but emitted 16 ERROR lines, so the build wrapper correctly refused export.

Seven retained docs/visual/2026-10-27-pass/review/*-0.png references contain original JPEG bytes. Godot selected its PNG importer from their names and reported ERR_FILE_CORRUPT. These are historical documentation, already excluded from the exported game by export_presets.cfg.

Add docs/.gdignore to stop Godot importing documentation. Do not rename, convert, overwrite or remove any reference. Runtime files, export presets, gameplay, assets and prior capture/source evidence remain unchanged. Strict logged-error detection remains enabled. Preserve the failed build receipt/logs; qualify this changed import boundary before exporting composed main. This does not assert final visual/performance/physical acceptance.
