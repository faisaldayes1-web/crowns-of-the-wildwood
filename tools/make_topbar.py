"""Cut the match top bar (score bands, crest shields, clock frame and the
parchment info strip) out of the owner's UI reference art and clean it up:
the baked-in names, scores, clock and info text are painted out, the
grass around it is made transparent, and the result is saved as
assets/ui/topbar/topbar.png for hud.gd to draw its own text on.

    python3 tools/make_topbar.py [reference.jpg]

Coordinates are in the reference's own pixels (2576 x 1438).
"""
import sys
from collections import deque

import numpy as np
from PIL import Image, ImageFilter

REF = sys.argv[1] if len(sys.argv) > 1 else "/mnt/project-files/game/reference-renders/ui-target-2026-10-08.jpg"
OUT = "assets/ui/topbar/topbar.png"
X0, Y0, X1, Y1 = 560, 0, 2020, 206   # crop box


def stretch_fill(a, x0, x1, y0, y1, src_cols):
    """Replace a[y0:y1, x0:x1] with the average of some clean columns,
    repeated across: the bands, the clock's inside and the parchment are
    all shaded top to bottom and flat left to right."""
    col = np.mean([a[y0:y1, c, :] for c in src_cols], axis=0)
    a[y0:y1, x0:x1, :] = col[:, None, :]


def main():
    im = Image.open(REF).convert("RGB").crop((X0, Y0, X1, Y1))
    a = np.asarray(im).astype(np.float32)
    # Text out (crop coordinates).
    stretch_fill(a, 318, 512, 34, 128, [300, 304, 308])          # ELVES 23
    stretch_fill(a, 960, 1140, 34, 128, [1150, 1154, 1158])      # HUMANS 19
    # The clock's dark inside: a smooth brown fall-off from the clean colour
    # just above the text, darkening downwards.
    top = a[46:50, 700:780, :].reshape(-1, 3).mean(axis=0)
    for i, y in enumerate(range(50, 144)):
        t = i / 93.0
        a[y, 628:846, :] = top * (1.0 - 0.35 * t)
    stretch_fill(a, 262, 1272, 170, 208, [258, 260, 1280, 1284]) # info line (and the pickup crown over it)
    rgb = np.clip(a, 0, 255).astype(np.uint8)

    # Transparent background: flood from the crop's edges over grassy
    # greens and the dark shade under the bar; the gold rims stop it, so
    # the green stag inside the red shield stays.
    hsv = np.asarray(Image.fromarray(rgb).convert("HSV")).astype(np.float32)
    h, s, v = hsv[..., 0] * 360 / 255, hsv[..., 1] / 255, hsv[..., 2] / 255
    grass = ((h > 38) & (h < 185) & (s > 0.12)) | (v < 0.2)
    H, W = grass.shape
    bg = np.zeros_like(grass)
    q = deque()
    for x in range(W):
        for y in (0, H - 1):
            if grass[y, x]:
                q.append((y, x))
    for y in range(H):
        for x in (0, W - 1):
            if grass[y, x]:
                q.append((y, x))
    for p in q:
        bg[p] = True
    while q:
        y, x = q.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < H and 0 <= nx < W and not bg[ny, nx] and grass[ny, nx]:
                bg[ny, nx] = True
                q.append((ny, nx))
    # The sunlit grass in the gap under the Humans band reads too yellow
    # for the flood; clear that gap outright.
    bg[153:168, 895:1285] = True
    alpha = Image.fromarray(np.where(bg, 0, 255).astype(np.uint8))
    # Close small holes, then soften the edge a touch.
    alpha = alpha.filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.MinFilter(5)).filter(ImageFilter.GaussianBlur(0.8))
    out = Image.fromarray(rgb).convert("RGBA")
    out.putalpha(alpha)
    import os
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    out.save(OUT)
    print("wrote", OUT, out.size)


if __name__ == "__main__":
    main()
