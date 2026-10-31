# Picked target comparison and follow-through

Agent: Codex-faisal2

Source: eight supplied triptychs in C:/Games/ORY-Candidates/Crowns/visual-pass/world/triptych. Right panels are selected targets, not engine screenshots. Map cards are rendered from main 354b74e's actual maps.

| Area | Actual game / new cards | Picked target / remaining gap |
|---|---|---|
| Map thumbnails | New actual-map captures, native match materials and lighting, crisp elevated cameras. Wildwood shows three crossings; Moonlit shows moonlit approach and gate; Stonekeep frames its snowbound fortress; Ember shows the two-objective bridge network. | Target has richer canopy and stone detail than current playable geometry. No invented scenery is painted into cards. |
| Card crop and lock | 1024x960 source renders are filtered to 512x480 runtime textures to suppress grass/flower aliasing in small cards. The native Moonlit lock and level requirement remain separate UI. | Picked cards are wider and the settings panels have a different structure; this texture task does not change menu layout. |
| Map hall | Current hall uses broad wall planes and existing props. | Target's framing has deeper corner columns, torch mounts and foreground greenery. |
| Spawn / battle world | Real overhead camera, cream courtyard, green/blue faction identity and existing castle layout. | Target has smaller layered leaf silhouettes, physical bevels between paving stones, stronger contact shadows and richer torch pools. Large tree crowns still read as blobs. |
| Hits / spells | Existing bright additive flares and rings can fade into pale courtyard stone. | Preserve compact hot cores but add a saturated body so effect identity survives bright surfaces; compare at the actual gameplay camera. |
| Carry / level-up | Crown carrier glow and progression pillars remain legible, with existing timings and semantics. | Avoid overexposing the whole player; no reason to expand banners or effect coverage. |

Capture-only settings: distance blur and atmospheric fog are disabled for elevated cameras; gameplay lighting and graphics settings remain unchanged. Actors, temporary fortify barrier and world labels are hidden in the reusable captures. Night uses the existing --debug-night flag so night lighting is real while the menu lock remains intact. Clean/labelled 4096x2304 orthographic exports share bounds JSON; image bounds are explicitly distinct from navigation bounds.

Next bounded implementation: effect colour contrast on pale paving, measured with the real world/camera and fixed-timestep captures. Broad foliage and paving geometry work remains a separate visual implementation toward the approved target, not silently claimed complete by this card pass.
