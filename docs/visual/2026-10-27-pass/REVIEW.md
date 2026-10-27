# Crowns picked visual pass

Agent: Codex-faisal. Implementation review; final visual acceptance remains Faisal's.

The three dedicated lanes implement the October 25 selections in the existing Godot game. The title uses a cleaned derivative of selected GAME A behind functional native UI D. World and character surfaces share cream stone, warm timber/gold, emerald and blue cloth, with satin armour and matte skin/cloth. Menus and HUD use the chosen structures. No topology or character rig replacement is included.

Open [the side-by-side gallery](review/index.html), [image comparison tables](COMPARISONS.md), or [phone-size captures](MOBILE.md). [Handoff and pending checks](HANDOFF.md) record the final renderer gate. These are actual Godot viewport captures. The menu harness invokes existing handlers and sets review states; it is not physical-input evidence. The selected battle reference is a quiet courtyard, so its matching comparison is also a courtyard; a separate natural bot combat capture is prepared but awaits the shared renderer reservation.

## Target gaps

| Screen | Built change | Remaining gap against the picked image |
|---|---|---|
| Title: GAME A / UI D | Clean selected scene; independent top strip, right action stack and lower-left utilities | Background is a static raster scene; it is not evidence that gameplay geometry reaches title-art detail |
| Map: GAME A / UI A | Native hall materials, map cards and grouped settings shelf | Hall masonry and prop density remain simpler; title and playable hall do not yet have equal detail |
| Ready: UI A | Four native character previews, faction/ready cards and separate launch footer | Material finish improved; existing silhouettes and hall geometry retained |
| Spawn: GAME D / UI C | Carved stone courses, square station bases, stronger timber signs, corner scores and action layout | Selected canopy, layered stone relief, cloth and ground detail are richer than this build |
| Battle: GAME A / UI C | Shared world surfaces, ornate faction corners, center clock and compact action arc | Existing foliage meshes remain; no claim of complete environmental fidelity |
| Pause: GAME B / UI C | Tabs, broad map view, right legend/objective and distinct leave/resume actions | Interactive map is still the schematic renderer. The separately exported real terrain map has not replaced it |
| Knight: GAME B / UI C | Satin armour, matte cloth/skin, class announcement and separate skill/training actions | Existing approved-source models and rigs retained; physical device feel and full animation smoothness need playtesting |

## Evidence and limits

Desktop captures are 1280 x 720; phone-layout captures are 844 x 390 on a Windows renderer, not an Android/iOS device. Per-run JSON identifies the exact source revision, command, errors and isolated user-data path. Test tools fail on logged engine errors even when the process exits zero.

The unchanged-source integration bot match at 659ab86 completed naturally: Elves 2–0, simulated time 375, no engine or script errors. This qualifies the integrated world/material/desktop changes before the subsequent touch-only layout update. It is not mobile performance evidence.

PR75 separately retains the same-source MSVC runtime candidate, 56 focused rendered checks and 41 animation checks in both headless/rendered modes. No runtime is replaced by this pass, and issue68 remains open.

## Map deliverables

[Clean 4096px world map](map/wildwood-clean-4096.png), [labelled version](map/wildwood-labelled-4096.png), and [bounds JSON](map/wildwood-bounds.json) come from the real playable Wildwood map. Dynamic actors and labels are hidden in the clean export. Bounds distinguish the playable rectangle from the square capture and specify X/Z-to-UV mapping. No invented map expansion is represented.

## Generation and cost

One built-in imagegen edit removed baked UI/logo from selected title A, preserving the selected scene. Exact prompt and source/output hash: `docs/visual/2026-10-27-world/title-backdrop-provenance.json` in the world PR. No paid API, Meshy, PixelLab or ComfyUI generation was used; no external generation credits were spent. The image job staged its result outside the repository; the separate authorized implementation lane integrated the sibling asset.

This set stays in review. Do not mark picked sets accepted or move them to the vault until Faisal accepts the built result.
