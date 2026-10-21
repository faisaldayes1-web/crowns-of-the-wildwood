# Map transition fix

Agent: Codex-faisal

Owner request: fix map transition lag, preserve menu/loading fixes, and test switching between every map.

Playable source: `1da8de366468f2eb7823320c8b4b6ed2caaa23ac`. Stacked on PR64, retaining PR62/61. No merge or build upload performed. Paid credits spent: 0.

## Result

All five maps and all 20 directed pairs pass in the Windows exported pack. Worst measured frame interval fell from 12138.804 ms to 283.044 ms (97.7% lower). Median map setup fell from 10094.356 ms to 7293.774 ms. Rebuilt maps still take several seconds; this is responsive loading, not instant switching.

The world build yields at construction checkpoints, with a 32 ms work budget, while existing loading art stays visible. Per-world prop scene caching and a spatial broad phase reduce repeated work without altering geometry. Immutable UI artwork survives scene replacements, preserving the earlier menu warm-up and hero reuse. Input is gated during partial construction. Replacing a loading layer cancels its old fade tween. Final scene exit drains the save worker and releases retained UI resources; Store/Menu reference cycles are broken on exit.

## Validation

- Godot 4.3 stable, Vulkan Forward+, RTX 4090, High preset. Timings measure menu action through world/menu warm-up plus six settling frames, excluding the loading fade. Maximum frame interval is not physical input latency. Recording is a separate run and excluded from timings.
- Exported pack: all 20 directed pairs correct, clean process exit; five visible map selections recorded with pagination and completed-loading teardown.
- Rendered gameplay regression: all 20 pairs and 12 scripted starts/forced finishes/returns, including solo and split-screen on all five maps; zero failures. Checks map/card/season, single game root, preserved volume/difficulty, completed loading, and advancing simulation clock.
- Focused loading replacement and solo/split return regression: zero failures, no stale fade callback errors.
- Options, store and menu-flow tests pass; reload-menu test passes. All-menu probe: 144 actions, average 16.096 ms, maximum 39.569 ms to next draw.
- Godot import: no script errors. Seed-7 full bot match completed, draw 0-0, simulation time 720 seconds, overtime. Existing headless shutdown resource warnings are recorded; no script errors.
- Fixed-seed visual/collider/MultiMesh transform fingerprints match baseline exactly on every map (see adjacent JSON).
- Five gameplay stills inspected. Real viewport video and wall-clock timestamps captured from the exported build; AVI and GIF retain elapsed time.

Earlier timing probes reproduced a native teardown crash also seen in the baseline. Final scene cleanup now drains the save worker; the final packaged suite and recording both exited with code 0. The probe also now starts at map 0, waits for loading completion before teardown, and navigates the fifth card's page when recording.

## Delivery

Desktop shortcut: `Play Crowns - Map Fix.lnk`.
Folder: `Crowns - Map Transition Fix - 1da8de3`.
Pack SHA256: `95DD2B3A3641FA81CCC7B523C66EA8D1770BC7F61CAA8F1CB7AB0DE9CB3648A7`.
Runtime SHA256: `B554BA80FB2AD8F1817BC21242AC8ADBB9E41F806C49AD5CC73603DB71FEE32F`.
Launcher retains `C:/Temp/OryPlaytests20261018/Crowns` save data. Previous menu build remains intact. Desktop files are hash-verified against the exported artifact.

Evidence in this chat's outputs: `map-transition-timings.csv`, `map-transition-results.json`, `map-transition-preview.gif`, `map-transition-video.avi`, and `map-gameplay/`.

Not retested: browser export, physical controllers, online multiplayer. The map tests use scripted input and forced finishes, not twelve full human-played matches. Owner review/integration remains pending.
