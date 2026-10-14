"""Faisal's painted skill-row strips (2026-10-14 10:59, "here are all of the
skill upgrades") into the game.

    python3 tools/make_skill_strips.py <folder with strips/<slug>.png>

Each source is 1024x256 on a dark navy backdrop. The backdrop is keyed to
clear by brightness (so the art sits on the row's own plate and wash) and
the left and right ends fade out; written at 512x128 to
assets/ui/strips/<slug>.png. The HUD draws it behind the animated sparkles.
"""
import glob
import os
import sys
import numpy as np
from PIL import Image

OUT = os.environ.get("UI_OUT", "assets/ui/") + "strips/"


def key(im):
    im = im.convert("RGB").resize((512, 128), Image.LANCZOS)
    a = np.asarray(im).astype(float)
    mx = a.max(2)
    alpha = np.clip((mx - 26.0) / 70.0, 0.0, 1.0) ** 0.8
    x = np.linspace(0, 1, a.shape[1])[None, :]
    alpha *= np.clip(x / 0.18, 0, 1) * np.clip((1 - x) / 0.05, 0, 1)
    # Un-premultiply against the backdrop so the faint glow keeps its colour.
    rgb = np.clip(a, 0, 255)
    return Image.fromarray(np.dstack([rgb, alpha * 255]).astype(np.uint8), "RGBA")


def main(folder):
    os.makedirs(OUT, exist_ok=True)
    n = 0
    for f in sorted(glob.glob(os.path.join(folder, "strips", "*.png"))):
        key(Image.open(f)).save(OUT + os.path.basename(f), optimize=True)
        n += 1
    print(n, "strips")


if __name__ == "__main__":
    main(sys.argv[1])
