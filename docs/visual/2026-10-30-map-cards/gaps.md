# Picked target comparison and follow-through

Agent: Codex-faisal2

Source: eight supplied triptychs in C:/Games/ORY-Candidates/Crowns/visual-pass/world/triptych. Right panels are selected targets, not engine screenshots. Final map cards are rendered from main 0158a9c's actual maps, including newly merged PR131.

| Area | Actual game / new cards | Picked target / remaining gap |
|---|---|---|
| Map thumbnails | New actual-map captures, native match materials and lighting, crisp elevated cameras. Wildwood shows three crossings; Moonlit shows moonlit approach and gate; Stonekeep frames its snowbound fortress; Ember shows the two-objective bridge network. | Target has richer canopy and stone detail than current playable geometry. No invented scenery is painted into cards. |
| Card crop and lock | 1024x960 source renders are filtered to 512x480 runtime textures to suppress grass/flower aliasing in small cards. The native Moonlit lock and level requirement remain separate UI. | Picked cards are wider and the settings panels have a different structure; this texture task does not change menu layout. |
| Map hall | PR131 added stone corner columns and torches, now present in the refreshed menu captures. | Target retains richer foreground greenery and more sculpted masonry. |
| Spawn / battle world | PR131 added paving relief and small leaf clumps while preserving the real overhead camera and green/blue identity. | Target has more physical stone bevels, canopy silhouette detail and deeper contact shading. Shader relief is not equivalent to fully modelled masonry. |
| Hits / spells | PR131 added saturated normally blended bodies under additive effects on bright maps. | Verify paired layers stay aligned through their animation; `_sprite` currently samples a separate random rotation for each flat layer. This follow-up is isolated from the card PR. |
| Carry / level-up | Crown carrier glow and progression pillars remain legible, with existing timings and semantics. | Avoid overexposing the whole player; no reason to expand banners or effect coverage. |

Capture-only settings: distance blur and atmospheric fog are disabled for elevated cameras; gameplay lighting and graphics settings remain unchanged. Actors, temporary fortify barrier and world labels are hidden in the reusable captures. Night uses the existing --debug-night flag so night lighting is real while the menu lock remains intact. Clean/labelled 4096x2304 orthographic exports share bounds JSON; image bounds are explicitly distinct from navigation bounds.

Next bounded implementation: verify/fix the paired rune-layer rotation in the new daylight effects, measured with the real world/camera and fixed-timestep captures. Broad foliage and paving geometry fidelity remains separate visual work toward the approved target, not silently claimed complete by this card pass.
