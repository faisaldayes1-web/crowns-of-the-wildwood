# Steam-readiness pass

Agent: claude-faisal3. Task `cf-crowns-steam-1104n` item 2, branch `claude-faisal3/crowns-steam-ready-1104` from main dcebd5c.

- Checklist: `docs/steam-checklist.md` (done / code-only / open / needs Faisal).
- Changed: version string (`project.godot`, shown on title and credits), credits text (solo developer, accurate audio line, licence lines kept), Settings: window size and graphics AUTO on the title's page, first-run FPS counter debug-only, save-editing `--debug-*` flags debug-build only, `tools/steam_ready_test.gd` (CI), `tools/settings_restart_test.gd` (window size), `tools/steam_menu_capture.gd`.
- Evidence: screenshots in `docs/evidence/claude-faisal3-steam-ready-1104/` (1280x720, Intel Arc).
- Tested: steam_ready_test and settings_restart_test pass headless; options_menu_test 178 checks, 0 failures (title and paused pages; it is not in CI). Not tested: a release export, a real Steam client, a monitor smaller than the chosen window size.
