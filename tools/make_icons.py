"""Draws the HUD icon set with PIL: ability, action, class and faction icons
in a painted style (gradient fills, dark outlines, a soft glow), on
transparent 128x128 PNGs. Run from the project root:
    python3 tools/make_icons.py
"""
from PIL import Image, ImageDraw, ImageFilter
import math, os

OUT = "assets/ui/icons"
SS = 4            # supersample
N = 128 * SS
C = N / 2

GOLD = (255, 204, 64)
GOLD_D = (160, 105, 20)
STEEL = (215, 222, 235)
STEEL_D = (95, 105, 125)
INK = (28, 20, 34)


def new():
    return Image.new("RGBA", (N, N), (0, 0, 0, 0))


def pts(seq, scale=1.0, dx=0.0, dy=0.0, rot=0.0):
    """Points given in a -1..1 box, scaled to the icon."""
    out = []
    cr, sr = math.cos(rot), math.sin(rot)
    for x, y in seq:
        rx, ry = x * cr - y * sr, x * sr + y * cr
        out.append((C + (rx * scale + dx) * C * 0.78, C + (ry * scale + dy) * C * 0.78))
    return out


def gradient(size, c1, c2, vertical=True):
    g = Image.new("RGBA", size)
    d = ImageDraw.Draw(g)
    w, h = size
    steps = h if vertical else w
    for i in range(steps):
        t = i / max(steps - 1, 1)
        col = tuple(int(c1[k] + (c2[k] - c1[k]) * t) for k in range(3)) + (255,)
        if vertical:
            d.line([(0, i), (w, i)], fill=col)
        else:
            d.line([(i, 0), (i, h)], fill=col)
    return g


def poly(img, points, c1, c2=None, outline=INK, width=None, vertical=True):
    """A polygon with a gradient fill and a dark outline."""
    c2 = c2 or c1
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).polygon(points, fill=255)
    img.paste(gradient(img.size, c1, c2, vertical), (0, 0), mask)
    if outline:
        ImageDraw.Draw(img).line(points + [points[0]], fill=outline + (255,), width=width or 5 * SS, joint="curve")


def circle(img, center, r, c1, c2=None, outline=INK, width=None):
    c2 = c2 or c1
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).ellipse([center[0] - r, center[1] - r, center[0] + r, center[1] + r], fill=255)
    img.paste(gradient(img.size, c1, c2), (0, 0), mask)
    if outline:
        ImageDraw.Draw(img).ellipse([center[0] - r, center[1] - r, center[0] + r, center[1] + r], outline=outline + (255,), width=width or 5 * SS)


def stroke(img, points, color, width):
    ImageDraw.Draw(img).line(points, fill=color + (255,), width=width, joint="curve")


def glow(img, color, radius=18, strength=1.0):
    """A soft halo in `color` behind everything drawn so far."""
    alpha = img.split()[3]
    halo = Image.new("RGBA", img.size, color + (0,))
    halo.putalpha(alpha.filter(ImageFilter.GaussianBlur(radius * SS)).point(lambda a: min(255, int(a * 1.6 * strength))))
    return Image.alpha_composite(halo, img)


def shine(img):
    """A highlight streak top-left, for a glossy painted feel."""
    hl = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(hl)
    d.ellipse([C * 0.35, C * 0.3, C * 0.95, C * 0.7], fill=(255, 255, 255, 70))
    hl = hl.filter(ImageFilter.GaussianBlur(6 * SS))
    mask = img.split()[3]
    hl.putalpha(Image.eval(hl.split()[3], lambda a: a).point(lambda a: a))
    out = img.copy()
    out.paste(hl, (0, 0), Image.composite(hl.split()[3], Image.new("L", img.size, 0), mask))
    return out


def save(img, name, halo=None):
    if halo:
        img = glow(img, halo)
    img = shine(img)
    img.resize((128, 128), Image.LANCZOS).save(f"{OUT}/{name}.png")
    print("wrote", name)


# --- Pieces ------------------------------------------------------------------

def sword(img, rot=-math.pi / 4, scale=1.0, dx=0.0, dy=0.0):
    blade = [(-0.13, 0.25), (0.13, 0.25), (0.13, -0.8), (0.0, -1.0), (-0.13, -0.8)]
    poly(img, pts(blade, scale, dx, dy, rot), STEEL, STEEL_D, vertical=False)
    stroke(img, pts([(0.0, 0.2), (0.0, -0.85)], scale, dx, dy, rot), (255, 255, 255), 3 * SS)
    guard = [(-0.45, 0.25), (0.45, 0.25), (0.45, 0.4), (-0.45, 0.4)]
    poly(img, pts(guard, scale, dx, dy, rot), GOLD, GOLD_D)
    grip = [(-0.1, 0.4), (0.1, 0.4), (0.1, 0.85), (-0.1, 0.85)]
    poly(img, pts(grip, scale, dx, dy, rot), (120, 70, 40), (70, 40, 20))
    circle(img, pts([(0, 0.95)], scale, dx, dy, rot)[0], 0.12 * C * 0.78 * scale, GOLD, GOLD_D)


