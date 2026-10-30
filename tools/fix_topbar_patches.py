"""claude-faisal/crowns-push: even out the score banner's painted-out patches
(assets/ui/topbar/topbar.png; usage: python tools/fix_topbar_patches.py <in.png> <out.png>).
Each band interior and the clock face get one smooth per-row colour (the row's
median, then smoothed vertically), replacing only pixels close to that colour,
so borders, crests, sparkles and anti-aliased edges are kept."""
import sys, statistics
from PIL import Image

src, dst = sys.argv[1], sys.argv[2]
im = Image.open(src).convert("RGBA")
px = im.load()

def is_green(c): return c[3] > 200 and c[1] > c[0] + 35 and c[1] > c[2] + 35
def is_blue(c): return c[3] > 200 and c[2] > c[0] + 45 and c[2] > c[1] + 25
def is_dark(c): return c[3] > 200 and c[0] < 90 and c[1] < 70 and c[2] < 60 and max(c[:3]) - min(c[:3]) < 45

def rebuild(x0, x1, y0, y1, pick, tol):
    rows = {}
    for y in range(y0, y1):
        cs = [px[x, y] for x in range(x0, x1) if pick(px[x, y])]
        if len(cs) > (x1 - x0) * 0.3:
            rows[y] = tuple(int(statistics.median(c[i] for c in cs)) for i in range(3))
    ys = sorted(rows)
    smooth = {}
    for y in ys:   # 5-row moving average keeps the light-top / dark-bottom shading but drops steps
        win = [rows[v] for v in range(y - 2, y + 3) if v in rows]
        smooth[y] = tuple(int(sum(c[i] for c in win) / len(win)) for i in range(3))
    changed = 0
    for y in ys:
        t = smooth[y]
        for x in range(x0, x1):
            c = px[x, y]
            if pick(c) and sum(abs(c[i] - t[i]) for i in range(3)) < tol:
                px[x, y] = (t[0], t[1], t[2], c[3])
                changed += 1
    return changed

print("green", rebuild(185, 560, 25, 150, is_green, 90))
print("blue", rebuild(895, 1292, 25, 150, is_blue, 90))
print("clock", rebuild(590, 878, 20, 160, is_dark, 60))

# The patches also carried a short copy of the top border a few pixels inside
# each band: dark pixels with band colour both just above and just below.
def is_band(c): return is_green(c) or is_blue(c)
for x0, x1 in [(190, 555), (900, 1288)]:
    for x in range(x0, x1):
        for y in range(26, 60):
            c = px[x, y]
            if sum(c[:3]) < 260 and not is_band(c):
                above = [px[x, y - d] for d in range(1, 5) if is_band(px[x, y - d])]
                below = [px[x, y + d] for d in range(1, 5) if is_band(px[x, y + d])]
                if above and below:
                    px[x, y] = below[0][:3] + (c[3],)
im.save(dst)
