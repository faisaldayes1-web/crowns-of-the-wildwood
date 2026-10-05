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


def flame(img, scale=1.0, dx=0.0, dy=0.0, c1=(255, 180, 40), c2=(220, 50, 20), c3=(255, 250, 170), c4=(255, 170, 50)):
    outer = [(0, -1.0), (0.35, -0.45), (0.7, -0.2), (0.75, 0.4), (0.4, 0.9), (0, 1.0), (-0.4, 0.9), (-0.75, 0.4), (-0.7, -0.2), (-0.3, -0.35)]
    poly(img, pts(outer, scale, dx, dy), c1, c2)
    inner = [(x * 0.5, y * 0.5 + 0.3) for x, y in outer]
    poly(img, pts(inner, scale, dx, dy), c3, c4, outline=None)


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

# Class emblems: rounded plaques with a gold rim in each class's colour,
# carrying the sheet's symbols (shield, bow, flame, cross).
def plaque(img, c1, c2):
    r = 0.9 * C * 0.78
    box = [C - r, C - r, C + r, C + r]
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(box, radius=r * 0.32, fill=255)
    img.paste(gradient(img.size, c1, c2), (0, 0), mask)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle(box, radius=r * 0.32, outline=INK + (255,), width=7 * SS)
    d.rounded_rectangle([b + (9 * SS if i < 2 else -9 * SS) for i, b in enumerate(box)], radius=r * 0.26, outline=GOLD + (255,), width=5 * SS)
    d.rounded_rectangle([b + (15 * SS if i < 2 else -15 * SS) for i, b in enumerate(box)], radius=r * 0.22, outline=GOLD_D + (255,), width=2 * SS)


def bow(img, scale=1.0, dx=0.0, dy=0.0):
    # A bow seen side-on: the stave is an arc bulging left, the string is
    # the chord, and a nocked arrow points right.
    r = 0.95 * C * 0.78 * scale
    cx, cy = C + (dx + 0.25 * scale) * C * 0.78, C + dy * C * 0.78
    d = ImageDraw.Draw(img)
    d.arc([cx - r, cy - r, cx + r, cy + r], 125, 235, fill=INK + (255,), width=16 * SS)
    d.arc([cx - r, cy - r, cx + r, cy + r], 125, 235, fill=(150, 95, 50, 255), width=10 * SS)
    d.arc([cx - r, cy - r, cx + r, cy + r], 140, 220, fill=(205, 145, 85, 255), width=4 * SS)
    tips = [(cx + r * math.cos(math.radians(a)), cy + r * math.sin(math.radians(a))) for a in (125, 235)]
    stroke(img, tips, INK, 5 * SS)
    stroke(img, tips, (240, 240, 240), 2 * SS)
    arrow(img, math.pi / 2, 0.85 * scale, dx + 0.05, dy)


img = new()
plaque(img, (90, 130, 230), (35, 55, 150))
shield(img, (150, 185, 250), (70, 100, 200), 0.6)
save(img, "class_knight", (200, 215, 255))

img = new()
plaque(img, (80, 170, 80), (25, 95, 45))
bow(img, 0.7)
save(img, "class_ranger", (190, 255, 170))

img = new()
plaque(img, (190, 90, 230), (100, 35, 150))
flame(img, 0.62, 0, 0.05, (255, 150, 240), (200, 60, 190), (255, 240, 255), (255, 170, 240))
save(img, "class_mage", (230, 150, 255))

img = new()
plaque(img, (230, 170, 70), (150, 95, 30))
poly(img, pts([(-0.2, -0.65), (0.2, -0.65), (0.2, -0.2), (0.65, -0.2), (0.65, 0.2), (0.2, 0.2), (0.2, 0.65), (-0.2, 0.65), (-0.2, 0.2), (-0.65, 0.2), (-0.65, -0.2), (-0.2, -0.2)]), (255, 245, 200), (235, 190, 90))
save(img, "class_healer", (255, 240, 180))

img = new(); leaf(img, (140, 220, 90), (40, 120, 40), 0.9, 0, 0, 0.4); save(img, "class_elf", (160, 255, 120))
img = new(); shield(img, (120, 160, 240), (40, 60, 150), 0.9); save(img, "class_human", (140, 170, 255))

