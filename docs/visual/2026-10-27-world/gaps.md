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
