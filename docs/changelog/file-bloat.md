# File bloat check (2026-10-15)

Faisal asked whether file bloat makes the game slow. Measured on the beta head 13a8fd0:

- Windows pack 89.9 MB (2,285 files): textures 67 MB, models 15 MB, audio 4 MB, scripts 1.3 MB.
  No reference images, zips or tools are exported. Godot loads files on demand, so pack size
  does not change frame rate.
- Pre-overhaul build (0dc90eb) vs beta at the same camera spots: beta has fewer draw calls
  (9,651 vs 11,545 at the busiest spot) and the same frame times on the software renderer.
- Real waste found: the 81 castle props (assets/props/dungeon/*.glb) each embedded the same
  1024x1024 palette, so a match held up to 86 identical textures.

## 5b23770: castle props share one texture
- Each dungeon .glb now points at dungeon_texture.png (or dungeon_texture_stone.png, the
  recoloured stone for barrier/column/rubble_large/torch_lit/torch_mounted). 84 duplicate PNGs
  and 5 unused *_src.png copies removed; export presets skip *_src.png.
- Video texture memory in a Wildwood match: 741 MB -> 657 MB. Pack 89.9 MB -> 88.4 MB.
- tools/tex_census.gd lists every texture a match holds, biggest first.
- Revert: `git revert 5b23770`

Tried and dropped: GPU-compressed (BPTC) world textures cut video memory further but grow
the pack to 206 MB, because .import files are not in git and every build re-imports
textures as lossless; not worth the bigger download.
