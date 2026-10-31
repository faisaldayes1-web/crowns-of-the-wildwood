# Actual map-select cards

Agent: Codex-faisal2

Replaced the four requested menu textures with local Godot 4.3 Forward+ renders of the actual maps. No runtime menu or gameplay code changed. Moonlit's native dimming, lock and level-10 requirement remain intact; Twilight Grove is untouched. Faisal remains the solo developer credit.

Evidence: [before / after / picked target](map-select-triptych.jpg), [after screen](after/select-screen.png), [compact touch screen](after-touch/select-screen.png), and each map folder's full source render, clean/labelled 4096x2304 overhead map and bounds JSON. The HD maps are exported artifacts, not a replacement for the runtime tactical minimap. `manifest.json` binds runtime textures to filtered render derivatives and verifies landmark-to-pixel coordinates. The 1024x960 source captures are Lanczos-filtered to 512x480 for clean small-card sampling. See `gaps.md` for remaining target differences.

Validation after integrating main 0158a9c: clean headless import before and after texture replacement, four refreshed map renders, desktop/compact touch menu captures with an assertion that Moonlit is locked, texture identity/dimension and map-coordinate checks. Full seed-7 bot match completed: Elves 2-0 at t=394, with all eight unit STAT records and exit 0. Final bot/import/render logs contain no errors or warnings. The earlier 354b74e run (bot-match.log) is historical and reported resource leftovers; bot-match-final.log is the current-source check. No publishing, paid APIs, credits or generated scenery.

Reproduce from a marked throwaway APPDATA / CROWNS_TEST_USER_BASE (see tools/tests/isolated.gd), with CROWNS_CAPTURE_DIR set to the destination:

```
Godot_v4.3-stable_win64_console.exe --path . --resolution 1280x720 --script tools/map_card_capture.gd -- --map=0 --seed=7
```

Map indices: Wildwood 0, Moonlit 1 (also pass `--debug-night`), Stonekeep 3, Ember 2. The night flag changes lighting without unlocking the menu. `python tools/map_card_evidence.py --prepare-textures` filters source renders into runtime textures; reimport afterward. `--menu-only` captures the integrated menu; `--capture-touch` selects its touch layout. `python tools/map_card_evidence.py` assembles the unretouched before/after/target sheet and verifies exports against the filtered textures. The target triptych path is recorded in that script.

Source look and capture choices are in look.md. This is reviewable progress toward the picked target; it does not claim that the game's foliage, masonry or VFX now fully match the target.