# Faction crests for the score tabs.
img = new(); shield(img, (60, 150, 80), (20, 70, 35), 1.0); leaf(img, (170, 240, 110), (60, 140, 50), 0.55, 0, -0.05, 0.3); save(img, "crest_forest", (120, 255, 140))
img = new(); shield(img, (70, 110, 220), (25, 40, 130), 1.0); crown(img, GOLD, GOLD_D, 0.5, 0, -0.05); save(img, "crest_kingdom", (140, 170, 255))

# --- Promotion (variant) abilities ------------------------------------------

def crossed_swords(img, scale=1.0):
    sword(img, -math.pi / 4, scale * 0.9, 0.0, 0.0)
    sword(img, math.pi / 4, scale * 0.9, 0.0, 0.0)


img = new()
for k in range(3):
    a = 2 * math.pi * k / 3
    blade = [(0.0, 0.0), (0.35, -0.3), (1.0, -0.15), (0.5, 0.2)]
    poly(img, pts(blade, 1.0, 0, 0, a), STEEL, STEEL_D)
circle(img, (C, C), 0.22 * C * 0.78, GOLD, GOLD_D)
save(img, "cleave", (220, 230, 255))

img = new()
for s in (-0.55, 0.0, 0.55):
    circle(img, pts([(s, 0.0)])[0], 0.3 * C * 0.78, (240, 190, 150), (190, 120, 90), width=3 * SS)
arrow(img, math.pi / 2, 1.05)
save(img, "pierce", (255, 240, 200))

img = new()
ImageDraw.Draw(img).ellipse([C - 0.9 * C * 0.78, C - 0.9 * C * 0.78, C + 0.9 * C * 0.78, C + 0.9 * C * 0.78], outline=INK + (255,), width=16 * SS)
ImageDraw.Draw(img).ellipse([C - 0.9 * C * 0.78, C - 0.9 * C * 0.78, C + 0.9 * C * 0.78, C + 0.9 * C * 0.78], outline=(235, 90, 80, 255), width=8 * SS)
for a in (0, math.pi / 2, math.pi, 3 * math.pi / 2):
    stroke(img, pts([(math.cos(a) * 0.55, math.sin(a) * 0.55), (math.cos(a) * 1.05, math.sin(a) * 1.05)]), INK, 14 * SS)
    stroke(img, pts([(math.cos(a) * 0.55, math.sin(a) * 0.55), (math.cos(a) * 1.05, math.sin(a) * 1.05)]), (235, 90, 80), 7 * SS)
circle(img, (C, C), 0.16 * C * 0.78, (255, 120, 100), (200, 40, 40))
save(img, "snipe", (255, 160, 140))

img = new()
for (x, y, r) in ((-0.45, 0.2, 0.5), (0.35, 0.15, 0.55), (-0.05, -0.35, 0.5), (0.0, 0.45, 0.45)):
    circle(img, pts([(x, y)])[0], r * C * 0.78, (200, 200, 210), (120, 120, 135), width=4 * SS)
circle(img, pts([(0.0, 0.75)])[0], 0.25 * C * 0.78, (90, 90, 100), (50, 50, 60), width=3 * SS)
poly(img, pts([(-0.08, 0.75), (0.08, 0.75), (0.12, 1.05), (-0.12, 1.05)]), (120, 70, 40), (70, 40, 20), width=3 * SS)
save(img, "smoke", (200, 200, 215))

img = new()
for k in range(5):
    a = -math.pi / 2 + (k - 2) * 0.42
    f = [(0, 0.3), (math.cos(a - 0.18) * 0.7, 0.3 + math.sin(a - 0.18) * 0.7), (math.cos(a) * 1.1, 0.3 + math.sin(a) * 1.1), (math.cos(a + 0.18) * 0.7, 0.3 + math.sin(a + 0.18) * 0.7)]
    poly(img, pts(f), (255, 200, 60), (220, 60, 20), width=3 * SS)
