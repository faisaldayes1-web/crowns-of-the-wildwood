"""Repaints the KayKit hexagon palette so trees, rocks, hills and flags fit
the Wildwood look: deep forest greens instead of mint, slate rocks, team
flags. The original is kept as hexagons_medieval_src.png.
Run from the project root:  python3 tools/recolor_palette.py
"""
from PIL import Image
import os, shutil

PAL = "assets/props/hex/hexagons_medieval.png"
SRC = "assets/props/hex/hexagons_medieval_src.png"
if not os.path.exists(SRC):
    shutil.copy(PAL, SRC)
img = Image.open(SRC).convert("RGBA")
px = img.load()

# (col, row): (top colour, bottom colour) of the 128x256 gradient cell.
CELLS = {
    (1, 2): ((0.46, 0.70, 0.30), (0.12, 0.32, 0.13)),   # tree foliage
    (0, 2): ((0.52, 0.66, 0.28), (0.24, 0.40, 0.14)),   # hills
    (2, 2): ((0.66, 0.70, 0.74), (0.28, 0.32, 0.40)),   # rocks
    (3, 3): ((0.36, 0.76, 0.40), (0.12, 0.38, 0.18)),   # elf flags
    (0, 3): ((0.42, 0.62, 1.00), (0.12, 0.22, 0.60)),   # human flags
    (6, 0): ((0.66, 0.44, 0.26), (0.42, 0.26, 0.14)),   # wood (crates, barrels, racks, trunks)
    (5, 0): ((0.82, 0.60, 0.38), (0.60, 0.42, 0.24)),   # light wood
    (6, 1): ((0.62, 0.52, 0.42), (0.38, 0.30, 0.22)),   # crate_B boards
    (2, 0): ((0.46, 0.46, 0.50), (0.22, 0.22, 0.26)),   # iron bands
    (2, 1): ((0.62, 0.42, 0.26), (0.40, 0.26, 0.14)),   # bark on hills
}
for (c, r), (top, bot) in CELLS.items():
    for y in range(256):
        t = y / 255.0
        col = tuple(int(255 * (top[i] * (1 - t) + bot[i] * t)) for i in range(3))
        for x in range(128):
            px[c * 128 + x, r * 256 + y] = col + (255,)
img.save(PAL)
print("wrote", PAL)