def shield(img, c1, c2, scale=1.0, dx=0.0, dy=0.0):
    shape = [(-0.8, -0.75), (0.8, -0.75), (0.8, 0.05), (0.0, 0.95), (-0.8, 0.05)]
    poly(img, pts(shape, scale, dx, dy), c1, c2)
    inner = [(x * 0.68, y * 0.68 - 0.02) for x, y in shape]
    poly(img, pts(inner, scale, dx, dy), c2, c1, outline=None)
    stroke(img, pts([(0, -0.5), (0, 0.6)], scale, dx, dy), GOLD, 4 * SS)
    stroke(img, pts([(-0.5, -0.1), (0.5, -0.1)], scale, dx, dy), GOLD, 4 * SS)


def arrow(img, rot=-math.pi / 4, scale=1.0, dx=0.0, dy=0.0, color=(230, 200, 140)):
    stroke(img, pts([(0, 0.95), (0, -0.6)], scale, dx, dy, rot), INK, 9 * SS)
    stroke(img, pts([(0, 0.95), (0, -0.6)], scale, dx, dy, rot), color, 5 * SS)
    head = [(0, -1.0), (0.22, -0.55), (0, -0.65), (-0.22, -0.55)]
    poly(img, pts(head, scale, dx, dy, rot), STEEL, STEEL_D)
    for s in (-1, 1):
        fl = [(0, 0.95), (s * 0.25, 0.75), (s * 0.25, 0.95), (0, 1.1)]
        poly(img, pts(fl, scale, dx, dy, rot), (235, 90, 80), (170, 40, 40))


def star(img, points_n, r_out, r_in, c1, c2, rot=0.0, scale=1.0, dx=0.0, dy=0.0):
    seq = []
    for i in range(points_n * 2):
        a = rot + math.pi * i / points_n
        r = r_out if i % 2 == 0 else r_in
        seq.append((math.cos(a) * r, math.sin(a) * r))
    poly(img, pts(seq, scale, dx, dy), c1, c2)


def flame(img, scale=1.0, dx=0.0, dy=0.0):
    outer = [(0, -1.0), (0.35, -0.45), (0.7, -0.2), (0.75, 0.4), (0.4, 0.9), (0, 1.0), (-0.4, 0.9), (-0.75, 0.4), (-0.7, -0.2), (-0.3, -0.35)]
    poly(img, pts(outer, scale, dx, dy), (255, 180, 40), (220, 50, 20))
    inner = [(x * 0.5, y * 0.5 + 0.3) for x, y in outer]
    poly(img, pts(inner, scale, dx, dy), (255, 250, 170), (255, 170, 50), outline=None)


def chevrons(img, color, count=3, rot=0.0):
    for i in range(count):
        dx = -0.55 + i * 0.55
        seq = [(dx - 0.25, -0.7), (dx + 0.25, 0.0), (dx - 0.25, 0.7)]
        stroke(img, pts(seq, 1.0, 0, 0, rot), INK, 16 * SS)
        stroke(img, pts(seq, 1.0, 0, 0, rot), color, 9 * SS)


def heart(img, c1, c2, scale=1.0, dx=0.0, dy=0.0):
    seq = []
    for i in range(48):
        t = 2 * math.pi * i / 48
        x = 16 * math.sin(t) ** 3
        y = -(13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t))
        seq.append((x / 17.0, y / 17.0 + 0.05))
    poly(img, pts(seq, scale, dx, dy), c1, c2)


def crown(img, c1=GOLD, c2=GOLD_D, scale=1.0, dx=0.0, dy=0.0):
    seq = [(-0.85, 0.6), (-0.95, -0.5), (-0.45, 0.0), (0.0, -0.8), (0.45, 0.0), (0.95, -0.5), (0.85, 0.6)]
    poly(img, pts(seq, scale, dx, dy), c1, c2)
    poly(img, pts([(-0.85, 0.6), (0.85, 0.6), (0.85, 0.85), (-0.85, 0.85)], scale, dx, dy), c2, c1)
    for x, col in ((-0.45, (70, 130, 255)), (0.0, (230, 40, 60)), (0.45, (70, 130, 255))):
        circle(img, pts([(x, 0.35)], scale, dx, dy)[0], 0.1 * C * 0.78 * scale, col, tuple(max(0, c - 90) for c in col), width=3 * SS)


