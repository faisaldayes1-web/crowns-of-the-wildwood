# World pass status and remaining target gaps

Agent: Codex-faisal/world. READY for review in PR #76. This is a partial build toward the approved targets, not full target fidelity.

The default title now uses `assets/ui/menu/title_picked_a_clean.png`: a built-in imagegen derivative of approved GAME title A with all baked UI and the logo removed. Controls and logo are independently rendered native game UI. The native 3D title is optional behind `--debug-native-title`; it is not built in the default path. Exact source, edit prompt, output and asset hash are in `title-backdrop-provenance.json`. No paid APIs, Meshy or PixelLab credits were used.

Reviewed the published [seven-screen comparisons](https://github.com/faisaldayes1-web/crowns-of-the-wildwood/blob/Codex-faisal/crowns-visual-evidence/docs/visual/2026-10-27-pass/COMPARISONS.md), including the actual title and match-spawn images. These are integrated evidence, not this PR alone. The comparison document identifies desktop source `c6c4e84` and mobile source `659ab86` and says a later touch revision still needs replacement captures.

| Surface | Built change | Remaining gap |
|---|---|---|
| Title A | Clean selected A raster background with independent native controls; actual comparison shows intended castle, forest, stream and foreground knight | Static backdrop, not playable 3D geometry; title success does not establish gameplay fidelity |
| Map hall A | Shared world texture family, cooler ambient fill and gentler contrast | Pillar geometry remains simpler than target |
| Spawn D | Chamfered square station bases, thicker sign posts/crossbeams, two low carved boundary courses and alternating cap blocks; original colliders and station coordinates retained | Actual capture still has flatter floor/material relief and simpler canopy shapes than target |
| Battle A | Shared courtyard material and structure improvements | Layered small-leaf foliage, physical floor relief and target contact-lighting depth remain incomplete |
| Paused B / knight B | Shared emerald cloth and gold family at station panels | Extensive cloth perimeter and stitched detail remain incomplete; UI layout belongs to the UI lane |

Earlier native-title renders showed oversized roof flags, flat grey stone, poor framing and foreground hero overlap. The optional debug scene now has a higher camera, smaller hero, native pennants and bevelled tower courses, but it remains below selected A. It is retained for further development, not presented as the finished title.

World-helper validation before integration: Godot 4.3 import and menu boot completed; generated bevel normals face outward; check-only passed for game, menu stage and title scripts after explicit material typing. Root owns integrated bot/render/mobile validation. Earlier native-title measurements (707 scenery meshes batched to 106, 747.9 MB static memory and 16,277 nodes at menu ready) describe the superseded native-default configuration and must not be attributed to the final raster-default path. Earlier shutdown resource warnings were forwarded to root's parallel #75 work.
