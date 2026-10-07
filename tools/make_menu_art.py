"""Paints the main menu's UI pieces with PIL: wooden plank buttons with brass
rims, the big wood-framed panel, dark slate inset panels, the leafy title
plaque, the green gem buttons with gold arrow ends, and the menu icons
(swords, tunic, gear, book, trophy, door, skull, gamepad, ...).

Frames are drawn to be nine-sliced by the HUD (see hud.gd `nine()`); the
margins each piece expects are noted beside it. Map card thumbnails are
cropped from in-game renders passed on the command line:

    python3 tools/make_menu_art.py                      # every UI piece
    python3 tools/make_menu_art.py thumbs day.png night.png   # map cards

Writes to assets/ui/menu.
"""
from PIL import Image, ImageDraw, ImageFilter, ImageChops, ImageEnhance
import math, os, random, sys

OUT = "assets/ui/menu"
SS = 3  # supersample

INK = (22, 14, 10)
GOLD = (246, 200, 92)
GOLD_L = (255, 236, 160)
GOLD_D = (150, 98, 30)
BRASS = (196, 140, 58)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))


def vgrad(size, stops):
    """A vertical gradient through (t, colour) stops."""
    w, h = size
    img = Image.new("RGBA", size)
    d = ImageDraw.Draw(img)
    for y in range(h):
        t = y / max(h - 1, 1)
        for k in range(len(stops) - 1):
            if stops[k][0] <= t <= stops[k + 1][0]:
                u = (t - stops[k][0]) / max(stops[k + 1][0] - stops[k][0], 1e-6)
                c = lerp(stops[k][1], stops[k + 1][1], u)
                break
        d.line([(0, y), (w, y)], fill=c + (255,) if len(c) == 3 else c)
    return img


def rounded_mask(size, box, radius):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle(box, radius=radius, fill=255)
    return m


def poly_mask(size, points):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).polygon(points, fill=255)
    return m


def wood_fill(size, base=(112, 66, 34), dark=(70, 38, 18), seed=1, planks=1, vertical=False):
    """Painted wood: warm planks with soft grain streaks and dark seams."""
    w, h = size
    rnd = random.Random(seed)
    img = vgrad(size, [(0.0, lerp(base, (255, 220, 160), 0.18)), (0.45, base), (1.0, dark)])
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    # Grain: long thin streaks, lighter and darker.
    for _ in range(int(w * h / 900) + 20):
        y = rnd.uniform(0, h)
        x0 = rnd.uniform(-w * 0.2, w)
        ln = rnd.uniform(w * 0.15, w * 0.6)
        col = (255, 220, 170, rnd.randint(10, 26)) if rnd.random() < 0.5 else (40, 18, 6, rnd.randint(18, 40))
        th = rnd.choice([1, 1, 2]) * SS
        d.line([(x0, y), (x0 + ln, y + rnd.uniform(-2, 2) * SS)], fill=col, width=th)
    # Knots.
    for _ in range(max(1, int(w * h / 60000))):
        cx, cy = rnd.uniform(0, w), rnd.uniform(0, h)
        r = rnd.uniform(3, 6) * SS
        d.ellipse([cx - r * 1.8, cy - r, cx + r * 1.8, cy + r], outline=(50, 24, 8, 70), width=SS)
    # Plank seams.
    for k in range(1, planks):
        y = h * k / planks
        d.line([(0, y), (w, y)], fill=(30, 14, 4, 170), width=2 * SS)
        d.line([(0, y + 2 * SS), (w, y + 2 * SS)], fill=(255, 210, 150, 40), width=SS)
    img = Image.alpha_composite(img, layer.filter(ImageFilter.GaussianBlur(0.6 * SS)))
    if vertical:
        img = img.rotate(90, expand=True).resize(size)
    return img


def bevel_rim(img, box, radius, width, c_light, c_mid, c_dark, outline=INK):
    """A metal rim: dark outline, a light top edge fading to a dark bottom."""
    w, h = img.size
    x0, y0, x1, y1 = box
    rim = vgrad((w, h), [(0.0, c_light), (0.5, c_mid), (1.0, c_dark)])
    outer = rounded_mask((w, h), box, radius)
    inner = rounded_mask((w, h), (x0 + width, y0 + width, x1 - width, y1 - width), max(radius - width, 1))
    ring = ImageChops.subtract(outer, inner)
    img.paste(rim, (0, 0), ring)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle(box, radius=radius, outline=outline + (255,), width=2 * SS)
    d.rounded_rectangle((x0 + width, y0 + width, x1 - width, y1 - width), radius=max(radius - width, 1), outline=outline + (200,), width=SS)
    # Specular glint along the top of the rim.
    d.line([(x0 + radius, y0 + width * 0.35), (x1 - radius, y0 + width * 0.35)], fill=c_light + (120,), width=SS)


