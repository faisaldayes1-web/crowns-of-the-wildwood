"""The end-of-match screen's icons (stat tiles and rewards), painted in the
same style as make_icons.py: skull, handshake, flag, damage burst, gold
chevrons, coin, shard, chest, padlock, clock and a red takedown badge. Run
from the project root:
    python3 tools/make_summary_icons.py
"""
import math

# Borrow the helpers and pieces from make_icons.py without running its icon
# list (everything above its "# --- Icons" marker).
_src = open("tools/make_icons.py").read().split("# --- Icons")[0]
exec(compile(_src, "tools/make_icons.py", "exec"))


def skull(img, c1=(245, 240, 230), c2=(170, 160, 150), scale=1.0, dx=0.0, dy=0.0):
    # Cranium, jaw, eye sockets and the nose.
    cr = 0.62 * C * 0.78 * scale
    cx, cy = pts([(0, -0.15)], 1.0, dx, dy)[0]
    circle(img, (cx, cy), cr, c1, c2)
    poly(img, pts([(-0.42, 0.25), (0.42, 0.25), (0.42, 0.75), (0.22, 0.75), (0.22, 0.6), (0.08, 0.6), (0.08, 0.75),
                   (-0.08, 0.75), (-0.08, 0.6), (-0.22, 0.6), (-0.22, 0.75), (-0.42, 0.75)], scale, dx, dy), c1, c2)
    for ex in (-0.26, 0.26):
        circle(img, pts([(ex, -0.18)], scale, dx, dy)[0], 0.17 * C * 0.78 * scale, INK, INK, outline=None)
    poly(img, pts([(0, 0.08), (0.09, 0.3), (-0.09, 0.3)], scale, dx, dy), INK, INK, outline=None)


def handshake(img, scale=1.0):
    skin1, skin2 = (255, 214, 170), (205, 150, 100)
    sleeve1, sleeve2 = (90, 140, 230), (40, 70, 160)
    # Two sleeves coming in from the sides, two hands clasped in the middle.
    poly(img, pts([(-1.0, -0.1), (-0.55, -0.25), (-0.5, 0.35), (-1.0, 0.45)], scale), sleeve1, sleeve2)
    poly(img, pts([(1.0, -0.1), (0.55, -0.25), (0.5, 0.35), (1.0, 0.45)], scale), (230, 90, 90), (150, 40, 50))
    poly(img, pts([(-0.6, -0.3), (0.15, -0.35), (0.45, 0.0), (0.2, 0.4), (-0.55, 0.4)], scale), skin1, skin2)
    poly(img, pts([(0.6, -0.3), (-0.1, -0.2), (-0.4, 0.05), (-0.15, 0.4), (0.55, 0.4)], scale), skin1, skin2)
    for k in range(3):
        y = -0.1 + k * 0.17
        stroke(img, pts([(-0.15, y), (0.25, y + 0.02)], scale), INK, 3 * SS)


def flag(img, scale=1.0):
    stroke(img, pts([(-0.55, -0.95), (-0.55, 0.95)], scale), INK, 12 * SS)
    stroke(img, pts([(-0.55, -0.95), (-0.55, 0.95)], scale), (120, 90, 60), 7 * SS)
    poly(img, pts([(-0.5, -0.9), (0.75, -0.75), (0.5, -0.35), (0.75, 0.05), (-0.5, 0.2)], scale), (250, 250, 245), (190, 195, 205))


def burst(img, scale=1.0):
    seq = []
    for i in range(16):
        a = 2 * math.pi * i / 16 - math.pi / 2
        r = 1.0 if i % 2 == 0 else 0.55
        seq.append((math.cos(a) * r, math.sin(a) * r))
    poly(img, pts(seq, scale), (255, 230, 90), (240, 120, 30))
    inner = [(x * 0.5, y * 0.5) for x, y in seq]
    poly(img, pts(inner, scale), (255, 255, 200), (255, 190, 60), outline=None)


def coin(img, scale=1.0):
    r = 0.9 * C * 0.78 * scale
    circle(img, (C, C), r, (255, 225, 90), (200, 140, 20))
    circle(img, (C, C), r * 0.72, (250, 200, 60), (230, 160, 30), outline=(150, 95, 15), width=3 * SS)
    star(img, 5, 0.42, 0.2, (255, 245, 180), (240, 190, 60), rot=-math.pi / 2, scale=scale)


