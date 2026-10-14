"""Centre every icon on its subject, and write halo-free copies for the
ability bar (Faisal 2026-10-14 18:16: "make sure the icons are not off
centered").

    python3 tools/center_icons.py

The icons cut from Faisal's 2026-10-14 sheet sit on a painted smudge
(burnt-paper halo) that is lopsided, so a piece centred by its whole
outline still looks off centre. The subject is the black-outlined object:
the largest dark outline, holes filled. Each icons/<name>.png is shifted so
that subject's box is centred (the halo goes with it), and
icons_clean/<name>.png keeps only the subject (halo faded off over 3 px)
for the hexagon slots, whose tile is the backing.
"""
import glob
import os
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

SRC = "assets/ui/icons/"
CLEAN = "assets/ui/icons_clean/"


def subject(a):
    """The bright, saturated object plus its black outline; the dull halo
    round it is left out."""
    rgb = a[..., :3].astype(int)
    mx = rgb.max(2)
    mn = rgb.min(2)
    al = a[..., 3]
    vivid = ((mx > 150) | ((mx - mn) > 90) | (mx > 120) & ((mx - mn) < 25)) & (al > 200)
    vivid = ndimage.binary_opening(vivid, iterations=1)
    vivid = ndimage.binary_closing(vivid, iterations=4)
    vivid = ndimage.binary_fill_holes(vivid)
    lab, n = ndimage.label(vivid)
    if n == 0:
        return None
    sizes = ndimage.sum(vivid, lab, range(1, n + 1))
    keep = np.isin(lab, [i + 1 for i, s in enumerate(sizes) if s >= 0.05 * sizes.max()])
    # the black outline round it
    return ndimage.binary_dilation(keep, iterations=6) & (al > 40)


def main():
    os.makedirs(CLEAN, exist_ok=True)
    moved = []
    for f in sorted(glob.glob(SRC + "*.png")):
        im = Image.open(f).convert("RGBA")
        a = np.asarray(im)
        m = subject(a)
        if m is None or not m.any():
            continue
        ys, xs = np.nonzero(m)
        h, w = m.shape
        dx = int(round(w / 2 - (xs.min() + xs.max() + 1) / 2))
        dy = int(round(h / 2 - (ys.min() + ys.max() + 1) / 2))
        if abs(dx) > 1 or abs(dy) > 1:
            out = Image.new("RGBA", im.size, (0, 0, 0, 0))
            out.alpha_composite(im, (dx, dy)) if dx >= 0 and dy >= 0 else out.paste(im, (dx, dy), im)
            out.save(f)
            moved.append((os.path.basename(f), dx, dy))
            a = np.asarray(out)
            m = np.roll(np.roll(m, dy, 0), dx, 1)
        soft = Image.fromarray((ndimage.binary_dilation(m, iterations=2) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.2))
        al = (np.asarray(soft).astype(float) / 255.0 * a[..., 3]).astype(np.uint8)
        Image.fromarray(np.dstack([a[..., :3], al]), "RGBA").save(CLEAN + os.path.basename(f))
    for n, dx, dy in moved:
        print("moved %-22s dx %+d dy %+d" % (n, dx, dy))
    print(len(moved), "moved")


if __name__ == "__main__":
    main()
