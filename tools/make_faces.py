"""Paints the characters' chibi anime faces: big glossy eyes with heavy upper
lashes and two highlights, eyebrows, cheek blush and small mouths, in four
face styles (Bold, Bright, Fierce, Gentle) and two iris colours (brown for
Humans, green for Elves).

scripts/face.gd lays these on curved patches in front of the KayKit heads:
- face_eyes_<style>_<iris>.png  512x256, covers head x -0.36..0.36, y 1.48..1.84
- face_brows_<style>.png        same frame, white (tinted to the hair colour)
- face_mouth_<style>.png        128x64, covers x -0.12..0.12, y 1.32..1.44

    python3 tools/make_faces.py      # writes assets/characters/faces
"""
from PIL import Image, ImageDraw, ImageFilter, ImageChops
import math, os

OUT = "assets/characters/faces"
SS = 4
INK = (34, 20, 18)
STYLES = ["bold", "bright", "fierce", "gentle"]
IRIS = {
    "brown": ((60, 32, 18), (150, 84, 34), (226, 160, 72)),
    "green": ((22, 58, 30), (52, 128, 60), (150, 214, 100)),
}

# Patch frame in head units (model space) -> pixels.
EW, EH = 512, 256
X0, X1, Y0, Y1 = -0.36, 0.36, 1.48, 1.84


def px(x, y, w=EW, h=EH, x0=X0, x1=X1, y0=Y0, y1=Y1):
    return ((x - x0) / (x1 - x0) * w * SS, (y1 - y) / (y1 - y0) * h * SS)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))


def vgrad(size, top, bottom, y_from=0, y_to=None):
    w, h = size
    y_to = h if y_to is None else y_to
    img = Image.new("RGBA", size)
    d = ImageDraw.Draw(img)
    for y in range(h):
        t = min(max((y - y_from) / max(y_to - y_from, 1), 0.0), 1.0)
        d.line([(0, y), (w, y)], fill=lerp(top, bottom, t) + (255,))
    return img


# Per-style eye shapes: size, how much the upper lid cuts in (0 none), the
# lid's tilt toward the nose, lash weight and highlight size.
SHAPES = {
    "bold": dict(w=0.2, h=0.25, lid=0.17, tilt=0.05, lash=1.0, hi=1.0, iris=0.84),
    "bright": dict(w=0.205, h=0.265, lid=0.05, tilt=-0.02, lash=0.9, hi=1.2, iris=0.82),
    "fierce": dict(w=0.205, h=0.22, lid=0.3, tilt=0.12, lash=1.15, hi=0.85, iris=0.86),
    "gentle": dict(w=0.2, h=0.24, lid=0.36, tilt=-0.06, lash=0.9, hi=0.95, iris=0.82),
}
BROWS = {
    # (inner (x, y), outer (x, y), arch height, thickness) for the right eye, in head units
    "bold": ((0.07, 1.79), (0.29, 1.805), -0.004, 0.03),
    "bright": ((0.08, 1.805), (0.29, 1.815), 0.018, 0.024),
    "fierce": ((0.065, 1.77), (0.3, 1.825), -0.01, 0.032),
    "gentle": ((0.08, 1.81), (0.29, 1.79), 0.014, 0.022),
}


