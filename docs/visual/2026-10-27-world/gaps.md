# Picked target gaps: first world implementation

Agent: Codex-faisal/world. This is a partial build toward the approved target, not a claim of target fidelity.

| Surface | Source capture / code | Picked target | Implemented first step | Remaining evidence / gap |
|---|---|---|---|---|
| Title A | Painted background covers an unused native castle/forest scene | Layered castle, stream, foreground heroes, substantial miniature masonry | Activate existing native scene; shared style textures, daylight sun, batch static scenery; keep animated armies/crown | Root must capture under UI D. Camera composition, fidelity and mobile frame cost require rendered review |
| Map hall A | Menu hall uses older material family and heavily warm fill | Warm carved masonry with clear soft shading | Use shared world texture family, cooler ambient fill and gentler contrast | Pillar geometry and native menu layout remain visibly simpler than reference |
| Spawn D | Thin sign posts, octagonal plate bases | Square masonry station footings and modular timber | Chamfered square layered bases and thickened posts/crossbeam; retain exact station coordinates and top height | Room walls, forest canopy density and stone relief still fall short |
| Battle A | Broad smooth tree blobs and flat flagstones | Layered foliage, soft bevels/contact shadows | Shared station material/detail improvements carry into battle | New foliage geometry/terrain textures not created in this PR |
| Paused B / knight B | Sparse cloth perimeter | Layered cloth and stitched runners | Shared emerald cloth and gold family at station panels | Extensive cloth perimeter and stitched geometry remain; UI owns screen arrangement |

Validation: Godot 4.3 headless import completed without script errors. Headless native-title smoke reached menu ready; 707 static scenery meshes became 106, 341 materials became 39 (98-105 ms batching). Animated crown/beam excluded; fighters/projectiles built after batching; title processing disabled off-title. Geometry probe confirms all generated bevel normals face outward. Root owns final rendered comparisons, full bot match and integrated mobile/performance qualification.

Headless smoke reported 747,903,502 static bytes and 16,277 nodes at menu-ready (11,422 ms including intentional 3-second probe wait); these are not GPU draw/memory measurements. Exit reported ObjectDB/resource cleanup warnings, forwarded to root's parallel #75 work. No renderer success claim is made from headless execution.

## Render-driven revision

Agent: Codex-faisal/world. Viewed root's actual desktop/01-title.png and desktop/04-match-spawn.png under C:/ORY-Cache/qa/crowns-visual-pass-Codex-faisal. First native title was visibly below target: giant legacy roof flag props, flat grey stone, low camera, oversized foreground knight overlapping right-hand actions, pale overfilled sky. It is not accepted as target fidelity.

Revised native title raises camera from (0,5.2,13.5) to (0,9,17), looks toward (0,6,-17), reduces foreground hero to 1.15 scale and places him at 60% width. Replaces legacy scale-7 roof flags with small native poles and pennants, retains warm stone instead of grey conversion, adds physical bevelled corner courses and foundation/cornice blocks to towers, and uses a stronger blue sky with lower cool ambient fill. Actual courtyard gains two carved masonry courses and alternating cap blocks underneath its existing timber boundary. Original colliders and class station positions remain unchanged.

This revision is source-reviewed only until root runs the serialized engine/render lane. It needs another actual capture before any quality acceptance. Prior import/boot results do not validate this revision. Added geometry is static and eligible for existing batching; new frame/memory counts must be measured after integration.