def leaf(img, c1, c2, scale=1.0, dx=0.0, dy=0.0, rot=0.0):
    seq = []
    for i in range(30):
        t = math.pi * i / 29
        seq.append((math.sin(t) * 0.55 * (1 - 0.3 * math.cos(t)), -math.cos(t)))
    for i in range(30):
        t = math.pi * (29 - i) / 29
        seq.append((-math.sin(t) * 0.55 * (1 - 0.3 * math.cos(t)), -math.cos(t)))
    poly(img, pts(seq, scale, dx, dy, rot), c1, c2)
    stroke(img, pts([(0, -0.9), (0, 0.95)], scale, dx, dy, rot), c2, 3 * SS)


# --- Icons -------------------------------------------------------------------

os.makedirs(OUT, exist_ok=True)

img = new(); sword(img); save(img, "sword", (255, 230, 150))

img = new()
circle(img, pts([(0, 0.15)])[0], 0.62 * C * 0.78, (240, 190, 150), (190, 120, 90))
for i, x in enumerate((-0.45, -0.15, 0.15, 0.45)):
    poly(img, pts([(x - 0.13, -0.3), (x + 0.13, -0.3), (x + 0.13, -0.95 + abs(x) * 0.3), (x - 0.13, -0.95 + abs(x) * 0.3)]), (245, 200, 160), (200, 130, 100))
save(img, "fist", (255, 220, 180))

img = new(); arrow(img); save(img, "arrow", (255, 240, 200))

img = new()
star(img, 4, 1.0, 0.28, (230, 190, 255), (120, 60, 220))
star(img, 4, 0.55, 0.15, (255, 255, 255), (200, 170, 255), rot=math.pi / 4, scale=1.0)
save(img, "bolt", (170, 100, 255))

img = new()
poly(img, pts([(-0.3, -0.95), (0.3, -0.95), (0.3, -0.3), (0.95, -0.3), (0.95, 0.3), (0.3, 0.3), (0.3, 0.95), (-0.3, 0.95), (-0.3, 0.3), (-0.95, 0.3), (-0.95, -0.3), (-0.3, -0.3)]),
     (160, 255, 170), (30, 160, 70))
circle(img, (C, C), 0.2 * C * 0.78, (255, 255, 255), (200, 255, 200), width=3 * SS)
save(img, "mend", (80, 255, 120))

img = new(); shield(img, STEEL, STEEL_D, 0.85, 0.15, 0.0)
for dy in (-0.45, 0.0, 0.45):
    stroke(img, pts([(-1.0, dy), (-0.65, dy)]), (255, 255, 255), 6 * SS)
save(img, "bash", (180, 200, 255))

img = new(); shield(img, (120, 170, 255), (40, 70, 170), 0.8)
ImageDraw.Draw(img).ellipse([C - 0.95 * C * 0.78, C - 0.95 * C * 0.78, C + 0.95 * C * 0.78, C + 0.95 * C * 0.78], outline=(150, 200, 255, 230), width=7 * SS)
save(img, "guard", (120, 170, 255))

img = new(); shield(img, STEEL, STEEL_D, 0.85); sword(img, math.pi / 4, 0.7, 0.2, -0.1); save(img, "block", (200, 215, 255))

img = new()
for rot in (-0.5, 0.0, 0.5):
    arrow(img, rot, 0.85)
save(img, "volley", (255, 240, 200))

img = new()
ImageDraw.Draw(img).ellipse([C - 0.7 * C * 0.78, C - 0.7 * C * 0.78, C + 0.7 * C * 0.78, C + 0.7 * C * 0.78], outline=(90, 95, 105, 255), width=14 * SS)
for i in range(10):
    a = 2 * math.pi * i / 10
    tooth = [(math.cos(a) * 0.62 + math.sin(a) * 0.1, math.sin(a) * 0.62 - math.cos(a) * 0.1), (math.cos(a) * 0.62 - math.sin(a) * 0.1, math.sin(a) * 0.62 + math.cos(a) * 0.1), (math.cos(a) * 1.0, math.sin(a) * 1.0)]
    poly(img, pts(tooth), STEEL, STEEL_D, width=3 * SS)
circle(img, (C, C), 0.22 * C * 0.78, (230, 60, 60), (140, 20, 30))
save(img, "trap", (255, 140, 120))

img = new(); flame(img); save(img, "fireball", (255, 140, 40))

img = new(); chevrons(img, (200, 150, 255), 2)
star(img, 4, 0.3, 0.1, (255, 255, 255), (220, 200, 255), scale=1.0, dx=0.75, dy=-0.6)
save(img, "blink", (170, 110, 255))