def eye(img, cx, cy, side, shape, iris):
    """One eye at (cx, cy) head units; side +1 = viewer's right."""
    w, h = shape["w"], shape["h"]
    W, H = img.size
    l, t = px(cx - w / 2, cy + h / 2)
    r, b = px(cx + w / 2, cy - h / 2)
    # The eye opening: an ellipse with the upper lid cutting across it.
    oval = Image.new("L", (W, H), 0)
    ImageDraw.Draw(oval).ellipse([l, t, r, b], fill=255)
    lid_y_inner = t + (b - t) * (shape["lid"] + shape["tilt"])
    lid_y_outer = t + (b - t) * (shape["lid"] - shape["tilt"])
    inner_x, outer_x = (l, r) if side > 0 else (r, l)
    cut = Image.new("L", (W, H), 0)
    ImageDraw.Draw(cut).polygon([(inner_x, lid_y_inner), (outer_x, lid_y_outer), (outer_x, H), (inner_x, H)], fill=255)
    mask = ImageChops.multiply(oval, cut)
    # Sclera: white, shaded blue-grey under the lid.
    img.paste(vgrad((W, H), (190, 198, 214), (255, 255, 255), int(min(lid_y_inner, lid_y_outer)), int(t + (b - t) * 0.6)), (0, 0), mask)
    # Iris and pupil, a little toward the nose and down.
    iw, ih = (r - l) * shape["iris"], (b - t) * 0.9
    icx = (l + r) / 2 - side * (r - l) * 0.04
    icy = (t + b) / 2 + (b - t) * 0.06
    imask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(imask).ellipse([icx - iw / 2, icy - ih / 2, icx + iw / 2, icy + ih / 2], fill=255)
    imask = ImageChops.multiply(imask, mask)
    dark, mid, light = IRIS[iris]
    img.paste(vgrad((W, H), dark, light, int(icy - ih / 2), int(icy + ih / 2)), (0, 0), imask)
    d = ImageDraw.Draw(img)
    # A darker ring and the pupil.
    ring = Image.new("L", (W, H), 0)
    ImageDraw.Draw(ring).ellipse([icx - iw / 2, icy - ih / 2, icx + iw / 2, icy + ih / 2], outline=255, width=int(iw * 0.07))
    img.paste(Image.new("RGBA", (W, H), dark + (255,)), (0, 0), ImageChops.multiply(ring, mask))
    pw, ph = iw * 0.42, ih * 0.5
    pm = Image.new("L", (W, H), 0)
    ImageDraw.Draw(pm).ellipse([icx - pw / 2, icy - ph / 2 - ih * 0.04, icx + pw / 2, icy + ph / 2 - ih * 0.04], fill=255)
    img.paste(Image.new("RGBA", (W, H), lerp(dark, (0, 0, 0), 0.5) + (255,)), (0, 0), ImageChops.multiply(pm, mask))
    # A warm glow low in the iris.
    glow = Image.new("L", (W, H), 0)
    ImageDraw.Draw(glow).ellipse([icx - iw * 0.32, icy + ih * 0.08, icx + iw * 0.32, icy + ih * 0.42], fill=120)
    glow = glow.filter(ImageFilter.GaussianBlur(iw * 0.08))
    img.paste(Image.new("RGBA", (W, H), light + (255,)), (0, 0), ImageChops.multiply(glow, mask))
    # The lid's shadow over the top of the eye.
    sh = Image.new("L", (W, H), 0)
    ImageDraw.Draw(sh).polygon([(inner_x, lid_y_inner - 4), (outer_x, lid_y_outer - 4),
                                (outer_x, lid_y_outer + (b - t) * 0.22), (inner_x, lid_y_inner + (b - t) * 0.22)], fill=110)
    sh = sh.filter(ImageFilter.GaussianBlur((b - t) * 0.06))
    img.paste(Image.new("RGBA", (W, H), (20, 10, 16, 255)), (0, 0), ImageChops.multiply(sh, mask))
    # Highlights: a big one up and out, a small one down and in.
    hs = shape["hi"]
    hl = Image.new("L", (W, H), 0)
    hd = ImageDraw.Draw(hl)
    hx, hy = icx + side * iw * 0.16, icy - ih * 0.2
    hd.ellipse([hx - iw * 0.17 * hs, hy - ih * 0.15 * hs, hx + iw * 0.17 * hs, hy + ih * 0.15 * hs], fill=255)
    hx2, hy2 = icx - side * iw * 0.18, icy + ih * 0.22
    hd.ellipse([hx2 - iw * 0.07 * hs, hy2 - ih * 0.06 * hs, hx2 + iw * 0.07 * hs, hy2 + ih * 0.06 * hs], fill=235)
    img.paste(Image.new("RGBA", (W, H), (255, 255, 255, 255)), (0, 0), ImageChops.multiply(hl, mask))
    # Upper lash: heavy along the lid, thickest at the outer corner, with a flick.
    lw = (b - t) * 0.12 * shape["lash"]
    steps = 24
    pts = []
    for k in range(steps + 1):
        u = k / steps
        x = inner_x + (outer_x - inner_x) * u
        # Follow the higher of the lid line and the ellipse top.
        ex = (x - (l + r) / 2) / ((r - l) / 2)
        top_oval = (t + b) / 2 - (b - t) / 2 * math.sqrt(max(1 - ex * ex, 0))
        lid = lid_y_inner + (lid_y_outer - lid_y_inner) * u
        pts.append((x, max(top_oval, lid)))
    for k in range(steps):
        u = k / steps
        wk = lw * (0.45 + 0.75 * u)
        d.line([pts[k], pts[k + 1]], fill=INK + (255,), width=max(int(wk), 1))
        d.ellipse([pts[k][0] - wk / 2, pts[k][1] - wk / 2, pts[k][0] + wk / 2, pts[k][1] + wk / 2], fill=INK + (255,))
    ox, oy = pts[-1]
    flick = [(ox, oy), (ox + side * lw * 1.6, oy - lw * 1.2), (ox + side * lw * 0.4, oy + lw * 0.6)]
    d.polygon(flick, fill=INK + (255,))
    # A thin lower lash on the outer half.
    lo = []
    for k in range(10):
        u = 0.45 + 0.55 * k / 9
        x = inner_x + (outer_x - inner_x) * u
        ex = (x - (l + r) / 2) / ((r - l) / 2)
        lo.append((x, (t + b) / 2 + (b - t) / 2 * math.sqrt(max(1 - ex * ex, 0)) - lw * 0.15))
    d.line(lo, fill=INK + (230,), width=max(int(lw * 0.35), 1), joint="curve")