def shard(img, scale=1.0):
    poly(img, pts([(0, -1.0), (0.55, -0.35), (0.35, 0.95), (-0.35, 0.95), (-0.55, -0.35)], scale), (170, 230, 255), (40, 120, 230))
    poly(img, pts([(0, -1.0), (0.55, -0.35), (0.1, -0.2)], scale), (235, 250, 255), (150, 210, 255), outline=None)
    stroke(img, pts([(0.1, -0.2), (0.1, 0.9)], scale), (60, 140, 240), 3 * SS)


def chest(img, scale=1.0):
    wood1, wood2 = (150, 95, 55), (80, 45, 25)
    poly(img, pts([(-0.95, -0.1), (0.95, -0.1), (0.95, 0.85), (-0.95, 0.85)], scale), wood1, wood2)
    poly(img, pts([(-0.95, -0.1), (-0.8, -0.65), (0.8, -0.65), (0.95, -0.1)], scale), (120, 70, 160), (70, 35, 110))
    for x in (-0.6, 0.6):
        stroke(img, pts([(x, -0.6), (x, 0.85)], scale), (235, 200, 90), 6 * SS)
    poly(img, pts([(-0.2, -0.25), (0.2, -0.25), (0.2, 0.25), (-0.2, 0.25)], scale), (255, 225, 110), (200, 140, 30))
    circle(img, (C, C + 0.02 * C), 0.1 * C * 0.78 * scale, (90, 200, 255), (30, 110, 220), width=3 * SS)


def padlock(img, scale=1.0, c1=(215, 220, 230), c2=(110, 115, 130)):
    stroke(img, pts([(-0.45, 0.0), (-0.45, -0.45), (-0.3, -0.75), (0.3, -0.75), (0.45, -0.45), (0.45, 0.0)], scale), INK, 16 * SS)
    stroke(img, pts([(-0.45, 0.0), (-0.45, -0.45), (-0.3, -0.75), (0.3, -0.75), (0.45, -0.45), (0.45, 0.0)], scale), c2, 9 * SS)
    poly(img, pts([(-0.75, -0.1), (0.75, -0.1), (0.75, 0.85), (-0.75, 0.85)], scale), c1, c2)
    circle(img, pts([(0, 0.3)], scale)[0], 0.12 * C * 0.78 * scale, INK, INK, outline=None)
    poly(img, pts([(-0.07, 0.3), (0.07, 0.3), (0.1, 0.6), (-0.1, 0.6)], scale), INK, INK, outline=None)


def clock(img, scale=1.0):
    r = 0.9 * C * 0.78 * scale
    circle(img, (C, C), r, (250, 245, 230), (190, 180, 160), outline=(90, 60, 30), width=7 * SS)
    for k in range(12):
        a = 2 * math.pi * k / 12
        stroke(img, pts([(math.cos(a) * 0.72, math.sin(a) * 0.72), (math.cos(a) * 0.82, math.sin(a) * 0.82)], scale), INK, 3 * SS)
    stroke(img, pts([(0, 0), (0, -0.55)], scale), INK, 6 * SS)
    stroke(img, pts([(0, 0), (0.4, 0.2)], scale), INK, 6 * SS)


def badge_skull(img):
    circle(img, (C, C), 0.92 * C * 0.78, (230, 70, 60), (140, 25, 30))
    skull(img, scale=0.62, dy=0.02)


img = new(); skull(img); save(img, "skull", (230, 230, 230))
img = new(); badge_skull(img); save(img, "takedown", (255, 120, 100))
img = new(); handshake(img); save(img, "assist", (255, 230, 200))
img = new(); flag(img); save(img, "flag", (240, 240, 255))
img = new(); burst(img); save(img, "burst", (255, 200, 80))
img = new(); chevrons(img, GOLD, 3, -math.pi / 2); save(img, "rank", (255, 220, 120))
img = new(); coin(img); save(img, "coin", (255, 220, 100))
img = new(); shard(img); save(img, "shard", (120, 200, 255))
img = new(); chest(img); save(img, "chest", (200, 160, 255))
img = new(); padlock(img); save(img, "lock", (200, 200, 220))
img = new(); clock(img); save(img, "clock", (255, 240, 200))