def finish(img, name, size):
    img = img.resize(size, Image.LANCZOS)
    img.save(f"{OUT}/{name}.png")
    print("wrote", name, size)


def drop_shadow(img, offset=(0, 4), blur=5, alpha=150):
    a = img.split()[3]
    sh = Image.new("RGBA", img.size, (0, 0, 0, 0))
    sh.putalpha(a.point(lambda v: v * alpha // 255))
    sh = sh.filter(ImageFilter.GaussianBlur(blur * SS))
    canvas = Image.new("RGBA", img.size, (0, 0, 0, 0))
    canvas.paste(sh, (offset[0] * SS, offset[1] * SS), sh)
    return Image.alpha_composite(canvas, img)


# --- Buttons and frames --------------------------------------------------------

def wood_button(name, gold=False, pointed=False, size=(300, 64), seed=3):
    """The menu's plank button. Nine-slice margins: 20 px each side (36 when pointed)."""
    W, H = size[0] * SS, size[1] * SS
    pad = 4 * SS
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    box = (pad, pad, W - pad, H - pad - 2 * SS)
    tip = 18 * SS if pointed else 0
    if pointed:
        pts = [(pad + tip, pad), (W - pad - tip, pad), (W - pad, H / 2 - SS), (W - pad - tip, H - pad - 2 * SS),
               (pad + tip, H - pad - 2 * SS), (pad, H / 2 - SS)]
        outer = poly_mask((W, H), pts)
        rim_w = 6 * SS
        inner_pts = [(pad + tip + rim_w * 0.4, pad + rim_w), (W - pad - tip - rim_w * 0.4, pad + rim_w), (W - pad - rim_w * 1.6, H / 2 - SS),
                     (W - pad - tip - rim_w * 0.4, H - pad - 2 * SS - rim_w), (pad + tip + rim_w * 0.4, H - pad - 2 * SS - rim_w), (pad + rim_w * 1.6, H / 2 - SS)]
        inner = poly_mask((W, H), inner_pts)
        rim = vgrad((W, H), [(0.0, GOLD_L), (0.45, GOLD), (1.0, GOLD_D)])
        img.paste(rim, (0, 0), outer)
        img.paste(wood_fill((W, H), (120, 70, 34), (66, 34, 14), seed), (0, 0), inner)
        d = ImageDraw.Draw(img)
        d.line(pts + [pts[0]], fill=INK + (255,), width=2 * SS, joint="curve")
        d.line(inner_pts + [inner_pts[0]], fill=(60, 30, 8, 220), width=SS, joint="curve")
    else:
        r = 9 * SS
        rim_w = 5 * SS if gold else 4 * SS
        img.paste(wood_fill((W, H), (104, 60, 30), (58, 30, 12), seed), (0, 0), rounded_mask((W, H), box, r))
        if gold:
            bevel_rim(img, box, r, rim_w, GOLD_L, GOLD, GOLD_D)
        else:
            bevel_rim(img, box, r, rim_w, (226, 170, 96), BRASS, (96, 60, 22))
        # Brass rivets in the corners.
        d = ImageDraw.Draw(img)
        for cx in (box[0] + rim_w + 6 * SS, box[2] - rim_w - 6 * SS):
            for cy in (box[1] + rim_w + 5 * SS, box[3] - rim_w - 5 * SS):
                d.ellipse([cx - 2.2 * SS, cy - 2.2 * SS, cx + 2.2 * SS, cy + 2.2 * SS], fill=(220, 170, 90, 255), outline=INK + (255,), width=SS)
    # Inner top sheen.
    sheen = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(sheen).rounded_rectangle((pad + 10 * SS + tip, pad + 7 * SS, W - pad - 10 * SS - tip, pad + 7 * SS + H * 0.16), radius=4 * SS, fill=(255, 235, 200, 34))
    img = Image.alpha_composite(img, sheen.filter(ImageFilter.GaussianBlur(2 * SS)))
    img = drop_shadow(img, (0, 3), 3, 140)
    finish(img, name, size)


def green_button(name, color=((120, 214, 70), (54, 150, 40), (24, 92, 22)), size=(360, 72)):
    """START MATCH / CONFIRM: a glossy gem bar in a gold frame with arrow ends.
    Nine-slice margins: 48 px left and right, 20 top and bottom."""
    W, H = size[0] * SS, size[1] * SS
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    cy = H / 2 - SS
    p = 4 * SS
    tip = 26 * SS
    outer = [(p + tip, p), (W - p - tip, p), (W - p, cy), (W - p - tip, H - p - 2 * SS), (p + tip, H - p - 2 * SS), (p, cy)]
    img.paste(vgrad((W, H), [(0.0, GOLD_L), (0.5, GOLD), (1.0, GOLD_D)]), (0, 0), poly_mask((W, H), outer))
    d = ImageDraw.Draw(img)
    d.line(outer + [outer[0]], fill=INK + (255,), width=2 * SS, joint="curve")
    # Little notches where the arrow ends meet the bar.
    for x in (p + tip + 4 * SS, W - p - tip - 4 * SS):
        d.line([(x, p + 3 * SS), (x, H - p - 5 * SS)], fill=GOLD_D + (255,), width=SS)
    rim = 7 * SS
    bar = (p + tip + 8 * SS, p + rim, W - p - tip - 8 * SS, H - p - 2 * SS - rim)
    c1, c2, c3 = color
    img.paste(vgrad((W, H), [(0.0, c1), (0.5, c2), (1.0, c3)]), (0, 0), rounded_mask((W, H), bar, 6 * SS))
    d.rounded_rectangle(bar, radius=6 * SS, outline=INK + (230,), width=SS)
    gloss = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(gloss).rounded_rectangle((bar[0] + 6 * SS, bar[1] + 3 * SS, bar[2] - 6 * SS, bar[1] + (bar[3] - bar[1]) * 0.42), radius=5 * SS, fill=(255, 255, 255, 70))
    img = Image.alpha_composite(img, gloss.filter(ImageFilter.GaussianBlur(1.5 * SS)))
    # Arrow-head studs on the ends.
    d = ImageDraw.Draw(img)
    for s, x in ((-1, p + tip * 0.62), (1, W - p - tip * 0.62)):
        a = [(x - s * 6 * SS, cy - 9 * SS), (x + s * 5 * SS, cy), (x - s * 6 * SS, cy + 9 * SS)]
        d.polygon(a, fill=(255, 245, 200, 255), outline=INK + (255,))
    img = drop_shadow(img, (0, 4), 4, 160)
    finish(img, name, size)


def big_frame(name, size=(400, 300)):
    """The wood-framed panel behind SELECT MAP. Nine-slice margins: 40 px."""
    W, H = size[0] * SS, size[1] * SS
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    p = 6 * SS
    box = (p, p, W - p, H - p)
    img.paste(wood_fill((W, H), (110, 64, 30), (64, 34, 14), 7, planks=1), (0, 0), rounded_mask((W, H), box, 16 * SS))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle(box, radius=16 * SS, outline=INK + (255,), width=3 * SS)
    # A brass inner rim, then the dark slate inside.
    fw = 22 * SS
    inner = (p + fw, p + fw, W - p - fw, H - p - fw)
    bevel_rim(img, (inner[0] - 4 * SS, inner[1] - 4 * SS, inner[2] + 4 * SS, inner[3] + 4 * SS), 8 * SS, 4 * SS, (230, 180, 100), BRASS, (90, 56, 20))
    img.paste(vgrad((W, H), [(0.0, (46, 40, 36)), (1.0, (28, 24, 22))]), (0, 0), rounded_mask((W, H), inner, 6 * SS))
    # Inner shadow along the top of the inset.
    sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(sh).rectangle((inner[0], inner[1], inner[2], inner[1] + 10 * SS), fill=(0, 0, 0, 120))
    img = Image.alpha_composite(img, sh.filter(ImageFilter.GaussianBlur(4 * SS)))
    d = ImageDraw.Draw(img)
    # Gold corner brackets with rivets.
    for sx, sy, cx, cy in ((1, 1, box[0], box[1]), (-1, 1, box[2], box[1]), (1, -1, box[0], box[3]), (-1, -1, box[2], box[3])):
        L = 34 * SS
        t = 9 * SS
        pts = [(cx, cy), (cx + sx * L, cy), (cx + sx * L, cy + sy * t), (cx + sx * t, cy + sy * t), (cx + sx * t, cy + sy * L), (cx, cy + sy * L)]
        pm = poly_mask((W, H), pts)
        img.paste(vgrad((W, H), [(0.0, GOLD_L), (0.5, GOLD), (1.0, GOLD_D)]), (0, 0), pm)
        d.line(pts + [pts[0]], fill=INK + (255,), width=SS * 2, joint="curve")
        rx, ry = cx + sx * 5 * SS, cy + sy * 5 * SS
        d.ellipse([rx - 2.5 * SS, ry - 2.5 * SS, rx + 2.5 * SS, ry + 2.5 * SS], fill=(255, 240, 190, 255), outline=INK + (255,))
    img = drop_shadow(img, (0, 6), 8, 170)
    finish(img, name, size)


def slate_panel(name, size=(200, 120), fill=((40, 46, 56), (26, 30, 38)), edge=(150, 112, 56)):
    """A dark inset panel (GAME SETTINGS, APPEARANCE, the lobby name plates).
    Nine-slice margins: 14 px."""
    W, H = size[0] * SS, size[1] * SS
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    p = 3 * SS
    box = (p, p, W - p, H - p)
    img.paste(vgrad((W, H), [(0.0, fill[0]), (1.0, fill[1])]), (0, 0), rounded_mask((W, H), box, 7 * SS))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle(box, radius=7 * SS, outline=INK + (255,), width=2 * SS)
    d.rounded_rectangle((box[0] + 2 * SS, box[1] + 2 * SS, box[2] - 2 * SS, box[3] - 2 * SS), radius=6 * SS, outline=edge + (255,), width=SS * 2)
    d.rounded_rectangle((box[0] + 5 * SS, box[1] + 5 * SS, box[2] - 5 * SS, box[3] - 5 * SS), radius=4 * SS, outline=(0, 0, 0, 90), width=SS)
    finish(img, name, size)


def leaf_shape(d, base, angle, length, width, c1, c2):
    """One painted leaf from `base` pointing along `angle`."""
    ca, sa = math.cos(angle), math.sin(angle)
    pts = []
    for i in range(21):
        t = i / 20
        r = math.sin(math.pi * t) ** 0.8 * width
        pts.append((t * length, r))
    for i in range(20, -1, -1):
        t = i / 20
        r = math.sin(math.pi * t) ** 0.8 * width
        pts.append((t * length, -r))
    world = [(base[0] + x * ca - y * sa, base[1] + x * sa + y * ca) for x, y in pts]
    d.polygon(world, fill=c1 + (255,), outline=INK + (255,))
    # Light half and the midrib.
    half = [(base[0] + x * ca - y * sa, base[1] + x * sa + y * ca) for x, y in pts[:21]] + [(base[0] + length * ca, base[1] + length * sa)]
    d.polygon(half, fill=c2 + (255,))
    d.line([base, (base[0] + length * 0.9 * ca, base[1] + length * 0.9 * sa)], fill=lerp(c1, INK, 0.5) + (255,), width=max(1, int(SS * 1.2)))


def plaque(name, size=(520, 76)):
    """The title plaque (SELECT MAP, READY UP...): a dark wood board in a gold
    rim with scrolled ends and sprays of leaves. Nine-slice margins: 110 px
    left and right, 24 top and bottom."""
    W, H = size[0] * SS, size[1] * SS
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    leaves = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ld = ImageDraw.Draw(leaves)
    rnd = random.Random(11)
    for side in (-1, 1):
        cx = W / 2 + side * (W / 2 - 62 * SS)
        for k in range(9):
            ang = (math.pi if side < 0 else 0.0) + rnd.uniform(-1.1, 1.1)
            base = (cx + rnd.uniform(-10, 10) * SS, H / 2 + rnd.uniform(-8, 8) * SS)
            ln = rnd.uniform(34, 50) * SS
            c = rnd.choice([((60, 140, 40), (110, 190, 60)), ((40, 112, 34), (86, 164, 52)), ((86, 160, 44), (150, 210, 80))])
            leaf_shape(ld, base, ang, ln, ln * 0.32, c[0], c[1])
    img = Image.alpha_composite(img, drop_shadow(leaves, (0, 2), 2, 120))
    # The board: a long hexagon with scrolled ends.
    p = 64 * SS
    t = 4 * SS
    cy = H / 2
    board = [(p + 22 * SS, t), (W - p - 22 * SS, t), (W - p, cy), (W - p - 22 * SS, H - t - 4 * SS), (p + 22 * SS, H - t - 4 * SS), (p, cy)]
    board_img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    board_img.paste(vgrad((W, H), [(0.0, GOLD_L), (0.5, GOLD), (1.0, GOLD_D)]), (0, 0), poly_mask((W, H), board))
    rim = 6 * SS
    inner = [(p + 22 * SS + rim * 0.4, t + rim), (W - p - 22 * SS - rim * 0.4, t + rim), (W - p - rim * 1.5, cy),
             (W - p - 22 * SS - rim * 0.4, H - t - 4 * SS - rim), (p + 22 * SS + rim * 0.4, H - t - 4 * SS - rim), (p + rim * 1.5, cy)]
    board_img.paste(wood_fill((W, H), (92, 52, 26), (48, 24, 10), 5), (0, 0), poly_mask((W, H), inner))
    bd = ImageDraw.Draw(board_img)
    bd.line(board + [board[0]], fill=INK + (255,), width=2 * SS, joint="curve")
    bd.line(inner + [inner[0]], fill=(40, 20, 6, 230), width=SS, joint="curve")
    # Scroll curls at both ends.
    for side in (-1, 1):
        x = W / 2 + side * (W / 2 - p + 6 * SS)
        for r in (11 * SS, 6 * SS):
            bd.arc([x - r, cy - r, x + r, cy + r], 0, 360, fill=GOLD + (255,), width=3 * SS)
            bd.arc([x - r, cy - r, x + r, cy + r], 0, 360, fill=INK + (200,), width=SS)
    img = Image.alpha_composite(img, drop_shadow(board_img, (0, 4), 4, 160))
    finish(img, name, size)


def tag(name, size=(120, 40)):
    """The P1-P4 header tag: a white ribbon the HUD tints per player.
    Nine-slice margins: 14 px."""
    W, H = size[0] * SS, size[1] * SS
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    p = 3 * SS
    box = (p, p, W - p, H - p - 2 * SS)
    img.paste(vgrad((W, H), [(0.0, (255, 255, 255)), (0.55, (215, 215, 215)), (1.0, (150, 150, 150))]), (0, 0), rounded_mask((W, H), box, 6 * SS))
    bevel_rim(img, box, 6 * SS, 3 * SS, GOLD_L, GOLD, GOLD_D)
    img = drop_shadow(img, (0, 3), 3, 150)
    finish(img, name, size)


# --- Icons ---------------------------------------------------------------------

N = 96 * SS
C = N / 2
CREAM = (246, 236, 214)
CREAM_D = (186, 168, 138)
STEEL = (225, 230, 240)
STEEL_D = (120, 130, 150)


def P(seq, s=1.0, dx=0.0, dy=0.0, rot=0.0):
    cr, sr = math.cos(rot), math.sin(rot)
    return [(C + ((x * cr - y * sr) * s + dx) * C * 0.8, C + ((x * sr + y * cr) * s + dy) * C * 0.8) for x, y in seq]


def fillpoly(img, pts, c1, c2=None, outline=INK, width=4):
    c2 = c2 or c1
    m = poly_mask(img.size, pts)
    img.paste(vgrad(img.size, [(0.0, c1), (1.0, c2)]), (0, 0), m)
    if outline:
        ImageDraw.Draw(img).line(pts + [pts[0]], fill=outline + (255,), width=width * SS, joint="curve")


def disc(img, c, r, c1, c2=None, outline=INK, width=4):
    c2 = c2 or c1
    m = Image.new("L", img.size, 0)
    ImageDraw.Draw(m).ellipse([c[0] - r, c[1] - r, c[0] + r, c[1] + r], fill=255)
    img.paste(vgrad(img.size, [(0.0, c1), (1.0, c2)]), (0, 0), m)
    if outline:
        ImageDraw.Draw(img).ellipse([c[0] - r, c[1] - r, c[0] + r, c[1] + r], outline=outline + (255,), width=width * SS)


def line(img, pts, color, width):
    ImageDraw.Draw(img).line(pts, fill=color + (255,), width=int(width * SS), joint="curve")


def icon_save(img, name):
    img = drop_shadow(img, (0, 2), 2, 160)
    img.resize((96, 96), Image.LANCZOS).save(f"{OUT}/icon_{name}.png")
    print("wrote icon", name)


def sword(img, rot, s=1.0, dx=0.0, dy=0.0):
    fillpoly(img, P([(-0.11, 0.3), (0.11, 0.3), (0.11, -0.78), (0.0, -0.98), (-0.11, -0.78)], s, dx, dy, rot), STEEL, STEEL_D)
    line(img, P([(0.0, 0.25), (0.0, -0.82)], s, dx, dy, rot), (255, 255, 255), 2)
    fillpoly(img, P([(-0.4, 0.3), (0.4, 0.3), (0.4, 0.44), (-0.4, 0.44)], s, dx, dy, rot), GOLD, GOLD_D)
    fillpoly(img, P([(-0.08, 0.44), (0.08, 0.44), (0.08, 0.84), (-0.08, 0.84)], s, dx, dy, rot), (140, 84, 44), (80, 44, 20))
    disc(img, P([(0, 0.93)], s, dx, dy, rot)[0], 0.11 * C * 0.8 * s, GOLD, GOLD_D, width=3)


def make_icons():
    # Crossed swords (PLAY, START MATCH).
    img = Image.new("RGBA", (N, N))
    sword(img, -math.pi / 4, 0.95)
    sword(img, math.pi / 4, 0.95)
    icon_save(img, "swords")
    # Tunic (CUSTOMIZE, ARMOR).
    img = Image.new("RGBA", (N, N))
    tunic = [(-0.35, -0.8), (-0.12, -0.7), (0.0, -0.55), (0.12, -0.7), (0.35, -0.8), (0.85, -0.45), (0.65, -0.05), (0.45, -0.18),
             (0.45, 0.85), (-0.45, 0.85), (-0.45, -0.18), (-0.65, -0.05), (-0.85, -0.45)]
    fillpoly(img, P(tunic), CREAM, CREAM_D)
    line(img, P([(-0.45, 0.35), (0.45, 0.35)]), (150, 120, 80), 3)
    icon_save(img, "tunic")
    # Gear (SETTINGS).
    img = Image.new("RGBA", (N, N))
    g = []
    for i in range(16):
        a = math.pi * i / 8
        for off, r in ((-0.09, 0.95 if i % 2 == 0 else 0.7), (0.09, 0.95 if i % 2 == 0 else 0.7)):
            g.append((math.cos(a + off) * r, math.sin(a + off) * r))
    fillpoly(img, P(g), CREAM, CREAM_D)
    disc(img, (C, C), 0.28 * C * 0.8, (60, 50, 44), (30, 24, 20))
    icon_save(img, "gear")
    # Open book (TUTORIAL).
    img = Image.new("RGBA", (N, N))
    for s in (-1, 1):
        page = [(0.0, -0.45), (s * 0.4, -0.62), (s * 0.92, -0.5), (s * 0.92, 0.6), (s * 0.4, 0.48), (0.0, 0.65)]
        fillpoly(img, P(page), CREAM, CREAM_D)
        for k in range(3):
            y = -0.3 + k * 0.25
            line(img, P([(s * 0.18, y), (s * 0.75, y - 0.06)]), (150, 125, 90), 2)
    line(img, P([(0.0, -0.45), (0.0, 0.65)]), INK, 4)
    icon_save(img, "book")
    # Trophy (CREDITS).
    img = Image.new("RGBA", (N, N))
    for s in (-1, 1):
        ImageDraw.Draw(img).arc([C + s * 0.55 * C * 0.8 - 0.3 * C * 0.8, C - 0.65 * C * 0.8, C + s * 0.55 * C * 0.8 + 0.3 * C * 0.8, C - 0.05 * C * 0.8],
                                90 if s > 0 else 270, 270 if s > 0 else 90, fill=INK + (255,), width=9 * SS)
        ImageDraw.Draw(img).arc([C + s * 0.55 * C * 0.8 - 0.3 * C * 0.8, C - 0.65 * C * 0.8, C + s * 0.55 * C * 0.8 + 0.3 * C * 0.8, C - 0.05 * C * 0.8],
                                90 if s > 0 else 270, 270 if s > 0 else 90, fill=CREAM + (255,), width=4 * SS)
    fillpoly(img, P([(-0.55, -0.8), (0.55, -0.8), (0.45, -0.2), (0.15, 0.15), (0.12, 0.45), (-0.12, 0.45), (-0.15, 0.15), (-0.45, -0.2)]), CREAM, CREAM_D)
    fillpoly(img, P([(-0.45, 0.45), (0.45, 0.45), (0.45, 0.8), (-0.45, 0.8)]), CREAM, CREAM_D)
    icon_save(img, "trophy")
    # Door with an arrow (EXIT).
    img = Image.new("RGBA", (N, N))
    fillpoly(img, P([(-0.2, -0.9), (0.75, -0.9), (0.75, 0.9), (-0.2, 0.9)]), (120, 110, 100), (70, 62, 56))
    fillpoly(img, P([(-0.2, -0.9), (0.45, -0.7), (0.45, 0.95), (-0.2, 0.9)]), CREAM, CREAM_D)
    disc(img, P([(0.28, 0.05)])[0], 0.06 * C * 0.8, INK, None, None)
    line(img, P([(-0.92, 0.0), (-0.35, 0.0)]), INK, 11)
    line(img, P([(-0.92, 0.0), (-0.35, 0.0)]), CREAM, 5)
    fillpoly(img, P([(-0.98, 0.0), (-0.68, -0.3), (-0.68, 0.3)]), CREAM, CREAM_D)
    icon_save(img, "exit")
    # Crown (CASUAL / NORMAL).
    img = Image.new("RGBA", (N, N))
    fillpoly(img, P([(-0.85, 0.55), (-0.95, -0.45), (-0.45, 0.0), (0.0, -0.75), (0.45, 0.0), (0.95, -0.45), (0.85, 0.55)]), GOLD_L, GOLD_D)
    fillpoly(img, P([(-0.85, 0.5), (0.85, 0.5), (0.85, 0.75), (-0.85, 0.75)]), GOLD, GOLD_D)
    for x, col in ((-0.45, (80, 150, 255)), (0.0, (230, 40, 50)), (0.45, (80, 150, 255))):
        disc(img, P([(x, 0.28)])[0], 0.1 * C * 0.8, col, lerp(col, INK, 0.4), width=2)
    icon_save(img, "crown")
    # Skull (HARDCORE).
    img = Image.new("RGBA", (N, N))
    disc(img, P([(0.0, -0.15)])[0], 0.72 * C * 0.8, (240, 90, 80), (170, 30, 30))
    fillpoly(img, P([(-0.42, 0.3), (0.42, 0.3), (0.35, 0.85), (-0.35, 0.85)]), (240, 90, 80), (170, 30, 30))
    for x in (-0.3, 0.3):
        disc(img, P([(x, -0.12)])[0], 0.2 * C * 0.8, (40, 10, 10), None, None)
    fillpoly(img, P([(0.0, 0.15), (0.1, 0.35), (-0.1, 0.35)]), (40, 10, 10), None, None)
    for x in (-0.18, 0.0, 0.18):
        line(img, P([(x, 0.55), (x, 0.82)]), (90, 20, 20), 3)
    icon_save(img, "skull")
    # Gamepad (SPLIT SCREEN).
    img = Image.new("RGBA", (N, N))
    pad = []
    for i in range(40):
        a = math.pi * 2 * i / 40
        x = math.cos(a) * 0.95
        y = math.sin(a) * 0.5
        if y > 0.15:
            y += 0.25 * abs(x) ** 0.5
        pad.append((x, y))
    fillpoly(img, P(pad), CREAM, CREAM_D)
    line(img, P([(-0.6, 0.0), (-0.25, 0.0)]), INK, 5)
    line(img, P([(-0.425, -0.17), (-0.425, 0.17)]), INK, 5)
    for x, y in ((0.4, -0.1), (0.6, 0.08)):
        disc(img, P([(x, y)])[0], 0.09 * C * 0.8, INK, None, None)
    icon_save(img, "gamepad")
    # Green check disc (Ready).
    img = Image.new("RGBA", (N, N))
    disc(img, (C, C), 0.9 * C * 0.8, (110, 220, 90), (30, 130, 40))
    line(img, P([(-0.45, 0.0), (-0.12, 0.35), (0.5, -0.38)]), INK, 14)
    line(img, P([(-0.45, 0.0), (-0.12, 0.35), (0.5, -0.38)]), (255, 255, 255), 8)
    icon_save(img, "check")
    # Grey wait disc (not ready).
    img = Image.new("RGBA", (N, N))
    disc(img, (C, C), 0.9 * C * 0.8, (150, 150, 160), (80, 80, 90))
    for x in (-0.38, 0.0, 0.38):
        disc(img, P([(x, 0.0)])[0], 0.1 * C * 0.8, (255, 255, 255), None, None)
    icon_save(img, "wait")
    # Lock.
    img = Image.new("RGBA", (N, N))
    ImageDraw.Draw(img).arc([C - 0.42 * C * 0.8, C - 0.95 * C * 0.8, C + 0.42 * C * 0.8, C - 0.1 * C * 0.8], 180, 360, fill=INK + (255,), width=13 * SS)
    ImageDraw.Draw(img).arc([C - 0.42 * C * 0.8, C - 0.95 * C * 0.8, C + 0.42 * C * 0.8, C - 0.1 * C * 0.8], 180, 360, fill=(200, 205, 215, 255), width=6 * SS)
    line(img, P([(-0.42, -0.55), (-0.42, -0.1)]), INK, 13)
    line(img, P([(0.42, -0.55), (0.42, -0.1)]), INK, 13)
    line(img, P([(-0.42, -0.55), (-0.42, -0.1)]), (200, 205, 215), 6)
    line(img, P([(0.42, -0.55), (0.42, -0.1)]), (200, 205, 215), 6)
    fillpoly(img, P([(-0.65, -0.15), (0.65, -0.15), (0.65, 0.85), (-0.65, 0.85)]), GOLD_L, GOLD_D)
    disc(img, P([(0, 0.25)])[0], 0.12 * C * 0.8, INK, None, None)
    line(img, P([(0, 0.3), (0, 0.55)]), INK, 5)
    icon_save(img, "lock")
    # Head (APPEARANCE / FACE).
    for name, hair in (("face", False), ("appearance", True)):
        img = Image.new("RGBA", (N, N))
        disc(img, P([(0, 0.05)])[0], 0.72 * C * 0.8, CREAM, CREAM_D)
        if hair:
            fillpoly(img, P([(-0.74, 0.0), (-0.6, -0.55), (-0.1, -0.78), (0.45, -0.68), (0.76, -0.1), (0.4, -0.35), (-0.05, -0.3), (-0.45, -0.2)]), (120, 90, 70), (70, 50, 40))
        for x in (-0.27, 0.27):
            disc(img, P([(x, 0.1)])[0], 0.09 * C * 0.8, INK, None, None)
        ImageDraw.Draw(img).arc([C - 0.25 * C * 0.8, C + 0.05 * C * 0.8, C + 0.25 * C * 0.8, C + 0.45 * C * 0.8], 20, 160, fill=INK + (255,), width=3 * SS)
        icon_save(img, name)
    # Hair.
    img = Image.new("RGBA", (N, N))
    fillpoly(img, P([(-0.85, 0.75), (-0.8, -0.2), (-0.45, -0.75), (0.1, -0.9), (0.6, -0.7), (0.88, -0.15), (0.85, 0.75), (0.55, 0.3),
                     (0.5, -0.2), (0.1, -0.35), (-0.3, -0.15), (-0.5, 0.3)]), CREAM, CREAM_D)
    for x in (-0.35, 0.05, 0.4):
        line(img, P([(x, -0.75), (x - 0.15, -0.35)]), (150, 120, 80), 2)
    icon_save(img, "hair")
    # Palette (COLORS).
    img = Image.new("RGBA", (N, N))
    pal = [(math.cos(a) * 0.9, math.sin(a) * 0.72) for a in [math.pi * 2 * i / 36 for i in range(36)]]
    fillpoly(img, P(pal), CREAM, CREAM_D)
    disc(img, P([(0.42, 0.3)])[0], 0.16 * C * 0.8, (60, 40, 30), None, None)
    for (x, y), col in zip(((-0.5, -0.2), (-0.15, -0.45), (0.25, -0.42), (-0.45, 0.25)), ((230, 60, 60), (70, 140, 240), (250, 200, 60), (80, 190, 80))):
        disc(img, P([(x, y)])[0], 0.15 * C * 0.8, col, lerp(col, INK, 0.3), width=2)
    icon_save(img, "palette")
    # Emblem (a round crest with a star).
    img = Image.new("RGBA", (N, N))
    disc(img, (C, C), 0.9 * C * 0.8, CREAM, CREAM_D)
    disc(img, (C, C), 0.62 * C * 0.8, (70, 64, 60), (40, 36, 34), width=3)
    star = []
    for i in range(10):
        a = -math.pi / 2 + math.pi * i / 5
        r = 0.5 if i % 2 == 0 else 0.22
        star.append((math.cos(a) * r, math.sin(a) * r))
    fillpoly(img, P(star), GOLD_L, GOLD_D, width=2)
    icon_save(img, "emblem")
    # Chevron arrows (map paging, body type).
    for name, s in (("arrow_left", -1), ("arrow_right", 1)):
        img = Image.new("RGBA", (N, N))
        fillpoly(img, P([(-0.35 * s, -0.85), (0.55 * s, 0.0), (-0.35 * s, 0.85), (-0.55 * s, 0.6), (0.12 * s, 0.0), (-0.55 * s, -0.6)]), GOLD_L, GOLD_D)
        icon_save(img, name)
    # Body silhouettes: slim, sturdy, broad.
    for name, w in (("body_slim", 0.28), ("body_sturdy", 0.38), ("body_broad", 0.5)):
        img = Image.new("RGBA", (N, N))
        disc(img, P([(0, -0.62)])[0], 0.24 * C * 0.8, CREAM, CREAM_D, width=3)
        fillpoly(img, P([(-w, -0.32), (w, -0.32), (w * 1.05, 0.3), (w * 0.6, 0.3), (w * 0.55, 0.95), (-w * 0.55, 0.95), (-w * 0.6, 0.3), (-w * 1.05, 0.3)]), CREAM, CREAM_D, width=3)
        icon_save(img, name)


# --- Map thumbnails -------------------------------------------------------------

def thumbs(day_path, night_path):
    """The map cards: the Wildwood and its moonlit night, cropped from
    renders; the coming-soon cards are the same valley graded to their
    planned themes (snow, embers, twilight), then dimmed and locked in-game."""
    def card(src):
        # The whole frame, shrunk: the card crops it to its own shape in-game.
        return Image.open(src).convert("RGB").resize((480, 270), Image.LANCZOS)

    day = card(day_path)
    day.save(f"{OUT}/map_wildwood.png")
    card(night_path).save(f"{OUT}/map_moonlit.png")
    grades = {
        "map_stonekeep": ((0.75, 0.85, 1.05), 0.35, 1.25),   # cold blue-white, desaturated, bright
        "map_ember": ((1.25, 0.62, 0.38), 1.25, 0.9),       # orange-red
        "map_twilight": ((0.8, 0.5, 1.15), 1.1, 0.8),        # violet
    }
    for name, (mul, sat, bright) in grades.items():
        im = ImageEnhance.Color(day).enhance(sat)
        r, g, b = im.split()
        im = Image.merge("RGB", (r.point(lambda v: min(255, int(v * mul[0]))), g.point(lambda v: min(255, int(v * mul[1]))), b.point(lambda v: min(255, int(v * mul[2])))))
        im = ImageEnhance.Brightness(im).enhance(bright)
        im.save(f"{OUT}/{name}.png")
        print("wrote", name)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    if len(sys.argv) > 1 and sys.argv[1] == "thumbs":
        thumbs(sys.argv[2], sys.argv[3])
        sys.exit(0)
    wood_button("btn_wood")
    wood_button("btn_wood_hi", gold=True, seed=4)
    wood_button("btn_play", gold=True, pointed=True, size=(320, 72), seed=5)
    green_button("btn_green")
    green_button("btn_green_off", ((150, 150, 150), (100, 100, 100), (60, 60, 60)))
    big_frame("frame_big")
    slate_panel("panel_slate")
    slate_panel("panel_row", (200, 60), ((48, 54, 66), (32, 36, 46)), (110, 96, 74))
    plaque("plaque")
    tag("tag")
    make_icons()