img = new()
for i in range(12):
    a = 2 * math.pi * i / 12
    ray = [(math.cos(a) * 0.45, math.sin(a) * 0.45), (math.cos(a - 0.12) * 0.7, math.sin(a - 0.12) * 0.7), (math.cos(a) * 1.0, math.sin(a) * 1.0), (math.cos(a + 0.12) * 0.7, math.sin(a + 0.12) * 0.7)]
    poly(img, pts(ray), (255, 240, 150), (240, 170, 40), width=3 * SS)
circle(img, (C, C), 0.42 * C * 0.78, (255, 255, 220), (255, 200, 90))
save(img, "blessing", (255, 220, 120))

img = new()
poly(img, pts([(-0.1, -1.0), (0.45, -1.0), (0.1, -0.2), (0.5, -0.2), (-0.35, 1.0), (-0.1, 0.1), (-0.5, 0.1)]), (255, 250, 200), (255, 190, 60))
save(img, "smite", (255, 230, 120))

img = new(); chevrons(img, (120, 230, 110), 3); save(img, "dodge", (120, 255, 140))

img = new(); crown(img); save(img, "crown", (255, 220, 120))

img = new(); heart(img, (255, 110, 120), (190, 30, 60))
stroke(img, pts([(-0.9, 0.05), (-0.4, 0.05), (-0.25, -0.45), (0.0, 0.5), (0.2, 0.05), (0.9, 0.05)]), (255, 255, 255), 6 * SS)
save(img, "vigor", (255, 150, 150))

img = new(); star(img, 5, 1.0, 0.45, (255, 240, 150), (240, 160, 40), rot=-math.pi / 2); save(img, "xp", (255, 210, 90))

# Class emblems.
img = new()
helm = [(-0.75, 0.2), (-0.75, -0.3), (-0.5, -0.8), (0.0, -1.0), (0.5, -0.8), (0.75, -0.3), (0.75, 0.2), (0.55, 0.9), (-0.55, 0.9)]
poly(img, pts(helm), STEEL, STEEL_D)
poly(img, pts([(-0.6, 0.0), (0.6, 0.0), (0.6, 0.22), (-0.6, 0.22)]), INK, (60, 50, 70), outline=None)
poly(img, pts([(-0.1, -1.3), (0.1, -1.3), (0.1, -0.7), (-0.1, -0.7)]), (255, 90, 90), (190, 30, 40))
save(img, "class_knight", (200, 215, 255))

img = new()
ImageDraw.Draw(img).arc([C - 0.85 * C * 0.78, C - 0.85 * C * 0.78, C + 0.85 * C * 0.78, C + 0.85 * C * 0.78], 200, 340, fill=(120, 75, 40, 255), width=12 * SS)
stroke(img, pts([(-0.8, -0.3), (0.8, -0.3)]), (235, 235, 235), 3 * SS)
arrow(img, -math.pi / 2, 0.9, 0, 0.1)
save(img, "class_ranger", (190, 255, 170))

img = new()
poly(img, pts([(-1.0, 0.6), (1.0, 0.6), (0.95, 0.8), (-0.95, 0.8)]), (120, 70, 220), (60, 30, 140))
poly(img, pts([(-0.6, 0.6), (0.6, 0.6), (0.2, -1.0)]), (150, 100, 240), (80, 40, 170))
star(img, 5, 0.22, 0.1, (255, 250, 180), (255, 200, 80), rot=-math.pi / 2, dx=-0.1, dy=-0.1)
save(img, "class_mage", (170, 110, 255))

img = new()
circle(img, (C, C), 0.95 * C * 0.78, (255, 250, 230), (230, 200, 140))
poly(img, pts([(-0.2, -0.75), (0.2, -0.75), (0.2, -0.2), (0.75, -0.2), (0.75, 0.2), (0.2, 0.2), (0.2, 0.75), (-0.2, 0.75), (-0.2, 0.2), (-0.75, 0.2), (-0.75, -0.2), (-0.2, -0.2)]), (120, 230, 140), (30, 150, 70))
save(img, "class_healer", (255, 240, 180))

img = new(); leaf(img, (140, 220, 90), (40, 120, 40), 0.9, 0, 0, 0.4); save(img, "class_elf", (160, 255, 120))
img = new(); shield(img, (120, 160, 240), (40, 60, 150), 0.9); save(img, "class_human", (140, 170, 255))

# Faction crests for the score tabs.
img = new(); shield(img, (60, 150, 80), (20, 70, 35), 1.0); leaf(img, (170, 240, 110), (60, 140, 50), 0.55, 0, -0.05, 0.3); save(img, "crest_forest", (120, 255, 140))
img = new(); shield(img, (70, 110, 220), (25, 40, 130), 1.0); crown(img, GOLD, GOLD_D, 0.5, 0, -0.05); save(img, "crest_kingdom", (140, 170, 255))
