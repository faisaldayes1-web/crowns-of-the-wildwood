"""Painted cloth fields for the player banners (Faisal 2026-10-14 20:48:
more player banners, "real painted art rather than vector glyphs").

    python3 tools/make_banner_art.py

Writes assets/ui/banners/bg_<name>.png (640x140). Each field is built
from soft brush strokes over blurred noise, so it reads as painted cloth
under the banner's frame, emblem and name. Stats.BANNER_BACKGROUNDS
points at them with the pattern "painted:<name>".
"""
import math
import os
import random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageChops

W, H = 640, 140
OUT = "assets/ui/banners/"


def noise(seed, scale, w=W, h=H):
    r = np.random.default_rng(seed)
    small = r.random((max(2, h // scale), max(2, w // scale)))
    im = Image.fromarray((small * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)
    return np.asarray(im.filter(ImageFilter.GaussianBlur(scale / 3))).astype(float) / 255.0


def grad(c_top, c_bot):
    t = np.linspace(0, 1, H)[:, None, None]
    return np.array(c_top, float)[None, None] * (1 - t) + np.array(c_bot, float)[None, None] * t * np.ones((1, W, 1))


def base(c_top, c_bot, seed, var=0.18):
    a = grad(c_top, c_bot) * np.ones((H, W, 3))
    n = noise(seed, 40) * 0.6 + noise(seed + 1, 12) * 0.4
    a *= (1 - var) + var * 2 * n[..., None]
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)).convert("RGBA")


def strokes(im, seed, colors, n=120, length=(30, 90), width=(4, 12), angle=(-0.4, 0.4), alpha=(40, 110), blur=1.4, region=None):
    rnd = random.Random(seed)
    layer = Image.new("RGBA", im.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for _ in range(n):
        x = rnd.uniform(-20, W + 20)
        y = rnd.uniform(-10, H + 10)
        if region and not region(x, y):
            continue
        L = rnd.uniform(*length)
        a = rnd.uniform(*angle)
        w = rnd.uniform(*width)
        c = rnd.choice(colors)
        d.line((x, y, x + math.cos(a) * L, y + math.sin(a) * L), fill=tuple(c) + (int(rnd.uniform(*alpha)),), width=int(w))
    return Image.alpha_composite(im, layer.filter(ImageFilter.GaussianBlur(blur)))


def glow(im, pts, color, radius, alpha=160):
    layer = Image.new("RGBA", im.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for x, y, r in pts:
        d.ellipse((x - r * radius, y - r * radius, x + r * radius, y + r * radius), fill=tuple(color) + (alpha,))
    return Image.alpha_composite(im, layer.filter(ImageFilter.GaussianBlur(radius * 0.6)))


def finish(im, name, tint=None):
    # Canvas grain, a soft vignette and a cloth sheen across the top.
    a = np.asarray(im.convert("RGB")).astype(float)
    g = np.random.default_rng(7).normal(0, 5, (H, W, 1))
    a += g
    y = np.linspace(-1, 1, H)[:, None]
    x = np.linspace(-1, 1, W)[None, :]
    v = 1 - 0.28 * (x ** 2) ** 1.5 - 0.22 * y ** 2
    a *= v[..., None]
    sheen = np.exp(-((y + 0.55) ** 2) / 0.05) * 22
    a += sheen[..., None]
    Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)).save(OUT + "bg_" + name + ".png", optimize=True)


def leaf(d, x, y, s, ang, col):
    pts = []
    for i in range(13):
        t = i / 12 * math.pi * 2
        r = s * (0.5 + 0.5 * abs(math.sin(t / 2))) if False else s
        px = math.cos(t) * s
        py = math.sin(t) * s * 0.42
        pts.append((x + px * math.cos(ang) - py * math.sin(ang), y + px * math.sin(ang) + py * math.cos(ang)))
    d.polygon(pts, fill=col)
    d.line((x - math.cos(ang) * s, y - math.sin(ang) * s, x + math.cos(ang) * s, y + math.sin(ang) * s), fill=(0, 0, 0, 60), width=1)


def make_all():
    os.makedirs(OUT, exist_ok=True)
    R = random.Random(3)

    # --- Elves -------------------------------------------------------------
    im = base((22, 62, 58), (8, 26, 30), 11)
    im = glow(im, [(520, 34, 1.0)], (220, 235, 255), 26, 220)
    im = glow(im, [(520, 34, 2.4)], (150, 200, 230), 26, 70)
    d = ImageDraw.Draw(im)
    for i in range(9):   # silver trees
        x = 30 + i * 70 + R.uniform(-12, 12)
        h = R.uniform(70, 130)
        d.line((x, H, x, H - h), fill=(10, 30, 32, 255), width=9)
        for k in range(5):
            yy = H - h + k * h / 6
            d.line((x, yy, x + R.choice([-1, 1]) * R.uniform(14, 30), yy - R.uniform(8, 18)), fill=(10, 30, 32, 255), width=4)
    im = strokes(im, 12, [(140, 200, 190), (90, 160, 150)], n=60, length=(20, 50), width=(2, 5), alpha=(30, 70))
    finish(im, "moonlit_grove")

    im = base((120, 52, 18), (60, 20, 10), 21)
    d = ImageDraw.Draw(im)
    for i in range(70):
        leaf(d, R.uniform(0, W), R.uniform(0, H), R.uniform(7, 15), R.uniform(0, 6.3),
             R.choice([(230, 120, 30, 200), (200, 70, 20, 200), (240, 180, 50, 190), (150, 40, 20, 200)]))
    im = im.filter(ImageFilter.GaussianBlur(0.6))
    im = strokes(im, 22, [(255, 200, 120)], n=40, alpha=(15, 40))
    finish(im, "autumn_leaves")

    im = base((12, 40, 30), (4, 16, 14), 31)
    im = strokes(im, 32, [(30, 90, 60), (20, 70, 50)], n=90, length=(40, 120), width=(6, 16), alpha=(40, 90))
    pts = [(R.uniform(0, W), R.uniform(0, H), R.uniform(0.4, 1.0)) for _ in range(45)]
    im = glow(im, pts, (200, 255, 140), 18, 120)
    im = glow(im, [(x, y, r * 0.3) for x, y, r in pts], (255, 255, 220), 12, 255)
    finish(im, "fae_lights")

    im = base((26, 54, 30), (12, 30, 16), 41)
    d = ImageDraw.Draw(im)
    for k in range(4):
        yb = 20 + k * 34
        pts = [(x, yb + 12 * math.sin(x / 38 + k)) for x in range(-10, W + 10, 6)]
        d.line(pts, fill=(60, 110, 50, 255), width=5)
        d.line(pts, fill=(110, 170, 80, 160), width=2)
        for x in range(0, W, 22):
            y = yb + 12 * math.sin(x / 38 + k)
            d.polygon([(x, y - 3), (x + 4, y - 11), (x + 6, y - 2)], fill=(150, 190, 110, 230))
    for i in range(30):
        leaf(d, R.uniform(0, W), R.uniform(0, H), R.uniform(5, 9), R.uniform(0, 6.3), (80, 150, 60, 220))
    finish(im.filter(ImageFilter.GaussianBlur(0.5)), "thornweave")

    im = base((10, 18, 40), (6, 10, 22), 51)
    for k, col in enumerate([(60, 230, 160), (120, 120, 255), (200, 90, 230)]):
        layer = Image.new("RGBA", im.size, (0, 0, 0, 0))
        dl = ImageDraw.Draw(layer)
        pts = [(x, 40 + k * 18 + 20 * math.sin(x / 70 + k * 1.7)) for x in range(-20, W + 20, 8)]
        for w, a in ((40, 50), (20, 90), (8, 140)):
            dl.line(pts, fill=col + (a,), width=w)
        im = Image.alpha_composite(im, layer.filter(ImageFilter.GaussianBlur(10)))
    im = glow(im, [(R.uniform(0, W), R.uniform(0, H * 0.5), R.uniform(0.2, 0.5)) for _ in range(40)], (255, 255, 255), 4, 220)
    finish(im, "aurora")

    # --- Humans ------------------------------------------------------------
    im = Image.new("RGBA", (W, H))
    d = ImageDraw.Draw(im)
    for qx in range(2):
        for qy in range(2):
            col = (150, 24, 30) if (qx + qy) % 2 == 0 else (210, 160, 50)
            d.rectangle((qx * W // 2, qy * H // 2, (qx + 1) * W // 2, (qy + 1) * H // 2), fill=col + (255,))
    n = noise(61, 20)
    a = np.asarray(im).astype(float)
    a[..., :3] *= (0.85 + 0.3 * n)[..., None]
    im = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))
    im = strokes(im, 62, [(255, 230, 160), (90, 10, 10)], n=120, alpha=(15, 45))
    finish(im, "quartered")

    im = base((40, 70, 150), (20, 36, 90), 71)
    d = ImageDraw.Draw(im)
    for i in range(-2, 12):
        x = i * 70
        d.polygon([(x, H), (x + 35, H * 0.25), (x + 70, H), (x + 56, H), (x + 35, H * 0.5), (x + 14, H)], fill=(235, 235, 225, 210))
    im = strokes(im.filter(ImageFilter.GaussianBlur(0.7)), 72, [(255, 255, 255), (20, 30, 80)], n=100, alpha=(12, 40))
    finish(im, "chevron")

    im = Image.new("RGBA", (W, H))
    d = ImageDraw.Draw(im)
    s = 28
    for y in range(0, H, s):
        for x in range(0, W, s):
            col = (30, 50, 120) if ((x // s) + (y // s)) % 2 else (200, 170, 80)
            d.rectangle((x, y, x + s, y + s), fill=col + (255,))
    a = np.asarray(im).astype(float)
    a[..., :3] *= (0.8 + 0.4 * noise(81, 16))[..., None]
    im = strokes(Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)), 82, [(255, 240, 200), (10, 20, 50)], n=140, alpha=(10, 40))
    finish(im, "checky")

    im = base((120, 118, 112), (70, 68, 66), 91, 0.25)
    d = ImageDraw.Draw(im)
    bh = 22
    for row in range(H // bh + 1):
        off = (row % 2) * 30
        for x in range(-60, W + 60, 60):
            sh = R.uniform(-18, 18)
            d.rectangle((x + off + 2, row * bh + 2, x + off + 58, row * bh + bh - 1), fill=(int(110 + sh), int(108 + sh), int(102 + sh), 255))
    for x in range(0, W, 3):
        pass
    im = strokes(im, 92, [(60, 58, 55), (160, 158, 150)], n=200, length=(6, 20), width=(2, 4), alpha=(30, 80))
    im = glow(im, [(R.uniform(0, W), R.uniform(0, H), 1) for _ in range(6)], (80, 110, 50), 14, 60)
    finish(im, "stone_keep")

    im = base((110, 14, 28), (60, 6, 16), 101)
    d = ImageDraw.Draw(im)
    for y in range(-10, H + 20, 46):
        for x in range(-20, W + 40, 52):
            ox = 26 if (y // 46) % 2 else 0
            cx, cy = x + ox, y
            for k in range(4):
                a = k * math.pi / 2
                d.ellipse((cx + math.cos(a) * 10 - 7, cy + math.sin(a) * 10 - 7, cx + math.cos(a) * 10 + 7, cy + math.sin(a) * 10 + 7), outline=(210, 160, 70, 150), width=2)
            d.ellipse((cx - 4, cy - 4, cx + 4, cy + 4), fill=(230, 180, 80, 170))
    im = strokes(im.filter(ImageFilter.GaussianBlur(0.4)), 102, [(255, 200, 120), (40, 0, 10)], n=100, alpha=(10, 35))
    finish(im, "royal_damask")

    # --- Rare (both sides) --------------------------------------------------
    im = base((60, 10, 4), (20, 2, 0), 111)
    for k, col in enumerate([(200, 50, 10, 170), (255, 140, 30, 170), (255, 225, 120, 180)]):
        layer = Image.new("RGBA", im.size, (0, 0, 0, 0))
        dl = ImageDraw.Draw(layer)
        for i in range(34):
            x = R.uniform(-10, W + 10)
            h = R.uniform(50, 130) * (1.0 - k * 0.25)
            w = R.uniform(14, 26) * (1.0 - k * 0.2)
            bend = R.uniform(-20, 20)
            pts = []
            for j in range(13):
                t = j / 12
                yy = H - t * h
                ww = w * (1 - t) ** 0.8
                pts.append((x - ww + bend * t * t + 6 * math.sin(t * 6 + i), yy))
            for j in range(12, -1, -1):
                t = j / 12
                yy = H - t * h
                ww = w * (1 - t) ** 0.8
                pts.append((x + ww + bend * t * t + 6 * math.sin(t * 6 + i), yy))
            dl.polygon(pts, fill=col)
        im = Image.alpha_composite(im, layer.filter(ImageFilter.GaussianBlur(5 - k * 1.2)))
    im = glow(im, [(R.uniform(0, W), R.uniform(0, H * 0.7), R.uniform(0.2, 0.4)) for _ in range(40)], (255, 200, 90), 5, 230)
    finish(im, "dragonfire")

    im = base((14, 12, 40), (4, 4, 16), 121)
    im = strokes(im, 122, [(70, 50, 140), (30, 60, 120)], n=60, length=(80, 200), width=(20, 40), alpha=(30, 60), blur=12)
    im = glow(im, [(R.uniform(0, W), R.uniform(0, H), R.uniform(0.15, 0.4)) for _ in range(90)], (255, 255, 255), 4, 255)
    d = ImageDraw.Draw(im)
    for i in range(4):
        x, y = R.uniform(100, W), R.uniform(10, 60)
        layer = Image.new("RGBA", im.size, (0, 0, 0, 0))
        ImageDraw.Draw(layer).line((x, y, x - 120, y + 50), fill=(200, 220, 255, 160), width=3)
        im = Image.alpha_composite(im, layer.filter(ImageFilter.GaussianBlur(2)))
        im = glow(im, [(x, y, 1)], (255, 255, 255), 5, 255)
    finish(im, "starfall")

    im = base((40, 46, 60), (16, 18, 26), 131, 0.35)
    im = strokes(im, 132, [(90, 96, 110), (30, 32, 40)], n=80, length=(60, 160), width=(16, 30), alpha=(40, 90), blur=8)
    layer = Image.new("RGBA", im.size, (0, 0, 0, 0))
    dl = ImageDraw.Draw(layer)
    for b in range(2):
        x, y = R.uniform(150, W - 100), 0
        pts = [(x, y)]
        while y < H:
            x += R.uniform(-22, 22)
            y += R.uniform(12, 24)
            pts.append((x, y))
        dl.line(pts, fill=(190, 220, 255, 255), width=3)
    im = Image.alpha_composite(im, layer.filter(ImageFilter.GaussianBlur(5)))
    im = Image.alpha_composite(im, layer)
    finish(im, "storm")

    im = base((70, 130, 170), (30, 60, 100), 141)
    d = ImageDraw.Draw(im)
    for i in range(22):
        x = R.uniform(0, W)
        h = R.uniform(40, 110)
        w = R.uniform(10, 22)
        d.polygon([(x - w, H), (x, H - h), (x + w, H)], fill=(200, 235, 255, 150))
        d.polygon([(x, H), (x, H - h), (x + w, H)], fill=(120, 180, 230, 150))
    im = glow(im.filter(ImageFilter.GaussianBlur(0.6)), [(R.uniform(0, W), R.uniform(0, H), R.uniform(0.2, 0.5)) for _ in range(30)], (255, 255, 255), 4, 230)
    finish(im, "crystal")

    im = base((120, 80, 20), (60, 36, 6), 151)
    d = ImageDraw.Draw(im)
    for i in range(160):
        x, y = R.uniform(0, W), H - abs(R.gauss(0, 50))
        r = R.uniform(5, 9)
        d.ellipse((x - r, y - r * 0.6, x + r, y + r * 0.6), fill=(150, 100, 20, 255))
        d.ellipse((x - r + 1, y - r * 0.6, x + r - 1, y + r * 0.45), fill=(240, 190, 70, 255))
        d.ellipse((x - r * 0.5, y - r * 0.4, x + r * 0.2, y), fill=(255, 240, 170, 200))
    im = glow(im, [(R.uniform(0, W), R.uniform(H * 0.4, H), R.uniform(0.2, 0.5)) for _ in range(25)], (255, 250, 210), 5, 230)
    finish(im, "golden_hoard")

    im = base((60, 40, 80), (20, 10, 30), 161)
    im = strokes(im, 162, [(70, 50, 90), (40, 30, 60), (110, 70, 130)], n=90, length=(60, 180), width=(14, 30), angle=(-1.0, 1.0), alpha=(30, 70), blur=10)
    im = glow(im, [(R.uniform(0, W), R.uniform(0, H), R.uniform(0.3, 0.7)) for _ in range(12)], (170, 80, 220), 20, 110)
    finish(im, "shadow")


if __name__ == "__main__":
    make_all()
    print(len(os.listdir(OUT)), "fields")