flame(img, 0.45, 0.0, 0.45)
save(img, "wave", (255, 150, 50))

img = new()
for k in range(6):
    a = math.pi * k / 3
    stroke(img, pts([(0, 0), (math.cos(a), math.sin(a))]), INK, 14 * SS)
    stroke(img, pts([(0, 0), (math.cos(a), math.sin(a))]), (200, 240, 255), 7 * SS)
    for t in (0.5, 0.8):
        for s in (-1, 1):
            b = a + s * 0.6
            p0 = (math.cos(a) * t, math.sin(a) * t)
            p1 = (p0[0] + math.cos(b) * 0.22, p0[1] + math.sin(b) * 0.22)
            stroke(img, pts([p0, p1]), INK, 9 * SS)
            stroke(img, pts([p0, p1]), (200, 240, 255), 4 * SS)
circle(img, (C, C), 0.16 * C * 0.78, (255, 255, 255), (180, 230, 255), width=3 * SS)
save(img, "frost", (150, 220, 255))

img = new()
circle(img, pts([(0, -0.15)])[0], 0.62 * C * 0.78, (235, 235, 245), (150, 150, 170))
poly(img, pts([(-0.4, 0.3), (0.4, 0.3), (0.35, 0.85), (-0.35, 0.85)]), (235, 235, 245), (150, 150, 170))
for s in (-1, 1):
    circle(img, pts([(s * 0.26, -0.2)])[0], 0.17 * C * 0.78, (90, 30, 140), (40, 10, 70), width=3 * SS)
for x in (-0.18, 0.0, 0.18):
    stroke(img, pts([(x, 0.4), (x, 0.8)]), INK, 4 * SS)
poly(img, pts([(-0.08, 0.05), (0.08, 0.05), (0.0, 0.25)]), (120, 60, 160), (70, 30, 110), width=3 * SS)
save(img, "curse", (170, 90, 230))

img = new()
poly(img, pts([(-0.1, -1.0), (0.45, -1.0), (0.1, -0.2), (0.5, -0.2), (-0.35, 1.0), (-0.1, 0.1), (-0.5, 0.1)]), (220, 170, 255), (110, 40, 170))
heart(img, (255, 110, 120), (190, 30, 60), 0.4, 0.55, 0.55)
save(img, "drain", (170, 100, 240))

def hammer(img, scale=1.0, dx=0.0, dy=0.0, head=STEEL, head_d=STEEL_D):
    """A war hammer, handle lower-left to head upper-right."""
    stroke(img, pts([(-0.85, 0.85), (0.35, -0.35)], scale, dx, dy), INK, 16 * SS)
    stroke(img, pts([(-0.85, 0.85), (0.35, -0.35)], scale, dx, dy), (150, 95, 50), 9 * SS)
    poly(img, pts([(-0.05, -0.95), (0.85, -0.95), (0.85, -0.25), (-0.05, -0.25)], scale, dx, dy, 0.0), head, head_d)
    stroke(img, pts([(0.1, -0.85), (0.7, -0.85)], scale, dx, dy), (255, 255, 255), 3 * SS)


def gear(img, c1, c2, scale=1.0, dx=0.0, dy=0.0, teeth=8):
    shape = []
    for i in range(teeth * 2):
        a = math.pi * i / teeth
        r = 0.95 if i % 2 == 0 else 0.72
        shape.append((math.cos(a) * r, math.sin(a) * r))
        a2 = a + math.pi / teeth * 0.5
        shape.append((math.cos(a2) * r, math.sin(a2) * r))
    poly(img, pts(shape, scale, dx, dy), c1, c2)
    circle(img, pts([(dx / scale if scale else 0, 0)], scale, dx, dy)[0] if False else pts([(0, 0)], scale, dx, dy)[0], 0.3 * C * 0.78 * scale, c2, c1)


img = new()
plaque(img, (210, 140, 70), (120, 70, 25))
gear(img, (235, 220, 190), (150, 110, 60), 0.55, 0.22, 0.22)
hammer(img, 0.6, -0.2, -0.15)
save(img, "class_engineer", (255, 210, 150))

