"""Heraldic emblems and floor runes for the castle interiors, drawn with PIL.

Writes RGBA PNGs to assets/textures/emblems/: a rampant lion and a crown for
the Humans, a great tree and a crescent moon for the Elves, and a glowing
rune circle (white, tinted in game per class). Each emblem has a dark ink
outline so it reads like the rest of the cartoon art. Run from the project
root:  python3 tools/make_emblems.py
"""
import math
import os
from PIL import Image, ImageDraw, ImageFilter

OUT = "assets/textures/emblems"
S = 512  # final size
K = 2    # supersampling


def canvas():
    return Image.new("L", (S * K, S * K), 0)


def pt(x, y):
    return (x * S * K / 100.0, y * S * K / 100.0)


def thick(d, pts, w):
    w = int(w * S * K / 100.0)
    d.line([pt(*p) for p in pts], fill=255, width=w, joint="curve")
    for p in (pts[0], pts[-1]):
        x, y = pt(*p)
        d.ellipse([x - w / 2, y - w / 2, x + w / 2, y + w / 2], fill=255)


def blob(d, x, y, rx, ry=None):
    ry = rx if ry is None else ry
    a, b = pt(x - rx, y - ry), pt(x + rx, y + ry)
    d.ellipse([a, b], fill=255)


def finish(mask, fill, shade, name, ink=(52, 32, 20), outline=2.2):
    """Colour a mask with a top-lit fill, ink outline and soft inner shade."""
    mask = mask.resize((S, S), Image.LANCZOS)
    o = int(outline * S / 100.0) | 1
    grown = mask.filter(ImageFilter.MaxFilter(o))
    inner = mask.filter(ImageFilter.MinFilter(max(3, o // 2 | 1)))
    img = Image.new("RGBA", (S, S), ink + (0,))
    img.putalpha(grown)
    grad = Image.new("RGBA", (S, S))
    gp = grad.load()
    for y in range(S):
        t = y / S
        c = tuple(int(fill[i] * (1 - t * 0.35) + shade[i] * t * 0.35) for i in range(3))
        for x in range(S):
            gp[x, y] = c + (255,)
    body = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    body.paste(grad, (0, 0), inner)
    img = Image.alpha_composite(img, body)
    os.makedirs(OUT, exist_ok=True)
    img.save(f"{OUT}/{name}.png")
    print("wrote", name)


def lion():
    m = canvas()
    d = ImageDraw.Draw(m)
    # Torso, rearing up to the left.
    d.polygon([pt(34, 34), pt(50, 30), pt(66, 58), pt(64, 70), pt(50, 72), pt(40, 52)], fill=255)
    blob(d, 57, 64, 11, 10)
    blob(d, 42, 40, 11, 12)
    # Mane and head.
    for i in range(14):
        a = i / 14 * math.tau
        blob(d, 36 + math.cos(a) * 9.5, 26 + math.sin(a) * 10.5, 5.2)
    blob(d, 36, 26, 11)
    d.polygon([pt(24, 24), pt(16, 27), pt(18, 32), pt(27, 33)], fill=255)  # muzzle
    d.polygon([pt(30, 15), pt(33, 9), pt(37, 15)], fill=255)  # ear
    # Forelegs raised, claws out.
    thick(d, [(38, 44), (26, 42), (18, 34)], 7)
    thick(d, [(42, 50), (28, 54), (20, 48)], 7)
    for cx, cy in ((16, 32), (18, 46)):
        for k in range(3):
            thick(d, [(cx, cy), (cx - 5, cy - 3 + k * 3)], 2.2)
    # Hind legs.
    thick(d, [(56, 70), (46, 80), (40, 92)], 8.5)
    thick(d, [(64, 70), (68, 82), (60, 93)], 8.5)
    thick(d, [(40, 92), (32, 93)], 5)
    thick(d, [(60, 93), (52, 94)], 5)
    # Tail curling up behind, with a tuft.
    thick(d, [(66, 64), (78, 60), (82, 46), (76, 36), (80, 26)], 3.4)
    blob(d, 81, 22, 4.8, 6)
    m2 = Image.new("L", m.size, 0)
    m2.paste(m)
    # Eye and mouth knocked out.
    e = ImageDraw.Draw(m2)
    x, y = pt(31, 24)
    e.ellipse([x - 9, y - 9, x + 9, y + 9], fill=0)
    e.line([pt(18, 31), pt(26, 31)], fill=0, width=7)
    finish(m2, (250, 206, 72), (196, 130, 30), "lion")


def crown():
    m = canvas()
    d = ImageDraw.Draw(m)
    d.polygon([pt(12, 76), pt(10, 34), pt(30, 54), pt(50, 22), pt(70, 54), pt(90, 34), pt(88, 76)], fill=255)
    d.rounded_rectangle([pt(10, 72), pt(90, 86)], radius=12, fill=255)
    for x, y in ((10, 30), (50, 17), (90, 30)):
        blob(d, x, y, 6)
    m2 = m.copy()
    e = ImageDraw.Draw(m2)
    for x in (30, 50, 70):
        a, b = pt(x - 4, 75), pt(x + 4, 83)
        e.ellipse([a, b], fill=0)
    finish(m2, (252, 214, 80), (200, 132, 28), "crown")


def tree():
    m = canvas()
    d = ImageDraw.Draw(m)
    # Crown of leaves.
    for x, y, r in ((50, 30, 18), (32, 38, 14), (68, 38, 14), (40, 22, 12), (60, 22, 12), (24, 50, 10), (76, 50, 10), (50, 46, 14)):
        blob(d, x, y, r)
    # Trunk and roots.
    d.polygon([pt(45, 50), pt(55, 50), pt(57, 78), pt(43, 78)], fill=255)
    thick(d, [(46, 76), (34, 86), (24, 88)], 5)
    thick(d, [(54, 76), (66, 86), (76, 88)], 5)
    thick(d, [(50, 78), (50, 90)], 5)
    finish(m, (196, 240, 150), (90, 170, 80), "tree")


def stag():
    """The Elves' stag head, front on, with wide branching antlers (the top
    bar's shield and Faisal's base banners, 2026-10-08), in gold."""
    m = canvas()
    d = ImageDraw.Draw(m)
    # Head: a long face with a rounded muzzle, cheeks and two ears.
    d.polygon([pt(40, 46), pt(60, 46), pt(63, 62), pt(57, 84), pt(43, 84), pt(37, 62)], fill=255)
    blob(d, 50, 48, 13, 10)
    blob(d, 50, 84, 8, 6)
    d.polygon([pt(38, 50), pt(26, 42), pt(30, 54)], fill=255)
    d.polygon([pt(62, 50), pt(74, 42), pt(70, 54)], fill=255)
    # Antlers: a main beam curving up and out each side with three tines.
    for sx in (-1, 1):
        def q(x, y):
            return (50 + sx * x, y)
        thick(d, [q(6, 44), q(12, 34), q(20, 22), q(30, 12), q(38, 8)], 4.2)
        thick(d, [q(13, 33), q(10, 22), q(12, 14)], 3.2)
        thick(d, [q(21, 22), q(24, 12), q(30, 6)], 3.0)
        thick(d, [q(28, 14), q(36, 16), q(42, 20)], 2.8)
        for x, y in ((12, 14), (30, 6), (42, 20), (38, 8)):
            blob(d, 50 + sx * x, y, 2.2)
    m2 = m.copy()
    e = ImageDraw.Draw(m2)
    # Eyes and nostrils knocked out.
    for x in (44, 56):
        a, b = pt(x - 2.4, 60), pt(x + 2.4, 65)
        e.ellipse([a, b], fill=0)
    for x in (47, 53):
        a, b = pt(x - 1.4, 82), pt(x + 1.4, 85)
        e.ellipse([a, b], fill=0)
    finish(m2, (250, 206, 72), (196, 130, 30), "stag")


def moon():
    m = canvas()
    d = ImageDraw.Draw(m)
    blob(d, 50, 50, 38)
    e = ImageDraw.Draw(m)
    a, b = pt(62 - 32, 40 - 32), pt(62 + 32, 40 + 32)
    e.ellipse([a, b], fill=0)
    # Three stars.
    for sx, sy, r in ((70, 62, 7), (80, 40, 5), (60, 78, 4)):
        pts = []
        for i in range(10):
            a = i / 10 * math.tau - math.pi / 2
            rr = r if i % 2 == 0 else r * 0.45
            pts.append(pt(sx + math.cos(a) * rr, sy + math.sin(a) * rr))
        d.polygon(pts, fill=255)
    finish(m, (210, 250, 240), (110, 200, 200), "moon")


def runes():
    """A white rune circle on transparent: two rings with glyphs between them
    and a ring of ticks inside. Tinted and made to glow in game."""
    size = S * K
    m = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(m)
    c = size / 2

    def ring(r, w):
        d.ellipse([c - r, c - r, c + r, c + r], outline=255, width=int(w))

    ring(size * 0.48, size * 0.018)
    ring(size * 0.37, size * 0.012)
    ring(size * 0.24, size * 0.010)
    n = 18
    for i in range(n):
        a = i / n * math.tau
        r0, r1 = size * 0.395, size * 0.455
        cx, cy = c + math.cos(a) * (r0 + r1) / 2, c + math.sin(a) * (r0 + r1) / 2
        # A small angular glyph made of two or three strokes, rotated to the ring.
        t = (math.cos(a + math.pi / 2), math.sin(a + math.pi / 2))
        u = (math.cos(a), math.sin(a))
        h = (r1 - r0) * 0.45
        w = h * 0.7
        kind = (i * 7) % 4
        strokes = [[(-w, -h), (-w, h)], [(-w, 0), (w, -h)], [(-w, 0), (w, h)], [(w, -h), (w, h)], [(-w, h), (w, -h)]]
        pick = [[0, 1, 2], [0, 3, 4], [3, 1], [0, 4, 3]][kind]
        for sidx in pick:
            (x0, y0), (x1, y1) = strokes[sidx]
            p0 = (cx + t[0] * x0 + u[0] * y0, cy + t[1] * x0 + u[1] * y0)
            p1 = (cx + t[0] * x1 + u[0] * y1, cy + t[1] * x1 + u[1] * y1)
            d.line([p0, p1], fill=255, width=int(size * 0.008))
    for i in range(36):
        a = i / 36 * math.tau
        r0, r1 = size * 0.30, size * 0.34 if i % 3 == 0 else size * 0.32
        d.line([(c + math.cos(a) * r0, c + math.sin(a) * r0), (c + math.cos(a) * r1, c + math.sin(a) * r1)], fill=255, width=int(size * 0.007))
    m = m.resize((S, S), Image.LANCZOS)
    glow = m.filter(ImageFilter.GaussianBlur(6))
    a = Image.eval(Image.merge("L", [m]), lambda v: v)
    alpha = Image.new("L", (S, S))
    alpha.paste(glow.point(lambda v: min(255, v * 2)))
    alpha = Image.composite(m, alpha, m)
    img = Image.new("RGBA", (S, S), (255, 255, 255, 0))
    img.putalpha(Image.eval(alpha, lambda v: v))
    os.makedirs(OUT, exist_ok=True)
    img.save(f"{OUT}/runes.png")
    print("wrote runes")


lion()
crown()
tree()
stag()
moon()
runes()
