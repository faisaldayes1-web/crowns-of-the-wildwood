"""Turn the reds of an Elves UI picture green, keeping their shading (the
reference art painted the Elves red; they are green everywhere in the game).

    python3 tools/elves_green.py assets/ui/skills/shield_elf.png

Same rule as tools/make_topbar.py elves_green(): hue within ~20 degrees of
red, saturation > 70/255 and not near-black. Rewrites the file in place."""
import sys

import numpy as np
from PIL import Image


def main():
    path = sys.argv[1]
    im = Image.open(path).convert("RGBA")
    alpha = im.getchannel("A")
    hsv = np.asarray(im.convert("RGB").convert("HSV")).astype(np.int16).copy()
    h, s, v = hsv[..., 0], hsv[..., 1], hsv[..., 2]
    red = ((h < 14) | (h > 236)) & (s > 70) & (v > 40)
    h[red] = 88
    s[red] = np.clip(s[red] * 0.85, 0, 255).astype(np.int16)
    v[red] = np.clip(v[red] * 0.82, 0, 255).astype(np.int16)
    out = Image.fromarray(hsv.astype(np.uint8), "HSV").convert("RGBA")
    out.putalpha(alpha)
    out.save(path)


if __name__ == "__main__":
    main()