def blush(img, cx, cy):
    W, H = img.size
    m = Image.new("L", (W, H), 0)
    x, y = px(cx, cy)
    rx, ry = 0.06 / (X1 - X0) * W, 0.022 / (Y1 - Y0) * H
    ImageDraw.Draw(m).ellipse([x - rx, y - ry, x + rx, y + ry], fill=120)
    m = m.filter(ImageFilter.GaussianBlur(rx * 0.35))
    img.paste(Image.new("RGBA", (W, H), (240, 110, 110, 255)), (0, 0), m)


def eyes_texture(style, iris):
    img = Image.new("RGBA", (EW * SS, EH * SS), (0, 0, 0, 0))
    shape = SHAPES[style]
    for side in (-1, 1):
        blush(img, side * 0.26, 1.5)
        eye(img, side * 0.18, 1.615, side, shape, iris)
    img = img.resize((EW, EH), Image.LANCZOS)
    img.save(f"{OUT}/face_eyes_{style}_{iris}.png")


def brows_texture(style):
    img = Image.new("RGBA", (EW * SS, EH * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    (ix, iy), (ox, oy), arch, thick = BROWS[style]
    for side in (-1, 1):
        pts = []
        for k in range(17):
            u = k / 16
            x = side * (ix + (ox - ix) * u)
            y = iy + (oy - iy) * u + arch * math.sin(u * math.pi)
            pts.append(px(x, y))
        th = thick / (Y1 - Y0) * EH * SS
        for k in range(16):
            u = k / 16
            wk = th * (1.0 - 0.55 * u)   # thick inner end tapering outward
            d.line([pts[k], pts[k + 1]], fill=(255, 255, 255, 255), width=max(int(wk), 1))
            d.ellipse([pts[k][0] - wk / 2, pts[k][1] - wk / 2, pts[k][0] + wk / 2, pts[k][1] + wk / 2], fill=(255, 255, 255, 255))
    img = img.resize((EW, EH), Image.LANCZOS)
    img.save(f"{OUT}/face_brows_{style}.png")


def mouth_texture(style):
    MW, MH = 128, 64
    img = Image.new("RGBA", (MW * SS, MH * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    P = lambda x, y: px(x, y, MW, MH, -0.12, 0.12, 1.32, 1.44)
    lw = int(0.011 / 0.12 * MH * SS)
    if style == "bright":
        # An open grin: dark mouth with a tongue.
        m = Image.new("L", img.size, 0)
        ImageDraw.Draw(m).chord([*P(-0.05, 1.415), *P(0.05, 1.345)], 0, 180, fill=255)
        img.paste(Image.new("RGBA", img.size, (90, 24, 30, 255)), (0, 0), m)
        tg = Image.new("L", img.size, 0)
        ImageDraw.Draw(tg).ellipse([*P(-0.03, 1.375), *P(0.03, 1.34)], fill=255)
        img.paste(Image.new("RGBA", img.size, (236, 110, 110, 255)), (0, 0), ImageChops.multiply(tg, m))
        d.line([P(-0.052, 1.388), P(0.052, 1.388)], fill=INK + (255,), width=lw)
    elif style == "fierce":
        # A one-sided smirk.
        d.line([P(-0.04, 1.382), P(0.01, 1.376), P(0.045, 1.392)], fill=INK + (255,), width=lw, joint="curve")
    elif style == "gentle":
        d.arc([*P(-0.035, 1.41), *P(0.035, 1.37)], 20, 160, fill=INK + (255,), width=lw)
    else:
        # Bold: a short determined line, a little turned down.
        d.line([P(-0.035, 1.38), P(0.0, 1.385), P(0.035, 1.38)], fill=INK + (255,), width=lw, joint="curve")
    img = img.resize((MW, MH), Image.LANCZOS)
    img.save(f"{OUT}/face_mouth_{style}.png")


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for st in STYLES:
        for ir in IRIS:
            eyes_texture(st, ir)
        brows_texture(st)
        mouth_texture(st)
    print("wrote faces to", OUT)
