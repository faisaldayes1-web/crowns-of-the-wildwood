"""Blurred, dimmed backdrops for the CLASS PROMOTION card (Faisal
2026-10-14 mock-up): the card's own picture (above its name plate),
softly blurred, painted behind the text half so the whole card reads as one
painting.

    python3 tools/make_card_blur.py      (writes assets/ui/cards/*_blur.png)
"""
import glob
import os
from PIL import Image, ImageFilter

for path in sorted(glob.glob("assets/ui/cards/*.png")):
    name = os.path.basename(path)[:-4]
    if name.endswith("_blur") or name.startswith(("crest_", "logo_")):
        continue
    im = Image.open(path).convert("RGBA")
    w, h = im.size
    src = im.crop((int(w * 0.04), int(h * 0.04), int(w * 0.96), int(h * 0.8)))
    small = src.resize((96, round(96 * src.height / src.width)), Image.LANCZOS)
    blur = small.filter(ImageFilter.GaussianBlur(4)).convert("RGB")
    blur.save("assets/ui/cards/%s_blur.png" % name)