img = new(); hammer(img, 1.0); save(img, "hammer", (220, 220, 240))

img = new()
poly(img, pts([(-0.75, 0.55), (0.75, 0.55), (0.6, 0.95), (-0.6, 0.95)]), (180, 180, 195), (90, 90, 105))
poly(img, pts([(-0.14, -0.3), (0.14, -0.3), (0.14, 0.55), (-0.14, 0.55)]), (150, 95, 50), (90, 55, 25))
d = ImageDraw.Draw(img)
cx, cy, r = C, C - 0.3 * C * 0.78, 0.7 * C * 0.78
d.arc([cx - r, cy - r, cx + r, cy + r], 180, 360, fill=INK + (255,), width=16 * SS)
d.arc([cx - r, cy - r, cx + r, cy + r], 180, 360, fill=(150, 95, 50, 255), width=9 * SS)
stroke(img, pts([(-0.7, -0.3), (0.7, -0.3)]), (240, 240, 240), 3 * SS)
arrow(img, -math.pi / 2, 0.75, 0.0, -0.25)
save(img, "turret", (255, 220, 150))

img = new()
poly(img, pts([(0, -1.0), (0.95, 0.0), (0.4, 0.0), (0.4, 0.95), (-0.4, 0.95), (-0.4, 0.0), (-0.95, 0.0)]), (255, 230, 120), (220, 150, 40))
poly(img, pts([(0, -0.55), (0.45, -0.1), (-0.45, -0.1)]), (255, 250, 200), (255, 210, 90), outline=None)
save(img, "upgrade", (255, 230, 140))

img = new()
circle(img, (C, C), 0.85 * C * 0.78, (120, 190, 240), (40, 90, 170), width=10 * SS)
stroke(img, pts([(0, 0), (0, -0.6)]), INK, 12 * SS)
stroke(img, pts([(0, 0), (0, -0.6)]), (255, 255, 255), 6 * SS)
stroke(img, pts([(0, 0), (0.45, 0.25)]), INK, 12 * SS)
stroke(img, pts([(0, 0), (0.45, 0.25)]), (255, 255, 255), 6 * SS)
for a in (0, 90, 180, 270):
    rad = math.radians(a)
    stroke(img, pts([(math.cos(rad) * 0.72, math.sin(rad) * 0.72), (math.cos(rad) * 0.85, math.sin(rad) * 0.85)]), (255, 255, 255), 4 * SS)
save(img, "overclock", (150, 210, 255))

# --- Promotion emblems -------------------------------------------------------

img = new()
gear(img, (200, 225, 250), (90, 130, 190), 0.95)
circle(img, (C, C), 0.2 * C * 0.78, (255, 255, 255), (150, 200, 255))
save(img, "artificer", (190, 225, 255))

img = new()
poly(img, pts([(-0.95, 0.95), (0.95, 0.95), (0.95, 0.35), (-0.95, 0.35)]), (190, 180, 165), (110, 100, 85))
for x in (-0.5, 0.0, 0.5):
    stroke(img, pts([(x, 0.35), (x, 0.95)]), INK, 4 * SS)
hammer(img, 0.75, 0.0, -0.25, GOLD, GOLD_D)
save(img, "siegewright", (255, 220, 170))

img = new(); crossed_swords(img, 1.0); save(img, "vanguard", (255, 200, 170))

img = new()
shape = [(-0.7, -0.95), (0.7, -0.95), (0.7, 0.55), (0.0, 1.0), (-0.7, 0.55)]
poly(img, pts(shape), (150, 170, 220), (60, 80, 150))
poly(img, pts([(x * 0.7, y * 0.7 - 0.05) for x, y in shape]), (60, 80, 150), (150, 170, 220), outline=None)
for dy in (-0.5, -0.1, 0.3):
    stroke(img, pts([(-0.5, dy), (0.5, dy)]), GOLD, 4 * SS)
save(img, "warden", (170, 200, 255))

