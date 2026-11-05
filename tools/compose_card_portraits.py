"""Class cards in the chibi style of the in-game units (Faisal 2026-11-04:
"Yes, match chibi"). Lays each real-model bust (tools/render_card_portraits.gd
-> build/card_busts/) into the existing card: same size, same gilt border,
name banner and leaves (kept from the card), over a soft painted team
backdrop. Then re-run tools/make_card_blur.py.

    python tools/compose_card_portraits.py
Agent: claude-faisal/crowns-visual2
"""
import glob
import os
from PIL import Image, ImageDraw, ImageFilter

TEAM = {"elf": ((40, 120, 70), (150, 215, 140)), "human": ((35, 70, 150), (140, 185, 240))}


def backdrop(w, h, dark, light):
    bg = Image.new("RGB", (w, h), dark)
    d = ImageDraw.Draw(bg)
    cx, cy = w * 0.5, h * 0.38
    steps = 40
    for i in range(steps):
        t = i / (steps - 1)
        r = max(w, h) * (1.0 - t) * 0.9
        col = tuple(int(dark[k] + (light[k] - dark[k]) * t) for k in range(3))
        d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=col)
    return bg.filter(ImageFilter.GaussianBlur(6))


for path in sorted(glob.glob("assets/ui/cards/*.png")):
    name = os.path.basename(path)[:-4]
    if name.endswith("_blur") or name.startswith(("crest_", "logo_")):
        continue
    bust_path = os.path.join("build", "card_busts", name + ".png")
    if not os.path.exists(bust_path):
        continue
    card = Image.open(path).convert("RGBA")
    w, h = card.size
    inset = max(10, round(w * 0.045))
    box = (inset, 7, w - inset, round(h * 0.80))
    bw, bh = box[2] - box[0], box[3] - box[1]
    dark, light = TEAM[name.split("_")[0]]
    inner = backdrop(bw, bh, dark, light).convert("RGBA")
    bust = Image.open(bust_path).convert("RGBA")
    bust = bust.crop(bust.getbbox())
    s = min(bw * 1.0 / bust.width, bh * 1.08 / bust.height)
    bust = bust.resize((round(bust.width * s), round(bust.height * s)), Image.LANCZOS)
    # A soft contact shadow, then the bust standing on the banner line.
    sh = Image.new("RGBA", inner.size, (0, 0, 0, 0))
    ImageDraw.Draw(sh).ellipse((bw * 0.18, bh - 26, bw * 0.82, bh + 6), fill=(0, 0, 0, 110))
    inner.alpha_composite(sh.filter(ImageFilter.GaussianBlur(6)))
    inner.alpha_composite(bust, ((bw - bust.width) // 2, bh - bust.height + round(bh * 0.04)))
    out = card.copy()
    # Rounded inner corners so the gilt frame still overlaps the art.
    mask = Image.new("L", inner.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, bw - 1, bh - 1), radius=10, fill=255)
    out.paste(inner, box[:2], mask)
    # The name banner, its emblem and the leaves from the original card.
    keep_y = round(h * 0.80)
    out.alpha_composite(card.crop((0, keep_y, w, h)), (0, keep_y))
    # The class emblem rises above the banner: keep it, cut to its shield.
    ex0, ex1, ey0 = round(w * 0.35), round(w * 0.65), round(h * 0.70)
    em = card.crop((ex0, ey0, ex1, keep_y + 4))
    emask = Image.new("L", em.size, 0)
    ImageDraw.Draw(emask).ellipse((2, 0, em.width - 3, em.height * 2), fill=255)
    out.paste(em, (ex0, ey0), emask.filter(ImageFilter.GaussianBlur(1)))
    out.save(path)
    print("card", name, (w, h))
