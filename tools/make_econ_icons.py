"""Economy icons in the HUD's painted style (same look as tools/make_icons.py:
gradient fills, thick ink outlines, a soft halo and a gloss streak), on
transparent 128x128 PNGs in assets/ui/icons. Run from the project root:
    python3 tools/make_econ_icons.py
Writes wood.png (a stack of three cut logs) and training.png (a laurel
wreath round a rising chevron and a star: Veteran Training).
"""
from PIL import Image, ImageDraw, ImageFilter
import math

OUT = "assets/ui/icons"
SS = 4
N = 128 * SS
C = N / 2
INK = (28, 20, 34)
GOLD = (255, 204, 64)
GOLD_D = (160, 105, 20)


def new():
    return Image.new("RGBA", (N, N), (0, 0, 0, 0))


def P(x, y):
    """A point in a -1..1 box."""
    return (C + x * C * 0.78, C + y * C * 0.78)


def R(r):
    return r * C * 0.78


def gradient(c1, c2):
    g = Image.new("RGBA", (N, N))
    d = ImageDraw.Draw(g)
    for i in range(N):
        t = i / (N - 1)
        d.line([(0, i), (N, i)], fill=tuple(int(c1[k] + (c2[k] - c1[k]) * t) for k in range(3)) + (255,))
    return g


def poly(img, points, c1, c2=None, outline=INK, width=5):
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).polygon(points, fill=255)
    img.paste(gradient(c1, c2 or c1), (0, 0), mask)
    if outline:
        ImageDraw.Draw(img).line(points + [points[0]], fill=outline + (255,), width=width * SS, joint="curve")


def disc(img, c, r, c1, c2=None, outline=INK, width=5):
    mask = Image.new("L", img.size, 0)
    box = [c[0] - r, c[1] - r, c[0] + r, c[1] + r]
    ImageDraw.Draw(mask).ellipse(box, fill=255)
    img.paste(gradient(c1, c2 or c1), (0, 0), mask)
    if outline:
        ImageDraw.Draw(img).ellipse(box, outline=outline + (255,), width=width * SS)


def ring(img, c, r, color, width):
    ImageDraw.Draw(img).ellipse([c[0] - r, c[1] - r, c[0] + r, c[1] + r], outline=color + (255,), width=int(width * SS))


def glow(img, color, radius=16):
    halo = Image.new("RGBA", img.size, color + (0,))
    halo.putalpha(img.split()[3].filter(ImageFilter.GaussianBlur(radius * SS)).point(lambda a: min(255, int(a * 1.6))))
    return Image.alpha_composite(halo, img)


def shine(img):
    hl = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(hl).ellipse([C * 0.35, C * 0.3, C * 0.95, C * 0.7], fill=(255, 255, 255, 60))
    hl = hl.filter(ImageFilter.GaussianBlur(6 * SS))
    out = img.copy()
    out.paste(hl, (0, 0), Image.composite(hl.split()[3], Image.new("L", img.size, 0), img.split()[3]))
    return out


def save(img, name, halo):
    img = shine(glow(img, halo))
    img.resize((128, 128), Image.LANCZOS).save(f"{OUT}/{name}.png")
    print("wrote", name)


def log_end(img, x, y, r):
    """A log seen end on: bark rim, pale cut face, growth rings, a crack."""
    c = P(x, y)
    disc(img, c, R(r), (150, 92, 48), (92, 52, 24))                     # bark
    disc(img, c, R(r * 0.78), (255, 222, 158), (226, 170, 96), None)      # cut face
    ring(img, c, R(r * 0.55), (196, 132, 70), 2.6)
    ring(img, c, R(r * 0.32), (196, 132, 70), 2.2)
    disc(img, c, R(r * 0.1), (170, 108, 54), None, None)
    ImageDraw.Draw(img).line([P(x + r * 0.1, y - r * 0.05), P(x + r * 0.62, y - r * 0.4)], fill=(150, 96, 48, 255), width=3 * SS)


# --- Wood: three logs stacked end on, a sprig of leaves on top ---------------
img = new()
log_end(img, -0.4, 0.3, 0.46)
log_end(img, 0.42, 0.3, 0.46)
log_end(img, 0.01, -0.38, 0.46)
leaf = [P(0.22, -0.84), P(0.52, -1.0), P(0.8, -0.92), P(0.56, -0.74)]
poly(img, leaf, (140, 225, 90), (50, 140, 40), width=4)
ImageDraw.Draw(img).line([P(0.24, -0.83), P(0.72, -0.92)], fill=(40, 110, 40, 255), width=2 * SS)
save(img, "wood", (255, 190, 110))

# --- Training: laurel wreath, rising gold chevron and a star -----------------
img = new()
for side in (-1, 1):
    a0, a1 = (100, 250) if side < 0 else (-70, 80)
    box = [P(-0.78, -0.73)[0], P(-0.78, -0.73)[1], P(0.78, 0.83)[0], P(0.78, 0.83)[1]]
    ImageDraw.Draw(img).arc(box, a0, a1, fill=INK + (255,), width=9 * SS)
    ImageDraw.Draw(img).arc(box, a0, a1, fill=(110, 80, 30, 255), width=4 * SS)
for side in (-1, 1):
    for k in range(5):
        a = math.radians(200 - k * 28) if side < 0 else math.radians(-20 + k * 28)
        cx, cy = 0.78 * math.cos(a), 0.78 * math.sin(a) * -1 + 0.05
        rot = a + (math.pi / 2 if side < 0 else -math.pi / 2)
        pts = []
        for px, py in [(0, -0.27), (0.15, 0), (0, 0.27), (-0.15, 0)]:
            rx = px * math.cos(rot) - py * math.sin(rot)
            ry = px * math.sin(rot) + py * math.cos(rot)
            pts.append(P(cx + rx, cy + ry))
        poly(img, pts, (150, 230, 100), (60, 150, 45), width=4)
chev = [P(-0.5, 0.5), P(0.0, 0.1), P(0.5, 0.5), P(0.5, 0.8), P(0.0, 0.42), P(-0.5, 0.8)]
poly(img, chev, GOLD, GOLD_D)
star = []
for i in range(10):
    a = -math.pi / 2 + i * math.pi / 5
    r = 0.5 if i % 2 == 0 else 0.22
    star.append(P(r * math.cos(a), -0.32 + r * math.sin(a)))
poly(img, star, (255, 236, 140), GOLD_D)
save(img, "training", (255, 215, 110))