img = new()
ImageDraw.Draw(img).ellipse([C - 0.8 * C * 0.78, C - 0.8 * C * 0.78, C + 0.8 * C * 0.78, C + 0.8 * C * 0.78], outline=INK + (255,), width=14 * SS)
ImageDraw.Draw(img).ellipse([C - 0.8 * C * 0.78, C - 0.8 * C * 0.78, C + 0.8 * C * 0.78, C + 0.8 * C * 0.78], outline=(130, 200, 110, 255), width=7 * SS)
arrow(img, -math.pi / 4, 1.0)
save(img, "sharpshooter", (170, 255, 150))

img = new()
ImageDraw.Draw(img).ellipse([C - 0.8 * C * 0.78, C - 0.8 * C * 0.78, C + 0.8 * C * 0.78, C + 0.8 * C * 0.78], outline=(90, 95, 105, 255), width=14 * SS)
for i in range(10):
    a = 2 * math.pi * i / 10
    tooth = [(math.cos(a) * 0.72 + math.sin(a) * 0.1, math.sin(a) * 0.72 - math.cos(a) * 0.1), (math.cos(a) * 0.72 - math.sin(a) * 0.1, math.sin(a) * 0.72 + math.cos(a) * 0.1), (math.cos(a) * 1.05, math.sin(a) * 1.05)]
    poly(img, pts(tooth), (190, 150, 100), (110, 75, 40), width=3 * SS)
leaf(img, (140, 220, 90), (40, 120, 40), 0.5, 0, 0, 0.5)
save(img, "trapper", (230, 200, 140))

img = new(); flame(img, 1.0)
star(img, 4, 0.28, 0.1, (255, 255, 255), (255, 220, 150), rot=math.pi / 4, dx=0.6, dy=-0.7)
save(img, "pyromancer", (255, 120, 40))

img = new()
for k in range(6):
    a = math.pi * k / 3
    stroke(img, pts([(0, 0), (math.cos(a) * 0.95, math.sin(a) * 0.95)]), INK, 16 * SS)
    stroke(img, pts([(0, 0), (math.cos(a) * 0.95, math.sin(a) * 0.95)]), (190, 235, 255), 8 * SS)
poly(img, pts([(0, -0.5), (0.43, -0.25), (0.43, 0.25), (0, 0.5), (-0.43, 0.25), (-0.43, -0.25)]), (240, 250, 255), (160, 210, 240))
save(img, "frostweaver", (140, 210, 255))

img = new()
for i in range(8):
    a = 2 * math.pi * i / 8
    ray = [(math.cos(a) * 0.5, math.sin(a) * 0.5), (math.cos(a - 0.2) * 0.75, math.sin(a - 0.2) * 0.75), (math.cos(a) * 1.0, math.sin(a) * 1.0), (math.cos(a + 0.2) * 0.75, math.sin(a + 0.2) * 0.75)]
    poly(img, pts(ray), (255, 245, 190), (240, 190, 70), width=3 * SS)
circle(img, (C, C), 0.5 * C * 0.78, (255, 255, 235), (240, 210, 130))
poly(img, pts([(-0.1, -0.35), (0.1, -0.35), (0.1, -0.1), (0.35, -0.1), (0.35, 0.1), (0.1, 0.1), (0.1, 0.4), (-0.1, 0.4), (-0.1, 0.1), (-0.35, 0.1), (-0.35, -0.1), (-0.1, -0.1)]), (120, 230, 140), (30, 150, 70), width=3 * SS)
save(img, "cleric", (255, 230, 150))

img = new()
circle(img, (C, C), 0.95 * C * 0.78, (70, 40, 110), (25, 10, 45))
pts_moon = []
for i in range(40):
    t = math.pi * i / 39
    pts_moon.append((math.cos(t - math.pi / 2) * 0.7, math.sin(t - math.pi / 2) * 0.7))
for i in range(40):
    t = math.pi * (39 - i) / 39
    pts_moon.append((math.cos(t - math.pi / 2) * 0.35 + 0.25, math.sin(t - math.pi / 2) * 0.7))
poly(img, pts(pts_moon, 1.0, -0.1, 0.0), (235, 225, 255), (170, 140, 220))
star(img, 4, 0.18, 0.07, (255, 255, 255), (220, 200, 255), rot=math.pi / 4, dx=0.5, dy=-0.4)
save(img, "darkpriest", (150, 90, 220))

# --- Pickups and blessings ----------------------------------------------------

# Health potion: a round red bottle with a cork and a white cross.
img = new()
circle(img, (C, C + 0.15 * C * 0.78), 0.62 * C * 0.78, (255, 90, 110), (150, 20, 50))
poly(img, pts([(-0.2, -0.5), (0.2, -0.5), (0.22, -0.95), (-0.22, -0.95)]), (230, 240, 255), (150, 170, 200))
poly(img, pts([(-0.26, -1.0), (0.26, -1.0), (0.26, -0.78), (-0.26, -0.78)]), (200, 150, 90), (120, 80, 40))
poly(img, pts([(-0.08, -0.12), (0.08, -0.12), (0.08, 0.02), (0.22, 0.02), (0.22, 0.18), (0.08, 0.18), (0.08, 0.32), (-0.08, 0.32), (-0.08, 0.18), (-0.22, 0.18), (-0.22, 0.02), (-0.08, 0.02)]),
     (255, 255, 255), (230, 230, 240), width=2 * SS)
circle(img, (C - 0.25 * C * 0.78, C), 0.09 * C * 0.78, (255, 230, 235), None, outline=None)
save(img, "potion", (255, 120, 140))

# Regeneration: a heart with a circling arrow.
img = new()
heart(img, (120, 255, 150), (30, 160, 80), 0.6, 0.0, 0.08)
arc = []
for i in range(30):
    t = -math.pi * 0.2 + math.pi * 1.3 * i / 29
    arc.append((math.cos(t) * 0.86, math.sin(t) * 0.86))
stroke(img, pts(arc), (255, 255, 255), 7 * SS)
poly(img, pts([(0.86, -0.72), (0.6, -0.55), (0.92, -0.38)]), (255, 255, 255), (220, 255, 230), width=2 * SS)
save(img, "regen", (120, 255, 150))

# Might: a flexed fist with an up-arrow of sparks.
img = new()
poly(img, pts([(-0.55, 0.1), (0.5, 0.1), (0.55, 0.75), (-0.5, 0.75)]), (255, 200, 150), (200, 120, 70))
for i in range(4):
    x = -0.4 + i * 0.27
    poly(img, pts([(x, 0.15), (x + 0.22, 0.15), (x + 0.22, -0.2), (x, -0.2)]), (255, 215, 170), (210, 140, 90))
poly(img, pts([(0.0, -0.95), (0.3, -0.5), (0.12, -0.5), (0.12, -0.28), (-0.12, -0.28), (-0.12, -0.5), (-0.3, -0.5)]), (255, 240, 150), (240, 160, 40))
save(img, "might", (255, 180, 100))


# Holy Bubble: a translucent dome of light with a shine arc.
img = new()
circle(img, (C, C + 0.1 * C * 0.78), 0.78 * C * 0.78, (200, 235, 255, 150), (120, 170, 255, 200), outline=(90, 130, 220), width=4 * SS)
circle(img, (C, C + 0.1 * C * 0.78), 0.55 * C * 0.78, (255, 255, 255, 90), (180, 220, 255, 40), outline=None)
stroke(img, pts([(math.cos(a) * 0.6, 0.1 + math.sin(a) * 0.6) for a in [math.radians(d) for d in range(205, 250, 5)]]), (255, 255, 255), 5 * SS)
star(img, 4, 0.16, 0.05, (255, 255, 255), (220, 240, 255), dx=0.3, dy=-0.45)
save(img, "bubble", (150, 200, 255))

# Bramble Burst: three leaves around a thorny seed.
img = new()
for rot in [0.0, 2.1, 4.2]:
    leaf(img, (120, 200, 90), (50, 120, 40), 0.55, math.sin(rot) * 0.45, -math.cos(rot) * 0.45, rot)
star(img, 8, 0.42, 0.22, (170, 110, 60), (90, 50, 30))
circle(img, (C, C), 0.2 * C * 0.78, (230, 200, 120), (160, 110, 50))
save(img, "bramble", (150, 230, 120))
